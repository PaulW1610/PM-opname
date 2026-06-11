import Flutter
import UIKit
import AVFoundation
import MediaPlayer

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
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "VolumeButton") {
      VolumeButtonHandler.register(messenger: registrar.messenger())
    }
  }
}

/// Detecteert fysieke volumeknop-drukken en stuurt een event naar Flutter,
/// zodat de volumeknop als camerasluiter gebruikt kan worden.
///
/// Werkt door het systeemvolume (AVAudioSession.outputVolume) te observeren.
/// Een verborgen MPVolumeView onderdrukt de volume-HUD en zet het volume na
/// elke druk terug naar het midden, zodat ook herhaald drukken blijft tellen.
/// Alles is best-effort en in try/catch, zodat het de camera nooit blokkeert.
class VolumeButtonHandler: NSObject, FlutterStreamHandler {
  private var eventSink: FlutterEventSink?
  private let audioSession = AVAudioSession.sharedInstance()
  private var volumeView: MPVolumeView?
  private var observation: NSKeyValueObservation?
  private var ignoreNextChange = false

  static func register(messenger: FlutterBinaryMessenger) {
    let handler = VolumeButtonHandler()
    let channel = FlutterEventChannel(name: "blueprint/volume_button",
                                      binaryMessenger: messenger)
    channel.setStreamHandler(handler)
  }

  func onListen(withArguments arguments: Any?,
                eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    eventSink = events
    start()
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    stop()
    eventSink = nil
    return nil
  }

  private func start() {
    DispatchQueue.main.async {
      if self.volumeView == nil {
        let mpv = MPVolumeView(frame: CGRect(x: -3000, y: -3000, width: 1, height: 1))
        mpv.alpha = 0.0001
        mpv.isUserInteractionEnabled = false
        self.keyWindow()?.addSubview(mpv)
        self.volumeView = mpv
      }
      do {
        try self.audioSession.setCategory(.ambient, options: [.mixWithOthers])
        try self.audioSession.setActive(true)
      } catch {}

      // Eerste KVO-callback bevat de huidige waarde -> negeren.
      self.ignoreNextChange = true
      self.observation = self.audioSession.observe(
        \.outputVolume, options: [.new, .initial]
      ) { [weak self] _, _ in
        guard let self = self else { return }
        if self.ignoreNextChange {
          self.ignoreNextChange = false
          return
        }
        self.eventSink?(nil)
        // Terug naar het midden zodat de volgende druk weer een verandering geeft.
        self.resetVolumeToMid()
      }
      self.resetVolumeToMid()
    }
  }

  private func stop() {
    observation?.invalidate()
    observation = nil
    DispatchQueue.main.async {
      self.volumeView?.removeFromSuperview()
      self.volumeView = nil
      do {
        try self.audioSession.setActive(false, options: [.notifyOthersOnDeactivation])
      } catch {}
    }
  }

  private func resetVolumeToMid() {
    guard let slider = volumeView?.subviews
      .compactMap({ $0 as? UISlider }).first else { return }
    // Onze eigen wijziging moet de volgende KVO-callback niet als druk tellen.
    ignoreNextChange = true
    DispatchQueue.main.async {
      slider.setValue(0.5, animated: false)
      slider.sendActions(for: .valueChanged)
    }
  }

  private func keyWindow() -> UIWindow? {
    return UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }
      .first { $0.isKeyWindow }
      ?? UIApplication.shared.windows.first
  }
}
