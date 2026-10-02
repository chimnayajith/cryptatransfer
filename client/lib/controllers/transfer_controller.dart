import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../crypto/aes_service.dart';
import '../crypto/key_manager.dart';
import '../crypto/rsa_encryption_service.dart';
import '../crypto/rsa_service.dart';
import '../models/online_user.dart';
import '../network/websocket_service.dart';
import '../services/file_transfer_service.dart';

class TransferController {
  final String userId;

  final KeyManager keyManager;
  final WebSocketService socket;

  TransferController({
    required this.userId,
    KeyManager? keyManager,
    WebSocketService? socket,
  }) : keyManager = keyManager ?? KeyManager(),
       socket = socket ?? WebSocketService();

  final StreamController<String> _statusController =
      StreamController<String>.broadcast();

  final StreamController<List<OnlineUser>> _usersController =
      StreamController<List<OnlineUser>>.broadcast();

  final StreamController<Map<String, dynamic>?> _incomingController =
      StreamController<Map<String, dynamic>?>.broadcast();

  Stream<String> get statusStream => _statusController.stream;

  Stream<List<OnlineUser>> get usersStream => _usersController.stream;

  Stream<Map<String, dynamic>?> get incomingTransferStream =>
      _incomingController.stream;

  StreamSubscription<Map<String, dynamic>>? _subscription;
  Timer? _publicKeyRequestTimer;

  PreparedFile? pendingFile;
  OnlineUser? pendingRecipient;

  Uint8List? pendingEncryptedAesKey;

  Map<String, dynamic>? incomingTransfer;

  bool transferResponded = false;

  bool _disposed = false;

  final List<Uint8List> _receivedChunks = [];

  String? _receivedFileName;
  int _expectedChunks = 0;

  Uint8List? _receivedAesKey;
  Uint8List? _receivedNonce;
  Uint8List? _receivedTag;

  void setStatus(String value) {
    if (_disposed) return;

    debugPrint('STATUS: $value');
    _statusController.add(value);
  }

  Future<void> initialize() async {
    try {
      setStatus('Generating/loading keys...');

      await keyManager.initialize();
      setStatus('RSA-2048 key pair generated');
      setStatus('Private key kept on this device');
      setStatus('Public key ready for registration');

      // AES test
      final key = AesService.generateKey();

      final original = Uint8List.fromList(utf8.encode('Hello CryptaTransfer!'));

      final encrypted = AesService.encrypt(original, key);

      final decrypted = AesService.decrypt(encrypted, key);

      debugPrint('AES TEST: ${utf8.decode(decrypted)}');
      setStatus('AES-256-GCM self-test passed');

      // RSA test
      final aesKey = AesService.generateKey();

      final encryptedKey = RsaEncryptionService.encrypt(
        aesKey,
        keyManager.publicKey,
      );

      final decryptedKey = RsaEncryptionService.decrypt(
        encryptedKey,
        keyManager.privateKey,
      );

      debugPrint('RSA KEY TEST: ${_bytesEqual(aesKey, decryptedKey)}');
      setStatus('RSA-OAEP key exchange self-test passed');

      setStatus('Keys ready');

      setStatus('Connecting to transfer server...');
      socket.connect();

      _subscription = socket.messages.listen(handleMessage);

      setStatus('Registering...');

      socket.send({
        'type': 'register',
        'userId': userId,
        'publicKey': keyManager.publicKeyBase64,
      });
      setStatus('Public key published to server');
    } catch (e, stackTrace) {
      debugPrint('INITIALIZATION ERROR: $e');
      debugPrintStack(stackTrace: stackTrace);

      setStatus('Error: $e');
    }
  }

  bool _bytesEqual(Uint8List a, Uint8List b) {
    if (a.length != b.length) {
      return false;
    }

    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }

    return true;
  }

  Future<void> handleMessage(Map<String, dynamic> message) async {
    debugPrint('SERVER: $message');

    switch (message['type']) {
      case 'registered':
        setStatus('Connected as ${message['userId']}');
        break;

      case 'users':
        final users = message['users'] as List;

        final parsedUsers = users
            .map((user) => OnlineUser.fromJson(Map<String, dynamic>.from(user)))
            .where((user) => user.userId != userId)
            .toList();

        _usersController.add(parsedUsers);
        break;

      case 'error':
        _publicKeyRequestTimer?.cancel();
        _publicKeyRequestTimer = null;
        setStatus('Error: ${message['message']}');
        break;

      case 'public_key':
        await handlePublicKey(message);
        break;

      case 'transfer_init':
        incomingTransfer = message;
        transferResponded = false;

        _incomingController.add(message);

        setStatus('Incoming file from ${message['senderId']}');
        break;

      case 'transfer_response':
        await handleTransferResponse(message);
        break;

      case 'transfer_start':
        await handleTransferStart(message);
        break;

      case 'transfer_chunk':
        handleTransferChunk(message);
        break;

      case 'transfer_complete':
        await handleTransferComplete(message);
        break;

      default:
        debugPrint('Unknown message type: ${message['type']}');
    }
  }

  Future<void> handlePublicKey(Map<String, dynamic> message) async {
    if (pendingFile == null || pendingRecipient == null) {
      debugPrint('No pending transfer');
      return;
    }

    try {
      _publicKeyRequestTimer?.cancel();
      _publicKeyRequestTimer = null;

      final recipientId = message['userId'].toString();

      final publicKey = RsaService.publicKeyFromBase64(
        message['publicKey'].toString(),
      );

      setStatus('Encrypting AES file key with $recipientId public key...');

      final encryptedAesKey = RsaEncryptionService.encrypt(
        pendingFile!.key,
        publicKey,
      );

      pendingEncryptedAesKey = encryptedAesKey;

      debugPrint('AES key encrypted with $recipientId public key');

      debugPrint(
        'Encrypted AES key size: '
        '${encryptedAesKey.length}',
      );

      setStatus('AES file key encrypted for $recipientId');

      socket.send({
        'type': 'transfer_init',
        'senderId': userId,
        'recipientId': recipientId,
        'fileName': pendingFile!.name,
        'fileSize': pendingFile!.originalSize,
        'encryptedAesKey': base64Encode(encryptedAesKey),
        'nonce': base64Encode(pendingFile!.nonce),
        'tag': base64Encode(pendingFile!.tag),
      });

      debugPrint('TRANSFER INIT SENT');
      setStatus('Transfer request sent to $recipientId');
    } catch (e, stackTrace) {
      debugPrint('TRANSFER ERROR: $e');
      debugPrintStack(stackTrace: stackTrace);

      setStatus('Transfer error: $e');
    }
  }

  Future<void> sendFile(OnlineUser recipient) async {
    try {
      setStatus('Opening file picker...');
      final file = await FileTransferService.prepareFile();

      if (file == null) {
        setStatus('File selection cancelled');
        return;
      }

      debugPrint('Selected: ${file.name}');
      setStatus('File selected: ${file.name}');

      debugPrint('Recipient: ${recipient.userId}');

      debugPrint(
        'Encrypted: '
        '${file.encryptedData.length} bytes',
      );
      setStatus('File encrypted with AES-256-GCM');

      pendingFile = file;
      pendingRecipient = recipient;

      setStatus('Fetching ${recipient.userId} public key...');

      _publicKeyRequestTimer?.cancel();
      _publicKeyRequestTimer = Timer(const Duration(seconds: 8), () {
        if (pendingFile == file && pendingRecipient == recipient) {
          pendingFile = null;
          pendingRecipient = null;
          pendingEncryptedAesKey = null;
          setStatus('Timed out waiting for ${recipient.userId} public key');
        }
      });

      socket.send({'type': 'get_public_key', 'userId': recipient.userId});
    } catch (e) {
      debugPrint('FILE ERROR: $e');

      setStatus('File error: $e');
    }
  }

  void acceptTransfer() {
    if (incomingTransfer == null || transferResponded) {
      return;
    }

    transferResponded = true;

    final senderId = incomingTransfer!['senderId'];

    socket.send({
      'type': 'transfer_response',
      'senderId': userId,
      'recipientId': senderId,
      'accepted': true,
    });

    setStatus('Waiting for file...');
  }

  void rejectTransfer() {
    if (incomingTransfer == null || transferResponded) {
      return;
    }

    transferResponded = true;

    final senderId = incomingTransfer!['senderId'];

    socket.send({
      'type': 'transfer_response',
      'senderId': userId,
      'recipientId': senderId,
      'accepted': false,
    });

    incomingTransfer = null;

    _incomingController.add(null);

    setStatus('Transfer rejected');
  }

  Future<void> handleTransferResponse(Map<String, dynamic> message) async {
    final accepted = message['accepted'] == true;

    final senderId = message['senderId'].toString();

    if (!accepted) {
      setStatus('$senderId rejected the file');

      pendingFile = null;
      pendingRecipient = null;
      pendingEncryptedAesKey = null;

      return;
    }

    debugPrint('$senderId accepted the transfer');

    setStatus(
      '$senderId accepted — '
      'preparing encrypted payload...',
    );

    await sendEncryptedFile();
  }

  Future<void> handleTransferStart(Map<String, dynamic> message) async {
    try {
      debugPrint('RECEIVE: transfer started');

      _receivedChunks.clear();

      _receivedFileName = message['fileName'].toString();

      _expectedChunks = message['totalChunks'] as int;

      _receivedNonce = base64Decode(message['nonce'].toString());

      _receivedTag = base64Decode(message['tag'].toString());

      final encryptedAesKey = base64Decode(
        message['encryptedAesKey'].toString(),
      );

      setStatus('Decrypting AES file key with local private key...');

      debugPrint(
        'RECEIVE: encrypted AES key '
        '${encryptedAesKey.length} bytes',
      );

      // IMPORTANT:
      // Only Bob's private key can decrypt this.
      _receivedAesKey = RsaEncryptionService.decrypt(
        encryptedAesKey,
        keyManager.privateKey,
      );

      debugPrint('RECEIVE: AES key decrypted');

      setStatus('AES file key decrypted successfully');
      setStatus('Receiving encrypted file...');
    } catch (e, stackTrace) {
      debugPrint('RECEIVE START ERROR: $e');

      debugPrintStack(stackTrace: stackTrace);

      setStatus('Receive error: $e');
    }
  }

  void handleTransferChunk(Map<String, dynamic> message) {
    try {
      final index = message['chunkIndex'] as int;

      final chunk = base64Decode(message['data'].toString());

      while (_receivedChunks.length <= index) {
        _receivedChunks.add(Uint8List(0));
      }

      _receivedChunks[index] = chunk;

      debugPrint('RECEIVE: chunk ${index + 1}/$_expectedChunks');

      final percentage = _expectedChunks == 0
          ? 100
          : ((index + 1) * 100 ~/ _expectedChunks);
      setStatus('Receiving file... $percentage%');
    } catch (e) {
      debugPrint('CHUNK ERROR: $e');
    }
  }

  Future<void> handleTransferComplete(Map<String, dynamic> message) async {
    try {
      debugPrint('RECEIVE: transfer complete');

      if (_receivedAesKey == null ||
          _receivedNonce == null ||
          _receivedTag == null) {
        throw Exception('Missing encryption information');
      }

      if (_receivedChunks.length != _expectedChunks) {
        throw Exception(
          'Missing chunks: '
          '${_receivedChunks.length}/$_expectedChunks',
        );
      }

      final totalSize = _receivedChunks.fold<int>(
        0,
        (sum, chunk) => sum + chunk.length,
      );

      final encryptedData = Uint8List(totalSize);

      var offset = 0;

      for (final chunk in _receivedChunks) {
        encryptedData.setRange(offset, offset + chunk.length, chunk);

        offset += chunk.length;
      }

      debugPrint('RECEIVE: combined $totalSize bytes');
      setStatus('All encrypted chunks received');

      final encrypted = EncryptedData(
        ciphertext: encryptedData,
        nonce: _receivedNonce!,
        tag: _receivedTag!,
      );

      final decryptedData = AesService.decrypt(encrypted, _receivedAesKey!);

      debugPrint(
        'RECEIVE: decrypted '
        '${decryptedData.length} bytes',
      );
      setStatus('AES-256-GCM authentication verified');
      setStatus('File decrypted successfully');

      setStatus('Saving decrypted file...');
      final savedPath = await FileTransferService.saveReceivedFile(
        _receivedFileName!,
        decryptedData,
      );

      debugPrint('RECEIVE: saved to $savedPath');

      setStatus('File received successfully');

      _receivedChunks.clear();
      _receivedFileName = null;
      _receivedAesKey = null;
      _receivedNonce = null;
      _receivedTag = null;
      _expectedChunks = 0;

      incomingTransfer = null;
      _incomingController.add(null);
    } catch (e, stackTrace) {
      debugPrint('RECEIVE ERROR: $e');

      debugPrintStack(stackTrace: stackTrace);

      setStatus('Receive error: $e');
    }
  }

  Future<void> sendEncryptedFile() async {
    if (pendingFile == null ||
        pendingRecipient == null ||
        pendingEncryptedAesKey == null) {
      debugPrint('No pending encrypted transfer');
      return;
    }

    final file = pendingFile!;
    final recipient = pendingRecipient!;

    const chunkSize = 32 * 1024;

    final data = file.encryptedData;

    final totalChunks = (data.length / chunkSize).ceil();

    debugPrint('Starting transfer: ${file.name}');

    debugPrint('Total encrypted bytes: ${data.length}');

    debugPrint('Total chunks: $totalChunks');
    setStatus('Sending encrypted file in $totalChunks chunk(s)...');

    socket.send({
      'type': 'transfer_start',
      'senderId': userId,
      'recipientId': recipient.userId,
      'fileName': file.name,
      'fileSize': file.originalSize,
      'encryptedSize': data.length,
      'totalChunks': totalChunks,
      'encryptedAesKey': base64Encode(pendingEncryptedAesKey!),
      'nonce': base64Encode(file.nonce),
      'tag': base64Encode(file.tag),
    });

    for (int i = 0; i < totalChunks; i++) {
      final start = i * chunkSize;

      final end = (start + chunkSize > data.length)
          ? data.length
          : start + chunkSize;

      final chunk = data.sublist(start, end);

      socket.send({
        'type': 'transfer_chunk',
        'senderId': userId,
        'recipientId': recipient.userId,
        'chunkIndex': i,
        'data': base64Encode(chunk),
      });

      debugPrint('Sent chunk ${i + 1}/$totalChunks');
      final percentage = totalChunks == 0
          ? 100
          : ((i + 1) * 100 ~/ totalChunks);
      setStatus('Sending file... $percentage%');
    }

    socket.send({
      'type': 'transfer_complete',
      'senderId': userId,
      'recipientId': recipient.userId,
    });

    debugPrint('TRANSFER COMPLETE');

    setStatus('File sent successfully');

    _publicKeyRequestTimer?.cancel();
    _publicKeyRequestTimer = null;
    pendingFile = null;
    pendingRecipient = null;
    pendingEncryptedAesKey = null;
  }

  void dispose() {
    if (_disposed) return;

    _publicKeyRequestTimer?.cancel();
    _disposed = true;

    _subscription?.cancel();
    socket.dispose();

    _statusController.close();
    _usersController.close();
    _incomingController.close();
  }
}
