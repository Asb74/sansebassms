import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AreaPersonalScreen extends StatefulWidget {
  const AreaPersonalScreen({super.key});

  @override
  State<AreaPersonalScreen> createState() => _AreaPersonalScreenState();
}

class _AreaPersonalScreenState extends State<AreaPersonalScreen> {
  bool _guardando = false;

  Future<void> _solicitarDiaLibre() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _mostrarSnackBar('Debes iniciar sesión');
      return;
    }

    final picked = await showDatePicker(
      context: context,
      locale: const Locale('es', 'ES'),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDate: DateTime.now(),
    );

    if (picked == null) {
      return;
    }

    final selectedDate = DateTime(picked.year, picked.month, picked.day);
    final formattedDate = DateFormat('yyyyMMdd').format(selectedDate);
    final docId = '${user.uid}_$formattedDate';

    if (!mounted) {
      return;
    }

    setState(() {
      _guardando = true;
    });

    try {
      await FirebaseFirestore.instance
          .collection('Peticiones')
          .doc(docId)
          .set(
        {
          'uid': user.uid,
          'Fecha': Timestamp.fromDate(selectedDate),
          'Admitido': 'Pendiente',
          'creadoEn': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (!mounted) return;
      _mostrarSnackBar('Petición registrada para $formattedDate');
    } catch (e) {
      if (!mounted) return;
      _mostrarSnackBar('Error al guardar la petición: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _guardando = false;
        });
      }
    }
  }

  void _mostrarSnackBar(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

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
          onTap: _guardando ? null : _solicitarDiaLibre,
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
