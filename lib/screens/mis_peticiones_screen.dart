import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MisPeticionesScreen extends StatelessWidget {
  MisPeticionesScreen({super.key});

  final ValueNotifier<Set<String>> _deleting =
      ValueNotifier<Set<String>>(<String>{});

  Future<void> _cancelPeticion(
    BuildContext context,
    DocumentSnapshot<Map<String, dynamic>> doc,
    String estado,
  ) async {
    if (estado != 'Pendiente') {
      return;
    }

    final confirmacion = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Cancelar petición'),
          content: const Text('¿Cancelar esta petición?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('No'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Sí, cancelar'),
            ),
          ],
        );
      },
    );

    if (confirmacion != true) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);

    _deleting.value = {..._deleting.value, doc.id};

    try {
      await doc.reference.delete();
      messenger.showSnackBar(
        const SnackBar(content: Text('Petición cancelada.')),
      );
    } on FirebaseException catch (e) {
      debugPrint('Error al cancelar petición: ${e.message ?? e.code}');
      messenger.showSnackBar(
        const SnackBar(content: Text('No se pudo cancelar la petición.')),
      );
    } catch (e) {
      debugPrint('Error al cancelar petición: $e');
      messenger.showSnackBar(
        const SnackBar(content: Text('No se pudo cancelar la petición.')),
      );
    } finally {
      final updated = {..._deleting.value};
      updated.remove(doc.id);
      _deleting.value = updated;
    }
  }

  String _formatFecha(dynamic value) {
    DateTime? fecha;
    if (value is Timestamp) {
      fecha = value.toDate();
    } else if (value is DateTime) {
      fecha = value;
    }

    if (fecha == null) {
      return 'Fecha no disponible';
    }

    return DateFormat('dd/MM/yyyy', 'es_ES').format(fecha);
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mis peticiones')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('Debes iniciar sesión para consultar tus peticiones.'),
          ),
        ),
      );
    }

    final query = FirebaseFirestore.instance
        .collection('Peticiones')
        .where('uid', isEqualTo: user.uid)
        .orderBy('Fecha', descending: true);

    return Scaffold(
      appBar: AppBar(title: const Text('Mis peticiones')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: query.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            debugPrint('MisPeticiones error: ${snapshot.error}');
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Error al cargar las peticiones.'),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? <QueryDocumentSnapshot<Map<String, dynamic>>>[];

          if (docs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Aún no has registrado peticiones.'),
              ),
            );
          }

          return Scrollbar(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: docs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final doc = docs[index];
                final data = doc.data();
                final fechaTexto = _formatFecha(data['Fecha']);
                final estado = (data['Admitido'] as String?) ?? 'Pendiente';
                final isPendiente = estado == 'Pendiente';

                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.event_note),
                    title: Text(fechaTexto),
                    subtitle: Text('Estado: $estado'),
                    trailing: isPendiente
                        ? ValueListenableBuilder<Set<String>>(
                            valueListenable: _deleting,
                            builder: (context, deleting, _) {
                              final isDeleting = deleting.contains(doc.id);
                              if (isDeleting) {
                                return const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                );
                              }

                              return TextButton.icon(
                                icon: const Icon(Icons.cancel),
                                label: const Text('Cancelar'),
                                style: TextButton.styleFrom(
                                  foregroundColor:
                                      Theme.of(context).colorScheme.error,
                                ),
                                onPressed: () =>
                                    _cancelPeticion(context, doc, estado),
                              );
                            },
                          )
                        : const Icon(Icons.lock),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
