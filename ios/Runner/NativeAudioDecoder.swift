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
    /// Cancellation is a generation counter, not a flag. `cancelAll()` bumps
    /// it and every decode compares the generation it started under. The
    /// flag this replaces was reset at the start of each new decode, which
    /// revived decodes cancelled a moment earlier (Session Review scrubbing
    /// after leaving a screen), and a cancel that raced a new call was lost.
    /// New decodes never cancel running ones — the dispatch queue has always
    /// allowed them to overlap, and callers rely on that.
    private static let generationLock = NSLock()
    private static var generation: UInt64 = 0

    /// Cancels every decode in flight.
    static func cancelAll() {
        generationLock.lock()
        generation &+= 1
        generationLock.unlock()
    }

    /// The generation a decode should run under. The channel handler reads it
    /// on the main thread, before dispatching, and passes it in: read inside
    /// the dispatched block instead, a `cancelDecode` that lands between the
    /// two would be missed and the decode would run to completion.
    static func currentGeneration() -> UInt64 {
        generationLock.lock()
        defer { generationLock.unlock() }
        return generation
    }

    static func inspect(path: String) throws -> [String: Any] {
        let url = URL(fileURLWithPath: path)

        guard FileManager.default.fileExists(atPath: path) else {
            throw DecoderError.fileNotFound(path)
        }

        let asset = preciseAsset(url)

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

    static func decode(
        path: String, tempPcmPath: String, generation: UInt64? = nil
    ) throws -> [String: Any] {
        let startedUnder = generation ?? currentGeneration()
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
        // `add` raises an uncatchable exception for a track the reader cannot
        // convert (a format description without a sample rate, say).
        guard reader.canAdd(output) else {
            throw DecoderError.readerFailed("Unsupported audio format")
        }
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

        // Read all sample buffers. Each pass runs in its own autorelease pool:
        // the GCD thread's pool only drains when this block returns, so an
        // hour-long decode would otherwise hold every sample buffer until the
        // end.
        var totalBytes = 0

        while reader.status == .reading {
            if currentGeneration() != startedUnder {
                reader.cancelReading()
                throw DecoderError.readerFailed("Cancelled")
            }

            let finished: Bool = try autoreleasepool {
                guard let sampleBuffer = output.copyNextSampleBuffer() else {
                    return true
                }
                guard let data = copyPcm(sampleBuffer) else { return false }
                // Throws on a full disk, where the legacy `write(_:)` raised an
                // NSFileHandleOperationException Swift cannot catch.
                try fileHandle.write(contentsOf: data)
                totalBytes += data.count
                return false
            }
            if finished { break }
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

    static func decodeRange(
        path: String, startSample: Int, count: Int, generation: UInt64? = nil
    ) throws -> [String: Any] {
        let startedUnder = generation ?? currentGeneration()
        let url = URL(fileURLWithPath: path)

        guard FileManager.default.fileExists(atPath: path) else {
            throw DecoderError.fileNotFound(path)
        }
        guard startSample >= 0 else {
            throw DecoderError.readerFailed("Negative start sample")
        }

        // Precise timing makes the seek below land on the requested sample
        // for VBR MP3 too; without it chunk boundaries drift.
        let asset = preciseAsset(url)

        guard let track = asset.tracks(withMediaType: .audio).first else {
            throw DecoderError.noAudioTrack(path)
        }

        let sampleRate = sampleRateFromTrack(track)
        if count <= 0 {
            return [
                "samples": FlutterStandardTypedData(bytes: Data()),
                "sampleRate": sampleRate,
                "totalSamples": 0,
                "reachedEnd": false,
            ]
        }
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
        // `add` raises an uncatchable exception for a track the reader cannot
        // convert (a format description without a sample rate, say).
        guard reader.canAdd(output) else {
            throw DecoderError.readerFailed("Unsupported audio format")
        }
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
            if currentGeneration() != startedUnder {
                reader.cancelReading()
                throw DecoderError.readerFailed("Cancelled")
            }

            let finished: Bool = autoreleasepool {
                guard let sampleBuffer = output.copyNextSampleBuffer() else {
                    return true
                }
                if let pcm = copyPcm(sampleBuffer) {
                    data.append(pcm)
                }
                return data.count >= count * 2
            }
            if finished { break }
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

    /// An asset whose duration and seeks are exact. The default estimates
    /// both for VBR MP3, and File Analysis plans its windows from the
    /// duration: an estimate that runs short silently drops the end of the
    /// recording. Costs one scan of the file.
    private static func preciseAsset(_ url: URL) -> AVURLAsset {
        AVURLAsset(url: url, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
    }

    /// The PCM bytes of one sample buffer, or nil for a buffer without data.
    private static func copyPcm(_ sampleBuffer: CMSampleBuffer) -> Data? {
        guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else {
            return nil
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
        return data
    }

    private static func sampleRateFromTrack(_ track: AVAssetTrack) -> Int {
        guard let desc = track.formatDescriptions.first else {
            return 44100  // Safe fallback.
        }
        let formatDesc = desc as! CMAudioFormatDescription
        let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDesc)
        let rate = Int(asbd?.pointee.mSampleRate ?? 44100)
        // A zero rate would make the CMTime seek in `decodeRange` invalid.
        return rate > 0 ? rate : 44100
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
