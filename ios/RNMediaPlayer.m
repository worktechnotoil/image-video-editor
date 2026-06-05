#import <React/RCTBridgeModule.h>
#import <AVKit/AVKit.h>
#import <React/RCTUtils.h>
#import <Photos/Photos.h>

@interface RNMediaPlayer : NSObject <RCTBridgeModule>
@end

@implementation RNMediaPlayer

RCT_EXPORT_MODULE(RNMediaPlayer)

+ (BOOL)requiresMainQueueSetup {
  return YES;
}

RCT_REMAP_METHOD(playVideo,
                 playVideoWithUri:(NSString *)uriString
                 resolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
  dispatch_async(dispatch_get_main_queue(), ^{
    UIViewController *presenter = RCTPresentedViewController();
    if (!presenter) {
      reject(@"no_view", @"No view controller to present player", nil);
      return;
    }

    if ([uriString hasPrefix:@"ph://"]) {
      NSString *localId = [uriString stringByReplacingOccurrencesOfString:@"ph://" withString:@""];
      PHFetchResult<PHAsset *> *result = [PHAsset fetchAssetsWithLocalIdentifiers:@[localId] options:nil];
      PHAsset *asset = result.firstObject;
      if (!asset) {
        reject(@"not_found", @"Asset not found", nil);
        return;
      }

      PHVideoRequestOptions *opts = [[PHVideoRequestOptions alloc] init];
      opts.networkAccessAllowed = YES;
      [[PHImageManager defaultManager] requestAVAssetForVideo:asset options:opts resultHandler:^(AVAsset * _Nullable avAsset, AVAudioMix * _Nullable audioMix, NSDictionary * _Nullable info) {
        if (!avAsset) {
          reject(@"play_failed", @"Could not load asset", nil);
          return;
        }
        dispatch_async(dispatch_get_main_queue(), ^{
          AVPlayerViewController *playerVC = [[AVPlayerViewController alloc] init];
          playerVC.player = [AVPlayer playerWithPlayerItem:[AVPlayerItem playerItemWithAsset:avAsset]];
          [presenter presentViewController:playerVC animated:YES completion:^{
            [playerVC.player play];
            resolve(@(YES));
          }];
        });
      }];
      return;
    }

    NSURL *url = [NSURL URLWithString:uriString];
    if (!url) {
      reject(@"bad_uri", @"Invalid video uri", nil);
      return;
    }

    AVPlayerViewController *playerVC = [[AVPlayerViewController alloc] init];
    playerVC.player = [AVPlayer playerWithURL:url];

    [presenter presentViewController:playerVC animated:YES completion:^{
      [playerVC.player play];
      resolve(@(YES));
    }];
  });
}

@end
