# Cloud Speech to Speech Translation gRPC Swift Sample

This app demonstrates how to create a live translation service using the Cloud Speech-To-Text, Translation, and Text-To-Speech APIs. It uses these apis to:
* Make streaming gRPC connections to the [Cloud Speech API](https://cloud.google.com/speech/)` to recognize speech in recorded audio.
* Send transcripts to the [Translate API](https://cloud.google.com/translate/) to get the translation.
* Send translated text to the [Text-to-Speech API](https://cloud.google.com/text-to-speech/) so that it can be played back to the user.


To call the APIs from iOS, you need to provide authorization tokens with each request for authentication. To get this token, this sample uses a Firebase Function (in Node.js) to generate these tokens on the behalf of a service account.

## Prerequisites
- An OSX machine or emulator
- [Xcode 8 beta 6][xcode] or later
- [Cocoapods][cocoapods] version 1.0 or later

## Setup

- Create a project (or use an existing one) in the [Google Cloud Console][cloud-console]
- [Enable billing][billing] and the
    - [Speech API](https://console.cloud.google.com/apis/library/speech.googleapis.com).
    - [Translate API](https://console.cloud.google.com/apis/library/translate.googleapis.com).
    - [Text-to-Speech API](https://console.cloud.google.com/apis/library/texttospeech.googleapis.com).
    - [IAM Service Account Credentials API](https://console.cloud.google.com/apis/library/iamcredentials.googleapis.com).
- [Create a Service account](https://cloud.google.com/iam/docs/creating-managing-service-accounts) with the following IAM role: `Cloud Translation API User`. Example name: `translate-client`. ([For more info on: how to add roles to a Service Account](https://cloud.google.com/iam/docs/granting-roles-to-service-accounts#granting_access_to_a_service_account_for_a_resource))

###  Setup the app
- Clone this repository `git clone https://github.com/GoogleCloudPlatform/ios-docs-samples.git` 
- `cd ios-docs-samples/speech-to-speech/` 
- Run `./INSTALL-COCOAPODS` to install app dependencies (this can take few minutes to run). When it finishes, it will open the SpeechtoSpeech workspace in Xcode. Since we are using Cocoapods, be sure to open the `SpeechtoSpeech.xcworkspace` and not `SpeechtoSpeech.xcodeproj`.
- In Xcode's Project Navigator, open the `ApplicationConstants.swift` file within the `SpeechtoSpeech` directory.
- Find the line where the `translateParent` is set. Replace the `project_id` string with the identifier for your Google Cloud Project..
- Go to the project editor for your target and then click on the Capabilities tab. Look for Push Notifications and toggle its value to ON

###  Setup Firebase on the application:

- Complete the steps for [Add Firebase to your app](https://firebase.google.com/docs/ios/setup#add_firebase_to_your_app) and expand the "Create a Firebase project" section for instructions on how to add project to your Firebase console. Note: No need to complete any other sections, they are already done. 
- Use `iOS bundle ID` which has push notifications enabled and select your development team in 'General->Signing' before building the application in an iOS device.
    Note: as we were going to get the token in notifications, Please run the sample in iOS device instead of running it in the simulator. 
- Complete the steps to [Configuring APNs with FCM](https://firebase.google.com/docs/cloud-messaging/ios/certs).
- In the [Firebase console](https://console.firebase.google.com/), open the "Authentication" section under Develop.
- On the **Sign-in Methods** page, enable the **Anonymous** sign-in method.

###  Setup and Deploy the Firebase Function 

The Firebase Function provides auth tokens to your app, You'll be using a provided sample function to be run with this app.

- Follow the steps in this [guide](https://firebase.google.com/docs/functions/get-started) for: 
- 1. Set up Node.js and the Firebase CLI
- 2. Initialize Firebase SDK for Cloud Functions.
- Replace `index.js` file with the [provided index.js](https://github.com/GoogleCloudPlatform/nodejs-docs-samples/blob/master/functions/tokenservice/functions/index.js).
- Replace scope in line 79 with `scope: ['https://www.googleapis.com/auth/cloud-platform'],`
- Open `index.js`, go to function "generateAccessToken", and replace “SERVICE-ACCOUNT-NAME@YOUR_PROJECT_ID.iam.gserviceaccount.com” with your Service account name (`translate-client`) and project id. 
- Deploy getOAuthToken method by running command:
```
firebase deploy -—only functions
```
- In IAM section for your "App Engine Default Service Account" add the following IAM role: `Service Account Token Creator` . ([For more info on: how to add roles to a Service Account](https://cloud.google.com/iam/docs/granting-roles-to-service-accounts#granting_access_to_a_service_account_for_a_resource))

- For more info please refer (https://firebase.google.com/docs/functions/get-started).



## Run the app

- You are now ready to build and run the project. In Xcode you can do this by clicking the 'Play' button in the top left. This will launch the app on the simulator or on the device you've selected. Be sure that the 'SpeechtoSpeech' target is selected in the popup near the top left of the Xcode window.
- The first screen sets up the translation service by configuring the language to translate from and to, along with the voice type.
- After choosing the available options, and taping on the GetStarted button, you will be navigated to the next screen.
- Tapping on the mic button will began streaming audio data for the translation.
- This uses a custom AudioController class to capture audio in an in-memory instance of NSMutableData. When this data reaches a certain size, it is sent to the SpeechRecognitionService class, which streams it to the speech recognition service. Packets are streamed as instances of the RecognizeRequest object, and the first RecognizeRequest object sent also includes configuration information in an instance of InitialRecognizeRequest. As it runs, the AudioController logs the number of samples and average sample magnitude for each packet that it captures.
- Your spoken transcript will appear on the right side.
- Translated output will be at the left side.
- Translated output audio will be played in the background.
- You can change the options at any time by going back to the first screen. (There is back button on the top left corner of second screen)
- The chosen options will be passed to the input/request parameters of api calls.
- The chosen options will be stored in the user defaults for subsequent visits, and the fields will be repopulated.
- Say a few words and wait for the display to update when your speech is recognized.

- Tap the `Close` button to stop capturing audio and close your gRPC connection.

[cloud-console]: https://console.cloud.google.com
[git]: https://git-scm.com/
[xcode]: https://developer.apple.com/xcode/
[billing]: https://console.cloud.google.com/billing?project=_
[cocoapods]: https://cocoapods.org/
[gRPC Objective-C setup]: https://github.com/grpc/grpc/tree/master/src/objective-c
[Firebase]: https://firebase.google.com/

