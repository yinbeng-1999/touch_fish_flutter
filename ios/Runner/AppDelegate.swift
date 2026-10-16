import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "TouchFishSocialPlugin")
    let socialChannel = FlutterMethodChannel(
      name: "touch_fish_flutter/social",
      binaryMessenger: registrar.messenger()
    )
    socialChannel.setMethodCallHandler { call, result in
      guard call.method == "openSocialApp",
            let arguments = call.arguments as? [String: Any],
            let urlString = arguments["url"] as? String,
            let url = URL(string: urlString) else {
        result(FlutterMethodNotImplemented)
        return
      }

      DispatchQueue.main.async {
        UIApplication.shared.open(url, options: [:]) { opened in
          result(opened)
        }
      }
    }
  }
}
