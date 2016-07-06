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
  var algorithms: [String: (TrackEntity, [TrackEntity]) -> TrackEntity] = [:]
  var algorithm: String = ""

  override init() {
    super.init()

    self.algorithms = [
      "dummy": self.selectTrackDummy,
    ]
    self.algorithm = appDelegate.settings?["selektorAlgorithm"] as! String

  }

  func selectTrack(currentTrack: TrackEntity) -> TrackEntity {
    let tracks = self.appDelegate.tracks.filter {
      $0.objectID != currentTrack.objectID && $0.analyzed == AnalysisState.Complete.rawValue
    }

    if tracks.count == 0 {
      // TODO: UI to show a useful error when there's only one track in the
      // library
      return currentTrack
    }

    if !self.algorithms.keys.contains(algorithm) {
      fatalError("Invalid selektorAlgorithm specified in Settings.plist")
    }

    return self.algorithms[algorithm]!(currentTrack, tracks)
  }

  func selectTrackDummy(currentTrack: TrackEntity, tracks: [TrackEntity]) -> TrackEntity {
    let index = Int(arc4random_uniform(UInt32(tracks.count)))
    return tracks[index]
  }
}
