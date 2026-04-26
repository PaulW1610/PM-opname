import Flutter
import Photos
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var photoChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    registerPhotoChannelIfNeeded()
    DispatchQueue.main.async { [weak self] in
      self?.registerPhotoChannelIfNeeded()
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func applicationDidBecomeActive(_ application: UIApplication) {
    super.applicationDidBecomeActive(application)
    registerPhotoChannelIfNeeded()
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    registerPhotoChannelIfNeeded()
  }

  private func registerPhotoChannelIfNeeded() {
    guard let controller = window?.rootViewController as? FlutterViewController else {
      return
    }

    let channel = FlutterMethodChannel(
      name: "photo_library_channel",
      binaryMessenger: controller.binaryMessenger
    )

    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "saveImageWithFilename" else {
        result(FlutterMethodNotImplemented)
        return
      }

      guard
        let args = call.arguments as? [String: Any],
        let imagePath = args["imagePath"] as? String,
        let albumName = args["albumName"] as? String,
        let fileName = args["fileName"] as? String
      else {
        result(
          FlutterError(
            code: "INVALID_ARGS",
            message: "Ontbrekende argumenten voor saveImageWithFilename",
            details: nil
          )
        )
        return
      }

      self?.saveImageWithFilename(
        imagePath: imagePath,
        albumName: albumName,
        fileName: fileName,
        result: result
      )
    }

    photoChannel = channel
  }

  private func saveImageWithFilename(
    imagePath: String,
    albumName: String,
    fileName: String,
    result: @escaping FlutterResult
  ) {
    let imageUrl = URL(fileURLWithPath: imagePath)
    guard FileManager.default.fileExists(atPath: imageUrl.path) else {
      result(
        FlutterError(
          code: "FILE_NOT_FOUND",
          message: "Afbeeldingsbestand niet gevonden op pad",
          details: imagePath
        )
      )
      return
    }

    let trimmedAlbumName = albumName.trimmingCharacters(in: .whitespacesAndNewlines)

    var targetCollection: PHAssetCollection?
    let fetchOptions = PHFetchOptions()
    fetchOptions.predicate = NSPredicate(format: "title = %@", trimmedAlbumName)
    let existingAlbums = PHAssetCollection.fetchAssetCollections(
      with: .album,
      subtype: .albumRegular,
      options: fetchOptions
    )
    targetCollection = existingAlbums.firstObject

    PHPhotoLibrary.shared().performChanges({
      var collectionChangeRequest: PHAssetCollectionChangeRequest?

      if let collection = targetCollection {
        collectionChangeRequest = PHAssetCollectionChangeRequest(for: collection)
      } else {
        collectionChangeRequest = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(
          withTitle: trimmedAlbumName
        )
      }

      let creationRequest = PHAssetCreationRequest.forAsset()
      let resourceOptions = PHAssetResourceCreationOptions()
      resourceOptions.originalFilename = fileName
      creationRequest.addResource(with: .photo, fileURL: imageUrl, options: resourceOptions)

      if let assetPlaceholder = creationRequest.placeholderForCreatedAsset {
        collectionChangeRequest?.addAssets([assetPlaceholder] as NSArray)
      }
    }) { success, error in
      DispatchQueue.main.async {
        if success {
          result(true)
          return
        }

        result(
          FlutterError(
            code: "SAVE_FAILED",
            message: "Opslaan in iOS Foto's mislukt",
            details: error?.localizedDescription
          )
        )
      }
    }
  }
}
