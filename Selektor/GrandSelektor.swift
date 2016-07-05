//
//  GrandSelektor.swift
//  Selektor
//
//  Created by James Gray on 2016-07-05.
//  Copyright © 2016 James Gray. All rights reserved.
//

import Foundation
import Cocoa

class GrandSelektor: NSObject {

  let appDelegate = NSApplication.sharedApplication().delegate as! AppDelegate
  var algorithms: [String: (SongEntity) -> SongEntity] = [:]
  var algorithm: String = ""

  override init() {
    super.init()

    self.algorithms = [
      "random": self.selectRandomSong,
    ]
    self.algorithm = appDelegate.settings?["selektorAlgorithm"] as! String

  }

  func selectSong(song: SongEntity) -> SongEntity {
    if !self.algorithms.keys.contains(algorithm) {
      fatalError("Invalid selektorAlgorithm specified in Settings.plist")
    }

    return self.algorithms[algorithm]!(song)
  }

  func selectRandomSong(song: SongEntity) -> SongEntity {
    let index = Int(arc4random_uniform(UInt32(self.appDelegate.songs.count)))
    return self.appDelegate.songs[index]
  }
}