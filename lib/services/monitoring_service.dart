import 'dart:async';
// Remove or comment out the unused import
// import 'package:location/location.dart';
import '../utils/damage_detector.dart';
import '../models/damage_severity.dart';

class MonitoringService {
  final DamageDetector _damageDetector = DamageDetector();
  bool _isMonitoring = false;

  // Stream controller to broadcast damage detection events
  final _damageStreamController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get damageStream => _damageStreamController.stream;

  // Start monitoring for road damage
  void startMonitoring(double sensitivityThreshold) {
    if (_isMonitoring) return;

    _isMonitoring = true;
    _damageDetector.initialize();

    // Note: In a real implementation, you would need to get speed data
    // from a location service or other source
  }

  // Process location update with speed data
  void processLocationUpdate(double speed, double sensitivityThreshold) {
    if (!_isMonitoring) return;

    // Use the detectDamage method (which now exists as an alias)
    final isDamageDetected = _damageDetector.detectDamage(
      speed,
      sensitivityThreshold,
    );

    if (isDamageDetected) {
      // Determine severity based on the intensity of the detection
      // This is a simplified example
      final severity = _calculateSeverity(speed);

      // Broadcast damage detection event
      _damageStreamController.add({
        'detected': true,
        'severity': severity,
        'speed': speed,
        'timestamp': DateTime.now(),
      });
    }
  }

  // Calculate damage severity based on speed and other factors
  DamageSeverity _calculateSeverity(double speed) {
    // Simple logic - could be more sophisticated in a real app
    if (speed < 20) {
      return DamageSeverity.low;
    } else if (speed < 40) {
      return DamageSeverity.medium;
    } else if (speed < 60) {
      return DamageSeverity.high;
    } else {
      return DamageSeverity.critical;
    }
  }

  // Stop monitoring
  void stopMonitoring() {
    if (!_isMonitoring) return;

    _isMonitoring = false;
    _damageDetector.dispose();
  }

  // Clean up resources
  void dispose() {
    stopMonitoring();
    _damageStreamController.close();
  }
}