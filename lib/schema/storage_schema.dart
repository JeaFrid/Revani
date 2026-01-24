import 'dart:typed_data';
import 'package:revani/schema/data_schema.dart';
import 'package:revani/core/database_engine.dart';
import 'package:revani/core/storage_engine.dart';
import 'package:revani/model/print.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as p;

class StorageSchema {
  static const String collectionTag = "storage_meta";
  static const String storageIndexTag = "idx_storage_file";

  final Uuid uuid = const Uuid();
  final RevaniDatabase db;
  final RevaniStorageCore core;
  final DataSchemaProject projectSchema;

  final Map<String, String> _pathCache = {};

  StorageSchema(this.db)
    : core = RevaniStorageCore(),
      projectSchema = DataSchemaProject(db);

  void rebuildIndices() {
    final files = db.getAll(collectionTag);
    if (files == null) return;
    for (var f in files) {
      final id = f.value['id'];
      final pId = f.value['project_id'];
      if (id != null && pId != null) {
        db.setIndex(storageIndexTag, id, id);
        _pathCache[id] = core.buildPath(pId, id);
      }
    }
  }

  Future<String?> resolveProjectID(
    String accountID,
    String projectNameOrId,
  ) async {
    String? projectID = await projectSchema.existProject(
      accountID,
      projectNameOrId,
    );
    if (projectID == null) {
      if (await projectSchema.isOwner(accountID, projectNameOrId)) {
        projectID = projectNameOrId;
      }
    }
    return projectID;
  }

  Future<DataResponse> registerUploadedFile(
    String accountID,
    String projectID,
    String fileId,
    String fileName,
    int size, {
    bool compressImage = false,
  }) async {
    final ext = p.extension(fileName).toLowerCase();
    final absolutePath = core.buildPath(projectID, fileId);

    try {
      bool isCompressed = false;
      if (compressImage && _isImage(ext)) {
        isCompressed = await core.optimizeImageRaw(absolutePath);
      }

      final fileMeta = {
        "id": fileId,
        "project_id": projectID,
        "original_name": fileName,
        "extension": ext,
        "size": size,
        "is_compressed": isCompressed,
        "created_at": DateTime.now().millisecondsSinceEpoch,
        "mime_type": _getMimeType(ext),
      };

      db.add(collectionTag, fileId, fileMeta);
      db.setIndex(storageIndexTag, fileId, fileId);
      _pathCache[fileId] = absolutePath;

      return DataResponse(
        message: "File uploaded successfully",
        error: "",
        status: StatusCodes.ok,
        data: {"file_id": fileId, "compressed": isCompressed},
      );
    } catch (e) {
      return DataResponse(
        message: "Storage Registration Error",
        error: e.toString(),
        status: StatusCodes.internalServerError,
      );
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

    if (!core.validateFile(fileName, rawData.length)) {
      return DataResponse(
        message: "Invalid file type or size limit exceeded",
        error: "Validation Failed",
        status: StatusCodes.notAcceptable,
      );
    }

    final fileId = uuid.v4();
    try {
      await core.saveFile(projectID, fileId, Uint8List.fromList(rawData));
      return await registerUploadedFile(
        accountID,
        projectID,
        fileId,
        fileName,
        rawData.length,
        compressImage: compressImage,
      );
    } catch (e) {
      return DataResponse(
        message: "Storage Write Error",
        error: e.toString(),
        status: StatusCodes.internalServerError,
      );
    }
  }

  Future<DataResponse> getFilePath(
    String accountID,
    String projectNameOrId,
    String fileId,
  ) async {
    final projectID = await resolveProjectID(accountID, projectNameOrId);
    if (projectID == null) {
      return DataResponse(
        message: "Project not found",
        error: "Not Found",
        status: StatusCodes.notFound,
      );
    }

    final absolutePath = _pathCache[fileId];
    if (absolutePath == null) {
      return DataResponse(
        message: "File path not in cache",
        error: "Not Found",
        status: StatusCodes.notFound,
      );
    }

    return DataResponse(
      message: "Path found",
      error: "",
      status: StatusCodes.ok,
      data: {"path": absolutePath},
    );
  }

  Future<DataResponse> downloadFile(
    String accountID,
    String projectNameOrId,
    String fileId,
  ) async {
    final res = await getFilePath(accountID, projectNameOrId, fileId);
    if (res.status != StatusCodes.ok) return res;

    final bytes = await core.readFileRaw(res.data['path']);
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
      data: {"bytes": bytes},
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

    final absolutePath = _pathCache[fileId];
    if (absolutePath != null) {
      try {
        await core.deleteFileRaw(absolutePath);
        db.remove(collectionTag, fileId);
        db.removeIndex(storageIndexTag, fileId);
        _pathCache.remove(fileId);

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
    return DataResponse(
      message: "File not found",
      error: "Not Found",
      status: StatusCodes.notFound,
    );
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
