//
//  TimbreVectorEntity.swift
//  Selektor
//
//  Created by James Gray on 2016-07-01.
//  Copyright © 2016 James Gray. All rights reserved.
//

import Foundation
import CoreData

/**
    Enumeration representing the summarization type of a given timbre vector.
    Marsyas's `mirex_extract` computes running statistics (means and standard
    deviations) of the audio file under analysis, producing a 64-dimensional
    vector, representing 16 audio features summarized in various ways - the first
    16 represent the means of the means, the second 16 the means of the standard
    deviations, the third 16 the standard deviations of the means, and the final
    16 the standard deviations of the standard deviations.

    See https://sourceforge.net/p/marsyas/mailman/message/27901579/
*/
enum SummaryType: Int {
  case meanAccMeanMem = 0
  case meanAccStdMem
  case stdAccMeanMem
  case stdAccStdMem
}

/**
    Entity representing a single 16-dimensional timbre vector containing double
    values for centroid, rolloff, flux, and thirteen Mel-frequency cepstral coefficients.
*/
@objc(TimbreVectorEntity)
class TimbreVectorEntity: SelektorObject {
  override class func getEntityName() -> String {
    return "TimbreVector"
  }

  // MARK: Properties
  @NSManaged var summaryType: NSNumber?
  @NSManaged var centroid: NSNumber?
  @NSManaged var flux: NSNumber?
  @NSManaged var rolloff: NSNumber?
  @NSManaged var mfccString: String?
  @NSManaged var track: TrackEntity?

  // MARK: Public getters/setters for managed MFCC properties

  /**
      Returns, or allows the setting of, the MFCCs as a length-13 array of doubles.
      MFCCs are stored in the database as a comma-separated string of numbers.
  */
  var mfcc: [Double] {
    get {
      return self.mfccString?.componentsSeparatedByString(",").map { Double($0)! } ?? []
    }
    set {
      self.mfccString = newValue.map({ String($0) }).joinWithSeparator(",")
    }
  }

  /// Returns a length-16 array representing this vector.
  var vector: [Double] {
    return [
      Double(self.centroid!),
      Double(self.flux!),
      Double(self.rolloff!)
    ] + self.mfcc.map { Double($0) }
  }
}