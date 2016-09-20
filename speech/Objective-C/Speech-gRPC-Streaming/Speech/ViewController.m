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

#import "ViewController.h"
#import "AudioController.h"
#import "SpeechRecognitionService.h"
#import "google/cloud/speech/v1beta1/CloudSpeech.pbrpc.h"

#define SAMPLE_RATE 16000.0f

@interface ViewController () <AudioControllerDelegate>
@property (nonatomic, strong) IBOutlet UITextView *textView;
@property (nonatomic, strong) NSMutableData *audioData;
@end

@implementation ViewController {
  BOOL stopRequested;
  __block BOOL speechWhileEnding;
  __block BOOL endingTransaction;
  BOOL endingStream;
}

- (void)viewDidLoad {
  [super viewDidLoad];

  [AudioController sharedInstance].delegate = self;
}

- (IBAction)recordAudio:(id)sender {
  if (sender) {
    stopRequested = NO;
    speechWhileEnding = NO;
    //_startButton.enabled = NO;
  } else if (stopRequested) {
    return;
  }
  AVAudioSession *audioSession = [AVAudioSession sharedInstance];
  [audioSession setCategory:AVAudioSessionCategoryRecord error:nil];

  _audioData = [[NSMutableData alloc] init];
  [[AudioController sharedInstance] prepareWithSampleRate:SAMPLE_RATE];
  [[SpeechRecognitionService sharedInstance] setSampleRate:SAMPLE_RATE];
  [[AudioController sharedInstance] start];
}

- (IBAction)stopAudio:(id)sender {
  [[AudioController sharedInstance] stop];
  [[SpeechRecognitionService sharedInstance] stopStreaming];
  if (sender) {
    stopRequested = YES;
    //_startButton.enabled = YES;
  }
}

// restart after API error
- (void) restart {
  if (endingStream || stopRequested) {
    return;
  }
  endingStream = YES;
  [self stopAudio:nil];
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
    endingStream = NO;
    [self recordAudio:nil];
  });
}

- (void) processSampleData:(NSData *)data
{
  [self.audioData appendData:data];
#if NO
  NSInteger frameCount = [data length] / 2;
  int16_t *samples = (int16_t *) [data bytes];
  int64_t sum = 0;
  for (int i = 0; i < frameCount; i++) {
    sum += abs(samples[i]);
  }
  NSLog(@"audio %d %d", (int) frameCount, (int) (sum * 1.0 / frameCount));
#endif
  // We recommend sending samples in 100ms chunks
  int chunk_size = 0.1 /* seconds/chunk */ * SAMPLE_RATE * 2 /* bytes/sample */ ; /* bytes/chunk */

  /*
   * Streaming recognition fails silently after ~60 of continuous audio. This limit applies whether we are silent or speaking.
   * To use streaming recognition over a longer session, we take advantage of natural pauses in speech to split the
   * recognition task into discrete transactions. We rely on the API to detect these pauses and then automatically restart 
   * the recognition process to reset our 60 second budget.
   *
   * Each streaming recognition transaction proceeds roughly as follows:
   *
   * start sending audio samples
   *    no response during initial silence
   * start speaking (this sequence will repeat if speaker pauses briefly)
   *    endpointerType: START_OF_SPEECH
   *    live results (isFinal NO)
   *    endpointerType: END_OF_SPEECH
   * stop speaking (aka longer pause or stop speaking)
   *    final results (isFinal YES)
   * stop sending audio samples
   *    endpointerType: END_OF_AUDIO (sometimes repeated, sometimes arrives before isFinal response)
   * automatically start next transaction
   *
   */
  if ([self.audioData length] > chunk_size) {
    NSLog(@"SENDING");
    [[SpeechRecognitionService sharedInstance] streamAudioData:self.audioData
                                                withCompletion:^(StreamingRecognizeResponse *response, NSError *error) {
                                                  if (error) {
                                                    NSLog(@"ERROR: %@", error);
                                                    _textView.text = [error localizedDescription];
                                                    [self restart];
                                                  } else if (response) {
                                                    BOOL finished = NO;
                                                    NSLog(@"RESPONSE: %@", response);
                                                    if (response.hasError) {
                                                        if (endingTransaction == NO) {
                                                            [self restart];
                                                        }
                                                    } else if (response.endpointerType == StreamingRecognizeResponse_EndpointerType_StartOfSpeech) {
                                                      if (endingTransaction)
                                                        speechWhileEnding = YES;
                                                      _textView.text = nil;
                                                    } else if (response.endpointerType == StreamingRecognizeResponse_EndpointerType_EndOfSpeech) {
                                                      if (endingTransaction)
                                                        speechWhileEnding = YES;
                                                    } else if (response.endpointerType == StreamingRecognizeResponse_EndpointerType_EndOfAudio) {
                                                      if (endingTransaction) {
                                                        endingTransaction = NO;
                                                        NSLog(@"restarting audio");
                                                        [self recordAudio:nil];
                                                      }
                                                    } else {
                                                      for (StreamingRecognitionResult *result in response.resultsArray) {
                                                        if (result.isFinal) {
                                                          NSLog(@"isFinal");
                                                          finished = YES;
                                                          _textView.text = nil;
                                                        }
                                                      }
                                                    }
                                                    _textView.text = [NSString stringWithFormat:@"%@%@", _textView.text, [response description]];
                                                    if (finished) {
                                                      if (endingTransaction) {
                                                        NSLog(@"don't stop, endingTransaction");
                                                      } else if (speechWhileEnding) {
                                                        NSLog(@"don't stop, speechWhileEnding");
                                                      } else {
                                                        endingTransaction = YES;
                                                        NSLog(@"stopping audio");
                                                        [self stopAudio:nil];
                                                      }
                                                      speechWhileEnding = NO;
                                                    }
                                                  }
                                                }
     ];
    self.audioData = [[NSMutableData alloc] init];
  }
}

@end

