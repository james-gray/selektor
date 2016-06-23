//
//  DataController.swift
//  Selektor
//
//  Created by James Gray on 2016-05-28.
//  Copyright © 2016 James Gray. All rights reserved.
//

import CoreData

class DataController: NSObject {
  // Based on sample code provided by Apple at:
  // developer.apple.com/library/mac/documentation/Cocoa/Conceptual/CoreData/
  //     InitializingtheCoreDataStack.html#//apple_ref/doc/uid/TP40001075-CH4-SW1
  //
  // Copyright © 2016 Apple Inc. All rights reserved.
  var managedObjectContext: NSManagedObjectContext
  
  override init() {
    let dbName = "Selektor"

    guard let modelURL = NSBundle.mainBundle().URLForResource(dbName,
        withExtension: "momd") else {
      fatalError("Error loading model from bundle.")
    }
    
    // The managed object model for the application. It is a fatal error for the
    // application not to be able to find and load its model.
    guard let mom = NSManagedObjectModel(contentsOfURL: modelURL) else {
      fatalError("Error initializing mom from: \(modelURL)")
    }
    
    let psc = NSPersistentStoreCoordinator(managedObjectModel: mom)

    managedObjectContext = NSManagedObjectContext(
        concurrencyType: .MainQueueConcurrencyType
    )
    managedObjectContext.persistentStoreCoordinator = psc
    managedObjectContext.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy

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
        try psc.addPersistentStoreWithType(NSSQLiteStoreType, configuration: nil,
            URL: storeURL, options: nil)
      } catch {
        fatalError("Error migrating store: \(error)")
      }
    }
  }

  func createEntity<T: SelektorObject>() -> T {
    return NSEntityDescription.insertNewObjectForEntityForName(T.getEntityName(),
        inManagedObjectContext: managedObjectContext) as! T
  }

  func fetchEntities<T: SelektorObject>(predicate: String? = nil) -> [T] {

    let moc = managedObjectContext
    let entityName = T.getEntityName()
    let fetchRequest = NSFetchRequest(entityName: entityName)

    if let predicate = predicate {
      // Filter the results
      fetchRequest.predicate = NSPredicate(format: predicate)
    }

    do {
      let fetchedObjects = try moc.executeFetchRequest(fetchRequest) as! [T]
      return fetchedObjects
    } catch {
      fatalError("Failed to fetch \(entityName)s: \(error)")
    }
  }

  func save() {
    do {
      try managedObjectContext.save()
    } catch {
      fatalError("Failure to save context: \(error)")
    }
  }
}
