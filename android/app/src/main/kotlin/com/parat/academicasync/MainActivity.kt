package com.parat.academicasync

import android.Manifest
import android.app.ActivityManager
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.SystemClock
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    companion object {
        private const val UPDATE_CHANNEL = "academic_async/update_installer"
        private const val ATTENDANCE_LOCK_CHANNEL = "academic_async/attendance_lock"
        private const val APK_MIME_TYPE = "application/vnd.android.package-archive"
        private const val STARTUP_PERMISSION_REQUEST_CODE = 4107
    }

    private var attendanceLockRequested: Boolean = false
    private var hasRequestedStartupPermissions: Boolean = false
    private var lastAttendanceLockAttemptMillis: Long = 0

    override fun onPostResume() {
        super.onPostResume()
        requestStartupPermissionsIfNeeded()
        ensureAttendanceLockIfRequested()
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) {
            ensureAttendanceLockIfRequested()
        }
    }

    override fun onBackPressed() {
        if (attendanceLockRequested) {
            return
        }
        super.onBackPressed()
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

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            ATTENDANCE_LOCK_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "setAttendanceLock" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    setAttendanceLock(enabled, result)
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun setAttendanceLock(
        enabled: Boolean,
        result: MethodChannel.Result,
    ) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP) {
            result.error(
                "unsupported_android",
                "Attendance lock requires Android 5.0 or above",
                null,
            )
            return
        }

        try {
            if (enabled) {
                enableAttendanceLock()
            } else {
                disableAttendanceLock()
            }
            val lockEnabledNow = isInLockTaskMode()
            result.success(if (enabled) lockEnabledNow else !lockEnabledNow)
        } catch (error: SecurityException) {
            result.error(
                "screen_pinning_unavailable",
                error.localizedMessage ?: "Screen pinning is not available on this device",
                null,
            )
        } catch (error: Exception) {
            result.error(
                "attendance_lock_failed",
                error.localizedMessage ?: "Unable to change attendance lock state",
                null,
            )
        }
    }

    private fun enableAttendanceLock() {
        if (isInLockTaskMode()) {
            attendanceLockRequested = true
            return
        }
        attendanceLockRequested = true
        ensureAttendanceLockIfRequested(force = true)
    }

    private fun disableAttendanceLock() {
        if (!isInLockTaskMode()) {
            attendanceLockRequested = false
            return
        }
        stopLockTask()
        attendanceLockRequested = false
    }

    private fun isInLockTaskMode(): Boolean {
        val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            activityManager.lockTaskModeState != ActivityManager.LOCK_TASK_MODE_NONE
        } else {
            @Suppress("DEPRECATION")
            activityManager.isInLockTaskMode
        }
    }

    private fun canInstallPackages(): Boolean {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
            packageManager.canRequestPackageInstalls()
    }

    private fun requestStartupPermissionsIfNeeded() {
        if (hasRequestedStartupPermissions || Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            return
        }

        val requiredPermissions = mutableListOf(
            Manifest.permission.ACCESS_FINE_LOCATION,
            Manifest.permission.ACCESS_COARSE_LOCATION,
            Manifest.permission.CAMERA,
        )
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            requiredPermissions.add(Manifest.permission.POST_NOTIFICATIONS)
        }

        val missingPermissions =
            requiredPermissions.filter { permission ->
                ContextCompat.checkSelfPermission(this, permission) !=
                    PackageManager.PERMISSION_GRANTED
            }

        if (missingPermissions.isEmpty()) {
            hasRequestedStartupPermissions = true
            return
        }

        hasRequestedStartupPermissions = true
        ActivityCompat.requestPermissions(
            this,
            missingPermissions.toTypedArray(),
            STARTUP_PERMISSION_REQUEST_CODE,
        )
    }

    private fun ensureAttendanceLockIfRequested(force: Boolean = false) {
        if (!attendanceLockRequested || Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP) {
            return
        }
        if (isInLockTaskMode()) {
            return
        }

        val now = SystemClock.elapsedRealtime()
        if (!force && now - lastAttendanceLockAttemptMillis < 1000) {
            return
        }
        lastAttendanceLockAttemptMillis = now

        try {
            startLockTask()
        } catch (_: SecurityException) {
            // Flutter side already shows a warning when strict lock cannot be enforced.
        } catch (_: Exception) {
            // Avoid crashing if screen pinning is unavailable on specific OEM builds.
        }
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
