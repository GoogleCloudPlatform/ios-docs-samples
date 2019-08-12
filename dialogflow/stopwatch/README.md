# Dialogflow Sample

This app demonstrates how to make gRPC connections to the [Dialogflow API](https://cloud.google.com/dialogflow-enterprise/)

The app demonstrates how to detect intents:
- Via Text
- Via Streaming Audio
- With Sentiment Analysis
- With Text-to-Speech
- With Knowledge Connectors

To call the Dialogflow API from iOS, you need to provide authorization tokens with each request for them to be accepted by the Dialogflow API. To get this token, this sample uses a Firebase Function (in Node.js) to generate these tokens on the behalf of a service account to be used by the app when making a request to the Dialogflow API.

## Prerequisites
- An OSX machine or simulator
- [Xcode 9.1][xcode] or later
- [Cocoapods][cocoapods] version 1.0 or later

## Setup
- Create a project (or use an existing one) in the [Google Cloud Console][cloud-console]
- Enable the [Dialogflow API](https://console.cloud.google.com/apis/library/dialogflow.googleapis.com).
- Enable the [IAM Service Account Credentials API](https://pantheon.corp.google.com/apis/library/iamcredentials.googleapis.com).
- [Enable billing][billing].
- Be sure that you have gone through the steps by expanding the [Create an agent](https://cloud.google.com/dialogflow-enterprise/docs/quickstart-console#create-an-agent) to create and configure your stopwatch agent.
- [Import the Dialogflow Agent](https://dialogflow.com/docs/agents/export-import-restore#import) using the `StopwatchAgent.zip` which is located in the `stopwatch` directory. 
- [Create a Service account](https://cloud.google.com/iam/docs/creating-managing-service-accounts) with the following IAM roles: `Dialogflow API Client` and `Dialogflow API Reader` Example name: `dialogflow-client`. ([For more info on: how to add roles to a Service Account](https://cloud.google.com/iam/docs/granting-roles-to-service-accounts#granting_access_to_a_service_account_for_a_resource))
- Enable beta features for:
  - [Sentiment Analysis](https://cloud.google.com/dialogflow-enterprise/docs/sentiment#enable_beta_features)
  - [Text-to-Speech](https://cloud.google.com/dialogflow-enterprise/docs/detect-intent-tts#enable_beta_features)
  - [Knowledge Connectors](https://cloud.google.com/dialogflow-enterprise/docs/knowledge-connectors#enable_beta_features)


### Setup the app
- Clone this repository `git clone https://github.com/GoogleCloudPlatform/ios-docs-samples.git` 
- `cd ios-docs-samples/dialogflow/stopwatch/` 
- Run `./INSTALL-COCOAPODS` to install app dependencies (this can take a long time to run). When it finishes, it will open the Stopwatch workspace in Xcode. Since we are using Cocoapods, be sure to open the `Stopwatch.xcworkspace` and not `Stopwatch.xcodeproj`.
- Replace `your-project-identifier` in `ApplicationConstants.swift` with the identifier of your Google Cloud project.
- Go to the project editor for your target and then click on the Capabilities tab. Look for Push Notifications and toggle its value to ON

###  Setup Firebase on the application:

- Complete the steps for [Add Firebase to your app](https://firebase.google.com/docs/ios/setup#add_firebase_to_your_app) and expand the "Create a Firebase project" section for instructions on how to add project to your Firebase console. Note: No need to complete any other sections, they are already done. 
- Complete the steps to [Configuring APNs with FCM](https://firebase.google.com/docs/cloud-messaging/ios/certs).
- Use `iOS bundle ID` which has push notifications enabled and select your development team in 'General->Signing' before building the application in an iOS device.
    Note: as we were going to get the token in notifications, Please run the sample in iOS device instead of running it in the simulator. 
- In the [Firebase console](https://console.firebase.google.com/), open the "Authentication" section under Develop.
- On the **Sign-in Methods** page, enable the **Anonymous** sign-in method.

###  Setup and Deploy the Firebase Function 
The Firebase Function provides auth tokens to your app, You'll be using a provided sample function to be run with this app.

- Follow the steps in this [guide](https://firebase.google.com/docs/functions/get-started) for: 
  - "1. Set up Node.js and the Firebase CLI"
  - "2. Initialize Firebase SDK for Cloud Functions". 
- Replace `index.js` file with the [provided index.js](https://github.com/GoogleCloudPlatform/nodejs-docs-samples/blob/master/functions/tokenservice/functions/index.js).
- Open `index.js`, go to function "generateAccessToken", and replace “SERVICE-ACCOUNT-NAME@YOUR_PROJECT_ID.iam.gserviceaccount.com” with your Service account name (`dialogflow-client`) and project id. 
- Deploy getOAuthToken method by running command:
```
firebase deploy -—only functions
```
- For your "App Engine Default Service Account" add the following IAM role: `Service Account Token Creator` . ([For more info on: how to add roles to a Service Account](https://cloud.google.com/iam/docs/granting-roles-to-service-accounts#granting_access_to_a_service_account_for_a_resource))

- For more info please refer (https://firebase.google.com/docs/functions/get-started).


## Run the app
- You are now ready to build and run the project. In Xcode you can do this by clicking the 'Play' button in the top left. This will launch the app on the simulator or on the device you've selected. Be sure that the 'Stopwatch' target is selected in the popup near the top left of the Xcode window. 
- Tap the `Mic` button. This uses a custom AudioController class to capture audio in an in-memory instance of NSMutableData. When this data reaches a certain size, it is sent to the StopwatchService class, which streams it to the Dialogflow API. Packets are streamed as instances of the DFStreamingDetectIntentRequest object. The first DFStreamingDetectIntentRequest object sent includes configuration information and subsequent DFStreamingDetectIntentRequest objects contain audio packets. 
- Say a few words and wait for the display to update when your speech is recognized.
- Tap the 'close' button to stop capturing audio, or if audio capture has stopped because your speech was recognized, tap it again to start a new listening session.


[cloud-console]: https://console.cloud.google.com
[git]: https://git-scm.com/
[xcode]: https://developer.apple.com/xcode/
[billing]: https://console.cloud.google.com/billing?project=_
[cocoapods]: https://cocoapods.org/
[Firebase]: https://firebase.google.com/

