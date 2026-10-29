import Flutter
import Foundation
import Security

/// Keychain key-value store — the iOS half of the `com.birdnet/secure_store`
/// channel. See lib/features/upload/secret_store.dart for the contract,
/// SecureStoreChannel.kt and secure_store_channel.cpp for the Android and
/// Windows halves.
///
/// Each value is a generic-password item under one service name, keyed by
/// account. Items are readable after the first unlock so a future background
/// upload can reach them, and stay on this device only (no iCloud Keychain).
final class SecureStoreChannel {
  private let channel: FlutterMethodChannel
  private let service = "com.birdnet.birdnet_live.secure_store"

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "com.birdnet/secure_store", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result)
    }
  }

  private func handle(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
      let key = args["key"] as? String, !key.isEmpty
    else {
      result(FlutterError(code: "bad_args", message: "key is required", details: nil))
      return
    }
    switch call.method {
    case "read":
      var query = baseQuery(key)
      query[kSecReturnData as String] = true
      query[kSecMatchLimit as String] = kSecMatchLimitOne
      var item: CFTypeRef?
      let status = SecItemCopyMatching(query as CFDictionary, &item)
      if status == errSecItemNotFound {
        result(nil)
        return
      }
      guard status == errSecSuccess, let data = item as? Data else {
        result(error(status))
        return
      }
      result(String(data: data, encoding: .utf8))
    case "write":
      guard let value = args["value"] as? String, let data = value.data(using: .utf8) else {
        result(FlutterError(code: "bad_args", message: "value is required", details: nil))
        return
      }
      let query = baseQuery(key)
      var status = SecItemUpdate(
        query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
      if status == errSecItemNotFound {
        var add = query
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        status = SecItemAdd(add as CFDictionary, nil)
      }
      result(status == errSecSuccess ? nil : error(status))
    case "delete":
      let status = SecItemDelete(baseQuery(key) as CFDictionary)
      result(status == errSecSuccess || status == errSecItemNotFound ? nil : error(status))
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func baseQuery(_ key: String) -> [String: Any] {
    [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: key,
    ]
  }

  private func error(_ status: OSStatus) -> FlutterError {
    let message = SecCopyErrorMessageString(status, nil) as String? ?? "OSStatus \(status)"
    return FlutterError(code: "secure_store", message: message, details: nil)
  }
}
