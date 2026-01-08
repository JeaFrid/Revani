import 'client_base.dart';

class RevaniUserClient extends RevaniBaseClient {
  RevaniUserClient(super.serverUrl);

  Future<Map<String, dynamic>> registerUser({
    required String projectID,
    required String email,
    required String password,
    Map<String, dynamic> userData = const {},
  }) {
    return post('/users/register', {
      'projectID': projectID,
      'email': email,
      'password': password,
      'userData': userData,
    });
  }

  Future<Map<String, dynamic>> loginUser({
    required String projectID,
    required String email,
    required String password,
  }) {
    return post('/users/login', {
      'projectID': projectID,
      'email': email,
      'password': password,
    });
  }

  Future<Map<String, dynamic>> verifyUserEmail({
    required String projectID,
    required String email,
    required String token,
  }) {
    return post('/users/verify-email', {
      'projectID': projectID,
      'email': email,
      'token': token,
    });
  }

  Future<Map<String, dynamic>> sendUserPasswordReset({
    required String projectID,
    required String email,
  }) {
    return post('/users/forgot-password', {
      'projectID': projectID,
      'email': email,
    });
  }

  Future<Map<String, dynamic>> resetUserPassword({
    required String projectID,
    required String email,
    required String token,
    required String newPassword,
  }) {
    return post('/users/reset-password', {
      'projectID': projectID,
      'email': email,
      'token': token,
      'newPassword': newPassword,
    });
  }

  Future<Map<String, dynamic>> logoutUser({
    required String projectID,
    required String userID,
  }) {
    if (authToken == null) throw Exception('Authentication token not set.');
    return post('/users/logout', {
      'projectID': projectID,
      'userID': userID,
      'token': authToken,
    }, authenticated: true);
  }

  Future<Map<String, dynamic>> getUserProfile({
    required String projectID,
    required String userID,
  }) async {
    if (authToken == null) throw Exception('Authentication token not set.');
    return get(
      '/users/profile/$userID?projectID=$projectID',
      authenticated: true,
    );
  }

  Future<Map<String, dynamic>> updateUserData({
    required String projectID,
    required String userID,
    required Map<String, dynamic> userData,
  }) {
    if (authToken == null) throw Exception('Authentication token not set.');
    return post('/users/update-data', {
      'projectID': projectID,
      'userID': userID,
      'userData': userData,
    }, authenticated: true);
  }

  Future<Map<String, dynamic>> changeUserPassword({
    required String projectID,
    required String userID,
    required String oldPassword,
    required String newPassword,
  }) {
    if (authToken == null) throw Exception('Authentication token not set.');
    return post('/users/change-password', {
      'projectID': projectID,
      'userID': userID,
      'oldPassword': oldPassword,
      'newPassword': newPassword,
    }, authenticated: true);
  }

  Future<Map<String, dynamic>> listAllUsers({
    required String projectID,
    int limit = 50,
  }) {
    if (authToken == null) throw Exception('Authentication token not set.');
    return post('/users/all', {
      'projectID': projectID,
      'limit': limit,
    }, authenticated: true);
  }

  Future<Map<String, dynamic>> searchUsers({
    required String projectID,
    required String query,
    int limit = 50,
  }) {
    if (authToken == null) throw Exception('Authentication token not set.');
    return post('/users/search', {
      'projectID': projectID,
      'query': query,
      'limit': limit,
    }, authenticated: true);
  }

  Future<Map<String, dynamic>> deleteUser({
    required String projectID,
    required String userID,
    bool hardDelete = false,
  }) {
    if (authToken == null) throw Exception('Authentication token not set.');
    return post('/users/delete', {
      'projectID': projectID,
      'userID': userID,
      'hardDelete': hardDelete,
    }, authenticated: true);
  }
}
