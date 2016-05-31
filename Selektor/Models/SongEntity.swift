//
//  SongEntity.swift
//  Selektor
//
//  Created by James Gray on 2016-05-28.
//  Copyright © 2016 James Gray. All rights reserved.
//

import Foundation
import CoreData

@objc(SongEntity)
class SongEntity: SelektorObject {

  override class func getEntityName() -> String {
    return "Song"
  }

  @NSManaged var dateAdded: NSDate?
  @NSManaged var duration: NSNumber?
  @NSManaged var filename: String?
  @NSManaged var loudness: NSNumber?
  @NSManaged var tempo: NSNumber?
  @NSManaged var title: String?
  @NSManaged var album: AlbumEntity?
  @NSManaged var artist: ArtistEntity?
  @NSManaged var genre: GenreEntity?
  @NSManaged var key: KeyEntity?
  @NSManaged var label: LabelEntity?

  override func awakeFromInsert() {
    super.awakeFromInsert()

    // Set dateAdded to the current date on object creation
    dateAdded = NSDate()
  }

}
