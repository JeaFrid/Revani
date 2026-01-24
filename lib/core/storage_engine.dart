import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:revani/config.dart';

class RevaniStorageCore {
  final String _baseStoragePath;

  RevaniStorageCore() : _baseStoragePath = RevaniConfig.storagePath {
    _initDirectory();
  }

  void _initDirectory() {
    final dir = Directory(_baseStoragePath);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
  }

  bool validateFile(String fileName) {
    final ext = p.extension(fileName).toLowerCase();
    return RevaniConfig.allowedExtensions.contains(ext);
  }

  File getFileHandle(String projectID, String fileId) {
    final projectDir = Directory(p.join(_baseStoragePath, projectID));
    if (!projectDir.existsSync()) {
      projectDir.createSync(recursive: true);
    }
    return File(p.join(projectDir.path, fileId));
  }

  Future<void> deleteFileRaw(String projectID, String fileId) async {
    final file = getFileHandle(projectID, fileId);
    if (await file.exists()) {
      await file.delete();
    }
  }

  String buildPath(String projectID, String fileId) {
    return p.join(_baseStoragePath, projectID, fileId);
  }
}
