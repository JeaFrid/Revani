/*
 * Copyright (C) 2026 JeaFriday (https://github.com/JeaFrid/Revani)
 * This project is part of Revani
 * Licensed under the GNU Affero General Public License v3.0 (AGPL-3.0).
 * See the LICENSE file in the project root for full license information.
 * For commercial licensing, please contact: JeaFriday
 */
import 'dart:io';
import 'dart:async';
import 'package:args/args.dart';
import '../client/dart/revani.dart';

const String _kReset = '\x1B[0m';
const String _kBold = '\x1B[1m';
const String _kRed = '\x1B[31m';
const String _kGreen = '\x1B[32m';
const String _kYellow = '\x1B[33m';
const String _kMagenta = '\x1B[35m';

void main(List<String> arguments) async {
  final parser = ArgParser()
    ..addFlag('local', abbr: 'l', defaultsTo: false)
    ..addOption('host', abbr: 'h')
    ..addOption('port', abbr: 'p');

  ArgResults argResults = parser.parse(arguments);
  String host = argResults['host'] ?? '127.0.0.1';
  int port = int.tryParse(argResults['port'] ?? '16897') ?? 16897;

  print(
    _kMagenta +
        r'''
    ____                    _   
   / __ \___ _      ______ _____(_)  
  / /_/ / _ \ | / / __ `/ __ \ /  
 / _, _/  __/ |/ / /_/ / / / / /  
/_/ |_|\___/|___/\__,_/_/ /_/_/   
            EXECUTIVE
''' +
        _kReset,
  );

  final client = RevaniClient(host: host, port: port, secure: true);

  try {
    stdout.write('Connecting to $host:$port... ');
    await client.connect();
    print('$_kGreen Connected.$_kReset');
  } catch (e) {
    print('$_kRed Connection failed: $e$_kReset');
    exit(1);
  }

  await _authMenu(client);
}

Future<void> _authMenu(RevaniClient client) async {
  while (true) {
    print('\n$_kBold=== REVANI AUTHENTICATION ===$_kReset');
    print('1. Login');
    print('2. Register (First Admin Setup)');
    print('0. Exit');
    stdout.write('${_kYellow}auth> $_kReset');

    final choice = stdin.readLineSync()?.trim();

    if (choice == '1') {
      if (await _login(client)) {
        await _userLoop(client);
      }
    } else if (choice == '2') {
      await _register(client);
    } else if (choice == '0') {
      exit(0);
    }
  }
}

Future<void> _register(RevaniClient client) async {
  print('\n$_kBold--- CREATE ADMIN ACCOUNT ---$_kReset');
  stdout.write('Email: ');
  final email = stdin.readLineSync()?.trim() ?? '';
  stdout.write('Password: ');
  stdin.echoMode = false;
  final password = stdin.readLineSync()?.trim() ?? '';
  stdin.echoMode = true;
  print('');

  final res = await client.account.create(
    email,
    password,
    data: {'role': 'root'},
  );

  if (res.isSuccess) {
    print('$_kGreen Account created. Now try to login.$_kReset');
  } else {
    print('$_kRed Registration failed: ${res.message}$_kReset');
  }
}

Future<bool> _login(RevaniClient client) async {
  stdout.write('Email: ');
  final email = stdin.readLineSync()?.trim() ?? '';
  stdout.write('Password: ');
  stdin.echoMode = false;
  final password = stdin.readLineSync()?.trim() ?? '';
  stdin.echoMode = true;
  print('');

  try {
    final res = await client.account.login(email, password);
    if (res.isSuccess) {
      final checkRole = await client.execute({
        'cmd': 'admin/stats/full',
        'accountID': client.accountID,
      });

      if (checkRole.status == 401) {
        print('$_kYellow[WARNING] Login success but not an admin yet.$_kReset');
        print('Check your server logs to promote this ID: ${client.accountID}');
        return true;
      }

      print('$_kGreen Login Successful.$_kReset');
      return true;
    } else {
      print('$_kRed Access Denied: ${res.message}$_kReset');
      return false;
    }
  } catch (e) {
    print('$_kRed Error: $e$_kReset');
    return false;
  }
}

Future<void> _userLoop(RevaniClient client) async {
  String? activeProject;
  while (true) {
    print('\n$_kBold=== DASHBOARD (${client.accountID}) ===$_kReset');
    print('1. Create Project  2. Select Project  0. Logout');
    stdout.write('${_kYellow}console> $_kReset');
    final choice = stdin.readLineSync()?.trim();
    if (choice == '0') break;
    if (choice == '1') await _createProject(client);
    if (choice == '2') activeProject = await _selectProject(client);
  }
}

Future<void> _createProject(RevaniClient client) async {
  stdout.write('Project Name: ');
  final name = stdin.readLineSync()?.trim();
  if (name == null || name.isEmpty) return;
  final res = await client.project.create(name);
  print(
    res.isSuccess
        ? '$_kGreen Success$_kReset'
        : '$_kRed ${res.message}$_kReset',
  );
}

Future<String?> _selectProject(RevaniClient client) async {
  stdout.write('Project Name: ');
  final name = stdin.readLineSync()?.trim();
  if (name == null || name.isEmpty) return null;
  final res = await client.project.use(name);
  return res.isSuccess ? name : null;
}
