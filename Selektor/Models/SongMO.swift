//
//  SongMO.swift
//  Selektor
//
//  Created by James Gray on 2016-05-28.
//  Copyright © 2016 James Gray. All rights reserved.
//

import Foundation
import CoreData

@objc(SongMO)
class SongMO: NSManagedObject, SelektorMO {

  static var entityName: String! = "Song"

  override func awakeFromInsert() {
    super.awakeFromInsert()

    // Set dateAdded to the current date on object creation
    dateAdded = NSDate()
  }

}
