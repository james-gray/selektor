//
//  ViewController.swift
//  Selektor
//
//  Created by James Gray on 2016-05-26.
//  Copyright © 2016 James Gray. All rights reserved.
//

import AVFoundation
import Cocoa

class ViewController: NSViewController {

  // MARK: Properties

  // Controller used by the table view for displaying songs in a list
  @IBOutlet var songsController: NSArrayController!

  // Data controller acts as the interface to the Core Data stack, allowing
  // interaction with the database.
  let dc = DataController()
  let mp = MetadataParser()

  // Array of songs which will be used by the songsController for
  // populating the songs table view.
  var songs = [SongEntity]()

  let validExtensions: Set<String> = ["mp3", "m4a", "wav", "m3u", "wma", "aif", "ogg"]

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

  func importSong(url: NSURL) {
    print("Importing song '\(url.absoluteString)'")

    var song: SongEntity = dc.createEntity()

    let asset = AVURLAsset(URL: url)
    var meta = mp.parse(asset)
    print("\(meta)")
    // TODO: Add metadata to the song entity
  }

  @IBAction func chooseMusicFolder(sender: AnyObject) {
    let openPanel = NSOpenPanel()
    openPanel.canChooseDirectories = true
    openPanel.canCreateDirectories = false
    openPanel.canChooseFiles = false
    openPanel.allowsMultipleSelection = false

    openPanel.beginWithCompletionHandler { (result) -> Void in
      if result == NSFileHandlingPanelOKButton {
        guard let directoryURL = openPanel.URL else {
          fatalError("Invalid directory specified")
        }

        let fileMgr = NSFileManager.defaultManager()
        let options: NSDirectoryEnumerationOptions = [.SkipsHiddenFiles, .SkipsPackageDescendants]

        if let fileUrls = fileMgr.enumeratorAtURL(directoryURL, includingPropertiesForKeys: nil,
            options: options, errorHandler: nil) {
          for url in fileUrls {
            if self.validExtensions.contains(url.pathExtension) {
              self.importSong(url as! NSURL)
            }
          }
        }
      }
    }
  }
}