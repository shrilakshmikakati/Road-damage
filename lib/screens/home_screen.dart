import 'package:flutter/material.dart';
import '../models/road_damage.dart';
import '../models/damage_type.dart';
import '../models/damage_severity.dart';
// Import other necessary files

class HomeScreen extends StatefulWidget {
  static const routeName = '/home';

  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Your existing code

  Widget _buildDamageCard(RoadDamage damage) {
    // Initialize cardColor with a default value
    Color cardColor = damage.severity.color;

    return Card(
      color: cardColor,
      child: ListTile(
        title: Text(damage.damageType.displayName),
        subtitle: Text(damage.description),
        trailing: Text('Confidence: ${(damage.confidenceScore * 100).toStringAsFixed(0)}%'),
        onTap: () {
          // Handle tap
        },
      ),
    );
  }

  // Rest of your code

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Road Damage Detection'),
      ),
      body: Column(
        children: [
          // Your existing widgets
        ],
      ),
    );
  }
}