/*
 * Copyright (C) 2026 JeaFriday (https://github.com/JeaFrid/Revani)
 * * This project is part of Revani
 * Licensed under the GNU Affero General Public License v3.0 (AGPL-3.0).
 * See the LICENSE file in the project root for full license information.
 * * For commercial licensing, please contact: JeaFriday
 */

// -----------------------------------
// This package was incorrectly configured. Therefore, we need to pull it from the src folder.
// ignore: implementation_imports
import 'package:livekit_server_sdk/src/proto/livekit_models.pb.dart';
import 'package:revani/schema/data_schema.dart';
import 'package:revani/core/database_engine.dart';
import 'package:revani/model/print.dart';
import 'package:revani/services/livekit.dart';
import 'package:revani/tools/name_parser.dart';
import 'package:revani/tools/tokener.dart';
import 'package:uuid/uuid.dart';

class LivekitSchema {
  final Uuid uuid = const Uuid();
  final RevaniDatabase db;
  late final DataSchemaProject projectSchema;
  late final DataSchemaAccount accountSchema;
  late final DataSchemaData dataSchema;
  String _accountID = "";
  String _projectName = "";

  LivekitSchema(this.db) {
    projectSchema = DataSchemaProject(db);
    accountSchema = DataSchemaAccount(db, JeaTokener());
    dataSchema = DataSchemaData(db, JeaTokener());
  }

  LiveKitService? livekit;

  Future<void> init(String host, String apiKey, String apiSecret) async {
    try {
      livekit = LiveKitService(
        host: host,
        apiKey: apiKey,
        apiSecret: apiSecret,
      );
    } catch (e) {
      print("Server Error [init]: $e");
    }
  }

  Future<DataResponse?> _validateOp() async {
    if (_accountID == "" || _projectName == "") {
      return DataResponse(
        message: "",
        error: "Project not connected. Please connect first.",
        status: StatusCodes.unauthorized,
      );
    }
    var project = await projectSchema.existProject(_accountID, _projectName);
    if (project == null) {
      return DataResponse(
        message: "",
        error: "Project not found.",
        status: StatusCodes.notFound,
      );
    }
    if (livekit == null) {
      return DataResponse(
        message: "",
        error: "Livekit service not initialized.",
        status: StatusCodes.internalServerError,
      );
    }
    return null;
  }

  Future<DataResponse> connectLivekit(
    String accountID,
    String projectName,
  ) async {
    try {
      var x = await projectSchema.existProject(accountID, projectName);
      if (x != null) {
        _accountID = accountID;
        _projectName = projectName;
        return DataResponse(
          message:
              "Oki! The Revani Livekit server was accessed using the project named $_projectName.",
          error: "",
          status: StatusCodes.ok,
        );
      } else {
        return DataResponse(
          message: "",
          error: "Project not found.",
          status: StatusCodes.notFound,
        );
      }
    } catch (e) {
      print("Server Error [connectLivekit]: $e");
      return DataResponse(
        message: "",
        error: "Oops... An error occurred.",
        status: StatusCodes.internalServerError,
      );
    }
  }

  Future<DataResponse> createToken(
    String roomName,
    String userID,
    String userName,
    bool isAdmin,
  ) async {
    try {
      var val = await _validateOp();
      if (val != null) return val;

      RoomParser roomParser = RoomParser(_accountID, _projectName);
      String? rn = roomParser.encodeRoomName(roomName);
      if (rn != null) {
        String token = livekit!.createJoinToken(
          roomName: rn,
          participantIdentity: userID,
          isAdmin: isAdmin,
          participantName: userName,
        );
        return DataResponse(
          message: "Oki.",
          error: "",
          status: StatusCodes.ok,
          data: {"token": token},
        );
      } else {
        return DataResponse(
          message: "",
          error: "Invalid room name.",
          status: StatusCodes.badRequest,
        );
      }
    } catch (e) {
      print("Server Error [createToken]: $e");
      return DataResponse(
        message: "",
        error: "Oops... An error occurred.",
        status: StatusCodes.internalServerError,
      );
    }
  }

  Future<DataResponse> createRoom(
    String roomName,
    int emptyTimeoutMinute,
    int maxUsers,
  ) async {
    try {
      var val = await _validateOp();
      if (val != null) return val;

      RoomParser roomParser = RoomParser(_accountID, _projectName);
      String? rn = roomParser.encodeRoomName(roomName);
      if (rn != null) {
        await livekit!.createRoom(
          rn,
          emptyTimeout: Duration(minutes: emptyTimeoutMinute),
          maxParticipants: maxUsers,
        );
        return DataResponse(
          message: "Room created.",
          error: "",
          status: StatusCodes.ok,
        );
      } else {
        return DataResponse(
          message: "",
          error: "Invalid room name.",
          status: StatusCodes.badRequest,
        );
      }
    } catch (e) {
      print("Server Error [createRoom]: $e");
      return DataResponse(
        message: "",
        error: "Oops... An error occurred.",
        status: StatusCodes.internalServerError,
      );
    }
  }

  Future<DataResponse> closeRoom(String roomName) async {
    try {
      var val = await _validateOp();
      if (val != null) return val;

      RoomParser roomParser = RoomParser(_accountID, _projectName);
      String? rn = roomParser.encodeRoomName(roomName);
      if (rn != null) {
        await livekit!.deleteRoom(rn);
        return DataResponse(
          message: "Room closed.",
          error: "",
          status: StatusCodes.ok,
        );
      } else {
        return DataResponse(
          message: "",
          error: "Invalid room name.",
          status: StatusCodes.badRequest,
        );
      }
    } catch (e) {
      print("Server Error [closeRoom]: $e");
      return DataResponse(
        message: "",
        error: "Oops... An error occurred.",
        status: StatusCodes.internalServerError,
      );
    }
  }

  Future<DataResponse> getRoomInfo(String roomName) async {
    try {
      var val = await _validateOp();
      if (val != null) return val;

      RoomParser roomParser = RoomParser(_accountID, _projectName);
      String? rn = roomParser.encodeRoomName(roomName);
      if (rn != null) {
        var room = await livekit!.getRoom(rn);
        if (room != null) {
          DateTime creationDate = DateTime.fromMillisecondsSinceEpoch(
            room.creationTime.toInt() * 1000,
          );
          Duration duration = DateTime.now().difference(creationDate);

          return DataResponse(
            message: "Room Infos",
            error: "",
            status: StatusCodes.ok,
            data: {
              "name": room.name,
              "total_user_count": room.numParticipants,
              "max_user_count": room.maxParticipants,
              "time":
                  "${duration.inDays}:${duration.inHours}:${duration.inMinutes}:${duration.inSeconds}",
              "metadata": room.metadata,
            },
          );
        } else {
          return DataResponse(
            message: "",
            error: "Room not found.",
            status: StatusCodes.notFound,
          );
        }
      } else {
        return DataResponse(
          message: "",
          error: "Invalid room name.",
          status: StatusCodes.badRequest,
        );
      }
    } catch (e) {
      print("Server Error [getRoomInfo]: $e");
      return DataResponse(
        message: "",
        error: "Oops... An error occurred.",
        status: StatusCodes.internalServerError,
      );
    }
  }

  Future<DataResponse> getAllRooms() async {
    try {
      var val = await _validateOp();
      if (val != null) return val;

      RoomParser roomParser = RoomParser(_accountID, _projectName);
      var rooms = await livekit!.getAllRooms();
      Map<String, dynamic> roomsContent = {};

      for (var element in rooms) {
        bool? isOwner = roomParser.isOwner(element.name);
        if (isOwner != null && isOwner) {
          DateTime creationDate = DateTime.fromMillisecondsSinceEpoch(
            element.creationTime.toInt() * 1000,
          );
          Duration duration = DateTime.now().difference(creationDate);
          roomsContent.addAll({
            element.name: {
              "name": element.name,
              "total_user_count": element.numParticipants,
              "max_user_count": element.maxParticipants,
              "time":
                  "${duration.inDays}:${duration.inHours}:${duration.inMinutes}:${duration.inSeconds}",
              "metadata": element.metadata,
            },
          });
        }
      }
      return DataResponse(
        message: "The rooms were brought.",
        error: "",
        status: StatusCodes.ok,
        data: roomsContent,
      );
    } catch (e) {
      print("Server Error [getAllRooms]: $e");
      return DataResponse(
        message: "",
        error: "Oops... An error occurred.",
        status: StatusCodes.internalServerError,
      );
    }
  }

  Future<DataResponse> kickUser(String roomName, String userID) async {
    try {
      var val = await _validateOp();
      if (val != null) return val;

      RoomParser roomParser = RoomParser(_accountID, _projectName);
      String? rn = roomParser.encodeRoomName(roomName);
      if (rn != null) {
        await livekit!.removeParticipant(rn, userID);
        return DataResponse(
          message: "User removed from the room.",
          error: "",
          status: StatusCodes.ok,
        );
      } else {
        return DataResponse(
          message: "",
          error: "Invalid room name.",
          status: StatusCodes.badRequest,
        );
      }
    } catch (e) {
      print("Server Error [kickUser]: $e");
      return DataResponse(
        message: "",
        error: "Oops... An error occurred.",
        status: StatusCodes.internalServerError,
      );
    }
  }

  Future<DataResponse> getUserInfo(String roomName, String userID) async {
    try {
      var val = await _validateOp();
      if (val != null) return val;

      RoomParser roomParser = RoomParser(_accountID, _projectName);
      String? rn = roomParser.encodeRoomName(roomName);
      if (rn != null) {
        ParticipantInfo info = await livekit!.getParticipant(rn, userID);
        DateTime creationDate = DateTime.fromMillisecondsSinceEpoch(
          info.joinedAt.toInt() * 1000,
        );
        Duration duration = DateTime.now().difference(creationDate);
        var permission = info.permission;
        return DataResponse(
          message: "Oki!",
          error: "",
          status: StatusCodes.ok,
          data: {
            "id": info.identity,
            "name": info.name,
            "region": info.region,
            "state": info.state.toString(),
            "isAdmin": permission.canUpdateMetadata,
            "joinedAt":
                "${duration.inDays}:${duration.inHours}:${duration.inMinutes}:${duration.inSeconds}",
            "metadata": info.metadata,
          },
        );
      } else {
        return DataResponse(
          message: "",
          error: "Invalid room name.",
          status: StatusCodes.badRequest,
        );
      }
    } catch (e) {
      print("Server Error [getUserInfo]: $e");
      return DataResponse(
        message: "",
        error: "Oops... An error occurred.",
        status: StatusCodes.internalServerError,
      );
    }
  }

  Future<DataResponse> updateRoomMetadata(
    String roomName,
    String metadata,
  ) async {
    try {
      var val = await _validateOp();
      if (val != null) return val;

      RoomParser roomParser = RoomParser(_accountID, _projectName);
      String? rn = roomParser.encodeRoomName(roomName);
      if (rn != null) {
        await livekit!.updateRoomMetadata(rn, metadata);
        return DataResponse(
          message: "Room metadata updated.",
          error: "",
          status: StatusCodes.ok,
        );
      } else {
        return DataResponse(
          message: "",
          error: "Invalid room name.",
          status: StatusCodes.badRequest,
        );
      }
    } catch (e) {
      print("Server Error [updateRoomMetadata]: $e");
      return DataResponse(
        message: "",
        error: "Oops... An error occurred.",
        status: StatusCodes.internalServerError,
      );
    }
  }

  Future<DataResponse> updateParticipant(
    String roomName,
    String userID, {
    String? metadata,
    ParticipantPermission? permission,
  }) async {
    try {
      var val = await _validateOp();
      if (val != null) return val;

      RoomParser roomParser = RoomParser(_accountID, _projectName);
      String? rn = roomParser.encodeRoomName(roomName);
      if (rn != null) {
        await livekit!.updateParticipant(
          rn,
          userID,
          metadata: metadata,
          permission: permission,
        );
        return DataResponse(
          message: "Participant updated.",
          error: "",
          status: StatusCodes.ok,
        );
      } else {
        return DataResponse(
          message: "",
          error: "Invalid room name.",
          status: StatusCodes.badRequest,
        );
      }
    } catch (e) {
      print("Server Error [updateParticipant]: $e");
      return DataResponse(
        message: "",
        error: "Oops... An error occurred.",
        status: StatusCodes.internalServerError,
      );
    }
  }

  Future<DataResponse> muteParticipant(
    String roomName,
    String userID,
    String trackSid,
    bool muted,
  ) async {
    try {
      var val = await _validateOp();
      if (val != null) return val;

      RoomParser roomParser = RoomParser(_accountID, _projectName);
      String? rn = roomParser.encodeRoomName(roomName);
      if (rn != null) {
        await livekit!.muteParticipantTrack(rn, userID, trackSid, muted);
        return DataResponse(
          message: "Participant mute state updated.",
          error: "",
          status: StatusCodes.ok,
        );
      } else {
        return DataResponse(
          message: "",
          error: "Invalid room name.",
          status: StatusCodes.badRequest,
        );
      }
    } catch (e) {
      print("Server Error [muteParticipant]: $e");
      return DataResponse(
        message: "",
        error: "Oops... An error occurred.",
        status: StatusCodes.internalServerError,
      );
    }
  }

  Future<DataResponse> listParticipants(String roomName) async {
    try {
      var val = await _validateOp();
      if (val != null) return val;

      RoomParser roomParser = RoomParser(_accountID, _projectName);
      String? rn = roomParser.encodeRoomName(roomName);
      if (rn != null) {
        var participants = await livekit!.listParticipants(rn);
        List<Map<String, dynamic>> participantList = [];
        for (var p in participants) {
          participantList.add({
            "id": p.identity,
            "name": p.name,
            "state": p.state.toString(),
            "metadata": p.metadata,
          });
        }
        return DataResponse(
          message: "Participants listed.",
          error: "",
          status: StatusCodes.ok,
          data: {"participants": participantList},
        );
      } else {
        return DataResponse(
          message: "",
          error: "Invalid room name.",
          status: StatusCodes.badRequest,
        );
      }
    } catch (e) {
      print("Server Error [listParticipants]: $e");
      return DataResponse(
        message: "",
        error: "Oops... An error occurred.",
        status: StatusCodes.internalServerError,
      );
    }
  }
}
