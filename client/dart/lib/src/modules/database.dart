import '../model/data_model.dart';
import '../services/revani_base.dart';
import '../services/revani_database_serv.dart';
import '../source/api.dart';
import 'dart:async';

class RevaniDatabase {
  RevaniDatabase();
  RevaniBaseDB database = RevaniBaseDB();
  RevaniBase revaniBase = RevaniBase();
  RevaniClient get revani => revaniBase.revani;
  RevaniData get db => revani.data;

  String _buildBucketName(String bucket) {
    return "${database.databaseBucketName}_$bucket";
  }

  Future<RevaniResponse> add({
    required String bucket,
    required String tag,
    required Map<String, dynamic> value,
    Map<String, dynamic> customData = const {},
  }) async {
    return await database.add(
      bucket: _buildBucketName(bucket),
      tag: tag,
      value: {...value, '_customData': customData},
    );
  }

  Future<DataModel?> get({required String bucket, required String tag}) async {
    return await database.get(bucket: _buildBucketName(bucket), tag: tag);
  }

  Future<List<DataModel>> getAll({
    required String bucket,
    String? query,
    Map<String, dynamic>? filter,
    int? limit,
    int? offset,
    String? sortBy,
    bool descending = true,
  }) async {
    try {
      final allData = await database.getAll(_buildBucketName(bucket));
      List<DataModel> filteredData = allData;

      if (query != null && query.isNotEmpty) {
        filteredData = filteredData.where((item) {
          return item.value.toString().toLowerCase().contains(
            query.toLowerCase(),
          );
        }).toList();
      }

      if (filter != null && filter.isNotEmpty) {
        filteredData = filteredData.where((item) {
          for (final key in filter.keys) {
            if (item.value[key] != filter[key]) {
              return false;
            }
          }
          return true;
        }).toList();
      }

      if (sortBy != null) {
        filteredData.sort((a, b) {
          final aValue = a.value[sortBy];
          final bValue = b.value[sortBy];

          if (aValue is Comparable && bValue is Comparable) {
            return descending
                ? bValue.compareTo(aValue)
                : aValue.compareTo(bValue);
          }
          return 0;
        });
      }

      final startIndex = offset ?? 0;
      final endIndex = limit != null
          ? (startIndex + limit).clamp(0, filteredData.length)
          : filteredData.length;

      if (startIndex >= filteredData.length) {
        return [];
      }

      return filteredData.sublist(startIndex, endIndex);
    } catch (e) {
      return [];
    }
  }

  Future<RevaniResponse> delete({
    required String bucket,
    required String tag,
    Map<String, dynamic> customData = const {},
  }) async {
    return await database.delete(bucket: _buildBucketName(bucket), tag: tag);
  }

  Future<RevaniResponse> update({
    required String bucket,
    required String tag,
    required Map<String, dynamic> value,
    Map<String, dynamic> customData = const {},
  }) async {
    return await database.update(
      bucket: _buildBucketName(bucket),
      tag: tag,
      newValue: {...value, '_customData': customData},
    );
  }

  Future<RevaniResponse> addBatch({
    required String bucket,
    required Map<String, Map<String, dynamic>> items,
    Map<String, dynamic> customData = const {},
  }) async {
    try {
      final processedItems = items.map((key, value) {
        return MapEntry(key, {...value, '_customData': customData});
      });

      return await db.addBatch(
        bucket: _buildBucketName(bucket),
        items: processedItems,
        customData: customData,
      );
    } catch (e) {
      return RevaniResponse(status: 500, message: e.toString());
    }
  }

  Future<RevaniResponse> updateBatch({
    required String bucket,
    required Map<String, Map<String, dynamic>> items,
    Map<String, dynamic> customData = const {},
  }) async {
    try {
      final results = <RevaniResponse>[];

      for (final entry in items.entries) {
        final response = await update(
          bucket: bucket,
          tag: entry.key,
          value: entry.value,
          customData: customData,
        );
        results.add(response);
        if (!response.isSuccess) {
          return RevaniResponse(
            status: response.status,
            message:
                "Batch update failed at tag ${entry.key}: ${response.message}",
            error: response.error,
          );
        }
      }

      return RevaniResponse(
        status: 200,
        message: "Successfully updated ${items.length} items",
        data: {'processed': items.length, 'results': results},
      );
    } catch (e) {
      return RevaniResponse(status: 500, message: e.toString());
    }
  }

  Future<RevaniResponse> deleteBatch({
    required String bucket,
    required List<String> tags,
    Map<String, dynamic> customData = const {},
  }) async {
    try {
      final results = <RevaniResponse>[];

      for (final tag in tags) {
        final response = await delete(
          bucket: bucket,
          tag: tag,
          customData: customData,
        );
        results.add(response);

        if (!response.isSuccess) {
          return RevaniResponse(
            status: response.status,
            message: "Batch delete failed at tag $tag: ${response.message}",
            error: response.error,
          );
        }
      }

      return RevaniResponse(
        status: 200,
        message: "Successfully deleted ${tags.length} items",
        data: {'processed': tags.length, 'results': results},
      );
    } catch (e) {
      return RevaniResponse(status: 500, message: e.toString());
    }
  }

  Future<RevaniResponse> upsert({
    required String bucket,
    required String tag,
    required Map<String, dynamic> value,
    Map<String, dynamic> customData = const {},
  }) async {
    try {
      final existing = await get(bucket: bucket, tag: tag);

      if (existing != null) {
        return await update(
          bucket: bucket,
          tag: tag,
          value: {...existing.value, ...value},
          customData: customData,
        );
      } else {
        return await add(
          bucket: bucket,
          tag: tag,
          value: value,
          customData: customData,
        );
      }
    } catch (e) {
      return RevaniResponse(status: 500, message: e.toString());
    }
  }

  Future<RevaniResponse> upsertBatch({
    required String bucket,
    required Map<String, Map<String, dynamic>> items,
    Map<String, dynamic> customData = const {},
  }) async {
    try {
      final results = <String, dynamic>{
        'added': [],
        'updated': [],
        'failed': [],
      };

      for (final entry in items.entries) {
        final existing = await get(bucket: bucket, tag: entry.key);

        RevaniResponse response;
        if (existing != null) {
          response = await update(
            bucket: bucket,
            tag: entry.key,
            value: {...existing.value, ...entry.value},
            customData: customData,
          );
          if (response.isSuccess) {
            results['updated'].add(entry.key);
          } else {
            results['failed'].add({
              'tag': entry.key,
              'error': response.message,
            });
          }
        } else {
          response = await add(
            bucket: bucket,
            tag: entry.key,
            value: entry.value,
            customData: customData,
          );
          if (response.isSuccess) {
            results['added'].add(entry.key);
          } else {
            results['failed'].add({
              'tag': entry.key,
              'error': response.message,
            });
          }
        }
      }

      return RevaniResponse(
        status: 200,
        message: "Batch upsert completed",
        data: results,
      );
    } catch (e) {
      return RevaniResponse(status: 500, message: e.toString());
    }
  }

  Future<List<DataModel>> query({
    required String bucket,
    required Map<String, dynamic> query,
    int? limit,
    int? offset,
    String? sortBy,
    bool descending = true,
  }) async {
    try {
      final response = await db.query(
        request: DataQueryRequest(
          bucket: _buildBucketName(bucket),
          query: query,
        ),
      );

      if (response.isSuccess && response.data != null) {
        List<DataModel> results = [];
        for (var item in response.data!) {
          if (item.containsKey('tag') && item.containsKey('value')) {
            results.add(DataModel(bucket, item['tag'], item['value']));
          }
        }
        if (sortBy != null) {
          results.sort((a, b) {
            final aValue = a.value[sortBy];
            final bValue = b.value[sortBy];

            if (aValue is Comparable && bValue is Comparable) {
              return descending
                  ? bValue.compareTo(aValue)
                  : aValue.compareTo(bValue);
            }
            return 0;
          });
        }
        final startIndex = offset ?? 0;
        final endIndex = limit != null
            ? (startIndex + limit).clamp(0, results.length)
            : results.length;

        if (startIndex >= results.length) {
          return [];
        }

        return results.sublist(startIndex, endIndex);
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, int>> getStats({
    required String bucket,
    Map<String, dynamic>? filter,
  }) async {
    try {
      final allData = await getAll(bucket: bucket);

      int total = allData.length;

      int filteredCount = total;
      if (filter != null) {
        filteredCount = allData.where((item) {
          for (final key in filter.keys) {
            if (item.value[key] != filter[key]) {
              return false;
            }
          }
          return true;
        }).length;
      }

      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));
      int last24h = allData.where((item) {
        final createdAt = item.value['createdAt'] ?? item.value['timestamp'];
        if (createdAt is String) {
          final date = DateTime.tryParse(createdAt);
          return date != null && date.isAfter(yesterday);
        }
        return false;
      }).length;

      return {'total': total, 'filtered': filteredCount, 'last24h': last24h};
    } catch (e) {
      print(e);
      return {};
    }
  }

  Future<RevaniResponse> clearBucket({
    required String bucket,
    Map<String, dynamic>? filter,
    Map<String, dynamic> customData = const {},
  }) async {
    try {
      if (filter != null) {
        // Filtreli silme
        final items = await getAll(bucket: bucket, filter: filter);
        final tags = items.map((item) => item.tag).toList();

        return await deleteBatch(
          bucket: bucket,
          tags: tags,
          customData: customData,
        );
      } else {
        // Tüm bucket'ı temizle
        return await db.deleteAll(
          bucket: _buildBucketName(bucket),
          customData: customData,
        );
      }
    } catch (e) {
      return RevaniResponse(status: 500, message: e.toString());
    }
  }

  Future<RevaniResponse> executeTransaction({
    required String bucket,
    required List<Map<String, dynamic>> operations,
    Map<String, dynamic> customData = const {},
  }) async {
    try {
      final results = <Map<String, dynamic>>[];

      for (final operation in operations) {
        final type = operation['type'];
        final tag = operation['tag'];
        final value = operation['value'];

        RevaniResponse response;

        switch (type) {
          case 'add':
            response = await add(
              bucket: bucket,
              tag: tag,
              value: value,
              customData: customData,
            );
            break;
          case 'update':
            response = await update(
              bucket: bucket,
              tag: tag,
              value: value,
              customData: customData,
            );
            break;
          case 'delete':
            response = await delete(
              bucket: bucket,
              tag: tag,
              customData: customData,
            );
            break;
          case 'upsert':
            response = await upsert(
              bucket: bucket,
              tag: tag,
              value: value,
              customData: customData,
            );
            break;
          default:
            return RevaniResponse(
              status: 400,
              message: "Unknown operation type: $type",
            );
        }

        results.add({
          'type': type,
          'tag': tag,
          'success': response.isSuccess,
          'message': response.message,
        });
        if (!response.isSuccess) {
          await _rollbackTransaction(bucket, results, customData);

          return RevaniResponse(
            status: 500,
            message: "Transaction failed at operation: $type - $tag",
            data: {'results': results, 'rolledBack': true},
          );
        }
      }

      return RevaniResponse(
        status: 200,
        message: "Transaction completed successfully",
        data: {'results': results, 'processed': operations.length},
      );
    } catch (e) {
      return RevaniResponse(status: 500, message: e.toString());
    }
  }

  Future<void> _rollbackTransaction(
    String bucket,
    List<Map<String, dynamic>> results,
    Map<String, dynamic> customData,
  ) async {
    for (final result in results) {
      if (result['success'] == true) {
        final type = result['type'];
        final tag = result['tag'];

        switch (type) {
          case 'add':
            await delete(bucket: bucket, tag: tag, customData: customData);
            break;
          case 'update':
            break;
          case 'delete':
            break;
        }
      }
    }
  }

  Future<List<String>> listBuckets() async {
    try {
      final allData = database.data;
      final buckets = <String>{};

      for (final item in allData) {
        if (item.bucket.startsWith("${database.databaseBucketName}_")) {
          final cleanBucket = item.bucket.replaceFirst(
            "${database.databaseBucketName}_",
            "",
          );
          buckets.add(cleanBucket);
        }
      }

      return buckets.toList();
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> getBucketInfo({required String bucket}) async {
    try {
      final items = await getAll(bucket: bucket);
      final tags = items.map((item) => item.tag).toList();

      int estimatedSize = 0;
      for (final item in items) {
        estimatedSize += item.value.toString().length;
      }

      return {
        'bucket': bucket,
        'itemCount': items.length,
        'estimatedSize': '$estimatedSize bytes',
        'tags': tags,
        'lastUpdated': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }
}
