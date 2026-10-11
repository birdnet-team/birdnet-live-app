#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <atomic>
#include <functional>
#include <memory>
#include <mutex>
#include <queue>

#include "tts_channel.h"
#include "win32_window.h"

// A window that does nothing but host a Flutter view.
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  explicit FlutterWindow(const flutter::DartProject& project);
  virtual ~FlutterWindow();

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  // Registers the `com.birdnet/audio_decoder` MethodChannel, used to decode
  // compressed audio (AAC/M4A, MP3, etc.) that the app's pure-Dart WAV/FLAC
  // decoder can't handle — mirrors NativeAudioDecoder.kt (Android) and
  // NativeAudioDecoder.swift (iOS). See native_audio_decoder.h.
  void SetupAudioDecoderChannel();

  // Queues |callback| to run on this window's message-loop thread and wakes
  // it with a posted message. Decoding runs on a worker thread (mirroring the
  // Kotlin coroutine / GCD dispatch used on Android/iOS), but Flutter method
  // results must be completed on the platform thread — this mirrors the
  // RunOnMainThread pattern in the record_windows plugin dependency.
  void RunOnMainThread(std::function<void()> callback);

  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;

  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      audio_decoder_channel_;

  // `com.birdnet/tts`: spoken announcements. Destroyed before the Flutter
  // controller in OnDestroy so no reply can reach a torn-down engine.
  std::unique_ptr<TtsChannel> tts_channel_;
  std::atomic<bool> audio_decode_cancelled_{false};

  std::queue<std::function<void()>> main_thread_callbacks_;
  std::mutex main_thread_callbacks_mutex_;
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
