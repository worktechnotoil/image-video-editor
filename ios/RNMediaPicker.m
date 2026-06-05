#import <React/RCTBridgeModule.h>
#import <React/RCTUtils.h>
#import <PhotosUI/PhotosUI.h>
#import <AVFoundation/AVFoundation.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

@interface RNMediaPicker : NSObject <RCTBridgeModule, PHPickerViewControllerDelegate>
@end

@implementation RNMediaPicker {
  RCTPromiseResolveBlock _resolve;
  RCTPromiseRejectBlock _reject;
}

RCT_EXPORT_MODULE(RNMediaPicker)

+ (BOOL)requiresMainQueueSetup {
  return YES;
}

RCT_REMAP_METHOD(pickMedia,
                 pickMediaWithResolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
  dispatch_async(dispatch_get_main_queue(), ^{
    UIViewController *presenter = RCTPresentedViewController();
    if (!presenter) {
      reject(@"no_view", @"No view controller to present picker", nil);
      return;
    }
    if (self->_resolve != nil) {
      reject(@"in_progress", @"Another picker request is in progress", nil);
      return;
    }
    self->_resolve = resolve;
    self->_reject = reject;

    PHPickerConfiguration *config = [[PHPickerConfiguration alloc] initWithPhotoLibrary:PHPhotoLibrary.sharedPhotoLibrary];
    config.selectionLimit = 0;
    config.filter = [PHPickerFilter anyFilterMatchingSubfilters:@[PHPickerFilter.imagesFilter, PHPickerFilter.videosFilter]];

    PHPickerViewController *picker = [[PHPickerViewController alloc] initWithConfiguration:config];
    picker.delegate = self;
    [presenter presentViewController:picker animated:YES completion:nil];
  });
}

- (void)picker:(PHPickerViewController *)picker didFinishPicking:(NSArray<PHPickerResult *> *)results {
  [picker dismissViewControllerAnimated:YES completion:nil];

  RCTPromiseResolveBlock resolve = _resolve;
  RCTPromiseRejectBlock reject = _reject;
  _resolve = nil;
  _reject = nil;

  if (!resolve) {
    return;
  }

  if (results.count == 0) {
    resolve(@[]);
    return;
  }

  dispatch_group_t group = dispatch_group_create();
  NSMutableArray *output = [NSMutableArray array];

  for (PHPickerResult *result in results) {
    NSItemProvider *provider = result.itemProvider;

    if ([provider hasItemConformingToTypeIdentifier:UTTypeMovie.identifier]) {
      dispatch_group_enter(group);
      [provider loadFileRepresentationForTypeIdentifier:UTTypeMovie.identifier completionHandler:^(NSURL * _Nullable url, NSError * _Nullable error) {
        if (error) {
          if (reject) reject(@"load_failed", error.localizedDescription, error);
          dispatch_group_leave(group);
          return;
        }
        if (!url) {
          dispatch_group_leave(group);
          return;
        }
        NSURL *tempUrl = [self copyToTemp:url prefix:@"video_"];
        AVAsset *asset = [AVAsset assetWithURL:tempUrl];
        double durationMs = CMTimeGetSeconds(asset.duration) * 1000.0;

        NSDictionary *item = @{
          @"id": [NSUUID UUID].UUIDString,
          @"uri": tempUrl.absoluteString,
          @"type": @"video",
          @"durationMs": @(durationMs)
        };
        @synchronized (output) { [output addObject:item]; }
        dispatch_group_leave(group);
      }];
    } else if ([provider canLoadObjectOfClass:UIImage.class]) {
      dispatch_group_enter(group);
      [provider loadObjectOfClass:UIImage.class completionHandler:^(UIImage * _Nullable image, NSError * _Nullable error) {
        if (error) {
          if (reject) reject(@"load_failed", error.localizedDescription, error);
          dispatch_group_leave(group);
          return;
        }
        if (!image) {
          dispatch_group_leave(group);
          return;
        }
        NSURL *tempUrl = [self writeImageToTemp:image];
        NSDictionary *item = @{
          @"id": [NSUUID UUID].UUIDString,
          @"uri": tempUrl.absoluteString,
          @"type": @"image",
          @"width": @(image.size.width),
          @"height": @(image.size.height)
        };
        @synchronized (output) { [output addObject:item]; }
        dispatch_group_leave(group);
      }];
    }
  }

  dispatch_group_notify(group, dispatch_get_main_queue(), ^{
    resolve(output);
  });
}

- (NSURL *)copyToTemp:(NSURL *)url prefix:(NSString *)prefix {
  NSURL *dir = NSTemporaryDirectory().length ? [NSURL fileURLWithPath:NSTemporaryDirectory()] : [NSFileManager.defaultManager temporaryDirectory];
  NSString *ext = url.pathExtension.length ? url.pathExtension : @"mp4";
  NSURL *dest = [dir URLByAppendingPathComponent:[NSString stringWithFormat:@"%@%@.%@", prefix, [NSUUID UUID].UUIDString, ext]];
  [NSFileManager.defaultManager removeItemAtURL:dest error:nil];
  [NSFileManager.defaultManager copyItemAtURL:url toURL:dest error:nil];
  return dest;
}

- (NSURL *)writeImageToTemp:(UIImage *)image {
  NSURL *dir = NSTemporaryDirectory().length ? [NSURL fileURLWithPath:NSTemporaryDirectory()] : [NSFileManager.defaultManager temporaryDirectory];
  NSURL *dest = [dir URLByAppendingPathComponent:[NSString stringWithFormat:@"image_%@.jpg", [NSUUID UUID].UUIDString]];
  NSData *data = UIImageJPEGRepresentation(image, 0.92);
  [data writeToURL:dest atomically:YES];
  return dest;
}

@end
