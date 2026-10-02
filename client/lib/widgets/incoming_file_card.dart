import 'package:flutter/material.dart';

class IncomingFileCard extends StatelessWidget {
  final Map<String, dynamic> transfer;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const IncomingFileCard({
    super.key,
    required this.transfer,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final sender =
        transfer['senderId']?.toString() ?? '';

    final fileName =
        transfer['fileName']?.toString() ?? '';

    final fileSize =
        transfer['fileSize']?.toString() ?? '0';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.download),
                SizedBox(width: 10),
                Text(
                  'Incoming File',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            Text(
              '$sender wants to send you:',
            ),

            const SizedBox(height: 8),

            Text(
              fileName,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 6),

            Text('$fileSize bytes'),

            const SizedBox(height: 16),

            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: onAccept,
                  icon: const Icon(
                    Icons.check,
                  ),
                  label: const Text('Accept'),
                ),

                const SizedBox(width: 12),

                OutlinedButton.icon(
                  onPressed: onReject,
                  icon: const Icon(
                    Icons.close,
                  ),
                  label: const Text('Reject'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}