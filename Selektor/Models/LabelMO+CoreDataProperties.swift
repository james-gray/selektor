//
//  LabelMO+CoreDataProperties.swift
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

extension LabelMO {

    @NSManaged var name: String?
    @NSManaged var songs: NSSet?

}
