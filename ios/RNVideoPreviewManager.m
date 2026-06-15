#import <React/RCTViewManager.h>
#import <React/RCTConvert.h>
#import <React/RCTEventEmitter.h>
#import <AVFoundation/AVFoundation.h>

@interface RNVideoPreviewView : UIView

@property(nonatomic, strong) AVPlayer *player;
@property(nonatomic, strong) AVPlayerLayer *playerLayer;
@property(nonatomic, strong) id timeObserver;
@property(nonatomic, copy) NSString *uri;
@property(nonatomic, assign) BOOL paused;
@property(nonatomic, assign) BOOL muted;
@property(nonatomic, copy) NSString *resizeMode;
@property(nonatomic, assign) int trimStartMs;
@property(nonatomic, assign) int trimEndMs;
@property(nonatomic, assign) int seekToMs;
@property(nonatomic, copy) RCTBubblingEventBlock onChange;

// internal flag: player item is ready
@property(nonatomic, assign) BOOL isPlayerReady;

@end

@implementation RNVideoPreviewView

- (instancetype)initWithFrame:(CGRect)frame {
  if (self = [super initWithFrame:frame]) {
    _trimStartMs = 0;
    _trimEndMs = 0;
    _seekToMs = -1;
    _isPlayerReady = NO;

    self.clipsToBounds = YES;

    self.player = [[AVPlayer alloc] init];
    self.player.actionAtItemEnd = AVPlayerActionAtItemEndNone;
    self.playerLayer = [AVPlayerLayer playerLayerWithPlayer:self.player];
    self.playerLayer.videoGravity = AVLayerVideoGravityResizeAspect;
    [self.layer addSublayer:self.playerLayer];

    // Loop + trim boundary observer
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(playerItemDidEnd:)
                                                 name:AVPlayerItemDidPlayToEndTimeNotification
                                               object:nil];
  }
  return self;
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [self removePeriodicObserver];
  if (self.player.currentItem) {
    [self.player.currentItem removeObserver:self forKeyPath:@"status"];
  }
}

- (void)layoutSubviews {
  [super layoutSubviews];
  self.playerLayer.frame = self.bounds;
}

// ─── URI ─────────────────────────────────────────────────────────────────────

- (void)setUri:(NSString *)uri {
  NSLog(@"[RNVideoPreview] setUri called with: %@", uri);
  if ([_uri isEqualToString:uri]) return;
  _uri = [uri copy];
  if (!_uri || _uri.length == 0) {
    NSLog(@"[RNVideoPreview] Uri is empty or nil, resetting player");
    if (self.player.currentItem) {
      [self.player.currentItem removeObserver:self forKeyPath:@"status"];
    }
    [self.player replaceCurrentItemWithPlayerItem:nil];
    return;
  }

  // Remove old KVO
  if (self.player.currentItem) {
    [self.player.currentItem removeObserver:self forKeyPath:@"status"];
  }
  [self removePeriodicObserver];
  _isPlayerReady = NO;

  NSURL *url = [RCTConvert NSURL:_uri];
  if (!url) {
    NSLog(@"[RNVideoPreview] Failed to convert uri to NSURL: %@", _uri);
    return;
  }
  NSLog(@"[RNVideoPreview] Resolved NSURL: %@, scheme: %@", url, url.scheme);

  AVPlayerItem *item = [AVPlayerItem playerItemWithURL:url];
  [item addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionNew context:nil];
  [self.player replaceCurrentItemWithPlayerItem:item];
  self.player.muted = self.muted;
}

// ─── KVO: player item status ──────────────────────────────────────────────────

- (void)observeValueForKeyPath:(NSString *)keyPath
                       ofObject:(id)object
                         change:(NSDictionary *)change
                        context:(void *)context {
  if ([keyPath isEqualToString:@"status"]) {
    AVPlayerItem *item = (AVPlayerItem *)object;
    if (item.status == AVPlayerItemStatusReadyToPlay) {
      _isPlayerReady = YES;
      NSLog(@"[RNVideoPreview] Player ready, paused=%d trimStart=%d", self.paused, self.trimStartMs);

      // Seek to trim start first, then play if not paused
      if (self.trimStartMs > 0) {
        CMTime seekTime = CMTimeMakeWithSeconds(self.trimStartMs / 1000.0, NSEC_PER_SEC);
        [self.player seekToTime:seekTime toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero completionHandler:^(BOOL finished) {
          if (!self.paused) {
            [self.player play];
          }
        }];
      } else {
        if (!self.paused) {
          [self.player play];
        }
      }

      [self startPeriodicObserver];
    } else if (item.status == AVPlayerItemStatusFailed) {
      NSLog(@"[RNVideoPreview] Player item failed: %@. Error description: %@, code: %ld, domain: %@",
            item.error, item.error.localizedDescription, (long)item.error.code, item.error.domain);
    }
  }
}

// ─── PERIODIC PROGRESS OBSERVER ──────────────────────────────────────────────

- (void)startPeriodicObserver {
  [self removePeriodicObserver];
  __weak typeof(self) weakSelf = self;
  CMTime interval = CMTimeMakeWithSeconds(0.1, NSEC_PER_SEC);
  self.timeObserver = [self.player addPeriodicTimeObserverForInterval:interval
                                                               queue:dispatch_get_main_queue()
                                                          usingBlock:^(CMTime time) {
    __strong typeof(weakSelf) strongSelf = weakSelf;
    if (!strongSelf) return;

    double currentSec = CMTimeGetSeconds(time);
    int currentMs = (int)(currentSec * 1000.0);

    // Trim boundary enforcement
    if (strongSelf.trimEndMs > 0 && currentMs >= strongSelf.trimEndMs) {
      CMTime trimStart = CMTimeMakeWithSeconds(strongSelf.trimStartMs / 1000.0, NSEC_PER_SEC);
      [strongSelf.player seekToTime:trimStart toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero completionHandler:^(BOOL finished) {
        if (!strongSelf.paused) {
          [strongSelf.player play];
        }
      }];
      return;
    }

    // Emit onChange
    if (strongSelf.onChange) {
      strongSelf.onChange(@{ @"currentTimeMs": @(currentMs) });
    }
  }];
}

- (void)removePeriodicObserver {
  if (self.timeObserver) {
    [self.player removeTimeObserver:self.timeObserver];
    self.timeObserver = nil;
  }
}

// ─── LOOP ─────────────────────────────────────────────────────────────────────

- (void)playerItemDidEnd:(NSNotification *)note {
  if (note.object == self.player.currentItem) {
    CMTime seekTime = CMTimeMakeWithSeconds(self.trimStartMs / 1000.0, NSEC_PER_SEC);
    [self.player seekToTime:seekTime toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero completionHandler:^(BOOL finished) {
      if (!self.paused) {
        [self.player play];
      }
    }];
  }
}

// ─── PROPS ────────────────────────────────────────────────────────────────────

- (void)setPaused:(BOOL)paused {
  _paused = paused;
  NSLog(@"[RNVideoPreview] setPaused=%d isReady=%d", paused, _isPlayerReady);
  if (paused) {
    [self.player pause];
  } else {
    if (_isPlayerReady) {
      [self.player play];
    }
    // If not ready yet, onPrepared (KVO) will auto-play when ready
  }
}

- (void)setMuted:(BOOL)muted {
  _muted = muted;
  self.player.muted = muted;
}

- (void)setResizeMode:(NSString *)resizeMode {
  _resizeMode = [resizeMode copy];
  if ([_resizeMode isEqualToString:@"contain"]) {
    self.playerLayer.videoGravity = AVLayerVideoGravityResizeAspect;
  } else if ([_resizeMode isEqualToString:@"stretch"]) {
    self.playerLayer.videoGravity = AVLayerVideoGravityResize;
  } else {
    self.playerLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
  }
}

- (void)setTrimStartMs:(int)trimStartMs {
  _trimStartMs = trimStartMs;
  // If current position is before trim start, seek forward
  if (_isPlayerReady) {
    double current = CMTimeGetSeconds(self.player.currentTime) * 1000.0;
    if (current < trimStartMs) {
      CMTime t = CMTimeMakeWithSeconds(trimStartMs / 1000.0, NSEC_PER_SEC);
      [self.player seekToTime:t toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero];
    }
  }
}

- (void)setTrimEndMs:(int)trimEndMs {
  _trimEndMs = trimEndMs;
}

- (void)setSeekToMs:(int)seekToMs {
  _seekToMs = seekToMs;
  if (seekToMs >= 0 && _isPlayerReady) {
    CMTime t = CMTimeMakeWithSeconds(seekToMs / 1000.0, NSEC_PER_SEC);
    [self.player seekToTime:t toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero];
  }
}

@end

// ─── MANAGER ──────────────────────────────────────────────────────────────────

@interface RNVideoPreviewManager : RCTViewManager
@end

@implementation RNVideoPreviewManager

RCT_EXPORT_MODULE(RNVideoPreview)

- (UIView *)view {
  return [[RNVideoPreviewView alloc] initWithFrame:CGRectZero];
}

RCT_EXPORT_VIEW_PROPERTY(uri, NSString)
RCT_EXPORT_VIEW_PROPERTY(paused, BOOL)
RCT_EXPORT_VIEW_PROPERTY(muted, BOOL)
RCT_EXPORT_VIEW_PROPERTY(resizeMode, NSString)
RCT_EXPORT_VIEW_PROPERTY(trimStartMs, int)
RCT_EXPORT_VIEW_PROPERTY(trimEndMs, int)
RCT_EXPORT_VIEW_PROPERTY(seekToMs, int)
RCT_EXPORT_VIEW_PROPERTY(onChange, RCTBubblingEventBlock)

@end
