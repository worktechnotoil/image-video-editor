#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreImage/CoreImage.h>
#import <CoreVideo/CoreVideo.h>
#import <CoreMedia/CoreMedia.h>
#import <Vision/Vision.h>
#import <React/RCTComponent.h>

typedef void (^CameraFilterResolveBlock)(id result);
typedef void (^CameraFilterRejectBlock)(NSString *code, NSString *message, NSError *error);

@interface CameraFilterView : UIView <AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate>

@property (nonatomic, copy) NSString *facing;
@property (nonatomic, copy) NSString *filter;

@property (nonatomic, strong) AVCaptureSession *session;
@property (nonatomic, strong) AVCaptureDeviceInput *videoInput;
@property (nonatomic, strong) AVCaptureDeviceInput *audioInput;
@property (nonatomic, strong) AVCaptureVideoDataOutput *videoOutput;
@property (nonatomic, strong) AVCaptureAudioDataOutput *audioOutput;
@property (nonatomic, strong) dispatch_queue_t sessionQueue;
@property (nonatomic, strong) dispatch_queue_t videoQueue;
@property (nonatomic, strong) CIContext *ciContext;

// Face Tracking
@property (nonatomic, strong) VNDetectFaceLandmarksRequest *faceDetectionRequest;
@property (nonatomic, strong) NSArray<VNFaceObservation *> *currentFaces;

// Recording
@property (nonatomic, strong) AVAssetWriter *assetWriter;
@property (nonatomic, strong) AVAssetWriterInput *videoWriterInput;
@property (nonatomic, strong) AVAssetWriterInput *audioWriterInput;
@property (nonatomic, strong) AVAssetWriterInputPixelBufferAdaptor *pixelBufferAdaptor;
@property (nonatomic, assign) BOOL isRecording;
@property (nonatomic, assign) CMTime sessionStartTime;
@property (nonatomic, copy) NSString *videoOutputPath;

@property (nonatomic, copy) CameraFilterResolveBlock photoResolve;
@property (nonatomic, copy) CameraFilterRejectBlock photoReject;
@property (nonatomic, assign) BOOL takePhotoNextFrame;

@property (nonatomic, assign) size_t lastVideoWidth;
@property (nonatomic, assign) size_t lastVideoHeight;

@property (nonatomic, assign) BOOL hasWrittenVideo;
@property (nonatomic, assign) BOOL hasWrittenAudio;

- (void)capturePhotoWithResolver:(CameraFilterResolveBlock)resolve rejecter:(CameraFilterRejectBlock)reject;
- (void)startRecordingWithResolver:(CameraFilterResolveBlock)resolve rejecter:(CameraFilterRejectBlock)reject;
- (void)stopRecordingWithResolver:(CameraFilterResolveBlock)resolve rejecter:(CameraFilterRejectBlock)reject;

@end
