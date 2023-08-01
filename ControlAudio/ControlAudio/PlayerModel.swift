//
//  PlayerModel.swift
//  ControlAudio
//
//  Created by Tom Kane on 8/1/23.
//  Copyright © 2023 Apple. All rights reserved.
//

import SwiftUI
import AVFoundation

class PlayerModel: ObservableObject {
  @Published var mainPlayer: AVAudioPlayer?
  
  static let notifName = Notification.Name("play")
  
  init() {
    NotificationCenter.default.addObserver(self, selector: #selector(playSound), name: Self.notifName, object: nil)
  }
  
  @objc func playSound(_ notification: Notification) {
    guard let sound = notification.object as? Bool else { return }
    
    let fileName = sound ? "ThankYou" : "sample"
    guard let fileURL = Bundle.main.url(forResource: fileName, withExtension: "mp3") else {
      print("URL fail")
      return
    }
    
    do {
      mainPlayer = try AVAudioPlayer(contentsOf: fileURL)
    }
    catch let error as NSError {
      print("play AVAudioPlayer error", error.localizedDescription, "fileURL:", fileURL)
    }
    
    do {
      try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
    }
    catch let error as NSError {
      print("play setCategory error", error.localizedDescription)
    }
    
    DispatchQueue.main.async {
      self.mainPlayer?.prepareToPlay()
      self.mainPlayer?.play()
    }
  }
}
