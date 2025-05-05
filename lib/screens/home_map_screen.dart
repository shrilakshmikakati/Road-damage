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

class HomeMapScreen extends StatefulWidget {
  const HomeMapScreen({Key? key}) : super(key: key);

  // Add static route name
  static const routeName = '/home';

  @override
  _HomeMapScreenState createState() => _HomeMapScreenState();
}

class _HomeMapScreenState extends State<HomeMapScreen> {
  // Google Maps controller
  Completer<GoogleMapController> _controller = Completer();

  // Current camera position
  CameraPosition _initialCameraPosition = CameraPosition(
    target: LatLng(37.42796133580664, -122.085749655962),
    zoom: 14.0,
  );

  // Markers and polylines
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  Map<RoadFeatureType, List<LatLng>> _roadSegments = {
    RoadFeatureType.pothole: [],
    RoadFeatureType.roughPatch: [],
    RoadFeatureType.speedBreaker: [],
    RoadFeatureType.railwayCrossing: [],
    RoadFeatureType.smooth: [],
  };

  // Damage detector reference
  final DamageDetector _damageDetector = DamageDetector();

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

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
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
        Offset(24, 24),
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
            LatLng(_currentLocation!.