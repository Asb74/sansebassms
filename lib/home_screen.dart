import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _mensajeController = TextEditingController();

  bool _enviando = false;
  String _log = "📋 Listo para enviar.";

  Future<void> _enviarMensajeFirestore() async {
    final mensaje = _mensajeController.text.trim();
    if (mensaje.isEmpty) {
      setState(() => _log = "⚠️ El mensaje está vacío.");
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Confirmar envío"),
        content: const Text("¿Seguro que deseas enviar este mensaje a todos los usuarios autorizados?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancelar")),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text("Sí, enviar"))
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _enviando = true;
      _log = "📤 Guardando mensajes en Firestore...";
    });

    try {
      final usuarios = await FirebaseFirestore.instance
          .collection("UsuariosAutorizados")
          .where("Mensaje", isEqualTo: true)
          .get();

      final fechaHora = DateTime.now();
      int total = 0;

      for (var doc in usuarios.docs) {
        final uid = doc.id;
        final telefono = doc.get("Telefono") ?? "";

        final idDoc = "${uid}_${fechaHora.toIso8601String()}";

        await FirebaseFirestore.instance
            .collection("Mensajes")
            .doc(idDoc)
            .set({
              "uid": uid,
              "mensaje": mensaje,
              "estado": "Pendiente",
              "fechaHora": fechaHora,
              "telefono": telefono,
            });

        total++;
      }

      setState(() => _log = "✅ Mensajes creados para $total usuarios.");
    } catch (e) {
      setState(() => _log = "❌ Error: $e");
    }

    setState(() => _enviando = false);
  }

  Future<void> _cerrarSesion() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (mounted) {
      Navigator.pushReplacementNamed(context, "/");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("SansebasSms - Administrador"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _cerrarSesion,
            tooltip: "Cerrar sesión",
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              _log,
              style: TextStyle(
                color: _log.startsWith("❌") ? Colors.red : Colors.black87,
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: GestureDetector(
                onHorizontalDragEnd: (_) async {
                  final confirmar = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text("Borrar mensaje"),
                      content: const Text("¿Deseas borrar el contenido del mensaje?"),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancelar")),
                        ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text("Borrar")),
                      ],
                    ),
                  );

                  if (confirmar == true) {
                    setState(() {
                      _mensajeController.clear();
                      _log = "🧹 Mensaje borrado.";
                    });
                  }
                },
                child: TextField(
                  controller: _mensajeController,
                  maxLines: null,
                  expands: true,
                  decoration: const InputDecoration(
                    labelText: "Escribe aquí el mensaje (desliza para borrar)",
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _enviando ? null : _enviarMensajeFirestore,
              icon: const Icon(Icons.send),
              label: const Text("Enviar mensaje"),
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            ),
          ],
        ),
      ),
    );
  }
}
