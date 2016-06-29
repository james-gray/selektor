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

  // MARK: Outlets

  @IBOutlet weak var songsTableView: NSTableView!
  @IBOutlet var songsController: NSArrayController!

  // MARK: Properties

  // Data controller acts as the interface to the Core Data stack, allowing
  // interaction with the database.
  let appDelegate = NSApplication.sharedApplication().delegate as! AppDelegate

  lazy var managedObjectContext: NSManagedObjectContext = {
    return (NSApplication.sharedApplication().delegate
      as? AppDelegate)?.dc.managedObjectContext
    }()!

  let mp = MetadataParser()

  // Array of songs which will be used by the songsController for
  // populating the songs table view.
  var songs = [SongEntity]()

  // Set of supported audio file extensions
  let validExtensions: Set<String> = ["mp3", "m4a", "wav", "m3u", "wma", "aif", "ogg"]

  // MARK: UI Elements
  lazy var openPanel: NSOpenPanel = {
    let openPanel = NSOpenPanel()
    openPanel.canChooseDirectories = true
    openPanel.canCreateDirectories = false
    openPanel.canChooseFiles = false
    openPanel.allowsMultipleSelection = false
    return openPanel
  }()

  lazy var deleteAlert: NSAlert = {
    let alert = NSAlert()
    alert.messageText = "Delete Songs"
    alert.addButtonWithTitle("Cancel")
    alert.addButtonWithTitle("Delete")
    return alert
  }()

  lazy var importProgressAlert: NSAlert = {
    let alert = NSAlert()
    alert.messageText = "Importing songs. Please wait..."
    return alert
  }()

  // MARK: Behaviour
  override func viewDidLoad() {
    super.viewDidLoad()

    // Populate the songs array and attach to the songsController
    dispatch_async(dispatch_get_main_queue()) {
      self.songs = self.appDelegate.dc.fetchEntities()
      self.songsController.content = self.songs
    }
  }

  func importMusicFolder(directoryURL: NSURL) {
    let fileMgr = NSFileManager.defaultManager()
    let options: NSDirectoryEnumerationOptions = [.SkipsHiddenFiles, .SkipsPackageDescendants]

    if let fileUrls = fileMgr.enumeratorAtURL(directoryURL, includingPropertiesForKeys: nil,
                                              options: options, errorHandler: nil) {
      for url in fileUrls {
        if self.validExtensions.contains(url.pathExtension) {
            self.importSong(url as! NSURL)
        }
      }

      // Persist changes to DB
      self.appDelegate.dc.save()

      // Update the table view by refreshing the array controller
      self.songsController.content = self.songs
      self.songsController.rearrangeObjects()
    }
  }

  func importSong(url: NSURL) {
    print("Importing song '\(url.absoluteString)'")
    let dc = appDelegate.dc

    let song: SongEntity = dc.createEntity()
    let asset = AVURLAsset(URL: url)
    let meta = mp.parse(asset)

    song.name = meta["name"] as? String ?? url.lastPathComponent
    song.filename = url.path
    song.tempo = meta["tempo"] as? Int ?? 0
    song.artist = meta["artist"] as? String ?? "Unknown Artist"
    song.album = meta["album"] as? String ?? "Unknown Album"
    song.genre = meta["genre"] as? String
    song.label = meta["label"] as? String
    song.key = meta["key"] as? String

    self.songs.append(song)
  }

  // MARK: Actions
  @IBAction func chooseMusicFolder(sender: AnyObject) {
    if self.openPanel.runModal() == NSFileHandlingPanelOKButton {

      dispatch_async(dispatch_get_main_queue()) {
        self.importProgressAlert.beginSheetModalForWindow(self.view.window!, completionHandler: nil)
        self.importMusicFolder(self.openPanel.URL!)
        self.view.window!.endSheet(self.importProgressAlert.window)
      }
      self.openPanel.close()
    }
  }

  @IBAction func handleSongRemove(sender: AnyObject) {
    dispatch_async(dispatch_get_main_queue()) {
      let selectedSongs = self.songsController.selectedObjects as! [SongEntity]

      if selectedSongs.count > 1 {
        self.deleteAlert.informativeText = "Are you sure you want to delete the selected songs?"
      } else {
        self.deleteAlert.informativeText = "Are you sure you want to delete the song '\(selectedSongs[0].name!)'?"
      }

      self.deleteAlert.beginSheetModalForWindow(self.view.window!, completionHandler: {
        (returnCode) -> Void in
        if returnCode == NSAlertSecondButtonReturn {
          self.songsController.removeObjectsAtArrangedObjectIndexes(self.songsController.selectionIndexes)
        }
      })
    }
  }
}