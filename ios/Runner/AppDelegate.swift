import Flutter
import UIKit
import AVFoundation
import AudioToolbox
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
