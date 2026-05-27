package com.birdnet.birdnet_live

import android.content.Intent
import android.os.Bundle
import android.view.WindowManager
import com.google.android.play.core.assetpacks.AssetPackManagerFactory
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*
import java.io.File
import java.io.FileNotFoundException

class MainActivity: FlutterActivity() {
    private val WAKELOCK_CHANNEL = "com.birdnet/wakelock"
    private val AUDIO_DECODER_CHANNEL = "com.birdnet/audio_decoder"
    private val ASSET_PACK_CHANNEL = "com.birdnet/asset_pack"
    private val WIDGET_STATS_CHANNEL = "com.birdnet/widget_stats"
    private val scope = CoroutineScope(Dispatchers.Default + SupervisorJob())
    private var pendingLaunchRequest: Map<String, Any?>? = null
    private var launchTargetEvents: EventChannel.EventSink? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        pendingLaunchRequest = extractLaunchRequest(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            AppLaunchTargetContract.eventsChannel,
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                launchTargetEvents = events
            }

            override fun onCancel(arguments: Any?) {
                launchTargetEvents = null
            }
        })

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            AppLaunchTargetContract.channel,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "takeInitialTarget" -> {
                    result.success(pendingLaunchRequest)
                    pendingLaunchRequest = null
                }
                else -> result.notImplemented()
            }
        }

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

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WIDGET_STATS_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "refreshDetectionStatsWidget" -> {
                        DetectionStatsWidgetProvider.refreshAll(applicationContext)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)

        val request = extractLaunchRequest(intent) ?: return
        pendingLaunchRequest = request
        launchTargetEvents?.success(request)
    }

    private fun extractLaunchRequest(intent: Intent?): Map<String, Any?>? {
        if (intent == null) return null

        val fromExtra = intent.getStringExtra(AppLaunchTargetContract.extraTarget)
        val target = when {
            !fromExtra.isNullOrBlank() -> fromExtra
            intent.action == AppLaunchTargetContract.actionOpenLiveMode ->
                AppLaunchTargetContract.targetLive
            else -> null
        }

        if (target == null) return null

        return mapOf(
            AppLaunchTargetContract.payloadTarget to target,
            AppLaunchTargetContract.payloadLiveAutoStart to
                intent.getBooleanExtra(AppLaunchTargetContract.extraLiveAutoStart, false),
        )
    }

    override fun onDestroy() {
        scope.cancel()
        super.onDestroy()
    }
}
