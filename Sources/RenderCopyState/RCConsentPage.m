#import "RCPrivate.h"

static NSString *const RCHintID = @"hint";
static NSString *const RCAgreeID = @"agree";
static NSString *const RCNextID = @"next";

@implementation RCConsentPage

- (instancetype)initWithToggleClass:(Class)toggleClass {
    return [self initWithToggleClass:toggleClass boundKey:nil];
}

- (instancetype)initWithToggleClass:(Class)toggleClass boundKey:(NSString *)boundKey {
    NSParameterAssert([toggleClass isSubclassOfClass:[RCToggle class]]);
    if ((self = [super initWithIdentifier:@"consent"])) {
        [self addChild:[[RCElement alloc] initWithIdentifier:RCHintID]];

        RCToggle *agree = [[toggleClass alloc] initWithIdentifier:RCAgreeID selected:NO];
        agree.boundKey = boundKey;
        __weak typeof(self) weakSelf = self;
        agree.onChange = ^(BOOL selected) {
            __strong typeof(weakSelf) page = weakSelf;
            if (page) page->_nextEnabled = selected;  // the "logic" side of the screen
        };
        [self addChild:agree];

        [self addChild:[[RCElement alloc] initWithIdentifier:RCNextID]];
    }
    return self;
}

- (void)present {
    for (RCElement *source in self.children) {
        [source prepareForFreshPresentation];
    }
    [self redraw];
    _nextEnabled = self.renderedToggle.isSelected;
    _presentationCount += 1;
}

- (RCToggle *)renderedToggle { return [self renderedChildWithIdentifier:RCAgreeID]; }
- (RCToggle *)sourceToggle { return [self sourceChildWithIdentifier:RCAgreeID]; }

- (void)setHintHidden:(BOOL)hidden {
    [self setCollapsed:hidden forChildWithIdentifier:RCHintID];
}

@end

@implementation RCPageCache {
    NSMutableDictionary<NSString *, RCConsentPage *> *_pages;
}

- (instancetype)init {
    if ((self = [super init])) {
        _pages = [NSMutableDictionary dictionary];
    }
    return self;
}

- (RCConsentPage *)pageNamed:(NSString *)name build:(RCConsentPage *(^)(void))build {
    RCConsentPage *page = _pages[name];
    if (!page) {
        page = build();
        _pages[name] = page;
    }
    return page;
}

@end
