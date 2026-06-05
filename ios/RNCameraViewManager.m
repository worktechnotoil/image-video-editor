#import <React/RCTViewManager.h>
#import <React/RCTUIManager.h>
#import <React/RCTConvert.h>
#import <AVFoundation/AVFoundation.h>

@interface RNCameraView : UIView <AVCapturePhotoCaptureDelegate, AVCaptureFileOutputRecordingDelegate>

@property (nonatomic, copy) NSString *facing;
@property (nonatomic, strong) AVCaptureSession *session;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *previewLayer;
@property (nonatomic, strong) AVCapturePhotoOutput *photoOutput;
@property (nonatomic, strong) AVCaptureMovieFileOutput *movieOutput;
@property (nonatomic, strong) AVCaptureDeviceInput *videoInput;
@property (nonatomic, strong) AVCaptureDeviceInput *audioInput;
@property (nonatomic, strong) dispatch_queue_t sessionQueue;

@property (nonatomic, copy) RCTPromiseResolveBlock photoResolve;
@property (nonatomic, copy) RCTPromiseRejectBlock photoReject;
@property (nonatomic, copy) RCTPromiseResolveBlock recordResolve;
@property (nonatomic, copy) RCTPromiseRejectBlock recordReject;

@property (nonatomic, copy) NSString *photoTrigger;
@property (nonatomic, copy) NSString *recordTrigger;
@property (nonatomic, copy) RCTDirectEventBlock onPhotoCaptured;
@property (nonatomic, copy) RCTDirectEventBlock onRecordStarted;
@property (nonatomic, copy) RCTDirectEventBlock onRecordStopped;

@end

@implementation RNCameraView

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        _facing = @"front"; // default to front
        self.sessionQueue = dispatch_queue_create("com.videoeditor.sessionQueue", DISPATCH_QUEUE_SERIAL);
        self.session = [[AVCaptureSession alloc] init];
        self.session.sessionPreset = AVCaptureSessionPresetHigh;
        
        self.previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:self.session];
        self.previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
        [self.layer addSublayer:self.previewLayer];
        
        self.photoOutput = [[AVCapturePhotoOutput alloc] init];
        self.movieOutput = [[AVCaptureMovieFileOutput alloc] init];
        
        dispatch_async(self.sessionQueue, ^{
            [self.session beginConfiguration];
            if ([self.session canAddOutput:self.photoOutput]) {
                [self.session addOutput:self.photoOutput];
            }
            if ([self.session canAddOutput:self.movieOutput]) {
                [self.session addOutput:self.movieOutput];
            }
            [self.session commitConfiguration];
        });
        
        [self configureInputs];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.previewLayer.frame = self.bounds;
    
    // Update preview orientation
    AVCaptureConnection *connection = self.previewLayer.connection;
    if (connection && connection.supportsVideoOrientation) {
        UIInterfaceOrientation orientation = [[UIApplication sharedApplication] statusBarOrientation];
        AVCaptureVideoOrientation avOrientation;
        switch (orientation) {
            case UIInterfaceOrientationPortraitUpsideDown:
                avOrientation = AVCaptureVideoOrientationPortraitUpsideDown;
                break;
            case UIInterfaceOrientationLandscapeLeft:
                avOrientation = AVCaptureVideoOrientationLandscapeLeft;
                break;
            case UIInterfaceOrientationLandscapeRight:
                avOrientation = AVCaptureVideoOrientationLandscapeRight;
                break;
            default:
                avOrientation = AVCaptureVideoOrientationPortrait;
                break;
        }
        connection.videoOrientation = avOrientation;
    }
}

- (void)didMoveToWindow {
    [super didMoveToWindow];
    if (self.window) {
        NSLog(@"[RNCameraView] View moved to window, requesting permissions");
        [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL cameraGranted) {
            [AVCaptureDevice requestAccessForMediaType:AVMediaTypeAudio completionHandler:^(BOOL audioGranted) {
                dispatch_async(self.sessionQueue, ^{
                    NSLog(@"[RNCameraView] Starting session running");
                    [self.session startRunning];
                });
            }];
        }];
    } else {
        dispatch_async(self.sessionQueue, ^{
            NSLog(@"[RNCameraView] Stopping session running");
            [self.session stopRunning];
        });
    }
}

- (void)setFacing:(NSString *)facing {
    if ([_facing isEqualToString:facing]) return;
    _facing = [facing copy];
    [self configureInputs];
}

- (void)setPhotoTrigger:(NSString *)photoTrigger {
    if (!photoTrigger || [photoTrigger length] == 0 || [_photoTrigger isEqualToString:photoTrigger]) return;
    _photoTrigger = [photoTrigger copy];
    [self capturePhotoWithResolver:^(id result) {
        if (self.onPhotoCaptured) {
            self.onPhotoCaptured(result);
        }
    } rejecter:^(NSString *code, NSString *message, NSError *error) {
        if (self.onPhotoCaptured) {
            self.onPhotoCaptured(@{@"error": message ?: @"Capture failed"});
        }
    }];
}

- (void)setRecordTrigger:(NSString *)recordTrigger {
    if ([_recordTrigger isEqualToString:recordTrigger]) return;
    _recordTrigger = [recordTrigger copy];
    
    if ([recordTrigger isEqualToString:@"start"]) {
        [self startRecordingWithResolver:^(id result) {
            if (self.onRecordStarted) {
                self.onRecordStarted(@{});
            }
        } rejecter:^(NSString *code, NSString *message, NSError *error) {
            if (self.onRecordStarted) {
                self.onRecordStarted(@{@"error": message ?: @"Start recording failed"});
            }
        }];
    } else if ([recordTrigger isEqualToString:@"stop"]) {
        [self stopRecordingWithResolver:^(id result) {
            if (self.onRecordStopped) {
                self.onRecordStopped(result);
            }
        } rejecter:^(NSString *code, NSString *message, NSError *error) {
            if (self.onRecordStopped) {
                self.onRecordStopped(@{@"error": message ?: @"Stop recording failed"});
            }
        }];
    }
}

- (void)configureInputs {
    dispatch_async(self.sessionQueue, ^{
        NSLog(@"[RNCameraView] Configuring inputs for facing: %@", self.facing);
        [self.session beginConfiguration];
        
        // Remove existing inputs
        if (self.videoInput) {
            [self.session removeInput:self.videoInput];
            self.videoInput = nil;
        }
        if (self.audioInput) {
            [self.session removeInput:self.audioInput];
            self.audioInput = nil;
        }
        
        // Setup Video Device
        AVCaptureDevicePosition position = [self.facing isEqualToString:@"back"] ? AVCaptureDevicePositionBack : AVCaptureDevicePositionFront;
        AVCaptureDevice *videoDevice = nil;
        
        // Search for device
        AVCaptureDeviceDiscoverySession *discoverySession = [AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:@[AVCaptureDeviceTypeBuiltInWideAngleCamera] mediaType:AVMediaTypeVideo position:position];
        for (AVCaptureDevice *device in discoverySession.devices) {
            if (device.position == position) {
                videoDevice = device;
                break;
            }
        }
        if (!videoDevice) {
            videoDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
        }
        
        if (videoDevice) {
            NSError *error = nil;
            self.videoInput = [AVCaptureDeviceInput deviceInputWithDevice:videoDevice error:&error];
            if (error) {
                NSLog(@"[RNCameraView] Error creating video input: %@", error.localizedDescription);
            }
            if (self.videoInput && [self.session canAddInput:self.videoInput]) {
                [self.session addInput:self.videoInput];
                NSLog(@"[RNCameraView] Video input added successfully");
            } else {
                NSLog(@"[RNCameraView] Cannot add video input");
            }
        } else {
            NSLog(@"[RNCameraView] No video device found");
        }
        
        // Setup Audio Device
        AVCaptureDevice *audioDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
        if (audioDevice) {
            NSError *error = nil;
            self.audioInput = [AVCaptureDeviceInput deviceInputWithDevice:audioDevice error:&error];
            if (error) {
                NSLog(@"[RNCameraView] Error creating audio input: %@", error.localizedDescription);
            }
            if (self.audioInput && [self.session canAddInput:self.audioInput]) {
                [self.session addInput:self.audioInput];
                NSLog(@"[RNCameraView] Audio input added successfully");
            } else {
                NSLog(@"[RNCameraView] Cannot add audio input");
            }
        } else {
            NSLog(@"[RNCameraView] No audio device found");
        }
        
        [self.session commitConfiguration];
    });
}

// Photo capture method
- (void)capturePhotoWithResolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject {
    self.photoResolve = resolve;
    self.photoReject = reject;
    
    dispatch_async(self.sessionQueue, ^{
        AVCapturePhotoSettings *settings = [AVCapturePhotoSettings photoSettings];
        [self.photoOutput capturePhotoWithSettings:settings delegate:self];
    });
}

// Photo delegate
- (void)captureOutput:(AVCapturePhotoOutput *)output didFinishProcessingPhoto:(AVCapturePhoto *)photo error:(NSError *)error {
    if (error) {
        if (self.photoReject) self.photoReject(@"capture_error", error.localizedDescription, error);
        return;
    }
    NSData *data = [photo fileDataRepresentation];
    UIImage *image = [UIImage imageWithData:data];
    
    // Save to temp folder
    NSString *fileName = [NSString stringWithFormat:@"photo_%f.jpg", [[NSDate date] timeIntervalSince1970]];
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:fileName];
    [data writeToFile:path atomically:YES];
    
    if (self.photoResolve) {
        self.photoResolve(@{
            @"uri": [NSURL fileURLWithPath:path].absoluteString,
            @"width": @(image.size.width),
            @"height": @(image.size.height)
        });
    }
}

// Video recording methods
- (void)startRecordingWithResolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject {
    if (self.movieOutput.isRecording) {
        reject(@"already_recording", @"Camera is already recording video.", nil);
        return;
    }
    
    self.recordResolve = resolve;
    self.recordReject = reject;
    
    NSString *fileName = [NSString stringWithFormat:@"video_%f.mp4", [[NSDate date] timeIntervalSince1970]];
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:fileName];
    NSURL *fileURL = [NSURL fileURLWithPath:path];
    
    dispatch_async(self.sessionQueue, ^{
        // Check orientation connection
        AVCaptureConnection *connection = [self.movieOutput connectionWithMediaType:AVMediaTypeVideo];
        if (connection && connection.supportsVideoOrientation) {
            dispatch_async(dispatch_get_main_queue(), ^{
                UIInterfaceOrientation orientation = [[UIApplication sharedApplication] statusBarOrientation];
                AVCaptureVideoOrientation avOrientation;
                switch (orientation) {
                    case UIInterfaceOrientationPortraitUpsideDown:
                        avOrientation = AVCaptureVideoOrientationPortraitUpsideDown;
                        break;
                    case UIInterfaceOrientationLandscapeLeft:
                        avOrientation = AVCaptureVideoOrientationLandscapeLeft;
                        break;
                    case UIInterfaceOrientationLandscapeRight:
                        avOrientation = AVCaptureVideoOrientationLandscapeRight;
                        break;
                    default:
                        avOrientation = AVCaptureVideoOrientationPortrait;
                        break;
                }
                dispatch_async(self.sessionQueue, ^{
                    connection.videoOrientation = avOrientation;
                    [self.movieOutput startRecordingToOutputFileURL:fileURL recordingDelegate:self];
                });
            });
        } else {
            [self.movieOutput startRecordingToOutputFileURL:fileURL recordingDelegate:self];
        }
    });
}

- (void)stopRecordingWithResolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject {
    if (!self.movieOutput.isRecording) {
        reject(@"not_recording", @"Camera is not recording.", nil);
        return;
    }
    
    self.recordResolve = resolve;
    self.recordReject = reject;
    
    dispatch_async(self.sessionQueue, ^{
        [self.movieOutput stopRecording];
    });
}

// Recording delegate
- (void)captureOutput:(AVCaptureFileOutput *)output didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL fromConnections:(NSArray<AVCaptureConnection *> *)connections error:(NSError *)error {
    if (error && error.code != NSURLErrorUnknown) {
        if (self.recordReject) self.recordReject(@"recording_error", error.localizedDescription, error);
        return;
    }
    
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:outputFileURL options:nil];
    CMTime duration = asset.duration;
    float durationMs = CMTimeGetSeconds(duration) * 1000.0;
    
    AVAssetTrack *track = [[asset tracksWithMediaType:AVMediaTypeVideo] firstObject];
    CGSize size = CGSizeMake(1280, 720); // fallback
    if (track) {
        CGSize natSize = track.naturalSize;
        CGAffineTransform t = track.preferredTransform;
        BOOL isPortrait = (t.a == 0 && t.d == 0 && (t.b == 1 || t.b == -1) && (t.c == 1 || t.c == -1));
        size = isPortrait ? CGSizeMake(natSize.height, natSize.width) : natSize;
    }
    
    if (self.recordResolve) {
        self.recordResolve(@{
            @"uri": outputFileURL.absoluteString,
            @"durationMs": @(durationMs),
            @"width": @(size.width),
            @"height": @(size.height)
        });
    }
}

@end

// Companion Bridge Module
@interface RNCameraModule : NSObject <RCTBridgeModule>
@end

@implementation RNCameraModule
RCT_EXPORT_MODULE(RNCameraModule)

@synthesize bridge = _bridge;

RCT_EXPORT_METHOD(capturePhoto:(nonnull NSNumber *)reactTag
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {
    [self.bridge.uiManager addUIBlock:^(RCTUIManager *uiManager, NSDictionary<NSNumber *,UIView *> *viewRegistry) {
        RNCameraView *view = (RNCameraView *)viewRegistry[reactTag];
        if (!view || ![view isKindOfClass:[RNCameraView class]]) {
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
        RNCameraView *view = (RNCameraView *)viewRegistry[reactTag];
        if (!view || ![view isKindOfClass:[RNCameraView class]]) {
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
        RNCameraView *view = (RNCameraView *)viewRegistry[reactTag];
        if (!view || ![view isKindOfClass:[RNCameraView class]]) {
            reject(@"error", @"Camera view not found", nil);
        } else {
            [view stopRecordingWithResolver:resolve rejecter:reject];
        }
    }];
}

@end

// View Manager
@interface RNCameraViewManager : RCTViewManager
@end

@implementation RNCameraViewManager

RCT_EXPORT_MODULE(RNCameraView)

- (UIView *)view {
    return [[RNCameraView alloc] initWithFrame:CGRectZero];
}

RCT_EXPORT_VIEW_PROPERTY(facing, NSString)
RCT_EXPORT_VIEW_PROPERTY(photoTrigger, NSString)
RCT_EXPORT_VIEW_PROPERTY(recordTrigger, NSString)
RCT_EXPORT_VIEW_PROPERTY(onPhotoCaptured, RCTDirectEventBlock)
RCT_EXPORT_VIEW_PROPERTY(onRecordStarted, RCTDirectEventBlock)
RCT_EXPORT_VIEW_PROPERTY(onRecordStopped, RCTDirectEventBlock)

@end
