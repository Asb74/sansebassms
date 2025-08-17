import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'log_buffer.dart';

class LogConsole extends StatefulWidget {
  const LogConsole({super.key});
  @override
  State<LogConsole> createState() => _LogConsoleState();
}

class _LogConsoleState extends State<LogConsole> {
  late final ScrollController _sc = ScrollController();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registro (diagnóstico)'), actions: [
        IconButton(
          icon: const Icon(Icons.ios_share),
          onPressed: () async {
            final dir = await getTemporaryDirectory();
            final f = File('${dir.path}/app-log.txt');
            await f.writeAsString(LogBuffer.I.lines.join('\n'));
            // Muestra una notificación simple con la ruta del archivo
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Log exportado: ${f.path}')),
              );
            }
          },
        ),
      ]),
      body: StreamBuilder<List<String>>(
        stream: LogBuffer.I.stream,
        initialData: LogBuffer.I.lines,
        builder: (context, snap) {
          final lines = snap.data ?? const <String>[];
          return ListView.builder(
            controller: _sc,
            itemCount: lines.length,
            itemBuilder: (_, i) =>
                Text(lines[i], style: const TextStyle(fontFamily: 'monospace')),
          );
        },
      ),
    );
  }
}

