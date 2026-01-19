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
import 'package:http/http.dart' as http;
import '../client/dart/revani.dart';

const String _kReset = '\x1B[0m';
const String _kBold = '\x1B[1m';
const String _kRed = '\x1B[31m';
const String _kGreen = '\x1B[32m';
const String _kYellow = '\x1B[33m';
const String _kBlue = '\x1B[34m';
const String _kCyan = '\x1B[36m';

void main(List<String> args) async {
  print(
    _kCyan +
        r'''
    ____                      _ 
   / __ \___ _   ______ _____(_)
  / /_/ / _ \ | / / __ `/ __ \ /
 / _, _/  __/ |/ / /_/ / / / / / 
/_/ |_|\___/|___/\__,_/_/ /_/_/  
      EXECUTIVE CONSOLE
''' +
        _kReset,
  );

  final client = RevaniClient(host: '127.0.0.1', port: 16897, secure: true);

  try {
    stdout.write('Connecting to Revani Core... ');
    await client.connect();
    print('$_kGreen Connected.$_kReset');
  } catch (e) {
    print('$_kRed Connection failed: $e$_kReset');
    exit(1);
  }

  await _authenticate(client);
  await _mainMenu(client);
}

Future<void> _authenticate(RevaniClient client) async {
  print('\n$_kBold=== AUTHENTICATION ===$_kReset');

  while (true) {
    print('1. Login as Admin');
    print('2. Create Admin Account (Setup)');
    stdout.write('${_kCyan}Select option: $_kReset');
    final option = stdin.readLineSync()?.trim();

    if (option == '2') {
      await _createFirstAdmin(client);
      continue;
    } else if (option == '1') {
    } else {
      print('${_kRed}Invalid option.$_kReset');
      continue;
    }

    stdout.write('Admin Email: ');
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
        print('${_kGreen}Access Granted.$_kReset');
        break;
      } else {
        print('${_kRed}Access Denied. Wrong email or password.$_kReset');
      }
    } catch (e) {
      print('${_kRed}Login Error: $e$_kReset');
    }
  }
}

Future<void> _createFirstAdmin(RevaniClient client) async {
  print('\n$_kBold=== SETUP ADMIN ===$_kReset');
  print(
    '${_kYellow}Note: If no ADMIN exists in DB, this account will claim control.$_kReset',
  );

  stdout.write('New Admin Email: ');
  final email = stdin.readLineSync()?.trim() ?? '';

  stdout.write('New Password: ');
  stdin.echoMode = false;
  final password = stdin.readLineSync()?.trim() ?? '';
  stdin.echoMode = true;
  print('');

  if (email.isEmpty || password.length < 6) {
    print('${_kRed}Invalid input. Password must be at least 6 chars.$_kReset');
    return;
  }

  try {
    final res = await client.account.create(email, password, {
      'created_via': 'cli_setup',
    });

    if (res['status'] == 200) {
      final role = res['data']['role'];
      if (role == 'admin') {
        print(
          '${_kGreen}SUCCESS! Admin account created. You can now login.$_kReset',
        );
      } else {
        print(
          '${_kRed}FAILED! Account created as "$role". An admin already exists.$_kReset',
        );
      }
    } else {
      print('${_kRed}Failed: ${res['error']}$_kReset');
    }
  } catch (e) {
    print('${_kRed}Error: $e$_kReset');
  }
  print('-----------------------------------');
}

Future<void> _mainMenu(RevaniClient client) async {
  while (true) {
    print('\n$_kBold=== MAIN MENU ===$_kReset');
    print('1. ${_kYellow}Live Monitor$_kReset');
    print('2. User Management');
    print('3. Project Management');
    print('4. Security Management (New)');
    print('5. System Operations');
    print('0. Exit');
    stdout.write('${_kCyan}revani> $_kReset');

    final choice = stdin.readLineSync()?.trim();

    switch (choice) {
      case '1':
        await _monitorMode(client);
        break;
      case '2':
        await _userManagement(client);
        break;
      case '3':
        await _projectManagement(client);
        break;
      case '4':
        await _securityManagement(client);
        break;
      case '5':
        await _systemOperations(client);
        break;
      case '0':
        print('Goodbye.');
        client.disconnect();
        exit(0);
      default:
        print('${_kRed}Invalid option.$_kReset');
    }
  }
}

Future<void> _securityManagement(RevaniClient client) async {
  while (true) {
    print('\n$_kBold=== SECURITY MANAGEMENT ===$_kReset');
    print('1. List Banned IPs');
    print('2. Unban IP');
    print('3. List Whitelist');
    print('4. Add IP to Whitelist');
    print('5. Remove IP from Whitelist');
    print('0. Back');
    stdout.write('${_kCyan}revani/sec> $_kReset');

    final choice = stdin.readLineSync()?.trim();
    if (choice == '0') break;

    switch (choice) {
      case '1':
        final res = await client.execute({
          'cmd': 'admin/security/ban-list',
          'accountID': client.accountID,
        });
        _handleResponse(res);
        break;
      case '2':
        stdout.write('IP to Unban: ');
        final ip = stdin.readLineSync()!.trim();
        final res = await client.execute({
          'cmd': 'admin/security/unban',
          'accountID': client.accountID,
          'targetIp': ip,
        });
        print(res['message']);
        break;
      case '3':
        final res = await client.execute({
          'cmd': 'admin/security/whitelist-list',
          'accountID': client.accountID,
        });
        if (res['status'] == 200) {
          final list = (res['data'] as List).map((ip) => {'ip': ip}).toList();
          _printTable(list);
        }
        break;
      case '4':
        stdout.write('IP to Whitelist: ');
        final ip = stdin.readLineSync()!.trim();
        final res = await client.execute({
          'cmd': 'admin/security/whitelist-add',
          'accountID': client.accountID,
          'targetIp': ip,
        });
        print(res['message']);
        break;
      case '5':
        stdout.write('IP to Remove from Whitelist: ');
        final ip = stdin.readLineSync()!.trim();
        final res = await client.execute({
          'cmd': 'admin/security/whitelist-remove',
          'accountID': client.accountID,
          'targetIp': ip,
        });
        print(res['message']);
        break;
    }
  }
}

Future<void> _monitorMode(RevaniClient client) async {
  print('\n$_kBold=== LIVE MONITOR (Ctrl+C to exit) ===$_kReset');
  print('Fetching stats from REST API (Port 16898)...');

  bool running = true;

  ProcessSignal.sigint.watch().listen((_) {
    running = false;
  });

  try {
    while (running) {
      final response = await http.get(
        Uri.parse('http://127.0.0.1:16898/stats'),
      );
      if (response.statusCode == 200) {
        final stats = jsonDecode(response.body);
        print('\x1B[2J\x1B[0;0H');
        print('$_kBold=== REVANI LIVE MONITOR ===$_kReset');
        print('Time: ${DateTime.now()}');
        print('---------------------------');
        print('Total Records : $_kGreen${stats['total_records']}$_kReset');
        print('Active Buckets: $_kBlue${stats['buckets_count']}$_kReset');
        print('---------------------------');
        print('Press Ctrl+C to stop monitoring (will exit app)');
      }
      await Future.delayed(Duration(seconds: 1));
    }
  } catch (e) {
    print('${_kRed}Monitor Error: $e$_kReset');
    print('Make sure REST server is running on port 16898.');
  }
}

Future<void> _userManagement(RevaniClient client) async {
  while (true) {
    print('\n$_kBold=== USER MANAGEMENT ===$_kReset');
    print('1. List Users');
    print('2. Create User');
    print('3. Change User Role');
    print('4. Delete User');
    print('0. Back');
    stdout.write('${_kCyan}revani/users> $_kReset');

    final choice = stdin.readLineSync()?.trim();
    if (choice == '0') break;

    switch (choice) {
      case '1':
        final res = await client.execute({
          'cmd': 'admin/users/list',
          'accountID': client.accountID,
        });
        _handleResponse(res);
        break;
      case '2':
        stdout.write('Email: ');
        final email = stdin.readLineSync()!.trim();
        stdout.write('Password: ');
        final pass = stdin.readLineSync()!.trim();
        await client.account.create(email, pass, {'created_via': 'cli'});
        print('${_kGreen}User created.$_kReset');
        break;
      case '3':
        final listRes = await client.execute({
          'cmd': 'admin/users/list',
          'accountID': client.accountID,
        });

        if (!_handleResponse(listRes)) break;

        stdout.write('\nTarget User ID: ');
        final uid = stdin.readLineSync()!.trim();
        if (uid.isEmpty) break;

        stdout.write('New Role (user/gold/premium/admin): ');
        final role = stdin.readLineSync()!.trim();

        final res = await client.execute({
          'cmd': 'admin/users/set-role',
          'accountID': client.accountID,
          'targetId': uid,
          'newRole': role,
        });
        print(res['message']);
        break;
      case '4':
        final listResDel = await client.execute({
          'cmd': 'admin/users/list',
          'accountID': client.accountID,
        });
        if (!_handleResponse(listResDel)) break;

        stdout.write('\nTarget User ID to DELETE: ');
        final uid = stdin.readLineSync()!.trim();
        if (uid.isEmpty) break;

        stdout.write('Are you sure? (y/N): ');
        if (stdin.readLineSync()!.trim().toLowerCase() == 'y') {
          final res = await client.execute({
            'cmd': 'admin/users/delete',
            'accountID': client.accountID,
            'targetId': uid,
          });
          print(res['message']);
        }
        break;
    }
  }
}

Future<void> _projectManagement(RevaniClient client) async {
  print('\n$_kBold=== PROJECT MANAGEMENT ===$_kReset');
  final res = await client.execute({
    'cmd': 'admin/projects/list',
    'accountID': client.accountID,
  });
  _handleResponse(res);
}

Future<void> _systemOperations(RevaniClient client) async {
  print('\n$_kBold=== SYSTEM OPERATIONS ===$_kReset');
  print('1. Force Garbage Collection');
  print('0. Back');
  stdout.write('${_kCyan}revani/sys> $_kReset');

  final choice = stdin.readLineSync()?.trim();
  if (choice == '1') {
    final res = await client.execute({
      'cmd': 'admin/system/force-gc',
      'accountID': client.accountID,
    });
    if (res['status'] == 200) {
      print('$_kGreen${res['message']}$_kReset');
    } else {
      print('$_kRed${res['message']}$_kReset');
    }
  }
}

bool _handleResponse(Map<String, dynamic> res) {
  if (res['status'] == 200) {
    _printTable(res['data'] ?? []);
    return true;
  } else {
    print('${_kRed}ERROR ${res['status']}: ${res['message']}$_kReset');
    if (res['status'] == 403) {
      print('${_kYellow}Hint: You are logged in, but not as an Admin.$_kReset');
    }
    return false;
  }
}

void _printTable(List<dynamic> data) {
  if (data.isEmpty) {
    print('${_kYellow}No data found in this category.$_kReset');
    return;
  }

  final headers = data.first.keys.toList();
  final colWidths = <String, int>{};

  for (var h in headers) {
    colWidths[h] = h.length;
  }

  for (var row in data) {
    for (var h in headers) {
      final val = row[h].toString();
      if (val.length > (colWidths[h] ?? 0)) {
        colWidths[h] = val.length;
      }
    }
  }

  var headerRow = '';
  var separator = '';
  for (var h in headers) {
    final w = colWidths[h]! + 2;
    headerRow += h.padRight(w);
    separator += '-' * w;
  }

  print(_kYellow + headerRow + _kReset);
  print(separator);

  for (var row in data) {
    var line = '';
    for (var h in headers) {
      final w = colWidths[h]! + 2;
      line += row[h].toString().padRight(w);
    }
    print(line);
  }
  print(separator);
  print('Total: ${data.length} rows.');
}
