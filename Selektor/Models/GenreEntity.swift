//
//  GenreEntity.swift
//  Selektor
//
//  Created by James Gray on 2016-05-28.
//  Copyright © 2016 James Gray. All rights reserved.
//

import Foundation
import CoreData

@objc(GenreEntity)
class GenreEntity: SelektorObject {

  override class func getEntityName() -> String {
    return "Genre"
  }

  @NSManaged var name: String?
  @NSManaged var songs: NSSet?

}
