import 'dart:async';
import 'dart:isolate';
import 'package:revani/config.dart';

enum RateLimiterType { data, account, project, connection }

class _RateLimitRequest {
  final SendPort replyPort;
  final String identifier;
  final RateLimiterType type;
  final String? role;

  _RateLimitRequest(this.replyPort, this.identifier, this.type, {this.role});
}

class RateLimitResponse {
  final bool isAllowed;
  final String? error;
  final int status;
  final String message;

  RateLimitResponse({
    required this.isAllowed,
    this.error,
    this.status = 200,
    this.message = 'OK',
  });
}

class RateLimiterClient {
  final SendPort _actorPort;

  RateLimiterClient(this._actorPort);

  Future<RateLimitResponse> check(
    String identifier,
    RateLimiterType type, {
    String? role,
  }) async {
    final responsePort = ReceivePort();
    _actorPort.send(
      _RateLimitRequest(responsePort.sendPort, identifier, type, role: role),
    );
    final response = await responsePort.first as RateLimitResponse;
    responsePort.close();
    return response;
  }
}

class RateLimitActor {
  static void start(SendPort sendPort) {
    final receivePort = ReceivePort();
    sendPort.send(receivePort.sendPort);

    final limiter = _RateLimitLogic();

    Timer.periodic(
      const Duration(minutes: 5),
      (_) => limiter.performMaintenance(),
    );

    receivePort.listen((message) {
      if (message is _RateLimitRequest) {
        final result = limiter.process(
          message.identifier,
          message.type,
          role: message.role,
        );
        message.replyPort.send(result);
      }
    });
  }
}

class _RateLimitLogic {
  final Map<String, DateTime> _blacklistedIdentifiers = {};
  final Map<String, int> _violationHistory = {};
  final Map<String, int> _requestCounts = {};
  final Map<String, DateTime> _windowStarts = {};

  static const int _windowDurationSeconds = 60;

  _RateLimitLogic();

  RateLimitResponse process(
    String identifier,
    RateLimiterType type, {
    String? role,
  }) {
    if (_isBanned(identifier)) {
      final releaseTime = _blacklistedIdentifiers[identifier];
      return RateLimitResponse(
        isAllowed: false,
        error: 'RateLimitBan',
        status: 403,
        message: 'Banned until $releaseTime',
      );
    }

    final String key = '$identifier:${type.name}';
    int limit;

    if (role != null) {
      final config =
          RevaniConfig.roleConfigs[role] ?? RevaniConfig.roleConfigs['user']!;
      limit = config.requestsPerMinute;
    } else {
      limit = RevaniConfig.limits[type.name] ?? 60;
    }

    final suspiciousThreshold = (limit * 0.8).toInt();
    final requestCount = _incrementAndGetCount(key);

    if (requestCount >= limit) {
      _executeBan(identifier, key, 300);
      return RateLimitResponse(
        isAllowed: false,
        error: 'RateLimitBan',
        status: 403,
        message: 'Limit exceeded for ${role ?? "IP Address"}.',
      );
    }

    if (requestCount > suspiciousThreshold) {
      return RateLimitResponse(
        isAllowed: false,
        error: 'RateLimitExceeded',
        status: 429,
        message: 'Requesting too fast.',
      );
    }

    return RateLimitResponse(isAllowed: true);
  }

  int _incrementAndGetCount(String key) {
    final now = DateTime.now();
    if (!_windowStarts.containsKey(key) ||
        now.difference(_windowStarts[key]!).inSeconds >=
            _windowDurationSeconds) {
      _windowStarts[key] = now;
      _requestCounts[key] = 0;
    }
    _requestCounts[key] = (_requestCounts[key] ?? 0) + 1;
    return _requestCounts[key]!;
  }

  void _executeBan(String identifier, String key, int baseDuration) {
    final previousViolations = _violationHistory[identifier] ?? 0;
    final currentViolationCount = previousViolations + 1;
    _violationHistory[identifier] = currentViolationCount;

    final multiplier = 1 << (currentViolationCount - 1);
    final durationSeconds = baseDuration * multiplier;

    _blacklistedIdentifiers[identifier] = DateTime.now().add(
      Duration(seconds: durationSeconds),
    );
    _requestCounts.remove(key);
    _windowStarts.remove(key);
  }

  bool _isBanned(String identifier) {
    if (!_blacklistedIdentifiers.containsKey(identifier)) return false;
    if (DateTime.now().isAfter(_blacklistedIdentifiers[identifier]!)) {
      _blacklistedIdentifiers.remove(identifier);
      return false;
    }
    return true;
  }

  void performMaintenance() {
    final now = DateTime.now();
    _blacklistedIdentifiers.removeWhere((id, time) => now.isAfter(time));
    _windowStarts.removeWhere(
      (key, time) => now.difference(time).inMinutes > 5,
    );
    _requestCounts.removeWhere((key, count) => !_windowStarts.containsKey(key));
  }
}
