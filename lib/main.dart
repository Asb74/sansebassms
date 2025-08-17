import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_core/firebase_core.dart';

import 'home_screen.dart';

class AppLogger {
  static File? _file;

  static Future<File> _ensureFile() async {
    if (_file != null) return _file!;
    final dir = await getApplicationDocumentsDirectory();
    _file = File('${dir.path}/app_logs.txt');
    if (!(await _file!.exists())) {
      await _file!.create(recursive: true);
    }
    return _file!;
  }

  static Future<void> log(String message, [Object? error, StackTrace? stack]) async {
    final f = await _ensureFile();
    final now = DateTime.now().toIso8601String();
    final lines = [
      '[$now] $message',
      if (error != null) 'ERROR: $error',
      if (stack != null) 'STACK: $stack',
    ];
    final txt = lines.join('\n') + '\n';
    // consola
    debugPrint(txt);
    // archivo
    await f.writeAsString(txt, mode: FileMode.append, flush: true);
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppLogger.log('App start: inicializando Firebase');

  FlutterError.onError = (FlutterErrorDetails details) async {
    FlutterError.presentError(details);
    await AppLogger.log('FlutterError', details.exception, details.stack);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    AppLogger.log('Zoned error', error, stack);
    return false;
  };

  bool firebaseOK = false;
  Object? initError;
  StackTrace? initStack;

  try {
    await Firebase.initializeApp();
    firebaseOK = true;
    await AppLogger.log('Firebase inicializado OK');
  } catch (e, s) {
    firebaseOK = false;
    initError = e;
    initStack = s;
    await AppLogger.log('Error al inicializar Firebase', e, s);
  }

  runApp(MyApp(firebaseOK: firebaseOK, initError: initError, initStack: initStack));
}

class MyApp extends StatelessWidget {
  final bool firebaseOK;
  final Object? initError;
  final StackTrace? initStack;

  const MyApp({super.key, required this.firebaseOK, this.initError, this.initStack});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'App',
      home: firebaseOK ? const HomeScreen() : ErrorScreen(error: initError),
    );
  }
}

class ErrorScreen extends StatelessWidget {
  final Object? error;
  const ErrorScreen({super.key, this.error});

  @override
  Widget build(BuildContext context) {
    final errText = (error ?? 'Error desconocido').toString();
    return Scaffold(
      appBar: AppBar(title: const Text('Error inicializando Firebase')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(errText),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LogsScreen()));
              },
              child: const Text('Ver logs'),
            ),
          ],
        ),
      ),
    );
  }
}

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});
  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  String _logs = 'Cargando...';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final f = File('${dir.path}/app_logs.txt');
      final txt = await f.exists() ? await f.readAsString() : '(Sin logs)';
      setState(() => _logs = txt);
    } catch (e, s) {
      await AppLogger.log('Error leyendo logs', e, s);
      setState(() => _logs = 'Error leyendo logs: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Logs de la app')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: SelectableText(_logs),
      ),
    );
  }
}
