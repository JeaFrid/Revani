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
  void rebuildIndices() {
    final projects = db.getAll(collectionTag);
    if (projects == null) return;
    for (var p in projects) {
      final owner = p.value['owner'];
      final name = p.value['name'];
      final id = p.value['id'];
      if (owner != null && name != null && id != null) {
        final String compositeKey = "${owner}_$name";
        db.setIndex(projectIndexTag, compositeKey, id);
      }
    }
  }

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

  Future<bool> isOwner(String accountID, String projectID) async {
    final project = db.get(collectionTag, projectID);
    if (project == null) return false;
    return project.value['owner'] == accountID;
  }
}

class DataSchemaAccount {
  static const String collectionTag = "account";
  static const String emailIndexTag = "idx_account_email";
  final Uuid uuid = const Uuid();
  final RevaniDatabase db;
  final JeaTokener tokener;
  final DataSchemaSession sessionSchema;
  DataSchemaAccount(this.db, this.tokener)
    : sessionSchema = DataSchemaSession(db);
  void rebuildIndices() {
    final users = db.getAll(collectionTag);
    if (users == null) return;
    for (var u in users) {
      final email = u.value['email'];
      final id = u.value['id'];
      if (email != null && id != null) {
        db.setIndex(emailIndexTag, email, id);
      }
    }
  }

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
    final allUsers = db.getAll(collectionTag);
    bool hasAdmin = false;

    if (allUsers != null && allUsers.isNotEmpty) {
      hasAdmin = allUsers.any((u) => u.value['role'] == 'admin');
    }

    final String role = !hasAdmin ? 'admin' : 'user';

    final String randomId = uuid.v4();
    final String passwordHash = tokener.hashPassword(password);
    final String encryptedData = tokener.encryptStorage(jsonEncode(data));

    db.add(collectionTag, randomId, {
      "base": "account",
      "email": email,
      "password": passwordHash,
      "data": encryptedData,
      "role": role,
      "id": randomId,
    });

    db.setIndex(emailIndexTag, email, randomId);

    return DataResponse(
      message: !hasAdmin
          ? "System claimed! First ADMIN account created."
          : "Account Created",
      error: "",
      status: StatusCodes.ok,
      data: {"id": randomId, "email": email, "role": role},
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
        final token = await sessionSchema.createSession(
          targetId,
          null,
          'account',
        );
        return DataResponse(
          message: "ID found.",
          error: "",
          status: StatusCodes.ok,
          data: {"id": item.tag, "email": email, "token": token},
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
  void rebuildIndices() {
    final dataList = db.getAll(collectionTag);
    if (dataList == null) return;
    for (var d in dataList) {
      final pId = d.value['projectId'];
      final bucket = d.value['bucket'];
      final tag = d.value['tag'];
      final id = d.value['id'];

      if (pId != null && bucket != null && tag != null && id != null) {
        final compositeKey = generateCompositeKey(pId, bucket, tag);
        db.setIndex(dataIndexTag, compositeKey, id);
      }
    }
  }

  String generateCompositeKey(String projectID, String bucket, String tag) {
    return "${projectID}_${bucket}$tag";
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
    final String compositeKey = generateCompositeKey(pId, bucket, tag);

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
    }, projectId: pId);

    db.setIndex(dataIndexTag, compositeKey, entryId);

    return DataResponse(
      message: "Data added.",
      error: "",
      status: StatusCodes.ok,
      data: {"id": entryId},
    );
  }

  Future<DataResponse> addAll(
    String accountID,
    String projectName,
    String bucket,
    Map<String, Map<String, dynamic>> items,
  ) async {
    DataSchemaProject projectSchema = DataSchemaProject(db);
    String? pId = await projectSchema.existProject(accountID, projectName);
    if (pId == null) {
      return DataResponse(
        message: "",
        error: "Project not found",
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

    if (userDataCount + items.length > limits.maxDataEntries) {
      return DataResponse(
        message: "",
        error: "Operation would exceed data limit for role: $role",
        status: StatusCodes.forbidden,
      );
    }

    final Map<String, Map<String, dynamic>> batchToStore = {};
    final List<String> compositeKeysToSet = [];
    final List<String> newIds = [];

    for (var entry in items.entries) {
      final String tag = entry.key;
      final String compositeKey = generateCompositeKey(pId, bucket, tag);

      if (db.getIdByIndex(dataIndexTag, compositeKey) != null) {
        continue;
      }

      final String entryId = uuid.v4();
      final String encryptedValue = tokener.encryptStorage(
        jsonEncode(entry.value),
      );

      batchToStore[entryId] = {
        "base": "data",
        "projectId": pId,
        "bucket": bucket,
        "tag": tag,
        "value": encryptedValue,
        "id": entryId,
      };

      compositeKeysToSet.add(compositeKey);
      newIds.add(entryId);
    }

    if (batchToStore.isNotEmpty) {
      db.addAll(collectionTag, batchToStore);

      int i = 0;
      batchToStore.forEach((id, data) {
        db.setIndex(dataIndexTag, compositeKeysToSet[i], id);
        i++;
      });
    }

    return DataResponse(
      message: "Batch operation completed. Added: ${newIds.length}",
      error: "",
      status: StatusCodes.ok,
      data: {"count": newIds.length, "ids": newIds},
    );
  }

  Future<DataResponse> get(
    String accountID,
    String projectID,
    String bucket,
    String tag,
  ) async {
    final projectSchema = DataSchemaProject(db);
    if (!(await projectSchema.isOwner(accountID, projectID))) {
      return DataResponse(
        message: "Access Denied",
        error: "Identity Mismatch",
        status: StatusCodes.forbidden,
      );
    }

    final String compositeKey = generateCompositeKey(projectID, bucket, tag);
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

  Future<DataResponse> getAll(
    String accountID,
    String projectID,
    String bucket,
  ) async {
    final projectSchema = DataSchemaProject(db);
    if (!(await projectSchema.isOwner(accountID, projectID))) {
      return DataResponse(
        message: "Access Denied",
        error: "Identity Mismatch",
        status: StatusCodes.forbidden,
      );
    }

    final allData = db.getAll(collectionTag);
    if (allData == null) {
      return DataResponse(
        message: "Success",
        error: "",
        status: StatusCodes.ok,
        data: [],
      );
    }
    final projectData = allData
        .where(
          (d) =>
              d.value['projectId'] == projectID && d.value['bucket'] == bucket,
        )
        .toList();

    final List<Map<String, dynamic>> resultList = [];

    for (var item in projectData) {
      try {
        final String encryptedValue = item.value["value"];
        final String decryptedValueJson = tokener.decryptStorage(
          encryptedValue,
        );
        resultList.add({
          "tag": item.value["tag"],
          "value": jsonDecode(decryptedValueJson),
          "created_at": item.createdAt,
        });
      } catch (e) {
        continue;
      }
    }

    return DataResponse(
      message: "Success",
      error: "",
      status: StatusCodes.ok,
      data: resultList,
    );
  }

  Future<DataResponse> delete(
    String accountID,
    String projectID,
    String bucket,
    String tag,
  ) async {
    final projectSchema = DataSchemaProject(db);
    if (!(await projectSchema.isOwner(accountID, projectID))) {
      return DataResponse(
        message: "Access Denied",
        error: "Identity Mismatch",
        status: StatusCodes.forbidden,
      );
    }

    final String compositeKey = generateCompositeKey(projectID, bucket, tag);
    final String? targetId = db.getIdByIndex(dataIndexTag, compositeKey);
    if (targetId == null) {
      return DataResponse(
        message: "Not found",
        error: "Not Found",
        status: StatusCodes.notFound,
      );
    }

    db.remove(collectionTag, targetId, projectId: projectID);
    db.removeIndex(dataIndexTag, compositeKey);

    return DataResponse(message: "Deleted.", error: "", status: StatusCodes.ok);
  }

  Future<DataResponse> deleteAll(
    String accountID,
    String projectID,
    String bucket,
  ) async {
    final projectSchema = DataSchemaProject(db);
    if (!(await projectSchema.isOwner(accountID, projectID))) {
      return DataResponse(
        message: "Access Denied",
        error: "Identity Mismatch",
        status: StatusCodes.forbidden,
      );
    }

    final allData = db.getAll(collectionTag);
    if (allData == null) {
      return DataResponse(
        message: "Bucket already empty.",
        error: "",
        status: StatusCodes.ok,
      );
    }
    final targets = allData
        .where(
          (d) =>
              d.value['projectId'] == projectID && d.value['bucket'] == bucket,
        )
        .toList();

    for (var item in targets) {
      final String tag = item.value['tag'];
      final String compositeKey = generateCompositeKey(projectID, bucket, tag);
      db.remove(collectionTag, item.tag);
      db.removeIndex(dataIndexTag, compositeKey);
    }

    return DataResponse(
      message:
          "All data in bucket '$bucket' for project '$projectID' deleted. Count: ${targets.length}",
      error: "",
      status: StatusCodes.ok,
    );
  }

  Future<DataResponse> update(
    String accountID,
    String projectID,
    String bucket,
    String tag,
    dynamic newValue,
  ) async {
    final projectSchema = DataSchemaProject(db);
    if (!(await projectSchema.isOwner(accountID, projectID))) {
      return DataResponse(
        message: "Access Denied",
        error: "Identity Mismatch",
        status: StatusCodes.forbidden,
      );
    }

    final String compositeKey = generateCompositeKey(projectID, bucket, tag);
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

    db.add(collectionTag, targetId, updatedData, projectId: projectID);

    return DataResponse(message: "Updated.", error: "", status: StatusCodes.ok);
  }
}

class DataSchemaUser {
  static const String collectionTag = "sys_users";
  static const String userIndexTag = "idx_sys_user_email";
  final RevaniDatabase db;
  final JeaTokener tokener;
  final DataSchemaProject projectSchema;
  final Uuid uuid = const Uuid();
  final DataSchemaSession sessionSchema;
  DataSchemaUser(this.db, this.tokener)
    : projectSchema = DataSchemaProject(db),
      sessionSchema = DataSchemaSession(db);
  void rebuildIndices() {
    final users = db.getAll(collectionTag);
    if (users == null) return;
    for (var u in users) {
      final pid = u.value['project_id'];
      final email = u.value['email'];
      final id = u.value['id'];
      if (pid != null && email != null && id != null) {
        db.setIndex(userIndexTag, "${pid}_$email", id);
      }
    }
  }

  Future<DataResponse> register(
    String accountID,
    String projectName,
    Map<String, dynamic> userData,
  ) async {
    final pId = await projectSchema.existProject(accountID, projectName);
    if (pId == null) {
      return DataResponse(
        message: "",
        error: "Project not found",
        status: StatusCodes.notFound,
      );
    }
    final email = userData['email'];
    final password = userData['password'];

    if (email == null || password == null) {
      return DataResponse(
        message: "",
        error: "Email and password required",
        status: StatusCodes.badRequest,
      );
    }

    final composite = "${pId}_$email";
    if (db.getIdByIndex(userIndexTag, composite) != null) {
      return DataResponse(
        message: "",
        error: "User already exists",
        status: StatusCodes.conflict,
      );
    }

    final userId = uuid.v4();
    final passwordHash = tokener.hashPassword(password);

    final userRecord = {
      "id": userId,
      "project_id": pId,
      "email": email,
      "password_hash": passwordHash,
      "name": userData['name'] ?? "",
      "bio": userData['bio'] ?? "",
      "age": userData['age'] ?? 0,
      "profile_photo": userData['profile_photo'] ?? "",
      "device_id": userData['device_id'] ?? "",
      "ip_address": userData['ip_address'] ?? "",
      "device_os": userData['device_os'] ?? "",
      "is_verified": false,
      "custom_data": userData['data'] ?? {},
      "created_at": DateTime.now().millisecondsSinceEpoch,
    };

    db.add(collectionTag, userId, userRecord);
    db.setIndex(userIndexTag, composite, userId);

    return DataResponse(
      message: "User registered",
      error: "",
      status: StatusCodes.created,
      data: {"user_id": userId},
    );
  }

  Future<DataResponse> login(
    String accountID,
    String projectName,
    String email,
    String password,
  ) async {
    final pId = await projectSchema.existProject(accountID, projectName);
    if (pId == null) {
      return DataResponse(
        message: "",
        error: "Project not found",
        status: StatusCodes.notFound,
      );
    }
    final composite = "${pId}_$email";
    final userId = db.getIdByIndex(userIndexTag, composite);

    if (userId == null) {
      return DataResponse(
        message: "",
        error: "User not found",
        status: StatusCodes.notFound,
      );
    }

    final data = db.get(collectionTag, userId);
    if (data == null) {
      return DataResponse(
        message: "",
        error: "Corrupt data",
        status: StatusCodes.internalServerError,
      );
    }

    final storedHash = data.value['password_hash'];
    if (tokener.verifyPassword(password, storedHash)) {
      final safeProfile = Map<String, dynamic>.from(data.value);
      safeProfile.remove('password_hash');

      final token = await sessionSchema.createSession(userId, pId, 'user');
      safeProfile['token'] = token;

      return DataResponse(
        message: "Login successful",
        error: "",
        status: StatusCodes.ok,
        data: safeProfile,
      );
    }

    return DataResponse(
      message: "",
      error: "Invalid credentials",
      status: StatusCodes.unauthorized,
    );
  }

  Future<DataResponse> getProfile(
    String accountID,
    String projectName,
    String userId,
  ) async {
    final pId = await projectSchema.existProject(accountID, projectName);
    if (pId == null) {
      return DataResponse(
        message: "",
        error: "Project not found",
        status: StatusCodes.notFound,
      );
    }
    final data = db.get(collectionTag, userId);
    if (data == null) {
      return DataResponse(
        message: "",
        error: "User not found",
        status: StatusCodes.notFound,
      );
    }

    if (data.value['project_id'] != pId) {
      return DataResponse(
        message: "",
        error: "User does not belong to this project",
        status: StatusCodes.forbidden,
      );
    }

    final safeProfile = Map<String, dynamic>.from(data.value);
    safeProfile.remove('password_hash');
    return DataResponse(
      message: "Success",
      error: "",
      status: StatusCodes.ok,
      data: safeProfile,
    );
  }

  Future<DataResponse> editProfile(
    String userId,
    Map<String, dynamic> updates,
  ) async {
    final data = db.get(collectionTag, userId);
    if (data == null) {
      return DataResponse(
        message: "",
        error: "User not found",
        status: StatusCodes.notFound,
      );
    }
    final current = Map<String, dynamic>.from(data.value);

    updates.remove('id');
    updates.remove('project_id');
    updates.remove('password_hash');
    updates.remove('email');

    current.addAll(updates);
    db.add(collectionTag, userId, current);

    return DataResponse(
      message: "Profile updated",
      error: "",
      status: StatusCodes.ok,
    );
  }

  Future<DataResponse> changePassword(
    String userId,
    String oldPass,
    String newPass,
  ) async {
    final data = db.get(collectionTag, userId);
    if (data == null) {
      return DataResponse(
        message: "",
        error: "User not found",
        status: StatusCodes.notFound,
      );
    }
    final current = Map<String, dynamic>.from(data.value);
    if (!tokener.verifyPassword(oldPass, current['password_hash'])) {
      return DataResponse(
        message: "",
        error: "Old password incorrect",
        status: StatusCodes.unauthorized,
      );
    }

    current['password_hash'] = tokener.hashPassword(newPass);
    db.add(collectionTag, userId, current);

    return DataResponse(
      message: "Password changed",
      error: "",
      status: StatusCodes.ok,
    );
  }
}

class DataSchemaSession {
  static const String collectionTag = "sys_sessions";
  final RevaniDatabase db;
  final Uuid uuid = const Uuid();

  DataSchemaSession(this.db);
  void rebuildIndices() {
    final sessions = db.getAll(collectionTag);
    if (sessions == null) return;
    for (var s in sessions) {
      final token = s.value['token'];
      if (token != null) {}
    }
  }

  Future<String> createSession(
    String userId,
    String? projectId,
    String type,
  ) async {
    final token = uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;
    final expiresAt = now + RevaniConfig.tokenHotTtl.inMilliseconds;

    final sessionData = {
      "token": token,
      "user_id": userId,
      "project_id": projectId,
      "type": type,
      "created_at": now,
      "expires_at": expiresAt,
    };

    db.add(collectionTag, token, sessionData, ttl: RevaniConfig.tokenHotTtl);

    return token;
  }

  Future<DataResponse> verifyToken(String token) async {
    final session = db.get(collectionTag, token);

    if (session == null) {
      return DataResponse(
        message: "",
        error: "Session expired or invalid",
        status: StatusCodes.unauthorized,
      );
    }

    final data = Map<String, dynamic>.from(session.value);
    final now = DateTime.now().millisecondsSinceEpoch;
    final newExpiresAt = now + RevaniConfig.tokenHotTtl.inMilliseconds;

    data['expires_at'] = newExpiresAt;

    db.add(collectionTag, token, data, ttl: RevaniConfig.tokenHotTtl);

    return DataResponse(
      message: "Session verified and heated",
      error: "",
      status: StatusCodes.ok,
      data: data,
    );
  }
}

class DataSchemaSocial {
  static const String bucketPost = "sys_posts";
  static const String bucketComment = "sys_comments";
  final RevaniDatabase db;
  final DataSchemaProject projectSchema;
  final Uuid uuid = const Uuid();
  DataSchemaSocial(this.db) : projectSchema = DataSchemaProject(db);
  Future<DataResponse> createPost(
    String accountID,
    String projectName,
    Map<String, dynamic> postData,
  ) async {
    final pId = await projectSchema.existProject(accountID, projectName);
    if (pId == null) {
      return DataResponse(
        message: "",
        error: "Project not found",
        status: StatusCodes.notFound,
      );
    }
    final text = postData['text'];
    if (text == null || (text as String).isEmpty) {
      return DataResponse(
        message: "",
        error: "Text is mandatory",
        status: StatusCodes.badRequest,
      );
    }

    final images = postData['images'] as List?;
    if (images != null && images.length > 10) {
      return DataResponse(
        message: "",
        error: "Max 10 images allowed",
        status: StatusCodes.badRequest,
      );
    }

    final postId = uuid.v4();
    final newPost = {
      "id": postId,
      "project_id": pId,
      "user_id": postData['user_id'],
      "text": text,
      "images": images ?? [],
      "video": postData['video'],
      "documents": postData['documents'] ?? [],
      "likes": [],
      "views": 0,
      "created_at": DateTime.now().millisecondsSinceEpoch,
    };

    db.add(bucketPost, postId, newPost);

    return DataResponse(
      message: "Post created",
      error: "",
      status: StatusCodes.created,
      data: {"post_id": postId},
    );
  }

  Future<DataResponse> toggleLike(
    String postId,
    String userId,
    bool isLike,
  ) async {
    final post = db.get(bucketPost, postId);
    if (post == null) {
      return DataResponse(
        message: "",
        error: "Post not found",
        status: StatusCodes.notFound,
      );
    }
    final data = Map<String, dynamic>.from(post.value);
    final List<dynamic> likes = List.from(data['likes'] ?? []);

    if (isLike) {
      if (!likes.contains(userId)) likes.add(userId);
    } else {
      likes.remove(userId);
    }

    data['likes'] = likes;
    db.add(bucketPost, postId, data);

    return DataResponse(
      message: "Like updated",
      error: "",
      status: StatusCodes.ok,
      data: {"count": likes.length},
    );
  }

  Future<DataResponse> addView(String postId) async {
    final post = db.get(bucketPost, postId);
    if (post == null) {
      return DataResponse(
        message: "",
        error: "Post not found",
        status: StatusCodes.notFound,
      );
    }
    final data = Map<String, dynamic>.from(post.value);
    data['views'] = (data['views'] ?? 0) + 1;
    db.add(bucketPost, postId, data);

    return DataResponse(
      message: "View added",
      error: "",
      status: StatusCodes.ok,
      data: {"views": data['views']},
    );
  }

  Future<DataResponse> getPost(String postId) async {
    final post = db.get(bucketPost, postId);
    if (post == null) {
      return DataResponse(
        message: "",
        error: "Post not found",
        status: StatusCodes.notFound,
      );
    }
    return DataResponse(
      message: "Success",
      error: "",
      status: StatusCodes.ok,
      data: post.value,
    );
  }

  Future<DataResponse> addComment(
    String postId,
    String userId,
    String text,
  ) async {
    final post = db.get(bucketPost, postId);
    if (post == null) {
      return DataResponse(
        message: "",
        error: "Post not found",
        status: StatusCodes.notFound,
      );
    }
    if (text.isEmpty) {
      return DataResponse(
        message: "",
        error: "Comment cannot be empty",
        status: StatusCodes.badRequest,
      );
    }

    final commentId = uuid.v4();
    final comment = {
      "id": commentId,
      "post_id": postId,
      "user_id": userId,
      "text": text,
      "likes": [],
      "created_at": DateTime.now().millisecondsSinceEpoch,
    };

    db.add(bucketComment, commentId, comment);

    return DataResponse(
      message: "Comment added",
      error: "",
      status: StatusCodes.created,
      data: {"comment_id": commentId},
    );
  }

  Future<DataResponse> getComments(String postId) async {
    final allComments = db.getAll(bucketComment);
    if (allComments == null) {
      return DataResponse(
        message: "No comments",
        error: "",
        status: StatusCodes.ok,
        data: [],
      );
    }
    final comments = allComments
        .where((c) => c.value['post_id'] == postId)
        .map((c) => c.value)
        .toList();

    comments.sort((a, b) => b['created_at'].compareTo(a['created_at']));

    return DataResponse(
      message: "Success",
      error: "",
      status: StatusCodes.ok,
      data: comments,
    );
  }

  Future<DataResponse> toggleCommentLike(
    String commentId,
    String userId,
    bool isLike,
  ) async {
    final comment = db.get(bucketComment, commentId);
    if (comment == null) {
      return DataResponse(
        message: "",
        error: "Comment not found",
        status: StatusCodes.notFound,
      );
    }
    final data = Map<String, dynamic>.from(comment.value);
    final List<dynamic> likes = List.from(data['likes'] ?? []);

    if (isLike) {
      if (!likes.contains(userId)) likes.add(userId);
    } else {
      likes.remove(userId);
    }

    data['likes'] = likes;
    db.add(bucketComment, commentId, data);

    return DataResponse(
      message: "Comment like updated",
      error: "",
      status: StatusCodes.ok,
      data: {"count": likes.length},
    );
  }
}

class DataSchemaMessaging {
  static const String bucketChat = "sys_chats";
  static const String bucketMessage = "sys_messages";
  final RevaniDatabase db;
  final DataSchemaProject projectSchema;
  final Uuid uuid = const Uuid();
  DataSchemaMessaging(this.db) : projectSchema = DataSchemaProject(db);
  Future<DataResponse> createChat(
    String accountID,
    String projectName,
    List<String> participants,
  ) async {
    final pId = await projectSchema.existProject(accountID, projectName);
    if (pId == null) {
      return DataResponse(
        message: "",
        error: "Project not found",
        status: StatusCodes.notFound,
      );
    }
    if (participants.length < 2) {
      return DataResponse(
        message: "",
        error: "At least 2 participants required",
        status: StatusCodes.badRequest,
      );
    }

    final chatId = uuid.v4();
    final newChat = {
      "id": chatId,
      "project_id": pId,
      "participants": participants,
      "created_at": DateTime.now().millisecondsSinceEpoch,
      "last_message_at": DateTime.now().millisecondsSinceEpoch,
    };

    db.add(bucketChat, chatId, newChat);

    return DataResponse(
      message: "Chat created",
      error: "",
      status: StatusCodes.created,
      data: {"chat_id": chatId},
    );
  }

  Future<DataResponse> getChats(
    String accountID,
    String projectName,
    String userId,
  ) async {
    final pId = await projectSchema.existProject(accountID, projectName);
    if (pId == null) {
      return DataResponse(
        message: "",
        error: "Project not found",
        status: StatusCodes.notFound,
      );
    }
    final allChats = db.getAll(bucketChat);
    if (allChats == null) {
      return DataResponse(
        message: "No chats",
        error: "",
        status: StatusCodes.ok,
        data: [],
      );
    }

    final userChats = allChats
        .where(
          (c) =>
              c.value['project_id'] == pId &&
              (c.value['participants'] as List).contains(userId),
        )
        .map((c) => c.value)
        .toList();

    userChats.sort(
      (a, b) => b['last_message_at'].compareTo(a['last_message_at']),
    );

    return DataResponse(
      message: "Success",
      error: "",
      status: StatusCodes.ok,
      data: userChats,
    );
  }

  Future<DataResponse> deleteChat(String chatId) async {
    final chat = db.get(bucketChat, chatId);
    if (chat == null) {
      return DataResponse(
        message: "",
        error: "Chat not found",
        status: StatusCodes.notFound,
      );
    }
    db.remove(bucketChat, chatId);

    final allMessages = db.getAll(bucketMessage);
    if (allMessages != null) {
      for (var m in allMessages) {
        if (m.value['chat_id'] == chatId) {
          db.remove(bucketMessage, m.tag);
        }
      }
    }

    return DataResponse(
      message: "Chat and messages deleted",
      error: "",
      status: StatusCodes.ok,
    );
  }

  Future<DataResponse> sendMessage(
    String chatId,
    String senderId,
    Map<String, dynamic> messageData,
  ) async {
    final chat = db.get(bucketChat, chatId);
    if (chat == null) {
      return DataResponse(
        message: "",
        error: "Chat not found",
        status: StatusCodes.notFound,
      );
    }
    final messageId = uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;

    final newMessage = {
      "id": messageId,
      "chat_id": chatId,
      "sender_id": senderId,
      "text": messageData['text'] ?? "",
      "image": messageData['image'],
      "video": messageData['video'],
      "custom": messageData['custom'],
      "reactions": {},
      "reply_to": messageData['reply_to'],
      "forwarded_from": messageData['forwarded_from'],
      "is_pinned": false,
      "created_at": now,
      "updated_at": now,
    };

    db.add(bucketMessage, messageId, newMessage);

    final chatData = Map<String, dynamic>.from(chat.value);
    chatData['last_message_at'] = now;
    db.add(bucketChat, chatId, chatData);

    return DataResponse(
      message: "Message sent",
      error: "",
      status: StatusCodes.created,
      data: {"message_id": messageId},
    );
  }

  Future<DataResponse> getMessages(String chatId) async {
    final allMessages = db.getAll(bucketMessage);
    if (allMessages == null) {
      return DataResponse(
        message: "No messages",
        error: "",
        status: StatusCodes.ok,
        data: [],
      );
    }
    final messages = allMessages
        .where((m) => m.value['chat_id'] == chatId)
        .map((m) => m.value)
        .toList();

    messages.sort((a, b) => a['created_at'].compareTo(b['created_at']));

    return DataResponse(
      message: "Success",
      error: "",
      status: StatusCodes.ok,
      data: messages,
    );
  }

  Future<DataResponse> updateMessage(
    String messageId,
    String senderId,
    String newText,
  ) async {
    final msg = db.get(bucketMessage, messageId);
    if (msg == null) {
      return DataResponse(
        message: "",
        error: "Message not found",
        status: StatusCodes.notFound,
      );
    }
    if (msg.value['sender_id'] != senderId) {
      return DataResponse(
        message: "",
        error: "Unauthorized",
        status: StatusCodes.forbidden,
      );
    }

    final data = Map<String, dynamic>.from(msg.value);
    data['text'] = newText;
    data['updated_at'] = DateTime.now().millisecondsSinceEpoch;
    db.add(bucketMessage, messageId, data);

    return DataResponse(
      message: "Message updated",
      error: "",
      status: StatusCodes.ok,
    );
  }

  Future<DataResponse> deleteMessage(String messageId, String userId) async {
    final msg = db.get(bucketMessage, messageId);
    if (msg == null) {
      return DataResponse(
        message: "",
        error: "Message not found",
        status: StatusCodes.notFound,
      );
    }
    if (msg.value['sender_id'] != userId) {
      return DataResponse(
        message: "",
        error: "Unauthorized",
        status: StatusCodes.forbidden,
      );
    }

    db.remove(bucketMessage, messageId);
    return DataResponse(
      message: "Message deleted",
      error: "",
      status: StatusCodes.ok,
    );
  }

  Future<DataResponse> toggleReaction(
    String messageId,
    String userId,
    String emoji,
    bool add,
  ) async {
    final msg = db.get(bucketMessage, messageId);
    if (msg == null) {
      return DataResponse(
        message: "",
        error: "Message not found",
        status: StatusCodes.notFound,
      );
    }
    final data = Map<String, dynamic>.from(msg.value);
    final reactions = Map<String, dynamic>.from(data['reactions'] ?? {});

    final usersForEmoji = List<String>.from(reactions[emoji] ?? []);

    if (add) {
      if (!usersForEmoji.contains(userId)) usersForEmoji.add(userId);
    } else {
      usersForEmoji.remove(userId);
    }

    if (usersForEmoji.isEmpty) {
      reactions.remove(emoji);
    } else {
      reactions[emoji] = usersForEmoji;
    }

    data['reactions'] = reactions;
    db.add(bucketMessage, messageId, data);

    return DataResponse(
      message: "Reaction updated",
      error: "",
      status: StatusCodes.ok,
    );
  }

  Future<DataResponse> pinMessage(String messageId, bool pin) async {
    final msg = db.get(bucketMessage, messageId);
    if (msg == null) {
      return DataResponse(
        message: "",
        error: "Message not found",
        status: StatusCodes.notFound,
      );
    }
    final data = Map<String, dynamic>.from(msg.value);
    data['is_pinned'] = pin;
    db.add(bucketMessage, messageId, data);

    return DataResponse(
      message: pin ? "Message pinned" : "Message unpinned",
      error: "",
      status: StatusCodes.ok,
    );
  }

  Future<DataResponse> getPinnedMessages(String chatId) async {
    final allMessages = db.getAll(bucketMessage);
    if (allMessages == null) {
      return DataResponse(
        message: "No pinned messages",
        error: "",
        status: StatusCodes.ok,
        data: [],
      );
    }
    final pinned = allMessages
        .where(
          (m) => m.value['chat_id'] == chatId && m.value['is_pinned'] == true,
        )
        .map((m) => m.value)
        .toList();

    return DataResponse(
      message: "Success",
      error: "",
      status: StatusCodes.ok,
      data: pinned,
    );
  }
}
