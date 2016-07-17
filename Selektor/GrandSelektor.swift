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
      "plusMinus3": self.selectTrackPlusMinus3,
    ]
    self.algorithm = appDelegate.settings?["selektorAlgorithm"] as! String
  }

  /**
      Find the track whose timbre is most similar to the current track's timbre
      based on the Euclidean distance between timbre vectors.

      - parameter currentTrack: The `TrackEntity` to compare against.
      - parameter inTrackArray: The array of tracks to be compared.

      - returns: The `TrackEntity` that is most similar to `currentTrack`.
  */
  func findTrackWithTimbreClosestTo(currentTrack currentTrack: TrackEntity, inTrackArray tracks: [TrackEntity]) -> TrackEntity {
    var minDistance = DBL_MAX
    var timbreDistance = 0.0
    var mostSimilarTrack: TrackEntity? = nil

    for track in tracks {
      timbreDistance = currentTrack.timbreVector64.calculateDistanceFrom(otherVector: track.timbreVector64)
      if timbreDistance < minDistance {
        minDistance = timbreDistance
        mostSimilarTrack = track
      }
    }

    return mostSimilarTrack!
  }

  /**
      Select the best next track to play based on the currently playing track.

      - parameter currentTrack: The `TrackEntity` the user is currently playing.

      - returns: A `TrackEntity` that the application suggests the user plays next.
  */
  func selectTrack(currentTrack: TrackEntity) -> TrackEntity {
    // Filter out un-analyzed tracks
    var tracks = self.appDelegate.tracks.filter {
      $0.objectID != currentTrack.objectID
      && $0.analyzed == AnalysisState.complete.rawValue
    }

    // Filter out tracks the user has already played
    tracks = tracks.filter {
      $0.played == false
    }

    // Mark the current track as played
    currentTrack.played = true

    if tracks.count == 0 {
      // TODO: UI to show a useful error when there's only one track in the
      // library
      return currentTrack
    }

    // Ensure the algorithm specified in Settings.plist is actually implemented
    if !self.algorithms.keys.contains(algorithm) {
      fatalError("Invalid selektorAlgorithm specified in Settings.plist")
    }

    // Get the selection function which implements the specified algorithm and
    // use it to determine the best next track
    let selekt = self.algorithms[algorithm]!
    return selekt(currentTrack, tracks)
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

  /**
      Selects a track within ± 3 BPM (if possible) with the most similar timbre
      to the current track. If no other tracks within the range of ± 3 BPM are
      available, increment the considered BPM range by 3 repeatedly until more
      tracks are found.

      - parameter currentTrack: The track that is currently playing.
      - parameter tracks: An array of `TrackEntity`s to choose from.

      - returns: The recommended track as deduced by the algorithm.
  */
  func selectTrackPlusMinus3(currentTrack: TrackEntity, tracks: [TrackEntity]) -> TrackEntity {
    var bpmOffset = 0
    let currentTempo = currentTrack.tempo as! Int
    var tracksSubset = [TrackEntity]()

    // Filter considered tracks to tracks with tempo within ± 3 BPM of the current
    // track's tempo, increasing the range if no tracks are found
    while tracksSubset.count == 0 {
      bpmOffset += 3
      tracksSubset = tracks.filter {
        ($0.tempo as! Int) <= currentTempo + bpmOffset
        && ($0.tempo as! Int) >= currentTempo - bpmOffset
      }
    }

    return findTrackWithTimbreClosestTo(currentTrack: currentTrack, inTrackArray: tracksSubset)
  }
}