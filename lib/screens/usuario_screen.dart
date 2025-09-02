import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

class UsuarioScreen extends StatefulWidget {
  const UsuarioScreen({super.key});

  @override
  State<UsuarioScreen> createState() => _UsuarioScreenState();
}

class _UsuarioScreenState extends State<UsuarioScreen> {
  String? uid;
  List<DocumentSnapshot> mensajesPendientes = [];
  bool cargando = true;
  List<String> _motivosDisponibles = [];
  Timer? _timer;
  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _solicitarPermisosNotificacion();
    _initNotifications();
    _cargarMensajes();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      _cargarMensajes();
    });
  }

  Future<void> _solicitarPermisosNotificacion() async {
    final status = await Permission.notification.status;
    if (!status.isGranted) {
      await Permission.notification.request();
    }
  }

  Future<void> _initNotifications() async {
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings = InitializationSettings(android: androidSettings);
    await flutterLocalNotificationsPlugin.initialize(initSettings);
  }

  Future<void> _mostrarNotificacion(String idMensaje, String texto) async {
    final prefs = await SharedPreferences.getInstance();
    final yaNotificados = prefs.getStringList("idsNotificados") ?? [];

    if (yaNotificados.contains(idMensaje)) return;

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'canal_mensajes',
      'Mensajes Sansebas',
      importance: Importance.high,
      priority: Priority.high,
    );

    const NotificationDetails details = NotificationDetails(android: androidDetails);

    //await flutterLocalNotificationsPlugin.show(
      //idMensaje.hashCode,
      //'Nuevo mensaje pendiente',
      //texto,
      //details,
    //);

    yaNotificados.add(idMensaje);
    await prefs.setStringList("idsNotificados", yaNotificados);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _cargarMensajes() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    uid = user.uid;

    final snapshot = await FirebaseFirestore.instance
        .collection("Mensajes")
        .where("uid", isEqualTo: uid)
        .where("estado", isEqualTo: "Pendiente")
        .orderBy("fechaHora", descending: false)
        .get();

    final motivosDoc = await FirebaseFirestore.instance
        .collection("PlantillasMotivos")
        .doc("Motivos")
        .get();

    final campos = motivosDoc.data()?['CAMPO'];
    if (campos != null && campos is String) {
      _motivosDisponibles = campos.split(',').map((e) => e.trim()).toList();
    }

    for (var doc in snapshot.docs) {
      final texto = doc['mensaje'] ?? '';
      await _mostrarNotificacion(doc.id, texto);
    }

    setState(() {
      mensajesPendientes = snapshot.docs;
      cargando = false;
    });
  }

  Future<void> _actualizarEstado(String docId, String nuevoEstado, [String? motivo]) async {
    final datos = {"estado": nuevoEstado};
    if (motivo != null) datos["motivo"] = motivo;

    await FirebaseFirestore.instance
        .collection("Mensajes")
        .doc(docId)
        .update(datos);

    setState(() {
      mensajesPendientes.removeWhere((m) => m.id == docId);
    });
  }

  void _mostrarMotivos(String docId) {
    String? motivoSeleccionado;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Selecciona un motivo"),
        content: DropdownButtonFormField<String>(
          items: _motivosDisponibles
              .map((motivo) => DropdownMenuItem(
                    value: motivo,
                    child: Text(motivo),
                  ))
              .toList(),
          onChanged: (valor) => motivoSeleccionado = valor,
          decoration: const InputDecoration(labelText: "Motivo"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () {
              if (motivoSeleccionado != null) {
                Navigator.pop(context);
                _actualizarEstado(docId, "Denegado", motivoSeleccionado);
              }
            },
            child: const Text("Enviar motivo"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (cargando) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (mensajesPendientes.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text("SansebasSms - Usuario")),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.mail_outline, size: 80, color: Colors.grey),
              SizedBox(height: 20),
              Text(
                "📭 No tienes mensajes pendientes por ahora.",
                style: TextStyle(fontSize: 18, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Mensajes pendientes")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView.builder(
          itemCount: mensajesPendientes.length,
          itemBuilder: (context, index) {
            final doc = mensajesPendientes[index];
            final docId = doc.id;
            final data = doc.data() as Map<String, dynamic>? ?? {};
            final String mensaje = (data['mensaje'] ?? '').toString();
            final String dia = (data['dia'] ?? '').toString();
            final String hora = (data['hora'] ?? '').toString();
            final String cuerpo = (data['cuerpo'] ?? '').toString();

            return Card(
              elevation: 1.5,
              margin: const EdgeInsets.symmetric(vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Mensaje:',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      mensaje.isEmpty ? '—' : mensaje,
                      style: const TextStyle(fontSize: 15),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Text('Día: ', style: TextStyle(fontWeight: FontWeight.w500)),
                        Expanded(child: Text(dia.isEmpty ? '—' : dia)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Text('Hora: ', style: TextStyle(fontWeight: FontWeight.w500)),
                        Expanded(child: Text(hora.isEmpty ? '—' : hora)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text('Cuerpo:', style: TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    Text(
                      cuerpo.isEmpty ? '—' : cuerpo,
                      textAlign: TextAlign.start,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _actualizarEstado(docId, 'OK'),
                            icon: const Icon(Icons.check),
                            label: const Text('Aceptar'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _mostrarMotivos(docId),
                            icon: const Icon(Icons.close),
                            label: const Text('Rechazar'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
