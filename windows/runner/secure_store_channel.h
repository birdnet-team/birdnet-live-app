#ifndef RUNNER_SECURE_STORE_CHANNEL_H_
#define RUNNER_SECURE_STORE_CHANNEL_H_

#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>

#include <memory>

// Keychain-style key-value store — the Windows half of the
// `com.birdnet/secure_store` channel. See lib/features/upload/secret_store.dart
// for the contract, SecureStoreChannel.kt and SecureStoreChannel.swift for the
// Android and iOS halves.
//
// Values live in the Windows Credential Manager as generic credentials named
// "BirdNET Live/<key>", encrypted by the OS for the current user. Every call
// is a synchronous Win32 API call and completes on the platform thread.
class SecureStoreChannel {
 public:
  explicit SecureStoreChannel(flutter::BinaryMessenger* messenger);
  ~SecureStoreChannel();

  SecureStoreChannel(const SecureStoreChannel&) = delete;
  SecureStoreChannel& operator=(const SecureStoreChannel&) = delete;

 private:
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
};

#endif  // RUNNER_SECURE_STORE_CHANNEL_H_
