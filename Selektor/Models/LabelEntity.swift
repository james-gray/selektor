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
  @NSManaged var name: String?
  @NSManaged var songs: NSSet?

  override class func getEntityName() -> String {
    return "Label"
  }

  class func createOrFetchLabel(name: String, dc: DataController, inout labelsDict: [String: LabelEntity]) -> LabelEntity {
    guard let label = labelsDict[name] else {
      let label: LabelEntity = dc.createEntity()
      label.name = name
      labelsDict[name] = label
      return label
    }
    return label
  }
}
