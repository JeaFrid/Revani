import 'dart:async';

class RevaniPubSub {
  static final RevaniPubSub _instance = RevaniPubSub._internal();
  factory RevaniPubSub() => _instance;
  RevaniPubSub._internal();

  final Map<String, Set<String>> _topicSubscribers = {};
  final StreamController<PubSubMessage> _bus =
      StreamController<PubSubMessage>.broadcast();

  Stream<PubSubMessage> get messageStream => _bus.stream;

  void subscribe(String clientId, String topic) {
    _topicSubscribers.putIfAbsent(topic, () => {}).add(clientId);
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

  List<String> getSubscribers(String topic) {
    return _topicSubscribers[topic]?.toList() ?? [];
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
