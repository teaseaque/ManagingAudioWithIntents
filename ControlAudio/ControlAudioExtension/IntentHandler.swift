import Intents
import IntentsUI
import MediaPlayer

class IntentHandler: INExtension, INPlayMediaIntentHandling {
  func resolveMediaItems(for intent: INPlayMediaIntent, with completion: @escaping ([INPlayMediaMediaItemResolutionResult]) -> Void) {
    let mi = INMediaItem(identifier: "siriIntent", title: "siriIntent", type: .song, artwork: nil)
          completion(INPlayMediaMediaItemResolutionResult.successes(with: [mi]))
  }
  
  func handle(intent: INPlayMediaIntent, completion: (INPlayMediaIntentResponse) -> Void) {
      completion(INPlayMediaIntentResponse(code: .handleInApp, userActivity: nil))
  }
}
