import 'dart:io';
import 'dart:async';
import 'package:args/args.dart';
import 'revani.dart';

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
      if (await _manualLogin(client)) {
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
  print('\n$_kBold--- CREATE ACCOUNT ---$_kReset');
  stdout.write('Email: ');
  final email = stdin.readLineSync()?.trim() ?? '';
  stdout.write('Password: ');
  stdin.echoMode = false;
  final password = stdin.readLineSync()?.trim() ?? '';
  stdin.echoMode = true;
  print('');

  final res = await client.account.create(email, password);

  if (res.isSuccess) {
    print('$_kGreen ${res.message}. Now try to login.$_kReset');
  } else {
    print('$_kRed Registration failed: ${res.error ?? res.message}$_kReset');
  }
}

Future<bool> _manualLogin(RevaniClient client) async {
  stdout.write('Email: ');
  final email = stdin.readLineSync()?.trim() ?? '';
  stdout.write('Password: ');
  stdin.echoMode = false;
  final password = stdin.readLineSync()?.trim() ?? '';
  stdin.echoMode = true;
  print('');

  try {
    final loginRes = await client.account.login(email, password);

    if (loginRes.isSuccess) {
      print('$_kGreen Login Successful. Session established.$_kReset');

      final checkRole = await client.execute({
        'cmd': 'admin/stats/full',
        'accountID': client.accountID,
      });

      if (checkRole.status == 200) {
        print('$_kGreen Welcome, Administrator.$_kReset');
      } else {
        print('$_kYellow[NOTICE] Logged in as User (No admin access).$_kReset');
      }
      return true;
    }

    print('$_kRed Access Denied: ${loginRes.message}$_kReset');
    return false;
  } catch (e) {
    print('$_kRed Error during login: $e$_kReset');
    return false;
  }
}

Future<void> _userLoop(RevaniClient client) async {
  while (true) {
    print('\n$_kBold=== DASHBOARD (${client.accountID}) ===$_kReset');
    print('1. Create Project  2. Select Project  0. Logout');
    stdout.write('${_kYellow}console> $_kReset');
    final choice = stdin.readLineSync()?.trim();
    if (choice == '0') {
      client.logout();
      break;
    }
    if (choice == '1') await _createProject(client);
    if (choice == '2') await _selectProject(client);
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

Future<void> _selectProject(RevaniClient client) async {
  stdout.write('Project Name: ');
  final name = stdin.readLineSync()?.trim();
  if (name == null || name.isEmpty) return;
  final res = await client.project.use(name);
  if (res.isSuccess) {
    print('$_kGreen Project active.$_kReset');
  } else {
    print('$_kRed Error: ${res.message}$_kReset');
  }
}
