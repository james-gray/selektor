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

  override class func getEntityName() -> String {
    return "Artist"
  }

  class func createOrFetchArtist(name: String, dc: DataController, inout artistsDict: [String: ArtistEntity]) -> ArtistEntity {
    var artist: ArtistEntity? = artistsDict[name]
    if artist == nil {
      artist = dc.createEntity() as ArtistEntity
      artist!.name = name
      artistsDict[name] = artist
    }
    return artist!
  }

  @NSManaged var name: String?
  @NSManaged var songs: NSSet?

}
