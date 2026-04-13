package com.parat.academicasync

import android.Manifest
import android.app.ActivityManager
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.content.pm.PackageManager
import android.os.Bundle
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.Process
import android.os.SystemClock
import android.os.UserManager
import android.provider.Settings
import android.view.WindowManager
import android.widget.Toast
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
        private const val ANDROID_USER_ID_OFFSET = 100000
    }

    private var attendanceLockRequested: Boolean = false
    private var hasRequestedStartupPermissions: Boolean = false
    private var lastAttendanceLockAttemptMillis: Long = 0
    private var lastWindowModeWarningMillis: Long = 0
    private var lastCloneWarningMillis: Long = 0
    private val environmentGuardHandler = Handler(Looper.getMainLooper())
    private val environmentGuardRunnable =
        object : Runnable {
            override fun run() {
                enforceEnvironmentRestrictionsIfNeeded()
                if (!isFinishing && !isDestroyed) {
                    environmentGuardHandler.postDelayed(this, 400)
                }
            }
        }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enforceEnvironmentRestrictionsIfNeeded()
    }

    override fun onStart() {
        super.onStart()
        startEnvironmentGuard()
    }

    override fun onStop() {
        stopEnvironmentGuard()
        super.onStop()
    }

    override fun onDestroy() {
        stopEnvironmentGuard()
        super.onDestroy()
    }

    override fun onResume() {
        super.onResume()
        enforceEnvironmentRestrictionsIfNeeded()
    }

    override fun onPostResume() {
        super.onPostResume()
        if (enforceEnvironmentRestrictionsIfNeeded()) {
            return
        }
        requestStartupPermissionsIfNeeded()
        ensureAttendanceLockIfRequested()
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) {
            if (enforceEnvironmentRestrictionsIfNeeded()) {
                return
            }
            ensureAttendanceLockIfRequested()
        }
    }

    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        enforceEnvironmentRestrictionsIfNeeded()
    }

    @Deprecated("Deprecated in Java")
    override fun onMultiWindowModeChanged(isInMultiWindowMode: Boolean) {
        super.onMultiWindowModeChanged(isInMultiWindowMode)
        enforceEnvironmentRestrictionsIfNeeded()
    }

    override fun onMultiWindowModeChanged(
        isInMultiWindowMode: Boolean,
        newConfig: Configuration,
    ) {
        super.onMultiWindowModeChanged(isInMultiWindowMode, newConfig)
        enforceEnvironmentRestrictionsIfNeeded()
    }

    override fun onPictureInPictureModeChanged(
        isInPictureInPictureMode: Boolean,
        newConfig: Configuration,
    ) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        enforceEnvironmentRestrictionsIfNeeded()
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

    private fun enforceEnvironmentRestrictionsIfNeeded(): Boolean {
        if (isLikelyClonedProfile()) {
            closeClonedInstance()
            return true
        }
        if (isLikelySplitOrMiniWindow()) {
            closeSplitInstance()
            return true
        }
        return isFinishing
    }

    private fun isLikelyClonedProfile(): Boolean {
        val runtimeUserId = Process.myUid() / ANDROID_USER_ID_OFFSET
        if (runtimeUserId != 0) {
            return true
        }

        val dataDirUserId = extractUserIdFromDataPath(filesDir.absolutePath)
        if (dataDirUserId != null && dataDirUserId != 0) {
            return true
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            val userManager = getSystemService(Context.USER_SERVICE) as? UserManager
            if (userManager?.isManagedProfile == true) {
                return true
            }
        }

        return false
    }

    private fun extractUserIdFromDataPath(path: String): Int? {
        val marker = "/data/user/"
        val markerIndex = path.indexOf(marker)
        if (markerIndex < 0) {
            return null
        }

        val userIdStart = markerIndex + marker.length
        if (userIdStart >= path.length) {
            return null
        }

        val userIdEnd = path.indexOf('/', userIdStart).let { index ->
            if (index == -1) path.length else index
        }
        if (userIdEnd <= userIdStart) {
            return null
        }

        return path.substring(userIdStart, userIdEnd).toIntOrNull()
    }

    private fun closeClonedInstance() {
        val now = SystemClock.elapsedRealtime()
        if (now - lastCloneWarningMillis > 1200) {
            lastCloneWarningMillis = now
            Toast
                .makeText(
                    this,
                    "Cloned / Dual app instance allowed nahi hai. Official app hi use karein.",
                    Toast.LENGTH_LONG,
                ).show()
        }

        closeRestrictedInstanceHard()
    }

    private fun isLikelySplitOrMiniWindow(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) {
            return false
        }

        if (isInMultiWindowMode) {
            return true
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && isInPictureInPictureMode) {
            return true
        }

        if (isLikelyFloatingWindow()) {
            return true
        }

        return isWindowBoundsReducedSignificantly()
    }

    private fun closeSplitInstance() {
        val now = SystemClock.elapsedRealtime()
        if (now - lastWindowModeWarningMillis > 1200) {
            lastWindowModeWarningMillis = now
            Toast
                .makeText(
                    this,
                    "Split screen / mini window supported nahi hai. App full screen me kholein.",
                    Toast.LENGTH_LONG,
                ).show()
        }

        closeRestrictedInstanceHard()
    }

    private fun closeRestrictedInstanceHard() {
        try {
            moveTaskToBack(true)
        } catch (_: Exception) {
            // no-op
        }
        try {
            finishAffinity()
        } catch (_: Exception) {
            // no-op
        }
        try {
            finishAndRemoveTask()
        } catch (_: Exception) {
            finish()
        }

        // OEM overlays may keep task alive; kill process to block split/clone bypass reliably.
        environmentGuardHandler.postDelayed(
            {
                try {
                    Process.killProcess(Process.myPid())
                } catch (_: Exception) {
                    // no-op
                }
            },
            120,
        )
    }

    private fun startEnvironmentGuard() {
        environmentGuardHandler.removeCallbacks(environmentGuardRunnable)
        environmentGuardHandler.post(environmentGuardRunnable)
    }

    private fun stopEnvironmentGuard() {
        environmentGuardHandler.removeCallbacks(environmentGuardRunnable)
    }

    private fun isWindowBoundsReducedSignificantly(): Boolean {
        val rootView = window?.decorView ?: return false
        val viewWidth = rootView.width
        val viewHeight = rootView.height
        if (viewWidth <= 0 || viewHeight <= 0) {
            return false
        }

        val minLossPx = (resources.displayMetrics.density * 140).toInt()
        val fullWidth: Int
        val fullHeight: Int

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val windowManager =
                getSystemService(Context.WINDOW_SERVICE) as? WindowManager ?: return false
            val maxBounds = windowManager.maximumWindowMetrics.bounds
            fullWidth = maxBounds.width()
            fullHeight = maxBounds.height()
        } else {
            val displayMetrics = resources.displayMetrics
            fullWidth = displayMetrics.widthPixels
            fullHeight = displayMetrics.heightPixels
        }

        if (fullWidth <= 0 || fullHeight <= 0) {
            return false
        }

        val widthLoss = fullWidth - viewWidth
        val heightLoss = fullHeight - viewHeight
        return widthLoss > minLossPx || heightLoss > minLossPx
    }

    private fun isLikelyFloatingWindow(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
            return false
        }
        val windowManager = getSystemService(Context.WINDOW_SERVICE) as? WindowManager ?: return false
        val currentBounds = windowManager.currentWindowMetrics.bounds
        val maxBounds = windowManager.maximumWindowMetrics.bounds
        val minLossPx = (resources.displayMetrics.density * 120).toInt()
        val widthLoss = maxBounds.width() - currentBounds.width()
        val heightLoss = maxBounds.height() - currentBounds.height()
        return widthLoss > minLossPx || heightLoss > minLossPx
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
