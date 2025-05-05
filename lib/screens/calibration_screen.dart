// lib/screens/calibration_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../provider/settings_provider.dart';
import '../utils/damage_detector.dart';
import '../repositories/damage_repository.dart';

class CalibrationScreen extends StatefulWidget {
  static const routeName = '/calibration';

  const CalibrationScreen({Key? key}) : super(key: key);

  @override
  _CalibrationScreenState createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends State<CalibrationScreen> {
  final DamageDetector _damageDetector = DamageDetector();
  final DamageRepository _repository = DamageRepository();
  bool _syncInProgress = false;
  String _syncStatus = '';

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _damageDetector.initialize();
    await _repository.initialize();
  }

  Future<void> _syncWithCloud() async {
    setState(() {
      _syncInProgress = true;
      _syncStatus = 'Syncing...';
    });

    try {
      // First upload
      bool uploadSuccess = await _repository.syncWithCloud(true);

      // Then download
      bool downloadSuccess = await _repository.syncWithCloud(false);

      setState(() {
        _syncStatus = uploadSuccess && downloadSuccess
            ? 'Sync completed successfully'
            : 'Sync completed with issues';
      });
    } catch (e) {
      setState(() {
        _syncStatus = 'Sync failed: $e';
      });
    } finally {
      setState(() {
        _syncInProgress = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Consumer<SettingsProvider>(
        builder: (context, settings, child) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Damage Detection section
              _buildSectionHeader('Damage Detection'),

              // Threshold slider
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Damage Threshold: ${settings.threshold.toStringAsFixed(1)}'),
                          Tooltip(
                            message: 'Lower value means more sensitive detection',
                            child: Icon(Icons.info_outline, size: 18),
                          ),
                        ],
                      ),
                      Slider(
                        min: 1.0,
                        max: 10.0,
                        divisions: 18,
                        value: settings.threshold,
                        onChanged: (value) {
                          settings.updateThreshold(value);
                          _damageDetector.updateThreshold(value);
                        },
                      ),
                      Text(
                        'Lower = More Sensitive, Higher = Less Sensitive',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 16),

              // AI section
              _buildSectionHeader('AI Features'),

              // AI mode toggle
              SwitchListTile(
                title: Text('Use AI Detection'),
                subtitle: Text('Intelligently identify road features'),
                value: settings.aiEnabled,
                onChanged: (value) {
                  settings.toggleAIMode(value);
                  _damageDetector.toggleAIMode(value);
                },
              ),

              if (settings.aiEnabled)
                ListTile(
                  title: Text('AI Training Status'),
                  subtitle: Text('${_damageDetector.trainingExampleCount} examples collected'),
                  trailing: ElevatedButton(
                    child: Text('Train AI'),
                    onPressed: () {
                      Navigator.of(context).pushNamed('/training');
                    },
                  ),
                ),

              SizedBox(height: 16),

              // Cloud sync section
              _buildSectionHeader('Cloud Sync'),

              // Auto sync toggle
              SwitchListTile(
                title: Text('Auto Sync'),
                subtitle: Text('Automatically sync data with cloud'),
                value: settings.autoSync,
                onChanged: (value) => settings.toggleAutoSync(value),
              ),

              // Manual sync button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: ElevatedButton(
                  onPressed: _syncInProgress ? null : _syncWithCloud,
                  child: _syncInProgress
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
                      SizedBox(width: 8),
                      Text('Syncing...'),
                    ],
                  )
                      : Text('Sync Now'),
                ),
              ),

              if (_syncStatus.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    _syncStatus,
                    style: TextStyle(
                      fontSize: 12,
                      color: _syncStatus.contains('failed')
                          ? Colors.red
                          : Colors.green,
                    ),
                  ),
                ),

              SizedBox(height: 16),

              // About section
              _buildSectionHeader('About'),

              ListTile(
                title: Text('Road Damage Detector'),
                subtitle: Text('Version 1.1.0'),
                leading: Icon(Icons.info),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).primaryColor,
        ),
      ),
    );
  }
}