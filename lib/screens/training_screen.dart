// lib/screens/training_screen.dart
import 'package:flutter/material.dart';
import '../utils/damage_detector.dart';
import 'package:provider/provider.dart';
import '../services/damage_ai_service.dart';
import '../services/location_service.dart';
import '../provider/settings_provider.dart';
import '../models/road_feature_type.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TrainingScreen extends StatefulWidget {
  static const routeName = '/training';

  const TrainingScreen({Key? key}) : super(key: key);

  @override
  _TrainingScreenState createState() => _TrainingScreenState();
}

class _TrainingScreenState extends State<TrainingScreen> {
  late final DamageDetector _damageDetector;
  // The repository can be removed if not used
  bool _isTraining = false;
  String _trainingStatus = '';
  int _currentExampleCount = 0;
  String? _userId;
  final DatabaseReference _trainingDataRef = FirebaseDatabase.instance.ref('training_data');

  @override
  void initState() {
    super.initState();
    _damageDetector = DamageDetector(
      aiService: DamageAIService(),
      locationService: LocationServiceImpl(),
    );
    _initialize();
  }

  Future<void> _initialize() async {
    _userId = FirebaseAuth.instance.currentUser?.uid;
    await _damageDetector.initialize();
    await _loadTrainingExampleCount();
  }

  Future<void> _loadTrainingExampleCount() async {
    if (_userId == null) return;

    try {
      final snapshot = await _trainingDataRef.child(_userId!).child('metadata').child('exampleCount').get();

      if (snapshot.exists) {
        setState(() {
          _currentExampleCount = (snapshot.value as int?) ?? 0;
          _damageDetector.updateTrainingExampleCount(_currentExampleCount);
        });
      }
    } catch (e) {
      debugPrint('Error loading training example count: $e');
    }
  }

  Future<void> _startTraining() async {
    if (_userId == null) return;

    setState(() {
      _isTraining = true;
      _trainingStatus = 'Training AI model...';
    });

    try {
      // Get training data from Firebase
      final snapshot = await _trainingDataRef.child(_userId!).child('examples').get();

      if (snapshot.exists) {
        final trainingData = snapshot.value as Map<dynamic, dynamic>;

        // Convert data to format needed by damage detector
        final examples = <Map<String, dynamic>>[];

        trainingData.forEach((key, value) {
          final example = value as Map<dynamic, dynamic>;
          examples.add({
            'type': example['type'],
            'features': example['features'],
          });
        });

        // Train model
        bool success = await _damageDetector.trainModelWithData(examples);

        // Save model to Firebase
        if (success) {
          final modelData = await _damageDetector.exportTrainedModelData();
          await _trainingDataRef.child(_userId!).child('model').set(modelData);
        }

        setState(() {
          _trainingStatus = success
              ? 'Training completed successfully'
              : 'Training completed with issues';
        });
      } else {
        setState(() {
          _trainingStatus = 'No training data found';
        });
      }
    } catch (e) {
      setState(() {
        _trainingStatus = 'Training failed: $e';
      });
    } finally {
      setState(() {
        _isTraining = false;
      });
    }
  }

  Future<void> _clearTrainingData() async {
    if (_userId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Training Data'),
        content: const Text('Are you sure you want to clear all training data? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Clear Data', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Clear from local detector
        await _damageDetector.clearTrainingData();

        // Clear from Firebase
        await _trainingDataRef.child(_userId!).remove();

        setState(() {
          _currentExampleCount = 0;
          _trainingStatus = 'Training data cleared';
        });
      } catch (e) {
        setState(() {
          _trainingStatus = 'Failed to clear data: $e';
        });
      }
    }
  }

  Future<void> _collectExampleManually(RoadFeatureType type) async {
    if (_userId == null) return;

    try {
      // Collect sensor data for training example
      final exampleData = await _damageDetector.collectTrainingExample();

      // Save to Firebase
      final exampleId = DateTime.now().millisecondsSinceEpoch.toString();

      await _trainingDataRef
          .child(_userId!)
          .child('examples')
          .child(exampleId)
          .set({
        'type': type.toString().split('.').last,
        'features': exampleData,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      // Update example count
      _currentExampleCount++;
      await _trainingDataRef
          .child(_userId!)
          .child('metadata')
          .child('exampleCount')
          .set(_currentExampleCount);

      // Update local detector
      _damageDetector.updateTrainingExampleCount(_currentExampleCount);

      setState(() {
        _trainingStatus = 'Example added for ${_getFeatureTypeName(type)}';
      });
    } catch (e) {
      setState(() {
        _trainingStatus = 'Failed to add example: $e';
      });
    }
  }

  String _getFeatureTypeName(RoadFeatureType type) {
    switch (type) {
      case RoadFeatureType.pothole:
        return 'Pothole';
      case RoadFeatureType.roughPatch:
        return 'Rough Patch';
      case RoadFeatureType.speedBreaker:
        return 'Speed Breaker';
      case RoadFeatureType.railwayCrossing:
        return 'Railway Crossing';
      case RoadFeatureType.smooth:
        return 'Smooth Road';
      default:
        return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Training'),
      ),
      body: Consumer<SettingsProvider>(
        builder: (context, settings, child) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Status Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI Training Status',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Examples collected:'),
                          Text(
                            '$_currentExampleCount',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: ElevatedButton(
                          onPressed: _currentExampleCount >= 10 && !_isTraining
                              ? _startTraining
                              : null,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 12,
                            ),
                          ),
                          child: _isTraining
                              ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text('Training...'),
                            ],
                          )
                              : const Text('Train AI Model'),
                        ),
                      ),
                      if (_currentExampleCount < 10)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Text(
                              'Need at least 10 examples to train',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        ),
                      if (_trainingStatus.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Text(
                            _trainingStatus,
                            style: TextStyle(
                              color: _trainingStatus.contains('failed') || _trainingStatus.contains('Failed')
                                  ? Colors.red
                                  : _trainingStatus.contains('completed') || _trainingStatus.contains('added')
                                  ? Colors.green
                                  : Colors.blue,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Manual Collection Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Manual Data Collection',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      ListTile(
                        title: const Text('Pothole'),
                        subtitle: const Text('Deep holes in the road'),
                        trailing: IconButton(
                          icon: const Icon(Icons.add_circle),
                          color: Theme.of(context).primaryColor,
                          onPressed: () => _collectExampleManually(RoadFeatureType.pothole),
                        ),
                      ),
                      const Divider(),
                      ListTile(
                        title: const Text('Rough Patch'),
                        subtitle: const Text('Uneven road surface'),
                        trailing: IconButton(
                          icon: const Icon(Icons.add_circle),
                          color: Theme.of(context).primaryColor,
                          onPressed: () => _collectExampleManually(RoadFeatureType.roughPatch),
                        ),
                      ),
                      const Divider(),
                      ListTile(
                        title: const Text('Speed Breaker'),
                        subtitle: const Text('Intentional bumps to slow traffic'),
                        trailing: IconButton(
                          icon: const Icon(Icons.add_circle),
                          color: Theme.of(context).primaryColor,
                          onPressed: () => _collectExampleManually(RoadFeatureType.speedBreaker),
                        ),
                      ),
                      const Divider(),
                      ListTile(
                        title: const Text('Railway Crossing'),
                        subtitle: const Text('Train tracks crossing road'),
                        trailing: IconButton(
                          icon: const Icon(Icons.add_circle),
                          color: Theme.of(context).primaryColor,
                          onPressed: () => _collectExampleManually(RoadFeatureType.railwayCrossing),
                        ),
                      ),
                      const Divider(),
                      ListTile(
                        title: const Text('Smooth Road'),
                        subtitle: const Text('Well maintained road surface'),
                        trailing: IconButton(
                          icon: const Icon(Icons.add_circle),
                          color: Theme.of(context).primaryColor,
                          onPressed: () => _collectExampleManually(RoadFeatureType.smooth),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Data Management Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Data Management',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.delete_forever),
                          label: const Text('Clear All Training Data'),
                          onPressed: _currentExampleCount > 0 ? _clearTrainingData : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}