import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

class EncryptedData {
  final Uint8List ciphertext;
  final Uint8List nonce;
  final Uint8List tag;

  EncryptedData({
    required this.ciphertext,
    required this.nonce,
    required this.tag,
  });
}

class AesService {
  static EncryptedData encrypt(
    Uint8List data,
    Uint8List key,
  ) {
    if (key.length != 32) {
      throw ArgumentError('AES-256 requires a 32-byte key');
    }

    final nonce = Uint8List.fromList(
      List.generate(
        12,
        (_) => Random.secure().nextInt(256),
      ),
    );

    final cipher = GCMBlockCipher(
      AESEngine(),
    );

    final params = AEADParameters(
      KeyParameter(key),
      128,
      nonce,
      Uint8List(0),
    );

    cipher.init(true, params);

    final output = cipher.process(data);

    final ciphertext = Uint8List(
      output.length - 16,
    );

    final tag = Uint8List(16);

    ciphertext.setRange(
      0,
      ciphertext.length,
      output,
    );

    tag.setRange(
      0,
      16,
      output,
      ciphertext.length,
    );

    return EncryptedData(
      ciphertext: ciphertext,
      nonce: nonce,
      tag: tag,
    );
  }

  static Uint8List decrypt(
    EncryptedData encrypted,
    Uint8List key,
  ) {
    if (key.length != 32) {
      throw ArgumentError('AES-256 requires a 32-byte key');
    }

    final cipher = GCMBlockCipher(
      AESEngine(),
    );

    final combined = Uint8List(
      encrypted.ciphertext.length + encrypted.tag.length,
    );

    combined.setRange(
      0,
      encrypted.ciphertext.length,
      encrypted.ciphertext,
    );

    combined.setRange(
      encrypted.ciphertext.length,
      combined.length,
      encrypted.tag,
    );

    final params = AEADParameters(
      KeyParameter(key),
      128,
      encrypted.nonce,
      Uint8List(0),
    );

    cipher.init(false, params);

    return cipher.process(combined);
  }

  static Uint8List generateKey() {
    return Uint8List.fromList(
      List.generate(
        32,
        (_) => Random.secure().nextInt(256),
      ),
    );
  }
}