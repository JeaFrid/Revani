/*
 * Copyright (C) 2026 JeaFriday (https://github.com/JeaFrid/Revani)
 * * This project is part of Revani
 * Licensed under the GNU Affero General Public License v3.0 (AGPL-3.0).
 * See the LICENSE file in the project root for full license information.
 * * For commercial licensing, please contact: JeaFriday
 */

import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:args/args.dart';
import '../client/dart/revani.dart';
const String _kReset = '\x1B[0m';
const String _kBold = '\x1B[1m';
const String _kRed = '\x1B[31m';
const String _kGreen = '\x1B[32m';
const String _kYellow = '\x1B[33m';
const String _kCyan = '\x1B[36m';
const String _kMagenta = '\x1B[35m';

void main(List<String> arguments) async {
  final parser = ArgParser()
    ..addFlag(
      'local',
      abbr: 'l',
      help: 'Connect to localhost:16897',
      defaultsTo: false,
    )
    ..addOption('host', abbr: 'h', help: 'Server Host')
    ..addOption('port', abbr: 'p', help: 'Server Port');

  ArgResults argResults = parser.parse(arguments);

  String host = '127.0.0.1';
  int port = 16897;

  print(
    _kMagenta +
        r'''
    ____                      _   
   / __ \___ _   ______ _____(_)  
  / /_/ / _ \ | / / __ `/ __ \ /  
 / _, _/  __/ |/ / /_/ / / / / /  
/_/ |_|\___/|___/\__,_/_/ /_/_/   
           CONSOLE
''' +
        _kReset,
  );

  if (argResults['local'] == true) {
    print('${_kYellow}Mode: Localhost Selected$_kReset');
  } else {
    if (argResults['host'] != null) {
      host = argResults['host'];
    } else {
      stdout.write('Server Host (Default: 127.0.0.1): ');
      final input = stdin.readLineSync()?.trim();
      if (input != null && input.isNotEmpty) host = input;
    }

    if (argResults['port'] != null) {
      port = int.tryParse(argResults['port']) ?? 16897;
    } else {
      stdout.write('Server Port (Default: 16897): ');
      final input = stdin.readLineSync()?.trim();
      if (input != null && input.isNotEmpty) {
        port = int.tryParse(input) ?? 16897;
      }
    }
  }

  final client = RevaniClient(host: host, port: port, secure: true);

  try {
    stdout.write('Connecting to $host:$port... ');
    await client.connect();
    print('$_kGreen Connected.$_kReset');
  } catch (e) {
    print('$_kRed Connection failed: $e$_kReset');
    print('Hint: Use --local if running locally, or check SSL certs.');
    exit(1);
  }

  if (await _authenticate(client)) {
    await _userLoop(client);
  }
}

Future<bool> _authenticate(RevaniClient client) async {
  print('\n$_kBold=== USER LOGIN ===$_kReset');

  while (true) {
    stdout.write('Email: ');
    final email = stdin.readLineSync()?.trim() ?? '';

    stdout.write('Password: ');
    stdin.echoMode = false;
    final password = stdin.readLineSync()?.trim() ?? '';
    stdin.echoMode = true;
    print('');

    if (email.isEmpty || password.isEmpty) {
      print('${_kRed}Credentials cannot be empty.$_kReset');
      continue;
    }

    try {
      final success = await client.account.login(email, password);
      if (success) {
        final checkRole = await client.execute({
          'cmd': 'admin/stats/full',
          'accountID': client.accountID,
        });

        if (checkRole['status'] == 200) {
          print(
            '$_kRed\n[ACCESS DENIED] This account has Administrator privileges.',
          );
          print(
            'Please use the "Executive Console" for admin operations.$_kReset',
          );
          client.disconnect();
          exit(0);
        }

        print('$_kGreen Login Successful. Welcome, User.$_kReset');
        return true;
      } else {
        print('${_kRed}Access Denied. Wrong email or password.$_kReset');
      }
    } catch (e) {
      print('${_kRed}Login Error: $e$_kReset');
      return false;
    }
  }
}

Future<void> _userLoop(RevaniClient client) async {
  String? activeProject;

  while (true) {
    String status = activeProject == null
        ? '${_kRed}No Project Selected$_kReset'
        : '${_kGreen}Project: $activeProject$_kReset';

    print('\n$_kBold=== DASHBOARD ===$_kReset');
    print('Status: $status');
    print('-----------------------');
    print('1. Create New Project');
    print('2. Select Project');
    if (activeProject != null) {
      print('3. ${_kCyan}Add Data$_kReset');
      print('4. ${_kCyan}Get Data (By Tag)$_kReset');
      print('5. ${_kCyan}Query Data (Filter)$_kReset');
      print('6. ${_kCyan}Update Data$_kReset');
      print('7. ${_kCyan}Delete Data$_kReset');
    }
    print('0. Exit');
    stdout.write('${_kYellow}console> $_kReset');

    final choice = stdin.readLineSync()?.trim();

    try {
      switch (choice) {
        case '1':
          await _createProject(client);
          break;
        case '2':
          activeProject = await _selectProject(client);
          break;
        case '3':
          if (activeProject != null) await _addData(client);
          break;
        case '4':
          if (activeProject != null) await _getData(client);
          break;
        case '5':
          if (activeProject != null) await _queryData(client);
          break;
        case '6':
          if (activeProject != null) await _updateData(client);
          break;
        case '7':
          if (activeProject != null) await _deleteData(client);
          break;
        case '0':
          print('Goodbye.');
          client.disconnect();
          exit(0);
        default:
          print('Invalid option.');
      }
    } catch (e) {
      print('${_kRed}Operation Failed: $e$_kReset');
    }
  }
}

Future<void> _createProject(RevaniClient client) async {
  stdout.write('New Project Name: ');
  final name = stdin.readLineSync()?.trim();
  if (name == null || name.isEmpty) return;

  final res = await client.project.create(name);
  if (res['status'] == 200) {
    print('$_kGreen Project "$name" created successfully.$_kReset');
  } else {
    print('$_kRed Error: ${res['error'] ?? res['message']}$_kReset');
  }
}

Future<String?> _selectProject(RevaniClient client) async {
  stdout.write('Enter Project Name to Select: ');
  final name = stdin.readLineSync()?.trim();
  if (name == null || name.isEmpty) return null;

  final res = await client.project.use(name);
  if (res['status'] == 200) {
    print('$_kGreen Project selected.$_kReset');
    return name;
  } else {
    print('$_kRed Project not found or access denied.$_kReset');
    return null;
  }
}

Future<void> _addData(RevaniClient client) async {
  stdout.write('Bucket (Category): ');
  final bucket = stdin.readLineSync()?.trim();

  stdout.write('Tag (Unique Key): ');
  final tag = stdin.readLineSync()?.trim();

  stdout.write('Value (JSON Format e.g. {"age": 25}): ');
  final jsonStr = stdin.readLineSync()?.trim();

  if (bucket == null || tag == null || jsonStr == null) return;

  try {
    final Map<String, dynamic> value = jsonDecode(jsonStr);
    final res = await client.data.add(bucket: bucket, tag: tag, value: value);
    if (res['status'] == 200) {
      print('$_kGreen Data saved.$_kReset');
    } else {
      print('$_kRed Error: ${res['message']}$_kReset');
    }
  } catch (e) {
    print('$_kRed Invalid JSON format.$_kReset');
  }
}

Future<void> _getData(RevaniClient client) async {
  stdout.write('Bucket: ');
  final bucket = stdin.readLineSync()?.trim();
  stdout.write('Tag: ');
  final tag = stdin.readLineSync()?.trim();

  if (bucket == null || tag == null) return;

  final res = await client.data.get(bucket: bucket, tag: tag);
  if (res['status'] == 200) {
    print('\n$_kCyan--- DATA ---$_kReset');
    print(JsonEncoder.withIndent('  ').convert(res['data']));
    print('$_kCyan------------$_kReset\n');
  } else {
    print('$_kRed Data not found.$_kReset');
  }
}

Future<void> _queryData(RevaniClient client) async {
  print(
    '${_kYellow}Query Format: {"where": [{"field": "age", "op": ">", "value": 18}]}$_kReset',
  );
  stdout.write('Bucket: ');
  final bucket = stdin.readLineSync()?.trim();
  stdout.write('Query JSON: ');
  final qStr = stdin.readLineSync()?.trim();

  if (bucket == null || qStr == null) return;

  try {
    final qJson = jsonDecode(qStr);
    final res = await client.data.query(bucket: bucket, query: qJson);

    if (res['status'] == 200) {
      final list = res['data'] as List;
      print('\n$_kGreen Found ${list.length} records:$_kReset');
      for (var item in list) {
        print(JsonEncoder.withIndent('  ').convert(item));
        print('-');
      }
    } else {
      print('$_kRed Query failed: ${res['message']}$_kReset');
    }
  } catch (e) {
    print('$_kRed Invalid JSON.$_kReset');
  }
}

Future<void> _updateData(RevaniClient client) async {
  stdout.write('Bucket: ');
  final bucket = stdin.readLineSync()?.trim();
  stdout.write('Tag: ');
  final tag = stdin.readLineSync()?.trim();
  stdout.write('New Value (JSON): ');
  final jsonStr = stdin.readLineSync()?.trim();

  if (bucket == null || tag == null || jsonStr == null) return;

  try {
    final val = jsonDecode(jsonStr);
    final res = await client.data.update(
      bucket: bucket,
      tag: tag,
      newValue: val,
    );
    if (res['status'] == 200) {
      print('$_kGreen Data updated.$_kReset');
    } else {
      print('$_kRed Error: ${res['message']}$_kReset');
    }
  } catch (e) {
    print('$_kRed Invalid JSON.$_kReset');
  }
}

Future<void> _deleteData(RevaniClient client) async {
  stdout.write('Bucket: ');
  final bucket = stdin.readLineSync()?.trim();
  stdout.write('Tag: ');
  final tag = stdin.readLineSync()?.trim();

  if (bucket == null || tag == null) return;

  final res = await client.data.delete(bucket: bucket, tag: tag);
  if (res['status'] == 200) {
    print('$_kGreen Data deleted.$_kReset');
  } else {
    print('$_kRed Error: ${res['message']}$_kReset');
  }
}
