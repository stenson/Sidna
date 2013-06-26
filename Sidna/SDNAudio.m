//
//  SDNAudio.m
//  Sidna
//
//  Created by Robert Stenson on 6/25/13.
//  Copyright (c) 2013 ADK. All rights reserved.
//

#import "SDNAudio.h"
#import "SDNConstants.h"

@interface SDNAudio () {
    AUGraph _graph;
    AudioUnit _rioUnit;
    AudioUnit _mixerUnit;
    
    AudioUnit _drones[STRING_COUNT];
    AudioUnit _varispeeds[STRING_COUNT];
    NSInteger _notes[STRING_COUNT];
}
@end

@implementation SDNAudio

#pragma mark public mutators

- (void)enableDrone:(NSInteger)tag
{
    CheckError(MusicDeviceMIDIEvent(_drones[tag], 0x90, _notes[tag], 127, 0),  "note");
}

- (void)disableDrone:(NSInteger)tag
{
    CheckError(MusicDeviceMIDIEvent(_drones[tag], 0x90, _notes[tag], 0, 0),  "note");
}

- (void)setDrone:(NSInteger)tag note:(NSInteger)note
{
    _notes[tag] = note;
}

- (void)updateDrone:(NSInteger)tag percentage:(Float32)percentage
{
    //percentage *= 3.75;
    //percentage += 0.25;
    percentage *= 0.5f;
    percentage += 1.f;
    CheckError(AudioUnitSetParameter(_varispeeds[tag], kVarispeedParam_PlaybackRate, kAudioUnitScope_Global, 0, percentage, 0), "rate");
}

#pragma mark public audio interface

- (BOOL)power
{
    CheckError(AudioSessionInitialize(NULL, kCFRunLoopDefaultMode, InterruptionListener, (__bridge void *)self), "couldn't initialize audio session");
    
	UInt32 category = kAudioSessionCategory_MediaPlayback;
    CheckError(AudioSessionSetProperty(kAudioSessionProperty_AudioCategory, sizeof(category), &category), "Couldn't set category on audio session");
    
    [self setupAUGraph];
    
    return YES;
}

- (BOOL)powerOff
{
    return YES;
}

/*
 rioNode, rioUnit
 register nodes & units
 */

#pragma mark graph setup

- (BOOL)setupAUGraph
{
    CheckError(NewAUGraph(&_graph), "instantiate graph");
    
    AUNode rioNode = [self addNodeWithType:kAudioUnitType_Output AndSubtype:kAudioUnitSubType_RemoteIO];
    AUNode mixerNode = [self addNodeWithType:kAudioUnitType_Mixer AndSubtype:kAudioUnitSubType_MultiChannelMixer];
    
    AUNode varispeedNodes[STRING_COUNT];
    AUNode droneNodes[STRING_COUNT];
    
    for (int i = 0; i < STRING_COUNT; i++) {
        varispeedNodes[i] = [self addNodeWithType:kAudioUnitType_FormatConverter AndSubtype:kAudioUnitSubType_Varispeed];
        droneNodes[i] = [self addNodeWithType:kAudioUnitType_MusicDevice AndSubtype:kAudioUnitSubType_Sampler];
    }
    
    CheckError(AUGraphOpen(_graph), "open graph");
    
    _rioUnit = [self unitFromNode:rioNode];
    _mixerUnit = [self unitFromNode:mixerNode];
    
    AudioStreamBasicDescription samplerASBD;
    UInt32 samplerASBDSize = sizeof(samplerASBD);
    memset(&samplerASBD, 0, samplerASBDSize);
    
    for (int i = 0; i < STRING_COUNT; i++) {
        _drones[i] = [self unitFromNode:droneNodes[i]];
        _varispeeds[i] = [self unitFromNode:varispeedNodes[i]];
        
        CheckError(AudioUnitGetProperty(_drones[i], kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, &samplerASBD, &samplerASBDSize), "sampler asbd get");
        CheckError(AudioUnitSetProperty(_varispeeds[i], kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, &samplerASBD, samplerASBDSize), "sampler asbd set");
        
        CheckError(AUGraphConnectNodeInput(_graph, droneNodes[i], 0, varispeedNodes[i], 0), "drone to vari");
        CheckError(AUGraphConnectNodeInput(_graph, varispeedNodes[i], 0, mixerNode, i), "vari to mixer");
    }
    
    CheckError(AUGraphConnectNodeInput(_graph, mixerNode, 0, rioNode, 0), "mixer to rio");
    
    CheckError(AUGraphInitialize(_graph), "initialize graph");
    CheckError(AudioSessionSetActive(1), "activate audio session");
    CheckError(AUGraphStart(_graph), "start graph");
    
//    for (int i = 0; i < STRING_COUNT; i++) {
//        CheckError(MusicDeviceMIDIEvent(_drones[i], 0x90, 62, 127, 0),  "note");
//    }
    
    return YES;
}

#pragma mark private helper functions

- (CFURLRef)urlRefWithTitle:(NSString *)title
{
    NSString *filePath = [[NSBundle mainBundle] pathForResource:title ofType:@"m4a"];
    return CFURLCreateWithFileSystemPath(kCFAllocatorDefault, (__bridge CFStringRef)filePath, kCFURLPOSIXPathStyle, false);
}

static void InterruptionListener (void *inUserData, UInt32 inInterruptionState)
{
	NSLog(@"INTERRUPTION");
}

- (AUNode)addNodeWithType:(OSType)type AndSubtype:(OSType)subtype
{
    AudioComponentDescription acd;
    AUNode node;
    
    acd.componentType = type;
    acd.componentSubType = subtype;
    acd.componentManufacturer = kAudioUnitManufacturer_Apple;
    acd.componentFlags = 0;
    acd.componentFlagsMask = 0;
    
    CheckError(AUGraphAddNode(_graph, &acd, &node), "adding node");
    return node;
}

- (AudioUnit)unitFromNode:(AUNode)node
{
    AudioUnit unit;
    CheckError(AUGraphNodeInfo(_graph, node, NULL, &unit), "unit from node");
    return unit;
}

- (void)printASBD: (AudioStreamBasicDescription) asbd
{
    char formatIDString[5];
    UInt32 formatID = CFSwapInt32HostToBig (asbd.mFormatID);
    bcopy (&formatID, formatIDString, 4);
    formatIDString[4] = '\0';
    
    if (asbd.mFormatFlags & kAudioFormatFlagIsSignedInteger) {
        NSLog(@"YES IT's INTEGER");
    } else if (asbd.mFormatFlags & kAudioFormatFlagIsFloat) {
        NSLog(@"YES IT's FLOAT");
    }
    
    NSLog (@"  Sample Rate:         %10.0f",  asbd.mSampleRate);
    NSLog (@"  Format ID:           %10s",    formatIDString);
    NSLog (@"  Format Flags:        %10lu",    asbd.mFormatFlags);
    NSLog (@"  Bytes per Packet:    %10lu",    asbd.mBytesPerPacket);
    NSLog (@"  Frames per Packet:   %10lu",    asbd.mFramesPerPacket);
    NSLog (@"  Bytes per Frame:     %10lu",    asbd.mBytesPerFrame);
    NSLog (@"  Channels per Frame:  %10lu",    asbd.mChannelsPerFrame);
    NSLog (@"  Bits per Channel:    %10lu",    asbd.mBitsPerChannel);
}

static void CheckError(OSStatus error, const char *operation)
{
	if (error == noErr) return;
	char str[20];
	*(UInt32 *)(str + 1) = CFSwapInt32HostToBig(error);
	if (isprint(str[1]) && isprint(str[2]) && isprint(str[3]) && isprint(str[4])) {
		str[0] = str[5] = '\'';
		str[6] = '\0';
	} else {
		sprintf(str, "%d", (int)error);
    }
	fprintf(stderr, "Error: %s (%s)\n", operation, str);
}


@end
