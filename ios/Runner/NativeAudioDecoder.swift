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
import Flutter

/// Decodes an audio file to mono 16-bit PCM using AVFoundation.
///
/// Returns a dictionary with:
///   - "samples": FlutterStandardTypedData of little-endian Int16 PCM (mono)
///   - "sampleRate": Int — output sample rate in Hz
///   - "totalSamples": Int — number of mono samples
enum NativeAudioDecoder {
    static var isCancelled = false

    static func inspect(path: String) throws -> [String: Any] {
        let url = URL(fileURLWithPath: path)

        guard FileManager.default.fileExists(atPath: path) else {
            throw DecoderError.fileNotFound(path)
        }

        let asset = AVURLAsset(url: url)

        guard let track = asset.tracks(withMediaType: .audio).first else {
            throw DecoderError.noAudioTrack(path)
        }

        let sampleRate = sampleRateFromTrack(track)
        let durationSeconds = CMTimeGetSeconds(asset.duration)
        let totalSamples =
            (durationSeconds.isFinite && durationSeconds > 0)
            ? Int(durationSeconds * Double(sampleRate))
            : 0

        return [
            "sampleRate": sampleRate,
            "totalSamples": totalSamples,
        ]
    }

    static func decode(path: String, tempPcmPath: String) throws -> [String: Any] {
        isCancelled = false
        let url = URL(fileURLWithPath: path)
        let tempUrl = URL(fileURLWithPath: tempPcmPath)

        guard FileManager.default.fileExists(atPath: path) else {
            throw DecoderError.fileNotFound(path)
        }

        // Remove temp file if it already exists.
        try? FileManager.default.removeItem(at: tempUrl)

        // Create file for writing.
        guard FileManager.default.createFile(atPath: tempPcmPath, contents: nil, attributes: nil),
              let fileHandle = try? FileHandle(forWritingTo: tempUrl) else {
            throw DecoderError.readerFailed("Failed to create temporary output file")
        }
        defer {
            try? fileHandle.close()
        }

        let asset = AVURLAsset(url: url)

        guard let track = asset.tracks(withMediaType: .audio).first else {
            throw DecoderError.noAudioTrack(path)
        }

        let sampleRate = sampleRateFromTrack(track)
        let reader = try AVAssetReader(asset: asset)

        // Request mono Int16 PCM output.
        let outputSettings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: sampleRate,
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
        defer {
            if reader.status != .completed && reader.status != .cancelled {
                reader.cancelReading()
            }
        }

        // Read all sample buffers.
        var totalBytes = 0

        while reader.status == .reading {
            if isCancelled {
                reader.cancelReading()
                throw DecoderError.readerFailed("Cancelled")
            }

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
            fileHandle.write(data)
            totalBytes += length
        }

        if reader.status == .failed {
            let msg = reader.error?.localizedDescription ?? "Unknown error"
            throw DecoderError.readerFailed(msg)
        }

        let totalSamples = totalBytes / 2  // 16-bit = 2 bytes per sample

        return [
            "sampleRate": sampleRate,
            "totalSamples": totalSamples,
        ]
    }

    static func decodeRange(path: String, startSample: Int, count: Int) throws -> [String: Any] {
        isCancelled = false
        let url = URL(fileURLWithPath: path)

        guard FileManager.default.fileExists(atPath: path) else {
            throw DecoderError.fileNotFound(path)
        }

        let asset = AVURLAsset(url: url)

        guard let track = asset.tracks(withMediaType: .audio).first else {
            throw DecoderError.noAudioTrack(path)
        }

        let sampleRate = sampleRateFromTrack(track)
        let reader = try AVAssetReader(asset: asset)

        // Request mono Int16 PCM output.
        let outputSettings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: sampleRate,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false,
            AVNumberOfChannelsKey: 1,
        ]

        let output = AVAssetReaderTrackOutput(track: track, outputSettings: outputSettings)
        output.alwaysCopiesSampleData = false
        reader.add(output)

        // Seek/restrict to time range.
        let startTime = CMTime(value: CMTimeValue(startSample), timescale: CMTimeScale(sampleRate))
        let durationTime = CMTime(value: CMTimeValue(count), timescale: CMTimeScale(sampleRate))
        reader.timeRange = CMTimeRange(start: startTime, duration: durationTime)

        guard reader.startReading() else {
            let msg = reader.error?.localizedDescription ?? "Unknown error"
            throw DecoderError.readerFailed(msg)
        }
        defer {
            if reader.status != .completed && reader.status != .cancelled {
                reader.cancelReading()
            }
        }

        // Read sample buffers up to the required count.
        var data = Data()
        data.reserveCapacity(count * 2)

        while reader.status == .reading {
            if isCancelled {
                reader.cancelReading()
                throw DecoderError.readerFailed("Cancelled")
            }

            guard let sampleBuffer = output.copyNextSampleBuffer() else {
                break
            }

            guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else {
                continue
            }

            let length = CMBlockBufferGetDataLength(blockBuffer)
            var bufferData = Data(count: length)
            bufferData.withUnsafeMutableBytes { rawPtr in
                guard let baseAddress = rawPtr.baseAddress else { return }
                CMBlockBufferCopyDataBytes(
                    blockBuffer, atOffset: 0, dataLength: length,
                    destination: baseAddress
                )
            }

            data.append(bufferData)

            if data.count >= count * 2 {
                break
            }
        }

        if reader.status == .failed {
            let msg = reader.error?.localizedDescription ?? "Unknown error"
            throw DecoderError.readerFailed(msg)
        }

        // If we read more samples than requested, truncate.
        if data.count > count * 2 {
            data = data.prefix(count * 2)
        }

        let totalSamples = data.count / 2
        let flutterData = FlutterStandardTypedData(bytes: data)

        return [
            "samples": flutterData,
            "sampleRate": sampleRate,
            "totalSamples": totalSamples,
            "reachedEnd": data.count < count * 2,
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
