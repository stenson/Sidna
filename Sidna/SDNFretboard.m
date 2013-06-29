//
//  SDNFretboard.m
//  Sidna
//
//  Created by Robert Stenson on 6/28/13.
//  Copyright (c) 2013 ADK. All rights reserved.
//

#import "SDNFretboard.h"

@implementation SDNFretboard

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.multipleTouchEnabled = YES;
        self.exclusiveTouch = YES;
    }
    return self;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    
}

@end
