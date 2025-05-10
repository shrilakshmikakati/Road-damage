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
import '../services/damage_ai_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
  bool _isInitialized = false;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _initialize();
    _loadAppInfo();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    setState(() {
      _isLoggedIn = user != null;
    });
  }

  Future<void> _initialize() async {
    try {
      await _damageDetector.initialize();
      await _repository.initialize();

      // Update the detector with current settings
      final settings = Provider.of<SettingsProvider>(context, listen: false);
      _damageDetector.updateThreshold(settings.threshold);
      _damageDetector.setAIMode(settings.aiEnabled);

      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      print('Error initializing: $e');
      _showInfoDialog('Initialization Error', 'Failed to initialize: $e');
    }
  }

  Future<void> _loadAppInfo() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      setState(() {
        _appVersion = packageInfo.version;
      });
    } catch (e) {
      print('Error loading app info: $e');
    }
  }

  Future<void> _syncWithCloud(bool isUpload) async {
    if (!_isInitialized) {
      _showInfoDialog('Not Ready', 'Please wait for initialization to complete.');
      return;
    }

    if (!_isLoggedIn) {
      _showLoginPrompt();
      return;
    }

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
      _syncStatus = isUpload ? 'Uploading data to Firebase...' : 'Downloading data from Firebase...';
    });

    try {
      final success = await _repository.syncWithCloud(isUpload);

      if (success) {
        _showInfoDialog(
            isUpload ? 'Upload Complete' : 'Download Complete',
            isUpload
                ? 'Your data has been successfully synced to Firebase.'
                : 'Your data has been successfully downloaded from Firebase.'
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
                : 'No new data found in Firebase or there was a problem downloading.'
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

  void _showLoginPrompt() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Login Required'),
        content: Text('You need to be logged in to use cloud sync features. Would you like to log in now?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('CANCEL'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pushNamed('/auth');
            },
            child: Text('LOGIN'),
          ),
        ],
      ),
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

  Future<void> _launchURL(String url) async {
    try {
      final Uri uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        _showInfoDialog('Error', 'Could not open $url');
      }
    } catch (e) {
      _showInfoDialog('Error', 'Failed to open URL: $e');
    }
  }

  Future<void> _clearAllData() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Clear All Data'),
        content: Text('This will delete all your recorded road damage data. This action cannot be undone. Do you want to continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('DELETE', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final settings = Provider.of<SettingsProvider>(context, listen: false);
        await _repository.clearRecords(syncToCloud: settings.cloudSync && _isLoggedIn);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('All data has been cleared')),
        );
      } catch (e) {
        _showInfoDialog('Error', 'Failed to clear data: $e');
      }
    }
  }

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Sign Out'),
        content: Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('SIGN OUT'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseAuth.instance.signOut();
        setState(() {
          _isLoggedIn = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Signed out successfully')),
        );
      } catch (e) {
        _showInfoDialog('Error', 'Failed to sign out: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () async {
              await _initialize();
              await _checkLoginStatus();
              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Settings refreshed')),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.help_outline),
            onPressed: () => _showInfoDialog(
                'Settings Help',
                'This screen allows you to configure app settings, manage data, and customize your experience.'
            ),
          ),
        ],
      ),
      body: !_isInitialized
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Initializing settings...'),
          ],
        ),
      )
          : Stack(
        children: [
          Consumer<SettingsProvider>(
            builder: (context, settings, child) {
              return ListView(
                padding: EdgeInsets.all(16),
                children: [
                  // User Account
                  if (_isLoggedIn)
                    Card(
                      margin: EdgeInsets.only(bottom: 16),
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.account_circle, color: Theme.of(context).primaryColor),
                                SizedBox(width: 8),
                                Text('Account', style: Theme.of(context).textTheme.titleLarge),
                              ],
                            ),
                            Divider(),
                            SizedBox(height: 8),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(FirebaseAuth.instance.currentUser?.email ?? 'User'),
                              subtitle: Text('Logged in'),
                              trailing: ElevatedButton(
                                onPressed: _signOut,
                                child: Text('Sign Out'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Detection Settings
                  Card(
                    margin: EdgeInsets.only(bottom: 16),
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                              settings.toggleAI(value);
                              _damageDetector.setAIMode(value);
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
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

                  // Appearance
                  Card(
                    margin: EdgeInsets.only(bottom: 16),
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Restart the app to apply theme changes'),
                                  duration: Duration(seconds: 3),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Storage & Sync
                  Card(
                    margin: EdgeInsets.only(bottom: 16),
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                            subtitle: Text('Sync road condition data with Firebase'),
                            value: settings.cloudSync,
                            onChanged: _isLoggedIn ? settings.setCloudSync : (value) {
                              if (value) {
                                _showLoginPrompt();
                              }
                            },
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text('Auto Sync'),
                            subtitle: Text('Automatically sync when connected to WiFi'),
                            value: settings.autoSync,
                            onChanged: (settings.cloudSync && _isLoggedIn)
                                ? (value) => settings.toggleAutoSync(value)
                                : null,
                          ),
                          Divider(),
                          SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: (settings.cloudSync && !_isSyncing && _isLoggedIn)
                                      ? () => _syncWithCloud(true)
                                      : null,
                                  icon: Icon(Icons.upload),
                                  label: Text('Upload to Firebase'),
                                ),
                              ),
                              SizedBox(width: 16),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: (settings.cloudSync && !_isSyncing && _isLoggedIn)
                                      ? () => _syncWithCloud(false)
                                      : null,
                                  icon: Icon(Icons.download),
                                  label: Text('Download from Firebase'),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _clearAllData,
                            icon: Icon(Icons.delete_forever),
                            label: Text('Clear All Data'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
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
                                      : _syncStatus.contains('issues')
                                      ? Colors.orange
                                      : Colors.green,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // About
                  Card(
                    margin: EdgeInsets.only(bottom: 16),
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                          Divider(),
                          SizedBox(height: 8),
                          Center(
                            child: Text(
                              '© 2023 Road Damage Detector Team',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Navigation
                  Card(
                    margin: EdgeInsets.only(bottom: 16),
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.navigation, color: Theme.of(context).primaryColor),
                              SizedBox(width: 8),
                              Text('Navigation', style: Theme.of(context).textTheme.titleLarge),
                            ],
                          ),
                          Divider(),
                          SizedBox(height: 8),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.map),
                            title: Text('Home Map'),
                            subtitle: Text('View road damage map'),
                            trailing: Icon(Icons.arrow_forward_ios, size: 16),
                            onTap: () => Navigator.of(context).pushReplacementNamed('/home'),
                          ),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.history),
                            title: Text('History'),
                            subtitle: Text('View damage history'),
                            trailing: Icon(Icons.arrow_forward_ios, size: 16),
                            onTap: () => Navigator.of(context).pushNamed('/history'),
                          ),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.tune),
                            title: Text('Calibration'),
                            subtitle: Text('Calibrate sensors'),
                            trailing: Icon(Icons.arrow_forward_ios, size: 16),
                            onTap: () => Navigator.of(context).pushNamed('/calibration'),
                          ),
                          if (!_isLoggedIn)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(Icons.login),
                              title: Text('Login'),
                              subtitle: Text('Sign in to enable cloud features'),
                              trailing: Icon(Icons.arrow_forward_ios, size: 16),
                              onTap: () => Navigator.of(context).pushNamed('/auth'),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

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