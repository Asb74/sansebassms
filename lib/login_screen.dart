import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_screen.dart';
import 'screens/usuario_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _correoController = TextEditingController();
  final TextEditingController _contrasenaController = TextEditingController();
  final TextEditingController _telefonoController = TextEditingController();

  bool _loading = false;
  String? _error;

  Future<void> _iniciarSesion() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final correo = _correoController.text.trim();
    final contrasena = _contrasenaController.text.trim();
    final telefono = _telefonoController.text.trim();

    final prefs = await SharedPreferences.getInstance();
    final yaRegistrado = prefs.getBool("registroRealizado") ?? false;

    // Validaciones
    if (telefono.isEmpty || telefono.length < 9 || !RegExp(r'^\d+$').hasMatch(telefono)) {
      setState(() {
        _error = "📵 Introduce un número de teléfono válido (mínimo 9 dígitos, solo números).";
        _loading = false;
      });
      return;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection("UsuariosAutorizados")
          .get();

      final yaExisteTelefono = snapshot.docs.any((doc) {
        final data = doc.data();
        final t = data["Telefono"];
        return t != null && t == telefono && data["correo"] != correo;
      });

      if (yaExisteTelefono) {
        setState(() {
          _error = "⚠️ Este teléfono ya está registrado con otra cuenta. Contacta con el administrador.";
          _loading = false;
        });
        return;
      }

      final query = await FirebaseFirestore.instance
          .collection("UsuariosAutorizados")
          .where("correo", isEqualTo: correo)
          .where("Contraseña", isEqualTo: contrasena)
          .get();

      if (query.docs.isNotEmpty) {
        final doc = query.docs.first;
        final data = doc.data();

        final permitido = data["Valor"] == true;
        final rol = (data["Rol"] ?? "User").toString().toLowerCase();

        if (!permitido) {
          setState(() {
            _error = "⛔ Tu cuenta aún no está autorizada. Contacta con el administrador.";
            _loading = false;
          });
          return;
        }

        await prefs.setString("correo", correo);
        await prefs.setString("contrasena", contrasena);

        if (mounted) {
          if (rol == "admin") {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const HomeScreen()),
            );
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const UsuarioScreen()),
            );
          }
        }
      } else {
        if (yaRegistrado) {
          setState(() {
            _error = "⚠️ Ya se ha creado una cuenta desde este dispositivo. Contacta con el administrador.";
            _loading = false;
          });
          return;
        }

        final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: correo,
          password: contrasena,
        );

        final uid = cred.user!.uid;

        await FirebaseFirestore.instance
            .collection("UsuariosAutorizados")
            .doc(uid)
            .set({
          "correo": correo,
          "Contraseña": contrasena,
          "Rol": "User",
          "Valor": false,
          "Telefono": telefono,
          "Mensaje": false,
        });

        await prefs.setBool("registroRealizado", true);

        setState(() {
          _error = "✅ Cuenta registrada. Espera la autorización del administrador.";
        });
      }
    } catch (e) {
      setState(() => _error = "❌ Error: ${e.toString()}");
    }

    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("SansebasSms - Iniciar Sesión")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: _correoController,
              decoration: const InputDecoration(labelText: "Correo"),
            ),
            TextField(
              controller: _contrasenaController,
              obscureText: true,
              decoration: const InputDecoration(labelText: "Contraseña"),
            ),
            TextField(
              controller: _telefonoController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: "Teléfono"),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loading ? null : _iniciarSesion,
              child: _loading
                  ? const CircularProgressIndicator()
                  : const Text("Iniciar Sesión"),
            ),
            if (_error != null) ...[
              const SizedBox(height: 20),
              Text(
                _error!,
                style: const TextStyle(color: Colors.red),
              ),
            ]
          ],
        ),
      ),
    );
  }
}
