import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // Audio decoder channel — decode compressed audio to PCM via AVFoundation.
    let controller = window?.rootViewController as! FlutterViewController
    let audioChannel = FlutterMethodChannel(
      name: "com.birdnet/audio_decoder",
      binaryMessenger: controller.binaryMessenger
    )
    audioChannel.setMethodCallHandler { (call, result) in
      guard call.method == "decode" else {
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
          let decoded = try NativeAudioDecoder.decode(path: path)
          DispatchQueue.main.async {
            result(decoded)
          }
        } catch {
          DispatchQueue.main.async {
            result(FlutterError(code: "DECODE_ERROR", message: error.localizedDescription, details: nil))
          }
        }
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
