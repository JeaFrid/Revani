import 'dart:async';
import 'dart:isolate';
import 'package:revani/core/database_engine.dart';
import 'package:revani/core/rate_limiter.dart';
import 'package:revani/schema/data_schema.dart';
import 'package:revani/schema/livekit_schema.dart';
import 'package:revani/schema/pubsub_schema.dart';
import 'package:revani/schema/query_schema.dart';
import 'package:revani/schema/storage_schema.dart';
import 'package:revani/model/print.dart';
import 'package:revani/tools/tokener.dart';
import 'package:uuid/uuid.dart';

class RequestDispatcher {
  final RevaniDatabase db;
  final RateLimiterClient? rateLimiter;
  late final DataSchemaProject projectSchema;
  late final DataSchemaAccount accountSchema;
  late final DataSchemaData dataSchema;
  late final DataSchemaUser userSchema;
  late final DataSchemaSocial socialSchema;
  late final DataSchemaMessaging messagingSchema;
  late final QuerySchema querySchema;
  late final DataSchemaSession sessionSchema;
  late final LivekitSchema livekitSchema;
  late final PubSubSchema pubSubSchema;
  late final StorageSchema storageSchema;
  final Uuid uuid = const Uuid();
  RequestDispatcher(this.db, {this.rateLimiter}) {
    projectSchema = DataSchemaProject(db);
    accountSchema = DataSchemaAccount(db, JeaTokener());
    dataSchema = DataSchemaData(db, JeaTokener());
    userSchema = DataSchemaUser(db, JeaTokener());
    socialSchema = DataSchemaSocial(db);
    messagingSchema = DataSchemaMessaging(db);
    livekitSchema = LivekitSchema(db);
    storageSchema = StorageSchema(db);
    pubSubSchema = PubSubSchema(db);
    querySchema = QuerySchema(db);
    sessionSchema = DataSchemaSession(db);
  }
  void rebuildAllIndices() {
    accountSchema.rebuildIndices();
    projectSchema.rebuildIndices();
    dataSchema.rebuildIndices();
    userSchema.rebuildIndices();
    storageSchema.rebuildIndices();
    sessionSchema.rebuildIndices();
  }

  Future<Map<String, dynamic>> processCommand(Map<String, dynamic> req) async {
    final cmd = req['cmd'];
    try {
      DataResponse? res;

      if (cmd.toString().startsWith('admin/')) {
        return _processAdminCommand(req);
      }

      switch (cmd) {
        case 'auth/verify-token':
          res = await sessionSchema.verifyToken(req['token']);
          break;
        case 'data/query':
          res = await querySchema.queryData(
            req['accountID'],
            req['projectName'],
            req['bucket'],
            req['query'] ?? {},
          );
          break;
        case 'pubsub/subscribe':
          res = await pubSubSchema.handleSubscribe(
            req['accountID'],
            req['projectName'],
            req['clientId'],
            req['topic'],
          );
          break;
        case 'pubsub/publish':
          res = await pubSubSchema.handlePublish(
            req['accountID'],
            req['projectName'],
            req['topic'],
            req['data'],
            req['clientId'],
          );
          break;
        case 'pubsub/unsubscribe':
          res = await pubSubSchema.handleUnsubscribe(
            req['clientId'],
            req['topic'],
          );
          break;
        case 'account/create':
          res = await accountSchema.createAccount(
            req['email'],
            req['password'],
            req['data'] ?? {},
          );
          break;
        case 'account/get-id':
          res = await accountSchema.getAccountID(req['email'], req['password']);
          break;
        case 'account/get-data':
          res = await accountSchema.getAccountDataWithID(req['id']);
          break;
        case 'project/create':
          res = await projectSchema.createProject(
            req['accountID'],
            req['projectName'],
          );
          break;
        case 'project/exist':
          final id = await projectSchema.existProject(
            req['accountID'],
            req['projectName'],
          );
          if (id != null) {
            return {'status': 200, 'message': 'Project found', 'id': id};
          } else {
            return {
              'status': 404,
              'message': 'Project not found',
              'error': 'Not Found',
            };
          }
        case 'data/add':
          if (req['raw_value'] != null) {
            return _handleAddRaw(req);
          }
          res = await dataSchema.add(
            req['accountID'],
            req['projectName'],
            req['bucket'],
            req['tag'],
            req['value'],
          );
          break;
        case 'data/add-batch':
          res = await dataSchema.addAll(
            req['accountID'],
            req['projectName'],
            req['bucket'],
            Map<String, Map<String, dynamic>>.from(req['items']),
          );
          break;
        case 'data/get':
          res = await dataSchema.get(
            req['projectID'],
            req['bucket'],
            req['tag'],
          );
          break;
        case 'data/get-all':
          res = await dataSchema.getAll(req['projectID'], req['bucket']);
          break;
        case 'data/update':
          res = await dataSchema.update(
            req['projectID'],
            req['bucket'],
            req['tag'],
            req['newValue'],
          );
          break;
        case 'data/delete':
          res = await dataSchema.delete(
            req['projectID'],
            req['bucket'],
            req['tag'],
          );
          break;
        case 'data/delete-all':
          res = await dataSchema.deleteAll(req['projectID'], req['bucket']);
          break;
        case 'storage/upload':
          List<int> fileData;
          if (req['raw_value'] != null) {
            fileData = (req['raw_value'] as TransferableTypedData)
                .materialize()
                .asUint8List();
          } else {
            fileData = (req['bytes'] as List).cast<int>();
          }
          res = await storageSchema.uploadFile(
            req['accountID'],
            req['projectName'],
            req['fileName'],
            fileData,
            compressImage: req['compress'] ?? false,
          );
          break;
        case 'storage/download':
          res = await storageSchema.downloadFile(
            req['accountID'],
            req['projectName'],
            req['fileId'],
          );
          break;
        case 'storage/delete':
          res = await storageSchema.deleteFile(
            req['accountID'],
            req['projectName'],
            req['fileId'],
          );
          break;
        case 'livekit/init':
          await livekitSchema.init(
            req['host'],
            req['apiKey'],
            req['apiSecret'],
          );
          res = DataResponse(
            message: "Livekit initialized.",
            error: "",
            status: StatusCodes.ok,
          );
          break;
        case 'livekit/connect':
          res = await livekitSchema.connectLivekit(
            req['accountID'],
            req['projectName'],
          );
          break;
        case 'livekit/create-token':
          res = await livekitSchema.createToken(
            req['roomName'],
            req['userID'],
            req['userName'],
            req['isAdmin'] ?? false,
          );
          break;
        case 'livekit/create-room':
          res = await livekitSchema.createRoom(
            req['roomName'],
            req['emptyTimeoutMinute'] ?? 10,
            req['maxUsers'] ?? 50,
          );
          break;
        case 'livekit/close-room':
          res = await livekitSchema.closeRoom(req['roomName']);
          break;
        case 'livekit/get-room-info':
          res = await livekitSchema.getRoomInfo(req['roomName']);
          break;
        case 'livekit/get-all-rooms':
          res = await livekitSchema.getAllRooms();
          break;
        case 'livekit/kick-user':
          res = await livekitSchema.kickUser(req['roomName'], req['userID']);
          break;
        case 'livekit/get-user-info':
          res = await livekitSchema.getUserInfo(req['roomName'], req['userID']);
          break;
        case 'livekit/update-metadata':
          res = await livekitSchema.updateRoomMetadata(
            req['roomName'],
            req['metadata'],
          );
          break;
        case 'livekit/update-participant':
          res = await livekitSchema.updateParticipant(
            req['roomName'],
            req['userID'],
            metadata: req['metadata'],
            permission: req['permission'],
          );
          break;
        case 'livekit/mute-participant':
          res = await livekitSchema.muteParticipant(
            req['roomName'],
            req['userID'],
            req['trackSid'],
            req['muted'],
          );
          break;
        case 'livekit/list-participants':
          res = await livekitSchema.listParticipants(req['roomName']);
          break;
        case 'user/register':
          res = await userSchema.register(
            req['accountID'],
            req['projectName'],
            req['userData'],
          );
          break;
        case 'user/login':
          res = await userSchema.login(
            req['accountID'],
            req['projectName'],
            req['email'],
            req['password'],
          );
          break;
        case 'user/get-profile':
          res = await userSchema.getProfile(
            req['accountID'],
            req['projectName'],
            req['userId'],
          );
          break;
        case 'user/edit-profile':
          res = await userSchema.editProfile(req['userId'], req['updates']);
          break;
        case 'user/change-password':
          res = await userSchema.changePassword(
            req['userId'],
            req['oldPass'],
            req['newPass'],
          );
          break;
        case 'social/post/create':
          res = await socialSchema.createPost(
            req['accountID'],
            req['projectName'],
            req['postData'],
          );
          break;
        case 'social/post/get':
          res = await socialSchema.getPost(req['postId']);
          break;
        case 'social/post/like':
          res = await socialSchema.toggleLike(
            req['postId'],
            req['userId'],
            req['isLike'],
          );
          break;
        case 'social/post/view':
          res = await socialSchema.addView(req['postId']);
          break;
        case 'social/comment/add':
          res = await socialSchema.addComment(
            req['postId'],
            req['userId'],
            req['text'],
          );
          break;
        case 'social/comment/get':
          res = await socialSchema.getComments(req['postId']);
          break;
        case 'social/comment/like':
          res = await socialSchema.toggleCommentLike(
            req['commentId'],
            req['userId'],
            req['isLike'],
          );
          break;
        case 'chat/create':
          res = await messagingSchema.createChat(
            req['accountID'],
            req['projectName'],
            List<String>.from(req['participants']),
          );
          break;
        case 'chat/get-list':
          res = await messagingSchema.getChats(
            req['accountID'],
            req['projectName'],
            req['userId'],
          );
          break;
        case 'chat/delete':
          res = await messagingSchema.deleteChat(req['chatId']);
          break;
        case 'chat/message/send':
          res = await messagingSchema.sendMessage(
            req['chatId'],
            req['senderId'],
            req['messageData'],
          );
          break;
        case 'chat/message/list':
          res = await messagingSchema.getMessages(req['chatId']);
          break;
        case 'chat/message/update':
          res = await messagingSchema.updateMessage(
            req['messageId'],
            req['senderId'],
            req['newText'],
          );
          break;
        case 'chat/message/delete':
          res = await messagingSchema.deleteMessage(
            req['messageId'],
            req['userId'],
          );
          break;
        case 'chat/message/react':
          res = await messagingSchema.toggleReaction(
            req['messageId'],
            req['userId'],
            req['emoji'],
            req['add'],
          );
          break;
        case 'chat/message/pin':
          res = await messagingSchema.pinMessage(req['messageId'], req['pin']);
          break;
        case 'chat/message/get-pinned':
          res = await messagingSchema.getPinnedMessages(req['chatId']);
          break;
        default:
          return {
            'status': 400,
            'message': 'Unknown command: $cmd',
            'error': 'Bad Request',
          };
      }
      return res.toJson();
    } catch (e) {
      return {
        'status': 500,
        'message': 'Internal Error',
        'error': e.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> _processAdminCommand(
    Map<String, dynamic> req,
  ) async {
    final accountID = req['accountID'];
    if (accountID == null) {
      return {'status': 401, 'message': 'Unauthorized: No accountID'};
    }

    final userData = db.get('account', accountID);
    if (userData == null) {
      return {'status': 404, 'message': 'Account not found in DB'};
    }

    String role = userData.value['role'] ?? 'user';

    if (role != 'admin') {
      final allAccounts = db.getAll('account');
      bool hasOtherAdmin = false;

      if (allAccounts != null) {
        hasOtherAdmin = allAccounts.any((u) => u.value['role'] == 'admin');
      }

      if (!hasOtherAdmin) {
        final newData = Map<String, dynamic>.from(userData.value);
        newData['role'] = 'admin';
        db.add('account', accountID, newData);
        role = 'admin';
      }
    }

    if (role != 'admin') {
      return {'status': 403, 'message': 'Admin privileges required'};
    }

    final cmd = req['cmd'];
    if (cmd.startsWith('admin/security/') && rateLimiter == null) {
      return {'status': 500, 'message': 'RateLimiter not connected'};
    }

    switch (cmd) {
      case 'admin/stats/full':
        return {'status': 200, 'data': db.stats()};
      case 'admin/users/list':
        final allAccounts = db.getAll('account');
        final cleanList = allAccounts?.map((e) {
          return {
            'id': e.value['id'],
            'email': e.value['email'],
            'role': e.value['role'],
            'created_at': e.createdAt,
          };
        }).toList();
        return {'status': 200, 'data': cleanList ?? []};
      case 'admin/users/set-role':
        final targetId = req['targetId'];
        final newRole = req['newRole'];
        final targetUser = db.get('account', targetId);
        if (targetUser != null) {
          final newData = Map<String, dynamic>.from(targetUser.value);
          newData['role'] = newRole;
          db.add('account', targetId, newData);
          return {'status': 200, 'message': 'Role updated'};
        }
        return {'status': 404, 'message': 'Target user not found'};
      case 'admin/users/delete':
        final targetId = req['targetId'];
        db.remove('account', targetId);
        return {'status': 200, 'message': 'User deleted'};
      case 'admin/projects/list':
        final allProjects = db.getAll('project');
        final cleanList = allProjects?.map((e) {
          return {
            'id': e.value['id'],
            'name': e.value['name'],
            'owner': e.value['owner'],
            'created_at': e.createdAt,
          };
        }).toList();
        return {'status': 200, 'data': cleanList ?? []};
      case 'admin/system/force-gc':
        db.performManualGC();
        return {'status': 200, 'message': 'Garbage Collection triggered'};
      case 'admin/security/ban-list':
        final list = await rateLimiter!.adminOp('get_banned');
        return {'status': 200, 'data': list};
      case 'admin/security/unban':
        await rateLimiter!.adminOp('unban', targetIp: req['targetIp']);
        return {'status': 200, 'message': 'IP Unbanned'};
      case 'admin/security/whitelist-list':
        final list = await rateLimiter!.adminOp('get_whitelist');
        return {'status': 200, 'data': list};
      case 'admin/security/whitelist-add':
        await rateLimiter!.adminOp('add_whitelist', targetIp: req['targetIp']);
        return {'status': 200, 'message': 'IP Whitelisted'};
      case 'admin/security/whitelist-remove':
        await rateLimiter!.adminOp(
          'remove_whitelist',
          targetIp: req['targetIp'],
        );
        return {'status': 200, 'message': 'IP Removed from Whitelist'};
      default:
        return {'status': 400, 'message': 'Unknown admin command'};
    }
  }

  Future<Map<String, dynamic>> _handleAddRaw(Map<String, dynamic> req) async {
    final compositeKeyP = "${req['accountID']}_${req['projectName']}";
    final pId = db.getIdByIndex("idx_project_owner_name", compositeKeyP);
    if (pId == null) {
      return {
        'status': 404,
        'message': 'Project not found.',
        'error': 'Closed',
      };
    }

    final compositeKeyD = "${pId}_${req['bucket']}_${req['tag']}";
    if (db.getIdByIndex("idx_data_composite", compositeKeyD) != null) {
      return {
        'status': 409,
        'message': 'Data tag already exists',
        'error': 'Conflict',
      };
    }

    final entryId = uuid.v4();
    final TransferableTypedData rawData = req['raw_value'];
    db.addRaw(req['bucket'], entryId, rawData.materialize().asUint8List());
    db.setIndex("idx_data_composite", compositeKeyD, entryId);

    return {
      'status': 200,
      'message': 'Data added (Raw).',
      'data': {"id": entryId},
    };
  }
}
