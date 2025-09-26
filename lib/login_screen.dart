import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'home_screen.dart';
import 'screens/usuario_screen.dart';

const bool kReviewBypassEnabled = true; // ← apágalo tras la revisión
const String kReviewEmail = 'prueba@sansebas.es';
const String kReviewPassword = 'kdjjs525';
const bool kAutocreateReviewUserIfMissing = true; // crea la cuenta de review si no existe

String mapAuthError(FirebaseAuthException e, {bool isSignIn = true}) {
  switch (e.code) {
    case 'invalid-email':
      return 'El correo no tiene un formato válido.';
    case 'user-disabled':
      return 'Esta cuenta está deshabilitada.';
    case 'user-not-found':
      return isSignIn
          ? 'No existe ninguna cuenta con ese correo.'
          : 'No se encontró la cuenta.';
    case 'wrong-password':
    case 'invalid-credential':
      return 'Contraseña incorrecta.';
    case 'email-already-in-use':
      return 'Ya existe una cuenta con ese correo.';
    case 'weak-password':
      return 'La contraseña es demasiado débil.';
    case 'too-many-requests':
      return 'Demasiados intentos. Prueba más tarde.';
    case 'network-request-failed':
      return 'Sin conexión. Revisa tu internet.';
    default:
      return e.message ?? 'Error de autenticación: ${e.code}';
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  final TextEditingController _telefonoController = TextEditingController();
  final TextEditingController _dniController = TextEditingController();

  bool _isRegister = false;
  bool _loading = false;
  String? _error;
  String? _textoLPD;
  bool _aceptaLPD = false;
  bool _tokenPendiente = false;

  @override
  void initState() {
    super.initState();
    _cargarTextoLPD();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _telefonoController.dispose();
    _dniController.dispose();
    super.dispose();
  }

  void _toggleMode() {
    setState(() {
      _isRegister = !_isRegister;
      _error = null;
      _tokenPendiente = false;
      _aceptaLPD = false;
    });
  }

  Future<void> _cargarTextoLPD() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('LPD')
          .doc('Login')
          .get();

      if (doc.exists) {
        setState(() {
          _textoLPD = doc.data()?['Autorizacion'] ?? '';
        });
      }
    } catch (_) {
      // Si falla la carga, dejamos el texto como null
    }
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

  Future<String?> _obtenerTokenFcm() async {
    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        return null;
      }

      if (Platform.isIOS) {
        try {
          await messaging
              .getAPNSToken()
              .timeout(const Duration(seconds: 5));
        } catch (_) {
          return null;
        }
      }

      return await messaging
          .getToken()
          .timeout(const Duration(seconds: 5), onTimeout: () => null);
    } catch (_) {
      return null;
    }
  }

  void _mostrarSnackBar(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje)),
    );
  }

  Future<void> _handleSignInSuccess(String email, String password) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final query = await FirebaseFirestore.instance
          .collection('UsuariosAutorizados')
          .where('correo', isEqualTo: email)
          .where('Contraseña', isEqualTo: password)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        final data = query.docs.first.data();
        final permitido = data['Valor'] == true;
        final rol = (data['Rol'] ?? 'User').toString().toLowerCase();

        if (!permitido) {
          if (!mounted) return;
          setState(() {
            _error =
                '⛔ Tu cuenta aún no está autorizada. Contacta con el administrador.';
            _loading = false;
          });
          return;
        }

        await prefs.setString('correo', email);
        await prefs.setString('contrasena', password);

        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = null;
        });
        _irAPantallaUsuario(rol);
      } else {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error =
              '⚠️ No se encontró la cuenta autorizada. Contacta con el administrador.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '❌ Error: ${e.toString()}';
      });
    }
  }

  void _irAPantallaUsuario(String rol) {
    if (!mounted) return;
    final Widget destino =
        rol == 'admin' ? const HomeScreen() : const UsuarioScreen();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => destino),
    );
  }

  Future<void> _enviar() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _mostrarSnackBar('Introduce correo y contraseña.');
      setState(() => _loading = false);
      return;
    }

    if (_isRegister) {
      final confirm = _confirmController.text;

      if (!(_formKey.currentState?.validate() ?? false)) {
        setState(() => _loading = false);
        return;
      }

      if (password != confirm) {
        _mostrarSnackBar('Las contraseñas no coinciden');
        setState(() => _loading = false);
        return;
      }

      if (password.length < 6) {
        _mostrarSnackBar(
            'La contraseña debe tener al menos 6 caracteres');
        setState(() => _loading = false);
        return;
      }

      final telefono = _telefonoController.text.trim();
      final dni = _dniController.text.trim().toUpperCase();

      if (telefono.isEmpty ||
          telefono.length < 9 ||
          !RegExp(r'^\d+$').hasMatch(telefono)) {
        setState(() {
          _error =
              '📵 Introduce un número de teléfono válido (mínimo 9 dígitos, solo números).';
          _loading = false;
        });
        return;
      }

      if (!esDniValido(dni)) {
        setState(() {
          _error = '🆔 DNI inválido. Revisa que esté bien escrito.';
          _loading = false;
        });
        return;
      }

      if (!_aceptaLPD) {
        setState(() {
          _error =
              '☑️ Debes aceptar la política de notificaciones para continuar.';
          _loading = false;
        });
        return;
      }

      try {
        final snapshot = await FirebaseFirestore.instance
            .collection('UsuariosAutorizados')
            .get();

        final yaExisteTelefono = snapshot.docs.any((doc) {
          final data = doc.data();
          final t = data['Telefono'];
          return t != null && t == telefono && data['correo'] != email;
        });

        if (yaExisteTelefono) {
          setState(() {
            _error =
                '⚠️ Este teléfono ya está registrado con otra cuenta. Contacta con el administrador.';
            _loading = false;
          });
          return;
        }

        final yaExisteDni = snapshot.docs.any((doc) {
          final data = doc.data();
          final d = (data['Dni'] ?? '').toString().toUpperCase();
          return d == dni && data['correo'] != email;
        });

        if (yaExisteDni) {
          setState(() {
            _error =
                '⚠️ Este DNI ya está registrado. Contacta con el administrador.';
            _loading = false;
          });
          return;
        }

        final prefs = await SharedPreferences.getInstance();
        final cred = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(email: email, password: password);

        final uid = cred.user!.uid;
        final fcmToken = await _obtenerTokenFcm();
        final tokenPendiente = fcmToken == null;

        await FirebaseFirestore.instance
            .collection('UsuariosAutorizados')
            .doc(uid)
            .set({
          'correo': email,
          'Contraseña': password,
          'Rol': 'User',
          'Valor': false,
          'Telefono': telefono,
          'Mensaje': false,
          'Dni': dni,
          'fcmToken': fcmToken ?? '',
          'tokenPendiente': tokenPendiente,
        });

        await prefs.setString('correo', email);
        await prefs.setString('contrasena', password);
        await prefs.setBool('registroRealizado', true);

        if (!mounted) return;
        setState(() {
          _tokenPendiente = tokenPendiente;
          _error = tokenPendiente
              ? '✅ Cuenta registrada, pero no recibirás notificaciones hasta habilitar los permisos y actualizar el token.'
              : '✅ Cuenta registrada. Espera la autorización del administrador.';
          _loading = false;
        });
      } on FirebaseAuthException catch (e) {
        if (!mounted) return;
        setState(() => _loading = false);
        _mostrarSnackBar(mapAuthError(e, isSignIn: false));
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _error = '❌ Error: ${e.toString()}';
          _loading = false;
        });
      }
      return;
    }

    final isReviewCandidate = kReviewBypassEnabled &&
        email.toLowerCase() == kReviewEmail &&
        password == kReviewPassword;

    try {
      await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);

      if (isReviewCandidate) {
        if (!mounted) return;
        setState(() => _loading = false);
        _irAPantallaUsuario('user');
        return;
      }

      await _handleSignInSuccess(email, password);
    } on FirebaseAuthException catch (e) {
      if (isReviewCandidate &&
          e.code == 'user-not-found' &&
          kAutocreateReviewUserIfMissing) {
        try {
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
            email: email,
            password: password,
          );
          if (!mounted) return;
          setState(() => _loading = false);
          _irAPantallaUsuario('user');
        } on FirebaseAuthException catch (e2) {
          if (!mounted) return;
          setState(() => _loading = false);
          _mostrarSnackBar(mapAuthError(e2, isSignIn: false));
        }
        return;
      }

      if (!mounted) return;
      setState(() => _loading = false);
      _mostrarSnackBar(mapAuthError(e, isSignIn: true));
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      _mostrarSnackBar('Error inesperado.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final titulo =
        _isRegister ? 'SansebasSms - Registro' : 'SansebasSms - Iniciar Sesión';
    return Scaffold(
      appBar: AppBar(title: Text(titulo)),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.username],
                  autocorrect: false,
                  enableSuggestions: false,
                  inputFormatters: [
                    FilteringTextInputFormatter.deny(RegExp(r'\s')),
                  ],
                  decoration: const InputDecoration(labelText: 'Correo'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  enableSuggestions: false,
                  autocorrect: false,
                  decoration: const InputDecoration(labelText: 'Contraseña'),
                ),
                if (_isRegister) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _confirmController,
                    obscureText: true,
                    enableSuggestions: false,
                    autocorrect: false,
                    decoration: const InputDecoration(
                        labelText: 'Confirmar Contraseña'),
                    validator: (v) {
                      final p = _passwordController.text;
                      if ((v ?? '').isEmpty) {
                        return 'Confirma la contraseña';
                      }
                      if (v != p) {
                        return 'Las contraseñas no coinciden';
                      }
                      if (p.length < 6) {
                        return 'La contraseña debe tener al menos 6 caracteres';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _dniController,
                    decoration: const InputDecoration(labelText: 'DNI o NIE'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _telefonoController,
                    keyboardType: TextInputType.phone,
                    decoration:
                        const InputDecoration(labelText: 'Teléfono'),
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
                            'He leído y acepto la política de notificaciones.',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: _loading ? null : _enviar,
                  child: _loading
                      ? const CircularProgressIndicator()
                      : Text(_isRegister ? 'Registrarse' : 'Iniciar Sesión'),
                ),
                TextButton(
                  onPressed: _loading ? null : _toggleMode,
                  child: Text(_isRegister
                      ? '¿Ya tienes cuenta? Inicia sesión'
                      : '¿No tienes cuenta? Regístrate'),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 20),
                  Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                  if (_tokenPendiente)
                    TextButton(
                      onPressed: () =>
                          Navigator.pushNamed(context, '/actualizar-token'),
                      child: const Text('Actualizar token'),
                    ),
                ]
              ],
            ),
          ),
        ),
      ),
    );
  }
}
