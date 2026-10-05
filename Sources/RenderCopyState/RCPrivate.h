#import "RenderCopyState.h"

NS_ASSUME_NONNULL_BEGIN

@interface RCToggle ()
/// Raw write of the element's own value - no hooks, no callbacks.
- (void)rc_storeSelectedValue:(BOOL)selected;
@end

NS_ASSUME_NONNULL_END
