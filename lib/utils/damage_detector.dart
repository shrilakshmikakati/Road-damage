import 'dart:async';
import 'package:sensors_plus/sensors_plus.dart';

class DamageDetector {
  // Accelerometer data stream
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;

  // Buffer to store recent accelerometer readings
  final List<AccelerometerEvent> _accelerometerBuffer = [];

  // Maximum buffer size
  final int _maxBufferSize = 50;

  // Initialize the detector
  void initialize() {
    // Clear any existing data
    _accelerometerBuffer.clear();

    // Start listening to accelerometer events
    _accelerometerSubscription = accelerometerEvents.listen((AccelerometerEvent event) {
      _accelerometerBuffer.add(event);

      // Keep buffer size limited
      if (_accelerometerBuffer.length > _maxBufferSize) {
        _accelerometerBuffer.removeAt(0);
      }
    });
  }

  // Process sensor data to detect road damage
  bool processSensorData(double speed, double sensitivityThreshold) {
    // Skip processing if we don't have enough data or vehicle is not moving
    if (_accelerometerBuffer.length < 10 || speed < 5.0) {
      return false;
    }

    // Calculate vertical acceleration variance
    double sum = 0;
    double sumSquared = 0;

    for (var event in _accelerometerBuffer) {
      sum += event.z;
      sumSquared += event.z * event.z;
    }

    double mean = sum / _accelerometerBuffer.length;
    double variance = (sumSquared / _accelerometerBuffer.length) - (mean * mean);

    // Adjust threshold based on speed and sensitivity setting
    double adjustedThreshold = sensitivityThreshold * (1 + (speed / 50));

    // Detect if variance exceeds threshold
    return variance > adjustedThreshold;
  }

  // Add this method to support the monitoring service
  bool detectDamage(double speed, double sensitivityThreshold) {
    // This is just an alias for processSensorData to maintain compatibility
    return processSensorData(speed, sensitivityThreshold);
  }

  // Clean up resources
  void dispose() {
    _accelerometerSubscription?.cancel();
    _accelerometerBuffer.clear();
  }
}