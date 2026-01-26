import 'dart:async';
import '../model/call_model.dart';
import '../model/user_response.dart';
import '../services/revani_base.dart';
import '../services/revani_database_serv.dart';
import '../source/api.dart';
import 'package:uuid/uuid.dart';

class RevaniCall {
  RevaniCall();
  RevaniBaseDB database = RevaniBaseDB();
  RevaniBase revaniBase = RevaniBase();
  RevaniClient get revani => revaniBase.revani;
  RevaniData get db => revani.data;
  RevaniLivekit get livekit => revani.livekit;

  Future<RevaniResponse> initiateCall({
    required RevaniUserResponse host,
    required String callName,
    required RevaniCallType callType,
    required List<RevaniUserResponse> participants,
    int maxParticipants = 10,
    Map<String, dynamic>? callSettings,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final callId = Uuid().v1();
      final now = DateTime.now();
      final roomName = 'call_$callId';

      final callParticipants = [
        RevaniCallParticipant(
          user: host,
          joinedAt: now,
          isHost: true,
          videoEnabled:
              callType == RevaniCallType.video ||
              callType == RevaniCallType.groupVideo,
        ),
        ...participants.map(
          (user) => RevaniCallParticipant(
            user: user,
            joinedAt: now,
            videoEnabled:
                callType == RevaniCallType.video ||
                callType == RevaniCallType.groupVideo,
          ),
        ),
      ];

      final callSession = RevaniCallSession(
        callId: callId,
        host: host,
        callName: callName,
        callType: callType,
        status: RevaniCallStatus.ringing,
        createdAt: now,
        participants: callParticipants,
        maxParticipants: maxParticipants,
        callSettings: callSettings ?? {},
        metadata: metadata ?? {},
      );

      final createRoomResponse = await livekit.createRoom(
        request: CreateRoomRequest(
          roomName: roomName,
          maxUsers: maxParticipants,
          metadata: {'callId': callId, 'callType': callType.value},
        ),
      );

      if (!createRoomResponse.isSuccess) {
        return createRoomResponse;
      }

      final addResponse = await database.add(
        bucket: 'calls',
        tag: callId,
        value: callSession.toJson(),
      );

      if (addResponse.isSuccess) {
        for (final participant in participants) {
          await _sendCallNotification(
            callId: callId,
            caller: host,
            participant: participant,
            callType: callType,
          );
        }
      }

      return addResponse;
    } catch (e) {
      return RevaniResponse(status: 500, message: e.toString());
    }
  }

  Future<RevaniResponse> acceptCall({
    required String callId,
    required RevaniUserResponse user,
  }) async {
    try {
      final callData = await database.get(bucket: 'calls', tag: callId);
      if (callData == null) {
        return RevaniResponse(status: 404, message: 'Call not found');
      }

      var callSession = RevaniCallSession.fromJson(callData.value);

      if (callSession.status != RevaniCallStatus.ringing) {
        return RevaniResponse(status: 400, message: 'Call is not ringing');
      }

      final participantIndex = callSession.participants.indexWhere(
        (p) => p.user.uid == user.uid,
      );

      if (participantIndex == -1) {
        return RevaniResponse(status: 403, message: 'Not invited to this call');
      }

      var participant = callSession.participants[participantIndex];
      participant = participant.copyWith(joinedAt: DateTime.now());

      final updatedParticipants = List<RevaniCallParticipant>.from(
        callSession.participants,
      );
      updatedParticipants[participantIndex] = participant;

      callSession = callSession.copyWith(
        status: RevaniCallStatus.active,
        startedAt: callSession.startedAt ?? DateTime.now(),
        participants: updatedParticipants,
      );

      return await database.update(
        bucket: 'calls',
        tag: callId,
        newValue: callSession.toJson(),
      );
    } catch (e) {
      return RevaniResponse(status: 500, message: e.toString());
    }
  }

  Future<RevaniResponse> rejectCall({
    required String callId,
    required RevaniUserResponse user,
  }) async {
    try {
      final callData = await database.get(bucket: 'calls', tag: callId);
      if (callData == null) {
        return RevaniResponse(status: 404, message: 'Call not found');
      }

      var callSession = RevaniCallSession.fromJson(callData.value);

      final participantIndex = callSession.participants.indexWhere(
        (p) => p.user.uid == user.uid,
      );

      if (participantIndex == -1) {
        return RevaniResponse(status: 403, message: 'Not invited to this call');
      }

      var participant = callSession.participants[participantIndex];
      participant = participant.copyWith(leftAt: DateTime.now());

      final updatedParticipants = List<RevaniCallParticipant>.from(
        callSession.participants,
      );
      updatedParticipants[participantIndex] = participant;

      callSession = callSession.copyWith(
        status: RevaniCallStatus.rejected,
        participants: updatedParticipants,
      );

      return await database.update(
        bucket: 'calls',
        tag: callId,
        newValue: callSession.toJson(),
      );
    } catch (e) {
      return RevaniResponse(status: 500, message: e.toString());
    }
  }

  Future<RevaniResponse> joinCall({
    required String callId,
    required RevaniUserResponse user,
  }) async {
    try {
      final callData = await database.get(bucket: 'calls', tag: callId);
      if (callData == null) {
        return RevaniResponse(status: 404, message: 'Call not found');
      }

      var callSession = RevaniCallSession.fromJson(callData.value);

      if (callSession.status != RevaniCallStatus.active) {
        return RevaniResponse(status: 400, message: 'Call is not active');
      }

      if (callSession.participants.length >= callSession.maxParticipants) {
        return RevaniResponse(status: 400, message: 'Call is full');
      }

      final existingParticipantIndex = callSession.participants.indexWhere(
        (p) => p.user.uid == user.uid,
      );

      if (existingParticipantIndex != -1) {
        var participant = callSession.participants[existingParticipantIndex];
        if (participant.leftAt != null) {
          participant = participant.copyWith(leftAt: null);
          final updatedParticipants = List<RevaniCallParticipant>.from(
            callSession.participants,
          );
          updatedParticipants[existingParticipantIndex] = participant;
          callSession = callSession.copyWith(participants: updatedParticipants);
        } else {
          return RevaniResponse(status: 200, message: 'Already in call');
        }
      } else {
        final newParticipant = RevaniCallParticipant(
          user: user,
          joinedAt: DateTime.now(),
          videoEnabled:
              callSession.callType == RevaniCallType.video ||
              callSession.callType == RevaniCallType.groupVideo,
        );

        final updatedParticipants = List<RevaniCallParticipant>.from(
          callSession.participants,
        );
        updatedParticipants.add(newParticipant);
        callSession = callSession.copyWith(participants: updatedParticipants);
      }

      return await database.update(
        bucket: 'calls',
        tag: callId,
        newValue: callSession.toJson(),
      );
    } catch (e) {
      return RevaniResponse(status: 500, message: e.toString());
    }
  }

  Future<RevaniResponse> leaveCall({
    required String callId,
    required RevaniUserResponse user,
  }) async {
    try {
      final callData = await database.get(bucket: 'calls', tag: callId);
      if (callData == null) {
        return RevaniResponse(status: 404, message: 'Call not found');
      }

      var callSession = RevaniCallSession.fromJson(callData.value);

      final participantIndex = callSession.participants.indexWhere(
        (p) => p.user.uid == user.uid,
      );

      if (participantIndex == -1) {
        return RevaniResponse(status: 403, message: 'Not in this call');
      }

      var participant = callSession.participants[participantIndex];
      participant = participant.copyWith(leftAt: DateTime.now());

      final updatedParticipants = List<RevaniCallParticipant>.from(
        callSession.participants,
      );
      updatedParticipants[participantIndex] = participant;

      callSession = callSession.copyWith(participants: updatedParticipants);

      final activeParticipants = callSession.participants
          .where((p) => p.leftAt == null)
          .toList();

      if (activeParticipants.isEmpty) {
        callSession = callSession.copyWith(
          status: RevaniCallStatus.ended,
          endedAt: DateTime.now(),
        );
      } else if (callSession.host.uid == user.uid &&
          activeParticipants.isNotEmpty) {
        final newHost = activeParticipants.first;
        callSession = callSession.copyWith(host: newHost.user);
      }

      return await database.update(
        bucket: 'calls',
        tag: callId,
        newValue: callSession.toJson(),
      );
    } catch (e) {
      return RevaniResponse(status: 500, message: e.toString());
    }
  }

  Future<RevaniResponse> endCall({
    required String callId,
    required RevaniUserResponse host,
  }) async {
    try {
      final callData = await database.get(bucket: 'calls', tag: callId);
      if (callData == null) {
        return RevaniResponse(status: 404, message: 'Call not found');
      }

      var callSession = RevaniCallSession.fromJson(callData.value);

      if (callSession.host.uid != host.uid) {
        return RevaniResponse(status: 403, message: 'Not the call host');
      }

      final now = DateTime.now();
      final updatedParticipants = callSession.participants.map((participant) {
        return participant.copyWith(leftAt: participant.leftAt ?? now);
      }).toList();

      callSession = callSession.copyWith(
        status: RevaniCallStatus.ended,
        endedAt: now,
        participants: updatedParticipants,
      );

      final roomResponse = await livekit.closeRoom(roomName: 'call_$callId');
      if (!roomResponse.isSuccess) {
        print('Failed to close LiveKit room: ${roomResponse.message}');
      }

      return await database.update(
        bucket: 'calls',
        tag: callId,
        newValue: callSession.toJson(),
      );
    } catch (e) {
      return RevaniResponse(status: 500, message: e.toString());
    }
  }

  Future<RevaniResponse> toggleMute({
    required String callId,
    required RevaniUserResponse user,
    required bool muted,
  }) async {
    try {
      final callData = await database.get(bucket: 'calls', tag: callId);
      if (callData == null) {
        return RevaniResponse(status: 404, message: 'Call not found');
      }

      var callSession = RevaniCallSession.fromJson(callData.value);

      final participantIndex = callSession.participants.indexWhere(
        (p) => p.user.uid == user.uid,
      );

      if (participantIndex == -1) {
        return RevaniResponse(status: 403, message: 'Not in this call');
      }

      var participant = callSession.participants[participantIndex];
      participant = participant.copyWith(isMuted: muted);

      final updatedParticipants = List<RevaniCallParticipant>.from(
        callSession.participants,
      );
      updatedParticipants[participantIndex] = participant;

      callSession = callSession.copyWith(participants: updatedParticipants);

      return await database.update(
        bucket: 'calls',
        tag: callId,
        newValue: callSession.toJson(),
      );
    } catch (e) {
      return RevaniResponse(status: 500, message: e.toString());
    }
  }

  Future<RevaniResponse> toggleVideo({
    required String callId,
    required RevaniUserResponse user,
    required bool videoEnabled,
  }) async {
    try {
      final callData = await database.get(bucket: 'calls', tag: callId);
      if (callData == null) {
        return RevaniResponse(status: 404, message: 'Call not found');
      }

      var callSession = RevaniCallSession.fromJson(callData.value);

      final participantIndex = callSession.participants.indexWhere(
        (p) => p.user.uid == user.uid,
      );

      if (participantIndex == -1) {
        return RevaniResponse(status: 403, message: 'Not in this call');
      }

      var participant = callSession.participants[participantIndex];
      participant = participant.copyWith(videoEnabled: videoEnabled);

      final updatedParticipants = List<RevaniCallParticipant>.from(
        callSession.participants,
      );
      updatedParticipants[participantIndex] = participant;

      callSession = callSession.copyWith(participants: updatedParticipants);

      return await database.update(
        bucket: 'calls',
        tag: callId,
        newValue: callSession.toJson(),
      );
    } catch (e) {
      return RevaniResponse(status: 500, message: e.toString());
    }
  }

  Future<RevaniCallSession?> getCall({required String callId}) async {
    try {
      final callData = await database.get(bucket: 'calls', tag: callId);
      if (callData == null) return null;
      return RevaniCallSession.fromJson(callData.value);
    } catch (e) {
      return null;
    }
  }

  Future<List<RevaniCallSession>> getUserCalls({
    required String userId,
    RevaniCallStatus? status,
    int? limit,
    int? offset,
  }) async {
    try {
      final allCalls = await database.getAll('calls');

      List<RevaniCallSession> userCalls = [];
      for (var item in allCalls) {
        final call = RevaniCallSession.fromJson(item.value);
        final isParticipant = call.participants.any(
          (p) => p.user.uid == userId,
        );
        if (isParticipant) {
          if (status == null || call.status == status) {
            userCalls.add(call);
          }
        }
      }

      userCalls.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      final startIndex = offset ?? 0;
      final endIndex = limit != null
          ? (startIndex + limit).clamp(0, userCalls.length)
          : userCalls.length;

      if (startIndex >= userCalls.length) {
        return [];
      }

      return userCalls.sublist(startIndex, endIndex);
    } catch (e) {
      return [];
    }
  }

  Future<RevaniResponse> updateCallSettings({
    required String callId,
    required RevaniUserResponse user,
    required Map<String, dynamic> settings,
  }) async {
    try {
      final callData = await database.get(bucket: 'calls', tag: callId);
      if (callData == null) {
        return RevaniResponse(status: 404, message: 'Call not found');
      }

      var callSession = RevaniCallSession.fromJson(callData.value);

      if (callSession.host.uid != user.uid) {
        return RevaniResponse(status: 403, message: 'Not the call host');
      }

      callSession = callSession.copyWith(callSettings: settings);

      return await database.update(
        bucket: 'calls',
        tag: callId,
        newValue: callSession.toJson(),
      );
    } catch (e) {
      return RevaniResponse(status: 500, message: e.toString());
    }
  }

  Future<RevaniResponse> generateLiveKitToken({
    required String callId,
    required RevaniUserResponse user,
  }) async {
    try {
      final callData = await database.get(bucket: 'calls', tag: callId);
      if (callData == null) {
        return RevaniResponse(status: 404, message: 'Call not found');
      }

      final callSession = RevaniCallSession.fromJson(callData.value);
      final isParticipant = callSession.participants.any(
        (p) => p.user.uid == user.uid,
      );
      if (!isParticipant) {
        return RevaniResponse(status: 403, message: 'Not a call participant');
      }

      final tokenResponse = await livekit.createToken(
        roomName: 'call_$callId',
        userID: user.uid,
        userName: user.displayName.isNotEmpty
            ? user.displayName
            : user.username,
        isAdmin: callSession.host.uid == user.uid,
      );

      if (!tokenResponse.isSuccess) {
        return RevaniResponse(
          status: tokenResponse.status,
          message: tokenResponse.message,
          error: tokenResponse.error,
        );
      }

      return tokenResponse;
    } catch (e) {
      return RevaniResponse(status: 500, message: e.toString());
    }
  }

  Future<RevaniResponse> startRecording({
    required String callId,
    required RevaniUserResponse user,
  }) async {
    try {
      final callData = await database.get(bucket: 'calls', tag: callId);
      if (callData == null) {
        return RevaniResponse(status: 404, message: 'Call not found');
      }

      var callSession = RevaniCallSession.fromJson(callData.value);

      if (callSession.host.uid != user.uid) {
        return RevaniResponse(status: 403, message: 'Not the call host');
      }

      if (callSession.isRecording) {
        return RevaniResponse(
          status: 400,
          message: 'Recording already in progress',
        );
      }

      callSession = callSession.copyWith(isRecording: true);

      return await database.update(
        bucket: 'calls',
        tag: callId,
        newValue: callSession.toJson(),
      );
    } catch (e) {
      return RevaniResponse(status: 500, message: e.toString());
    }
  }

  Future<RevaniResponse> stopRecording({
    required String callId,
    required RevaniUserResponse user,
    required String recordingUrl,
  }) async {
    try {
      final callData = await database.get(bucket: 'calls', tag: callId);
      if (callData == null) {
        return RevaniResponse(status: 404, message: 'Call not found');
      }

      var callSession = RevaniCallSession.fromJson(callData.value);

      if (callSession.host.uid != user.uid) {
        return RevaniResponse(status: 403, message: 'Not the call host');
      }

      if (!callSession.isRecording) {
        return RevaniResponse(status: 400, message: 'No recording in progress');
      }

      callSession = callSession.copyWith(
        isRecording: false,
        recordingUrl: recordingUrl,
      );

      return await database.update(
        bucket: 'calls',
        tag: callId,
        newValue: callSession.toJson(),
      );
    } catch (e) {
      return RevaniResponse(status: 500, message: e.toString());
    }
  }

  Future<RevaniResponse> sendCallNotification({
    required String callId,
    required RevaniUserResponse caller,
    required RevaniUserResponse recipient,
    required RevaniCallType callType,
  }) async {
    try {
      return await _sendCallNotification(
        callId: callId,
        caller: caller,
        participant: recipient,
        callType: callType,
      );
    } catch (e) {
      return RevaniResponse(status: 500, message: e.toString());
    }
  }

  Future<RevaniResponse> _sendCallNotification({
    required String callId,
    required RevaniUserResponse caller,
    required RevaniUserResponse participant,
    required RevaniCallType callType,
  }) async {
    try {
      final notificationId = Uuid().v1();
      final notification = {
        'id': notificationId,
        'type': 'call',
        'callId': callId,
        'caller': caller.toJson(),
        'callType': callType.value,
        'timestamp': DateTime.now().toIso8601String(),
        'read': false,
      };

      return await database.add(
        bucket: 'notifications',
        tag: notificationId,
        value: {...notification, 'userId': participant.uid},
      );
    } catch (e) {
      return RevaniResponse(status: 500, message: e.toString());
    }
  }

  Future<List<RevaniCallSession>> getActiveCalls() async {
    try {
      final allCalls = await database.getAll('calls');

      List<RevaniCallSession> activeCalls = [];
      for (var item in allCalls) {
        final call = RevaniCallSession.fromJson(item.value);
        if (call.status == RevaniCallStatus.active) {
          activeCalls.add(call);
        }
      }

      return activeCalls;
    } catch (e) {
      return [];
    }
  }

  Future<RevaniResponse> updateCallMetadata({
    required String callId,
    required RevaniUserResponse user,
    required Map<String, dynamic> metadata,
  }) async {
    try {
      final callData = await database.get(bucket: 'calls', tag: callId);
      if (callData == null) {
        return RevaniResponse(status: 404, message: 'Call not found');
      }

      var callSession = RevaniCallSession.fromJson(callData.value);

      if (callSession.host.uid != user.uid) {
        return RevaniResponse(status: 403, message: 'Not the call host');
      }

      callSession = callSession.copyWith(metadata: metadata);

      return await database.update(
        bucket: 'calls',
        tag: callId,
        newValue: callSession.toJson(),
      );
    } catch (e) {
      return RevaniResponse(status: 500, message: e.toString());
    }
  }
}
