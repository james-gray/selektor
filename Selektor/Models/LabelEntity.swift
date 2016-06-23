//
//  LabelEntity.swift
//  Selektor
//
//  Created by James Gray on 2016-05-28.
//  Copyright © 2016 James Gray. All rights reserved.
//

import Foundation
import CoreData

@objc(LabelEntity)
class LabelEntity: SelektorObject {

  // MARK: Properties
  @NSManaged var songs: NSSet?

  override class func getEntityName() -> String {
    return "Label"
  }

  class func createOrFetchLabel(name: String, dc: DataController, inout labelsDict: [String: LabelEntity]) -> LabelEntity {
    return super.createOrFetchEntity(name, dc: dc, entityDict: &labelsDict) as LabelEntity
  }
}
