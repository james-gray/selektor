//
//  TimbreVectorEntity.swift
//  Selektor
//
//  Created by James Gray on 2016-07-01.
//  Copyright © 2016 James Gray. All rights reserved.
//

import Foundation
import CoreData


class TimbreVectorEntity: SelektorObject {

  // MARK: Properties
  @NSManaged var mammCentroid: NSNumber?
  @NSManaged var masmCentroid: NSNumber?
  @NSManaged var sammCentroid: NSNumber?
  @NSManaged var sasmCentroid: NSNumber?
  @NSManaged var mammFlux: NSNumber?
  @NSManaged var masmFlux: NSNumber?
  @NSManaged var sammFlux: NSNumber?
  @NSManaged var sasmFlux: NSNumber?
  @NSManaged var mammRolloff: NSNumber?
  @NSManaged var masmRolloff: NSNumber?
  @NSManaged var sammRolloff: NSNumber?
  @NSManaged var sasmRolloff: NSNumber?
  @NSManaged var mammMFCCString: String?
  @NSManaged var masmMFCCString: String?
  @NSManaged var sammMFCCString: String?
  @NSManaged var sasmMFCCString: String?
  @NSManaged var song: SongEntity?

  // MARK: Public getters/setters for managed MFCC properties
  var mammMFCC: [Double] {
    get {
      return self.doubleArrayFromCsvString(self.mammMFCCString) ?? []
    }
    set {
      self.mammMFCCString = self.csvStringFromDoubleArray(newValue)
    }
  }

  var mammsMFCC: [Double] {
    get {
      return self.doubleArrayFromCsvString(self.masmMFCCString) ?? []
    }
    set {
      self.masmMFCCString = self.csvStringFromDoubleArray(newValue)
    }
  }

  var sammMFCC: [Double] {
    get {
      return self.doubleArrayFromCsvString(self.sammMFCCString) ?? []
    }
    set {
      self.sammMFCCString = self.csvStringFromDoubleArray(newValue)
    }
  }

  var sasmMFCC: [Double] {
    get {
      return self.doubleArrayFromCsvString(self.sasmMFCCString) ?? []
    }
    set {
      self.sasmMFCCString = self.csvStringFromDoubleArray(newValue)
    }
  }

  /*
      Serialize a double array into a string of doubles separated by commas for
      storage in the database.
   */
  func csvStringFromDoubleArray(doubles: [Double]) -> String {
    return doubles.map({ String($0) }).joinWithSeparator(",")
  }

  /*
      Parse a CSV string of doubles from the database into an array of doubles.
   */
  func doubleArrayFromCsvString(csv: String?) -> [Double] {
    return csv?.componentsSeparatedByString(",").map { Double($0)! } ?? []
  }
}
