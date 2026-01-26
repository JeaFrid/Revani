import 'dart:io';
import '../services/revani_base.dart';
import '../services/revani_database_serv.dart';
import '../source/api.dart';

class RevaniStorage {
  RevaniStorage();
  RevaniBaseDB database = RevaniBaseDB();
  RevaniBase revaniBase = RevaniBase();
  RevaniClient get revani => revaniBase.revani;
  RevaniData get db => revani.data;

  Future<RevaniResponse> upload(File file) async {
    return revaniBase.revani.storage.upload(file: file);
  }

  Future<RevaniResponse> delete(String fileId) async {
    return revaniBase.revani.storage.delete(fileId: fileId);
  }

  String getImage(String fileId) {
    return revaniBase.revani.storage.getImage(fileId);
  }
}
