import 'package:flutter/material.dart'; // Add this import at the top of the file

enum DamageSeverity {
  low,
  medium,
  high,
  critical
}

extension DamageSeverityExtension on DamageSeverity {
  String get displayName {
    switch (this) {
      case DamageSeverity.low:
        return 'Low';
      case DamageSeverity.medium:
        return 'Medium';
      case DamageSeverity.high:
        return 'High';
      case DamageSeverity.critical:
        return 'Critical';
    }
  }

  int get value {
    switch (this) {
      case DamageSeverity.low:
        return 1;
      case DamageSeverity.medium:
        return 2;
      case DamageSeverity.high:
        return 3;
      case DamageSeverity.critical:
        return 4;
    }
  }

  Color get color {
    switch (this) {
      case DamageSeverity.low:
        return Colors.green;
      case DamageSeverity.medium:
        return Colors.yellow;
      case DamageSeverity.high:
        return Colors.orange;
      case DamageSeverity.critical:
        return Colors.red;
    }
  }
}