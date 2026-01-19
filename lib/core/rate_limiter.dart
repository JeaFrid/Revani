/*
 * Copyright (C) 2026 JeaFriday (https://github.com/JeaFrid/Revani)
 * * This project is part of Revani
 * Licensed under the GNU Affero General Public License v3.0 (AGPL-3.0).
 * See the LICENSE file in the project root for full license information.
 * * For commercial licensing, please contact: JeaFriday
 */
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

class _AdminRateLimitRequest {
  final SendPort replyPort;
  final String action;
  final String? targetIp;

  _AdminRateLimitRequest(this.replyPort, this.action, {this.targetIp});
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

  Future<dynamic> adminOp(String action, {String? targetIp}) async {
    final responsePort = ReceivePort();
    _actorPort.send(
      _AdminRateLimitRequest(responsePort.sendPort, action, targetIp: targetIp),
    );
    final response = await responsePort.first;
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
      } else if (message is _AdminRateLimitRequest) {
        switch (message.action) {
          case 'get_banned':
            message.replyPort.send(limiter.getBannedList());
            break;
          case 'unban':
            limiter.unban(message.targetIp!);
            message.replyPort.send(true);
            break;
          case 'get_whitelist':
            message.replyPort.send(limiter.getWhitelist());
            break;
          case 'add_whitelist':
            limiter.addToWhitelist(message.targetIp!);
            message.replyPort.send(true);
            break;
          case 'remove_whitelist':
            limiter.removeFromWhitelist(message.targetIp!);
            message.replyPort.send(true);
            break;
        }
      }
    });
  }
}

class _RateLimitLogic {
  final Map<String, DateTime> _blacklistedIdentifiers = {};
  final Set<String> _whitelistedIdentifiers = {'127.0.0.1', '::1'};
  final Map<String, int> _violationHistory = {};
  final Map<String, int> _requestCounts = {};
  final Map<String, DateTime> _windowStarts = {};

  static const int _windowDurationSeconds = 60;

  _RateLimitLogic();

  List<Map<String, String>> getBannedList() {
    return _blacklistedIdentifiers.entries.map((e) {
      return {'ip': e.key, 'until': e.value.toIso8601String()};
    }).toList();
  }

  void unban(String ip) {
    _blacklistedIdentifiers.remove(ip);
    _violationHistory.remove(ip);
  }

  List<String> getWhitelist() {
    return _whitelistedIdentifiers.toList();
  }

  void addToWhitelist(String ip) {
    _whitelistedIdentifiers.add(ip);
    unban(ip);
  }

  void removeFromWhitelist(String ip) {
    _whitelistedIdentifiers.remove(ip);
  }

  RateLimitResponse process(
    String identifier,
    RateLimiterType type, {
    String? role,
  }) {
    if (_whitelistedIdentifiers.contains(identifier)) {
      return RateLimitResponse(isAllowed: true);
    }

    if (role == 'admin') {
      return RateLimitResponse(isAllowed: true);
    }

    if (_isBanned(identifier)) {
      final releaseTime = _blacklistedIdentifiers[identifier];
      return RateLimitResponse(
        isAllowed: false,
        error: 'RateLimitBan',
        status: 429,
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

    if (limit > 100000) return RateLimitResponse(isAllowed: true);

    final suspiciousThreshold = (limit * 0.8).toInt();
    final requestCount = _incrementAndGetCount(key);

    if (requestCount >= limit) {
      _executeBan(identifier, key, 300);
      return RateLimitResponse(
        isAllowed: false,
        error: 'RateLimitBan',
        status: 429,
        message: 'Limit exceeded for ${role ?? "IP Address"}.',
      );
    }

    if (requestCount > suspiciousThreshold) {
      return RateLimitResponse(
        isAllowed: true,
        message: 'Requesting too fast (Warning).',
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
