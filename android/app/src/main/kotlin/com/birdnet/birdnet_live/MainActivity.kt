package com.birdnet.birdnet_live

import android.os.BatteryManager
import android.os.Build
import android.os.PowerManager
import android.view.WindowManager
import com.google.android.play.core.assetpacks.AssetPackManagerFactory
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*
import java.io.File
import java.io.FileNotFoundException

class MainActivity: FlutterActivity() {
    private val WAKELOCK_CHANNEL = "com.birdnet/wakelock"
    private val AUDIO_DECODER_CHANNEL = "com.birdnet/audio_decoder"
    private val ASSET_PACK_CHANNEL = "com.birdnet/asset_pack"
    private val DEVICE_STATS_CHANNEL = "com.birdnet/device_stats"
    private val scope = CoroutineScope(Dispatchers.Default + SupervisorJob())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Wakelock channel.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WAKELOCK_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "enable" -> {
                    window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    result.success(null)
                }
                "disable" -> {
                    window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        // Audio decoder channel — decode compressed audio to PCM via MediaCodec.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AUDIO_DECODER_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "inspect" -> {
                    val path = call.argument<String>("path")
                    if (path == null) {
                        result.error("INVALID_ARG", "Missing 'path' argument", null)
                        return@setMethodCallHandler
                    }
                    scope.launch {
                        try {
                            val metadata = NativeAudioDecoder.inspect(path)
                            withContext(Dispatchers.Main) {
                                result.success(metadata)
                            }
                        } catch (e: Exception) {
                            withContext(Dispatchers.Main) {
                                result.error("INSPECT_ERROR", e.message, null)
                            }
                        }
                    }
                }
                "decode" -> {
                    val path = call.argument<String>("path")
                    if (path == null) {
                        result.error("INVALID_ARG", "Missing 'path' argument", null)
                        return@setMethodCallHandler
                    }
                    scope.launch {
                        try {
                            val decoded = NativeAudioDecoder.decode(path)
                            withContext(Dispatchers.Main) {
                                result.success(decoded)
                            }
                        } catch (e: Exception) {
                            withContext(Dispatchers.Main) {
                                result.error("DECODE_ERROR", e.message, null)
                            }
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }

        // Asset pack channel — resolves the on-device path of an
        // install-time Play Asset Delivery pack. Used to locate the ONNX
        // model files in App Bundle (AAB) installs from the Play Store.
        // On sideload APK installs there is no asset pack, so the call
        // returns null and the Dart side falls back to extracting the
        // models from `rootBundle`.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ASSET_PACK_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getPackPath" -> {
                    val packName = call.argument<String>("packName")
                    if (packName.isNullOrBlank()) {
                        result.error("INVALID_ARG", "Missing 'packName'", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val mgr = AssetPackManagerFactory.getInstance(applicationContext)
                        val location = mgr.getPackLocation(packName)
                        result.success(location?.assetsPath())
                    } catch (e: Throwable) {
                        // Sideload APK without Play Asset Delivery support,
                        // pack not installed, or any other failure: report
                        // null so the Dart side falls back to rootBundle.
                        result.success(null)
                    }
                }
                // Extract a file from the APK's AssetManager (which includes
                // install-time asset packs merged into the app namespace) to
                // a real on-disk path. ONNX Runtime needs a file path /
                // mmap, not an InputStream. Idempotent: if the destination
                // already exists with the expected size, the copy is
                // skipped. Returns null when the asset is not present (used
                // as the probe for "are we in a Play install with the
                // models_pack merged into AssetManager?").
                "extractAsset" -> {
                    val assetPath = call.argument<String>("assetPath")
                    val destName = call.argument<String>("destName")
                    if (assetPath.isNullOrBlank() || destName.isNullOrBlank()) {
                        result.error(
                            "INVALID_ARG",
                            "Missing 'assetPath' or 'destName'",
                            null,
                        )
                        return@setMethodCallHandler
                    }
                    scope.launch {
                        try {
                            val outFile = File(applicationContext.filesDir, destName)
                            // Open the asset to (a) probe for presence and
                            // (b) read its uncompressed length via FileDescriptor
                            // when possible, so we can short-circuit if the
                            // destination already exists.
                            val inStream = try {
                                applicationContext.assets.open(assetPath)
                            } catch (e: FileNotFoundException) {
                                withContext(Dispatchers.Main) {
                                    result.success(null)
                                }
                                return@launch
                            }
                            // Try to determine the uncompressed length cheaply
                            // via openFd (works for noCompress assets like .onnx).
                            var expectedSize = -1L
                            try {
                                applicationContext.assets.openFd(assetPath).use { afd ->
                                    expectedSize = afd.length
                                }
                            } catch (_: Throwable) {
                                // Compressed asset: fall back to comparing after copy.
                            }
                            if (outFile.exists() && expectedSize > 0 &&
                                outFile.length() == expectedSize) {
                                inStream.close()
                                withContext(Dispatchers.Main) {
                                    result.success(outFile.absolutePath)
                                }
                                return@launch
                            }
                            // Stream-copy to a temp file then atomically rename
                            // so a partial copy from a previous crash never
                            // looks like a complete file.
                            val tmpFile = File(outFile.parentFile, "$destName.tmp")
                            inStream.use { input ->
                                tmpFile.outputStream().use { output ->
                                    input.copyTo(output, bufferSize = 1 shl 20)
                                }
                            }
                            if (outFile.exists()) outFile.delete()
                            if (!tmpFile.renameTo(outFile)) {
                                throw java.io.IOException(
                                    "Failed to rename ${tmpFile.absolutePath} to ${outFile.absolutePath}"
                                )
                            }
                            withContext(Dispatchers.Main) {
                                result.success(outFile.absolutePath)
                            }
                        } catch (e: Throwable) {
                            withContext(Dispatchers.Main) {
                                result.error(
                                    "EXTRACT_ERROR",
                                    e.message ?: "extractAsset failed",
                                    null,
                                )
                            }
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }

        // Device stats channel — power/thermal metrics for the benchmark screen.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DEVICE_STATS_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getStats" -> {
                    val bm = applicationContext.getSystemService(BATTERY_SERVICE) as BatteryManager
                    val pm = applicationContext.getSystemService(POWER_SERVICE) as PowerManager

                    // Instantaneous current in µA (negative = discharging).
                    val currentUa = bm.getIntProperty(BatteryManager.BATTERY_PROPERTY_CURRENT_NOW)
                    // Voltage in mV — comes from the battery-changed broadcast, not BatteryManager.
                    val batteryIntent = applicationContext.registerReceiver(
                        null,
                        android.content.IntentFilter(android.content.Intent.ACTION_BATTERY_CHANGED)
                    )
                    val voltageMv = batteryIntent?.getIntExtra(BatteryManager.EXTRA_VOLTAGE, -1) ?: -1
                    // Battery level 0–100.
                    val level = bm.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
                    // Thermal status 0–6 (NONE/LIGHT/MODERATE/SEVERE/CRITICAL/EMERGENCY/SHUTDOWN).
                    val thermalStatus = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                        pm.currentThermalStatus
                    } else {
                        -1
                    }

                    // Chip/SoC info.
                    val socModel = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        Build.SOC_MODEL
                    } else {
                        Build.HARDWARE
                    }

                    result.success(mapOf(
                        "currentUa" to currentUa,
                        "voltageMv" to voltageMv,
                        "batteryLevel" to level,
                        "thermalStatus" to thermalStatus,
                        "socModel" to socModel,
                    ))
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        scope.cancel()
        super.onDestroy()
    }
}
