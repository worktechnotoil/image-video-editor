#import <React/RCTViewManager.h>

@interface RCT_EXTERN_MODULE(CameraFilterViewManager, RCTViewManager)
RCT_EXPORT_VIEW_PROPERTY(filter, NSString)
RCT_EXTERN_METHOD(checkPermission:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)
RCT_EXTERN_METHOD(requestPermission:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(startRecording:(nonnull NSNumber *)node resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)
RCT_EXTERN_METHOD(stopRecording:(nonnull NSNumber *)node resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)
RCT_EXTERN_METHOD(capturePhoto:(nonnull NSNumber *)node resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)
@end
