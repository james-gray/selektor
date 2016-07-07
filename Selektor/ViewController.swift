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

  @IBOutlet var tracksController: NSArrayController!
  @IBOutlet var bestNextTrackController: NSObjectController!

  @IBOutlet weak var tracksTableView: NSTableView!
  @IBOutlet weak var selectNextTrackBtn: NSButton!
  @IBOutlet weak var bestNextTrackBox: NSBox!
  @IBOutlet weak var playNextTrackBtn: NSButton!

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

  var bestNextTrack: TrackEntity? = nil

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
    alert.messageText = "Delete Tracks"
    alert.addButtonWithTitle("Cancel")
    alert.addButtonWithTitle("Delete")
    return alert
  }()

  lazy var importProgressAlert: NSAlert = {
    let alert = NSAlert()
    alert.messageText = "Importing tracks. Please wait..."
    return alert
  }()

  // MARK: Behaviour
  override func viewDidLoad() {
    super.viewDidLoad()

    // Add observer to notify the view controller when the tracks controller's
    // selection changes (so it can hide the suggested track UI elements)
    self.tracksController.addObserver(
      self,
      forKeyPath: "selection",
      options:(NSKeyValueObservingOptions.New),
      context: nil
    )

    // Hide the suggested track UI elements at first
    self.bestNextTrackBox.hidden = true
    self.playNextTrackBtn.hidden = true

    // Populate the tracks array and attach to the tracksController
    dispatch_async(dispatch_get_main_queue()) {
      self.appDelegate.tracks = self.appDelegate.dc.fetchEntities()
      self.tracksController.content = self.appDelegate.tracks

      if self.appDelegate.tracks.count > 0 {
        self.analyzeTracks() // Process any un-analyzed tracks
      }
    }
  }

  override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
    if keyPath == "selection" {
      self.bestNextTrackBox.hidden = true
      self.playNextTrackBtn.hidden = true

      // Hide the "Select Next Track" button when no / multiple tracks are selected
      self.selectNextTrackBtn.hidden = self.tracksController.selectionIndexes.count != 1
    }
  }

  func importMusicFolder(directoryURL: NSURL) {
    let fileMgr = self.appDelegate.fileManager
    let options: NSDirectoryEnumerationOptions = [.SkipsHiddenFiles, .SkipsPackageDescendants]

    if let fileUrls = fileMgr.enumeratorAtURL(directoryURL, includingPropertiesForKeys: nil,
                                              options: options, errorHandler: nil) {
      for url in fileUrls {
        if self.validExtensions.contains(url.pathExtension) {
            self.importTrack(url as! NSURL)
        }
      }

      // Persist changes to DB
      self.appDelegate.dc.save()

      // Update the table view by refreshing the array controller
      self.tracksController.content = self.appDelegate.tracks
      self.tracksController.rearrangeObjects()
    }
  }

  func importTrack(url: NSURL) {
    print("Importing track '\(url.absoluteString)'")
    let dc = self.appDelegate.dc

    let track: TrackEntity = dc.createEntity()
    let asset = AVURLAsset(URL: url)
    let meta = mp.parse(asset)

    track.name = meta["name"] as? String ?? url.lastPathComponent
    track.filename = url.path
    track.tempo = meta["tempo"] as? Int ?? 0
    track.duration = Int(asset.duration.seconds)
    track.artist = meta["artist"] as? String ?? "Unknown Artist"
    track.album = meta["album"] as? String ?? "Unknown Album"
    track.genre = meta["genre"] as? String
    track.key = meta["key"] as? String

    self.appDelegate.tracks.append(track)
  }

  func analyzeTracks() {
    // Serially analyze tracks in the background
    let tracksIdsToAnalyze = self.appDelegate.tracks
        .filter { $0.analyzed != AnalysisState.complete.rawValue } // Filter out analyzed tracks
        .sort { Int($0.analyzed) > Int($1.analyzed) } // Sort such that "in progress" tracks are analyzed first
        .map { $0.objectID } // Extract object IDs

    dispatch_async(dispatch_get_global_queue(Int(QOS_CLASS_BACKGROUND.rawValue), 0)) {
      // Set up a threadlocal data controller and store it in the current thread's dictionary.
      // This way when the TrackEntity instance attempts to create a TimbreVectorEntity it will be
      // able to use the same managed object context as the TrackEntity.
      let localMoc = NSManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
      localMoc.parentContext = self.managedObjectContext
      self.localDc = DataController(managedObjectContext: localMoc)
      NSThread.currentThread().threadDictionary.setObject(self.localDc!, forKey: "dc")

      for trackId in tracksIdsToAnalyze {
        let track = self.localDc!.managedObjectContext.objectWithID(trackId) as! TrackEntity
        if (track.managedObjectContext != nil) {
          track.analyze()
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
        self.analyzeTracks()
      }
      self.openPanel.close()
    }
  }

  @IBAction func selectBestNextTrack(sender: AnyObject) {
    let selectedTracks = self.tracksController.selectedObjects as! [TrackEntity]
    if selectedTracks.count > 1 {
      fatalError("selectBestNextTrack called for multiple selected objects")
    }

    let track = selectedTracks[0]
    self.bestNextTrack = selektor.selectTrack(track)
    self.bestNextTrackController.content = self.bestNextTrack

    self.bestNextTrackBox.hidden = false
    self.playNextTrackBtn.hidden = false
  }

  @IBAction func playBestNextTrack(sender: AnyObject) {
    self.bestNextTrackBox.hidden = true
    self.playNextTrackBtn.hidden = true

    guard let bestNextTrack = self.bestNextTrack else {
      fatalError("playBestNextTrack called before a bestNextTrack was selected!")
    }
    let indexSet = self.tracksController.selectionIndexes
    self.tracksController.removeSelectionIndexes(indexSet)
    self.tracksController.addSelectedObjects([bestNextTrack])
  }

  @IBAction func handleTrackRemove(sender: AnyObject) {
      let selectedTracks = self.tracksController.selectedObjects as! [TrackEntity]

      if selectedTracks.count > 1 {
        self.deleteAlert.informativeText = "Are you sure you want to delete the selected tracks?"
      } else {
        self.deleteAlert.informativeText = "Are you sure you want to delete the track '\(selectedTracks[0].name!)'?"
      }

    dispatch_async(dispatch_get_main_queue()) {
      self.deleteAlert.beginSheetModalForWindow(self.view.window!, completionHandler: {
        (returnCode) -> Void in
        if returnCode == NSAlertSecondButtonReturn {
          self.tracksController.removeObjectsAtArrangedObjectIndexes(self.tracksController.selectionIndexes)
          self.appDelegate.dc.save()
        }
      })
    }
  }
}
