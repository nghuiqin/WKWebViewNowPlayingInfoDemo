//
// KKAudioNode+View.m
//
// Copyright (c) 2014 KKBOX Taiwan Co., Ltd. All Rights Reserved.
//

#import "KKAudioNode+View.h"
#import <CoreAudioKit/CoreAudioKit.h>
#import <objc/runtime.h>

@implementation KKAudioNode (View)

- (NSView *)_view
{
	return objc_getAssociatedObject(self, "view");
}

- (void)_setView:(NSView *)view
{
	objc_setAssociatedObject(self, "view", view, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSView *)view
{
	if (self.audioUnit == NULL) {
		return nil;
	}

	NSView *view = [self _view];
	if (!view) {
		view = [[AUGenericView alloc] initWithAudioUnit:self.audioUnit];
		[self _setView:view];
	}
	return view;
}

@end
