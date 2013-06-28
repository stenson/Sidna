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
    AudioUnit _effectUnit;
    AudioUnit _distortionUnit;
    
    AudioUnit _drones[STRING_COUNT];
    BOOL _droning[STRING_COUNT];
    AudioUnit _varispeeds[STRING_COUNT];
    NSInteger _notes[STRING_COUNT];
}
@end

@implementation SDNAudio

#pragma mark public mutators

- (void)enableDrone:(NSInteger)tag
{
    if (_droning[tag] != YES) {
        _droning[tag] = YES;
        CheckError(MusicDeviceMIDIEvent(_drones[tag], 0x90, _notes[tag], 127, 0), "on");
    }
}

- (void)disableDrone:(NSInteger)tag
{
    if (_droning[tag]) {
        _droning[tag] = NO;
        CheckError(MusicDeviceMIDIEvent(_drones[tag], 0x80, _notes[tag], 0, 0), "off");
    }
    //CheckError(MusicDeviceMIDIEvent(_drones[tag], 0x90, _notes[tag] + 12, 40, 0), "octave");
    //CheckError(MusicDeviceMIDIEvent(_drones[tag], 0x80, _notes[tag] + 12, 0, 20), "octave");
}

- (void)setDrone:(NSInteger)tag note:(NSInteger)note
{
    _notes[tag] = note;
}

- (void)updateDrone:(NSInteger)tag percentage:(Float32)percentage
{
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

#pragma mark - AUGraph

- (BOOL)setupAUGraph
{
    CheckError(NewAUGraph(&_graph), "instantiate graph");
    
    AUNode rioNode = [self addNodeWithType:kAudioUnitType_Output AndSubtype:kAudioUnitSubType_RemoteIO];
    AUNode mixerNode = [self addNodeWithType:kAudioUnitType_Mixer AndSubtype:kAudioUnitSubType_MultiChannelMixer];
    AUNode effectNode = [self addNodeWithType:kAudioUnitType_Effect AndSubtype:kAudioUnitSubType_Reverb2];
    AUNode distortionNode = [self addNodeWithType:kAudioUnitType_Effect AndSubtype:kAudioUnitSubType_Distortion];
    AUNode varispeedNodes[STRING_COUNT];
    AUNode droneNodes[STRING_COUNT];
    
    for (int i = 0; i < STRING_COUNT; i++) {
        varispeedNodes[i] = [self addNodeWithType:kAudioUnitType_FormatConverter AndSubtype:kAudioUnitSubType_Varispeed];
        droneNodes[i] = [self addNodeWithType:kAudioUnitType_MusicDevice AndSubtype:kAudioUnitSubType_Sampler];
    }
    
    CheckError(AUGraphOpen(_graph), "open graph");
    
    _rioUnit = [self unitFromNode:rioNode];
    _mixerUnit = [self unitFromNode:mixerNode];
    _effectUnit = [self unitFromNode:effectNode];
    _distortionUnit = [self unitFromNode:distortionNode];
    
    AudioStreamBasicDescription effectASBD;
    UInt32 asbdSize = sizeof(effectASBD);
    memset(&effectASBD, 0, asbdSize);
    CheckError(AudioUnitGetProperty(_effectUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &effectASBD, &asbdSize), "asbd from reverb");
    CheckError(AudioUnitSetProperty(_mixerUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, &effectASBD, sizeof(effectASBD)), "set on mixer");
    
    CheckError(AudioUnitSetParameter(_effectUnit, kReverb2Param_DryWetMix, kAudioUnitScope_Global, 0, 40.0, 0), "reverb gain");
    CheckError(AudioUnitSetParameter(_distortionUnit, kDistortionParam_FinalMix, kAudioUnitScope_Global, 0, 5.0, 0), "delay time");
    
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
    
    CheckError(AUGraphConnectNodeInput(_graph, mixerNode, 0, effectNode, 0), "mixer to effect");
    CheckError(AUGraphConnectNodeInput(_graph, effectNode, 0, distortionNode, 0), "effect to dist");
    CheckError(AUGraphConnectNodeInput(_graph, distortionNode, 0, rioNode, 0), "effect to rio");
    
    CheckError(AUGraphInitialize(_graph), "initialize graph");
    CheckError(AudioSessionSetActive(1), "activate audio session");
    CheckError(AUGraphStart(_graph), "start graph");
    
    [self loadPresetToUnit:_drones[1]];
    
    return YES;
}

- (OSStatus)loadPresetToUnit:(AudioUnit)unit {
    NSString *path = [[NSBundle mainBundle] pathForResource:@"MellotronFluteC" ofType:@"aupreset"];
    NSDictionary *plist = [NSDictionary dictionaryWithContentsOfFile:path];
    CFPropertyListRef plistRef = (__bridge CFPropertyListRef)plist;
    return AudioUnitSetProperty(unit, kAudioUnitProperty_ClassInfo, kAudioUnitScope_Global, 0, &plistRef, sizeof(CFPropertyListRef));
}

#pragma mark - Helpers

static void InterruptionListener (void *inUserData, UInt32 inInterruptionState)
{
	NSLog(@"Interruption");
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
