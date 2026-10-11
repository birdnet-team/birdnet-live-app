#include "flutter_window.h"

#include <memory>
#include <optional>
#include <string>
#include <thread>

#include "flutter/generated_plugin_registrant.h"
#include "native_audio_decoder.h"

namespace {
// Custom window message used to drain FlutterWindow::main_thread_callbacks_.
// WM_APP is the start of the range reserved for application-defined messages.
constexpr UINT kWmRunOnMainThread = WM_APP + 1;
}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

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
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
    case kWmRunOnMainThread: {
      std::function<void()> callback;
      {
        std::lock_guard<std::mutex> lock(main_thread_callbacks_mutex_);
        if (!main_thread_callbacks_.empty()) {
          callback = std::move(main_thread_callbacks_.front());
          main_thread_callbacks_.pop();
        }
      }
      if (callback) callback();
      break;
    }
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}

void FlutterWindow::RunOnMainThread(std::function<void()> callback) {
  {
    std::lock_guard<std::mutex> lock(main_thread_callbacks_mutex_);
    main_thread_callbacks_.push(std::move(callback));
  }
  PostMessage(GetHandle(), kWmRunOnMainThread, 0, 0);
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
    result->Error("DECODE_ERROR", info.error);
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
          audio_decode_cancelled_.store(true);
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
        auto* cancelled = &audio_decode_cancelled_;

        if (method == "inspect") {
          std::string path = GetStringArg(*args, "path");
          std::thread([this, path, shared_result]() {
            auto info = NativeAudioDecoder::Inspect(path);
            this->RunOnMainThread(
                [shared_result, info]() { RespondInfo(shared_result, info); });
          }).detach();
          return;
        }

        if (method == "decode") {
          std::string path = GetStringArg(*args, "path");
          std::string temp_path = GetStringArg(*args, "tempPcmPath");
          audio_decode_cancelled_.store(false);
          std::thread([this, path, temp_path, shared_result, cancelled]() {
            auto info =
                NativeAudioDecoder::DecodeToFile(path, temp_path, cancelled);
            this->RunOnMainThread(
                [shared_result, info]() { RespondInfo(shared_result, info); });
          }).detach();
          return;
        }

        if (method == "decodeRange") {
          std::string path = GetStringArg(*args, "path");
          int64_t start_sample = GetIntArg(*args, "startSample");
          int64_t count = GetIntArg(*args, "count");
          audio_decode_cancelled_.store(false);
          std::thread([this, path, start_sample, count, shared_result,
                       cancelled]() {
            auto range = NativeAudioDecoder::DecodeRange(
                path, start_sample, count, cancelled);
            this->RunOnMainThread([shared_result, range]() {
              if (!range.ok) {
                shared_result->Error("DECODE_ERROR", range.error);
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
