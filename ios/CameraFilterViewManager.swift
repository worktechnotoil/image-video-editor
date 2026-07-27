import React
import AVFoundation

@objc(CameraFilterViewManager)
class CameraFilterViewManager: RCTViewManager {
  override func view() -> UIView! {
    return CameraFilterView()
  }

  override static func requiresMainQueueSetup() -> Bool {
    return true
  }

  @objc(checkPermission:rejecter:)
  func checkPermission(_ resolve: @escaping RCTPromiseResolveBlock, rejecter reject: @escaping RCTPromiseRejectBlock) {
    let status = AVCaptureDevice.authorizationStatus(for: .video)
    resolve(status == .authorized)
  }

  @objc(requestPermission:rejecter:)
  func requestPermission(_ resolve: @escaping RCTPromiseResolveBlock, rejecter reject: @escaping RCTPromiseRejectBlock) {
    AVCaptureDevice.requestAccess(for: .video) { granted in
      resolve(granted)
    }
  }

  @objc(startRecording:resolve:reject:)
  func startRecording(_ node: NSNumber, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
    DispatchQueue.main.async {
      if let view = self.bridge.uiManager.view(forReactTag: node) as? CameraFilterView {
        view.startRecording(resolve, rejecter: reject)
      } else {
        reject("error", "View not found", nil)
      }
    }
  }

  @objc(stopRecording:resolve:reject:)
  func stopRecording(_ node: NSNumber, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
    DispatchQueue.main.async {
      if let view = self.bridge.uiManager.view(forReactTag: node) as? CameraFilterView {
        view.stopRecording(resolve, rejecter: reject)
      } else {
        reject("error", "View not found", nil)
      }
    }
  }

  @objc(capturePhoto:resolve:reject:)
  func capturePhoto(_ node: NSNumber, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
    DispatchQueue.main.async {
      if let view = self.bridge.uiManager.view(forReactTag: node) as? CameraFilterView {
        view.capturePhoto(resolve, rejecter: reject)
      } else {
        reject("error", "View not found", nil)
      }
    }
  }
}
