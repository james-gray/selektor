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
  let validExtensions: Set<String> = ["wav", "mp3", "m4a", "m3u", "wma", "aif", "ogg"]

  let mirexPath: String? = NSBundle.mainBundle().pathForResource("mirex_extract", ofType: nil, inDirectory: "Lib/marsyas/bin")
  let ffmpegPath: String? = NSBundle.mainBundle().pathForResource("ffmpeg", ofType: nil, inDirectory: "Lib/ffmpeg")

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
      if self.songs.count > 0 {
        self.analyzeSongs() // Process any un-analyzed songs
      }
    }
  }

  func importMusicFolder(directoryURL: NSURL) {
    let fileMgr = self.appDelegate.fileManager
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
    let dc = self.appDelegate.dc

    let song: SongEntity = dc.createEntity()
    let asset = AVURLAsset(URL: url)
    let meta = mp.parse(asset)

    song.name = meta["name"] as? String ?? url.lastPathComponent
    song.filename = url.path
    song.tempo = meta["tempo"] as? Int ?? 0
    song.duration = Int(asset.duration.seconds)
    song.artist = meta["artist"] as? String ?? "Unknown Artist"
    song.album = meta["album"] as? String ?? "Unknown Album"
    song.genre = meta["genre"] as? String
    song.key = meta["key"] as? String

    self.songs.append(song)
  }

  func analyzeSongs() {
    let songsToAnalyze = self.songs.filter { $0.analyzed != AnalysisState.Complete.rawValue }.splitBy(10)

    // Serially analyze groups of ten songs at a time concurrently in the background.
    // i.e., up to 10 songs will be analyzed concurrently at any given time, but the
    // current 10 must all finish analyzing before the next 10 begin. This should be
    // slightly faster than analyzing the songs serially.
    dispatch_async(dispatch_get_global_queue(Int(QOS_CLASS_USER_INITIATED.rawValue), 0)) {
      let analysisTaskGroup = dispatch_group_create()

      for subgroup in songsToAnalyze {
        // dispatch_apply acts similar to a for loop, but it executes each iteration
        // of the loop concurrently - the body of its closure (one iteration of the
        // 'loop') is an asynchronous task. This allows for each song in the subgroup
        // to be analyzed concurrently.
        let songIds = subgroup.map { $0.objectID }
        dispatch_apply(songIds.count, dispatch_get_global_queue(Int(QOS_CLASS_BACKGROUND.rawValue), 0)) {
          i in
          dispatch_group_enter(analysisTaskGroup)

          // Set up a threadlocal data controller and store it in the current thread's dictionary.
          // This way when the SongEntity instance attempts to create a TimbreVectorEntity it will be
          // able to use the same managed object context as the SongEntity.
          let localDc = DataController()
          localDc.managedObjectContext = NSManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
          localDc.managedObjectContext.parentContext = self.managedObjectContext
          NSThread.currentThread().threadDictionary.setObject(localDc, forKey: "dc")

          let songId = songIds[Int(i)]
          let song = localDc.managedObjectContext.objectWithID(songId) as! SongEntity
          if (song.managedObjectContext != nil) {
            song.analyze()
          }
          dispatch_group_leave(analysisTaskGroup)
        }

        // Wait for the analysis of the current subgroup of songs to finish before
        // saving the context and analyzing the next group
        dispatch_group_wait(analysisTaskGroup, DISPATCH_TIME_FOREVER)
      }
    }
  }

  // MARK: Actions
  @IBAction func chooseMusicFolder(sender: AnyObject) {
    dispatch_async(dispatch_get_main_queue()) {
      if self.openPanel.runModal() == NSFileHandlingPanelOKButton {
        self.importProgressAlert.beginSheetModalForWindow(self.view.window!, completionHandler: nil)
        self.importMusicFolder(self.openPanel.URL!)
        self.view.window!.endSheet(self.importProgressAlert.window)
        self.analyzeSongs()
      }
      self.openPanel.close()
    }
  }

  @IBAction func handleSongRemove(sender: AnyObject) {
      let selectedSongs = self.songsController.selectedObjects as! [SongEntity]

      if selectedSongs.count > 1 {
        self.deleteAlert.informativeText = "Are you sure you want to delete the selected songs?"
      } else {
        self.deleteAlert.informativeText = "Are you sure you want to delete the song '\(selectedSongs[0].name!)'?"
      }

    dispatch_async(dispatch_get_main_queue()) {
      self.deleteAlert.beginSheetModalForWindow(self.view.window!, completionHandler: {
        (returnCode) -> Void in
        if returnCode == NSAlertSecondButtonReturn {
          self.songsController.removeObjectsAtArrangedObjectIndexes(self.songsController.selectionIndexes)
          self.appDelegate.dc.save()
        }
      })
    }
  }
}