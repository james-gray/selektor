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

  @NSManaged var name: String?
  @NSManaged var songs: NSSet?

}
