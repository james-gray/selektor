//
//  GrandSelektor.swift
//  Selektor
//
//  Created by James Gray on 2016-07-05.
//  Copyright © 2016 James Gray. All rights reserved.
//

import Foundation
import Cocoa

/**
    The meat and potatoes of the Selektor application. This class contains a method
    to select the best next track given a currently playing track, and provides
    multiple implementations of selection algorithms, with the algorithm to be used
    specified in Settings.plist.
*/
class GrandSelektor: NSObject {

  /// Convenience property reference to the application delegate
  let appDelegate = NSApplication.sharedApplication().delegate as! AppDelegate

  /**
      Mapping of algorithm strings as can be specified in Settings.plist to the
      selection functions.
  */
  var algorithms: [String: (TrackEntity, [TrackEntity]) -> TrackEntity] = [:]

  /// The algorithm to be used.
  var algorithm: String = ""

  /**
      Set up the GrandSelektor instance, configuring the algorithms as necessary.
  */
  override init() {
    super.init()

    self.algorithms = [
      "dummy": self.selectTrackDummy,
    ]
    self.algorithm = appDelegate.settings?["selektorAlgorithm"] as! String
  }

  /**
      Select the best next track to play based on the currently playing track.

      - parameter currentTrack: The `TrackEntity` the user is currently playing.

      - returns: A `TrackEntity` that the application suggests the user plays next.
  */
  func selectTrack(currentTrack: TrackEntity) -> TrackEntity {
    let tracks = self.appDelegate.tracks.filter {
      $0.objectID != currentTrack.objectID
      && $0.analyzed == AnalysisState.complete.rawValue
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

  /**
      Dummy selection algorithm which simply picks another track at random.
  
      - parameter currentTrack: The track that is currently playing.
      - parameter tracks: An array of `TrackEntity`s to choose from.
  
      - returns: A random track.
  */
  func selectTrackDummy(currentTrack: TrackEntity, tracks: [TrackEntity]) -> TrackEntity {
    let index = Int(arc4random_uniform(UInt32(tracks.count)))
    return tracks[index]
  }
}