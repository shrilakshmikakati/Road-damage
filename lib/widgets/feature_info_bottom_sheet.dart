import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/road_feature.dart';
import '../models/road_damage.dart';
import '../models/damage_type.dart';
import '../models/damage_severity.dart';
import '../models/road_feature_type.dart';

class FeatureInfoBottomSheet extends StatelessWidget {
  final dynamic feature;

  // Fix the super parameter warning by using super.key
  const FeatureInfoBottomSheet({
    super.key,
    required this.feature,
  });

  @override
  Widget build(BuildContext context) {
    // Determine if we're dealing with RoadFeature or RoadDamage
    final bool isRoadDamage = feature is RoadDamage;

    // Get the title based on the type of feature
    String title;
    if (isRoadDamage) {
      title = (feature as RoadDamage).damageType.displayName;
    } else {
      title = (feature as RoadFeature).type.displayName;
    }

    // Get the position
    final position = isRoadDamage
        ? (feature as RoadDamage).position
        : (feature as RoadFeature).position;

    // Get the description
    final description = feature.description;

    // Get the timestamp
    final timestamp = feature.timestamp;

    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const Divider(),
          const SizedBox(height: 8),
          _buildInfoRow(
            context,
            'Description',
            description,
          ),
          _buildInfoRow(
            context,
            'Location',
            '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}',
          ),
          _buildInfoRow(
            context,
            'Time Detected',
            DateFormat('MMM dd, yyyy - HH:mm:ss').format(timestamp),
          ),
          if (isRoadDamage)
            _buildInfoRow(
              context,
              'Severity',
              (feature as RoadDamage).severity.displayName,
            ),
          if (isRoadDamage && (feature as RoadDamage).confidenceScore > 0)
            _buildInfoRow(
              context,
              'Confidence',
              '${((feature as RoadDamage).confidenceScore * 100).toStringAsFixed(0)}%',
            ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.share),
                label: const Text('Share'),
                onPressed: () {
                  // Implement sharing functionality
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Sharing not implemented yet')),
                  );
                },
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.report),
                label: const Text('Report'),
                onPressed: () {
                  // Implement reporting functionality
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Reporting not implemented yet')),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}