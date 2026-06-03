import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    let controller = window?.rootViewController as! FlutterViewController

    let wakelockChannel = FlutterMethodChannel(
      name: "com.birdnet/wakelock",
      binaryMessenger: controller.binaryMessenger
    )
    wakelockChannel.setMethodCallHandler { (call, result) in
      switch call.method {
      case "enable":
        UIApplication.shared.isIdleTimerDisabled = true
        result(nil)
      case "disable":
        UIApplication.shared.isIdleTimerDisabled = false
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    // Audio decoder channel — decode compressed audio to PCM via AVFoundation.
    let audioChannel = FlutterMethodChannel(
      name: "com.birdnet/audio_decoder",
      binaryMessenger: controller.binaryMessenger
    )
    audioChannel.setMethodCallHandler { (call, result) in
      guard call.method == "decode" || call.method == "inspect" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let args = call.arguments as? [String: Any],
            let path = args["path"] as? String else {
        result(FlutterError(code: "INVALID_ARG", message: "Missing 'path' argument", details: nil))
        return
      }
      DispatchQueue.global(qos: .userInitiated).async {
        do {
          let decoded = call.method == "inspect"
            ? try NativeAudioDecoder.inspect(path: path)
            : try NativeAudioDecoder.decode(path: path)
          DispatchQueue.main.async {
            result(decoded)
          }
        } catch {
          DispatchQueue.main.async {
            let code = call.method == "inspect" ? "INSPECT_ERROR" : "DECODE_ERROR"
            result(FlutterError(code: code, message: error.localizedDescription, details: nil))
          }
        }
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
