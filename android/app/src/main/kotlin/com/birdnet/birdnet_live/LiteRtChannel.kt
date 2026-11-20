package com.birdnet.birdnet_live

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.tensorflow.lite.Delegate
import org.tensorflow.lite.Interpreter
import org.tensorflow.lite.gpu.GpuDelegate
import org.tensorflow.lite.nnapi.NnApiDelegate
import java.io.File
import java.io.FileInputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.MappedByteBuffer
import java.nio.channels.FileChannel
import java.util.concurrent.Executors

/**
 * Experimental LiteRT (TFLite) backend for the audio classifier — the Android half of the
 * `com.birdnet/litert` channel. See lib/features/inference/litert_classifier_model.dart.
 *
 * The model is split in two LiteRT graphs:
 *  - **frontend** (audio [1, 96000] -> spectrogram [1, 224, 281, 3]) always runs on the CPU.
 *  - **classifier** (spectrogram -> predictions [1, N] + embeddings [1, 1280]) runs on the
 *    requested accelerator:
 *      - `tpu`: NNAPI delegate pinned to `google-edgetpu` with fp16 allowed. The Edge TPU only
 *        accepts fp16 graphs; without `allowFp16` NNAPI silently falls back to the CPU. The
 *        classifier head must be the fp16-safe GeM rewrite, the original head underflows in fp16.
 *      - `gpu`: GPU delegate (fp16 precision loss allowed).
 *      - `cpu`: XNNPACK, 4 threads.
 *    If the requested accelerator fails to initialise, the next one in tpu -> gpu -> cpu is
 *    tried; `load` reports the accelerator that is actually in use.
 *
 * NNAPI is deprecated since Android 15 but is still the only route to the Edge TPU of Tensor G4
 * (Pixel 9). The compiled TPU program is cached in [Context.getCodeCacheDir] so only the first
 * load pays the ~5-12 s compilation.
 *
 * Interpreters are not thread-safe: every call runs on one single-thread executor and the
 * result is posted back to the main thread.
 */
class LiteRtChannel(private val context: Context, messenger: BinaryMessenger) {
    companion object {
        const val CHANNEL = "com.birdnet/litert"
        private const val TAG = "LiteRtChannel"
        private const val CPU_THREADS = 4
        private const val FRONTEND_THREADS = 1 // 4 threads: 27 ms, 1 thread: 5 ms (12 small partitions, sync overhead dominates)
    }

    private val channel = MethodChannel(messenger, CHANNEL)
    private val executor = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    private var frontend: Interpreter? = null
    private var classifier: Interpreter? = null
    private var delegate: Delegate? = null
    private var accelerator: String = "none"
    private var windowSamples = 0
    private var specShape = intArrayOf()
    private var predIndex = 0
    private var embIndex = -1
    private var numClasses = 0
    private var embDim = 0

    // Reused direct buffers (allocated once per load; all access is on [executor]).
    private var audioBuf: ByteBuffer = direct(0)
    private var specBuf: ByteBuffer = direct(0)
    private var predBuf: ByteBuffer = direct(0)
    private var embBuf: ByteBuffer = direct(0)

    init {
        channel.setMethodCallHandler(::handle)
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        executor.execute { closeModels() }
        executor.shutdown()
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "load" -> runAsync(result) { load(call) }
            "predict" -> runAsync(result) { predict(call) }
            "close" -> runAsync(result) { closeModels(); null }
            else -> result.notImplemented()
        }
    }

    private fun runAsync(result: MethodChannel.Result, block: () -> Any?) {
        executor.execute {
            try {
                val value = block()
                main.post { result.success(value) }
            } catch (t: Throwable) {
                Log.e(TAG, "LiteRT call failed", t)
                main.post { result.error("litert_error", t.message ?: t.toString(), null) }
            }
        }
    }

    // ── Loading ──────────────────────────────────────────────────────────

    private fun load(call: MethodCall): Map<String, Any> {
        val frontendPath = call.argument<String>("frontendPath") ?: throw IllegalArgumentException("frontendPath")
        val classifierPath = call.argument<String>("classifierPath") ?: throw IllegalArgumentException("classifierPath")
        val requested = call.argument<String>("accelerator") ?: "tpu"
        val lowPower = call.argument<Boolean>("lowPower") ?: false
        closeModels()

        val t0 = System.nanoTime()
        frontend = Interpreter(map(frontendPath), Interpreter.Options().setNumThreads(FRONTEND_THREADS)).also {
            windowSamples = it.getInputTensor(0).shape().last()
        }

        val classifierModel = map(classifierPath)
        val chain = listOf("tpu", "gpu", "cpu").let { it.subList(it.indexOf(requested).coerceAtLeast(0), it.size) }
        var lastError: Throwable? = null
        for (acc in chain) {
            try {
                val (interp, del) = createClassifier(classifierModel, acc, classifierPath, lowPower)
                classifier = interp
                delegate = del
                accelerator = acc
                break
            } catch (t: Throwable) {
                Log.w(TAG, "classifier on $acc failed, trying next", t)
                lastError = t
            }
        }
        val interp = classifier ?: throw IllegalStateException("no accelerator worked", lastError)

        specShape = interp.getInputTensor(0).shape()
        predIndex = -1
        embIndex = -1
        for (i in 0 until interp.outputTensorCount) {
            val n = interp.getOutputTensor(i).shape().last()
            if (n == 1280) embIndex = i else predIndex = i
        }
        check(predIndex >= 0) { "no predictions output" }
        numClasses = interp.getOutputTensor(predIndex).shape().last()
        embDim = if (embIndex >= 0) interp.getOutputTensor(embIndex).shape().last() else 0
        audioBuf = direct(windowSamples)
        specBuf = direct(specShape.fold(1) { a, b -> a * b })
        predBuf = direct(numClasses)
        embBuf = direct(maxOf(embDim, 1))

        // Warm-up: the first NNAPI/GPU invocation compiles or uploads the program.
        predictInternal(FloatArray(windowSamples), 1)
        val loadMs = (System.nanoTime() - t0) / 1_000_000
        Log.i(TAG, "loaded on $accelerator (requested $requested) in $loadMs ms, classes=$numClasses")
        return mapOf(
            "accelerator" to accelerator,
            "requested" to requested,
            "loadMs" to loadMs,
            "windowSamples" to windowSamples,
            "numClasses" to numClasses,
        )
    }

    private fun createClassifier(
        model: MappedByteBuffer,
        acc: String,
        path: String,
        lowPower: Boolean,
    ): Pair<Interpreter, Delegate?> {
        val options = Interpreter.Options()
        var del: Delegate? = null
        when (acc) {
            "tpu" -> {
                val cache = File(context.codeCacheDir, "litert_nnapi").apply { mkdirs() }
                val token = "bn_" + File(path).name.hashCode().toUInt().toString(16) + "_" + File(path).length()
                val nn = NnApiDelegate(
                    NnApiDelegate.Options()
                        .setAcceleratorName("google-edgetpu")
                        .setAllowFp16(true)
                        .setUseNnapiCpu(false)
                        .setExecutionPreference(
                            if (lowPower) NnApiDelegate.Options.EXECUTION_PREFERENCE_LOW_POWER
                            else NnApiDelegate.Options.EXECUTION_PREFERENCE_SUSTAINED_SPEED,
                        )
                        .setCacheDir(cache.absolutePath)
                        .setModelToken(token),
                )
                del = nn
                options.addDelegate(nn)
            }
            "gpu" -> {
                val gpu = GpuDelegate(GpuDelegate.Options().setPrecisionLossAllowed(true))
                del = gpu
                options.addDelegate(gpu)
            }
            else -> options.setNumThreads(CPU_THREADS).setUseXNNPACK(true)
        }
        try {
            val interp = Interpreter(model, options)
            // A delegate that silently rejects ops would leave them on the reference CPU kernels;
            // treat an NNAPI init that did not take the whole graph as a failure.
            if (acc == "tpu" && (del as NnApiDelegate).nnapiErrno != 0) {
                interp.close()
                throw IllegalStateException("NNAPI errno ${del.nnapiErrno}")
            }
            return interp to del
        } catch (t: Throwable) {
            (del as? AutoCloseable)?.close()
            throw t
        }
    }

    private fun map(path: String): MappedByteBuffer =
        FileInputStream(path).use { it.channel.map(FileChannel.MapMode.READ_ONLY, 0, it.channel.size()) }

    // ── Inference ────────────────────────────────────────────────────────

    private fun predict(call: MethodCall): Map<String, Any> {
        val audio = call.argument<FloatArray>("audio") ?: throw IllegalArgumentException("audio")
        val batch = call.argument<Int>("batch") ?: 1
        return predictInternal(audio, batch)
    }

    private fun predictInternal(audio: FloatArray, batch: Int): Map<String, Any> {
        val fe = frontend ?: throw IllegalStateException("not loaded")
        val cl = classifier ?: throw IllegalStateException("not loaded")
        require(audio.size == batch * windowSamples) { "audio size ${audio.size} != $batch x $windowSamples" }

        val preds = FloatArray(batch * numClasses)
        val embs = FloatArray(batch * embDim)
        var frontendNs = 0L
        var classifierNs = 0L

        for (b in 0 until batch) {
            audioBuf.clear()
            audioBuf.asFloatBuffer().put(audio, b * windowSamples, windowSamples)
            specBuf.clear()
            var t = System.nanoTime()
            fe.run(audioBuf, specBuf)
            frontendNs += System.nanoTime() - t
            specBuf.rewind()
            predBuf.clear()
            embBuf.clear()
            val outputs = HashMap<Int, Any>(2)
            outputs[predIndex] = predBuf
            if (embIndex >= 0) outputs[embIndex] = embBuf
            t = System.nanoTime()
            cl.runForMultipleInputsOutputs(arrayOf<Any>(specBuf), outputs)
            classifierNs += System.nanoTime() - t
            predBuf.rewind()
            predBuf.asFloatBuffer().get(preds, b * numClasses, numClasses)
            if (embIndex >= 0) {
                embBuf.rewind()
                embBuf.asFloatBuffer().get(embs, b * embDim, embDim)
            }
        }
        return mapOf(
            "predictions" to preds,
            "embeddings" to embs,
            "frontendUs" to frontendNs / 1000,
            "classifierUs" to classifierNs / 1000,
            "accelerator" to accelerator,
        )
    }

    private fun direct(floats: Int): ByteBuffer =
        ByteBuffer.allocateDirect(floats * 4).order(ByteOrder.nativeOrder())

    private fun closeModels() {
        frontend?.close()
        classifier?.close()
        (delegate as? AutoCloseable)?.close()
        frontend = null
        classifier = null
        delegate = null
        accelerator = "none"
    }
}
