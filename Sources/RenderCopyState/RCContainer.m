#import "RCPrivate.h"

@implementation RCContainer {
    NSMutableArray<RCElement *> *_sources;
    NSArray<RCElement *> *_rendered;
}

- (instancetype)initWithIdentifier:(NSString *)identifier {
    if ((self = [super initWithIdentifier:identifier])) {
        _sources = [NSMutableArray array];
        _rendered = @[];
        _dataStore = [NSMutableDictionary dictionary];
    }
    return self;
}

- (NSArray<RCElement *> *)children { return [_sources copy]; }
- (NSArray<RCElement *> *)renderedChildren { return _rendered; }

- (void)addChild:(RCElement *)child {
    [_sources addObject:child];
}

static RCElement *RCFind(NSArray<RCElement *> *elements, NSString *identifier) {
    for (RCElement *element in elements) {
        if ([element.identifier isEqualToString:identifier]) return element;
    }
    return nil;
}

- (RCElement *)sourceChildWithIdentifier:(NSString *)identifier {
    return RCFind(_sources, identifier);
}

- (RCElement *)renderedChildWithIdentifier:(NSString *)identifier {
    return RCFind(_rendered, identifier);
}

- (void)redraw {
    NSMutableArray<RCElement *> *rendered = [NSMutableArray arrayWithCapacity:_sources.count];
    for (RCElement *source in _sources) {
        RCElement *copy = [source copy];   // every live element is a render copy...
        copy.parent = self;                // ...whose parent is the SOURCE container
        [copy didRenderInContainer:self];
        [rendered addObject:copy];
    }
    _rendered = [rendered copy];
    _redrawCount += 1;
}

- (void)setCollapsed:(BOOL)collapsed forChildWithIdentifier:(NSString *)identifier {
    [self sourceChildWithIdentifier:identifier].collapsed = collapsed;
    [self redraw];  // a visibility change means a new layout pass
}

@end
