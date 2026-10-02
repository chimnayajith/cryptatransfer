import 'package:flutter/material.dart';

import '../models/online_user.dart';

class OnlineUserTile extends StatelessWidget {
  final OnlineUser user;
  final VoidCallback onTap;

  const OnlineUserTile({
    super.key,
    required this.user,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const CircleAvatar(
          child: Icon(Icons.person),
        ),
        title: Text(user.userId),
        subtitle: const Text('Online'),
        trailing: const Icon(
          Icons.chevron_right,
        ),
        onTap: onTap,
      ),
    );
  }
}