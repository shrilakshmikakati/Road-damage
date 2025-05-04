// lib/widgets/status_card.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class StatusCard extends StatelessWidget {
  final double threshold;
  final double currentSeverity;
  final bool isDamaged;
  final bool recordingActive;
  final int damageCount;
  final double distanceTraveled;
  final DateTime? lastRecordTime;

  const StatusCard({
    Key? key,
    required this.threshold,
    required this.currentSeverity,
    required this.isDamaged,
    required this.recordingActive,
    required this.damageCount,
    required this.distanceTraveled,
    this.lastRecordTime,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(12),
        width: MediaQuery.of(context).size.width * 0.85,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Status header with recording indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Status',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Row(
                  children: [
                    if (recordingActive)
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    SizedBox(width: 4),
                    Text(
                      recordingActive ? 'RECORDING' : 'IDLE',
                      style: TextStyle(
                        color: recordingActive ? Colors.red : Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            Divider(),

            // Current severity indicator
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Current Severity',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                      SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: currentSeverity / 10, // Scale to 0-1 range assuming max severity is 10
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isDamaged ? Colors.red : Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 12),
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDamaged ? Colors.red.shade100 : Colors.green.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    currentSeverity.toStringAsFixed(1),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDamaged ? Colors.red : Colors.green,
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: 12),

            // Status indicators
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatusItem(
                  context,
                  Icons.warning,
                  damageCount.toString(),
                  'Potholes',
                  Colors.orange,
                ),
                _buildStatusItem(
                  context,
                  Icons.straighten,
                  '${(distanceTraveled / 1000).toStringAsFixed(1)} km',
                  'Distance',
                  Colors.blue,
                ),
                _buildStatusItem(
                  context,
                  Icons.access_time,
                  lastRecordTime != null
                      ? DateFormat('HH:mm:ss').format(lastRecordTime!)
                      : '--:--',
                  'Last Detection',
                  Colors.purple,
                ),
              ],
            ),

            SizedBox(height: 8),

            // Threshold information
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Detection Threshold: ${threshold.toStringAsFixed(1)}',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusItem(BuildContext context, IconData icon, String value, String label, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }
}