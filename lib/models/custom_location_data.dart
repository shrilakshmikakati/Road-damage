// lib/models/custom_location_data.dart
class CustomLocationData {
  final double latitude;
  final double longitude;
  final double? heading;
  final double? speed;
  final double? accuracy;

  CustomLocationData({
    required this.latitude,
    required this.longitude,
    this.heading,
    this.speed,
    this.accuracy,
  });
}