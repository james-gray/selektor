//
//  ArtistEntity.swift
//  Selektor
//
//  Created by James Gray on 2016-05-28.
//  Copyright © 2016 James Gray. All rights reserved.
//

import Foundation
import CoreData

@objc(ArtistEntity)
class ArtistEntity: SelektorObject {

  // MARK: Properties
  @NSManaged var songs: NSSet?

  override class func getEntityName() -> String {
    return "Artist"
  }

  class func createOrFetchArtist(name: String, dc: DataController, inout artistsDict: [String: ArtistEntity]) -> ArtistEntity {
    return super.createOrFetchEntity(name, dc: dc, entityDict: &artistsDict) as ArtistEntity
  }
}