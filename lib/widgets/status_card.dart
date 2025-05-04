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
        width: 220,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Status indicator
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: recordingActive ? Colors.green : Colors.grey,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  recordingActive ? 'Recording Active' : 'Recording Paused',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: recordingActive ? Colors.green : Colors.grey,
                  ),
                ),
              ],
            ),
            const Divider(),

            // Current severity indicator
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Current Severity',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      Text(
                        currentSeverity.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDamaged ? Colors.red : Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ),
                // Severity gauge
                Container(
                  width: 60,
                  height: 60,
                  child: CustomPaint(
                    painter: SeverityGaugePainter(
                      threshold: threshold,
                      currentValue: currentSeverity,
                      isDamaged: isDamaged,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Stats
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStatItem('Damages', '$damageCount', Icons.warning),
                _buildStatItem(
                  'Distance',
                  '${(distanceTraveled / 1000).toStringAsFixed(1)} km',
                  Icons.straighten,
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Last record time
            if (lastRecordTime != null)
              Row(
                children: [
                  Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    'Last: ${DateFormat('HH:mm:ss').format(lastRecordTime!)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: Colors.grey[600]),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class SeverityGaugePainter extends CustomPainter {
  final double threshold;
  final double currentValue;
  final bool isDamaged;

  SeverityGaugePainter({
    required this.threshold,
    required this.currentValue,
    required this.isDamaged,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Draw background circle
    final bgPaint = Paint()
      ..color = Colors.grey.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5;

    canvas.drawCircle(center, radius - 5, bgPaint);

    // Draw threshold marker
    final thresholdAngle = (threshold / 10) * 2 * 3.14159;
    final thresholdPaint = Paint()
      ..color = Colors.orange
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 5),
      -3.14159 / 2, // Start from top (negative PI/2)
      thresholdAngle,
      false,
      thresholdPaint,
    );

    // Calculate angle based on currentValue (max 10)
    final normalizedValue = currentValue > 10 ? 10 : currentValue;
    final sweepAngle = (normalizedValue / 10) * 2 * 3.14159;

    // Draw value arc
    final valuePaint = Paint()
      ..color = isDamaged ? Colors.red : Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 5),
      -3.14159 / 2, // Start from top
      sweepAngle,
      false,
      valuePaint,
    );
  }

  @override
  bool shouldRepaint(covariant SeverityGaugePainter oldDelegate) {
    return oldDelegate.currentValue != currentValue ||
        oldDelegate.threshold != threshold ||
        oldDelegate.isDamaged != isDamaged;
  }
}