import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../provider/settings_provider.dart';
import '../services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SettingsScreen extends StatefulWidget {
  static const routeName = '/settings';

  const SettingsScreen({Key? key}) : super(key: key);

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isLoading = false;
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _emailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        _displayNameController.text = user.displayName ?? '';
        _emailController.text = user.email ?? '';
      });
    }
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && _displayNameController.text.isNotEmpty) {
        await user.updateDisplayName(_displayNameController.text.trim());

        // Update local storage
        final authService = Provider.of<AuthService>(context, listen: false);
        await authService.saveUserDataLocally(user);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating profile: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _resetPassword() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.resetPassword(_emailController.text.trim());

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset email sent')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending password reset: $e')),
      );
    }
  }

  Future<void> _clearLocalData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Local data cleared')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error clearing data: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Profile Section
            const Text(
              'User Profile',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _displayNameController,
                    decoration: const InputDecoration(
                      labelText: 'Display Name',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email),
                    ),
                    readOnly: true,
                    enabled: false,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _updateProfile,
                          icon: const Icon(Icons.save),
                          label: const Text('Update Profile'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _resetPassword,
                          icon: const Icon(Icons.lock_reset),
                          label: const Text('Reset Password'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const Divider(height: 32),

            // App Settings Section
            const Text(
              'App Settings',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // Dark Mode Toggle
            SwitchListTile(
              title: const Text('Dark Mode'),
              subtitle: const Text('Enable dark theme'),
              value: settings.darkMode,
              onChanged: (value) {
                settings.toggleDarkMode();
              },
              secondary: const Icon(Icons.dark_mode),
            ),

            // Notifications Toggle
            SwitchListTile(
              title: const Text('Notifications'),
              subtitle: const Text('Enable push notifications'),
              value: settings.notificationsEnabled,
              onChanged: (value) {
                settings.toggleNotifications();
              },
              secondary: const Icon(Icons.notifications),
            ),

            // Background Tracking Toggle
            SwitchListTile(
              title: const Text('Background Tracking'),
              subtitle: const Text('Continue tracking in background'),
              value: settings.backgroundTrackingEnabled,
              onChanged: (value) {
                settings.toggleBackgroundTracking();
              },
              secondary: const Icon(Icons.location_on),
            ),

            // Sensitivity Slider
            ListTile(
              title: const Text('Detection Sensitivity'),
              subtitle: Text('Current: ${settings.sensitivityThreshold.toStringAsFixed(1)}'),
              leading: const Icon(Icons.tune),
            ),
            Slider(
              value: settings.sensitivityThreshold,
              min: 1.0,
              max: 10.0,
              divisions: 9,
              label: settings.sensitivityThreshold.toStringAsFixed(1),
              onChanged: (value) {
                settings.setSensitivityThreshold(value);
              },
            ),

            const Divider(height: 32),

            // Data Management Section
            const Text(
              'Data Management',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            ListTile(
              title: const Text('Clear Local Data'),
              subtitle: const Text('Remove all locally stored data'),
              leading: const Icon(Icons.delete_forever),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Clear Local Data'),
                    content: const Text(
                      'Are you sure you want to clear all locally stored data? This action cannot be undone.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                        },
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          _clearLocalData();
                        },
                        child: const Text('Clear'),
                      ),
                    ],
                  ),
                );
              },
            ),

            ListTile(
              title: const Text('Export Data'),
              subtitle: const Text('Export collected road data'),
              leading: const Icon(Icons.upload_file),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Export feature coming soon')),
                );
              },
            ),

            const SizedBox(height: 16),

            // About Section
            const Divider(height: 32),

            const Text(
              'About',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            ListTile(
              title: const Text('App Version'),
              subtitle: const Text('1.0.0'),
              leading: const Icon(Icons.info),
            ),

            ListTile(
              title: const Text('Terms of Service'),
              leading: const Icon(Icons.description),
              onTap: () {
                // Navigate to Terms of Service
              },
            ),

            ListTile(
              title: const Text('Privacy Policy'),
              leading: const Icon(Icons.privacy_tip),
              onTap: () {
                // Navigate to Privacy Policy
              },
            ),
          ],
        ),
      ),
    );
  }
}