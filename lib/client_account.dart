import 'client_base.dart';

class RevaniAccountClient extends RevaniBaseClient {
  RevaniAccountClient(super.serverUrl);

  Future<Map<String, dynamic>> createAccount(
    String name,
    String email,
    String password,
  ) {
    return post('/account/create', {
      'name': name,
      'email': email,
      'password': password,
    });
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await post('/account/login', {
      'email': email,
      'password': password,
    });
    return response;
  }

  Future<String> getAuthToken(String email, String password) async {
    final response = await post('/account/token', {
      'email': email,
      'password': password,
    });
    if (response['success'] == true && response['token'] != null) {
      setAuthToken(response['token']);
      return response['token'];
    } else {
      throw Exception('Failed to get auth token');
    }
  }
}
