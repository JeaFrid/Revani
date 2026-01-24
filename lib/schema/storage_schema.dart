import 'package:revani/schema/data_schema.dart';
import 'package:revani/core/database_engine.dart';
import 'package:revani/core/storage_engine.dart';
import 'package:revani/model/print.dart';
import 'package:uuid/uuid.dart';

class StorageSchema {
  final Uuid uuid = const Uuid();
  final RevaniDatabase db;
  final RevaniStorageCore core;
  final DataSchemaProject projectSchema;

  StorageSchema(this.db)
    : core = RevaniStorageCore(),
      projectSchema = DataSchemaProject(db);

  void rebuildIndices() {}

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

  Future<DataResponse> getFilePath(String projectID, String fileId) async {
    final absolutePath = core.buildPath(projectID, fileId);
    return DataResponse(
      message: "Path found",
      error: "",
      status: StatusCodes.ok,
      data: {"path": absolutePath},
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

    try {
      await core.deleteFileRaw(projectID, fileId);
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
}
