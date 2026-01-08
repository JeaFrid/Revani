import 'client_base.dart';
import 'package:http/http.dart' as http;

class RevaniGalleryClient extends RevaniBaseClient {
  RevaniGalleryClient(super.serverUrl);

  Future<Map<String, dynamic>> uploadFile({
    required String projectID,
    required String fileName,
    required List<int> fileBytes,
    String? fileType,
  }) {
    if (authToken == null) throw Exception('Authentication token not set.');
    return post('/gallery/upload', {
      'projectID': projectID,
      'fileName': fileName,
      'fileBytes': fileBytes,
      'fileType': fileType,
    }, authenticated: true);
  }

  Future<Map<String, dynamic>> getFileMetadata({
    required String projectID,
    required String fileID,
  }) async {
    if (authToken == null) throw Exception('Authentication token not set.');
    return get(
      '/gallery/metadata/$fileID?projectID=$projectID',
      authenticated: true,
    );
  }

  Future<List<int>> downloadFile({
    required String projectID,
    required String fileID,
  }) async {
    if (authToken == null) throw Exception('Authentication token not set.');
    final headers = {'Authorization': 'Bearer $authToken'};
    final response = await http.get(
      Uri.parse('$serverUrl/gallery/file/$fileID?projectID=$projectID'),
      headers: headers,
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response.bodyBytes;
    } else {
      throw Exception(
        'Request failed with status: ${response.statusCode}\nBody: ${response.body}',
      );
    }
  }

  Future<Map<String, dynamic>> renameFile({
    required String projectID,
    required String fileID,
    required String newName,
  }) {
    if (authToken == null) throw Exception('Authentication token not set.');
    return post('/gallery/rename', {
      'projectID': projectID,
      'fileID': fileID,
      'newName': newName,
    }, authenticated: true);
  }

  Future<Map<String, dynamic>> deleteFile({
    required String projectID,
    required String fileID,
  }) {
    if (authToken == null) throw Exception('Authentication token not set.');
    return post('/gallery/delete', {
      'projectID': projectID,
      'fileID': fileID,
    }, authenticated: true);
  }

  Future<Map<String, dynamic>> deleteMultipleFiles({
    required String projectID,
    required List<String> fileIDs,
  }) {
    if (authToken == null) throw Exception('Authentication token not set.');
    return post('/gallery/delete-multiple', {
      'projectID': projectID,
      'fileIDs': fileIDs,
    }, authenticated: true);
  }

  Future<Map<String, dynamic>> listFiles({
    required String projectID,
    int limit = 100,
    int offset = 0,
  }) {
    if (authToken == null) throw Exception('Authentication token not set.');
    return post('/gallery/list', {
      'projectID': projectID,
      'limit': limit,
      'offset': offset,
    }, authenticated: true);
  }

  Future<Map<String, dynamic>> getStorageUsage({
    required String projectID,
  }) async {
    if (authToken == null) throw Exception('Authentication token not set.');
    return get(
      '/gallery/storage-usage?projectID=$projectID',
      authenticated: true,
    );
  }
}
