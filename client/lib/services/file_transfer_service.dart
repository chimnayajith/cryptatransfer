import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import '../crypto/aes_service.dart';

class PreparedFile {
  final String name;
  final Uint8List encryptedData;
  final Uint8List key;
  final Uint8List nonce;
  final Uint8List tag;
  final int originalSize;

  PreparedFile({
    required this.name,
    required this.encryptedData,
    required this.key,
    required this.nonce,
    required this.tag,
    required this.originalSize,
  });
}

class FileTransferService {
  static Future<PreparedFile?> prepareFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      withData: true,
    );

    if (result == null) {
      return null;
    }

    final file = result.files.single;
    final bytes = file.bytes;

    if (bytes == null) {
      throw Exception('Unable to read selected file');
    }

    final key = AesService.generateKey();

    final encrypted = AesService.encrypt(
      bytes,
      key,
    );

    return PreparedFile(
      name: file.name,
      encryptedData: encrypted.ciphertext,
      key: key,
      nonce: encrypted.nonce,
      tag: encrypted.tag,
      originalSize: bytes.length,
    );
  }

  static Future<String?> saveReceivedFile(
    String fileName,
    Uint8List data,
  ) async {
    final path = await FilePicker.platform.saveFile(
      fileName: fileName,
      bytes: data,
    );

    return path;
  }
}