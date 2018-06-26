//
// Copyright 2016 Google Inc. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

#import <AVFoundation/AVFoundation.h>

#import "AudioController.h"

@interface AudioController () {
  AudioComponentInstance remoteIOUnit;
    BOOL audioComponentInitialized;
}
@end

@implementation AudioController

+ (instancetype) sharedInstance {
  static AudioController *instance = nil;
  if (!instance) {
    instance = [[self alloc] init];
  }
  return instance;
}

- (void) dealloc {
  AudioComponentInstanceDispose(remoteIOUnit);
}

static OSStatus CheckError(OSStatus error, const char *operation)
{
  if (error == noErr) {
    return error;
  }
  char errorString[20];
  // See if it appears to be a 4-char-code
  *(UInt32 *)(errorString + 1) = CFSwapInt32HostToBig(error);
  if (isprint(errorString[1]) && isprint(errorString[2]) &&
      isprint(errorString[3]) && isprint(errorString[4])) {
    errorString[0] = errorString[5] = '\'';
    errorString[6] = '\0';
  } else {
    // No, format it as an integer
    sprintf(errorString, "%d", (int)error);
  }
  fprintf(stderr, "Error: %s (%s)\n", operation, errorString);
  return error;
}

static OSStatus recordingCallback(void *inRefCon,
                                  AudioUnitRenderActionFlags *ioActionFlags,
                                  const AudioTimeStamp *inTimeStamp,
                                  UInt32 inBusNumber,
                                  UInt32 inNumberFrames,
                                  AudioBufferList *ioData) {
  OSStatus status;

  AudioController *audioController = (__bridge AudioController *) inRefCon;

  int channelCount = 1;

  // build the AudioBufferList structure
  AudioBufferList *bufferList = (AudioBufferList *) malloc (sizeof (AudioBufferList));
  bufferList->mNumberBuffers = channelCount;
  bufferList->mBuffers[0].mNumberChannels = 1;
  bufferList->mBuffers[0].mDataByteSize = inNumberFrames * 2;
  bufferList->mBuffers[0].mData = NULL;

  // get the recorded samples
  status = AudioUnitRender(audioController->remoteIOUnit,
                           ioActionFlags,
                           inTimeStamp,
                           inBusNumber,
                           inNumberFrames,
                           bufferList);
  if (status != noErr) {
    return status;
  }

  NSData *data = [[NSData alloc] initWithBytes:bufferList->mBuffers[0].mData
                                        length:bufferList->mBuffers[0].mDataByteSize];
  dispatch_async(dispatch_get_main_queue(), ^{
    [audioController.delegate processSampleData:data];
  });

  return noErr;
}

static OSStatus playbackCallback(void *inRefCon,
                                 AudioUnitRenderActionFlags *ioActionFlags,
                                 const AudioTimeStamp *inTimeStamp,
                                 UInt32 inBusNumber,
                                 UInt32 inNumberFrames,
                                 AudioBufferList *ioData) {
  OSStatus status = noErr;

  // Notes: ioData contains buffers (may be more than one!)
  // Fill them up as much as you can. Remember to set the size value in each buffer to match how
  // much data is in the buffer.
  AudioController *audioController = (__bridge AudioController *) inRefCon;

  UInt32 bus1 = 1;
  status = AudioUnitRender(audioController->remoteIOUnit,
                           ioActionFlags,
                           inTimeStamp,
                           bus1,
                           inNumberFrames,
                           ioData);
  CheckError(status, "Couldn't render from RemoteIO unit");
  return status;
}

- (OSStatus) prepareWithSampleRate:(double) specifiedSampleRate {
  OSStatus status = noErr;

  AVAudioSession *session = [AVAudioSession sharedInstance];

  NSError *error;

  BOOL ok = [session setCategory:AVAudioSessionCategoryRecord error:&error];
  NSLog(@"set category %d", ok);

  // This doesn't seem to really indicate a problem (iPhone 6s Plus)
#ifdef IGNORE
  NSInteger inputChannels = session.inputNumberOfChannels;
  if (!inputChannels) {
    NSLog(@"ERROR: NO AUDIO INPUT DEVICE");
    return -1;
  }
#endif

  [session setPreferredIOBufferDuration:10 error:&error];

  double sampleRate = session.sampleRate;
  NSLog (@"hardware sample rate = %f, using specified rate = %f", sampleRate, specifiedSampleRate);
  sampleRate = specifiedSampleRate;
  if (!audioComponentInitialized) {
        
    audioComponentInitialized = YES;
    // Describe the RemoteIO unit
    AudioComponentDescription audioComponentDescription;
    audioComponentDescription.componentType = kAudioUnitType_Output;
    audioComponentDescription.componentSubType = kAudioUnitSubType_RemoteIO;
    audioComponentDescription.componentManufacturer = kAudioUnitManufacturer_Apple;
    audioComponentDescription.componentFlags = 0;
    audioComponentDescription.componentFlagsMask = 0;

    // Get the RemoteIO unit
    AudioComponent remoteIOComponent = AudioComponentFindNext(NULL,&audioComponentDescription);
    status = AudioComponentInstanceNew(remoteIOComponent,&(self->remoteIOUnit));
    if (CheckError(status, "Couldn't get RemoteIO unit instance")) {
      return status;
    }
    
  }

  UInt32 oneFlag = 1;
  AudioUnitElement bus0 = 0;
  AudioUnitElement bus1 = 1;

  if ((NO)) {
    // Configure the RemoteIO unit for playback
    status = AudioUnitSetProperty (self->remoteIOUnit,
                                   kAudioOutputUnitProperty_EnableIO,
                                   kAudioUnitScope_Output,
                                   bus0,
                                   &oneFlag,
                                   sizeof(oneFlag));
    if (CheckError(status, "Couldn't enable RemoteIO output")) {
      return status;
    }
  }

  // Configure the RemoteIO unit for input
  status = AudioUnitSetProperty(self->remoteIOUnit,
                                kAudioOutputUnitProperty_EnableIO,
                                kAudioUnitScope_Input,
                                bus1,
                                &oneFlag,
                                sizeof(oneFlag));
  if (CheckError(status, "Couldn't enable RemoteIO input")) {
    return status;
  }

  AudioStreamBasicDescription asbd;
  memset(&asbd, 0, sizeof(asbd));
  asbd.mSampleRate = sampleRate;
  asbd.mFormatID = kAudioFormatLinearPCM;
  asbd.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
  asbd.mBytesPerPacket = 2;
  asbd.mFramesPerPacket = 1;
  asbd.mBytesPerFrame = 2;
  asbd.mChannelsPerFrame = 1;
  asbd.mBitsPerChannel = 16;

  // Set format for output (bus 0) on the RemoteIO's input scope
  status = AudioUnitSetProperty(self->remoteIOUnit,
                                kAudioUnitProperty_StreamFormat,
                                kAudioUnitScope_Input,
                                bus0,
                                &asbd,
                                sizeof(asbd));
  if (CheckError(status, "Couldn't set the ASBD for RemoteIO on input scope/bus 0")) {
    return status;
  }

  // Set format for mic input (bus 1) on RemoteIO's output scope
  status = AudioUnitSetProperty(self->remoteIOUnit,
                                kAudioUnitProperty_StreamFormat,
                                kAudioUnitScope_Output,
                                bus1,
                                &asbd,
                                sizeof(asbd));
  if (CheckError(status, "Couldn't set the ASBD for RemoteIO on output scope/bus 1")) {
    return status;
  }

  // Set the recording callback
  AURenderCallbackStruct callbackStruct;
  callbackStruct.inputProc = recordingCallback;
  callbackStruct.inputProcRefCon = (__bridge void *) self;
  status = AudioUnitSetProperty(self->remoteIOUnit,
                                kAudioOutputUnitProperty_SetInputCallback,
                                kAudioUnitScope_Global,
                                bus1,
                                &callbackStruct,
                                sizeof (callbackStruct));
  if (CheckError(status, "Couldn't set RemoteIO's render callback on bus 0")) {
    return status;
  }

  if ((NO)) {
    // Set the playback callback
    AURenderCallbackStruct callbackStruct;
    callbackStruct.inputProc = playbackCallback;
    callbackStruct.inputProcRefCon = (__bridge void *) self;
    status = AudioUnitSetProperty(self->remoteIOUnit,
                                  kAudioUnitProperty_SetRenderCallback,
                                  kAudioUnitScope_Global,
                                  bus0,
                                  &callbackStruct,
                                  sizeof (callbackStruct));
    if (CheckError(status, "Couldn't set RemoteIO's render callback on bus 0")) {
      return status;
    }
  }

  // Initialize the RemoteIO unit
  status = AudioUnitInitialize(self->remoteIOUnit);
  if (CheckError(status, "Couldn't initialize the RemoteIO unit")) {
    return status;
  }

  return status;
}

- (OSStatus) start {
  return AudioOutputUnitStart(self->remoteIOUnit);
}

- (OSStatus) stop {
  return AudioOutputUnitStop(self->remoteIOUnit);
}

@end
