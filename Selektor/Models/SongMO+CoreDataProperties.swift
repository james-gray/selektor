//
//  SongMO+CoreDataProperties.swift
//  Selektor
//
//  Created by James Gray on 2016-05-28.
//  Copyright © 2016 James Gray. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

import Foundation
import CoreData

extension SongMO {

    @NSManaged var dateAdded: NSDate?
    @NSManaged var duration: NSNumber?
    @NSManaged var filename: String?
    @NSManaged var loudness: NSNumber?
    @NSManaged var tempo: NSNumber?
    @NSManaged var title: String?
    @NSManaged var album: AlbumMO?
    @NSManaged var artist: ArtistMO?
    @NSManaged var genre: GenreMO?
    @NSManaged var key: KeyMO?
    @NSManaged var label: LabelMO?

}
