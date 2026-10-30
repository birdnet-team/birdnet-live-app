package com.birdnet.birdnet_live

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import android.speech.tts.Voice
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.Locale
import java.util.UUID
import java.util.concurrent.Executors
import java.util.concurrent.RejectedExecutionException

/**
 * Text-to-speech bridge for spoken announcements — the Android half of the
 * `com.birdnet/tts` channel. See lib/features/announcements/platform/
 * tts_engine.dart for the contract, TtsChannel.swift and tts_channel.cpp for
 * the iOS and Windows halves.
 *
 * Every [TextToSpeech] call is a blocking Binder round-trip into the engine
 * process, so all engine work runs on one worker thread and only the channel
 * replies touch the main thread. The engine is created lazily on the first
 * call; calls that arrive while it is still connecting are queued and drained
 * once `onInit` reports back. If the engine's service connection breaks, the
 * next `speak` reconnects once and restores language, voice, rate and pitch.
 */
class TtsChannel(private val context: Context, messenger: BinaryMessenger) {
    companion object {
        const val CHANNEL = "com.birdnet/tts"
        private const val TAG = "BirdNetTts"
    }

    private val channel = MethodChannel(messenger, CHANNEL)
    private val mainHandler = Handler(Looper.getMainLooper())
    private val worker = Executors.newSingleThreadExecutor { r -> Thread(r, "birdnet-tts") }

    // --- worker-thread state -------------------------------------------------
    private var tts: TextToSpeech? = null
    private var connecting: TextToSpeech? = null
    private var attempt = 0
    private val queued = ArrayDeque<Pair<MethodCall, MethodChannel.Result>>()
    private var retrying = false

    // Last applied settings, restored after a reconnect.
    private var languageTag: String? = null
    private var voice: Pair<String, String>? = null // name, locale
    private var rate = 1.0f
    private var pitch = 1.0f

    // The utterance whose `speak` reply is still outstanding.
    private var speakId: String? = null
    private var speakResult: MethodChannel.Result? = null

    init {
        channel.setMethodCallHandler { call, result -> post { dispatch(call, result) } }
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        post {
            settleSpeak(false)
            connecting?.shutdown()
            connecting = null
            tts?.shutdown()
            tts = null
        }
        worker.shutdown()
    }

    private fun post(block: () -> Unit) {
        try {
            worker.execute(block)
        } catch (_: RejectedExecutionException) {
            // Disposed; late engine callbacks have nothing left to update.
        }
    }

    private fun reply(result: MethodChannel.Result, value: Any?) {
        mainHandler.post { result.success(value) }
    }

    private fun fallbackValue(method: String): Any? = when (method) {
        "setLanguage", "setVoice", "speak" -> false
        "getVoices" -> emptyList<Any>()
        else -> null
    }

    private fun dispatch(call: MethodCall, result: MethodChannel.Result) {
        val engine = tts
        if (engine == null) {
            queued.addLast(call to result)
            connect()
            return
        }
        try {
            when (call.method) {
                "setLanguage" ->
                    reply(result, applyLanguage(engine, call.argument<String>("tag") ?: ""))
                "setVoice" -> reply(
                    result,
                    applyVoice(
                        engine,
                        call.argument<String>("name") ?: "",
                        call.argument<String>("locale") ?: "",
                    ),
                )
                "setRate" -> {
                    rate = (call.argument<Number>("rate") ?: 1.0).toFloat()
                    engine.setSpeechRate(rate)
                    reply(result, null)
                }
                "setPitch" -> {
                    pitch = (call.argument<Number>("pitch") ?: 1.0).toFloat()
                    engine.setPitch(pitch)
                    reply(result, null)
                }
                "getVoices" -> reply(
                    result,
                    voicesOf(engine).map {
                        mapOf("name" to it.name, "locale" to it.locale.toLanguageTag())
                    },
                )
                "speak" -> speak(engine, call.argument<String>("text") ?: "", call, result)
                "stop" -> {
                    settleSpeak(false)
                    engine.stop()
                    reply(result, null)
                }
                else -> mainHandler.post { result.notImplemented() }
            }
        } catch (e: Exception) {
            // Engines occasionally throw across Binder (dead service, odd
            // OEM builds). Never let that leave Dart waiting.
            Log.w(TAG, "${call.method} failed", e)
            reply(result, fallbackValue(call.method))
        }
    }

    private fun connect() {
        if (connecting != null) return
        val thisAttempt = ++attempt
        // The constructor binds the engine service and may call back
        // synchronously when no engine is installed; `post` keeps `onInit`
        // ordered after the assignment below either way.
        connecting = TextToSpeech(context) { status -> post { onInit(thisAttempt, status) } }
    }

    private fun onInit(thisAttempt: Int, status: Int) {
        if (thisAttempt != attempt) return // stale callback from a disposed engine
        val engine = connecting ?: return
        connecting = null
        if (status == TextToSpeech.SUCCESS) {
            engine.setOnUtteranceProgressListener(progressListener)
            tts = engine
            restoreSettings(engine)
        } else {
            Log.w(TAG, "TextToSpeech init failed with status $status")
            engine.shutdown()
        }
        val calls = queued.toList()
        queued.clear()
        for ((call, result) in calls) {
            if (tts != null) dispatch(call, result) else reply(result, fallbackValue(call.method))
        }
    }

    private fun restoreSettings(engine: TextToSpeech) {
        val tag = languageTag ?: return // first connection: nothing applied yet
        try {
            applyLanguage(engine, tag)
            voice?.let { applyVoice(engine, it.first, it.second) }
            if (rate != 1.0f) engine.setSpeechRate(rate)
            if (pitch != 1.0f) engine.setPitch(pitch)
        } catch (e: Exception) {
            Log.w(TAG, "Could not restore speech settings", e)
        }
    }

    /** Returns whether the engine has a voice for [tag]; applying it also drops a pinned voice. */
    private fun applyLanguage(engine: TextToSpeech, tag: String): Boolean {
        if (tag.isBlank()) return false
        // setLanguage() only applies the locale when the engine reports it
        // available, so one Binder call covers the probe and the switch.
        val ok = engine.setLanguage(Locale.forLanguageTag(tag)) >= TextToSpeech.LANG_AVAILABLE
        if (ok) {
            languageTag = tag
            voice = null
        }
        return ok
    }

    private fun applyVoice(engine: TextToSpeech, name: String, locale: String): Boolean {
        val match = voicesOf(engine).firstOrNull {
            it.name == name && it.locale.toLanguageTag().equals(locale, ignoreCase = true)
        } ?: return false
        val ok = engine.setVoice(match) == TextToSpeech.SUCCESS
        if (ok) voice = name to locale
        return ok
    }

    private fun voicesOf(engine: TextToSpeech): Set<Voice> = try {
        engine.voices ?: emptySet()
    } catch (e: Exception) {
        // Some minimal engines throw instead of returning an empty set.
        emptySet()
    }

    private fun speak(
        engine: TextToSpeech,
        text: String,
        call: MethodCall,
        result: MethodChannel.Result,
    ) {
        settleSpeak(false)
        val id = UUID.randomUUID().toString()
        if (engine.speak(text, TextToSpeech.QUEUE_FLUSH, null, id) == TextToSpeech.SUCCESS) {
            speakId = id
            speakResult = result
            retrying = false
            return
        }
        if (retrying) {
            retrying = false
            reply(result, false)
            return
        }
        // speak() fails synchronously when the engine's service connection
        // has died (engine updated or killed). Reconnect once and replay.
        Log.w(TAG, "speak() rejected; reconnecting to the engine")
        retrying = true
        engine.shutdown()
        tts = null
        queued.addLast(call to result)
        connect()
    }

    private fun settleSpeak(success: Boolean) {
        val result = speakResult ?: return
        speakResult = null
        speakId = null
        reply(result, success)
    }

    // The engine calls these from its own thread; hop to the worker so all
    // state stays single-threaded.
    private val progressListener = object : UtteranceProgressListener() {
        override fun onStart(utteranceId: String) {}

        override fun onDone(utteranceId: String) {
            post { if (utteranceId == speakId) settleSpeak(true) }
        }

        @Deprecated("Deprecated in Java")
        override fun onError(utteranceId: String) {
            onError(utteranceId, TextToSpeech.ERROR)
        }

        override fun onError(utteranceId: String, errorCode: Int) {
            post {
                if (utteranceId == speakId) {
                    Log.w(TAG, "Utterance failed with error $errorCode")
                    settleSpeak(false)
                }
            }
        }

        override fun onStop(utteranceId: String, interrupted: Boolean) {
            post { if (utteranceId == speakId) settleSpeak(false) }
        }
    }
}
