import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../repositories/damage_repository.dart';
import '../services/map_service.dart';
import '../models/road_damage.dart';

class MapScreen extends StatefulWidget {
  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDamages();
  }

  Future<void> _loadDamages() async {
    final damageRepository = Provider.of<DamageRepository>(context, listen: false);
    final mapService = Provider.of<MapService>(context, listen: false);

    final damages = await damageRepository.getAllDamages();

    setState(() {
      _markers = mapService.generateMarkers(damages);
      _isLoading = false;
    });

    if (damages.isNotEmpty) {
      _centerMapOnDamages(damages);
    }
  }

  void _centerMapOnDamages(List<RoadDamage> damages) {
    if (_mapController == null || damages.isEmpty) return;

    // Calculate the center of all damages
    double totalLat = 0;
    double totalLng = 0;

    for (var damage in damages) {
      totalLat += damage.location.latitude;
      totalLng += damage.location.longitude;
    }

    final centerLat = totalLat / damages.length;
    final centerLng = totalLng / damages.length;

    _mapController!.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(centerLat, centerLng),
          zoom: 14,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Road Damage Map'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadDamages,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : GoogleMap(
        initialCameraPosition: CameraPosition(
          target: LatLng(0, 0),
          zoom: 2,
        ),
        markers: _markers,
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
        mapToolbarEnabled: true,
        onMapCreated: (controller) {
          _mapController = controller;
          final damageRepository = Provider.of<DamageRepository>(context, listen: false);
          damageRepository.getAllDamages().then((damages) {
            if (damages.isNotEmpty) {
              _centerMapOnDamages(damages);
            }
          });
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/');
        },
        child: Icon(Icons.home),
      ),
    );
  }
}