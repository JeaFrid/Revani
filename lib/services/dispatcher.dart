import 'dart:async';
import 'dart:isolate';
import 'package:revani/core/database_engine.dart';
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

  late final DataSchemaProject projectSchema;
  late final DataSchemaAccount accountSchema;
  late final DataSchemaData dataSchema;
  late final QuerySchema querySchema;
  late final LivekitSchema livekitSchema;
  late final PubSubSchema pubSubSchema;
  late final StorageSchema storageSchema;
  final Uuid uuid = const Uuid();

  RequestDispatcher(this.db) {
    projectSchema = DataSchemaProject(db);
    accountSchema = DataSchemaAccount(db, JeaTokener());
    dataSchema = DataSchemaData(db, JeaTokener());
    livekitSchema = LivekitSchema(db);
    storageSchema = StorageSchema(db);
    pubSubSchema = PubSubSchema(db);
    querySchema = QuerySchema(db);
  }

  Future<Map<String, dynamic>> processCommand(Map<String, dynamic> req) async {
    final cmd = req['cmd'];

    try {
      DataResponse? res;

      switch (cmd) {
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

        case 'data/get':
          res = await dataSchema.get(
            req['projectID'],
            req['bucket'],
            req['tag'],
          );
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

        case 'repository/get-all':
          return _handleRepositoryGetAll(req);

        case 'repository/feed':
          return _handleRepositoryFeed(req);

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

        default:
          return {
            'status': 400,
            'message': 'Unknown command: $cmd',
            'error': 'Bad Request',
          };
      }
      return res.toJson();
    } catch (e, stack) {
      print('Core Processing Error: $e\n$stack');
      return {
        'status': 500,
        'message': 'Internal Error',
        'error': e.toString(),
      };
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

  Map<String, dynamic> _handleRepositoryGetAll(Map<String, dynamic> req) {
    final bucket = req['tag'];
    final items = db.getAll(bucket);
    final results =
        items
            ?.map(
              (item) => {
                'id': item.tag,
                'bucket': item.bucket,
                'data': item.value,
                'created_at': item.createdAt,
                'expires_at': item.expiresAt,
              },
            )
            .toList() ??
        [];

    return {
      'status': 200,
      'message': 'Success',
      'count': results.length,
      'data': results,
    };
  }

  Map<String, dynamic> _handleRepositoryFeed(Map<String, dynamic> req) {
    final bucket = req['tag'];
    final limit = int.tryParse(req['limit']?.toString() ?? '20') ?? 20;
    final items = db.getLatest(bucket, limit);

    final results = items
        .map(
          (item) => {
            'id': item.tag,
            'bucket': item.bucket,
            'data': item.value,
            'created_at': item.createdAt,
          },
        )
        .toList();

    return {
      'status': 200,
      'message': 'Success',
      'count': results.length,
      'data': results,
    };
  }
}
