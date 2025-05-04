// lib/screens/home_map_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import '../utils/damage_detector.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';

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
  Map<String, List<LatLng>> _roadSegments = {
    'damaged': [],
    'smooth': [],
  };

  // Damage detector reference
  final DamageDetector _damageDetector = DamageDetector();

  // Location service
  final Location _locationService = Location();
  LocationData? _currentLocation;

  // Tracking state
  bool _isTracking = false;
  bool _firstLocationUpdate = true;

  // Custom markers
  BitmapDescriptor? _damageMarkerIcon;
  BitmapDescriptor? _smoothMarkerIcon;

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
  }

  Future<void> _createMarkerIcons() async {
    // Create custom marker for damage
    final Uint8List damageMarkerIcon = await _getBytesFromCanvas(
        'D',
        Colors.red,
        Colors.white
    );
    _damageMarkerIcon = BitmapDescriptor.fromBytes(damageMarkerIcon);

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
            LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!)
        );
      }
    } catch (e) {
      print('Error getting location: $e');
    }

    // Listen for location changes
    _locationService.onLocationChanged.listen((LocationData newLocation) {
      setState(() {
        _currentLocation = newLocation;

        if (_firstLocationUpdate) {
          _updateCameraPosition(
              LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!)
          );
          _firstLocationUpdate = false;
        }

        // If tracking, update camera position to follow user
        if (_isTracking) {
          _updateCameraPosition(
              LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!)
          );
        }
      });
    });
  }

  void _updateCameraPosition(LatLng position) async {
    final GoogleMapController controller = await _controller.future;
    controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: position,
          zoom: 16.0,
        ),
      ),
    );
  }

  void _loadSavedRoadData() {
    final roadData = _damageDetector.getRoadData();

    for (var event in roadData) {
      _addRoadDamageEvent(event, updateState: false);
    }

    setState(() {});
  }

  void _onRoadDamageEvent(RoadDamageEvent event) {
    _addRoadDamageEvent(event);
  }

  void _addRoadDamageEvent(RoadDamageEvent event, {bool updateState = true}) {
    final latLng = LatLng(event.latitude, event.longitude);

    // Add to appropriate road segment
    if (event.isDamaged) {
      _roadSegments['damaged']!.add(latLng);
    } else {
      _roadSegments['smooth']!.add(latLng);
    }

    // Add marker
    final markerId = 'marker_${event.timestamp}';
    final marker = Marker(
      markerId: MarkerId(markerId),
      position: latLng,
      icon: event.isDamaged ? _damageMarkerIcon! : _smoothMarkerIcon!,
      infoWindow: InfoWindow(
        title: event.isDamaged ? 'Damaged Road' : 'Smooth Road',
        snippet: 'Severity: ${event.severity.toStringAsFixed(2)}',
      ),
    );

    // Update polylines
    _updatePolylines();

    if (updateState) {
      setState(() {
        _markers.add(marker);
      });
    } else {
      _markers.add(marker);
    }
  }

  void _updatePolylines() {
    _polylines.clear();

    // Add damaged road polyline if we have at least 2 points
    if (_roadSegments['damaged']!.length >= 2) {
      _polylines.add(
        Polyline(
          polylineId: PolylineId('damaged_roads'),
          points: _roadSegments['damaged']!,
          color: Colors.red,
          width: 5,
        ),
      );
    }

    // Add smooth road polyline if we have at least 2 points
    if (_roadSegments['smooth']!.length >= 2) {
      _polylines.add(
        Polyline(
          polylineId: PolylineId('smooth_roads'),
          points: _roadSegments['smooth']!,
          color: Colors.blue,
          width: 5,
        ),
      );
    }
  }

  void _toggleTracking() {
    setState(() {
      _isTracking = !_isTracking;

      if (_isTracking) {
        _damageDetector.startMonitoring();
        if (_currentLocation != null) {
          _updateCameraPosition(
              LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!)
          );
        }
      } else {
        _damageDetector.stopMonitoring();
      }
    });
  }

  @override
  void dispose() {
    _damageDetector.removeListener(_onRoadDamageEvent);
    _damageDetector.stopMonitoring();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Road Damage Detector'),
        actions: [
          IconButton(
            icon: Icon(Icons.delete),
            onPressed: () {
              _showClearDataDialog();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            mapType: MapType.normal,
            initialCameraPosition: _initialCameraPosition,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            markers: _markers,
            polylines: _polylines,
            onMapCreated: (GoogleMapController controller) {
              _controller.complete(controller);
            },
          ),
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Card(
              color: Colors.white.withOpacity(0.9),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.blue,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Red lines indicate damaged roads, blue lines indicate smooth roads.',
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'btn_my_location',
            onPressed: () {
              if (_currentLocation != null) {
                _updateCameraPosition(
                    LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!)
                );
              }
            },
            child: Icon(Icons.my_location),
            mini: true,
          ),
          SizedBox(height: 16),
          FloatingActionButton.extended(
            heroTag: 'btn_tracking',
            onPressed: _toggleTracking,
            label: Text(_isTracking ? 'Stop Tracking' : 'Start Tracking'),
            icon: Icon(_isTracking ? Icons.stop : Icons.play_arrow),
            backgroundColor: _isTracking ? Colors.red : Colors.green,
          ),
        ],
      ),
    );
  }

  void _showClearDataDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Clear Data'),
          content: Text('Are you sure you want to clear all saved road data?'),
          actions: [
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Clear', style: TextStyle(color: Colors.red)),
              onPressed: () async {
                await _damageDetector.clearData();
                setState(() {
                  _markers.clear();
                  _polylines.clear();
                  _roadSegments = {
                    'damaged': [],
                    'smooth': [],
                  };
                });
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('All data cleared'))
                );
              },
            ),
          ],
        );
      },
    );
  }
}