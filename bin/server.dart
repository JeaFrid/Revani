import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:revani/core/database_engine.dart';
import 'package:revani/services/dispatcher.dart';
import 'package:revani/core/rate_limiter.dart';
import 'package:revani/tools/tokener.dart';
import 'package:revani/config.dart';
import 'package:revani/schema/data_schema.dart';
import 'package:dotenv/dotenv.dart';
import 'package:uuid/uuid.dart';

void main(List<String> args) async {
  print('\n[o] Preheating the digital oven...');
  var env = DotEnv();
  if (File('.env').existsSync()) {
    env.load(['.env']);
    print('[*] Special spices mixed in.');
  } else {
    print('[!] OVEN ERROR: Missing recipe card. Kitchen stopping.');
    exit(1);
  }
  final db = RevaniDatabase();
  final persistence = RevaniPersistence(db, RevaniConfig.dbPath);
  print('[@] Greasing the baking pans...');
  await persistence.init();
  _startMaintenanceLoop(persistence);
  final rateLimitReceivePort = ReceivePort();
  await Isolate.spawn(RateLimitActor.start, rateLimitReceivePort.sendPort);
  final SendPort rateLimitSendPort = await rateLimitReceivePort.first;
  final rateLimiterClient = RateLimiterClient(rateLimitSendPort);
  print('[~] Dough proofer is warm and running.');
  final dbServer = RequestDispatcher(db, rateLimiter: rateLimiterClient);
  dbServer.rebuildAllIndices();
  final mainReceivePort = ReceivePort();
  final restHandler = const Pipeline()
      .addMiddleware(logRequests())
      .addHandler((Request request) => _handleRestRequests(request, dbServer));
  final restPort = RevaniConfig.port + 1;
  final restServer = await shelf_io.serve(
    restHandler,
    '0.0.0.0',
    restPort,
    shared: true,
  );
  print('[+] HTTP Side-Kitchen is open on port $restPort');
  final workersCount = RevaniConfig.workerCount;
  print('[&] Waking up $workersCount pastry chefs...');
  for (int i = 0; i < workersCount; i++) {
    await Isolate.spawn(_startWorker, [
      mainReceivePort.sendPort,
      rateLimitSendPort,
    ]);
  }
  print(
    '[^] Fresh batches ready! Bakery is open for business on port ${RevaniConfig.port}.\n',
  );
  await for (final message in mainReceivePort) {
    if (message is List && message.length >= 2) {
      final SendPort replyPort = message[0];
      final Map<String, dynamic> request = message[1];
      final String type = request['__type'] ?? 'db';
      try {
        if (type == 'auth_verify') {
          final email = request['email'];
          final password = request['password'];
          final check = await dbServer.processCommand({
            'cmd': 'account/get-id',
            'email': email,
            'password': password,
          });
          replyPort.send(check);
        } else {
          dbServer.processCommand(request).then((response) {
            replyPort.send(response);
          });
        }
      } catch (e) {
        replyPort.send({
          'status': 500,
          'message': 'Main Isolate Error',
          'error': e.toString(),
        });
      }
    } else if (message is String) {
      print(message);
    }
  }
  ProcessSignal.sigint.watch().listen((_) async {
    print('\n[x] Shop closed. Cleaning the flour...');
    await restServer.close();
    await persistence.close();
    exit(0);
  });
}

Future<Response> _handleRestRequests(
  Request request,
  RequestDispatcher dispatcher,
) async {
  final path = request.url.path;
  if (path == '') {
    return Response.ok(
      '<h1>🍰 Revani Database</h1><p>The oven is on and smells wonderful. Developed for humanity by JeaFriday!</p>',
      headers: {'content-type': 'text/html; charset=utf-8'},
    );
  }
  if (path == 'health') {
    return Response.ok(
      jsonEncode({
        'status': 'up',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'engine': 'Revani Database',
      }),
      headers: {'content-type': 'application/json'},
    );
  }
  if (path == 'stats') {
    final stats = dispatcher.db.stats();
    return Response.ok(
      jsonEncode(stats),
      headers: {'content-type': 'application/json'},
    );
  }
  if (request.method == 'GET' && path.startsWith('file/')) {
    try {
      final sessionToken = request.headers['x-session-token'];
      if (sessionToken == null) {
        return Response.forbidden(
          jsonEncode({'error': 'Authentication Required'}),
        );
      }

      final sessionRes = await dispatcher.sessionSchema.verifyToken(
        sessionToken,
      );
      if (sessionRes.status?.code != 200) {
        return Response.unauthorized(jsonEncode({'error': 'Invalid Session'}));
      }

      final parts = path.split('/');
      if (parts.length < 3) return Response.notFound('Invalid path');
      final projectID = parts[1];
      final fileId = parts[2];

      final accountID = sessionRes.data['user_id'];
      if (!(await dispatcher.projectSchema.isOwner(accountID, projectID))) {
        return Response.forbidden(
          jsonEncode({'error': 'Access Denied to this Project'}),
        );
      }

      final bytes = await dispatcher.storageSchema.core.readFile(
        projectID,
        fileId,
      );
      if (bytes == null) return Response.notFound('File not found');
      return Response.ok(
        bytes,
        headers: {
          'content-type': 'application/octet-stream',
          'cache-control': 'public, max-age=31536000',
          'access-control-allow-origin': '*',
        },
      );
    } catch (e) {
      return Response.internalServerError(body: 'File Error');
    }
  }
  if (request.method == 'POST' && path == 'upload') {
    try {
      final accountID = request.headers['x-account-id'];
      final projectName = request.headers['x-project-name'];
      final fileName = request.headers['x-file-name'] ?? 'upload.bin';
      if (accountID == null || projectName == null) {
        return Response.forbidden(
          jsonEncode({'error': 'Missing Auth Headers'}),
          headers: {'content-type': 'application/json'},
        );
      }
      final builder = BytesBuilder();
      await for (final chunk in request.read()) {
        builder.add(chunk);
      }
      final bytes = builder.takeBytes();
      if (bytes.isEmpty) {
        return Response.badRequest(
          body: jsonEncode({'error': 'Empty body'}),
          headers: {'content-type': 'application/json'},
        );
      }
      final res = await dispatcher.storageSchema.uploadFile(
        accountID,
        projectName,
        fileName,
        bytes,
        compressImage: true,
      );
      return Response.ok(
        jsonEncode(res.toJson()),
        headers: {
          'content-type': 'application/json',
          'access-control-allow-origin': '*',
        },
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': e.toString()}),
        headers: {'content-type': 'application/json'},
      );
    }
  }

  return Response.notFound(
    jsonEncode({'error': 'Endpoint not found'}),
    headers: {'content-type': 'application/json'},
  );
}

void _startWorker(List<dynamic> args) async {
  final SendPort mainSendPort = args[0];
  final SendPort rateLimitSendPort = args[1];
  final rateLimiter = RateLimiterClient(rateLimitSendPort);
  try {
    var env = DotEnv();
    if (File('.env').existsSync()) {
      env.load(['.env']);
    }
    final db = RevaniDatabase();
    final tokener = JeaTokener();
    final dbServer = RequestDispatcher(db);
    SecurityContext? securityContext;
    if (RevaniConfig.sslEnabled) {
      if (!File(RevaniConfig.certPath).existsSync() ||
          !File(RevaniConfig.keyPath).existsSync()) {
        mainSendPort.send(
          '[!] MISSING INGREDIENT: SSL Certificates (crt/key) not found.',
        );
        return;
      }
      securityContext = SecurityContext.defaultContext;
      securityContext.useCertificateChain(RevaniConfig.certPath);
      securityContext.usePrivateKey(RevaniConfig.keyPath);
    }

    Stream<Socket> server;
    if (RevaniConfig.sslEnabled) {
      server = await SecureServerSocket.bind(
        RevaniConfig.host,
        RevaniConfig.port,
        securityContext!,
        shared: true,
      );
    } else {
      server = await ServerSocket.bind(
        RevaniConfig.host,
        RevaniConfig.port,
        shared: true,
      );
    }

    server.listen((Socket client) {
      _handleTcpConnection(
        client,
        mainSendPort,
        rateLimiter,
        dbServer,
        tokener,
      );
    });
    mainSendPort.send(
      '[&] Chef #${Isolate.current.hashCode} serving sweets on table ${RevaniConfig.port}',
    );
  } catch (e, stack) {
    mainSendPort.send('[!] Burnt batch! Chef error: $e\n$stack');
  }
}

void _handleTcpConnection(
  Socket client,
  SendPort mainSendPort,
  RateLimiterClient rateLimiter,
  RequestDispatcher dbServer,
  JeaTokener tokener,
) async {
  final clientIp = client.remoteAddress.address;
  try {
    final initialCheck = await rateLimiter.check(
      clientIp,
      RateLimiterType.connection,
    );
    if (!initialCheck.isAllowed) {
      client.destroy();
      return;
    }
  } catch (e) {}
  final buffer = BytesBuilder(copy: false);
  int? expectedLength;
  String? sessionKey;
  String? sessionOwnerID;
  final uuid = Uuid();
  client.listen(
    (Uint8List data) async {
      buffer.add(data);
      while (true) {
        if (expectedLength == null) {
          if (buffer.length >= 4) {
            final bytes = buffer.toBytes();
            final headerData = ByteData.sublistView(bytes, 0, 4);
            expectedLength = headerData.getUint32(0);
            if (expectedLength! > 10 * 1024 * 1024) {
              client.destroy();
              return;
            }
            final remaining = bytes.sublist(4);
            buffer.clear();
            buffer.add(remaining);
          } else {
            break;
          }
        }
        if (expectedLength != null) {
          if (buffer.length >= expectedLength!) {
            final bytes = buffer.toBytes();
            final payload = bytes.sublist(0, expectedLength!);
            final remaining = bytes.sublist(expectedLength!);
            buffer.clear();
            buffer.add(remaining);
            expectedLength = null;
            try {
              final requestString = utf8.decode(payload);
              Map<String, dynamic> requestData = jsonDecode(requestString);
              RateLimiterType? businessType;
              final cmd = requestData['cmd'] as String?;
              if (cmd != null) {
                if (cmd.startsWith('auth/') || cmd.startsWith('account/')) {
                  businessType = RateLimiterType.account;
                } else if (cmd.startsWith('project/')) {
                  businessType = RateLimiterType.project;
                } else if (cmd.startsWith('data/')) {
                  businessType = RateLimiterType.data;
                }
              }
              final ipLimit = await rateLimiter.check(
                clientIp,
                businessType ?? RateLimiterType.data,
              );
              if (!ipLimit.isAllowed) {
                if (sessionKey == null) {
                  _sendPlainData(client, {
                    'status': ipLimit.status,
                    'message': ipLimit.message,
                    'error': ipLimit.error,
                  });
                } else {
                  _sendEncryptedError(
                    client,
                    tokener,
                    sessionKey!,
                    ipLimit.message,
                  );
                }
                return;
              }
              if (sessionKey == null) {
                if (requestData['cmd'] == 'auth/login') {
                  final responsePort = ReceivePort();
                  requestData['__type'] = 'auth_verify';
                  mainSendPort.send([responsePort.sendPort, requestData]);
                  final response =
                      await responsePort.first as Map<String, dynamic>;
                  responsePort.close();
                  if (response['status'] == 200) {
                    sessionKey = uuid.v4() + uuid.v4();
                    if (response['data'] != null &&
                        response['data']['id'] != null) {
                      sessionOwnerID = response['data']['id'];
                    }
                    _sendPlainData(client, {
                      'status': 200,
                      'message': 'Session established',
                      'data': {'session_key': sessionKey, 'id': sessionOwnerID},
                    });
                  } else {
                    _sendPlainData(client, response);
                  }
                } else if (requestData['cmd'] == 'account/create') {
                  final responsePort = ReceivePort();
                  mainSendPort.send([responsePort.sendPort, requestData]);
                  final response =
                      await responsePort.first as Map<String, dynamic>;
                  responsePort.close();
                  _sendPlainData(client, response);
                } else {
                  _sendPlainData(client, {
                    'status': 403,
                    'message': 'Handshake required',
                  });
                }
              } else {
                if (requestData['encrypted'] != null) {
                  try {
                    final decrypted = tokener.decryptSession(
                      requestData['encrypted'],
                      sessionKey!,
                    );
                    final Map<String, dynamic> decryptedRequest = jsonDecode(
                      decrypted,
                    );
                    final accountID = decryptedRequest['accountID'];
                    if (accountID != null &&
                        sessionOwnerID != null &&
                        accountID != sessionOwnerID) {
                      _sendEncryptedError(
                        client,
                        tokener,
                        sessionKey!,
                        "Identity Mismatch",
                      );
                      return;
                    }
                    String? userRole;
                    if (accountID != null) {
                      final accSchema = DataSchemaAccount(dbServer.db, tokener);
                      userRole = await accSchema.getAccountRole(accountID);
                    }
                    final accountLimit = await rateLimiter.check(
                      accountID ?? clientIp,
                      businessType ?? RateLimiterType.data,
                      role: userRole,
                    );
                    if (!accountLimit.isAllowed) {
                      _sendEncryptedError(
                        client,
                        tokener,
                        sessionKey!,
                        accountLimit.message,
                      );
                      return;
                    }
                    await _processRequest(
                      client,
                      mainSendPort,
                      tokener,
                      decryptedRequest,
                      sessionKey!,
                    );
                  } catch (e) {
                    _sendEncryptedError(
                      client,
                      tokener,
                      sessionKey!,
                      "Decryption Failed: $e",
                    );
                  }
                } else {
                  _sendEncryptedError(
                    client,
                    tokener,
                    sessionKey!,
                    "Encryption Expected",
                  );
                }
              }
            } catch (e) {
              if (sessionKey != null) {
                _sendEncryptedError(
                  client,
                  tokener,
                  sessionKey!,
                  "Packet Error",
                );
              } else {
                _sendPlainData(client, {
                  'status': 500,
                  'message': 'Packet Error',
                });
              }
            }
          } else {
            break;
          }
        }
      }
    },
    onError: (e) => client.close(),
    onDone: () => client.close(),
  );
}

Future<void> _processRequest(
  Socket client,
  SendPort mainSendPort,
  JeaTokener tokener,
  Map<String, dynamic> req,
  String key,
) async {
  try {
    if (req['cmd'] == 'data/add' && req['value'] != null) {
      req['raw_value'] = RevaniBson.encodeTransferable(req['value']);
      req.remove('value');
    }
    final responsePort = ReceivePort();
    mainSendPort.send([responsePort.sendPort, req]);
    final responseMap = await responsePort.first as Map<String, dynamic>;
    responsePort.close();
    _sendEncryptedData(client, tokener, key, responseMap);
  } catch (e) {
    _sendEncryptedError(client, tokener, key, "Internal Error");
  }
}

void _sendPlainData(Socket client, Map<String, dynamic> data) {
  try {
    final jsonString = jsonEncode(data);
    final responseBytes = utf8.encode(jsonString);
    final header = ByteData(4)..setUint32(0, responseBytes.length);
    client.add(header.buffer.asUint8List());
    client.add(responseBytes);
  } catch (e) {}
}

void _sendEncryptedData(
  Socket client,
  JeaTokener tokener,
  String key,
  Map<String, dynamic> data,
) {
  try {
    final jsonString = jsonEncode(data);
    final encryptedString = tokener.encryptSession(jsonString, key);
    final envelope = jsonEncode({'encrypted': encryptedString});
    final responseBytes = utf8.encode(envelope);
    final header = ByteData(4)..setUint32(0, responseBytes.length);
    client.add(header.buffer.asUint8List());
    client.add(responseBytes);
  } catch (e) {}
}

void _sendEncryptedError(
  Socket client,
  JeaTokener tokener,
  String key,
  String msg,
) {
  _sendEncryptedData(client, tokener, key, {
    'status': 500,
    'message': msg,
    'error': 'Server Error',
  });
}

void _startMaintenanceLoop(RevaniPersistence persistence) {
  Timer.periodic(RevaniConfig.compactionInterval, (_) => persistence.compact());
}
