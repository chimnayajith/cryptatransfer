import 'package:client/theme/app_theme.dart';
import 'package:flutter/material.dart';

import 'screens/username_screen.dart';

class CryptaTransferApp extends StatelessWidget {
  const CryptaTransferApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CryptaTransfer',
      theme: AppTheme.dark,
      home: const UsernameScreen(),
    );
  }
}