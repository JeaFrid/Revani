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
import 'package:dotenv/dotenv.dart';
import 'package:uuid/uuid.dart';

void main(List<String> args) async {
  try {
    print('[*] Revani is preparing the kitchen environment...');

    var env = DotEnv();
    if (File('.env').existsSync()) {
      env.load(['.env']);
      print('[+] Secret ingredients gathered from .env file.');
    } else {
      print(
        '[!] Critical: Chef cannot find the recipe (.env file is missing).',
      );
      exit(1);
    }

    final db = RevaniDatabase();
    final persistence = RevaniPersistence(db, RevaniConfig.dbPath);

    print('[*] Preheating the persistence oven at: ${RevaniConfig.dbPath}');
    await persistence.init().catchError((e) {
      print('[!] Oven failure during initialization: $e');
      exit(1);
    });

    startMaintenanceLoop(persistence);
    print('[+] Floor sweeping cycle (Maintenance) is now active.');

    final rateLimitReceivePort = ReceivePort();
    await Isolate.spawn(
      RateLimitActor.start,
      rateLimitReceivePort.sendPort,
    ).catchError((e) {
      print('[!] Failed to hire the floor manager (Rate Limiter): $e');
    });

    final SendPort rateLimitSendPort = await rateLimitReceivePort.first;
    final rateLimiterClient = RateLimiterClient(rateLimitSendPort);
    print('[+] Floor manager is at the door for crowd control.');

    final dbServer = RequestDispatcher(db, rateLimiter: rateLimiterClient);
    print('[*] Sorting ingredient jars (Rebuilding indices)...');
    dbServer.rebuildAllIndices();

    final mainReceivePort = ReceivePort();

    final restHandler = const Pipeline()
        .addMiddleware(logRequests())
        .addHandler(
          (Request request) => _handleRestRequests(request, dbServer),
        );

    final restPort = RevaniConfig.port + 1;
    final restServer = await shelf_io
        .serve(restHandler, InternetAddress.anyIPv4, restPort, shared: true)
        .catchError((e) {
          print('[!] Side-kitchen could not be opened: $e');
        });

    print('[+] Side-kitchen is open for fast delivery on port: $restPort');

    final workersCount = RevaniConfig.workerCount;
    print('[*] Assigning $workersCount pastry chefs to their stations.');

    for (int i = 0; i < workersCount; i++) {
      await Isolate.spawn(_startWorker, [
        mainReceivePort.sendPort,
        rateLimitSendPort,
      ]).catchError((e) {
        print('[!] A chef had an accident while entering the kitchen: $e');
      });
    }

    print('[!] Revani is now live and serving delicious data!');
    print(
      '[!] Main counter active at: ${InternetAddress.anyIPv4.address}:${RevaniConfig.port}',
    );
    print(
      '[!] Security Mode: ${RevaniConfig.sslEnabled ? "Silk Apron (SSL On)" : "Basic Apron (SSL Off)"}',
    );

    await for (final message in mainReceivePort) {
      if (message is List && message.length >= 2) {
        final SendPort replyPort = message[0];
        final Map<String, dynamic> request = message[1];
        final String type = request['__type'] ?? 'db';

        try {
          if (type == 'auth_verify') {
            final check = await dbServer.processCommand({
              'cmd': 'account/get-id',
              'email': request['email'],
              'password': request['password'],
            });
            replyPort.send(check);
          } else {
            dbServer
                .processCommand(request)
                .then((response) {
                  replyPort.send(response);
                })
                .catchError((e) {
                  print('[!] Order processing error: $e');
                  replyPort.send({'status': 500, 'error': 'Order Failed'});
                });
          }
        } catch (e) {
          print('[!] Kitchen accident during request: $e');
          replyPort.send({
            'status': 500,
            'message': 'Internal Chef Error',
            'error': e.toString(),
          });
        }
      }
    }

    ProcessSignal.sigint.watch().listen((_) async {
      print('\n[!] Closing the shop... Saving recipes and cleaning counters.');
      await restServer.close();
      await persistence.close();
      print('[!] Bakery closed. See you in the next shift!');
      exit(0);
    });
  } catch (e, stackTrace) {
    print('[!!] Unrecoverable disaster in the kitchen: $e');
    print(stackTrace);
    exit(1);
  }
}

Future<Response> _handleRestRequests(
  Request request,
  RequestDispatcher dispatcher,
) async {
  try {
    final path = request.url.path;

    if (request.method == 'POST' && path == 'upload') {
      final accountID = request.headers['x-account-id'];
      final projectName = request.headers['x-project-name'];
      final fileName = request.headers['x-file-name'] ?? 'unnamed_batch';
      final sessionToken = request.headers['x-session-token'];

      if (accountID == null || projectName == null || sessionToken == null) {
        return Response.forbidden(
          jsonEncode({'error': 'Missing pantry headers'}),
        );
      }

      final sessionRes = await dispatcher.sessionSchema.verifyToken(
        sessionToken,
      );
      if (sessionRes.status?.code != 200 ||
          sessionRes.data['user_id'] != accountID) {
        return Response.unauthorized(
          jsonEncode({'error': 'Health Inspector Alert: Identity Mismatch'}),
        );
      }

      final projectID = await dispatcher.storageSchema.resolveProjectID(
        accountID,
        projectName,
      );

      if (projectID == null) {
        return Response.notFound(jsonEncode({'error': 'Project not found'}));
      }

      final fileId = const Uuid().v4();
      final fileHandle = dispatcher.storageSchema.core.getFileHandle(
        projectID,
        fileId,
      );
      final sink = fileHandle.openWrite();

      try {
        await request.read().pipe(sink);
      } catch (e) {
        await sink.close();
        if (await fileHandle.exists()) await fileHandle.delete();
        return Response.internalServerError(body: 'Upload pipe broken');
      }

      final fileSize = await fileHandle.length();
      final res = await dispatcher.storageSchema.registerUploadedFile(
        accountID,
        projectID,
        fileId,
        fileName,
        fileSize,
        compressImage: false,
      );

      return Response(
        res.status?.code ?? 200,
        body: jsonEncode(res.toJson()),
        headers: {'content-type': 'application/json'},
      );
    }

    if (request.method == 'GET' && path.startsWith('file/')) {
      final sessionToken = request.headers['x-session-token'];
      if (sessionToken == null) {
        return Response.forbidden('No entry to the storage allowed');
      }

      final sessionRes = await dispatcher.sessionSchema.verifyToken(
        sessionToken,
      );
      if (sessionRes.status?.code != 200) {
        return Response.unauthorized('Stale session');
      }

      final parts = path.split('/');
      if (parts.length < 3) return Response.notFound('Wrong table number');

      final projectIdentifier = parts[1];
      final fileId = parts[2];
      final accountID = sessionRes.data['user_id'];

      final pathRes = await dispatcher.storageSchema.getFilePath(
        accountID,
        projectIdentifier,
        fileId,
      );

      if (pathRes.status?.code != 200) {
        return Response.notFound('Ingredient not found');
      }

      final file = File(pathRes.data['path']);
      if (!await file.exists()) {
        return Response.notFound('Empty jar');
      }

      return Response.ok(
        file.openRead(),
        headers: {
          'content-type': 'application/octet-stream',
          'content-length': (await file.length()).toString(),
        },
      );
    }
  } catch (e) {
    print('[!] Side-kitchen request error: $e');
    return Response.internalServerError(body: 'Kitchen Error');
  }
  return Response.notFound(jsonEncode({'error': 'Menu item not found'}));
}

void _startWorker(List<dynamic> args) async {
  final SendPort mainSendPort = args[0];
  final SendPort rateLimitSendPort = args[1];
  final rateLimiter = RateLimiterClient(rateLimitSendPort);

  try {
    final db = RevaniDatabase();
    final tokener = JeaTokener();
    final dbServer = RequestDispatcher(db);
    dbServer.rebuildAllIndices();

    SecurityContext? securityContext;
    if (RevaniConfig.sslEnabled) {
      securityContext = SecurityContext.defaultContext;
      securityContext.useCertificateChain(RevaniConfig.certPath);
      securityContext.usePrivateKey(RevaniConfig.keyPath);
    }

    final Stream<Socket> server = RevaniConfig.sslEnabled
        ? await SecureServerSocket.bind(
            InternetAddress.anyIPv4,
            RevaniConfig.port,
            securityContext!,
            shared: true,
          )
        : await ServerSocket.bind(
            InternetAddress.anyIPv4,
            RevaniConfig.port,
            shared: true,
          );

    server.listen((Socket client) {
      _handleTcpConnection(
        client,
        mainSendPort,
        rateLimiter,
        dbServer,
        tokener,
      );
    }, onError: (e) => print('[!] Master counter socket error: $e'));
  } catch (e) {
    print('[!] Chef worker station failure: $e');
    mainSendPort.send(e.toString());
  }
}

void _handleTcpConnection(
  Socket client,
  SendPort mainSendPort,
  RateLimiterClient rateLimiter,
  RequestDispatcher dbServer,
  JeaTokener tokener,
) async {
  final List<int> buffer = [];
  int? expectedLength;
  String? sessionKey;
  String? sessionOwnerID;
  final uuid = Uuid();
  const int maxPayloadSize = 10 * 1024 * 1024;

  client.listen(
    (Uint8List data) async {
      try {
        if (buffer.length + data.length > maxPayloadSize + 4) {
          _sendPlainData(client, {
            'status': 413,
            'message': 'Too much dough for one tray',
          });
          client.close();
          return;
        }

        buffer.addAll(data);
        while (true) {
          if (expectedLength == null) {
            if (buffer.length >= 4) {
              final headerData = ByteData.sublistView(
                Uint8List.fromList(buffer.sublist(0, 4)),
              );
              expectedLength = headerData.getUint32(0);
              buffer.removeRange(0, 4);

              if (expectedLength! > maxPayloadSize) {
                _sendPlainData(client, {
                  'status': 413,
                  'message': 'Batch size too large',
                });
                client.close();
                return;
              }
            } else {
              break;
            }
          }

          if (expectedLength != null && buffer.length >= expectedLength!) {
            final payload = Uint8List.fromList(
              buffer.sublist(0, expectedLength!),
            );
            buffer.removeRange(0, expectedLength!);
            expectedLength = null;

            final requestString = utf8.decode(payload);
            Map<String, dynamic> requestData = jsonDecode(requestString);

            if (requestData['cmd'] == 'health') {
              _sendPlainData(client, {
                'status': 200,
                'message': 'Bakery is operational',
                'data': {'ts': DateTime.now().millisecondsSinceEpoch},
              });
              continue;
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
                  sessionOwnerID = response['data']['id'];
                  _sendPlainData(client, {
                    'status': 200,
                    'message': 'Table reserved successfully',
                    'data': {
                      'session_key': sessionKey,
                      'id': sessionOwnerID,
                      'token': response['data']['token'],
                    },
                  });
                } else {
                  _sendPlainData(client, response);
                }
              }
            } else {
              if (requestData['encrypted'] != null) {
                final decrypted = tokener.decryptSession(
                  requestData['encrypted'],
                  sessionKey!,
                );
                final decryptedRequest =
                    jsonDecode(decrypted) as Map<String, dynamic>;

                if (decryptedRequest['accountID'] != null &&
                    decryptedRequest['accountID'] != sessionOwnerID) {
                  _sendEncryptedData(client, tokener, sessionKey!, {
                    'status': 403,
                    'message': 'Tray Hijacking Attempted',
                    'error': 'Forbidden',
                  });
                  continue;
                }

                await _processRequest(
                  client,
                  mainSendPort,
                  tokener,
                  decryptedRequest,
                  sessionKey!,
                );
              }
            }
          } else {
            break;
          }
        }
      } catch (e) {
        print('[!] Protocol error during connection: $e');
        _sendPlainData(client, {
          'status': 500,
          'message': 'Recipe parsing error',
        });
      }
    },
    onError: (e) {
      print('[!] Connection lost unexpectedly: $e');
      client.close();
    },
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
    final responsePort = ReceivePort();
    mainSendPort.send([responsePort.sendPort, req]);
    final responseMap = await responsePort.first as Map<String, dynamic>;
    responsePort.close();
    _sendEncryptedData(client, tokener, key, responseMap);
  } catch (e) {
    print('[!] Chef failed to prepare a specific dish: $e');
  }
}

void _sendPlainData(Socket client, Map<String, dynamic> data) {
  try {
    final responseBytes = utf8.encode(jsonEncode(data));
    final header = ByteData(4)..setUint32(0, responseBytes.length);
    client.add(header.buffer.asUint8List());
    client.add(responseBytes);
  } catch (e) {
    print('[!] Error sending plain delivery: $e');
  }
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
    final responseBytes = utf8.encode(
      jsonEncode({'encrypted': encryptedString}),
    );
    final header = ByteData(4)..setUint32(0, responseBytes.length);
    client.add(header.buffer.asUint8List());
    client.add(responseBytes);
  } catch (e) {
    print('[!] Error sending armored delivery: $e');
  }
}

void startMaintenanceLoop(RevaniPersistence persistence) {
  Timer.periodic(RevaniConfig.compactionInterval, (timer) {
    print('[*] Compacting the pastry shop database to save space...');
    persistence.compact().catchError(
      (e) => print('[!] Maintenance failure: $e'),
    );
  });
}
