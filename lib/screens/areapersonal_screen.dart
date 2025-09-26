import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../login_screen.dart';
import 'mis_peticiones_screen.dart';
import 'report_mensajes_screen.dart';

class AreaPersonalScreen extends StatefulWidget {
  const AreaPersonalScreen({super.key});

  @override
  State<AreaPersonalScreen> createState() => _AreaPersonalScreenState();
}

class _AreaPersonalScreenState extends State<AreaPersonalScreen> {
  bool _guardando = false;
  bool _deleting = false;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Si true, además de borrar la cuenta de Auth, limpia la colección Peticiones del usuario
  static const bool kDeleteFirestoreData = true;

  Future<void> _confirmDeleteAccount() async {
    if (_deleting) return;

    // Aviso inicial
    final continuar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar mi cuenta'),
        content: const Text(
          'Esta acción es permanente. Se eliminará tu usuario de la aplicación.\n'
          'No podrás deshacerlo.'
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Continuar')),
        ],
      ),
    );

    if (continuar != true) return;

    // Confirmación escribiendo la palabra ELIMINAR
    final ok = await _secondConfirm();
    if (ok != true) return;

    await _deleteAccountFlow();
  }

  Future<bool?> _secondConfirm() async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final res = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Confirmación final'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Escribe: ELIMINAR',
            ),
            validator: (v) {
              if ((v ?? '').trim() != 'ELIMINAR') {
                return 'Debes escribir exactamente: ELIMINAR';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    controller.dispose();
    return res;
  }

  Future<void> _deleteAccountFlow() async {
    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('No hay sesión activa.')));
      return;
    }

    setState(() => _deleting = true);
    try {
      // 1) (opcional) Eliminar datos del usuario en Firestore
      if (kDeleteFirestoreData) {
        await _deleteUserCollections(user.uid);
      }

      // 2) Intentar eliminar cuenta de Auth
      await user.delete();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        // Pedir contraseña y reautenticar (email/password)
        final ok = await _reauthenticateAndRetryDelete(user);
        if (!ok) {
          setState(() => _deleting = false);
          return;
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo eliminar la cuenta: ${e.message ?? e.code}')),
        );
        setState(() => _deleting = false);
        return;
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Error inesperado al borrar la cuenta.')));
      setState(() => _deleting = false);
      return;
    }

    // 3) Sign out y navegar a login
    try {
      await _auth.signOut();
    } catch (_) {}
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Tu cuenta se ha eliminado.')));
    setState(() => _deleting = false);
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<bool> _reauthenticateAndRetryDelete(User user) async {
    final email = user.email;
    if (email == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo reautenticar: email no disponible.')),
      );
      return false;
    }

    final pass = await _askPassword();
    if (pass == null) return false;

    try {
      final cred = EmailAuthProvider.credential(email: email, password: pass);
      await user.reauthenticateWithCredential(cred);
      await user.delete();
      return true;
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reautenticación fallida: ${e.message ?? e.code}')),
      );
      return false;
    }
  }

  Future<String?> _askPassword() async {
    final controller = TextEditingController();
    final res = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Confirmar con contraseña'),
        content: TextField(
          controller: controller,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Contraseña',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('Confirmar')),
        ],
      ),
    );
    controller.dispose();
    return res;
  }

  /// Borra en páginas la colección Peticiones del usuario (si existe)
  Future<void> _deleteUserCollections(String uid) async {
    // Peticiones
    Query q = _db.collection('Peticiones').where('uid', isEqualTo: uid).limit(100);
    while (true) {
      final snap = await q.get();
      if (snap.docs.isEmpty) break;
      final batch = _db.batch();
      for (final d in snap.docs) {
        batch.delete(d.reference);
      }
      await batch.commit();
      if (snap.docs.length < 100) break;
    }

    // Si quieres borrar otras colecciones del usuario, repite patrón aquí.
  }

  Future<void> _peticionDiaLibre() async {
    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes iniciar sesión')),
      );
      return;
    }

    final now = DateTime.now();
    final first = DateTime(now.year, now.month, now.day);
    final last = first.add(const Duration(days: 365));

    final picked = await showDatePicker(
      context: context,
      initialDate: first,
      firstDate: first,
      lastDate: last,
      locale: const Locale('es', 'ES'),
      useRootNavigator: true,
    );

    // ⛔ Si cancela: cerrar picker y volver a la pantalla anterior a Área personal
    if (picked == null) {
      if (mounted) Navigator.of(context).maybePop(); // salir de AreaPersonalScreen
      return;
    }

    // Normalizamos a 00:00 local
    final fechaSolo = DateTime(picked.year, picked.month, picked.day);
    final motivo = await _pedirMotivo(context);
    if (motivo == null) return; // canceló en el diálogo de motivo

    final yyyyMMdd = DateFormat('yyyyMMdd').format(fechaSolo);
    final docId = '${user.uid}_$yyyyMMdd';

    setState(() => _guardando = true);
    try {
      await _db.collection('Peticiones').doc(docId).set({
        'uid'      : user.uid,
        'Fecha'    : Timestamp.fromDate(fechaSolo),
        'Admitido' : 'Pendiente',
        'Motivo'   : motivo,
        'creadoEn' : FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Petición registrada para $yyyyMMdd')),
      );
    } on FirebaseException catch (e) {
      debugPrint('Error guardando petición: ${e.code} ${e.message}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al guardar la petición.')),
      );
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    final tiles = <Widget>[
      Card(
        child: ListTile(
          leading: const Icon(Icons.event_available),
          title: const Text('Petición de días libres'),
          subtitle: const Text('Selecciona un día para solicitarlo'),
          trailing: _guardando
              ? const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.chevron_right),
          onTap: _guardando ? null : _peticionDiaLibre,
        ),
      ),
      Card(
        child: ListTile(
          leading: const Icon(Icons.list_alt),
          title: const Text('Mis peticiones'),
          subtitle:
              const Text('Ver historial y cancelar las pendientes'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const MisPeticionesScreen(),
              ),
            );
          },
        ),
      ),
      Card(
        child: ListTile(
          leading: const Icon(Icons.receipt_long),
          title: const Text('Informe de mis mensajes'),
          subtitle: const Text('Consulta tus últimos mensajes enviados'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const ReportMensajesScreen(),
              ),
            );
          },
        ),
      ),
      Card(
        child: ListTile(
          leading: const Icon(Icons.delete_forever),
          title: const Text('Eliminar mi cuenta'),
          subtitle: const Text('Borra tu usuario de forma permanente'),
          trailing: _deleting
              ? const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.chevron_right),
          onTap: _deleting ? null : _confirmDeleteAccount,
        ),
      ),
    ];

    if (user == null) {
      tiles.insert(
        0,
        Card(
          child: ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text('Debes iniciar sesión'),
            subtitle:
                const Text('Inicia sesión para registrar tus peticiones'),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Área personal')),
      body: Stack(
        children: [
          AbsorbPointer(
            absorbing: _deleting,
            child: Scrollbar(
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemBuilder: (context, index) => tiles[index],
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemCount: tiles.length,
              ),
            ),
          ),
          if (_deleting)
            Container(
              color: Colors.black45,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}

Future<String?> _pedirMotivo(BuildContext context) async {
  final formKey = GlobalKey<FormState>();
  final controller = TextEditingController();

  final res = await showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      return AlertDialog(
        title: const Text('Motivo de la petición'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            maxLength: 150,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Escribe el motivo (10–150 caracteres)',
              counterText: '',
            ),
            validator: (v) {
              final t = (v ?? '').trim();
              if (t.length < 10) return 'Mínimo 10 caracteres';
              if (t.length > 150) return 'Máximo 150 caracteres';
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.of(ctx).pop(controller.text.trim());
              }
            },
            child: const Text('Aceptar'),
          ),
        ],
      );
    },
  );

  controller.dispose();
  return res; // null si canceló
}
