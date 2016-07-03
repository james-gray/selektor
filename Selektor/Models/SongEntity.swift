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
  @NSManaged dynamic var timbres: NSSet?

  // MARK: Convenience getters for obtaining timbre vectors of different
  // summarization types
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

  func getTimbreForSummaryType(summaryType: SummaryType) -> TimbreVectorEntity? {
    return timbres!.filter({
      ($0 as! TimbreVectorEntity).summaryType == summaryType.rawValue
    }).first as? TimbreVectorEntity
  }

  func setTimbreForSummaryType(newVector: TimbreVectorEntity, summaryType: SummaryType) {
    let timbresSet = self.mutableSetValueForKey("timbres")
    // Remove old timbre vector if necessary
    self.removeTimbreForSummaryType(timbresSet, summaryType: summaryType)

    // Set the summary type for the new vector and add it to the timbres set
    newVector.summaryType = summaryType.rawValue
    timbresSet.addObject(newVector)
  }

  func removeTimbreForSummaryType(timbresSet: NSMutableSet?, summaryType: SummaryType) {
    let timbresSet = timbresSet ?? self.mutableSetValueForKey("timbres")
    if let oldVector = self.getTimbreForSummaryType(summaryType) {
      // Remove the old vector for the summary type
      timbresSet.removeObject(oldVector)
    }
  }

  override class func getEntityName() -> String {
    return "Song"
  }

  override func awakeFromInsert() {
    super.awakeFromInsert()

    // Set default values for NSManaged properties
    dateAdded = NSDate()
  }
}