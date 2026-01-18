/*
 * Copyright (C) 2026 JeaFriday (https://github.com/JeaFrid/Revani)
 * * This project is part of Revani
 * Licensed under the GNU Affero General Public License v3.0 (AGPL-3.0).
 * See the LICENSE file in the project root for full license information.
 * * For commercial licensing, please contact: JeaFriday
 */

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dotenv/dotenv.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';
import 'package:argon2/argon2.dart';

class JeaTokener {
  var env = DotEnv();
  JeaTokener() {
    if (File('.env').existsSync()) {
      env.load(['.env']);
    }
  }
  String hashPassword(String password) {
    final salt = Uint8List.fromList(
      utf8.encode(const Uuid().v4().substring(0, 16)),
    );

    var parameters = Argon2Parameters(
      Argon2Parameters.ARGON2_id,
      salt,
      version: Argon2Parameters.ARGON2_VERSION_13,
      iterations: 3,
      memoryPowerOf2: 16,
    );

    var generator = Argon2BytesGenerator();
    generator.init(parameters);

    var passwordBytes = Uint8List.fromList(utf8.encode(password));
    var resultHash = Uint8List(32);
    generator.generateBytes(passwordBytes, resultHash, 0, resultHash.length);

    String encodedSalt = base64.encode(salt);
    String encodedHash = base64.encode(resultHash);

    return "$encodedSalt:$encodedHash";
  }

  bool verifyPassword(String password, String storedValue) {
    try {
      var parts = storedValue.split(':');
      if (parts.length != 2) return false;

      var salt = base64.decode(parts[0]);
      var originalHash = parts[1];

      var parameters = Argon2Parameters(
        Argon2Parameters.ARGON2_id,
        salt,
        version: Argon2Parameters.ARGON2_VERSION_13,
        iterations: 3,
        memoryPowerOf2: 16,
      );

      var generator = Argon2BytesGenerator();
      generator.init(parameters);

      var passwordBytes = Uint8List.fromList(utf8.encode(password));
      var newHashBytes = Uint8List(32);
      generator.generateBytes(
        passwordBytes,
        newHashBytes,
        0,
        newHashBytes.length,
      );

      String newHashEncoded = base64.encode(newHashBytes);
      return newHashEncoded == originalHash;
    } catch (e) {
      return false;
    }
  }

  String encryptStorage(String text) {
    String? password = env.getOrElse("PASSWORD", () => "");
    if (password == "") {
      throw Exception("Storage Password Not Found!!");
    }
    return _encryptCore(text, password);
  }

  String decryptStorage(String encryptedData) {
    String? password = env.getOrElse("PASSWORD", () => "");
    if (password == "") {
      throw Exception("Storage Password Not Found!!");
    }
    return _decryptCore(encryptedData, password);
  }

  String encryptSession(String text, String sessionKey) {
    return _encryptCore(text, sessionKey);
  }

  String decryptSession(String encryptedData, String sessionKey) {
    return _decryptCore(encryptedData, sessionKey);
  }

  String _encryptCore(String text, String keyString) {
    final Map<String, dynamic> wrapper = {
      "payload": text,
      "ts": DateTime.now().millisecondsSinceEpoch,
    };
    final String wrappedText = jsonEncode(wrapper);

    final salt = encrypt.IV.fromSecureRandom(16);
    final keyBytes = sha256.convert(utf8.encode(keyString + salt.base64)).bytes;
    final key = encrypt.Key(Uint8List.fromList(keyBytes));

    final iv = encrypt.IV.fromSecureRandom(16);
    final encrypter = encrypt.Encrypter(
      encrypt.AES(key, mode: encrypt.AESMode.gcm),
    );
    final encrypted = encrypter.encrypt(wrappedText, iv: iv);
    return "${salt.base64}:${iv.base64}:${encrypted.base64}";
  }

  String _decryptCore(String encryptedData, String keyString) {
    final parts = encryptedData.split(':');
    if (parts.length != 3) throw Exception("Invalid encrypted format");

    final salt = encrypt.IV.fromBase64(parts[0]);
    final iv = encrypt.IV.fromBase64(parts[1]);
    final cipherText = parts[2];

    final keyBytes = sha256.convert(utf8.encode(keyString + salt.base64)).bytes;
    final key = encrypt.Key(Uint8List.fromList(keyBytes));

    final encrypter = encrypt.Encrypter(
      encrypt.AES(key, mode: encrypt.AESMode.gcm),
    );

    final decryptedRaw = encrypter.decrypt64(cipherText, iv: iv);

    try {
      final Map<String, dynamic> wrapper = jsonDecode(decryptedRaw);
      final int ts = wrapper['ts'];
      final int now = DateTime.now().millisecondsSinceEpoch;

      if ((now - ts).abs() > 30000) {
        throw Exception("Replay Attack Detected");
      }

      return wrapper['payload'];
    } catch (e) {
      if (e.toString().contains("Replay")) rethrow;
      return decryptedRaw;
    }
  }
}
