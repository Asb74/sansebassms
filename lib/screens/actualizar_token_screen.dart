import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ActualizarTokenScreen extends StatefulWidget {
  const ActualizarTokenScreen({super.key});

  @override
  State<ActualizarTokenScreen> createState() => _ActualizarTokenScreenState();
}

class _ActualizarTokenScreenState extends State<ActualizarTokenScreen> {
  bool _cargando = false;
  String? _mensaje;

  Future<void> _actualizarToken() async {
    setState(() {
      _cargando = true;
      _mensaje = null;
    });

    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        setState(() {
          _mensaje = "🔇 Permiso de notificaciones denegado.";
        });
        return;
      }

      if (Platform.isIOS) {
        try {
          await messaging.getAPNSToken().timeout(const Duration(seconds: 5));
        } catch (_) {
          setState(() {
            _mensaje =
                "⚠️ No se pudo obtener el token de notificaciones.";
          });
          return;
        }
      }

      final token = await messaging
          .getToken()
          .timeout(const Duration(seconds: 5), onTimeout: () => null);

      if (token == null) {
        setState(() {
          _mensaje =
              "⚠️ No se pudo generar el token. Inténtalo de nuevo más tarde.";
        });
        return;
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _mensaje = "⚠️ Usuario no autenticado.";
        });
        return;
      }

      await FirebaseFirestore.instance
          .collection("UsuariosAutorizados")
          .doc(user.uid)
          .update({"fcmToken": token, "tokenPendiente": false});

      setState(() {
        _mensaje = "✅ Token actualizado correctamente.";
      });
    } catch (e) {
      setState(() {
        _mensaje = "❌ Error: ${e.toString()}";
      });
    } finally {
      setState(() {
        _cargando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Actualizar token")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: _cargando ? null : _actualizarToken,
              child: _cargando
                  ? const CircularProgressIndicator()
                  : const Text("Actualizar token"),
            ),
            const SizedBox(height: 20),
            if (_mensaje != null)
              Text(
                _mensaje!,
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
    );
  }
}
