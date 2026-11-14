import Flutter
import UIKit

/// Background upload transfer — the iOS half of `com.birdnet/upload_transfer`.
/// See lib/features/upload/upload_background.dart for the contract.
///
/// Dart builds and stages the export, then hands the PUT to a background
/// `URLSession`, which carries it out while the app is suspended or gone and
/// relaunches the app when the transfer ends. Each outcome is kept in
/// UserDefaults until Dart acknowledges it, so a transfer that finished while
/// the app was not alive still reaches the queue on the next launch.
///
/// A singleton because the system can wake the app for session events before
/// the Flutter engine exists; `attach` connects the channel once it does.
final class UploadTransferChannel: NSObject, URLSessionDataDelegate {
  static let shared = UploadTransferChannel()

  static let channelName = "com.birdnet/upload_transfer"
  static let sessionIdentifier = "de.tu-chemnitz.mi.kahst.birdnet-live.uploads"
  private static let finishedKey = "com.birdnet.upload_transfer.finished"

  private var channel: FlutterMethodChannel?
  /// Credentials for the Basic/Digest challenge of each live task, by task
  /// identifier. In memory only: a task that outlives the process answers no
  /// challenge, and its 401 makes the queue retry with the app open.
  private var credentials: [Int: URLCredential] = [:]
  /// Background time while Dart records an outcome, by transfer id.
  private var bookkeeping: [String: UIBackgroundTaskIdentifier] = [:]
  /// Background time while a Dart run is still preparing hand-offs.
  private var runTask: UIBackgroundTaskIdentifier = .invalid
  private var completionHandlers: [() -> Void] = []

  private lazy var session: URLSession = {
    let config = URLSessionConfiguration.background(withIdentifier: Self.sessionIdentifier)
    config.isDiscretionary = false
    config.sessionSendsLaunchEvents = true
    config.httpMaximumConnectionsPerHost = 1
    return URLSession(configuration: config, delegate: self, delegateQueue: .main)
  }()

  func attach(messenger: FlutterBinaryMessenger) {
    channel?.setMethodCallHandler(nil)
    let channel = FlutterMethodChannel(name: Self.channelName, binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in self?.handle(call, result) }
    self.channel = channel
  }

  /// The system's wake-up for our session (AppDelegate). Touching `session`
  /// recreates it, so the delegate receives the events that are waiting.
  func handleEvents(completionHandler: @escaping () -> Void) {
    completionHandlers.append(completionHandler)
    _ = session
  }

  private func handle(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "upload":
      guard let transferId = args["transferId"] as? String,
            let urlString = args["url"] as? String, let url = URL(string: urlString),
            let path = args["path"] as? String else {
        result(FlutterError(code: "INVALID_ARG", message: "Missing upload arguments", details: nil))
        return
      }
      var request = URLRequest(url: url)
      request.httpMethod = "PUT"
      for (key, value) in (args["headers"] as? [String: String]) ?? [:] {
        request.setValue(value, forHTTPHeaderField: key)
      }
      let wifiOnly = args["wifiOnly"] as? Bool ?? false
      request.allowsCellularAccess = !wifiOnly
      request.allowsExpensiveNetworkAccess = !wifiOnly
      let task = session.uploadTask(with: request, fromFile: URL(fileURLWithPath: path))
      task.taskDescription = transferId
      let user = args["username"] as? String ?? ""
      let secret = args["secret"] as? String ?? ""
      if !(user.isEmpty && secret.isEmpty) {
        credentials[task.taskIdentifier] = URLCredential(user: user, password: secret, persistence: .forSession)
      }
      task.resume()
      result(nil)
    case "recover":
      let finished = Self.finishedResults().map { ["transferId": $0.key, "status": $0.value] }
      session.getAllTasks { tasks in
        let running = tasks.compactMap { $0.taskDescription }
        DispatchQueue.main.async { result(["running": running, "finished": finished]) }
      }
    case "ack":
      guard let transferId = args["transferId"] as? String else {
        result(FlutterError(code: "INVALID_ARG", message: "Missing 'transferId'", details: nil))
        return
      }
      var finished = Self.finishedResults()
      finished.removeValue(forKey: transferId)
      Self.store(finished)
      endBookkeeping(transferId)
      result(nil)
    case "cancel":
      guard let transferId = args["transferId"] as? String else {
        result(FlutterError(code: "INVALID_ARG", message: "Missing 'transferId'", details: nil))
        return
      }
      session.getAllTasks { tasks in
        tasks.filter { $0.taskDescription == transferId }.forEach { $0.cancel() }
        DispatchQueue.main.async { result(nil) }
      }
    case "setRunning":
      setRunning(args["running"] as? Bool ?? false)
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: URLSessionTaskDelegate

  func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
    credentials.removeValue(forKey: task.taskIdentifier)
    guard let transferId = task.taskDescription else { return }
    // 0 means the request never got an answer (cancelled, dropped); the
    // queue treats it like any network failure and retries.
    let status = error == nil ? ((task.response as? HTTPURLResponse)?.statusCode ?? 0) : 0
    var finished = Self.finishedResults()
    finished[transferId] = status
    Self.store(finished)
    guard let channel = channel else { return }
    beginBookkeeping(transferId)
    channel.invokeMethod("onFinished", arguments: ["transferId": transferId, "status": status])
  }

  func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
    let handlers = completionHandlers
    completionHandlers = []
    handlers.forEach { $0() }
  }

  /// Answers one Basic or Digest challenge with the task's credential. The
  /// request already carries Dart's preemptive header; this covers a Digest
  /// server that was never challenged in Dart and a nonce that went stale.
  func urlSession(
    _ session: URLSession,
    task: URLSessionTask,
    didReceive challenge: URLAuthenticationChallenge,
    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
  ) {
    let method = challenge.protectionSpace.authenticationMethod
    guard method == NSURLAuthenticationMethodHTTPBasic || method == NSURLAuthenticationMethodHTTPDigest,
          challenge.previousFailureCount == 0,
          let credential = credentials[task.taskIdentifier] else {
      completionHandler(.performDefaultHandling, nil)
      return
    }
    completionHandler(.useCredential, credential)
  }

  /// Follows one redirect with the same method and headers, as the Dart
  /// client does; URLSession on its own would turn a 301/302 PUT into a GET.
  func urlSession(
    _ session: URLSession,
    task: URLSessionTask,
    willPerformHTTPRedirection response: HTTPURLResponse,
    newRequest request: URLRequest,
    completionHandler: @escaping (URLRequest?) -> Void
  ) {
    guard let original = task.originalRequest, task.currentRequest?.url == original.url,
          let url = request.url else {
      completionHandler(nil)
      return
    }
    var next = URLRequest(url: url)
    next.httpMethod = original.httpMethod
    next.allHTTPHeaderFields = original.allHTTPHeaderFields
    next.allowsCellularAccess = original.allowsCellularAccess
    next.allowsExpensiveNetworkAccess = original.allowsExpensiveNetworkAccess
    completionHandler(next)
  }

  // MARK: Background time

  private func setRunning(_ running: Bool) {
    if runTask != .invalid {
      UIApplication.shared.endBackgroundTask(runTask)
      runTask = .invalid
    }
    guard running else { return }
    runTask = UIApplication.shared.beginBackgroundTask(withName: "upload-run") { [weak self] in
      guard let self = self, self.runTask != .invalid else { return }
      UIApplication.shared.endBackgroundTask(self.runTask)
      self.runTask = .invalid
    }
  }

  private func beginBookkeeping(_ transferId: String) {
    endBookkeeping(transferId)
    bookkeeping[transferId] = UIApplication.shared.beginBackgroundTask(withName: "upload-bookkeeping") {
      [weak self] in self?.endBookkeeping(transferId)
    }
  }

  private func endBookkeeping(_ transferId: String) {
    guard let id = bookkeeping.removeValue(forKey: transferId) else { return }
    UIApplication.shared.endBackgroundTask(id)
  }

  // MARK: Ledger

  private static func finishedResults() -> [String: Int] {
    UserDefaults.standard.dictionary(forKey: finishedKey) as? [String: Int] ?? [:]
  }

  private static func store(_ finished: [String: Int]) {
    if finished.isEmpty {
      UserDefaults.standard.removeObject(forKey: finishedKey)
    } else {
      UserDefaults.standard.set(finished, forKey: finishedKey)
    }
  }
}
