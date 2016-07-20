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
      "rankedBPM": self.selectTrackRankedBPM,
      "medianBPM": self.selectTrackMedianBPM,
      "rankedLoudness": self.selectTrackRankedLoudness,
      //"medianLoudness": self.selectTrackMedianLoudness,
      //"rankedKey": self.selectTrackRankedKey,
      //"medianKey": self.selectTrackMedianKey,
    ]
    self.algorithm = appDelegate.settings?["selektorAlgorithm"] as! String
  }

  /**
      Given the current track, return a subset of tracks that are similar in BPM
      to the current track's tempo, with a range of ± 3 BPM.

      If no other tracks within the range of ± 3 BPM are available, increment
      the considered BPM range by 3 repeatedly until more tracks are found.
  */
  func findTracksWithSimilarBPM(toTrack currentTrack: TrackEntity, inSet tracks: [TrackEntity]) -> [TrackEntity] {
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

    return tracksSubset
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
      to the current track. Timbre similarity is calculated by computing the
      Euclidean distance between the tracks' timbre vectors.

      - parameter currentTrack: The track that is currently playing.
      - parameter tracks: An array of `TrackEntity`s to choose from.

      - returns: The recommended track as deduced by the algorithm.
  */
  func selectTrackRankedBPM(currentTrack: TrackEntity, tracks: [TrackEntity]) -> TrackEntity {
    let trackSubset = findTracksWithSimilarBPM(toTrack: currentTrack, inSet: tracks)

    var minDistance = DBL_MAX
    var timbreDistance = 0.0
    var selectedTrack: TrackEntity? = nil

    for track in trackSubset {
      timbreDistance = currentTrack.compareTimbreWith(otherTrack: track)
      if timbreDistance < minDistance {
        minDistance = timbreDistance
        selectedTrack = track
      }
    }

    return selectedTrack!
  }

  /**
      Selects a track within ± 3 BPM (if possible) whose timbre distance is
      closest to the median distance of all tracks to the current track.

      - parameter currentTrack: The track that is currently playing.
      - parameter tracks: An array of `TrackEntity`s to choose from.

      - returns: The recommended track as deduced by the algorithm.
  */
  func selectTrackMedianBPM(currentTrack: TrackEntity, tracks: [TrackEntity]) -> TrackEntity {
    let trackSubset = findTracksWithSimilarBPM(toTrack: currentTrack, inSet: tracks)

    // Compute the median distance
    let distances = trackSubset.map { currentTrack.compareTimbreWith(otherTrack: $0) }
    let medianDistance = distances.sort()[distances.count / 2]

    // Compare the distances of each track from the current track to the median distance
    let deviationsFromMedianDistance = distances.map { fabs(medianDistance - $0) }

    var minDeviation = DBL_MAX
    var selectedIndex = -1

    // Find the index of the track with the closest timbre distance to the
    // median.
    for (index, deviation) in deviationsFromMedianDistance.enumerate() {
      if deviation < minDeviation {
        minDeviation = deviation
        selectedIndex = index
      }
    }

    return trackSubset[selectedIndex]
  }

  /**
      Selects a track within ± 3 BPM (if possible) of the current track's tempo,
      with the most similar timbre and loudness to the current track. Timbre
      similarity is calculated by computing the Euclidean distance between the
      tracks' timbre vectors, while loudness similarity is calculated by simply
      subtracting the tracks' loudness values and taking the absolute value.

      The distance values for timbre and loudness are added together for each
      track, and the track with the shortest combined distance is chosen as the
      suggested track.

      - parameter currentTrack: The track that is currently playing.
      - parameter tracks: An array of `TrackEntity`s to choose from.

      - returns: The recommended track as deduced by the algorithm.
  */
  func selectTrackRankedLoudness(currentTrack: TrackEntity, tracks: [TrackEntity]) -> TrackEntity {
    let trackSubset = findTracksWithSimilarBPM(toTrack: currentTrack, inSet: tracks)

    var minDistance = DBL_MAX
    var timbreDistance = 0.0, loudnessDistance = 0.0, totalTrackDistance = 0.0
    var selectedTrack: TrackEntity? = nil

    for track in trackSubset {
      timbreDistance = currentTrack.compareTimbreWith(otherTrack: track)
      loudnessDistance = fabs(Double(currentTrack.loudness!) - Double(track.loudness!))
      totalTrackDistance = timbreDistance + loudnessDistance

      if totalTrackDistance < minDistance {
        minDistance = totalTrackDistance
        selectedTrack = track
      }
    }

    return selectedTrack!
  }
}