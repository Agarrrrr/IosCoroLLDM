import Flutter
import UIKit
import AVFoundation
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Configurar AVAudioSession como Playback para que el audio suene
    // incluso con el interruptor físico de silencio activado.
    do {
      try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
      try AVAudioSession.sharedInstance().setActive(true)
    } catch {
      print("Error configurando AVAudioSession: \(error)")
    }

    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    }

    GeneratedPluginRegistrant.register(with: self)

    if let controller = window?.rootViewController as? FlutterViewController {
      let appInfoChannel = FlutterMethodChannel(
        name: "com.lldm.coro/app_info",
        binaryMessenger: controller.binaryMessenger
      )
      appInfoChannel.setMethodCallHandler { call, result in
        guard call.method == "isSandboxReceipt" else {
          result(FlutterMethodNotImplemented)
          return
        }
        let receiptName = Bundle.main.appStoreReceiptURL?.lastPathComponent
        result(receiptName == "sandboxReceipt")
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
