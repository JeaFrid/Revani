import '../model/data_model.dart';
import '../source/api.dart';
import 'revani_base.dart';

class RevaniBaseDB {
  static final RevaniBaseDB _instance = RevaniBaseDB._internal();

  factory RevaniBaseDB() => _instance;

  RevaniBaseDB._internal();

  RevaniBase revaniBase = RevaniBase();
  RevaniClient get revani => revaniBase.revani;
  RevaniPubSub get pubsub => revani.pubsub;
  RevaniData get db => revani.data;
  List<DataModel> data = [];

  String get userBucketName => "users";
  String get databaseBucketName => "database";

  Future<void> init() async {
    var users = await db.getAll(bucket: "users");
    if (users.isSuccess) {
      for (var element in users.data!) {
        data.add(DataModel("users", element["tag"], element["value"]));
      }
      var database = await db.getAll(bucket: "database");
      if (database.isSuccess) {
        for (var element in database.data!) {
          data.add(DataModel("users", element["tag"], element["value"]));
        }

        var sub = await revani.subscribeToBucket(
          bucket: "bucket",
          clientId: "all_data",
        );
        if (sub.isSuccess) {
          revani.bucketEvents.listen((event) {
            if (event.action == "updated") {
              for (var element in data) {
                if (element.tag == event.tag) {
                  data[data.indexOf(element)] = DataModel(
                    element.bucket,
                    element.tag,
                    event.newValue ?? element.value,
                  );
                }
              }
            } else if (event.action == "added") {
              if (event.tag == null || event.newValue == null) return;
              data.add(DataModel(event.bucket, event.tag!, event.newValue!));
            } else if (event.action == "deleted") {
              for (var element in data) {
                if (element.tag == event.tag) {
                  data.remove(element);
                }
              }
            }
          });
        }
      }
    }
  }

  Future<RevaniResponse> add({
    required String bucket,
    required String tag,
    required Map<String, dynamic> value,
  }) async {
    try {
      data.add(DataModel(bucket, tag, value));
      return await db.add(
        request: DataAddRequest(bucket: bucket, tag: tag, value: value),
      );
    } catch (e) {
      Exception(e);
      return RevaniResponse(status: 200, message: "err", error: e.toString());
    }
  }

  Future<DataModel?> get({required String bucket, required String tag}) async {
    try {
      for (var element in data) {
        if (element.bucket == bucket && element.tag == tag) {
          return element;
        }
      }
    } catch (e) {
      Exception(e);
      return null;
    }
    return null;
  }

  Future<RevaniResponse> delete({
    required String bucket,
    required String tag,
  }) async {
    try {
      for (var element in data) {
        if (element.bucket == bucket && element.tag == tag) {
          data.remove(data[data.indexOf(element)]);
          await db.delete(bucket: bucket, tag: tag);
          return RevaniResponse(status: 200, message: "ok");
        }
      }
      return RevaniResponse(status: 200, message: "??");
    } catch (e) {
      Exception(e);
      return RevaniResponse(status: 200, message: "err", error: e.toString());
    }
  }

  Future<List<DataModel>> getAll(String bucket) async {
    List<DataModel> all = [];
    try {
      for (var element in data) {
        if (element.bucket == bucket) {
          all.add(element);
        }
      }
      return all;
    } catch (e) {
      Exception(e);
      return [];
    }
  }

  Future<RevaniResponse> update({
    required String bucket,
    required String tag,
    required Map<String, dynamic> newValue,
  }) async {
    try {
      for (var element in data) {
        if (element.bucket == bucket && element.tag == tag) {
          await db.update(bucket: bucket, tag: tag, newValue: newValue);
          data[data.indexOf(element)] = DataModel(
            element.bucket,
            element.tag,
            newValue,
          );
          return RevaniResponse(status: 200, message: "ok");
        }
      }
      return RevaniResponse(status: 200, message: "??");
    } catch (e) {
      Exception(e);
      return RevaniResponse(status: 200, message: "err", error: e.toString());
    }
  }
}
