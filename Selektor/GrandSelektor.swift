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
  var algorithms: [String: (SongEntity, [SongEntity]) -> SongEntity] = [:]
  var algorithm: String = ""

  override init() {
    super.init()

    self.algorithms = [
      "dummy": self.selectSongDummy,
    ]
    self.algorithm = appDelegate.settings?["selektorAlgorithm"] as! String

  }

  func selectSong(currentSong: SongEntity) -> SongEntity {
    let songs = self.appDelegate.songs.filter {
      $0.objectID != currentSong.objectID && $0.analyzed == AnalysisState.Complete.rawValue
    }

    if songs.count == 0 {
      // TODO: UI to show a useful error when there's only one song in the
      // library
      return currentSong
    }

    if !self.algorithms.keys.contains(algorithm) {
      fatalError("Invalid selektorAlgorithm specified in Settings.plist")
    }

    return self.algorithms[algorithm]!(currentSong, songs)
  }

  func selectSongDummy(currentSong: SongEntity, songs: [SongEntity]) -> SongEntity {
    let index = Int(arc4random_uniform(UInt32(songs.count)))
    return songs[index]
  }
}