import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import 'client_base.dart';

class RevaniEventsClient extends RevaniBaseClient {
  WebSocketChannel? _eventSocket;

  RevaniEventsClient(super.serverUrl);

  Stream<Map<String, dynamic>> subscribeToEvents(String projectID) {
    if (authToken == null) throw Exception('Authentication token not set.');

    final wsUrl = serverUrl.replaceFirst(RegExp(r'^http'), 'wss');
    _eventSocket = IOWebSocketChannel.connect('$wsUrl/events');

    _eventSocket!.sink.add(
      jsonEncode({
        'type': 'subscribe',
        'projectID': projectID,
        'token': authToken,
      }),
    );

    return _eventSocket!.stream.map((message) {
      final data = jsonDecode(message);
      if (data['type'] == 'event' && data['data'] != null) {
        return data['data'] as Map<String, dynamic>;
      }
      return data;
    });
  }

  void unsubscribeFromEvents() {
    _eventSocket?.sink.close();
    _eventSocket = null;
  }
}
