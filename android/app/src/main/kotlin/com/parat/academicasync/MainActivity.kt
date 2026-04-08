package com.parat.academicasync

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    companion object {
        private const val UPDATE_CHANNEL = "academic_async/update_installer"
        private const val APK_MIME_TYPE = "application/vnd.android.package-archive"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            UPDATE_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "canRequestPackageInstalls" -> {
                    result.success(canInstallPackages())
                }

                "getSupportedAbis" -> {
                    result.success(Build.SUPPORTED_ABIS.toList())
                }

                "openUnknownAppSourcesSettings" -> {
                    openUnknownAppSourcesSettings()
                    result.success(true)
                }

                "getUpdateStorageDir" -> {
                    result.success(getUpdateStorageDir())
                }

                "installApk" -> {
                    val path = call.argument<String>("path")
                    if (path.isNullOrBlank()) {
                        result.error("invalid_path", "APK path is required", null)
                        return@setMethodCallHandler
                    }
                    installApk(path, result)
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun canInstallPackages(): Boolean {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
            packageManager.canRequestPackageInstalls()
    }

    private fun openUnknownAppSourcesSettings() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }

        val intent = Intent(
            Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
            Uri.parse("package:$packageName"),
        ).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(intent)
    }

    private fun getUpdateStorageDir(): String {
        val updatesDir = File(cacheDir, "updates")
        if (!updatesDir.exists()) {
            updatesDir.mkdirs()
        }
        return updatesDir.absolutePath
    }

    private fun installApk(
        path: String,
        result: MethodChannel.Result,
    ) {
        val apkFile = File(path)
        if (!apkFile.exists()) {
            result.error("file_not_found", "APK file not found", null)
            return
        }
        if (!canInstallPackages()) {
            result.error(
                "install_permission_required",
                "Allow app installs from this source first",
                null,
            )
            return
        }

        val authority = "$packageName.updateFileProvider"
        val apkUri =
            try {
                FileProvider.getUriForFile(this, authority, apkFile)
            } catch (error: IllegalArgumentException) {
                result.error(
                    "invalid_apk_uri",
                    error.localizedMessage ?: "Unable to open the downloaded APK",
                    null,
                )
                return
            }

        val installIntent = Intent(Intent.ACTION_INSTALL_PACKAGE).apply {
            data = apkUri
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        val fallbackIntent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(apkUri, APK_MIME_TYPE)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }

        val resolvedIntent =
            when {
                installIntent.resolveActivity(packageManager) != null -> installIntent
                fallbackIntent.resolveActivity(packageManager) != null -> fallbackIntent
                else -> null
            }

        if (resolvedIntent == null) {
            result.error(
                "installer_unavailable",
                "Android installer app was not found",
                null,
            )
            return
        }

        try {
            startActivity(resolvedIntent)
            result.success(true)
        } catch (error: ActivityNotFoundException) {
            result.error(
                "installer_unavailable",
                error.localizedMessage ?: "Android installer app was not found",
                null,
            )
        } catch (error: Exception) {
            result.error(
                "installer_failed",
                error.localizedMessage ?: "Unable to open Android installer",
                null,
            )
        }
    }
}
