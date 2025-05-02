// Method 2: Using Consumer widget
// This is useful when you want to rebuild only specific parts of the UI
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../provider/settings_provider.dart';

class CalibrationScreen extends StatelessWidget {
  static const routeName = '/calibration';

  const CalibrationScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Calibration')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // This will only rebuild the Text widget when threshold changes
            Consumer<SettingsProvider>(
              builder: (context, settings, child) {
                return Text('Damage Threshold: ${settings.threshold.toStringAsFixed(1)}');
              },
            ),

            // This will only rebuild the Slider when threshold changes
            Consumer<SettingsProvider>(
              builder: (context, settings, child) {
                return Slider(
                  min: 1.0,
                  max: 10.0,
                  divisions: 18,
                  value: settings.threshold,
                  onChanged: settings.updateThreshold,
                );
              },
            ),

            const SizedBox(height: 20),
            const Text('Drive around to test new threshold.'),
          ],
        ),
      ),
    );
  }
}