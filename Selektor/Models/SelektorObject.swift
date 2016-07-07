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

  let appDelegate = NSApplication.sharedApplication().delegate as! AppDelegate

  /**
      Return a threadlocal DataController if one has been configured, otherwise use the AppDelegate's
      DataController.
  */
  lazy var dataController: DataController = {
    let currentThread = NSThread.currentThread()
    let td = currentThread.threadDictionary
    let dc = td.valueForKey("dc") as? DataController ?? (NSApplication.sharedApplication().delegate
      as? AppDelegate)?.dataController
    return dc!
  }()

  // XXX: Hack due to Swift's lack of support for class vars as of yet.
  // A `class func` is effectively equivalent to a `static func`, but can be
  // overridden by subclasses (unlike static funcs.)
  // Similarly, `static var`s cannot be overridden (and `class vars` don't exist)
  // so we must use a getter method instead.
  class func getEntityName() -> String {
    print("Subclasses should override abstract method `getEntityName`!")
    abort()
  }
}