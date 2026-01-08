// Path: lib/widgets/dashboard/dashboard_cards.dart

import 'package:flutter/material.dart';

class FinancialCard extends StatelessWidget {
  final String title;
  final String amount;
  final Color color;
  final String status;
  // final double width; // <<--- REMOVE THIS LINE

  const FinancialCard({
    super.key,
    required this.title,
    required this.amount,
    required this.color,
    required this.status,
    // required this.width, // <<--- AND REMOVE THIS LINE
  });

  @override
  Widget build(BuildContext context) {
    // The Container no longer has a fixed width. Its width will be
    // determined by its parent (in our case, a Flexible widget).
    return Container(
      // The outer container applies the shadow to the entire card footprint.
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 4), // subtle shadow below the card
          ),
        ],
      ),
      child: Stack( // Use Stack to overlay the accent bar on the main card content
        children: [
          // --- Main Card Content Container ---
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12), // Rounded corners for the whole card
              border: Border.all(color: Colors.grey.shade200, width: 1), // UNIFORM grey border
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min, // Ensure Column only takes needed height
              children: [
                Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 4),
                // Use FittedBox to make the text shrink if space is tight
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(amount, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.check_circle, size: 14, color: color),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        status,
                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // --- Positioned Colored Accent Bar ---
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: 4, // The width of the accent bar
              decoration: BoxDecoration(
                color: color, // Dynamic color for the accent bar
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


// ... PerformanceCard remains the same ...
class PerformanceCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final double progress;
  final Color color;

  const PerformanceCard({
    super.key,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.progress,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            borderRadius: BorderRadiusGeometry.all(Radius.circular(20)),
            value: progress,
            minHeight: 8,
            backgroundColor: Colors.grey[200],
            color: color,
          ),
          const SizedBox(height: 8),
          Text(subtitle, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ],
      ),
    );
  }
}
