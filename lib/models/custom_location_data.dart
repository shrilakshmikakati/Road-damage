class CustomLocationData {
  final double latitude;
  final double longitude;
  final double? heading;
  final double? speed;
  final double? accuracy;
  final DateTime timestamp;

  CustomLocationData({
    required this.latitude,
    required this.longitude,
    this.heading,
    this.speed,
    this.accuracy,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'heading': heading,
      'speed': speed,
      'accuracy': accuracy,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory CustomLocationData.fromJson(Map<String, dynamic> json) {
    return CustomLocationData(
      latitude: json['latitude'],
      longitude: json['longitude'],
      heading: json['heading'],
      speed: json['speed'],
      accuracy: json['accuracy'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}