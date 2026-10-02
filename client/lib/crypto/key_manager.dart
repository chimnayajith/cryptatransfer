import 'package:pointycastle/export.dart';

import 'rsa_service.dart';

class KeyManager {
  late final RSAPublicKey publicKey;
  late final RSAPrivateKey privateKey;

  Future<void> initialize() async {
    final pair = RsaService.generateKeyPair();

    publicKey = pair.publicKey;
    privateKey = pair.privateKey;
  }

  String get publicKeyBase64 {
    return RsaService.publicKeyToBase64(publicKey);
  }
}