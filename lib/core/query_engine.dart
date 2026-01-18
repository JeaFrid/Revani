/*
 * Copyright (C) 2026 JeaFriday (https://github.com/JeaFrid/Revani)
 * * This project is part of Revani
 * Licensed under the GNU Affero General Public License v3.0 (AGPL-3.0).
 * See the LICENSE file in the project root for full license information.
 * * For commercial licensing, please contact: JeaFriday
 */

import 'package:revani/core/database_engine.dart';

class RevaniQueryEngine {
  List<RevaniData> execute(
    List<RevaniData> source,
    Map<String, dynamic> query,
  ) {
    final filters = query['where'] as List<dynamic>? ?? [];
    final limit = query['limit'] as int? ?? 100;

    return source
        .where((item) {
          final data = item.value;
          for (var filter in filters) {
            if (!_matchFilter(data, filter)) return false;
          }
          return true;
        })
        .take(limit)
        .toList();
  }

  bool _matchFilter(Map<String, dynamic> data, Map<String, dynamic> filter) {
    final field = filter['field'] as String;
    final op = filter['op'] as String;
    final target = filter['value'];
    final actual = data[field];

    switch (op) {
      case '==':
        return actual == target;
      case '!=':
        return actual != target;
      case '>':
        if (actual is num && target is num) return actual > target;
        return false;
      case '<':
        if (actual is num && target is num) return actual < target;
        return false;
      case '>=':
        if (actual is num && target is num) return actual >= target;
        return false;
      case '<=':
        if (actual is num && target is num) return actual <= target;
        return false;
      case 'contains':
        if (actual is String && target is String)
          return actual.contains(target);
        if (actual is List) return actual.contains(target);
        return false;
      default:
        return false;
    }
  }
}
