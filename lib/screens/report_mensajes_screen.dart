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

          final items = docs
              .map((doc) {
                final data = doc.data();
                final dia = data['Dia'] ?? data['dia'];
                final hora = data['Hora'] ?? data['hora'];
                final prefer = combineLocalDayHour(dia, hora);
                final alt =
                    toLocalDate(data['fechaHora'] ?? data['Fecha'] ?? data['fecha']);
                final dt = prefer ?? alt ?? DateTime.fromMillisecondsSinceEpoch(0);
                return {'doc': doc, 'data': data, 'dt': dt};
              })
              .toList()
            ..sort((a, b) => (b['dt'] as DateTime).compareTo(a['dt'] as DateTime));

          return Scrollbar(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final data = items[index]['data'] as Map<String, dynamic>;

                final mensaje = (data['mensaje'] ?? '').toString().trim();
                final telefono = (data['telefono'] ?? '').toString().trim();
                final estado = (data['estado'] ?? '').toString().trim();
                final cuerpo =
                    (data['cuerpo'] ?? data['Cuerpo'] ?? '').toString().trim();

                final dia = data['Dia'] ?? data['dia'];
                final hora = data['Hora'] ?? data['hora'];

                String fechaVis;
                DateTime? dtOrden;

                final dtPrefer = combineLocalDayHour(dia, hora);
                if (dtPrefer != null) {
                  fechaVis = formatLocalFromDayHour(dia, hora);
                  dtOrden = dtPrefer;
                } else {
                  final alternativa = data['fechaHora'] ?? data['Fecha'] ?? data['fecha'];
                  fechaVis = formatLocal(alternativa);
                  dtOrden = toLocalDate(alternativa);
                }

                assert(() {
                  final rawFecha = data['fechaHora'] ?? data['Fecha'] ?? data['fecha'];
                  // ignore: avoid_print
                  print(
                    '[DEBUG] uid=${data['uid']} prefer=$dtPrefer fallback=$rawFecha orden=$dtOrden',
                  );
                  return true;
                }());

                return Card(
                  elevation: 1,
                  child: ListTile(
                    leading: const Icon(Icons.message),
                    title: Text(mensaje.isEmpty ? '(sin texto)' : mensaje),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (telefono.isNotEmpty) Text('Teléfono: $telefono'),
                        if (estado.isNotEmpty) Text('Estado: $estado'),
                        if (cuerpo.isNotEmpty) Text('Cuerpo: $cuerpo'),
                        Text('Fecha: $fechaVis'),
                      ],
                    ),
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
