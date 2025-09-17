import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'mis_peticiones_screen.dart';
import 'report_mensajes_screen.dart';

class AreaPersonalScreen extends StatefulWidget {
  const AreaPersonalScreen({super.key});

  @override
  State<AreaPersonalScreen> createState() => _AreaPersonalScreenState();
}

class _AreaPersonalScreenState extends State<AreaPersonalScreen> {
  bool _guardando = false;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

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
      body: Scrollbar(
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemBuilder: (context, index) => tiles[index],
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemCount: tiles.length,
        ),
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
