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

// Enumeration to track song analysis state
enum AnalysisState: Int {
  case ToDo = 0, InProgress, Done
}

@objc(SongEntity)
class SongEntity: SelektorObject {

  // MARK: Properties
  @NSManaged dynamic var analyzed: NSNumber?
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
  @NSManaged dynamic var timbre: TimbreVectorEntity?

  override class func getEntityName() -> String {
    return "Song"
  }

  override func awakeFromInsert() {
    super.awakeFromInsert()

    // Set dateAdded to the current date on object creation
    dateAdded = NSDate()
    analyzed = AnalysisState.ToDo.rawValue
  }
}