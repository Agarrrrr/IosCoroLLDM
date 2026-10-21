import Flutter
import UIKit
import AVFoundation
import AudioToolbox
import MediaPlayer
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var audioRouteObserver: NSObjectProtocol?
  private var fileExport: FileExportCoordinator?
  private var mediaSessionCoordinator: MediaSessionCoordinator?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Configurar AVAudioSession como Playback para que el audio suene
    // incluso con el interruptor físico de silencio activado.
    do {
      try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
      try AVAudioSession.sharedInstance().setActive(true)
    } catch {
      print("Error configurando AVAudioSession: \(error)")
    }

    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    }

    GeneratedPluginRegistrant.register(with: self)

    if let controller = window?.rootViewController as? FlutterViewController {
      let fileExport = FileExportCoordinator(root: controller)
      self.fileExport = fileExport
      let exportChannel = FlutterMethodChannel(
        name: "com.lldm.coro/file_export",
        binaryMessenger: controller.binaryMessenger
      )
      exportChannel.setMethodCallHandler { [weak fileExport] call, result in
        guard let fileExport = fileExport else {
          result(FlutterError(code: "UNAVAILABLE", message: "Export unavailable", details: nil))
          return
        }
        fileExport.handle(call, result: result)
      }
      let audioRouteChannel = FlutterMethodChannel(
        name: "com.lldm.coro/audio_route",
        binaryMessenger: controller.binaryMessenger
      )
      audioRouteObserver = NotificationCenter.default.addObserver(
        forName: AVAudioSession.routeChangeNotification,
        object: AVAudioSession.sharedInstance(),
        queue: .main
      ) { _ in
        let outputs = AVAudioSession.sharedInstance().currentRoute.outputs.map {
          ["name": $0.portName, "type": $0.portType.rawValue]
        }
        audioRouteChannel.invokeMethod("routeChanged", arguments: ["outputs": outputs])
      }

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

      let cloudSyncChannel = FlutterMethodChannel(
        name: "com.lldm.coro/cloud_sync",
        binaryMessenger: controller.binaryMessenger
      )
      cloudSyncChannel.setMethodCallHandler { call, result in
        switch call.method {
        case "getCloudUserId":
          result(KeychainCloudHelper.getUserId())
        case "saveCloudUserId":
          guard let args = call.arguments as? [String: Any],
                let userId = args["userId"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "Falta userId", details: nil))
            return
          }
          KeychainCloudHelper.saveUserId(userId)
          result(true)
        default:
          result(FlutterMethodNotImplemented)
        }
      }

      let mediaSessionChannel = FlutterMethodChannel(
        name: "com.lldm.coro/media_session",
        binaryMessenger: controller.binaryMessenger
      )
      let coordinator = MediaSessionCoordinator(channel: mediaSessionChannel)
      self.mediaSessionCoordinator = coordinator
      mediaSessionChannel.setMethodCallHandler { [weak coordinator] call, result in
        coordinator?.handle(call, result: result)
      }

      let midiRenderChannel = FlutterMethodChannel(
        name: "com.lldm.coro/midi_render",
        binaryMessenger: controller.binaryMessenger
      )
      midiRenderChannel.setMethodCallHandler { [weak self] call, result in
        guard call.method == "renderMidiToWav" else {
          result(FlutterMethodNotImplemented)
          return
        }
        guard let args = call.arguments as? [String: Any],
              let midiPath = args["midiPath"] as? String,
              let soundfontPath = args["soundfontPath"] as? String,
              let outputPath = args["outputPath"] as? String,
              let durationSeconds = args["durationSeconds"] as? Double,
              durationSeconds.isFinite,
              durationSeconds > 0 else {
          result(FlutterError(code: "INVALID_ARGS", message: "Argumentos inválidos", details: nil))
          return
        }
        self?.renderMidiToWav(
          midiPath: midiPath,
          soundfontPath: soundfontPath,
          outputPath: outputPath,
          durationSeconds: durationSeconds
        ) { success, errorMsg in
          DispatchQueue.main.async {
            if success {
              result(true)
            } else {
              result(FlutterError(code: "RENDER_ERROR", message: errorMsg ?? "Error al renderizar audio", details: nil))
            }
          }
        }
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  deinit {
    if let observer = audioRouteObserver {
      NotificationCenter.default.removeObserver(observer)
    }
  }

  private func renderMidiToWav(
    midiPath: String,
    soundfontPath: String,
    outputPath: String,
    durationSeconds: Double,
    completion: @escaping (Bool, String?) -> Void
  ) {
    DispatchQueue.global(qos: .userInitiated).async {
      do {
        let midiURL = URL(fileURLWithPath: midiPath)
        let sfURL = URL(fileURLWithPath: soundfontPath)
        let outURL = URL(fileURLWithPath: outputPath)

        let engine = AVAudioEngine()
        let sampler = AVAudioUnitSampler()
        engine.attach(sampler)
        engine.connect(sampler, to: engine.mainMixerNode, format: nil)

        try sampler.loadInstrument(at: sfURL)
        // AVAudioUnitSampler expresa la ganancia maestra en decibelios.
        // Coincide con el reproductor y eleva la exportación 5 dB adicionales.
        sampler.masterGain = 15.0

        let sequencer = AVAudioSequencer(audioEngine: engine)
        try sequencer.load(from: midiURL, options: [])

        for track in sequencer.tracks {
          track.destinationAudioUnit = sampler
        }

        let sampleRate: Double = 44100.0
        guard let engineFormat = AVAudioFormat(
          standardFormatWithSampleRate: sampleRate,
          channels: 2
        ), let fileFormat = AVAudioFormat(
          commonFormat: .pcmFormatInt16,
          sampleRate: sampleRate,
          channels: 2,
          interleaved: true
        ) else {
          throw NSError(
            domain: "com.lldm.coro.midi_render",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "No se pudieron crear los formatos de audio"]
          )
        }

        try engine.enableManualRenderingMode(.offline, format: engineFormat, maximumFrameCount: 4096)
        try engine.start()
        try sequencer.start()

        // El motor exige su formato canónico Float32 no intercalado. El archivo
        // conserva ese formato de procesamiento y AVAudioFile convierte a PCM16
        // intercalado al escribir el WAV.
        let outputFile = try AVAudioFile(
          forWriting: outURL,
          settings: fileFormat.settings,
          commonFormat: .pcmFormatFloat32,
          interleaved: false
        )
        guard let buffer = AVAudioPCMBuffer(
          pcmFormat: engine.manualRenderingFormat,
          frameCapacity: 4096
        ) else {
          throw NSError(
            domain: "com.lldm.coro.midi_render",
            code: -2,
            userInfo: [NSLocalizedDescriptionKey: "No se pudo crear el buffer de renderizado"]
          )
        }

        // NativeMidiParser calcula la duración del MIDI respetando sus cambios
        // de tempo. Añadimos una cola breve para la liberación y reverberación
        // del sampler, manteniendo 20 minutos solo como límite de seguridad.
        let tailSeconds = 2.0
        let renderDuration = min(durationSeconds + tailSeconds, 1200.0)
        let maxFrames = AVAudioFramePosition(ceil(renderDuration * sampleRate))

        while engine.manualRenderingSampleTime < maxFrames {
          let remaining = maxFrames - engine.manualRenderingSampleTime
          let framesToRender = min(AVAudioFrameCount(4096), AVAudioFrameCount(remaining))
          let status = try engine.renderOffline(framesToRender, to: buffer)
          guard status == .success else { break }
          try outputFile.write(from: buffer)
        }

        sequencer.stop()
        engine.stop()
        completion(true, nil)
      } catch {
        completion(false, error.localizedDescription)
      }
    }
  }
}

enum KeychainCloudHelper {
  private static let service = "com.lldm.coro.user_identity"
  private static let account = "persistent_user_id"
  private static let kvKey = "coro_cloud_user_id"

  static func getUserId() -> String? {
    // 1. Intentar leer desde Keychain sincronizable con iCloud
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
      kSecReturnData as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne,
      kSecAttrSynchronizable as String: kCFBooleanTrue!
    ]

    var dataTypeRef: AnyObject?
    let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
    if status == errSecSuccess, let data = dataTypeRef as? Data, let id = String(data: data, encoding: .utf8), !id.isEmpty {
      return id
    }

    // 2. Intentar leer desde NSUbiquitousKeyValueStore si está disponible
    let kvStore = NSUbiquitousKeyValueStore.default
    if let kvId = kvStore.string(forKey: kvKey), !kvId.isEmpty {
      return kvId
    }

    return nil
  }

  static func saveUserId(_ userId: String) {
    guard let data = userId.data(using: .utf8) else { return }

    // Limpiar entrada anterior si existiera
    let deleteQuery: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
      kSecAttrSynchronizable as String: kCFBooleanTrue!
    ]
    SecItemDelete(deleteQuery as CFDictionary)

    // Guardar nuevo ID sincronizable en iCloud Keychain
    let addQuery: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
      kSecValueData as String: data,
      kSecAttrSynchronizable as String: kCFBooleanTrue!
    ]
    SecItemAdd(addQuery as CFDictionary, nil)

    // Sincronizar también con NSUbiquitousKeyValueStore como respaldo secundario
    let kvStore = NSUbiquitousKeyValueStore.default
    kvStore.set(userId, forKey: kvKey)
    kvStore.synchronize()
  }
}


// One native presentation at a time, with real file URLs and explicit dismissal.
private final class FileExportCoordinator: NSObject, UIDocumentPickerDelegate, UIAdaptivePresentationControllerDelegate {
  private weak var root: UIViewController?
  private var pending: FlutterResult?
  private var completionValue: Any?
  private weak var activeController: UIViewController?

  init(root: UIViewController) {
    self.root = root
    super.init()
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "shareFiles" || call.method == "saveFiles" else {
      result(FlutterMethodNotImplemented)
      return
    }
    guard pending == nil else {
      result(FlutterError(code: "BUSY", message: "An export is already open", details: nil))
      return
    }
    guard let args = call.arguments as? [String: Any] else {
      result(FlutterError(code: "INVALID_ARGS", message: "Missing files", details: nil))
      return
    }
    let paths: [String]
    if call.method == "saveFiles" {
      paths = (args["files"] as? [[String: Any]])?.compactMap { $0["path"] as? String } ?? []
    } else {
      paths = args["paths"] as? [String] ?? []
    }
    let urls = paths.map { URL(fileURLWithPath: $0) }
    guard !urls.isEmpty, urls.allSatisfy({ url in
      guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]) else { return false }
      return values.isRegularFile == true && (values.fileSize ?? 0) > 0
    }) else {
      result(FlutterError(code: "MISSING_FILE", message: "Export file is missing or empty", details: nil))
      return
    }
    pending = result
    presentWhenReady(urls: urls, save: call.method == "saveFiles", args: args, attempts: 0)
  }

  private func presentWhenReady(urls: [URL], save: Bool, args: [String: Any], attempts: Int) {
    guard let root = root, root.view.window != nil else {
      finish(FlutterError(code: "UNAVAILABLE", message: "Export screen is unavailable", details: nil))
      return
    }
    var presenter = root
    while let next = presenter.presentedViewController, !next.isBeingDismissed { presenter = next }
    if presenter.isBeingDismissed || presenter.isBeingPresented || presenter.presentedViewController != nil {
      guard attempts < 40 else {
        finish(FlutterError(code: "PRESENTATION_BUSY", message: "Another window is still open", details: nil))
        return
      }
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
        self?.presentWhenReady(urls: urls, save: save, args: args, attempts: attempts + 1)
      }
      return
    }
    let controller: UIViewController
    if save {
      let picker = UIDocumentPickerViewController(forExporting: urls, asCopy: true)
      picker.delegate = self
      controller = picker
    } else {
      let activity = UIActivityViewController(activityItems: urls, applicationActivities: nil)
      if let subject = args["subject"] as? String { activity.setValue(subject, forKey: "subject") }
      activity.completionWithItemsHandler = { [weak self, weak activity] _, completed, _, error in
        DispatchQueue.main.async {
          guard let self = self else { return }
          let value: Any
          if let error = error {
            value = FlutterError(code: "SHARE_FAILED", message: error.localizedDescription, details: nil)
          } else {
            value = completed
          }
          self.finishAfterDismissal(activity, value: value)
        }
      }
      // Only iPad needs an anchor. An iPhone sourceView can interfere with iOS 26 dismissal.
      if UIDevice.current.userInterfaceIdiom == .pad, let popover = activity.popoverPresentationController {
        popover.sourceView = presenter.view
        let candidate = CGRect(x: (args["x"] as? NSNumber)?.doubleValue ?? 0,
                               y: (args["y"] as? NSNumber)?.doubleValue ?? 0,
                               width: (args["width"] as? NSNumber)?.doubleValue ?? 0,
                               height: (args["height"] as? NSNumber)?.doubleValue ?? 0)
        let converted = presenter.view.convert(candidate, from: root.view)
        let clipped = converted.intersection(presenter.view.bounds)
        popover.sourceRect = clipped.isNull || clipped.isEmpty
          ? CGRect(x: presenter.view.bounds.midX, y: presenter.view.bounds.midY, width: 1, height: 1) : clipped
      }
      controller = activity
    }
    activeController = controller
    presenter.present(controller, animated: true) {
      controller.presentationController?.delegate = self
    }
  }

  private func finishAfterDismissal(_ controller: UIViewController?, value: Any) {
    guard pending != nil else { return }
    completionValue = value
    guard let controller = controller, controller.presentingViewController != nil else {
      finish(value)
      return
    }
    if controller.isBeingDismissed, let transition = controller.transitionCoordinator {
      transition.animate(alongsideTransition: nil) { [weak self] _ in self?.finish(value) }
    } else {
      controller.dismiss(animated: true) { [weak self] in self?.finish(value) }
    }
  }

  private func finish(_ value: Any) {
    let callback = pending
    pending = nil
    completionValue = nil
    activeController = nil
    callback?(value)
  }

  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    finishAfterDismissal(controller, value: !urls.isEmpty)
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    finishAfterDismissal(controller, value: false)
  }

  func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
    if presentationController.presentedViewController === activeController { finish(completionValue ?? false) }
  }
}

private final class MediaSessionCoordinator {
  private let channel: FlutterMethodChannel
  private var commandsConfigured = false
  private var transitionTask: UIBackgroundTaskIdentifier = .invalid
  private var transitionTimer: Timer?
  private var currentMetadata: [String: Any] = [:]
  private lazy var cachedArtwork: MPMediaItemArtwork? = {
    if let img = UIImage(named: "AppIcon") ?? UIImage(named: "LaunchImage") {
      return MPMediaItemArtwork(boundsSize: img.size) { _ in img }
    }
    return nil
  }()

  init(channel: FlutterMethodChannel) {
    self.channel = channel
  }

  private func ensureRemoteCommands() {
    guard !commandsConfigured else { return }
    commandsConfigured = true

    let center = MPRemoteCommandCenter.shared()
    center.playCommand.isEnabled = true
    center.playCommand.addTarget { [weak self] _ in
      DispatchQueue.main.async {
        self?.channel.invokeMethod("play", arguments: nil)
      }
      return .success
    }

    center.pauseCommand.isEnabled = true
    center.pauseCommand.addTarget { [weak self] _ in
      DispatchQueue.main.async {
        self?.channel.invokeMethod("pause", arguments: nil)
      }
      return .success
    }

    center.togglePlayPauseCommand.isEnabled = true
    center.togglePlayPauseCommand.addTarget { [weak self] _ in
      DispatchQueue.main.async {
        self?.channel.invokeMethod("togglePlayPause", arguments: nil)
      }
      return .success
    }

    center.nextTrackCommand.isEnabled = true
    center.nextTrackCommand.addTarget { [weak self] _ in
      DispatchQueue.main.async {
        self?.channel.invokeMethod("next", arguments: nil)
      }
      return .success
    }

    center.previousTrackCommand.isEnabled = true
    center.previousTrackCommand.addTarget { [weak self] _ in
      DispatchQueue.main.async {
        self?.channel.invokeMethod("previous", arguments: nil)
      }
      return .success
    }

    center.changePlaybackPositionCommand.isEnabled = true
    center.changePlaybackPositionCommand.addTarget { [weak self] event in
      guard let posEvent = event as? MPChangePlaybackPositionCommandEvent else {
        return .commandFailed
      }
      let ms = Int(posEvent.positionTime * 1000.0)
      DispatchQueue.main.async {
        self?.channel.invokeMethod("seek", arguments: ["positionMs": ms])
      }
      return .success
    }
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "updateMetadata":
      ensureRemoteCommands()
      guard let args = call.arguments as? [String: Any] else {
        result(nil)
        return
      }
      try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
      try? AVAudioSession.sharedInstance().setActive(true)
      UIApplication.shared.beginReceivingRemoteControlEvents()

      let title = args["title"] as? String ?? "Coro LLDM"
      let artist = args["artist"] as? String ?? "Coro LLDM"
      let album = args["album"] as? String ?? "Coro LLDM"
      let durationMs = (args["durationMs"] as? NSNumber)?.doubleValue ?? 0
      let positionMs = (args["positionMs"] as? NSNumber)?.doubleValue ?? 0
      let isPlaying = (args["isPlaying"] as? Bool) ?? false
      let canSkipNext = (args["canSkipNext"] as? Bool) ?? true
      let canSkipPrevious = (args["canSkipPrevious"] as? Bool) ?? true
      let canSeek = (args["canSeek"] as? Bool) ?? true

      let center = MPRemoteCommandCenter.shared()
      center.nextTrackCommand.isEnabled = canSkipNext
      center.previousTrackCommand.isEnabled = canSkipPrevious
      center.changePlaybackPositionCommand.isEnabled = canSeek

      var info: [String: Any] = [
        MPMediaItemPropertyTitle: title,
        MPMediaItemPropertyArtist: artist,
        MPMediaItemPropertyAlbumTitle: album,
        MPMediaItemPropertyPlaybackDuration: max(0.0, durationMs / 1000.0),
        MPNowPlayingInfoPropertyElapsedPlaybackTime: max(0.0, positionMs / 1000.0),
        MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
        MPNowPlayingInfoPropertyDefaultPlaybackRate: 1.0,
      ]
      if let artworkPath = args["artworkPath"] as? String,
         !artworkPath.isEmpty,
         let img = UIImage(contentsOfFile: artworkPath) {
        info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: img.size) { _ in img }
      } else if let artwork = cachedArtwork {
        info[MPMediaItemPropertyArtwork] = artwork
      }
      currentMetadata = info
      MPNowPlayingInfoCenter.default().nowPlayingInfo = info
      result(nil)

    case "updatePlaybackState":
      ensureRemoteCommands()
      guard let args = call.arguments as? [String: Any] else {
        result(nil)
        return
      }
      let durationMs = (args["durationMs"] as? NSNumber)?.doubleValue ?? 0
      let positionMs = (args["positionMs"] as? NSNumber)?.doubleValue ?? 0
      let isPlaying = (args["isPlaying"] as? Bool) ?? false
      let canSkipNext = (args["canSkipNext"] as? Bool) ?? true
      let canSkipPrevious = (args["canSkipPrevious"] as? Bool) ?? true
      let canSeek = (args["canSeek"] as? Bool) ?? true

      let center = MPRemoteCommandCenter.shared()
      center.nextTrackCommand.isEnabled = canSkipNext
      center.previousTrackCommand.isEnabled = canSkipPrevious
      center.changePlaybackPositionCommand.isEnabled = canSeek

      var info = currentMetadata
      if durationMs > 0 {
        info[MPMediaItemPropertyPlaybackDuration] = durationMs / 1000.0
      }
      info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = max(0.0, positionMs / 1000.0)
      info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
      currentMetadata = info
      MPNowPlayingInfoCenter.default().nowPlayingInfo = info
      result(nil)

    case "beginTrackTransition":
      beginTransitionTask()
      try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
      try? AVAudioSession.sharedInstance().setActive(true)
      result(nil)

    case "endTrackTransition":
      endTransitionTask()
      result(nil)

    case "stopSession":
      endTransitionTask()
      currentMetadata.removeAll()
      MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
      result(nil)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func beginTransitionTask() {
    endTransitionTask()
    transitionTask = UIApplication.shared.beginBackgroundTask(withName: "CoroLLDMTrackTransition") { [weak self] in
      self?.endTransitionTask()
    }
    transitionTimer = Timer.scheduledTimer(withTimeInterval: 20.0, repeats: false) { [weak self] _ in
      self?.endTransitionTask()
    }
  }

  private func endTransitionTask() {
    transitionTimer?.invalidate()
    transitionTimer = nil
    if transitionTask != .invalid {
      UIApplication.shared.endBackgroundTask(transitionTask)
      transitionTask = .invalid
    }
  }
}
