// lib/screens/home_map_screen.dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:provider/provider.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'dart:async';
import '../provider/settings_provider.dart';
import '../models/damage_record.dart';
import '../repositories/damage_repository.dart';
import 'calibration_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';

class HomeMapScreen extends StatefulWidget {
  const HomeMapScreen({Key? key}) : super(key: key);
  static const routeName = '/home';
  @override
  _HomeMapScreenState createState() => _HomeMapScreenState();
}

class _HomeMapScreenState extends State<HomeMapScreen> {
  late GoogleMapController _mapController;
  final Location _location = Location();
  final DamageRepository _repository = DamageRepository();

  StreamSubscription<GyroscopeEvent>? _gyroSub;
  StreamSubscription<LocationData>? _locationSub;

  bool _isDamaged = false;
  double _currentSeverity = 0.0;
  Set<Marker> _markers = {};
  LatLng _currentPosition = LatLng(0, 0);

  // For polyline rendering
  List<LatLng> _positions = [];
  Set<Polyline> _polylines = {};

  @override
  void initState() {
    super.initState();
    _loadSavedMarkers();
    _initLocation();
    _startServices();
  }

  Future<void> _loadSavedMarkers() async {
    final records = await _repository.getRecords();
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
              snippet: '${record.timestamp.hour}:${record.timestamp.minute} - Severity: ${record.severity.toStringAsFixed(1)}',
            ),
          )
      ).toSet();
    });
  }

  void _initLocation() {
    _location.changeSettings(accuracy: LocationAccuracy.high, interval: 1000);
  }

  void _startServices() {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    if (settings.recordingActive) {
      _startRecording();
    }
  }

  void _startRecording() {
    // Start location tracking
    _locationSub = _location.onLocationChanged.listen((loc) {
      if (loc.latitude == null || loc.longitude == null) return;

      final newPos = LatLng(loc.latitude!, loc.longitude!);
      setState(() {
        _currentPosition = newPos;
        _positions.add(newPos);
      });

      // Update camera position
      _mapController.animateCamera(CameraUpdate.newLatLng(newPos));

      // Record damage if threshold exceeded
      if (_isDamaged) {
        _recordDamage(newPos, _currentSeverity);
      }

      // Update polylines
      _updatePolylines();
    });

    // Start gyroscope listening
    final threshold = Provider.of<SettingsProvider>(context, listen: false).threshold;
    _gyroSub = gyroscopeEvents.listen((e) {
      final mag = e.x.abs() + e.y.abs() + e.z.abs();
      setState(() {
        _currentSeverity = mag;
        _isDamaged = mag > threshold;
      });
    });
  }

  void _stopRecording() {
    _locationSub?.cancel();
    _gyroSub?.cancel();
    _locationSub = null;
    _gyroSub = null;
  }

  void _updatePolylines() {
    // Skip if not enough points
    if (_positions.length < 2) return;

    setState(() {
      _polylines.add(
        Polyline(
          polylineId: PolylineId('route'),
          points: _positions,
          color: Colors.blue,
          width: 3,
        ),
      );
    });
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

  @override
  void dispose() {
    _stopRecording();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Road Damage Map'),
        actions: [
          IconButton(
            icon: Icon(Icons.tune),
            onPressed: () => Navigator.pushNamed(context, CalibrationScreen.routeName),
          ),
          IconButton(
            icon: Icon(Icons.history),
            onPressed: () => Navigator.pushNamed(context, HistoryScreen.routeName),
          ),
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () => Navigator.pushNamed(context, SettingsScreen.routeName),
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: (c) => _mapController = c,
            initialCameraPosition: CameraPosition(target: _currentPosition, zoom: 15),
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            mapType: _getMapType(settings.mapStyle),
          ),
          Positioned(
            top: 16,
            left: 16,
            child: Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.8),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Threshold: ${settings.threshold.toStringAsFixed(1)}'),
                  Text('Current: ${_currentSeverity.toStringAsFixed(1)}'),
                  Text('Status: ${_isDamaged ? 'DAMAGED' : 'OK'}',
                      style: TextStyle(
                        color: _isDamaged ? Colors.red : Colors.green,
                        fontWeight: FontWeight.bold,
                      )),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _toggleRecording,
        backgroundColor: settings.recordingActive ? Colors.red : Colors.green,
        child: Icon(settings.recordingActive ? Icons.stop : Icons.play_arrow),
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