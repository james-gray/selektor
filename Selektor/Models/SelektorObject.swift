//
//  SelektorObject.swift
//  Selektor
//
//  Created by James Gray on 2016-05-28.
//  Copyright © 2016 James Gray. All rights reserved.

import Foundation
import CoreData
import Cocoa

// Subclass of NSManagedObject that entity classes should subclass for the purpose
// of exposing their entity names to the DataController via the `getEntityName` method.
// NOTE: This could also be accomplished with an NSManagedObject extension, however
// I've opted to simply subclass NSManagedObject in case I need other common
// functionality that only makes sense within the context of this app.
@objc(SelektorObject)
class SelektorObject: NSManagedObject {

  // MARK: Properties
  @NSManaged var name: String?

  let delegate = NSApplication.sharedApplication().delegate as! AppDelegate

  // XXX: Hack due to Swift's lack of support for class vars as of yet.
  // A `class func` is effectively equivalent to a `static func`, but can be
  // overridden by subclasses (unlike static funcs.)
  // Similarly, `static var`s cannot be overridden (and `class vars` don't exist)
  // so we must use a getter method instead.
  class func getEntityName() -> String {
    print("Subclasses should override abstract method `getEntityName`!")
    abort()
  }

  class func createOrFetchEntity<T: SelektorObject>(name: String, dc: DataController, inout entityDict: [String: T]) -> T {
    // First check the memoization dictionary for the desired entity
    if let entity: T = entityDict[name] {
      return entity
    }

    // If the entity is not in the dict, check the database
    let predicate = NSPredicate(format: "self.name = %@", name)
    guard let entity: T = dc.fetchEntities(predicate).first else {
      // Create the entity if it does not exist in the DB
      let entity: T = dc.createEntity()
      entity.name = name
      entityDict[name] = entity // Memoize the newly created entity
      return entity
    }

    entityDict[name] = entity // Memoize the fetched entity
    return entity
  }
}