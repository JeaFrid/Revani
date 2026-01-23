import 'dart:typed_data';
import 'package:revani/config.dart';
import 'package:revani/schema/data_schema.dart';
import 'package:revani/core/database_engine.dart';
import 'package:revani/core/storage_engine.dart';
import 'package:revani/model/print.dart';
import 'package:revani/tools/tokener.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as p;

class StorageSchema {
  static const String collectionTag = "storage_meta";
  static const String storageIndexTag = "idx_storage_file";
  final Uuid uuid = const Uuid();
  final RevaniDatabase db;
  final RevaniStorageCore core;
  final DataSchemaProject projectSchema;
  StorageSchema(this.db)
    : core = RevaniStorageCore(),
      projectSchema = DataSchemaProject(db);
  void rebuildIndices() {
    final files = db.getAll(collectionTag);
    if (files == null) return;
    for (var f in files) {
      final id = f.value['id'];
      if (id != null) {
        db.setIndex(storageIndexTag, id, id);
      }
    }
  }

  Future<DataResponse> uploadFile(
    String accountID,
    String projectName,
    String fileName,
    List<int> rawData, {
    bool compressImage = false,
  }) async {
    final projectID = await projectSchema.existProject(accountID, projectName);
    if (projectID == null) {
      return DataResponse(
        message: "Project not found",
        error: "Not Found",
        status: StatusCodes.notFound,
      );
    }
    final accountSchema = DataSchemaAccount(db, JeaTokener());
    final role = await accountSchema.getAccountRole(accountID);
    final limits = RevaniConfig.roleConfigs[role]!;

    final allFiles = db.getAll(collectionTag) ?? [];
    final userFiles = allFiles.where((f) => f.value['project_id'] == projectID);

    int totalUsedBytes = 0;
    for (var f in userFiles) {
      totalUsedBytes += (f.value['size'] as int);
    }

    double totalUsedMB = totalUsedBytes / (1024 * 1024);
    if (totalUsedMB + (rawData.length / (1024 * 1024)) > limits.maxStorageMB) {
      return DataResponse(
        message: "",
        error: "Storage limit reached for role: $role",
        status: StatusCodes.insufficientStorage,
      );
    }
    if (!core.validateFile(fileName, rawData.length)) {
      return DataResponse(
        message: "Invalid file type or size limit exceeded",
        error: "Validation Failed",
        status: StatusCodes.notAcceptable,
      );
    }

    final fileId = uuid.v4();
    final ext = p.extension(fileName).toLowerCase();

    try {
      await core.saveFile(projectID, fileId, Uint8List.fromList(rawData));

      bool isCompressed = false;
      if (compressImage && _isImage(ext)) {
        isCompressed = await core.optimizeImage(projectID, fileId);
      }

      final fileMeta = {
        "id": fileId,
        "project_id": projectID,
        "original_name": fileName,
        "extension": ext,
        "size": rawData.length,
        "is_compressed": isCompressed,
        "created_at": DateTime.now().millisecondsSinceEpoch,
        "mime_type": _getMimeType(ext),
      };

      db.add(collectionTag, fileId, fileMeta);
      db.setIndex(storageIndexTag, fileId, fileId);

      return DataResponse(
        message: "File uploaded successfully",
        error: "",
        status: StatusCodes.ok,
        data: {"file_id": fileId, "compressed": isCompressed},
      );
    } catch (e) {
      return DataResponse(
        message: "Storage Write Error",
        error: e.toString(),
        status: StatusCodes.internalServerError,
      );
    }
  }

  Future<DataResponse> downloadFile(
    String accountID,
    String projectName,
    String fileId,
  ) async {
    final projectID = await projectSchema.existProject(accountID, projectName);
    if (projectID == null) {
      return DataResponse(
        message: "Project not found",
        error: "Not Found",
        status: StatusCodes.notFound,
      );
    }

    final RevaniData? metaData = db.get(collectionTag, fileId);

    if (metaData == null || metaData.value['project_id'] != projectID) {
      return DataResponse(
        message: "File not found or access denied",
        error: "Not Found",
        status: StatusCodes.notFound,
      );
    }

    final bytes = await core.readFile(projectID, fileId);

    if (bytes == null) {
      return DataResponse(
        message: "File binary missing from disk",
        error: "Corrupt Storage",
        status: StatusCodes.internalServerError,
      );
    }

    return DataResponse(
      message: "File retrieved",
      error: "",
      status: StatusCodes.ok,
      data: {"meta": metaData.value, "bytes": bytes},
    );
  }

  Future<DataResponse> deleteFile(
    String accountID,
    String projectName,
    String fileId,
  ) async {
    final projectID = await projectSchema.existProject(accountID, projectName);
    if (projectID == null) {
      return DataResponse(
        message: "Project not found",
        error: "Not Found",
        status: StatusCodes.notFound,
      );
    }

    final RevaniData? metaData = db.get(collectionTag, fileId);

    if (metaData == null || metaData.value['project_id'] != projectID) {
      return DataResponse(
        message: "File not found or access denied",
        error: "Not Found",
        status: StatusCodes.notFound,
      );
    }

    try {
      await core.deleteFile(projectID, fileId);
      db.remove(collectionTag, fileId);
      db.removeIndex(storageIndexTag, fileId);

      return DataResponse(
        message: "File deleted",
        error: "",
        status: StatusCodes.ok,
      );
    } catch (e) {
      return DataResponse(
        message: "Deletion failed",
        error: e.toString(),
        status: StatusCodes.internalServerError,
      );
    }
  }

  bool _isImage(String ext) {
    return ['.jpg', '.jpeg', '.png', '.webp', '.bmp'].contains(ext);
  }

  String _getMimeType(String ext) {
    switch (ext) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.gif':
        return 'image/gif';
      case '.pdf':
        return 'application/pdf';
      case '.json':
        return 'application/json';
      case '.mp4':
        return 'video/mp4';
      default:
        return 'application/octet-stream';
    }
  }
}
