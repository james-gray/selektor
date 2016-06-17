//
//  ViewController.swift
//  Selektor
//
//  Created by James Gray on 2016-05-26.
//  Copyright © 2016 James Gray. All rights reserved.
//

import Cocoa

class ViewController: NSViewController {

  // MARK: Properties

  // Controller used by the table view for displaying songs in a list
  @IBOutlet var songsController: NSArrayController!

  // Data controller acts as the interface to the Core Data stack, allowing
  // interaction with the database.
  let dc = DataController()

  // Array of songs which will be used by the songsController for
  // populating the songs table view.
  var songs = [SongEntity]()

  override func viewDidLoad() {
    super.viewDidLoad()

    // Populate the songs array and attach to the songsController
    dispatch_async(dispatch_get_main_queue()) {
      self.songs = self.dc.fetchEntities()
      self.songsController.content = self.songs
    }
  }

  override var representedObject: AnyObject? {
    didSet {
    // Update the view, if already loaded.
    }
  }


}