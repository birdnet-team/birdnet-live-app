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
import kotlin.math.roundToInt

/**
 * Decodes an audio file to mono 16-bit PCM using Android's MediaCodec.
 *
 * Returns a map with:
 *   - "samples": ByteArray of little-endian Int16 PCM samples (mono)
 *   - "sampleRate": Int — output sample rate in Hz
 *   - "totalSamples": Int — number of mono samples
 */
object NativeAudioDecoder {

    fun decode(path: String): Map<String, Any> {
        val file = File(path)
        if (!file.exists()) {
            throw IllegalArgumentException("File not found: $path")
        }

        val extractor = MediaExtractor()
        try {
            extractor.setDataSource(path)

            // Find the first audio track.
            val (trackIndex, format) = findAudioTrack(extractor)
                ?: throw IllegalArgumentException("No audio track found in: $path")

            extractor.selectTrack(trackIndex)

            val mime = format.getString(MediaFormat.KEY_MIME)
                ?: throw IllegalArgumentException("No MIME type in track format")
            val inputSampleRate = format.getInteger(MediaFormat.KEY_SAMPLE_RATE)
            val inputChannels = format.getInteger(MediaFormat.KEY_CHANNEL_COUNT)

            // Decode compressed audio → PCM.
            val pcmBytes = decodeTrack(extractor, format, mime)

            // Convert to mono Int16 if needed.
            val monoSamples = toMonoInt16(pcmBytes, inputChannels)

            // Return as byte array (little-endian Int16).
            val outputBytes = ByteArray(monoSamples.size * 2)
            ByteBuffer.wrap(outputBytes).order(ByteOrder.LITTLE_ENDIAN).apply {
                val shortBuf = asShortBuffer()
                shortBuf.put(monoSamples)
            }

            return mapOf(
                "samples" to outputBytes,
                "sampleRate" to inputSampleRate,
                "totalSamples" to monoSamples.size,
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

    /** Decode all audio frames via MediaCodec → raw PCM bytes. */
    private fun decodeTrack(
        extractor: MediaExtractor,
        format: MediaFormat,
        mime: String,
    ): ByteArray {
        val codec = MediaCodec.createDecoderByType(mime)
        codec.configure(format, null, null, 0)
        codec.start()

        val bufferInfo = MediaCodec.BufferInfo()
        var inputDone = false
        val outputChunks = mutableListOf<ByteArray>()

        try {
            while (true) {
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
                        val chunk = ByteArray(bufferInfo.size)
                        outputBuffer.position(bufferInfo.offset)
                        outputBuffer.get(chunk, 0, bufferInfo.size)
                        outputChunks.add(chunk)
                    }
                    codec.releaseOutputBuffer(outputIndex, false)

                    if (bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) {
                        break
                    }
                } else if (outputIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                    // Format changed, continue processing.
                } else if (outputIndex == MediaCodec.INFO_TRY_AGAIN_LATER) {
                    if (inputDone) {
                        // No more input and no output — done.
                        break
                    }
                }
            }
        } finally {
            codec.stop()
            codec.release()
        }

        // Concatenate all chunks.
        val totalSize = outputChunks.sumOf { it.size }
        val result = ByteArray(totalSize)
        var offset = 0
        for (chunk in outputChunks) {
            System.arraycopy(chunk, 0, result, offset, chunk.size)
            offset += chunk.size
        }
        return result
    }

    /**
     * Convert interleaved 16-bit PCM to mono by averaging channels.
     *
     * MediaCodec outputs 16-bit little-endian PCM by default.
     */
    private fun toMonoInt16(pcmBytes: ByteArray, channels: Int): ShortArray {
        val shortBuf = ByteBuffer.wrap(pcmBytes)
            .order(ByteOrder.LITTLE_ENDIAN)
            .asShortBuffer()
        val totalShorts = shortBuf.remaining()
        val totalFrames = totalShorts / channels

        if (channels == 1) {
            val mono = ShortArray(totalFrames)
            shortBuf.get(mono)
            return mono
        }

        // Downmix to mono by averaging channels.
        val mono = ShortArray(totalFrames)
        for (i in 0 until totalFrames) {
            var sum = 0L
            for (ch in 0 until channels) {
                sum += shortBuf.get()
            }
            mono[i] = (sum / channels).toInt().coerceIn(-32768, 32767).toShort()
        }
        return mono
    }
}
