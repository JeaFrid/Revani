import 'dart:convert';
import 'package:http/http.dart' as http;

class RevaniBaseClient {
  final String serverUrl;
  String? _token;

  RevaniBaseClient(this.serverUrl);

  void setAuthToken(String token) {
    _token = token;
  }

  String? get authToken => _token;

  Future<Map<String, dynamic>> _handleResponse(http.Response response) async {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body);
    } else {
      throw Exception(
        'Request failed with status: ${response.statusCode}\nBody: ${response.body}',
      );
    }
  }

  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> data, {
    bool authenticated = false,
  }) async {
    final headers = {'Content-Type': 'application/json'};
    if (authenticated && _token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }

    final response = await http.post(
      Uri.parse('$serverUrl$path'),
      headers: headers,
      body: jsonEncode(data),
    );

    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> get(
    String path, {
    bool authenticated = false,
  }) async {
    final headers = {'Content-Type': 'application/json'};
    if (authenticated && _token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }

    final response = await http.get(
      Uri.parse('$serverUrl$path'),
      headers: headers,
    );

    return _handleResponse(response);
  }
}
