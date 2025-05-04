// lib/utils/damage_detector.dart
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';

class DamageResult {
  final bool isDamaged;
  final double severity;
  final double confidence;

  DamageResult({
    required this.isDamaged,
    required this.severity,
    required this.confidence,
  });
}

class DamageDetector {
  // Constants for detection tuning
  static const int _windowSize = 20; // Number of readings to analyze
  static const double _zAxisImpactWeight = 1.5; // Z-axis gets more weight (vertical movement)
  static const double _minConfidenceThreshold = 0.7; // Min confidence for detection

  // Accelerometer readings history
  final List<AccelerometerEvent> _accelHistory = [];
  final List<GyroscopeEvent> _gyroHistory = [];

  // Calculated baselines (device at rest values)
  double _accelBaselineX = 0.0;
  double _accelBaselineY = 0.0;
  double _accelBaselineZ = 9.8; // Default earth gravity
  double _gyroBaselineX = 0.0;
  double _gyroBaselineY = 0.0;
  double _gyroBaselineZ = 0.0;

  // Detection state
  bool _isCalibrated = false;
  double _lastPeakMagnitude = 0.0;

  // Add a new accelerometer reading
  void addAccelerometerReading(AccelerometerEvent event) {
    _accelHistory.add(event);
    if (_accelHistory.length > _windowSize) {
      _accelHistory.removeAt(0);
    }

    // Recalibrate if we have enough readings
    if (_accelHistory.length >= _windowSize && !_isCalibrated) {
      _calibrateBaselines();
    }
  }

  // Add a new gyroscope reading
  void addGyroscopeReading(GyroscopeEvent event) {
    _gyroHistory.add(event);
    if (_gyroHistory.length > _windowSize) {
      _gyroHistory.removeAt(0);
    }
  }

  // Calculate baseline values (sensor readings when device is relatively steady)
  void _calibrateBaselines() {
    if (_accelHistory.length < _windowSize || _gyroHistory.length < _windowSize) {
      return;
    }

    // Calculate variance to see if device is steady enough for calibration
    double varianceSum = _calculateAccelVariance();

    // Only calibrate if variance is low (device is relatively still)
    if (varianceSum < 2.0) {
      double sumX = 0, sumY = 0, sumZ = 0;
      double gyroSumX = 0, gyroSumY = 0, gyroSumZ = 0;

      // Calculate averages
      for (var reading in _accelHistory) {
        sumX += reading.x;
        sumY += reading.y;
        sumZ += reading.z;
      }

      for (var reading in _gyroHistory) {
        gyroSumX += reading.x;
        gyroSumY += reading.y;
        gyroSumZ += reading.z;
      }

      // Update baselines
      _accelBaselineX = sumX / _accelHistory.length;
      _accelBaselineY = sumY / _accelHistory.length;
      _accelBaselineZ = sumZ / _accelHistory.length;

      _gyroBaselineX = gyroSumX / _gyroHistory.length;
      _gyroBaselineY = gyroSumY / _gyroHistory.length;
      _gyroBaselineZ = gyroSumZ / _gyroHistory.length;

      _isCalibrated = true;
    }
  }

  // Calculate the variance of accelerometer readings (to check if device is steady)
  double _calculateAccelVariance() {
    if (_accelHistory.length < 3) return double.infinity;

    // Calculate mean
    double meanX = 0, meanY = 0, meanZ = 0;
    for (var reading in _accelHistory) {
      meanX += reading.x;
      meanY += reading.y;
      meanZ += reading.z;
    }
    meanX /= _accelHistory.length;
    meanY /= _accelHistory.length;
    meanZ /= _accelHistory.length;

    // Calculate variance
    double varX = 0, varY = 0, varZ = 0;
    for (var reading in _accelHistory) {
      varX += pow(reading.x - meanX, 2);
      varY += pow(reading.y - meanY, 2);
      varZ += pow(reading.z - meanZ, 2);
    }
    varX /= _accelHistory.length;
    varY /= _accelHistory.length;
    varZ /= _accelHistory.length;

    return varX + varY + varZ;
  }

  // Check if current readings indicate a road damage
  DamageResult checkForDamage(double threshold) {
    if (!_isCalibrated || _accelHistory.length < _windowSize || _gyroHistory.length < _windowSize) {
      return DamageResult(isDamaged: false, severity: 0.0, confidence: 0.0);
    }

    // Get the latest readings
    AccelerometerEvent latestAccel = _accelHistory.last;
    GyroscopeEvent latestGyro = _gyroHistory.last;

    // Calculate deviation from baseline
    double accelDevX = (latestAccel.x - _accelBaselineX).abs();
    double accelDevY = (latestAccel.y - _accelBaselineY).abs();
    double accelDevZ = (latestAccel.z - _accelBaselineZ).abs() * _zAxisImpactWeight; // Z-axis weighted more

    double gyroDevX = (latestGyro.x - _gyroBaselineX).abs();
    double gyroDevY = (latestGyro.y - _gyroBaselineY).abs();
    double gyroDevZ = (latestGyro.z - _gyroBaselineZ).abs();

    // Calculate composite severity
    // We combine accelerometer and gyroscope data for better accuracy
    double accelMagnitude = sqrt(accelDevX * accelDevX + accelDevY * accelDevY + accelDevZ * accelDevZ);
    double gyroMagnitude = sqrt(gyroDevX * gyroDevX + gyroDevY * gyroDevY + gyroDevZ * gyroDevZ);

    // Detect peaks in the signal
    double compositeMagnitude = (accelMagnitude * 0.6 + gyroMagnitude * 0.4);

    // Update peak if current magnitude is higher
    if (compositeMagnitude > _lastPeakMagnitude) {
      _lastPeakMagnitude = compositeMagnitude;
    } else {
      // Decay the peak over time to reset after a while
      _lastPeakMagnitude *= 0.95;
    }

    // Calculate confidence based on signal-to-noise ratio
    double noiseLevel = _calculateNoiseLevel();
    double signalToNoise = noiseLevel > 0 ? compositeMagnitude / noiseLevel : 0;
    double confidence = min(signalToNoise / 5.0, 1.0); // Cap at 1.0

    // Determine if this is a damage event
    bool isDamaged = compositeMagnitude > threshold && confidence > _minConfidenceThreshold;

    return DamageResult(
      isDamaged: isDamaged,
      severity: compositeMagnitude,
      confidence: confidence,
    );
  }

  // Calculate noise level from recent readings
  double _calculateNoiseLevel() {
    if (_accelHistory.length < 5) return 1.0; // Default if not enough data

    // Use the standard deviation of recent readings as noise estimate
    List<double> magnitudes = [];
    for (int i = max(0, _accelHistory.length - 5); i < _accelHistory.length; i++) {
      AccelerometerEvent event = _accelHistory[i];
      double devX = (event.x - _accelBaselineX).abs();
      double devY = (event.y - _accelBaselineY).abs();
      double devZ = (event.z - _accelBaselineZ).abs();
      magnitudes.add(sqrt(devX * devX + devY * devY + devZ * devZ));
    }

    // Calculate standard deviation
    double mean = magnitudes.reduce((a, b) => a + b) / magnitudes.length;
    double variance = magnitudes.fold(0.0, (sum, val) => sum + pow(val - mean, 2)) / magnitudes.length;
    return sqrt(variance) + 0.1; // Add small constant to avoid division by zero
  }

  // Force recalibration (e.g., on user request)
  void recalibrate() {
    _isCalibrated = false;
    _lastPeakMagnitude = 0.0;
  }
}