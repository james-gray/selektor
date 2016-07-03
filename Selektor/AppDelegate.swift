//
//  AppDelegate.swift
//  Selektor
//
//  Created by James Gray on 2016-05-26.
//  Copyright © 2016 James Gray. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

  let dc = DataController()

  override class func initialize() {
    let filenameTransformer = FilenameTransformer()
    let countTransformer = CountTransformer()
    NSValueTransformer.setValueTransformer(filenameTransformer, forName: "FilenameTransformer")
    NSValueTransformer.setValueTransformer(countTransformer, forName: "CountTransformer")
  }

  func applicationDidFinishLaunching(aNotification: NSNotification) {
    // Insert code here to initialize your application
  }

  func applicationWillTerminate(aNotification: NSNotification) {
    // Insert code here to tear down your application
    
  }

  lazy var managedObjectContext: NSManagedObjectContext = {
    return self.dc.managedObjectContext
  }()

  // MARK: - Core Data Saving and Undo support

  @IBAction func saveAction(sender: AnyObject!) {
    // Performs the save action for the application, which is to send the save: message to the application's managed object context. Any encountered errors are presented to the user.
    if !managedObjectContext.commitEditing() {
      NSLog("\(NSStringFromClass(self.dynamicType)) unable to commit editing before saving")
    }
    if managedObjectContext.hasChanges {
      do {
        try managedObjectContext.save()
      } catch {
        let nserror = error as NSError
        NSApplication.sharedApplication().presentError(nserror)
      }
    }
  }

  func windowWillReturnUndoManager(window: NSWindow) -> NSUndoManager? {
    // Returns the NSUndoManager for the application. In this case, the manager returned is that of the managed object context for the application.
    return managedObjectContext.undoManager
  }

  func applicationShouldTerminate(sender: NSApplication) -> NSApplicationTerminateReply {
    // Save changes in the application's managed object context before the application terminates.

    if !managedObjectContext.commitEditing() {
      NSLog("\(NSStringFromClass(self.dynamicType)) unable to commit editing to terminate")
      return .TerminateCancel
    }

    if !managedObjectContext.hasChanges {
      return .TerminateNow
    }

    do {
      try managedObjectContext.save()
    } catch {
      let nserror = error as NSError
      // Customize this code block to include application-specific recovery steps.
      let result = sender.presentError(nserror)
      if (result) {
        return .TerminateCancel
      }

      let question = NSLocalizedString("Could not save changes while quitting. Quit anyway?", comment: "Quit without saves error question message")
      let info = NSLocalizedString("Quitting now will lose any changes you have made since the last successful save", comment: "Quit without saves error question info");
      let quitButton = NSLocalizedString("Quit anyway", comment: "Quit anyway button title")
      let cancelButton = NSLocalizedString("Cancel", comment: "Cancel button title")
      let alert = NSAlert()
      alert.messageText = question
      alert.informativeText = info
      alert.addButtonWithTitle(quitButton)
      alert.addButtonWithTitle(cancelButton)

      let answer = alert.runModal()
      if answer == NSAlertFirstButtonReturn {
        return .TerminateCancel
      }
    }

    // If we got here, it is time to quit.
    return .TerminateNow
  }
}