//
//  TimbreVectorEntity.swift
//  Selektor
//
//  Created by James Gray on 2016-07-01.
//  Copyright © 2016 James Gray. All rights reserved.
//

import Foundation
import CoreData

enum SummaryType: Int {
  case MeanAccMeanMem = 0
  case MeanAccStdMem
  case StdAccMeanMem
  case StdAccStdMem
}

@objc(TimbreVectorEntity)
class TimbreVectorEntity: SelektorObject {

  // MARK: Properties
  @NSManaged var summaryType: NSNumber?
  @NSManaged var centroid: NSNumber?
  @NSManaged var flux: NSNumber?
  @NSManaged var rolloff: NSNumber?
  @NSManaged var mfccString: String?
  @NSManaged var track: TrackEntity?

  override class func getEntityName() -> String {
    return "TimbreVector"
  }

  // MARK: Public getters/setters for managed MFCC properties
  var mfcc: [Double] {
    get {
      return self.mfccString?.componentsSeparatedByString(",").map { Double($0)! } ?? []
    }
    set {
      self.mfccString = newValue.map({ String($0) }).joinWithSeparator(",")
    }
  }

  var vector: [Double] {
    get {
      return [
        Double(self.centroid!),
        Double(self.flux!),
        Double(self.rolloff!)
      ] + self.mfcc.map { Double($0) }
    }
  }
}
