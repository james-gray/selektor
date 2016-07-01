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

class TimbreVectorEntity: SelektorObject {

  // MARK: Properties
  @NSManaged var summaryType: NSNumber?
  @NSManaged var centroid: NSNumber?
  @NSManaged var flux: NSNumber?
  @NSManaged var rolloff: NSNumber?
  @NSManaged var mfccString: String?
  @NSManaged var song: SongEntity?

  // MARK: Public getters/setters for managed MFCC properties
  var mfcc: [Double] {
    get {
      return self.mfccString?.componentsSeparatedByString(",").map { Double($0)! } ?? []
    }
    set {
      self.mfccString = newValue.map({ String($0) }).joinWithSeparator(",")
    }
  }
}