import UIKit
import Intents
import AVFoundation

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
  var player: AVAudioPlayer?
    
  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    return true
  }
    
  func application(_ application: UIApplication, handle intent: INIntent, completionHandler: @escaping (INIntentResponse) -> Void) {
    
    guard let url = Bundle.main.url(forResource: "ThankYou", withExtension: "mp3") else {
      print("appDel URL fail")
      return
    }

    do {
      try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
      try AVAudioSession.sharedInstance().setActive(true)
      player = try AVAudioPlayer(contentsOf: url, fileTypeHint: AVFileType.mp3.rawValue)
      player!.play()
    } catch let error as NSError {
      print("play error ", error.localizedDescription)
    }
    
    completionHandler(INPlayMediaIntentResponse(code: .success, userActivity: nil))
  }
}
