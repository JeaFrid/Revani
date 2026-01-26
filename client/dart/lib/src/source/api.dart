import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:path/path.dart' as p;

class UserRegisterRequest {
  final String email;
  final String password;
  final String? name;
  final String? bio;
  final int? age;
  final String? profilePhoto;
  final String? deviceId;
  final String? ipAddress;
  final String? deviceOs;
  final Map<String, dynamic> customData;

  UserRegisterRequest({
    required this.email,
    required this.password,
    this.name,
    this.bio,
    this.age,
    this.profilePhoto,
    this.deviceId,
    this.ipAddress,
    this.deviceOs,
    this.customData = const {},
  }) {
    if (email.isEmpty || !email.contains('@')) {
      throw ArgumentError('Invalid email format');
    }
    if (password.length < 6) {
      throw ArgumentError('Password must be at least 6 characters');
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'password': password,
      'name': name ?? '',
      'bio': bio ?? '',
      'age': age ?? 0,
      'profile_photo': profilePhoto ?? '',
      'device_id': deviceId ?? '',
      'ip_address': ipAddress ?? '',
      'device_os': deviceOs ?? '',
      'custom_data': customData,
    };
  }
}

class UserProfileUpdateRequest {
  final String? name;
  final String? bio;
  final int? age;
  final String? profilePhoto;
  final String? deviceId;
  final String? ipAddress;
  final String? deviceOs;
  final bool? isVerified;
  final Map<String, dynamic> customData;

  UserProfileUpdateRequest({
    this.name,
    this.bio,
    this.age,
    this.profilePhoto,
    this.deviceId,
    this.ipAddress,
    this.deviceOs,
    this.isVerified,
    this.customData = const {},
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{};
    if (name != null) map['name'] = name;
    if (bio != null) map['bio'] = bio;
    if (age != null) map['age'] = age;
    if (profilePhoto != null) map['profile_photo'] = profilePhoto;
    if (deviceId != null) map['device_id'] = deviceId;
    if (ipAddress != null) map['ip_address'] = ipAddress;
    if (deviceOs != null) map['device_os'] = deviceOs;
    if (isVerified != null) map['is_verified'] = isVerified;
    map['custom_data'] = customData;
    return map;
  }
}

class CreatePostRequest {
  final String text;
  final List<String> images;
  final String? video;
  final List<String> documents;
  final Map<String, dynamic> customData;

  CreatePostRequest({
    required this.text,
    this.images = const [],
    this.video,
    this.documents = const [],
    this.customData = const {},
  }) {
    if (text.trim().isEmpty) {
      throw ArgumentError('Post text cannot be empty');
    }
    if (images.length > 10) {
      throw ArgumentError('Maximum 10 images allowed');
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'images': images,
      'video': video,
      'documents': documents,
      'custom_data': customData,
    };
  }
}

class SendMessageRequest {
  final String text;
  final String? image;
  final String? video;
  final Map<String, dynamic> custom;
  final String? replyTo;
  final String? forwardedFrom;
  final Map<String, dynamic> customData;

  SendMessageRequest({
    this.text = "",
    this.image,
    this.video,
    this.custom = const {},
    this.replyTo,
    this.forwardedFrom,
    this.customData = const {},
  });

  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'image': image,
      'video': video,
      'custom': custom,
      'reply_to': replyTo,
      'forwarded_from': forwardedFrom,
      'custom_data': customData,
    };
  }
}

class CreateRoomRequest {
  final String roomName;
  final int emptyTimeoutMinute;
  final int maxUsers;
  final Map<String, dynamic> metadata;
  final Map<String, dynamic> customData;

  CreateRoomRequest({
    required this.roomName,
    this.emptyTimeoutMinute = 10,
    this.maxUsers = 50,
    this.metadata = const {},
    this.customData = const {},
  });

  Map<String, dynamic> toMap() {
    return {
      'roomName': roomName,
      'emptyTimeoutMinute': emptyTimeoutMinute,
      'maxUsers': maxUsers,
      'metadata': jsonEncode(metadata),
      'custom_data': customData,
    };
  }
}

class UpdateParticipantRequest {
  final String? metadata;
  final dynamic permission;
  final Map<String, dynamic> customData;

  UpdateParticipantRequest({
    this.metadata,
    this.permission,
    this.customData = const {},
  });

  Map<String, dynamic> toMap() {
    return {
      'metadata': metadata,
      'permission': permission,
      'custom_data': customData,
    };
  }
}

class PubSubSubscribeRequest {
  final String clientId;
  final String topic;
  final Map<String, dynamic> customData;

  PubSubSubscribeRequest({
    required this.clientId,
    required this.topic,
    this.customData = const {},
  });

  Map<String, dynamic> toMap() {
    return {'clientId': clientId, 'topic': topic, 'custom_data': customData};
  }
}

class PubSubPublishRequest {
  final String topic;
  final Map<String, dynamic> data;
  final String? senderId;
  final Map<String, dynamic> customData;

  PubSubPublishRequest({
    required this.topic,
    required this.data,
    this.senderId,
    this.customData = const {},
  });

  Map<String, dynamic> toMap() {
    return {
      'topic': topic,
      'data': data,
      'senderId': senderId,
      'custom_data': customData,
    };
  }
}

class DataAddRequest {
  final String bucket;
  final String tag;
  final Map<String, dynamic> value;
  final Map<String, dynamic> customData;

  DataAddRequest({
    required this.bucket,
    required this.tag,
    required this.value,
    this.customData = const {},
  });

  Map<String, dynamic> toMap() {
    return {
      'bucket': bucket,
      'tag': tag,
      'value': value,
      'custom_data': customData,
    };
  }
}

class DataQueryRequest {
  final String bucket;
  final Map<String, dynamic> query;
  final Map<String, dynamic> customData;

  DataQueryRequest({
    required this.bucket,
    required this.query,
    this.customData = const {},
  });

  Map<String, dynamic> toMap() {
    return {'bucket': bucket, 'query': query, 'custom_data': customData};
  }
}

class LivekitRoomInfo {
  final String name;
  final int totalUserCount;
  final int maxUserCount;
  final String uptime;
  final String metadata;
  final Map<String, dynamic> customData;

  LivekitRoomInfo({
    required this.name,
    required this.totalUserCount,
    required this.maxUserCount,
    required this.uptime,
    required this.metadata,
    required this.customData,
  });

  factory LivekitRoomInfo.fromMap(Map<String, dynamic> map) {
    return LivekitRoomInfo(
      name: map['name'] ?? '',
      totalUserCount: map['total_user_count'] ?? 0,
      maxUserCount: map['max_user_count'] ?? 0,
      uptime: map['time'] ?? '',
      metadata: map['metadata'] ?? '',
      customData: map['custom_data'] != null
          ? Map<String, dynamic>.from(map['custom_data'])
          : {},
    );
  }
}

class LivekitParticipant {
  final String id;
  final String name;
  final String state;
  final bool isAdmin;
  final String joinedAt;
  final String metadata;
  final Map<String, dynamic> customData;

  LivekitParticipant({
    required this.id,
    required this.name,
    required this.state,
    required this.isAdmin,
    required this.joinedAt,
    required this.metadata,
    required this.customData,
  });

  factory LivekitParticipant.fromMap(Map<String, dynamic> map) {
    return LivekitParticipant(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      state: map['state'] ?? '',
      isAdmin: map['isAdmin'] ?? false,
      joinedAt: map['joinedAt'] ?? '',
      metadata: map['metadata'] ?? '',
      customData: map['custom_data'] != null
          ? Map<String, dynamic>.from(map['custom_data'])
          : {},
    );
  }
}

class BucketEvent {
  final String action;
  final String bucket;
  final String? tag;
  final Map<String, dynamic>? oldValue;
  final Map<String, dynamic>? newValue;
  final String? projectId;
  final String? clientId;
  final int timestamp;

  BucketEvent({
    required this.action,
    required this.bucket,
    this.tag,
    this.oldValue,
    this.newValue,
    this.projectId,
    this.clientId,
    required this.timestamp,
  });

  factory BucketEvent.fromMap(Map<String, dynamic> map) {
    return BucketEvent(
      action: map['action'] ?? '',
      bucket: map['bucket'] ?? '',
      tag: map['tag'],
      oldValue: map['oldValue'] != null
          ? Map<String, dynamic>.from(map['oldValue'])
          : null,
      newValue: map['newValue'] != null
          ? Map<String, dynamic>.from(map['newValue'])
          : null,
      projectId: map['projectId'],
      clientId: map['clientId'],
      timestamp: map['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
    );
  }
}

class RevaniResponse<T> {
  final int status;
  final String message;
  final String? error;
  final T? data;
  final String? description;

  RevaniResponse({
    required this.status,
    required this.message,
    this.error,
    this.data,
    this.description,
  });

  bool get isSuccess => status >= 200 && status < 300;

  static RevaniResponse<T> fromMap<T>(
    Map<String, dynamic> map,
    T Function(dynamic)? parser,
  ) {
    dynamic rawData = map['data'];
    if (rawData == null && map.containsKey('id')) {
      rawData = {'id': map['id']};
    } else if (rawData == null && map.containsKey('token')) {
      rawData = {'token': map['token']};
    } else if (rawData == null && map.containsKey('payload')) {
      rawData = map['payload'];
    }

    T? parsedData;
    if (rawData != null && parser != null) {
      if (rawData is List) {
        parsedData = parser(rawData);
      } else if (rawData is Map) {
        Map<String, dynamic> combined = Map<String, dynamic>.from(rawData);
        if (map.containsKey('session_key')) {
          combined['session_key'] = map['session_key'];
        }
        if (map.containsKey('token')) combined['token'] = map['token'];
        if (map.containsKey('id')) combined['id'] = map['id'];
        parsedData = parser(combined);
      } else {
        parsedData = parser(rawData);
      }
    } else if (rawData != null && T == dynamic) {
      parsedData = rawData as T;
    }

    return RevaniResponse<T>(
      status: map['status'] ?? 500,
      message: map['message'] ?? (map['msg'] ?? 'Unknown'),
      error: map['error'],
      data: parsedData,
      description: map['description'],
    );
  }

  RevaniResponse.networkError(String errorDetail)
    : status = 503,
      message = 'Network Error',
      error = errorDetail,
      description = 'Connection failed',
      data = null;
}

typedef SuccessCallback<T> = void Function(RevaniResponse<T> response);
typedef ErrorCallback<T> = void Function(RevaniResponse<T> response);

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
  String? _token;
  int _serverTimeOffset = 0;
  bool _isReconnecting = false;

  late final RevaniAccount account;
  late final RevaniProject project;
  late final RevaniData data;
  late final RevaniStorage storage;
  late final RevaniLivekit livekit;
  late final RevaniPubSub pubsub;

  late final http.Client _httpClient;

  final StreamController<Map<String, dynamic>> _responseController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<BucketEvent> _bucketEventController =
      StreamController<BucketEvent>.broadcast();
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
    storage = RevaniStorage(this);
    livekit = RevaniLivekit(this);
    pubsub = RevaniPubSub(this);

    final ioc = HttpClient();
    ioc.badCertificateCallback =
        (X509Certificate cert, String host, int port) => true;
    _httpClient = IOClient(ioc);
  }

  String get httpBaseUrl {
    if (secure) {
      return "https://$host";
    }
    return "http://$host:${port + 1}";
  }

  Future<void> connect() async {
    try {
      if (secure) {
        _socket = await SecureSocket.connect(
          host,
          port,
          onBadCertificate: (cert) => true,
        ).timeout(const Duration(seconds: 10));
      } else {
        _socket = await Socket.connect(
          host,
          port,
        ).timeout(const Duration(seconds: 10));
      }

      _socket!.listen(
        _onData,
        onError: (e) => _handleConnectionError(e),
        onDone: () => _handleConnectionDone(),
      );
      _isReconnecting = false;
      await _syncTime();
    } catch (e) {
      if (autoReconnect) _attemptReconnect();
    }
  }

  Future<void> _syncTime() async {
    try {
      final res = await execute({
        'cmd': 'health',
      }, useEncryption: false).timeout(const Duration(seconds: 2));
      if (res.isSuccess &&
          res.data != null &&
          res.data['payload'] != null &&
          res.data['payload']['ts'] != null) {
        _serverTimeOffset =
            res.data['payload']['ts'] - DateTime.now().millisecondsSinceEpoch;
      }
    } catch (_) {}
  }

  void _attemptReconnect() async {
    if (_isReconnecting) return;
    _isReconnecting = true;
    _socket?.destroy();
    _socket = null;
    await Future.delayed(const Duration(seconds: 2));
    try {
      await connect();
    } catch (_) {}
  }

  void _onData(Uint8List data) {
    _buffer.addAll(data);
    while (true) {
      if (_buffer.length < 4) break;
      final headerBytes = Uint8List.fromList(_buffer.sublist(0, 4));
      final header = ByteData.sublistView(headerBytes);
      final length = header.getUint32(0);
      if (_buffer.length >= length + 4) {
        final payload = Uint8List.fromList(_buffer.sublist(4, length + 4));
        _buffer.removeRange(0, length + 4);
        try {
          final json = jsonDecode(utf8.decode(payload));
          if (json is Map<String, dynamic> &&
              json.containsKey('encrypted') &&
              _sessionKey != null) {
            final decrypted = jsonDecode(_decrypt(json['encrypted']));
            if (decrypted is Map<String, dynamic>) {
              _handleBucketEvent(decrypted);
              _responseController.add(decrypted);
            }
          } else if (json is Map<String, dynamic>) {
            _handleBucketEvent(json);
            _responseController.add(json);
          }
        } catch (_) {}
      } else {
        break;
      }
    }
  }

  void _handleBucketEvent(Map<String, dynamic> json) {
    if (json.containsKey('action') &&
        ['added', 'updated', 'deleted', 'clear'].contains(json['action']) &&
        json.containsKey('bucket')) {
      final event = BucketEvent.fromMap(json);
      _bucketEventController.add(event);
    }
  }

  Future<RevaniResponse<T>> execute<T>(
    Map<String, dynamic> command, {
    bool useEncryption = true,
    SuccessCallback<T>? onSuccess,
    ErrorCallback<T>? onError,
    T Function(dynamic)? parser,
  }) async {
    if (_socket == null) {
      final res = RevaniResponse<T>.networkError("Not connected");
      onError?.call(res);
      return res;
    }

    try {
      final responseFuture = _responseController.stream.first;
      final payload = (useEncryption && _sessionKey != null)
          ? {'encrypted': _encrypt(jsonEncode(command))}
          : command;

      final bytes = utf8.encode(jsonEncode(payload));
      _socket!.add(
        (ByteData(4)..setUint32(0, bytes.length)).buffer.asUint8List(),
      );
      _socket!.add(bytes);

      final rawResponse = await responseFuture.timeout(
        const Duration(seconds: 5),
      );
      final response = RevaniResponse.fromMap<T>(rawResponse, parser);

      if (response.isSuccess) {
        onSuccess?.call(response);
      } else {
        onError?.call(response);
      }
      return response;
    } catch (e) {
      final res = RevaniResponse<T>.networkError(e.toString());
      onError?.call(res);
      return res;
    }
  }

  String _encrypt(String text) {
    final wrapper = jsonEncode({
      "payload": text,
      "ts": DateTime.now().millisecondsSinceEpoch + _serverTimeOffset,
    });
    final salt = encrypt.IV.fromSecureRandom(16);
    final key = encrypt.Key(
      Uint8List.fromList(
        sha256.convert(utf8.encode(_sessionKey! + salt.base64)).bytes,
      ),
    );
    final iv = encrypt.IV.fromSecureRandom(16);
    final encrypter = encrypt.Encrypter(
      encrypt.AES(key, mode: encrypt.AESMode.gcm),
    );
    return "${salt.base64}:${iv.base64}:${encrypter.encrypt(wrapper, iv: iv).base64}";
  }

  String _decrypt(String encryptedData) {
    final parts = encryptedData.split(':');
    final key = encrypt.Key(
      Uint8List.fromList(
        sha256.convert(utf8.encode(_sessionKey! + parts[0])).bytes,
      ),
    );
    final encrypter = encrypt.Encrypter(
      encrypt.AES(key, mode: encrypt.AESMode.gcm),
    );
    return jsonDecode(
      encrypter.decrypt64(parts[2], iv: encrypt.IV.fromBase64(parts[1])),
    )['payload'];
  }

  void setSession(String key) => _sessionKey = key;
  void setAccount(String id) => _accountID = id;
  void setToken(String token) => _token = token;
  void setProject(String name, String? id) {
    _projectName = name;
    _projectID = id;
  }

  String get accountID => _accountID ?? "";
  String get projectName => _projectName ?? "";
  String get projectID => _projectID ?? "";
  String get token => _token ?? "";
  bool get isSignedIn => _token != null && _token!.isNotEmpty;

  Stream<BucketEvent> get bucketEvents => _bucketEventController.stream;

  Stream<BucketEvent> watchBucket(String bucketName) {
    return bucketEvents.where((event) => event.bucket == bucketName);
  }

  Stream<BucketEvent> watchAddedEvents(String bucketName) {
    return watchBucket(bucketName).where((event) => event.action == 'added');
  }

  Stream<BucketEvent> watchUpdatedEvents(String bucketName) {
    return watchBucket(bucketName).where((event) => event.action == 'updated');
  }

  Stream<BucketEvent> watchDeletedEvents(String bucketName) {
    return watchBucket(bucketName).where((event) => event.action == 'deleted');
  }

  Stream<BucketEvent> watchTag(String bucketName, String tag) {
    return watchBucket(bucketName).where((event) => event.tag == tag);
  }

  Future<RevaniResponse<Map<String, dynamic>>> subscribeToBucket({
    required String bucket,
    required String clientId,
    Map<String, dynamic> customData = const {},
    SuccessCallback<Map<String, dynamic>>? onSuccess,
    ErrorCallback<Map<String, dynamic>>? onError,
  }) async {
    return await execute<Map<String, dynamic>>(
      {
        'cmd': 'bucket/subscribe',
        'accountID': _accountID,
        'projectId': _projectID,
        'bucket': bucket,
        'clientId': clientId,
        'custom_data': customData,
      },
      onSuccess: onSuccess,
      onError: onError,
      parser: (data) => Map<String, dynamic>.from(data),
    );
  }

  Future<RevaniResponse<void>> unsubscribeFromBucket({
    required String bucket,
    required String clientId,
    Map<String, dynamic> customData = const {},
    SuccessCallback<void>? onSuccess,
    ErrorCallback<void>? onError,
  }) async {
    return await execute<void>(
      {
        'cmd': 'bucket/unsubscribe',
        'clientId': clientId,
        'bucket': bucket,
        'projectId': _projectID,
        'custom_data': customData,
      },
      onSuccess: onSuccess,
      onError: onError,
    );
  }

  void logout() {
    _sessionKey = null;
    _accountID = null;
    _token = null;
    _socket?.destroy();
    _socket = null;
  }

  void _handleConnectionError(dynamic e) => _attemptReconnect();
  void _handleConnectionDone() => _attemptReconnect();
}

class RevaniAccount {
  final RevaniClient _client;
  RevaniAccount(this._client);

  Future<RevaniResponse<Map<String, dynamic>>> login(
    String email,
    String password, {
    SuccessCallback<Map<String, dynamic>>? onSuccess,
    ErrorCallback<Map<String, dynamic>>? onError,
  }) async {
    final res = await _client.execute<Map<String, dynamic>>(
      {'cmd': 'auth/login', 'email': email, 'password': password},
      useEncryption: false,
      parser: (data) => Map<String, dynamic>.from(data),
    );

    if (res.isSuccess && res.data != null) {
      if (res.data!.containsKey('session_key')) {
        _client.setSession(res.data!['session_key']);
      }
      if (res.data!.containsKey('token')) {
        _client.setToken(res.data!['token']);
      }
      if (res.data!.containsKey('id')) {
        _client.setAccount(res.data!['id']);
        onSuccess?.call(res);
        return res;
      }
    }
    onError?.call(res);
    return res;
  }

  Future<RevaniResponse<Map<String, dynamic>>> create(
    String email,
    String password, {
    Map<String, dynamic> data = const {},
    SuccessCallback<Map<String, dynamic>>? onSuccess,
    ErrorCallback<Map<String, dynamic>>? onError,
  }) => _client.execute<Map<String, dynamic>>(
    {
      'cmd': 'account/create',
      'email': email,
      'password': password,
      'data': data,
    },
    useEncryption: false,
    onSuccess: onSuccess,
    onError: onError,
    parser: (data) => Map<String, dynamic>.from(data),
  );

  Future<RevaniResponse<Map<String, dynamic>>> getData({
    SuccessCallback<Map<String, dynamic>>? onSuccess,
    ErrorCallback<Map<String, dynamic>>? onError,
  }) => _client.execute<Map<String, dynamic>>(
    {'cmd': 'account/get-data', 'id': _client.accountID},
    onSuccess: onSuccess,
    onError: onError,
    parser: (data) => Map<String, dynamic>.from(data),
  );
}

class RevaniProject {
  final RevaniClient _client;
  RevaniProject(this._client);

  Future<RevaniResponse<String>> use(
    String name, {
    SuccessCallback<String>? onSuccess,
    ErrorCallback<String>? onError,
  }) async {
    final res = await _client.execute<String>({
      'cmd': 'project/exist',
      'accountID': _client.accountID,
      'projectName': name,
    }, parser: (data) => data['id'] ?? data['payload'] ?? "");
    if (res.isSuccess) {
      _client.setProject(name, res.data);
      onSuccess?.call(res);
    } else {
      onError?.call(res);
    }
    return res;
  }

  Future<RevaniResponse<Map<String, dynamic>>> create(
    String name, {
    Map<String, dynamic> customData = const {},
    SuccessCallback<Map<String, dynamic>>? onSuccess,
    ErrorCallback<Map<String, dynamic>>? onError,
  }) => _client.execute<Map<String, dynamic>>(
    {
      'cmd': 'project/create',
      'accountID': _client.accountID,
      'projectName': name,
      'custom_data': customData,
    },
    onSuccess: onSuccess,
    onError: onError,
    parser: (data) => Map<String, dynamic>.from(data),
  );
}

class RevaniData {
  final RevaniClient _client;
  RevaniData(this._client);

  Future<RevaniResponse<Map<String, dynamic>>> add({
    required DataAddRequest request,
    SuccessCallback<Map<String, dynamic>>? onSuccess,
    ErrorCallback<Map<String, dynamic>>? onError,
  }) => _client.execute<Map<String, dynamic>>(
    {
      'cmd': 'data/add',
      'accountID': _client.accountID,
      'projectName': _client.projectName,
      ...request.toMap(),
    },
    onSuccess: onSuccess,
    onError: onError,
    parser: (data) => Map<String, dynamic>.from(data),
  );

  Future<RevaniResponse<Map<String, dynamic>>> addBatch({
    required String bucket,
    required Map<String, Map<String, dynamic>> items,
    Map<String, dynamic> customData = const {},
    SuccessCallback<Map<String, dynamic>>? onSuccess,
    ErrorCallback<Map<String, dynamic>>? onError,
  }) => _client.execute<Map<String, dynamic>>(
    {
      'cmd': 'data/add-batch',
      'accountID': _client.accountID,
      'projectName': _client.projectName,
      'bucket': bucket,
      'items': items,
      'custom_data': customData,
    },
    onSuccess: onSuccess,
    onError: onError,
    parser: (data) => Map<String, dynamic>.from(data),
  );

  Future<RevaniResponse<Map<String, dynamic>>> get({
    required String bucket,
    required String tag,
    SuccessCallback<Map<String, dynamic>>? onSuccess,
    ErrorCallback<Map<String, dynamic>>? onError,
  }) => _client.execute<Map<String, dynamic>>(
    {
      'cmd': 'data/get',
      'projectID': _client.projectID,
      'bucket': bucket,
      'tag': tag,
    },
    onSuccess: onSuccess,
    onError: onError,
    parser: (data) => Map<String, dynamic>.from(data),
  );

  Future<RevaniResponse<List<Map<String, dynamic>>>> getAll({
    required String bucket,
    SuccessCallback<List<Map<String, dynamic>>>? onSuccess,
    ErrorCallback<List<Map<String, dynamic>>>? onError,
  }) => _client.execute<List<Map<String, dynamic>>>(
    {'cmd': 'data/get-all', 'projectID': _client.projectID, 'bucket': bucket},
    onSuccess: onSuccess,
    onError: onError,
    parser: (data) => List<Map<String, dynamic>>.from(data),
  );

  Future<RevaniResponse<List<Map<String, dynamic>>>> query({
    required DataQueryRequest request,
    SuccessCallback<List<Map<String, dynamic>>>? onSuccess,
    ErrorCallback<List<Map<String, dynamic>>>? onError,
  }) => _client.execute<List<Map<String, dynamic>>>(
    {
      'cmd': 'data/query',
      'accountID': _client.accountID,
      'projectName': _client.projectName,
      ...request.toMap(),
    },
    onSuccess: onSuccess,
    onError: onError,
    parser: (data) => List<Map<String, dynamic>>.from(data),
  );

  Future<RevaniResponse<void>> update({
    required String bucket,
    required String tag,
    required dynamic newValue,
    Map<String, dynamic> customData = const {},
    SuccessCallback<void>? onSuccess,
    ErrorCallback<void>? onError,
  }) => _client.execute<void>(
    {
      'cmd': 'data/update',
      'projectID': _client.projectID,
      'bucket': bucket,
      'tag': tag,
      'newValue': newValue,
      'custom_data': customData,
    },
    onSuccess: onSuccess,
    onError: onError,
  );

  Future<RevaniResponse<void>> delete({
    required String bucket,
    required String tag,
    Map<String, dynamic> customData = const {},
    SuccessCallback<void>? onSuccess,
    ErrorCallback<void>? onError,
  }) => _client.execute<void>(
    {
      'cmd': 'data/delete',
      'projectID': _client.projectID,
      'bucket': bucket,
      'tag': tag,
      'custom_data': customData,
    },
    onSuccess: onSuccess,
    onError: onError,
  );

  Future<RevaniResponse<void>> deleteAll({
    required String bucket,
    Map<String, dynamic> customData = const {},
    SuccessCallback<void>? onSuccess,
    ErrorCallback<void>? onError,
  }) => _client.execute<void>(
    {
      'cmd': 'data/delete-all',
      'projectID': _client.projectID,
      'bucket': bucket,
      'custom_data': customData,
    },
    onSuccess: onSuccess,
    onError: onError,
  );
}

class RevaniLivekit {
  final RevaniClient _client;
  RevaniLivekit(this._client);

  Future<RevaniResponse<void>> init({
    required String host,
    required String apiKey,
    required String apiSecret,
    Map<String, dynamic> customData = const {},
    SuccessCallback<void>? onSuccess,
    ErrorCallback<void>? onError,
  }) => _client.execute<void>(
    {
      'cmd': 'livekit/init',
      'host': host,
      'apiKey': apiKey,
      'apiSecret': apiSecret,
      'custom_data': customData,
    },
    onSuccess: onSuccess,
    onError: onError,
  );

  Future<RevaniResponse<void>> connect({
    Map<String, dynamic> customData = const {},
    SuccessCallback<void>? onSuccess,
    ErrorCallback<void>? onError,
  }) => _client.execute<void>(
    {
      'cmd': 'livekit/connect',
      'accountID': _client.accountID,
      'projectName': _client.projectName,
      'custom_data': customData,
    },
    onSuccess: onSuccess,
    onError: onError,
  );

  Future<RevaniResponse<Map<String, dynamic>>> createToken({
    required String roomName,
    required String userID,
    required String userName,
    bool isAdmin = false,
    Map<String, dynamic> customData = const {},
    SuccessCallback<Map<String, dynamic>>? onSuccess,
    ErrorCallback<Map<String, dynamic>>? onError,
  }) => _client.execute<Map<String, dynamic>>(
    {
      'cmd': 'livekit/create-token',
      'roomName': roomName,
      'userID': userID,
      'userName': userName,
      'isAdmin': isAdmin,
      'custom_data': customData,
    },
    onSuccess: onSuccess,
    onError: onError,
    parser: (data) => Map<String, dynamic>.from(data),
  );

  Future<RevaniResponse<void>> createRoom({
    required CreateRoomRequest request,
    SuccessCallback<void>? onSuccess,
    ErrorCallback<void>? onError,
  }) => _client.execute<void>(
    {'cmd': 'livekit/create-room', ...request.toMap()},
    onSuccess: onSuccess,
    onError: onError,
  );

  Future<RevaniResponse<void>> closeRoom({
    required String roomName,
    Map<String, dynamic> customData = const {},
    SuccessCallback<void>? onSuccess,
    ErrorCallback<void>? onError,
  }) => _client.execute<void>(
    {
      'cmd': 'livekit/close-room',
      'roomName': roomName,
      'custom_data': customData,
    },
    onSuccess: onSuccess,
    onError: onError,
  );

  Future<RevaniResponse<LivekitRoomInfo>> getRoomInfo({
    required String roomName,
    SuccessCallback<LivekitRoomInfo>? onSuccess,
    ErrorCallback<LivekitRoomInfo>? onError,
  }) => _client.execute<LivekitRoomInfo>(
    {'cmd': 'livekit/get-room-info', 'roomName': roomName},
    onSuccess: onSuccess,
    onError: onError,
    parser: (data) => LivekitRoomInfo.fromMap(data),
  );

  Future<RevaniResponse<Map<String, LivekitRoomInfo>>> getAllRooms({
    SuccessCallback<Map<String, LivekitRoomInfo>>? onSuccess,
    ErrorCallback<Map<String, LivekitRoomInfo>>? onError,
  }) => _client.execute<Map<String, LivekitRoomInfo>>(
    {'cmd': 'livekit/get-all-rooms'},
    onSuccess: onSuccess,
    onError: onError,
    parser: (data) {
      Map<String, LivekitRoomInfo> rooms = {};
      (data as Map).forEach((key, value) {
        rooms[key] = LivekitRoomInfo.fromMap(value);
      });
      return rooms;
    },
  );

  Future<RevaniResponse<void>> kickUser({
    required String roomName,
    required String userID,
    Map<String, dynamic> customData = const {},
    SuccessCallback<void>? onSuccess,
    ErrorCallback<void>? onError,
  }) => _client.execute<void>(
    {
      'cmd': 'livekit/kick-user',
      'roomName': roomName,
      'userID': userID,
      'custom_data': customData,
    },
    onSuccess: onSuccess,
    onError: onError,
  );

  Future<RevaniResponse<LivekitParticipant>> getUserInfo({
    required String roomName,
    required String userID,
    SuccessCallback<LivekitParticipant>? onSuccess,
    ErrorCallback<LivekitParticipant>? onError,
  }) => _client.execute<LivekitParticipant>(
    {'cmd': 'livekit/get-user-info', 'roomName': roomName, 'userID': userID},
    onSuccess: onSuccess,
    onError: onError,
    parser: (data) => LivekitParticipant.fromMap(data),
  );

  Future<RevaniResponse<void>> updateMetadata({
    required String roomName,
    required String metadata,
    Map<String, dynamic> customData = const {},
    SuccessCallback<void>? onSuccess,
    ErrorCallback<void>? onError,
  }) => _client.execute<void>(
    {
      'cmd': 'livekit/update-metadata',
      'roomName': roomName,
      'metadata': metadata,
      'custom_data': customData,
    },
    onSuccess: onSuccess,
    onError: onError,
  );

  Future<RevaniResponse<void>> updateParticipant({
    required String roomName,
    required String userID,
    required UpdateParticipantRequest request,
    SuccessCallback<void>? onSuccess,
    ErrorCallback<void>? onError,
  }) => _client.execute<void>(
    {
      'cmd': 'livekit/update-participant',
      'roomName': roomName,
      'userID': userID,
      ...request.toMap(),
    },
    onSuccess: onSuccess,
    onError: onError,
  );

  Future<RevaniResponse<void>> muteParticipant({
    required String roomName,
    required String userID,
    required String trackSid,
    required bool muted,
    Map<String, dynamic> customData = const {},
    SuccessCallback<void>? onSuccess,
    ErrorCallback<void>? onError,
  }) => _client.execute<void>(
    {
      'cmd': 'livekit/mute-participant',
      'roomName': roomName,
      'userID': userID,
      'trackSid': trackSid,
      'muted': muted,
      'custom_data': customData,
    },
    onSuccess: onSuccess,
    onError: onError,
  );

  Future<RevaniResponse<List<LivekitParticipant>>> listParticipants({
    required String roomName,
    SuccessCallback<List<LivekitParticipant>>? onSuccess,
    ErrorCallback<List<LivekitParticipant>>? onError,
  }) => _client.execute<List<LivekitParticipant>>(
    {'cmd': 'livekit/list-participants', 'roomName': roomName},
    onSuccess: onSuccess,
    onError: onError,
    parser: (data) {
      final list = data['participants'] as List;
      return list.map((e) => LivekitParticipant.fromMap(e)).toList();
    },
  );
}

class RevaniPubSub {
  final RevaniClient _client;
  RevaniPubSub(this._client);

  Future<RevaniResponse<Map<String, dynamic>>> subscribe({
    required PubSubSubscribeRequest request,
    SuccessCallback<Map<String, dynamic>>? onSuccess,
    ErrorCallback<Map<String, dynamic>>? onError,
  }) => _client.execute<Map<String, dynamic>>(
    {
      'cmd': 'pubsub/subscribe',
      'accountID': _client.accountID,
      'projectName': _client.projectName,
      ...request.toMap(),
    },
    onSuccess: onSuccess,
    onError: onError,
    parser: (data) => Map<String, dynamic>.from(data),
  );

  Future<RevaniResponse<void>> publish({
    required PubSubPublishRequest request,
    SuccessCallback<void>? onSuccess,
    ErrorCallback<void>? onError,
  }) => _client.execute<void>(
    {
      'cmd': 'pubsub/publish',
      'accountID': _client.accountID,
      'projectName': _client.projectName,
      ...request.toMap(),
    },
    onSuccess: onSuccess,
    onError: onError,
  );

  Future<RevaniResponse<void>> unsubscribe({
    required String topic,
    required String clientId,
    Map<String, dynamic> customData = const {},
    SuccessCallback<void>? onSuccess,
    ErrorCallback<void>? onError,
  }) => _client.execute<void>(
    {
      'cmd': 'pubsub/unsubscribe',
      'clientId': clientId,
      'topic': topic,
      'custom_data': customData,
    },
    onSuccess: onSuccess,
    onError: onError,
  );
}

class RevaniStorage {
  final RevaniClient _client;

  RevaniStorage(this._client);

  Future<RevaniResponse<Map<String, dynamic>>> upload({
    required File file,
    String? fileName,
    Map<String, dynamic> customData = const {},
    SuccessCallback<Map<String, dynamic>>? onSuccess,
    ErrorCallback<Map<String, dynamic>>? onError,
  }) async {
    try {
      if (!file.existsSync()) {
        final res = RevaniResponse<Map<String, dynamic>>.networkError(
          "File not found locally",
        );
        onError?.call(res);
        return res;
      }

      final stream = file.openRead();
      final length = await file.length();
      final name = fileName ?? p.basename(file.path);

      final url = Uri.parse("${_client.httpBaseUrl}/upload");
      final request = http.StreamedRequest("POST", url);

      request.headers['x-account-id'] = _client.accountID;
      request.headers['x-project-name'] = _client.projectName;
      request.headers['x-session-token'] = _client.token;
      request.headers['x-file-name'] = name;
      request.headers['x-custom-data'] = jsonEncode(customData);
      request.headers['content-type'] = 'application/octet-stream';
      request.contentLength = length;

      stream.listen(
        (chunk) => request.sink.add(chunk),
        onDone: () => request.sink.close(),
        onError: (e) {
          request.sink.addError(e);
          request.sink.close();
        },
        cancelOnError: true,
      );

      final streamedResponse = await request.send();
      final responseString = await streamedResponse.stream.bytesToString();
      final jsonResponse = jsonDecode(responseString);
      final res = RevaniResponse.fromMap<Map<String, dynamic>>(
        jsonResponse,
        (data) => Map<String, dynamic>.from(data),
      );

      if (res.isSuccess) {
        onSuccess?.call(res);
      } else {
        onError?.call(res);
      }
      return res;
    } catch (e) {
      final res = RevaniResponse<Map<String, dynamic>>.networkError(
        e.toString(),
      );
      onError?.call(res);
      return res;
    }
  }

  String getImage(String fileID) {
    return "${_client.httpBaseUrl}/file/${_client.projectID}/$fileID";
  }

  Future<void> downloadToFile({
    required String projectID,
    required String fileId,
    required String savePath,
    SuccessCallback<Map<String, dynamic>>? onSuccess,
    ErrorCallback<Map<String, dynamic>>? onError,
  }) async {
    try {
      final url = Uri.parse("${_client.httpBaseUrl}/file/$projectID/$fileId");

      final request = http.Request('GET', url);
      final response = await _client._httpClient.send(request);

      if (response.statusCode == 200) {
        final file = File(savePath);
        final sink = file.openWrite();

        await response.stream.pipe(sink);
        await sink.flush();
        await sink.close();

        final res = RevaniResponse<Map<String, dynamic>>(
          status: 200,
          message: "File downloaded to $savePath",
          data: {"path": savePath},
        );
        onSuccess?.call(res);
      } else {
        final res = RevaniResponse<Map<String, dynamic>>(
          status: response.statusCode,
          message: "Download Failed",
          error: response.reasonPhrase,
        );
        onError?.call(res);
      }
    } catch (e) {
      final res = RevaniResponse<Map<String, dynamic>>.networkError(
        e.toString(),
      );
      onError?.call(res);
    }
  }

  Future<RevaniResponse<void>> delete({
    required String fileId,
    Map<String, dynamic> customData = const {},
    SuccessCallback<void>? onSuccess,
    ErrorCallback<void>? onError,
  }) => _client.execute<void>(
    {
      'cmd': 'storage/delete',
      'accountID': _client.accountID,
      'projectName': _client.projectName,
      'fileId': fileId,
      'custom_data': customData,
    },
    onSuccess: onSuccess,
    onError: onError,
  );
}
