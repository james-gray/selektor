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

  override class func getEntityName() -> String {
    return "Label"
  }

  class func createOrFetchLabel(name: String, dc: DataController, inout labelsDict: [String: LabelEntity]) -> LabelEntity {
    var label: LabelEntity? = labelsDict[name]
    if label == nil {
      label = dc.createEntity() as LabelEntity
      label!.name = name
      labelsDict[name] = label
    }
    return label!
  }

  @NSManaged var name: String?
  @NSManaged var songs: NSSet?

}
