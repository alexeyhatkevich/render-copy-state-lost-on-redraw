#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class RCContainer;

/// A node of the declarative UI tree. The tree you build is the SOURCE.
/// A container never shows its source children directly: every render makes
/// `[sourceChild copy]`, so whatever sits behind a live view is a RENDER COPY.
@interface RCElement : NSObject <NSCopying>
@property (nonatomic, copy, readonly) NSString *identifier;
/// Set on render copies. Points at the SOURCE container (copies are never parents).
@property (nonatomic, weak, nullable) RCContainer *parent;
@property (nonatomic, getter=isCollapsed) BOOL collapsed;
- (instancetype)initWithIdentifier:(NSString *)identifier NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
/// Called on the fresh render copy right after the container created it.
- (void)didRenderInContainer:(RCContainer *)container;
/// Called on SOURCE elements when the page is freshly presented (navigation in,
/// re-entry, popup shown) - never on a plain redraw. Default: no-op.
- (void)prepareForFreshPresentation;
@end

/// Renders its children as copies. Any layout change (a child collapsing or
/// expanding) throws the copies away and rebuilds them from the sources.
@interface RCContainer : RCElement
@property (nonatomic, copy, readonly) NSArray<RCElement *> *children;          // sources
@property (nonatomic, copy, readonly) NSArray<RCElement *> *renderedChildren;  // copies
/// Values bound to a key live here, not in any element.
@property (nonatomic, readonly) NSMutableDictionary<NSString *, id> *dataStore;
@property (nonatomic, readonly) NSUInteger redrawCount;
- (void)addChild:(RCElement *)child;
- (nullable __kindof RCElement *)sourceChildWithIdentifier:(NSString *)identifier
    NS_SWIFT_NAME(sourceChild(_:));
- (nullable __kindof RCElement *)renderedChildWithIdentifier:(NSString *)identifier
    NS_SWIFT_NAME(renderedChild(_:));
/// Rebuilds every render copy from the sources.
- (void)redraw;
/// Changes a sibling's visibility on the source and redraws - like a real layout pass.
- (void)setCollapsed:(BOOL)collapsed forChildWithIdentifier:(NSString *)identifier
    NS_SWIFT_NAME(setCollapsed(_:forChild:));
@end

// MARK: - Toggles

/// An on/off switch. The base class is the NAIVE version: a value change is
/// stored on `self`, which is the render copy the user tapped.
@interface RCToggle : RCElement
@property (nonatomic, readonly, getter=isSelected) BOOL selected;
/// When set, the value lives in `parent.dataStore[boundKey]` instead of the element.
@property (nonatomic, copy, nullable) NSString *boundKey;
/// Fired after every value change (user or programmatic).
@property (nonatomic, copy, nullable) void (^onChange)(BOOL selected);
- (instancetype)initWithIdentifier:(NSString *)identifier selected:(BOOL)selected;
/// The user flipped the switch (UIControlEventValueChanged in a real app).
- (void)userDidToggle:(BOOL)selected NS_SWIFT_NAME(userDidToggle(_:));
/// Programmatic "set selected" command - a second mutation entry point.
- (void)applySelected:(BOOL)selected NS_SWIFT_NAME(applySelected(_:));
/// Hook both entry points funnel into. Default (naive): nothing.
- (void)persistSelected:(BOOL)selected;
@end

/// Naive: state lives only on the render copy and dies on the next redraw.
@interface RCNaiveToggle : RCToggle
@end

/// Fix part 1: every change is written through to the SOURCE element,
/// unless the value is bound to the data store (which already persists it).
@interface RCWriteThroughToggle : RCToggle
@end

/// Fix part 2: write-through plus a reset to the authored value on every fresh
/// presentation, because cached page models are reused across visits.
@interface RCFixedToggle : RCWriteThroughToggle
@property (nonatomic, readonly) BOOL authoredSelected;
@end

// MARK: - Page

/// A consent screen: a hint line, an "I agree" toggle and a Next button whose
/// enabled state is driven by the toggle's onChange.
@interface RCConsentPage : RCContainer
@property (nonatomic, readonly) BOOL nextEnabled;
@property (nonatomic, readonly) NSUInteger presentationCount;
- (instancetype)initWithToggleClass:(Class)toggleClass NS_SWIFT_NAME(init(toggleClass:));
- (instancetype)initWithToggleClass:(Class)toggleClass boundKey:(nullable NSString *)boundKey
    NS_SWIFT_NAME(init(toggleClass:boundKey:)) NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithIdentifier:(NSString *)identifier NS_UNAVAILABLE;
/// Fresh presentation: resets sources that opt in, renders, syncs Next.
- (void)present;
/// The live switch the user sees.
@property (nonatomic, readonly) RCToggle *renderedToggle;
/// The toggle in the source tree.
@property (nonatomic, readonly) RCToggle *sourceToggle;
/// Show/hide the hint - a sibling visibility change that triggers a redraw.
- (void)setHintHidden:(BOOL)hidden;
@end

/// Screen models are built once and reused on every visit.
@interface RCPageCache : NSObject
- (RCConsentPage *)pageNamed:(NSString *)name build:(RCConsentPage *(^)(void))build
    NS_SWIFT_NAME(page(named:build:));
@end

NS_ASSUME_NONNULL_END
