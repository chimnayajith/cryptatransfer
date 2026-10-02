import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

class WebSocketService {
  WebSocketChannel? _channel;

  final StreamController<Map<String, dynamic>> _messages =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get messages => _messages.stream;

  void connect() {
    _channel = WebSocketChannel.connect(
      Uri.parse('ws://192.168.1.13:8000'),
    );

    _channel!.stream.listen(
      (rawMessage) {
        try {
          final decoded = jsonDecode(rawMessage.toString());

          if (decoded is Map<String, dynamic>) {
            _messages.add(decoded);
          }
        } catch (e) {
          _messages.add({
            'type': 'error',
            'message': 'Invalid server response: $e',
          });
        }
      },
      onError: (error) {
        _messages.add({
          'type': 'error',
          'message': error.toString(),
        });
      },
      onDone: () {
        _messages.add({
          'type': 'disconnected',
        });
      },
    );
  }

  void send(Map<String, dynamic> message) {
    if (_channel == null) {
      throw StateError('WebSocket is not connected');
    }

    _channel!.sink.add(jsonEncode(message));
  }

  void dispose() {
    _channel?.sink.close();
    _messages.close();
  }
}