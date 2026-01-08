import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import 'client_base.dart';

class RevaniTunnelClient extends RevaniBaseClient {
  WebSocketChannel? _tunnelSocket;

  RevaniTunnelClient(super.serverUrl);

  Future<void> openTunnel({
    required String projectID,
    required Future<Map<String, dynamic>> Function(Map<String, dynamic>)
    onRequestHandler,
  }) async {
    if (authToken == null) throw Exception('Authentication token not set.');

    final wsUrl = serverUrl.replaceFirst(RegExp(r'^http'), 'wss');
    _tunnelSocket = IOWebSocketChannel.connect('$wsUrl/revani-tunnel');

    _tunnelSocket!.sink.add(
      jsonEncode({
        'type': 'register',
        'projectID': projectID,
        'token': authToken,
      }),
    );

    _tunnelSocket!.stream.listen((message) async {
      final data = jsonDecode(message);
      if (data['type'] == 'request') {
        final responsePayload = await onRequestHandler(data);
        _tunnelSocket!.sink.add(
          jsonEncode({
            'type': 'response',
            'requestId': data['requestId'],
            ...responsePayload,
          }),
        );
      }
    });
  }

  void closeTunnel() {
    _tunnelSocket?.sink.close();
    _tunnelSocket = null;
  }
}
