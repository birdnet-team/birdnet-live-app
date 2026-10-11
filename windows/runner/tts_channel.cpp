#include "tts_channel.h"

#include <windows.h>

#include <winrt/Windows.Foundation.Collections.h>
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Media.Core.h>
#include <winrt/Windows.Media.Playback.h>
#include <winrt/Windows.Media.SpeechSynthesis.h>
#include <winrt/Windows.Storage.Streams.h>

#include <flutter/standard_method_codec.h>

#include <algorithm>
#include <atomic>
#include <cctype>
#include <string>

namespace {

using flutter::EncodableList;
using flutter::EncodableMap;
using flutter::EncodableValue;
using winrt::Windows::Foundation::AsyncStatus;
using winrt::Windows::Foundation::IAsyncOperation;
using winrt::Windows::Foundation::IInspectable;
using winrt::Windows::Media::Core::MediaSource;
using winrt::Windows::Media::Playback::IMediaPlaybackSource;
using winrt::Windows::Media::Playback::MediaPlayer;
using winrt::Windows::Media::Playback::MediaPlayerFailedEventArgs;
using winrt::Windows::Media::SpeechSynthesis::SpeechSynthesisStream;
using winrt::Windows::Media::SpeechSynthesis::SpeechSynthesizer;
using winrt::Windows::Media::SpeechSynthesis::VoiceInformation;

using MethodResult = flutter::MethodResult<EncodableValue>;

std::string Lower(std::string text) {
  for (auto& c : text) {
    c = static_cast<char>(std::tolower(static_cast<unsigned char>(c)));
  }
  return text;
}

std::string GetStringArg(const EncodableMap* args, const char* key) {
  if (!args) return std::string();
  auto it = args->find(EncodableValue(key));
  if (it == args->end()) return std::string();
  if (const auto* value = std::get_if<std::string>(&it->second)) {
    return *value;
  }
  return std::string();
}

double GetDoubleArg(const EncodableMap* args, const char* key,
                    double fallback) {
  if (!args) return fallback;
  auto it = args->find(EncodableValue(key));
  if (it == args->end()) return fallback;
  if (const auto* value = std::get_if<double>(&it->second)) return *value;
  if (const auto* value = std::get_if<int32_t>(&it->second)) return *value;
  if (const auto* value = std::get_if<int64_t>(&it->second)) {
    return static_cast<double>(*value);
  }
  return fallback;
}

}  // namespace

// Everything here runs on the platform thread; the WinRT callbacks only
// capture a weak pointer and re-enter through |post_to_main|.
struct TtsChannel::State : std::enable_shared_from_this<TtsChannel::State> {
  explicit State(std::function<void(std::function<void()>)> post)
      : post_to_main(std::move(post)) {}

  std::function<void(std::function<void()>)> post_to_main;
  SpeechSynthesizer synth{nullptr};
  MediaPlayer player{nullptr};
  MediaPlayer::MediaEnded_revoker ended_revoker;
  MediaPlayer::MediaFailed_revoker failed_revoker;

  // The `speak` reply still outstanding, and the utterance it belongs to.
  // Every speak/stop bumps |sequence| so late callbacks for a superseded
  // utterance can be told apart from the current one.
  std::shared_ptr<MethodResult> pending;
  std::atomic<uint64_t> sequence{0};

  bool EnsureEngine();
  void Settle(bool success);
  void Speak(const std::string& text, std::shared_ptr<MethodResult> result);
  void Stop();
  bool SetLanguage(const std::string& tag);
  bool SetVoice(const std::string& name, const std::string& locale);
  void SetRate(double rate);
  void SetPitch(double pitch);
  EncodableList Voices();
  void Shutdown();
};

bool TtsChannel::State::EnsureEngine() {
  if (synth) return true;
  try {
    synth = SpeechSynthesizer();
    player = MediaPlayer();
    std::weak_ptr<State> weak = weak_from_this();
    ended_revoker = player.MediaEnded(
        winrt::auto_revoke,
        [weak](MediaPlayer const&, IInspectable const&) {
          auto self = weak.lock();
          if (!self) return;
          const uint64_t seq = self->sequence.load();
          self->post_to_main([weak, seq]() {
            auto state = weak.lock();
            if (state && state->sequence.load() == seq) state->Settle(true);
          });
        });
    failed_revoker = player.MediaFailed(
        winrt::auto_revoke,
        [weak](MediaPlayer const&, MediaPlayerFailedEventArgs const&) {
          auto self = weak.lock();
          if (!self) return;
          const uint64_t seq = self->sequence.load();
          self->post_to_main([weak, seq]() {
            auto state = weak.lock();
            if (state && state->sequence.load() == seq) state->Settle(false);
          });
        });
    return true;
  } catch (winrt::hresult_error const&) {
    synth = nullptr;
    player = nullptr;
    return false;
  }
}

void TtsChannel::State::Settle(bool success) {
  if (!pending) return;
  auto result = std::move(pending);
  pending.reset();
  result->Success(EncodableValue(success));
}

void TtsChannel::State::Speak(const std::string& text,
                              std::shared_ptr<MethodResult> result) {
  Stop();
  if (!EnsureEngine()) {
    result->Success(EncodableValue(false));
    return;
  }
  const uint64_t seq = ++sequence;
  pending = std::move(result);
  std::weak_ptr<State> weak = weak_from_this();
  try {
    auto operation = synth.SynthesizeTextToStreamAsync(winrt::to_hstring(text));
    operation.Completed([weak, seq](
                            IAsyncOperation<SpeechSynthesisStream> const& op,
                            AsyncStatus status) {
      // Thread-pool thread: only pick up the stream, then hand it over.
      SpeechSynthesisStream stream{nullptr};
      if (status == AsyncStatus::Completed) {
        try {
          stream = op.GetResults();
        } catch (winrt::hresult_error const&) {
        }
      }
      auto self = weak.lock();
      if (!self) return;
      self->post_to_main([weak, seq, stream]() {
        auto state = weak.lock();
        // Stopped or superseded while synthesizing: drop silently.
        if (!state || state->sequence.load() != seq) return;
        if (!stream) {
          state->Settle(false);
          return;
        }
        try {
          state->player.Source(
              MediaSource::CreateFromStream(stream, stream.ContentType()));
          state->player.Play();
        } catch (winrt::hresult_error const&) {
          state->Settle(false);
        }
      });
    });
  } catch (winrt::hresult_error const&) {
    Settle(false);
  }
}

void TtsChannel::State::Stop() {
  ++sequence;  // invalidates in-flight synthesis and playback callbacks
  Settle(false);
  if (!player) return;
  try {
    player.Pause();
    player.Source(IMediaPlaybackSource{nullptr});
  } catch (winrt::hresult_error const&) {
  }
}

bool TtsChannel::State::SetLanguage(const std::string& tag) {
  const std::string wanted = Lower(tag);
  if (wanted.empty() || !EnsureEngine()) return false;
  const bool region_less = wanted.find('-') == std::string::npos;
  try {
    // The system default voice wins when it speaks the requested language.
    VoiceInformation default_voice = SpeechSynthesizer::DefaultVoice();
    if (default_voice &&
        Lower(winrt::to_string(default_voice.Language())) == wanted) {
      synth.Voice(default_voice);
      return true;
    }
    VoiceInformation exact{nullptr};
    VoiceInformation same_language{nullptr};
    for (VoiceInformation const& candidate : SpeechSynthesizer::AllVoices()) {
      const std::string language =
          Lower(winrt::to_string(candidate.Language()));
      if (language == wanted) {
        exact = candidate;
        break;
      }
      // A region-less tag such as `de` accepts any `de-*` voice.
      if (!same_language && region_less &&
          language.rfind(wanted + "-", 0) == 0) {
        same_language = candidate;
      }
    }
    VoiceInformation match = exact ? exact : same_language;
    if (!match) return false;
    synth.Voice(match);
    return true;
  } catch (winrt::hresult_error const&) {
    return false;
  }
}

bool TtsChannel::State::SetVoice(const std::string& name,
                                 const std::string& locale) {
  if (!EnsureEngine()) return false;
  const std::string wanted_locale = Lower(locale);
  try {
    for (VoiceInformation const& candidate : SpeechSynthesizer::AllVoices()) {
      if (winrt::to_string(candidate.DisplayName()) == name &&
          Lower(winrt::to_string(candidate.Language())) == wanted_locale) {
        synth.Voice(candidate);
        return true;
      }
    }
  } catch (winrt::hresult_error const&) {
  }
  return false;
}

void TtsChannel::State::SetRate(double rate) {
  if (!EnsureEngine()) return;
  try {
    // SpeakingRate: 0.5–6.0, 1.0 = normal.
    synth.Options().SpeakingRate(std::clamp(rate, 0.5, 6.0));
  } catch (winrt::hresult_error const&) {
  }
}

void TtsChannel::State::SetPitch(double pitch) {
  if (!EnsureEngine()) return;
  try {
    // AudioPitch: 0.0–2.0, 1.0 = normal.
    synth.Options().AudioPitch(std::clamp(pitch, 0.0, 2.0));
  } catch (winrt::hresult_error const&) {
  }
}

EncodableList TtsChannel::State::Voices() {
  EncodableList voices;
  try {
    for (VoiceInformation const& voice : SpeechSynthesizer::AllVoices()) {
      EncodableMap entry;
      entry[EncodableValue("name")] =
          EncodableValue(winrt::to_string(voice.DisplayName()));
      entry[EncodableValue("locale")] =
          EncodableValue(winrt::to_string(voice.Language()));
      voices.push_back(EncodableValue(entry));
    }
  } catch (winrt::hresult_error const&) {
  }
  return voices;
}

// Teardown only: the engine may already be gone, so the pending reply is
// dropped rather than sent.
void TtsChannel::State::Shutdown() {
  ++sequence;
  pending.reset();
  ended_revoker.revoke();
  failed_revoker.revoke();
  if (player) {
    try {
      player.Close();
    } catch (winrt::hresult_error const&) {
    }
  }
  player = nullptr;
  synth = nullptr;
}

TtsChannel::TtsChannel(
    flutter::BinaryMessenger* messenger,
    std::function<void(std::function<void()>)> run_on_main_thread)
    : state_(std::make_shared<State>(std::move(run_on_main_thread))) {
  channel_ = std::make_unique<flutter::MethodChannel<EncodableValue>>(
      messenger, "com.birdnet/tts",
      &flutter::StandardMethodCodec::GetInstance());
  channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<EncodableValue>& call,
             std::unique_ptr<MethodResult> result) {
        HandleMethodCall(call, std::move(result));
      });
}

TtsChannel::~TtsChannel() {
  channel_->SetMethodCallHandler(nullptr);
  state_->Shutdown();
}

void TtsChannel::HandleMethodCall(
    const flutter::MethodCall<EncodableValue>& call,
    std::unique_ptr<MethodResult> result) {
  const auto* args = std::get_if<EncodableMap>(call.arguments());
  const std::string& method = call.method_name();

  if (method == "setLanguage") {
    result->Success(
        EncodableValue(state_->SetLanguage(GetStringArg(args, "tag"))));
  } else if (method == "setVoice") {
    result->Success(EncodableValue(state_->SetVoice(
        GetStringArg(args, "name"), GetStringArg(args, "locale"))));
  } else if (method == "setRate") {
    state_->SetRate(GetDoubleArg(args, "rate", 1.0));
    result->Success();
  } else if (method == "setPitch") {
    state_->SetPitch(GetDoubleArg(args, "pitch", 1.0));
    result->Success();
  } else if (method == "getVoices") {
    result->Success(EncodableValue(state_->Voices()));
  } else if (method == "speak") {
    state_->Speak(GetStringArg(args, "text"),
                  std::shared_ptr<MethodResult>(result.release()));
  } else if (method == "stop") {
    state_->Stop();
    result->Success();
  } else {
    result->NotImplemented();
  }
}
