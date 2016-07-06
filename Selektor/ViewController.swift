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
  @IBOutlet weak var selectNextTrackBtn: NSButton!

  @IBOutlet var bestNextSongController: NSObjectController!
  @IBOutlet weak var bestNextSongBox: NSBox!
  @IBOutlet weak var playNextSongBtn: NSButton!

  // MARK: Properties

  // Data controller acts as the interface to the Core Data stack, allowing
  // interaction with the database.
  let appDelegate = NSApplication.sharedApplication().delegate as! AppDelegate

  lazy var managedObjectContext: NSManagedObjectContext = {
    return (NSApplication.sharedApplication().delegate
      as? AppDelegate)?.dc.managedObjectContext
    }()!

  let mp = MetadataParser()
  var selektor = GrandSelektor()

  var localDc: DataController?

  var bestNextSong: SongEntity? = nil

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

    // Add observer to notify the view controller when the songs controller's
    // selection changes (so it can hide the suggested song UI elements)
    self.songsController.addObserver(
      self,
      forKeyPath: "selection",
      options:(NSKeyValueObservingOptions.New),
      context: nil
    )

    // Hide the suggested song UI elements at first
    self.bestNextSongBox.hidden = true
    self.playNextSongBtn.hidden = true

    // Populate the songs array and attach to the songsController
    dispatch_async(dispatch_get_main_queue()) {
      self.appDelegate.songs = self.appDelegate.dc.fetchEntities()
      self.songsController.content = self.appDelegate.songs

      if self.appDelegate.songs.count > 0 {
        self.analyzeSongs() // Process any un-analyzed songs
      }
    }
  }

  override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
    if keyPath == "selection" {
      self.bestNextSongBox.hidden = true
      self.playNextSongBtn.hidden = true

      // Hide the "Select Next Track" button when no / multiple songs are selected
      self.selectNextTrackBtn.hidden = self.songsController.selectionIndexes.count != 1
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
      self.songsController.content = self.appDelegate.songs
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

    self.appDelegate.songs.append(song)
  }

  func analyzeSongs() {
    // Serially analyze songs in the background
    let songsIdsToAnalyze = self.appDelegate.songs
        .filter { $0.analyzed != AnalysisState.Complete.rawValue } // Filter out analyzed songs
        .sort { Int($0.analyzed) > Int($1.analyzed) } // Sort such that "in progress" songs are analyzed first
        .map { $0.objectID } // Extract object IDs

    dispatch_async(dispatch_get_global_queue(Int(QOS_CLASS_BACKGROUND.rawValue), 0)) {
      // Set up a threadlocal data controller and store it in the current thread's dictionary.
      // This way when the SongEntity instance attempts to create a TimbreVectorEntity it will be
      // able to use the same managed object context as the SongEntity.
      let localMoc = NSManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
      localMoc.parentContext = self.managedObjectContext
      self.localDc = DataController(managedObjectContext: localMoc)
      NSThread.currentThread().threadDictionary.setObject(self.localDc!, forKey: "dc")

      for songId in songsIdsToAnalyze {
        let song = self.localDc!.managedObjectContext.objectWithID(songId) as! SongEntity
        if (song.managedObjectContext != nil) {
          song.analyze()
        }
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

  @IBAction func selectBestNextSong(sender: AnyObject) {
    let selectedSongs = self.songsController.selectedObjects as! [SongEntity]
    if selectedSongs.count > 1 {
      fatalError("selectBestNextSong called for multiple selected objects")
    }

    let song = selectedSongs[0]
    self.bestNextSong = selektor.selectSong(song)
    self.bestNextSongController.content = self.bestNextSong

    self.bestNextSongBox.hidden = false
    self.playNextSongBtn.hidden = false
  }

  @IBAction func playBestNextSong(sender: AnyObject) {
    self.bestNextSongBox.hidden = true
    self.playNextSongBtn.hidden = true

    guard let bestNextSong = self.bestNextSong else {
      fatalError("playBestNextSong called before a bestNextSong was selected!")
    }
    let indexSet = self.songsController.selectionIndexes
    self.songsController.removeSelectionIndexes(indexSet)
    self.songsController.addSelectedObjects([bestNextSong])
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