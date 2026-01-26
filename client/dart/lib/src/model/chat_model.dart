import 'user_response.dart';

class Chat {
  final List<RevaniUserResponse>? participants;
  final String? chatID;
  final String? chatName;
  final String? chatPhotoURL;
  final String? lastMessage;
  final DateTime? lastMessageTimestamp;
  final String? lastMessageSenderID;
  final int unreadCount;
  final bool isMuted;
  final String type;
  final DateTime? createdAt;
  final List<String>? adminIDs;
  final Map<String, dynamic>? themeSettings;
  final List<String>? pinnedMessageIDs;
  final bool isArchived;
  final bool isBlocked;
  final List<String>? typingUserIDs;
  final String? disappearingMessagesTimer;
  final Map<String, dynamic>? callHistorySummary;
  final List<String>? botIDs;
  final Map<String, dynamic>? moreData;

  Chat({
    this.participants,
    this.chatID,
    this.chatName,
    this.chatPhotoURL,
    this.lastMessage,
    this.lastMessageTimestamp,
    this.lastMessageSenderID,
    this.unreadCount = 0,
    this.isMuted = false,
    this.type = "private",
    this.createdAt,
    this.adminIDs,
    this.themeSettings,
    this.pinnedMessageIDs,
    this.isArchived = false,
    this.isBlocked = false,
    this.typingUserIDs,
    this.disappearingMessagesTimer,
    this.callHistorySummary,
    this.botIDs,
    this.moreData,
  });

  Map<String, dynamic> toJson() {
    var participantList = [];
    if (participants != null) {
      for (var element in participants!) {
        participantList.add(element.toJson());
      }
    }

    return {
      "participants": participantList,
      "chatID": chatID ?? "",
      "chatName": chatName,
      "chatPhotoURL": chatPhotoURL,
      "lastMessage": lastMessage,
      "lastMessageTimestamp": lastMessageTimestamp?.toIso8601String(),
      "lastMessageSenderID": lastMessageSenderID,
      "unreadCount": unreadCount,
      "isMuted": isMuted,
      "type": type,
      "createdAt": createdAt?.toIso8601String(),
      "adminIDs": adminIDs ?? [],
      "themeSettings": themeSettings ?? {},
      "pinnedMessageIDs": pinnedMessageIDs ?? [],
      "isArchived": isArchived,
      "isBlocked": isBlocked,
      "typingUserIDs": typingUserIDs ?? [],
      "disappearingMessagesTimer": disappearingMessagesTimer,
      "callHistorySummary": callHistorySummary ?? {},
      "botIDs": botIDs ?? [],
      "moreData": moreData ?? {},
    };
  }

  Chat copyWith({
    List<RevaniUserResponse>? participants,
    String? chatID,
    String? chatName,
    String? chatPhotoURL,
    String? lastMessage,
    DateTime? lastMessageTimestamp,
    String? lastMessageSenderID,
    int? unreadCount,
    bool? isMuted,
    String? type,
    DateTime? createdAt,
    List<String>? adminIDs,
    Map<String, dynamic>? themeSettings,
    List<String>? pinnedMessageIDs,
    bool? isArchived,
    bool? isBlocked,
    List<String>? typingUserIDs,
    String? disappearingMessagesTimer,
    Map<String, dynamic>? callHistorySummary,
    List<String>? botIDs,
    Map<String, dynamic>? moreData,
  }) {
    return Chat(
      participants: participants ?? this.participants,
      chatID: chatID ?? this.chatID,
      chatName: chatName ?? this.chatName,
      chatPhotoURL: chatPhotoURL ?? this.chatPhotoURL,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTimestamp: lastMessageTimestamp ?? this.lastMessageTimestamp,
      lastMessageSenderID: lastMessageSenderID ?? this.lastMessageSenderID,
      unreadCount: unreadCount ?? this.unreadCount,
      isMuted: isMuted ?? this.isMuted,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      adminIDs: adminIDs ?? this.adminIDs,
      themeSettings: themeSettings ?? this.themeSettings,
      pinnedMessageIDs: pinnedMessageIDs ?? this.pinnedMessageIDs,
      isArchived: isArchived ?? this.isArchived,
      isBlocked: isBlocked ?? this.isBlocked,
      typingUserIDs: typingUserIDs ?? this.typingUserIDs,
      disappearingMessagesTimer:
          disappearingMessagesTimer ?? this.disappearingMessagesTimer,
      callHistorySummary: callHistorySummary ?? this.callHistorySummary,
      botIDs: botIDs ?? this.botIDs,
      moreData: moreData ?? this.moreData,
    );
  }

  factory Chat.fromJson(Map<String, dynamic> data) {
    List<RevaniUserResponse> participantList = [];
    if (data["participants"] != null) {
      for (var element in data["participants"]!) {
        participantList.add(RevaniUserResponse.fromJson(element));
      }
    }

    return Chat(
      participants: participantList,
      chatID: data["chatID"] ?? "",
      chatName: data["chatName"],
      chatPhotoURL: data["chatPhotoURL"],
      lastMessage: data["lastMessage"],
      lastMessageTimestamp: data["lastMessageTimestamp"] != null
          ? DateTime.tryParse(data["lastMessageTimestamp"])
          : null,
      lastMessageSenderID: data["lastMessageSenderID"],
      unreadCount: data["unreadCount"] ?? 0,
      isMuted: data["isMuted"] ?? false,
      type: data["type"] ?? "private",
      createdAt: data["createdAt"] != null
          ? DateTime.tryParse(data["createdAt"])
          : null,
      adminIDs: data["adminIDs"] != null
          ? List<String>.from(data["adminIDs"])
          : null,
      themeSettings: data["themeSettings"] != null
          ? Map<String, dynamic>.from(data["themeSettings"])
          : null,
      pinnedMessageIDs: data["pinnedMessageIDs"] != null
          ? List<String>.from(data["pinnedMessageIDs"])
          : null,
      isArchived: data["isArchived"] ?? false,
      isBlocked: data["isBlocked"] ?? false,
      typingUserIDs: data["typingUserIDs"] != null
          ? List<String>.from(data["typingUserIDs"])
          : null,
      disappearingMessagesTimer: data["disappearingMessagesTimer"],
      callHistorySummary: data["callHistorySummary"] != null
          ? Map<String, dynamic>.from(data["callHistorySummary"])
          : null,
      botIDs: data["botIDs"] != null ? List<String>.from(data["botIDs"]) : null,
      moreData: data["moreData"] != null
          ? Map<String, dynamic>.from(data["moreData"])
          : null,
    );
  }
}
