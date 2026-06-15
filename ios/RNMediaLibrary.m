#import <React/RCTBridgeModule.h>
#import <React/RCTImageLoaderProtocol.h>
#import <Photos/Photos.h>
#import <AVFoundation/AVFoundation.h>

@interface RNMediaLibrary : NSObject <RCTBridgeModule, RCTImageURLLoader>
@end

@implementation RNMediaLibrary

RCT_EXPORT_MODULE(RNMediaLibrary)

// --- RCTImageURLLoader Implementation ---

- (BOOL)canLoadImageURL:(NSURL *)requestURL {
  return [requestURL.scheme.lowercaseString isEqualToString:@"ph"];
}

- (RCTImageLoaderCancellationBlock)loadImageForURL:(NSURL *)imageURL
                                              size:(CGSize)size
                                             scale:(CGFloat)scale
                                        resizeMode:(RCTResizeMode)resizeMode
                                   progressHandler:(RCTImageLoaderProgressBlock)progressHandler
                                partialLoadHandler:(RCTImageLoaderPartialLoadBlock)partialLoadHandler
                                 completionHandler:(RCTImageLoaderCompletionBlock)completionHandler {
  
  NSString *localIdentifier = [imageURL.absoluteString substringFromIndex:5]; // remove "ph://"
  PHFetchResult<PHAsset *> *assets = [PHAsset fetchAssetsWithLocalIdentifiers:@[localIdentifier] options:nil];
  PHAsset *asset = assets.firstObject;
  
  if (!asset) {
    completionHandler(nil, nil);
    return ^{};
  }
  
  PHImageRequestOptions *options = [[PHImageRequestOptions alloc] init];
  options.networkAccessAllowed = YES;
  options.deliveryMode = PHImageRequestOptionsDeliveryModeHighQualityFormat;
  
  // If size is 0 or very large, request original image
  CGSize targetSize = size;
  if (CGSizeEqualToSize(size, CGSizeZero)) {
    targetSize = PHImageManagerMaximumSize;
  }
  
  PHImageRequestID requestId = [[PHImageManager defaultManager] requestImageForAsset:asset
                                                                          targetSize:targetSize
                                                                         contentMode:PHImageContentModeAspectFill
                                                                             options:options
                                                                       resultHandler:^(UIImage *result, NSDictionary *info) {
    completionHandler(nil, result);
  }];
  
  return ^{
    [[PHImageManager defaultManager] cancelImageRequest:requestId];
  };
}

// --- End RCTImageURLLoader ---

+ (BOOL)requiresMainQueueSetup {
  return YES;
}

RCT_REMAP_METHOD(requestAccess,
                 requestAccessWithResolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
  PHAuthorizationStatus status = [PHPhotoLibrary authorizationStatusForAccessLevel:PHAccessLevelReadWrite];
  if (status == PHAuthorizationStatusAuthorized || status == PHAuthorizationStatusLimited) {
    resolve(@(YES));
    return;
  }
  [PHPhotoLibrary requestAuthorizationForAccessLevel:PHAccessLevelReadWrite handler:^(PHAuthorizationStatus newStatus) {
    BOOL ok = (newStatus == PHAuthorizationStatusAuthorized || newStatus == PHAuthorizationStatusLimited);
    resolve(@(ok));
  }];
}

RCT_REMAP_METHOD(listAlbums,
                 listAlbumsWithResolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
 {
   @try {
     NSMutableArray *results = [NSMutableArray array];
     
     // 1. Smart Albums (Recent, Favorites, etc)
     PHFetchResult<PHAssetCollection *> *smartAlbums = [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeSmartAlbum subtype:PHAssetCollectionSubtypeAny options:nil];
     [smartAlbums enumerateObjectsUsingBlock:^(PHAssetCollection * _Nonnull collection, NSUInteger idx, BOOL * _Nonnull stop) {
       PHFetchResult *assets = [PHAsset fetchAssetsInAssetCollection:collection options:nil];
       if (assets.count > 0) {
         [results addObject:@{
           @"id": collection.localIdentifier,
           @"title": collection.localizedTitle ?: @"Unknown"
         }];
       }
     }];
     
     // 2. User Albums
     PHFetchResult<PHAssetCollection *> *userAlbums = [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeAlbum subtype:PHAssetCollectionSubtypeAny options:nil];
     [userAlbums enumerateObjectsUsingBlock:^(PHAssetCollection * _Nonnull collection, NSUInteger idx, BOOL * _Nonnull stop) {
       PHFetchResult *assets = [PHAsset fetchAssetsInAssetCollection:collection options:nil];
       if (assets.count > 0) {
         [results addObject:@{
           @"id": collection.localIdentifier,
           @"title": collection.localizedTitle ?: @"Unknown"
         }];
       }
     }];
     
     resolve(results);
   } @catch (NSException *exception) {
     reject(@"albums_failed", exception.reason, nil);
   }
 }
 
 RCT_REMAP_METHOD(listMedia,
                  listMediaWithOptions:(NSDictionary *)options
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
 {
   dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
   @try {
     NSNumber *limit = options[@"limit"] ?: @200;
     NSNumber *offset = options[@"offset"] ?: @0;
     NSString *type = options[@"type"] ?: @"all";
     NSString *albumId = options[@"albumId"];
 
     PHFetchOptions *fetchOptions = [[PHFetchOptions alloc] init];
     fetchOptions.sortDescriptors = @[ [NSSortDescriptor sortDescriptorWithKey:@"creationDate" ascending:NO] ];
 
     PHFetchResult<PHAsset *> *assets = nil;
     
     if (albumId) {
       PHFetchResult<PHAssetCollection *> *collections = [PHAssetCollection fetchAssetCollectionsWithLocalIdentifiers:@[albumId] options:nil];
       PHAssetCollection *collection = collections.firstObject;
       if (collection) {
         if ([type isEqualToString:@"image"]) {
           fetchOptions.predicate = [NSPredicate predicateWithFormat:@"mediaType = %d", PHAssetMediaTypeImage];
         } else if ([type isEqualToString:@"video"]) {
           fetchOptions.predicate = [NSPredicate predicateWithFormat:@"mediaType = %d", PHAssetMediaTypeVideo];
         }
         assets = [PHAsset fetchAssetsInAssetCollection:collection options:fetchOptions];
       }
     }
     
     if (!assets) {
       if ([type isEqualToString:@"image"]) {
         assets = [PHAsset fetchAssetsWithMediaType:PHAssetMediaTypeImage options:fetchOptions];
       } else if ([type isEqualToString:@"video"]) {
         assets = [PHAsset fetchAssetsWithMediaType:PHAssetMediaTypeVideo options:fetchOptions];
       } else {
         fetchOptions.predicate = [NSPredicate predicateWithFormat:@"mediaType = %d OR mediaType = %d", PHAssetMediaTypeImage, PHAssetMediaTypeVideo];
         assets = [PHAsset fetchAssetsWithOptions:fetchOptions];
       }
     }

    NSMutableArray *results = [NSMutableArray array];
    PHImageRequestOptions *thumbOptions = [[PHImageRequestOptions alloc] init];
    thumbOptions.synchronous = YES;
    thumbOptions.deliveryMode = PHImageRequestOptionsDeliveryModeHighQualityFormat;
    thumbOptions.resizeMode = PHImageRequestOptionsResizeModeExact;
    thumbOptions.networkAccessAllowed = YES;

    PHImageManager *manager = [PHImageManager defaultManager];
    NSInteger start = offset.integerValue;
    NSInteger end = MIN(start + limit.integerValue, assets.count);

    for (NSInteger i = start; i < end; i++) {
      PHAsset *asset = [assets objectAtIndex:i];
      NSString *mediaType = asset.mediaType == PHAssetMediaTypeVideo ? @"video" : @"image";

      __block NSString *thumbUri = nil;
      CGSize targetSize = CGSizeMake(240, 240);
      [manager requestImageForAsset:asset targetSize:targetSize contentMode:PHImageContentModeAspectFill options:thumbOptions resultHandler:^(UIImage * _Nullable image, NSDictionary * _Nullable info) {
        if (image) {
          NSData *data = UIImageJPEGRepresentation(image, 0.8);
          NSString *fileName = [NSString stringWithFormat:@"thumb_%@.jpg", [[NSUUID UUID] UUIDString]];
          NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:fileName];
          [data writeToFile:path atomically:YES];
          thumbUri = [NSURL fileURLWithPath:path].absoluteString;
        }
      }];

      if (!thumbUri && asset.mediaType == PHAssetMediaTypeVideo) {
        dispatch_semaphore_t sema = dispatch_semaphore_create(0);
        PHVideoRequestOptions *videoOpts = [[PHVideoRequestOptions alloc] init];
        videoOpts.networkAccessAllowed = YES;
        [[PHImageManager defaultManager] requestAVAssetForVideo:asset options:videoOpts resultHandler:^(AVAsset * _Nullable avAsset, AVAudioMix * _Nullable audioMix, NSDictionary * _Nullable info) {
          if (avAsset) {
            AVAssetImageGenerator *gen = [[AVAssetImageGenerator alloc] initWithAsset:avAsset];
            gen.appliesPreferredTrackTransform = YES;
            gen.maximumSize = CGSizeMake(240, 240);
            NSError *err = nil;
            CGImageRef imageRef = [gen copyCGImageAtTime:CMTimeMake(0, 1) actualTime:nil error:&err];
            if (imageRef) {
              UIImage *image = [UIImage imageWithCGImage:imageRef];
              CGImageRelease(imageRef);
              NSData *data = UIImageJPEGRepresentation(image, 0.8);
              NSString *fileName = [NSString stringWithFormat:@"thumb_%@.jpg", [[NSUUID UUID] UUIDString]];
              NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:fileName];
              [data writeToFile:path atomically:YES];
              thumbUri = [NSURL fileURLWithPath:path].absoluteString;
            }
          }
          dispatch_semaphore_signal(sema);
        }];
        dispatch_semaphore_wait(sema, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)));
      }

      __block NSString *fullUri = nil;
      if (asset.mediaType == PHAssetMediaTypeVideo) {
        // Return a ph:// URI for videos so we do not attempt to read system files directly or transcode in listMedia
        fullUri = [NSString stringWithFormat:@"ph://%@", asset.localIdentifier];
      } else {
        [manager requestImageForAsset:asset targetSize:PHImageManagerMaximumSize contentMode:PHImageContentModeAspectFit options:thumbOptions resultHandler:^(UIImage * _Nullable image, NSDictionary * _Nullable info) {
          if (image) {
            NSData *data = UIImageJPEGRepresentation(image, 0.9);
            NSString *fileName = [NSString stringWithFormat:@"full_%@.jpg", [[NSUUID UUID] UUIDString]];
            NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:fileName];
            [data writeToFile:path atomically:YES];
            fullUri = [NSURL fileURLWithPath:path].absoluteString;
          }
        }];
      }

      NSDictionary *item = @{
        @"id": asset.localIdentifier,
        @"uri": fullUri ?: thumbUri ?: @"",
        @"thumbnailUri": thumbUri ?: @"",
        @"type": mediaType,
        @"durationMs": @(asset.duration * 1000.0)
      };
      [results addObject:item];
    }

      resolve(results);
    } @catch (NSException *exception) {
      reject(@"list_failed", exception.reason, nil);
    }
    });
  }

- (void)exportVideoFallback:(PHAsset *)asset
                   resolver:(RCTPromiseResolveBlock)resolve
                   rejecter:(RCTPromiseRejectBlock)reject
{
  PHVideoRequestOptions *opts = [[PHVideoRequestOptions alloc] init];
  opts.networkAccessAllowed = YES;

  [[PHImageManager defaultManager] requestAVAssetForVideo:asset options:opts resultHandler:^(AVAsset * _Nullable avAsset, AVAudioMix * _Nullable audioMix, NSDictionary * _Nullable info) {
    if (!avAsset) {
      reject(@"export_failed", @"Could not get AVAsset for video", nil);
      return;
    }

    // Try exporting via AVAssetExportSession
    AVAssetExportSession *exporter = [[AVAssetExportSession alloc] initWithAsset:avAsset presetName:AVAssetExportPresetHighestQuality];
    if (!exporter) {
      reject(@"export_failed", @"Could not create AVAssetExportSession", nil);
      return;
    }

    NSString *fileName = [NSString stringWithFormat:@"export_%@.mp4", [[NSUUID UUID] UUIDString]];
    NSString *exportPath = [NSTemporaryDirectory() stringByAppendingPathComponent:fileName];
    NSURL *exportURL = [NSURL fileURLWithPath:exportPath];

    exporter.outputURL = exportURL;
    exporter.outputFileType = AVFileTypeMPEG4;
    exporter.shouldOptimizeForNetworkUse = YES;

    [exporter exportAsynchronouslyWithCompletionHandler:^{
      if (exporter.status == AVAssetExportSessionStatusCompleted) {
        resolve(exportURL.absoluteString);
      } else {
        // Last fallback: if exporter fails, see if it is an AVURLAsset and try copying it directly
        if ([avAsset isKindOfClass:[AVURLAsset class]]) {
          AVURLAsset *urlAsset = (AVURLAsset *)avAsset;
          if (urlAsset.URL) {
            NSString *copyFileName = [NSString stringWithFormat:@"export_%@.mov", [[NSUUID UUID] UUIDString]];
            NSString *copyPath = [NSTemporaryDirectory() stringByAppendingPathComponent:copyFileName];
            NSURL *copyURL = [NSURL fileURLWithPath:copyPath];
            NSError *copyError = nil;
            [[NSFileManager defaultManager] copyItemAtURL:urlAsset.URL toURL:copyURL error:&copyError];
            if (!copyError) {
              resolve(copyURL.absoluteString);
              return;
            }
          }
        }
        NSError *err = exporter.error;
        NSString *errMsg = err ? err.localizedDescription : @"Unknown export error";
        reject(@"export_failed", [NSString stringWithFormat:@"Export session failed: %@", errMsg], err);
      }
    }];
  }];
}

RCT_REMAP_METHOD(exportAsset,
                 exportAssetWithLocalId:(NSString *)localId
                 resolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    PHFetchResult<PHAsset *> *result = [PHAsset fetchAssetsWithLocalIdentifiers:@[localId] options:nil];
    PHAsset *asset = result.firstObject;
    if (!asset) {
      reject(@"not_found", @"Asset not found", nil);
      return;
    }

    if (asset.mediaType == PHAssetMediaTypeImage) {
      PHImageRequestOptions *opts = [[PHImageRequestOptions alloc] init];
      opts.synchronous = YES;
      opts.networkAccessAllowed = YES;

      __block NSString *outUri = nil;
    [[PHImageManager defaultManager] requestImageDataAndOrientationForAsset:asset options:opts resultHandler:^(NSData * _Nullable imageData, NSString * _Nullable dataUTI, CGImagePropertyOrientation orientation, NSDictionary * _Nullable info) {
      if (imageData) {
        NSString *fileName = [NSString stringWithFormat:@"export_%@.jpg", [[NSUUID UUID] UUIDString]];
        NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:fileName];
        [imageData writeToFile:path atomically:YES];
        outUri = [NSURL fileURLWithPath:path].absoluteString;
      }
    }];

    if (outUri) {
      resolve(outUri);
    } else {
      reject(@"export_failed", @"Could not export image", nil);
    }
  } else if (asset.mediaType == PHAssetMediaTypeVideo) {
    NSArray<PHAssetResource *> *resources = [PHAssetResource assetResourcesForAsset:asset];
    PHAssetResource *videoResource = nil;
    for (PHAssetResource *res in resources) {
      if (res.type == PHAssetResourceTypeVideo) {
        videoResource = res;
        break;
      }
    }
    
    if (videoResource) {
      NSString *fileName = [NSString stringWithFormat:@"export_%@.mov", [[NSUUID UUID] UUIDString]];
      NSString *exportPath = [NSTemporaryDirectory() stringByAppendingPathComponent:fileName];
      NSURL *exportURL = [NSURL fileURLWithPath:exportPath];
      
      PHAssetResourceRequestOptions *options = [[PHAssetResourceRequestOptions alloc] init];
      options.networkAccessAllowed = YES;
      
      [[PHAssetResourceManager defaultManager] writeDataForAssetResource:videoResource toFile:exportURL options:options completionHandler:^(NSError * _Nullable error) {
        if (!error) {
          resolve(exportURL.absoluteString);
        } else {
          [self exportVideoFallback:asset resolver:resolve rejecter:reject];
        }
      }];
    } else {
      [self exportVideoFallback:asset resolver:resolve rejecter:reject];
    }
  } else {
    reject(@"unsupported", @"Unsupported asset type", nil);
  }
  });
}

RCT_REMAP_METHOD(saveToGallery,
                 saveToGallery:(NSString *)uriString
                 type:(NSString *)type
                 resolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
  NSURL *url = [NSURL URLWithString:uriString];
  if (!url) {
    reject(@"bad_uri", @"Invalid uri", nil);
    return;
  }
  
  [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
    if ([type isEqualToString:@"video"]) {
      [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:url];
    } else {
      [PHAssetChangeRequest creationRequestForAssetFromImageAtFileURL:url];
    }
  } completionHandler:^(BOOL success, NSError * _Nullable error) {
    if (success) {
      resolve(@(YES));
    } else {
      reject(@"save_failed", error.localizedDescription, error);
    }
  }];
}

@end
