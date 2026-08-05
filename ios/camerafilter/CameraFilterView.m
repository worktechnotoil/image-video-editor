#import "CameraFilterView.h"

@implementation CameraFilterView

- (instancetype)initWithFrame:(CGRect)frame {
  if (self = [super initWithFrame:frame]) {
    _facing = @"front";
    _filter = @"none";
    _ciContext = [CIContext contextWithOptions:nil];

    self.layer.contentsGravity = kCAGravityResizeAspectFill;
    self.layer.masksToBounds = YES;

    self.faceDetectionRequest = [[VNDetectFaceLandmarksRequest alloc] init];

    static dispatch_queue_t sharedSessionQueue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      sharedSessionQueue = dispatch_queue_create("com.videoeditor.sessionQueue",
                                                 DISPATCH_QUEUE_SERIAL);
    });
    self.sessionQueue = sharedSessionQueue;

    self.videoQueue = dispatch_queue_create("com.videoeditor.videoQueue",
                                            DISPATCH_QUEUE_SERIAL);

    self.session = [[AVCaptureSession alloc] init];
    self.session.sessionPreset = AVCaptureSessionPreset1280x720;

    self.videoOutput = [[AVCaptureVideoDataOutput alloc] init];
    self.videoOutput.alwaysDiscardsLateVideoFrames = YES;
    self.videoOutput.videoSettings =
        @{(id)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32BGRA)};
    [self.videoOutput setSampleBufferDelegate:self queue:self.videoQueue];

    self.audioOutput = [[AVCaptureAudioDataOutput alloc] init];
    [self.audioOutput setSampleBufferDelegate:self queue:self.videoQueue];

    dispatch_async(self.sessionQueue, ^{
      [self.session beginConfiguration];
      if ([self.session canAddOutput:self.videoOutput]) {
        [self.session addOutput:self.videoOutput];
      }
      if ([self.session canAddOutput:self.audioOutput]) {
        [self.session addOutput:self.audioOutput];
      }
      [self.session commitConfiguration];
    });

    [self configureInputs];
  }
  return self;
}

- (void)didMoveToWindow {
  [super didMoveToWindow];
  if (self.window) {
    [AVCaptureDevice
        requestAccessForMediaType:AVMediaTypeVideo
                completionHandler:^(BOOL cameraGranted) {
                  [AVCaptureDevice
                      requestAccessForMediaType:AVMediaTypeAudio
                              completionHandler:^(BOOL audioGranted) {
                                dispatch_async(self.sessionQueue, ^{
                                  // Force audio session to PlayAndRecord so it isn't stuck in Playback mode from EditorScreen
                                  [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord
                                                                   withOptions:AVAudioSessionCategoryOptionMixWithOthers | AVAudioSessionCategoryOptionDefaultToSpeaker
                                                                         error:nil];
                                  [[AVAudioSession sharedInstance] setActive:YES error:nil];
                                  
                                  [self.session startRunning];
                                });
                              }];
                }];
  } else {
    dispatch_async(self.videoQueue, ^{
      if (self.isRecording && self.assetWriter) {
        self.isRecording = NO;
        [self.assetWriter cancelWriting];
        self.assetWriter = nil;
        self.videoWriterInput = nil;
        self.audioWriterInput = nil;
        self.pixelBufferAdaptor = nil;
      }
    });
    dispatch_async(self.sessionQueue, ^{
      [self.session stopRunning];
      for (AVCaptureInput *input in self.session.inputs) {
        [self.session removeInput:input];
      }
      for (AVCaptureOutput *output in self.session.outputs) {
        [self.session removeOutput:output];
      }
      
      // Also reset audio session to ambient/playback so it doesn't hold recording priority
      dispatch_async(dispatch_get_main_queue(), ^{
        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
        [[AVAudioSession sharedInstance] setActive:NO error:nil];
      });
    });
  }
}

- (void)dealloc {
  if (self.isRecording && self.assetWriter) {
    [self.assetWriter cancelWriting];
  }
}

- (void)setFacing:(NSString *)facing {
  if ([_facing isEqualToString:facing])
    return;
  _facing = [facing copy];
  [self configureInputs];
}

- (void)setFilter:(NSString *)filter {
  if ([_filter isEqualToString:filter])
    return;
  _filter = [filter copy];
}

- (void)configureInputs {
  dispatch_async(self.sessionQueue, ^{
    [self.session beginConfiguration];
    if (self.videoInput) {
      [self.session removeInput:self.videoInput];
      self.videoInput = nil;
    }
    if (self.audioInput) {
      [self.session removeInput:self.audioInput];
      self.audioInput = nil;
    }

    AVCaptureDevicePosition position = [self.facing isEqualToString:@"back"]
                                           ? AVCaptureDevicePositionBack
                                           : AVCaptureDevicePositionFront;
    AVCaptureDevice *videoDevice = [AVCaptureDevice
        defaultDeviceWithDeviceType:AVCaptureDeviceTypeBuiltInWideAngleCamera
                          mediaType:AVMediaTypeVideo
                           position:position];

    if (videoDevice) {
      NSError *error = nil;
      self.videoInput = [AVCaptureDeviceInput deviceInputWithDevice:videoDevice
                                                              error:&error];
      if (self.videoInput && [self.session canAddInput:self.videoInput]) {
        [self.session addInput:self.videoInput];
        AVCaptureConnection *conn =
            [self.videoOutput connectionWithMediaType:AVMediaTypeVideo];
        if (conn.isVideoOrientationSupported) {
          conn.videoOrientation = AVCaptureVideoOrientationPortrait;
        }
        if (conn.isVideoMirroringSupported) {
          conn.videoMirrored = (position == AVCaptureDevicePositionFront);
        }
      }
    }

    AVCaptureDevice *audioDevice =
        [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
    if (audioDevice) {
      NSError *error = nil;
      self.audioInput = [AVCaptureDeviceInput deviceInputWithDevice:audioDevice
                                                              error:&error];
      if (self.audioInput && [self.session canAddInput:self.audioInput]) {
        [self.session addInput:self.audioInput];
      }
    }
    [self.session commitConfiguration];
  });
}

- (CIImage *)applyFilterToImage:(CIImage *)image {
  if ([_filter isEqualToString:@"none"])
    return image;

  CIFilter *filter = nil;

  // Color & Tone Filters
  if ([_filter isEqualToString:@"vintage"]) {
    filter = [CIFilter
        filterWithName:@"CISepiaTone"
         keysAndValues:kCIInputImageKey, image, @"inputIntensity", @0.8, nil];
  } else if ([_filter isEqualToString:@"blackWhite"] ||
             [_filter isEqualToString:@"snap_evil_bw"] ||
             [_filter isEqualToString:@"snap_noir_kitty"] ||
             [_filter isEqualToString:@"snap_butterflies"] ||
             [_filter isEqualToString:@"snap_pink_hearts"] ||
             [_filter isEqualToString:@"snap_vintage_grain"] ||
             [_filter isEqualToString:@"snap_eyes_reveal"]) {
    filter = [CIFilter filterWithName:@"CIPhotoEffectNoir"
                        keysAndValues:kCIInputImageKey, image, nil];
  } else if ([_filter isEqualToString:@"vibrant"] ||
             [_filter isEqualToString:@"brightenGlow"] ||
             [_filter isEqualToString:@"snap_neon_outline"]) {
    filter = [CIFilter
        filterWithName:@"CIColorControls"
         keysAndValues:kCIInputImageKey, image, @"inputSaturation", @1.5,
                       @"inputContrast", @1.1, @"inputBrightness", @0.1, nil];
  } else if ([_filter isEqualToString:@"coolTone"]) {
    filter = [CIFilter
        filterWithName:@"CITemperatureAndTint"
         keysAndValues:kCIInputImageKey, image, @"inputNeutral",
                       [CIVector vectorWithX:6500 Y:0], @"inputTargetNeutral",
                       [CIVector vectorWithX:9000 Y:0], nil];
  } else if ([_filter isEqualToString:@"warmTone"] ||
             [_filter isEqualToString:@"snap_sunset_cowboy"] ||
             [_filter isEqualToString:@"snap_heart_frame"] ||
             [_filter isEqualToString:@"snap_city_time"] ||
             [_filter isEqualToString:@"snap_pookie"]) {
    filter = [CIFilter
        filterWithName:@"CITemperatureAndTint"
         keysAndValues:kCIInputImageKey, image, @"inputNeutral",
                       [CIVector vectorWithX:6500 Y:0], @"inputTargetNeutral",
                       [CIVector vectorWithX:4000 Y:0], nil];
  } else if ([_filter isEqualToString:@"smoothSkin"]) {
    // Pseudo smooth skin using slight blur and unsharp mask
    CIFilter *blur = [CIFilter
        filterWithName:@"CIGaussianBlur"
         keysAndValues:kCIInputImageKey, image, @"inputRadius", @2.0, nil];
    filter = [CIFilter filterWithName:@"CIUnsharpMask"
                        keysAndValues:kCIInputImageKey, blur.outputImage, nil];

  } else if ([_filter isEqualToString:@"snap_retro_skull"]) {
    filter = [CIFilter filterWithName:@"CIPhotoEffectNoir"
                        keysAndValues:kCIInputImageKey, image, nil];
  } else if ([_filter isEqualToString:@"snap_neon_neon"]) {
    filter = [CIFilter
        filterWithName:@"CIColorMatrix"
         keysAndValues:kCIInputImageKey, image, @"inputRVector",
                       [CIVector vectorWithX:1.2 Y:0.0 Z:0.2 W:0.0],
                       @"inputGVector",
                       [CIVector vectorWithX:0.1 Y:0.8 Z:0.0 W:0.0],
                       @"inputBVector",
                       [CIVector vectorWithX:0.3 Y:0.0 Z:1.4 W:0.0],
                       @"inputAVector",
                       [CIVector vectorWithX:0.0 Y:0.0 Z:0.0 W:1.0],
                       @"inputBiasVector",
                       [CIVector vectorWithX:0.05 Y:0.0 Z:0.05 W:0.0], nil];
  } else if ([_filter isEqualToString:@"snap_icy_dalmatian"]) {
    filter = [CIFilter
        filterWithName:@"CIColorMatrix"
         keysAndValues:kCIInputImageKey, image, @"inputRVector",
                       [CIVector vectorWithX:0.75 Y:0.1 Z:0.0 W:0.0],
                       @"inputGVector",
                       [CIVector vectorWithX:0.0 Y:1.1 Z:0.1 W:0.0],
                       @"inputBVector",
                       [CIVector vectorWithX:0.0 Y:0.1 Z:1.35 W:0.0],
                       @"inputAVector",
                       [CIVector vectorWithX:0.0 Y:0.0 Z:0.0 W:1.0],
                       @"inputBiasVector",
                       [CIVector vectorWithX:0.0 Y:0.02 Z:0.06 W:0.0], nil];
  } else if ([_filter isEqualToString:@"snap_dark_moon"]) {
    filter = [CIFilter
        filterWithName:@"CIColorMatrix"
         keysAndValues:kCIInputImageKey, image, @"inputRVector",
                       [CIVector vectorWithX:0.25 Y:0.50 Z:0.09 W:0.0],
                       @"inputGVector",
                       [CIVector vectorWithX:0.25 Y:0.50 Z:0.09 W:0.0],
                       @"inputBVector",
                       [CIVector vectorWithX:0.25 Y:0.50 Z:0.09 W:0.0],
                       @"inputAVector",
                       [CIVector vectorWithX:0.0 Y:0.0 Z:0.0 W:1.0],
                       @"inputBiasVector",
                       [CIVector vectorWithX:-0.03 Y:-0.03 Z:-0.03 W:0.0], nil];
  } else if ([_filter isEqualToString:@"snap_day_stamp"]) {
    filter = [CIFilter
        filterWithName:@"CIColorMatrix"
         keysAndValues:kCIInputImageKey, image, @"inputRVector",
                       [CIVector vectorWithX:1.04 Y:0.04 Z:0.00 W:0.0],
                       @"inputGVector",
                       [CIVector vectorWithX:0.02 Y:1.00 Z:0.02 W:0.0],
                       @"inputBVector",
                       [CIVector vectorWithX:0.00 Y:0.03 Z:0.96 W:0.0],
                       @"inputAVector",
                       [CIVector vectorWithX:0.0 Y:0.0 Z:0.0 W:1.0],
                       @"inputBiasVector",
                       [CIVector vectorWithX:0.04 Y:0.02 Z:0.01 W:0.0], nil];
  } else if ([_filter isEqualToString:@"fisheyeBulge"] ||
             [_filter isEqualToString:@"slimFace"] ||
             [_filter isEqualToString:@"eyeEnhance"] ||
             [_filter isEqualToString:@"babyFace"]) {
    CIImage *currentImage = image;
    CGFloat width = image.extent.size.width;
    CGFloat height = image.extent.size.height;

    if (self.currentFaces && self.currentFaces.count > 0) {
      CGPoint (^getCenter)(VNFaceLandmarkRegion2D *, CGRect) =
          ^CGPoint(VNFaceLandmarkRegion2D *region, CGRect rect) {
            if (!region || region.pointCount == 0)
              return CGPointZero;
            CGFloat x = 0, y = 0;
            for (NSUInteger i = 0; i < region.pointCount; i++) {
              CGPoint p = region.normalizedPoints[i];
              x += p.x;
              y += p.y;
            }
            x /= region.pointCount;
            y /= region.pointCount;
            return CGPointMake(rect.origin.x + x * rect.size.width,
                               rect.origin.y + y * rect.size.height);
          };

      for (VNFaceObservation *face in self.currentFaces) {
        CGRect faceRect = CGRectMake(face.boundingBox.origin.x * width,
                                     face.boundingBox.origin.y * height,
                                     face.boundingBox.size.width * width,
                                     face.boundingBox.size.height * height);

        CGPoint leftEye = getCenter(face.landmarks.leftEye, faceRect);
        CGPoint rightEye = getCenter(face.landmarks.rightEye, faceRect);

        CGFloat eyeDist =
            (leftEye.x != 0 && rightEye.x != 0)
                ? hypot(rightEye.x - leftEye.x, rightEye.y - leftEye.y)
                : 0;

        if (eyeDist > 0) {
          BOOL doEye = [_filter isEqualToString:@"eyeEnhance"] ||
                       [_filter isEqualToString:@"babyFace"];
          BOOL doSlim = [_filter isEqualToString:@"slimFace"] ||
                        [_filter isEqualToString:@"babyFace"];

          if (doEye) {
            CGFloat radius = eyeDist * 1.2;
            CGFloat scale = 0.6; // Bulge
            CIFilter *f1 = [CIFilter
                filterWithName:@"CIBumpDistortion"
                 keysAndValues:kCIInputImageKey, currentImage, @"inputCenter",
                               [CIVector vectorWithX:leftEye.x Y:leftEye.y],
                               @"inputRadius", @(radius), @"inputScale",
                               @(scale), nil];
            currentImage = f1.outputImage;
            CIFilter *f2 = [CIFilter
                filterWithName:@"CIBumpDistortion"
                 keysAndValues:kCIInputImageKey, currentImage, @"inputCenter",
                               [CIVector vectorWithX:rightEye.x Y:rightEye.y],
                               @"inputRadius", @(radius), @"inputScale",
                               @(scale), nil];
            currentImage = f2.outputImage;
          }

          if (doSlim) {
            // Cheeks are roughly below and outside the eyes (+Y is up in
            // CIImage, so cheeks are lower Y) wait! Vision bounding box origin
            // is bottom-left? No, Vision y=0 is bottom! So eyes have higher Y
            // than cheeks. Therefore cheeks are at eye.y - eyeDist * 0.8
            CGPoint leftCheek = CGPointMake(leftEye.x - eyeDist * 0.3,
                                            leftEye.y - eyeDist * 0.8);
            CGPoint rightCheek = CGPointMake(rightEye.x + eyeDist * 0.3,
                                             rightEye.y - eyeDist * 0.8);

            CGFloat radius = eyeDist * 1.5;
            CGFloat scale = 0.5; // Pinch in

            CIFilter *f1 = [CIFilter
                filterWithName:@"CIPinchDistortion"
                 keysAndValues:kCIInputImageKey, currentImage, @"inputCenter",
                               [CIVector vectorWithX:leftCheek.x Y:leftCheek.y],
                               @"inputRadius", @(radius), @"inputScale",
                               @(scale), nil];
            currentImage = f1.outputImage;
            CIFilter *f2 = [CIFilter
                filterWithName:@"CIPinchDistortion"
                 keysAndValues:kCIInputImageKey, currentImage, @"inputCenter",
                               [CIVector vectorWithX:rightCheek.x
                                                   Y:rightCheek.y],
                               @"inputRadius", @(radius), @"inputScale",
                               @(scale), nil];
            currentImage = f2.outputImage;
          }
        }

        if ([_filter isEqualToString:@"fisheyeBulge"]) {
          CGPoint center =
              CGPointMake(faceRect.origin.x + faceRect.size.width / 2.0,
                          faceRect.origin.y + faceRect.size.height / 2.0);
          CGFloat radius = faceRect.size.width * 0.8;
          CIFilter *f1 = [CIFilter
              filterWithName:@"CIBumpDistortion"
               keysAndValues:kCIInputImageKey, currentImage, @"inputCenter",
                             [CIVector vectorWithX:center.x Y:center.y],
                             @"inputRadius", @(radius), @"inputScale", @(0.7),
                             nil];
          currentImage = f1.outputImage;
        }
      }
    }
    return currentImage;
  } else if ([_filter isEqualToString:@"snap_cartoon_toon"]) {
    filter = [CIFilter filterWithName:@"CIComicEffect"
                        keysAndValues:kCIInputImageKey, image, nil];
  } else if ([_filter isEqualToString:@"snap_creator_hud"]) {
    filter =
        [CIFilter filterWithName:@"CIColorMatrix"
                   keysAndValues:kCIInputImageKey, image, @"inputRVector",
                                 [CIVector vectorWithX:1.08 Y:0.02 Z:0.0 W:0.0],
                                 @"inputGVector",
                                 [CIVector vectorWithX:0.0 Y:1.03 Z:0.01 W:0.0],
                                 @"inputBVector",
                                 [CIVector vectorWithX:0.0 Y:0.0 Z:0.95 W:0.0],
                                 @"inputAVector",
                                 [CIVector vectorWithX:0.0 Y:0.0 Z:0.0 W:1.0],
                                 @"inputBiasVector",
                                 [CIVector vectorWithX:15.0 / 255.0
                                                     Y:8.0 / 255.0
                                                     Z:-4.0 / 255.0
                                                     W:0.0],
                                 nil];
  } else if ([_filter isEqualToString:@"snap_wanted_poster"]) {
    filter = [CIFilter
        filterWithName:@"CISepiaTone"
         keysAndValues:kCIInputImageKey, image, @"inputIntensity", @1.0, nil];
  }
  // Any unmapped color filter falls back to a slight color boost
  else if (![_filter containsString:@"snap_"] &&
           ![_filter containsString:@"glasses"] &&
           ![_filter containsString:@"hat"]) {
    filter = [CIFilter
        filterWithName:@"CIColorControls"
         keysAndValues:kCIInputImageKey, image, @"inputSaturation", @1.2, nil];
  }

  if (filter && filter.outputImage) {
    return filter.outputImage;
  }
  return image;
}

// CoreGraphics AR Overlays
- (CGImageRef)drawAROverlaysOnImage:(CGImageRef)cgImage {
  if ([_filter isEqualToString:@"none"]) {
    return CGImageRetain(cgImage);
  }

  BOOL needsFace = ![_filter isEqualToString:@"snap_day_stamp"] &&
                   ![_filter isEqualToString:@"snap_city_time"] &&
                   ![_filter isEqualToString:@"snap_heart_frame"] &&
                   ![_filter isEqualToString:@"snap_lens_verified"];

  if (needsFace && (!self.currentFaces || self.currentFaces.count == 0)) {
    return CGImageRetain(cgImage);
  }

  size_t width = CGImageGetWidth(cgImage);
  size_t height = CGImageGetHeight(cgImage);

  CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
  CGContextRef context = CGBitmapContextCreate(
      NULL, width, height, 8, 4 * width, colorSpace,
      kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
  CGColorSpaceRelease(colorSpace);
  if (!context)
    return CGImageRetain(cgImage);

  // Draw original image
  CGContextDrawImage(context, CGRectMake(0, 0, width, height), cgImage);

  // Helper block to get center point of a landmark region
  CGPoint (^getCenter)(VNFaceLandmarkRegion2D *, CGRect) =
      ^CGPoint(VNFaceLandmarkRegion2D *region, CGRect rect) {
        if (!region || region.pointCount == 0)
          return CGPointZero;
        CGFloat x = 0, y = 0;
        for (NSUInteger i = 0; i < region.pointCount; i++) {
          CGPoint p = region.normalizedPoints[i];
          x += p.x;
          y += p.y;
        }
        x /= region.pointCount;
        y /= region.pointCount;
        return CGPointMake(rect.origin.x + x * rect.size.width,
                           rect.origin.y + y * rect.size.height);
      };

  // Draw AR for each face
  for (VNFaceObservation *face in self.currentFaces) {
    CGRect boundingBox = face.boundingBox;
    CGRect faceRect = CGRectMake(
        boundingBox.origin.x * width, boundingBox.origin.y * height,
        boundingBox.size.width * width, boundingBox.size.height * height);

    CGPoint leftEye = getCenter(face.landmarks.leftEye, faceRect);
    CGPoint rightEye = getCenter(face.landmarks.rightEye, faceRect);
    CGPoint nose = getCenter(face.landmarks.nose, faceRect);

    // If eyes aren't detected, fallback
    if (leftEye.x == 0 || rightEye.x == 0)
      continue;

    CGFloat dx = rightEye.x - leftEye.x;
    CGFloat dy = rightEye.y - leftEye.y;
    CGFloat eyeDist = hypot(dx, dy);
    CGFloat rollAngle = face.roll ? [face.roll floatValue] : 0.0;

    if (eyeDist == 0)
      continue;

    CGContextSaveGState(context);

    // Face center anchor for rotation
    CGPoint faceCenter = CGPointMake((leftEye.x + rightEye.x) / 2.0,
                                     (leftEye.y + rightEye.y) / 2.0);
    CGContextTranslateCTM(context, faceCenter.x, faceCenter.y);
    CGContextRotateCTM(context, rollAngle);

    if ([_filter isEqualToString:@"bigHead"]) {
      CGFloat scaleFactor = 1.35;

      CGFloat headW = eyeDist * 2.8;
      CGFloat headH = eyeDist * 3.6;
      CGFloat clipW = headW * scaleFactor;
      CGFloat clipH = headH * scaleFactor;

      CGContextSaveGState(context);

      // Undo rotation so the copied background image draws straight
      CGContextRotateCTM(context, -rollAngle);

      CGContextBeginPath(context);
      // Oval shifted slightly up for forehead (+Y is up in iOS)
      CGContextAddEllipseInRect(
          context,
          CGRectMake(-clipW / 2.0, -clipH / 2.0 + eyeDist * 0.5, clipW, clipH));
      CGContextClip(context);

      CGContextScaleCTM(context, scaleFactor, scaleFactor);

      // Translate back so the original image aligns with the background
      CGContextTranslateCTM(context, -faceCenter.x, -faceCenter.y);
      CGContextDrawImage(context, CGRectMake(0, 0, width, height), cgImage);

      CGContextRestoreGState(context);
    } else if ([_filter isEqualToString:@"snap_spiderman"]) {
      CGContextSaveGState(context);

      // Clip to exact face contour
      CGContextBeginPath(context);
      VNFaceLandmarkRegion2D *contour = face.landmarks.faceContour;
      if (contour && contour.pointCount > 0) {
        CGPoint (^toLocal)(CGPoint) = ^CGPoint(CGPoint p) {
          CGFloat ax =
              (boundingBox.origin.x + p.x * boundingBox.size.width) * width;
          CGFloat ay =
              (boundingBox.origin.y + p.y * boundingBox.size.height) * height;
          return CGPointMake(ax - faceCenter.x, ay - faceCenter.y);
        };

        CGPoint firstPt = toLocal(contour.normalizedPoints[0]);
        CGContextMoveToPoint(context, firstPt.x, firstPt.y);
        for (int i = 1; i < contour.pointCount; i++) {
          CGPoint pt = toLocal(contour.normalizedPoints[i]);
          // Expand slightly outwards for the mask
          pt.x = pt.x * 1.05;
          pt.y = pt.y * 1.05;
          CGContextAddLineToPoint(context, pt.x, pt.y);
        }

        CGPoint lastPt =
            toLocal(contour.normalizedPoints[contour.pointCount - 1]);
        // Add dome for the top of the head
        CGContextAddCurveToPoint(
            context, lastPt.x * 1.05, lastPt.y + eyeDist * 2.2,
            firstPt.x * 1.05, firstPt.y + eyeDist * 2.2, firstPt.x, firstPt.y);
      } else {
        CGRect faceOval =
            CGRectMake(-eyeDist * 1.4, -eyeDist * 1.6 + eyeDist * 0.4,
                       eyeDist * 2.8, eyeDist * 3.8);
        CGContextAddEllipseInRect(context, faceOval);
      }
      CGContextClosePath(context);
      CGContextClip(context);

      // 1. Draw black base mask filling the face
      CGContextSetFillColorWithColor(context, [UIColor blackColor].CGColor);
      CGContextFillRect(context, CGRectMake(-eyeDist * 2.0, -eyeDist * 2.0,
                                            eyeDist * 4.0, eyeDist * 4.0));

      // 2. Draw white web pattern
      CGContextSetStrokeColorWithColor(context, [UIColor whiteColor].CGColor);
      CGContextSetLineWidth(context, eyeDist * 0.04);

      CGFloat webCx = 0;
      CGFloat webCy = -eyeDist * 0.12;
      int numRadials = 12;
      CGFloat maxRadius = eyeDist * 4.0;

      for (int i = 0; i < numRadials; i++) {
        CGFloat angle = (2 * M_PI * i) / numRadials;
        CGContextMoveToPoint(context, webCx, webCy);
        CGContextAddLineToPoint(context, webCx + cos(angle) * maxRadius,
                                webCy + sin(angle) * maxRadius);
      }
      CGContextStrokePath(context);

      int numRings = 6;
      for (int r = 1; r <= numRings; r++) {
        CGFloat radius = maxRadius * 0.14 * r;
        for (int i = 0; i <= numRadials; i++) {
          CGFloat angle1 = (2 * M_PI * i) / numRadials;
          CGFloat x1 = webCx + cos(angle1) * radius;
          CGFloat y1 = webCy + sin(angle1) * radius;
          if (i == 0) {
            CGContextMoveToPoint(context, x1, y1);
          } else {
            CGFloat anglePrev = (2 * M_PI * (i - 1)) / numRadials;
            CGFloat angleMid = (anglePrev + angle1) / 2.0;
            CGFloat ctrlRadius = radius * 0.86;
            CGFloat cx1 = webCx + cos(angleMid) * ctrlRadius;
            CGFloat cy1 = webCy + sin(angleMid) * ctrlRadius;
            CGContextAddQuadCurveToPoint(context, cx1, cy1, x1, y1);
          }
        }
        CGContextStrokePath(context);
      }

      // 3. Draw Spider-Man slanted eyes
      CGContextSetFillColorWithColor(context, [UIColor whiteColor].CGColor);
      CGContextSetStrokeColorWithColor(context, [UIColor blackColor].CGColor);
      CGContextSetLineWidth(context, eyeDist * 0.14);
      CGContextSetLineJoin(context, kCGLineJoinRound);
      CGContextSetLineCap(context, kCGLineCapRound);

      CGFloat lx = -eyeDist * 0.5;
      CGFloat ly = 0;

      UIBezierPath *leftEyePath = [UIBezierPath bezierPath];
      // Note: Y is up in iOS, so Android's Y offsets need to be inverted
      // (multiplied by -1)
      [leftEyePath
          moveToPoint:CGPointMake(lx + eyeDist * 0.32, ly - eyeDist * 0.10)];
      [leftEyePath addQuadCurveToPoint:CGPointMake(lx - 0.40 * eyeDist,
                                                   ly + 0.30 * eyeDist)
                          controlPoint:CGPointMake(lx - 0.05 * eyeDist,
                                                   ly + 0.25 * eyeDist)];
      [leftEyePath addQuadCurveToPoint:CGPointMake(lx - 0.50 * eyeDist,
                                                   ly - 0.15 * eyeDist)
                          controlPoint:CGPointMake(lx - 0.48 * eyeDist,
                                                   ly + 0.05 * eyeDist)];
      [leftEyePath addQuadCurveToPoint:CGPointMake(lx + 0.32 * eyeDist,
                                                   ly - 0.10 * eyeDist)
                          controlPoint:CGPointMake(lx - 0.20 * eyeDist,
                                                   ly - 0.35 * eyeDist)];
      [leftEyePath closePath];

      CGFloat rx = eyeDist * 0.5;
      CGFloat ry = 0;
      UIBezierPath *rightEyePath = [UIBezierPath bezierPath];
      [rightEyePath
          moveToPoint:CGPointMake(rx - eyeDist * 0.32, ry - eyeDist * 0.10)];
      [rightEyePath addQuadCurveToPoint:CGPointMake(rx + 0.40 * eyeDist,
                                                    ry + 0.30 * eyeDist)
                           controlPoint:CGPointMake(rx + 0.05 * eyeDist,
                                                    ry + 0.25 * eyeDist)];
      [rightEyePath addQuadCurveToPoint:CGPointMake(rx + 0.50 * eyeDist,
                                                    ry - 0.15 * eyeDist)
                           controlPoint:CGPointMake(rx + 0.48 * eyeDist,
                                                    ry + 0.05 * eyeDist)];
      [rightEyePath addQuadCurveToPoint:CGPointMake(rx - 0.32 * eyeDist,
                                                    ry - 0.10 * eyeDist)
                           controlPoint:CGPointMake(rx + 0.20 * eyeDist,
                                                    ry - 0.35 * eyeDist)];
      [rightEyePath closePath];

      CGContextAddPath(context, leftEyePath.CGPath);
      CGContextAddPath(context, rightEyePath.CGPath);
      CGContextDrawPath(context, kCGPathFillStroke);

      CGContextRestoreGState(context); // restore clip
    } else if ([_filter isEqualToString:@"dogEars"] ||
               [_filter isEqualToString:@"snap_icy_dalmatian"]) {
      // Both Dog and Snow Pup filters render as Dalmatian in Android
      BOOL isDalmatian = YES;

      // Flip Y axis to match Android coordinate system (where positive Y goes
      // down)
      CGContextScaleCTM(context, 1, -1);

      CGFloat earLocalY = -eyeDist * 1.45;
      CGFloat leftEarX = eyeDist * 0.60;
      CGFloat rightEarX = -eyeDist * 0.60;

      // Ear colors
      UIColor *earColor = [UIColor whiteColor];
      UIColor *innerColor = [UIColor colorWithRed:1.0
                                            green:0.8
                                             blue:0.84
                                            alpha:1.0];
      UIColor *borderColor = [UIColor colorWithRed:0.87
                                             green:0.87
                                              blue:0.87
                                             alpha:1.0];

#define DRAW_CIRCLE(cx, cy, r)                                                 \
  CGContextFillEllipseInRect(                                                  \
      context, CGRectMake((cx) - (r), (cy) - (r), (r) * 2, (r) * 2))

      // ── Left Floppy Ear ──
      UIBezierPath *leftEarPath = [UIBezierPath bezierPath];
      [leftEarPath
          moveToPoint:CGPointMake(leftEarX, earLocalY + eyeDist * 0.1)];
      [leftEarPath addCurveToPoint:CGPointMake(leftEarX + eyeDist * 0.70,
                                               earLocalY + eyeDist * 0.15)
                     controlPoint1:CGPointMake(leftEarX + eyeDist * 0.25,
                                               earLocalY - eyeDist * 0.18)
                     controlPoint2:CGPointMake(leftEarX + eyeDist * 0.55,
                                               earLocalY - eyeDist * 0.08)];
      [leftEarPath addCurveToPoint:CGPointMake(leftEarX + eyeDist * 0.50,
                                               earLocalY + eyeDist * 0.88)
                     controlPoint1:CGPointMake(leftEarX + eyeDist * 0.88,
                                               earLocalY + eyeDist * 0.45)
                     controlPoint2:CGPointMake(leftEarX + eyeDist * 0.82,
                                               earLocalY + eyeDist * 0.75)];
      [leftEarPath
          addCurveToPoint:CGPointMake(leftEarX, earLocalY + eyeDist * 0.25)
            controlPoint1:CGPointMake(leftEarX + eyeDist * 0.25,
                                      earLocalY + eyeDist * 0.80)
            controlPoint2:CGPointMake(leftEarX + eyeDist * 0.12,
                                      earLocalY + eyeDist * 0.45)];
      [leftEarPath closePath];

      CGContextSaveGState(context);
      CGContextAddPath(context, leftEarPath.CGPath);
      CGContextClip(context);
      CGContextSetFillColorWithColor(context, earColor.CGColor);
      CGContextFillRect(context, CGRectMake(-eyeDist * 3, -eyeDist * 3,
                                            eyeDist * 6, eyeDist * 6));

      UIBezierPath *leftInnerPath = [UIBezierPath bezierPath];
      [leftInnerPath moveToPoint:CGPointMake(leftEarX + eyeDist * 0.12,
                                             earLocalY + eyeDist * 0.22)];
      [leftInnerPath addCurveToPoint:CGPointMake(leftEarX + eyeDist * 0.40,
                                                 earLocalY + eyeDist * 0.70)
                       controlPoint1:CGPointMake(leftEarX + eyeDist * 0.35,
                                                 earLocalY + eyeDist * 0.28)
                       controlPoint2:CGPointMake(leftEarX + eyeDist * 0.48,
                                                 earLocalY + eyeDist * 0.52)];
      [leftInnerPath addCurveToPoint:CGPointMake(leftEarX + eyeDist * 0.06,
                                                 earLocalY + eyeDist * 0.28)
                       controlPoint1:CGPointMake(leftEarX + eyeDist * 0.28,
                                                 earLocalY + eyeDist * 0.70)
                       controlPoint2:CGPointMake(leftEarX + eyeDist * 0.15,
                                                 earLocalY + eyeDist * 0.52)];
      [leftInnerPath closePath];
      CGContextSetFillColorWithColor(context, innerColor.CGColor);
      CGContextAddPath(context, leftInnerPath.CGPath);
      CGContextFillPath(context);

      if (isDalmatian) {
        CGContextSetFillColorWithColor(context, [UIColor blackColor].CGColor);
        DRAW_CIRCLE(leftEarX + eyeDist * 0.22, earLocalY + eyeDist * 0.15,
                    eyeDist * 0.10);
        DRAW_CIRCLE(leftEarX + eyeDist * 0.45, earLocalY + eyeDist * 0.32,
                    eyeDist * 0.12);
        DRAW_CIRCLE(leftEarX + eyeDist * 0.58, earLocalY + eyeDist * 0.50,
                    eyeDist * 0.11);
        DRAW_CIRCLE(leftEarX + eyeDist * 0.35, earLocalY + eyeDist * 0.72,
                    eyeDist * 0.09);
        DRAW_CIRCLE(leftEarX + eyeDist * 0.12, earLocalY + eyeDist * 0.48,
                    eyeDist * 0.08);
      }
      CGContextRestoreGState(context);

      CGContextSetStrokeColorWithColor(context, borderColor.CGColor);
      CGContextSetLineWidth(context, eyeDist * 0.015);
      CGContextAddPath(context, leftEarPath.CGPath);
      CGContextStrokePath(context);

      // ── Right Floppy Ear ──
      UIBezierPath *rightEarPath = [UIBezierPath bezierPath];
      [rightEarPath
          moveToPoint:CGPointMake(rightEarX, earLocalY + eyeDist * 0.1)];
      [rightEarPath addCurveToPoint:CGPointMake(rightEarX - eyeDist * 0.70,
                                                earLocalY + eyeDist * 0.15)
                      controlPoint1:CGPointMake(rightEarX - eyeDist * 0.25,
                                                earLocalY - eyeDist * 0.18)
                      controlPoint2:CGPointMake(rightEarX - eyeDist * 0.55,
                                                earLocalY - eyeDist * 0.08)];
      [rightEarPath addCurveToPoint:CGPointMake(rightEarX - eyeDist * 0.50,
                                                earLocalY + eyeDist * 0.88)
                      controlPoint1:CGPointMake(rightEarX - eyeDist * 0.88,
                                                earLocalY + eyeDist * 0.45)
                      controlPoint2:CGPointMake(rightEarX - eyeDist * 0.82,
                                                earLocalY + eyeDist * 0.75)];
      [rightEarPath
          addCurveToPoint:CGPointMake(rightEarX, earLocalY + eyeDist * 0.25)
            controlPoint1:CGPointMake(rightEarX - eyeDist * 0.25,
                                      earLocalY + eyeDist * 0.80)
            controlPoint2:CGPointMake(rightEarX - eyeDist * 0.12,
                                      earLocalY + eyeDist * 0.45)];
      [rightEarPath closePath];

      CGContextSaveGState(context);
      CGContextAddPath(context, rightEarPath.CGPath);
      CGContextClip(context);
      CGContextSetFillColorWithColor(context, earColor.CGColor);
      CGContextFillRect(context, CGRectMake(-eyeDist * 3, -eyeDist * 3,
                                            eyeDist * 6, eyeDist * 6));

      UIBezierPath *rightInnerPath = [UIBezierPath bezierPath];
      [rightInnerPath moveToPoint:CGPointMake(rightEarX - eyeDist * 0.12,
                                              earLocalY + eyeDist * 0.22)];
      [rightInnerPath addCurveToPoint:CGPointMake(rightEarX - eyeDist * 0.40,
                                                  earLocalY + eyeDist * 0.70)
                        controlPoint1:CGPointMake(rightEarX - eyeDist * 0.35,
                                                  earLocalY + eyeDist * 0.28)
                        controlPoint2:CGPointMake(rightEarX - eyeDist * 0.48,
                                                  earLocalY + eyeDist * 0.52)];
      [rightInnerPath addCurveToPoint:CGPointMake(rightEarX - eyeDist * 0.06,
                                                  earLocalY + eyeDist * 0.28)
                        controlPoint1:CGPointMake(rightEarX - eyeDist * 0.28,
                                                  earLocalY + eyeDist * 0.70)
                        controlPoint2:CGPointMake(rightEarX - eyeDist * 0.15,
                                                  earLocalY + eyeDist * 0.52)];
      [rightInnerPath closePath];
      CGContextSetFillColorWithColor(context, innerColor.CGColor);
      CGContextAddPath(context, rightInnerPath.CGPath);
      CGContextFillPath(context);

      if (isDalmatian) {
        CGContextSetFillColorWithColor(context, [UIColor blackColor].CGColor);
        DRAW_CIRCLE(rightEarX - eyeDist * 0.22, earLocalY + eyeDist * 0.15,
                    eyeDist * 0.10);
        DRAW_CIRCLE(rightEarX - eyeDist * 0.45, earLocalY + eyeDist * 0.32,
                    eyeDist * 0.12);
        DRAW_CIRCLE(rightEarX - eyeDist * 0.58, earLocalY + eyeDist * 0.50,
                    eyeDist * 0.11);
        DRAW_CIRCLE(rightEarX - eyeDist * 0.35, earLocalY + eyeDist * 0.72,
                    eyeDist * 0.09);
        DRAW_CIRCLE(rightEarX - eyeDist * 0.12, earLocalY + eyeDist * 0.48,
                    eyeDist * 0.08);
      }
      CGContextRestoreGState(context);

      CGContextSetStrokeColorWithColor(context, borderColor.CGColor);
      CGContextAddPath(context, rightEarPath.CGPath);
      CGContextStrokePath(context);

      // ── Muzzle ──
      CGContextSaveGState(context);
      // Translate to nose base (downwards from eyes by eyeDist * 0.5)
      CGContextTranslateCTM(context, 0, eyeDist * 0.5);

      UIColor *muzzleColor = isDalmatian ? [UIColor whiteColor]
                                         : [UIColor colorWithRed:0.96
                                                           green:0.96
                                                            blue:0.94
                                                           alpha:1.0];
      CGContextSetFillColorWithColor(context, muzzleColor.CGColor);
      CGContextSetStrokeColorWithColor(
          context,
          [UIColor colorWithRed:0.88 green:0.88 blue:0.88 alpha:1.0].CGColor);
      CGContextSetLineWidth(context, eyeDist * 0.01);

      UIBezierPath *muzzlePath = [UIBezierPath bezierPath];
      [muzzlePath
          appendPath:[UIBezierPath
                         bezierPathWithOvalInRect:CGRectMake(-eyeDist * 0.15 -
                                                                 eyeDist * 0.20,
                                                             eyeDist * 0.06 -
                                                                 eyeDist * 0.20,
                                                             eyeDist * 0.40,
                                                             eyeDist * 0.40)]];
      [muzzlePath
          appendPath:[UIBezierPath
                         bezierPathWithOvalInRect:CGRectMake(eyeDist * 0.15 -
                                                                 eyeDist * 0.20,
                                                             eyeDist * 0.06 -
                                                                 eyeDist * 0.20,
                                                             eyeDist * 0.40,
                                                             eyeDist * 0.40)]];

      CGContextAddPath(context, muzzlePath.CGPath);
      CGContextFillPath(context);
      CGContextAddPath(context, muzzlePath.CGPath);
      CGContextStrokePath(context);

      CGContextSaveGState(context);
      CGContextAddPath(context, muzzlePath.CGPath);
      CGContextClip(context);

      if (isDalmatian) {
        CGContextSetFillColorWithColor(context, [UIColor blackColor].CGColor);
        DRAW_CIRCLE(-eyeDist * 0.22, eyeDist * 0.04, eyeDist * 0.04);
        DRAW_CIRCLE(-eyeDist * 0.10, eyeDist * 0.18, eyeDist * 0.03);
        DRAW_CIRCLE(eyeDist * 0.20, eyeDist * 0.08, eyeDist * 0.05);
        DRAW_CIRCLE(eyeDist * 0.12, eyeDist * 0.16, eyeDist * 0.03);
      }
      CGContextRestoreGState(context);

      // Whisker Dots
      CGContextSetFillColorWithColor(
          context,
          [UIColor colorWithRed:0.33 green:0.33 blue:0.33 alpha:1.0].CGColor);
      CGFloat dotR = eyeDist * 0.012;
      DRAW_CIRCLE(-eyeDist * 0.10, eyeDist * 0.05, dotR);
      DRAW_CIRCLE(-eyeDist * 0.16, eyeDist * 0.07, dotR);
      DRAW_CIRCLE(-eyeDist * 0.12, eyeDist * 0.11, dotR);

      DRAW_CIRCLE(eyeDist * 0.10, eyeDist * 0.05, dotR);
      DRAW_CIRCLE(eyeDist * 0.16, eyeDist * 0.07, dotR);
      DRAW_CIRCLE(eyeDist * 0.12, eyeDist * 0.11, dotR);

      // ── Nose ──
      CGContextSetFillColorWithColor(context, [UIColor blackColor].CGColor);
      CGContextFillEllipseInRect(context,
                                 CGRectMake(-eyeDist * 0.17, -eyeDist * 0.17,
                                            eyeDist * 0.34, eyeDist * 0.22));

      // Nose Shine
      CGContextSetFillColorWithColor(context, [UIColor whiteColor].CGColor);
      DRAW_CIRCLE(-eyeDist * 0.05, -eyeDist * 0.08, eyeDist * 0.025);

      CGContextRestoreGState(context); // Restore after muzzle translation

#undef DRAW_CIRCLE

    } else if ([_filter isEqualToString:@"catEars"] ||
               [_filter isEqualToString:@"snap_noir_kitty"]) {
      BOOL isNoir = [_filter isEqualToString:@"snap_noir_kitty"];
      UIColor *earColor =
          isNoir ? [UIColor colorWithRed:1.0
                                   green:0.65
                                    blue:0.79
                                   alpha:1.0] // Pink for Noir Kitty
                 : [UIColor colorWithRed:0.37
                                   green:0.37
                                    blue:0.37
                                   alpha:1.0]; // Gray for normal CatEars
      UIColor *innerColor =
          isNoir ? [UIColor colorWithRed:1.0 green:0.36 blue:0.54 alpha:1.0]
                 : [UIColor colorWithRed:0.94 green:0.59 blue:0.66 alpha:1.0];

      CGFloat cEarW = eyeDist * 0.65;
      CGFloat cEarH = eyeDist * 0.72;
      // Android: -eyeDist * 1.45. iOS Y-up: +eyeDist * 1.45
      CGFloat cEarLocalY = eyeDist * 1.45;

      void (^drawCatEar)(CGFloat, BOOL) = ^(CGFloat ex, BOOL isLeft) {
        CGFloat tilt = isLeft ? -8.0 * M_PI / 180.0 : 8.0 * M_PI / 180.0;
        CGContextSaveGState(context);
        CGContextTranslateCTM(context, ex, cEarLocalY);
        CGContextRotateCTM(context, -tilt);
        // Outer bezier ear shape
        // Android Y-down: top is negative, bottom is positive. iOS Y-up: invert
        // Ys
        UIBezierPath *outer = [UIBezierPath bezierPath];
        [outer moveToPoint:CGPointMake(-cEarW * 0.5, -cEarH * 0.35)];
        [outer addCurveToPoint:CGPointMake(0, cEarH * 0.75)
                 controlPoint1:CGPointMake(-cEarW * 0.45, cEarH * 0.45)
                 controlPoint2:CGPointMake(-cEarW * 0.05, cEarH * 0.75)];
        [outer addCurveToPoint:CGPointMake(cEarW * 0.5, -cEarH * 0.35)
                 controlPoint1:CGPointMake(cEarW * 0.05, cEarH * 0.75)
                 controlPoint2:CGPointMake(cEarW * 0.45, cEarH * 0.45)];
        [outer closePath];
        CGContextSetFillColorWithColor(context, earColor.CGColor);
        CGContextAddPath(context, outer.CGPath);
        CGContextFillPath(context);
        // Inner bezier pink center (Y inverted)
        UIBezierPath *inner = [UIBezierPath bezierPath];
        [inner moveToPoint:CGPointMake(-cEarW * 0.32, -cEarH * 0.28)];
        [inner addCurveToPoint:CGPointMake(0, cEarH * 0.52)
                 controlPoint1:CGPointMake(-cEarW * 0.28, cEarH * 0.32)
                 controlPoint2:CGPointMake(-cEarW * 0.03, cEarH * 0.52)];
        [inner addCurveToPoint:CGPointMake(cEarW * 0.32, -cEarH * 0.28)
                 controlPoint1:CGPointMake(cEarW * 0.03, cEarH * 0.52)
                 controlPoint2:CGPointMake(cEarW * 0.28, cEarH * 0.32)];
        [inner closePath];
        CGContextSetFillColorWithColor(context, innerColor.CGColor);
        CGContextAddPath(context, inner.CGPath);
        CGContextFillPath(context);
        // Sparkle dots inside ear
        NSArray *sparkles = @[
          [UIColor colorWithRed:1.0 green:0.78 blue:1.0 alpha:1.0],
          [UIColor colorWithRed:1.0 green:0.68 blue:0.68 alpha:1.0],
          [UIColor colorWithRed:0.99 green:1.0 blue:0.71 alpha:1.0],
          [UIColor whiteColor],
          [UIColor colorWithRed:1.0 green:0.44 blue:0.65 alpha:1.0]
        ];
        srand48(12345);
        for (int i = 0; i < 18; i++) {
          CGFloat rx = (drand48() - 0.5) * cEarW * 0.4;
          CGFloat ry = (drand48() - 0.5) * cEarH * 0.4 - cEarH * 0.1;
          CGFloat sz = eyeDist * (0.015 + drand48() * 0.02);
          UIColor *sc = sparkles[arc4random_uniform((uint32_t)sparkles.count)];
          CGContextSetFillColorWithColor(context, sc.CGColor);
          CGContextFillEllipseInRect(
              context, CGRectMake(rx - sz, ry - sz, sz * 2, sz * 2));
        }
        CGContextRestoreGState(context);
      };

      drawCatEar(-eyeDist * 0.60, YES);
      drawCatEar(eyeDist * 0.60, NO);

      // Nose Y from landmark or fallback (make sure Vision Y-axis matches)
      CGFloat cNoseY = (nose.x != 0) ? (nose.y - faceCenter.y) : -eyeDist * 0.2;
      CGFloat nw = eyeDist * 0.12, nh = eyeDist * 0.07;
      // Heart-shaped nose path (Android parity, Y inverted)
      UIBezierPath *nosePath = [UIBezierPath bezierPath];
      [nosePath moveToPoint:CGPointMake(0, cNoseY + nh * 0.2)];
      [nosePath addCurveToPoint:CGPointMake(-nw * 0.2, cNoseY - nh * 0.4)
                  controlPoint1:CGPointMake(-nw * 0.5, cNoseY + nh * 0.7)
                  controlPoint2:CGPointMake(-nw, cNoseY + nh * 0.1)];
      [nosePath addLineToPoint:CGPointMake(0, cNoseY - nh * 0.7)];
      [nosePath addLineToPoint:CGPointMake(nw * 0.2, cNoseY - nh * 0.4)];
      [nosePath addCurveToPoint:CGPointMake(0, cNoseY + nh * 0.2)
                  controlPoint1:CGPointMake(nw, cNoseY + nh * 0.1)
                  controlPoint2:CGPointMake(nw * 0.5, cNoseY + nh * 0.7)];
      [nosePath closePath];
      CGContextSetFillColorWithColor(
          context,
          [UIColor colorWithRed:1.0 green:0.52 blue:0.64 alpha:1.0].CGColor);
      CGContextAddPath(context, nosePath.CGPath);
      CGContextFillPath(context);
      // Nose highlight shine (Y inverted)
      CGContextSetFillColorWithColor(
          context, [UIColor colorWithWhite:1.0 alpha:0.86].CGColor);
      CGContextFillEllipseInRect(
          context,
          CGRectMake(-nw * 0.37, cNoseY + nh * 0.3, nw * 0.3, nw * 0.3));

      // 6 Whiskers - 3 per cheek (Android parity, Y inverted)
      CGContextSetStrokeColorWithColor(
          context, [UIColor colorWithWhite:1.0 alpha:0.78].CGColor);
      CGContextSetLineWidth(context, eyeDist * 0.015);
      CGContextSetLineCap(context, kCGLineCapRound);

      CGFloat leftStart = -eyeDist * 0.16;
      CGContextMoveToPoint(context, leftStart, cNoseY - eyeDist * 0.03);
      CGContextAddLineToPoint(context, -eyeDist * 0.65,
                              cNoseY + eyeDist * 0.05);
      CGContextStrokePath(context);
      CGContextMoveToPoint(context, leftStart, cNoseY - eyeDist * 0.06);
      CGContextAddLineToPoint(context, -eyeDist * 0.68,
                              cNoseY - eyeDist * 0.06);
      CGContextStrokePath(context);
      CGContextMoveToPoint(context, leftStart, cNoseY - eyeDist * 0.09);
      CGContextAddLineToPoint(context, -eyeDist * 0.65,
                              cNoseY - eyeDist * 0.17);
      CGContextStrokePath(context);

      CGFloat rightStart = eyeDist * 0.16;
      CGContextMoveToPoint(context, rightStart, cNoseY - eyeDist * 0.03);
      CGContextAddLineToPoint(context, eyeDist * 0.65, cNoseY + eyeDist * 0.05);
      CGContextStrokePath(context);
      CGContextMoveToPoint(context, rightStart, cNoseY - eyeDist * 0.06);
      CGContextAddLineToPoint(context, eyeDist * 0.68, cNoseY - eyeDist * 0.06);
      CGContextStrokePath(context);
      CGContextMoveToPoint(context, rightStart, cNoseY - eyeDist * 0.09);
      CGContextAddLineToPoint(context, eyeDist * 0.65, cNoseY - eyeDist * 0.17);
      CGContextStrokePath(context);

      // ── Floating Pink Hearts ──
      // In Android they bob using SystemClock.uptimeMillis(). We will use
      // NSProcessInfo
      NSTimeInterval time = [[NSProcessInfo processInfo] systemUptime] * 1000.0;
      NSArray *hearts = @[
        @[ @(-0.68), @(-0.42), @(0.09) ], @[ @(-0.35), @(-0.65), @(0.07) ],
        @[ @(0.35), @(-0.65), @(0.07) ], @[ @(0.68), @(-0.42), @(0.09) ],
        @[ @(-0.85), @(0.05), @(0.08) ], @[ @(0.85), @(0.05), @(0.08) ],
        @[ @(-0.55), @(0.42), @(0.06) ], @[ @(0.55), @(0.42), @(0.06) ]
      ];

      UIColor *heartFill = [UIColor colorWithRed:0xFF / 255.0
                                           green:0xA6 / 255.0
                                            blue:0xC9 / 255.0
                                           alpha:1.0];
      CGContextSetFillColorWithColor(context, heartFill.CGColor);
      CGContextSetStrokeColorWithColor(context, [UIColor whiteColor].CGColor);
      CGContextSetLineWidth(context, eyeDist * 0.012);
      CGContextSetLineJoin(context, kCGLineJoinRound);

      CGFloat faceW = face.boundingBox.size.width * width;
      CGFloat faceH = face.boundingBox.size.height * height;

      for (int i = 0; i < hearts.count; i++) {
        CGFloat rx = [hearts[i][0] floatValue];
        CGFloat ry = [hearts[i][1] floatValue]; // ry is in Android Y-down
        CGFloat sizeMult = [hearts[i][2] floatValue];

        CGFloat bobY = sin(time * 0.0028 + i * 1.2) * faceH * 0.03;
        CGFloat bobScale = 1.0 + sin(time * 0.0035 + i) * 0.12;

        // Invert Y for iOS
        CGFloat hCx = rx * faceW;
        CGFloat hCy = -(ry * faceH + bobY); // Flip Y

        CGFloat w = faceW * sizeMult * bobScale;
        CGFloat h = w * 1.05;

        CGContextSaveGState(context);
        CGContextTranslateCTM(context, hCx, hCy);
        CGFloat tiltAngle = sin(time * 0.002 + i) * 8.0 * M_PI / 180.0;
        CGContextRotateCTM(context, -tiltAngle); // CCW rotate

        UIBezierPath *hPath = [UIBezierPath bezierPath];
        // Android Y-down heart translated to iOS Y-up (all Y negated)
        [hPath moveToPoint:CGPointMake(0, -h * 0.35)];
        [hPath addCurveToPoint:CGPointMake(-w * 0.15, h * 0.45)
                 controlPoint1:CGPointMake(-w * 0.45, h * 0.1)
                 controlPoint2:CGPointMake(-w * 0.4, h * 0.45)];
        [hPath addCurveToPoint:CGPointMake(0, h * 0.1)
                 controlPoint1:CGPointMake(0, h * 0.45)
                 controlPoint2:CGPointMake(0, h * 0.1)];
        [hPath addCurveToPoint:CGPointMake(w * 0.15, h * 0.45)
                 controlPoint1:CGPointMake(0, h * 0.1)
                 controlPoint2:CGPointMake(0, h * 0.45)];
        [hPath addCurveToPoint:CGPointMake(0, -h * 0.35)
                 controlPoint1:CGPointMake(w * 0.4, h * 0.45)
                 controlPoint2:CGPointMake(w * 0.45, h * 0.1)];
        [hPath closePath];

        CGContextAddPath(context, hPath.CGPath);
        CGContextFillPath(context);
        CGContextAddPath(context, hPath.CGPath);
        CGContextStrokePath(context);

        CGContextRestoreGState(context);
      }

    } else if ([_filter hasPrefix:@"lipstick"]) {
      if (face.landmarks.outerLips && face.landmarks.innerLips) {
        UIColor *lipColor;
        if ([_filter isEqualToString:@"lipstick_red"]) {
          lipColor = [UIColor colorWithRed:0.85 green:0.1 blue:0.1 alpha:0.6];
        } else if ([_filter isEqualToString:@"lipstick_pink"]) {
          lipColor = [[UIColor systemPinkColor] colorWithAlphaComponent:0.55];
        } else if ([_filter isEqualToString:@"lipstick_coral"]) {
          lipColor = [UIColor colorWithRed:1.0 green:0.5 blue:0.3 alpha:0.6];
        } else if ([_filter isEqualToString:@"lipstick_plum"]) {
          lipColor = [UIColor colorWithRed:0.55 green:0.1 blue:0.4 alpha:0.65];
        } else {
          lipColor = [[UIColor redColor] colorWithAlphaComponent:0.5];
        }
        CGContextSaveGState(context);
        CGContextSetBlendMode(context, kCGBlendModeMultiply);
        CGContextSetFillColorWithColor(context, lipColor.CGColor);
        CGContextBeginPath(context);

        CGPoint (^toLocal)(CGPoint) = ^CGPoint(CGPoint p) {
          CGFloat ax =
              (boundingBox.origin.x + p.x * boundingBox.size.width) * width;
          CGFloat ay =
              (boundingBox.origin.y + p.y * boundingBox.size.height) * height;
          return CGPointMake(ax - faceCenter.x, ay - faceCenter.y);
        };

        for (int i = 0; i < face.landmarks.outerLips.pointCount; i++) {
          CGPoint p = face.landmarks.outerLips.normalizedPoints[i];
          CGPoint local = toLocal(p);
          if (i == 0)
            CGContextMoveToPoint(context, local.x, local.y);
          else
            CGContextAddLineToPoint(context, local.x, local.y);
        }
        CGContextClosePath(context);
        for (int i = 0; i < face.landmarks.innerLips.pointCount; i++) {
          CGPoint p = face.landmarks.innerLips.normalizedPoints[i];
          CGPoint local = toLocal(p);
          if (i == 0)
            CGContextMoveToPoint(context, local.x, local.y);
          else
            CGContextAddLineToPoint(context, local.x, local.y);
        }
        CGContextClosePath(context);
        CGContextEOFillPath(context);
        CGContextRestoreGState(context);
      }

    } else if ([_filter hasPrefix:@"glasses_"] ||
               [_filter isEqualToString:@"snap_neon_neon"]) {

      // ── Unified Android parity for ALL glasses
      // ───────────────────────────────
      CGFloat lensW = eyeDist * 0.82;
      CGFloat lensH = eyeDist * 0.62;
      CGFloat cornerRadius = lensH * 0.4;
      CGFloat frameWidth = eyeDist * 0.05;

      CGRect leftLens =
          CGRectMake(-eyeDist * 0.46 - lensW / 2, -lensH / 2, lensW, lensH);
      CGRect rightLens =
          CGRectMake(eyeDist * 0.46 - lensW / 2, -lensH / 2, lensW, lensH);

      BOOL isHeart = [_filter isEqualToString:@"glasses_heart"];
      BOOL isRetro = [_filter isEqualToString:@"glasses_retro"];
      BOOL isSport = [_filter isEqualToString:@"glasses_sport"] ||
                     [_filter isEqualToString:@"snap_neon_neon"];
      BOOL isSun = [_filter isEqualToString:@"glasses_sunglasses"] ||
                   [_filter isEqualToString:@"glasses_sun"];

      UIBezierPath *lPath;
      UIBezierPath *rPath;

      if (isHeart) {
        UIBezierPath * (^makeHeart)(CGRect) = ^UIBezierPath *(CGRect rect) {
          CGFloat w = rect.size.width;
          CGFloat h = rect.size.height;
          CGFloat cx = CGRectGetMidX(rect);
          CGFloat cy = CGRectGetMidY(rect);
          UIBezierPath *path = [UIBezierPath bezierPath];
          [path moveToPoint:CGPointMake(cx, cy - h * 0.35)];
          [path addCurveToPoint:CGPointMake(cx - w * 0.15, cy + h * 0.45)
                  controlPoint1:CGPointMake(cx - w * 0.45, cy + h * 0.1)
                  controlPoint2:CGPointMake(cx - w * 0.4, cy + h * 0.45)];
          [path addCurveToPoint:CGPointMake(cx, cy + h * 0.1)
                  controlPoint1:CGPointMake(cx, cy + h * 0.45)
                  controlPoint2:CGPointMake(cx, cy + h * 0.1)];
          [path addCurveToPoint:CGPointMake(cx + w * 0.15, cy + h * 0.45)
                  controlPoint1:CGPointMake(cx, cy + h * 0.1)
                  controlPoint2:CGPointMake(cx, cy + h * 0.45)];
          [path addCurveToPoint:CGPointMake(cx, cy - h * 0.35)
                  controlPoint1:CGPointMake(cx + w * 0.4, cy + h * 0.45)
                  controlPoint2:CGPointMake(cx + w * 0.45, cy + h * 0.1)];
          [path closePath];
          return path;
        };
        lPath = makeHeart(leftLens);
        rPath = makeHeart(rightLens);
      } else {
        lPath = [UIBezierPath bezierPathWithRoundedRect:leftLens
                                           cornerRadius:cornerRadius];
        rPath = [UIBezierPath bezierPathWithRoundedRect:rightLens
                                           cornerRadius:cornerRadius];
      }

      UIColor *armColor;
      if (isSport)
        armColor = [UIColor colorWithRed:0x39 / 255.0
                                   green:0xFF / 255.0
                                    blue:0x14 / 255.0
                                   alpha:1.0];
      else if (isHeart)
        armColor = [UIColor colorWithRed:0xFF / 255.0
                                   green:0x2a / 255.0
                                    blue:0x2a / 255.0
                                   alpha:1.0];
      else if (isRetro)
        armColor = [UIColor colorWithRed:0xFF / 255.0
                                   green:0xFF / 255.0
                                    blue:0xFF / 255.0
                                   alpha:1.0];
      else
        armColor = [UIColor colorWithRed:0x1c / 255.0
                                   green:0x1c / 255.0
                                    blue:0x1e / 255.0
                                   alpha:1.0];

      CGContextSetStrokeColorWithColor(context, armColor.CGColor);
      CGContextSetLineWidth(context, frameWidth * 0.85);
      CGContextSetLineCap(context, kCGLineCapRound);

      // Arms
      VNFaceLandmarkRegion2D *contour = face.landmarks.faceContour;
      CGPoint leftArmEnd, rightArmEnd;
      if (contour && contour.pointCount >= 2) {
        CGPoint (^toLocal)(CGPoint) = ^CGPoint(CGPoint p) {
          CGFloat ax =
              (boundingBox.origin.x + p.x * boundingBox.size.width) * width;
          CGFloat ay =
              (boundingBox.origin.y + p.y * boundingBox.size.height) * height;
          return CGPointMake(ax - faceCenter.x, ay - faceCenter.y);
        };

        // Determine which point is left vs right
        CGPoint p0 = toLocal(contour.normalizedPoints[0]);
        CGPoint p1 = toLocal(contour.normalizedPoints[contour.pointCount - 1]);
        CGPoint pLeft = (p0.x < p1.x) ? p0 : p1;
        CGPoint pRight = (p0.x < p1.x) ? p1 : p0;

        CGFloat cosR = cos(-rollAngle);
        CGFloat sinR = sin(-rollAngle);

        CGFloat localLx = pLeft.x * cosR - pLeft.y * sinR;
        CGFloat localLy = pLeft.x * sinR + pLeft.y * cosR;

        CGFloat localRx = pRight.x * cosR - pRight.y * sinR;
        CGFloat localRy = pRight.x * sinR + pRight.y * cosR;

        leftArmEnd = CGPointMake(localLx, localLy + eyeDist * 0.25);
        rightArmEnd = CGPointMake(localRx, localRy + eyeDist * 0.25);
      } else {
        leftArmEnd = CGPointMake(-eyeDist * 1.25, eyeDist * 0.15);
        rightArmEnd = CGPointMake(eyeDist * 1.25, eyeDist * 0.15);
      }

      CGContextMoveToPoint(context, CGRectGetMinX(leftLens), 0);
      CGContextAddLineToPoint(context, leftArmEnd.x, leftArmEnd.y);
      CGContextStrokePath(context);

      CGContextMoveToPoint(context, CGRectGetMaxX(rightLens), 0);
      CGContextAddLineToPoint(context, rightArmEnd.x, rightArmEnd.y);
      CGContextStrokePath(context);

      // Bridge
      CGFloat bridgeSideY = lensH * 0.05;
      CGFloat bridgeMidY = lensH * 0.12;
      CGContextSetLineWidth(context, frameWidth * 0.8);
      CGContextMoveToPoint(context, CGRectGetMaxX(leftLens), bridgeSideY);
      CGContextAddQuadCurveToPoint(context, 0, bridgeMidY,
                                   CGRectGetMinX(rightLens), bridgeSideY);
      CGContextStrokePath(context);

      // Glass Lens Fill Gradients
      NSArray *lensColors;
      if (isSun) {
        lensColors = @[
          (__bridge id)[UIColor colorWithRed:0x11 / 255.0
                                       green:0x11 / 255.0
                                        blue:0x13 / 255.0
                                       alpha:0xFA / 255.0]
              .CGColor,
          (__bridge id)[UIColor colorWithRed:0x22 / 255.0
                                       green:0x22 / 255.0
                                        blue:0x28 / 255.0
                                       alpha:0xD0 / 255.0]
              .CGColor
        ];
      } else if (isSport) {
        lensColors = @[
          (__bridge id)[UIColor colorWithRed:0x00
                                       green:0xE5 / 255.0
                                        blue:1.0
                                       alpha:0xCC / 255.0]
              .CGColor,
          (__bridge id)[UIColor colorWithRed:0xBD / 255.0
                                       green:0.0
                                        blue:1.0
                                       alpha:0xCC / 255.0]
              .CGColor
        ];
      } else if (isHeart) {
        lensColors = @[
          (__bridge id)[UIColor colorWithRed:0xFF / 255.0
                                       green:0x4d / 255.0
                                        blue:0x6d / 255.0
                                       alpha:0x99 / 255.0]
              .CGColor,
          (__bridge id)[UIColor colorWithRed:0xFF / 255.0
                                       green:0xb3 / 255.0
                                        blue:0xc1 / 255.0
                                       alpha:0x40 / 255.0]
              .CGColor
        ];
      } else {
        // Classic & Retro use same lens
        lensColors = @[
          (__bridge id)[UIColor colorWithRed:0x18 / 255.0
                                       green:0x18 / 255.0
                                        blue:0x1C / 255.0
                                       alpha:0x8C / 255.0]
              .CGColor,
          (__bridge id)[UIColor colorWithRed:0x40 / 255.0
                                       green:0x40 / 255.0
                                        blue:0x48 / 255.0
                                       alpha:0x50 / 255.0]
              .CGColor
        ];
      }

      CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
      CGFloat locs[] = {0.0, 1.0};
      CGGradientRef lensGrad =
          CGGradientCreateWithColors(cs, (__bridge CFArrayRef)lensColors, locs);

      void (^drawLens)(UIBezierPath *, CGRect) =
          ^(UIBezierPath *path, CGRect rect) {
            CGContextSaveGState(context);
            CGContextAddPath(context, path.CGPath);
            CGContextClip(context);

            if (isSport) {
              CGContextDrawLinearGradient(
                  context, lensGrad,
                  CGPointMake(CGRectGetMinX(rect), CGRectGetMaxY(rect)),
                  CGPointMake(CGRectGetMaxX(rect), CGRectGetMinY(rect)), 0);
            } else {
              CGContextDrawLinearGradient(
                  context, lensGrad,
                  CGPointMake(CGRectGetMinX(rect), CGRectGetMaxY(rect)),
                  CGPointMake(CGRectGetMinX(rect), CGRectGetMinY(rect)), 0);
            }
            CGContextRestoreGState(context);
          };

      drawLens(lPath, leftLens);
      drawLens(rPath, rightLens);

      // Frame strokes (gradient)
      NSArray *frameColorsArr;
      if (isSport) {
        frameColorsArr = @[
          (__bridge id)[UIColor colorWithRed:0x39 / 255.0
                                       green:0xFF / 255.0
                                        blue:0x14 / 255.0
                                       alpha:1.0]
              .CGColor,
          (__bridge id)[UIColor colorWithRed:0.0
                                       green:0xE5 / 255.0
                                        blue:1.0
                                       alpha:1.0]
              .CGColor
        ];
      } else if (isHeart) {
        frameColorsArr = @[
          (__bridge id)[UIColor colorWithRed:0xFF / 255.0
                                       green:0x2A / 255.0
                                        blue:0x2A / 255.0
                                       alpha:1.0]
              .CGColor,
          (__bridge id)[UIColor colorWithRed:0xFF / 255.0
                                       green:0x8A / 255.0
                                        blue:0x8A / 255.0
                                       alpha:1.0]
              .CGColor
        ];
      } else if (isRetro) {
        frameColorsArr = @[
          (__bridge id)[UIColor colorWithRed:1.0 green:1.0 blue:1.0 alpha:1.0]
              .CGColor,
          (__bridge id)[UIColor colorWithRed:0xD4 / 255.0
                                       green:0xAF / 255.0
                                        blue:0x37 / 255.0
                                       alpha:1.0]
              .CGColor
        ];
      } else {
        frameColorsArr = @[
          (__bridge id)[UIColor colorWithRed:0x2C / 255.0
                                       green:0x2C / 255.0
                                        blue:0x2E / 255.0
                                       alpha:1.0]
              .CGColor,
          (__bridge id)[UIColor colorWithRed:0x0A / 255.0
                                       green:0x0A / 255.0
                                        blue:0x0B / 255.0
                                       alpha:1.0]
              .CGColor
        ];
      }

      CGGradientRef frameGrad = CGGradientCreateWithColors(
          cs, (__bridge CFArrayRef)frameColorsArr, locs);
      CGContextSetLineWidth(context, frameWidth);
      CGContextSetLineJoin(context, kCGLineJoinRound);

      CGContextSaveGState(context);
      CGContextAddPath(context, lPath.CGPath);
      CGContextReplacePathWithStrokedPath(context);
      CGContextClip(context);
      CGContextDrawLinearGradient(context, frameGrad,
                                  CGPointMake(0, CGRectGetMaxY(leftLens)),
                                  CGPointMake(0, CGRectGetMinY(leftLens)), 0);
      CGContextRestoreGState(context);

      CGContextSaveGState(context);
      CGContextAddPath(context, rPath.CGPath);
      CGContextReplacePathWithStrokedPath(context);
      CGContextClip(context);
      CGContextDrawLinearGradient(context, frameGrad,
                                  CGPointMake(0, CGRectGetMaxY(rightLens)),
                                  CGPointMake(0, CGRectGetMinY(rightLens)), 0);
      CGContextRestoreGState(context);
      CGGradientRelease(frameGrad);

      // Glare highlights
      CGContextSetFillColorWithColor(
          context, [UIColor colorWithWhite:1.0 alpha:0.33].CGColor);
      if (isHeart) {
        CGFloat hw = lensW * 0.08 * 2.0;
        CGContextFillEllipseInRect(
            context, CGRectMake(CGRectGetMidX(leftLens) - lensW * 0.18 - hw / 2,
                                CGRectGetMidY(leftLens) + lensH * 0.22 - hw / 2,
                                hw, hw));
        CGContextFillEllipseInRect(
            context,
            CGRectMake(CGRectGetMidX(rightLens) - lensW * 0.18 - hw / 2,
                       CGRectGetMidY(rightLens) + lensH * 0.22 - hw / 2, hw,
                       hw));
      } else {
        CGFloat hw = lensW * 0.22, hh = lensH * 0.50;
        CGFloat lhx = CGRectGetMinX(leftLens) + lensW * 0.28;
        CGFloat lhy = CGRectGetMaxY(leftLens) - lensH * 0.32;
        CGContextFillEllipseInRect(
            context, CGRectMake(lhx - hw / 2, lhy - hh / 2, hw, hh));

        CGFloat rhx = CGRectGetMinX(rightLens) + lensW * 0.28;
        CGFloat rhy = CGRectGetMaxY(rightLens) - lensH * 0.32;
        CGContextFillEllipseInRect(
            context, CGRectMake(rhx - hw / 2, rhy - hh / 2, hw, hh));
      }

      CGColorSpaceRelease(cs);

    } else if ([_filter hasPrefix:@"hat_"] ||
               [_filter isEqualToString:@"flowerCrown"] ||
               [_filter isEqualToString:@"golden_crown"] ||
               [_filter isEqualToString:@"snap_sunset_cowboy"] ||
               [_filter isEqualToString:@"snap_retro_bloom"]) {
      if ([_filter isEqualToString:@"hat_wizard"]) {
        CGContextSetFillColorWithColor(context, [UIColor purpleColor].CGColor);
        CGContextBeginPath(context);
        CGContextMoveToPoint(context, -eyeDist * 1.5, eyeDist * 1.55);
        CGContextAddLineToPoint(context, eyeDist * 1.5, eyeDist * 1.55);
        CGContextAddLineToPoint(context, 0, eyeDist * 4.05);
        CGContextClosePath(context);
        CGContextFillPath(context);
      } else if ([_filter isEqualToString:@"hat_santa"]) {
        CGContextSetFillColorWithColor(context, [UIColor redColor].CGColor);
        CGContextBeginPath(context);
        CGContextMoveToPoint(context, -eyeDist * 1.2, eyeDist * 1.35);
        CGContextAddLineToPoint(context, eyeDist * 1.2, eyeDist * 1.35);
        CGContextAddLineToPoint(context, eyeDist * 0.8, eyeDist * 2.85);
        CGContextAddLineToPoint(context, eyeDist * 1.8, eyeDist * 2.35);
        CGContextClosePath(context);
        CGContextFillPath(context);
        CGContextSetFillColorWithColor(context, [UIColor whiteColor].CGColor);
        CGContextFillEllipseInRect(context,
                                   CGRectMake(eyeDist * 1.6, eyeDist * 2.15,
                                              eyeDist * 0.6, eyeDist * 0.6));
        CGContextFillRect(context, CGRectMake(-eyeDist * 1.3, eyeDist * 1.25,
                                              eyeDist * 2.6, eyeDist * 0.4));
      } else if ([_filter isEqualToString:@"hat_cowboy"] ||
                 [_filter isEqualToString:@"snap_sunset_cowboy"]) {
        // ── Exact Android cowboy hat — Y-axis correctly converted
        // ────────────── Android Y-down: brimY = centerY - 0.82*eyeDist (above
        // eyes, smaller Y = higher on screen) iOS Y-up:  brimY = +0.82*eyeDist
        // (above eyes, larger Y = higher on screen) Key rule: Android (brimY +
        // X) = below brimY in Y-down → iOS (brimY - X)
        //           Android (brimY - X) = above brimY in Y-down → iOS (brimY +
        //           X)
        CGFloat brimY = eyeDist * 1.45; // reference level (where brim sits)
        CGFloat brimX = 0;

        CGFloat crownW = eyeDist * 1.8;
        CGFloat crownH = eyeDist * 1.4;
        // Android crownTopY = brimY - crownH (above brimY in Y-down)
        // iOS: above brimY = brimY + crownH
        CGFloat crownTopY = brimY + crownH;

        // ── Crown path
        // ───────────────────────────────────────────────────────── Android
        // start: brimY + crownH*0.08  (below brimY in Y-down) → iOS: brimY -
        // crownH*0.08
        UIBezierPath *crownPath = [UIBezierPath bezierPath];
        [crownPath moveToPoint:CGPointMake(brimX - crownW * 0.44,
                                           brimY - crownH * 0.08)];
        // CP1: brimY - crownH*0.5 (above brimY in Android Y-down) → iOS: brimY
        // + crownH*0.5 CP2: crownTopY - crownH*0.05 (above crownTopY in
        // Android) → iOS: crownTopY + crownH*0.05
        [crownPath addCurveToPoint:CGPointMake(brimX - crownW * 0.22, crownTopY)
                     controlPoint1:CGPointMake(brimX - crownW * 0.48,
                                               brimY + crownH * 0.5)
                     controlPoint2:CGPointMake(brimX - crownW * 0.35,
                                               crownTopY + crownH * 0.05)];
        // Android quadTo control: crownTopY + crownH*0.12 (below crownTopY in
        // Y-down) → iOS: crownTopY - crownH*0.12
        [crownPath
            addQuadCurveToPoint:CGPointMake(brimX + crownW * 0.22, crownTopY)
                   controlPoint:CGPointMake(brimX, crownTopY - crownH * 0.12)];
        // CP1: crownTopY + crownH*0.05 ✓ (above crownTopY)
        // CP2: brimY - crownH*0.5 ✓ (above brimY)
        // End: brimY - crownH*0.08 ✓ (below brimY)
        [crownPath addCurveToPoint:CGPointMake(brimX + crownW * 0.44,
                                               brimY - crownH * 0.08)
                     controlPoint1:CGPointMake(brimX + crownW * 0.35,
                                               crownTopY + crownH * 0.05)
                     controlPoint2:CGPointMake(brimX + crownW * 0.48,
                                               brimY + crownH * 0.5)];
        // Android bottom control: brimY + crownH*0.16 (below brimY in Y-down) →
        // iOS: brimY - crownH*0.16
        [crownPath
            addQuadCurveToPoint:CGPointMake(brimX - crownW * 0.44,
                                            brimY - crownH * 0.08)
                   controlPoint:CGPointMake(brimX, brimY - crownH * 0.16)];
        [crownPath closePath];

        // Crown gradient: #a0522d → #8b5a2b → #5c2e0b
        CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
        CGFloat locs3[] = {0.0, 0.5, 1.0};
        NSArray *crownColors = @[
          (__bridge id)[UIColor colorWithRed:0xa0 / 255.0
                                       green:0x52 / 255.0
                                        blue:0x2d / 255.0
                                       alpha:1.0]
              .CGColor,
          (__bridge id)[UIColor colorWithRed:0x8b / 255.0
                                       green:0x5a / 255.0
                                        blue:0x2b / 255.0
                                       alpha:1.0]
              .CGColor,
          (__bridge id)[UIColor colorWithRed:0x5c / 255.0
                                       green:0x2e / 255.0
                                        blue:0x0b / 255.0
                                       alpha:1.0]
              .CGColor
        ];
        CGGradientRef crownGrad = CGGradientCreateWithColors(
            cs, (__bridge CFArrayRef)crownColors, locs3);
        CGContextSaveGState(context);
        CGContextAddPath(context, crownPath.CGPath);
        CGContextClip(context);
        CGContextDrawLinearGradient(
            context, crownGrad, CGPointMake(brimX, crownTopY),
            CGPointMake(brimX, brimY - crownH * 0.08), 0);
        CGContextRestoreGState(context);
        CGGradientRelease(crownGrad);

        // ── Hatband: dark strip at crown base
        // ───────────────────────────────── Android: brimY+crownH*0.07 (below
        // brimY in Y-down) → iOS: brimY-crownH*0.07
        UIBezierPath *bandPath = [UIBezierPath bezierPath];
        [bandPath moveToPoint:CGPointMake(brimX - crownW * 0.43,
                                          brimY - crownH * 0.07)];
        [bandPath
            addQuadCurveToPoint:CGPointMake(brimX + crownW * 0.43,
                                            brimY - crownH * 0.07)
                   controlPoint:CGPointMake(brimX, brimY - crownH * 0.14)];
        [bandPath addLineToPoint:CGPointMake(brimX + crownW * 0.43,
                                             brimY - crownH * 0.15)];
        [bandPath
            addQuadCurveToPoint:CGPointMake(brimX - crownW * 0.43,
                                            brimY - crownH * 0.15)
                   controlPoint:CGPointMake(brimX, brimY - crownH * 0.22)];
        [bandPath closePath];
        CGContextSetFillColorWithColor(context,
                                       [UIColor colorWithRed:0x2a / 255.0
                                                       green:0x15 / 255.0
                                                        blue:0x08 / 255.0
                                                       alpha:1.0]
                                           .CGColor);
        CGContextAddPath(context, bandPath.CGPath);
        CGContextFillPath(context);

        // ── Brim
        // ──────────────────────────────────────────────────────────────
        // Android brimW = 2.8*eyeDist, brimH = 0.42*eyeDist
        // Android brim moveTo: (brimX-brimW/2, brimY-brimH*0.4)  → iOS:
        // (brimX-brimW/2, brimY+brimH*0.4) Android top-arc control:
        // brimY+brimH*0.35 (below, dips down) → iOS: brimY-brimH*0.35 Android
        // bottom: brimY+brimH*0.75 → iOS: brimY-brimH*0.75
        CGFloat brimW2 = eyeDist * 2.8;
        CGFloat brimH2 = eyeDist * 0.42;
        UIBezierPath *brimPath = [UIBezierPath bezierPath];
        // Top edge of brim (above brimY)
        [brimPath
            moveToPoint:CGPointMake(brimX - brimW2 / 2, brimY + brimH2 * 0.4)];
        // Top arc: dips DOWN in middle (control at brimY - brimH*0.35 = below
        // brimY in iOS)
        [brimPath
            addQuadCurveToPoint:CGPointMake(brimX + brimW2 / 2,
                                            brimY + brimH2 * 0.4)
                   controlPoint:CGPointMake(brimX, brimY - brimH2 * 0.35)];
        // Right side down to brimY level
        [brimPath
            addQuadCurveToPoint:CGPointMake(brimX + brimW2 / 2, brimY)
                   controlPoint:CGPointMake(brimX + brimW2 / 2 + eyeDist * 0.08,
                                            brimY + brimH2 * 0.1)];
        // Bottom arc (below brimY: brimY - brimH*0.75)
        [brimPath
            addQuadCurveToPoint:CGPointMake(brimX - brimW2 / 2, brimY)
                   controlPoint:CGPointMake(brimX, brimY - brimH2 * 0.75)];
        // Left side back up
        [brimPath
            addQuadCurveToPoint:CGPointMake(brimX - brimW2 / 2,
                                            brimY + brimH2 * 0.4)
                   controlPoint:CGPointMake(brimX - brimW2 / 2 - eyeDist * 0.08,
                                            brimY + brimH2 * 0.1)];
        [brimPath closePath];

        NSArray *brimColors = @[
          (__bridge id)[UIColor colorWithRed:0x70 / 255.0
                                       green:0x36 / 255.0
                                        blue:0x12 / 255.0
                                       alpha:1.0]
              .CGColor,
          (__bridge id)[UIColor colorWithRed:0x8b / 255.0
                                       green:0x5a / 255.0
                                        blue:0x2b / 255.0
                                       alpha:1.0]
              .CGColor,
          (__bridge id)[UIColor colorWithRed:0x5c / 255.0
                                       green:0x2e / 255.0
                                        blue:0x0b / 255.0
                                       alpha:1.0]
              .CGColor
        ];
        CGFloat locs3b[] = {0.0, 0.5, 1.0};
        CGGradientRef brimGrad = CGGradientCreateWithColors(
            cs, (__bridge CFArrayRef)brimColors, locs3b);
        CGContextSaveGState(context);
        CGContextAddPath(context, brimPath.CGPath);
        CGContextClip(context);
        CGContextDrawLinearGradient(context, brimGrad,
                                    CGPointMake(brimX - brimW2 / 2, brimY),
                                    CGPointMake(brimX + brimW2 / 2, brimY), 0);
        CGContextRestoreGState(context);
        CGGradientRelease(brimGrad);
        CGColorSpaceRelease(cs);
      } else if ([_filter isEqualToString:@"flowerCrown"] ||
                 [_filter isEqualToString:@"snap_retro_bloom"]) {
        // ── Exact Android flower crown port
        // ────────────────────────────────────
        BOOL isGold = [_filter isEqualToString:@"snap_retro_bloom"];

        NSArray *hexColors =
            isGold ? @[ @0xffe066, @0xffb700, @0xffa000, @0xffc300, @0xffd700 ]
                   : @[ @0xd65db1, @0xff9671, @0xf9f871, @0xffc75f, @0xff6f91 ];

        int centerHex = isGold ? 0xff5722 : 0xf5c542;
        UIColor *centerColor =
            [UIColor colorWithRed:((centerHex >> 16) & 0xFF) / 255.0
                            green:((centerHex >> 8) & 0xFF) / 255.0
                             blue:(centerHex & 0xFF) / 255.0
                            alpha:1.0];

        // bandY is above eyes. In Android Y-down it was min(eye.y) -
        // 1.1*eyeDist In iOS Y-up, above eyes is positive Y
        CGFloat bandY = eyeDist * 1.4;
        CGFloat flowerSize = eyeDist * 0.32;
        CGFloat centerX = 0; // already centered via faceCenter translation

        for (int i = -2; i <= 2; i++) {
          CGFloat fx = centerX + i * flowerSize * 1.3;
          // Android: fy = bandY + abs(i)*... (plus means lower on screen)
          // iOS: lower on screen means minus
          CGFloat fy = bandY - fabs((float)i) * flowerSize * 0.25;

          int colorHex = [hexColors[(i + 2) % 5] intValue];
          UIColor *petalColor =
              [UIColor colorWithRed:((colorHex >> 16) & 0xFF) / 255.0
                              green:((colorHex >> 8) & 0xFF) / 255.0
                               blue:(colorHex & 0xFF) / 255.0
                              alpha:1.0];

          // Draw 5 petals
          CGContextSetFillColorWithColor(context, petalColor.CGColor);
          for (int p = 0; p < 5; p++) {
            CGFloat angle = p * 2.0 * M_PI / 5.0;
            CGFloat px = fx + cos(angle) * flowerSize * 0.55;
            CGFloat py = fy + sin(angle) * flowerSize * 0.55;

            CGFloat petalRadius = flowerSize * 0.4;
            CGContextFillEllipseInRect(
                context, CGRectMake(px - petalRadius, py - petalRadius,
                                    petalRadius * 2, petalRadius * 2));
          }

          // Draw center
          CGContextSetFillColorWithColor(context, centerColor.CGColor);
          CGFloat centerRadius = flowerSize * 0.32;
          CGContextFillEllipseInRect(
              context, CGRectMake(fx - centerRadius, fy - centerRadius,
                                  centerRadius * 2, centerRadius * 2));
        }

      } else if ([_filter isEqualToString:@"golden_crown"]) {
        CGContextSetFillColorWithColor(context,
                                       [UIColor systemYellowColor].CGColor);
        CGContextBeginPath(context);
        CGContextMoveToPoint(context, -eyeDist, eyeDist * 1.0);
        CGContextAddLineToPoint(context, eyeDist, eyeDist * 1.0);
        CGContextAddLineToPoint(context, eyeDist * 1.2, eyeDist * 2.0);
        CGContextAddLineToPoint(context, eyeDist * 0.5, eyeDist * 1.5);
        CGContextAddLineToPoint(context, 0, eyeDist * 2.2);
        CGContextAddLineToPoint(context, -eyeDist * 0.5, eyeDist * 1.5);
        CGContextAddLineToPoint(context, -eyeDist * 1.2, eyeDist * 2.0);
        CGContextClosePath(context);
        CGContextFillPath(context);
      }

    } else if ([_filter isEqualToString:@"snap_butterflies"]) {
      CGFloat faceW = faceRect.size.width;
      CGFloat faceH = faceRect.size.height;
      // In iOS CGBitmapContext, Y points UP.
      // Top of the face relative to faceCenter is positive.
      CGFloat cx = 0.0;
      CGFloat foreheadY = faceH * 0.45;

      CGFloat time = [[NSProcessInfo processInfo] systemUptime] * 1000.0;
      CGFloat floatPhase = time / 1400.0;

      CGFloat butterflies[16][3] = {
          {-0.45, -0.25, 1.0}, {-0.25, -0.32, 0.9}, {0.00, -0.36, 1.1},
          {0.25, -0.32, 0.9},  {0.45, -0.25, 1.0},  {-0.55, -0.05, 0.8},
          {-0.35, -0.10, 1.0}, {-0.12, -0.15, 0.9}, {0.12, -0.15, 0.9},
          {0.35, -0.10, 1.0},  {0.55, -0.05, 0.8},  {-0.40, 0.10, 0.7},
          {-0.20, 0.05, 0.8},  {0.00, 0.02, 1.0},   {0.20, 0.05, 0.8},
          {0.40, 0.10, 0.7}};

      for (int i = 0; i < 16; i++) {
        CGFloat rx = butterflies[i][0];
        CGFloat ry = butterflies[i][1];
        CGFloat baseScale = butterflies[i][2];

        CGFloat risePhase = fmod(floatPhase + i * 0.065, 1.0);
        CGFloat rise = risePhase * faceH * 0.16;
        CGFloat floatX = cos(floatPhase * 0.5 + i * 0.7) * faceW * 0.025;
        CGFloat bobY = sin(i * 0.8 + floatPhase * 0.6) * faceH * 0.035;

        // Since Y points UP in iOS, we invert the negative Android Y offsets:
        // -ry makes the negative Android offset positive (UP).
        // +rise moves it UP.
        // -bobY maps Android's downward bob to iOS's downward bob.
        CGFloat bCx = cx + rx * faceW + floatX;
        CGFloat bCy = foreheadY - ry * faceH - bobY + rise;
        CGFloat bSize = faceW * 0.08 * baseScale;

        CGFloat flutterScale = 0.25 + 0.75 * fabs(sin(time * 0.018 + i * 1.3));

        CGFloat alpha =
            fmax(0.0, fmin(1.0, (240.0 * (1.0 - risePhase)) / 255.0));

        CGContextSaveGState(context);
        CGFloat tilt = sin(time * 0.005 + i) * 15.0 * M_PI / 180.0;
        CGContextTranslateCTM(context, bCx, bCy);
        CGContextRotateCTM(context, tilt);

        CGContextBeginPath(context);
        CGContextMoveToPoint(context, 0, 0);
        CGContextAddCurveToPoint(context, -bSize * 0.9 * flutterScale,
                                 -bSize * 0.7, -bSize * 1.1 * flutterScale,
                                 -bSize * 0.1, -bSize * 0.1 * flutterScale,
                                 bSize * 0.1);
        CGContextAddCurveToPoint(context, -bSize * 0.8 * flutterScale,
                                 bSize * 0.4, -bSize * 0.4 * flutterScale,
                                 bSize * 0.5, 0, 0);
        CGContextMoveToPoint(context, 0, 0);
        CGContextAddCurveToPoint(context, bSize * 0.9 * flutterScale,
                                 -bSize * 0.7, bSize * 1.1 * flutterScale,
                                 -bSize * 0.1, bSize * 0.1 * flutterScale,
                                 bSize * 0.1);
        CGContextAddCurveToPoint(context, bSize * 0.8 * flutterScale,
                                 bSize * 0.4, bSize * 0.4 * flutterScale,
                                 bSize * 0.5, 0, 0);
        CGContextClosePath(context);

        CGContextSetFillColorWithColor(
            context,
            [[UIColor whiteColor] colorWithAlphaComponent:alpha].CGColor);
        CGContextFillPath(context);

        CGContextBeginPath(context);
        CGContextMoveToPoint(context, 0, 0);
        CGContextAddCurveToPoint(context, -bSize * 0.9 * flutterScale,
                                 -bSize * 0.7, -bSize * 1.1 * flutterScale,
                                 -bSize * 0.1, -bSize * 0.1 * flutterScale,
                                 bSize * 0.1);
        CGContextAddCurveToPoint(context, -bSize * 0.8 * flutterScale,
                                 bSize * 0.4, -bSize * 0.4 * flutterScale,
                                 bSize * 0.5, 0, 0);
        CGContextMoveToPoint(context, 0, 0);
        CGContextAddCurveToPoint(context, bSize * 0.9 * flutterScale,
                                 -bSize * 0.7, bSize * 1.1 * flutterScale,
                                 -bSize * 0.1, bSize * 0.1 * flutterScale,
                                 bSize * 0.1);
        CGContextAddCurveToPoint(context, bSize * 0.8 * flutterScale,
                                 bSize * 0.4, bSize * 0.4 * flutterScale,
                                 bSize * 0.5, 0, 0);
        CGContextClosePath(context);

        CGContextSetStrokeColorWithColor(
            context, [[UIColor colorWithRed:250.0 / 255.0
                                      green:250.0 / 255.0
                                       blue:255.0 / 255.0
                                      alpha:alpha] CGColor]);
        CGContextSetLineWidth(context, bSize * 0.08);
        CGContextStrokePath(context);

        CGContextRestoreGState(context);
      }

    } else if ([_filter isEqualToString:@"snap_pink_hearts"]) {
      // 21 small floating hearts (Android parity)
      CGFloat time = CACurrentMediaTime() * 1000.0;
      CGFloat floatPhase = time / 1600.0;

      CGRect box = face.boundingBox;
      CGFloat faceW = box.size.width * width;
      CGFloat faceH = box.size.height * height;
      // Top of head relative to faceCenter
      CGFloat cx = 0.0;
      CGFloat foreheadY = faceH * 0.45; // Anchor at the forehead

      CGFloat hearts[][3] = {
          {-0.48, -0.20, 1.00}, {-0.34, -0.24, 1.00}, {-0.20, -0.27, 1.00},
          {-0.06, -0.28, 1.00}, {0.08, -0.27, 1.00},  {0.22, -0.24, 1.00},
          {0.36, -0.20, 1.00},  {-0.50, -0.02, 1.00}, {-0.36, -0.05, 1.00},
          {-0.22, -0.06, 1.00}, {-0.08, -0.07, 1.00}, {0.06, -0.06, 1.00},
          {0.20, -0.05, 1.00},  {0.34, -0.02, 1.00},  {-0.46, 0.16, 1.00},
          {-0.31, 0.12, 1.00},  {-0.16, 0.10, 1.00},  {-0.01, 0.09, 1.00},
          {0.14, 0.10, 1.00},   {0.29, 0.12, 1.00},   {0.44, 0.16, 1.00}};

      CGContextSetFillColorWithColor(
          context, [[UIColor colorWithRed:255 / 255.0
                                    green:65 / 255.0
                                     blue:155 / 255.0
                                    alpha:220 / 255.0] CGColor]);

      for (int i = 0; i < 21; i++) {
        CGFloat rx = hearts[i][0];
        CGFloat ry = hearts[i][1];

        CGFloat risePhase = fmod(floatPhase + i * 0.08, 1.0);
        CGFloat rise = risePhase * faceH * 0.10;
        CGFloat floatX = cos(floatPhase * 0.45 + i * 0.65) * faceW * 0.002;
        CGFloat bobY = sin(i * 0.92 + floatPhase * 0.75) * faceH * 0.045;

        CGFloat heartCx = cx + rx * faceW + floatX;
        // In Y-up, subtract ry (negative means higher) and add rise (higher)
        CGFloat heartCy = foreheadY - ry * faceH - bobY + rise;

        CGFloat heartW = faceW * 0.092;
        CGFloat heartH = heartW * 1.06;

        CGFloat rotation = 0;
        switch (i % 4) {
        case 0:
          rotation = -7;
          break;
        case 1:
          rotation = -2;
          break;
        case 2:
          rotation = 3;
          break;
        default:
          rotation = 8;
          break;
        }

        CGContextSaveGState(context);
        CGContextTranslateCTM(context, heartCx, heartCy);
        CGContextRotateCTM(context, rotation * M_PI / 180.0);

        // Exact 2-curve Android heart path, inverted for iOS Y-up
        UIBezierPath *path = [UIBezierPath bezierPath];
        [path moveToPoint:CGPointMake(0, -heartH * 0.25)]; // Tip at bottom
        [path addCurveToPoint:CGPointMake(0, heartH * 0.25)
                controlPoint1:CGPointMake(-heartW * 0.5, heartH * 0.1)
                controlPoint2:CGPointMake(-heartW * 0.5,
                                          heartH * 0.5)]; // Left lobe
        [path addCurveToPoint:CGPointMake(0, -heartH * 0.25)
                controlPoint1:CGPointMake(heartW * 0.5, heartH * 0.5)
                controlPoint2:CGPointMake(heartW * 0.5,
                                          heartH * 0.1)]; // Right lobe
        [path closePath];

        CGContextAddPath(context, path.CGPath);
        CGContextFillPath(context);
        CGContextRestoreGState(context);
      }

    } else if ([_filter isEqualToString:@"snap_evil_bw"]) {
      // ── Exact Android neon evil horns port ─────────────────────────────────
      CGFloat coreW = eyeDist * 0.038;
      CGFloat midW = eyeDist * 0.095;
      CGFloat glowW = eyeDist * 0.220;

      CGFloat hornH = eyeDist * 1.08;
      CGFloat hornArc = eyeDist * 0.72;

      void (^drawNeonHorn)(CGFloat, CGFloat,
                           CGFloat) = ^(CGFloat cx, CGFloat cy, CGFloat sweep) {
        CGContextSaveGState(context);
        CGContextTranslateCTM(context, cx, cy);

        // iOS Y-up conversions (relative to cx, cy)
        CGFloat botX = sweep * eyeDist * 0.04;
        CGFloat botY =
            -eyeDist * 0.06; // Android +0.06 -> iOS -0.06 (below eyes)

        CGFloat tipX = -sweep * eyeDist * 0.04;
        CGFloat tipY = hornH; // Android -hornH -> iOS +hornH (above eyes)

        // ── OUTER ARC ──
        UIBezierPath *outerPath = [UIBezierPath bezierPath];
        [outerPath moveToPoint:CGPointMake(botX, botY)];
        [outerPath addCurveToPoint:CGPointMake(tipX, tipY)
                     controlPoint1:CGPointMake(botX + sweep * hornArc * 0.92,
                                               botY + hornH * 0.24)
                     controlPoint2:CGPointMake(tipX + sweep * hornArc * 0.46,
                                               tipY - hornH * 0.52)];

        // ── INNER ARC ──
        UIBezierPath *innerPath = [UIBezierPath bezierPath];
        CGFloat inset = eyeDist * 0.15;
        [innerPath moveToPoint:CGPointMake(botX - sweep * inset * 0.30,
                                           botY + eyeDist * 0.09)];
        [innerPath
            addCurveToPoint:CGPointMake(tipX + sweep * inset * 0.04,
                                        tipY - eyeDist * 0.07)
              controlPoint1:CGPointMake(botX + sweep * (hornArc * 0.92 - inset),
                                        botY + hornH * 0.22)
              controlPoint2:CGPointMake(
                                tipX + sweep * (hornArc * 0.46 - inset * 0.65),
                                tipY - hornH * 0.50)];

        // ── Radial red bloom ──
        CGFloat bgX = sweep * hornArc * 0.38;
        CGFloat bgY = hornH * 0.44; // Android -0.44 -> iOS +0.44
        CGFloat radius = eyeDist * 0.58;

        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        NSArray *colors = @[
          (__bridge id)[UIColor colorWithRed:1.0
                                       green:0.0
                                        blue:0.0
                                       alpha:(75.0 / 255.0)]
              .CGColor,
          (__bridge id)[UIColor colorWithRed:1.0 green:0.0 blue:0.0 alpha:0.0]
              .CGColor
        ];
        CGFloat locations[] = {0.0, 1.0};
        CGGradientRef gradient = CGGradientCreateWithColors(
            colorSpace, (__bridge CFArrayRef)colors, locations);
        CGContextDrawRadialGradient(context, gradient, CGPointMake(bgX, bgY), 0,
                                    CGPointMake(bgX, bgY), radius,
                                    kCGGradientDrawsBeforeStartLocation |
                                        kCGGradientDrawsAfterEndLocation);
        CGGradientRelease(gradient);
        CGColorSpaceRelease(colorSpace);
        CGColorSpaceRelease(colorSpace);

        // ── Layered neon draw ──
        void (^neonDraw)(UIBezierPath *) = ^(UIBezierPath *path) {
          CGContextSetLineCap(context, kCGLineCapRound);
          CGContextSetLineJoin(context, kCGLineJoinRound);

          // Layer 1
          CGContextSetStrokeColorWithColor(context,
                                           [UIColor colorWithRed:1.0
                                                           green:0.0
                                                            blue:0.0
                                                           alpha:(75.0 / 255.0)]
                                               .CGColor);
          CGContextSetLineWidth(context, glowW);
          CGContextAddPath(context, path.CGPath);
          CGContextStrokePath(context);

          // Layer 2
          CGContextSetStrokeColorWithColor(
              context, [UIColor colorWithRed:1.0
                                       green:20.0 / 255.0
                                        blue:0.0
                                       alpha:(195.0 / 255.0)]
                           .CGColor);
          CGContextSetLineWidth(context, midW);
          CGContextAddPath(context, path.CGPath);
          CGContextStrokePath(context);

          // Layer 3
          CGContextSetStrokeColorWithColor(context,
                                           [UIColor colorWithRed:1.0
                                                           green:65.0 / 255.0
                                                            blue:30.0 / 255.0
                                                           alpha:1.0]
                                               .CGColor);
          CGContextSetLineWidth(context, coreW * 1.7);
          CGContextAddPath(context, path.CGPath);
          CGContextStrokePath(context);

          // Layer 4
          CGContextSetStrokeColorWithColor(context,
                                           [UIColor whiteColor].CGColor);
          CGContextSetLineWidth(context, coreW);
          CGContextAddPath(context, path.CGPath);
          CGContextStrokePath(context);
        };

        neonDraw(outerPath);
        neonDraw(innerPath);

        CGContextRestoreGState(context);
      };

      // Android positions:
      // lx = le.x - eyeDist * 0.22. Relative to center: -0.5 - 0.22 = -0.72
      // ly = eyeMidY - eyeDist * 1.08. Relative to center in Y-up: +1.08
      CGFloat lx = -eyeDist * 0.72;
      CGFloat rx = eyeDist * 0.72;
      CGFloat ly = eyeDist * 1.08;

      // -1f for left horn, +1f for right horn
      drawNeonHorn(lx, ly, -1.0);
      drawNeonHorn(rx, ly, 1.0);

    } else if ([_filter isEqualToString:@"snap_lens_verified"]) {
      // Reset CTM back to screen coordinates (undo face-centric translation)
      CGContextRestoreGState(context);
      CGContextSaveGState(context);
      
      // Android ML Parity for Lens+ Verified
      static float currentDeluluVal = 97.0f;
      static float currentSleepHoursVal = 5.3f;
      static float currentAttentionRateVal = 5.1f;

      float s = 0.5f, l = 0.9f, r = 0.9f;
      float pitch = 0, yaw = 0, roll = 0;
      if (@available(iOS 12.0, *)) {
        yaw = face.yaw ? face.yaw.floatValue * 180.0 / M_PI : 0;
        roll = face.roll ? face.roll.floatValue * 180.0 / M_PI : 0;
      }
      if (@available(iOS 15.0, *)) {
        pitch = face.pitch ? face.pitch.floatValue * 180.0 / M_PI : 0;
      }

      // Pseudo-ML probabilities from landmarks
      if (face.landmarks.outerLips) {
        CGPoint p0 = face.landmarks.outerLips.normalizedPoints[0];
        CGPoint pM =
            face.landmarks.outerLips
                .normalizedPoints[face.landmarks.outerLips.pointCount / 2];
        float mouthW = hypot(p0.x - pM.x, p0.y - pM.y) * width;
        s = MIN(MAX((mouthW / eyeDist - 1.2) * 2.0, 0.0), 1.0);
      }

      float eyeOpen = (l + r) / 2.0f;
      float targetDelulu =
          MAX(1, MIN(100, 50 + s * 40 + (MIN(fabs(roll), 30) / 30.0) * 10));
      float sleepRed = pitch < -4 ? (MIN(fabs(pitch + 4), 10) / 10.0) * 2.5 : 0;
      float targetSleep = MAX(1, MIN(12, 3 + eyeOpen * 4.5 - sleepRed));
      float yawRed = (MIN(fabs(yaw), 25) / 25.0) * 4;
      float targetAtt = MAX(0.1, MIN(15, 1 + eyeOpen * 8 - yawRed));

      currentDeluluVal = currentDeluluVal * 0.85 + targetDelulu * 0.15;
      currentSleepHoursVal = currentSleepHoursVal * 0.85 + targetSleep * 0.15;
      currentAttentionRateVal =
          currentAttentionRateVal * 0.85 + targetAtt * 0.15;

      BOOL isFront =
          (self.videoInput.device.position == AVCaptureDevicePositionFront);

      CGContextSaveGState(context);
      // The context is natively bottom-left, but the display engine seems to expect top-left.
      // We apply a vertical flip here so the card draws upright on the screen.
      // We also removed the isFront horizontal flip to prevent 'left going to right'.
      CGContextTranslateCTM(context, 0, height);
      CGContextScaleCTM(context, 1.0, -1.0);

      // Use MIN(width, height) and account for AspectFill cropping (typically ~82% visible on iPhones)
      CGFloat narrow = MIN(width, height);
      CGFloat cardW = narrow * 0.75;
      CGFloat cardH = cardW * 0.72;
      
      // Center the card statically on the screen
      CGFloat cardLeft = (width - cardW) / 2.0;
      CGFloat cardRight = cardLeft + cardW;

      // Perfectly center it vertically on the screen
      CGFloat layCardTop = (height - cardH) / 2.0;
      CGFloat layCardBottom = layCardTop + cardH;

      CGContextSaveGState(context);

      CGRect cgCardRect =
          CGRectMake(cardLeft, height - layCardBottom, cardW, cardH);
      CGFloat cardRx = cardW * 0.05;

      CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
      CGFloat locations[] = {0.0, 0.35, 0.7, 1.0};
      NSArray *colors = @[
        (__bridge id)[UIColor colorWithRed:0xEA / 255.0
                                     green:0xE9 / 255.0
                                      blue:0xF8 / 255.0
                                     alpha:1.0]
            .CGColor,
        (__bridge id)[UIColor colorWithRed:0xEA / 255.0
                                     green:0xF3 / 255.0
                                      blue:0xFD / 255.0
                                     alpha:1.0]
            .CGColor,
        (__bridge id)[UIColor colorWithRed:0xFB / 255.0
                                     green:0xEB / 255.0
                                      blue:0xF3 / 255.0
                                     alpha:1.0]
            .CGColor,
        (__bridge id)[UIColor colorWithRed:0xF5 / 255.0
                                     green:0xF6 / 255.0
                                      blue:0xFC / 255.0
                                     alpha:1.0]
            .CGColor
      ];
      CGGradientRef gradient = CGGradientCreateWithColors(
          colorSpace, (__bridge CFArrayRef)colors, locations);

      UIBezierPath *cardPath =
          [UIBezierPath bezierPathWithRoundedRect:cgCardRect
                                     cornerRadius:cardRx];
      CGContextAddPath(context, cardPath.CGPath);
      CGContextClip(context);

      CGContextDrawLinearGradient(
          context, gradient, CGPointMake(cardLeft, height - layCardTop),
          CGPointMake(cardRight, height - layCardBottom), 0);
      CGGradientRelease(gradient);
      CGColorSpaceRelease(colorSpace);

      CGFloat layWmCx = cardLeft + cardW * 0.28;
      CGFloat layWmCy = layCardTop + cardH * 0.46;
      CGContextSetStrokeColorWithColor(context,
                                       [[UIColor colorWithRed:0x7A / 255.0
                                                        green:0x8C / 255.0
                                                         blue:0xD0 / 255.0
                                                        alpha:0.1] CGColor]);
      CGContextSetLineWidth(context, cardW * 0.002);
      for (int i = 1; i <= 8; i++) {
        CGFloat r = cardW * 0.03 * i;
        CGContextStrokeEllipseInRect(
            context,
            CGRectMake(layWmCx - r, height - layWmCy - r, r * 2, r * 2));
      }

      CGFloat photoSlotW = cardW * 0.30;
      CGFloat photoSlotH = photoSlotW * 1.25;
      CGFloat photoSlotL = cardRight - cardW * 0.04 - photoSlotW;
      CGFloat layPhotoSlotTop = layCardTop + cardH * 0.20;
      CGFloat photoSlotRx = photoSlotW * 0.06;

      CGRect cgPhotoSlotRect =
          CGRectMake(photoSlotL, height - layPhotoSlotTop - photoSlotH,
                     photoSlotW, photoSlotH);

      CGContextSaveGState(context);
      UIBezierPath *photoPath =
          [UIBezierPath bezierPathWithRoundedRect:cgPhotoSlotRect
                                     cornerRadius:photoSlotRx];
      CGContextAddPath(context, photoPath.CGPath);
      CGContextClip(context);

      if (face) {
        CGRect fBox = face.boundingBox;
        CGFloat fCx = (fBox.origin.x + fBox.size.width / 2.0) * width;
        CGFloat fCyBottomUp = (fBox.origin.y + fBox.size.height / 2.0) * height;
        CGFloat padW = fBox.size.width * width * 1.4;
        CGFloat padH = padW * 1.25;

        CGFloat captureLeftX = fCx - padW / 2.0;
        CGFloat captureBottomY =
            fCyBottomUp -
            padH *
                0.6; // Shifted further down to capture iOS Vision chin properly

        CGContextSaveGState(context);
        CGFloat S = photoSlotW / padW;
        CGContextTranslateCTM(context,
                              cgPhotoSlotRect.origin.x - S * captureLeftX,
                              cgPhotoSlotRect.origin.y - S * captureBottomY);
        CGContextScaleCTM(context, S, S);

        // Flip image upright for Core Graphics
        CGContextTranslateCTM(context, 0, height);
        CGContextScaleCTM(context, 1.0, -1.0);

        CGContextDrawImage(context, CGRectMake(0, 0, width, height), cgImage);
        CGContextRestoreGState(context);
      }
      CGContextRestoreGState(context);

      CGContextSetStrokeColorWithColor(context,
                                       [[UIColor colorWithRed:0x9C / 255.0
                                                        green:0xB6 / 255.0
                                                         blue:0xFA / 255.0
                                                        alpha:1.0] CGColor]);
      CGContextSetLineWidth(context, photoSlotW * 0.024);
      CGContextAddPath(context, photoPath.CGPath);
      CGContextStrokePath(context);

      CGFloat trX = cardLeft + cardW * 0.04;
      CGFloat diamondCx = trX + cardW * 0.02;
      CGFloat cgDiamondCy = height - (layCardTop + cardH * 0.11);
      CGFloat diaW = cardW * 0.04;
      UIBezierPath *diaPath = [UIBezierPath bezierPath];
      [diaPath moveToPoint:CGPointMake(diamondCx, cgDiamondCy - diaW / 2)];
      [diaPath addLineToPoint:CGPointMake(diamondCx + diaW / 2, cgDiamondCy)];
      [diaPath addLineToPoint:CGPointMake(diamondCx, cgDiamondCy + diaW / 2)];
      [diaPath addLineToPoint:CGPointMake(diamondCx - diaW / 2, cgDiamondCy)];
      [diaPath closePath];
      [[UIColor colorWithRed:0x5C / 255.0
                       green:0x6B / 255.0
                        blue:0xC0 / 255.0
                       alpha:1.0] setFill];
      [diaPath fill];

      CGFloat iconBoxSize = cardW * 0.09;
      CGFloat iconBoxL = cardRight - cardW * 0.04 - iconBoxSize;
      CGFloat layIconBoxTop = layCardTop + cardH * 0.06;
      CGRect cgIconBoxRect =
          CGRectMake(iconBoxL, height - layIconBoxTop - iconBoxSize,
                     iconBoxSize, iconBoxSize);
      UIBezierPath *iconBoxPath =
          [UIBezierPath bezierPathWithRoundedRect:cgIconBoxRect
                                     cornerRadius:iconBoxSize * 0.2];
      [[UIColor colorWithRed:0x7A / 255.0
                       green:0x8C / 255.0
                        blue:0xD0 / 255.0
                       alpha:0.15] setFill];
      [iconBoxPath fill];
      [[UIColor colorWithRed:0x7A / 255.0
                       green:0x8C / 255.0
                        blue:0xD0 / 255.0
                       alpha:1.0] setStroke];
      [iconBoxPath stroke];

      CGFloat crownCx = iconBoxL + iconBoxSize / 2;
      CGFloat cgCrownCy = height - (layIconBoxTop + iconBoxSize * 0.45);
      CGFloat crownW = iconBoxSize * 0.6;
      CGFloat crownH = iconBoxSize * 0.4;
      UIBezierPath *crownPath = [UIBezierPath bezierPath];
      [crownPath moveToPoint:CGPointMake(crownCx - crownW / 2,
                                         cgCrownCy - crownH / 2)];
      [crownPath addLineToPoint:CGPointMake(crownCx - crownW / 2,
                                            cgCrownCy + crownH * 0.2)];
      [crownPath addLineToPoint:CGPointMake(crownCx - crownW * 0.25,
                                            cgCrownCy - crownH * 0.1)];
      [crownPath addLineToPoint:CGPointMake(crownCx, cgCrownCy + crownH / 2)];
      [crownPath addLineToPoint:CGPointMake(crownCx + crownW * 0.25,
                                            cgCrownCy - crownH * 0.1)];
      [crownPath addLineToPoint:CGPointMake(crownCx + crownW / 2,
                                            cgCrownCy + crownH * 0.2)];
      [crownPath addLineToPoint:CGPointMake(crownCx + crownW / 2,
                                            cgCrownCy - crownH / 2)];
      [crownPath closePath];
      [[UIColor colorWithRed:0x5C / 255.0
                       green:0x6B / 255.0
                        blue:0xC0 / 255.0
                       alpha:1.0] setFill];
      [crownPath fill];

      // We are already in the vertically flipped context (from line 2112).
      // We don't need to apply another global vertical flip.
      UIGraphicsPushContext(context);

      NSDictionary *hA1 = @{
        NSFontAttributeName : [UIFont boldSystemFontOfSize:(cardW * 0.052)],
        NSForegroundColorAttributeName : [UIColor colorWithRed:0x0A / 255.0
                                                         green:0x3F / 255.0
                                                          blue:0x9A / 255.0
                                                         alpha:1.0]
      };
      NSDictionary *hA2 = @{
        NSFontAttributeName : [UIFont boldSystemFontOfSize:(cardW * 0.024)],
        NSForegroundColorAttributeName : [UIColor colorWithRed:0x5A / 255.0
                                                         green:0x6B / 255.0
                                                          blue:0x8C / 255.0
                                                         alpha:1.0]
      };
      NSDictionary *idA = @{
        NSFontAttributeName : [UIFont boldSystemFontOfSize:(cardW * 0.030)],
        NSForegroundColorAttributeName : [UIColor colorWithRed:0x5C / 255.0
                                                         green:0x6B / 255.0
                                                          blue:0xC0 / 255.0
                                                         alpha:1.0]
      };
      NSDictionary *sLA = @{
        NSFontAttributeName : [UIFont boldSystemFontOfSize:(cardW * 0.024)],
        NSForegroundColorAttributeName : [UIColor colorWithRed:0x5A / 255.0
                                                         green:0x6B / 255.0
                                                          blue:0x8C / 255.0
                                                         alpha:1.0]
      };
      NSDictionary *sVA = @{
        NSFontAttributeName : [UIFont boldSystemFontOfSize:(cardW * 0.045)],
        NSForegroundColorAttributeName : [UIColor colorWithRed:0x0A / 255.0
                                                         green:0x3F / 255.0
                                                          blue:0x9A / 255.0
                                                         alpha:1.0]
      };
      NSDictionary *dVA = @{
        NSFontAttributeName : [UIFont boldSystemFontOfSize:(cardW * 0.045)],
        NSForegroundColorAttributeName : [UIColor colorWithRed:0xD8 / 255.0
                                                         green:0x1B / 255.0
                                                          blue:0x60 / 255.0
                                                         alpha:1.0]
      };
      NSDictionary *bA1 = @{
        NSFontAttributeName : [UIFont boldSystemFontOfSize:(cardW * 0.028)],
        NSForegroundColorAttributeName : [UIColor colorWithRed:0x0A / 255.0
                                                         green:0x3F / 255.0
                                                          blue:0x9A / 255.0
                                                         alpha:1.0]
      };
      NSDictionary *bA2 = @{
        NSFontAttributeName : [UIFont boldSystemFontOfSize:(cardW * 0.016)],
        NSForegroundColorAttributeName : [UIColor colorWithRed:0x5A / 255.0
                                                         green:0x6B / 255.0
                                                          blue:0x8C / 255.0
                                                         alpha:1.0]
      };

      void (^drawFlippedText)(NSString *, CGPoint, NSDictionary *) =
          ^(NSString *text, CGPoint pt, NSDictionary *attrs) {
            CGSize sz = [text sizeWithAttributes:attrs];
            if (sz.width == 0 || sz.height == 0)
              return;

            UIGraphicsBeginImageContextWithOptions(sz, NO, 0.0);
            [text drawAtPoint:CGPointZero withAttributes:attrs];
            UIImage *textImage = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();

            CGContextSaveGState(context);
            
            // Translate to the exact position first
            CGContextTranslateCTM(context, pt.x, pt.y);
            
            // Text image from UIGraphics is top-left oriented.
            // Since our context is currently top-left (from our global vertical flip),
            // CGContextDrawImage will natively draw it upside down.
            // So we must flip it vertically in-place.
            CGContextTranslateCTM(context, 0, sz.height);
            CGContextScaleCTM(context, 1.0, -1.0);
            
            CGContextDrawImage(context, CGRectMake(0, 0, sz.width, sz.height),
                               textImage.CGImage);
            CGContextRestoreGState(context);
          };

      CGFloat headerCx = width / 2.0;

      NSString *tT = @"LENS+ VERIFIED";
      CGSize tS = [tT sizeWithAttributes:hA1];
      drawFlippedText(tT,
                      CGPointMake(headerCx - tS.width / 2,
                                  layCardTop + cardH * 0.12 - tS.height / 2),
                      hA1);

      NSString *sT = @"USER IDENTITY CARD";
      CGSize sS = [sT sizeWithAttributes:hA2];
      drawFlippedText(sT,
                      CGPointMake(headerCx - sS.width / 2,
                                  layCardTop + cardH * 0.17 - sS.height / 2),
                      hA2);

      NSString *iL = @"ID LEVEL";
      CGSize iS = [iL sizeWithAttributes:hA2];
      drawFlippedText(iL,
                      CGPointMake(trX + cardW * 0.05,
                                  layCardTop + cardH * 0.09 - iS.height / 2),
                      hA2);

      NSString *pS = @"PLATINUM";
      CGSize pSS = [pS sizeWithAttributes:idA];
      drawFlippedText(pS,
                      CGPointMake(trX + cardW * 0.05,
                                  layCardTop + cardH * 0.14 - pSS.height / 2),
                      idA);

      CGFloat rCx = layWmCx;
      CGFloat lSY = layCardTop + cardH * 0.32;
      CGFloat yG = cardH * 0.18;

      NSString *str = @"DELULU LEVEL";
      CGSize sz = [str sizeWithAttributes:sLA];
      drawFlippedText(
          str, CGPointMake(rCx - sz.width / 2, lSY - cardH * 0.035 - sz.height),
          sLA);

      str = [NSString stringWithFormat:@": %d%%", (int)currentDeluluVal];
      sz = [str sizeWithAttributes:dVA];
      drawFlippedText(
          str, CGPointMake(rCx - sz.width / 2, lSY + cardH * 0.035 - sz.height),
          dVA);

      str = @"SLEEP HOURS";
      sz = [str sizeWithAttributes:sLA];
      drawFlippedText(
          str,
          CGPointMake(rCx - sz.width / 2, lSY + yG - cardH * 0.035 - sz.height),
          sLA);

      str = [NSString stringWithFormat:@": %.1f", currentSleepHoursVal];
      sz = [str sizeWithAttributes:sVA];
      drawFlippedText(
          str,
          CGPointMake(rCx - sz.width / 2, lSY + yG + cardH * 0.035 - sz.height),
          sVA);

      str = @"ATTENTION RATE";
      sz = [str sizeWithAttributes:sLA];
      drawFlippedText(str,
                      CGPointMake(rCx - sz.width / 2,
                                  lSY + 2 * yG - cardH * 0.035 - sz.height),
                      sLA);

      str = [NSString stringWithFormat:@": %.1f sec", currentAttentionRateVal];
      sz = [str sizeWithAttributes:sVA];
      drawFlippedText(str,
                      CGPointMake(rCx - sz.width / 2,
                                  lSY + 2 * yG + cardH * 0.035 - sz.height),
                      sVA);

      str = @"OFFICIAL LENS+ CITIZEN";
      sz = [str sizeWithAttributes:bA1];
      drawFlippedText(str,
                      CGPointMake(headerCx - sz.width / 2,
                                  layCardTop + cardH * 0.91 - sz.height / 2),
                      bA1);

      str = @"VERIFIED • ACTIVE • LEGENDARY";
      sz = [str sizeWithAttributes:bA2];
      drawFlippedText(str,
                      CGPointMake(headerCx - sz.width / 2,
                                  layCardTop + cardH * 0.95 - sz.height / 2),
                      bA2);

      UIGraphicsPopContext();
      CGContextRestoreGState(context); // Restore UIKit vertical flip
      [crownPath moveToPoint:CGPointMake(crownCx - crownW / 2,
                                         cgCrownCy - crownH / 2)];
      [crownPath addLineToPoint:CGPointMake(crownCx - crownW / 2,
                                            cgCrownCy + crownH * 0.2)];
      [crownPath addLineToPoint:CGPointMake(crownCx - crownW * 0.25,
                                            cgCrownCy - crownH * 0.1)];
      [crownPath addLineToPoint:CGPointMake(crownCx, cgCrownCy + crownH / 2)];
      [crownPath addLineToPoint:CGPointMake(crownCx + crownW * 0.25,
                                            cgCrownCy - crownH * 0.1)];
      [crownPath addLineToPoint:CGPointMake(crownCx + crownW / 2,
                                            cgCrownCy + crownH * 0.2)];
      [crownPath addLineToPoint:CGPointMake(crownCx + crownW / 2,
                                            cgCrownCy - crownH / 2)];
      [crownPath closePath];
      [[UIColor colorWithRed:0x5C / 255.0
                       green:0x6B / 255.0
                        blue:0xC0 / 255.0
                       alpha:1.0] setFill];
      [crownPath fill];

      CGContextRestoreGState(context); // Restore the outer mirror context
    } else if ([_filter isEqualToString:@"snap_pookie"]) {
      static UIImage *bowImage = nil;
      static dispatch_once_t onceToken;
      dispatch_once(&onceToken, ^{
        bowImage = [UIImage imageNamed:@"bow_pookie.png"];
        if (!bowImage)
          bowImage = [UIImage imageNamed:@"bow_pookie"];
      });

      if (bowImage) {
        CGFloat bowDisplayW = eyeDist * 1.15;
        CGFloat scale = bowDisplayW / bowImage.size.width;
        CGFloat bowDisplayH = bowImage.size.height * scale;

        CGFloat bx = (rightEye.x - faceCenter.x) + eyeDist * 0.15;
        CGFloat by =
            (rightEye.y - faceCenter.y) + eyeDist * 0.80; // + is UP in iOS

        CGContextSaveGState(context);
        CGContextTranslateCTM(context, bx, by);
        // Tilt towards the right
        CGContextRotateCTM(context, -35.0 * M_PI / 180.0);
        CGRect rect = CGRectMake(-bowDisplayW / 2.0, -bowDisplayH / 2.0,
                                 bowDisplayW, bowDisplayH);
        CGContextDrawImage(context, rect, bowImage.CGImage);
        CGContextRestoreGState(context);
      }
    } else if ([_filter isEqualToString:@"snap_bow_aesthetic"]) {
      static UIImage *bowImage2 = nil;
      static dispatch_once_t onceToken2;
      dispatch_once(&onceToken2, ^{
        bowImage2 = [UIImage imageNamed:@"bow_pookie.png"];
        if (!bowImage2)
          bowImage2 = [UIImage imageNamed:@"bow_pookie"];
      });

      if (bowImage2) {
        CGFloat bowDisplayW = eyeDist * 0.95;
        CGFloat scale = bowDisplayW / bowImage2.size.width;
        CGFloat bowDisplayH = bowImage2.size.height * scale;

        CGFloat lx = -eyeDist * 0.72;
        CGFloat ly = eyeDist * 1.08;

        void (^drawBow)(CGFloat, CGFloat, CGFloat) =
            ^(CGFloat cx, CGFloat cy, CGFloat angleDeg) {
              CGContextSaveGState(context);
              CGContextTranslateCTM(context, cx, cy);
              CGContextRotateCTM(context, angleDeg * M_PI / 180.0);
              CGRect rect = CGRectMake(-bowDisplayW / 2.0, -bowDisplayH / 2.0,
                                       bowDisplayW, bowDisplayH);
              CGContextDrawImage(context, rect, bowImage2.CGImage);
              CGContextRestoreGState(context);
            };

        drawBow(lx, ly, 25.0);

        CGFloat rx = eyeDist * 0.72;
        drawBow(rx, ly, -25.0);
      }

    } else if ([_filter isEqualToString:@"snap_panda_face"]) {
      // Android parity: Draw 10 small panda faces around the face boundary
      CGRect box = face.boundingBox;
      CGFloat faceW = box.size.width * width;
      CGFloat faceH = box.size.height * height;

      // Panda stamps array: (rx, ry, scale, rotation)
      CGFloat pandas[][4] = {
          {-0.21, -0.32, 0.70, -12}, {0.21, -0.32, 0.70, 15},
          {-0.33, -0.15, 0.65, -20}, {0.33, -0.15, 0.65, 25},
          {-0.13, 0.05, 0.60, -5},   {0.13, 0.05, 0.60, 8},
          {-0.30, 0.15, 0.75, -15},  {0.30, 0.15, 0.75, 12},
          {-0.21, 0.32, 0.68, -8},   {0.21, 0.32, 0.68, 18},
          {0.00, 0.46, 0.72, 0},     {-0.11, 0.25, 0.55, -10},
          {0.11, 0.25, 0.55, 12}};

      CGFloat baseSize = faceW * 0.12;

      void (^drawPanda)(void) = ^{
        // Draw a vector panda face
        CGContextSetFillColorWithColor(context, [UIColor whiteColor].CGColor);
        CGContextSetStrokeColorWithColor(context, [UIColor blackColor].CGColor);
        CGContextSetLineWidth(context, baseSize * 0.05);

        // Ears (black)
        CGContextSetFillColorWithColor(context, [UIColor blackColor].CGColor);
        CGContextFillEllipseInRect(
            context, CGRectMake(-baseSize * 0.4, -baseSize * 0.4,
                                baseSize * 0.35, baseSize * 0.35));
        CGContextFillEllipseInRect(
            context, CGRectMake(baseSize * 0.05, -baseSize * 0.4,
                                baseSize * 0.35, baseSize * 0.35));

        // Head (white)
        CGContextSetFillColorWithColor(context, [UIColor whiteColor].CGColor);
        CGContextFillEllipseInRect(
            context, CGRectMake(-baseSize * 0.45, -baseSize * 0.25,
                                baseSize * 0.9, baseSize * 0.7));
        CGContextStrokeEllipseInRect(
            context, CGRectMake(-baseSize * 0.45, -baseSize * 0.25,
                                baseSize * 0.9, baseSize * 0.7));

        // Eye patches (black)
        CGContextSetFillColorWithColor(context, [UIColor blackColor].CGColor);
        CGContextFillEllipseInRect(context,
                                   CGRectMake(-baseSize * 0.3, -baseSize * 0.05,
                                              baseSize * 0.25, baseSize * 0.3));
        CGContextFillEllipseInRect(context,
                                   CGRectMake(baseSize * 0.05, -baseSize * 0.05,
                                              baseSize * 0.25, baseSize * 0.3));

        // Nose (black)
        CGContextFillEllipseInRect(context,
                                   CGRectMake(-baseSize * 0.08, baseSize * 0.2,
                                              baseSize * 0.16, baseSize * 0.1));

        // Eyes (white dots)
        CGContextSetFillColorWithColor(context, [UIColor whiteColor].CGColor);
        CGContextFillEllipseInRect(
            context,
            CGRectMake(-baseSize * 0.2, 0, baseSize * 0.08, baseSize * 0.08));
        CGContextFillEllipseInRect(
            context,
            CGRectMake(baseSize * 0.12, 0, baseSize * 0.08, baseSize * 0.08));
      };

      for (int i = 0; i < 13; i++) {
        CGFloat px = pandas[i][0] * faceW;
        // Invert Y coordinate for Y-up
        CGFloat py = -pandas[i][1] * faceH;
        CGFloat pScale = pandas[i][2];
        CGFloat pRot = pandas[i][3];

        CGContextSaveGState(context);
        CGContextTranslateCTM(context, px, py);
        // Scale Y by -1 so the panda (which was written with Y-down logic)
        // draws upright
        CGContextScaleCTM(context, pScale, -pScale);
        CGContextRotateCTM(context, pRot * M_PI / 180.0);
        drawPanda();
        CGContextRestoreGState(context);
      }

    } else if ([_filter isEqualToString:@"snap_pink_flower"]) {
      // Android parity: Plumeria flower near right ear
      CGFloat fSize = eyeDist * 0.45;
      CGFloat earX = eyeDist * 0.48; // fallback relative to right eye
      CGFloat earY = -eyeDist * 0.42;

      // Adjust to face center
      CGFloat fx = (rightEye.x - faceCenter.x) + earX;
      CGFloat fy = (rightEye.y - faceCenter.y) + earY;

      CGContextSaveGState(context);
      CGContextTranslateCTM(context, fx, fy);

      UIBezierPath *petalPath = [UIBezierPath bezierPath];
      [petalPath moveToPoint:CGPointZero];
      [petalPath addCurveToPoint:CGPointMake(0, -fSize * 0.9)
                   controlPoint1:CGPointMake(-fSize * 0.4, -fSize * 0.3)
                   controlPoint2:CGPointMake(-fSize * 0.5, -fSize * 0.8)];
      [petalPath addCurveToPoint:CGPointZero
                   controlPoint1:CGPointMake(fSize * 0.5, -fSize * 0.8)
                   controlPoint2:CGPointMake(fSize * 0.4, -fSize * 0.3)];
      [petalPath closePath];

      // Draw drop shadow
      CGContextSaveGState(context);
      CGContextTranslateCTM(context, fSize * 0.08, fSize * 0.08);
      CGContextSetFillColorWithColor(
          context, [[UIColor blackColor] colorWithAlphaComponent:0.18].CGColor);
      for (int i = 0; i < 5; i++) {
        CGContextSaveGState(context);
        CGContextRotateCTM(context, (i * 72.0) * M_PI / 180.0);
        CGContextAddPath(context, petalPath.CGPath);
        CGContextFillPath(context);
        CGContextRestoreGState(context);
      }
      CGContextRestoreGState(context);

      // Create gradient for petals
      CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
      CGFloat locations[] = {0.0, 0.2, 0.5, 0.85, 1.0};
      NSArray *colors = @[
        (__bridge id)[UIColor colorWithRed:0xFF / 255.0
                                     green:0xCC / 255.0
                                      blue:0x00 / 255.0
                                     alpha:1.0]
            .CGColor,
        (__bridge id)[UIColor colorWithRed:0xFF / 255.0
                                     green:0xFB / 255.0
                                      blue:0xEB / 255.0
                                     alpha:1.0]
            .CGColor,
        (__bridge id)[UIColor colorWithRed:0xFF / 255.0
                                     green:0xFF / 255.0
                                      blue:0xFF / 255.0
                                     alpha:1.0]
            .CGColor,
        (__bridge id)[UIColor colorWithRed:0xFF / 255.0
                                     green:0xA6 / 255.0
                                      blue:0xC9 / 255.0
                                     alpha:1.0]
            .CGColor,
        (__bridge id)[UIColor colorWithRed:0xFF / 255.0
                                     green:0x4D / 255.0
                                      blue:0xA6 / 255.0
                                     alpha:1.0]
            .CGColor
      ];
      CGGradientRef gradient = CGGradientCreateWithColors(
          colorSpace, (__bridge CFArrayRef)colors, locations);

      // Draw 5 petals with gradient
      for (int i = 0; i < 5; i++) {
        CGContextSaveGState(context);
        CGContextRotateCTM(context, (i * 72.0) * M_PI / 180.0);
        CGContextAddPath(context, petalPath.CGPath);
        CGContextClip(context);
        CGContextDrawLinearGradient(context, gradient, CGPointMake(0, 0),
                                    CGPointMake(0, -fSize), 0);
        CGContextRestoreGState(context);
      }
      CGGradientRelease(gradient);
      CGColorSpaceRelease(colorSpace);

      // Yellow center
      CGFloat centerLocs[] = {0.0, 0.5, 1.0};
      NSArray *centerColors = @[
        (__bridge id)[UIColor colorWithRed:0xFF / 255.0
                                     green:0xA6 / 255.0
                                      blue:0x00 / 255.0
                                     alpha:1.0]
            .CGColor,
        (__bridge id)[UIColor colorWithRed:0xFF / 255.0
                                     green:0xCC / 255.0
                                      blue:0x00 / 255.0
                                     alpha:1.0]
            .CGColor,
        (__bridge id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor
      ];
      CGGradientRef centerGradient = CGGradientCreateWithColors(
          colorSpace, (__bridge CFArrayRef)centerColors, centerLocs);

      CGContextSaveGState(context);
      CGContextAddArc(context, 0, 0, fSize * 0.22, 0, 2 * M_PI, 0);
      CGContextClip(context);
      // In iOS, CGContextDrawRadialGradient takes start/end centers and radii
      CGContextDrawRadialGradient(context, centerGradient, CGPointZero, 0,
                                  CGPointZero, fSize * 0.22, 0);
      CGContextRestoreGState(context);

      CGGradientRelease(centerGradient);
      CGColorSpaceRelease(colorSpace);

      CGContextRestoreGState(context);

    } else if ([_filter isEqualToString:@"snap_dark_moon"]) {
      // Android parity: Golden Crescent Moons scattered over face
      CGRect box = face.boundingBox;
      CGFloat faceW = box.size.width * width;
      CGFloat faceH = box.size.height * height;

      CGContextSetFillColorWithColor(context,
                                     [[UIColor colorWithRed:255 / 255.0
                                                      green:205 / 255.0
                                                       blue:20 / 255.0
                                                      alpha:0.92] CGColor]);

      // moons array (rx, ry, sizeMult)
      CGFloat moons[][3] = {
          {-0.24, -0.42, 1.00}, {-0.06, -0.32, 0.85}, {0.20, -0.40, 0.95},
          {0.32, -0.25, 1.00},  {-0.30, -0.15, 0.80}, {-0.04, -0.05, 0.70},
          {0.05, 0.22, 0.80},   {-0.35, 0.06, 0.90},  {0.32, 0.13, 0.95},
          {-0.33, 0.26, 0.85},  {0.24, 0.36, 0.85},   {-0.16, 0.44, 0.90}};

      CGFloat baseR = faceW * 0.038;
      for (int i = 0; i < 12; i++) {
        CGFloat px = moons[i][0] * faceW;
        CGFloat py = moons[i][1] * faceH;
        CGFloat outerR = baseR * moons[i][2];
        CGFloat innerR = outerR * 0.68;
        CGFloat offX = outerR * 0.38;

        CGContextSaveGState(context);
        CGContextTranslateCTM(context, px, py);

        UIBezierPath *path = [UIBezierPath bezierPath];
        [path
            appendPath:[UIBezierPath
                           bezierPathWithOvalInRect:CGRectMake(-outerR, -outerR,
                                                               outerR * 2,
                                                               outerR * 2)]];
        [path appendPath:[UIBezierPath
                             bezierPathWithOvalInRect:CGRectMake(
                                                          -outerR + offX,
                                                          -outerR - offX * 0.12,
                                                          innerR * 2,
                                                          innerR * 2)]];
        path.usesEvenOddFillRule = YES;

        CGContextAddPath(context, path.CGPath);
        CGContextDrawPath(context, kCGPathEOFill);
        CGContextRestoreGState(context);
      }

    } else if ([_filter isEqualToString:@"snap_talking_forest"]) {
      CGContextSaveGState(context);
      // Reverse rotation & translation to work in original cgImage coordinates
      CGContextRotateCTM(context, -rollAngle);
      CGContextTranslateCTM(context, -faceCenter.x, -faceCenter.y);

      static UIImage *forestBg = nil;
      static dispatch_once_t onceTokenForest;
      dispatch_once(&onceTokenForest, ^{
        forestBg = [UIImage imageNamed:@"talking_forest.png"];
        if (!forestBg)
          forestBg = [UIImage imageNamed:@"talking_forest"];
      });
      if (forestBg) {
        CGFloat bgW = forestBg.size.width;
        CGFloat bgH = forestBg.size.height;
        CGFloat scale = MAX(width / bgW, height / bgH);
        CGFloat drawW = bgW * scale;
        CGFloat drawH = bgH * scale;
        CGFloat drawX = (width - drawW) / 2.0;
        CGFloat drawY = (height - drawH) / 2.0;

        CGContextSaveGState(context);
        CGContextDrawImage(context, CGRectMake(drawX, drawY, drawW, drawH),
                           forestBg.CGImage);
        CGContextRestoreGState(context);
      } else {
        CGContextSetFillColorWithColor(
            context, [[UIColor colorWithRed:0 green:0 blue:0
                                      alpha:1.0] CGColor]);
        CGContextFillRect(context, CGRectMake(0, 0, width, height));
      }

      // Now cut out the eyes and mouth by drawing a mask into a transparency
      // layer, and then drawing the original cgImage with SourceIn over it!
      CGContextBeginTransparencyLayer(context, NULL);

      // Feathered mask function using radial gradient
      void (^drawMask)(CGPoint, CGFloat, CGFloat) = ^(CGPoint pt, CGFloat rx,
                                                      CGFloat ry) {
        CGContextSaveGState(context);
        CGContextTranslateCTM(context, pt.x, pt.y);
        CGContextScaleCTM(context, 1.0,
                          ry / rx); // Scale Y to draw oval gradient

        CGColorSpaceRef cs = CGColorSpaceCreateDeviceGray();
        CGFloat locs[] = {0.0, 0.4, 1.0};
        // Alpha goes from 1.0 to 0.0
        CGFloat cols[] = {1.0, 1.0, 1.0, 1.0, 1.0, 0.0};
        CGGradientRef grad =
            CGGradientCreateWithColorComponents(cs, cols, locs, 3);

        CGContextDrawRadialGradient(context, grad, CGPointZero, 0, CGPointZero,
                                    rx, kCGGradientDrawsBeforeStartLocation);

        CGGradientRelease(grad);
        CGColorSpaceRelease(cs);
        CGContextRestoreGState(context);
      };

      // Draw Masks for Left Eye, Right Eye, Mouth in ORIGINAL coordinates
      CGPoint le = leftEye;
      CGPoint re = rightEye;
      drawMask(le, eyeDist * 0.40, eyeDist * 0.28);
      drawMask(re, eyeDist * 0.40, eyeDist * 0.28);

      if (face.landmarks.outerLips) {
        CGPoint mouthC = getCenter(face.landmarks.outerLips, faceRect);
        drawMask(mouthC, eyeDist * 0.65, eyeDist * 0.40);
      }

      // Now set blend mode to SourceIn and draw the original camera feed!
      CGContextSetBlendMode(context, kCGBlendModeSourceIn);
      CGContextSaveGState(context);
      CGContextDrawImage(context, CGRectMake(0, 0, width, height), cgImage);
      CGContextRestoreGState(context);

      CGContextEndTransparencyLayer(context);
      CGContextRestoreGState(context); // Restore face loop CTM

    } else if ([_filter isEqualToString:@"oldAge"]) {
      CGContextSetStrokeColorWithColor(
          context, [[UIColor blackColor] colorWithAlphaComponent:0.2].CGColor);
      CGContextSetLineWidth(context, 1.5);
      for (int i = 0; i < 3; i++) {
        CGFloat y = eyeDist * 1.5 + i * eyeDist * 0.15;
        CGContextMoveToPoint(context, -eyeDist * 0.6, y);
        CGContextAddLineToPoint(context, eyeDist * 0.6, y);
      }
      CGContextStrokePath(context);
    } else if ([_filter isEqualToString:@"faceSwap"] &&
               self.currentFaces.count >= 2) {
      // Face Swap (draw second face over first face)
      VNFaceObservation *otherFace = (face == self.currentFaces[0])
                                         ? self.currentFaces[1]
                                         : self.currentFaces[0];
      CGPoint otherLeft = CGPointZero;
      CGPoint otherRight = CGPointZero;
      if (otherFace.landmarks.leftEye) {
        CGPoint p = otherFace.landmarks.leftEye.normalizedPoints[0];
        otherLeft = CGPointMake(p.x * width, p.y * height);
      }
      if (otherFace.landmarks.rightEye) {
        CGPoint p = otherFace.landmarks.rightEye.normalizedPoints[0];
        otherRight = CGPointMake(p.x * width, p.y * height);
      }
      CGPoint otherCenter = CGPointMake((otherLeft.x + otherRight.x) / 2.0,
                                        (otherLeft.y + otherRight.y) / 2.0);

      CGContextSaveGState(context);
      CGContextAddEllipseInRect(context,
                                CGRectMake(-eyeDist * 1.2, -eyeDist * 1.2,
                                           eyeDist * 2.4, eyeDist * 2.4));
      CGContextClip(context);
      CGContextTranslateCTM(context, -otherCenter.x + faceCenter.x,
                            -otherCenter.y + faceCenter.y);
      CGContextDrawImage(context, CGRectMake(0, 0, width, height), cgImage);
      CGContextRestoreGState(context);
    } else if ([_filter isEqualToString:@"snap_neon_outline"]) {
      VNFaceLandmarkRegion2D *contour = face.landmarks.faceContour;
      if (contour && contour.pointCount > 0) {
        CGFloat faceW = faceRect.size.width;
        CGFloat faceH = faceRect.size.height;

        // Helper to map normalized point to faceCenter-relative context
        CGPoint (^toLocal)(CGPoint) = ^CGPoint(CGPoint p) {
          CGFloat ax =
              (boundingBox.origin.x + p.x * boundingBox.size.width) * width;
          CGFloat ay =
              (boundingBox.origin.y + p.y * boundingBox.size.height) * height;
          return CGPointMake(ax - faceCenter.x, ay - faceCenter.y);
        };

        // VNFaceLandmarkRegion2D faceContour typically has 17 points (0 to 16).
        // Point 0 is left ear, point 8 is chin, point 16 is right ear.
        // We want the lower jaw points to emulate Android's MLKit points 13
        // and 23.
        NSInteger ptCount = contour.pointCount;
        CGPoint p0 = toLocal(contour.normalizedPoints[0]);
        CGPoint p1 = toLocal(contour.normalizedPoints[ptCount - 1]);

        BOOL leftToRight = p0.x < p1.x;

        // Use lower cheek/jaw points (around index 6 and 10) to avoid cutting
        // across the mouth
        NSInteger leftJawIdx = 6;
        NSInteger rightJawIdx = ptCount - 1 - 6;
        if (!leftToRight) {
          leftJawIdx = ptCount - 1 - 6;
          rightJawIdx = 6;
        }

        // Ensure indices are within bounds
        leftJawIdx = MAX(0, MIN(leftJawIdx, ptCount - 1));
        rightJawIdx = MAX(0, MIN(rightJawIdx, ptCount - 1));

        CGPoint leftJaw = toLocal(contour.normalizedPoints[leftJawIdx]);
        CGPoint rightJaw = toLocal(contour.normalizedPoints[rightJawIdx]);

        // Y points UP in iOS CGBitmapContext
        CGFloat shoulderY = leftJaw.y - faceH * 0.65;
        CGPoint leftShoulder = CGPointMake(leftJaw.x - faceW * 0.85, shoulderY);
        CGPoint rightShoulder =
            CGPointMake(rightJaw.x + faceW * 0.85, shoulderY);
        CGFloat bottomY = leftShoulder.y - faceH * 2.5;

        // 1. Draw glowing body/shoulder silhouette outline
        UIBezierPath *path = [UIBezierPath bezierPath];
        [path moveToPoint:CGPointMake(leftShoulder.x, bottomY)];
        [path addLineToPoint:leftShoulder];
        // Curve to the lower jaw (this curve acts as the chin visually)
        [path addQuadCurveToPoint:leftJaw
                     controlPoint:CGPointMake(leftJaw.x - faceW * 0.15,
                                              leftJaw.y - faceH * 0.25)];

        // Trace UP the left cheek
        if (leftToRight) {
          for (NSInteger i = leftJawIdx; i >= 0; i--) {
            [path addLineToPoint:toLocal(contour.normalizedPoints[i])];
          }
        } else {
          for (NSInteger i = leftJawIdx; i < ptCount; i++) {
            [path addLineToPoint:toLocal(contour.normalizedPoints[i])];
          }
        }

        CGPoint leftEar = leftToRight ? p0 : p1;
        CGPoint rightEar = leftToRight ? p1 : p0;

        // Arc across the forehead
        CGPoint topLeftForehead =
            CGPointMake(leftEar.x + faceW * 0.15, leftEar.y + faceH * 0.35);
        CGPoint topRightForehead =
            CGPointMake(rightEar.x - faceW * 0.15, rightEar.y + faceH * 0.35);

        [path addQuadCurveToPoint:topLeftForehead
                     controlPoint:CGPointMake(leftEar.x - faceW * 0.05,
                                              leftEar.y + faceH * 0.2)];
        [path addLineToPoint:topRightForehead];
        [path addQuadCurveToPoint:rightEar
                     controlPoint:CGPointMake(rightEar.x + faceW * 0.05,
                                              rightEar.y + faceH * 0.2)];

        // Trace DOWN the right cheek
        if (leftToRight) {
          for (NSInteger i = ptCount - 1; i >= rightJawIdx; i--) {
            [path addLineToPoint:toLocal(contour.normalizedPoints[i])];
          }
        } else {
          for (NSInteger i = 0; i <= rightJawIdx; i++) {
            [path addLineToPoint:toLocal(contour.normalizedPoints[i])];
          }
        }

        // Curve to the right shoulder
        [path addQuadCurveToPoint:rightShoulder
                     controlPoint:CGPointMake(rightJaw.x + faceW * 0.15,
                                              rightJaw.y - faceH * 0.25)];
        [path addLineToPoint:CGPointMake(rightShoulder.x, bottomY)];

        CGContextSetLineCap(context, kCGLineCapRound);
        CGContextSetLineJoin(context, kCGLineJoinRound);

        // Neon Glow Layers
        CGContextSetStrokeColorWithColor(
            context, [[UIColor whiteColor] colorWithAlphaComponent:40.0 / 255.0]
                         .CGColor);
        CGContextSetLineWidth(context, faceW * 0.132);
        CGContextAddPath(context, path.CGPath);
        CGContextStrokePath(context);

        CGContextSetStrokeColorWithColor(
            context, [[UIColor whiteColor] colorWithAlphaComponent:95.0 / 255.0]
                         .CGColor);
        CGContextSetLineWidth(context, faceW * 0.082);
        CGContextAddPath(context, path.CGPath);
        CGContextStrokePath(context);

        CGContextSetStrokeColorWithColor(
            context,
            [[UIColor whiteColor] colorWithAlphaComponent:160.0 / 255.0]
                .CGColor);
        CGContextSetLineWidth(context, faceW * 0.042);
        CGContextAddPath(context, path.CGPath);
        CGContextStrokePath(context);

        CGContextSetStrokeColorWithColor(context, [UIColor whiteColor].CGColor);
        CGContextSetLineWidth(context, faceW * 0.022);
        CGContextAddPath(context, path.CGPath);
        CGContextStrokePath(context);

        // 2. Draw floating sketched hearts
        CGFloat cx = 0.0;
        CGFloat foreheadY = faceH * 0.45;
        CGFloat time = [[NSProcessInfo processInfo] systemUptime] * 1000.0;

        CGFloat heartLocations[6][3] = {
            {-0.72, 0.22, 0.16}, {-0.45, 0.42, 0.14},  {0.45, 0.42, 0.14},
            {0.72, 0.22, 0.16},  {-0.85, -0.15, 0.15}, {0.85, -0.15, 0.15}};

        for (int i = 0; i < 6; i++) {
          CGFloat rx = heartLocations[i][0];
          CGFloat ry = heartLocations[i][1];
          CGFloat sizeMult = heartLocations[i][2];

          CGFloat bobY = sin(time * 0.0022 + i * 1.5) * faceH * 0.03;
          CGFloat bobX = cos(time * 0.0018 + i * 0.9) * faceW * 0.02;
          CGFloat hCx = cx + rx * faceW + bobX;
          CGFloat hCy = foreheadY + ry * faceH + bobY;
          CGFloat size = faceW * sizeMult;

          CGContextSaveGState(context);
          CGContextTranslateCTM(context, hCx, hCy);
          CGContextRotateCTM(context, sin(time * 0.001 + i) * 0.15);

          UIBezierPath *hPath = [UIBezierPath bezierPath];
          CGFloat hw = size * 0.45;
          CGFloat hh = size * 0.45;

          [hPath moveToPoint:CGPointMake(0, -hh * 0.7)];
          [hPath addCurveToPoint:CGPointMake(-hw, hh * 0.3)
                   controlPoint1:CGPointMake(-hw, -hh * 0.2)
                   controlPoint2:CGPointMake(-hw * 1.1, hh * 0.6)];
          [hPath addCurveToPoint:CGPointMake(0, hh * 0.1)
                   controlPoint1:CGPointMake(-hw * 0.4, hh * 1.1)
                   controlPoint2:CGPointMake(0, hh * 0.6)];
          [hPath addCurveToPoint:CGPointMake(hw, hh * 0.3)
                   controlPoint1:CGPointMake(0, hh * 0.6)
                   controlPoint2:CGPointMake(hw * 0.4, hh * 1.1)];
          [hPath addCurveToPoint:CGPointMake(0, -hh * 0.7)
                   controlPoint1:CGPointMake(hw * 1.1, hh * 0.6)
                   controlPoint2:CGPointMake(hw, -hh * 0.2)];

          CGContextSetStrokeColorWithColor(context,
                                           [UIColor whiteColor].CGColor);
          CGContextSetLineWidth(context, faceW * 0.018);
          CGContextSetShadowWithColor(context, CGSizeZero, size * 0.2,
                                      [UIColor whiteColor].CGColor);
          CGContextAddPath(context, hPath.CGPath);
          CGContextStrokePath(context);

          CGContextRestoreGState(context);
        }

        // 3. Draw sketched clouds at the bottom
        CGFloat cloudXOffsets[2] = {-0.48, 0.48};
        CGFloat clY =
            leftJaw.y -
            faceH *
                0.22; // iOS Y points UP, so subtract to go DOWN from the jaw

        for (int i = 0; i < 2; i++) {
          CGFloat clX = cx + cloudXOffsets[i] * faceW;
          CGFloat clW = faceW * 0.35;
          CGFloat clH = faceH * 0.18;

          CGContextSaveGState(context);
          CGFloat bob = sin(time * 0.0022 + i) * faceH * 0.02;
          CGContextTranslateCTM(context, clX, clY + bob);

          UIBezierPath *cPath = [UIBezierPath bezierPath];
          [cPath moveToPoint:CGPointMake(-clW * 0.4, -clH * 0.2)];
          [cPath addLineToPoint:CGPointMake(clW * 0.4, -clH * 0.2)];
          [cPath addQuadCurveToPoint:CGPointMake(clW * 0.35, clH * 0.3)
                        controlPoint:CGPointMake(clW * 0.55, clH * 0.1)];
          [cPath addQuadCurveToPoint:CGPointMake(0, clH * 0.4)
                        controlPoint:CGPointMake(clW * 0.20, clH * 0.6)];
          [cPath addQuadCurveToPoint:CGPointMake(-clW * 0.35, clH * 0.3)
                        controlPoint:CGPointMake(-clW * 0.20, clH * 0.6)];
          [cPath addQuadCurveToPoint:CGPointMake(-clW * 0.4, -clH * 0.2)
                        controlPoint:CGPointMake(-clW * 0.55, clH * 0.1)];
          [cPath closePath];

          CGContextSetStrokeColorWithColor(
              context,
              [[UIColor whiteColor] colorWithAlphaComponent:200.0 / 255.0]
                  .CGColor);
          CGContextSetLineWidth(context, clW * 0.035);
          CGContextAddPath(context, cPath.CGPath);
          CGContextStrokePath(context);

          CGContextRestoreGState(context);
        }
      }
    }

    CGContextRestoreGState(context);
  }

  // Non-face overlays
  if ([_filter isEqualToString:@"snap_day_stamp"]) {
    UIGraphicsPushContext(context);
    CGContextSaveGState(context);
    CGContextTranslateCTM(context, 0, height);
    CGContextScaleCTM(context, 1.0, -1.0);

    // Radial wash gradient
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGFloat locations[] = {0.0, 0.6, 1.0};
    NSArray *colors = @[
      (__bridge id)[UIColor colorWithRed:255 / 255.0
                                   green:246 / 255.0
                                    blue:235 / 255.0
                                   alpha:0.0]
          .CGColor,
      (__bridge id)[UIColor colorWithRed:255 / 255.0
                                   green:239 / 255.0
                                    blue:224 / 255.0
                                   alpha:18 / 255.0]
          .CGColor,
      (__bridge id)[UIColor colorWithRed:230 / 255.0
                                   green:210 / 255.0
                                    blue:190 / 255.0
                                   alpha:72 / 255.0]
          .CGColor
    ];
    CGGradientRef gradient = CGGradientCreateWithColors(
        colorSpace, (__bridge CFArrayRef)colors, locations);
    CGPoint center = CGPointMake(width * 0.55, height * 0.28);
    CGFloat radius = MAX(width, height) * 0.95;
    CGContextDrawRadialGradient(context, gradient, center, 0, center, radius,
                                kCGGradientDrawsBeforeStartLocation |
                                    kCGGradientDrawsAfterEndLocation);
    CGGradientRelease(gradient);
    CGColorSpaceRelease(colorSpace);
    CGColorSpaceRelease(colorSpace);

    NSDate *now = [NSDate date];
    NSDateFormatter *timeFmt = [[NSDateFormatter alloc] init];
    [timeFmt setDateFormat:@"HH:mm"];
    NSString *timeText = [timeFmt stringFromDate:now];

    NSDateFormatter *dayFmt = [[NSDateFormatter alloc] init];
    [dayFmt setDateFormat:@"EEEE"];
    NSString *dayText = [[dayFmt stringFromDate:now] uppercaseString];

    NSShadow *timeShadow = [[NSShadow alloc] init];
    timeShadow.shadowBlurRadius = height * 0.004;
    timeShadow.shadowColor = [UIColor colorWithWhite:0 alpha:70 / 255.0];

    NSDictionary *timeAttrs = @{
      NSFontAttributeName : [UIFont systemFontOfSize:height * 0.044],
      NSForegroundColorAttributeName : [UIColor colorWithWhite:1.0
                                                         alpha:225 / 255.0],
      NSShadowAttributeName : timeShadow
    };

    NSShadow *dayShadow = [[NSShadow alloc] init];
    dayShadow.shadowBlurRadius = height * 0.006;
    dayShadow.shadowColor = [UIColor colorWithWhite:0 alpha:90 / 255.0];

    NSDictionary *dayAttrs = @{
      NSFontAttributeName : [UIFont fontWithName:@"TimesNewRomanPS-BoldMT"
                                            size:height * 0.080]
          ?: [UIFont boldSystemFontOfSize:height * 0.080],
      NSForegroundColorAttributeName : [UIColor colorWithRed:255 / 255.0
                                                       green:248 / 255.0
                                                        blue:240 / 255.0
                                                       alpha:240 / 255.0],
      NSShadowAttributeName : dayShadow,
      NSKernAttributeName : @(height * 0.080 * 0.02)
    };

    CGFloat left = width * 0.12;
    CGFloat baseline = height * 0.80;

    // Draw text (since context is Y-down due to scale, drawing at Y is normal
    // UIKit style)
    [timeText drawAtPoint:CGPointMake(left, baseline - (height * 0.080) * 0.82)
           withAttributes:timeAttrs];
    [dayText drawAtPoint:CGPointMake(left, baseline) withAttributes:dayAttrs];

    CGContextRestoreGState(context);
    UIGraphicsPopContext();

  } else if ([_filter isEqualToString:@"snap_city_time"]) {
    // 1. In iOS, the camera feed is already drawn over the whole context.
    // To match Android, the camera feed should only occupy the top rect (height
    // = width * 1.22). So we draw a black rectangle over the remaining bottom
    // portion.
    CGFloat rectH = width * 1.22;
    CGFloat blackH = height - rectH;

    // Y-up: bottom part is from y=0 to y=blackH
    CGContextSetFillColorWithColor(context, [UIColor blackColor].CGColor);
    CGContextFillRect(context, CGRectMake(0, 0, width, blackH));

    UIGraphicsPushContext(context);
    CGContextSaveGState(context);
    // Translate and scale for text drawing (Y-down)
    CGContextTranslateCTM(context, 0, height);
    CGContextScaleCTM(context, 1.0, -1.0);

    // 2. Format dynamic time as HH:mm (24-hour format)
    NSDateFormatter *tf = [[NSDateFormatter alloc] init];
    [tf setDateFormat:@"HH:mm"];
    NSString *timeStr = [tf stringFromDate:[NSDate date]];

    // 3. Draw golden-orange cursive/italic text on the left
    UIColor *goldColor = [UIColor colorWithRed:0xe0 / 255.0
                                         green:0x9f / 255.0
                                          blue:0x3e / 255.0
                                         alpha:1.0];
    UIFont *font = [UIFont fontWithName:@"Georgia-Italic" size:width * 0.052];
    if (!font)
      font = [UIFont italicSystemFontOfSize:width * 0.052];

    NSDictionary *attrs = @{
      NSFontAttributeName : font,
      NSForegroundColorAttributeName : goldColor
    };

    CGFloat left = width * 0.12;
    // In Y-down (after transform), the bottom of the camera feed is at y =
    // rectH. We draw the text just below it: rectH + width * 0.08
    CGFloat textY = rectH + width * 0.08;

    [timeStr drawAtPoint:CGPointMake(left, textY) withAttributes:attrs];

    CGContextRestoreGState(context);
    UIGraphicsPopContext();

  } else if ([_filter isEqualToString:@"snap_heart_frame"]) {
    // 1. Draw black mask with a rounded rectangle hole
    // In iOS, the camera feed might be 16:9 while the screen is 19.5:9.
    // This causes aspect-fill cropping on the left and right (up to ~10% each
    // side). So we use a narrower rect to ensure the heart isn't cut off.
    CGFloat rectW = width * 0.68;
    CGFloat rectH = rectW * 0.58;
    CGFloat rectLeft = (width - rectW) / 2.0;
    CGFloat rectTop = (height - rectH) / 2.0;
    CGRect rect = CGRectMake(rectLeft, rectTop, rectW, rectH);
    CGFloat cornerRadius = rectH * 0.12;

    CGContextSaveGState(context);
    UIBezierPath *maskPath =
        [UIBezierPath bezierPathWithRect:CGRectMake(0, 0, width, height)];
    UIBezierPath *holePath =
        [UIBezierPath bezierPathWithRoundedRect:rect cornerRadius:cornerRadius];
    [maskPath appendPath:holePath];
    maskPath.usesEvenOddFillRule = YES;

    CGContextSetFillColorWithColor(context, [UIColor blackColor].CGColor);
    CGContextAddPath(context, maskPath.CGPath);
    CGContextDrawPath(context, kCGPathEOFill);

    // 2. Draw border
    CGContextSetStrokeColorWithColor(
        context, [UIColor colorWithWhite:1.0 alpha:0x88 / 255.0].CGColor);
    CGContextSetLineWidth(context, width * 0.006);
    CGContextAddPath(context, holePath.CGPath);
    CGContextStrokePath(context);

    // 3. Draw single 3D glossy pink heart at the top-right corner
    CGFloat heartSize =
        rectW * 0.22; // Slightly larger relative to the smaller rect
    // Move slightly inwards so it doesn't touch the very edge
    CGFloat heartCx = rectLeft + rectW - heartSize * 0.1;
    CGFloat heartCy = rectTop + rectH - heartSize * 0.1;

    CGContextTranslateCTM(context, heartCx, heartCy);
    // In iOS Y-up, positive rotation is CCW. Android uses -15 (CCW in Y-down).
    // The screenshot shows the heart tilted outwards to the right.
    // We'll rotate by -15.0 in iOS to tilt it outwards to the right.
    CGContextRotateCTM(context, -15.0 * M_PI / 180.0);

    CGFloat hw = heartSize;
    CGFloat hh = heartSize * 1.05;

    // Android heart path (Y-down coordinates translated to Y-up)
    // Android uses +hh * 0.35 for the bottom tip, and negative values for the
    // top lobes. In iOS (Y-up), to keep the heart upright, we must invert the Y
    // values!
    UIBezierPath *heartPath = [UIBezierPath bezierPath];
    [heartPath moveToPoint:CGPointMake(0, -hh * 0.35)]; // Invert Y
    [heartPath addCurveToPoint:CGPointMake(-hw * 0.12, hh * 0.45)
                 controlPoint1:CGPointMake(-hw * 0.45, hh * 0.08)
                 controlPoint2:CGPointMake(-hw * 0.40, hh * 0.45)];
    [heartPath addCurveToPoint:CGPointMake(0, hh * 0.10)
                 controlPoint1:CGPointMake(0, hh * 0.45)
                 controlPoint2:CGPointMake(0, hh * 0.10)];
    [heartPath addCurveToPoint:CGPointMake(hw * 0.12, hh * 0.45)
                 controlPoint1:CGPointMake(0, hh * 0.10)
                 controlPoint2:CGPointMake(0, hh * 0.45)];
    [heartPath addCurveToPoint:CGPointMake(0, -hh * 0.35)
                 controlPoint1:CGPointMake(hw * 0.40, hh * 0.45)
                 controlPoint2:CGPointMake(hw * 0.45, hh * 0.08)];
    [heartPath closePath];

    // Realistic multi-layered drop shadow
    for (int i = 1; i <= 4; i++) {
      CGFloat offset = heartSize * 0.02 * i;
      // Adjust shadow offset for Y-up (Android offset is down-right, so Y
      // offset should be negative in Y-up)
      CGContextSaveGState(context);
      CGContextTranslateCTM(context, offset, -offset);
      CGFloat alpha = (0x24 / (CGFloat)i) / 255.0;
      CGContextSetFillColorWithColor(
          context, [UIColor colorWithWhite:0 alpha:alpha].CGColor);
      CGContextAddPath(context, heartPath.CGPath);
      CGContextFillPath(context);
      CGContextRestoreGState(context);
    }

    // Radial gradient for glossy look
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    NSArray *colors = @[
      (__bridge id)[UIColor colorWithRed:0xff / 255.0
                                   green:0x8b / 255.0
                                    blue:0xb6 / 255.0
                                   alpha:1.0]
          .CGColor,
      (__bridge id)[UIColor colorWithRed:0xff / 255.0
                                   green:0x2e / 255.0
                                    blue:0x74 / 255.0
                                   alpha:1.0]
          .CGColor,
      (__bridge id)[UIColor colorWithRed:0xb3 / 255.0
                                   green:0x00 / 255.0
                                    blue:0x3b / 255.0
                                   alpha:1.0]
          .CGColor
    ];
    CGFloat locations[] = {0.0, 0.6, 1.0};
    CGGradientRef gradient = CGGradientCreateWithColors(
        colorSpace, (__bridge CFArrayRef)colors, locations);
    // Move highlight to top-right (positive X, positive Y in iOS Y-up) to match
    // the screenshot
    CGPoint gradCenter = CGPointMake(heartSize * 0.15, heartSize * 0.15);
    CGFloat gradRadius = heartSize * 0.8;

    CGContextSaveGState(context);
    CGContextAddPath(context, heartPath.CGPath);
    CGContextClip(context);
    CGContextDrawRadialGradient(
        context, gradient, gradCenter, 0, gradCenter, gradRadius,
        kCGGradientDrawsBeforeStartLocation | kCGGradientDrawsAfterEndLocation);
    CGContextRestoreGState(context);

    CGGradientRelease(gradient);
    CGColorSpaceRelease(colorSpace);
    CGColorSpaceRelease(colorSpace);

    CGContextRestoreGState(context);

  } else if ([_filter isEqualToString:@"snap_wanted_poster"]) {
    NSArray *brickColors = @[
      [UIColor colorWithRed:0x7A / 255.0
                      green:0x24 / 255.0
                       blue:0x14 / 255.0
                      alpha:1.0],
      [UIColor colorWithRed:0x69 / 255.0
                      green:0x1F / 255.0
                       blue:0x11 / 255.0
                      alpha:1.0],
      [UIColor colorWithRed:0x8A / 255.0
                      green:0x35 / 255.0
                       blue:0x23 / 255.0
                      alpha:1.0],
      [UIColor colorWithRed:0x57 / 255.0
                      green:0x1A / 255.0
                       blue:0x0E / 255.0
                      alpha:1.0],
      [UIColor colorWithRed:0x9C / 255.0
                      green:0x44 / 255.0
                       blue:0x30 / 255.0
                      alpha:1.0]
    ];
    CGFloat rowH = height / 16.0;
    CGFloat brickW = width / 3.5;

    for (int row = 0; row < 17; row++) {
      CGFloat top = row * rowH;
      CGFloat offset = (row % 2 == 0) ? 0.0 : -brickW / 2.0;
      CGFloat left = offset;

      while (left < width + brickW) {
        int seed = row * 37 + (int)(left / brickW) * 17;
        int index = abs(seed) % brickColors.count;

        CGRect rect = CGRectMake(left, top, brickW, rowH);
        CGContextSetFillColorWithColor(context,
                                       ((UIColor *)brickColors[index]).CGColor);
        CGContextFillRect(context, rect);

        CGContextSetStrokeColorWithColor(context,
                                         [UIColor colorWithRed:0xBF / 255.0
                                                         green:0xB2 / 255.0
                                                          blue:0xA3 / 255.0
                                                         alpha:1.0]
                                             .CGColor);
        CGContextSetLineWidth(context, width * 0.008);
        CGContextStrokeRect(context, rect);

        left += brickW;
      }
    }

    CGFloat posterW = width * 0.84;
    CGFloat posterH = posterW * 1.45;
    CGFloat posterLeft = (width - posterW) / 2.0;
    CGFloat posterTop = (height - posterH) / 2.0;
    CGRect posterRect = CGRectMake(posterLeft, posterTop, posterW, posterH);

    CGContextSetFillColorWithColor(context,
                                   [[UIColor colorWithRed:0xEE / 255.0
                                                    green:0xDA / 255.0
                                                     blue:0xB3 / 255.0
                                                    alpha:1.0] CGColor]);
    CGContextFillRect(context, posterRect);

    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGFloat locations[] = {0.0, 0.7, 1.0};
    NSArray *colors = @[
      (__bridge id)[UIColor clearColor].CGColor,
      (__bridge id)[UIColor colorWithWhite:0.0 alpha:0.1].CGColor,
      (__bridge id)[UIColor colorWithRed:100 / 255.0
                                   green:60 / 255.0
                                    blue:20 / 255.0
                                   alpha:0.33]
          .CGColor
    ];
    CGGradientRef gradient = CGGradientCreateWithColors(
        colorSpace, (__bridge CFArrayRef)colors, locations);
    CGContextSaveGState(context);
    CGContextClipToRect(context, posterRect);
    CGContextDrawRadialGradient(
        context, gradient, CGPointMake(width / 2, height / 2), 0,
        CGPointMake(width / 2, height / 2), posterH * 0.7, 0);
    CGGradientRelease(gradient);
    CGColorSpaceRelease(colorSpace);
    CGColorSpaceRelease(colorSpace);
    CGContextRestoreGState(context);

    CGFloat borderOffset = posterW * 0.024;
    CGRect innerBorder = CGRectInset(posterRect, borderOffset, borderOffset);
    CGContextSetStrokeColorWithColor(context,
                                     [[UIColor colorWithRed:0x2B / 255.0
                                                      green:0x22 / 255.0
                                                       blue:0x1A / 255.0
                                                      alpha:1.0] CGColor]);
    CGContextSetLineWidth(context, posterW * 0.008);
    CGContextStrokeRect(context, innerBorder);

    CGFloat frameW = posterW * 0.82;
    CGFloat frameH = frameW * 0.96;
    CGFloat frameLeft = posterLeft + (posterW - frameW) / 2.0;
    CGFloat frameTop = posterTop + posterH * 0.215;
    CGRect frameRect = CGRectMake(frameLeft, frameTop, frameW, frameH);

    UIGraphicsPushContext(context);
    CGContextSaveGState(context);
    CGContextTranslateCTM(context, 0, height);
    CGContextScaleCTM(context, 1.0, -1.0);

    CGFloat cx = width / 2.0;
    NSDictionary *wantedAttrs = @{
      NSFontAttributeName : [UIFont boldSystemFontOfSize:posterW * 0.15],
      NSForegroundColorAttributeName : [UIColor colorWithRed:0x1C / 255.0
                                                       green:0x14 / 255.0
                                                        blue:0x0E / 255.0
                                                       alpha:1.0]
    };
    NSString *str1 = @"WANTED";
    CGSize sz = [str1 sizeWithAttributes:wantedAttrs];
    [str1 drawAtPoint:CGPointMake(cx - sz.width / 2.0,
                                  height - (posterTop + posterH * 0.125) -
                                      sz.height / 2.0)
        withAttributes:wantedAttrs];

    NSDictionary *doaAttrs = @{
      NSFontAttributeName : [UIFont boldSystemFontOfSize:posterW * 0.062],
      NSForegroundColorAttributeName : [UIColor colorWithRed:0x1C / 255.0
                                                       green:0x14 / 255.0
                                                        blue:0x0E / 255.0
                                                       alpha:1.0]
    };
    NSString *str2 = @"★ DEAD OR ALIVE ★";
    sz = [str2 sizeWithAttributes:doaAttrs];
    [str2 drawAtPoint:CGPointMake(cx - sz.width / 2.0,
                                  height - (posterTop + posterH * 0.185) -
                                      sz.height / 2.0)
        withAttributes:doaAttrs];

    NSString *str3 = @"$1,000,000 REWARD";
    sz = [str3 sizeWithAttributes:doaAttrs];
    [str3 drawAtPoint:CGPointMake(cx - sz.width / 2.0,
                                  height - (posterTop + posterH * 0.865) -
                                      sz.height / 2.0)
        withAttributes:doaAttrs];

    NSDictionary *subAttrs = @{
      NSFontAttributeName : [UIFont boldSystemFontOfSize:posterW * 0.055],
      NSForegroundColorAttributeName : [UIColor colorWithRed:0x1C / 255.0
                                                       green:0x14 / 255.0
                                                        blue:0x0E / 255.0
                                                       alpha:1.0]
    };
    NSString *str4 = @"DANGEROUSLY CUTE";
    sz = [str4 sizeWithAttributes:subAttrs];
    [str4 drawAtPoint:CGPointMake(cx - sz.width / 2.0,
                                  height - (posterTop + posterH * 0.93) -
                                      sz.height / 2.0)
        withAttributes:subAttrs];

    CGContextRestoreGState(context);
    UIGraphicsPopContext();

    CGContextSaveGState(context);
    CGContextClipToRect(context, frameRect);
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), cgImage);
    CGContextRestoreGState(context);

    CGContextSetStrokeColorWithColor(context,
                                     [[UIColor colorWithRed:0x2B / 255.0
                                                      green:0x22 / 255.0
                                                       blue:0x1A / 255.0
                                                      alpha:1.0] CGColor]);
    CGContextSetLineWidth(context, posterW * 0.016);
    CGContextStrokeRect(context, frameRect);

  } else if ([_filter isEqualToString:@"snap_creator_hud"]) {
    CGFloat cx = width / 2.0;
    CGFloat cy = height * 0.4;
    CGFloat r = MAX(width, height) * 0.85;
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGFloat locations[3] = {0.0, 0.55, 1.0};
    CGFloat colors[12] = {255.0 / 255.0, 235.0 / 255.0, 215.0 / 255.0,
                          26.0 / 255.0,  255.0 / 255.0, 220.0 / 255.0,
                          200.0 / 255.0, 14.0 / 255.0,  235.0 / 255.0,
                          205.0 / 255.0, 185.0 / 255.0, 40.0 / 255.0};
    CGGradientRef gradient =
        CGGradientCreateWithColorComponents(colorSpace, colors, locations, 3);
    CGContextDrawRadialGradient(
        context, gradient, CGPointMake(cx, cy), 0, CGPointMake(cx, cy), r,
        kCGGradientDrawsAfterEndLocation | kCGGradientDrawsBeforeStartLocation);
    CGGradientRelease(gradient);
    CGColorSpaceRelease(colorSpace);
    CGColorSpaceRelease(colorSpace);
  } else if ([_filter isEqualToString:@"snap_fashion_overlay"]) {
    static UIImage *fashionBg = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      fashionBg = [UIImage imageNamed:@"fashion_girl.png"];
      if (!fashionBg)
        fashionBg = [UIImage imageNamed:@"fashion_girl"];
    });
    if (fashionBg) {
      CGFloat bgW = fashionBg.size.width;
      CGFloat bgH = fashionBg.size.height;
      CGFloat scale = MAX(width / bgW, height / bgH);
      CGFloat drawW = bgW * scale;
      CGFloat drawH = bgH * scale;
      CGFloat drawX = (width - drawW) / 2.0;
      CGFloat drawY = (height - drawH) / 2.0;

      CGContextSaveGState(context);

      // Draw static background
      CGContextDrawImage(context, CGRectMake(drawX, drawY, drawW, drawH),
                         fashionBg.CGImage);

      // Draw live camera feed on top with opacity (alpha = 90 / 255)
      CGContextRestoreGState(context);

      CGContextSaveGState(context);
      CGContextSetAlpha(context, 90.0 / 255.0);
      CGContextDrawImage(context, CGRectMake(0, 0, width, height), cgImage);
      CGContextRestoreGState(context);
    }

  } else if ([_filter isEqualToString:@"snap_retro_skull"]) {
    static UIImage *skullImage = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      skullImage = [UIImage imageNamed:@"retro_skull.png"];
      if (!skullImage)
        skullImage = [UIImage imageNamed:@"retro_skull"];
    });
    if (skullImage) {
      CGFloat cx = width * 0.5;
      CGFloat cy =
          height *
          0.36; // 64% from top in Android = 36% from bottom in iOS (+Y is up)
      CGFloat skullW = width * 0.20;
      CGFloat skullH =
          skullW * (skullImage.size.height / skullImage.size.width);

      CGContextSaveGState(context);
      CGContextTranslateCTM(context, cx, cy);

      CGContextDrawImage(context,
                         CGRectMake(-skullW / 2, -skullH / 2, skullW, skullH),
                         skullImage.CGImage);

      CGContextRestoreGState(context);
    }
  } else if ([_filter isEqualToString:@"snap_eyes_reveal"]) {
    CGFloat cx = width * 0.5;
    CGFloat cy = height * 0.58;
    CGFloat halfW = width * 0.52;
    CGFloat halfH = height * 0.082;

    int steps = 100;
    CGFloat stepSize = (halfW * 2.0) / steps;

    // Top black shape
    CGContextBeginPath(context);
    CGContextMoveToPoint(context, 0, height);
    CGContextAddLineToPoint(context, width, height);
    for (int i = steps; i >= 0; i--) {
      CGFloat x = cx - halfW + i * stepSize;
      CGFloat freq = 1.0;
      CGFloat offset = sin(x * 0.04 * freq) * 8.0 +
                       cos(x * 0.095 * freq) * 5.0 + sin(x * 0.22 * freq) * 2.5;
      CGFloat y = cy + halfH + offset;
      CGContextAddLineToPoint(context, x, y);
    }
    CGContextClosePath(context);
    CGContextSetFillColorWithColor(context, [UIColor blackColor].CGColor);
    CGContextFillPath(context);

    // Top white border
    CGContextBeginPath(context);
    for (int i = steps; i >= 0; i--) {
      CGFloat x = cx - halfW + i * stepSize;
      CGFloat offset = sin(x * 0.04 * 1.0) * 8.0 + cos(x * 0.095 * 1.0) * 5.0 +
                       sin(x * 0.22 * 1.0) * 2.5;
      CGFloat y = cy + halfH + offset;
      if (i == steps) {
        CGContextMoveToPoint(context, x, y);
      } else {
        CGContextAddLineToPoint(context, x, y);
      }
    }
    CGContextSetStrokeColorWithColor(context, [UIColor whiteColor].CGColor);
    CGContextSetLineWidth(context, width * 0.012);
    CGContextSetLineJoin(context, kCGLineJoinRound);
    CGContextSetLineCap(context, kCGLineCapRound);
    CGContextStrokePath(context);

    // Bottom black shape
    CGContextBeginPath(context);
    CGContextMoveToPoint(context, 0, 0);
    CGContextAddLineToPoint(context, width, 0);
    for (int i = steps; i >= 0; i--) {
      CGFloat x = cx - halfW + i * stepSize;
      CGFloat freq = 1.2;
      CGFloat offset = sin(x * 0.04 * freq) * 8.0 +
                       cos(x * 0.095 * freq) * 5.0 + sin(x * 0.22 * freq) * 2.5;
      CGFloat y = cy - halfH + offset;
      CGContextAddLineToPoint(context, x, y);
    }
    CGContextClosePath(context);
    CGContextSetFillColorWithColor(context, [UIColor blackColor].CGColor);
    CGContextFillPath(context);

    // Bottom white border
    CGContextBeginPath(context);
    for (int i = steps; i >= 0; i--) {
      CGFloat x = cx - halfW + i * stepSize;
      CGFloat offset = sin(x * 0.04 * 1.2) * 8.0 + cos(x * 0.095 * 1.2) * 5.0 +
                       sin(x * 0.22 * 1.2) * 2.5;
      CGFloat y = cy - halfH + offset;
      if (i == steps) {
        CGContextMoveToPoint(context, x, y);
      } else {
        CGContextAddLineToPoint(context, x, y);
      }
    }
    CGContextStrokePath(context);

    // Draw Text
    NSString *text = @"eyes always reveal the truth 👀✨";
    UIFont *font = [UIFont italicSystemFontOfSize:width * 0.046];
    UIFontDescriptor *fontDescriptor = [font.fontDescriptor
        fontDescriptorWithSymbolicTraits:UIFontDescriptorTraitBold |
                                         UIFontDescriptorTraitItalic];
    if (fontDescriptor) {
      font = [UIFont fontWithDescriptor:fontDescriptor size:width * 0.046];
    }

    NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
    style.alignment = NSTextAlignmentCenter;
    NSDictionary *attrs = @{
      NSFontAttributeName : font,
      NSForegroundColorAttributeName : [UIColor whiteColor],
      NSParagraphStyleAttributeName : style
    };

    CGSize textSize = [text sizeWithAttributes:attrs];
    CGFloat textY = cy - halfH - width * 0.12 - textSize.height / 2.0;

    CGContextSaveGState(context);
    CGContextTranslateCTM(context, 0, height);
    CGContextScaleCTM(context, 1.0, -1.0);

    UIGraphicsPushContext(context);
    CGFloat flippedTextY = height - textY - textSize.height;
    [text drawInRect:CGRectMake(0, flippedTextY, width, textSize.height)
        withAttributes:attrs];
    UIGraphicsPopContext();

    CGContextRestoreGState(context);

  } else if ([_filter isEqualToString:@"snap_sunset_cowboy"]) {
    CGContextSetFillColorWithColor(
        context,
        [[UIColor systemOrangeColor] colorWithAlphaComponent:0.3].CGColor);
    CGContextSetBlendMode(context, kCGBlendModeColorBurn);
    CGContextFillRect(context, CGRectMake(0, 0, width, height));
    CGContextSetBlendMode(context, kCGBlendModeNormal);

  } else if ([_filter isEqualToString:@"vintage"]) {
    // 1. Draw Vignette
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    CGFloat locs[] = {0.0, 0.55, 1.0};
    NSArray *vignetteColors = @[
      (__bridge id)[UIColor colorWithWhite:0 alpha:0.0].CGColor,
      (__bridge id)[UIColor colorWithWhite:0 alpha:0.0].CGColor,
      (__bridge id)[UIColor colorWithWhite:0 alpha:0.66].CGColor
    ];
    CGGradientRef vignetteGrad = CGGradientCreateWithColors(
        cs, (__bridge CFArrayRef)vignetteColors, locs);
    CGPoint center = CGPointMake(width / 2.0, height / 2.0);
    CGFloat radius = MAX(width, height) * 0.75;

    CGContextDrawRadialGradient(
        context, vignetteGrad, center, 0, center, radius,
        kCGGradientDrawsBeforeStartLocation | kCGGradientDrawsAfterEndLocation);
    CGGradientRelease(vignetteGrad);

    // 2. Draw Heavy Film Grain (Tiled Noise)
    static CGImageRef noiseTile = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      int size = 64;
      size_t bytesPerRow = size * 4;
      uint32_t *pixels = malloc(size * bytesPerRow);
      for (int i = 0; i < size * size; i++) {
        uint8_t a = 38;                                    // ~15% alpha
        uint8_t val = (arc4random_uniform(256) * a) / 255; // Premultiplied
        pixels[i] = (a << 24) | (val << 16) | (val << 8) | val;
      }
      CGContextRef ctx = CGBitmapContextCreate(
          pixels, size, size, 8, bytesPerRow, cs,
          kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little);
      noiseTile = CGBitmapContextCreateImage(ctx);
      CGContextRelease(ctx);
      free(pixels);
    });

    if (noiseTile) {
      CGContextSaveGState(context);
      CGContextSetBlendMode(context, kCGBlendModeScreen);
      CGContextDrawTiledImage(context, CGRectMake(0, 0, 64, 64), noiseTile);
      CGContextRestoreGState(context);
    }
    CGColorSpaceRelease(cs);

  } else if ([_filter isEqualToString:@"snap_vintage_grain"]) {
    // 1. Draw Vignette
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    CGFloat locs[] = {0.0, 0.55, 1.0};
    NSArray *vignetteColors = @[
      (__bridge id)[UIColor colorWithWhite:0 alpha:0.0].CGColor,
      (__bridge id)[UIColor colorWithWhite:0 alpha:0.0].CGColor,
      (__bridge id)[UIColor colorWithWhite:0 alpha:0.66].CGColor
    ];
    CGGradientRef vignetteGrad = CGGradientCreateWithColors(
        cs, (__bridge CFArrayRef)vignetteColors, locs);
    CGPoint center = CGPointMake(width / 2.0, height / 2.0);
    CGFloat radius = MAX(width, height) * 0.75;

    CGContextDrawRadialGradient(
        context, vignetteGrad, center, 0, center, radius,
        kCGGradientDrawsBeforeStartLocation | kCGGradientDrawsAfterEndLocation);
    CGGradientRelease(vignetteGrad);

    // 2. Draw Heavy Film Grain (Tiled Noise)
    static CGImageRef noiseTile = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      int size = 64;
      size_t bytesPerRow = size * 4;
      uint32_t *pixels = malloc(size * bytesPerRow);
      for (int i = 0; i < size * size; i++) {
        uint8_t a = 38;                                    // ~15% alpha
        uint8_t val = (arc4random_uniform(256) * a) / 255; // Premultiplied
        pixels[i] = (a << 24) | (val << 16) | (val << 8) | val;
      }
      CGContextRef ctx = CGBitmapContextCreate(
          pixels, size, size, 8, bytesPerRow, cs,
          kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little);
      noiseTile = CGBitmapContextCreateImage(ctx);
      CGContextRelease(ctx);
      free(pixels);
    });

    if (noiseTile) {
      CGContextSaveGState(context);
      CGContextSetBlendMode(context, kCGBlendModeScreen);
      CGContextDrawTiledImage(context, CGRectMake(0, 0, 64, 64), noiseTile);
      CGContextRestoreGState(context);
    }
    CGColorSpaceRelease(cs);
  }

  CGImageRef result = CGBitmapContextCreateImage(context);
  CGContextRelease(context);
  return result;
}

- (void)captureOutput:(AVCaptureOutput *)output
    didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
           fromConnection:(AVCaptureConnection *)connection {
  BOOL isVideo = (output == self.videoOutput);

  if (isVideo) {
    CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    self.lastVideoWidth = CVPixelBufferGetWidth(pixelBuffer);
    self.lastVideoHeight = CVPixelBufferGetHeight(pixelBuffer);

    // Face Tracking (Vision)
    if (![_filter isEqualToString:@"none"]) {
      VNImageRequestHandler *handler =
          [[VNImageRequestHandler alloc] initWithCVPixelBuffer:pixelBuffer
                                                       options:@{}];
      NSError *error;
      [handler performRequests:@[ self.faceDetectionRequest ] error:&error];
      NSMutableArray *validFaces = [NSMutableArray array];
      for (VNFaceObservation *face in self.faceDetectionRequest.results) {
        if (face.landmarks.leftEye && face.landmarks.rightEye && face.landmarks.faceContour) {
          [validFaces addObject:face];
        }
      }
      self.currentFaces = validFaces;
    } else {
      self.currentFaces = nil;
    }

    CIImage *ciImage = [CIImage imageWithCVPixelBuffer:pixelBuffer];
    if (!ciImage)
      return;

    CIImage *filteredImage = [self applyFilterToImage:ciImage];

    CGImageRef cgImage = [self.ciContext createCGImage:filteredImage
                                              fromRect:filteredImage.extent];
    if (!cgImage)
      return;
    CGImageRef finalImage = [self drawAROverlaysOnImage:cgImage];
    CGImageRelease(cgImage);

    CGImageRetain(finalImage);
    dispatch_async(dispatch_get_main_queue(), ^{
      self.layer.contents = (__bridge id)finalImage;
      CGImageRelease(finalImage);
    });

    if (self.takePhotoNextFrame) {
      self.takePhotoNextFrame = NO;
      CGImageRetain(finalImage);
      CameraFilterResolveBlock currentResolve = self.photoResolve;
      CameraFilterRejectBlock currentReject = self.photoReject;
      self.photoResolve = nil;
      self.photoReject = nil;
      dispatch_async(self.sessionQueue, ^{
        [self processPhotoFromImage:finalImage
                           resolver:currentResolve
                           rejecter:currentReject];
      });
    }

    if (self.isRecording && self.assetWriter &&
        self.assetWriter.status == AVAssetWriterStatusWriting) {
      CMTime timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
      if (CMTIME_IS_INVALID(self.sessionStartTime)) {
        self.sessionStartTime = timestamp;
        [self.assetWriter startSessionAtSourceTime:timestamp];
      }
      if (self.videoWriterInput.readyForMoreMediaData) {
        CVPixelBufferRef outputPixelBuffer = NULL;
        CVPixelBufferPoolCreatePixelBuffer(
            NULL, self.pixelBufferAdaptor.pixelBufferPool, &outputPixelBuffer);

        CIImage *ciFinal = [CIImage imageWithCGImage:finalImage];
        [self.ciContext render:ciFinal toCVPixelBuffer:outputPixelBuffer];

        [self.pixelBufferAdaptor appendPixelBuffer:outputPixelBuffer
                              withPresentationTime:timestamp];
        self.hasWrittenVideo = YES;
        CVPixelBufferRelease(outputPixelBuffer);
      }
    }

    CGImageRelease(finalImage);
  } else {
    if (self.isRecording && self.assetWriter &&
        self.assetWriter.status == AVAssetWriterStatusWriting) {
      if (CMTIME_IS_VALID(self.sessionStartTime) &&
          self.audioWriterInput.readyForMoreMediaData) {
        [self.audioWriterInput appendSampleBuffer:sampleBuffer];
        self.hasWrittenAudio = YES;
      }
    }
  }
}

- (void)processPhotoFromImage:(CGImageRef)cgImage
                     resolver:(CameraFilterResolveBlock)resolve
                     rejecter:(CameraFilterRejectBlock)reject {
  UIImage *uiImage = [UIImage imageWithCGImage:cgImage];
  CGImageRelease(cgImage);
  NSData *data = UIImageJPEGRepresentation(uiImage, 1.0);

  if (!data) {
    dispatch_async(dispatch_get_main_queue(), ^{
      if (reject)
        reject(@"compression_error", @"Failed to compress image data", nil);
    });
    return;
  }

  NSString *fileName = [NSString
      stringWithFormat:@"photo_%f.jpg", [[NSDate date] timeIntervalSince1970]];
  NSString *path =
      [NSTemporaryDirectory() stringByAppendingPathComponent:fileName];
  NSError *error = nil;
  BOOL success = [data writeToFile:path
                           options:NSDataWritingAtomic
                             error:&error];

  dispatch_async(dispatch_get_main_queue(), ^{
    if (success) {
      if (resolve)
        resolve([NSURL fileURLWithPath:path].absoluteString);
    } else {
      if (reject)
        reject(@"write_error", @"Failed to save photo to disk", error);
    }
  });
}

- (void)capturePhotoWithResolver:(CameraFilterResolveBlock)resolve
                        rejecter:(CameraFilterRejectBlock)reject {
  dispatch_async(self.videoQueue, ^{
    self.photoResolve = resolve;
    self.photoReject = reject;
    self.takePhotoNextFrame = YES;
  });
}

- (void)startRecordingWithResolver:(CameraFilterResolveBlock)resolve
                          rejecter:(CameraFilterRejectBlock)reject {
  dispatch_async(self.videoQueue, ^{
    if (self.isRecording) {
      reject(@"error", @"Already recording", nil);
      return;
    }

    NSString *fileName =
        [NSString stringWithFormat:@"video_%@.mp4", [[NSUUID UUID] UUIDString]];
    self.videoOutputPath =
        [NSTemporaryDirectory() stringByAppendingPathComponent:fileName];
    NSURL *url = [NSURL fileURLWithPath:self.videoOutputPath];
    
    // Ensure file doesn't exist just in case
    if ([[NSFileManager defaultManager] fileExistsAtPath:self.videoOutputPath]) {
      [[NSFileManager defaultManager] removeItemAtPath:self.videoOutputPath error:nil];
    }

    NSError *error = nil;
    self.assetWriter = [[AVAssetWriter alloc] initWithURL:url
                                                 fileType:AVFileTypeMPEG4
                                                    error:&error];
    if (error) {
      reject(@"error", @"Could not create asset writer", error);
      return;
    }

    size_t w = self.lastVideoWidth > 0 ? self.lastVideoWidth : 720;
    size_t h = self.lastVideoHeight > 0 ? self.lastVideoHeight : 1280;

    NSDictionary *videoSettings = @{
      AVVideoCodecKey : AVVideoCodecTypeH264,
      AVVideoWidthKey : @(w),
      AVVideoHeightKey : @(h)
    };
    self.videoWriterInput =
        [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeVideo
                                       outputSettings:videoSettings];
    self.videoWriterInput.expectsMediaDataInRealTime = YES;

    self.pixelBufferAdaptor = [[AVAssetWriterInputPixelBufferAdaptor alloc]
           initWithAssetWriterInput:self.videoWriterInput
        sourcePixelBufferAttributes:@{
          (id)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32BGRA)
        }];

    NSDictionary *audioSettings = @{
      AVFormatIDKey : @(kAudioFormatMPEG4AAC),
      AVNumberOfChannelsKey : @1,
      AVSampleRateKey : @44100.0,
      AVEncoderBitRateKey : @64000
    };
    self.audioWriterInput =
        [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeAudio
                                       outputSettings:audioSettings];
    self.audioWriterInput.expectsMediaDataInRealTime = YES;

    if ([self.assetWriter canAddInput:self.videoWriterInput])
      [self.assetWriter addInput:self.videoWriterInput];
    if ([self.assetWriter canAddInput:self.audioWriterInput])
      [self.assetWriter addInput:self.audioWriterInput];

    self.sessionStartTime = kCMTimeInvalid;
    [self.assetWriter startWriting];
    self.isRecording = YES;
    self.hasWrittenVideo = NO;
    self.hasWrittenAudio = NO;
    resolve(nil);
  });
}

- (void)stopRecordingWithResolver:(CameraFilterResolveBlock)resolve
                         rejecter:(CameraFilterRejectBlock)reject {
  dispatch_async(self.videoQueue, ^{
    if (!self.isRecording) {
      reject(@"error", @"Not recording", nil);
      return;
    }
    self.isRecording = NO;

    if (CMTIME_IS_INVALID(self.sessionStartTime) || !self.hasWrittenVideo || !self.hasWrittenAudio) {
      [self.assetWriter cancelWriting];
      resolve(@{
        @"uri" : [NSURL fileURLWithPath:self.videoOutputPath].absoluteString,
        @"durationMs" : @0,
        @"width" : @(self.lastVideoWidth > 0 ? self.lastVideoWidth : 720),
        @"height" : @(self.lastVideoHeight > 0 ? self.lastVideoHeight : 1280)
      });
      self.assetWriter = nil;
      self.videoWriterInput = nil;
      self.audioWriterInput = nil;
      self.pixelBufferAdaptor = nil;
      return;
    }

    [self.videoWriterInput markAsFinished];
    [self.audioWriterInput markAsFinished];

    AVAssetWriter *writerToStop = self.assetWriter;
    [writerToStop finishWritingWithCompletionHandler:^{
      dispatch_async(self.videoQueue, ^{
        resolve(@{
          @"uri" : [NSURL fileURLWithPath:self.videoOutputPath].absoluteString,
          @"durationMs" : @0,
          @"width" : @(self.lastVideoWidth > 0 ? self.lastVideoWidth : 720),
          @"height" : @(self.lastVideoHeight > 0 ? self.lastVideoHeight : 1280)
        });
        if (self.assetWriter == writerToStop) {
            self.assetWriter = nil;
            self.videoWriterInput = nil;
            self.audioWriterInput = nil;
            self.pixelBufferAdaptor = nil;
        }
      });
    }];
  });
}

@end
