#import "CameraFilterModule.h"
#import "CameraFilterView.h"

@implementation CameraFilterModule

RCT_EXPORT_MODULE(CameraFilterModule)

@synthesize bridge = _bridge;

RCT_EXPORT_METHOD(capturePhoto:(nonnull NSNumber *)reactTag
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {
    [self.bridge.uiManager addUIBlock:^(RCTUIManager *uiManager, NSDictionary<NSNumber *,UIView *> *viewRegistry) {
        CameraFilterView *view = (CameraFilterView *)viewRegistry[reactTag];
        if (!view || ![view isKindOfClass:[CameraFilterView class]]) {
            reject(@"error", @"Camera view not found", nil);
        } else {
            [view capturePhotoWithResolver:resolve rejecter:reject];
        }
    }];
}

RCT_EXPORT_METHOD(startRecording:(nonnull NSNumber *)reactTag
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {
    [self.bridge.uiManager addUIBlock:^(RCTUIManager *uiManager, NSDictionary<NSNumber *,UIView *> *viewRegistry) {
        CameraFilterView *view = (CameraFilterView *)viewRegistry[reactTag];
        if (!view || ![view isKindOfClass:[CameraFilterView class]]) {
            reject(@"error", @"Camera view not found", nil);
        } else {
            [view startRecordingWithResolver:resolve rejecter:reject];
        }
    }];
}

RCT_EXPORT_METHOD(stopRecording:(nonnull NSNumber *)reactTag
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {
    [self.bridge.uiManager addUIBlock:^(RCTUIManager *uiManager, NSDictionary<NSNumber *,UIView *> *viewRegistry) {
        CameraFilterView *view = (CameraFilterView *)viewRegistry[reactTag];
        if (!view || ![view isKindOfClass:[CameraFilterView class]]) {
            reject(@"error", @"Camera view not found", nil);
        } else {
            [view stopRecordingWithResolver:resolve rejecter:reject];
        }
    }];
}

@end
