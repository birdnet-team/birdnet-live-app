import AVFoundation
import Flutter
import Foundation

/// Text-to-speech bridge for spoken announcements — the iOS half of the
/// `com.birdnet/tts` channel. See lib/features/announcements/platform/
/// tts_engine.dart for the contract, TtsChannel.kt and tts_channel.cpp for the
/// Android and Windows halves.
///
/// Speech plays through the app's shared AVAudioSession (the synthesizer's
/// default), which the Announcements routing service configures, so an
/// utterance never tears down live capture. The synthesizer is created lazily
/// on the first `speak`.
final class TtsChannel: NSObject, AVSpeechSynthesizerDelegate {
  private let channel: FlutterMethodChannel
  private var synthesizer: AVSpeechSynthesizer?

  /// Language of the voice the last successful `setLanguage` resolved to.
  private var language: String?
  private var voice: AVSpeechSynthesisVoice?
  private var rate: Float = AVSpeechUtteranceDefaultSpeechRate
  private var pitch: Float = 1.0

  /// The utterance whose `speak` reply is still outstanding.
  private var pendingUtterance: AVSpeechUtterance?
  private var pendingResult: FlutterResult?

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "com.birdnet/tts", binaryMessenger: messenger)
    super.init()
    channel.setMethodCallHandler { [weak self] (call, result) in
      guard let self = self else {
        result(nil)
        return
      }
      self.handle(call, result: result)
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "setLanguage":
      result(setLanguage(args["tag"] as? String ?? ""))
    case "setVoice":
      result(setVoice(name: args["name"] as? String ?? "", locale: args["locale"] as? String ?? ""))
    case "setRate":
      // 1.0 is the platform's normal pace; AVSpeechUtterance expresses that
      // as AVSpeechUtteranceDefaultSpeechRate on its own 0...1 scale.
      let factor = Float(args["rate"] as? Double ?? 1.0)
      rate = min(
        max(factor * AVSpeechUtteranceDefaultSpeechRate, AVSpeechUtteranceMinimumSpeechRate),
        AVSpeechUtteranceMaximumSpeechRate)
      result(nil)
    case "setPitch":
      pitch = min(max(Float(args["pitch"] as? Double ?? 1.0), 0.5), 2.0)
      result(nil)
    case "getVoices":
      result(AVSpeechSynthesisVoice.speechVoices().map { ["name": $0.name, "locale": $0.language] })
    case "speak":
      speak(args["text"] as? String ?? "", result: result)
    case "stop":
      stop()
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - Configuration

  private func setLanguage(_ tag: String) -> Bool {
    guard let match = TtsChannel.voice(forLanguage: tag) else { return false }
    language = match.language
    voice = nil
    return true
  }

  /// An installed voice for `tag`: an exact (case-insensitive) language match
  /// wins. A region-less tag such as `de` — which is what the species locale
  /// is, except for Chinese — prefers the user's own region, then the voice
  /// the system picks for the language (what flutter_tts resolved before the
  /// custom channel), and only then the first installed `de-*` voice.
  /// `speechVoices()` is ordered alphabetically, so that last fallback alone
  /// would read English species names in Australian and French ones in
  /// Canadian French.
  private static func voice(forLanguage tag: String) -> AVSpeechSynthesisVoice? {
    let wanted = tag.lowercased()
    if wanted.isEmpty { return nil }
    let voices = AVSpeechSynthesisVoice.speechVoices()
    if let exact = voices.first(where: { $0.language.lowercased() == wanted }) {
      return exact
    }
    if !wanted.contains("-") {
      if let region = Locale.current.region?.identifier.lowercased(),
         let regional = voices.first(where: { $0.language.lowercased() == "\(wanted)-\(region)" }) {
        return regional
      }
      if let system = AVSpeechSynthesisVoice(language: tag) {
        return system
      }
      return voices.first(where: { $0.language.lowercased().hasPrefix(wanted + "-") })
    }
    return nil
  }

  private func setVoice(name: String, locale: String) -> Bool {
    let wantedLocale = locale.lowercased()
    let matches = AVSpeechSynthesisVoice.speechVoices().filter {
      $0.name == name && $0.language.lowercased() == wantedLocale
    }
    // Several qualities can share a name; prefer the best one installed.
    guard let best = matches.max(by: { $0.quality.rawValue < $1.quality.rawValue }) else {
      return false
    }
    voice = best
    language = best.language
    return true
  }

  // MARK: - Speaking

  private func speak(_ text: String, result: @escaping FlutterResult) {
    let synth = synthesizer ?? makeSynthesizer()
    settlePending(false)
    synth.stopSpeaking(at: .immediate)

    let utterance = AVSpeechUtterance(string: text)
    utterance.voice = voice ?? language.flatMap { AVSpeechSynthesisVoice(language: $0) }
    utterance.rate = rate
    utterance.pitchMultiplier = pitch
    pendingUtterance = utterance
    pendingResult = result
    synth.speak(utterance)
  }

  private func makeSynthesizer() -> AVSpeechSynthesizer {
    let synth = AVSpeechSynthesizer()
    synth.delegate = self
    // The routing service configures the shared session; make sure it is
    // active before the first utterance (a no-op while capture is running).
    try? AVAudioSession.sharedInstance().setActive(true)
    synthesizer = synth
    return synth
  }

  private func stop() {
    settlePending(false)
    synthesizer?.stopSpeaking(at: .immediate)
  }

  private func settlePending(_ success: Bool) {
    guard let result = pendingResult else { return }
    pendingResult = nil
    pendingUtterance = nil
    result(success)
  }

  // MARK: - AVSpeechSynthesizerDelegate

  func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
    settle(utterance, success: true)
  }

  func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
    settle(utterance, success: false)
  }

  /// Settles the pending reply if `utterance` is still the one it belongs to;
  /// stale callbacks for a flushed utterance are ignored.
  private func settle(_ utterance: AVSpeechUtterance, success: Bool) {
    let work = { [weak self] in
      guard let self = self, self.pendingUtterance === utterance else { return }
      self.settlePending(success)
    }
    if Thread.isMainThread {
      work()
    } else {
      DispatchQueue.main.async(execute: work)
    }
  }
}
