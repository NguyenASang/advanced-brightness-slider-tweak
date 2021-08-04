#import <ControlCenterUIKit/CCUICAPackageDescription.h>
#import "ReduceWhitePointLevel.h"

@interface UIDevice (Category)
@property float _backlightLevel;
@end

@interface SBDisplayBrightnessController
-(void) setBrightnessLevel:(float) arg1;
@end

@interface CCUIContinuousSliderView : UIControl {
	CCUICAPackageDescription* _glyphPackageDescription;
	UIPanGestureRecognizer* _valueChangeGestureRecognizer;
}
-(CCUICAPackageDescription *)glyphPackageDescription;
-(void)_handleValueChangeGestureRecognizer:(id)arg1;
-(BOOL)isGlyphVisible;
-(CGSize)size;
-(void)setValue:(float)arg1;
-(BOOL) isBrightnessSlider;
-(float) inSmallMode;
@end

SBDisplayBrightnessController * brightness;
float currentSliderLevel; // TODO: update this when system brightness changes from elsewhere (with listener)
float oldSliderLevel; // keep track of where slider was to calculate panning offset
float threshold = 0.3; // value where slider switches from brightness to

float clampZeroOne(float value) {
	if (value > 1) return 1.0f;
	else if (value < 0) return 0.0f;
	else return value;
}

%hook CCUIContinuousSliderView

-(id)initWithFrame:(CGRect)arg1 {
	id orig = %orig;
	brightness = [%c(SBDisplayBrightnessController) new];
	currentSliderLevel = [[%c(UIDevice) currentDevice] _backlightLevel];
	oldSliderLevel = currentSliderLevel;
	return orig;
}

%new
-(BOOL) isBrightnessSlider {
	// TODO: implement less complex (save slider type in boolean property if possible, string comparison is expensive)
	NSString * glyphpackage = [[[self glyphPackageDescription] packageURL] absoluteString];
	return [glyphpackage rangeOfString:@"Brightness"].location != NSNotFound;
}

%new
-(float) inSmallMode {
	return [self isGlyphVisible];
}

-(void)_handleValueChangeGestureRecognizer:(id)arg1 {
	if (![self isBrightnessSlider]) return %orig;

	UIPanGestureRecognizer * recognizer = (UIPanGestureRecognizer *) arg1;
	CGPoint translation = [recognizer translationInView: self];
	float ytranslation = (float) translation.y / ([self inSmallMode] ? 160.0f : 350.0f);

	if ([recognizer state] == UIGestureRecognizerStateBegan) {
		oldSliderLevel = currentSliderLevel;
	}

	currentSliderLevel = clampZeroOne(oldSliderLevel - ytranslation);
	if (currentSliderLevel >= threshold) {
		float distance = 1 - threshold; // 0.7
		float upperSectionSliderLevel = currentSliderLevel - threshold; // in 0.7..0
		float newBrightnessLevel = upperSectionSliderLevel / distance; // in 1..0
		[brightness setBrightnessLevel: newBrightnessLevel];
	} else {
		float distance = threshold; // 0.3
		float lowerSectionSliderLevel = currentSliderLevel; // 0..0..3
		float newWhitePointLevel = lowerSectionSliderLevel / distance; // 0..1
		float newAdjustedWhitePointLevel = 1 - (newWhitePointLevel * 0.75f); // 1..0.25
		MADisplayFilterPrefSetReduceWhitePointIntensity(newAdjustedWhitePointLevel);
		[self setValue: -newAdjustedWhitePointLevel];
	}
}

-(void) setValue:(float)arg1 {
	if(![self isBrightnessSlider]) return %orig;

	if (arg1 >= 0) {
		// brightness
		float distance = 1 - threshold; // 0.7
		float newSliderLevel = arg1 * distance + threshold; // 1..0.3
		%orig(newSliderLevel);
	} else {
		// arg1 -0.25..-1
		float distance = threshold; // 0.3
		float whitePointLevel = -arg1; // 1..0.25
		float levelBetween0and1 = (whitePointLevel - 0.25f) / 0.75f; // 0..1
		float newSliderLevel = distance - (levelBetween0and1 * distance); // 0.3..0
		%orig(newSliderLevel);
	}
}

%end;
