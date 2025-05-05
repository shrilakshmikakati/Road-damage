// lib/screens/home_map_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import '../utils/damage_detector.dart';
import '../services/damage_ai_service.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:provider/provider.dart';
import '../provider/settings_provider.dart';
import '../models/road_feature_type.dart'; // Import the enum from a separate file
import '../repositories/damage_repository.dart'; // Import for Firebase persistence
import 'package:firebase_auth/firebase_auth.dart'; // For user authentication
import 'package:firebase_database/firebase_database.dart'; // For realtime database

class HomeMapScreen extends StatefulWidget {
  const HomeMapScreen({Key? key}) : super(key: key);

  // Add static route name
  static const routeName = '/home';

  @override
  _HomeMapScreenState createState() => _HomeMapScreenState();
}

class _HomeMapScreenState extends State<HomeMapScreen> {
  // Google Maps controller
  final Completer<GoogleMapController> _controller = Completer();

  // Current camera position
  CameraPosition _initialCameraPosition = const CameraPosition(
    target: LatLng(37.42796133580664, -122.085749655962),
    zoom: 14.0,
  );

  // Markers and polylines
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  final Map<RoadFeatureType, List<LatLng>> _roadSegments = {
    RoadFeatureType.pothole: [],
    RoadFeatureType.roughPatch: [],
    RoadFeatureType.speedBreaker: [],
    RoadFeatureType.railwayCrossing: [],
    RoadFeatureType.smooth: [],
  };

  // Damage detector reference
  final DamageDetector _damageDetector = DamageDetector();

  // Repository for Firebase operations
  final DamageRepository _repository = DamageRepository();

  // Location service
  final Location _locationService = Location();
  LocationData? _currentLocation;

  // Tracking state
  bool _isTracking = false;
  bool _firstLocationUpdate = true;
  bool _isAIMode = true;

  // Custom markers
  BitmapDescriptor? _potholeMarkerIcon;
  BitmapDescriptor? _speedBreakerMarkerIcon;
  BitmapDescriptor? _smoothMarkerIcon;
  BitmapDescriptor? _railwayCrossingMarkerIcon;
  BitmapDescriptor? _roughPatchMarkerIcon;

  // Firebase reference
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref('road_data');
  String? _userId;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Get current user ID
    _userId = FirebaseAuth.instance.currentUser?.uid;

    // Create custom marker icons
    await _createMarkerIcons();

    // Initialize damage detector
    await _damageDetector.initialize();

    // Add listener for road damage events
    _damageDetector.addListener(_onRoadDamageEvent);

    // Get initial location
    await _getCurrentLocation();

    // Load saved road data
    _loadSavedRoadData();

    // Get AI mode status
    _isAIMode = _damageDetector.isAIEnabled;
  }

  Future<void> _createMarkerIcons() async {
    // Create custom marker for potholes
    final Uint8List potholeMarkerIcon = await _getBytesFromCanvas(
        'P',
        Colors.red,
        Colors.white
    );
    _potholeMarkerIcon = BitmapDescriptor.fromBytes(potholeMarkerIcon);

    // Create custom marker for speed breakers
    final Uint8List speedBreakerMarkerIcon = await _getBytesFromCanvas(
        'B',
        Colors.orange,
        Colors.white
    );
    _speedBreakerMarkerIcon = BitmapDescriptor.fromBytes(speedBreakerMarkerIcon);

    // Create custom marker for railway crossings
    final Uint8List railwayCrossingMarkerIcon = await _getBytesFromCanvas(
        'R',
        Colors.purple,
        Colors.white
    );
    _railwayCrossingMarkerIcon = BitmapDescriptor.fromBytes(railwayCrossingMarkerIcon);

    // Create custom marker for rough patches
    final Uint8List roughPatchMarkerIcon = await _getBytesFromCanvas(
        'X',
        Colors.amber,
        Colors.white
    );
    _roughPatchMarkerIcon = BitmapDescriptor.fromBytes(roughPatchMarkerIcon);

    // Create custom marker for smooth roads
    final Uint8List smoothMarkerIcon = await _getBytesFromCanvas(
        'S',
        Colors.blue,
        Colors.white
    );
    _smoothMarkerIcon = BitmapDescriptor.fromBytes(smoothMarkerIcon);
  }

  Future<Uint8List> _getBytesFromCanvas(String text, Color backgroundColor, Color textColor) async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    final Paint paint = Paint()..color = backgroundColor;
    final TextPainter textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: 30.0,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();

    // Draw circle background
    canvas.drawCircle(
        const Offset(24, 24),
        24,
        paint
    );

    // Draw text
    textPainter.paint(
        canvas,
        Offset(
            24 - textPainter.width / 2,
            24 - textPainter.height / 2
        )
    );

    final ui.Image image = await pictureRecorder.endRecording().toImage(48, 48);
    final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    return byteData!.buffer.asUint8List();
  }

  Future<void> _getCurrentLocation() async {
    try {
      _currentLocation = await _locationService.getLocation();
      if (_currentLocation != null) {
        _updateCameraPosition(
            LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!)
        );
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
    }
  }

  void _updateCameraPosition(LatLng position) async {
    final GoogleMapController controller = await _controller.future;
    CameraPosition newPosition = CameraPosition(
      target: position,
      zoom: 17.0,
    );
    controller.animateCamera(CameraUpdate.newCameraPosition(newPosition));
  }

  void _onRoadDamageEvent(RoadFeatureEvent event) {
    if (!mounted) return;

    setState(() {
      // Add to appropriate segment list
      _roadSegments[event.type]?.add(LatLng(event.latitude, event.longitude));

      // Add marker
      _addMarker(event);

      // Update polylines
      _updatePolylines();
    });

    // Save to Firebase
    _saveRoadFeatureToFirebase(event);
  }

  void _addMarker(RoadFeatureEvent event) {
    BitmapDescriptor? icon;

    // Select appropriate icon
    switch (event.type) {
      case RoadFeatureType.pothole:
        icon = _potholeMarkerIcon;
        break;
      case RoadFeatureType.roughPatch:
        icon = _roughPatchMarkerIcon;
        break;
      case RoadFeatureType.speedBreaker:
        icon = _speedBreakerMarkerIcon;
        break;
      case RoadFeatureType.railwayCrossing:
        icon = _railwayCrossingMarkerIcon;
        break;
      case RoadFeatureType.smooth:
        icon = _smoothMarkerIcon;
        break;
    }

    final markerId = MarkerId("${event.type}_${DateTime.now().millisecondsSinceEpoch}");

    final marker = Marker(
      markerId: markerId,
      position: LatLng(event.latitude, event.longitude),
      icon: icon ?? BitmapDescriptor.defaultMarker,
      infoWindow: InfoWindow(
        title: _getFeatureTypeName(event.type),
        snippet: 'Detected on ${DateTime.now().toString()}',
      ),
    );

    _markers.add(marker);
  }

  void _updatePolylines() {
    _polylines.clear();

    // Add polylines for each road feature type with different colors
    if (_roadSegments[RoadFeatureType.pothole]!.isNotEmpty) {
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('potholes'),
          color: Colors.red,
          width: 5,
          points: _roadSegments[RoadFeatureType.pothole]!,
        ),
      );
    }

    if (_roadSegments[RoadFeatureType.roughPatch]!.isNotEmpty) {
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('rough_patches'),
          color: Colors.amber,
          width: 5,
          points: _roadSegments[RoadFeatureType.roughPatch]!,
        ),
      );
    }

    if (_roadSegments[RoadFeatureType.speedBreaker]!.isNotEmpty) {
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('speed_breakers'),
          color: Colors.orange,
          width: 5,
          points: _roadSegments[RoadFeatureType.speedBreaker]!,
        ),
      );
    }

    if (_roadSegments[RoadFeatureType.railwayCrossing]!.isNotEmpty) {
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('railway_crossings'),
          color: Colors.purple,
          width: 5,
          points: _roadSegments[RoadFeatureType.railwayCrossing]!,
        ),
      );
    }

    if (_roadSegments[RoadFeatureType.smooth]!.isNotEmpty) {
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('smooth_roads'),
          color: Colors.blue,
          width: 5,
          points: _roadSegments[RoadFeatureType.smooth]!,
        ),
      );
    }
  }

  Future<void> _loadSavedRoadData() async {
    if (_userId == null) return;

    try {
      // Get data from Firebase
      final snapshot = await _databaseRef.child(_userId!).get();

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;

        setState(() {
          // Clear existing data
          _markers.clear();
          _roadSegments.forEach((key, value) => value.clear());

          // Load data for each feature type
          data.forEach((key, value) {
            final featureData = value as Map<dynamic, dynamic>;
            final featureType = _getFeatureTypeFromString(key);

            featureData.forEach((fKey, fValue) {
              final feature = fValue as Map<dynamic, dynamic>;
              final latitude = feature['latitude'] as double;
              final longitude = feature['longitude'] as double;
              final timestamp = feature['timestamp'] as int;

              // Create event and add to map
              final event = RoadFeatureEvent(
                type: featureType,
                latitude: latitude,
                longitude: longitude,
                timestamp: timestamp,
              );

              // Add to appropriate segment list
              _roadSegments[featureType]?.add(LatLng(latitude, longitude));

              // Add marker
              _addMarker(event);
            });
          });

          // Update polylines
          _updatePolylines();
        });
      }
    } catch (e) {
      debugPrint('Error loading road data: $e');
    }
  }

  String _getFeatureTypeName(RoadFeatureType type) {
    switch (type) {
      case RoadFeatureType.pothole:
        return 'Pothole';
      case RoadFeatureType.roughPatch:
        return 'Rough Patch';
      case RoadFeatureType.speedBreaker:
        return 'Speed Breaker';
      case RoadFeatureType.railwayCrossing:
        return 'Railway Crossing';
      case RoadFeatureType.smooth:
        return 'Smooth Road';
      default:
        return 'Unknown';
    }
  }

  RoadFeatureType _getFeatureTypeFromString(String typeString) {
    switch (typeString) {
      case 'pothole':
        return RoadFeatureType.pothole;
      case 'roughPatch':
        return RoadFeatureType.roughPatch;
      case 'speedBreaker':
        return RoadFeatureType.speedBreaker;
      case 'railwayCrossing':
        return RoadFeatureType.railwayCrossing;
      case 'smooth':
        return RoadFeatureType.smooth;
      default:
        return RoadFeatureType.pothole; // Default
    }
  }

  Future<void> _saveRoadFeatureToFirebase(RoadFeatureEvent event) async {
    if (_userId == null) return;

    try {
      final featureTypeString = event.type.toString().split('.').last;
      final featureId = DateTime.now().millisecondsSinceEpoch.toString();

      await _databaseRef
          .child(_userId!)
          .child(featureTypeString)
          .child(featureId)
          .set({
        'latitude': event.latitude,
        'longitude': event.longitude,
        'timestamp': event.timestamp,
      });
    } catch (e) {
      debugPrint('Error saving road feature: $e');
    }
  }

  void _toggleTracking() {
    setState(() {
      _isTracking = !_isTracking;
    });

    if (_isTracking) {
      _startTracking();
    } else {
      _stopTracking();
    }
  }

  void _startTracking() {
    _damageDetector.startDetection();
    _locationService.onLocationChanged.listen((LocationData locationData) {
      setState(() {
        _currentLocation = locationData;

        if (_firstLocationUpdate) {
          _updateCameraPosition(
            LatLng(locationData.latitude!, locationData.longitude!),
          );
          _firstLocationUpdate = false;
        }
      });
    });
  }

  void _stopTracking() {
    _damageDetector.stopDetection();
  }

  void _toggleAIMode() {
    setState(() {
      _isAIMode = !_isAIMode;
      _damageDetector.setAIMode(_isAIMode);
    });
  }

  @override
  void dispose() {
    _damageDetector.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Road Damage Map'),
        actions: [
          IconButton(
            icon: Icon(_isAIMode ? Icons.auto_awesome : Icons.auto_awesome_outlined),
            tooltip: 'Toggle AI Mode',
            onPressed: _toggleAIMode,
          ),
        ],
      ),
      body: GoogleMap(
        mapType: MapType.normal,
        initialCameraPosition: _initialCameraPosition,
        onMapCreated: (GoogleMapController controller) {
          _controller.complete(controller);
        },
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
        markers: _markers,
        polylines: _polylines,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _toggleTracking,
        label: Text(_isTracking ? 'Stop Tracking' : 'Start Tracking'),
        icon: Icon(_isTracking ? Icons.pause : Icons.play_arrow),
      ),
    );
  }
}

// Model class for road feature events
class RoadFeatureEvent {
  final RoadFeatureType type;
  final double latitude;
  final double longitude;
  final int timestamp;

  RoadFeatureEvent({
    required this.type,
    required this.latitude,
    required this.longitude,
    this.timestamp = 0,
  });
}