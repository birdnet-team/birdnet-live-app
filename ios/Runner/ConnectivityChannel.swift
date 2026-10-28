import Flutter
import Foundation
import Network

/// Network type snapshot — the iOS half of the `com.birdnet/connectivity`
/// channel. See lib/features/upload/connectivity.dart for the contract and
/// ConnectivityChannel.kt for the Android half.
///
/// A path monitor runs from the first call on; `getType` answers from its
/// latest path with `wifi`, `ethernet`, `cellular`, `none`, or `unknown`.
final class ConnectivityChannel {
  private let channel: FlutterMethodChannel
  private var monitor: NWPathMonitor?
  private let queue = DispatchQueue(label: "com.birdnet.connectivity")
  private var latest: NWPath?
  private let lock = NSLock()

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "com.birdnet/connectivity", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result)
    }
  }

  private func handle(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    guard call.method == "getType" else {
      result(FlutterMethodNotImplemented)
      return
    }
    startMonitorIfNeeded()
    lock.lock()
    let path = latest
    lock.unlock()
    guard let path = path else {
      result("unknown")
      return
    }
    result(Self.describe(path))
  }

  private func startMonitorIfNeeded() {
    if monitor != nil { return }
    let monitor = NWPathMonitor()
    // The first update arrives asynchronously; take the current path right
    // away so the very first answer is not "unknown" forever.
    lock.lock()
    latest = monitor.currentPath
    lock.unlock()
    monitor.pathUpdateHandler = { [weak self] path in
      guard let self = self else { return }
      self.lock.lock()
      self.latest = path
      self.lock.unlock()
    }
    monitor.start(queue: queue)
    self.monitor = monitor
  }

  private static func describe(_ path: NWPath) -> String {
    if path.status != .satisfied { return "none" }
    if path.usesInterfaceType(.wifi) { return "wifi" }
    if path.usesInterfaceType(.wiredEthernet) { return "ethernet" }
    if path.usesInterfaceType(.cellular) { return "cellular" }
    return path.isExpensive ? "cellular" : "unknown"
  }
}
