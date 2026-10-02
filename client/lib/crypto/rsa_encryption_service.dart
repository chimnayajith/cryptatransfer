import 'dart:typed_data';

import 'package:pointycastle/export.dart';

class RsaEncryptionService {
  static Uint8List encrypt(
    Uint8List data,
    RSAPublicKey publicKey,
  ) {
    final cipher = OAEPEncoding(
      RSAEngine(),
    );

    cipher.init(
      true,
      PublicKeyParameter<RSAPublicKey>(publicKey),
    );

    return cipher.process(data);
  }

  static Uint8List decrypt(
    Uint8List encrypted,
    RSAPrivateKey privateKey,
  ) {
    final cipher = OAEPEncoding(
      RSAEngine(),
    );

    cipher.init(
      false,
      PrivateKeyParameter<RSAPrivateKey>(privateKey),
    );

    return cipher.process(encrypted);
  }
}