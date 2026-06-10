// =============================================================================
// Native Audio Decoder — Decode compressed audio via Android MediaCodec
// =============================================================================
//
// Uses Android's MediaExtractor + MediaCodec pipeline to decode compressed
// audio formats (MP3, OGG, AAC/M4A, OPUS, etc.) to raw mono 16-bit PCM.
//
// Called from Dart via MethodChannel "com.birdnet/audio_decoder".
//
// Supported formats: everything Android's MediaCodec framework supports —
// MP3, OGG Vorbis, AAC (M4A), OPUS, AMR, FLAC, WAV, and more.
// =============================================================================

package com.birdnet.birdnet_live

import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.concurrent.CancellationException

/**
 * Decodes an audio file to mono 16-bit PCM using Android's MediaCodec.
 *
 * Returns a map with:
 *   - "samples": ByteArray of little-endian Int16 PCM samples (mono)
 *   - "sampleRate": Int — output sample rate in Hz
 *   - "totalSamples": Int — number of mono samples
 */
object NativeAudioDecoder {

    fun inspect(path: String): Map<String, Any> {
        val file = File(path)
        if (!file.exists()) {
            throw IllegalArgumentException("File not found: $path")
        }

        val extractor = MediaExtractor()
        try {
            extractor.setDataSource(path)
            val (_, format) = findAudioTrack(extractor)
                ?: throw IllegalArgumentException("No audio track found in: $path")

            val sampleRate = format.getInteger(MediaFormat.KEY_SAMPLE_RATE)
            val durationUs = if (format.containsKey(MediaFormat.KEY_DURATION)) {
                format.getLong(MediaFormat.KEY_DURATION)
            } else {
                0L
            }
            val totalSamples = if (durationUs > 0) {
                (durationUs * sampleRate / 1_000_000L).toInt()
            } else {
                0
            }

            return mapOf(
                "sampleRate" to sampleRate,
                "totalSamples" to totalSamples,
            )
        } finally {
            extractor.release()
        }
    }

    fun decode(path: String, tempPcmPath: String, isCancelled: () -> Boolean = { false }): Map<String, Any> {
        val file = File(path)
        if (!file.exists()) {
            throw IllegalArgumentException("File not found: $path")
        }

        val extractor = MediaExtractor()
        val tempFile = File(tempPcmPath)
        try {
            extractor.setDataSource(path)

            // Find the first audio track.
            val (trackIndex, format) = findAudioTrack(extractor)
                ?: throw IllegalArgumentException("No audio track found in: $path")

            extractor.selectTrack(trackIndex)

            val mime = format.getString(MediaFormat.KEY_MIME)
                ?: throw IllegalArgumentException("No MIME type in track format")

            // Decode compressed audio to mono PCM directly to file.
            val (codecSampleRate, totalSamples) = decodeTrack(extractor, format, mime, tempFile, isCancelled)

            return mapOf(
                "sampleRate" to codecSampleRate,
                "totalSamples" to totalSamples,
            )
        } catch (e: Throwable) {
            // Clean up temp file on failure
            if (tempFile.exists()) {
                tempFile.delete()
            }
            throw e
        } finally {
            extractor.release()
        }
    }

    fun decodeRange(
        path: String,
        startSample: Long,
        count: Int,
        isCancelled: () -> Boolean = { false }
    ): Map<String, Any> {
        val file = File(path)
        if (!file.exists()) {
            throw IllegalArgumentException("File not found: $path")
        }

        val extractor = MediaExtractor()
        try {
            extractor.setDataSource(path)
            val (trackIndex, format) = findAudioTrack(extractor)
                ?: throw IllegalArgumentException("No audio track found in: $path")
            extractor.selectTrack(trackIndex)

            val trackSampleRate = format.getInteger(MediaFormat.KEY_SAMPLE_RATE)
            val mime = format.getString(MediaFormat.KEY_MIME)
                ?: throw IllegalArgumentException("No MIME type in track format")

            // Seek to previous sync frame.
            val startUs = startSample * 1_000_000L / trackSampleRate
            extractor.seekTo(startUs, MediaExtractor.SEEK_TO_PREVIOUS_SYNC)

            val codec = MediaCodec.createDecoderByType(mime)
            codec.configure(format, null, null, 0)
            codec.start()

            val bufferInfo = MediaCodec.BufferInfo()
            var inputDone = false
            var outputBufferBytes: ByteBuffer? = null
            var outputShorts: java.nio.ShortBuffer? = null
            var discardSamples = 0L
            var decodedSamplesCount = 0L

            var channels = if (format.containsKey(MediaFormat.KEY_CHANNEL_COUNT)) {
                format.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
            } else {
                1
            }
            var codecSampleRate = trackSampleRate

            try {
                while (true) {
                    if (isCancelled()) {
                        throw CancellationException("Decoding cancelled")
                    }

                    // Feed input.
                    if (!inputDone) {
                        val inputIndex = codec.dequeueInputBuffer(10_000)
                        if (inputIndex >= 0) {
                            val inputBuffer = codec.getInputBuffer(inputIndex)!!
                            val bytesRead = extractor.readSampleData(inputBuffer, 0)
                            if (bytesRead < 0) {
                                codec.queueInputBuffer(
                                    inputIndex, 0, 0, 0,
                                    MediaCodec.BUFFER_FLAG_END_OF_STREAM,
                                )
                                inputDone = true
                            } else {
                                codec.queueInputBuffer(
                                    inputIndex, 0, bytesRead,
                                    extractor.sampleTime, 0,
                                )
                                extractor.advance()
                            }
                        }
                    }

                    // Drain output.
                    val outputIndex = codec.dequeueOutputBuffer(bufferInfo, 10_000)
                    if (outputIndex >= 0) {
                        var reachedEnd = false
                        if (bufferInfo.size > 0) {
                            val outputBuffer = codec.getOutputBuffer(outputIndex)!!
                            outputBuffer.position(bufferInfo.offset)
                            outputBuffer.limit(bufferInfo.offset + bufferInfo.size)
                            outputBuffer.order(ByteOrder.LITTLE_ENDIAN)
                            val shortBuf = outputBuffer.asShortBuffer()

                            val totalShorts = bufferInfo.size / 2
                            val frames = totalShorts / channels

                            if (outputBufferBytes == null) {
                                val targetCount = (count.toLong() * codecSampleRate / trackSampleRate).toInt()
                                val bytesBuffer = ByteBuffer.allocate(targetCount * 2).order(ByteOrder.LITTLE_ENDIAN)
                                outputBufferBytes = bytesBuffer
                                outputShorts = bytesBuffer.asShortBuffer()

                                val desiredStartSample = startSample * codecSampleRate / trackSampleRate
                                val firstOutputSample = bufferInfo.presentationTimeUs * codecSampleRate / 1_000_000L
                                discardSamples = (desiredStartSample - firstOutputSample).coerceAtLeast(0L)
                            }

                            val shorts = outputShorts!!
                            if (channels == 1) {
                                for (f in 0 until frames) {
                                    if (shortBuf.hasRemaining()) {
                                        val sample = shortBuf.get()
                                        if (decodedSamplesCount >= discardSamples) {
                                            if (shorts.hasRemaining()) {
                                                shorts.put(sample)
                                            } else {
                                                reachedEnd = true
                                                break
                                            }
                                        }
                                        decodedSamplesCount++
                                    }
                                }
                            } else {
                                for (f in 0 until frames) {
                                    var sum = 0L
                                    for (ch in 0 until channels) {
                                        if (shortBuf.hasRemaining()) {
                                            sum += shortBuf.get()
                                        }
                                    }
                                    val avg = (sum / channels).toInt().coerceIn(-32768, 32767).toShort()

                                    if (decodedSamplesCount >= discardSamples) {
                                        if (shorts.hasRemaining()) {
                                            shorts.put(avg)
                                        } else {
                                            reachedEnd = true
                                            break
                                        }
                                    }
                                    decodedSamplesCount++
                                }
                            }
                        }
                        codec.releaseOutputBuffer(outputIndex, false)

                        val targetCount = (count.toLong() * codecSampleRate / trackSampleRate).toInt()
                        val collectedSamples = if (outputShorts != null) outputShorts.position() else 0
                        if (collectedSamples >= targetCount || (bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) || reachedEnd) {
                            break
                        }
                    } else if (outputIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                        val newFormat = codec.outputFormat
                        if (newFormat.containsKey(MediaFormat.KEY_CHANNEL_COUNT)) {
                            channels = newFormat.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
                        }
                        if (newFormat.containsKey(MediaFormat.KEY_SAMPLE_RATE)) {
                            codecSampleRate = newFormat.getInteger(MediaFormat.KEY_SAMPLE_RATE)
                        }
                    } else if (outputIndex == MediaCodec.INFO_TRY_AGAIN_LATER) {
                        if (inputDone) {
                            break
                        }
                    }
                }
            } finally {
                codec.stop()
                codec.release()
            }

            val finalBytes = if (outputBufferBytes != null) {
                val actualSamples = outputShorts!!.position()
                val targetCount = (count.toLong() * codecSampleRate / trackSampleRate).toInt()
                if (actualSamples < targetCount) {
                    val trimmed = ByteArray(actualSamples * 2)
                    System.arraycopy(outputBufferBytes.array(), 0, trimmed, 0, actualSamples * 2)
                    trimmed
                } else {
                    outputBufferBytes.array()
                }
            } else {
                ByteArray(0)
            }
            val finalTotalSamples = if (outputShorts != null) outputShorts.position() else 0
            val expectedTotalSamples = (count.toLong() * codecSampleRate / trackSampleRate).toInt()

            return mapOf(
                "samples" to finalBytes,
                "sampleRate" to codecSampleRate,
                "totalSamples" to finalTotalSamples,
                "reachedEnd" to (finalTotalSamples < expectedTotalSamples),
            )
        } finally {
            extractor.release()
        }
    }

    /** Find the first audio track in the extractor. */
    private fun findAudioTrack(extractor: MediaExtractor): Pair<Int, MediaFormat>? {
        for (i in 0 until extractor.trackCount) {
            val format = extractor.getTrackFormat(i)
            val mime = format.getString(MediaFormat.KEY_MIME) ?: continue
            if (mime.startsWith("audio/")) {
                return Pair(i, format)
            }
        }
        return null
    }

    /** Decode all audio frames via MediaCodec to raw mono PCM bytes written to a file. */
    private fun decodeTrack(
        extractor: MediaExtractor,
        format: MediaFormat,
        mime: String,
        tempFile: File,
        isCancelled: () -> Boolean,
    ): Pair<Int, Int> {
        val codec = MediaCodec.createDecoderByType(mime)
        codec.configure(format, null, null, 0)
        codec.start()

        val bufferInfo = MediaCodec.BufferInfo()
        var inputDone = false
        var totalSamples = 0

        var channels = if (format.containsKey(MediaFormat.KEY_CHANNEL_COUNT)) {
            format.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
        } else {
            1
        }
        var codecSampleRate = if (format.containsKey(MediaFormat.KEY_SAMPLE_RATE)) {
            format.getInteger(MediaFormat.KEY_SAMPLE_RATE)
        } else {
            32000
        }

        val outputStream = tempFile.outputStream()
        try {
            while (true) {
                if (isCancelled()) {
                    throw CancellationException("Decoding cancelled")
                }

                // Feed input buffers.
                if (!inputDone) {
                    val inputIndex = codec.dequeueInputBuffer(10_000)
                    if (inputIndex >= 0) {
                        val inputBuffer = codec.getInputBuffer(inputIndex)!!
                        val bytesRead = extractor.readSampleData(inputBuffer, 0)
                        if (bytesRead < 0) {
                            codec.queueInputBuffer(
                                inputIndex, 0, 0, 0,
                                MediaCodec.BUFFER_FLAG_END_OF_STREAM,
                            )
                            inputDone = true
                        } else {
                            codec.queueInputBuffer(
                                inputIndex, 0, bytesRead,
                                extractor.sampleTime, 0,
                            )
                            extractor.advance()
                        }
                    }
                }

                // Drain output buffers.
                val outputIndex = codec.dequeueOutputBuffer(bufferInfo, 10_000)
                if (outputIndex >= 0) {
                    if (bufferInfo.size > 0) {
                        val outputBuffer = codec.getOutputBuffer(outputIndex)!!
                        outputBuffer.position(bufferInfo.offset)
                        outputBuffer.limit(bufferInfo.offset + bufferInfo.size)
                        outputBuffer.order(ByteOrder.LITTLE_ENDIAN)
                        val shortBuf = outputBuffer.asShortBuffer()

                        val totalShorts = bufferInfo.size / 2
                        val frames = totalShorts / channels

                        val monoByteChunk = ByteArray(frames * 2)
                        val monoShortBuf = ByteBuffer.wrap(monoByteChunk)
                            .order(ByteOrder.LITTLE_ENDIAN)
                            .asShortBuffer()

                        if (channels == 1) {
                            // Copy directly.
                            if (shortBuf.hasRemaining()) {
                                monoShortBuf.put(shortBuf)
                            }
                        } else {
                            for (i in 0 until frames) {
                                var sum = 0L
                                for (ch in 0 until channels) {
                                    if (shortBuf.hasRemaining()) {
                                        sum += shortBuf.get()
                                    }
                                }
                                val avg = (sum / channels).toInt().coerceIn(-32768, 32767).toShort()
                                monoShortBuf.put(avg)
                            }
                        }
                        outputStream.write(monoByteChunk)
                        totalSamples += frames
                    }
                    codec.releaseOutputBuffer(outputIndex, false)

                    if (bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) {
                        break
                    }
                } else if (outputIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                    val newFormat = codec.outputFormat
                    if (newFormat.containsKey(MediaFormat.KEY_CHANNEL_COUNT)) {
                        channels = newFormat.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
                    }
                    if (newFormat.containsKey(MediaFormat.KEY_SAMPLE_RATE)) {
                        codecSampleRate = newFormat.getInteger(MediaFormat.KEY_SAMPLE_RATE)
                    }
                } else if (outputIndex == MediaCodec.INFO_TRY_AGAIN_LATER) {
                    if (inputDone) {
                        // No more input and no output — done.
                        break
                    }
                }
            }
        } finally {
            outputStream.close()
            codec.stop()
            codec.release()
        }
        return Pair(codecSampleRate, totalSamples)
    }
}
