import 'package:flutter/material.dart';

import 'home_screen.dart';

class UsernameScreen extends StatefulWidget {
  const UsernameScreen({super.key});

  @override
  State<UsernameScreen> createState() => _UsernameScreenState();
}

class _UsernameScreenState extends State<UsernameScreen> {
  final TextEditingController controller = TextEditingController();

  String? error;

  void continueToApp() {
    final username = controller.text.trim();

    if (username.isEmpty) {
      setState(() {
        error = 'Please enter a username';
      });
      return;
    }

    if (username.length < 2) {
      setState(() {
        error = 'Username must be at least 2 characters';
      });
      return;
    }

    if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(username)) {
      setState(() {
        error = 'Use only letters, numbers, _ or -';
      });
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => HomeScreen(userId: username),
      ),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.lock_rounded,
                  size: 72,
                ),

                const SizedBox(height: 28),

                const Text(
                  'CryptaTransfer',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 8),

                const Text(
                  'Secure peer-to-peer file transfer',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white60,
                  ),
                ),

                const SizedBox(height: 40),

                TextField(
                  controller: controller,
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => continueToApp(),
                  decoration: InputDecoration(
                    labelText: 'Username',
                    hintText: 'e.g. alice',
                    prefixIcon: const Icon(
                      Icons.person_outline,
                    ),
                    errorText: error,
                    border: const OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: continueToApp,
                    child: const Text(
                      'Continue',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                const Text(
                  'Your RSA-2048 identity is generated locally\n'
                  'and your private key never leaves this device.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white38,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}