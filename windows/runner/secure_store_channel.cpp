#include "secure_store_channel.h"

#include <windows.h>
#include <wincred.h>

#include <flutter/standard_method_codec.h>

#include <string>
#include <vector>

namespace {

constexpr wchar_t kTargetPrefix[] = L"BirdNET Live/";
constexpr wchar_t kUserName[] = L"BirdNET Live";

std::wstring Utf16FromUtf8(const std::string& utf8) {
  if (utf8.empty()) return std::wstring();
  const int length = MultiByteToWideChar(CP_UTF8, 0, utf8.data(),
                                         static_cast<int>(utf8.size()),
                                         nullptr, 0);
  std::wstring out(static_cast<size_t>(length), L'\0');
  MultiByteToWideChar(CP_UTF8, 0, utf8.data(), static_cast<int>(utf8.size()),
                      out.data(), length);
  return out;
}

std::wstring TargetName(const std::string& key) {
  return kTargetPrefix + Utf16FromUtf8(key);
}

const std::string* GetStringArg(const flutter::EncodableValue* args,
                                const char* name) {
  const auto* map = std::get_if<flutter::EncodableMap>(args);
  if (!map) return nullptr;
  const auto it = map->find(flutter::EncodableValue(name));
  if (it == map->end()) return nullptr;
  return std::get_if<std::string>(&it->second);
}

std::string Win32Message(const char* api) {
  return std::string(api) + " failed: " + std::to_string(GetLastError());
}

}  // namespace

SecureStoreChannel::SecureStoreChannel(flutter::BinaryMessenger* messenger)
    : channel_(
          std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
              messenger, "com.birdnet/secure_store",
              &flutter::StandardMethodCodec::GetInstance())) {
  channel_->SetMethodCallHandler([this](const auto& call, auto result) {
    HandleMethodCall(call, std::move(result));
  });
}

SecureStoreChannel::~SecureStoreChannel() {
  channel_->SetMethodCallHandler(nullptr);
}

void SecureStoreChannel::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const std::string* key = GetStringArg(call.arguments(), "key");
  if (!key || key->empty()) {
    result->Error("bad_args", "key is required");
    return;
  }
  const std::wstring target = TargetName(*key);
  const std::string& method = call.method_name();

  if (method == "read") {
    PCREDENTIALW credential = nullptr;
    if (!CredReadW(target.c_str(), CRED_TYPE_GENERIC, 0, &credential)) {
      if (GetLastError() == ERROR_NOT_FOUND) {
        result->Success();
      } else {
        result->Error("secure_store", Win32Message("CredRead"));
      }
      return;
    }
    std::string value(
        reinterpret_cast<const char*>(credential->CredentialBlob),
        credential->CredentialBlobSize);
    CredFree(credential);
    result->Success(flutter::EncodableValue(value));
    return;
  }

  if (method == "write") {
    const std::string* value = GetStringArg(call.arguments(), "value");
    if (!value) {
      result->Error("bad_args", "value is required");
      return;
    }
    if (value->size() > CRED_MAX_CREDENTIAL_BLOB_SIZE) {
      result->Error("secure_store", "value too large for Credential Manager");
      return;
    }
    std::vector<BYTE> blob(value->begin(), value->end());
    CREDENTIALW credential = {};
    credential.Type = CRED_TYPE_GENERIC;
    credential.TargetName = const_cast<LPWSTR>(target.c_str());
    credential.CredentialBlobSize = static_cast<DWORD>(blob.size());
    credential.CredentialBlob = blob.empty() ? nullptr : blob.data();
    credential.Persist = CRED_PERSIST_LOCAL_MACHINE;
    credential.UserName = const_cast<LPWSTR>(kUserName);
    if (!CredWriteW(&credential, 0)) {
      result->Error("secure_store", Win32Message("CredWrite"));
      return;
    }
    result->Success();
    return;
  }

  if (method == "delete") {
    if (!CredDeleteW(target.c_str(), CRED_TYPE_GENERIC, 0) &&
        GetLastError() != ERROR_NOT_FOUND) {
      result->Error("secure_store", Win32Message("CredDelete"));
      return;
    }
    result->Success();
    return;
  }

  result->NotImplemented();
}
