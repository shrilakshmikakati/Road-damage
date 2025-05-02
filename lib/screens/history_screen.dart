// lib/screens/history_screen.dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import '../models/damage_record.dart';
import '../repositories/damage_repository.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({Key? key}) : super(key: key);
  static const routeName = '/history';
  @override
  _HistoryScreenState createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> with SingleTickerProviderStateMixin {
  final DamageRepository _repository = DamageRepository();
  List<DamageRecord> _records = [];
  bool _isLoading = true;
  late TabController _tabController;
  Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    setState(() => _isLoading = true);

    final records = await _repository.getRecords();
    records.sort((a, b) => b.timestamp.compareTo(a.timestamp)); // Sort by newest first

    setState(() {
      _records = records;
      _isLoading = false;

      // Create markers for map view
      _markers = records.map((record) =>
          Marker(
            markerId: MarkerId(record.id),
            position: record.position,
            icon: BitmapDescriptor.defaultMarkerWithHue(
              record.isDamaged ? BitmapDescriptor.hueRed : BitmapDescriptor.hueBlue,
            ),
            infoWindow: InfoWindow(
              title: record.isDamaged ? 'Damaged Road' : 'Good Road',
              snippet: DateFormat('MM/dd HH:mm').format(record.timestamp),
            ),
          )
      ).toSet();
    });
  }

  Future<void> _clearHistory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Clear History'),
        content: Text('Are you sure you want to delete all records? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('DELETE', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _repository.clearRecords();
      _loadRecords();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('History'),
        actions: [
          IconButton(
            icon: Icon(Icons.delete),
            onPressed: _clearHistory,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(icon: Icon(Icons.list), text: 'List View'),
            Tab(icon: Icon(Icons.map), text: 'Map View'),
          ],
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : TabBarView(
        controller: _tabController,
        children: [
          _buildListView(),
          _buildMapView(),
        ],
      ),
    );
  }

  Widget _buildListView() {
    if (_records.isEmpty) {
      return Center(child: Text('No records yet'));
    }

    return ListView.builder(
      itemCount: _records.length,
      itemBuilder: (ctx, i) {
        final record = _records[i];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: record.isDamaged ? Colors.red : Colors.blue,
            child: Icon(
              record.isDamaged ? Icons.warning : Icons.check,
              color: Colors.white,
            ),
          ),
          title: Text(
            DateFormat('yyyy-MM-dd HH:mm:ss').format(record.timestamp),
          ),
          subtitle: Text(
            'Severity: ${record.severity.toStringAsFixed(1)} - ' +
                'Location: ${record.position.latitude.toStringAsFixed(5)}, ' +
                '${record.position.longitude.toStringAsFixed(5)}',
          ),
          trailing: Text(
            record.isDamaged ? 'DAMAGED' : 'GOOD',
            style: TextStyle(
              color: record.isDamaged ? Colors.red : Colors.green,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      },
    );
  }

  Widget _buildMapView() {
    if (_records.isEmpty) {
      return Center(child: Text('No records yet'));
    }

    // Find center of all points
    double avgLat = 0;
    double avgLng = 0;

    for (var record in _records) {
      avgLat += record.position.latitude;
      avgLng += record.position.longitude;
    }

    avgLat /= _records.length;
    avgLng /= _records.length;

    final center = LatLng(avgLat, avgLng);

    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: center,
        zoom: 12,
      ),
      markers: _markers,
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
    );
  }
}