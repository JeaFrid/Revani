class RevaniMediaDimensions {
  final int width;
  final int height;

  RevaniMediaDimensions({required this.width, required this.height});

  Map<String, dynamic> toJson() => {'width': width, 'height': height};
  factory RevaniMediaDimensions.fromJson(Map<String, dynamic> json) {
    return RevaniMediaDimensions(
      width: json['width'] ?? 0,
      height: json['height'] ?? 0,
    );
  }
}

class RevaniMedia {
  final String url;
  final String? thumbnailUrl;
  final int? fileSize;
  final String fileName;
  final String mimeType;
  final Duration? duration;
  final RevaniMediaDimensions? dimensions;

  RevaniMedia({
    required this.url,
    this.thumbnailUrl,
    this.fileSize,
    required this.fileName,
    required this.mimeType,
    this.duration,
    this.dimensions,
  });

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'thumbnailUrl': thumbnailUrl,
      'fileSize': fileSize,
      'fileName': fileName,
      'mimeType': mimeType,
      'duration': duration?.inMilliseconds,
      'dimensions': dimensions?.toJson(),
    };
  }

  factory RevaniMedia.fromJson(Map<String, dynamic> json) {
    return RevaniMedia(
      url: json['url'] ?? '',
      thumbnailUrl: json['thumbnailUrl'],
      fileSize: json['fileSize'],
      fileName: json['fileName'] ?? '',
      mimeType: json['mimeType'] ?? '',
      duration: json['duration'] != null
          ? Duration(milliseconds: json['duration'])
          : null,
      dimensions: json['dimensions'] != null
          ? RevaniMediaDimensions.fromJson(json['dimensions'])
          : null,
    );
  }
}

class RevaniLocation {
  final double latitude;
  final double longitude;
  final String? name;
  final String? address;

  RevaniLocation({
    required this.latitude,
    required this.longitude,
    this.name,
    this.address,
  });

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'name': name,
      'address': address,
    };
  }

  factory RevaniLocation.fromJson(Map<String, dynamic> json) {
    return RevaniLocation(
      latitude: json['latitude'] ?? 0.0,
      longitude: json['longitude'] ?? 0.0,
      name: json['name'],
      address: json['address'],
    );
  }
}

class RevaniContact {
  final String name;
  final String? phoneNumber;
  final String? email;

  RevaniContact({required this.name, this.phoneNumber, this.email});

  Map<String, dynamic> toJson() {
    return {'name': name, 'phoneNumber': phoneNumber, 'email': email};
  }

  factory RevaniContact.fromJson(Map<String, dynamic> json) {
    return RevaniContact(
      name: json['name'] ?? '',
      phoneNumber: json['phoneNumber'],
      email: json['email'],
    );
  }
}

class RevaniReaction {
  final String emoji;
  final String userId;
  final DateTime timestamp;

  RevaniReaction({
    required this.emoji,
    required this.userId,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'emoji': emoji,
      'userId': userId,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory RevaniReaction.fromJson(Map<String, dynamic> json) {
    return RevaniReaction(
      emoji: json['emoji'] ?? '',
      userId: json['userId'] ?? '',
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}

class RevaniMessageReactions {
  final Map<String, List<RevaniReaction>> reactions;

  RevaniMessageReactions({Map<String, List<RevaniReaction>>? reactions})
    : reactions = reactions ?? {};

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> result = {};
    reactions.forEach((emoji, reactionList) {
      result[emoji] = reactionList.map((r) => r.toJson()).toList();
    });
    return result;
  }

  factory RevaniMessageReactions.fromJson(Map<String, dynamic> json) {
    final Map<String, List<RevaniReaction>> reactionsMap = {};

    json.forEach((emoji, reactionData) {
      if (reactionData is List) {
        reactionsMap[emoji] = reactionData
            .map<RevaniReaction>((item) => RevaniReaction.fromJson(item))
            .toList();
      }
    });

    return RevaniMessageReactions(reactions: reactionsMap);
  }
}

class RevaniMessageStatusInfo {
  final List<String> deliveredTo;
  final List<String> readBy;
  final DateTime? deliveredAt;
  final DateTime? readAt;

  RevaniMessageStatusInfo({
    List<String>? deliveredTo,
    List<String>? readBy,
    this.deliveredAt,
    this.readAt,
  }) : deliveredTo = deliveredTo ?? [],
       readBy = readBy ?? [];

  Map<String, dynamic> toJson() {
    return {
      'deliveredTo': deliveredTo,
      'readBy': readBy,
      'deliveredAt': deliveredAt?.toIso8601String(),
      'readAt': readAt?.toIso8601String(),
    };
  }

  RevaniMessageStatusInfo copyWith({
    List<String>? deliveredTo,
    List<String>? readBy,
    DateTime? deliveredAt,
    DateTime? readAt,
  }) {
    return RevaniMessageStatusInfo(
      deliveredTo: deliveredTo ?? this.deliveredTo,
      readBy: readBy ?? this.readBy,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      readAt: readAt ?? this.readAt,
    );
  }

  factory RevaniMessageStatusInfo.fromJson(Map<String, dynamic> json) {
    return RevaniMessageStatusInfo(
      deliveredTo: json['deliveredTo'] != null
          ? List<String>.from(json['deliveredTo'])
          : [],
      readBy: json['readBy'] != null ? List<String>.from(json['readBy']) : [],
      deliveredAt: json['deliveredAt'] != null
          ? DateTime.tryParse(json['deliveredAt'])
          : null,
      readAt: json['readAt'] != null ? DateTime.tryParse(json['readAt']) : null,
    );
  }
}

class RevaniSystemMessageData {
  final String type;
  final String? userId;
  final String? userName;
  final String? oldValue;
  final String? newValue;

  RevaniSystemMessageData({
    required this.type,
    this.userId,
    this.userName,
    this.oldValue,
    this.newValue,
  });

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'userId': userId,
      'userName': userName,
      'oldValue': oldValue,
      'newValue': newValue,
    };
  }

  factory RevaniSystemMessageData.fromJson(Map<String, dynamic> json) {
    return RevaniSystemMessageData(
      type: json['type'] ?? '',
      userId: json['userId'],
      userName: json['userName'],
      oldValue: json['oldValue'],
      newValue: json['newValue'],
    );
  }
}

class RevaniInteractiveButton {
  final String id;
  final String text;
  final String type;
  final String? payload;

  RevaniInteractiveButton({
    required this.id,
    required this.text,
    required this.type,
    this.payload,
  });

  Map<String, dynamic> toJson() {
    return {'id': id, 'text': text, 'type': type, 'payload': payload};
  }

  factory RevaniInteractiveButton.fromJson(Map<String, dynamic> json) {
    return RevaniInteractiveButton(
      id: json['id'] ?? '',
      text: json['text'] ?? '',
      type: json['type'] ?? '',
      payload: json['payload'],
    );
  }
}

class RevaniMessage {
  final String messageId;
  final String chatId;
  final String senderId;
  final String text;
  final DateTime timestamp;
  final String messageType;
  final String status;
  final bool isEdited;
  final DateTime? editedTimestamp;
  final bool isDeleted;
  final bool deletedForEveryone;
  final bool isForwarded;
  final String? forwardedFrom;
  final RevaniMedia? media;
  final RevaniLocation? location;
  final RevaniContact? contact;
  final String? replyToMessageId;
  final List<String> mentions;
  final RevaniMessageReactions reactions;
  final RevaniMessageStatusInfo statusInfo;
  final List<String> starredBy;
  final bool isPinned;
  final String? pinnedBy;
  final DateTime? pinnedTimestamp;
  final bool isSystemMessage;
  final RevaniSystemMessageData? systemMessageData;
  final bool encrypted;
  final String? encryptionKey;
  final Duration? selfDestructTimer;
  final DateTime? selfDestructTimestamp;
  final String? localId;
  final String? serverId;
  final int sequenceNumber;
  final String? botId;
  final List<RevaniInteractiveButton> interactiveButtons;
  final Map<String, dynamic> metadata;

  RevaniMessage({
    required this.messageId,
    required this.chatId,
    required this.senderId,
    required this.text,
    required this.timestamp,
    this.messageType = 'text',
    this.status = 'sent',
    this.isEdited = false,
    this.editedTimestamp,
    this.isDeleted = false,
    this.deletedForEveryone = false,
    this.isForwarded = false,
    this.forwardedFrom,
    this.media,
    this.location,
    this.contact,
    this.replyToMessageId,
    List<String>? mentions,
    RevaniMessageReactions? reactions,
    RevaniMessageStatusInfo? statusInfo,
    List<String>? starredBy,
    this.isPinned = false,
    this.pinnedBy,
    this.pinnedTimestamp,
    this.isSystemMessage = false,
    this.systemMessageData,
    this.encrypted = false,
    this.encryptionKey,
    this.selfDestructTimer,
    this.selfDestructTimestamp,
    this.localId,
    this.serverId,
    this.sequenceNumber = 0,
    this.botId,
    List<RevaniInteractiveButton>? interactiveButtons,
    Map<String, dynamic>? metadata,
  }) : mentions = mentions ?? [],
       reactions = reactions ?? RevaniMessageReactions(),
       statusInfo = statusInfo ?? RevaniMessageStatusInfo(),
       starredBy = starredBy ?? [],
       interactiveButtons = interactiveButtons ?? [],
       metadata = metadata ?? {};

  Map<String, dynamic> toJson() {
    return {
      'messageId': messageId,
      'chatId': chatId,
      'senderId': senderId,
      'text': text,
      'timestamp': timestamp.toIso8601String(),
      'messageType': messageType,
      'status': status,
      'isEdited': isEdited,
      'editedTimestamp': editedTimestamp?.toIso8601String(),
      'isDeleted': isDeleted,
      'deletedForEveryone': deletedForEveryone,
      'isForwarded': isForwarded,
      'forwardedFrom': forwardedFrom,
      'media': media?.toJson(),
      'location': location?.toJson(),
      'contact': contact?.toJson(),
      'replyToMessageId': replyToMessageId,
      'mentions': mentions,
      'reactions': reactions.toJson(),
      'statusInfo': statusInfo.toJson(),
      'starredBy': starredBy,
      'isPinned': isPinned,
      'pinnedBy': pinnedBy,
      'pinnedTimestamp': pinnedTimestamp?.toIso8601String(),
      'isSystemMessage': isSystemMessage,
      'systemMessageData': systemMessageData?.toJson(),
      'encrypted': encrypted,
      'encryptionKey': encryptionKey,
      'selfDestructTimer': selfDestructTimer?.inSeconds,
      'selfDestructTimestamp': selfDestructTimestamp?.toIso8601String(),
      'localId': localId,
      'serverId': serverId,
      'sequenceNumber': sequenceNumber,
      'botId': botId,
      'interactiveButtons': interactiveButtons.map((b) => b.toJson()).toList(),
      'metadata': metadata,
    };
  }

  factory RevaniMessage.fromJson(Map<String, dynamic> json) {
    return RevaniMessage(
      messageId: json['messageId'] ?? '',
      chatId: json['chatId'] ?? '',
      senderId: json['senderId'] ?? '',
      text: json['text'] ?? '',
      timestamp: DateTime.parse(json['timestamp']),
      messageType: json['messageType'] ?? 'text',
      status: json['status'] ?? 'sent',
      isEdited: json['isEdited'] ?? false,
      editedTimestamp: json['editedTimestamp'] != null
          ? DateTime.tryParse(json['editedTimestamp'])
          : null,
      isDeleted: json['isDeleted'] ?? false,
      deletedForEveryone: json['deletedForEveryone'] ?? false,
      isForwarded: json['isForwarded'] ?? false,
      forwardedFrom: json['forwardedFrom'],
      media: json['media'] != null ? RevaniMedia.fromJson(json['media']) : null,
      location: json['location'] != null
          ? RevaniLocation.fromJson(json['location'])
          : null,
      contact: json['contact'] != null
          ? RevaniContact.fromJson(json['contact'])
          : null,
      replyToMessageId: json['replyToMessageId'],
      mentions: json['mentions'] != null
          ? List<String>.from(json['mentions'])
          : [],
      reactions: json['reactions'] != null
          ? RevaniMessageReactions.fromJson(json['reactions'])
          : RevaniMessageReactions(),
      statusInfo: json['statusInfo'] != null
          ? RevaniMessageStatusInfo.fromJson(json['statusInfo'])
          : RevaniMessageStatusInfo(),
      starredBy: json['starredBy'] != null
          ? List<String>.from(json['starredBy'])
          : [],
      isPinned: json['isPinned'] ?? false,
      pinnedBy: json['pinnedBy'],
      pinnedTimestamp: json['pinnedTimestamp'] != null
          ? DateTime.tryParse(json['pinnedTimestamp'])
          : null,
      isSystemMessage: json['isSystemMessage'] ?? false,
      systemMessageData: json['systemMessageData'] != null
          ? RevaniSystemMessageData.fromJson(json['systemMessageData'])
          : null,
      encrypted: json['encrypted'] ?? false,
      encryptionKey: json['encryptionKey'],
      selfDestructTimer: json['selfDestructTimer'] != null
          ? Duration(seconds: json['selfDestructTimer'])
          : null,
      selfDestructTimestamp: json['selfDestructTimestamp'] != null
          ? DateTime.tryParse(json['selfDestructTimestamp'])
          : null,
      localId: json['localId'],
      serverId: json['serverId'],
      sequenceNumber: json['sequenceNumber'] ?? 0,
      botId: json['botId'],
      interactiveButtons: json['interactiveButtons'] != null
          ? (json['interactiveButtons'] as List)
                .map((item) => RevaniInteractiveButton.fromJson(item))
                .toList()
          : [],
      metadata: json['metadata'] != null
          ? Map<String, dynamic>.from(json['metadata'])
          : {},
    );
  }

  RevaniMessage copyWith({
    String? messageId,
    String? chatId,
    String? senderId,
    String? text,
    DateTime? timestamp,
    String? messageType,
    String? status,
    bool? isEdited,
    DateTime? editedTimestamp,
    bool? isDeleted,
    bool? deletedForEveryone,
    bool? isForwarded,
    String? forwardedFrom,
    RevaniMedia? media,
    RevaniLocation? location,
    RevaniContact? contact,
    String? replyToMessageId,
    List<String>? mentions,
    RevaniMessageReactions? reactions,
    RevaniMessageStatusInfo? statusInfo,
    List<String>? starredBy,
    bool? isPinned,
    String? pinnedBy,
    DateTime? pinnedTimestamp,
    bool? isSystemMessage,
    RevaniSystemMessageData? systemMessageData,
    bool? encrypted,
    String? encryptionKey,
    Duration? selfDestructTimer,
    DateTime? selfDestructTimestamp,
    String? localId,
    String? serverId,
    int? sequenceNumber,
    String? botId,
    List<RevaniInteractiveButton>? interactiveButtons,
    Map<String, dynamic>? metadata,
  }) {
    return RevaniMessage(
      messageId: messageId ?? this.messageId,
      chatId: chatId ?? this.chatId,
      senderId: senderId ?? this.senderId,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      messageType: messageType ?? this.messageType,
      status: status ?? this.status,
      isEdited: isEdited ?? this.isEdited,
      editedTimestamp: editedTimestamp ?? this.editedTimestamp,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedForEveryone: deletedForEveryone ?? this.deletedForEveryone,
      isForwarded: isForwarded ?? this.isForwarded,
      forwardedFrom: forwardedFrom ?? this.forwardedFrom,
      media: media ?? this.media,
      location: location ?? this.location,
      contact: contact ?? this.contact,
      replyToMessageId: replyToMessageId ?? this.replyToMessageId,
      mentions: mentions ?? this.mentions,
      reactions: reactions ?? this.reactions,
      statusInfo: statusInfo ?? this.statusInfo,
      starredBy: starredBy ?? this.starredBy,
      isPinned: isPinned ?? this.isPinned,
      pinnedBy: pinnedBy ?? this.pinnedBy,
      pinnedTimestamp: pinnedTimestamp ?? this.pinnedTimestamp,
      isSystemMessage: isSystemMessage ?? this.isSystemMessage,
      systemMessageData: systemMessageData ?? this.systemMessageData,
      encrypted: encrypted ?? this.encrypted,
      encryptionKey: encryptionKey ?? this.encryptionKey,
      selfDestructTimer: selfDestructTimer ?? this.selfDestructTimer,
      selfDestructTimestamp:
          selfDestructTimestamp ?? this.selfDestructTimestamp,
      localId: localId ?? this.localId,
      serverId: serverId ?? this.serverId,
      sequenceNumber: sequenceNumber ?? this.sequenceNumber,
      botId: botId ?? this.botId,
      interactiveButtons: interactiveButtons ?? this.interactiveButtons,
      metadata: metadata ?? this.metadata,
    );
  }
}
