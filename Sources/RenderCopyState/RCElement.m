#import "RCPrivate.h"

@implementation RCElement

- (instancetype)initWithIdentifier:(NSString *)identifier {
    if ((self = [super init])) {
        _identifier = [identifier copy];
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone {
    RCElement *copy = [[[self class] allocWithZone:zone] initWithIdentifier:_identifier];
    copy.collapsed = _collapsed;
    copy.parent = _parent;
    return copy;
}

- (void)didRenderInContainer:(RCContainer *)container {}
- (void)prepareForFreshPresentation {}

@end
