#ifndef RUNNER_TTS_CHANNEL_H_
#define RUNNER_TTS_CHANNEL_H_

#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>

#include <functional>
#include <memory>

// Text-to-speech bridge for spoken announcements — the Windows half of the
// `com.birdnet/tts` channel. See lib/features/announcements/platform/
// tts_engine.dart for the contract, TtsChannel.kt and TtsChannel.swift for
// the Android and iOS halves.
//
// Speech is synthesized with the WinRT SpeechSynthesizer (the same OneCore
// voices the Windows Settings app lists) and played through a MediaPlayer.
// Synthesis and playback events complete on thread-pool threads, so they are
// handed back to the platform thread through |run_on_main_thread| before any
// channel reply. The engine is created lazily on the first call.
class TtsChannel {
 public:
  TtsChannel(flutter::BinaryMessenger* messenger,
             std::function<void(std::function<void()>)> run_on_main_thread);
  ~TtsChannel();

  TtsChannel(const TtsChannel&) = delete;
  TtsChannel& operator=(const TtsChannel&) = delete;

 private:
  struct State;

  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
  std::shared_ptr<State> state_;
};

#endif  // RUNNER_TTS_CHANNEL_H_
