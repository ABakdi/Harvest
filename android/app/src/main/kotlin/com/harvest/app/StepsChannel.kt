package com.harvest.app

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.activity.result.ActivityResultLauncher
import androidx.core.content.ContextCompat
import androidx.fragment.app.FragmentActivity
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.PermissionController
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.StepsRecord
import androidx.health.connect.client.request.AggregateRequest
import androidx.health.connect.client.time.TimeRangeFilter
import androidx.lifecycle.lifecycleScope
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.launch
import java.time.Instant

/**
 * Where the step count comes from.
 *
 * Two sources, tried in this order:
 *
 * 1. **Health Connect** — the system's own step store. Samsung Health,
 *    Google Fit and the Pixel's counter all write to it, so reading
 *    from it means reading whatever the phone already trusts, and the
 *    numbers agree with the phone's own health app. Aggregated per
 *    window, so a 3 AM → 3 AM Harvest Day is one query and the whole
 *    reboot-and-delta business goes away.
 * 2. **The raw step counter sensor** — for a phone with no Health
 *    Connect at all. It counts since boot, so the Dart side keeps the
 *    delta arithmetic for this path only.
 *
 * Neither involves an account or a network: Health Connect is an
 * on-device store, and the sensor is a sensor.
 */
class StepsChannel(private val activity: FragmentActivity, messenger: BinaryMessenger) {

    private val channel = MethodChannel(messenger, CHANNEL)
    private var permissionResult: MethodChannel.Result? = null
    private val healthPermissions = setOf(HealthPermission.getReadPermission(StepsRecord::class))

    /**
     * Registered up front because the activity result API demands it
     * before the activity starts; the result it hands back is whatever
     * Flutter call was waiting for it.
     */
    private val healthLauncher: ActivityResultLauncher<Set<String>> =
        activity.registerForActivityResult(
            PermissionController.createRequestPermissionResultContract(),
        ) { granted ->
            val result = permissionResult
            permissionResult = null
            result?.success(granted.containsAll(healthPermissions))
        }

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "status" -> result.success(status())
                "requestPermission" -> requestPermission(result)
                "readTotals" -> readTotals(call.arguments(), result)
                "readCounter" -> readCounter(result)
                "openHealthConnect" -> {
                    openHealthConnect()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    // --------------------------------------------------------------- status

    private fun healthConnectAvailable(): Boolean =
        HealthConnectClient.getSdkStatus(activity) == HealthConnectClient.SDK_AVAILABLE

    /** Health Connect exists but needs installing or updating. */
    private fun healthConnectInstallable(): Boolean =
        HealthConnectClient.getSdkStatus(activity) ==
            HealthConnectClient.SDK_UNAVAILABLE_PROVIDER_UPDATE_REQUIRED

    private fun sensorAvailable(): Boolean {
        val manager = activity.getSystemService(Context.SENSOR_SERVICE) as SensorManager
        return manager.getDefaultSensor(Sensor.TYPE_STEP_COUNTER) != null
    }

    private fun sensorGranted(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.Q ||
            ContextCompat.checkSelfPermission(activity, Manifest.permission.ACTIVITY_RECOGNITION) ==
            PackageManager.PERMISSION_GRANTED

    /**
     * One answer for the Dart side: which source this phone has, and
     * whether it may be read yet. Health Connect's grant is a suspend
     * call, so the status is delivered through the same map rather
     * than returned.
     */
    private fun status(): Map<String, Any> {
        val backend = when {
            healthConnectAvailable() -> "healthConnect"
            sensorAvailable() -> "sensor"
            else -> "none"
        }
        return mapOf(
            "backend" to backend,
            "installable" to healthConnectInstallable(),
            // For the sensor the answer is known now; for Health
            // Connect it is looked up by [readTotals], which reports
            // "denied" instead of numbers.
            "granted" to (backend == "sensor" && sensorGranted()),
        )
    }

    // ----------------------------------------------------------- permission

    private fun requestPermission(result: MethodChannel.Result) {
        if (permissionResult != null) {
            result.error("busy", "a permission request is already showing", null)
            return
        }
        when {
            healthConnectAvailable() -> {
                permissionResult = result
                healthLauncher.launch(healthPermissions)
            }
            sensorAvailable() -> {
                if (sensorGranted()) {
                    result.success(true)
                    return
                }
                permissionResult = result
                activity.requestPermissions(
                    arrayOf(Manifest.permission.ACTIVITY_RECOGNITION),
                    REQUEST_ACTIVITY,
                )
            }
            else -> result.success(false)
        }
    }

    /** Called by the activity for the sensor permission's answer. */
    fun onRequestPermissionsResult(requestCode: Int, grantResults: IntArray): Boolean {
        if (requestCode != REQUEST_ACTIVITY) return false
        val result = permissionResult
        permissionResult = null
        result?.success(grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED)
        return true
    }

    // ----------------------------------------------------- health connect

    /**
     * Step totals for a list of [start, end) windows, in epoch millis.
     *
     * Returns a list of longs, or the string "denied" when the read
     * permission is not held — so the caller can ask for it rather than
     * mistaking a refusal for a quiet day.
     */
    private fun readTotals(windows: List<List<Long>>?, result: MethodChannel.Result) {
        if (windows == null) {
            result.error("arguments", "windows are required", null)
            return
        }
        if (!healthConnectAvailable()) {
            result.success("unavailable")
            return
        }
        val client = HealthConnectClient.getOrCreate(activity)
        activity.lifecycleScope.launch {
            try {
                val granted = client.permissionController.getGrantedPermissions()
                if (!granted.containsAll(healthPermissions)) {
                    result.success("denied")
                    return@launch
                }
                val totals = windows.map { window ->
                    val response = client.aggregate(
                        AggregateRequest(
                            metrics = setOf(StepsRecord.COUNT_TOTAL),
                            timeRangeFilter = TimeRangeFilter.between(
                                Instant.ofEpochMilli(window[0]),
                                Instant.ofEpochMilli(window[1]),
                            ),
                        ),
                    )
                    response[StepsRecord.COUNT_TOTAL] ?: 0L
                }
                result.success(totals)
            } catch (error: SecurityException) {
                result.success("denied")
            } catch (error: Exception) {
                result.error("read", error.message, null)
            }
        }
    }

    private fun openHealthConnect() {
        val intent = if (healthConnectInstallable()) {
            Intent(Intent.ACTION_VIEW).apply {
                data = Uri.parse(
                    "market://details?id=$HEALTH_CONNECT_PACKAGE&url=healthconnect%3A%2F%2Fonboarding",
                )
                setPackage("com.android.vending")
                putExtra("overlay", true)
                putExtra("callerId", activity.packageName)
            }
        } else {
            Intent(HealthConnectClient.ACTION_HEALTH_CONNECT_SETTINGS)
        }
        try {
            activity.startActivity(intent)
        } catch (_: Exception) {
            // No store and no settings screen: nothing to open.
        }
    }

    // --------------------------------------------------------------- sensor

    /**
     * One reading of the since-boot step counter, or null when the
     * sensor stays silent. The counter only reports on registration
     * and on change, so a phone lying still can take a moment — and a
     * phone with no reading yet since boot never answers, which is
     * what the timeout is for.
     */
    private fun readCounter(result: MethodChannel.Result) {
        if (!sensorAvailable() || !sensorGranted()) {
            result.success(null)
            return
        }
        val manager = activity.getSystemService(Context.SENSOR_SERVICE) as SensorManager
        val sensor = manager.getDefaultSensor(Sensor.TYPE_STEP_COUNTER)
        val handler = Handler(Looper.getMainLooper())
        var answered = false
        val listener = object : SensorEventListener {
            override fun onSensorChanged(event: SensorEvent) {
                if (answered) return
                answered = true
                manager.unregisterListener(this)
                result.success(event.values[0].toLong())
            }

            override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit
        }
        manager.registerListener(listener, sensor, SensorManager.SENSOR_DELAY_NORMAL)
        handler.postDelayed({
            if (answered) return@postDelayed
            answered = true
            manager.unregisterListener(listener)
            result.success(null)
        }, SENSOR_TIMEOUT_MS)
    }

    companion object {
        const val CHANNEL = "harvest/steps"
        const val HEALTH_CONNECT_PACKAGE = "com.google.android.apps.healthdata"
        private const val REQUEST_ACTIVITY = 4101
        private const val SENSOR_TIMEOUT_MS = 3000L
    }
}
