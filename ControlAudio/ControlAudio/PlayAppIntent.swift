import Foundation
import AppIntents
import AVFoundation

struct PlayAppIntent: AudioStartingIntent {
  static var title: LocalizedStringResource = "Play"
  
  static var description: IntentDescription? = "AppIntent"

  @MainActor
  func perform() async throws -> some IntentResult {
    let url = Bundle.main.url(forResource: "ThankYou", withExtension: "mp3")!

    do {
      try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
      try AVAudioSession.sharedInstance().setActive(true)

      let player = try AVAudioPlayer(contentsOf: url, fileTypeHint: AVFileType.mp3.rawValue)
      player.play()
      print("So-called \"Played\"")

    } catch let error {
      print("playback error:", error.localizedDescription)
    }

    return .result()
  }
}
