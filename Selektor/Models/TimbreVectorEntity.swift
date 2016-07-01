//
//  TimbreVector.swift
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
  @NSManaged var mammFlux: NSNumber?
  @NSManaged var mammMFCC: String?
  @NSManaged var mammRolloff: NSNumber?
  @NSManaged var masmCentroid: NSNumber?
  @NSManaged var masmFlux: NSNumber?
  @NSManaged var masmMFCC: String?
  @NSManaged var masmRolloff: NSNumber?
  @NSManaged var sammCentroid: NSNumber?
  @NSManaged var sammFlux: NSNumber?
  @NSManaged var sammMFCC: String?
  @NSManaged var sammRolloff: NSNumber?
  @NSManaged var sasmCentroid: NSNumber?
  @NSManaged var sasmFlux: NSNumber?
  @NSManaged var sasmMFCC: String?
  @NSManaged var sasmRolloff: NSNumber?
  @NSManaged var song: SongEntity?


}
