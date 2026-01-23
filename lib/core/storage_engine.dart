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
    return RevaniConfig.allowedExtensions.contains(ext);
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

  Future<Uint8List?> readFileRaw(String absolutePath) async {
    final file = File(absolutePath);
    if (await file.exists()) {
      return await file.readAsBytes();
    }
    return null;
  }

  Future<void> deleteFileRaw(String absolutePath) async {
    final file = File(absolutePath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<bool> optimizeImageRaw(String absolutePath) async {
    try {
      final file = File(absolutePath);
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

  String buildPath(String projectID, String fileId) {
    return p.join(_baseStoragePath, projectID, fileId);
  }
}
