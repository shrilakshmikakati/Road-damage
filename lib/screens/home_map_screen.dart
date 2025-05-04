// lib/screens/home_map_screen.dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:provider/provider.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'dart:async';
import 'dart:math';
import 'package:flutter/services.dart';
import '../provider/settings_provider.dart';
import '../models/damage_record.dart';
import '../repositories/damage_repository.dart';
import '../widgets/status_card.dart';
import '../utils/damage_detector.dart';
import 'calibration_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';

class HomeMapScreen extends StatefulWidget {
  const HomeMapScreen({Key? key}) : super(key: key);
  static const routeName = '/home';
  @override
  _HomeMapScreenState createState() => _HomeMapScreenState();
}

class _HomeMapScreenState extends State<HomeMapScreen> with WidgetsBindingObserver {
  GoogleMapController? _mapController;
  final Location _location = Location();
  final DamageRepository _repository = DamageRepository();
  final DamageDetector _damageDetector = DamageDetector();

  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<GyroscopeEvent>? _gyroSub;
  StreamSubscription<LocationData>? _locationSub;

  bool _isDamaged = false;
  double _currentSeverity = 0.0;
  Set<Marker> _markers = {};
  LatLng _currentPosition = LatLng(37.7749, -122.4194); // Default position

  // For polyline rendering
  Map<String, List<LatLng>> _routeSegments = {};
  Set<Polyline> _polylines = {};
  String _currentSegmentId = DateTime.now().millisecondsSinceEpoch.toString();

  // For UI updates
  bool _isMapReady = false;
  bool _isFollowingUser = true;
  int _detectedDamageCount = 0;
  double _distanceTraveled = 0;
  DateTime? _lastRecordTime;
  LatLng? _lastPosition;

  // For damage detection
  final List<double> _recentAccelReadings = [];
  final int _maxReadingsHistory = 100;
  double _baselineNoise = 0.5;
  Timer? _cooldownTimer;
  bool _inCooldown = false;

  // Map style
  String _mapStyle = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadMapStyles();
    _loadSavedMarkers();
    _initLocation();

    // Start services after a short delay to ensure everything is initialized
    Future.delayed(Duration(milliseconds: 500), () {
      _startServices();
    });
  }

  Future<void> _loadMapStyles() async {
    // Load the map style for night mode
    _mapStyle = await rootBundle.loadString('assets/map_styles/night_mode.json');
  }

  Future<void> _loadSavedMarkers() async {
    final records = await _repository.getRecords();

    if (mounted) {
      setState(() {
        _markers = records.map((record) =>
            Marker(
              markerId: MarkerId(record.id),
              position: record.position,
              icon: BitmapDescriptor.defaultMarkerWithHue(
                record.isDamaged ? BitmapDescriptor.hueRed : BitmapDescriptor.hueBlue,
              ),
              infoWindow: InfoWindow(
                title: record.isDamaged ? 'Damaged Road' : 'Good Road',
                snippet: 'Date: ${_formatDateTime(record.timestamp)} - Severity: ${record.severity.toStringAsFixed(1)}',
              ),
            )
        ).toSet();
      });
    }
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.month}/${dt.day} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }

  void _initLocation() {
    _location.changeSettings(
      accuracy: LocationAccuracy.high,
      interval: 1000,
      distanceFilter: 5, // Update only when moved 5 meters
    );
  }

  void _startServices() {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    if (settings.recordingActive) {
      _startRecording();
    }
  }

  void _startRecording() {
    // Reset counters
    _detectedDamageCount = 0;
    _distanceTraveled = 0;
    _lastPosition = null;
    _currentSegmentId = DateTime.now().millisecondsSinceEpoch.toString();
    _routeSegments[_currentSegmentId] = [];

    // Show toast
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Recording started'),
          duration: Duration(seconds: 2),
        )
    );

    // Start location tracking
    _locationSub = _location.onLocationChanged.listen((loc) {
      if (loc.latitude == null || loc.longitude == null) return;

      final newPos = LatLng(loc.latitude!, loc.longitude!);

      // Calculate distance if we have a previous position
      if (_lastPosition != null) {
        final distance = _calculateDistance(_lastPosition!, newPos);
        _distanceTraveled += distance;
      }

      _lastPosition = newPos;

      if (mounted) {
        setState(() {
          _currentPosition = newPos;
          if (_routeSegments.containsKey(_currentSegmentId)) {
            _routeSegments[_currentSegmentId]!.add(newPos);
          }
        });
      }

      // Update camera position if following is enabled
      if (_isMapReady && _mapController != null && _isFollowingUser) {
        _mapController!.animateCamera(CameraUpdate.newLatLng(newPos));
      }

      // Update polylines
      _updatePolylines();
    });

    // Start accelerometer listening
    _accelSub = accelerometerEvents.listen((e) {
      // Calculate the magnitude of acceleration
      final magnitude = sqrt(e.x * e.x + e.y * e.y + e.z * e.z);

      // Add to readings history
      _recentAccelReadings.add(magnitude);
      if (_recentAccelReadings.length > _maxReadingsHistory) {
        _recentAccelReadings.removeAt(0);
      }

      // Calculate baseline (average) if we have enough readings
      if (_recentAccelReadings.length >= 20) {
        _baselineNoise = _calculateBaseline();
      }
    });

    // Start gyroscope listening
    final threshold = Provider.of<SettingsProvider>(context, listen: false).threshold;
    _gyroSub = gyroscopeEvents.listen((e) {
      // Calculate rotational magnitude and adjust for baseline noise
      final mag = (e.x.abs() + e.y.abs() + e.z.abs()) - _baselineNoise;
      final adjustedMag = max(0.0, mag); // Don't allow negative values

      if (mounted) {
        setState(() {
          _currentSeverity = adjustedMag;
          _isDamaged = adjustedMag > threshold && !_inCooldown;
        });
      }

      // If we have a damage spike and not in cooldown, record it
      if (_isDamaged && !_inCooldown) {
        _recordDamage(_currentPosition, adjustedMag);

        // Start cooldown timer to prevent repeated recordings at same location
        _startCooldown();
      }
    });
  }

  double _calculateBaseline() {
    // Get the average of the middle 60% of readings (removing extremes)
    List<double> sortedReadings = List.from(_recentAccelReadings)..sort();
    int startIdx = (_recentAccelReadings.length * 0.2).round();
    int endIdx = (_recentAccelReadings.length * 0.8).round();

    double sum = 0;
    for (int i = startIdx; i < endIdx; i++) {
      sum += sortedReadings[i];
    }

    return sum / (endIdx - startIdx);
  }

  void _startCooldown() {
    _inCooldown = true;
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer(const Duration(seconds: 3), () {
      _inCooldown = false;
    });
  }

  double _calculateDistance(LatLng start, LatLng end) {
    // Using Haversine formula to calculate distance
    const int earthRadius = 6371000; // in meters
    double lat1 = start.latitude * pi / 180;
    double lat2 = end.latitude * pi / 180;
    double lon1 = start.longitude * pi / 180;
    double lon2 = end.longitude * pi / 180;

    double dLat = lat2 - lat1;
    double dLon = lon2 - lon1;

    double a = sin(dLat/2) * sin(dLat/2) +
        cos(lat1) * cos(lat2) *
            sin(dLon/2) * sin(dLon/2);
    double c = 2 * atan2(sqrt(a), sqrt(1-a));

    return earthRadius * c; // in meters
  }

  void _stopRecording() {
    _locationSub?.cancel();
    _accelSub?.cancel();
    _gyroSub?.cancel();
    _locationSub = null;
    _accelSub = null;
    _gyroSub = null;

    // Show toast
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Recording stopped'),
          duration: Duration(seconds: 2),
        )
    );
  }

  void _updatePolylines() {
    // Skip if not enough points
    if (_routeSegments.isEmpty) return;

    Set<Polyline> newPolylines = {};

    _routeSegments.forEach((id, points) {
      if (points.length >= 2) {
        newPolylines.add(
          Polyline(
            polylineId: PolylineId(id),
            points: points,
            color: _isDamaged ? Colors.red : Colors.blue,
            width: 4,
          ),
        );
      }
    });

    if (mounted) {
      setState(() {
        _polylines = newPolylines;
      });
    }
  }

  void _recordDamage(LatLng pos, double severity) {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final record = DamageRecord(
      id: id,
      position: pos,
      timestamp: DateTime.now(),
      severity: severity,
      isDamaged: true,
    );

    // Save to repository
    _repository.addRecord(record);

    // Increment counter
    setState(() {
      _detectedDamageCount++;
      _lastRecordTime = DateTime.now();
    });

    // Add to map
    setState(() {
      _markers.add(
        Marker(
          markerId: MarkerId(id),
          position: pos,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(
            title: 'Damaged Road',
            snippet: 'Severity: ${severity.toStringAsFixed(1)}',
          ),
        ),
      );
    });

    // Vibrate to give feedback
    HapticFeedback.mediumImpact();

    // Start a new polyline segment for color distinction
    _currentSegmentId = DateTime.now().millisecondsSinceEpoch.toString();
    _routeSegments[_currentSegmentId] = [pos];
  }

  void _toggleRecording() {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    settings.toggleRecording(!settings.recordingActive);

    if (settings.recordingActive) {
      _startRecording();
    } else {
      _stopRecording();
    }
  }

  void _toggleFollowUser() {
    setState(() {
      _isFollowingUser = !_isFollowingUser;

      if (_isFollowingUser && _mapController != null) {
        _mapController!.animateCamera(CameraUpdate.newLatLng(_currentPosition));
      }
    });
  }

  void _clearMap() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Clear Map'),
        content: Text('This will clear all current route lines but keep saved damage records. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('CANCEL'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _polylines.clear();
                _routeSegments.clear();
                _currentSegmentId = DateTime.now().millisecondsSinceEpoch.toString();
                _routeSegments[_currentSegmentId] = [];
              });
              Navigator.of(ctx).pop();
            },
            child: Text('CLEAR'),
          ),
        ],
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Handle app lifecycle changes
    if (state == AppLifecycleState.paused) {
      // App is in background, consider saving state
      final settings = Provider.of<SettingsProvider>(context, listen: false);
      if (settings.recordingActive) {
        // Optionally stop recording when app is in background
        // _stopRecording();
      }
    } else if (state == AppLifecycleState.resumed) {
      // App is in foreground again
      if (_mapController != null) {
        _applyMapStyle();
      }
    }
  }

  void _applyMapStyle() {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    if (settings.darkMode && _mapController != null) {
      _mapController!.setMapStyle(_mapStyle);
    } else if (_mapController != null) {
      _mapController!.setMapStyle(null); // Reset to default style
    }
  }

  @override
  void dispose() {
    _stopRecording();
    _mapController?.dispose();
    _cooldownTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      appBar: AppBar(
        title: Text('Road Damage Detector'),
        actions: [
          IconButton(
            icon: Icon(Icons.tune),
            onPressed: () => Navigator.pushNamed(context, CalibrationScreen.routeName),
          ),
          IconButton(
            icon: Icon(Icons.history),
            onPressed: () => Navigator.pushNamed(context, HistoryScreen.routeName).then((_) {
              // Refresh markers when returning from history
              _loadSavedMarkers();
            }),
          ),
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () => Navigator.pushNamed(context, SettingsScreen.routeName),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Main Map
          GoogleMap(
            onMapCreated: (controller) {
              _mapController = controller;
              _applyMapStyle();
              setState(() {
                _isMapReady = true;
              });
            },
            initialCameraPosition: CameraPosition(target: _currentPosition, zoom: 15),
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            mapType: _getMapType(settings.mapStyle),
            onCameraMove: (_) {
              // Disable follow mode if user manually moves the map
              if (_isFollowingUser) {
                setState(() {
                  _isFollowingUser = false;
                });
              }
            },
          ),

          // Status Card
          Positioned(
            top: 16,
            left: 16,
            child: StatusCard(
              threshold: settings.threshold,
              currentSeverity: _currentSeverity,
              isDamaged: _isDamaged,
              recordingActive: settings.recordingActive,
              damageCount: _detectedDamageCount,
              distanceTraveled: _distanceTraveled,
              lastRecordTime: _lastRecordTime,
            ),
          ),

          // Map Control Buttons
          Positioned(
            right: 16,
            bottom: 100,
            child: Column(
              children: [
                // Follow user button
                FloatingActionButton.small(
                  heroTag: "followBtn",
                  backgroundColor: _isFollowingUser ? Colors.blue : Colors.grey,
                  onPressed: _toggleFollowUser,
                  child: Icon(Icons.gps_fixed),
                ),
                SizedBox(height: 8),
                // Clear map button
                FloatingActionButton.small(
                  heroTag: "clearBtn",
                  backgroundColor: Colors.white,
                  onPressed: _clearMap,
                  child: Icon(Icons.layers_clear, color: Colors.black87),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _toggleRecording,
        backgroundColor: settings.recordingActive ? Colors.red : Colors.green,
        icon: Icon(settings.recordingActive ? Icons.stop : Icons.play_arrow),
        label: Text(settings.recordingActive ? 'Stop' : 'Start'),
      ),
    );
  }

  MapType _getMapType(String style) {
    switch (style) {
      case 'satellite':
        return MapType.satellite;
      case 'terrain':
        return MapType.terrain;
      default:
        return MapType.normal;
    }
  }
}