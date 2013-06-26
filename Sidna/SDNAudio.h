//
//  SDNAudio.h
//  Sidna
//
//  Created by Robert Stenson on 6/25/13.
//  Copyright (c) 2013 ADK. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

@interface SDNAudio : NSObject

- (BOOL)power;
- (void)setDrone:(NSInteger)tag note:(NSInteger)note;
- (void)enableDrone:(NSInteger)tag;
- (void)disableDrone:(NSInteger)tag;
- (void)updateDrone:(NSInteger)tag percentage:(Float32)percentage;

@end
