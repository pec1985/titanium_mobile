/**
 * Appcelerator Titanium Mobile
 * Copyright (c) 2009-2015 by Appcelerator, Inc. All Rights Reserved.
 * Licensed under the terms of the Apache Public License
 * Please see the LICENSE included with this distribution for details.
 */

#import "TiLayoutView.h"
#import "TiUtils.h"

#define SuppressPerformSelectorLeakWarning(Stuff) \
do { \
_Pragma("clang diagnostic push") \
_Pragma("clang diagnostic ignored \"-Warc-performSelector-leaks\"") \
Stuff; \
_Pragma("clang diagnostic pop") \
} while (0)

#define IS_PERCENT TiDimensionIsPercent
#define IS_AUTO TiDimensionIsAuto
#define IS_AUTOSIZE TiDimensionIsAutoSize
#define IS_AUTOFILL TiDimensionIsAutoFill
#define IS_DIP TiDimensionIsDip
#define IS_UNDEFINED TiDimensionIsUndefined

#define TI_VIEWS(...) NSDictionaryOfVariableBindings(__VA_ARGS__)
static inline NSString* TI_CONSTRAINT_STRING(NSLayoutConstraint* constraint)
{
    return  [NSString stringWithFormat:@"<%p-%p-%li-%li-%li>",
             [constraint firstItem],
             [constraint secondItem],
             (long)[constraint firstAttribute],
             (long)[constraint secondAttribute],
             (long)[constraint relation]
             ];
}

static void TiLayoutUpdateMargins(TiLayoutView* superview, TiLayoutView* self);
static void TiLayoutRemoveChildConstraints(UIView* superview, UIView*child);

static NSString* capitalizedFirstLetter(NSString* string)
{
    NSString *retVal = string;
    if (string.length <= 1) {
        retVal = [string capitalizedString];
    } else {
        retVal = TI_STRING(@"%@%@",[[string substringToIndex:1] uppercaseString],[string substringFromIndex:1]);
    }
    return retVal;
}

@interface TiLayoutView()
{
    TiLayoutConstraint _tiLayoutConstraint;
    NSMutableDictionary* _constraintsAdded;
    BOOL _loaded;
    BOOL _innerViewSetup;
    BOOL _needsToRemoveConstrains;
    CGRect _oldRect;
    
    
    BOOL _isLeftPercentage;
    BOOL _isBottomPercentage;
    BOOL _isTopPercentage;
    BOOL _isRightPercentage;
    
    CGFloat _leftPercentage;
    CGFloat _rightPercentage;
    CGFloat _topPercentage;
    CGFloat _bottomPercentage;
    
    TiDimension _defaultWidth;
    TiDimension _defaultHeight;
}
@end

@implementation TiLayoutView

- (void)dealloc
{
    [self.layer removeObserver:self forKeyPath:@"position"];
    [self.layer removeObserver:self forKeyPath:@"bounds"];
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        [self setClipsToBounds:YES];
        [self setTranslatesAutoresizingMaskIntoConstraints:NO];
        [self setHorizontalWrap:YES];
        [self setDefaultHeight:TiDimensionMake(TiDimensionTypeAutoFill, 0)];
        [self setDefaultWidth:TiDimensionMake(TiDimensionTypeAutoFill, 0)];
        [self.layer addObserver:self forKeyPath:@"position" options:0 context:NULL];
        [self.layer addObserver:self forKeyPath:@"bounds" options:0 context:NULL];
        
    }
    return self;
}

-(instancetype)initWithProperties:(NSDictionary*)properties
{
    if (self = [self init])
    {
        for (NSString* key in properties) {
            NSString* newKey = TI_STRING(@"set%@_:", capitalizedFirstLetter(key));
            SEL selector = NSSelectorFromString(newKey);
            if ([self respondsToSelector:selector]) {
                SuppressPerformSelectorLeakWarning([self performSelector:selector withObject: [properties objectForKey:key]]);
            }
        }
    }
    return self;
}
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self fireLayoutEvent];
    });
}

+(void)removeConstraints:(UIView*)parent fromChild:(UIView*)child
{
    TiLayoutRemoveChildConstraints(parent, child);
}

-(TiLayoutConstraint*) tiLayoutConstraint;
{
    return &_tiLayoutConstraint;
}

-(void)setLeft:(id)arg
{
    [self setLeft_:arg];
}
-(void)setRight:(id)arg
{
    [self setRight_:arg];
}
-(void)setTop:(id)arg
{
    [self setTop_:arg];
}
-(void)setBottom:(id)arg
{
    [self setBottom_:arg];
}
-(void)setWidth:(id)arg
{
    [self setWidth_:arg];
}
-(void)setHeight:(id)arg
{
    [self setHeight_:arg];
}
-(void)setLayout:(id)arg
{
    _layout = arg;
    [self setLayout_:arg];
}

-(void)setDefaultHeight:(TiDimension)defaultHeight
{
    _defaultHeight = defaultHeight;
    [self setNeedsUpdateConstraints];
}
-(void)setDefaultWidth:(TiDimension)defaultWidth
{
    _defaultWidth = defaultWidth;
    [self setNeedsUpdateConstraints];
}
-(void)setLeft_:(id)args
{
    _tiLayoutConstraint.left = TiDimensionFromObject(args);
    _isLeftPercentage = IS_PERCENT(_tiLayoutConstraint.left);
    if (_isLeftPercentage && _leftPercentage != _tiLayoutConstraint.left.value) {
        _leftPercentage = _tiLayoutConstraint.left.value;
    }
    TiLayoutUpdateMargins((TiLayoutView*)[self superview], self);
}
-(void)setRight_:(id)args
{
    _tiLayoutConstraint.right = TiDimensionFromObject(args);
    _isRightPercentage = IS_PERCENT(_tiLayoutConstraint.right);
    if (_isRightPercentage && _rightPercentage != _tiLayoutConstraint.right.value) {
        _rightPercentage = _tiLayoutConstraint.right.value;
    }
    TiLayoutUpdateMargins((TiLayoutView*)[self superview], self);
}
-(void)setTop_:(id)args
{
    _tiLayoutConstraint.top = TiDimensionFromObject(args);
    _isTopPercentage = IS_PERCENT(_tiLayoutConstraint.top);
    if (_isTopPercentage && _topPercentage != _tiLayoutConstraint.top.value) {
        _topPercentage = _tiLayoutConstraint.top.value;
    }
    TiLayoutUpdateMargins((TiLayoutView*)[self superview], self);
}
-(void)setBottom_:(id)args
{
    _tiLayoutConstraint.bottom = TiDimensionFromObject(args);
    _isBottomPercentage = IS_PERCENT(_tiLayoutConstraint.bottom);
    if (_isBottomPercentage && _bottomPercentage != _tiLayoutConstraint.bottom.value) {
        _bottomPercentage = _tiLayoutConstraint.bottom.value;
    }
    TiLayoutUpdateMargins((TiLayoutView*)[self superview], self);
}
-(void)setWidth_:(id)args
{
    _tiLayoutConstraint.width = TiDimensionFromObject(args);
    [self updateWidthAndHeight];
    TiLayoutUpdateMargins((TiLayoutView*)[self superview], self);
    [self layoutIfNeeded];
}
-(void)setHeight_:(id)args
{
    _tiLayoutConstraint.height = TiDimensionFromObject(args);
    [self updateWidthAndHeight];
    TiLayoutUpdateMargins((TiLayoutView*)[self superview], self);
    [self layoutIfNeeded];
}
-(void)setCenter_:(id)args
{
    ENSURE_SINGLE_ARG(args, NSDictionary)
    _tiLayoutConstraint.centerX = TiDimensionFromObject([args valueForKey:@"x"]);
    _tiLayoutConstraint.centerY = TiDimensionFromObject([args valueForKey:@"y"]);
    TiLayoutUpdateMargins((TiLayoutView*)[self superview], self);

}
-(void)setLayout_:(id)args
{
    TiLayoutRule rule = TiLayoutRuleFromObject(args);
    if (rule != _tiLayoutConstraint.layoutStyle)
    {
        _needsToRemoveConstrains = YES;
        _tiLayoutConstraint.layoutStyle = rule;
        [self updateWidthAndHeight];
        [self layoutChildren];
        [self layoutIfNeeded];
    }
}

-(void)fireLayoutEvent
{
    if ([self onLayout] != nil && !CGRectEqualToRect(self.frame, _oldRect)) {
        self.onLayout(self, self.frame);
    }
    _oldRect = self.frame;
}
-(void)removeFromSuperview
{
    [super removeFromSuperview];
    if ([self onViewRemoved] != nil) {
        self.onViewRemoved(self);
    }
}

-(void)addSubview:(nonnull UIView *)view
{
    _needsToRemoveConstrains = YES;
    [super addSubview:view];
    [self layoutChildren];
}
-(void)insertSubview:(UIView *)view belowSubview:(UIView *)siblingSubview
{
    _needsToRemoveConstrains = YES;
    [super insertSubview:view belowSubview:siblingSubview];
    [self layoutChildren];
}
-(void)insertSubview:(UIView *)view aboveSubview:(nonnull UIView *)siblingSubview
{
    _needsToRemoveConstrains = YES;
    [super insertSubview:view aboveSubview:siblingSubview];
    [self layoutChildren];
}
-(void)insertSubview:(UIView *)view atIndex:(NSInteger)index
{
    _needsToRemoveConstrains = YES;
    [super insertSubview:view atIndex:index];
    [self layoutChildren];
}

-(void)layoutChildren
{
    if (!_loaded) return;
    if (_innerView != nil) return;
    
    BOOL isVertical = TiLayoutRuleIsVertical(_tiLayoutConstraint.layoutStyle);
    BOOL isHorizontal = TiLayoutRuleIsHorizontal(_tiLayoutConstraint.layoutStyle);
    
    NSArray* subviews = [self subviews];
    for (NSUInteger index = 0, length = [subviews count]; index < length; index++)
    {
        TiLayoutView* child = [subviews objectAtIndex:index];
        if (![child isKindOfClass:[TiLayoutView class]]) {
            @throw [NSException exceptionWithName:@"Bad Subview" reason:TI_STRING(@"%s", __PRETTY_FUNCTION__) userInfo:nil];
        };

         if ((isVertical || isHorizontal) && _needsToRemoveConstrains) {
//        if (_needsToRemoveConstrains) {
            TiLayoutRemoveChildConstraints(self, child);
            // LOOK HERE and maybe remove
            [child updateWidthAndHeight];
        }
        
        
        TiLayoutView* previous = index == 0 ? nil : [subviews objectAtIndex:index-1];
        TiLayoutView* next = index < (length - 1)  ? [subviews objectAtIndex:index+1] : nil;
        
        [self updateMarginsPrevious:previous current:child next:next];
    }
    _needsToRemoveConstrains = NO;
    
}

-(void)didMoveToWindow
{
    [super didMoveToWindow];
    UIView *superview = [self superview];
    if (superview != nil) {
        _loaded = YES;
        [self updateWidthAndHeight];
        [self layoutChildren];
    }
}

-(void)addConstraints:(nonnull NSArray *)constraints
{
    for(NSLayoutConstraint* c in constraints) {
        [self addConstraint:c];
    }
}

-(void)removeConstraints:(nonnull NSArray*)constraints
{
    for(NSLayoutConstraint* c in constraints) {
        [self removeConstraint:c];
    }
}

-(void)removeAndReplaceConstraint:(nonnull NSLayoutConstraint *)constraint
{
    [self removeConstraint:constraint];
    [self addConstraint:constraint];
}
-(void)removeAndReplaceConstraints:(NSArray *)constraints
{
    for (NSLayoutConstraint* c in constraints)
    {
        [self removeAndReplaceConstraint:c];
    }
}

-(void)addConstraint:(nonnull NSLayoutConstraint *)constraint
{
    if (!_constraintsAdded) _constraintsAdded = [NSMutableDictionary dictionary];
    NSString* description = TI_CONSTRAINT_STRING(constraint);
    
    NSLayoutConstraint* currentConstraint = [_constraintsAdded valueForKey:description];
    if (currentConstraint) {
        if ([constraint constant] != [currentConstraint constant]) {
            [currentConstraint setConstant: [constraint constant]];
        }
    } else {
        [_constraintsAdded setObject:constraint forKey:description];
        [super addConstraint:constraint];
    }
}

-(void)removeConstraint:(nonnull NSLayoutConstraint *)constraint
{
    if (!_constraintsAdded) _constraintsAdded = [NSMutableDictionary dictionary];
    NSString* description = TI_CONSTRAINT_STRING(constraint);
    NSLayoutConstraint* currentConstraint = [_constraintsAdded valueForKey:description];
    if (currentConstraint != nil) {
        [super removeConstraint:currentConstraint];
        [_constraintsAdded removeObjectForKey:description];
    }
}

-(void)updateWidthAndHeight
{
    if (_loaded == NO) return;

    UIView* superview = [self superview];
    if (superview == nil) return;

    TiDimension width = _tiLayoutConstraint.width;
    TiDimension height = _tiLayoutConstraint.height;

    if (![superview isKindOfClass:[TiLayoutView class]])
    {
        if ([superview isKindOfClass:[UIScrollView class]])
        {
            TiLayoutRemoveChildConstraints(superview, self);
            if (IS_AUTOFILL(height)) {
                [superview addConstraints: TI_CONSTR(@"V:[self(superview)]", TI_VIEWS(superview, self))];
            } else if (IS_DIP(height)) {
                [superview addConstraints: TI_CONSTR( TI_STRING(@"V:[self(%f)]", TiDimensionCalculateValue(height, 1)), TI_VIEWS(self, superview))];
            } else {
                [superview addConstraints: TI_CONSTR(@"V:[self(>=superview)]", TI_VIEWS(superview, self))];
            }
            
            if (IS_AUTOFILL(width)) {
                [superview addConstraints: TI_CONSTR(@"H:[self(superview)]", TI_VIEWS(superview, self))];
            } else if (IS_DIP(width)) {
                [superview addConstraints: TI_CONSTR( TI_STRING(@"H:[self(%f)]", TiDimensionCalculateValue(width, 1)), TI_VIEWS(self, superview))];
            } else {
                [superview addConstraints: TI_CONSTR(@"H:[self(>=superview)]", TI_VIEWS(superview, self))];
            }

        }
        [superview addConstraints: TI_CONSTR(@"V:|[self]|", TI_VIEWS(self, superview))];
        [superview addConstraints: TI_CONSTR(@"H:|[self]|", TI_VIEWS(self, superview))];
        return;
    }
    

    if (_innerView != nil || _innerViewSetup) {
        _innerViewSetup = YES;
        [self addConstraints: TI_CONSTR(@"V:|[_innerView]|", TI_VIEWS(_innerView))];
        [self addConstraints: TI_CONSTR(@"H:|[_innerView]|", TI_VIEWS(_innerView))];
    }
    

    [self removeConstraints: TI_CONSTR(@"H:[self(0)]", TI_VIEWS(self))];
    [superview removeConstraint: [NSLayoutConstraint constraintWithItem: self attribute: NSLayoutAttributeWidth relatedBy: NSLayoutRelationEqual
                                                                 toItem: superview attribute: NSLayoutAttributeWidth multiplier: 1 constant: 1]];
    [self removeConstraints: TI_CONSTR(@"V:[self(0)]", TI_VIEWS(self))];
    [superview removeConstraint: [NSLayoutConstraint constraintWithItem: self attribute: NSLayoutAttributeHeight relatedBy: NSLayoutRelationEqual
                                                                 toItem: superview attribute: NSLayoutAttributeHeight multiplier: 1 constant: 1]];

    // ========= percentage % ============
    if (IS_PERCENT(width)) {
        [superview addConstraint: [NSLayoutConstraint constraintWithItem: self attribute: NSLayoutAttributeWidth relatedBy: NSLayoutRelationEqual
                                                             toItem: superview attribute: NSLayoutAttributeWidth multiplier: width.value constant: 1]];
    }
    if (IS_PERCENT(height)) {
        [superview addConstraint: [NSLayoutConstraint constraintWithItem: self attribute: NSLayoutAttributeHeight relatedBy: NSLayoutRelationEqual
                                                             toItem: superview attribute: NSLayoutAttributeHeight multiplier: height.value constant: 1]];
    }
    if (IS_DIP(width)) {
        CGFloat value = TiDimensionCalculateValue(width, 1);
        [self addConstraints: TI_CONSTR(TI_STRING(@"H:[self(%f)]", value), TI_VIEWS(self))];
    }
    
    if (IS_DIP(height)) {
        CGFloat value = TiDimensionCalculateValue(height, 1);
        [self addConstraints: TI_CONSTR(TI_STRING(@"V:[self(%f)]", value), TI_VIEWS(self))];
    }
    
    if (IS_UNDEFINED(width) && IS_AUTOSIZE(_defaultWidth)) {
        [superview addConstraints: TI_CONSTR(TI_STRING(@"H:[self(<=superview)]"), TI_VIEWS(self, superview))];
    }
    if (IS_UNDEFINED(height) && IS_AUTOSIZE(_defaultHeight)) {
        [superview addConstraints: TI_CONSTR(TI_STRING(@"V:[self(<=superview)]"), TI_VIEWS(self, superview))];
    }
}

-(void)updateMarginsForAbsoluteLayout:(TiLayoutView*)child
{
    NSDictionary* viewsDict = TI_VIEWS(child);
    TiLayoutConstraint* childConstraints = [child tiLayoutConstraint];
    TiDimension left = childConstraints->left;
    TiDimension right = childConstraints->right;
    TiDimension top = childConstraints->top;
    TiDimension bottom = childConstraints->bottom;
    TiDimension centerX = childConstraints->centerX;
    TiDimension centerY = childConstraints->centerY;

    TiDimension width = childConstraints->width;
    TiDimension height = childConstraints->height;
    
    
    // ========= Ti.UI.FILL ============
    if (IS_AUTOFILL(width) || (IS_UNDEFINED(width) && IS_AUTOFILL(child->_defaultWidth))) {
        if (IS_UNDEFINED(left)) left = TiDimensionFromObject(@0);
        if (IS_UNDEFINED(right)) right = TiDimensionFromObject(@0);
    }
    
    if (IS_AUTOFILL(height) || (IS_UNDEFINED(height) && IS_AUTOFILL(child->_defaultHeight))) {
        if (IS_UNDEFINED(top)) top = TiDimensionFromObject(@0);
        if (IS_UNDEFINED(bottom)) bottom = TiDimensionFromObject(@0);
    }

    CGFloat leftValue = TiDimensionCalculateValue(left, 1);
    CGFloat rightValue = TiDimensionCalculateValue(right, 1);
    CGFloat topValue = TiDimensionCalculateValue(top, 1);
    CGFloat bottomValue = TiDimensionCalculateValue(bottom, 1);
    
    // ========= TI.UI.SIZE ============
    if (IS_AUTOSIZE(_tiLayoutConstraint.width)) {
        [self addConstraints: TI_CONSTR( TI_STRING(@"H:|-(>=%f)-[child]-(>=%f)-|", leftValue, rightValue), viewsDict)];
    } else {
        [self removeConstraints: TI_CONSTR( TI_STRING(@"H:|-(>=%f)-[child]-(>=%f)-|", leftValue, rightValue), viewsDict)];
    }
    if (IS_AUTOSIZE(_tiLayoutConstraint.height)) {
        [self addConstraints: TI_CONSTR( TI_STRING(@"V:|-(>=%f)-[child]-(>=%f)-|", topValue, bottomValue), viewsDict)];
    } else {
        [self removeConstraints: TI_CONSTR( TI_STRING(@"V:|-(>=%f)-[child]-(>=%f)-|", topValue, bottomValue), viewsDict)];
    }
    
    // ========= left & right ============
    if (IS_UNDEFINED(left) && IS_UNDEFINED(right))
    {
        [self removeConstraints:TI_CONSTR( TI_STRING( @"H:[child]-%f-|", rightValue), viewsDict)];
        [self removeConstraints:TI_CONSTR( TI_STRING( @"H:|-%f-[child]", leftValue), viewsDict)];
        if (IS_UNDEFINED(centerX)) {
            [self removeConstraint:[NSLayoutConstraint constraintWithItem:child attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeLeft multiplier:1 constant:0]];
            [self addConstraint:[NSLayoutConstraint constraintWithItem:self attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:child attribute:NSLayoutAttributeCenterX multiplier:1 constant:0]];
        } else {
            CGFloat centerXValue = TiDimensionCalculateValue(centerX, 1);
            [self removeConstraint:[NSLayoutConstraint constraintWithItem:self attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:child attribute:NSLayoutAttributeCenterX multiplier:1 constant:0]];
            [self addConstraint:[NSLayoutConstraint constraintWithItem:child attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeLeft multiplier:1 constant:centerXValue]];
        }
    }
    else
    {
        [self removeConstraint:[NSLayoutConstraint constraintWithItem:self attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:child attribute:NSLayoutAttributeCenterX multiplier:1 constant:0]];
        
        
        if (IS_DIP(left)) {
            [self addConstraints:TI_CONSTR( TI_STRING( @"H:|-%f-[child]", leftValue), viewsDict)];
        } else {
            [self removeConstraints:TI_CONSTR( TI_STRING( @"H:|-%f-[child]", leftValue), viewsDict)];
        }
        
        if (IS_DIP(right) && (IS_UNDEFINED(left) || IS_AUTOFILL(width) || IS_UNDEFINED(width))) {
            [self addConstraints:TI_CONSTR( TI_STRING( @"H:[child]-%f-|", rightValue), viewsDict)];
        } else {
            [self removeConstraints:TI_CONSTR( TI_STRING( @"H:[child]-%f-|", rightValue), viewsDict)];
        }
    }

    if (IS_UNDEFINED(top) && IS_UNDEFINED(bottom))
    {
        [self removeConstraints:TI_CONSTR( TI_STRING( @"V:|-%f-[child]", topValue), viewsDict)];
        [self removeConstraints:TI_CONSTR( TI_STRING( @"V:[child]-%f-|", bottomValue), viewsDict)];
        if (IS_UNDEFINED(centerY)) {
            [self removeConstraint:[NSLayoutConstraint constraintWithItem:child attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeTop multiplier:1 constant:0]];
            [self addConstraint:[NSLayoutConstraint constraintWithItem:child attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeCenterY multiplier:1 constant:0]];
        } else {
            CGFloat centerYValue = TiDimensionCalculateValue(centerY, 1);
            [self removeConstraint:[NSLayoutConstraint constraintWithItem:child attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeCenterY multiplier:1 constant:0]];
            [self addConstraint:[NSLayoutConstraint constraintWithItem:child attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeTop multiplier:1 constant:centerYValue]];
        }
    }
    else
    {
        [self removeConstraint:[NSLayoutConstraint constraintWithItem:child attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeCenterY multiplier:1 constant:0]];

        if (IS_DIP(top)) {
            [self addConstraints:TI_CONSTR( TI_STRING( @"V:|-%f-[child]", topValue), viewsDict)];
        } else {
            [self removeConstraints:TI_CONSTR( TI_STRING( @"V:|-%f-[child]", topValue), viewsDict)];
        }
        if (IS_DIP(bottom) && (IS_UNDEFINED(top) || IS_AUTOFILL(height) || IS_UNDEFINED(height))) {
            [self addConstraints:TI_CONSTR( TI_STRING( @"V:[child]-%f-|", bottomValue), viewsDict)];
        } else {
            [self removeConstraints:TI_CONSTR( TI_STRING( @"V:[child]-%f-|", bottomValue), viewsDict)];
        }
    }

}

-(void)updateMarginsForVerticalLayout:(TiLayoutView*)prev current:(TiLayoutView*)child next:(TiLayoutView*)next
{
    NSDictionary* viewsDict = TI_VIEWS(child);
    TiLayoutConstraint* childConstraints = [child tiLayoutConstraint];
    TiDimension left = childConstraints->left;
    TiDimension right = childConstraints->right;
    TiDimension top = childConstraints->top;
    TiDimension bottom = childConstraints->bottom;
    
    TiDimension width = childConstraints->width;
    //TiDimension height = childConstraints->height;
    
    // ========= Ti.UI.FILL ============
    if (IS_AUTOFILL(width) || (IS_UNDEFINED(width) && IS_AUTOFILL(child->_defaultWidth))) {
        if (IS_UNDEFINED(left)) left = TiDimensionFromObject(@0);
        if (IS_UNDEFINED(right)) right = TiDimensionFromObject(@0);
    }

    CGFloat leftValue = TiDimensionCalculateValue(left, 1);
    CGFloat rightValue = TiDimensionCalculateValue(right, 1);
    CGFloat topValue = TiDimensionCalculateValue(top, 1);
    CGFloat bottomValue = TiDimensionCalculateValue(bottom, 1);
    
    // ========= TI.UI.SIZE ============
    if (IS_AUTOSIZE(_tiLayoutConstraint.width)) {
        [self addConstraints: TI_CONSTR( TI_STRING(@"H:|-(>=%f)-[child]-(>=%f)-|", leftValue, rightValue), viewsDict)];
    } else {
        [self removeConstraints: TI_CONSTR( TI_STRING(@"H:|-(>=%f)-[child]-(>=%f)-|", leftValue, rightValue), viewsDict)];
    }
    if (IS_AUTOSIZE(_tiLayoutConstraint.height)) {
//        [self removeConstraints: TI_CONSTR( @"V:|-0-[child]", TI_VIEWS(child))];
        [self addConstraints: TI_CONSTR( TI_STRING(@"V:|-(>=%f)-[child]-(>=%f)-|", topValue, bottomValue), viewsDict)];
    } else {
        [self removeConstraints: TI_CONSTR( TI_STRING(@"V:|-(>=%f)-[child]-(>=%f)-|", topValue, bottomValue), viewsDict)];
    }
    
    // ========= left & right ============
    if (IS_UNDEFINED(left) && IS_UNDEFINED(right))
    {
        [self addConstraint:[NSLayoutConstraint constraintWithItem:self attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:child attribute:NSLayoutAttributeCenterX multiplier:1 constant:0]];
    }
    else
    {
        [self removeConstraint:[NSLayoutConstraint constraintWithItem:self attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:child attribute:NSLayoutAttributeCenterX multiplier:1 constant:0]];
        
        if (IS_DIP(left)) {
            [self addConstraints:TI_CONSTR( TI_STRING( @"H:|-%f-[child]", leftValue), viewsDict)];
        } else {
            [self removeConstraints:TI_CONSTR( TI_STRING( @"H:|-%f-[child]", leftValue), viewsDict)];
        }
        
        if (IS_DIP(right) && (IS_UNDEFINED(left) || IS_AUTOFILL(width) || IS_UNDEFINED(width))) {
            [self addConstraints:TI_CONSTR( TI_STRING( @"H:[child]-%f-|", rightValue), viewsDict)];
        } else {
            [self removeConstraints:TI_CONSTR( TI_STRING( @"H:[child]-%f-|", rightValue), viewsDict)];
        }
    }

    if (prev == nil) // first one
    {
        [self addConstraints: TI_CONSTR( TI_STRING(@"V:|-%f-[child]",topValue), viewsDict)];
    }
    else
    {
        NSDictionary* viewsDict2 = TI_VIEWS(prev, child);
        [self removeConstraints: TI_CONSTR(@"V:|-0-[child]", viewsDict)];
        
        TiLayoutConstraint* previousConstraints = [prev tiLayoutConstraint];
        TiDimension prevBottom = previousConstraints->bottom;
        
        CGFloat prevBottomValue = TiDimensionCalculateValue(prevBottom, 1);
        [self addConstraints: TI_CONSTR( TI_STRING(@"V:[prev]-%f-[child]",(topValue+prevBottomValue)), viewsDict2)];
        
        
        if (next == nil) // last one
        {
            [self addConstraints: TI_CONSTR( TI_STRING(@"V:[child]-(>=%f)-|",(bottomValue)), viewsDict2)];
        } else {
            [self removeConstraints: TI_CONSTR(@"V:[child]-(>=0)-|", viewsDict2)];
        }
    }

}

-(void)updateMarginsForHorizontalLayout:(TiLayoutView*)prev current:(TiLayoutView*)child next:(TiLayoutView*)next
{
    TiLayoutConstraint* childConstraints = [child tiLayoutConstraint];
    TiDimension left = childConstraints->left;
    TiDimension right = childConstraints->right;
    TiDimension top = childConstraints->top;
    TiDimension bottom = childConstraints->bottom;


    CGFloat leftValue = TiDimensionCalculateValue(left, 1);
    CGFloat rightValue = TiDimensionCalculateValue(right, 1);
    CGFloat topValue = TiDimensionCalculateValue(top, 1);
    CGFloat bottomValue = TiDimensionCalculateValue(bottom, 1);
    
    if (prev == nil) // first
    {
        [self addConstraints: TI_CONSTR( TI_STRING(@"H:|-(>=%f)-[child]", leftValue), TI_VIEWS(child))];
    }
    else
    {
        TiLayoutConstraint* previousConstraints = [prev tiLayoutConstraint];
        TiDimension prevRight = previousConstraints->right;
        
        CGFloat prevRightValue = TiDimensionCalculateValue(prevRight, 1);
        [self addConstraints: TI_CONSTR( TI_STRING(@"H:[prev]-%f-[child]",(leftValue+prevRightValue)), TI_VIEWS(prev, child))];
    }
    
    
    if (_horizontalWrap) {
        [self addConstraints: TI_CONSTR( TI_STRING(@"V:|-(>=%f)-[child]",(topValue)), TI_VIEWS(child))];
        [self addConstraints: TI_CONSTR( TI_STRING(@"V:[child]-(>=%f)-|",(bottomValue)), TI_VIEWS(child))];

    } else {
        
        TiDimension height = childConstraints->height;
        if (IS_AUTOFILL(height) || (IS_UNDEFINED(height) && IS_AUTOFILL(child->_defaultHeight))) {
            if (IS_UNDEFINED(top)) top = TiDimensionFromObject(@0);
            if (IS_UNDEFINED(bottom)) bottom = TiDimensionFromObject(@0);
        }
        
        BOOL bottomUndefined = IS_UNDEFINED(bottom);
        BOOL topUndefined = IS_UNDEFINED(top);
        if (bottomUndefined && topUndefined)
        {
            [self addConstraint:[NSLayoutConstraint constraintWithItem:self attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:child attribute:NSLayoutAttributeCenterY multiplier:1 constant:0]];
        }
        else
        {
            if (!bottomUndefined) {
                [self addConstraints: TI_CONSTR( TI_STRING(@"V:[child]-%f-|",(bottomValue)), TI_VIEWS(child))];
            }
            if (!topUndefined) {
                [self addConstraints: TI_CONSTR( TI_STRING(@"V:|-%f-[child]",(topValue)), TI_VIEWS(child))];
            }
        }
        if (next == nil) {
            [self addConstraints: TI_CONSTR( TI_STRING(@"H:[child]-(>=%f)-|",(rightValue)), TI_VIEWS(child))];
        }
        
    }
}

-(void)removeConstraintFromChild:(UIView*)child attribute:(NSLayoutAttribute)attribute
{
    NSArray* constraints = [self constraints];
    for (NSLayoutConstraint* c in constraints)
    {
        if (([c firstItem] == child || [c secondItem] == child) &&
            ([c firstAttribute] == attribute || [c secondAttribute] == attribute))
        {
            [self removeConstraint:c];
            return;
        }
    }
}

-(void)redoConstraintsForHorizontalWrap
{
    CGFloat maxWidthAlowed = self.frame.size.width;
    NSArray* children = [self subviews];
    NSUInteger length = [children count];;

    TiLayoutView* tallestView;
    TiLayoutView* tempView;
    CGFloat currentPosition = 0;
    for (NSUInteger i = 0; i < length; i++) {
    
        TiLayoutView* prev = nil;
        TiLayoutView* curr = [children objectAtIndex:i];
        TiLayoutView* next = nil;
    
        TiLayoutConstraint* childConstraints = [curr tiLayoutConstraint];
        
        TiDimension top = childConstraints->top;
        TiDimension left = childConstraints->left;
        TiDimension right = childConstraints->left;
        TiDimension bottom = childConstraints->bottom;
        
        CGFloat topValue = TiDimensionCalculateValue(top, 1);
        CGFloat leftValue = TiDimensionCalculateValue(left, 1);
        CGFloat rightValue = TiDimensionCalculateValue(right, 1);
        CGFloat bottomValue = TiDimensionCalculateValue(bottom, 1);

        
        CGFloat prevBottomValue = 0;
        CGFloat prevRightValue = 0;
        
        if (i != 0) // not first one
        {
            prev = [children objectAtIndex:i-1];
            
            TiLayoutConstraint* prevConstraints = [prev tiLayoutConstraint];
            
            TiDimension prevBottom = prevConstraints->bottom;
            TiDimension prevRight = prevConstraints->right;

            prevBottomValue = TiDimensionCalculateValue(prevBottom, 1);
            prevRightValue = TiDimensionCalculateValue(prevRight, 1);

        }
        if (i < length-1) {
            next = [children objectAtIndex:i+1];
        }

        CGFloat spaceTakenHorizontally = leftValue + curr.frame.size.width + rightValue;
        CGFloat spaceTakenVeritcally = topValue + curr.frame.size.height + bottomValue;

        currentPosition += spaceTakenHorizontally;


        if (currentPosition > maxWidthAlowed) {

            currentPosition = spaceTakenHorizontally;
            tempView = tallestView;
            tallestView = nil;
            [self removeConstraintFromChild:curr attribute:NSLayoutAttributeLeft];
            [self addConstraints: TI_CONSTR( TI_STRING(@"H:|-(>=%f)-[curr]", leftValue), TI_VIEWS(curr))];
        }
        
        [self removeConstraintFromChild:curr attribute:NSLayoutAttributeTop];

        if (tempView != nil) {
            [self addConstraints: TI_CONSTR( TI_STRING(@"V:[tempView]-%f-[curr]", topValue + TiDimensionCalculateValue([tempView tiLayoutConstraint]->bottom, 0)), TI_VIEWS(tempView, curr))];
        } else {
            [self addConstraints: TI_CONSTR( TI_STRING(@"V:|-(%f)-[curr]", topValue), TI_VIEWS(curr))];
        }

        if (tallestView == nil) {
            tallestView = curr;
        } else {
            TiLayoutConstraint* tallestConstraints = [tallestView tiLayoutConstraint];
            CGFloat tallestBottom = TiDimensionCalculateValue(tallestConstraints->bottom, 0);
            CGFloat tallestTop = TiDimensionCalculateValue(tallestConstraints->top,0);
            CGFloat tallestSpaceTakenVeritcally = tallestTop + tallestView.frame.size.height + tallestBottom;
            if (spaceTakenVeritcally > tallestSpaceTakenVeritcally) {
                tallestView = curr;
                spaceTakenVeritcally = tallestSpaceTakenVeritcally;
            }
        }

        if (next == nil) {
            [self addConstraints: TI_CONSTR( TI_STRING(@"V:[curr]-(>=%f)-|", bottomValue), TI_VIEWS(curr))];
        }
    }
}

-(void)checkPercentageMargins
{
    if (_innerView == nil) {
        BOOL isScrollViewContentView = [[self superview] isKindOfClass:[UIScrollView class]];
        CGRect rect;
        if (isScrollViewContentView) {
            rect = [[[self superview] superview] frame];
        } else {
            rect = self.frame;
        }

        if (CGRectIsEmpty(rect)) return;
        
        NSArray* subviews = [self subviews];
        for (NSUInteger index = 0, length = [subviews count]; index < length; index++) {
            TiLayoutView* child = [subviews objectAtIndex:index];
            
            CGFloat parentWidth = rect.size.width;
            CGFloat parentHeight = rect.size.height;
            BOOL isLeftPercentage = child->_isLeftPercentage ;
            BOOL isRightPercentage = child->_isRightPercentage ;
            BOOL isTopPercentage = child->_isTopPercentage ;
            BOOL isBottomPercentage= child->_isBottomPercentage;
            BOOL needsUpdate = NO;
            if (isLeftPercentage || isRightPercentage || isTopPercentage || isBottomPercentage)
            {
                
                if (isLeftPercentage) {
                    CGFloat value = parentWidth * child->_leftPercentage;
                    TiDimension newValue = TiDimensionFromObject([NSString stringWithFormat:@"%f",value]);
                    if (!TiDimensionEqual(newValue, child->_tiLayoutConstraint.left))
                    {
                        child->_tiLayoutConstraint.left = newValue;
                        needsUpdate = YES;
                    }
                }
                if (isRightPercentage) {
                    CGFloat value = parentWidth * child->_rightPercentage;
                    TiDimension newValue = TiDimensionFromObject([NSString stringWithFormat:@"%f",value]);
                    if (!TiDimensionEqual(newValue, child->_tiLayoutConstraint.right))
                    {
                        child->_tiLayoutConstraint.right = newValue;
                        needsUpdate = YES;
                    }
                }
                if (isTopPercentage) {
                    CGFloat value = parentHeight * child->_topPercentage;
                    TiDimension newValue = TiDimensionFromObject([NSString stringWithFormat:@"%f",value]);
                    if (!TiDimensionEqual(newValue, child->_tiLayoutConstraint.top))
                    {
                        child->_tiLayoutConstraint.top = newValue;
                        needsUpdate = YES;
                    }
                }
                if (isBottomPercentage) {
                    CGFloat value = parentHeight * child->_bottomPercentage;
                    TiDimension newValue = TiDimensionFromObject([NSString stringWithFormat:@"%f",value]);
                    if (!TiDimensionEqual(newValue, child->_tiLayoutConstraint.bottom))
                    {
                        child->_tiLayoutConstraint.bottom = newValue;
                        needsUpdate = YES;
                    }
                }
            }
            
            if (needsUpdate) {
                TiLayoutView* previous = index == 0 ? nil : [subviews objectAtIndex:index-1];
                TiLayoutView* next = index < (length - 1)  ? [subviews objectAtIndex:index+1] : nil;
                [self updateMarginsPrevious:previous current:child next:next];
            }
        }
    }
}

-(void)layoutSubviews
{
    [self checkPercentageMargins];
    [super layoutSubviews];
    if (TiLayoutRuleIsHorizontal(_tiLayoutConstraint.layoutStyle) && [self horizontalWrap])
    {
        _needsToRemoveConstrains = YES;
        [self layoutChildren];
        [super layoutSubviews];
        [self redoConstraintsForHorizontalWrap];
        [super layoutSubviews];
    }
}

-(void)updateMarginsPrevious:(TiLayoutView*)prev current:(TiLayoutView*)current next:(TiLayoutView*)next
{
    if (TiLayoutRuleIsHorizontal(_tiLayoutConstraint.layoutStyle))
    {
        [self updateMarginsForHorizontalLayout:prev current:current next:next];
    }
    else if (TiLayoutRuleIsVertical(_tiLayoutConstraint.layoutStyle))
    {
        [self updateMarginsForVerticalLayout:prev current:current next:next];
    }
    else
    {
        [self updateMarginsForAbsoluteLayout:current];
    }
}
@end

void TiLayoutUpdateMargins(TiLayoutView* superview, TiLayoutView* self)
{
    if (superview != nil) {
        if ([superview isKindOfClass:[TiLayoutView class]])
        {
            if (TiLayoutRuleIsAbsolute([superview tiLayoutConstraint]->layoutStyle)) {
                [superview updateMarginsForAbsoluteLayout:self];
            } else {
                [(TiLayoutView*)[self superview] layoutChildren];
            }
        }
        [superview setNeedsLayout];
        [superview layoutIfNeeded];
    }
}
void TiLayoutRemoveChildConstraints(UIView* superview, UIView*child)
{
    NSMutableArray* toRemoved = [NSMutableArray array];
    for (NSLayoutConstraint* constraint in [superview constraints]) {
        if (([constraint firstItem] == child || [constraint secondItem] == child))
        {
            [toRemoved addObject:constraint];
        }
    }
    [superview removeConstraints:toRemoved];
}
