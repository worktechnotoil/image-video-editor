#import <React/RCTBridgeModule.h>
#import <AVFoundation/AVFoundation.h>

@interface RNFrameGrabber : NSObject <RCTBridgeModule>
@end

@implementation RNFrameGrabber

RCT_EXPORT_MODULE(RNFrameGrabber)

+ (BOOL)requiresMainQueueSetup { return NO; }

- (NSURL *)cleanURL:(NSString *)uriString {
    NSURL *url = [NSURL URLWithString:uriString];
    if ([url.scheme isEqualToString:@"file"]) {
        return [NSURL fileURLWithPath:url.path];
    }
    return url;
}

RCT_REMAP_METHOD(captureFrame,
                 captureFrameWithUri:(NSString *)uriString
                 options:(NSDictionary *)options
                 resolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
  NSURL *url = [self cleanURL:uriString];
  if (!url) {
    reject(@"bad_uri", @"Invalid video uri", nil);
    return;
  }

  AVAsset *asset = [AVAsset assetWithURL:url];
  NSNumber *timeMs = options[@"timeMs"] ?: @0;
  CMTime time = CMTimeMakeWithSeconds(timeMs.doubleValue / 1000.0, 600);

  AVAssetImageGenerator *generator = [[AVAssetImageGenerator alloc] initWithAsset:asset];
  generator.appliesPreferredTrackTransform = YES;

  NSError *error = nil;
  CGImageRef imageRef = [generator copyCGImageAtTime:time actualTime:NULL error:&error];
  if (!imageRef) {
    reject(@"frame_failed", error.localizedDescription ?: @"Could not capture frame", error);
    return;
  }

  UIImage *image = [UIImage imageWithCGImage:imageRef];
  CGImageRelease(imageRef);

  NSURL *outUrl = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"frame_%@.jpg", [NSUUID UUID].UUIDString]]];
  NSData *outData = UIImageJPEGRepresentation(image, 0.9);
  if (![outData writeToURL:outUrl atomically:YES]) {
    reject(@"write_failed", @"Failed to write frame", nil);
    return;
  }

  resolve(outUrl.absoluteString);
}

@end

