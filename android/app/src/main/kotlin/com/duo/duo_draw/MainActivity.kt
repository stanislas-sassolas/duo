package com.duo.duo_draw

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import com.google.firebase.appdistribution.FirebaseAppDistribution
import com.google.firebase.appdistribution.FirebaseAppDistributionException
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Mises à jour dans l'app via Firebase App Distribution. L'interface
        // (fenêtres en français) est côté Flutter ; ici, seulement les étapes.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "duo/update")
            .setMethodCallHandler { call, result ->
                val distribution = FirebaseAppDistribution.getInstance()
                var replied = false
                fun reply(value: Any?) {
                    if (!replied) {
                        replied = true
                        result.success(value)
                    }
                }
                fun status(e: Exception): String =
                    when ((e as? FirebaseAppDistributionException)?.errorCode) {
                        FirebaseAppDistributionException.Status.AUTHENTICATION_CANCELED,
                        FirebaseAppDistributionException.Status.INSTALLATION_CANCELED -> "canceled"
                        else -> "error:${e.message}"
                    }

                when (call.method) {
                    "version" -> reply(BuildConfig.VERSION_NAME)
                    "isSignedIn" -> reply(distribution.isTesterSignedIn)
                    // Connexion du testeur (compte Google invité), une seule fois.
                    "signIn" -> distribution.signInTester()
                        .addOnSuccessListener { reply("ok") }
                        .addOnFailureListener { e -> reply(status(e)) }
                    // Nouvelle version ? → {version, notes} ou null.
                    "check" -> distribution.checkForNewRelease()
                        .addOnSuccessListener { release ->
                            reply(
                                release?.let {
                                    mapOf(
                                        "version" to it.displayVersion,
                                        "notes" to (it.releaseNotes ?: ""),
                                    )
                                }
                            )
                        }
                        .addOnFailureListener { e -> reply(status(e)) }
                    "canInstall" -> reply(
                        Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
                            packageManager.canRequestPackageInstalls()
                    )
                    // Réglage Android « Installer des applis inconnues » de Duo.
                    "openInstallSettings" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startActivity(
                                Intent(
                                    Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                                    Uri.parse("package:$packageName"),
                                )
                            )
                        }
                        reply(null)
                    }
                    // Télécharge puis ouvre l'installeur Android.
                    "install" -> distribution.updateApp()
                        .addOnSuccessListener { reply("ok") }
                        .addOnFailureListener { e -> reply(status(e)) }
                    else -> result.notImplemented()
                }
            }
    }
}
