//
//  SongEntity.swift
//  Selektor
//
//  Created by James Gray on 2016-05-28.
//  Copyright © 2016 James Gray. All rights reserved.
//

import Foundation
import CoreData
import Cocoa
import ObjectiveC
import QuartzCore

let mirexPath: String? = NSBundle.mainBundle().pathForResource("mirex_extract", ofType: nil, inDirectory: "Lib/marsyas/bin")
let ffmpegPath: String? = NSBundle.mainBundle().pathForResource("ffmpeg", ofType: nil, inDirectory: "Lib/ffmpeg")
let tempoPath: String? = NSBundle.mainBundle().pathForResource("tempo", ofType: nil, inDirectory: "Lib/marsyas/bin")

enum AnalysisState: Int {
  case ToDo = 0
  case InProgress
  case Complete
}

@objc(SongEntity)
class SongEntity: SelektorObject {

  // MARK: Properties
  @NSManaged dynamic var analyzed: NSNumber
  @NSManaged dynamic var dateAdded: NSDate?
  @NSManaged dynamic var duration: NSNumber?
  @NSManaged dynamic var filename: String?
  @NSManaged dynamic var loudness: NSNumber?
  @NSManaged dynamic var tempo: NSNumber?
  @NSManaged dynamic var album: String?
  @NSManaged dynamic var artist: String?
  @NSManaged dynamic var genre: String?
  @NSManaged dynamic var key: String?
  @NSManaged dynamic var label: String?
  @NSManaged dynamic var timbreVectors: NSSet?

  override class func getEntityName() -> String {
    return "Song"
  }

  override func awakeFromInsert() {
    super.awakeFromInsert()

    // Set default values for NSManaged properties
    dateAdded = NSDate()
  }

  // MARK: Convenience properties

  dynamic var relativeFilename: String? {
    get { return NSURL(fileURLWithPath: self.filename!).lastPathComponent ?? nil }
  }

  dynamic var timbreVectorSet: NSMutableSet {
    get { return self.mutableSetValueForKey("timbreVectors") }
  }

  dynamic var mammTimbre: TimbreVectorEntity? {
    get { return self.getTimbreForSummaryType(SummaryType.MeanAccMeanMem) }
    set { self.setTimbreForSummaryType(newValue!, summaryType: SummaryType.MeanAccMeanMem) }
  }

  dynamic var masmTimbre: TimbreVectorEntity? {
    get { return self.getTimbreForSummaryType(SummaryType.MeanAccStdMem) }
    set { self.setTimbreForSummaryType(newValue!, summaryType: SummaryType.MeanAccStdMem) }
  }

  dynamic var sammTimbre: TimbreVectorEntity? {
    get { return self.getTimbreForSummaryType(SummaryType.StdAccMeanMem) }
    set { self.setTimbreForSummaryType(newValue!, summaryType: SummaryType.StdAccMeanMem) }
  }

  dynamic var sasmTimbre: TimbreVectorEntity? {
    get { return self.getTimbreForSummaryType(SummaryType.StdAccStdMem) }
    set { self.setTimbreForSummaryType(newValue!, summaryType: SummaryType.StdAccStdMem) }
  }

  // MARK: Convenience getter and setter functions for retrieving/storing timbre vectors
  // of a given summary type

  func getTimbreForSummaryType(summaryType: SummaryType) -> TimbreVectorEntity? {
    return timbreVectorSet.filter({
      ($0 as! TimbreVectorEntity).summaryType == summaryType.rawValue
    }).first as? TimbreVectorEntity
  }

  func setTimbreForSummaryType(newVector: TimbreVectorEntity, summaryType: SummaryType) {
    // Remove old timbre vector if necessary
    self.removeTimbreForSummaryType(summaryType)

    // Set the summary type for the new vector and add it to the timbres set
    newVector.summaryType = summaryType.rawValue
    timbreVectorSet.addObject(newVector)
  }

  func removeTimbreForSummaryType(summaryType: SummaryType) {
    if let oldVector = self.getTimbreForSummaryType(summaryType) {
      // Remove the old vector for the summary type
      timbreVectorSet.removeObject(oldVector)
    }
  }

  // MARK: Analysis Functions

  func createTimbreVectorFromFeaturesArray(features: [Double]) -> TimbreVectorEntity {
    let dc = self.appDelegate.dc
    let vector: TimbreVectorEntity = dc.createEntity()

    vector.centroid = features[0]
    vector.rolloff = features[1]
    vector.flux = features[2]
    vector.mfcc = Array(features[3...11])

    return vector
  }

  // MARK: Store
  func store64DimensionalTimbreVector(arffFileURL: NSURL) {
    do {
      let arffContents = try String(contentsOfURL: arffFileURL)
      let arffLines = arffContents.componentsSeparatedByString("\n")

      // Extract the vector from the ARFF file.
      // Since only one song was analyzed, only one vector will be contained
      // in the file, so we always know the position of the vector relative to
      // the end of the file.
      let vectorString = arffLines[arffLines.endIndex - 2]
      var stringFeatures = vectorString.componentsSeparatedByString(",")
      stringFeatures.removeLast(1) // Remove the file label
      let features = (stringFeatures.map({ Double($0)! }) as [Double]) // Cast strings to doubles

      // Split array into 16-dimensional vectors for each summary type
      let mammFeatures = Array(features[0...15])
      let masmFeatures = Array(features[16...31])
      let sammFeatures = Array(features[32...47])
      let sasmFeatures = Array(features[48...63])

      // Set up vectors
      self.mammTimbre = self.createTimbreVectorFromFeaturesArray(mammFeatures)
      self.masmTimbre = self.createTimbreVectorFromFeaturesArray(masmFeatures)
      self.sammTimbre = self.createTimbreVectorFromFeaturesArray(sammFeatures)
      self.sasmTimbre = self.createTimbreVectorFromFeaturesArray(sasmFeatures)

    } catch {
      print("Error reading from ARFF file at \(arffFileURL)")
    }
  }

  func computeTimbreVector(wavURL: NSURL) {
    guard let mirexPath = mirexPath else {
      print("Unable to locate the mirex_extract binary")
      return
    }

    let tempDir = self.appDelegate.tempDir
    let fileManager = self.appDelegate.fileManager

    let tempMfURL = tempDir.URLByAppendingPathComponent("\(self.relativeFilename!).mf")
    let tempArffURL = tempDir.URLByAppendingPathComponent("\(self.relativeFilename!).arff")

    // Write a temporary .mf file containing the song's URL for Marsyas
    do {
      try wavURL.path!.writeToURL(tempMfURL, atomically: false, encoding: NSUTF8StringEncoding)
    } catch {
      print("Error writing filename to temporary .mf file")
      return
    }

    // Execute the mirex_extract command to analyze the song
    let task = NSTask()
    task.launchPath = mirexPath
    task.arguments = [tempMfURL.path!, tempArffURL.path!]
    task.launch()
    task.waitUntilExit()

    // Store the timbre data in the song object
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

  func parseTempoOutput(pipe: NSPipe) -> Int {
    let data = NSString(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: NSASCIIStringEncoding) as! String
    let lines = data.componentsSeparatedByString("\n")
    let tempoLine = lines.filter { $0.hasPrefix("Estimated tempo") }.first
    let tempo = tempoLine?.componentsSeparatedByString(" ").last

    return Int(tempo!)!
  }

  func computeTempo(wavURL: NSURL) {
    guard let tempoPath = tempoPath else {
      print("Unable to locate the tempo binary")
      return
    }

    // Execute the tempo command to analyze the song's BPM
    let task = NSTask()
    let pipe = NSPipe()
    task.launchPath = tempoPath
    task.arguments = [wavURL.path!]
    task.standardOutput = pipe
    task.launch()
    task.waitUntilExit()

    self.tempo = self.parseTempoOutput(pipe)
  }

  func getOrCreateWavURL() -> (NSURL, Bool)? {
    let tempDir = self.appDelegate.tempDir
    var wavURL: NSURL

    let isWav = NSURL(fileURLWithPath: self.filename!).pathExtension == "wav"
    if !isWav {
      print("Converting \(self.relativeFilename!) to .wav")

      // Use ffmpeg to create a temporary wav copy of the song
      guard let ffmpegPath = ffmpegPath else {
        print("Unable to locate the ffmpeg binary")
        return nil
      }

      let filename = NSURL(fileURLWithPath: self.filename!).URLByDeletingPathExtension?.lastPathComponent
      wavURL = tempDir.URLByAppendingPathComponent(filename! + "_temp.wav")

      let task = NSTask()
      task.launchPath = ffmpegPath
      task.arguments = ["-i", self.filename!, wavURL.path!]
      task.launch()
      task.waitUntilExit()
    } else {
      // Simply use the song's file path as the WAV URL
      wavURL = NSURL(fileURLWithPath: self.filename!)
    }

    // Invert the boolean to indicate whether or not we had to convert the file
    let converted = !isWav
    return (wavURL, converted)
  }

  func analyze() {
    self.analyzed = AnalysisState.InProgress.rawValue

    // Get (or create via conversion) the WAV URL for the song
    guard let (wavURL, converted) = self.getOrCreateWavURL() else {
      // There was some issue creating the Wav file - most likely the
      // FFMPEG binary couldn't be located
      return
    }

    // Compute timbre vector and (if necessary) tempo
    self.computeTimbreVector(wavURL)

    // Compute the tempo for songs shorter than 20 minutes long.
    // The vast majority of electronic dance songs clock in somewhere between
    // 5 and ~10 minutes long - allowing for up to 20 minutes gives a bit of
    // a buffer for this. Files longer than 20 minutes are more likely to be
    // non-song files (for example, DJ mixes or podcasts.)
    // The tempo executable is extremely slow on files of long lengths, so
    // forgo processing files that are likely not songs anyway.
    if self.tempo! == 0 && Int(self.duration!) < 1200 {
      self.computeTempo(wavURL)
    }

    // Delete the WAV file if we converted from another format
    if converted {
      do {
        try self.appDelegate.fileManager.removeItemAtURL(wavURL)
      } catch {
        print("Could not remove file at \(wavURL): \(error)")
      }
    }

    // Mark this song as analyzed
    self.analyzed = AnalysisState.Complete.rawValue
  }
}