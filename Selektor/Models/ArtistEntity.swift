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
  @NSManaged var name: String?
  @NSManaged var songs: NSSet?

  override class func getEntityName() -> String {
    return "Artist"
  }

  class func createOrFetchArtist(name: String, dc: DataController, inout artistsDict: [String: ArtistEntity]) -> ArtistEntity {
    guard let artist = artistsDict[name] else {
      let artist: ArtistEntity = dc.createEntity()
      artist.name = name
      artistsDict[name] = artist
      return artist
    }
    return artist
  }
}