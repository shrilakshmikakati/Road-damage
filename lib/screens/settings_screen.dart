// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../provider/settings_provider.dart';
import '../utils/damage_detector.dart';
import '../repositories/damage_repository.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:location/location.dart';
import '../services/location_service.dart';
import '../services/damage_ai_service.dart'; // Correct import path

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);
  static const routeName = '/settings';

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}
class _SettingsScreenState extends State<SettingsScreen> {
  final DamageDetector _damageDetector = DamageDetector(
    aiService: DamageAIService(),
    locationService: LocationServiceImpl(),
  );
  final DamageRepository _repository = DamageRepository();
  bool _isSyncing = false;
  String _syncStatus = '';
  String _appVersion = '1.0.0';

  @override
  void initState() {
    super.initState();
    _initialize();
    _loadAppInfo();
  }

  Future<void> _initialize() async {
    await _damageDetector.initialize();
    await _repository.initialize();
  }

  Future<void> _loadAppInfo() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      setState(() {
        _appVersion = packageInfo.version;
      });
    } catch (e) {
      // Use default version if unable to get package info
    }
  }

  Future<void> _syncWithCloud(bool isUpload) async {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    if (!settings.cloudSync) {
      _showInfoDialog(
          'Cloud Sync Disabled',
          'Please enable Cloud Sync first to use this feature.'
      );
      return;
    }

    setState(() {
      _isSyncing = true;
      _syncStatus = isUpload ? 'Uploading data...' : 'Downloading data...';
    });

    try {
      final success = await _repository.syncWithCloud(isUpload);

      if (success) {
        _showInfoDialog(
            isUpload ? 'Upload Complete' : 'Download Complete',
            isUpload
                ? 'Your data has been successfully synced to the cloud.'
                : 'Your data has been successfully downloaded from the cloud.'
        );
        setState(() {
          _syncStatus = isUpload
              ? 'Upload completed successfully'
              : 'Download completed successfully';
        });
      } else {
        _showInfoDialog(
            isUpload ? 'Upload Notice' : 'Download Notice',
            isUpload
                ? 'There was a problem syncing your data. Please try again.'
                : 'No new data found in the cloud or there was a problem downloading.'
        );
        setState(() {
          _syncStatus = isUpload
              ? 'Upload completed with issues'
              : 'Download completed with issues';
        });
      }
    } catch (e) {
      _showInfoDialog(isUpload ? 'Upload Error' : 'Download Error', 'Error: $e');
      setState(() {
        _syncStatus = 'Sync failed: $e';
      });
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
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

  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      _showInfoDialog('Error', 'Could not open $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Settings')),
      body: Stack(
        children: [
          Consumer<SettingsProvider>(
            builder: (context, settings, child) {
              return ListView(
                padding: EdgeInsets.all(16),
                children: [
                  // Detection Settings
                  Card(
                    margin: EdgeInsets.only(bottom: 16),
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.analytics_outlined, color: Theme.of(context).primaryColor),
                              SizedBox(width: 8),
                              Text('Detection Settings', style: Theme.of(context).textTheme.titleLarge),
                            ],
                          ),
                          Divider(),
                          SizedBox(height: 8),
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
                          SizedBox(height: 16),
                          // AI mode toggle
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
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
                              contentPadding: EdgeInsets.zero,
                              title: Text('AI Training Status'),
                              subtitle: Text('${_damageDetector.trainingExampleCount} examples collected'),
                              trailing: ElevatedButton(
                                child: Text('Train AI'),
                                onPressed: () {
                                  Navigator.of(context).pushNamed('/training');
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // Map Settings
                  Card(
                    margin: EdgeInsets.only(bottom: 16),
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.map_outlined, color: Theme.of(context).primaryColor),
                              SizedBox(width: 8),
                              Text('Map Settings', style: Theme.of(context).textTheme.titleLarge),
                            ],
                          ),
                          Divider(),
                          SizedBox(height: 8),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text('Map Type'),
                            trailing: DropdownButton<String>(
                              value: settings.mapStyle,
                              onChanged: (value) {
                                if (value != null) settings.setMapStyle(value);
                              },
                              items: [
                                DropdownMenuItem(
                                  value: 'standard',
                                  child: Text('Standard'),
                                ),
                                DropdownMenuItem(
                                  value: 'satellite',
                                  child: Text('Satellite'),
                                ),
                                DropdownMenuItem(
                                  value: 'terrain',
                                  child: Text('Terrain'),
                                ),
                              ],
                            ),
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text('Night Mode Map'),
                            subtitle: Text('Use dark styled map at night'),
                            value: settings.nightModeMap,
                            onChanged: (value) {
                              settings.setNightModeMap(value);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Appearance Settings
                  Card(
                    margin: EdgeInsets.only(bottom: 16),
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.palette_outlined, color: Theme.of(context).primaryColor),
                              SizedBox(width: 8),
                              Text('Appearance', style: Theme.of(context).textTheme.titleLarge),
                            ],
                          ),
                          Divider(),
                          SizedBox(height: 8),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text('Dark Mode'),
                            subtitle: Text('Use dark theme throughout the app'),
                            value: settings.darkMode,
                            onChanged: (value) {
                              settings.setDarkMode(value);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Storage & Sync Settings
                  Card(
                    margin: EdgeInsets.only(bottom: 16),
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.storage_outlined, color: Theme.of(context).primaryColor),
                              SizedBox(width: 8),
                              Text('Storage & Sync', style: Theme.of(context).textTheme.titleLarge),
                            ],
                          ),
                          Divider(),
                          SizedBox(height: 8),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text('Cloud Sync'),
                            subtitle: Text('Sync road condition data with the cloud'),
                            value: settings.cloudSync,
                            onChanged: settings.setCloudSync,
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text('Auto Sync'),
                            subtitle: Text('Automatically sync when connected to WiFi'),
                            value: settings.autoSync,
                            onChanged: settings.cloudSync ? (value) => settings.toggleAutoSync(value) : null,
                          ),
                          Divider(),
                          SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: settings.cloudSync && !_isSyncing
                                      ? () => _syncWithCloud(true)
                                      : null,
                                  icon: Icon(Icons.upload),
                                  label: Text('Upload Data'),
                                ),
                              ),
                              SizedBox(width: 16),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: settings.cloudSync && !_isSyncing
                                      ? () => _syncWithCloud(false)
                                      : null,
                                  icon: Icon(Icons.download),
                                  label: Text('Download Data'),
                                ),
                              ),
                            ],
                          ),
                          if (_syncStatus.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
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
                        ],
                      ),
                    ),
                  ),

                  // About Section
                  Card(
                    margin: EdgeInsets.only(bottom: 16),
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info_outline, color: Theme.of(context).primaryColor),
                              SizedBox(width: 8),
                              Text('About', style: Theme.of(context).textTheme.titleLarge),
                            ],
                          ),
                          Divider(),
                          SizedBox(height: 8),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text('Road Damage Detector'),
                            subtitle: Text('Version $_appVersion'),
                            trailing: Icon(Icons.arrow_forward_ios, size: 16),
                            onTap: () => _showInfoDialog(
                                'App Version',
                                'Road Damage Detector\nVersion: $_appVersion\n\nThis app helps detect and map road damage using your device sensors.'
                            ),
                          ),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text('Privacy Policy'),
                            trailing: Icon(Icons.arrow_forward_ios, size: 16),
                            onTap: () => _launchURL('https://example.com/privacy'),
                          ),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text('Send Feedback'),
                            trailing: Icon(Icons.arrow_forward_ios, size: 16),
                            onTap: () => _launchURL('mailto:feedback@example.com'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          // Loading overlay
          if (_isSyncing)
            Container(
              color: Colors.black26,
              child: Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text(_syncStatus),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}