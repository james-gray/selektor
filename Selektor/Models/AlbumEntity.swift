//
//  AlbumEntity.swift
//  Selektor
//
//  Created by James Gray on 2016-05-28.
//  Copyright © 2016 James Gray. All rights reserved.
//

import Foundation
import CoreData

@objc(AlbumEntity)
class AlbumEntity: SelektorObject {

  override class func getEntityName() -> String {
    return "Album"
  }

  class func createOrFetchAlbum(name: String, dc: DataController, inout albumsDict: [String: AlbumEntity]) -> AlbumEntity {
    var album: AlbumEntity? = albumsDict[name]
    if album == nil {
      album = dc.createEntity() as AlbumEntity
      album!.name = name
      albumsDict[name] = album
    }
    return album!
  }


  @NSManaged var name: String?
  @NSManaged var songs: NSSet?

}
