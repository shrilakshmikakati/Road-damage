import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import '../utils/damage_detector.dart';
import '../models/custom_location_data.dart';
import '../services/location_service.dart';
import '../services/damage_ai_service.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import '../models/road_feature_type.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';


class HomeMapScreen extends StatefulWidget {
  const HomeMapScreen({Key? key}) : super(key: key);

  static const routeName = '/home';

  @override
  _HomeMapScreenState createState() => _HomeMapScreenState();
}

class _HomeMapScreenState extends State<HomeMapScreen> {
  final Completer<GoogleMapController> _controller = Completer();

  CameraPosition _initialCameraPosition = const CameraPosition(
    target: LatLng(37.42796133580664, -122.085749655962),
    zoom: 14.0,
  );

  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  final Map<RoadFeatureType, List<LatLng>> _roadSegments = {
    RoadFeatureType.pothole: [],
    RoadFeatureType.roughPatch: [],
    RoadFeatureType.speedBreaker: [],
    RoadFeatureType.railwayCrossing: [],
    RoadFeatureType.smooth: [],
  };


  final List<LatLng> _userPath = [];

  late DamageDetector _damageDetector;
  final Location _locationService = Location();
  LocationData? _currentLocation;
  StreamSubscription<LocationData>? _locationSubscription;

  bool _isTracking = false;
  bool _firstLocationUpdate = true;
  bool _isAIMode = true;

  BitmapDescriptor? _potholeMarkerIcon;
  BitmapDescriptor? _speedBreakerMarkerIcon;
  BitmapDescriptor? _smoothMarkerIcon;
  BitmapDescriptor? _railwayCrossingMarkerIcon;
  BitmapDescriptor? _roughPatchMarkerIcon;

  final DatabaseReference _databaseRef =
  FirebaseDatabase.instance.ref('road_data');
  String? _userId;

  @override
  void initState() {
    super.initState();

    _damageDetector = DamageDetector(
        aiService: DamageAIService(),
        locationService: LocationServiceImpl()
    );
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    _userId = FirebaseAuth.instance.currentUser?.uid;
    await _createMarkerIcons();
    await _damageDetector.initialize();

    _damageDetector.addRoadFeatureEventListener((event) {
      _handleRoadFeatureEvent(event);
    });

    await _requestLocationPermission();
    await _getCurrentLocation();
    await _loadSavedRoadData();
    _isAIMode = _damageDetector.isAIEnabled;
  }

  Future<void> _requestLocationPermission() async {
    bool _serviceEnabled;
    PermissionStatus _permissionGranted;

    _serviceEnabled = await _locationService.serviceEnabled();
    if (!_serviceEnabled) {
      _serviceEnabled = await _locationService.requestService();
      if (!_serviceEnabled) {
        return;
      }
    }

    _permissionGranted = await _locationService.hasPermission();
    if (_permissionGranted == PermissionStatus.denied) {
      _permissionGranted = await _locationService.requestPermission();
      if (_permissionGranted != PermissionStatus.granted) {
        return;
      }
    }

    await _locationService.changeSettings(
      accuracy: LocationAccuracy.high,
      interval: 1000,
      distanceFilter: 5,
    );
  }

  void _handleRoadFeatureEvent(RoadFeatureEvent event) {
    if (!mounted) return;

    setState(() {
      _roadSegments[event.type]?.add(LatLng(event.latitude, event.longitude));
      _addMarker(event);
      _updatePolylines();
    });

    _saveRoadFeatureToFirebase(event);
  }

  Future<void> _createMarkerIcons() async {
    final Uint8List potholeMarkerIcon =
    await _getBytesFromCanvas('P', Colors.red, Colors.white);
    _potholeMarkerIcon = BitmapDescriptor.fromBytes(potholeMarkerIcon);

    final Uint8List speedBreakerMarkerIcon =
    await _getBytesFromCanvas('B', Colors.orange, Colors.white);
    _speedBreakerMarkerIcon = BitmapDescriptor.fromBytes(speedBreakerMarkerIcon);

    final Uint8List railwayCrossingMarkerIcon =
    await _getBytesFromCanvas('R', Colors.purple, Colors.white);
    _railwayCrossingMarkerIcon =
        BitmapDescriptor.fromBytes(railwayCrossingMarkerIcon);

    final Uint8List roughPatchMarkerIcon =
    await _getBytesFromCanvas('X', Colors.amber, Colors.white);
    _roughPatchMarkerIcon = BitmapDescriptor.fromBytes(roughPatchMarkerIcon);

    final Uint8List smoothMarkerIcon =
    await _getBytesFromCanvas('S', Colors.blue, Colors.white);
    _smoothMarkerIcon = BitmapDescriptor.fromBytes(smoothMarkerIcon);
  }

  Future<Uint8List> _getBytesFromCanvas(
      String text, Color backgroundColor, Color textColor) async {
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

    canvas.drawCircle(const Offset(24, 24), 24, paint);
    textPainter.paint(
        canvas, Offset(24 - textPainter.width / 2, 24 - textPainter.height / 2));

    final ui.Image image =
    await pictureRecorder.endRecording().toImage(48, 48);
    final ByteData? byteData =
    await image.toByteData(format: ui.ImageByteFormat.png);

    return byteData!.buffer.asUint8List();
  }

  Future<void> _getCurrentLocation() async {
    try {
      _currentLocation = await _locationService.getLocation();
      if (_currentLocation != null) {
        setState(() {
          _initialCameraPosition = CameraPosition(
            target: LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!),
            zoom: 17.0,
          );
        });
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
    }
  }

  void _relocateToCurrentPosition() async {
    if (_currentLocation != null) {
      _updateCameraPosition(
        LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!),
      );
    } else {
      await _getCurrentLocation();
    }
  }

  void _updateCameraPosition(LatLng position) async {
    try {
      final GoogleMapController controller = await _controller.future;
      CameraPosition newPosition = CameraPosition(
        target: position,
        zoom: 17.0,
        tilt: 45.0, // Add tilt for better navigation view
      );
      controller.animateCamera(CameraUpdate.newCameraPosition(newPosition));
    } catch (e) {
      debugPrint('Error updating camera position: $e');
    }
  }

  void _addMarker(RoadFeatureEvent event) {
    BitmapDescriptor? icon;

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

    final markerId =
    MarkerId("${event.type}_${DateTime.now().millisecondsSinceEpoch}");

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

    // Add user path polyline
    if (_userPath.length > 1) {
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('user_path'),
          color: Colors.green,
          width: 5,
          points: _userPath,
        ),
      );
    }

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
      final snapshot = await _databaseRef.child(_userId!).get();

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;

        setState(() {
          _markers.clear();
          _roadSegments.forEach((key, value) => value.clear());

          data.forEach((key, value) {
            final featureData = value as Map<dynamic, dynamic>;
            final featureType = _getFeatureTypeFromString(key);

            featureData.forEach((fKey, fValue) {
              final feature = fValue as Map<dynamic, dynamic>;
              final latitude = feature['latitude'] as double;
              final longitude = feature['longitude'] as double;
              final timestamp = feature['timestamp'] as int;

              final event = RoadFeatureEvent(
                type: featureType,
                latitude: latitude,
                longitude: longitude,
                timestamp: timestamp,
              );

              _roadSegments[featureType]?.add(LatLng(latitude, longitude));
              _addMarker(event);
            });
          });

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
        return RoadFeatureType.pothole;
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


    _locationSubscription?.cancel();


    _locationSubscription = _locationService.onLocationChanged.listen((LocationData locationData) {
      if (!mounted) return;

      setState(() {
        _currentLocation = locationData;


        if (locationData.latitude != null && locationData.longitude != null) {
          LatLng currentPosition = LatLng(locationData.latitude!, locationData.longitude!);


          _userPath.add(currentPosition);


          _damageDetector.setCurrentLocation(CustomLocationData(
            latitude: locationData.latitude!,
            longitude: locationData.longitude!,
            heading: locationData.heading,
            speed: locationData.speed,
            accuracy: locationData.accuracy,
          ));

          // Update polylines to show the path
          _updatePolylines();

          if (_firstLocationUpdate) {
            _updateCameraPosition(currentPosition);
            _firstLocationUpdate = false;
          }
        }
      });
    });
  }

  void _stopTracking() {
    _damageDetector.stopDetection();
    _locationSubscription?.cancel();
  }

  void _toggleAIMode() {
    setState(() {
      _isAIMode = !_isAIMode;
      _damageDetector.setAIMode(_isAIMode);
    });
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _damageDetector.dispose();
    super.dispose();
  }

  Widget _buildLegendPanel() {
    return Positioned(
      top: 10,
      left: 10,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Legend:',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            _legendItem('Potholes', Colors.red),
            _legendItem('Speed Breakers', Colors.orange),
            _legendItem('Rough Patches', Colors.amber),
            _legendItem('Railway Crossings', Colors.purple),
            _legendItem('Smooth Roads', Colors.blue),
            _legendItem('Your Path', Colors.green),
          ],
        ),
      ),
    );
  }

  Widget _legendItem(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 16,
            height: 3,
            color: color,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPanel() {
    return Positioned(
      bottom: 80,
      left: 10,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Markers: ${_markers.length}',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
            Text(
              'Path Points: ${_userPath.length}',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
            Text(
              'Tracking: ${_isTracking ? "ON" : "OFF"}',
              style: TextStyle(
                color: _isTracking ? Colors.green : Colors.red,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Road Damage Map'),
        actions: [
          IconButton(
            icon: Icon(
                _isAIMode ? Icons.auto_awesome : Icons.auto_awesome_outlined),
            tooltip: 'Toggle AI Mode',
            onPressed: _toggleAIMode,
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            mapType: MapType.normal,
            initialCameraPosition: _initialCameraPosition,
            onMapCreated: (GoogleMapController controller) {
              _controller.complete(controller);
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: false, // Disable default button
            markers: _markers,
            polylines: _polylines,
          ),
          _buildLegendPanel(),
          _buildStatusPanel(),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Container(
        margin: const EdgeInsets.only(bottom: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FloatingActionButton(
              heroTag: "relocateBtn",
              onPressed: _relocateToCurrentPosition,
              backgroundColor: Colors.blue,
              child: const Icon(Icons.my_location),
              mini: true,
            ),
            const SizedBox(width: 16),
            ElevatedButton.icon(
              onPressed: _toggleTracking,
              icon: Icon(_isTracking ? Icons.stop : Icons.play_arrow),
              label: Text(_isTracking ? 'Stop Tracking' : 'Start Tracking'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isTracking ? Colors.red : Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}