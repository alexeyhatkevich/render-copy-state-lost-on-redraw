#import "RCPrivate.h"

@implementation RCToggle

- (instancetype)initWithIdentifier:(NSString *)identifier {
    return [self initWithIdentifier:identifier selected:NO];
}

- (instancetype)initWithIdentifier:(NSString *)identifier selected:(BOOL)selected {
    if ((self = [super initWithIdentifier:identifier])) {
        _selected = selected;
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone {
    RCToggle *copy = [super copyWithZone:zone];
    copy->_selected = _selected;
    copy.boundKey = _boundKey;
    copy.onChange = _onChange;
    return copy;
}

- (void)didRenderInContainer:(RCContainer *)container {
    if (_boundKey) {
        _selected = [container.dataStore[_boundKey] boolValue];
    }
}

- (void)rc_storeSelectedValue:(BOOL)selected {
    _selected = selected;
}

// Both entry points funnel through one method, so a fix applied in
// -persistSelected: cannot be forgotten on either of them.
- (void)rc_changeSelected:(BOOL)selected {
    _selected = selected;
    if (_boundKey) {
        self.parent.dataStore[_boundKey] = @(selected);
    }
    [self persistSelected:selected];
    if (_onChange) _onChange(selected);
}

- (void)userDidToggle:(BOOL)selected { [self rc_changeSelected:selected]; }
- (void)applySelected:(BOOL)selected { [self rc_changeSelected:selected]; }

- (void)persistSelected:(BOOL)selected {}

@end

@implementation RCNaiveToggle
@end

@implementation RCWriteThroughToggle

- (void)persistSelected:(BOOL)selected {
    if (self.boundKey) return;  // the data store already owns this value
    RCToggle *source = [self.parent sourceChildWithIdentifier:self.identifier];
    if (source && source != self) {
        [source rc_storeSelectedValue:selected];
    }
}

@end

@implementation RCFixedToggle

- (instancetype)initWithIdentifier:(NSString *)identifier selected:(BOOL)selected {
    if ((self = [super initWithIdentifier:identifier selected:selected])) {
        _authoredSelected = selected;  // what the screen definition says
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone {
    RCFixedToggle *copy = [super copyWithZone:zone];
    copy->_authoredSelected = _authoredSelected;  // copies must remember it too
    return copy;
}

- (void)prepareForFreshPresentation {
    if (self.boundKey) return;
    [self rc_storeSelectedValue:_authoredSelected];
}

@end
