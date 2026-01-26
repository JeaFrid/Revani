

import 'user_response.dart';

enum RevaniCallType { audio, video, groupAudio, groupVideo }

extension RevaniCallTypeExtension on RevaniCallType {
  String get value {
    switch (this) {
      case RevaniCallType.audio:
        return 'audio';
      case RevaniCallType.video:
        return 'video';
      case RevaniCallType.groupAudio:
        return 'group_audio';
      case RevaniCallType.groupVideo:
        return 'group_video';
    }
  }
}

enum RevaniCallStatus { ringing, active, ended, missed, rejected, cancelled }

extension RevaniCallStatusExtension on RevaniCallStatus {
  String get value {
    switch (this) {
      case RevaniCallStatus.ringing:
        return 'ringing';
      case RevaniCallStatus.active:
        return 'active';
      case RevaniCallStatus.ended:
        return 'ended';
      case RevaniCallStatus.missed:
        return 'missed';
      case RevaniCallStatus.rejected:
        return 'rejected';
      case RevaniCallStatus.cancelled:
        return 'cancelled';
    }
  }
}

class RevaniCallParticipant {
  final RevaniUserResponse user;
  final DateTime joinedAt;
  final DateTime? leftAt;
  final bool isMuted;
  final bool videoEnabled;
  final bool isHost;
  final Map<String, dynamic> metadata;

  RevaniCallParticipant({
    required this.user,
    required this.joinedAt,
    this.leftAt,
    this.isMuted = false,
    this.videoEnabled = true,
    this.isHost = false,
    this.metadata = const {},
  });

  Map<String, dynamic> toJson() {
    return {
      'user': user.toJson(),
      'joinedAt': joinedAt.toIso8601String(),
      'leftAt': leftAt?.toIso8601String(),
      'isMuted': isMuted,
      'videoEnabled': videoEnabled,
      'isHost': isHost,
      'metadata': metadata,
    };
  }

  RevaniCallParticipant copyWith({
    RevaniUserResponse? user,
    DateTime? joinedAt,
    DateTime? leftAt,
    bool? isMuted,
    bool? videoEnabled,
    bool? isHost,
    Map<String, dynamic>? metadata,
  }) {
    return RevaniCallParticipant(
      user: user ?? this.user,
      joinedAt: joinedAt ?? this.joinedAt,
      leftAt: leftAt ?? this.leftAt,
      isMuted: isMuted ?? this.isMuted,
      videoEnabled: videoEnabled ?? this.videoEnabled,
      isHost: isHost ?? this.isHost,
      metadata: metadata ?? this.metadata,
    );
  }

  factory RevaniCallParticipant.fromJson(Map<String, dynamic> json) {
    return RevaniCallParticipant(
      user: RevaniUserResponse.fromJson(json['user']),
      joinedAt: DateTime.parse(json['joinedAt']),
      leftAt: json['leftAt'] != null ? DateTime.parse(json['leftAt']) : null,
      isMuted: json['isMuted'] ?? false,
      videoEnabled: json['videoEnabled'] ?? true,
      isHost: json['isHost'] ?? false,
      metadata: json['metadata'] != null
          ? Map<String, dynamic>.from(json['metadata'])
          : {},
    );
  }
}

class RevaniCallSession {
  final String callId;
  final RevaniUserResponse host;
  final String callName;
  final RevaniCallType callType;
  final RevaniCallStatus status;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final List<RevaniCallParticipant> participants;
  final int maxParticipants;
  final bool isRecording;
  final String? recordingUrl;
  final Map<String, dynamic> callSettings;
  final Map<String, dynamic> metadata;

  RevaniCallSession({
    required this.callId,
    required this.host,
    required this.callName,
    required this.callType,
    required this.status,
    required this.createdAt,
    this.startedAt,
    this.endedAt,
    List<RevaniCallParticipant>? participants,
    this.maxParticipants = 10,
    this.isRecording = false,
    this.recordingUrl,
    Map<String, dynamic>? callSettings,
    Map<String, dynamic>? metadata,
  }) : participants = participants ?? [],
       callSettings = callSettings ?? {},
       metadata = metadata ?? {};

  Map<String, dynamic> toJson() {
    return {
      'callId': callId,
      'host': host.toJson(),
      'callName': callName,
      'callType': callType.value,
      'status': status.value,
      'createdAt': createdAt.toIso8601String(),
      'startedAt': startedAt?.toIso8601String(),
      'endedAt': endedAt?.toIso8601String(),
      'participants': participants.map((p) => p.toJson()).toList(),
      'maxParticipants': maxParticipants,
      'isRecording': isRecording,
      'recordingUrl': recordingUrl,
      'callSettings': callSettings,
      'metadata': metadata,
    };
  }

  RevaniCallSession copyWith({
    String? callId,
    RevaniUserResponse? host,
    String? callName,
    RevaniCallType? callType,
    RevaniCallStatus? status,
    DateTime? createdAt,
    DateTime? startedAt,
    DateTime? endedAt,
    List<RevaniCallParticipant>? participants,
    int? maxParticipants,
    bool? isRecording,
    String? recordingUrl,
    Map<String, dynamic>? callSettings,
    Map<String, dynamic>? metadata,
  }) {
    return RevaniCallSession(
      callId: callId ?? this.callId,
      host: host ?? this.host,
      callName: callName ?? this.callName,
      callType: callType ?? this.callType,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      participants: participants ?? this.participants,
      maxParticipants: maxParticipants ?? this.maxParticipants,
      isRecording: isRecording ?? this.isRecording,
      recordingUrl: recordingUrl ?? this.recordingUrl,
      callSettings: callSettings ?? this.callSettings,
      metadata: metadata ?? this.metadata,
    );
  }

  factory RevaniCallSession.fromJson(Map<String, dynamic> json) {
    List<RevaniCallParticipant> participantList = [];
    if (json['participants'] != null) {
      for (var element in json['participants']) {
        participantList.add(RevaniCallParticipant.fromJson(element));
      }
    }

    RevaniCallType getCallType(String type) {
      switch (type) {
        case 'audio':
          return RevaniCallType.audio;
        case 'video':
          return RevaniCallType.video;
        case 'group_audio':
          return RevaniCallType.groupAudio;
        case 'group_video':
          return RevaniCallType.groupVideo;
        default:
          return RevaniCallType.audio;
      }
    }

    RevaniCallStatus getCallStatus(String status) {
      switch (status) {
        case 'ringing':
          return RevaniCallStatus.ringing;
        case 'active':
          return RevaniCallStatus.active;
        case 'ended':
          return RevaniCallStatus.ended;
        case 'missed':
          return RevaniCallStatus.missed;
        case 'rejected':
          return RevaniCallStatus.rejected;
        case 'cancelled':
          return RevaniCallStatus.cancelled;
        default:
          return RevaniCallStatus.active;
      }
    }

    return RevaniCallSession(
      callId: json['callId'] ?? '',
      host: RevaniUserResponse.fromJson(json['host']),
      callName: json['callName'] ?? '',
      callType: getCallType(json['callType'] ?? 'audio'),
      status: getCallStatus(json['status'] ?? 'active'),
      createdAt: DateTime.parse(json['createdAt']),
      startedAt: json['startedAt'] != null
          ? DateTime.tryParse(json['startedAt'])
          : null,
      endedAt: json['endedAt'] != null
          ? DateTime.tryParse(json['endedAt'])
          : null,
      participants: participantList,
      maxParticipants: json['maxParticipants'] ?? 10,
      isRecording: json['isRecording'] ?? false,
      recordingUrl: json['recordingUrl'],
      callSettings: json['callSettings'] != null
          ? Map<String, dynamic>.from(json['callSettings'])
          : {},
      metadata: json['metadata'] != null
          ? Map<String, dynamic>.from(json['metadata'])
          : {},
    );
  }
}