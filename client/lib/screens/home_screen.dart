import 'dart:async';

import 'package:flutter/material.dart';

import '../controllers/transfer_controller.dart';
import '../models/online_user.dart';
import '../widgets/incoming_file_card.dart';
import '../widgets/online_user_tile.dart';
import '../widgets/status_card.dart';

class HomeScreen extends StatefulWidget {
  final String userId;

  const HomeScreen({super.key, required this.userId});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final TransferController controller;

  List<OnlineUser> onlineUsers = [];

  String status = 'Starting...';

  final List<_TimelineEvent> timeline = [
    _TimelineEvent(message: 'Starting secure identity setup', timestamp: null),
  ];

  final List<String> pendingStatuses = [];

  bool isDrainingTimeline = false;

  bool isIncomingDialogOpen = false;

  StreamSubscription<String>? statusSubscription;

  StreamSubscription<List<OnlineUser>>? usersSubscription;

  StreamSubscription<Map<String, dynamic>?>? incomingSubscription;

  @override
  void initState() {
    super.initState();

    controller = TransferController(userId: widget.userId);

    statusSubscription = controller.statusStream.listen((value) {
      if (!mounted) return;

      final progress = _transferProgress(value);

      if (progress == null) {
        pendingStatuses.add(value);
      } else {
        pendingStatuses.removeWhere(
          (pendingStatus) => _transferProgress(pendingStatus) != null,
        );
        pendingStatuses.add(progress.$1);
      }

      unawaited(_drainTimeline());
    });

    usersSubscription = controller.usersStream.listen((users) {
      if (!mounted) return;

      setState(() {
        onlineUsers = users;
      });
    });

    incomingSubscription = controller.incomingTransferStream.listen((transfer) {
      if (!mounted) return;

      if (transfer == null || isIncomingDialogOpen) return;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showIncomingTransferDialog(transfer);
        }
      });
    });

    controller.initialize();
  }

  @override
  void dispose() {
    statusSubscription?.cancel();
    usersSubscription?.cancel();
    incomingSubscription?.cancel();

    pendingStatuses.clear();
    controller.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('CryptaTransfer'), centerTitle: false),

      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),

          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              // User
              Row(
                children: [
                  const CircleAvatar(radius: 24, child: Icon(Icons.person)),

                  const SizedBox(width: 12),

                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.userId,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const Text(
                        'Local identity',
                        style: TextStyle(color: Colors.white54),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Status
              StatusCard(status: status),

              const SizedBox(height: 24),

              // Online users
              const Text(
                'Online Users',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 12),

              if (onlineUsers.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(
                      child: Text(
                        'No other users online',
                        style: TextStyle(color: Colors.white54),
                      ),
                    ),
                  ),
                ),

              ...onlineUsers.map(
                (user) => OnlineUserTile(
                  user: user,
                  onTap: () => controller.sendFile(user),
                ),
              ),

              const SizedBox(height: 24),

              _ActivityTimeline(events: timeline),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showIncomingTransferDialog(
    Map<String, dynamic> transfer,
  ) async {
    if (isIncomingDialogOpen) return;

    isIncomingDialogOpen = true;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        content: IncomingFileCard(
          transfer: transfer,
          onAccept: () {
            controller.acceptTransfer();
            Navigator.of(dialogContext).pop();
          },
          onReject: () {
            controller.rejectTransfer();
            Navigator.of(dialogContext).pop();
          },
        ),
      ),
    );

    isIncomingDialogOpen = false;
  }

  Future<void> _drainTimeline() async {
    if (isDrainingTimeline) return;

    isDrainingTimeline = true;

    while (mounted && pendingStatuses.isNotEmpty) {
      await Future<void>.delayed(const Duration(milliseconds: 600));

      if (!mounted) break;

      final nextStatus = pendingStatuses.removeAt(0);
      final progress = _transferProgress(nextStatus);

      setState(() {
        status = progress?.$1 ?? nextStatus;

        if (progress != null &&
            timeline.isNotEmpty &&
            timeline.last.progress != null) {
          timeline[timeline.length - 1] = _TimelineEvent(
            message: progress.$1,
            timestamp: timeline.last.timestamp,
            progress: progress.$2,
          );
        } else {
          timeline.add(
            _TimelineEvent(
              message: progress?.$1 ?? nextStatus,
              timestamp: DateTime.now(),
              progress: progress?.$2,
            ),
          );
        }

        if (timeline.length > 12) {
          timeline.removeAt(0);
        }
      });
    }

    isDrainingTimeline = false;
  }

  (String, int)? _transferProgress(String value) {
    final match = RegExp(
      r'^(Sending|Receiving) file\.\.\.\s+(\d+)%$',
    ).firstMatch(value);

    if (match == null) return null;

    final direction = match.group(1)!;
    final percentage = int.parse(match.group(2)!);

    return ('$direction file... $percentage%', percentage);
  }
}

class _TimelineEvent {
  final String message;
  final DateTime? timestamp;
  final int? progress;

  const _TimelineEvent({
    required this.message,
    required this.timestamp,
    this.progress,
  });
}

class _ActivityTimeline extends StatelessWidget {
  final List<_TimelineEvent> events;

  const _ActivityTimeline({required this.events});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.route_rounded,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Activity timeline',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...events.reversed.toList().asMap().entries.map(
              (entry) => _TimelineRow(
                event: entry.value,
                isLatest: entry.key == 0,
                isLast: entry.key == events.length - 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  final _TimelineEvent event;
  final bool isLatest;
  final bool isLast;

  const _TimelineRow({
    required this.event,
    required this.isLatest,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final color = Colors.green.shade400;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 20,
            child: Column(
              children: [
                Icon(
                  event.progress != null && event.progress! < 100
                      ? Icons.sync
                      : Icons.check_circle_outline,
                  size: 16,
                  color: color,
                ),
                if (!isLast)
                  Expanded(child: Container(width: 1, color: Colors.white24)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.message,
                    style: TextStyle(
                      color: isLatest ? null : Colors.white,
                      fontWeight: isLatest ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                  if (event.timestamp != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      _formatTime(event.timestamp!),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white38,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime timestamp) {
    final hour = timestamp.hour.toString().padLeft(2, '0');
    final minute = timestamp.minute.toString().padLeft(2, '0');
    final second = timestamp.second.toString().padLeft(2, '0');
    return '$hour:$minute:$second';
  }
}
