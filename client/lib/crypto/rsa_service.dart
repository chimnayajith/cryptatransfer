import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

class RsaKeyPairData {
  final RSAPublicKey publicKey;
  final RSAPrivateKey privateKey;

  RsaKeyPairData({
    required this.publicKey,
    required this.privateKey,
  });
}

class RsaService {
  static SecureRandom _secureRandom() {
    final secureRandom = FortunaRandom();
    final random = Random.secure();

    final seed = Uint8List.fromList(
      List.generate(
        32,
        (_) => random.nextInt(256),
      ),
    );

    secureRandom.seed(KeyParameter(seed));

    return secureRandom;
  }

  static RsaKeyPairData generateKeyPair() {
    final generator = RSAKeyGenerator();

    generator.init(
      ParametersWithRandom(
        RSAKeyGeneratorParameters(
          BigInt.from(65537),
          2048,
          64,
        ),
        _secureRandom(),
      ),
    );

    final pair = generator.generateKeyPair();

    return RsaKeyPairData(
      publicKey: pair.publicKey as RSAPublicKey,
      privateKey: pair.privateKey as RSAPrivateKey,
    );
  }

  static String publicKeyToBase64(RSAPublicKey key) {
    final modulus = key.modulus;
    final exponent = key.exponent;

    if (modulus == null || exponent == null) {
      throw StateError('Invalid RSA public key');
    }

    final data = jsonEncode({
      'modulus': modulus.toString(),
      'exponent': exponent.toString(),
    });

    return base64Encode(utf8.encode(data));
  }

  static RSAPublicKey publicKeyFromBase64(String encoded) {
    final json = jsonDecode(
      utf8.decode(base64Decode(encoded)),
    );

    return RSAPublicKey(
      BigInt.parse(json['modulus'].toString()),
      BigInt.parse(json['exponent'].toString()),
    );
  }
}