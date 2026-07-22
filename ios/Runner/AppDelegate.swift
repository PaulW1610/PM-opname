import Flutter
import UIKit
import AVFoundation
import AVKit
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
/// Voorkeursroute (iOS 17.2 en nieuwer): `AVCaptureEventInteraction` — de
/// officiële Apple-API waarmee camera-apps de volumeknoppen als sluiter
/// krijgen. iOS levert de druk dan rechtstreeks af en verandert het volume
/// niet; er is geen truc met een verborgen volumeregelaar nodig.
///
/// Terugval (oudere iOS): het systeemvolume (AVAudioSession.outputVolume)
/// observeren, met een verborgen MPVolumeView die de volume-HUD onderdrukt en
/// het volume na elke druk terugzet naar het midden. Die route faalt op
/// moderne iOS zodra het volume al op maximaal (of minimaal) staat — dan
/// verandert er niets meer en komt er dus ook geen druk binnen.
///
/// Alles is best-effort en in try/catch, zodat het de camera nooit blokkeert.
class VolumeButtonHandler: NSObject, FlutterStreamHandler {
  private var eventSink: FlutterEventSink?
  private let audioSession = AVAudioSession.sharedInstance()
  private var volumeView: MPVolumeView?
  private var observation: NSKeyValueObservation?
  /// `AVCaptureEventInteraction` (iOS 17.2+); als AnyObject bewaard omdat een
  /// opgeslagen property niet met @available gemarkeerd mag worden.
  private var captureInteraction: AnyObject?
  // Negeer KVO-callbacks die voortkomen uit onze eigen volume-reset, op basis
  // van een tijdvenster (geen vlag die kan blijven hangen als de reset niets doet).
  private var suppressUntil = Date.distantPast
  private let baseline: Float = 0.5

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
      // Eerst de officiële route proberen; lukt dat, dan hoeft de oude
      // volume-truc helemaal niet aan te staan.
      if self.startCaptureEventInteraction() { return }
      self.startVolumeObserver()
    }
  }

  /// iOS 17.2+: laat het systeem de volumeknoppen als sluiter afleveren.
  /// Geeft `false` terug als dat niet kan, zodat de terugval kan starten.
  private func startCaptureEventInteraction() -> Bool {
    guard #available(iOS 17.2, *) else { return false }
    guard let window = keyWindow() else { return false }
    let interaction = AVCaptureEventInteraction { [weak self] event in
      guard let self = self else { return }
      // Alleen bij loslaten, anders vuurt één druk twee keer.
      guard event.phase == .ended else { return }
      self.eventSink?(nil)
    }
    interaction.isEnabled = true
    window.addInteraction(interaction)
    self.captureInteraction = interaction
    return true
  }

  private func startVolumeObserver() {
    DispatchQueue.main.async {
      if self.volumeView == nil {
        let mpv = MPVolumeView(frame: CGRect(x: -4000, y: -4000, width: 120, height: 40))
        mpv.alpha = 0.0001
        mpv.isUserInteractionEnabled = false
        self.keyWindow()?.addSubview(mpv)
        self.volumeView = mpv
      }
      do {
        try self.audioSession.setCategory(.ambient, options: [.mixWithOthers])
        try self.audioSession.setActive(true)
      } catch {}

      // Beginvolume naar het midden (eigen wijziging wordt onderdrukt).
      self.applyBaseline()
      self.observation = self.audioSession.observe(
        \.outputVolume, options: [.new]
      ) { [weak self] _, _ in
        guard let self = self else { return }
        // Negeer wijzigingen vlak na onze eigen reset.
        if Date() < self.suppressUntil { return }
        // Echte volumeknop-druk.
        self.eventSink?(nil)
        // Zet terug naar het midden zodat er speling in beide richtingen blijft.
        self.applyBaseline()
      }
    }
  }

  private func stop() {
    observation?.invalidate()
    observation = nil
    DispatchQueue.main.async {
      if #available(iOS 17.2, *),
         let interaction = self.captureInteraction as? AVCaptureEventInteraction {
        interaction.isEnabled = false
        interaction.view?.removeInteraction(interaction)
      }
      self.captureInteraction = nil
      self.volumeView?.removeFromSuperview()
      self.volumeView = nil
      do {
        try self.audioSession.setActive(false, options: [.notifyOthersOnDeactivation])
      } catch {}
    }
  }

  private func applyBaseline() {
    // Onderdruk KVO-callbacks die uit deze eigen wijziging voortkomen.
    suppressUntil = Date().addingTimeInterval(0.3)
    DispatchQueue.main.async {
      guard let slider = self.volumeView?.subviews
        .compactMap({ $0 as? UISlider }).first else { return }
      slider.value = self.baseline
      slider.setValue(self.baseline, animated: false)
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
