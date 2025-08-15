import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'login_screen.dart';
import 'home_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/usuario_screen.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await _initNotifications();
  runApp(const SansebasSmsApp());
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

class SansebasSmsApp extends StatelessWidget {
  const SansebasSmsApp({super.key});

  Future<Widget> _decidirPantallaInicial() async {
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
      home: FutureBuilder<Widget>(
        future: _decidirPantallaInicial(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const SplashScreen();
          return snapshot.data!;
        },
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}
