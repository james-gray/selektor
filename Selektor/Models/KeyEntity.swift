//
//  KeyEntity.swift
//  Selektor
//
//  Created by James Gray on 2016-05-28.
//  Copyright © 2016 James Gray. All rights reserved.
//

import Foundation
import CoreData

@objc(KeyEntity)
class KeyEntity: SelektorObject {

  // MARK: Properties
  @NSManaged var songs: SongEntity?

  override class func getEntityName() -> String {
    return "Key"
  }

  class func createOrFetchKey(name: String, dc: DataController, inout keysDict: [String: KeyEntity]) -> KeyEntity {
    return super.createOrFetchEntity(name, dc: dc, entityDict: &keysDict) as KeyEntity
  }

}
