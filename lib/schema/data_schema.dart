import 'dart:convert';
import 'package:revani/config.dart';
import 'package:revani/core/database_engine.dart';
import 'package:revani/model/print.dart';
import 'package:revani/tools/tokener.dart';
import 'package:uuid/uuid.dart';

class DataSchemaProject {
  static const String collectionTag = "project";
  static const String projectIndexTag = "idx_project_owner_name";

  final Uuid uuid = const Uuid();
  final RevaniDatabase db;

  DataSchemaProject(this.db);

  Future<DataResponse> createProject(
    String accountID,
    String projectName,
  ) async {
    final String compositeKey = "${accountID}_$projectName";
    final accountSchema = DataSchemaAccount(db, JeaTokener());
    final role = await accountSchema.getAccountRole(accountID);
    final limits = RevaniConfig.roleConfigs[role]!;
    final allProjects = db.getAll(collectionTag) ?? [];
    final userProjectCount = allProjects
        .where((p) => p.value['owner'] == accountID)
        .length;

    if (userProjectCount >= limits.maxProjects) {
      return DataResponse(
        message: "",
        error: "Project limit reached for role: $role",
        status: StatusCodes.forbidden,
      );
    }
    if (db.getIdByIndex(projectIndexTag, compositeKey) != null) {
      return DataResponse(
        message: "",
        error: "Project already exists",
        status: StatusCodes.conflict,
      );
    }

    final String randomId = uuid.v4();

    db.add(collectionTag, randomId, {
      "base": "project",
      "owner": accountID,
      "id": randomId,
      "name": projectName,
    });

    db.setIndex(projectIndexTag, compositeKey, randomId);

    return DataResponse(
      message: "Project Created",
      error: "",
      status: StatusCodes.ok,
      data: {"id": randomId, "name": projectName},
    );
  }

  Future<String?> existProject(String accountID, String projectName) async {
    final String compositeKey = "${accountID}_$projectName";
    return db.getIdByIndex(projectIndexTag, compositeKey);
  }
}

class DataSchemaAccount {
  static const String collectionTag = "account";
  static const String emailIndexTag = "idx_account_email";

  final Uuid uuid = const Uuid();
  final RevaniDatabase db;
  final JeaTokener tokener;

  DataSchemaAccount(this.db, this.tokener);

  Future<String> getAccountRole(String accountID) async {
    final result = db.get(collectionTag, accountID);
    if (result == null) return 'user';
    return result.value['role'] ?? 'user';
  }

  Future<DataResponse> createAccount(
    String email,
    String password,
    Map<String, dynamic> data,
  ) async {
    if (db.getIdByIndex(emailIndexTag, email) != null) {
      return DataResponse(
        message: "",
        error: "Email already exists",
        status: StatusCodes.conflict,
      );
    }

    final String randomId = uuid.v4();
    final String passwordHash = tokener.hashPassword(password);
    final String encryptedData = tokener.encryptStorage(jsonEncode(data));

    db.add(collectionTag, randomId, {
      "base": "account",
      "email": email,
      "password": passwordHash,
      "data": encryptedData,
      "role": "user",
      "id": randomId,
    });

    db.setIndex(emailIndexTag, email, randomId);

    return DataResponse(
      message: "Account Created",
      error: "",
      status: StatusCodes.ok,
      data: {"id": randomId, "email": email, "role": "user"},
    );
  }

  Future<DataResponse> getAccountID(String email, String password) async {
    final String? targetId = db.getIdByIndex(emailIndexTag, email);

    if (targetId == null) {
      return DataResponse(
        message: "",
        error: "Account not found",
        status: StatusCodes.notFound,
      );
    }

    final RevaniData? item = db.get(collectionTag, targetId);

    if (item != null) {
      final String storedHash = item.value["password"];
      final bool isValid = tokener.verifyPassword(password, storedHash);

      if (isValid) {
        return DataResponse(
          message: "ID found.",
          error: "",
          status: StatusCodes.ok,
          data: {"id": item.tag, "email": email},
        );
      }
    }

    return DataResponse(
      message: "",
      error: "Invalid credentials",
      status: StatusCodes.unauthorized,
    );
  }

  Future<DataResponse> getAccountDataWithID(String id) async {
    final result = db.get(collectionTag, id);

    if (result != null) {
      final Map<String, dynamic> userData = result.value;
      final String decryptedDataJson = tokener.decryptStorage(userData['data']);
      final Map<String, dynamic> decryptedData = jsonDecode(decryptedDataJson);

      return DataResponse(
        message: "Oki!",
        error: "",
        status: StatusCodes.ok,
        data: {"data": decryptedData, "email": userData['email']},
      );
    }

    return DataResponse(
      message: "",
      error: "Account not found",
      status: StatusCodes.notFound,
    );
  }
}

class DataSchemaData {
  static const String collectionTag = "data";
  static const String dataIndexTag = "idx_data_composite";

  final Uuid uuid = const Uuid();
  final RevaniDatabase db;
  final JeaTokener tokener;

  DataSchemaData(this.db, this.tokener);

  String _generateCompositeKey(String projectID, String bucket, String tag) {
    return "${projectID}_${bucket}_$tag";
  }

  Future<DataResponse> add(
    String accountID,
    String projectName,
    String bucket,
    String tag,
    Map<String, dynamic> value,
  ) async {
    DataSchemaProject projectSchema = DataSchemaProject(db);
    String? pId = await projectSchema.existProject(accountID, projectName);

    if (pId == null) {
      return DataResponse(
        message: "Project not found.",
        error: "Closed",
        status: StatusCodes.notFound,
      );
    }
    final accountSchema = DataSchemaAccount(db, tokener);
    final role = await accountSchema.getAccountRole(accountID);
    final limits = RevaniConfig.roleConfigs[role]!;

    final allData = db.getAll(collectionTag) ?? [];
    final userDataCount = allData
        .where((d) => d.value['projectId'] == pId)
        .length;

    if (userDataCount >= limits.maxDataEntries) {
      return DataResponse(
        message: "",
        error: "Data entry limit reached for role: $role",
        status: StatusCodes.forbidden,
      );
    }
    final String compositeKey = _generateCompositeKey(pId, bucket, tag);

    if (db.getIdByIndex(dataIndexTag, compositeKey) != null) {
      return DataResponse(
        message: "Data tag already exists in this bucket.",
        error: "Conflict",
        status: StatusCodes.conflict,
      );
    }

    final String entryId = uuid.v4();
    final String encryptedValue = tokener.encryptStorage(jsonEncode(value));

    db.add(collectionTag, entryId, {
      "base": "data",
      "projectId": pId,
      "bucket": bucket,
      "tag": tag,
      "value": encryptedValue,
      "id": entryId,
    });

    db.setIndex(dataIndexTag, compositeKey, entryId);

    return DataResponse(
      message: "Data added.",
      error: "",
      status: StatusCodes.ok,
      data: {"id": entryId},
    );
  }

  Future<DataResponse> get(String projectID, String bucket, String tag) async {
    final String compositeKey = _generateCompositeKey(projectID, bucket, tag);
    final String? targetId = db.getIdByIndex(dataIndexTag, compositeKey);

    if (targetId == null) {
      return DataResponse(
        message: "Data not found.",
        error: "Not Found",
        status: StatusCodes.notFound,
      );
    }

    final RevaniData? item = db.get(collectionTag, targetId);

    if (item != null) {
      final String encryptedValue = item.value["value"];
      final String decryptedValueJson = tokener.decryptStorage(encryptedValue);
      final dynamic decryptedValue = jsonDecode(decryptedValueJson);

      return DataResponse(
        message: "Success",
        error: "",
        status: StatusCodes.ok,
        data: decryptedValue,
      );
    }

    return DataResponse(
      message: "Data corrupted or missing.",
      error: "Not Found",
      status: StatusCodes.notFound,
    );
  }

  Future<DataResponse> delete(
    String projectID,
    String bucket,
    String tag,
  ) async {
    final String compositeKey = _generateCompositeKey(projectID, bucket, tag);
    final String? targetId = db.getIdByIndex(dataIndexTag, compositeKey);

    if (targetId == null) {
      return DataResponse(
        message: "Not found",
        error: "Not Found",
        status: StatusCodes.notFound,
      );
    }

    db.remove(collectionTag, targetId);
    db.removeIndex(dataIndexTag, compositeKey);

    return DataResponse(message: "Deleted.", error: "", status: StatusCodes.ok);
  }

  Future<DataResponse> update(
    String projectID,
    String bucket,
    String tag,
    dynamic newValue,
  ) async {
    final String compositeKey = _generateCompositeKey(projectID, bucket, tag);
    final String? targetId = db.getIdByIndex(dataIndexTag, compositeKey);

    if (targetId == null) {
      return DataResponse(
        message: "Not found",
        error: "Not Found",
        status: StatusCodes.notFound,
      );
    }

    final RevaniData? item = db.get(collectionTag, targetId);

    if (item == null) {
      return DataResponse(
        message: "Not found",
        error: "Not Found",
        status: StatusCodes.notFound,
      );
    }

    final String encryptedValue = tokener.encryptStorage(jsonEncode(newValue));
    final updatedData = Map<String, dynamic>.from(item.value);
    updatedData['value'] = encryptedValue;

    db.add(collectionTag, targetId, updatedData);

    return DataResponse(message: "Updated.", error: "", status: StatusCodes.ok);
  }
}
