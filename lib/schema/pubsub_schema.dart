/*
 * Copyright (C) 2026 JeaFriday (https://github.com/JeaFrid/Revani)
 * * This project is part of Revani
 * Licensed under the GNU Affero General Public License v3.0 (AGPL-3.0).
 * See the LICENSE file in the project root for full license information.
 * * For commercial licensing, please contact: JeaFriday
 */

import 'package:revani/core/pubsub_engine.dart';
import 'package:revani/model/print.dart';
import 'package:revani/schema/data_schema.dart';
import 'package:revani/core/database_engine.dart';

class PubSubSchema {
  final RevaniPubSub _pubSub = RevaniPubSub();
  final RevaniDatabase db;
  late final DataSchemaProject _projectSchema;

  PubSubSchema(this.db) {
    _projectSchema = DataSchemaProject(db);
  }

  Future<DataResponse> handleSubscribe(
    String accountID,
    String projectName,
    String clientId,
    String topic,
  ) async {
    final pId = await _projectSchema.existProject(accountID, projectName);
    if (pId == null) {
      return printGenerator(
        error: "Project not found",
        status: StatusCodes.notFound,
      );
    }

    final globalTopic = "${pId}_$topic";
    _pubSub.subscribe(clientId, globalTopic);

    return printGenerator(
      message: "Subscribed to $topic",
      status: StatusCodes.ok,
      data: {"topic": topic, "clientId": clientId},
    );
  }

  Future<DataResponse> handleUnsubscribe(String clientId, String topic) async {
    _pubSub.unsubscribe(clientId, topic);
    return printGenerator(message: "Unsubscribed", status: StatusCodes.ok);
  }

  Future<DataResponse> handlePublish(
    String accountID,
    String projectName,
    String topic,
    Map<String, dynamic> data,
    String? senderId,
  ) async {
    final pId = await _projectSchema.existProject(accountID, projectName);
    if (pId == null) {
      return printGenerator(
        error: "Project not found",
        status: StatusCodes.notFound,
      );
    }

    final globalTopic = "${pId}_$topic";
    _pubSub.publish(globalTopic, data, senderId: senderId);

    return printGenerator(message: "Published", status: StatusCodes.ok);
  }
}
