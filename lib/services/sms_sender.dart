import 'package:flutter/services.dart';

class SmsSender {
  static const MethodChannel _channel = MethodChannel('com.sansebas.sms/channel');

  /// Envía SMS de forma automática usando código nativo
  /// [mensaje]: texto del SMS
  /// [numeros]: lista de teléfonos en formato internacional
  static Future<int> enviarSmsMasivo(String mensaje, List<String> numeros) async {
    try {
      final enviados = await _channel.invokeMethod("enviarSms", {
        "mensaje": mensaje,
        "numeros": numeros,
      });

      return enviados as int;
    } on PlatformException catch (e) {
      print("Error al enviar SMS: ${e.message}");
      rethrow;
    }
  }
}
