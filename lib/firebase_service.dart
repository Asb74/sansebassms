package com.example.sansebassms

import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager
import android.telephony.SmsManager
import android.util.Log
import androidx.core.app.ActivityCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class SmsHelper(private val activity: Activity) : FlutterPlugin, MethodChannel.MethodCallHandler {

    private lateinit var channel: MethodChannel

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "com.sansebas.sms/channel")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method == "enviarSms") {
            val args = call.arguments as Map<*, *>
            val mensaje = args["mensaje"] as? String ?: return result.error("ARG", "Mensaje no válido", null)
            val numeros = args["numeros"] as? List<*> ?: return result.error("ARG", "Lista inválida", null)

            if (!tienePermisosSms()) {
                result.error("PERMISO", "Permiso SEND_SMS denegado", null)
                return
            }

            val smsManager = SmsManager.getDefault()
            var enviados = 0

            for (num in numeros) {
                val telefono = num.toString()
                try {
                    smsManager.sendTextMessage(telefono, null, mensaje, null, null)
                    enviados++
                } catch (e: Exception) {
                    Log.e("SmsHelper", "Error al enviar a $telefono: ${e.message}")
                }
            }

            result.success(enviados)
        } else {
            result.notImplemented()
        }
    }

    private fun tienePermisosSms(): Boolean {
        val permiso = ActivityCompat.checkSelfPermission(activity, Manifest.permission.SEND_SMS)
        return permiso == PackageManager.PERMISSION_GRANTED
    }
}
