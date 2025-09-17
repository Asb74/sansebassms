import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:sansebassms/utils/datetime_local.dart';

class ReportMensajesScreen extends StatelessWidget {
  const ReportMensajesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Informe de mis mensajes'),
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text('Debes iniciar sesión para ver tus mensajes.'),
          ),
        ),
      );
    }

    final mensajesQuery = FirebaseFirestore.instance
        .collection('Mensajes')
        .where('uid', isEqualTo: user.uid)
        .orderBy('fechaHora', descending: true)
        .limit(10);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Informe de mis mensajes'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: mensajesQuery.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Se ha producido un error al cargar los mensajes.'),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('No hay mensajes recientes.'),
              ),
            );
          }

          return Scrollbar(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: docs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final data = docs[index].data();
                final mensaje = (data['mensaje'] as String?)?.trim();
                final telefono = (data['telefono'] as String?)?.trim();
                final estado = (data['estado'] as String?)?.trim();
                final fecha = formatLocal(data['fechaHora']);
                assert(() {
                  final dt = toLocalDate(data['fechaHora']);
                  // ignore: avoid_print
                  print(
                    "[DEBUG] uid=${data['uid']} fechaHoraUTC=${(data['fechaHora'] as Timestamp?)?.toDate()} local=$dt",
                  );
                  return true;
                }());

                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.message_outlined),
                    title: Text(mensaje?.isNotEmpty == true
                        ? mensaje!
                        : 'Mensaje sin contenido'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (telefono?.isNotEmpty == true)
                          Text('Teléfono: ${telefono!}')
                        else
                          const Text('Teléfono no disponible'),
                        Text('Estado: ${estado?.isNotEmpty == true ? estado! : 'Desconocido'}'),
                        Text('Fecha: $fecha'),
                      ],
                    ),
                    isThreeLine: true,
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
