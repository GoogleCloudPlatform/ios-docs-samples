# Cloud Speech Streaming gRPC Objective-C Sample

This app demonstrates how to make streaming gRPC connections to the [Cloud Speech API](https://cloud.google.com/speech/) to recognize speech in recorded audio.

## Continuous streaming

This fork demonstrates how to get real-time recognition results over an entire audio session as opposed to a single utterance. 

Streaming recognition fails silently after ~60 seconds of continuous audio, consistent with the [advertised limit](https://cloud.google.com/speech/limits). Once we start streaming, this time limit applies whether we are silent or speaking. To use streaming recognition over a longer audio session, we take advantage of natural pauses in speech to split the recognition task into discrete transactions. The UITextView retains the `isFinal` transcription response for the previous transaction, scroll it to see all of the returned alternatives. 

This demo relies on the Cloud Speech API to detect pauses in speech and automatically restarts the recognition process with each pause. This has a side effect of resetting the 60 second recognition budget. Locally detecting lack of speech would probably be a more effective approach, and could also be used to reduce the likelihood of missing words while in the (narrow) window between transactions. 

Continuous 16k LINEAR16 requires a stable uplink at 256kbps. If network conditions degrade, you may receive the following response with `response.hasError` set: 
```
{
    error {
      code: 11
      message: "Audio data is being streamed too slow. Please stream audio data approximately at real time."
    }
}
```
It appears that recognition does not proceed after this error, so we start a new transaction to recover from this and other error conditions. 

## Prerequisites
- An API key for the Cloud Speech API (See
  [the docs][getting-started] to learn more)
- An OSX machine or emulator
- [Xcode 7][xcode]
- [Cocoapods][cocoapods] version 1.0 or later

## Quickstart
- Clone this repo and `cd` into this directory.
- Run `pod install` to download and build Cocoapods dependencies.
- Open the project by running `open Speech.xcworkspace`.
- In `Speech/SpeechRecognitionService.m`, replace `YOUR_API_KEY` with the API key obtained above.
- Build and run the app.


## Running the app

- As with all Google Cloud APIs, every call to the Speech API must be associated
  with a project within the [Google Cloud Console][cloud-console] that has the
  Speech API enabled. This is described in more detail in the [getting started
  doc][getting-started], but in brief:
  - Create a project (or use an existing one) in the [Cloud
    Console][cloud-console]
  - [Enable billing][billing] and the [Speech API][enable-speech].
  - Create an [API key][api-key], and save this for later.

- Clone this repository on GitHub. If you have [`git`][git] installed, you can do this by executing the following command:

        $ git clone https://github.com/GoogleCloudPlatform/ios-docs-samples.git

    This will download the repository of samples into the directory
    `ios-docs-samples`.

- `cd` into this directory in the repository you just cloned, and run the command `pod install` to prepare all Cocoapods-related dependencies.

- `open Speech.xcworkspace` to open this project in Xcode. Since we are using Cocoapods, be sure to open the workspace and not Speech.xcodeproj.

- In Xcode's Project Navigator, open the `SpeechRecognitionService.m` file within the `Speech` directory.

- Find the line where the `API_KEY` is set. Replace the string value with the API key obtained from the Cloud console above. This key is the credential used to authenticate all requests to the Speech API. Calls to the API are thus associated with the project you created above, for access and billing purposes.

- You are now ready to build and run the project. In Xcode you can do this by clicking the 'Play' button in the top left. This will launch the app on the simulator or on the device you've selected. Be sure that the 'Speech' target is selected in the popup near the top left of the Xcode window. 

- Tap the `Start Streaming` button. This uses a custom AudioController class to capture audio in an in-memory instance of NSMutableData. When this data reaches a certain size, it is sent to the SpeechRecognitionService class, which streams it to the speech recognition service. Packets are streamed as instances of the RecognizeRequest object, and the first RecognizeRequest object sent also includes configuration information in an instance of InitialRecognizeRequest. As it runs, the AudioController logs the number of samples and average sample magnitude for each packet that it captures.

- Say a few words and wait for the display to update when your speech is recognized.

- Tap the `Stop Streaming` button to stop capturing audio and close your gRPC connection.

[vision-zip]: https://github.com/GoogleCloudPlatform/cloud-vision/archive/master.zip
[getting-started]: https://cloud.google.com/vision/docs/getting-started
[cloud-console]: https://console.cloud.google.com
[git]: https://git-scm.com/
[xcode]: https://developer.apple.com/xcode/
[billing]: https://console.cloud.google.com/billing?project=_
[enable-speech]: https://console.cloud.google.com/apis/api/speech.googleapis.com/overview?project=_
[api-key]: https://console.cloud.google.com/apis/credentials?project=_
[cocoapods]: https://cocoapods.org/
[gRPC Objective-C setup]: https://github.com/grpc/grpc/tree/master/src/objective-c

