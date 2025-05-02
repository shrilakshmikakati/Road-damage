// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../provider/settings_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({Key? key}) : super(key: key);
  static const routeName = '/settings';

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);

    return Scaffold(
      appBar: AppBar(title: Text('Settings')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: ListView(
          children: [
            // Threshold Settings
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Detection Settings', style: Theme.of(context).textTheme.titleLarge),
                    SizedBox(height: 16),
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

            SizedBox(height: 16),

            // Map Settings
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Map Settings', style: Theme.of(context).textTheme.titleLarge),
                    SizedBox(height: 16),
                    ListTile(
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

            SizedBox(height: 16),

            // Appearance Settings
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Appearance', style: Theme.of(context).textTheme.titleLarge),
                    SizedBox(height: 16),
                    SwitchListTile(
                      title: Text('Dark Mode'),
                      subtitle: Text('Enable dark theme for the app'),
                      value: settings.darkMode,
                      onChanged: settings.toggleDarkMode,
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 16),

            // Data Settings
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Data Settings', style: Theme.of(context).textTheme.titleLarge),
                    SizedBox(height: 16),
                    SwitchListTile(
                      title: Text('Cloud Sync'),
                      subtitle: Text('Sync your data to the cloud'),
                      value: settings.cloudSync,
                      onChanged: settings.toggleCloudSync,
                    ),
                    if (settings.cloudSync)
                      Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          'Note: You need to set up a Firebase account to use this feature',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 16),

            // About
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('About', style: Theme.of(context).textTheme.titleLarge),
                    SizedBox(height: 16),
                    ListTile(
                      title: Text('Road Damage Detector'),
                      subtitle: Text('Version 1.0.0'),
                      trailing: Icon(Icons.info_outline),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}