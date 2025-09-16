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

    // Rango y fecha inicial seguros
    final now = DateTime.now();
    final first = DateTime(now.year, now.month, now.day); // hoy 00:00
    final last = first.add(const Duration(days: 365));
    final initial = now.isBefore(first) ? first : now;

    // 1) INTENTO PRINCIPAL: showDatePicker con tema forzado (M3 + DatePickerTheme)
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
      locale: const Locale('es', 'ES'),
      useRootNavigator: true,
      builder: (ctx, child) {
        final base = Theme.of(ctx);
        return Theme(
          data: base.copyWith(
            // Fuerza contraste y fondos del diálogo del datepicker
            colorScheme: base.colorScheme.copyWith(
              surface: Colors.white,
              onSurface: Colors.black,
              primary: base.colorScheme.primary,
            ),
            dialogBackgroundColor: Colors.white,
            // ⚠️ En M3 el picker usa este tema específico
            datePickerTheme: const DatePickerThemeData(
              backgroundColor: Colors.white,
              headerBackgroundColor: Colors.white,
              headerForegroundColor: Colors.black,
              dayForegroundColor: MaterialStatePropertyAll(Colors.black),
              yearForegroundColor: MaterialStatePropertyAll(Colors.black),
              todayForegroundColor: MaterialStatePropertyAll(Colors.black),
            ),
            // Si tu copyWith soporta esto, mantenlo; si no, ignóralo.
            // ignore: deprecated_member_use
            useMaterial3: true,
          ),
          child: child!,
        );
      },
    );

    // 2) FALLBACK: si por tema/ROM el diálogo no se ve/retorna null, usa bottom sheet
    if (picked == null) {
      picked = await showModalBottomSheet<DateTime>(
        context: context,
        isScrollControlled: false,
        showDragHandle: true,
        backgroundColor: Colors.white,
        builder: (ctx) {
          DateTime selected = initial;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Selecciona una fecha',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  CalendarDatePicker(
                    initialDate: initial,
                    firstDate: first,
                    lastDate: last,
                    onDateChanged: (d) =>
                        selected = DateTime(d.year, d.month, d.day),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancelar')),
                      const SizedBox(width: 8),
                      FilledButton(
                          onPressed: () => Navigator.pop(ctx, selected),
                          child: const Text('Aceptar')),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    if (picked == null) return;

    final fechaSolo = DateTime(picked.year, picked.month, picked.day);
    final yyyyMMdd = DateFormat('yyyyMMdd').format(fechaSolo);
    final docId = '${user.uid}_$yyyyMMdd';

    setState(() => _guardando = true);
    try {
      await _db.collection('Peticiones').doc(docId).set({
        'uid': user.uid,
        'Fecha': Timestamp.fromDate(fechaSolo), // Timestamp para poder ordenar
        'Admitido': 'Pendiente',
        'creadoEn': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Petición registrada para $yyyyMMdd')),
      );
    } on FirebaseException catch (e) {
      debugPrint('Error guardando petición: ${e.message}');
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
