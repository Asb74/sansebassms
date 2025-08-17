import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../services/logger.dart';

class ErrorBanner {
  static void show(
    BuildContext context, {
    required String message,
    String? details,
    Object? error,
    StackTrace? stackTrace,
    VoidCallback? onRetry,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearMaterialBanners();
    messenger.showMaterialBanner(
      MaterialBanner(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        actions: [
          if (details != null || stackTrace != null)
            TextButton(
              onPressed: () {
                messenger.hideCurrentMaterialBanner();
                _showDetails(context, details, stackTrace);
              },
              child: const Text('Detalles'),
            ),
          if (onRetry != null)
            TextButton(
              onPressed: () {
                messenger.hideCurrentMaterialBanner();
                onRetry();
              },
              child: const Text('Reintentar'),
            ),
        ],
      ),
    );
    LoggingService.instance.error(message, error, stackTrace);
  }

  static void _showDetails(
      BuildContext context, String? details, StackTrace? stackTrace) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        final log = [if (details != null) details, if (stackTrace != null) stackTrace.toString()].join('\n');
        return Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(log),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () async {
                    final path = await LoggingService.instance.exportLogFile();
                    await Share.shareXFiles([XFile(path)], text: 'diagnóstico');
                  },
                  child: const Text('Compartir diagnóstico'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
