#include "flutter_window.h"

#include <memory>
#include <optional>
#include <string>
#include <thread>

#include "flutter/generated_plugin_registrant.h"
#include "native_audio_decoder.h"

namespace {
// Custom window message used to drain FlutterWindow::MainThreadQueue.
// WM_APP is the start of the range reserved for application-defined messages.
constexpr UINT kWmRunOnMainThread = WM_APP + 1;
}  // namespace

struct FlutterWindow::MainThreadQueue {
  std::mutex mutex;
  std::queue<std::function<void()>> callbacks;
  // Window to wake; null once the window has been destroyed.
  HWND hwnd = nullptr;

  // Cancellation for the audio decoder is a generation counter: cancelDecode
  // bumps it and every decode compares the value it started under. A flag
  // reset at the start of each decode (the previous design) revived decodes
  // cancelled a moment earlier and lost a cancel that raced a new call. New
  // decodes never cancel running ones, matching the iOS decoder.
  std::atomic<uint64_t> decode_generation{0};

  // Queues |callback| for the window's message loop. Dropped once the window
  // is gone: there is no engine left to deliver a reply to.
  void Post(std::function<void()> callback) {
    std::lock_guard<std::mutex> lock(mutex);
    if (!hwnd) return;
    callbacks.push(std::move(callback));
    PostMessage(hwnd, kWmRunOnMainThread, 0, 0);
  }

  // Takes the next queued callback, or an empty function when there is none.
  std::function<void()> Take() {
    std::lock_guard<std::mutex> lock(mutex);
    if (callbacks.empty()) return nullptr;
    std::function<void()> callback = std::move(callbacks.front());
    callbacks.pop();
    return callback;
  }

  // Detaches the queue from the window; later posts are dropped.
  void Close() {
    std::lock_guard<std::mutex> lock(mutex);
    hwnd = nullptr;
    while (!callbacks.empty()) callbacks.pop();
  }
};

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  main_thread_queue_ = std::make_shared<MainThreadQueue>();
  main_thread_queue_->hwnd = GetHandle();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetupAudioDecoderChannel();
  tts_channel_ = std::make_unique<TtsChannel>(
      flutter_controller_->engine()->messenger(),
      [this](std::function<void()> callback) {
        RunOnMainThread(std::move(callback));
      });
  secure_store_channel_ = std::make_unique<SecureStoreChannel>(
      flutter_controller_->engine()->messenger());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  // Close the queue first: a decode thread that finishes from here on finds
  // no window to post to and drops its reply.
  if (main_thread_queue_) {
    main_thread_queue_->decode_generation.fetch_add(1);
    main_thread_queue_->Close();
  }
  secure_store_channel_ = nullptr;
  tts_channel_ = nullptr;
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      if (flutter_controller_) {
        flutter_controller_->engine()->ReloadSystemFonts();
      }
      break;
    case kWmRunOnMainThread: {
      if (main_thread_queue_) {
        std::function<void()> callback = main_thread_queue_->Take();
        if (callback) callback();
      }
      break;
    }
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}

void FlutterWindow::RunOnMainThread(std::function<void()> callback) {
  if (main_thread_queue_) main_thread_queue_->Post(std::move(callback));
}

namespace {

std::string GetStringArg(const flutter::EncodableMap& args, const char* key) {
  auto it = args.find(flutter::EncodableValue(key));
  if (it != args.end()) {
    if (const auto* value = std::get_if<std::string>(&it->second)) {
      return *value;
    }
  }
  return std::string();
}

int64_t GetIntArg(const flutter::EncodableMap& args, const char* key) {
  auto it = args.find(flutter::EncodableValue(key));
  if (it != args.end()) {
    if (const auto* value = std::get_if<int32_t>(&it->second)) {
      return *value;
    }
    if (const auto* value = std::get_if<int64_t>(&it->second)) {
      return *value;
    }
  }
  return 0;
}

using AudioResult =
    std::shared_ptr<flutter::MethodResult<flutter::EncodableValue>>;

void RespondInfo(const AudioResult& result, const NativeAudioDecoder::Info& info) {
  if (!info.ok) {
    result->Error(info.cancelled ? "DECODE_CANCELLED" : "DECODE_ERROR",
                  info.error);
    return;
  }
  flutter::EncodableMap map;
  map[flutter::EncodableValue("sampleRate")] =
      flutter::EncodableValue(info.sample_rate);
  map[flutter::EncodableValue("totalSamples")] =
      flutter::EncodableValue(static_cast<int>(info.total_samples));
  result->Success(flutter::EncodableValue(map));
}

}  // namespace

void FlutterWindow::SetupAudioDecoderChannel() {
  audio_decoder_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(),
          "com.birdnet/audio_decoder",
          &flutter::StandardMethodCodec::GetInstance());

  audio_decoder_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        const std::string& method = call.method_name();

        if (method == "cancelDecode") {
          main_thread_queue_->decode_generation.fetch_add(1);
          result->Success();
          return;
        }

        const auto* args =
            std::get_if<flutter::EncodableMap>(call.arguments());
        if (!args) {
          result->Error("INVALID_ARG", "Arguments must be a map");
          return;
        }

        AudioResult shared_result(result.release());
        // The worker threads below hold the queue, never `this`: the window
        // may be gone by the time a decode finishes.
        std::shared_ptr<MainThreadQueue> queue = main_thread_queue_;
        // Captured by value: a decode compares against the generation it
        // started under, so a later cancelDecode stops it and a later decode
        // does not revive it.
        const uint64_t started_under = queue->decode_generation.load();
        NativeAudioDecoder::CancelCheck is_cancelled =
            [queue, started_under]() {
              return queue->decode_generation.load() != started_under;
            };

        if (method == "inspect") {
          std::string path = GetStringArg(*args, "path");
          std::thread([queue, path, shared_result]() {
            auto info = NativeAudioDecoder::Inspect(path);
            queue->Post(
                [shared_result, info]() { RespondInfo(shared_result, info); });
          }).detach();
          return;
        }

        if (method == "decode") {
          std::string path = GetStringArg(*args, "path");
          std::string temp_path = GetStringArg(*args, "tempPcmPath");
          std::thread([queue, path, temp_path, shared_result, is_cancelled]() {
            auto info = NativeAudioDecoder::DecodeToFile(path, temp_path,
                                                         is_cancelled);
            queue->Post(
                [shared_result, info]() { RespondInfo(shared_result, info); });
          }).detach();
          return;
        }

        if (method == "decodeRange") {
          std::string path = GetStringArg(*args, "path");
          int64_t start_sample = GetIntArg(*args, "startSample");
          int64_t count = GetIntArg(*args, "count");
          std::thread([queue, path, start_sample, count, shared_result,
                       is_cancelled]() {
            auto range = NativeAudioDecoder::DecodeRange(
                path, start_sample, count, is_cancelled);
            queue->Post([shared_result, range]() {
              if (!range.ok) {
                shared_result->Error(
                    range.cancelled ? "DECODE_CANCELLED" : "DECODE_ERROR",
                    range.error);
                return;
              }
              flutter::EncodableMap map;
              map[flutter::EncodableValue("sampleRate")] =
                  flutter::EncodableValue(range.sample_rate);
              map[flutter::EncodableValue("totalSamples")] =
                  flutter::EncodableValue(
                      static_cast<int>(range.total_samples));
              map[flutter::EncodableValue("reachedEnd")] =
                  flutter::EncodableValue(range.reached_end);
              map[flutter::EncodableValue("samples")] =
                  flutter::EncodableValue(range.pcm16le);
              shared_result->Success(flutter::EncodableValue(map));
            });
          }).detach();
          return;
        }

        result->NotImplemented();
      });
}
