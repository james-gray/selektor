//
//  SongEntity.swift
//  Selektor
//
//  Created by James Gray on 2016-05-28.
//  Copyright © 2016 James Gray. All rights reserved.
//

import Foundation
import CoreData
import Cocoa

@objc(SongEntity)
class SongEntity: SelektorObject {

  // MARK: Properties
  @NSManaged dynamic var dateAdded: NSDate?
  @NSManaged dynamic var duration: NSNumber?
  @NSManaged dynamic var filename: String?
  @NSManaged dynamic var loudness: NSNumber?
  @NSManaged dynamic var tempo: NSNumber?
  @NSManaged dynamic var album: AlbumEntity?
  @NSManaged dynamic var artist: ArtistEntity?
  @NSManaged dynamic var genre: GenreEntity?
  @NSManaged dynamic var key: KeyEntity?
  @NSManaged dynamic var label: LabelEntity?

  override class func getEntityName() -> String {
    return "Song"
  }

  override func awakeFromInsert() {
    super.awakeFromInsert()

    // Set dateAdded to the current date on object creation
    dateAdded = NSDate()
  }

}