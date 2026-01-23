import 'dart:io';
import 'dart:async';

const String _kReset = '\x1B[0m';
const String _kBold = '\x1B[1m';
const String _kRed = '\x1B[31m';
const String _kGreen = '\x1B[32m';
const String _kYellow = '\x1B[33m';
const String _kCyan = '\x1B[36m';

const String logFile = 'revani.log';
const String pidFile = 'server.pid';
const String binaryPath = 'bin/server.exe';

void main() async {
  while (true) {
    print('\x1B[2J\x1B[0;0H');
    print(
      _kCyan +
          r'''
    ____                        _   
   / __ \___ _   ______ _____  (_)  
  / /_/ / _ \ | / / __ `/ __ \/ /   
 / _, _/  __/ |/ / /_/ / / / / /    
/_/ |_|\___/|___/\__,_/_/ /_/_/     
        SERVER MANAGER
''' +
          _kReset,
    );

    print('1. ${_kGreen}Start Test Mode (JIT)$_kReset');
    print('2. ${_kGreen}Start Live Mode (AOT Compilation)$_kReset');
    print('3. ${_kYellow}Watch Logs$_kReset');
    print('4. ${_kRed}Stop Server$_kReset');
    print('5. ${_kRed}UNINSTALL SYSTEM$_kReset');
    print('6. ${_kCyan}UPDATE SYSTEM$_kReset');
    print('7. ${_kYellow}Clean Database$_kReset');
    print('0. Exit');

    stdout.write('\n${_kBold}Choice: $_kReset');
    String? choice = stdin.readLineSync()?.trim();

    switch (choice) {
      case '1':
        await _startTestMode();
        break;
      case '2':
        await _startLiveMode();
        break;
      case '3':
        await _watchLogs();
        break;
      case '4':
        await _stopServer();
        break;
      case '5':
        await _uninstallSystem();
        break;
      case '6':
        await _updateSystem();
        break;
      case '7':
        await _cleanDatabase();
        break;
      case '0':
        exit(0);
      default:
        print('Invalid selection.');
        sleep(Duration(seconds: 1));
    }

    if (choice != '1' && choice != '3') {
      stdout.write('\nPress ENTER to continue...');
      stdin.readLineSync();
    }
  }
}

Future<void> _startTestMode() async {
  print('\n$_kGreen[TEST MODE] Starting via JIT...$_kReset');
  print('Use CTRL+C to exit.\n');

  var process = await Process.start('dart', [
    'run',
    'bin/server.dart',
  ], mode: ProcessStartMode.inheritStdio);
  await process.exitCode;
}

Future<void> _startLiveMode() async {
  print('\n$_kCyan[BUILD] Compiling to AOT binary for performance...$_kReset');

  var compileResult = await Process.run('dart', [
    'compile',
    'exe',
    'bin/server.dart',
    '-o',
    binaryPath,
  ]);

  if (compileResult.exitCode != 0) {
    print('$_kRed[ERROR] Compilation failed: ${compileResult.stderr}$_kReset');
    return;
  }

  print('$_kGreen[SUCCESS] Compilation complete.$_kReset');

  if (File(pidFile).existsSync()) {
    print(
      '$_kRed[WARNING] Server might already be running ($pidFile exists).$_kReset',
    );
    return;
  }

  var shellCmd = 'nohup ./$binaryPath > $logFile 2>&1 & echo \$! > $pidFile';

  await Process.run('bash', ['-c', shellCmd]);

  print('$_kGreen[SUCCESS] AOT Server started in background.$_kReset');
  print('Log file: $logFile');
  print('PID file: $pidFile');

  sleep(Duration(seconds: 1));
  if (File(pidFile).existsSync()) {
    String pid = File(pidFile).readAsStringSync().trim();
    print('Process ID: $pid');
  }
}

Future<void> _watchLogs() async {
  print('\n$_kYellow[LOGS] Watching logs (CTRL+C to exit)...$_kReset');

  var process = await Process.start('tail', [
    '-f',
    logFile,
  ], mode: ProcessStartMode.inheritStdio);
  await process.exitCode;
}

Future<void> _stopServer() async {
  print('\n$_kRed[STOP] Stopping server...$_kReset');

  if (!File(pidFile).existsSync()) {
    print(
      '$_kYellow[INFO] PID file not found. Trying manual search...$_kReset',
    );
    await Process.run('pkill', ['-f', binaryPath]);
    await Process.run('pkill', ['-f', 'dart run bin/server.dart']);
    print('$_kGreen[SUCCESS] Revani processes terminated.$_kReset');
    return;
  }

  try {
    String pid = File(pidFile).readAsStringSync().trim();
    var result = await Process.run('kill', [pid]);

    if (result.exitCode == 0) {
      print('$_kGreen[SUCCESS] Process ($pid) stopped.$_kReset');
      if (File(pidFile).existsSync()) File(pidFile).deleteSync();
    } else {
      print(
        '$_kRed[ERROR] Could not stop process. Terminating manually...$_kReset',
      );
      await Process.run('pkill', ['-f', binaryPath]);
      if (File(pidFile).existsSync()) File(pidFile).deleteSync();
    }
  } catch (e) {
    print('Error: $e');
  }
}

Future<void> _uninstallSystem() async {
  print('\n$_kRed${'=' * 40}');
  print(' WARNING: THIS ACTION CANNOT BE UNDONE!');
  print('=' * 40 + _kReset);
  print('This action will delete:');
  print('1. The current Revani folder');
  print('2. AND THE PARENT DIRECTORY completely.');

  stdout.write('\nType "DELETE" to continue: ');
  var confirm1 = stdin.readLineSync();

  if (confirm1 != 'DELETE') {
    print('Cancelled.');
    return;
  }

  stdout.write(
    '$_kRed[FINAL WARNING] Are you absolutely sure? (yes/no): $_kReset',
  );
  var confirm2 = stdin.readLineSync();

  if (confirm2?.toLowerCase() != 'yes') {
    print('Cancelled.');
    return;
  }

  print('\n$_kYellow[DELETING] Self-destruct sequence initiated...$_kReset');

  await _stopServer();

  var currentDir = Directory.current.path;
  var parentDir = Directory.current.parent.path;

  print('Target: $currentDir and parent $parentDir');

  var destroyerScript =
      '''
#!/bin/bash
sleep 2
echo "Deleting Revani Files..."
rm -rf "$currentDir"
echo "Deleting Parent Directory..."
rm -rf "$parentDir"
echo "Cleanup Complete. Goodbye."
''';

  var tmpScript = File('/tmp/revani_destroyer.sh');
  await tmpScript.writeAsString(destroyerScript);
  await Process.run('chmod', ['+x', '/tmp/revani_destroyer.sh']);

  print(
    '$_kRed[BYE] System will be deleted in 2 seconds. Console closing.$_kReset',
  );

  await Process.start('bash', [
    '/tmp/revani_destroyer.sh',
  ], mode: ProcessStartMode.detached);
  exit(0);
}

Future<void> _updateSystem() async {
  print('\n$_kCyan[UPDATE] Updating system...$_kReset');

  print('[@] Backing up configuration files...');
  bool hasConfig = await File('lib/config.dart').exists();
  bool hasEnv = await File('.env').exists();

  if (hasConfig) await File('lib/config.dart').copy('/tmp/revani_config.bak');
  if (hasEnv) await File('.env').copy('/tmp/revani_env.bak');

  print('[@] Fetching data from GitHub...');

  var gitCheck = await Process.run('git', ['status']);
  if (gitCheck.exitCode != 0) {
    print(
      '$_kRed[ERROR] Not a git repository. Did you install via "git clone"?$_kReset',
    );
    return;
  }

  await Process.run('git', ['fetch', '--all']);
  var resetRes = await Process.run('git', ['reset', '--hard', 'origin/main']);

  if (resetRes.exitCode == 0) {
    print('$_kGreen[SUCCESS] Files updated.$_kReset');
  } else {
    print('$_kRed[ERROR] Git update failed: ${resetRes.stderr}$_kReset');
  }

  print('[@] Restoring configurations...');
  if (hasConfig) {
    await File('/tmp/revani_config.bak').copy('lib/config.dart');
    print(' - lib/config.dart restored.');
  }
  if (hasEnv) {
    await File('/tmp/revani_env.bak').copy('.env');
    print(' - .env restored.');
  }

  print('[@] Updating dependencies (dart pub get)...');
  await Process.run('dart', ['pub', 'get']);

  print(
    '\n$_kGreen[COMPLETE] System updated. Please restart the server (Option 4 -> Option 2).$_kReset',
  );
}

Future<void> _cleanDatabase() async {
  print('\n$_kRed[CLEANUP] Deleting database and cache...$_kReset');

  stdout.write('Are you sure? All data will be lost (y/n): ');
  var confirm = stdin.readLineSync();
  if (confirm?.toLowerCase() != 'y') return;

  if (File(pidFile).existsSync()) {
    print(
      '$_kYellow[WARNING] Server seems to be running. Stopping first...$_kReset',
    );
    await _stopServer();
  }

  List<String> filesToDelete = [
    'revani.db',
    'revani.db.lock',
    'revani.db.compact',
    'revani.log',
    pidFile,
    binaryPath,
  ];

  for (var f in filesToDelete) {
    var file = File(f);
    if (await file.exists()) {
      await file.delete();
      print(' - Deleted: $f');
    }
  }

  var dartTool = Directory('.dart_tool');
  if (await dartTool.exists()) {
    await dartTool.delete(recursive: true);
    print(' - Deleted: .dart_tool/');
  }

  var storageDir = Directory('storage');
  if (await storageDir.exists()) {
    stdout.write('Delete storage (files) folder as well? (y/n): ');
    if (stdin.readLineSync()?.toLowerCase() == 'y') {
      await storageDir.delete(recursive: true);
      print(' - Deleted: storage/');
    }
  }

  print('$_kGreen[SUCCESS] Bakery cleaned.$_kReset');
}
