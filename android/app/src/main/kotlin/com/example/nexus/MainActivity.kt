package com.example.nexus

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * La app del teléfono, con lo único nativo que necesita para actualizarse sola:
 * abrir el instalador de Android con el APK que descargó.
 *
 * El APK se baja en Dart a la carpeta de caché `actualizaciones/`, y aquí se le
 * pasa al instalador por un FileProvider: Android no deja abrir un archivo de la
 * app con una ruta a pelo desde la 7. Instalar lo decide siempre quien la usa —el
 * sistema pregunta—, y para poder preguntar hace falta el permiso de «instalar
 * apps desconocidas», que se pide la primera vez.
 */
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.katanalabs.nexus/instalar")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "puedeInstalar" -> result.success(puedeInstalar())
                    "pedirPermiso" -> {
                        pedirPermiso()
                        result.success(null)
                    }
                    "instalar" -> {
                        val ruta = call.argument<String>("ruta")
                        if (ruta == null) {
                            result.error("sin-ruta", "falta la ruta del APK", null)
                        } else {
                            result.success(instalar(File(ruta)))
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun puedeInstalar(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
            packageManager.canRequestPackageInstalls()

    private fun pedirPermiso() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        startActivity(
            Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES)
                .setData(Uri.parse("package:$packageName"))
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
        )
    }

    /** `null` si se abrió el instalador; si no, por qué. */
    private fun instalar(apk: File): String? {
        if (!apk.exists()) return "no está el archivo descargado"
        return try {
            val uri = FileProvider.getUriForFile(this, "$packageName.instalador", apk)
            startActivity(
                Intent(Intent.ACTION_VIEW)
                    .setDataAndType(uri, "application/vnd.android.package-archive")
                    .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK),
            )
            null
        } catch (e: Exception) {
            e.message ?: e.javaClass.simpleName
        }
    }
}
