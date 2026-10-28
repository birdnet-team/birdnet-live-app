package com.birdnet.birdnet_live

import android.content.Context
import android.util.Log
import androidx.work.BackoffPolicy
import androidx.work.Constraints
import androidx.work.CoroutineWorker
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.TimeUnit
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeoutOrNull

/**
 * Background upload run — the Android half of `com.birdnet/upload_work`.
 * See lib/features/upload/upload_background.dart for the contract.
 *
 * [UploadWorkChannel] takes `schedule` / `cancel` from the running app and
 * enqueues one unique piece of work with a network constraint. [UploadWorker]
 * then starts a headless Flutter engine on `uploadQueueBackgroundMain`,
 * registers the in-house channels that run needs (keychain, connectivity),
 * and waits for Dart's `finished` call. Jobs still pending afterwards make
 * the worker ask for a retry with exponential backoff; WorkManager re-runs it
 * when the network constraint is met again.
 */
class UploadWorkChannel(private val context: Context, messenger: BinaryMessenger) {
    companion object {
        const val CHANNEL = "com.birdnet/upload_work"
        const val WORK_NAME = "birdnet-upload-queue"

        fun schedule(context: Context, wifiOnly: Boolean) {
            val constraints = Constraints.Builder()
                .setRequiredNetworkType(if (wifiOnly) NetworkType.UNMETERED else NetworkType.CONNECTED)
                .build()
            val request = OneTimeWorkRequestBuilder<UploadWorker>()
                .setConstraints(constraints)
                .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 1, TimeUnit.MINUTES)
                .build()
            // KEEP: a run already waiting for its network keeps its place; the
            // queue file decides what gets uploaded, not the request.
            WorkManager.getInstance(context)
                .enqueueUniqueWork(WORK_NAME, ExistingWorkPolicy.KEEP, request)
        }

        fun cancel(context: Context) {
            WorkManager.getInstance(context).cancelUniqueWork(WORK_NAME)
        }
    }

    private val channel = MethodChannel(messenger, CHANNEL)

    init {
        channel.setMethodCallHandler(::handle)
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "schedule" -> {
                    schedule(context, call.argument<Boolean>("wifiOnly") ?: false)
                    result.success(null)
                }
                "cancel" -> {
                    cancel(context)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            result.error("upload_work", e.message ?: e.javaClass.simpleName, null)
        }
    }
}

class UploadWorker(context: Context, params: WorkerParameters) : CoroutineWorker(context, params) {
    companion object {
        private const val TAG = "BirdNetUploadWorker"
        private const val ENTRYPOINT_LIBRARY = "package:birdnet_live/features/upload/upload_background.dart"
        private const val ENTRYPOINT_FUNCTION = "uploadQueueBackgroundMain"
        private const val RUN_TIMEOUT_MS = 9L * 60 * 1000
    }

    override suspend fun doWork(): Result = withContext(Dispatchers.Main) {
        val loader = FlutterInjector.instance().flutterLoader()
        loader.startInitialization(applicationContext)
        loader.ensureInitializationComplete(applicationContext, null)

        val engine = FlutterEngine(applicationContext)
        val messenger = engine.dartExecutor.binaryMessenger
        val secureStore = SecureStoreChannel(applicationContext, messenger)
        val connectivity = ConnectivityChannel(applicationContext, messenger)
        val finished = CompletableDeferred<Result>()
        MethodChannel(messenger, UploadWorkChannel.CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "finished" -> {
                    val pending = call.argument<Int>("pending") ?: 0
                    val error = call.argument<String>("error")
                    if (error != null) Log.w(TAG, "background run reported: $error")
                    finished.complete(if (pending > 0 || error != null) Result.retry() else Result.success())
                    result.success(null)
                }
                // The headless run does not reschedule itself; the app does.
                "schedule", "cancel" -> result.success(null)
                else -> result.notImplemented()
            }
        }
        try {
            engine.dartExecutor.executeDartEntrypoint(
                DartExecutor.DartEntrypoint(loader.findAppBundlePath(), ENTRYPOINT_LIBRARY, ENTRYPOINT_FUNCTION)
            )
            withTimeoutOrNull(RUN_TIMEOUT_MS) { finished.await() } ?: run {
                Log.w(TAG, "background run timed out")
                Result.retry()
            }
        } catch (e: Exception) {
            Log.w(TAG, "background run failed to start", e)
            Result.retry()
        } finally {
            secureStore.dispose()
            connectivity.dispose()
            engine.destroy()
        }
    }
}
