import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:provider/provider.dart';
import '../provider/settings_provider.dart';
import '../utils/damage_detector.dart';

class CalibrationScreen extends StatefulWidget {
  static const routeName = '/calibration';

  const CalibrationScreen({Key? key}) : super(key: key);

  @override
  _CalibrationScreenState createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends State<CalibrationScreen> {
  final DamageDetector _damageDetector = DamageDetector();

  List<double> _accelerometerValues = [0, 0, 0];
  List<List<double>> _accelerometerHistory = [];

  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;

  double _maxZ = 0;
  double _minZ = 0;
  double _currentThreshold = 1.5;

  @override
  void initState() {
    super.initState();
    _damageDetector.initialize();
    _startListening();

    // Get current threshold from settings
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settings = Provider.of<SettingsProvider>(context, listen: false);
      setState(() {
        _currentThreshold = settings.sensitivityThreshold;
      });
    });
  }

  void _startListening() {
    _accelerometerSubscription = accelerometerEvents.listen((AccelerometerEvent event) {
      setState(() {
        _accelerometerValues = [event.x, event.y, event.z];
        _accelerometerHistory.add([event.x, event.y, event.z]);

        // Keep history to a reasonable size
        if (_accelerometerHistory.length > 100) {
          _accelerometerHistory.removeAt(0);
        }

        // Update min/max Z values
        if (event.z > _maxZ) _maxZ = event.z;
        if (event.z < _minZ) _minZ = event.z;
      });
    });
  }

  void _resetCalibration() {
    setState(() {
      _maxZ = 0;
      _minZ = 0;
      _accelerometerHistory.clear();
    });
  }

  void _saveCalibration() {
    // Calculate a good threshold based on recorded values
    double range = (_maxZ - _minZ).abs();
    double suggestedThreshold = range * 0.4; // 40% of the range

    // Ensure threshold is at least 1.0
    suggestedThreshold = suggestedThreshold < 1.0 ? 1.0 : suggestedThreshold;

    // Update settings
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    settings.updateSensitivityThreshold(suggestedThreshold);

    setState(() {
      _currentThreshold = suggestedThreshold;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Calibration saved. New threshold: ${suggestedThreshold.toStringAsFixed(2)}')),
    );
  }

  @override
  void dispose() {
    _accelerometerSubscription?.cancel();
    _damageDetector.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calibration'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Calibration Instructions',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Drive over different road surfaces to calibrate the sensor. Try to include both smooth roads and rough patches.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            Text(
              'Current Sensor Values',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildSensorValue('X', _accelerometerValues[0]),
                    _buildSensorValue('Y', _accelerometerValues[1]),
                    _buildSensorValue('Z', _accelerometerValues[2]),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Recorded Range',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildSensorValue('Min Z', _minZ),
                    _buildSensorValue('Max Z', _maxZ),
                    _buildSensorValue('Range', (_maxZ - _minZ).abs()),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Current Threshold',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Center(
                  child: Text(
                    _currentThreshold.toStringAsFixed(2),
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (_accelerometerHistory.isNotEmpty)
              SizedBox(
                height: 200,
                child: _buildAccelerometerGraph(),
              ),
          ],
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: _resetCalibration,
                child: const Text('Reset'),
              ),
              ElevatedButton(
                onPressed: _saveCalibration,
                child: const Text('Save Calibration'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSensorValue(String label, double value) {
    return Column(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          value.toStringAsFixed(2),
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ],
    );
  }

  Widget _buildAccelerometerGraph() {
    return CustomPaint(
      painter: AccelerometerGraphPainter(_accelerometerHistory),
      size: const Size(double.infinity, 200),
    );
  }
}

class AccelerometerGraphPainter extends CustomPainter {
  final List<List<double>> accelerometerHistory;

  AccelerometerGraphPainter(this.accelerometerHistory);

  @override
  void paint(Canvas canvas, Size size) {
    final Paint linePaint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final Paint gridPaint = Paint()
      ..color = Colors.grey.withOpacity(0.3)
      ..strokeWidth = 1.0;

    // Draw grid
    for (int i = 0; i < 5; i++) {
      double y = size.height / 4 * i;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Draw center line
    final Paint centerPaint = Paint()
      ..color = Colors.grey
      ..strokeWidth = 1.0;
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      centerPaint,
    );

    if (accelerometerHistory.isEmpty) return;

    // Find min and max values for scaling
    double minValue = -10;
    double maxValue = 10;

    // Create path for Z values
    final Path zPath = Path();

    // Start path at first point
    double xStep = size.width / (accelerometerHistory.length - 1);
    double x = 0;
    double y = size.height / 2 - (accelerometerHistory[0][2] / (maxValue - minValue)) * size.height / 2;
    zPath.moveTo(x, y);

    // Add points to path
    for (int i = 1; i < accelerometerHistory.length; i++) {
      x = i * xStep;
      y = size.height / 2 - (accelerometerHistory[i][2] / (maxValue - minValue)) * size.height / 2;
      zPath.lineTo(x, y);
    }

    // Draw Z path
    canvas.drawPath(zPath, linePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}