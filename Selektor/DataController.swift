//
//  DataController.swift
//  Selektor
//
//  Created by James Gray on 2016-05-28.
//  Copyright © 2016 James Gray. All rights reserved.
//

import CoreData

/**
    This class acts as a mediator between the application and the Core Data store.

    Based on sample code provided by Apple at:
    developer.apple.com/library/mac/documentation/Cocoa/Conceptual/CoreData/
    InitializingtheCoreDataStack.html#//apple_ref/doc/uid/TP40001075-CH4-SW1

    Copyright © 2016 Apple Inc. All rights reserved.
*/
class DataController {

  var managedObjectContext: NSManagedObjectContext
  var persistentStoreCoordinator: NSPersistentStoreCoordinator? = nil

  /**
      Set up the Core Data stack.
  */
  init(managedObjectContext: NSManagedObjectContext? = nil) {
    let dbName = "Selektor"

    guard let modelURL = NSBundle.mainBundle().URLForResource(dbName,
        withExtension: "momd") else {
      fatalError("Error loading model from bundle.")
    }

    // The managed object model for the application. It is a fatal error for the
    // application not to be able to find and load its model.
    guard let managedObjectModel = NSManagedObjectModel(contentsOfURL: modelURL) else {
      fatalError("Error initializing managedObjectModel from: \(modelURL)")
    }

    if managedObjectContext != nil {
      self.managedObjectContext = managedObjectContext!
    } else {
      self.managedObjectContext = NSManagedObjectContext(
        concurrencyType: .MainQueueConcurrencyType
      )
      self.persistentStoreCoordinator = NSPersistentStoreCoordinator(managedObjectModel: managedObjectModel)
      self.managedObjectContext.persistentStoreCoordinator = persistentStoreCoordinator
      self.managedObjectContext.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
    }

    // Add persistent store only if this is the first (i.e. global) DataController with the
    // managed object context for the main thread, as we only need one persistent store
    // coordinator per application.
    if self.persistentStoreCoordinator != nil {
      dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0)) {
        let urls = NSFileManager.defaultManager().URLsForDirectory(
            .DocumentDirectory,
            inDomains: .UserDomainMask
        )
        let docURL = urls[urls.endIndex-1]

        // The directory the application uses to store the Core Data store file.
        // This code uses a file named "DataModel.sqlite" in the application's
        // documents directory.
        let storeURL = docURL.URLByAppendingPathComponent(dbName + ".sqlite")
        do {
          try self.persistentStoreCoordinator!.addPersistentStoreWithType(NSSQLiteStoreType, configuration: nil,
              URL: storeURL, options: nil)
        } catch {
          fatalError("Error migrating store: \(error)")
        }
      }
    }
  }

  /**
      Create a new entity of type `T`, where `T` is a `SelektorObject` subclass.

      Example:

          let track: TrackEntity = dataController.createEntity() // create a `TrackEntity`

      - returns: A new managed object instance of type `T`.
  */
  func createEntity<T: SelektorObject>() -> T {
    return NSEntityDescription.insertNewObjectForEntityForName(T.getEntityName(),
        inManagedObjectContext: managedObjectContext) as! T
  }

  /**
      Fetch entities of type `T`, where `T` is a `SelektorObject` subclass.

      Example:

          let tracks: [TrackEntity] = dataController.fetchEntities()

      - parameter predicate: Optional `NSPredicate` to filter the results.

      - returns: An array of managed objects of type `T`.
  */
  func fetchEntities<T: SelektorObject>(predicate: NSPredicate? = nil) -> [T] {
    let managedObjectContext = self.managedObjectContext
    let entityName = T.getEntityName()
    let fetchRequest = NSFetchRequest(entityName: entityName)

    if let predicate = predicate {
      // Filter the results
      fetchRequest.predicate = predicate
    }

    do {
      let fetchedObjects = try managedObjectContext.executeFetchRequest(fetchRequest) as! [T]
      return fetchedObjects
    } catch {
      fatalError("Failed to fetch \(entityName)s: \(error)")
    }
  }

  /**
      Save the managed object context.
  */
  func save() {
    do {
      try managedObjectContext.save()
    } catch {
      fatalError("Failure to save context: \(error)")
    }
  }
}
