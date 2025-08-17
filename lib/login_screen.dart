import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'home_screen.dart';
import 'screens/usuario_screen.dart';
import 'data/bootstrap_repo.dart';
import 'widgets/error_banner.dart';
import 'services/logger.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _correoController = TextEditingController();
  final TextEditingController _contrasenaController = TextEditingController();
  final TextEditingController _confirmarContrasenaController = TextEditingController();
  final TextEditingController _telefonoController = TextEditingController();
  final TextEditingController _dniController = TextEditingController();

  bool _loading = false;
  String? _error;
  String? _textoLPD;
  bool _aceptaLPD = false;
  String? _lpdError;

  @override
  void initState() {
    super.initState();
    _cargarTextoLPD();
  }

  Future<void> _cargarTextoLPD() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection("LPD")
          .doc("Login")
          .get()
          .timeout(const Duration(seconds: 8));

      if (doc.exists) {
        setState(() {
          _textoLPD = doc.data()?["Autorizacion"] ?? "";
        });
        return;
      }
    } catch (e, st) {
      LoggingService.instance
          .error('Error cargando consentimiento', e, st);
      if (mounted) {
        ErrorBanner.show(context,
            message: 'Firebase no disponible (timeout)',
            details: e.toString(),
            error: e,
            stackTrace: st,
            onRetry: _cargarTextoLPD);
      }
    }
    setState(() {
      _textoLPD = null;
    });
  }

  bool esDniValido(String dni) {
    final letras = 'TRWAGMYFPDXBNJZSQVHLCKE';
    String numero = dni.toUpperCase().trim();

    if (!RegExp(r'^[XYZ\d]\d{7}[A-Z]$').hasMatch(numero)) return false;

    if (numero.startsWith('X')) {
      numero = numero.replaceFirst('X', '0');
    } else if (numero.startsWith('Y')) {
      numero = numero.replaceFirst('Y', '1');
    } else if (numero.startsWith('Z')) {
      numero = numero.replaceFirst('Z', '2');
    }

    final numeroSinLetra = int.tryParse(numero.substring(0, 8));
    final letraEsperada = letras[numeroSinLetra! % 23];

    return letraEsperada == numero[8];
  }

  Future<void> _iniciarSesion() async {
    setState(() {
      _loading = true;
      _error = null;
      _lpdError = null;
    });

    final correo = _correoController.text.trim();
    final contrasena = _contrasenaController.text.trim();
    final confirmarContrasena = _confirmarContrasenaController.text.trim();
    final telefono = _telefonoController.text.trim();
    final dni = _dniController.text.trim().toUpperCase();

    final prefs = await SharedPreferences.getInstance();
    final yaRegistrado = prefs.getBool("registroRealizado") ?? false;

    if (telefono.isEmpty || telefono.length < 9 || !RegExp(r'^\d+$').hasMatch(telefono)) {
      setState(() {
        _error = "📵 Introduce un número de teléfono válido (mínimo 9 dígitos, solo números).";
        _loading = false;
      });
      return;
    }

    if (contrasena != confirmarContrasena) {
      setState(() {
        _error = "🔐 Las contraseñas no coinciden.";
        _loading = false;
      });
      return;
    }

    if (!esDniValido(dni)) {
      setState(() {
        _error = "🆔 DNI inválido. Revisa que esté bien escrito.";
        _loading = false;
      });
      return;
    }

    if (!_aceptaLPD) {
      setState(() {
        _lpdError =
            "☑️ Debes aceptar la política de notificaciones para continuar.";
        _loading = false;
      });
      return;
    } else {
      _lpdError = null;
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

      final yaExisteDni = snapshot.docs.any((doc) {
        final data = doc.data();
        final d = (data["Dni"] ?? "").toString().toUpperCase();
        return d == dni && data["correo"] != correo;
      });

      if (yaExisteDni) {
        setState(() {
          _error = "⚠️ Este DNI ya está registrado. Contacta con el administrador.";
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
        final fcmToken = await FirebaseMessaging.instance.getToken();

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
          "Dni": dni,
          "fcmToken": fcmToken,
        });

        await prefs.setBool("registroRealizado", true);

        setState(() {
          _error = "✅ Cuenta registrada. Espera la autorización del administrador.";
        });
      }
    } on FirebaseAuthException catch (e, st) {
      LoggingService.instance.error('Error de FirebaseAuth', e, st);
      String msg;
      switch (e.code) {
        case 'invalid-credential':
          msg = 'Credenciales inválidas';
          break;
        case 'network-request-failed':
          msg = 'Fallo de red';
          break;
        default:
          msg = e.message ?? 'Error de autenticación';
      }
      if (mounted) {
        ErrorBanner.show(context,
            message: msg,
            details: e.code,
            error: e,
            stackTrace: st,
            onRetry: _iniciarSesion);
      }
    } catch (e, st) {
      LoggingService.instance.error('Error inesperado al iniciar sesión', e, st);
      if (mounted) {
        ErrorBanner.show(context,
            message: 'Error inesperado',
            details: e.toString(),
            error: e,
            stackTrace: st,
            onRetry: _iniciarSesion);
      }
    }

    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: BootstrapRepo.ensureBoxes(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return Scaffold(
          appBar: AppBar(title: const Text("SansebasSms - Iniciar Sesión")),
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
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
                    controller: _confirmarContrasenaController,
                    obscureText: true,
                    decoration:
                        const InputDecoration(labelText: "Confirmar Contraseña"),
                  ),
                  TextField(
                    controller: _dniController,
                    decoration: const InputDecoration(labelText: "DNI o NIE"),
                  ),
                  TextField(
                    controller: _telefonoController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: "Teléfono"),
                  ),
                  const SizedBox(height: 12),
                  if (_textoLPD != null && _textoLPD!.isNotEmpty) ...[
                    Text(
                      _textoLPD!,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    Row(
                      children: [
                        Checkbox(
                          value: _aceptaLPD,
                          onChanged: (val) {
                            setState(() {
                              _aceptaLPD = val ?? false;
                            });
                          },
                        ),
                        const Expanded(
                          child: Text(
                            "He leído y acepto la política de notificaciones.",
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    if (_lpdError != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: Text(
                          _lpdError!,
                          style:
                              const TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      ),
                  ] else
                    const Text(
                      'No se pudo cargar el texto de consentimiento',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  const SizedBox(height: 10),
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
          ),
        );
      },
    );
  }
}
