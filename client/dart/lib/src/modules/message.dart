import '../model/chat_model.dart';
import '../model/message_model.dart';
import '../model/user_response.dart';
import '../services/revani_base.dart';
import '../services/revani_database_serv.dart';
import '../source/api.dart';
import 'package:uuid/uuid.dart';

class RevaniChat {
  RevaniChat();
  RevaniBaseDB database = RevaniBaseDB();
  RevaniBase revaniBase = RevaniBase();
  RevaniClient get revani => revaniBase.revani;
  RevaniData get db => revani.data;

  Future<RevaniResponse> createChat({
    required String chatId,
    required String chatName,
    required List<String> participantIds,
    required String type,
    String? chatPhotoURL,
    List<String>? adminIds,
    Map<String, dynamic>? themeSettings,
    String? disappearingMessagesTimer,
  }) async {
    try {
      final chat = Chat(
        chatID: chatId,
        chatName: chatName,
        chatPhotoURL: chatPhotoURL,
        type: type,
        adminIDs: adminIds ?? (type == "private" ? [] : participantIds),
        themeSettings: themeSettings,
        disappearingMessagesTimer: disappearingMessagesTimer,
        participants: null,
        createdAt: DateTime.now(),
      );

      return await database.add(
        bucket: "chats",
        tag: chatId,
        value: chat.toJson(),
      );
    } catch (e) {
      return RevaniResponse(status: 500, message: e.toString());
    }
  }

  Future<RevaniResponse> sendMessage({
    required String chatId,
    required String senderId,
    required String text,
    String? messageType,
    RevaniMedia? media,
    RevaniLocation? location,
    RevaniContact? contact,
    String? replyToMessageId,
    List<String>? mentions,
    Duration? selfDestructTimer,
    String? botId,
    List<RevaniInteractiveButton>? interactiveButtons,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final messageId = Uuid().v1();
      final now = DateTime.now();
      final selfDestructTimestamp = selfDestructTimer != null
          ? now.add(selfDestructTimer)
          : null;

      final message = RevaniMessage(
        messageId: messageId,
        chatId: chatId,
        senderId: senderId,
        text: text,
        timestamp: now,
        messageType: messageType ?? 'text',
        status: 'sent',
        media: media,
        location: location,
        contact: contact,
        replyToMessageId: replyToMessageId,
        mentions: mentions ?? [],
        selfDestructTimer: selfDestructTimer,
        selfDestructTimestamp: selfDestructTimestamp,
        botId: botId,
        interactiveButtons: interactiveButtons ?? [],
        metadata: metadata ?? {},
      );

      final response = await database.add(
        bucket: "messages",
        tag: messageId,
        value: message.toJson(),
      );

      if (response.status == 200) {
        await _updateChatLastMessage(chatId, message);
      }

      return response;
    } catch (e) {
      return RevaniResponse(status: 500, message: e.toString());
    }
  }

  Future<List<RevaniMessage>> getMessages({
    required String chatId,
    int? limit,
    int? offset,
    String? beforeMessageId,
    DateTime? beforeTimestamp,
  }) async {
    try {
      final allMessages = await database.getAll("messages");

      List<RevaniMessage> chatMessages = [];
      for (var item in allMessages) {
        final message = RevaniMessage.fromJson(item.value);
        if (message.chatId == chatId) {
          chatMessages.add(message);
        }
      }

      chatMessages.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      if (beforeMessageId != null) {
        final index = chatMessages.indexWhere(
          (m) => m.messageId == beforeMessageId,
        );
        if (index != -1) {
          chatMessages = chatMessages.sublist(index + 1);
        }
      } else if (beforeTimestamp != null) {
        chatMessages = chatMessages
            .where((m) => m.timestamp.isBefore(beforeTimestamp))
            .toList();
      }

      final startIndex = offset ?? 0;
      final endIndex = limit != null
          ? (startIndex + limit).clamp(0, chatMessages.length)
          : chatMessages.length;

      if (startIndex >= chatMessages.length) {
        return [];
      }

      return chatMessages.sublist(startIndex, endIndex).reversed.toList();
    } catch (e) {
      return [];
    }
  }

  Future<RevaniResponse> editMessage({
    required String messageId,
    required String newText,
    String? editedBy,
  }) async {
    try {
      final messageData = await database.get(
        bucket: "messages",
        tag: messageId,
      );

      if (messageData == null) {
        return RevaniResponse(status: 404, message: "Message not found");
      }

      var message = RevaniMessage.fromJson(messageData.value);

      if (message.isDeleted) {
        return RevaniResponse(
          status: 400,
          message: "Cannot edit deleted message",
        );
      }

      message = message.copyWith(
        text: newText,
        isEdited: true,
        editedTimestamp: DateTime.now(),
      );

      return await database.update(
        bucket: "messages",
        tag: messageId,
        newValue: message.toJson(),
      );
    } catch (e) {
      return RevaniResponse(status: 500, message: e.toString());
    }
  }

  Future<RevaniResponse> deleteMessage({
    required String messageId,
    required String userId,
    bool deleteForEveryone = false,
  }) async {
    try {
      final messageData = await database.get(
        bucket: "messages",
        tag: messageId,
      );

      if (messageData == null) {
        return RevaniResponse(status: 404, message: "Message not found");
      }

      var message = RevaniMessage.fromJson(messageData.value);

      if (message.senderId != userId && !deleteForEveryone) {
        return RevaniResponse(status: 403, message: "Not authorized");
      }

      message = message.copyWith(
        isDeleted: true,
        deletedForEveryone: deleteForEveryone,
      );

      return await database.update(
        bucket: "messages",
        tag: messageId,
        newValue: message.toJson(),
      );
    } catch (e) {
      return RevaniResponse(status: 500, message: e.toString());
    }
  }

  Future<RevaniResponse> addReaction({
    required String messageId,
    required String userId,
    required String emoji,
  }) async {
    try {
      final messageData = await database.get(
        bucket: "messages",
        tag: messageId,
      );

      if (messageData == null) {
        return RevaniResponse(status: 404, message: "Message not found");
      }

      var message = RevaniMessage.fromJson(messageData.value);

      final existingReactions = message.reactions.reactions;
      final reactionsForEmoji = existingReactions[emoji] ?? [];

      final alreadyReacted = reactionsForEmoji.any((r) => r.userId == userId);
      if (alreadyReacted) {
        return RevaniResponse(status: 200, message: "Already reacted");
      }

      final newReaction = RevaniReaction(
        emoji: emoji,
        userId: userId,
        timestamp: DateTime.now(),
      );

      reactionsForEmoji.add(newReaction);
      existingReactions[emoji] = reactionsForEmoji;

      message = message.copyWith(
        reactions: RevaniMessageReactions(reactions: existingReactions),
      );

      return await database.update(
        bucket: "messages",
        tag: messageId,
        newValue: message.toJson(),
      );
    } catch (e) {
      return RevaniResponse(status: 500, message: e.toString());
    }
  }

  Future<RevaniResponse> removeReaction({
    required String messageId,
    required String userId,
    required String emoji,
  }) async {
    try {
      final messageData = await database.get(
        bucket: "messages",
        tag: messageId,
      );

      if (messageData == null) {
        return RevaniResponse(status: 404, message: "Message not found");
      }

      var message = RevaniMessage.fromJson(messageData.value);

      final existingReactions = message.reactions.reactions;
      final reactionsForEmoji = existingReactions[emoji] ?? [];

      final index = reactionsForEmoji.indexWhere((r) => r.userId == userId);
      if (index == -1) {
        return RevaniResponse(status: 200, message: "Reaction not found");
      }

      reactionsForEmoji.removeAt(index);

      if (reactionsForEmoji.isEmpty) {
        existingReactions.remove(emoji);
      } else {
        existingReactions[emoji] = reactionsForEmoji;
      }

      message = message.copyWith(
        reactions: RevaniMessageReactions(reactions: existingReactions),
      );

      return await database.update(
        bucket: "messages",
        tag: messageId,
        newValue: message.toJson(),
      );
    } catch (e) {
      return RevaniResponse(status: 500, message: e.toString());
    }
  }

  Future<RevaniResponse> markAsRead({
    required String messageId,
    required String userId,
  }) async {
    try {
      final messageData = await database.get(
        bucket: "messages",
        tag: messageId,
      );

      if (messageData == null) {
        return RevaniResponse(status: 404, message: "Message not found");
      }

      var message = RevaniMessage.fromJson(messageData.value);

      final readBy = message.statusInfo.readBy;
      if (!readBy.contains(userId)) {
        readBy.add(userId);
      }

      final statusInfo = message.statusInfo.copyWith(
        readBy: readBy,
        readAt: readBy.length == 1 ? DateTime.now() : message.statusInfo.readAt,
      );

      message = message.copyWith(statusInfo: statusInfo);

      return await database.update(
        bucket: "messages",
        tag: messageId,
        newValue: message.toJson(),
      );
    } catch (e) {
      return RevaniResponse(status: 500, message: e.toString());
    }
  }

  Future<RevaniResponse> markAsDelivered({
    required String messageId,
    required String userId,
  }) async {
    try {
      final messageData = await database.get(
        bucket: "messages",
        tag: messageId,
      );

      if (messageData == null) {
        return RevaniResponse(status: 404, message: "Message not found");
      }

      var message = RevaniMessage.fromJson(messageData.value);

      final deliveredTo = message.statusInfo.deliveredTo;
      if (!deliveredTo.contains(userId)) {
        deliveredTo.add(userId);
      }

      final statusInfo = message.statusInfo.copyWith(
        deliveredTo: deliveredTo,
        deliveredAt: deliveredTo.length == 1
            ? DateTime.now()
            : message.statusInfo.deliveredAt,
      );

      message = message.copyWith(statusInfo: statusInfo);

      return await database.update(
        bucket: "messages",
        tag: messageId,
        newValue: message.toJson(),
      );
    } catch (e) {
      return RevaniResponse(status: 500, message: e.toString());
    }
  }

  Future<RevaniResponse> forwardMessage({
    required String originalMessageId,
    required String targetChatId,
    required String senderId,
  }) async {
    try {
      final messageData = await database.get(
        bucket: "messages",
        tag: originalMessageId,
      );

      if (messageData == null) {
        return RevaniResponse(status: 404, message: "Message not found");
      }

      final originalMessage = RevaniMessage.fromJson(messageData.value);

      final newMessageId = Uuid().v1();
      final now = DateTime.now();

      final forwardedMessage = RevaniMessage(
        messageId: newMessageId,
        chatId: targetChatId,
        senderId: senderId,
        text: originalMessage.text,
        timestamp: now,
        messageType: originalMessage.messageType,
        status: 'sent',
        isForwarded: true,
        forwardedFrom: originalMessage.senderId,
        media: originalMessage.media,
        location: originalMessage.location,
        contact: originalMessage.contact,
        mentions: originalMessage.mentions,
      );

      final response = await database.add(
        bucket: "messages",
        tag: newMessageId,
        value: forwardedMessage.toJson(),
      );

      if (response.status == 200) {
        await _updateChatLastMessage(targetChatId, forwardedMessage);
      }

      return response;
    } catch (e) {
      return RevaniResponse(status: 500, message: e.toString());
    }
  }

  Future<RevaniResponse> pinMessage({
    required String messageId,
    required String pinnedBy,
    required String chatId,
  }) async {
    try {
      final messageData = await database.get(
        bucket: "messages",
        tag: messageId,
      );

      if (messageData == null) {
        return RevaniResponse(status: 404, message: "Message not found");
      }

      var message = RevaniMessage.fromJson(messageData.value);

      if (message.chatId != chatId) {
        return RevaniResponse(status: 400, message: "Message not in this chat");
      }

      message = message.copyWith(
        isPinned: true,
        pinnedBy: pinnedBy,
        pinnedTimestamp: DateTime.now(),
      );

      final chatData = await database.get(bucket: "chats", tag: chatId);
      if (chatData != null) {
        var chat = Chat.fromJson(chatData.value);
        final pinnedMessageIDs = chat.pinnedMessageIDs ?? [];
        if (!pinnedMessageIDs.contains(messageId)) {
          pinnedMessageIDs.add(messageId);
          chat = chat.copyWith(pinnedMessageIDs: pinnedMessageIDs);
          await database.update(
            bucket: "chats",
            tag: chatId,
            newValue: chat.toJson(),
          );
        }
      }

      return await database.update(
        bucket: "messages",
        tag: messageId,
        newValue: message.toJson(),
      );
    } catch (e) {
      return RevaniResponse(status: 500, message: e.toString());
    }
  }

  Future<RevaniResponse> unpinMessage({
    required String messageId,
    required String chatId,
  }) async {
    try {
      final messageData = await database.get(
        bucket: "messages",
        tag: messageId,
      );

      if (messageData == null) {
        return RevaniResponse(status: 404, message: "Message not found");
      }

      var message = RevaniMessage.fromJson(messageData.value);

      message = message.copyWith(
        isPinned: false,
        pinnedBy: null,
        pinnedTimestamp: null,
      );

      final chatData = await database.get(bucket: "chats", tag: chatId);
      if (chatData != null) {
        var chat = Chat.fromJson(chatData.value);
        final pinnedMessageIDs = chat.pinnedMessageIDs ?? [];
        pinnedMessageIDs.remove(messageId);
        chat = chat.copyWith(pinnedMessageIDs: pinnedMessageIDs);
        await database.update(
          bucket: "chats",
          tag: chatId,
          newValue: chat.toJson(),
        );
      }

      return await database.update(
        bucket: "messages",
        tag: messageId,
        newValue: message.toJson(),
      );
    } catch (e) {
      return RevaniResponse(status: 500, message: e.toString());
    }
  }

  Future<RevaniResponse> starMessage({
    required String messageId,
    required String userId,
  }) async {
    try {
      final messageData = await database.get(
        bucket: "messages",
        tag: messageId,
      );

      if (messageData == null) {
        return RevaniResponse(status: 404, message: "Message not found");
      }

      var message = RevaniMessage.fromJson(messageData.value);

      final starredBy = message.starredBy;
      if (!starredBy.contains(userId)) {
        starredBy.add(userId);
        message = message.copyWith(starredBy: starredBy);

        return await database.update(
          bucket: "messages",
          tag: messageId,
          newValue: message.toJson(),
        );
      }

      return RevaniResponse(status: 200, message: "Already starred");
    } catch (e) {
      return RevaniResponse(status: 500, message: e.toString());
    }
  }

  Future<RevaniResponse> unstarMessage({
    required String messageId,
    required String userId,
  }) async {
    try {
      final messageData = await database.get(
        bucket: "messages",
        tag: messageId,
      );

      if (messageData == null) {
        return RevaniResponse(status: 404, message: "Message not found");
      }

      var message = RevaniMessage.fromJson(messageData.value);

      final starredBy = message.starredBy;
      if (starredBy.contains(userId)) {
        starredBy.remove(userId);
        message = message.copyWith(starredBy: starredBy);

        return await database.update(
          bucket: "messages",
          tag: messageId,
          newValue: message.toJson(),
        );
      }

      return RevaniResponse(status: 200, message: "Not starred");
    } catch (e) {
      return RevaniResponse(status: 500, message: e.toString());
    }
  }

  Future<List<Chat>> getChatsForUser({
    required String userId,
    int? limit,
    int? offset,
  }) async {
    try {
      final allChats = await database.getAll("chats");

      List<Chat> userChats = [];
      for (var item in allChats) {
        final chat = Chat.fromJson(item.value);

        final chatData = await database.get(
          bucket: "chats",
          tag: chat.chatID ?? "",
        );
        if (chatData != null) {
          userChats.add(chat);
        }
      }

      userChats.sort((a, b) {
        final aTime = a.lastMessageTimestamp ?? DateTime(1970);
        final bTime = b.lastMessageTimestamp ?? DateTime(1970);
        return bTime.compareTo(aTime);
      });

      final startIndex = offset ?? 0;
      final endIndex = limit != null
          ? (startIndex + limit).clamp(0, userChats.length)
          : userChats.length;

      if (startIndex >= userChats.length) {
        return [];
      }

      return userChats.sublist(startIndex, endIndex);
    } catch (e) {
      return [];
    }
  }

  Future<Chat?> getChat({required String chatId}) async {
    try {
      final chatData = await database.get(bucket: "chats", tag: chatId);
      if (chatData == null) return null;
      return Chat.fromJson(chatData.value);
    } catch (e) {
      return null;
    }
  }

  Future<RevaniResponse> updateChat({
    required String chatId,
    String? chatName,
    String? chatPhotoURL,
    Map<String, dynamic>? themeSettings,
    bool? isMuted,
    bool? isArchived,
    bool? isBlocked,
    String? disappearingMessagesTimer,
    List<String>? adminIDs,
  }) async {
    try {
      final chatData = await database.get(bucket: "chats", tag: chatId);
      if (chatData == null) {
        return RevaniResponse(status: 404, message: "Chat not found");
      }

      var chat = Chat.fromJson(chatData.value);

      chat = chat.copyWith(
        chatName: chatName ?? chat.chatName,
        chatPhotoURL: chatPhotoURL ?? chat.chatPhotoURL,
        themeSettings: themeSettings ?? chat.themeSettings,
        isMuted: isMuted ?? chat.isMuted,
        isArchived: isArchived ?? chat.isArchived,
        isBlocked: isBlocked ?? chat.isBlocked,
        disappearingMessagesTimer:
            disappearingMessagesTimer ?? chat.disappearingMessagesTimer,
        adminIDs: adminIDs ?? chat.adminIDs,
      );

      return await database.update(
        bucket: "chats",
        tag: chatId,
        newValue: chat.toJson(),
      );
    } catch (e) {
      return RevaniResponse(status: 500, message: e.toString());
    }
  }

  Future<RevaniResponse> addParticipant({
    required String chatId,
    required String userId,
  }) async {
    try {
      final chatData = await database.get(bucket: "chats", tag: chatId);
      if (chatData == null) {
        return RevaniResponse(status: 404, message: "Chat not found");
      }

      final chat = Chat.fromJson(chatData.value);
      List<RevaniUserResponse> participants = chat.participants ?? [];

      final userResponse = await _getUserResponse(userId);
      if (userResponse == null) {
        return RevaniResponse(status: 404, message: "User not found");
      }

      final alreadyParticipant = participants.any((p) => p.uid == userId);
      if (alreadyParticipant) {
        return RevaniResponse(status: 200, message: "Already a participant");
      }

      final newParticipants = [...participants, userResponse];
      final updatedChat = chat.copyWith(participants: newParticipants);

      return await database.update(
        bucket: "chats",
        tag: chatId,
        newValue: updatedChat.toJson(),
      );
    } catch (e) {
      return RevaniResponse(status: 500, message: e.toString());
    }
  }

  Future<RevaniResponse> removeParticipant({
    required String chatId,
    required String userId,
  }) async {
    try {
      final chatData = await database.get(bucket: "chats", tag: chatId);
      if (chatData == null) {
        return RevaniResponse(status: 404, message: "Chat not found");
      }

      final chat = Chat.fromJson(chatData.value);
      List<RevaniUserResponse> participants = chat.participants ?? [];

      final updatedParticipants = participants
          .where((p) => p.uid != userId)
          .toList();
      final updatedChat = chat.copyWith(participants: updatedParticipants);

      return await database.update(
        bucket: "chats",
        tag: chatId,
        newValue: updatedChat.toJson(),
      );
    } catch (e) {
      return RevaniResponse(status: 500, message: e.toString());
    }
  }

  Future<RevaniResponse> createSystemMessage({
    required String chatId,
    required String type,
    String? userId,
    String? userName,
    String? oldValue,
    String? newValue,
  }) async {
    try {
      final messageId = Uuid().v1();
      final now = DateTime.now();

      final systemMessageData = RevaniSystemMessageData(
        type: type,
        userId: userId,
        userName: userName,
        oldValue: oldValue,
        newValue: newValue,
      );

      final message = RevaniMessage(
        messageId: messageId,
        chatId: chatId,
        senderId: "system",
        text: _getSystemMessageText(type, userName, oldValue, newValue),
        timestamp: now,
        messageType: 'system',
        status: 'sent',
        isSystemMessage: true,
        systemMessageData: systemMessageData,
      );

      final response = await database.add(
        bucket: "messages",
        tag: messageId,
        value: message.toJson(),
      );

      if (response.status == 200) {
        await _updateChatLastMessage(chatId, message);
      }

      return response;
    } catch (e) {
      return RevaniResponse(status: 500, message: e.toString());
    }
  }

  Future<List<RevaniMessage>> searchMessages({
    required String chatId,
    required String query,
    int? limit,
    int? offset,
  }) async {
    try {
      final allMessages = await database.getAll("messages");

      List<RevaniMessage> matchingMessages = [];
      for (var item in allMessages) {
        final message = RevaniMessage.fromJson(item.value);
        if (message.chatId == chatId &&
            !message.isDeleted &&
            message.text.toLowerCase().contains(query.toLowerCase())) {
          matchingMessages.add(message);
        }
      }

      matchingMessages.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      final startIndex = offset ?? 0;
      final endIndex = limit != null
          ? (startIndex + limit).clamp(0, matchingMessages.length)
          : matchingMessages.length;

      if (startIndex >= matchingMessages.length) {
        return [];
      }

      return matchingMessages.sublist(startIndex, endIndex);
    } catch (e) {
      return [];
    }
  }

  Future<RevaniResponse> setTyping({
    required String chatId,
    required String userId,
    required bool isTyping,
  }) async {
    try {
      final chatData = await database.get(bucket: "chats", tag: chatId);
      if (chatData == null) {
        return RevaniResponse(status: 404, message: "Chat not found");
      }

      var chat = Chat.fromJson(chatData.value);
      var typingUserIDs = chat.typingUserIDs ?? [];

      if (isTyping) {
        if (!typingUserIDs.contains(userId)) {
          typingUserIDs.add(userId);
        }
      } else {
        typingUserIDs.remove(userId);
      }

      chat = chat.copyWith(typingUserIDs: typingUserIDs);

      return await database.update(
        bucket: "chats",
        tag: chatId,
        newValue: chat.toJson(),
      );
    } catch (e) {
      return RevaniResponse(status: 500, message: e.toString());
    }
  }

  Future<List<RevaniMessage>> getStarredMessages({
    required String userId,
    int? limit,
    int? offset,
  }) async {
    try {
      final allMessages = await database.getAll("messages");

      List<RevaniMessage> starredMessages = [];
      for (var item in allMessages) {
        final message = RevaniMessage.fromJson(item.value);
        if (message.starredBy.contains(userId) && !message.isDeleted) {
          starredMessages.add(message);
        }
      }

      starredMessages.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      final startIndex = offset ?? 0;
      final endIndex = limit != null
          ? (startIndex + limit).clamp(0, starredMessages.length)
          : starredMessages.length;

      if (startIndex >= starredMessages.length) {
        return [];
      }

      return starredMessages.sublist(startIndex, endIndex);
    } catch (e) {
      return [];
    }
  }

  Future<RevaniResponse> updateUnreadCount({
    required String chatId,
    required String userId,
    int? unreadCount,
  }) async {
    try {
      final chatData = await database.get(bucket: "chats", tag: chatId);
      if (chatData == null) {
        return RevaniResponse(status: 404, message: "Chat not found");
      }

      var chat = Chat.fromJson(chatData.value);

      if (unreadCount != null) {
        chat = chat.copyWith(unreadCount: unreadCount);
      } else {
        final messages = await getMessages(chatId: chatId, limit: 100);
        final unread = messages.where((m) {
          return m.senderId != userId &&
              !m.statusInfo.readBy.contains(userId) &&
              !m.isDeleted;
        }).length;

        chat = chat.copyWith(unreadCount: unread);
      }

      return await database.update(
        bucket: "chats",
        tag: chatId,
        newValue: chat.toJson(),
      );
    } catch (e) {
      return RevaniResponse(status: 500, message: e.toString());
    }
  }

  Future<List<RevaniMessage>> getPinnedMessages({
    required String chatId,
    int? limit,
    int? offset,
  }) async {
    try {
      final chatData = await database.get(bucket: "chats", tag: chatId);
      if (chatData == null) return [];

      final chat = Chat.fromJson(chatData.value);
      final pinnedMessageIDs = chat.pinnedMessageIDs ?? [];

      List<RevaniMessage> pinnedMessages = [];
      for (var messageId in pinnedMessageIDs) {
        final messageData = await database.get(
          bucket: "messages",
          tag: messageId,
        );
        if (messageData != null) {
          final message = RevaniMessage.fromJson(messageData.value);
          if (!message.isDeleted) {
            pinnedMessages.add(message);
          }
        }
      }

      pinnedMessages.sort((a, b) {
        final aTime = a.pinnedTimestamp ?? DateTime(1970);
        final bTime = b.pinnedTimestamp ?? DateTime(1970);
        return bTime.compareTo(aTime);
      });

      final startIndex = offset ?? 0;
      final endIndex = limit != null
          ? (startIndex + limit).clamp(0, pinnedMessages.length)
          : pinnedMessages.length;

      if (startIndex >= pinnedMessages.length) {
        return [];
      }

      return pinnedMessages.sublist(startIndex, endIndex);
    } catch (e) {
      return [];
    }
  }

  Future<RevaniResponse> clearChatHistory({
    required String chatId,
    required String userId,
    bool deleteForEveryone = false,
  }) async {
    try {
      final messages = await getMessages(chatId: chatId, limit: 1000);

      for (var message in messages) {
        if (deleteForEveryone || message.senderId == userId) {
          await deleteMessage(
            messageId: message.messageId,
            userId: userId,
            deleteForEveryone: deleteForEveryone,
          );
        }
      }

      final chatData = await database.get(bucket: "chats", tag: chatId);
      if (chatData != null) {
        var chat = Chat.fromJson(chatData.value);
        chat = chat.copyWith(
          lastMessage: null,
          lastMessageTimestamp: null,
          lastMessageSenderID: null,
          unreadCount: 0,
        );

        await database.update(
          bucket: "chats",
          tag: chatId,
          newValue: chat.toJson(),
        );
      }

      return RevaniResponse(status: 200, message: "Chat history cleared");
    } catch (e) {
      return RevaniResponse(status: 500, message: e.toString());
    }
  }

  Future<RevaniMessage?> getMessage({required String messageId}) async {
    try {
      final messageData = await database.get(
        bucket: "messages",
        tag: messageId,
      );
      if (messageData == null) return null;
      return RevaniMessage.fromJson(messageData.value);
    } catch (e) {
      return null;
    }
  }

  Future<RevaniResponse> archiveChat({
    required String chatId,
    required bool archive,
  }) async {
    try {
      final chatData = await database.get(bucket: "chats", tag: chatId);
      if (chatData == null) {
        return RevaniResponse(status: 404, message: "Chat not found");
      }

      var chat = Chat.fromJson(chatData.value);
      chat = chat.copyWith(isArchived: archive);

      return await database.update(
        bucket: "chats",
        tag: chatId,
        newValue: chat.toJson(),
      );
    } catch (e) {
      return RevaniResponse(status: 500, message: e.toString());
    }
  }

  Future<RevaniResponse> muteChat({
    required String chatId,
    required bool mute,
  }) async {
    try {
      final chatData = await database.get(bucket: "chats", tag: chatId);
      if (chatData == null) {
        return RevaniResponse(status: 404, message: "Chat not found");
      }

      var chat = Chat.fromJson(chatData.value);
      chat = chat.copyWith(isMuted: mute);

      return await database.update(
        bucket: "chats",
        tag: chatId,
        newValue: chat.toJson(),
      );
    } catch (e) {
      return RevaniResponse(status: 500, message: e.toString());
    }
  }

  Future<RevaniResponse> blockChat({
    required String chatId,
    required bool block,
  }) async {
    try {
      final chatData = await database.get(bucket: "chats", tag: chatId);
      if (chatData == null) {
        return RevaniResponse(status: 404, message: "Chat not found");
      }

      var chat = Chat.fromJson(chatData.value);
      chat = chat.copyWith(isBlocked: block);

      return await database.update(
        bucket: "chats",
        tag: chatId,
        newValue: chat.toJson(),
      );
    } catch (e) {
      return RevaniResponse(status: 500, message: e.toString());
    }
  }

  Future<RevaniResponse> processSelfDestructMessages() async {
    try {
      final allMessages = await database.getAll("messages");
      final now = DateTime.now();

      for (var item in allMessages) {
        final message = RevaniMessage.fromJson(item.value);

        if (message.selfDestructTimestamp != null &&
            message.selfDestructTimestamp!.isBefore(now) &&
            !message.isDeleted) {
          await deleteMessage(
            messageId: message.messageId,
            userId: message.senderId,
            deleteForEveryone: true,
          );
        }
      }

      return RevaniResponse(
        status: 200,
        message: "Self-destruct messages processed",
      );
    } catch (e) {
      return RevaniResponse(status: 500, message: e.toString());
    }
  }

  Future<RevaniUserResponse?> _getUserResponse(String userId) async {
    try {
      final userData = await database.get(bucket: "users", tag: userId);
      if (userData == null) return null;
      return RevaniUserResponse.fromJson(userData.value);
    } catch (e) {
      return null;
    }
  }

  Future<void> _updateChatLastMessage(
    String chatId,
    RevaniMessage message,
  ) async {
    try {
      final chatData = await database.get(bucket: "chats", tag: chatId);
      if (chatData == null) return;

      var chat = Chat.fromJson(chatData.value);

      chat = chat.copyWith(
        lastMessage: message.text,
        lastMessageTimestamp: message.timestamp,
        lastMessageSenderID: message.senderId,
      );

      await database.update(
        bucket: "chats",
        tag: chatId,
        newValue: chat.toJson(),
      );
    } catch (e) {
      print("Error updating chat last message: $e");
    }
  }

  String _getSystemMessageText(
    String type,
    String? userName,
    String? oldValue,
    String? newValue,
  ) {
    switch (type) {
      case 'user_joined':
        return '$userName joined the chat';
      case 'user_left':
        return '$userName left the chat';
      case 'group_created':
        return 'Group created by $userName';
      case 'name_changed':
        return '$userName changed group name from "$oldValue" to "$newValue"';
      case 'photo_changed':
        return '$userName changed group photo';
      case 'admin_added':
        return '$userName is now an admin';
      case 'admin_removed':
        return '$userName is no longer an admin';
      default:
        return 'System message';
    }
  }
}
