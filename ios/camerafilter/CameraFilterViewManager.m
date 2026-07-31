#import "CameraFilterViewManager.h"
#import "CameraFilterView.h"

@implementation CameraFilterViewManager

RCT_EXPORT_MODULE(CameraFilterView)

- (UIView *)view {
    return [[CameraFilterView alloc] initWithFrame:CGRectZero];
}

RCT_EXPORT_VIEW_PROPERTY(facing, NSString)
RCT_EXPORT_VIEW_PROPERTY(filter, NSString)

@end
