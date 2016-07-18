//
//  TrackEntity.swift
//  Selektor
//
//  Created by James Gray on 2016-05-28.
//  Copyright © 2016 James Gray. All rights reserved.
//

import CoreData

/**
    Enumeration to track the state of each track's feature analysis.
*/
enum AnalysisState: Int {
  case toDo = 0
  case inProgress
  case complete
}

/**
    The core `TrackEntity` represents a single Track's state, with properties
    representing track metadata, as well as functionality to analyze the track's
    timbre and tempo in beats per minute.
*/
@objc(TrackEntity)
class TrackEntity: SelektorObject {
  override class func getEntityName() -> String {
    return "Track"
  }

  let extractor = FeatureExtractor()

  // MARK: Properties

  @NSManaged dynamic var analyzed: NSNumber
  @NSManaged dynamic var duration: NSNumber?
  @NSManaged dynamic var filename: String?
  @NSManaged dynamic var loudness: NSNumber?
  @NSManaged dynamic var tempo: NSNumber?
  @NSManaged dynamic var album: String?
  @NSManaged dynamic var artist: String?
  @NSManaged dynamic var genre: String?
  @NSManaged dynamic var key: String?
  @NSManaged dynamic var played: NSNumber?
  @NSManaged dynamic var timbreVectors: NSSet?

  // MARK: Convenience properties

  let tempDirectory = NSURL(fileURLWithPath: NSTemporaryDirectory() as String)

  dynamic var relativeFilename: String? {
    return NSURL(fileURLWithPath: self.filename!).lastPathComponent ?? nil
  }

  /**
      Returns a 64-dimensional array vector consisting of the track's four timbre
      vectors concatenated, consistent with the format returned by the `mirex_extract`
      feature extraction executable.
  */
  dynamic var timbreVector64: [Double] {
    get {
      if self.analyzed != AnalysisState.complete.rawValue {
        return [Double](count: 64, repeatedValue: 0.0)
      }

      var vector: [Double] = []
      vector += self.mammTimbre!.vector
      vector += self.masmTimbre!.vector
      vector += self.sammTimbre!.vector
      vector += self.sasmTimbre!.vector

      return vector
    }
  }

  /**
      Returns a mutable set for the managed `timbreVectors` relationship.
  */
  dynamic var timbreVectorSet: NSMutableSet {
    return self.mutableSetValueForKey("timbreVectors")
  }

  /**
      Timbre vector 1 (means of the means)
  */
  dynamic var mammTimbre: TimbreVectorEntity? {
    get { return self.getTimbreVector(forSummaryType: SummaryType.meanAccMeanMem) }
    set { self.setTimbreVector(newValue!, forSummaryType: SummaryType.meanAccMeanMem) }
  }

  /**
      Timbre vector 2 (means of the standard deviations)
  */
  dynamic var masmTimbre: TimbreVectorEntity? {
    get { return self.getTimbreVector(forSummaryType: SummaryType.meanAccStdMem) }
    set { self.setTimbreVector(newValue!, forSummaryType: SummaryType.meanAccStdMem) }
  }

  /**
      Timbre vector 3 (standard deviations of the means)
  */
  dynamic var sammTimbre: TimbreVectorEntity? {
    get { return self.getTimbreVector(forSummaryType: SummaryType.stdAccMeanMem) }
    set { self.setTimbreVector(newValue!, forSummaryType: SummaryType.stdAccMeanMem) }
  }

  /**
      Timbre vector 4 (standard deviations of the standard deviations)
  */
  dynamic var sasmTimbre: TimbreVectorEntity? {
    get { return self.getTimbreVector(forSummaryType: SummaryType.stdAccStdMem) }
    set { self.setTimbreVector(newValue!, forSummaryType: SummaryType.stdAccStdMem) }
  }

  // MARK: Convenience getter and setter functions for retrieving/storing timbre vectors
  // of a given summary type

  func getTimbreVector(forSummaryType summaryType: SummaryType) -> TimbreVectorEntity? {
    return timbreVectorSet.filter({
      ($0 as! TimbreVectorEntity).summaryType == summaryType.rawValue
    }).first as? TimbreVectorEntity
  }

  func removeTimbreVector(forSummaryType summaryType: SummaryType) {
    if let oldVector = self.getTimbreVector(forSummaryType: summaryType) {
      // Remove the old vector for the summary type
      timbreVectorSet.removeObject(oldVector)
    }
  }

  func setTimbreVector(newVector: TimbreVectorEntity, forSummaryType summaryType: SummaryType) {
    // Remove old timbre vector if necessary
    self.removeTimbreVector(forSummaryType: summaryType)

    // Set the summary type for the new vector and add it to the timbres set
    newVector.summaryType = summaryType.rawValue
    timbreVectorSet.addObject(newVector)
  }

  /**
      Compares the timbre of this track with another track, using the distance
      formula specified in the Settings.plist file. Supported formulas include
      `"euclidean"` and `"manhattan"`.

      - parameter track: The `TrackEntity` to compare this track with.

      - returns: The distance between the two vectors as a double.
  */
  func compareTimbreWith(otherTrack track: TrackEntity) -> Double {
    let formula = self.appDelegate.settings?["distanceFormula"] as! String
    return self.timbreVector64.calculateDistanceFrom(
      otherVector: track.timbreVector64, withFormula: formula)
  }

  /**
      Create a new `TimbreVectorEntity` from a 16-dimensional array of audio features
      (represented as doubles.)

      - parameter features: 16-dimensional array of audio features.

      - returns: The newly-created `TimbreVectorEntity`.
  */
  func createTimbreVector(fromFeaturesArray features: [Double]) -> TimbreVectorEntity {
    let vector: TimbreVectorEntity = self.dataController.createEntity()

    vector.centroid = features[0]
    vector.rolloff = features[1]
    vector.flux = features[2]
    vector.mfcc = Array(features[3...15])

    return vector
  }

  /**
      Given a 64-dimensional vector of features, creates a set of
      `TimbreVectorEntity`s and creates relationships between this track and
      the vectors.

      - parameter features: The 64-dimensional feature array.
  */
  func store64DimensionalTimbreVector(features: [Double]) {
    // Split array into 16-dimensional vectors for each summary type
    let mammFeatures = Array(features[0...15])
    let masmFeatures = Array(features[16...31])
    let sammFeatures = Array(features[32...47])
    let sasmFeatures = Array(features[48...63])

    // Set up vectors
    self.mammTimbre = self.createTimbreVector(fromFeaturesArray: mammFeatures)
    self.masmTimbre = self.createTimbreVector(fromFeaturesArray: masmFeatures)
    self.sammTimbre = self.createTimbreVector(fromFeaturesArray: sammFeatures)
    self.sasmTimbre = self.createTimbreVector(fromFeaturesArray: sasmFeatures)
  }

  /**
      Analyze the timbre, tempo, key, and loudness of this track.
  */
  func analyze() {
    self.analyzed = AnalysisState.inProgress.rawValue
    // Save the new analysis state to signal the UI
    if self.managedObjectContext != nil {
      self.dataController.save()
    }

    // Get (or create via conversion) the WAV URL for the track
    guard let (wavURL, converted) = extractor.getOrCreateWavURL(self) else {
      // There was some issue creating the Wav file - most likely the
      // FFMPEG binary couldn't be located
      return
    }

    // Compute key, loudness, and timbre
    let features = extractor.computeTimbre(wavURL)
    self.store64DimensionalTimbreVector(features)
    self.key = extractor.computeKey(wavURL)
    self.loudness = extractor.computeLoudness(wavURL)

    // Compute the tempo for tracks shorter than 20 minutes long.
    // The vast majority of electronic dance tracks clock in somewhere between
    // 5 and ~10 minutes long - allowing for up to 20 minutes gives a bit of
    // a buffer for this. Files longer than 20 minutes are more likely to be
    // non-track files (for example, DJ mixes or podcasts.)
    // The tempo executable is extremely slow on files of long lengths, so
    // forgo processing files that are likely not tracks anyway.
    if self.tempo! == 0 && Int(self.duration!) < 1200 {
      self.tempo = extractor.computeTempo(wavURL)
    }

    // Delete the WAV file if we converted from another format
    if converted {
      do {
        try NSFileManager.defaultManager().removeItemAtURL(wavURL)
      } catch {
        print("Could not remove file at \(wavURL): \(error)")
      }
    }

    self.analyzed = AnalysisState.complete.rawValue
    // Save the new analysis state to signal the UI
    if self.managedObjectContext != nil {
      self.dataController.save()
    }
  }
}
