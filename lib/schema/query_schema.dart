import 'package:revani/core/database_engine.dart';
import 'package:revani/core/query_engine.dart';
import 'package:revani/model/print.dart';
import 'package:revani/schema/data_schema.dart';

class QuerySchema {
  final RevaniDatabase db;
  final RevaniQueryEngine _engine = RevaniQueryEngine();
  late final DataSchemaProject _projectSchema;

  QuerySchema(this.db) {
    _projectSchema = DataSchemaProject(db);
  }

  Future<DataResponse> queryData(
    String accountID,
    String projectName,
    String bucket,
    Map<String, dynamic> query,
  ) async {
    final pId = await _projectSchema.existProject(accountID, projectName);
    if (pId == null) {
      return printGenerator(
        error: "Project not found",
        status: StatusCodes.notFound,
      );
    }

    final bucketData = db.getAll(bucket);
    if (bucketData == null || bucketData.isEmpty) {
      return printGenerator(
        message: "No data in bucket",
        status: StatusCodes.ok,
        data: [],
      );
    }

    final filtered = bucketData
        .where((e) => e.value['projectId'] == pId)
        .toList();
    final results = _engine.execute(filtered, query);

    return printGenerator(
      message: "Query completed",
      status: StatusCodes.ok,
      data: results
          .map(
            (e) => {
              'tag': e.tag,
              'value': e.value['value'],
              'created_at': e.createdAt,
            },
          )
          .toList(),
    );
  }
}
