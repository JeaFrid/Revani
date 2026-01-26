/*
 * Copyright (C) 2026 JeaFriday (https://github.com/JeaFrid/Revani)
 * * This project is part of Revani
 * Licensed under the GNU Affero General Public License v3.0 (AGPL-3.0).
 * See the LICENSE file in the project root for full license information.
 * * For commercial licensing, please contact: JeaFriday
 */

import 'dart:async';

class RevaniPubSub {
  static final RevaniPubSub _instance = RevaniPubSub._internal();
  factory RevaniPubSub() => _instance;
  RevaniPubSub._internal();

  final Map<String, Set<String>> _topicSubscribers = {};
  final Map<String, Set<String>> _bucketSubscribers = {};
  final StreamController<PubSubMessage> _bus =
      StreamController<PubSubMessage>.broadcast();

  Stream<PubSubMessage> get messageStream => _bus.stream;

  void subscribe(String clientId, String topic) {
    _topicSubscribers.putIfAbsent(topic, () => {}).add(clientId);
  }

  void subscribeToBucket(String clientId, String bucket, String projectId) {
    final bucketKey = '$projectId/$bucket';
    _bucketSubscribers.putIfAbsent(bucketKey, () => {}).add(clientId);
  }

  void unsubscribeFromBucket(String clientId, String bucket, String projectId) {
    final bucketKey = '$projectId/$bucket';
    _bucketSubscribers[bucketKey]?.remove(clientId);
    if (_bucketSubscribers[bucketKey]?.isEmpty ?? false) {
      _bucketSubscribers.remove(bucketKey);
    }
  }

  void unsubscribe(String clientId, String topic) {
    _topicSubscribers[topic]?.remove(clientId);
    if (_topicSubscribers[topic]?.isEmpty ?? false) {
      _topicSubscribers.remove(topic);
    }
  }

  void unsubscribeAll(String clientId) {
    _topicSubscribers.forEach((topic, subs) {
      subs.remove(clientId);
    });
    _topicSubscribers.removeWhere((topic, subs) => subs.isEmpty);

    _bucketSubscribers.forEach((bucketKey, subs) {
      subs.remove(clientId);
    });
    _bucketSubscribers.removeWhere((bucketKey, subs) => subs.isEmpty);
  }

  void publish(String topic, Map<String, dynamic> data, {String? senderId}) {
    final message = PubSubMessage(
      topic: topic,
      data: data,
      senderId: senderId,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
    _bus.add(message);
  }

  void publishBucketEvent(
    String projectId,
    String bucket,
    String action,
    Map<String, dynamic> data, {
    String? senderId,
  }) {
    final bucketKey = '$projectId/$bucket';
    final subscribers = _bucketSubscribers[bucketKey] ?? {};

    for (final clientId in subscribers) {
      final topic = 'bucket/$projectId/$bucket/$action';
      publish(topic, {
        ...data,
        'clientId': clientId,
        'bucket': bucket,
        'projectId': projectId,
        'action': action,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      }, senderId: senderId);
    }
  }

  List<String> getSubscribers(String topic) {
    return _topicSubscribers[topic]?.toList() ?? [];
  }

  List<String> getBucketSubscribers(String bucket, String projectId) {
    final bucketKey = '$projectId/$bucket';
    return _bucketSubscribers[bucketKey]?.toList() ?? [];
  }
}

class PubSubMessage {
  final String topic;
  final Map<String, dynamic> data;
  final String? senderId;
  final int timestamp;

  PubSubMessage({
    required this.topic,
    required this.data,
    this.senderId,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'topic': topic,
      'data': data,
      'senderId': senderId,
      'ts': timestamp,
    };
  }
}
