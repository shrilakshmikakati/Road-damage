// lib/screens/calibration_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../provider/settings_provider.dart';
import 'package:location/location.dart';
import '../utils/damage_detector.dart';
import '../services/location_service.dart';
import '../services/damage_ai_service.dart';
import '../repositories/damage_repository.dart';

class CalibrationScreen extends StatefulWidget {
  static const routeName = '/calibration';

  const CalibrationScreen({Key? key}) : super(key: key);

  @override
  _CalibrationScreenState createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends State<CalibrationScreen> {
  final DamageDetector _damageDetector = DamageDetector(
    aiService: DamageAIService(),
    locationService: LocationServiceImpl(),
  );
  final DamageRepository _repository = DamageRepository();
  bool _syncInProgress = false;
  String _syncStatus = '';
  bool _isCalibrating = false;
  double _calibrationProgress = 0.0;
  String _calibrationStatus = 'Not calibrated';

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _damageDetector.initialize();
    await _repository.initialize();

    // Check if already calibrated
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    if (settings.isCalibrated) {
      setState(() {
        _calibrationStatus = 'Device calibrated';
        _calibrationProgress = 1.0;
      });
    }
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

  Future<void> _startCalibration() async {
    setState(() {
      _isCalibrating = true;
      _calibrationProgress = 0.0;
      _calibrationStatus = 'Calibrating...';
    });

    // Simulate calibration process
    for (int i = 1; i <= 10; i++) {
      await Future.delayed(Duration(milliseconds: 300));
      setState(() {
        _calibrationProgress = i / 10;
      });
    }

    // Update settings when calibration is complete
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    settings.setCalibrated(true);

    setState(() {
      _isCalibrating = false;
      _calibrationStatus = 'Calibration complete';
    });

    // Show success dialog
    _showInfoDialog(
        'Calibration Complete',
        'Your device has been successfully calibrated for optimal damage detection.'
    );
  }

  void _showInfoDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).primaryColor,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Calibration & Settings')),
      body: Consumer<SettingsProvider>(
        builder: (context, settings, child) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Calibration section
              _buildSectionHeader('Device Calibration'),

              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Calibration Status: $_calibrationStatus',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 12),
                      LinearProgressIndicator(
                        value: _calibrationProgress,
                        backgroundColor: Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).primaryColor,
                        ),
                      ),
                      SizedBox(height: 16),
                      Center(
                        child: ElevatedButton.icon(
                          icon: Icon(_isCalibrating ? Icons.hourglass_top : Icons.sensors),
                          label: Text(_isCalibrating ? 'Calibrating...' : 'Start Calibration'),
                          onPressed: _isCalibrating ? null : _startCalibration,
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                        ),
                      ),
                      SizedBox(height: 8),
                      Center(
                        child: Text(
                          'Place your device on a flat surface for best results',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

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
                            child: Icon(Icons.info_outline, size: 16),
                          ),
                        ],
                      ),
                      Slider(
                        value: settings.threshold,
                        min: 0.5,
                        max: 5.0,
                        divisions: 9,
                        label: settings.threshold.toStringAsFixed(1),
                        onChanged: (value) => settings.updateThreshold(value),
                      ),
                      Text(
                        'Sensitivity: ${settings.threshold <= 1.5 ? "High" : settings.threshold <= 3.0 ? "Medium" : "Low"}',
                        style: TextStyle(
                          color: settings.threshold <= 1.5
                              ? Colors.red
                              : settings.threshold <= 3.0
                              ? Colors.orange
                              : Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // AI toggle
              SwitchListTile(
                title: Text('AI Detection'),
                subtitle: Text('Use AI for more accurate detection'),
                value: settings.aiEnabled,
                onChanged: (value) => settings.toggleAI(value),
              ),

              // AI training status
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
                      color: _syncStatus.contains('failed')
                          ? Colors.red
                          : _syncStatus.contains('issues')
                          ? Colors.orange
                          : Colors.green,
                    ),
                  ),
                ),

              // Navigation section
              _buildSectionHeader('Navigation'),

              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(Icons.map),
                      title: Text('Home Map'),
                      subtitle: Text('View road damage map'),
                      trailing: Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () => Navigator.of(context).pushReplacementNamed('/home'),
                    ),
                    Divider(height: 1),
                    ListTile(
                      leading: Icon(Icons.history),
                      title: Text('History'),
                      subtitle: Text('View damage history'),
                      trailing: Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () => Navigator.of(context).pushNamed('/history'),
                    ),
                    Divider(height: 1),
                    ListTile(
                      leading: Icon(Icons.settings),
                      title: Text('Settings'),
                      subtitle: Text('Advanced settings'),
                      trailing: Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () => Navigator.of(context).pushNamed('/settings'),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }
}