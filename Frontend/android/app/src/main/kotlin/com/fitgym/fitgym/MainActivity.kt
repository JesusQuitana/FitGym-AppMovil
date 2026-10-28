package com.fitgym.fitgym

import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Bloqueo de capturas de pantalla mientras se muestra el pase (ver pantalla_segura.dart).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "fitgym/pantalla")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "proteger" -> {
                        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        result.success(null)
                    }
                    "desproteger" -> {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
