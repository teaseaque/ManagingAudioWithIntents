import Foundation
import AppIntents
import AVFoundation

struct PlayAppIntent: AudioStartingIntent {
  static var title: LocalizedStringResource = "Play"
  
  static var description: IntentDescription? = "AppIntent"
  
  @Parameter(title: "Sound")
  var sound: Bool

  @MainActor
  func perform() async throws -> some IntentResult {
    NotificationCenter.default.post(Notification(name: PlayerModel.notifName, object: sound))
    return .result()
  }
}
