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

  override class func getEntityName() -> String {
    return "Key"
  }

  @NSManaged var mode: ModeEntity?
  @NSManaged var note: NoteEntity?
  @NSManaged var songs: SongEntity?

}
