// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../provider/settings_provider.dart';
import '../repositories/damage_repository.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);
  static const routeName = '/settings';

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final DamageRepository _repository = DamageRepository();
  bool _isSyncing = false;
  String _appVersion = '1.0.0';

  @override
  void initState() {
    super.initState();
    _loadAppInfo();
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

  Future<void> _syncWithCloud() async {
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
    });

    try {
      final success = await _repository.syncWithCloud(true);

      if (success) {
        _showInfoDialog('Sync Complete', 'Your data has been successfully synced to the cloud.');
      } else {
        _showInfoDialog('Sync Error', 'There was a problem syncing your data. Please try again.');
      }
    } catch (e) {
      _showInfoDialog('Sync Error', 'Error: $e');
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }

  Future<void> _downloadFromCloud() async {
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
    });

    try {
      final success = await _repository.syncWithCloud(false);

      if (success) {
        _showInfoDialog(
            'Download Complete',
            'Your data has been successfully downloaded from the cloud.'
        );
      } else {
        _showInfoDialog(
            'Download Notice',
            'No new data found in the cloud or there was a problem downloading.'
        );
      }
    } catch (e) {
      _showInfoDialog('Download Error', 'Error: $e');
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
    final settings = Provider.of<SettingsProvider>(context);

    return Scaffold(
      appBar: AppBar(title: Text('Settings')),
      body: Stack(
        children: [
          ListView(
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
                      Text('Damage Threshold: ${settings.threshold.toStringAsFixed(1)}'),
                      Slider(
                        min: 1.0,
                        max: 10.0,
                        divisions: 18,
                        value: settings.threshold,
                        onChanged: settings.updateThreshold,
                      ),
                      Text(
                        'Higher values make the app less sensitive to bumps.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
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

              // Storage Settings
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
                        onChanged: settings.cloudSync ? settings.setAutoSync : null,
                      ),
                      Divider(),
                      SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: settings.cloudSync && !_isSyncing
                                  ? _syncWithCloud
                                  : null,
                              icon: Icon(Icons.upload),
                              label: Text('Upload Data'),
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: settings.cloudSync && !_isSyncing
                                  ? _downloadFromCloud
                                  : null,
                              icon: Icon(Icons.download),
                              label: Text('Download Data'),
                            ),
                          ),
                        ],
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
                        title: Text('Version'),
                        subtitle: Text(_appVersion),
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
                        Text('Syncing data...'),
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