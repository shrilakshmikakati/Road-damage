import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/road_damage.dart';
import '../models/damage_severity.dart';

class MapService {
  // Convert road damage to map marker
  Marker createDamageMarker(RoadDamage damage) {
    // Determine marker color based on damage type and severity
    BitmapDescriptor markerIcon;

    switch (damage.severity) {
      case DamageSeverity.critical:
        markerIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet);
        break;
      case DamageSeverity.high:
        markerIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
        break;
      case DamageSeverity.medium:
        markerIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
        break;
      case DamageSeverity.low:
        markerIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow);
        break;
    }

    return Marker(
      markerId: MarkerId(damage.id),
      position: LatLng(damage.location.latitude, damage.location.longitude),
      icon: markerIcon,
      infoWindow: InfoWindow(
        title: '${damage.damageType.toString().split('.').last} - ${damage.severity.toString().split('.').last}',
        snippet: 'Detected on ${damage.timestamp.toString().split('.')[0]}',
      ),
    );
  }

  // Create a smooth road marker (for comparison)
  Marker createSmoothRoadMarker(String id, double latitude, double longitude) {
    return Marker(
      markerId: MarkerId('smooth_$id'),
      position: LatLng(latitude, longitude),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      infoWindow: InfoWindow(
        title: 'Smooth Road',
        snippet: 'No damage detected',
      ),
    );
  }

  // Generate a set of markers from a list of road damages
  Set<Marker> generateMarkers(List<RoadDamage> damages) {
    return damages.map((damage) => createDamageMarker(damage)).toSet();
  }
}