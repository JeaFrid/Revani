import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt;

class RevaniResponse {
  final int status;
  final String message;
  final String? error;
  final dynamic data;
  final String? description;

  RevaniResponse({
    required this.status,
    required this.message,
    this.error,
    this.data,
    this.description,
  });

  bool get isSuccess => status >= 200 && status < 300;

  void handle({
    Function(dynamic data)? onSuccess,
    Function(String error)? onError,
  }) {
    if (isSuccess) {
      if (onSuccess != null) onSuccess(data);
    } else {
      if (onError != null) onError(error ?? message);
    }
  }

  static RevaniResponse fromMap(Map<String, dynamic> map) {
    return RevaniResponse(
      status: map['status'] ?? 500,
      message: map['message'] ?? 'Unknown',
      error: map['error'],
      data: map['data'],
      description: map['description'],
    );
  }

  static RevaniResponse networkError(String error) {
    return RevaniResponse(
      status: 503,
      message: 'Network Error',
      error: error,
      description: 'Connection failed',
    );
  }
}

class RevaniClient {
  final String host;
  final int port;
  final bool secure;
  final bool autoReconnect;

  Socket? _socket;
  String? _sessionKey;
  String? _accountID;
  String? _projectName;
  String? _projectID;
  bool _isReconnecting = false;
  final String _sessionFile = '.revani_session';

  late final RevaniAccount account;
  late final RevaniProject project;
  late final RevaniData data;
  late final RevaniUser user;
  late final RevaniSocial social;
  late final RevaniChat chat;
  late final RevaniStorage storage;
  late final RevaniLivekit livekit;
  late final RevaniPubSub pubsub;

  StreamController<Map<String, dynamic>> _responseController =
      StreamController<Map<String, dynamic>>.broadcast();
  final List<int> _buffer = [];

  RevaniClient({
    required this.host,
    this.port = 16897,
    this.secure = true,
    this.autoReconnect = true,
  }) {
    account = RevaniAccount(this);
    project = RevaniProject(this);
    data = RevaniData(this);
    user = RevaniUser(this);
    social = RevaniSocial(this);
    chat = RevaniChat(this);
    storage = RevaniStorage(this);
    livekit = RevaniLivekit(this);
    pubsub = RevaniPubSub(this);
  }

  Future<void> connect() async {
    try {
      if (secure) {
        _socket = await SecureSocket.connect(
          host,
          port,
          onBadCertificate: (cert) => true,
        );
      } else {
        _socket = await Socket.connect(host, port);
      }

      _socket!.listen(
        _onData,
        onError: (e) => _handleConnectionError(e),
        onDone: () => _handleConnectionDone(),
      );
      _isReconnecting = false;

      await _checkLocalSession();
    } catch (e) {
      if (autoReconnect) {
        _attemptReconnect();
      } else {
        throw Exception("Connection failed: $e");
      }
    }
  }

  Future<RevaniResponse> authenticateWithToken() async {
    if (_sessionKey == null) {
      return RevaniResponse(
        status: 401,
        message: "No token found",
        error: "Session key missing",
      );
    }

    final res = await execute({
      'cmd': 'auth/verify-token',
      'token': _sessionKey,
    });

    if (res.isSuccess) {
      final data = res.data;
      if (data['type'] == 'account') {
        setAccount(data['user_id']);
      } else {
        setAccount(data['project_id']);
      }
    } else {
      _clearSession();
    }
    return res;
  }

  Future<void> _checkLocalSession() async {
    final file = File(_sessionFile);
    if (await file.exists()) {
      try {
        final content = await file.readAsString();
        final map = jsonDecode(content);
        _sessionKey = map['session_key'];
        _accountID = map['account_id'];
      } catch (_) {}
    }
  }

  Future<void> _saveSession() async {
    if (_sessionKey != null) {
      final file = File(_sessionFile);
      await file.writeAsString(
        jsonEncode({'session_key': _sessionKey, 'account_id': _accountID}),
      );
    }
  }

  void _clearSession() {
    _sessionKey = null;
    _accountID = null;
    final file = File(_sessionFile);
    if (file.existsSync()) {
      file.deleteSync();
    }
  }

  bool get isSignedIn => _sessionKey != null;

  void _handleConnectionError(dynamic error) {
    if (autoReconnect) _attemptReconnect();
  }

  void _handleConnectionDone() {
    if (autoReconnect) _attemptReconnect();
  }

  void _attemptReconnect() async {
    if (_isReconnecting) return;
    _isReconnecting = true;
    _socket?.destroy();
    _socket = null;

    int attempts = 0;
    while (_socket == null) {
      attempts++;
      final delay = min(30, pow(2, attempts));
      await Future.delayed(Duration(seconds: delay.toInt()));
      try {
        await connect();
      } catch (_) {}
    }
  }

  void _onData(Uint8List data) {
    _buffer.addAll(data);
    while (_buffer.length >= 4) {
      final header = ByteData.sublistView(
        Uint8List.fromList(_buffer.sublist(0, 4)),
      );
      final length = header.getUint32(0);

      if (_buffer.length >= length + 4) {
        final payload = _buffer.sublist(4, length + 4);
        _buffer.removeRange(0, length + 4);

        try {
          final jsonString = utf8.decode(payload);
          final json = jsonDecode(jsonString);

          if (json is Map<String, dynamic> &&
              json.containsKey('encrypted') &&
              _sessionKey != null) {
            try {
              final decrypted = _decrypt(json['encrypted']);
              _responseController.add(jsonDecode(decrypted));
            } catch (e) {
              _responseController.addError(e);
            }
          } else {
            _responseController.add(json);
          }
        } catch (e) {}
      } else {
        break;
      }
    }
  }

  Future<RevaniResponse> execute(
    Map<String, dynamic> command, {
    bool useEncryption = true,
    Function(dynamic)? onSuccess,
    Function(String)? onError,
  }) async {
    if (_socket == null) {
      final res = RevaniResponse.networkError("Not connected");
      res.handle(onError: onError);
      return res;
    }

    try {
      final responseFuture = _responseController.stream.first;

      final payload = (useEncryption && _sessionKey != null)
          ? {'encrypted': _encrypt(jsonEncode(command))}
          : command;

      final bytes = utf8.encode(jsonEncode(payload));
      final header = ByteData(4)..setUint32(0, bytes.length);

      _socket!.add(header.buffer.asUint8List());
      _socket!.add(bytes);

      final rawResponse = await responseFuture.timeout(Duration(seconds: 15));
      final response = RevaniResponse.fromMap(rawResponse);

      response.handle(onSuccess: onSuccess, onError: onError);
      return response;
    } catch (e) {
      if (e is TimeoutException) {
        final res = RevaniResponse.networkError("Timeout");
        res.handle(onError: onError);
        return res;
      }
      final res = RevaniResponse.networkError(e.toString());
      res.handle(onError: onError);
      return res;
    }
  }

  String _encrypt(String text) {
    final wrapper = jsonEncode({
      "payload": text,
      "ts": DateTime.now().millisecondsSinceEpoch,
    });

    final salt = encrypt.IV.fromSecureRandom(16);
    final keyBytes = sha256
        .convert(utf8.encode(_sessionKey! + salt.base64))
        .bytes;
    final key = encrypt.Key(Uint8List.fromList(keyBytes));
    final iv = encrypt.IV.fromSecureRandom(16);

    final encrypter = encrypt.Encrypter(
      encrypt.AES(key, mode: encrypt.AESMode.gcm),
    );
    final encrypted = encrypter.encrypt(wrapper, iv: iv);

    return "${salt.base64}:${iv.base64}:${encrypted.base64}";
  }

  String _decrypt(String encryptedData) {
    final parts = encryptedData.split(':');
    final salt = encrypt.IV.fromBase64(parts[0]);
    final iv = encrypt.IV.fromBase64(parts[1]);
    final cipherText = parts[2];

    final keyBytes = sha256
        .convert(utf8.encode(_sessionKey! + salt.base64))
        .bytes;
    final key = encrypt.Key(Uint8List.fromList(keyBytes));

    final encrypter = encrypt.Encrypter(
      encrypt.AES(key, mode: encrypt.AESMode.gcm),
    );
    final decrypted = encrypter.decrypt64(cipherText, iv: iv);

    final Map<String, dynamic> wrapper = jsonDecode(decrypted);
    return wrapper['payload'];
  }

  void setSession(String key) => _sessionKey = key;
  void setAccount(String id) => _accountID = id;
  void setProject(String name, String? id) {
    _projectName = name;
    _projectID = id;
  }

  String get accountID => _accountID ?? "";
  String get projectName => _projectName ?? "";
  String get projectID => _projectID ?? "";

  void logout() {
    _clearSession();
    disconnect();
  }

  void disconnect() {
    _socket?.destroy();
    _socket = null;
    _sessionKey = null;
    _accountID = null;
    _projectName = null;
    _projectID = null;
  }
}

class RevaniAccount {
  final RevaniClient _client;
  RevaniAccount(this._client);

  Future<RevaniResponse> create(
    String email,
    String password, {
    Map<String, dynamic>? extraData,
    Function(dynamic)? onSuccess,
    Function(String)? onError,
  }) async {
    return await _client.execute(
      {
        'cmd': 'account/create',
        'email': email,
        'password': password,
        'data': extraData ?? {},
      },
      useEncryption: false,
      onSuccess: onSuccess,
      onError: onError,
    );
  }

  Future<RevaniResponse> login(
    String email,
    String password, {
    Function(dynamic)? onSuccess,
    Function(String)? onError,
  }) async {
    final res = await _client.execute({
      'cmd': 'auth/login',
      'email': email,
      'password': password,
    }, useEncryption: false);

    if (res.isSuccess) {
      _client.setSession(res.data['session_key'] ?? res.data);

      final idRes = await _client.execute({
        'cmd': 'account/get-id',
        'email': email,
        'password': password,
      });

      if (idRes.isSuccess) {
        _client.setAccount(idRes.data['id']);
        if (idRes.data['token'] != null) {
          _client.setSession(idRes.data['token']);
        }
        await _client._saveSession();
        if (onSuccess != null) onSuccess(idRes.data);
      } else {
        if (onError != null) onError(idRes.error ?? idRes.message);
      }
    } else {
      if (onError != null) onError(res.error ?? res.message);
    }
    return res;
  }

  Future<RevaniResponse> getData({
    Function(dynamic)? onSuccess,
    Function(String)? onError,
  }) async {
    return await _client.execute(
      {'cmd': 'account/get-data', 'id': _client.accountID},
      onSuccess: onSuccess,
      onError: onError,
    );
  }
}

class RevaniProject {
  final RevaniClient _client;
  RevaniProject(this._client);

  Future<RevaniResponse> use(
    String projectName, {
    Function(dynamic)? onSuccess,
    Function(String)? onError,
  }) async {
    final res = await _client.execute({
      'cmd': 'project/exist',
      'accountID': _client.accountID,
      'projectName': projectName,
    });

    if (res.isSuccess) {
      _client.setProject(projectName, res.data['id'] ?? res.data);
      if (onSuccess != null) onSuccess(res.data);
    } else {
      if (onError != null) onError(res.error ?? res.message);
    }
    return res;
  }

  Future<RevaniResponse> create(
    String projectName, {
    Function(dynamic)? onSuccess,
    Function(String)? onError,
  }) async {
    final res = await _client.execute({
      'cmd': 'project/create',
      'accountID': _client.accountID,
      'projectName': projectName,
    });
    if (res.isSuccess) {
      _client.setProject(projectName, res.data['id']);
      if (onSuccess != null) onSuccess(res.data);
    } else {
      if (onError != null) onError(res.error ?? res.message);
    }
    return res;
  }
}

class RevaniData {
  final RevaniClient _client;
  RevaniData(this._client);

  Future<RevaniResponse> add({
    required String bucket,
    required String tag,
    required Map<String, dynamic> value,
    Function(dynamic)? onSuccess,
    Function(String)? onError,
  }) async {
    return await _client.execute(
      {
        'cmd': 'data/add',
        'accountID': _client.accountID,
        'projectName': _client.projectName,
        'bucket': bucket,
        'tag': tag,
        'value': value,
      },
      onSuccess: onSuccess,
      onError: onError,
    );
  }

  Future<RevaniResponse> addAll({
    required String bucket,
    required Map<String, Map<String, dynamic>> items,
    Function(dynamic)? onSuccess,
    Function(String)? onError,
  }) async {
    return await _client.execute(
      {
        'cmd': 'data/add-batch',
        'accountID': _client.accountID,
        'projectName': _client.projectName,
        'bucket': bucket,
        'items': items,
      },
      onSuccess: onSuccess,
      onError: onError,
    );
  }

  Future<RevaniResponse> get({
    required String bucket,
    required String tag,
    Function(dynamic)? onSuccess,
    Function(String)? onError,
  }) async {
    return await _client.execute(
      {
        'cmd': 'data/get',
        'projectID': _client.projectID,
        'bucket': bucket,
        'tag': tag,
      },
      onSuccess: onSuccess,
      onError: onError,
    );
  }

  Future<RevaniResponse> getAll({
    required String bucket,
    Function(dynamic)? onSuccess,
    Function(String)? onError,
  }) async {
    return await _client.execute(
      {'cmd': 'data/get-all', 'projectID': _client.projectID, 'bucket': bucket},
      onSuccess: onSuccess,
      onError: onError,
    );
  }

  Future<RevaniResponse> query({
    required String bucket,
    required Map<String, dynamic> query,
    Function(dynamic)? onSuccess,
    Function(String)? onError,
  }) async {
    return await _client.execute(
      {
        'cmd': 'data/query',
        'accountID': _client.accountID,
        'projectName': _client.projectName,
        'bucket': bucket,
        'query': query,
      },
      onSuccess: onSuccess,
      onError: onError,
    );
  }

  Future<RevaniResponse> update({
    required String bucket,
    required String tag,
    required dynamic newValue,
    Function(dynamic)? onSuccess,
    Function(String)? onError,
  }) async {
    return await _client.execute(
      {
        'cmd': 'data/update',
        'projectID': _client.projectID,
        'bucket': bucket,
        'tag': tag,
        'newValue': newValue,
      },
      onSuccess: onSuccess,
      onError: onError,
    );
  }

  Future<RevaniResponse> delete({
    required String bucket,
    required String tag,
    Function(dynamic)? onSuccess,
    Function(String)? onError,
  }) async {
    return await _client.execute(
      {
        'cmd': 'data/delete',
        'projectID': _client.projectID,
        'bucket': bucket,
        'tag': tag,
      },
      onSuccess: onSuccess,
      onError: onError,
    );
  }

  Future<RevaniResponse> deleteAll({
    required String bucket,
    Function(dynamic)? onSuccess,
    Function(String)? onError,
  }) async {
    return await _client.execute(
      {
        'cmd': 'data/delete-all',
        'projectID': _client.projectID,
        'bucket': bucket,
      },
      onSuccess: onSuccess,
      onError: onError,
    );
  }
}

class RevaniUser {
  final RevaniClient _client;
  RevaniUser(this._client);

  Future<RevaniResponse> register({
    required String email,
    required String password,
    String? name,
    String? bio,
    int? age,
    String? profilePhoto,
    String? deviceId,
    String? deviceOs,
    Map<String, dynamic>? customData,
    Function(dynamic)? onSuccess,
    Function(String)? onError,
  }) async {
    final userData = {
      'email': email,
      'password': password,
      'name': name,
      'bio': bio,
      'age': age,
      'profile_photo': profilePhoto,
      'device_id': deviceId,
      'device_os': deviceOs,
      'data': customData,
    };
    return await _client.execute(
      {
        'cmd': 'user/register',
        'accountID': _client.accountID,
        'projectName': _client.projectName,
        'userData': userData,
      },
      onSuccess: onSuccess,
      onError: onError,
    );
  }

  Future<RevaniResponse> login(
    String email,
    String password, {
    Function(dynamic)? onSuccess,
    Function(String)? onError,
  }) async {
    final res = await _client.execute(
      {
        'cmd': 'user/login',
        'accountID': _client.accountID,
        'projectName': _client.projectName,
        'email': email,
        'password': password,
      },
      onSuccess: onSuccess,
      onError: onError,
    );

    if (res.isSuccess && res.data['token'] != null) {
      _client.setSession(res.data['token']);
      await _client._saveSession();
    }
    return res;
  }

  Future<RevaniResponse> getProfile(
    String userId, {
    Function(dynamic)? onSuccess,
    Function(String)? onError,
  }) async {
    return await _client.execute(
      {
        'cmd': 'user/get-profile',
        'accountID': _client.accountID,
        'projectName': _client.projectName,
        'userId': userId,
      },
      onSuccess: onSuccess,
      onError: onError,
    );
  }

  Future<RevaniResponse> editProfile(
    String userId,
    Map<String, dynamic> updates, {
    Function(dynamic)? onSuccess,
    Function(String)? onError,
  }) async {
    return await _client.execute(
      {'cmd': 'user/edit-profile', 'userId': userId, 'updates': updates},
      onSuccess: onSuccess,
      onError: onError,
    );
  }

  Future<RevaniResponse> changePassword(
    String userId,
    String oldPass,
    String newPass, {
    Function(dynamic)? onSuccess,
    Function(String)? onError,
  }) async {
    return await _client.execute(
      {
        'cmd': 'user/change-password',
        'userId': userId,
        'oldPass': oldPass,
        'newPass': newPass,
      },
      onSuccess: onSuccess,
      onError: onError,
    );
  }
}

class RevaniSocial {
  final RevaniClient _client;
  RevaniSocial(this._client);

  Future<RevaniResponse> createPost({
    required String userId,
    required String text,
    List<String>? images,
    String? video,
    List<String>? documents,
    Function(dynamic)? onSuccess,
    Function(String)? onError,
  }) async {
    return await _client.execute(
      {
        'cmd': 'social/post/create',
        'accountID': _client.accountID,
        'projectName': _client.projectName,
        'postData': {
          'user_id': userId,
          'text': text,
          'images': images,
          'video': video,
          'documents': documents,
        },
      },
      onSuccess: onSuccess,
      onError: onError,
    );
  }

  Future<RevaniResponse> getPost(
    String postId, {
    Function(dynamic)? onSuccess,
    Function(String)? onError,
  }) async {
    return await _client.execute(
      {'cmd': 'social/post/get', 'postId': postId},
      onSuccess: onSuccess,
      onError: onError,
    );
  }

  Future<RevaniResponse> likePost(
    String postId,
    String userId,
    bool isLike, {
    Function(dynamic)? onSuccess,
    Function(String)? onError,
  }) async {
    return await _client.execute(
      {
        'cmd': 'social/post/like',
        'postId': postId,
        'userId': userId,
        'isLike': isLike,
      },
      onSuccess: onSuccess,
      onError: onError,
    );
  }

  Future<RevaniResponse> viewPost(
    String postId, {
    Function(dynamic)? onSuccess,
    Function(String)? onError,
  }) async {
    return await _client.execute(
      {'cmd': 'social/post/view', 'postId': postId},
      onSuccess: onSuccess,
      onError: onError,
    );
  }

  Future<RevaniResponse> addComment(
    String postId,
    String userId,
    String text, {
    Function(dynamic)? onSuccess,
    Function(String)? onError,
  }) async {
    return await _client.execute(
      {
        'cmd': 'social/comment/add',
        'postId': postId,
        'userId': userId,
        'text': text,
      },
      onSuccess: onSuccess,
      onError: onError,
    );
  }

  Future<RevaniResponse> getComments(
    String postId, {
    Function(dynamic)? onSuccess,
    Function(String)? onError,
  }) async {
    return await _client.execute(
      {'cmd': 'social/comment/get', 'postId': postId},
      onSuccess: onSuccess,
      onError: onError,
    );
  }

  Future<RevaniResponse> likeComment(
    String commentId,
    String userId,
    bool isLike, {
    Function(dynamic)? onSuccess,
    Function(String)? onError,
  }) async {
    return await _client.execute(
      {
        'cmd': 'social/comment/like',
        'commentId': commentId,
        'userId': userId,
        'isLike': isLike,
      },
      onSuccess: onSuccess,
      onError: onError,
    );
  }
}

class RevaniChat {
  final RevaniClient _client;
  RevaniChat(this._client);

  Future<RevaniResponse> create(
    List<String> participants, {
    Function(dynamic)? onSuccess,
    Function(String)? onError,
  }) async {
    return await _client.execute(
      {
        'cmd': 'chat/create',
        'accountID': _client.accountID,
        'projectName': _client.projectName,
        'participants': participants,
      },
      onSuccess: onSuccess,
      onError: onError,
    );
  }

  Future<RevaniResponse> getList(
    String userId, {
    Function(dynamic)? onSuccess,
    Function(String)? onError,
  }) async {
    return await _client.execute(
      {
        'cmd': 'chat/get-list',
        'accountID': _client.accountID,
        'projectName': _client.projectName,
        'userId': userId,
      },
      onSuccess: onSuccess,
      onError: onError,
    );
  }

  Future<RevaniResponse> delete(
    String chatId, {
    Function(dynamic)? onSuccess,
    Function(String)? onError,
  }) async {
    return await _client.execute(
      {'cmd': 'chat/delete', 'chatId': chatId},
      onSuccess: onSuccess,
      onError: onError,
    );
  }

  Future<RevaniResponse> sendMessage(
    String chatId,
    String senderId,
    Map<String, dynamic> messageData, {
    Function(dynamic)? onSuccess,
    Function(String)? onError,
  }) async {
    return await _client.execute(
      {
        'cmd': 'chat/message/send',
        'chatId': chatId,
        'senderId': senderId,
        'messageData': messageData,
      },
      onSuccess: onSuccess,
      onError: onError,
    );
  }

  Future<RevaniResponse> getMessages(
    String chatId, {
    Function(dynamic)? onSuccess,
    Function(String)? onError,
  }) async {
    return await _client.execute(
      {'cmd': 'chat/message/list', 'chatId': chatId},
      onSuccess: onSuccess,
      onError: onError,
    );
  }

  Future<RevaniResponse> updateMessage(
    String messageId,
    String senderId,
    String newText, {
    Function(dynamic)? onSuccess,
    Function(String)? onError,
  }) async {
    return await _client.execute(
      {
        'cmd': 'chat/message/update',
        'messageId': messageId,
        'senderId': senderId,
        'newText': newText,
      },
      onSuccess: onSuccess,
      onError: onError,
    );
  }

  Future<RevaniResponse> deleteMessage(
    String messageId,
    String userId, {
    Function(dynamic)? onSuccess,
    Function(String)? onError,
  }) async {
    return await _client.execute(
      {'cmd': 'chat/message/delete', 'messageId': messageId, 'userId': userId},
      onSuccess: onSuccess,
      onError: onError,
    );
  }

  Future<RevaniResponse> react(
    String messageId,
    String userId,
    String emoji,
    bool add, {
    Function(dynamic)? onSuccess,
    Function(String)? onError,
  }) async {
    return await _client.execute(
      {
        'cmd': 'chat/message/react',
        'messageId': messageId,
        'userId': userId,
        'emoji': emoji,
        'add': add,
      },
      onSuccess: onSuccess,
      onError: onError,
    );
  }

  Future<RevaniResponse> pinMessage(
    String messageId,
    bool pin, {
    Function(dynamic)? onSuccess,
    Function(String)? onError,
  }) async {
    return await _client.execute(
      {'cmd': 'chat/message/pin', 'messageId': messageId, 'pin': pin},
      onSuccess: onSuccess,
      onError: onError,
    );
  }

  Future<RevaniResponse> getPinned(
    String chatId, {
    Function(dynamic)? onSuccess,
    Function(String)? onError,
  }) async {
    return await _client.execute(
      {'cmd': 'chat/message/get-pinned', 'chatId': chatId},
      onSuccess: onSuccess,
      onError: onError,
    );
  }
}

class RevaniStorage {
  final RevaniClient _client;
  RevaniStorage(this._client);

  Future<RevaniResponse> upload({
    required String fileName,
    required List<int> bytes,
    bool compress = false,
    Function(dynamic)? onSuccess,
    Function(String)? onError,
  }) async {
    return await _client.execute(
      {
        'cmd': 'storage/upload',
        'accountID': _client.accountID,
        'projectName': _client.projectName,
        'fileName': fileName,
        'bytes': bytes,
        'compress': compress,
      },
      onSuccess: onSuccess,
      onError: onError,
    );
  }

  Future<RevaniResponse> download(
    String fileId, {
    Function(dynamic)? onSuccess,
    Function(String)? onError,
  }) async {
    return await _client.execute(
      {
        'cmd': 'storage/download',
        'accountID': _client.accountID,
        'projectName': _client.projectName,
        'fileId': fileId,
      },
      onSuccess: onSuccess,
      onError: onError,
    );
  }

  Future<RevaniResponse> delete(
    String fileId, {
    Function(dynamic)? onSuccess,
    Function(String)? onError,
  }) async {
    return await _client.execute(
      {
        'cmd': 'storage/delete',
        'accountID': _client.accountID,
        'projectName': _client.projectName,
        'fileId': fileId,
      },
      onSuccess: onSuccess,
      onError: onError,
    );
  }
}

class RevaniLivekit {
  final RevaniClient _client;
  RevaniLivekit(this._client);

  Future<RevaniResponse> init(
    String host,
    String apiKey,
    String apiSecret, {
    Function(dynamic)? onSuccess,
    Function(String)? onError,
  }) async {
    return await _client.execute(
      {
        'cmd': 'livekit/init',
        'host': host,
        'apiKey': apiKey,
        'apiSecret': apiSecret,
      },
      onSuccess: onSuccess,
      onError: onError,
    );
  }

  Future<RevaniResponse> autoConnect({
    Function(dynamic)? onSuccess,
    Function(String)? onError,
  }) async {
    return await _client.execute(
      {
        'cmd': 'livekit/connect',
        'accountID': _client.accountID,
        'projectName': _client.projectName,
      },
      onSuccess: onSuccess,
      onError: onError,
    );
  }

  Future<RevaniResponse> createToken({
    required String roomName,
    required String userID,
    required String userName,
    bool isAdmin = false,
    Function(dynamic)? onSuccess,
    Function(String)? onError,
  }) async {
    return await _client.execute(
      {
        'cmd': 'livekit/create-token',
        'roomName': roomName,
        'userID': userID,
        'userName': userName,
        'isAdmin': isAdmin,
      },
      onSuccess: onSuccess,
      onError: onError,
    );
  }

  Future<RevaniResponse> createRoom(
    String roomName, {
    int timeout = 10,
    int maxUsers = 50,
    Function(dynamic)? onSuccess,
    Function(String)? onError,
  }) async {
    return await _client.execute(
      {
        'cmd': 'livekit/create-room',
        'roomName': roomName,
        'emptyTimeoutMinute': timeout,
        'maxUsers': maxUsers,
      },
      onSuccess: onSuccess,
      onError: onError,
    );
  }
}

class RevaniPubSub {
  final RevaniClient _client;
  RevaniPubSub(this._client);

  Future<RevaniResponse> subscribe(
    String topic,
    String clientId, {
    Function(dynamic)? onSuccess,
    Function(String)? onError,
  }) async {
    return await _client.execute(
      {
        'cmd': 'pubsub/subscribe',
        'accountID': _client.accountID,
        'projectName': _client.projectName,
        'clientId': clientId,
        'topic': topic,
      },
      onSuccess: onSuccess,
      onError: onError,
    );
  }

  Future<RevaniResponse> publish(
    String topic,
    Map<String, dynamic> data, [
    String? clientId,
    Function(dynamic)? onSuccess,
    Function(String)? onError,
  ]) async {
    return await _client.execute(
      {
        'cmd': 'pubsub/publish',
        'accountID': _client.accountID,
        'projectName': _client.projectName,
        'topic': topic,
        'data': data,
        'clientId': clientId,
      },
      onSuccess: onSuccess,
      onError: onError,
    );
  }

  Future<RevaniResponse> unsubscribe(
    String topic,
    String clientId, {
    Function(dynamic)? onSuccess,
    Function(String)? onError,
  }) async {
    return await _client.execute(
      {'cmd': 'pubsub/unsubscribe', 'clientId': clientId, 'topic': topic},
      onSuccess: onSuccess,
      onError: onError,
    );
  }
}
