//
//  SDNViewController.m
//  Sidna
//
//  Created by Robert Stenson on 6/25/13.
//  Copyright (c) 2013 ADK. All rights reserved.
//

#import "SDNViewController.h"
#import "SDNString.h"
#import "CGGeometryAdditions.h"
#import "SDNAudio.h"
#import "SDNConstants.h"

@interface SDNViewController () {
    SDNAudio *_audio;
    CGFloat _ys[STRING_COUNT];
    CGFloat _percents[STRING_COUNT];
}
@end

@implementation SDNViewController

- (CGFloat)randomFloat
{
    return (float)arc4random_uniform(100)/100.f;
}

- (UIColor *)randomColor
{
    return [UIColor colorWithRed:self.randomFloat green:self.randomFloat blue:self.randomFloat alpha:1.f];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _audio = [[SDNAudio alloc] init];
    [_audio power];
    
    NSInteger notes[] = { 79, 48, 60, 67, 72, 74 };
    
    for (int i = 0; i < STRING_COUNT; i++) {
        SDNString *string = [[SDNString alloc] init];
        string.backgroundColor = [self randomColor];
        string.tag = i;
        UILongPressGestureRecognizer *press = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleStringPress:)];
        press.minimumPressDuration = 0.f;
        //[string addGestureRecognizer:press];
        [self.view addSubview:string];
        [_audio setDrone:i note:notes[i]];
    }
    
    self.view.multipleTouchEnabled = YES;
    self.view.exclusiveTouch = YES;
}

- (void)viewDidLayoutSubviews
{
    NSInteger count = self.view.subviews.count;
    CGRect strings[count-1];
    CGRect highG;
    
    CGRectDivideRectIntoEqualSubs(CGRectSegment(self.view.bounds, &highG, NULL, 44.f, CGRectMinYEdge), strings, count-1, CGRectMinYEdge);
    [self.view.subviews[0] setFrame:highG];
    for (int i = 1; i < count; i++) {
        CGRect frame = strings[i-1];
        _ys[i-1] = CGRectGetMinY(frame);
        [self.view.subviews[i] setFrame:frame];
    }
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self handleTouches:event.allTouches];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self handleTouches:event.allTouches];
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    // look out for 6 touches
    NSLog(@"cancelled: %i", touches.count);
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self handleTouches:event.allTouches];
}

- (void)handleTouches:(NSSet *)touches
{
    for (int i = 0; i < STRING_COUNT; i++) _percents[i] = 0.f;
    CGFloat width = CGRectGetWidth(self.view.bounds);
    
    for (UITouch *touch in touches) {
        if (touch.phase == UITouchPhaseBegan || touch.phase == UITouchPhaseMoved || touch.phase == UITouchPhaseStationary) {
            CGPoint location = [touch locationInView:self.view];
            NSInteger string = 0;
            for (string = 0; string < STRING_COUNT-1; string++) {
                if (location.y < _ys[string]) {
                    break;
                }
            }
            
            CGFloat percent = 1.f - (location.x / width);
            if (_percents[string] == 0.f || _percents[string] < percent) {
                _percents[string] = percent;
            }
        }
    }
    
    for (int i = 0; i < STRING_COUNT; i++) {
        if (_percents[i] > 0.f) {
            [_audio enableDrone:i];
            [_audio updateDrone:i percentage:_percents[i]];
        } else {
            [_audio disableDrone:i];
        }
    }
}

- (void)handleStringPress:(UILongPressGestureRecognizer *)press
{
    CGPoint location = [press locationInView:press.view];
    CGFloat percent = (location.y / press.view.bounds.size.height);
    NSInteger tag = press.view.tag;
    switch (press.state) {
        case UIGestureRecognizerStateBegan: {
            [_audio enableDrone:tag];
        }
        case UIGestureRecognizerStateChanged: {
            [_audio updateDrone:tag percentage:percent];
        } break;
        case UIGestureRecognizerStateCancelled:
        case UIGestureRecognizerStateEnded: {
            [_audio disableDrone:tag];
        } break;
        default: break;
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

@end
