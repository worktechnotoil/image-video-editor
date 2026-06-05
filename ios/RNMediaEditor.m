#import <React/RCTBridgeModule.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreImage/CoreImage.h>
#import <UIKit/UIKit.h>
#import <Vision/Vision.h>

@interface RNMediaEditor : NSObject <RCTBridgeModule>
@end

@implementation RNMediaEditor {
  CIContext *_ciContext;
}

RCT_EXPORT_MODULE(RNMediaEditor)

+ (BOOL)requiresMainQueueSetup {
  return NO;
}

- (instancetype)init {
  if (self = [super init]) {
    _ciContext = [CIContext contextWithOptions:nil];
  }
  return self;
}

- (NSURL *)cleanURL:(NSString *)uriString {
    NSURL *url = [NSURL URLWithString:uriString];
    if ([url.scheme isEqualToString:@"file"]) {
        return [NSURL fileURLWithPath:url.path];
    }
    return url;
}

- (NSURL *)downloadToCache:(NSURL *)remoteURL {
    if (!remoteURL) return nil;
    
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    __block NSURL *localURL = nil;
    
    NSURLSessionDownloadTask *task = [[NSURLSession sharedSession] downloadTaskWithURL:remoteURL completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error) {
        if (!error && location) {
            NSString *tempName = [NSString stringWithFormat:@"music_%@.mp3", [NSUUID UUID].UUIDString];
            NSString *tempPath = [NSTemporaryDirectory() stringByAppendingPathComponent:tempName];
            NSURL *destinationURL = [NSURL fileURLWithPath:tempPath];
            
            NSError *moveError = nil;
            [[NSFileManager defaultManager] moveItemAtURL:location toURL:destinationURL error:&moveError];
            if (!moveError) {
                localURL = destinationURL;
            }
        }
        dispatch_semaphore_signal(sema);
    }];
    [task resume];
    dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
    
    return localURL;
}

RCT_REMAP_METHOD(editImage,
                 editImageWithUri:(NSString *)uriString
                 options:(NSDictionary *)options
                 resolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
  NSURL *url = [self cleanURL:uriString];
  if (!url) {
    reject(@"bad_uri", @"Invalid image uri", nil);
    return;
  }
  
  NSData *data = [NSData dataWithContentsOfURL:url];
  UIImage *rawImage = data ? [UIImage imageWithData:data] : nil;
  if (!rawImage) {
    NSString *reason = [NSString stringWithFormat:@"Could not decode image from uri: %@", uriString];
    reject(@"decode_failed", reason, nil);
    return;
  }

  // Normalize EXIF orientation to avoid coordinate system mismatches when applying crops
  UIGraphicsBeginImageContextWithOptions(rawImage.size, NO, 1.0);
  [rawImage drawInRect:CGRectMake(0, 0, rawImage.size.width, rawImage.size.height)];
  UIImage *originalImage = UIGraphicsGetImageFromCurrentImageContext();
  UIGraphicsEndImageContext();

  CIImage *ciImage = [[CIImage alloc] initWithImage:originalImage];
  
  // 1. Transform (Rotate/Flip)
  NSNumber *rotateDegrees = options[@"rotateDegrees"] ?: @0;
  BOOL flipX = [options[@"flipX"] boolValue];
  BOOL flipY = [options[@"flipY"] boolValue];

  if (rotateDegrees.intValue != 0 || flipX || flipY) {
    CGAffineTransform transform = CGAffineTransformIdentity;
    if (flipX) transform = CGAffineTransformScale(transform, -1, 1);
    if (flipY) transform = CGAffineTransformScale(transform, 1, -1);
    if (rotateDegrees.intValue != 0) {
      CGFloat radians = (CGFloat)(rotateDegrees.doubleValue * M_PI / 180.0);
      transform = CGAffineTransformRotate(transform, radians);
    }
    ciImage = [ciImage imageByApplyingTransform:transform];
    // Normalize transformed origin to 0,0 to prevent coordinate shifts during crop
    ciImage = [ciImage imageByApplyingTransform:CGAffineTransformMakeTranslation(-ciImage.extent.origin.x, -ciImage.extent.origin.y)];
  }

  // 2. Final Crop / Canvas Logic
  NSDictionary *crop = options[@"crop"];
  if ([crop isKindOfClass:NSDictionary.class] && crop.count > 0) {
    CGFloat cx = [crop[@"x"] doubleValue];
    CGFloat cy = [crop[@"y"] doubleValue];
    CGFloat cw = [crop[@"width"] doubleValue];
    CGFloat ch = [crop[@"height"] doubleValue];
    
    CGFloat maxW = ciImage.extent.size.width;
    CGFloat maxH = ciImage.extent.size.height;
    
    if (maxW > 0 && maxH > 0) {
      if (cx < 0) cx = 0;
      if (cy < 0) cy = 0;
      if (cx + cw > maxW) cw = maxW - cx;
      if (cy + ch > maxH) ch = maxH - cy;
      
      if (cw > 0 && ch > 0) {
        CGRect canvasRect = CGRectMake(0, 0, cw, ch);
        CIImage *blackBase = [[CIImage imageWithColor:[CIColor blackColor]] imageByCroppingToRect:canvasRect];
        
        CGFloat imgH = ciImage.extent.size.height;
        CGFloat ciOriginX = -cx;
        CGFloat ciOriginY = ch - (imgH - cy);
        
        CIImage *positionedImage = [ciImage imageByApplyingTransform:CGAffineTransformMakeTranslation(ciOriginX, ciOriginY)];
        ciImage = [positionedImage imageByCompositingOverImage:blackBase];
        ciImage = [ciImage imageByCroppingToRect:canvasRect];
        ciImage = [ciImage imageByApplyingTransform:CGAffineTransformMakeTranslation(-ciImage.extent.origin.x, -ciImage.extent.origin.y)];
      }
    }
  }

  // 3. Apply Frame after crop
  NSString *frameKey = options[@"frame"];
  BOOL frameApplied = NO;
  if ([frameKey isKindOfClass:NSString.class] && frameKey.length > 0) {
      // Bulletproof frame loading:
      // 1. Try Assets Catalog / Flat Bundle
      UIImage *uiFrame = [UIImage imageNamed:frameKey];
      
      // 2. Try various bundle paths
      if (!uiFrame) {
          NSArray *searchPaths = @[
              [[NSBundle mainBundle] pathForResource:frameKey ofType:@"png" inDirectory:@"frames"],
              [[NSBundle mainBundle] pathForResource:frameKey ofType:@"png" inDirectory:@"videoEditor/frames"],
              [[NSBundle mainBundle] pathForResource:frameKey ofType:@"png"]
          ];
          for (NSString *p in searchPaths) {
              if (p) {
                  uiFrame = [UIImage imageWithContentsOfFile:p];
                  if (uiFrame) break;
              }
          }
      }
      
      if (uiFrame) {
          NSLog(@"[RNMediaEditor] Frame loaded successfully: %@ size: %.0fx%.0f", frameKey, uiFrame.size.width, uiFrame.size.height);
          CIImage *frameImage = [CIImage imageWithCGImage:uiFrame.CGImage];
          if (frameImage) {
              // Ensure frame starts at 0,0
              frameImage = [frameImage imageByApplyingTransform:CGAffineTransformMakeTranslation(-frameImage.extent.origin.x, -frameImage.extent.origin.y)];
              
              CGFloat scaleX = ciImage.extent.size.width / frameImage.extent.size.width;
              CGFloat scaleY = ciImage.extent.size.height / frameImage.extent.size.height;
              CIImage *scaledFrame = [frameImage imageByApplyingTransform:CGAffineTransformMakeScale(scaleX, scaleY)];
              
              // Scale down original image slightly to fit inside the frame opening
              CGFloat insetScale = [options[@"frameScale"] doubleValue] ?: 0.88;
              CGFloat offsetYRatio = [options[@"frameOffsetY"] doubleValue] ?: 0.0;
              
              CGFloat tx = ciImage.extent.size.width * (1.0 - insetScale) / 2.0;
              CGFloat ty = ciImage.extent.size.height * (1.0 - insetScale) / 2.0;
              
              // Apply relative vertical offset
              CGFloat extraTY = ciImage.extent.size.height * offsetYRatio;
              
              CGAffineTransform insetTransform = CGAffineTransformConcat(
                  CGAffineTransformMakeScale(insetScale, insetScale),
                  CGAffineTransformMakeTranslation(tx, ty + extraTY)
              );
              
              // Normalize photo origin after potential crop
              ciImage = [ciImage imageByApplyingTransform:CGAffineTransformMakeTranslation(-ciImage.extent.origin.x, -ciImage.extent.origin.y)];
              
              CGRect targetRect = scaledFrame.extent;
              // Use an opaque black base so that transparent frame areas render as black.
              CIImage *opaqueBase = [[CIImage imageWithColor:[CIColor colorWithRed:0 green:0 blue:0 alpha:1]] imageByCroppingToRect:targetRect];
              
              // 1. Photo over opaque base (at 0,0)
              CIImage *photoLayer = [[ciImage imageByApplyingTransform:insetTransform] imageByCompositingOverImage:opaqueBase];
              
              // 2. Frame over photo
              ciImage = [scaledFrame imageByCompositingOverImage:photoLayer];
              
              // Reset result to 0,0 for final render
              ciImage = [ciImage imageByApplyingTransform:CGAffineTransformMakeTranslation(-ciImage.extent.origin.x, -ciImage.extent.origin.y)];
              frameApplied = YES;
          }
      } else {
          NSLog(@"[RNMediaEditor] ERROR: Frame image NOT FOUND for key: %@", frameKey);
      }
  }

  // 4. Adjustments (Brightness, Contrast, Saturation)
  NSNumber *brightness = options[@"brightness"] ?: @0;
  NSNumber *contrast = options[@"contrast"] ?: @1;
  NSNumber *saturation = options[@"saturation"] ?: @1;
  BOOL grayscale = [options[@"grayscale"] boolValue];

  CIFilter *controlsFilter = [CIFilter filterWithName:@"CIColorControls"];
  [controlsFilter setValue:ciImage forKey:kCIInputImageKey];
  [controlsFilter setValue:(grayscale ? @0 : saturation) forKey:kCIInputSaturationKey];
  [controlsFilter setValue:brightness forKey:kCIInputBrightnessKey];
  [controlsFilter setValue:contrast forKey:kCIInputContrastKey];
  
  CIImage *outputCI = controlsFilter.outputImage ?: ciImage;

  NSString *arFilter = options[@"arFilter"];
  if (arFilter != nil && arFilter.length > 0) {
      outputCI = [self applyARFilter:arFilter toCIImage:outputCI];
  }

  // 3. Render into a temporary bitmap image to support drawing overlays
  CGRect renderExtent = outputCI.extent;
  if (CGRectIsInfinite(renderExtent) || CGRectIsEmpty(renderExtent)) {
      renderExtent = ciImage.extent;
  }
  
  CGImageRef cgImage = [_ciContext createCGImage:outputCI fromRect:renderExtent];
  if (!cgImage) {
    reject(@"render_failed", @"Failed to render CoreImage", nil);
    return;
  }
  UIImage *workingImage = [UIImage imageWithCGImage:cgImage];
  CGImageRelease(cgImage);

  // 4. Draw Overlays (Color Tints, Text)
  UIGraphicsBeginImageContextWithOptions(workingImage.size, NO, 1.0);
  [workingImage drawAtPoint:CGPointZero];
  
  CGContextRef ctx = UIGraphicsGetCurrentContext();
  CGRect fullRect = CGRectMake(0, 0, workingImage.size.width, workingImage.size.height);

  // Tint color UI replica
  if (options[@"tintColor"] && options[@"tintOpacity"]) {
    NSString *hexString = options[@"tintColor"];
    CGFloat tintOp = [options[@"tintOpacity"] doubleValue];
    if (tintOp > 0 && [hexString hasPrefix:@"#"]) {
       unsigned rgbValue = 0;
       NSScanner *scanner = [NSScanner scannerWithString:hexString];
       [scanner setScanLocation:1];
       [scanner scanHexInt:&rgbValue];
       UIColor *tintColor = [UIColor colorWithRed:((rgbValue & 0xFF0000) >> 16)/255.0 
                                            green:((rgbValue & 0xFF00) >> 8)/255.0 
                                             blue:(rgbValue & 0xFF)/255.0 
                                            alpha:tintOp];
       [tintColor setFill];
       CGContextFillRect(ctx, fullRect);
    }
  }

  NSArray *overlays = options[@"overlays"];
  if ([overlays isKindOfClass:NSArray.class] && overlays.count > 0) {
    
    for (NSDictionary *overlay in overlays) {
        NSString *text = overlay[@"text"];
        NSNumber *x = overlay[@"x"];
        NSNumber *y = overlay[@"y"];
        NSNumber *fontSize = overlay[@"fontSize"] ?: @24;
        NSString *colorHex = overlay[@"color"] ?: @"#FFFFFF";
        
        if (text && x && y) {
            UIColor *color = [self colorFromHexString:colorHex];
            NSDictionary *attrs = @{
                NSFontAttributeName: [UIFont boldSystemFontOfSize:fontSize.floatValue],
                NSForegroundColorAttributeName: color
            };
            [text drawAtPoint:CGPointMake(x.doubleValue, y.doubleValue) withAttributes:attrs];
        }
    }
  }

  workingImage = UIGraphicsGetImageFromCurrentImageContext();
  UIGraphicsEndImageContext();

  // 5. Save to persistent directory
  NSString *ext = frameApplied ? @"png" : @"jpg";
  NSString *fileName = [NSString stringWithFormat:@"edited_%@.%@", [[NSUUID UUID] UUIDString], ext];
  
  NSString *docsDir = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
  NSString *editedPath = [docsDir stringByAppendingPathComponent:@"edited_media"];
  
  NSFileManager *fm = [NSFileManager defaultManager];
  if (![fm fileExistsAtPath:editedPath]) {
      [fm createDirectoryAtPath:editedPath withIntermediateDirectories:YES attributes:nil error:nil];
  }
  
  NSString *outPath = [editedPath stringByAppendingPathComponent:fileName];
  NSURL *outUrl = [NSURL fileURLWithPath:outPath];
  
  NSData *outData;
  if (frameApplied) {
    outData = UIImagePNGRepresentation(workingImage);
  } else {
    outData = UIImageJPEGRepresentation(workingImage, 0.9);
  }
  if (outData) {
    [outData writeToURL:outUrl atomically:YES];
    resolve(outUrl.absoluteString);
  } else {
    reject(@"write_failed", @"Failed to write edited image to disk", nil);
  }
}

- (CIImage *)applyARFilter:(NSString *)filter toCIImage:(CIImage *)ciImage {
    VNSequenceRequestHandler *handler = [[VNSequenceRequestHandler alloc] init];
    VNDetectFaceRectanglesRequest *request = [[VNDetectFaceRectanglesRequest alloc] init];
    NSError *error = nil;
    [handler performRequests:@[request] onCIImage:ciImage error:&error];
    if (error || request.results.count == 0) return ciImage;
    
    CIImage *result = ciImage;
    NSString *emoji = [filter isEqualToString:@"sunglasses"] ? @"🕶️" : ([filter isEqualToString:@"dog"] ? @"🐶" : @"🤓");
    
    for (VNFaceObservation *face in request.results) {
        CGRect bb = face.boundingBox;
        CGFloat extentWidth = result.extent.size.width;
        CGFloat extentHeight = result.extent.size.height;
        
        CGRect faceRect = CGRectMake(bb.origin.x * extentWidth, bb.origin.y * extentHeight, bb.size.width * extentWidth, bb.size.height * extentHeight);
        
        CGFloat scaleMultiplier = [filter isEqualToString:@"sunglasses"] ? 1.0 : 1.3;
        CGRect targetRect = CGRectMake(0, 0, faceRect.size.width * scaleMultiplier, faceRect.size.height * scaleMultiplier);
        
        UIGraphicsBeginImageContextWithOptions(targetRect.size, NO, 1.0);
        UIFont *font = [UIFont systemFontOfSize:targetRect.size.height * 0.8];
        
        CGFloat yOffset = targetRect.size.height * 0.1;
        if ([filter isEqualToString:@"sunglasses"]) { yOffset = targetRect.size.height * 0.3; }
        
        NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
        style.alignment = NSTextAlignmentCenter;
        [emoji drawInRect:CGRectMake(0, yOffset, targetRect.size.width, targetRect.size.height)
           withAttributes:@{NSFontAttributeName: font, NSParagraphStyleAttributeName: style}];
        UIImage *emojiImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        
        CIImage *emojiCI = [[CIImage alloc] initWithImage:emojiImage];
        emojiCI = [emojiCI imageByApplyingTransform:CGAffineTransformMakeScale(1, -1)];
        emojiCI = [emojiCI imageByApplyingTransform:CGAffineTransformMakeTranslation(0, targetRect.size.height)];
        
        CGFloat xTrans = faceRect.origin.x - (targetRect.size.width - faceRect.size.width) / 2.0;
        CGFloat yTrans = faceRect.origin.y - (targetRect.size.height - faceRect.size.height) / 2.0;
        
        emojiCI = [emojiCI imageByApplyingTransform:CGAffineTransformMakeTranslation(xTrans, yTrans)];
        result = [emojiCI imageByCompositingOverImage:result];
    }
    return result;
}

- (UIColor *)colorFromHexString:(NSString *)hex {
  unsigned rgbValue = 0;
  NSScanner *scanner = [NSScanner scannerWithString:hex];
  if ([hex hasPrefix:@"#"]) scanner.scanLocation = 1;
  [scanner scanHexInt:&rgbValue];
  return [UIColor colorWithRed:((rgbValue >> 16) & 0xFF) / 255.0
                         green:((rgbValue >> 8) & 0xFF) / 255.0
                          blue:(rgbValue & 0xFF) / 255.0
                         alpha:1.0];
}

RCT_REMAP_METHOD(trimVideo,
                 trimVideoWithUri:(NSString *)uriString
                 options:(NSDictionary *)options
                 resolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
  NSURL *url = [self cleanURL:uriString];
  if (!url) {
    reject(@"bad_uri", @"Invalid video uri", nil);
    return;
  }

  BOOL isImage = [options[@"isImage"] boolValue];
  NSString *musicUri = options[@"musicUri"];

  AVAsset *asset = nil;
  CMTimeRange range;
  __block NSString *tempVideoToDelete = nil;
  __block NSURL *tempMusicToDelete = nil;

  if (isImage) {
      UIImage *image = [UIImage imageWithContentsOfFile:url.path];
      if (!image) {
          reject(@"bad_image", @"Could not load image", nil);
          return;
      }
      NSString *tempVideoName = [NSString stringWithFormat:@"temp_img_video_%@.mp4", [NSUUID UUID].UUIDString];
      NSString *tempVideoPath = [NSTemporaryDirectory() stringByAppendingPathComponent:tempVideoName];
      tempVideoToDelete = tempVideoPath;
      
      dispatch_semaphore_t sema = dispatch_semaphore_create(0);
      __block NSError *writeError = nil;
      [self createVideoFromImage:image duration:10.0 outputPath:tempVideoPath completion:^(BOOL success, NSError *err) {
          writeError = err;
          dispatch_semaphore_signal(sema);
      }];
      dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
      
      if (writeError) {
          reject(@"image_to_video_failed", writeError.localizedDescription, writeError);
          return;
      }
      
      asset = [AVAsset assetWithURL:[NSURL fileURLWithPath:tempVideoPath]];
      range = CMTimeRangeMake(kCMTimeZero, CMTimeMakeWithSeconds(10.0, 600));
  } else {
      asset = [AVAsset assetWithURL:url];
      double startMs = [options[@"startMs"] doubleValue];
      double endMs = [options[@"endMs"] doubleValue];
      CMTime startTime = CMTimeMakeWithSeconds(startMs / 1000.0, 600);
      CMTime endTime = CMTimeMakeWithSeconds(endMs / 1000.0, 600);
      range = CMTimeRangeFromTimeToTime(startTime, endTime);
  }

  BOOL mute = [options[@"mute"] boolValue];

  // Use AVMutableComposition to handle Mute by optionally adding audio tracks
  AVMutableComposition *composition = [AVMutableComposition composition];
  
  // Video track
  AVMutableCompositionTrack *videoTrack = [composition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
  NSArray<AVAssetTrack *> *origVideoTracks = [asset tracksWithMediaType:AVMediaTypeVideo];
  if (origVideoTracks.count > 0) {
    AVAssetTrack *track = origVideoTracks.firstObject;
    CMTime trackDuration = track.timeRange.duration;
    CMTime startTime = CMTimeMinimum(range.start, trackDuration);
    CMTime duration = CMTimeMinimum(range.duration, CMTimeSubtract(trackDuration, startTime));
    CMTimeRange safeRange = CMTimeRangeMake(startTime, duration);
    [videoTrack insertTimeRange:safeRange ofTrack:track atTime:kCMTimeZero error:nil];
    videoTrack.preferredTransform = track.preferredTransform;
  }

  // Audio track (only if not muted)
  if (!mute) {
    NSArray<AVAssetTrack *> *origAudioTracks = [asset tracksWithMediaType:AVMediaTypeAudio];
    if (origAudioTracks.count > 0) {
      AVMutableCompositionTrack *audioTrack = [composition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
      AVAssetTrack *track = origAudioTracks.firstObject;
      CMTime trackDuration = track.timeRange.duration;
      CMTime startTime = CMTimeMinimum(range.start, trackDuration);
      CMTime duration = CMTimeMinimum(range.duration, CMTimeSubtract(trackDuration, startTime));
      CMTimeRange safeRange = CMTimeRangeMake(startTime, duration);
      [audioTrack insertTimeRange:safeRange ofTrack:track atTime:kCMTimeZero error:nil];
    }
  }

  // Music track overlay/mix
  if (musicUri && musicUri.length > 0) {
    NSURL *musicURL = [self cleanURL:musicUri];
    if ([musicURL.scheme isEqualToString:@"http"] || [musicURL.scheme isEqualToString:@"https"]) {
        NSURL *cachedURL = [self downloadToCache:musicURL];
        if (cachedURL) {
            musicURL = cachedURL;
            tempMusicToDelete = cachedURL;
        }
    }
    if (musicURL) {
      AVAsset *musicAsset = [AVAsset assetWithURL:musicURL];
      NSArray<AVAssetTrack *> *musicAudioTracks = [musicAsset tracksWithMediaType:AVMediaTypeAudio];
      if (musicAudioTracks.count > 0) {
        AVMutableCompositionTrack *musicCompositionTrack = [composition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
        CMTime musicDuration = musicAsset.duration;
        CMTime targetDuration = range.duration;
        CMTime insertDuration = CMTimeMinimum(targetDuration, musicDuration);
        [musicCompositionTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, insertDuration) ofTrack:musicAudioTracks.firstObject atTime:kCMTimeZero error:nil];
      }
    }
  }


  AVAssetExportSession *export = [[AVAssetExportSession alloc] initWithAsset:composition presetName:AVAssetExportPresetHighestQuality];
  if (!export) {
    reject(@"export_failed", @"Could not create export session", nil);
    return;
  }

  // --- Filtering Logic (using CI filters) ---
  NSNumber *brightness = options[@"brightness"] ?: @0;
  NSNumber *contrast = options[@"contrast"] ?: @1;
  NSNumber *saturation = options[@"saturation"] ?: @1;
  BOOL grayscale = [options[@"grayscale"] boolValue];
  NSString *tintHex = options[@"tintColor"];
  NSNumber *tintOpacity = options[@"tintOpacity"];
  NSString *frameKey = options[@"frame"];

  NSNumber *rotateDegrees = options[@"rotateDegrees"] ?: @0;
  BOOL flipX = [options[@"flipX"] boolValue];
  BOOL flipY = [options[@"flipY"] boolValue];

  // Prepare Frame before block to avoid reloading it 30-60 times a second
  CIImage *capturedFrameImg = nil;
  if (frameKey && frameKey.length > 0) {
      // Bulletproof frame loading (same as editImage)
      UIImage *uiFrame = [UIImage imageNamed:frameKey];
      if (!uiFrame) {
          NSArray *searchPaths = @[
              [[NSBundle mainBundle] pathForResource:frameKey ofType:@"png" inDirectory:@"frames"],
              [[NSBundle mainBundle] pathForResource:frameKey ofType:@"png" inDirectory:@"videoEditor/frames"],
              [[NSBundle mainBundle] pathForResource:frameKey ofType:@"png"]
          ];
          for (NSString *p in searchPaths) {
              if (p) {
                  uiFrame = [UIImage imageWithContentsOfFile:p];
                  if (uiFrame) break;
              }
          }
      }
      
      if (uiFrame) {
          NSLog(@"[RNMediaEditor] Video frame overlay loaded: %@", frameKey);
          capturedFrameImg = [CIImage imageWithCGImage:uiFrame.CGImage];
          if (capturedFrameImg) {
              // Ensure frame starts at 0,0
              capturedFrameImg = [capturedFrameImg imageByApplyingTransform:CGAffineTransformMakeTranslation(-capturedFrameImg.extent.origin.x, -capturedFrameImg.extent.origin.y)];
          }
      } else {
          NSLog(@"[RNMediaEditor] ERROR: Video frame overlay NOT FOUND for key: %@", frameKey);
      }
  }

  // Pre-render text overlays if any
  NSArray *vOverlays = options[@"overlays"];
  CIImage *textOverlayCI = nil;
  if ([vOverlays isKindOfClass:NSArray.class] && vOverlays.count > 0) {
      // Determine final output size to create a correctly scaled overlay
      NSDictionary *vCrop = options[@"crop"];
      CGSize targetSize;
      if (vCrop) {
          targetSize = CGSizeMake([vCrop[@"width"] doubleValue], [vCrop[@"height"] doubleValue]);
      } else {
          targetSize = videoTrack.naturalSize;
          if (ABS(videoTrack.preferredTransform.b) > 0.5) {
              targetSize = CGSizeMake(targetSize.height, targetSize.width);
          }
      }
      
      if (targetSize.width > 0 && targetSize.height > 0) {
          UIGraphicsBeginImageContextWithOptions(targetSize, NO, 1.0);
          for (NSDictionary *overlay in vOverlays) {
              NSString *text = overlay[@"text"];
              NSNumber *x = overlay[@"x"];
              NSNumber *y = overlay[@"y"];
              NSNumber *fontSize = overlay[@"fontSize"] ?: @24;
              NSString *colorHex = overlay[@"color"] ?: @"#FFFFFF";
              
              if (text && x && y) {
                  UIColor *color = [self colorFromHexString:colorHex];
                  NSDictionary *attrs = @{
                      NSFontAttributeName: [UIFont boldSystemFontOfSize:fontSize.floatValue],
                      NSForegroundColorAttributeName: color
                  };
                  [text drawAtPoint:CGPointMake(x.doubleValue, y.doubleValue) withAttributes:attrs];
              }
          }
          UIImage *overlayImg = UIGraphicsGetImageFromCurrentImageContext();
          UIGraphicsEndImageContext();
          if (overlayImg) {
              textOverlayCI = [[CIImage alloc] initWithImage:overlayImg];
              // UIImage (top-left) to CIImage (bottom-left) conversion requires vertical flip
              // to maintain the correct visual position for the video compositor.
              textOverlayCI = [textOverlayCI imageByApplyingTransform:CGAffineTransformMakeScale(1, -1)];
              textOverlayCI = [textOverlayCI imageByApplyingTransform:CGAffineTransformMakeTranslation(0, targetSize.height)];
          }
      }
  }

  NSDictionary *cropOption = options[@"crop"];
  if (brightness.floatValue != 0 || contrast.floatValue != 1 || saturation.floatValue != 1 || grayscale || (tintHex && tintOpacity.floatValue > 0) || rotateDegrees.intValue != 0 || flipX || flipY || (cropOption && cropOption.count > 0) || capturedFrameImg || textOverlayCI) {
    AVVideoComposition *videoComposition = [AVVideoComposition videoCompositionWithAsset:composition applyingCIFiltersWithHandler:^(AVAsynchronousCIImageFilteringRequest *request) {
      CIImage *output = request.sourceImage;
      
      // 1. Transform (Rotate/Flip)
      NSNumber *rDeg = options[@"rotateDegrees"] ?: @0;
      BOOL fX = [options[@"flipX"] boolValue];
      BOOL fY = [options[@"flipY"] boolValue];
      
      if (rDeg.intValue != 0 || fX || fY) {
        CGAffineTransform t = CGAffineTransformIdentity;
        if (fX) t = CGAffineTransformScale(t, -1, 1);
        if (fY) t = CGAffineTransformScale(t, 1, -1);
        if (rDeg.intValue != 0) {
          t = CGAffineTransformRotate(t, (CGFloat)(rDeg.doubleValue * M_PI / 180.0));
        }
        output = [output imageByApplyingTransform:t];
        
        // Ensure image starts at (0,0) after transform
        output = [output imageByApplyingTransform:CGAffineTransformMakeTranslation(-output.extent.origin.x, -output.extent.origin.y)];
      }

      // 2. Crop
      NSDictionary *vCrop = options[@"crop"];
      if ([vCrop isKindOfClass:NSDictionary.class] && vCrop.count > 0) {
        CGFloat cx = [vCrop[@"x"] doubleValue];
        CGFloat cy = [vCrop[@"y"] doubleValue];
        CGFloat cw = [vCrop[@"width"] doubleValue];
        CGFloat ch = [vCrop[@"height"] doubleValue];
        
        CGFloat maxW = output.extent.size.width;
        CGFloat maxH = output.extent.size.height;
        
        if (maxW > 0 && maxH > 0) {
          if (cx < 0) cx = 0;
          if (cy < 0) cy = 0;
          if (cx + cw > maxW) cw = maxW - cx;
          if (cy + ch > maxH) ch = maxH - cy;
          
          NSInteger icw = (NSInteger)cw;
          NSInteger ich = (NSInteger)ch;
          if (icw % 2 != 0) icw = (icw > 1) ? icw - 1 : 2;
          if (ich % 2 != 0) ich = (ich > 1) ? ich - 1 : 2;
          cw = icw;
          ch = ich;
          
          if (cw > 0 && ch > 0) {
            CGFloat flippedY = maxH - cy - ch;
            output = [output imageByCroppingToRect:CGRectMake(cx, flippedY, cw, ch)];
            output = [output imageByApplyingTransform:CGAffineTransformMakeTranslation(-output.extent.origin.x, -output.extent.origin.y)];
          }
        }
      }

      // 3. Apply Frame after crop
      if (capturedFrameImg) {
        CGFloat scaleX = output.extent.size.width / capturedFrameImg.extent.size.width;
        CGFloat scaleY = output.extent.size.height / capturedFrameImg.extent.size.height;
        CIImage *scaledFrame = [capturedFrameImg imageByApplyingTransform:CGAffineTransformMakeScale(scaleX, scaleY)];
        
        // Scale down video content slightly to fit inside the frame opening
        CGFloat insetScale = [options[@"frameScale"] doubleValue] ?: 0.88;
        CGFloat offsetYRatio = [options[@"frameOffsetY"] doubleValue] ?: 0.0;
        
        CGFloat tx = output.extent.size.width * (1.0 - insetScale) / 2.0;
        CGFloat ty = output.extent.size.height * (1.0 - insetScale) / 2.0;
        CGFloat extraTY = output.extent.size.height * offsetYRatio;
        
        CGAffineTransform insetTransform = CGAffineTransformConcat(
            CGAffineTransformMakeScale(insetScale, insetScale),
            CGAffineTransformMakeTranslation(tx, ty + extraTY)
        );

        // Normalize video frame origin
        output = [output imageByApplyingTransform:CGAffineTransformMakeTranslation(-output.extent.origin.x, -output.extent.origin.y)];

        CGRect targetRect = scaledFrame.extent;
        // H.264 video does not support alpha, so use an opaque black base.
        // This ensures transparent areas of the frame PNG render as black
        // (matching the preview dark background in the editor UI).
        CIImage *opaqueBase = [[CIImage imageWithColor:[CIColor colorWithRed:0 green:0 blue:0 alpha:1]] imageByCroppingToRect:targetRect];
        
        // 1. Video frame over opaque base (at 0,0)
        CIImage *videoLayer = [[output imageByApplyingTransform:insetTransform] imageByCompositingOverImage:opaqueBase];
        
        // 2. Frame overlay over video layer
        output = [scaledFrame imageByCompositingOverImage:videoLayer];
        
        // Final normalization for generator
        output = [output imageByApplyingTransform:CGAffineTransformMakeTranslation(-output.extent.origin.x, -output.extent.origin.y)];
      }

      // 4. Color adjustments (Apply after crop/frame so everything is affected)
      CIFilter *filter = [CIFilter filterWithName:@"CIColorControls"];
      [filter setValue:output forKey:kCIInputImageKey];
      [filter setValue:(grayscale ? @0 : saturation) forKey:kCIInputSaturationKey];
      [filter setValue:brightness forKey:kCIInputBrightnessKey];
      [filter setValue:contrast forKey:kCIInputContrastKey];
      output = filter.outputImage ?: output;
      
      // Tint overlay
      if (tintHex && tintOpacity.doubleValue > 0 && [tintHex hasPrefix:@"#"]) {
        unsigned rgbValue = 0;
        NSScanner *scanner = [NSScanner scannerWithString:tintHex];
        [scanner setScanLocation:1];
        [scanner scanHexInt:&rgbValue];
        CGFloat r = ((rgbValue & 0xFF0000) >> 16)/255.0;
        CGFloat g = ((rgbValue & 0xFF00) >> 8)/255.0;
        CGFloat b = (rgbValue & 0xFF)/255.0;
        CIColor *cColor = [CIColor colorWithRed:r green:g blue:b alpha:tintOpacity.doubleValue];
        CIImage *overlay = [[CIImage imageWithColor:cColor] imageByCroppingToRect:output.extent];
        output = [overlay imageByCompositingOverImage:output];
      }
      
      // 5. Text Overlays (Apply at the very end)
      if (textOverlayCI) {
          output = [textOverlayCI imageByCompositingOverImage:output];
      }
      
      // 6. AR Filter Face Tracking
      NSString *arFilter = options[@"arFilter"];
      if (arFilter && arFilter.length > 0) {
          // VNSequenceRequestHandler requires an strong ref. Since this is async blocks, 
          // we use a fresh VNSequenceRequestHandler per request.
          output = [self applyARFilter:arFilter toCIImage:output];
      }

      [request finishWithImage:output context:nil];
    }];
    
    // Set proper size for composition based on track transform + user requested transforms
    CGSize naturalSize = videoTrack.naturalSize;
    CGAffineTransform trackT = videoTrack.preferredTransform;
    
    NSNumber *userRotate = options[@"rotateDegrees"] ?: @0;
    CGAffineTransform userT = CGAffineTransformIdentity;
    if ([options[@"flipX"] boolValue]) userT = CGAffineTransformScale(userT, -1, 1);
    if ([options[@"flipY"] boolValue]) userT = CGAffineTransformScale(userT, 1, -1);
    if (userRotate.intValue != 0) {
      userT = CGAffineTransformRotate(userT, (CGFloat)(userRotate.doubleValue * M_PI / 180.0));
    }
    
    CGAffineTransform combinedT = CGAffineTransformConcat(trackT, userT);
    CGRect finalRect = CGRectApplyAffineTransform(CGRectMake(0, 0, naturalSize.width, naturalSize.height), combinedT);
    
    CGSize renderSize = CGSizeMake(ABS(finalRect.size.width), ABS(finalRect.size.height));
    
    NSDictionary *finalCrop = options[@"crop"];
    if ([finalCrop isKindOfClass:NSDictionary.class]) {
        renderSize = CGSizeMake([finalCrop[@"width"] doubleValue], [finalCrop[@"height"] doubleValue]);
    }
    
    NSInteger rWidth = (NSInteger)renderSize.width;
    NSInteger rHeight = (NSInteger)renderSize.height;
    if (rWidth % 2 != 0) rWidth = (rWidth > 1) ? rWidth - 1 : 2;
    if (rHeight % 2 != 0) rHeight = (rHeight > 1) ? rHeight - 1 : 2;
    renderSize = CGSizeMake(rWidth, rHeight);
    
    AVMutableVideoComposition *mutableVideoComposition = [videoComposition mutableCopy];
    mutableVideoComposition.renderSize = renderSize;
    export.videoComposition = mutableVideoComposition;
  }

  // ------------------------

  NSString *docsDir = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
  NSString *editedPath = [docsDir stringByAppendingPathComponent:@"edited_media"];
  
  NSFileManager *fm = [NSFileManager defaultManager];
  if (![fm fileExistsAtPath:editedPath]) {
      [fm createDirectoryAtPath:editedPath withIntermediateDirectories:YES attributes:nil error:nil];
  }

  NSString *fileName = [NSString stringWithFormat:@"trimmed_%@.mp4", [NSUUID UUID].UUIDString];
  NSString *outPath = [editedPath stringByAppendingPathComponent:fileName];
  NSURL *outUrl = [NSURL fileURLWithPath:outPath];
  export.outputURL = outUrl;
  export.outputFileType = AVFileTypeMPEG4;
  // Note: timeRange is now kCMTimeRangeInvalid (meaning whole composition) 
  // because we already trimmed while building the composition tracks.
  export.timeRange = CMTimeRangeMake(kCMTimeZero, composition.duration);

  [export exportAsynchronouslyWithCompletionHandler:^{
    if (tempVideoToDelete) {
        [[NSFileManager defaultManager] removeItemAtPath:tempVideoToDelete error:nil];
    }
    if (tempMusicToDelete) {
        [[NSFileManager defaultManager] removeItemAtURL:tempMusicToDelete error:nil];
    }
    switch (export.status) {
      case AVAssetExportSessionStatusCompleted:
        resolve(outUrl.absoluteString);
        break;
      case AVAssetExportSessionStatusFailed:
      case AVAssetExportSessionStatusCancelled:
        reject(@"export_failed", export.error.localizedDescription ?: @"Export failed", export.error);
        break;
      default:
        reject(@"export_failed", @"Export did not complete", nil);
        break;
    }
  }];
}

- (CVPixelBufferRef)pixelBufferFromCGImage:(CGImageRef)image width:(NSInteger)width height:(NSInteger)height {
    NSDictionary *options = @{
        (id)kCVPixelBufferCGImageCompatibilityKey: @YES,
        (id)kCVPixelBufferCGBitmapContextCompatibilityKey: @YES
    };
    CVPixelBufferRef pxbuffer = NULL;
    CVReturn status = CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32ARGB, (__bridge CFDictionaryRef)options, &pxbuffer);
    if (status != kCVReturnSuccess || pxbuffer == NULL) {
        return NULL;
    }
    
    CVPixelBufferLockBaseAddress(pxbuffer, 0);
    void *pxdata = CVPixelBufferGetBaseAddress(pxbuffer);
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(pxbuffer);
    
    CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(pxdata, width, height, 8, bytesPerRow, rgbColorSpace, kCGImageAlphaNoneSkipFirst);
    if (context == NULL) {
        CVPixelBufferUnlockBaseAddress(pxbuffer, 0);
        CVPixelBufferRelease(pxbuffer);
        CGColorSpaceRelease(rgbColorSpace);
        return NULL;
    }
    
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), image);
    CGColorSpaceRelease(rgbColorSpace);
    CGContextRelease(context);
    
    CVPixelBufferUnlockBaseAddress(pxbuffer, 0);
    return pxbuffer;
}

- (void)createVideoFromImage:(UIImage *)image duration:(NSTimeInterval)duration outputPath:(NSString *)outputPath completion:(void (^)(BOOL success, NSError *error))completion {
    NSError *error = nil;
    AVAssetWriter *writer = [[AVAssetWriter alloc] initWithURL:[NSURL fileURLWithPath:outputPath] fileType:AVFileTypeMPEG4 error:&error];
    if (error) {
        completion(NO, error);
        return;
    }
    
    CGImageRef cgImage = image.CGImage;
    BOOL shouldReleaseCGImage = NO;
    if (!cgImage && image.CIImage) {
        CIContext *ciContext = [CIContext contextWithOptions:nil];
        cgImage = [ciContext createCGImage:image.CIImage fromRect:image.CIImage.extent];
        shouldReleaseCGImage = YES;
    }
    
    if (!cgImage) {
        completion(NO, [NSError errorWithDomain:@"RNMediaEditor" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"Could not get CGImage from UIImage"}]);
        return;
    }
    
    CGFloat originalWidth = CGImageGetWidth(cgImage);
    CGFloat originalHeight = CGImageGetHeight(cgImage);
    NSInteger width = ((NSInteger)originalWidth / 2) * 2;
    NSInteger height = ((NSInteger)originalHeight / 2) * 2;
    
    NSDictionary *videoSettings = @{
        AVVideoCodecKey: AVVideoCodecTypeH264,
        AVVideoWidthKey: @(width),
        AVVideoHeightKey: @(height)
    };
    
    AVAssetWriterInput *input = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:videoSettings];
    NSDictionary *bufferAttributes = @{
        (id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32ARGB),
        (id)kCVPixelBufferWidthKey: @(width),
        (id)kCVPixelBufferHeightKey: @(height)
    };
    AVAssetWriterInputPixelBufferAdaptor *adaptor = [AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:input sourcePixelBufferAttributes:bufferAttributes];
    
    [writer addInput:input];
    if (![writer startWriting]) {
        if (shouldReleaseCGImage) {
            CGImageRelease(cgImage);
        }
        completion(NO, writer.error ?: [NSError errorWithDomain:@"RNMediaEditor" code:-2 userInfo:@{NSLocalizedDescriptionKey: @"Failed to start writing"}]);
        return;
    }
    
    NSInteger fps = 10;
    NSInteger totalFrames = (NSInteger)(duration * fps);
    
    [writer startSessionAtSourceTime:kCMTimeZero];
    
    for (NSInteger i = 0; i < totalFrames; i++) {
        int retryCount = 0;
        while (!input.isReadyForMoreMediaData && retryCount < 50) {
            [NSThread sleepForTimeInterval:0.01];
            retryCount++;
        }
        
        CVPixelBufferRef buffer = [self pixelBufferFromCGImage:cgImage width:width height:height];
        if (buffer) {
            [adaptor appendPixelBuffer:buffer withPresentationTime:CMTimeMake(i, (int32_t)fps)];
            CVPixelBufferRelease(buffer);
        }
    }
    
    if (shouldReleaseCGImage) {
        CGImageRelease(cgImage);
    }
    
    [input markAsFinished];
    [writer finishWritingWithCompletionHandler:^{
        if (writer.status == AVAssetWriterStatusFailed) {
            completion(NO, writer.error);
        } else {
            completion(YES, nil);
        }
    }];
}

@end

