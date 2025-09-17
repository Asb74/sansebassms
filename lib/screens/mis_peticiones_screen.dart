import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:sansebassms/utils/datetime_local.dart';

class MisPeticionesScreen extends StatelessWidget {
  const MisPeticionesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mis peticiones')),
        body: const Center(child: Text('Debes iniciar sesión')),
      );
    }

    final query = FirebaseFirestore.instance
        .collection('Peticiones')
        .where('uid', isEqualTo: user.uid)
        .orderBy('Fecha', descending: true); // índice compuesto requerido

    return Scaffold(
      appBar: AppBar(title: const Text('Mis peticiones')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: query.snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            debugPrint('MisPeticiones error: ${snap.error}');
            return const Center(child: Text('Error al cargar las peticiones.'));
          }

          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('No tienes peticiones todavía.'));
          }

          return Scrollbar(
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: docs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final doc = docs[i];
                final data = doc.data();
                final estado = (data['Admitido'] ?? 'Pendiente').toString();
                final fechaStr = formatLocalDay(data['Fecha']);
                final cancelable = estado == 'Pendiente';

                return Card(
                  elevation: 1,
                  child: ListTile(
                    leading: const Icon(Icons.event_note),
                    title: Text('Fecha: $fechaStr'),
                    subtitle: Text('Estado: $estado'),
                    trailing: cancelable
                        ? TextButton.icon(
                            onPressed: () => _cancelar(context, doc.id),
                            icon: const Icon(Icons.cancel),
                            label: const Text('Cancelar'),
                          )
                        : const Icon(Icons.lock_outline),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _cancelar(BuildContext context, String docId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancelar petición'),
        content: const Text('¿Deseas cancelar esta petición pendiente?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sí'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await FirebaseFirestore.instance.collection('Peticiones').doc(docId).delete();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Petición cancelada.')),
        );
      }
    } on FirebaseException catch (e) {
      debugPrint('Error al cancelar petición $docId: ${e.message}');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo cancelar.')),
        );
      }
    }
  }
}
