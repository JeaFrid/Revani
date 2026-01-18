import 'dart:io';

class RoleLimits {
  final int maxProjects;
  final int maxDataEntries;
  final int maxStorageMB;
  final int requestsPerMinute;

  const RoleLimits({
    required this.maxProjects,
    required this.maxDataEntries,
    required this.maxStorageMB,
    required this.requestsPerMinute,
  });
}

class RevaniConfig {
  static const int port = 16897;
  static const String host = '0.0.0.0';
  static final int workerCount = Platform.numberOfProcessors;
  static const bool sslEnabled = true;
  static const String certPath = 'server.crt';
  static const String keyPath = 'server.key';
  static const Duration sessionTimeout = Duration(hours: 24);
  static const Duration replayAttackWindow = Duration(seconds: 30);
  static const String dbPath = 'revani.db';
  static const Duration compactionInterval = Duration(minutes: 10);
  static const Duration flushInterval = Duration(milliseconds: 200);
  static const int maxRamUsageMB = 8000;
  static const String storagePath = 'storage';
  static const int maxFileSizeMB = 50;
  static const List<String> allowedExtensions = [
    '.jpg',
    '.png',
    '.pdf',
    '.mp4',
    '.json',
    '.zip',
  ];
  static const Map<String, int> limits = {
    'connection': 50,
    'account': 5,
    'data': 300,
    'project': 10,
  };

  static const Duration gcInterval = Duration(milliseconds: 100);
  static const int gcCheckCount = 20;
  static const Map<String, RoleLimits> roleConfigs = {
    'user': RoleLimits(
      maxProjects: 3,
      maxDataEntries: 1000,
      maxStorageMB: 50,
      requestsPerMinute: 60,
    ),
    'gold': RoleLimits(
      maxProjects: 15,
      maxDataEntries: 10000,
      maxStorageMB: 500,
      requestsPerMinute: 300,
    ),
    'premium': RoleLimits(
      maxProjects: 100,
      maxDataEntries: 100000,
      maxStorageMB: 5000,
      requestsPerMinute: 1000,
    ),
    'admin': RoleLimits(
      maxProjects: 999999,
      maxDataEntries: 999999999,
      maxStorageMB: 9999999,
      requestsPerMinute: 999999,
    ),
  };
}
