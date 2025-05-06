import 'package:location/location.dart';
import '../utils/damage_detector.dart';
import '../models/custom_location_data.dart';

class LocationServiceImpl implements LocationService {
  final Location _location = Location();

  @override
  Future<CustomLocationData> getLocation() async {
    try {
      LocationData locationData = await _location.getLocation();
      return CustomLocationData(
        latitude: locationData.latitude ?? 0.0,
        longitude: locationData.longitude ?? 0.0,
        heading: locationData.heading,
        speed: locationData.speed,
        accuracy: locationData.accuracy,
      );
    } catch (e) {
      return CustomLocationData(
        latitude: 0.0,
        longitude: 0.0,
      );
    }
  }
}