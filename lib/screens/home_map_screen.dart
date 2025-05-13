import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:provider/provider.dart';
import '../models/custom_location_data.dart';
import '../models/road_feature.dart';
import '../models/road_feature_type.dart';
import '../services/location_service.dart';
import '../utils/damage_detector.dart';
import '../provider/settings_provider.dart';
import '../widgets/feature_info_bottom_sheet.dart';
import '../models/road_feature_type.dart';
import '../services/auth_service.dart';
import 'settings_screen.dart';
import 'calibration_screen.dart';
import 'login_screen.dart';

class HomeMapScreen extends StatefulWidget {
  static const routeName = '/home';

  const HomeMapScreen({Key? key}) : super(key: key);

  @override
  _HomeMapScreenState createState() => _HomeMapScreenState();
}

class _HomeMapScreenState extends State<HomeMapScreen> {
  final Completer<GoogleMapController> _controller = Completer();
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  final List<LatLng> _routePoints = [];
  final DamageDetector _damageDetector = DamageDetector();

  LocationServiceImpl? _locationService;
  StreamSubscription<LocationData>? _locationSubscription;

  CameraPosition _initialCameraPosition = const CameraPosition(
    target: LatLng(0, 0),
    zoom: 15,
  );

  bool _isTracking = false;
  bool _isFirstLocationUpdate = true;
  bool _isMapCreated = false;
  bool _isLoading = true;

  // List to store detected road features
  final List<RoadFeature> _roadFeatures = [];

  @override
  void initState() {
    super.initState();
    _initializeLocationService();
  }

  Future<void> _initializeLocationService() async {
    setState(() {
      _isLoading = true;
    });

    _locationService = LocationServiceImpl();

    try {
      final initialLocation = await _locationService!.getLocation();

      setState(() {
        _initialCameraPosition = CameraPosition(
          target: LatLng(initialLocation.latitude, initialLocation.longitude),
          zoom: 15,
        );
        _isLoading = false;
      });

    } catch (e) {
      print('Error getting initial location: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _startTracking() {
    if (_locationService == null) return;

    setState(() {
      _isTracking = true;
      _routePoints.clear();
      _polylines.clear();
      _roadFeatures.clear();
      _markers.clear();
    });

    // Start listening to location updates
    _locationSubscription = _locationService!.onLocationChanged.listen(_onLocationChanged);

    // Initialize damage detector
    _damageDetector.initialize();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Tracking started')),
    );
  }

  void _stopTracking() {
    setState(() {
      _isTracking = false;
    });

    // Stop listening to location updates
    _locationSubscription?.cancel();

    // Stop damage detector
    _damageDetector.dispose();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Tracking stopped')),
    );

    // Save the collected data (could be implemented to save to Firebase)
    _saveCollectedData();
  }

  void _onLocationChanged(LocationData locationData) async {
    if (!_isMapCreated) return;

    final currentPosition = LatLng(
      locationData.latitude ?? 0,
      locationData.longitude ?? 0,
    );

    // Move camera to current position on first location update
    if (_isFirstLocationUpdate) {
      final GoogleMapController controller = await _controller.future;
      controller.animateCamera(CameraUpdate.newCameraPosition(
        CameraPosition(
          target: currentPosition,
          zoom: 17,
        ),
      ));
      _isFirstLocationUpdate = false;
    }

    // Add current position to route points
    setState(() {
      _routePoints.add(currentPosition);

      // Update polyline
      _polylines.clear();
      _polylines.add(Polyline(
        polylineId: const PolylineId('route'),
        points: _routePoints,
        color: Colors.blue,
        width: 5,
      ));

      // Add vehicle marker
      _markers.removeWhere((marker) => marker.markerId.value == 'vehicle');
      _markers.add(Marker(
        markerId: const MarkerId('vehicle'),
        position: currentPosition,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: const InfoWindow(title: 'Current Location'),
      ));
    });

    // Process sensor data for damage detection
    if (_isTracking) {
      final settings = Provider.of<SettingsProvider>(context, listen: false);
      final isDamageDetected = _damageDetector.processSensorData(
        locationData.speed ?? 0,
        settings.sensitivityThreshold,
      );

      if (isDamageDetected) {
        _addRoadFeature(
          currentPosition,
          RoadFeatureType.pothole,
          'Pothole detected',
          DateTime.now(),
        );
      }
    }
  }

  void _addRoadFeature(LatLng position, RoadFeatureType type, String description, DateTime timestamp) {
    // Create a new road feature
    final feature = RoadFeature(
      id: 'feature_${_roadFeatures.length}',
      position: position,
      type: type,
      description: description,
      timestamp: timestamp,
    );

    // Add to list of features
    setState(() {
      _roadFeatures.add(feature);

      // Add marker for the feature
      _markers.add(Marker(
        markerId: MarkerId(feature.id),
        position: position,
        icon: _getMarkerIcon(type),
        infoWindow: InfoWindow(
          title: type.toString().split('.').last,
          snippet: description,
        ),
        onTap: () => _showFeatureDetails(feature),
      ));
    });
  }

  BitmapDescriptor _getMarkerIcon(RoadFeatureType type) {
    switch (type) {
      case RoadFeatureType.pothole:
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
      case RoadFeatureType.bump:
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
      case RoadFeatureType.smoothRoad:
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
      default:
        return BitmapDescriptor.defaultMarker;
    }
  }

  void _showFeatureDetails(RoadFeature feature) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => FeatureInfoBottomSheet(feature: feature),
    );
  }

  Future<void> _saveCollectedData() async {
    // This could be implemented to save data to Firebase
    // For now, just show a message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Data saved locally')),
    );
  }

  Future<void> _signOut() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    await authService.signOut();
    Navigator.of(context).pushReplacementNamed(LoginScreen.routeName);
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _damageDetector.dispose();
    _locationService?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Road Damage Detection'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.of(context).pushNamed(SettingsScreen.routeName);
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : GoogleMap(
        mapType: MapType.normal,
        initialCameraPosition: _initialCameraPosition,
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
        markers: _markers,
        polylines: _polylines,
        onMapCreated: (GoogleMapController controller) {
          _controller.complete(controller);
          setState(() {
            _isMapCreated = true;
          });
        },
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'calibrate',
            onPressed: () {
              Navigator.of(context).pushNamed(CalibrationScreen.routeName);
            },
            child: const Icon(Icons.tune),
            tooltip: 'Calibrate',
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: 'track',
            onPressed: _isTracking ? _stopTracking : _startTracking,
            backgroundColor: _isTracking ? Colors.red : Colors.green,
            child: Icon(_isTracking ? Icons.stop : Icons.play_arrow),
            tooltip: _isTracking ? 'Stop Tracking' : 'Start Tracking',
          ),
        ],
      ),
    );
  }
}