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

  /// Path to the ffmpeg conversion executable.
  static let ffmpegPath: String? = NSBundle.mainBundle().pathForResource("ffmpeg",
      ofType: nil, inDirectory: "Dependencies/ffmpeg")

  /// Path to the Marsyas tempo beat estimation executable.
  static let tempoPath: String? = NSBundle.mainBundle().pathForResource("tempo",
    ofType: nil, inDirectory: "Dependencies/marsyas/bin")

  /// Path to the Marsyas mirex_extract executable.
  static let mirexPath: String? = NSBundle.mainBundle().pathForResource("mirex_extract",
    ofType: nil, inDirectory: "Dependencies/marsyas/bin")

  /// Path to the Marsyas omRms executable.
  static let omRmsPath: String? = NSBundle.mainBundle().pathForResource("omRms",
    ofType: nil, inDirectory: "Dependencies/marsyas/bin")

  /// Path to the VAMP simple host executable.
  static let hostPath: String? = NSBundle.mainBundle().pathForResource("vamp-simple-host",
    ofType: nil, inDirectory: "Dependencies/vamp_simple_host")

  /// Path to the key detector dylib.
  static let keyDetectorPath: String? = NSBundle.mainBundle().pathForResource("qm-vamp-plugins.dylib", ofType: nil, inDirectory: "Dependencies/qm_vamp_plugins")

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

  // MARK: Analysis Functions

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
      Given an .arff file generated with the `mirex_extract` executable, creates
      a set of `TimbreVectorEntity`s and creates relationships between this track
      and the vectors.

      - parameter arffFileURL: The URL of the .arff file to parse.
  */
  func store64DimensionalTimbreVector(arffFileURL: NSURL) {
    do {
      let arffContents = try String(contentsOfURL: arffFileURL)
      let arffLines = arffContents.componentsSeparatedByString("\n")

      // Extract the vector from the ARFF file.
      // Since only one track was analyzed, only one vector will be contained
      // in the file, so we always know the position of the vector relative to
      // the end of the file.
      let vectorString = arffLines[arffLines.endIndex - 2]
      var stringFeatures = vectorString.componentsSeparatedByString(",")
      stringFeatures.removeLast() // Remove the file label
      let features = (stringFeatures.map({ Double($0)! }) as [Double]) // Cast strings to doubles

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

    } catch {
      print("Error reading from ARFF file at \(arffFileURL)")
    }
  }

  /**
      Executes the `mirex_extract` command against the file at `wavURL` to generate
      an .arff file of timbre information for this track.

      - parameter wavURL: The URL of the wave file to analyze.
  */
  func computeTimbre(wavURL: NSURL) {
    guard let mirexPath = TrackEntity.mirexPath else {
      print("Unable to locate the mirex_extract binary")
      return
    }

    let fileManager = NSFileManager.defaultManager()

    let mfUUID = NSUUID().UUIDString
    let arffUUID = NSUUID().UUIDString

    let tempMfURL = tempDirectory.URLByAppendingPathComponent("\(mfUUID).mf")
    let tempArffURL = tempDirectory.URLByAppendingPathComponent("\(arffUUID).arff")

    // Write a temporary .mf file containing the track's URL for Marsyas
    do {
      try wavURL.path!.writeToURL(tempMfURL, atomically: false, encoding: NSUTF8StringEncoding)
    } catch {
      print("Error writing filename to temporary .mf file")
      return
    }

    // Execute the mirex_extract command to analyze the track
    let task = NSTask()
    task.launchPath = mirexPath
    task.arguments = [tempMfURL.path!, tempArffURL.path!]
    task.launch()
    task.waitUntilExit()

    // Store the timbre data in the track object
    self.store64DimensionalTimbreVector(tempArffURL)

    // Clean up temporary files. Wav files are huge - we don't want them cluttering
    // up the user's disk until the app quits!
    do {
      try fileManager.removeItemAtURL(tempMfURL)
      try fileManager.removeItemAtURL(tempArffURL)
    } catch {
      print("Could not remove files at \(tempMfURL), \(tempArffURL): \(error)")
    }
  }

  /**
      Parses the standard output of the `tempo` executable to extract the BPM tempo
      value and return it as an integer.

      - parameter pipe: The pipe to read the standard output from.

      - returns: An integer representation of the BPM tempo of this track.
  */
  func parseTempoOutput(pipe: NSPipe) -> Int {
    let data = NSString(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: NSASCIIStringEncoding) as! String

    if data.rangeOfString("MRS_WARNING") != nil {
        // Error computing tempo if MRS_WARNING is in the output
        return 0
    }

    let lines = data.componentsSeparatedByString("\n")
    let tempoLine = lines.filter { $0.hasPrefix("Estimated tempo") }.first
    let tempo = tempoLine?.componentsSeparatedByString(" ").last

    return Int(tempo!)!
  }

  /**
      Runs the `tempo` executable on `wavURL` to extract tempo information about
      this track.

      - parameter wavURL: The wave file to perform tempo estimation on.
  */
  func computeTempo(wavURL: NSURL) {
    guard let tempoPath = TrackEntity.tempoPath else {
      print("Unable to locate the tempo binary")
      return
    }

    // Execute the tempo command to analyze the track's BPM
    let task = NSTask()
    let pipe = NSPipe()
    task.launchPath = tempoPath
    task.arguments = [wavURL.path!]
    task.standardOutput = pipe
    task.launch()
    task.waitUntilExit()

    var tempo = abs(self.parseTempoOutput(pipe))

    // Account (somewhat heavy-handedly) for octave errors.
    // Most electronic dance music's BPM ranges from about 80 to 180
    // (give or take 10 bpm) depending on the genre. In order to ensure the
    // BPM is (most likely) in the correct octave, arbitrarily set BPM limits
    // to within 70...190 bpm.
    if tempo != 0 {
      while tempo > 190 {
        tempo /= 2
      }
      while tempo < 70 {
        tempo *= 2
      }
    }

    self.tempo = tempo
  }

  /**
      Parses the standard output of the `qm-keydetector` VAMP plugin to extract
      the most likely candidate key for the track.

      - parameter pipe: The pipe to read the standard output from.

      - returns: A string representation of the key of this track.
  */
  func parseKeyDetectorOutput(pipe: NSPipe) -> String {
    let data = NSString(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: NSASCIIStringEncoding) as! String

    // Parse out the key values per analysis frame
    let lines = data.componentsSeparatedByString("\n")
    var keys = lines.map { $0.componentsSeparatedByString(" ").last }
    keys.removeLast() // Remove emptystring from keys array

    // Map each key to the number of times it appears in the array. The key with
    // the most occurrences will be chosen as this song's key.
    var keyOccurrences = [String: Int]()
    for key in keys {
      // Increment occurrences for this key
      keyOccurrences[key!] = (keyOccurrences[key!] ?? 0) + 1
    }

    // Sort key occurrences in descending order by value, i.e. the first key in
    // the sorted array is the key candidate that occurred the most times in detection
    let sortedKeys = keyOccurrences.sort { $0.1 > $1.1 }

    // Return the most frequently occurring key as the detected key.
    return sortedKeys[0].0
  }

  /**
      Runs the `qm-keydetector` VAMP plugin on `wavURL` to extract key information about
      this track.

      - parameter wavURL: The wave file to perform key detection on.
  */
  func computeKey(wavURL: NSURL) {
    guard let hostPath = TrackEntity.hostPath else {
      print("Unable to locate the vamp-simple-host binary")
      return
    }

    // Add the plugins directory to the NSTask's VAMP_PATH env var to ensure the VAMP
    // simple host can load the key detector plugin correctly.
    let pluginsDirectory = NSString(UTF8String: TrackEntity.keyDetectorPath!)?.stringByDeletingLastPathComponent
    var env = NSProcessInfo.processInfo().environment
    env["VAMP_PATH"] = pluginsDirectory!

    // Execute the tempo command to analyze the track's BPM
    let task = NSTask()
    let pipe = NSPipe()
    task.launchPath = hostPath
    task.environment = env
    task.arguments = [
      "\(TrackEntity.keyDetectorPath!):qm-keydetector",
      wavURL.path!,
    ]
    task.standardOutput = pipe
    task.launch()
    task.waitUntilExit()

    // Parse key detector output and set the song's key
    self.key = self.parseKeyDetectorOutput(pipe)
  }

  /**
      Parses the standard output of the `omRms` executable to extract
      a single normalized RMS loudness value for this track

      - parameter pipe: The pipe to read the standard output from.

      - returns: A double representation of the track's loudness.
  */
  func parseOmRmsOutput(pipe: NSPipe) -> Double {
    let data = NSString(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: NSASCIIStringEncoding) as! String

    // Parse out the loudness values per window
    let lines = data.componentsSeparatedByString("\n")
    let rmsValues = lines.map { Double($0.componentsSeparatedByString("\t").last!) }

    // Compute the average loudness
    var avgRms = 0.0
    for value in rmsValues {
      avgRms += value ?? 0
    }
    avgRms /= Double(rmsValues.count)

    return avgRms
  }

  /**
      Runs the `omRms` executable on `wavURL` to extract loudness information about
      this track.

      - parameter wavURL: The wave file to perform loudness extraction on.
  */
  func computeLoudness(wavURL: NSURL) {
    guard let omRmsPath = TrackEntity.omRmsPath else {
      print("Unable to locate the omRms binary")
      return
    }

    // Execute the omRms command to analyze the track's loudness
    let task = NSTask()
    let pipe = NSPipe()
    task.launchPath = omRmsPath
    task.arguments = [
      "-ws", "44100", // Window size of 44100 samples
      "-hp", "22050", // Hop size of 22050 samples
      wavURL.path!,
    ]
    task.standardOutput = pipe
    task.launch()
    task.waitUntilExit()

    // Parse omRms output and set the song's loudness
    self.loudness = self.parseOmRmsOutput(pipe)
  }

  /**
      Returns, or creates, a wave file URL for this track. If this track is
      already a wave file, this method simply returns the URL of the file's
      location, otherwise it creates a temporary wave file in the application's
      temporary directory.

      - returns: A tuple containing the URL of the wave file and a boolean indicating
          that the file was converted if `true` or that the original file was used
          if `false`.
  */
  func getOrCreateWavURL() -> (NSURL, Bool)? {
    var wavURL: NSURL

    let isWav = NSURL(fileURLWithPath: self.filename!).pathExtension == "wav"
    if !isWav {
      print("Converting \(self.relativeFilename!) to .wav")

      // Use ffmpeg to create a temporary wav copy of the track
      guard let ffmpegPath = TrackEntity.ffmpegPath else {
        print("Unable to locate the ffmpeg binary")
        return nil
      }

      let uuid = NSUUID().UUIDString
      wavURL = tempDirectory.URLByAppendingPathComponent("\(uuid).wav")

      let task = NSTask()
      task.launchPath = ffmpegPath
      task.arguments = ["-i", self.filename!, wavURL.path!]
      task.launch()
      task.waitUntilExit()
    } else {
      // Simply use the track's file path as the WAV URL
      wavURL = NSURL(fileURLWithPath: self.filename!)
    }

    // Invert the boolean to indicate whether or not we had to convert the file
    let converted = !isWav
    return (wavURL, converted)
  }

  /**
      Analyze the timbre and tempo of this track.
  */
  func analyze() {
    self.analyzed = AnalysisState.inProgress.rawValue
    // Save the new analysis state to signal the UI
    if self.managedObjectContext != nil {
      self.dataController.save()
    }

    // Get (or create via conversion) the WAV URL for the track
    guard let (wavURL, converted) = self.getOrCreateWavURL() else {
      // There was some issue creating the Wav file - most likely the
      // FFMPEG binary couldn't be located
      return
    }

    // Compute key, loudness, and timbre
    self.computeKey(wavURL)
    self.computeLoudness(wavURL)
    self.computeTimbre(wavURL)

    // Compute the tempo for tracks shorter than 20 minutes long.
    // The vast majority of electronic dance tracks clock in somewhere between
    // 5 and ~10 minutes long - allowing for up to 20 minutes gives a bit of
    // a buffer for this. Files longer than 20 minutes are more likely to be
    // non-track files (for example, DJ mixes or podcasts.)
    // The tempo executable is extremely slow on files of long lengths, so
    // forgo processing files that are likely not tracks anyway.
    if self.tempo! == 0 && Int(self.duration!) < 1200 {
      self.computeTempo(wavURL)
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
