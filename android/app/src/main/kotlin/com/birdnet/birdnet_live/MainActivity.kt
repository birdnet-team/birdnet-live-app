package com.birdnet.birdnet_live

import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.provider.OpenableColumns
import android.view.WindowManager
import android.webkit.MimeTypeMap
import androidx.core.app.NotificationCompat
import com.google.android.play.core.assetpacks.AssetPackManagerFactory
import com.pravera.flutter_foreground_task.service.ForegroundService
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*
import java.io.File
import java.io.FileNotFoundException
import java.io.IOException
import java.util.Collections

class MainActivity: FlutterActivity() {
    private val WAKELOCK_CHANNEL = "com.birdnet/wakelock"
    private val AUDIO_DECODER_CHANNEL = "com.birdnet/audio_decoder"
    private val ASSET_PACK_CHANNEL = "com.birdnet/asset_pack"
    private val ARU_NOTIFICATION_CHANNEL = "com.birdnet/aru_notification"
    private val ARU_NOTIFICATION_INTENTS_CHANNEL = "com.birdnet/aru_notification_intents"
    private val ARU_NOTIFICATION_ACTION_EXTRA = "com.birdnet.aru_notification_action"
    private val QUICK_ACTION_INTENTS_CHANNEL = "com.birdnet/quick_action_intents"
    private val SHARED_MEDIA_CHANNEL = "com.birdnet/shared_media"
    private val SHARED_MEDIA_DIR = "shared_audio"
    private val scope = CoroutineScope(Dispatchers.Default + SupervisorJob())
    private val activeDecodeJobs = Collections.synchronizedSet(mutableSetOf<Job>())
    private var pendingAruNotificationAction: String? = null
    private var aruNotificationIntentChannel: MethodChannel? = null
    private var pendingQuickAction: String? = null
    private var quickActionIntentChannel: MethodChannel? = null
    private var pendingSharedMedia: Map<String, String?>? = null
    private var sharedMediaChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        // Clear audio ACTION_VIEW data before FlutterActivity derives its
        // initial route from the Intent URI.
        captureSharedMedia(intent)
        super.onCreate(savedInstanceState)
        captureAruNotificationAction(intent)
        captureQuickAction(intent)
        ForegroundService.handleNotificationContentIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        // Clear audio ACTION_VIEW data before FlutterActivity forwards the
        // Intent to Flutter's deep-link router.
        captureSharedMedia(intent)
        super.onNewIntent(intent)
        setIntent(intent)
        captureAruNotificationAction(intent)
        captureQuickAction(intent)
        ForegroundService.handleNotificationContentIntent(intent)
    }

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

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ARU_NOTIFICATION_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "update" -> {
                    @Suppress("UNCHECKED_CAST")
                    val args = call.arguments as? Map<String, Any?>
                    if (args == null) {
                        result.error("INVALID_ARG", "Missing notification arguments", null)
                        return@setMethodCallHandler
                    }
                    try {
                        updateAruNotification(args)
                        result.success(null)
                    } catch (e: Throwable) {
                        result.error("NOTIFICATION_ERROR", e.message ?: "Notification update failed", null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        aruNotificationIntentChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            ARU_NOTIFICATION_INTENTS_CHANNEL
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "takePendingAction" -> {
                        val action = pendingAruNotificationAction
                        pendingAruNotificationAction = null
                        result.success(action)
                    }
                    "clearPendingAction" -> {
                        val action = call.arguments as? String
                        if (pendingAruNotificationAction == action) {
                            pendingAruNotificationAction = null
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }

        quickActionIntentChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            QUICK_ACTION_INTENTS_CHANNEL
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "takePendingAction" -> {
                        val action = pendingQuickAction
                        pendingQuickAction = null
                        result.success(action)
                    }
                    "clearPendingAction" -> {
                        val action = call.arguments as? String
                        if (pendingQuickAction == action) {
                            pendingQuickAction = null
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }

        // Shared-media channel — "Share with"/"Open with" audio hand-off.
        //
        // Split in two calls on purpose: `takePendingSharedFile` answers
        // immediately with the URI so Dart can open File Analysis right away,
        // and `importSharedFile` does the potentially slow copy behind that
        // screen's own progress indicator.
        sharedMediaChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SHARED_MEDIA_CHANNEL
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "takePendingSharedFile" -> {
                        val shared = pendingSharedMedia
                        pendingSharedMedia = null
                        result.success(shared)
                    }
                    "importSharedFile" -> {
                        val uri = call.argument<String>("uri")
                        if (uri.isNullOrBlank()) {
                            result.error("INVALID_ARG", "Missing 'uri'", null)
                            return@setMethodCallHandler
                        }
                        val name = call.argument<String>("name")
                        scope.launch {
                            try {
                                val path = importSharedMedia(uri, name)
                                withContext(Dispatchers.Main) {
                                    result.success(path)
                                }
                            } catch (e: Throwable) {
                                withContext(Dispatchers.Main) {
                                    result.error(
                                        "IMPORT_ERROR",
                                        e.message ?: "Could not read the shared file",
                                        null,
                                    )
                                }
                            }
                        }
                    }
                    "discardSharedFile" -> {
                        // Nothing to release. The shared URI belongs to the app
                        // that sent it, and no copy of our own exists until the
                        // import creates one.
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
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
                        } catch (e: Throwable) {
                            withContext(Dispatchers.Main) {
                                result.error("INSPECT_ERROR", e.message ?: "Unknown error", null)
                            }
                        }
                    }
                }
                "decode" -> {
                    val path = call.argument<String>("path")
                    val tempPcmPath = call.argument<String>("tempPcmPath")
                    if (path == null || tempPcmPath == null) {
                        result.error("INVALID_ARG", "Missing 'path' or 'tempPcmPath' argument", null)
                        return@setMethodCallHandler
                    }
                    launchDecode(allowConcurrent = false) {
                        try {
                            val decoded = NativeAudioDecoder.decode(path, tempPcmPath) {
                                !coroutineContext.isActive
                            }
                            withContext(Dispatchers.Main) {
                                result.success(decoded)
                            }
                        } catch (e: CancellationException) {
                            withContext(NonCancellable + Dispatchers.Main) {
                                result.error("DECODE_CANCELLED", "Decoding cancelled", null)
                            }
                        } catch (e: Throwable) {
                            withContext(NonCancellable + Dispatchers.Main) {
                                result.error("DECODE_ERROR", e.message ?: "Unknown error", null)
                            }
                        }
                    }
                }
                "decodeRange" -> {
                    val path = call.argument<String>("path")
                    val startSample = call.argument<Number>("startSample")?.toLong()
                    val count = call.argument<Number>("count")?.toInt()
                    val allowConcurrent = call.argument<Boolean>("allowConcurrent") ?: false
                    if (path == null || startSample == null || count == null) {
                        result.error("INVALID_ARG", "Missing 'path', 'startSample', or 'count' argument", null)
                        return@setMethodCallHandler
                    }
                    launchDecode(allowConcurrent = allowConcurrent) {
                        try {
                            val decoded = NativeAudioDecoder.decodeRange(path, startSample, count) {
                                !coroutineContext.isActive
                            }
                            withContext(Dispatchers.Main) {
                                result.success(decoded)
                            }
                        } catch (e: CancellationException) {
                            withContext(NonCancellable + Dispatchers.Main) {
                                result.error("DECODE_CANCELLED", "Decoding cancelled", null)
                            }
                        } catch (e: Throwable) {
                            withContext(NonCancellable + Dispatchers.Main) {
                                result.error("DECODE_ERROR", e.message ?: "Unknown error", null)
                            }
                        }
                    }
                }
                "cancelDecode" -> {
                    cancelActiveDecodes()
                    result.success(null)
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
    }

    private fun launchDecode(
        allowConcurrent: Boolean,
        block: suspend CoroutineScope.() -> Unit,
    ) {
        if (!allowConcurrent) {
            cancelActiveDecodes()
        }
        lateinit var job: Job
        job = scope.launch(start = CoroutineStart.LAZY, block = block)
        activeDecodeJobs.add(job)
        job.invokeOnCompletion { activeDecodeJobs.remove(job) }
        job.start()
    }

    private fun cancelActiveDecodes() {
        val jobs = synchronized(activeDecodeJobs) { activeDecodeJobs.toList() }
        jobs.forEach { it.cancel() }
        activeDecodeJobs.clear()
    }

    override fun onDestroy() {
        aruNotificationIntentChannel = null
        quickActionIntentChannel = null
        sharedMediaChannel = null
        scope.cancel()
        super.onDestroy()
    }

    private fun captureAruNotificationAction(intent: Intent?) {
        val action = intent?.getStringExtra(ARU_NOTIFICATION_ACTION_EXTRA) ?: return
        pendingAruNotificationAction = action
        aruNotificationIntentChannel?.invokeMethod("onNotificationAction", action)
        intent.removeExtra(ARU_NOTIFICATION_ACTION_EXTRA)
    }

    private fun captureQuickAction(intent: Intent?) {
        val action = intent?.getStringExtra(
            QuickListenContract.QUICK_ACTION_EXTRA
        ) ?: return
        pendingQuickAction = action
        quickActionIntentChannel?.invokeMethod("onQuickAction", action)
        intent.removeExtra(QuickListenContract.QUICK_ACTION_EXTRA)
    }

    // Picks up an ACTION_SEND / ACTION_VIEW audio hand-off.
    //
    // The URI is only remembered here — the copy happens later, in
    // [importSharedMedia], once Dart has a screen up to show progress on. The
    // intent's payload is cleared so an activity re-creation (rotation,
    // process restart) does not replay the same share.
    private fun captureSharedMedia(intent: Intent?) {
        if (intent == null) return
        @Suppress("DEPRECATION")
        val uri: Uri? = when (intent.action) {
            Intent.ACTION_SEND -> intent.getParcelableExtra(Intent.EXTRA_STREAM)
            Intent.ACTION_VIEW -> intent.data
            else -> null
        }
        if (uri == null) return

        if (intent.action == Intent.ACTION_SEND) {
            intent.removeExtra(Intent.EXTRA_STREAM)
        } else {
            intent.data = null
        }

        pendingSharedMedia = mapOf(
            "uri" to uri.toString(),
            // Deliberately not resolved here. The display name costs a provider
            // query, this runs on the main thread inside onCreate, and nothing
            // reads the name before importSharedMedia — which resolves it off
            // the main thread anyway.
            "name" to null,
        )
        sharedMediaChannel?.invokeMethod("onSharedFile", null)
    }

    // Copies a shared URI into `cacheDir/shared_audio` and returns its path.
    //
    // The analysis pipeline works on real file paths (MediaExtractor, the
    // pure-Dart WAV/FLAC readers, and the spectrogram all seek by offset), so
    // a content:// stream has to be materialized first. Only the most recent
    // share is kept: the directory is emptied before each copy.
    private fun importSharedMedia(uriString: String, displayName: String?): String {
        val uri = Uri.parse(uriString)
        val dir = File(cacheDir, SHARED_MEDIA_DIR)
        if (dir.exists()) {
            dir.listFiles()?.forEach { it.delete() }
        } else if (!dir.mkdirs()) {
            throw IOException("Could not create ${dir.absolutePath}")
        }

        val name = safeFileName(
            displayName?.takeIf { it.isNotBlank() } ?: resolveDisplayName(uri),
            uri,
        )
        val outFile = File(dir, name)
        val input = contentResolver.openInputStream(uri)
            ?: throw IOException("Could not open the shared file")
        input.use { source ->
            outFile.outputStream().use { sink ->
                source.copyTo(sink, bufferSize = 1 shl 20)
            }
        }
        return outFile.absolutePath
    }

    private fun resolveDisplayName(uri: Uri): String? {
        if (uri.scheme == "file") return uri.lastPathSegment
        return try {
            contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
                ?.use { cursor ->
                    val column = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                    if (column >= 0 && cursor.moveToFirst()) cursor.getString(column) else null
                }
        } catch (e: Throwable) {
            null
        }
    }

    // Strips path components from a provider-supplied name and makes sure the
    // result still carries an extension — File Analysis labels the format from
    // it, and the native decoder uses it as its container hint.
    private fun safeFileName(displayName: String?, uri: Uri): String {
        val base = (displayName ?: uri.lastPathSegment ?: "shared_audio")
            .substringAfterLast('/')
            .substringAfterLast('\\')
            .replace(Regex("[\\x00-\\x1f]"), "")
            .trim()
            .takeIf { it.isNotEmpty() && it != "." && it != ".." }
            ?: "shared_audio"
        val trimmed = if (base.length > 120) base.takeLast(120) else base
        if (trimmed.substringAfterLast('.', "").isNotEmpty()) return trimmed
        val extension = MimeTypeMap.getSingleton()
            .getExtensionFromMimeType(contentResolver.getType(uri))
            ?: "audio"
        return "$trimmed.$extension"
    }

    private fun updateAruNotification(args: Map<String, Any?>) {
        val serviceId = (args["serviceId"] as Number).toInt()
        val channelId = args["channelId"] as String
        val title = args["title"] as String
        val text = args["text"] as String
        val stopText = args["stopText"] as String
        val openText = args["openText"] as String
        val stopAction = args["stopAction"] as String
        val openAction = args["openAction"] as String

        val notification = NotificationCompat.Builder(this, channelId)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(title)
            .setContentText(text)
            .setStyle(NotificationCompat.BigTextStyle().bigText(text))
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setSound(null)
            .setVibrate(longArrayOf(0L))
            .setContentIntent(
                buildAruNotificationPendingIntent(openAction, 0)
            )
            .addAction(
                0,
                stopText,
                buildAruNotificationPendingIntent(stopAction, 1)
            )
            .addAction(
                0,
                openText,
                buildAruNotificationPendingIntent(openAction, 2)
            )
            .build()

        val notificationManager =
            getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(serviceId, notification)
    }

    private fun buildAruNotificationPendingIntent(
        action: String,
        requestCode: Int
    ): PendingIntent {
        val launchIntent = packageManager
            .getLaunchIntentForPackage(packageName)
            ?: Intent(this, MainActivity::class.java)

        launchIntent.apply {
            addFlags(
                Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP
            )
            putExtra(ARU_NOTIFICATION_ACTION_EXTRA, action)
        }

        var flags = PendingIntent.FLAG_UPDATE_CURRENT
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
            flags = flags or PendingIntent.FLAG_IMMUTABLE
        }
        return PendingIntent.getActivity(this, requestCode, launchIntent, flags)
    }
}
