import 'package:location/location.dart';
import '../utils/damage_detector.dart';
import '../models/custom_location_data.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Define the LocationService interface
abstract class LocationService {
  Future<CustomLocationData> getLocation();
  Stream<LocationData> get onLocationChanged;
  void dispose();
}

class LocationServiceImpl implements LocationService {
  final Location _location = Location();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Add a stream controller for location changes
  final _locationController = StreamController<LocationData>.broadcast();

  LocationServiceImpl() {
    // Initialize location service
    _location.requestPermission().then((permission) {
      if (permission == PermissionStatus.granted) {
        _location.onLocationChanged.listen((locationData) {
          _locationController.add(locationData);

          // If user is authenticated, store location data
          if (_auth.currentUser != null) {
            _storeLocationData(locationData);
          }
        });
      }
    });
  }

  @override
  Future<CustomLocationData> getLocation() async {
    try {
      LocationData locationData = await _location.getLocation();

      // If user is authenticated, store location data
      if (_auth.currentUser != null) {
        _storeLocationData(locationData);
      }

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

  // Store location data in Firestore
  Future<void> _storeLocationData(LocationData locationData) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      await _firestore.collection('user_locations').doc(userId).set({
        'latitude': locationData.latitude,
        'longitude': locationData.longitude,
        'heading': locationData.heading,
        'speed': locationData.speed,
        'accuracy': locationData.accuracy,
        'timestamp': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error storing location data: $e');
    }
  }

  // Add a stream for location changes
  @override
  Stream<LocationData> get onLocationChanged => _locationController.stream;

  // Don't forget to dispose the controller - fixed to handle null check
  @override
  void dispose() {
    if (!_locationController.isClosed) {
      _locationController.close();
    }
  }
}