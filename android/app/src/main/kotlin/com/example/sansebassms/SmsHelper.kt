package com.example.sansebassms

import android.app.Activity
import android.telephony.SmsManager
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class SmsHelper(private val activity: Activity) : MethodChannel.MethodCallHandler {
    companion object {
        fun registerWith(engine: FlutterPlugin.FlutterPluginBinding, activity: Activity) {
            val channel = MethodChannel(engine.binaryMessenger, "com.example.sansebassms/sms")
            channel.setMethodCallHandler(SmsHelper(activity))
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method == "enviarSms") {
            val numero = call.argument<String>("numero")
            val mensaje = call.argument<String>("mensaje")
            try {
                val smsManager = SmsManager.getDefault()
                smsManager.sendTextMessage(numero, null, mensaje, null, null)
                result.success("SMS enviado a $numero")
            } catch (e: Exception) {
                result.error("ERROR", "Fallo enviando SMS: ${e.message}", null)
            }
        } else {
            result.notImplemented()
        }
    }
}
