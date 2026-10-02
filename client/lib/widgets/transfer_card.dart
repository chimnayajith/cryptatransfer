import 'package:flutter/material.dart';

class StatusCard extends StatelessWidget {
  final String status;

  const StatusCard({
    super.key,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        child: Row(
          children: [
            const Icon(
              Icons.circle,
              size: 10,
              color: Colors.green,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(status),
            ),
          ],
        ),
      ),
    );
  }
}