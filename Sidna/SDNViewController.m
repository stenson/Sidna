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
    
    NSInteger notes[] = { 60, 67, 72, 74 };
    
    for (int i = 0; i < STRING_COUNT; i++) {
        SDNString *string = [[SDNString alloc] init];
        string.backgroundColor = [self randomColor];
        string.tag = i;
        UILongPressGestureRecognizer *press = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleStringPress:)];
        press.minimumPressDuration = 0.f;
        [string addGestureRecognizer:press];
        [self.view addSubview:string];
        [_audio setDrone:i note:notes[i]];
    }
}

- (void)viewDidLayoutSubviews
{
    NSInteger count = self.view.subviews.count;
    NSInteger i = 0;
    CGRect strings[count];
    CGRectDivideRectIntoEqualSubs(self.view.bounds, strings, count, CGRectMinXEdge);
    
    for (SDNString *string in self.view.subviews) {
        string.frame = strings[i++];
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
