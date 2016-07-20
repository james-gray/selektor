//
//  FeatureExtractor.swift
//  Selektor
//
//  Created by James Gray on 2016-07-18.
//  Copyright © 2016 James Gray. All rights reserved.
//

import Foundation

/**
    Controller class that handles the calling of executables to perform feature
    extraction.
*/
class FeatureExtractor {

  /// Path to the ffmpeg conversion executable.
  static let ffmpegPath: String? = NSBundle.mainBundle().pathForResource("ffmpeg",
    ofType: nil, inDirectory: "Dependencies/ffmpeg")

  /// Path to the Marsyas mirex_extract executable.
  static let mirexPath: String? = NSBundle.mainBundle().pathForResource("mirex_extract",
    ofType: nil, inDirectory: "Dependencies/marsyas/bin")

  /// Path to the Marsyas tempo beat estimation executable.
  static let tempoPath: String? = NSBundle.mainBundle().pathForResource("tempo",
    ofType: nil, inDirectory: "Dependencies/marsyas/bin")

  /// Path to the Marsyas omRms executable.
  static let omRmsPath: String? = NSBundle.mainBundle().pathForResource("omRms",
    ofType: nil, inDirectory: "Dependencies/marsyas/bin")

  /// Path to the VAMP simple host executable.
  static let hostPath: String? = NSBundle.mainBundle().pathForResource("vamp-simple-host",
    ofType: nil, inDirectory: "Dependencies/vamp_simple_host")

  /// Path to the key detector dylib.
  static let keyDetectorPath: String? = NSBundle.mainBundle().pathForResource("qm-vamp-plugins.dylib", ofType: nil, inDirectory: "Dependencies/qm_vamp_plugins")

  // MARK: Convenience properties
  let tempDirectory = NSURL(fileURLWithPath: NSTemporaryDirectory() as String)

  /**
      Returns, or creates, a wave file URL for the given track. If this track is
      already a wave file, this method simply returns the URL of the file's
      location, otherwise it creates a temporary wave file in the application's
      temporary directory.

      - parameter track: The track to get or create a wave file for.

      - returns: A tuple containing the URL of the wave file and a boolean indicating
          that the file was converted if `true` or that the original file was used
          if `false`.
  */
  func getOrCreateWavURL(track: TrackEntity) -> (NSURL, Bool)? {
    var wavURL: NSURL

    let isWav = NSURL(fileURLWithPath: track.filename!).pathExtension == "wav"
    if !isWav {
      print("Converting \(track.relativeFilename!) to .wav")

      // Use ffmpeg to create a temporary wav copy of the track
      guard let ffmpegPath = FeatureExtractor.ffmpegPath else {
        print("Unable to locate the ffmpeg binary")
        return nil
      }

      let uuid = NSUUID().UUIDString
      wavURL = tempDirectory.URLByAppendingPathComponent("\(uuid).wav")

      let task = NSTask()
      task.launchPath = ffmpegPath
      task.arguments = ["-i", track.filename!, wavURL.path!]
      task.launch()
      task.waitUntilExit()
    } else {
      // Simply use the track's file path as the WAV URL
      wavURL = NSURL(fileURLWithPath: track.filename!)
    }

    // Invert the boolean to indicate whether or not we had to convert the file
    let converted = !isWav
    return (wavURL, converted)
  }

  /**
      Parse ARFF output of mirex_extract command to create a 64-dimensional
      timbre vector as a double array.

      - parameter arffURL: The arff file to parse.

      - returns: The feature vector as a double array.
  */
  func parseArffFile(arffURL: NSURL) -> [Double] {
    do {
      let arffContents = try String(contentsOfURL: arffURL)
      let arffLines = arffContents.componentsSeparatedByString("\n")

      // Extract the vector from the ARFF file.
      // Since only one track was analyzed, only one vector will be contained
      // in the file, so we always know the position of the vector relative to
      // the end of the file.
      let vectorString = arffLines[arffLines.endIndex - 2]
      var stringFeatures = vectorString.componentsSeparatedByString(",")
      stringFeatures.removeLast() // Remove the file label

      // Cast strings to doubles
      return (stringFeatures.map({ Double($0)! }) as [Double])
    } catch {
      print("Error reading from ARFF file at \(arffURL)")
      return []
    }
  }

  /**
      Executes the `mirex_extract` command against the file at `wavURL` to generate
      an .arff file of timbre information for the given track.

      - parameter wavURL: The URL of the wave file to analyze.

      - returns: The 64-dimensional feature vector as a double array.
  */
  func computeTimbre(wavURL: NSURL) -> [Double] {
    guard let mirexPath = FeatureExtractor.mirexPath else {
      print("Unable to locate the mirex_extract binary")
      return []
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
      return []
    }

    // Execute the mirex_extract command to analyze the track
    let task = NSTask()
    task.launchPath = mirexPath
    task.arguments = [tempMfURL.path!, tempArffURL.path!]
    task.launch()
    task.waitUntilExit()

    // Parse output and compute 64-dimensional timbre vector
    let features = self.parseArffFile(tempArffURL)

    // Clean up tempfiles
    do {
      try fileManager.removeItemAtURL(tempMfURL)
      try fileManager.removeItemAtURL(tempArffURL)
    } catch {
      print("Error removing temporary files at \(tempMfURL), \(tempArffURL)")
    }

    return features
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

      - returns: The tempo as an integer.
  */
  func computeTempo(wavURL: NSURL) -> Int {
    guard let tempoPath = FeatureExtractor.tempoPath else {
      print("Unable to locate the tempo binary")
      return 0
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

    return tempo
  }

  /**
      Parses the standard output of the `qm-keydetector` VAMP plugin to extract
      the most likely candidate key for the track.

      - parameter pipe: The pipe to read the standard output from.

      - returns: A string representation of the key of this track.
  */
  func parseKeyDetectorOutput(pipe: NSPipe) -> String {
    // Enharmonically respell all flat keys as sharp keys for consistency using
    // this map
    let keyMap = [
      "Db": "C#",
      "Eb": "D#",
      "Gb": "F#",
      "Ab": "G#",
      "Bb": "A#",
    ]
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
    let chosenKey = sortedKeys[0].0

    // Return the most frequently occurring key as the detected key,
    // respelling it enharmonically if necessary.
    return keyMap.keys.contains(chosenKey) ? keyMap[chosenKey]! : chosenKey
  }

  /**
      Runs the `qm-keydetector` VAMP plugin on `wavURL` to extract key information about
      this track.

      - parameter wavURL: The wave file to perform key detection on.

      - returns: The key as a string.
  */
  func computeKey(wavURL: NSURL) -> String {
    guard let hostPath = FeatureExtractor.hostPath else {
      print("Unable to locate the vamp-simple-host binary")
      return ""
    }

    // Add the plugins directory to the NSTask's VAMP_PATH env var to ensure the VAMP
    // simple host can load the key detector plugin correctly.
    let pluginsDirectory = NSString(UTF8String: FeatureExtractor.keyDetectorPath!)?.stringByDeletingLastPathComponent
    var env = NSProcessInfo.processInfo().environment
    env["VAMP_PATH"] = pluginsDirectory!

    // Execute the tempo command to analyze the track's BPM
    let task = NSTask()
    let pipe = NSPipe()
    task.launchPath = hostPath
    task.environment = env
    task.arguments = [
      "\(FeatureExtractor.keyDetectorPath!):qm-keydetector",
      wavURL.path!,
    ]
    task.standardOutput = pipe
    task.launch()
    task.waitUntilExit()

    // Parse key detector output and set the song's key
    return self.parseKeyDetectorOutput(pipe)
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

      - returns: The loudness as a double.
  */
  func computeLoudness(wavURL: NSURL) -> Double {
    guard let omRmsPath = FeatureExtractor.omRmsPath else {
      print("Unable to locate the omRms binary")
      return 0.0
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
    return self.parseOmRmsOutput(pipe)
  }
}
