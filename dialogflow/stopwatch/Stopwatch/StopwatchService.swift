//
// Copyright 2017 Google Inc. All Rights Reserved.
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
import Foundation
import googleapis
import AuthLibrary
import Firebase

typealias StopwatchCompletionHandler =
  (DFStreamingDetectIntentResponse?, NSError?) -> (Void)

typealias StopwatchTextCompletionHandler = (DFDetectIntentResponse?, NSError?) -> (Void)

enum StopwatchServiceError: Error {
  case unknownError
  case invalidCredentials
  case tokenNotAvailable
}

protocol StopwatchServiceProtocol {
  func didReceiveTextResponse(response: DFDetectIntentResponse?, error: NSError?)
  func didReceiveAudioInputResponse(response: DFStreamingDetectIntentResponse?, error: NSError?)
}

class StopwatchService {
  var sampleRate: Int = ApplicationConstants.SampleRate
  private var streaming = false
  private var client : DFSessions!
  private var writer : GRXBufferedPipe!
  private var call : GRPCProtoCall!
  var userInputText: String? = "Hello"
  var delegate: StopwatchServiceProtocol?
  var authToken: String = ""

  private var session : String {
    return "projects/" + ApplicationConstants.ProjectName + "/agent/sessions/" + ApplicationConstants.SessionID
  }
  
  static let sharedInstance = StopwatchService()
  
  func getDeviceID(callBack: @escaping (String)->Void) {
    InstanceID.instanceID().instanceID { (result, error) in
      if let error = error {
        print("Error fetching remote instance ID: \(error)")
        callBack( "")
      } else if let result = result {
        print("Remove instance ID token: \(result.token)")
        callBack( result.token)
      } else {
        callBack( "")
      }
    }
  }

  func streamAudioData(_ audioData: NSData, completion: @escaping StopwatchCompletionHandler) {
    // authenticate using an authorization token (obtained using OAuth)
    if (!self.streaming) {
      // if we aren't already streaming, set up a gRPC connection
      self.client = DFSessions(host:ApplicationConstants.Host)
      self.writer = GRXBufferedPipe()
      self.call = self.client.rpcToStreamingDetectIntent(
        withRequestsWriter: self.writer,
        eventHandler: { (done, response, error) in
          completion(response, error as NSError?)
      })
      self.call.requestHeaders.setObject(NSString(string:authToken),

                                         forKey:NSString(string:"Authorization"))
      self.call.start()
      self.streaming = true
      // send an initial request message to configure the service
      let queryInput = DFQueryInput()
      let inputAudioConfig = DFInputAudioConfig()
      inputAudioConfig.audioEncoding = DFAudioEncoding(rawValue:1)!
      inputAudioConfig.languageCode = ApplicationConstants.languageCode
      inputAudioConfig.sampleRateHertz = Int32(self.sampleRate)
      queryInput.audioConfig = inputAudioConfig
      let streamingDetectIntentRequest = DFStreamingDetectIntentRequest()
      streamingDetectIntentRequest.session = self.session
      streamingDetectIntentRequest.singleUtterance = true
      streamingDetectIntentRequest.queryParams = self.getQueryParmasFor()
      streamingDetectIntentRequest.queryInput = queryInput
      streamingDetectIntentRequest.outputAudioConfig = self.getOutputAudioConfig()
      self.writer.writeValue(streamingDetectIntentRequest)
    }
    // send a request message containing the audio data
    let streamingDetectIntentRequest = DFStreamingDetectIntentRequest()
    streamingDetectIntentRequest.inputAudio = audioData as Data
    self.writer.writeValue(streamingDetectIntentRequest)
  }

  func getQueryParamsForAudionWithoutKnowledge() -> DFQueryParameters {
    let queryParams = DFQueryParameters()
    let defaults = UserDefaults.standard
    if let defaultItems = defaults.value(forKey: ApplicationConstants.selectedMenuItems) as? [Int],
      defaultItems.count > 0 {
      let sentimentSelected =
        defaultItems.contains(BetaFeatureMenu.sentimentAnalysis.rawValue)
      queryParams.sentimentAnalysisRequestConfig = getSentimentAnalysisConfig(sentimentSelected: sentimentSelected)
    }
    return queryParams
  }

  @objc func sendText() {
    getDeviceID { (deviceID) in
      // authenticate using an authorization token (obtained using OAuth)
      FCMTokenProvider.getToken(deviceID: deviceID) { (shouldWait, token, error) in
        if let authT = token,shouldWait == false {
          self.client = DFSessions(host:ApplicationConstants.Host)
          let queryInput = DFQueryInput()
          let inputTextConfig = DFTextInput()
          inputTextConfig.text = self.userInputText ?? ""
          inputTextConfig.languageCode = ApplicationConstants.languageCode
          queryInput.text = inputTextConfig
          let detectIntentRequest = DFDetectIntentRequest()
          detectIntentRequest.session = self.session
          detectIntentRequest.queryInput = queryInput
          detectIntentRequest.outputAudioConfig = self.getOutputAudioConfig()
          detectIntentRequest.queryParams = self.getQueryParmasFor()
          self.call = self.client.rpcToDetectIntent(with: detectIntentRequest, handler: { (response, error) in
            self.delegate?.didReceiveTextResponse(response: response, error: error as NSError?)
          })
          self.call.requestHeaders.setObject(NSString(string:authT),
                                             forKeyedSubscript:NSString(string:"Authorization"))
          self.call.start()
          //Remove notification
          NotificationCenter.default.removeObserver(self, name: NSNotification.Name(ApplicationConstants.tokenReceived), object: nil)
        } else if shouldWait == true { //Token will be sent via PN
          //Observe for notification
          NotificationCenter.default.addObserver(self, selector: #selector(self.sendText), name: NSNotification.Name(ApplicationConstants.tokenReceived), object: nil)
        } else { //an error occured
          //Handle error
        }
      }
    }

  }

  func getOutputAudioConfig() -> DFOutputAudioConfig? {
    let defaults = UserDefaults.standard
    if let defaultItems = defaults.value(forKey: ApplicationConstants.selectedMenuItems) as? [Int],
      defaultItems.count > 0 {
      if defaultItems.contains(BetaFeatureMenu.textToSpeech.rawValue) {
        let outputAudioConfig = DFOutputAudioConfig()
        outputAudioConfig.audioEncoding = DFOutputAudioEncoding(rawValue:2)!
        outputAudioConfig.sampleRateHertz = Int32(sampleRate)
        return outputAudioConfig
      }
    }
    return nil
  }
  
  func getSentimentAnalysisConfig(sentimentSelected: Bool) -> DFSentimentAnalysisRequestConfig {
    let sentimentConfig = DFSentimentAnalysisRequestConfig()
    sentimentConfig.analyzeQueryTextSentiment = sentimentSelected
    return sentimentConfig
  }
  
  func getQueryParmasFor() -> DFQueryParameters {
    let queryParams = DFQueryParameters()
    let defaults = UserDefaults.standard
    if let defaultItems = defaults.value(forKey: ApplicationConstants.selectedMenuItems) as? [Int],
      defaultItems.count > 0 {
      let sentimentSelected =
        defaultItems.contains(BetaFeatureMenu.sentimentAnalysis.rawValue)
      queryParams.sentimentAnalysisRequestConfig = getSentimentAnalysisConfig(sentimentSelected: sentimentSelected)
      
      if defaultItems.contains(BetaFeatureMenu.knowledgeConnector.rawValue) {
        if let knowledgeBasePath = UserDefaults.standard.value(forKey: "knowledgeBasePath") as? String {
          queryParams.knowledgeBaseNamesArray = [knowledgeBasePath]
        }
      }
    }else {
      queryParams.sentimentAnalysisRequestConfig = getSentimentAnalysisConfig(sentimentSelected: false)
    }
    return queryParams
  }
  
  @objc func getKnowledgeBasePath(handler: @escaping (_ KnowledgeBasePath: String) -> Void) {
    getDeviceID { (deviceID) in
      // authenticate using an authorization token (obtained using OAuth)
      FCMTokenProvider.getToken(deviceID: deviceID) { (shouldWait, token, error) in
        if let authT = token, shouldWait == false { //Token received execute code
          let knowledgeBase = DFKnowledgeBases(host: ApplicationConstants.Host)
          let request = DFListKnowledgeBasesRequest()
          request.parent = "projects/\(ApplicationConstants.ProjectName)/agent"
          let call = knowledgeBase.rpcToListKnowledgeBases(with: request, handler: {(knowledgeBaseRes, error) in
            if let error = error {
              print("Error occured while calling knowledge base api \(error.localizedDescription)")
              return
            }
            if let res = knowledgeBaseRes,
              res.knowledgeBasesArray_Count > 0,
              let lastKB = res.knowledgeBasesArray.lastObject as? DFKnowledgeBase,
              let knowledgeBasePath = lastKB.name {
              print("Source response for knowledge base: \(res)")
              print("Found path:\(knowledgeBasePath)")
              handler(knowledgeBasePath)
            }
          })
          call.requestHeaders.setObject(NSString(string:authT),
                                        forKey:NSString(string:"Authorization"))
          call.start()
          //Remove notification
          NotificationCenter.default.removeObserver(self, name: NSNotification.Name(ApplicationConstants.tokenReceived), object: nil)
        } else if shouldWait == true { //Token will be sent via PN
          //Observe for notification
          NotificationCenter.default.addObserver(self, selector: #selector(self.getKnowledgeBasePath(handler:)), name: NSNotification.Name(ApplicationConstants.tokenReceived), object: handler)
        } else { //an error occured
          //Handle error
        }
      }
    }
  }
  
  func stopStreaming() {
    if (!streaming) {
      return
    }
    writer.finishWithError(nil)
    streaming = false
  }
  
  func isStreaming() -> Bool {
    return streaming
  }
}


