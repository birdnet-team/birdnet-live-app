// =============================================================================
// Native Audio Decoder — Decode compressed audio via AVFoundation
// =============================================================================
//
// Uses AVAssetReader + AVAssetReaderTrackOutput to decode compressed audio
// formats (MP3, AAC/M4A, ALAC, WAV, FLAC, etc.) to raw mono 16-bit PCM.
//
// Called from Dart via MethodChannel "com.birdnet/audio_decoder".
// =============================================================================

import AVFoundation
import Foundation

/// Decodes an audio file to mono 16-bit PCM using AVFoundation.
///
/// Returns a dictionary with:
///   - "samples": FlutterStandardTypedData of little-endian Int16 PCM (mono)
///   - "sampleRate": Int — output sample rate in Hz
///   - "totalSamples": Int — number of mono samples
enum NativeAudioDecoder {

    static func decode(path: String) throws -> [String: Any] {
        let url = URL(fileURLWithPath: path)

        guard FileManager.default.fileExists(atPath: path) else {
            throw DecoderError.fileNotFound(path)
        }

        let asset = AVURLAsset(url: url)

        guard let track = asset.tracks(withMediaType: .audio).first else {
            throw DecoderError.noAudioTrack(path)
        }

        let reader = try AVAssetReader(asset: asset)

        // Request mono Int16 PCM output.
        let outputSettings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false,
            AVNumberOfChannelsKey: 1,
        ]

        let output = AVAssetReaderTrackOutput(track: track, outputSettings: outputSettings)
        output.alwaysCopiesSampleData = false
        reader.add(output)

        guard reader.startReading() else {
            let msg = reader.error?.localizedDescription ?? "Unknown error"
            throw DecoderError.readerFailed(msg)
        }

        // Read all sample buffers.
        var pcmChunks: [Data] = []
        var totalBytes = 0

        while reader.status == .reading {
            guard let sampleBuffer = output.copyNextSampleBuffer() else {
                break
            }

            guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else {
                continue
            }

            let length = CMBlockBufferGetDataLength(blockBuffer)
            var data = Data(count: length)
            data.withUnsafeMutableBytes { rawPtr in
                guard let baseAddress = rawPtr.baseAddress else { return }
                CMBlockBufferCopyDataBytes(
                    blockBuffer, atOffset: 0, dataLength: length,
                    destination: baseAddress
                )
            }
            pcmChunks.append(data)
            totalBytes += length
        }

        if reader.status == .failed {
            let msg = reader.error?.localizedDescription ?? "Unknown error"
            throw DecoderError.readerFailed(msg)
        }

        // Concatenate chunks.
        var pcmData = Data(capacity: totalBytes)
        for chunk in pcmChunks {
            pcmData.append(chunk)
        }

        // Get the original sample rate from the track's format descriptions.
        let sampleRate = sampleRateFromTrack(track)
        let totalSamples = pcmData.count / 2  // 16-bit = 2 bytes per sample

        return [
            "samples": FlutterStandardTypedData(bytes: pcmData),
            "sampleRate": sampleRate,
            "totalSamples": totalSamples,
        ]
    }

    // MARK: - Private

    private static func sampleRateFromTrack(_ track: AVAssetTrack) -> Int {
        guard let desc = track.formatDescriptions.first else {
            return 44100  // Safe fallback.
        }
        let formatDesc = desc as! CMAudioFormatDescription
        let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDesc)
        return Int(asbd?.pointee.mSampleRate ?? 44100)
    }

    enum DecoderError: LocalizedError {
        case fileNotFound(String)
        case noAudioTrack(String)
        case readerFailed(String)

        var errorDescription: String? {
            switch self {
            case .fileNotFound(let path):
                return "File not found: \(path)"
            case .noAudioTrack(let path):
                return "No audio track found in: \(path)"
            case .readerFailed(let msg):
                return "AVAssetReader failed: \(msg)"
            }
        }
    }
}
