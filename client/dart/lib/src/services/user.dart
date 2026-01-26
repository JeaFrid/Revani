import '../model/user_response.dart';
import '../source/api.dart';
import 'package:uuid/uuid.dart';
import 'dart:async';

import 'revani_base.dart';
import 'revani_database_serv.dart';

class RevaniBaseUser {
  RevaniBaseUser();
  RevaniBaseDB database = RevaniBaseDB();
  RevaniBase revaniBase = RevaniBase();
  RevaniClient get revani => revaniBase.revani;
  RevaniData get db => revani.data;

  Future<RevaniResponse?> create(
    String name,
    String email,
    String password,
  ) async {
    try {
      bool existEmail = exist(email);
      if (existEmail) {
        return RevaniResponse(
          status: 500,
          message: "Email available",
          error: "Email available",
        );
      } else {
        String uid = Uuid().v1();
        var emptyUser = RevaniUserResponse.empty();
        RevaniUserResponse userData() => emptyUser.copyWith(
          username: name,
          email: email,
          password: password,
        );

        var res = await database.add(
          bucket: "users",
          tag: uid,
          value: userData().toJson(),
        );
        if (res.isSuccess) {
          return RevaniResponse(status: 200, message: "ok");
        }
        return RevaniResponse(
          status: res.status,
          message: res.message,
          error: res.error,
        );
      }
    } catch (e) {
      return RevaniResponse(status: 500, message: "Error", error: e.toString());
    }
  }

  bool exist(String email) {
    for (var element in database.data) {
      if (element.bucket == database.userBucketName) {
        if (element.value.containsKey("email")) {
          if (element.value["email"] == email) {
            return true;
          }
        }
      }
    }
    return false;
  }

  Future<RevaniResponse> login(String email, String password) async {
    bool existE = exist(email);
    if (existE) {
      for (var element in database.data) {
        if (element.bucket == database.userBucketName) {
          if (element.value.containsKey("email")) {
            if (element.value["email"] == email &&
                element.value["password"] == password) {
              return RevaniResponse(status: 200, message: "ok");
            }
          }
        }
      }
    } else {
      return RevaniResponse(status: 500, message: "Account not found");
    }
    return RevaniResponse(status: 500, message: "Err");
  }

  Future<RevaniResponse> updateProfile(RevaniUserResponse user) async {
    return await database.update(
      bucket: database.userBucketName,
      tag: user.uid,
      newValue: user.toJson(),
    );
  }
}
