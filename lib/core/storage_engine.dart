import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import 'package:image/image.dart' as img;
import 'package:revani/config.dart';

class RevaniStorageCore {
  final String _baseStoragePath;
  final int _maxFileSize;

  RevaniStorageCore()
    : _baseStoragePath = RevaniConfig.storagePath,
      _maxFileSize = RevaniConfig.maxFileSizeMB * 1024 * 1024 {
    _initDirectory();
  }

  void _initDirectory() {
    final dir = Directory(_baseStoragePath);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
  }

  bool validateFile(String fileName, int fileSize) {
    if (fileSize > _maxFileSize) return false;

    final ext = p.extension(fileName).toLowerCase();
    if (!RevaniConfig.allowedExtensions.contains(ext)) return false;

    return true;
  }

  Future<File> saveFile(String projectID, String fileId, Uint8List data) async {
    final projectDir = Directory(p.join(_baseStoragePath, projectID));
    if (!await projectDir.exists()) {
      await projectDir.create(recursive: true);
    }

    final filePath = p.join(projectDir.path, fileId);
    final file = File(filePath);
    return await file.writeAsBytes(data, flush: true);
  }

  Future<Uint8List?> readFile(String projectID, String fileId) async {
    final filePath = p.join(_baseStoragePath, projectID, fileId);
    final file = File(filePath);

    if (await file.exists()) {
      return await file.readAsBytes();
    }
    return null;
  }

  Future<void> deleteFile(String projectID, String fileId) async {
    final filePath = p.join(_baseStoragePath, projectID, fileId);
    final file = File(filePath);

    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<bool> optimizeImage(String projectID, String fileId) async {
    try {
      final filePath = p.join(_baseStoragePath, projectID, fileId);
      final file = File(filePath);

      if (!await file.exists()) return false;

      final bytes = await file.readAsBytes();
      final originalSize = bytes.length;

      final compressedBytes = await Isolate.run(() {
        final image = img.decodeImage(bytes);
        if (image == null) return null;
        return img.encodeJpg(image, quality: 75);
      });

      if (compressedBytes != null && compressedBytes.length < originalSize) {
        await file.writeAsBytes(compressedBytes, flush: true);
        return true;
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  String getStoragePath(String projectID, String fileId) {
    return p.join(_baseStoragePath, projectID, fileId);
  }
}
