import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:provider/provider.dart';

import 'data/app_database.dart';

import 'login_screen.dart';
import 'home_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/usuario_screen.dart';
import 'debug/log_buffer.dart';
import 'debug/log_console.dart';
import 'app_state.dart';
import 'services/logger.dart';
import 'widgets/error_banner.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

const bool runningWithoutFirebase =
    bool.fromEnvironment('NO_FIREBASE', defaultValue: false);
const bool kShowLogButton =
    bool.fromEnvironment('SHOW_LOG', defaultValue: true);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  installGlobalLogCapture();
  final logger = LoggingService.instance;
  final appState = AppState();

  runZonedGuarded(() async {
    FlutterError.onError = (details) {
      logger.error('FlutterError', details.exception, details.stack);
      try {
        FirebaseCrashlytics.instance.recordFlutterError(details);
      } catch (_) {}
    };

    await _initFirebase(appState, logger);
    await _initNotifications();
    await Hive.initFlutter();

    runApp(
      ChangeNotifierProvider.value(
        value: appState,
        child: FirstFrameGate(child: const MyApp()),
      ),
    );
  }, (error, stack) {
    logger.error('Uncaught zone error', error, stack);
    try {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    } catch (_) {}
  }, zoneSpecification: ZoneSpecification(print: (self, parent, zone, line) {
    LogBuffer.I.add(line);
    parent.print(zone, line);
  }));
}

Future<void> _initFirebase(AppState state, LoggingService logger) async {
  if (runningWithoutFirebase) {
    logger.info('Running without Firebase (NO_FIREBASE=true)');
    return;
  }
  try {
    final init = Firebase.initializeApp();
    await init.timeout(const Duration(seconds: 10));
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
    state.setFirebaseAvailable(true);
    logger.info('Firebase initialized');
  } catch (e, st) {
    state.setFirebaseAvailable(false, error: e.toString());
    logger.error('Firebase init failed', e, st);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = navigatorKey.currentContext;
      if (ctx != null) {
        ErrorBanner.show(ctx,
            message: 'Firebase no disponible',
            details: e.toString(),
            error: e,
            stackTrace: st,
            onRetry: () => _initFirebase(state, logger));
      }
    });
  }
}

Future<void> _initNotifications() async {
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosSettings = DarwinInitializationSettings();
  const initSettings = InitializationSettings(
    android: androidSettings,
    iOS: iosSettings,
  );
  try {
    await flutterLocalNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        if (response.payload == "abrir_usuario_screen") {
          navigatorKey.currentState?.pushNamed("/usuario");
        }
      },
    );
  } catch (e) {
    // Avoid blocking app startup if notifications fail to initialize
    debugPrint('Notification init failed: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Future<Widget> _decidirPantallaInicial() async {
    final db = await AppDatabase.instance.database;
    await db.rawQuery('SELECT 1');
    debugPrint('DB warmup complete');

    final prefs = await SharedPreferences.getInstance();
    final correo = prefs.getString("correo");
    final contrasena = prefs.getString("contrasena");
    await Future.delayed(const Duration(milliseconds: 1500));

    if (correo != null && contrasena != null) {
      final query = await FirebaseFirestore.instance
          .collection("UsuariosAutorizados")
          .where("correo", isEqualTo: correo)
          .get();

      if (query.docs.isNotEmpty) {
        final doc = query.docs.first;
        final data = doc.data();
        final rol = (data["Rol"] ?? "user").toString().toLowerCase();
        final permitido = data["Valor"] == true;

        if (!permitido) return const LoginScreen();

        // ✅ Actualizar token FCM
        try {
          final user = FirebaseAuth.instance.currentUser;
          final uid = user?.uid ?? doc.id;

          final token = await FirebaseMessaging.instance.getToken();
          if (token != null) {
            await FirebaseFirestore.instance
                .collection("UsuariosAutorizados")
                .doc(uid)
                .update({"fcmToken": token});
          }

          // 🔁 Escuchar cambios futuros del token
          FirebaseMessaging.instance.onTokenRefresh.listen((nuevoToken) async {
            await FirebaseFirestore.instance
                .collection("UsuariosAutorizados")
                .doc(uid)
                .update({"fcmToken": nuevoToken});
          });
        } catch (e) {
          print("⚠️ No se pudo actualizar el token FCM: $e");
        }

        if (rol == "admin") return const HomeScreen();
        return const UsuarioScreen();
      }
    }

    return const LoginScreen();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SansebasSms',
      navigatorKey: navigatorKey,
      theme: ThemeData(
        primarySwatch: Colors.green,
        useMaterial3: true,
      ),
      routes: {
        '/usuario': (_) => const UsuarioScreen(),
      },
      home: Stack(
        children: [
          FutureBuilder<Widget>(
            future: _decidirPantallaInicial(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SplashScreen();
              return snapshot.data!;
            },
          ),
          if (kShowLogButton)
            Positioned(
              right: 12,
              bottom: 24,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => const LogConsole())),
                child: const Text('Ver registro'),
              ),
            ),
        ],
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}

class FirstFrameGate extends StatefulWidget {
  const FirstFrameGate({super.key, required this.child});
  final Widget child;

  @override
  State<FirstFrameGate> createState() => _FirstFrameGateState();
}

class _FirstFrameGateState extends State<FirstFrameGate> {
  bool _firstFrameSeen = false;
  bool _timeout = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _firstFrameSeen = true;
    });
    Timer(const Duration(seconds: 5), () {
      if (!_firstFrameSeen && mounted) {
        setState(() => _timeout = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_timeout && !_firstFrameSeen) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text(
                'Diagnóstico: no se pintó el primer frame.\nRevisa inicialización de DB y logs.'),
          ),
        ),
      );
    }
    return widget.child;
  }
}
