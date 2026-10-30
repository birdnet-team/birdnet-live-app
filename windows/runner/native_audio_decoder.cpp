#include "native_audio_decoder.h"

#include <windows.h>

#include <mfapi.h>
#include <mferror.h>
#include <mfidl.h>
#include <mfreadwrite.h>
#include <propvarutil.h>

#include <fstream>

namespace {

// A scoped COM + Media Foundation session. Each decode call runs on its own
// worker thread (see flutter_window.cpp), so each one gets its own
// CoInitializeEx/MFStartup pair rather than sharing global state across
// threads.
class MfSession {
 public:
  MfSession() {
    co_hr_ = CoInitializeEx(nullptr, COINIT_MULTITHREADED);
    if (SUCCEEDED(co_hr_) || co_hr_ == RPC_E_CHANGED_MODE) {
      mf_hr_ = MFStartup(MF_VERSION, MFSTARTUP_NOSOCKET);
    }
  }
  ~MfSession() {
    if (SUCCEEDED(mf_hr_)) {
      MFShutdown();
    }
    if (SUCCEEDED(co_hr_)) {
      CoUninitialize();
    }
  }
  bool ok() const { return SUCCEEDED(mf_hr_); }

 private:
  HRESULT co_hr_ = E_FAIL;
  HRESULT mf_hr_ = E_FAIL;
};

template <typename T>
void SafeRelease(T** ptr) {
  if (*ptr) {
    (*ptr)->Release();
    *ptr = nullptr;
  }
}

std::wstring Utf8ToWide(const std::string& utf8) {
  if (utf8.empty()) return std::wstring();
  int size =
      MultiByteToWideChar(CP_UTF8, 0, utf8.c_str(), -1, nullptr, 0);
  if (size <= 0) return std::wstring();
  std::wstring result(static_cast<size_t>(size - 1), L'\0');
  MultiByteToWideChar(CP_UTF8, 0, utf8.c_str(), -1, &result[0], size);
  return result;
}

// Opens |path| and negotiates a mono-or-native-channel 16-bit PCM output on
// the first audio stream. Leaves sample rate/channel count as whatever the
// source natively decodes to — callers downmix to mono themselves (mirroring
// the explicit downmix done on Android) and the Dart side already resamples
// via DecodedAudio.resampleTo() after decode.
HRESULT OpenAndNegotiate(const std::wstring& wpath,
                         IMFSourceReader** out_reader,
                         int* out_sample_rate,
                         int* out_channels) {
  *out_reader = nullptr;
  *out_sample_rate = 0;
  *out_channels = 0;

  IMFAttributes* attributes = nullptr;
  HRESULT hr = MFCreateAttributes(&attributes, 1);
  if (SUCCEEDED(hr)) {
    // Synchronous (pull-based) reads — no async callback attribute set.
    hr = attributes->SetUINT32(MF_READWRITE_ENABLE_HARDWARE_TRANSFORMS, TRUE);
  }

  IMFSourceReader* reader = nullptr;
  if (SUCCEEDED(hr)) {
    hr = MFCreateSourceReaderFromURL(wpath.c_str(), attributes, &reader);
  }
  SafeRelease(&attributes);
  if (FAILED(hr)) {
    return hr;
  }

  // Only decode the first audio stream.
  hr = reader->SetStreamSelection(static_cast<DWORD>(MF_SOURCE_READER_ALL_STREAMS), FALSE);
  if (SUCCEEDED(hr)) {
    hr = reader->SetStreamSelection(
        static_cast<DWORD>(MF_SOURCE_READER_FIRST_AUDIO_STREAM), TRUE);
  }

  IMFMediaType* pcm_type = nullptr;
  if (SUCCEEDED(hr)) {
    hr = MFCreateMediaType(&pcm_type);
  }
  if (SUCCEEDED(hr)) {
    hr = pcm_type->SetGUID(MF_MT_MAJOR_TYPE, MFMediaType_Audio);
  }
  if (SUCCEEDED(hr)) {
    hr = pcm_type->SetGUID(MF_MT_SUBTYPE, MFAudioFormat_PCM);
  }
  if (SUCCEEDED(hr)) {
    hr = pcm_type->SetUINT32(MF_MT_AUDIO_BITS_PER_SAMPLE, 16);
  }
  if (SUCCEEDED(hr)) {
    hr = reader->SetCurrentMediaType(
        static_cast<DWORD>(MF_SOURCE_READER_FIRST_AUDIO_STREAM), nullptr,
        pcm_type);
  }
  SafeRelease(&pcm_type);
  if (FAILED(hr)) {
    SafeRelease(&reader);
    return hr;
  }

  IMFMediaType* actual_type = nullptr;
  hr = reader->GetCurrentMediaType(
      static_cast<DWORD>(MF_SOURCE_READER_FIRST_AUDIO_STREAM), &actual_type);
  if (SUCCEEDED(hr)) {
    UINT32 sample_rate = 0;
    UINT32 channels = 0;
    actual_type->GetUINT32(MF_MT_AUDIO_SAMPLES_PER_SECOND, &sample_rate);
    actual_type->GetUINT32(MF_MT_AUDIO_NUM_CHANNELS, &channels);
    *out_sample_rate = static_cast<int>(sample_rate);
    *out_channels = static_cast<int>(channels > 0 ? channels : 1);
  }
  SafeRelease(&actual_type);

  if (FAILED(hr) || *out_sample_rate <= 0) {
    SafeRelease(&reader);
    return FAILED(hr) ? hr : E_FAIL;
  }

  *out_reader = reader;
  return S_OK;
}

// Downmixes interleaved PCM16 |src| (|frame_count| frames of |channels|
// channels) into mono int16 samples appended to |out|.
void AppendDownmixed(const int16_t* src, size_t frame_count, int channels,
                     std::vector<int16_t>* out) {
  const size_t base = out->size();
  out->resize(base + frame_count);
  if (channels <= 1) {
    memcpy(out->data() + base, src, frame_count * sizeof(int16_t));
    return;
  }
  for (size_t i = 0; i < frame_count; i++) {
    int32_t sum = 0;
    for (int c = 0; c < channels; c++) {
      sum += src[i * channels + c];
    }
    (*out)[base + i] = static_cast<int16_t>(sum / channels);
  }
}

}  // namespace

NativeAudioDecoder::Info NativeAudioDecoder::Inspect(
    const std::string& utf8_path) {
  Info info;
  MfSession session;
  if (!session.ok()) {
    info.error = "Media Foundation failed to start";
    return info;
  }

  IMFSourceReader* reader = nullptr;
  int sample_rate = 0, channels = 0;
  HRESULT hr = OpenAndNegotiate(Utf8ToWide(utf8_path), &reader, &sample_rate,
                                 &channels);
  if (FAILED(hr)) {
    info.error = "Failed to open audio file";
    return info;
  }

  PROPVARIANT var;
  PropVariantInit(&var);
  hr = reader->GetPresentationAttribute(
      static_cast<DWORD>(MF_SOURCE_READER_MEDIASOURCE), MF_PD_DURATION, &var);
  if (SUCCEEDED(hr)) {
    LONGLONG duration_100ns = 0;
    PropVariantToInt64(var, &duration_100ns);
    info.ok = true;
    info.sample_rate = sample_rate;
    info.total_samples = static_cast<int64_t>(
        static_cast<double>(duration_100ns) * sample_rate / 10000000.0);
  } else {
    info.error = "Failed to read duration";
  }
  PropVariantClear(&var);
  SafeRelease(&reader);
  return info;
}

NativeAudioDecoder::Info NativeAudioDecoder::DecodeToFile(
    const std::string& utf8_path, const std::string& utf8_temp_path,
    const CancelCheck& is_cancelled) {
  Info info;
  MfSession session;
  if (!session.ok()) {
    info.error = "Media Foundation failed to start";
    return info;
  }

  IMFSourceReader* reader = nullptr;
  int sample_rate = 0, channels = 0;
  HRESULT hr = OpenAndNegotiate(Utf8ToWide(utf8_path), &reader, &sample_rate,
                                 &channels);
  if (FAILED(hr)) {
    info.error = "Failed to open audio file";
    return info;
  }

  std::ofstream out(Utf8ToWide(utf8_temp_path), std::ios::binary);
  if (!out.is_open()) {
    SafeRelease(&reader);
    info.error = "Failed to create temp PCM file";
    return info;
  }

  int64_t total_samples = 0;
  bool reader_failed = false;
  bool was_cancelled = false;
  for (;;) {
    if (is_cancelled && is_cancelled()) {
      was_cancelled = true;
      break;
    }

    DWORD stream_index = 0, flags = 0;
    LONGLONG timestamp = 0;
    IMFSample* sample = nullptr;
    hr = reader->ReadSample(
        static_cast<DWORD>(MF_SOURCE_READER_FIRST_AUDIO_STREAM), 0,
        &stream_index, &flags, &timestamp, &sample);
    if (FAILED(hr)) {
      reader_failed = true;
      break;
    }

    if (sample) {
      IMFMediaBuffer* buffer = nullptr;
      if (SUCCEEDED(sample->ConvertToContiguousBuffer(&buffer))) {
        BYTE* data = nullptr;
        DWORD length = 0;
        if (SUCCEEDED(buffer->Lock(&data, nullptr, &length))) {
          size_t frame_count =
              length / (sizeof(int16_t) * static_cast<size_t>(channels));
          std::vector<int16_t> mono;
          AppendDownmixed(reinterpret_cast<const int16_t*>(data), frame_count,
                          channels, &mono);
          out.write(reinterpret_cast<const char*>(mono.data()),
                    static_cast<std::streamsize>(mono.size() *
                                                  sizeof(int16_t)));
          total_samples += static_cast<int64_t>(frame_count);
          buffer->Unlock();
        }
        SafeRelease(&buffer);
      }
      SafeRelease(&sample);
    }

    if (flags & MF_SOURCE_READERF_ENDOFSTREAM) break;
  }

  out.close();
  SafeRelease(&reader);

  if (was_cancelled) {
    info.cancelled = true;
    info.error = "Decoding cancelled";
    return info;
  }
  if (reader_failed) {
    info.error = "Decode failed while reading samples";
    return info;
  }

  info.ok = true;
  info.sample_rate = sample_rate;
  info.total_samples = total_samples;
  return info;
}

NativeAudioDecoder::RangeResult NativeAudioDecoder::DecodeRange(
    const std::string& utf8_path, int64_t start_sample, int64_t count,
    const CancelCheck& is_cancelled) {
  RangeResult result;
  MfSession session;
  if (!session.ok()) {
    result.error = "Media Foundation failed to start";
    return result;
  }

  IMFSourceReader* reader = nullptr;
  int sample_rate = 0, channels = 0;
  HRESULT hr = OpenAndNegotiate(Utf8ToWide(utf8_path), &reader, &sample_rate,
                                 &channels);
  if (FAILED(hr)) {
    result.error = "Failed to open audio file";
    return result;
  }

  if (start_sample > 0) {
    PROPVARIANT var;
    PropVariantInit(&var);
    var.vt = VT_I8;
    var.hVal.QuadPart = static_cast<LONGLONG>(
        static_cast<double>(start_sample) * 10000000.0 / sample_rate);
    hr = reader->SetCurrentPosition(GUID_NULL, var);
    PropVariantClear(&var);
    if (FAILED(hr)) {
      SafeRelease(&reader);
      result.error = "Failed to seek";
      return result;
    }
  }

  std::vector<int16_t> mono;
  mono.reserve(static_cast<size_t>(count));
  bool reached_end = false;
  bool reader_failed = false;
  bool was_cancelled = false;

  while (static_cast<int64_t>(mono.size()) < count) {
    if (is_cancelled && is_cancelled()) {
      was_cancelled = true;
      break;
    }

    DWORD stream_index = 0, flags = 0;
    LONGLONG timestamp = 0;
    IMFSample* sample = nullptr;
    hr = reader->ReadSample(
        static_cast<DWORD>(MF_SOURCE_READER_FIRST_AUDIO_STREAM), 0,
        &stream_index, &flags, &timestamp, &sample);
    if (FAILED(hr)) {
      reader_failed = true;
      break;
    }

    if (sample) {
      IMFMediaBuffer* buffer = nullptr;
      if (SUCCEEDED(sample->ConvertToContiguousBuffer(&buffer))) {
        BYTE* data = nullptr;
        DWORD length = 0;
        if (SUCCEEDED(buffer->Lock(&data, nullptr, &length))) {
          size_t frame_count =
              length / (sizeof(int16_t) * static_cast<size_t>(channels));
          AppendDownmixed(reinterpret_cast<const int16_t*>(data), frame_count,
                          channels, &mono);
          buffer->Unlock();
        }
        SafeRelease(&buffer);
      }
      SafeRelease(&sample);
    }

    if (flags & MF_SOURCE_READERF_ENDOFSTREAM) {
      reached_end = true;
      break;
    }
  }

  SafeRelease(&reader);

  if (was_cancelled) {
    result.cancelled = true;
    result.error = "Decoding cancelled";
    return result;
  }
  if (reader_failed) {
    result.error = "Decode failed while reading samples";
    return result;
  }

  if (static_cast<int64_t>(mono.size()) > count) {
    mono.resize(static_cast<size_t>(count));
  }

  result.ok = true;
  result.sample_rate = sample_rate;
  result.total_samples = static_cast<int64_t>(mono.size());
  result.reached_end = reached_end;
  result.pcm16le.resize(mono.size() * sizeof(int16_t));
  if (!mono.empty()) {
    memcpy(result.pcm16le.data(), mono.data(), result.pcm16le.size());
  }
  return result;
}
