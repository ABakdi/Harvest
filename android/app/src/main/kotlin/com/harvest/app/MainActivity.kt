package com.harvest.app

import android.content.ContentValues
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * FlutterFragmentActivity, not FlutterActivity: the biometric prompt
 * behind the app lock is a fragment and needs a FragmentActivity host.
 */
class MainActivity : FlutterFragmentActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DOWNLOADS_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "saveToDownloads" -> saveToDownloads(call.arguments(), result)
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SECURITY_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setSecure" -> {
                        setSecure(call.arguments<Boolean>() ?: false)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * Keeps the app's contents out of the recents thumbnail while the
     * app lock is armed (checkpoint rule L4).
     *
     * Dart's lifecycle callbacks arrive after Android has already taken
     * that snapshot, so a shield drawn in Flutter is always one frame
     * too late. FLAG_SECURE is the only thing that gets there first. It
     * blocks screenshots too, which is the deal the lock switch makes.
     */
    private fun setSecure(secure: Boolean) {
        runOnUiThread {
            if (secure) {
                window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
            } else {
                window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
            }
        }
    }

    /**
     * Writes one file into the public Downloads folder.
     *
     * A whole plugin for a single file write would be a dependency to
     * keep; this is the two paths that actually exist. On Android 10+
     * MediaStore owns the folder and no permission is involved at all.
     */
    private fun saveToDownloads(args: Map<String, Any>?, result: MethodChannel.Result) {
        val fileName = args?.get("fileName") as? String
        val bytes = args?.get("bytes") as? ByteArray
        val mimeType = args?.get("mimeType") as? String ?: "application/octet-stream"
        if (fileName == null || bytes == null) {
            result.error("arguments", "fileName and bytes are required", null)
            return
        }

        try {
            val path = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                writeWithMediaStore(fileName, bytes, mimeType)
            } else {
                writeLegacy(fileName, bytes)
            }
            result.success(path)
        } catch (error: SecurityException) {
            result.error("permission", error.message, null)
        } catch (error: Exception) {
            result.error("write", error.message, null)
        }
    }

    private fun writeWithMediaStore(
        fileName: String,
        bytes: ByteArray,
        mimeType: String,
    ): String {
        val resolver = contentResolver
        val values = ContentValues().apply {
            put(MediaStore.Downloads.DISPLAY_NAME, fileName)
            put(MediaStore.Downloads.MIME_TYPE, mimeType)
            put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
            // Hidden from other apps until the bytes are all there, so a
            // half-written workbook is never picked up as a whole one.
            put(MediaStore.Downloads.IS_PENDING, 1)
        }
        val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
            ?: throw IllegalStateException("Downloads rejected the file")
        try {
            resolver.openOutputStream(uri)?.use { it.write(bytes) }
                ?: throw IllegalStateException("Downloads gave no stream")
        } catch (error: Exception) {
            resolver.delete(uri, null, null)
            throw error
        }
        values.clear()
        values.put(MediaStore.Downloads.IS_PENDING, 0)
        resolver.update(uri, values, null, null)
        return "${Environment.DIRECTORY_DOWNLOADS}/$fileName"
    }

    /** Android 8.0–9.0, where Downloads is still a plain directory. */
    private fun writeLegacy(fileName: String, bytes: ByteArray): String {
        val directory =
            Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
        if (!directory.exists() && !directory.mkdirs()) {
            throw IllegalStateException("Downloads is not available")
        }
        val file = File(directory, fileName)
        file.writeBytes(bytes)
        return file.absolutePath
    }

    private companion object {
        const val DOWNLOADS_CHANNEL = "harvest/downloads"
        const val SECURITY_CHANNEL = "harvest/security"
    }
}
