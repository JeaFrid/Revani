import 'client_base.dart';

class RevaniDataClient extends RevaniBaseClient {
  RevaniDataClient(super.serverUrl);

  Future<Map<String, dynamic>> addData({
    required String projectID,
    required String bucket,
    required Map<String, dynamic> data,
    String tag = '',
  }) async {
    if (authToken == null) throw Exception('Authentication token not set.');
    return post('/add', {
      'projectID': projectID,
      'bucket': bucket,
      'tag': tag,
      'data': data,
    }, authenticated: true);
  }

  Future<Map<String, dynamic>> getData({
    required String projectID,
    required String bucket,
    required String tag,
  }) {
    if (authToken == null) throw Exception('Authentication token not set.');
    return post('/get', {
      'projectID': projectID,
      'bucket': bucket,
      'tag': tag,
    }, authenticated: true);
  }

  Future<Map<String, dynamic>> listData({
    required String projectID,
    required String bucket,
    int? count,
  }) {
    if (authToken == null) throw Exception('Authentication token not set.');
    return post('/list', {
      'projectID': projectID,
      'bucket': bucket,
      'count': count,
    }, authenticated: true);
  }

  Future<Map<String, dynamic>> updateData({
    required String projectID,
    required String bucket,
    required String tag,
    required Map<String, dynamic> changes,
  }) {
    if (authToken == null) throw Exception('Authentication token not set.');
    return post('/update', {
      'projectID': projectID,
      'bucket': bucket,
      'tag': tag,
      'changes': changes,
    }, authenticated: true);
  }

  Future<Map<String, dynamic>> deleteData({
    required String projectID,
    required String bucket,
    required String tag,
  }) {
    if (authToken == null) throw Exception('Authentication token not set.');
    return post('/delete', {
      'projectID': projectID,
      'bucket': bucket,
      'tag': tag,
    }, authenticated: true);
  }

  Future<Map<String, dynamic>> deleteAllData({
    required String projectID,
    required String bucket,
  }) {
    if (authToken == null) throw Exception('Authentication token not set.');
    return post('/deleteAll', {
      'projectID': projectID,
      'bucket': bucket,
    }, authenticated: true);
  }
}
