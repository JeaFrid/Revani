import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:isolate';
import 'dart:math';

import 'package:revani/config.dart';

class RevaniBson {
  static const int _typeNull = 0;
  static const int _typeBoolTrue = 1;
  static const int _typeBoolFalse = 2;
  static const int _typeInt = 3;
  static const int _typeDouble = 4;
  static const int _typeString = 5;
  static const int _typeList = 6;
  static const int _typeMap = 7;
  static const int _typeBinary = 8;

  static Uint8List encode(dynamic value) {
    final builder = BytesBuilder(copy: false);
    _write(builder, value);
    return builder.takeBytes();
  }

  static TransferableTypedData encodeTransferable(dynamic value) {
    return TransferableTypedData.fromList([encode(value)]);
  }

  static dynamic decode(Uint8List bytes) {
    final reader = _BufferReader(ByteData.sublistView(bytes));
    return _read(reader);
  }

  static void _write(BytesBuilder builder, dynamic value) {
    if (value == null) {
      builder.addByte(_typeNull);
    } else if (value is bool) {
      builder.addByte(value ? _typeBoolTrue : _typeBoolFalse);
    } else if (value is int) {
      builder.addByte(_typeInt);
      final data = ByteData(8);
      data.setInt64(0, value);
      builder.add(data.buffer.asUint8List());
    } else if (value is double) {
      builder.addByte(_typeDouble);
      final data = ByteData(8);
      data.setFloat64(0, value);
      builder.add(data.buffer.asUint8List());
    } else if (value is String) {
      builder.addByte(_typeString);
      final bytes = utf8.encode(value);
      final lenData = ByteData(4);
      lenData.setUint32(0, bytes.length);
      builder.add(lenData.buffer.asUint8List());
      builder.add(bytes);
    } else if (value is Uint8List) {
      builder.addByte(_typeBinary);
      final lenData = ByteData(4);
      lenData.setUint32(0, value.length);
      builder.add(lenData.buffer.asUint8List());
      builder.add(value);
    } else if (value is List) {
      builder.addByte(_typeList);
      final lenData = ByteData(4);
      lenData.setUint32(0, value.length);
      builder.add(lenData.buffer.asUint8List());
      for (var item in value) {
        _write(builder, item);
      }
    } else if (value is Map) {
      builder.addByte(_typeMap);
      final lenData = ByteData(4);
      lenData.setUint32(0, value.length);
      builder.add(lenData.buffer.asUint8List());
      value.forEach((k, v) {
        _write(builder, k.toString());
        _write(builder, v);
      });
    } else {
      _write(builder, value.toString());
    }
  }

  static dynamic _read(_BufferReader reader) {
    final type = reader.readByte();
    switch (type) {
      case _typeNull:
        return null;
      case _typeBoolTrue:
        return true;
      case _typeBoolFalse:
        return false;
      case _typeInt:
        return reader.readInt64();
      case _typeDouble:
        return reader.readFloat64();
      case _typeString:
        final len = reader.readUint32();
        final bytes = reader.readBytes(len);
        return utf8.decode(bytes);
      case _typeBinary:
        final len = reader.readUint32();
        return reader.readBytes(len);
      case _typeList:
        final len = reader.readUint32();
        final list = List<dynamic>.filled(len, null, growable: true);
        for (int i = 0; i < len; i++) {
          list[i] = _read(reader);
        }
        return list;
      case _typeMap:
        final len = reader.readUint32();
        final map = <String, dynamic>{};
        for (int i = 0; i < len; i++) {
          final key = _read(reader) as String;
          final val = _read(reader);
          map[key] = val;
        }
        return map;
      default:
        throw FormatException('Invalid BSON Type: $type');
    }
  }
}

class _BufferReader {
  final ByteData _data;
  int _offset = 0;

  _BufferReader(this._data);

  int readByte() {
    final b = _data.getUint8(_offset);
    _offset += 1;
    return b;
  }

  int readUint32() {
    final v = _data.getUint32(_offset);
    _offset += 4;
    return v;
  }

  int readInt64() {
    final v = _data.getInt64(_offset);
    _offset += 8;
    return v;
  }

  double readFloat64() {
    final v = _data.getFloat64(_offset);
    _offset += 8;
    return v;
  }

  Uint8List readBytes(int length) {
    final list = _data.buffer.asUint8List(
      _data.offsetInBytes + _offset,
      length,
    );
    _offset += length;
    return Uint8List.fromList(list);
  }
}

class RevaniData {
  final String bucket;
  final String tag;
  final Uint8List _storage;
  final int createdAt;
  final int? expiresAt;

  RevaniData(
    this.bucket,
    this.tag,
    Map<String, dynamic> value, {
    int? createdAt,
    this.expiresAt,
  }) : _storage = RevaniBson.encode(value),
       createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch;

  RevaniData.fromBytes(
    this.bucket,
    this.tag,
    this._storage, {
    int? createdAt,
    this.expiresAt,
  }) : createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch;

  Map<String, dynamic> get value {
    return RevaniBson.decode(_storage) as Map<String, dynamic>;
  }

  Uint8List get rawBytes => _storage;

  TransferableTypedData get transferableBytes =>
      TransferableTypedData.fromList([_storage]);

  bool get isExpired =>
      expiresAt != null && DateTime.now().millisecondsSinceEpoch > expiresAt!;
}

class RevaniDatabase {
  final StreamController<Map<String, dynamic>> _eventController =
      StreamController<Map<String, dynamic>>.broadcast();

  final Map<String, Map<String, RevaniData>> _box = {};
  Timer? _gcTimer;
  final Random _rng = Random();

  RevaniDatabase() {
    _startSmartGarbageCollector();
  }

  Stream<Map<String, dynamic>> get eventStream => _eventController.stream;
  Map<String, Map<String, RevaniData>> get box => _box;

  void _startSmartGarbageCollector() {
    _gcTimer = Timer.periodic(RevaniConfig.gcInterval, (timer) {
      _performIncrementalGC();
    });
  }

  void _performIncrementalGC() {
    if (_box.isEmpty) return;

    final buckets = _box.keys.toList();
    if (buckets.isEmpty) return;

    final randomBucketName = buckets[_rng.nextInt(buckets.length)];
    final bucketMap = _box[randomBucketName];

    if (bucketMap == null || bucketMap.isEmpty) {
      if (bucketMap != null && bucketMap.isEmpty) {
        _box.remove(randomBucketName);
      }
      return;
    }

    int expiredCount = 0;
    int checkedCount = 0;
    final keysToRemove = <String>[];
    final now = DateTime.now().millisecondsSinceEpoch;

    for (var entry in bucketMap.entries) {
      if (entry.value.expiresAt != null) {
        checkedCount++;
        if (now > entry.value.expiresAt!) {
          keysToRemove.add(entry.key);
          expiredCount++;
        }
      }
      if (checkedCount >= RevaniConfig.gcCheckCount) break;
    }

    for (var key in keysToRemove) {
      remove(randomBucketName, key);
    }

    if (checkedCount > 0 && (expiredCount / checkedCount) > 0.25) {
      Future.microtask(() => _performIncrementalGC());
    }
  }

  void _createEvent(
    String action,
    String bucket,
    String? tag,
    Map<String, dynamic>? value, {
    int? createdAt,
    int? expiresAt,
    Uint8List? preEncodedValue,
  }) {
    if (_eventController.hasListener) {
      _eventController.add({
        'action': action,
        'bucket': bucket,
        'tag': tag,
        'value': value,
        'preEncodedValue': preEncodedValue,
        'createdAt': createdAt,
        'expiresAt': expiresAt,
      });
    }
  }

  final Map<String, Map<String, String>> _indices = {};

  void add(
    String bucket,
    String tag,
    Map<String, dynamic> value, {
    Duration? ttl,
  }) {
    final bytes = RevaniBson.encode(value);
    _addInternal(bucket, tag, bytes, value, ttl: ttl);
  }

  void addRaw(String bucket, String tag, Uint8List rawValue, {Duration? ttl}) {
    _addInternal(bucket, tag, rawValue, null, ttl: ttl);
  }

  void _addInternal(
    String bucket,
    String tag,
    Uint8List rawData,
    Map<String, dynamic>? originalValue, {
    Duration? ttl,
  }) {
    _box.putIfAbsent(bucket, () => <String, RevaniData>{});

    final now = DateTime.now().millisecondsSinceEpoch;
    int? expiresAt;
    if (ttl != null) {
      expiresAt = now + ttl.inMilliseconds;
    }

    final data = RevaniData.fromBytes(
      bucket,
      tag,
      rawData,
      createdAt: now,
      expiresAt: expiresAt,
    );

    _box[bucket]![tag] = data;

    _createEvent(
      'add',
      bucket,
      tag,
      originalValue,
      preEncodedValue: rawData,
      createdAt: now,
      expiresAt: expiresAt,
    );
  }

  RevaniData? get(String bucket, String tag) {
    final data = _box[bucket]?[tag];
    if (data == null) return null;

    if (data.isExpired) {
      remove(bucket, tag);
      return null;
    }
    return data;
  }

  List<RevaniData>? getAll(String bucket) {
    return _box[bucket]?.values.where((e) => !e.isExpired).toList();
  }

  List<RevaniData> getLatest(String bucket, int count) {
    final bucketData = _box[bucket];
    if (bucketData == null) return [];

    final list = bucketData.values
        .where((e) => !e.isExpired)
        .toList(growable: false);

    if (list.isEmpty) return [];

    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (count >= list.length) return list;
    return list.sublist(0, count);
  }

  Map<String, dynamic> stats() {
    int totalCount = 0;
    _box.forEach((bucket, data) {
      totalCount += data.length;
    });

    return {'total_records': totalCount, 'buckets_count': _box.length};
  }

  void remove(String bucket, String tag) {
    final bucketMap = _box[bucket];
    if (bucketMap != null && bucketMap.containsKey(tag)) {
      bucketMap.remove(tag);
      if (bucketMap.isEmpty) _box.remove(bucket);
      _createEvent('remove', bucket, tag, null);
    }
  }

  void clear(String bucket) {
    if (_box.containsKey(bucket)) {
      _box.remove(bucket);
      _createEvent('clear', bucket, null, null);
    }
  }

  void setIndex(String indexName, String key, String id) {
    _indices.putIfAbsent(indexName, () => {});
    _indices[indexName]![key] = id;
  }

  String? getIdByIndex(String indexName, String key) {
    return _indices[indexName]?[key];
  }

  void removeIndex(String indexName, String key) {
    _indices[indexName]?.remove(key);
  }

  void dispose() {
    _gcTimer?.cancel();
    _eventController.close();
  }
}

class RevaniPersistence {
  final RevaniDatabase db;
  final String filePath;
  RandomAccessFile? _raf;
  bool _isCompacting = false;
  final List<Map<String, dynamic>> _compactionBuffer = [];

  Timer? _flushTimer;
  Timer? _backupTimer;
  final BytesBuilder _writeBuffer = BytesBuilder(copy: false);
  File? _lockFile;

  RevaniPersistence(this.db, this.filePath);

  Future<void> init() async {
    final lockPath = '$filePath.lock';
    _lockFile = File(lockPath);

    if (await _lockFile!.exists()) {
      try {
        final stat = await _lockFile!.stat();
        if (DateTime.now().difference(stat.modified).inMinutes > 5) {
          await _lockFile!.delete();
        } else {
          throw StateError('Database locked by another instance.');
        }
      } catch (e) {
        await _lockFile!.delete();
      }
      await _lockFile!.create();
    } else {
      await _lockFile!.create();
    }

    final file = File(filePath);
    if (await file.exists()) {
      await _loadFromDiskStreamed();
    }

    _raf = await file.open(mode: FileMode.append);

    db.eventStream.listen((event) {
      if (_isCompacting) {
        _compactionBuffer.add(event);
      } else {
        _bufferEvent(event);
      }
    });

    _flushTimer = Timer.periodic(RevaniConfig.flushInterval, (_) {
      _flushBuffer();
    });

    _backupTimer = Timer.periodic(const Duration(hours: 1), (_) {
      _performBackupIsolate();
    });
  }

  Future<void> _performBackupIsolate() async {
    try {
      final parentDir = File(filePath).parent.path;
      final currentFilePath = filePath;

      await Isolate.run(() async {
        final backupDir = Directory('$parentDir/backup');
        if (!await backupDir.exists()) {
          await backupDir.create(recursive: true);
        }

        final now = DateTime.now();
        final timestamp =
            '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}';
        final backupPath = '${backupDir.path}/backup_$timestamp.rev';

        final sourceFile = File(currentFilePath);
        if (await sourceFile.exists()) {
          await sourceFile.copy(backupPath);
        }

        final cutoffDate = now.subtract(const Duration(days: 7));
        await for (var entity in backupDir.list()) {
          if (entity is File) {
            final stat = await entity.stat();
            if (stat.modified.isBefore(cutoffDate)) {
              await entity.delete();
            }
          }
        }
      });
    } catch (e) {
      stderr.writeln('Backup Error: $e');
    }
  }

  Future<void> _loadFromDiskStreamed() async {
    final file = File(filePath);
    final reader = await file.open(mode: FileMode.read);
    final length = await reader.length();

    try {
      int processed = 0;
      while (await reader.position() < length) {
        processed++;
        if (processed % 2000 == 0) {
          await Future.delayed(Duration.zero);
        }

        try {
          final actionByte = await reader.readByte();
          if (actionByte == -1) break;

          final bucketLen = await _readUint32(reader);
          final bucketBytes = await reader.read(bucketLen);
          final bucket = utf8.decode(bucketBytes);

          if (actionByte == 0) {
            final tagLen = await _readUint32(reader);
            final tagBytes = await reader.read(tagLen);
            final tag = utf8.decode(tagBytes);

            final valLen = await _readUint32(reader);
            final valBytes = await reader.read(valLen);
            final Uint8List value = Uint8List.fromList(valBytes);

            final createdAt = await _readUint64(reader);

            final hasExpiry = await reader.readByte();
            int? expiresAt;
            if (hasExpiry == 1) {
              expiresAt = await _readUint64(reader);
            }

            final now = DateTime.now().millisecondsSinceEpoch;
            if (expiresAt == null || now < expiresAt) {
              db.box.putIfAbsent(bucket, () => <String, RevaniData>{});
              db.box[bucket]![tag] = RevaniData.fromBytes(
                bucket,
                tag,
                value,
                createdAt: createdAt,
                expiresAt: expiresAt,
              );
            }
          } else if (actionByte == 1) {
            final tagLen = await _readUint32(reader);
            final tagBytes = await reader.read(tagLen);
            final tag = utf8.decode(tagBytes);
            db.box[bucket]?.remove(tag);
          } else if (actionByte == 2) {
            db.box.remove(bucket);
          }
        } catch (e) {
          stderr.writeln('Corrupt Record Error: $e');
        }
      }
    } catch (e) {
      stderr.writeln('Load Error: $e');
    } finally {
      await reader.close();
    }
  }

  Future<int> _readUint32(RandomAccessFile reader) async {
    final bytes = await reader.read(4);
    if (bytes.length < 4) throw Exception("EOF Uint32");
    return ByteData.sublistView(bytes).getUint32(0);
  }

  Future<int> _readUint64(RandomAccessFile reader) async {
    final bytes = await reader.read(8);
    if (bytes.length < 8) throw Exception("EOF Uint64");
    return ByteData.sublistView(bytes).getUint64(0);
  }

  void _bufferEvent(Map<String, dynamic> event) {
    try {
      final action = event['action'];
      final bucket = utf8.encode(event['bucket']);

      if (action == 'add') {
        _writeBuffer.addByte(0);
        _writeBuffer.add(_uint32ToBytes(bucket.length));
        _writeBuffer.add(bucket);

        final tag = utf8.encode(event['tag']);
        _writeBuffer.add(_uint32ToBytes(tag.length));
        _writeBuffer.add(tag);

        final Uint8List val =
            event['preEncodedValue'] ?? RevaniBson.encode(event['value']);

        _writeBuffer.add(_uint32ToBytes(val.length));
        _writeBuffer.add(val);

        final createdAt =
            event['createdAt'] ?? DateTime.now().millisecondsSinceEpoch;
        _writeBuffer.add(_uint64ToBytes(createdAt));

        if (event['expiresAt'] != null) {
          _writeBuffer.addByte(1);
          _writeBuffer.add(_uint64ToBytes(event['expiresAt']));
        } else {
          _writeBuffer.addByte(0);
        }
      } else if (action == 'remove') {
        _writeBuffer.addByte(1);
        _writeBuffer.add(_uint32ToBytes(bucket.length));
        _writeBuffer.add(bucket);

        final tag = utf8.encode(event['tag']);
        _writeBuffer.add(_uint32ToBytes(tag.length));
        _writeBuffer.add(tag);
      } else if (action == 'clear') {
        _writeBuffer.addByte(2);
        _writeBuffer.add(_uint32ToBytes(bucket.length));
        _writeBuffer.add(bucket);
      }

      if (_writeBuffer.length > 65536) {
        _flushBuffer();
      }
    } catch (e) {
      stderr.writeln('Buffer Error: $e');
    }
  }

  Future<void> _flushBuffer() async {
    if (_writeBuffer.isEmpty || _raf == null || _isCompacting) return;

    final bytes = _writeBuffer.takeBytes();
    try {
      await _raf!.writeFrom(bytes);
    } catch (e) {
      _writeBuffer.add(bytes);
    }
  }

  Future<void> forceSync() async {
    await _flushBuffer();
    if (_raf != null) {
      await _raf!.flush();
    }
  }

  Uint8List _uint32ToBytes(int value) {
    final data = ByteData(4);
    data.setUint32(0, value);
    return data.buffer.asUint8List();
  }

  Uint8List _uint64ToBytes(int value) {
    final data = ByteData(8);
    data.setUint64(0, value);
    return data.buffer.asUint8List();
  }

  Future<void> compact() async {
    if (_isCompacting) return;
    _isCompacting = true;

    await _flushBuffer();

    final tempPath = '$filePath.compact';
    final tempFile = File(tempPath);
    final rafTemp = await tempFile.open(mode: FileMode.write);

    try {
      int count = 0;

      for (var bucketEntry in db.box.entries) {
        final bucketBytes = utf8.encode(bucketEntry.key);

        for (var entry in bucketEntry.value.entries) {
          if (entry.value.isExpired) continue;

          count++;
          if (count % 500 == 0) await Future.delayed(Duration.zero);

          final tagBytes = utf8.encode(entry.key);
          final vBytes = entry.value.rawBytes;

          final entryBuffer = BytesBuilder(copy: false);
          entryBuffer.addByte(0);
          entryBuffer.add(_uint32ToBytes(bucketBytes.length));
          entryBuffer.add(bucketBytes);
          entryBuffer.add(_uint32ToBytes(tagBytes.length));
          entryBuffer.add(tagBytes);
          entryBuffer.add(_uint32ToBytes(vBytes.length));
          entryBuffer.add(vBytes);
          entryBuffer.add(_uint64ToBytes(entry.value.createdAt));

          if (entry.value.expiresAt != null) {
            entryBuffer.addByte(1);
            entryBuffer.add(_uint64ToBytes(entry.value.expiresAt!));
          } else {
            entryBuffer.addByte(0);
          }

          await rafTemp.writeFrom(entryBuffer.takeBytes());
        }
      }
      await rafTemp.flush();
      await rafTemp.close();

      await _raf?.close();
      await tempFile.rename(filePath);
      _raf = await File(filePath).open(mode: FileMode.append);
    } catch (e) {
      try {
        await tempFile.delete();
      } catch (_) {}
    } finally {
      _isCompacting = false;
    }

    for (var queuedEvent in _compactionBuffer) {
      _bufferEvent(queuedEvent);
    }
    _compactionBuffer.clear();
    await _flushBuffer();
  }

  Future<void> close() async {
    _flushTimer?.cancel();
    _backupTimer?.cancel();
    await _flushBuffer();
    await _raf?.close();
    _raf = null;
    db.dispose();

    if (_lockFile != null && await _lockFile!.exists()) {
      await _lockFile!.delete();
    }
  }
}
