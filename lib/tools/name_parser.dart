
import 'dart:convert';

class RoomParser {
  final String _accountID;
  final String _projectName;

  RoomParser(this._accountID, this._projectName);

  String? encodeRoomName(String roomName) {
    if (_accountID.isEmpty || _projectName.isEmpty) {
      return null;
    }

    try {
      final Map<String, dynamic> data = {
        "roomName": roomName,
        "accountID": _accountID,
        "projectName": _projectName,
      };
      return jsonEncode(data);
    } catch (e) {
      return null;
    }
  }

  String? decodeRoomName(String encodedName) {
    if (encodedName.isEmpty) {
      return null;
    }

    try {
      final dynamic decoded = jsonDecode(encodedName);

      if (decoded is Map<String, dynamic>) {
        final content = decoded["roomName"];
        if (content is String) {
          return content;
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }
    bool? isOwner(String encodedName) {
    if (encodedName.isEmpty) {
      return null;
    }

    try {
      final dynamic decoded = jsonDecode(encodedName);

      if (decoded is Map<String, dynamic>) {
        final targetProjectName = decoded["projectName"];
         final targetAccountID = decoded["accountID"];
        if (targetProjectName is String && targetAccountID is String) {
          if (targetProjectName == _projectName && targetAccountID == _accountID) {
            return true;
          }else{
            return false;
          }
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}