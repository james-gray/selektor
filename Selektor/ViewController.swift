//
//  ViewController.swift
//  Selektor
//
//  Created by James Gray on 2016-05-26.
//  Copyright © 2016 James Gray. All rights reserved.
//

import AVFoundation
import Cocoa

/// The main view controller for the application.
class ViewController: NSViewController {

  /// The tracks array controller which manages tracks for the table view.
  @IBOutlet var tracksController: NSArrayController!
  
  /// The object controller which populates the "best next track" box detail view.
  @IBOutlet var bestNextTrackController: NSObjectController!
  var bestNextTrack: TrackEntity? = nil

  /// The table view that displays the user's tracks.
  @IBOutlet weak var tracksTableView: NSTableView!
  
  /// "Select My Next Track!" button.
  @IBOutlet weak var selectNextTrackBtn: NSButton!
  
  /// The "best next track" box detail view.
  @IBOutlet weak var bestNextTrackBox: NSBox!
  
  /// The "Play This Track" button, which will change the suggested track to the
  /// currently playing track.
  @IBOutlet weak var playNextTrackBtn: NSButton!

  let metadataParser = MetadataParser()
  let selektor = GrandSelektor()

  // MARK: Convenience properties
  let appDelegate = NSApplication.sharedApplication().delegate as! AppDelegate
  lazy var managedObjectContext: NSManagedObjectContext = {
    return (NSApplication.sharedApplication().delegate
      as? AppDelegate)?.dataController.managedObjectContext
    }()!

  // Set of supported audio file extensions
  let validExtensions: Set<String> = ["wav", "mp3", "m4a"]


  // MARK: UI Elements

  /// The `NSOpenPanel` that allows the user to import a folder of tracks.
  lazy var openPanel: NSOpenPanel = {
    let openPanel = NSOpenPanel()
    openPanel.canChooseDirectories = true
    openPanel.canCreateDirectories = false
    openPanel.canChooseFiles = false
    openPanel.allowsMultipleSelection = false
    return openPanel
  }()

  /// The confirmation alert presented to the user on deletion of tracks.
  lazy var deleteAlert: NSAlert = {
    let alert = NSAlert()
    alert.messageText = "Delete Tracks"
    alert.addButtonWithTitle("Cancel")
    alert.addButtonWithTitle("Delete")
    return alert
  }()

  /// An alert displayed to the user while tracks are being imported.
  lazy var importProgressAlert: NSAlert = {
    let alert = NSAlert()
    alert.messageText = "Importing tracks. Please wait..."
    return alert
  }()


  // MARK: Behavior

  /**
      Shows the "best next track" UI box detail view and button.
  */
  func showSuggestedTrackElements() {
    self.bestNextTrackBox.hidden = false
    self.playNextTrackBtn.hidden = false
  }

  /**
      Hides the "best next track" UI box detail view and button.
  */
  func hideSuggestedTrackElements() {
    self.bestNextTrackBox.hidden = true
    self.playNextTrackBtn.hidden = true
  }

  /**
      Performs necessary app initialization work on application load.
  */
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

    self.hideSuggestedTrackElements()

    // Populate the tracks array and attach to the tracksController
    dispatch_async(dispatch_get_main_queue()) {
      self.appDelegate.tracks = self.appDelegate.dataController.fetchEntities()
      self.tracksController.content = self.appDelegate.tracks

      if self.appDelegate.tracks.count > 0 {
        // Process any un-analyzed tracks
        self.analyzeTracks()
      }
    }
  }

  /**
      Observes when the selection changes and shows/hides UI elements as needed.
  */
  override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
    if keyPath == "selection" {
      self.hideSuggestedTrackElements()

      // Hide the "Select Next Track" button when no / multiple tracks are selected
      self.selectNextTrackBtn.hidden = self.tracksController.selectionIndexes.count != 1
    }
  }

  /**
      Imports a folder of tracks into the database, creating `TrackEntity` objects
      for all songs and using them populating the `tracksController`'s content array.

      - parameter folderURL: The URL of the directory to import.
  */
  func importMusicFolder(folderURL: NSURL) {
    let fileManager = NSFileManager.defaultManager()
    let options: NSDirectoryEnumerationOptions = [.SkipsHiddenFiles, .SkipsPackageDescendants]

    if let fileUrls = fileManager.enumeratorAtURL(folderURL,
        includingPropertiesForKeys: nil, options: options, errorHandler: nil) {
      for url in fileUrls {
        // Import all tracks with valid file extensions
        if self.validExtensions.contains(url.pathExtension) {
            self.importTrack(url as! NSURL)
        }
      }

      // Persist changes to the database
      self.appDelegate.dataController.save()

      // Update the table view by refreshing the array controller
      self.tracksController.content = self.appDelegate.tracks
      self.tracksController.rearrangeObjects()
    }
  }

  /**
      Import the track at `url` by creating a `TrackEntity` object and populating
      the values of its properties as needed with the parsed metadata from the
      audio file at `url` before adding the track to the application's tracks array.
  */
  func importTrack(url: NSURL) {
    print("Importing track '\(url.absoluteString)'")
    let dc = self.appDelegate.dataController

    let track: TrackEntity = dc.createEntity()
    let asset = AVURLAsset(URL: url)
    let meta = metadataParser.parse(asset)

    // Use the filename as the track title if no title is present in the meta
    track.name = meta["name"] as? String ?? url.lastPathComponent
    track.filename = url.path
    track.tempo = meta["tempo"] as? Int ?? 0
    track.duration = Int(asset.duration.seconds)
    track.artist = meta["artist"] as? String
    track.album = meta["album"] as? String
    track.genre = meta["genre"] as? String

    self.appDelegate.tracks.append(track)
  }

  /**
      Analyzes any tracks in the application's tracks array that are not yet analyzed.
      Analysis happens serially (i.e. tracks are analyzed one at a time) but analysis
      is performed in the background so the user can still interact with the GUI.
  */
  func analyzeTracks() {
    // Filter out analyzed tracks, sort the tracks such that "in progress" tracks
    // are analyzed first, then extract the managed object IDs from the tracks.
    let tracksIdsToAnalyze = self.appDelegate.tracks
        .filter { $0.analyzed != AnalysisState.complete.rawValue }
        .sort { Int($0.analyzed) > Int($1.analyzed) }
        .map { $0.objectID }

    dispatch_async(dispatch_get_global_queue(Int(QOS_CLASS_BACKGROUND.rawValue), 0)) {
      // Set up a threadlocal data controller and store it in the current thread's dictionary.
      // Private threads cannot use the main thread's managed object context.
      let localMoc = NSManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
      localMoc.parentContext = self.managedObjectContext
      let localDc = DataController(managedObjectContext: localMoc)
      NSThread.currentThread().threadDictionary.setObject(localDc, forKey: "dc")

      for trackId in tracksIdsToAnalyze {
        let track = localDc.managedObjectContext.objectWithID(trackId) as! TrackEntity
        if (track.managedObjectContext != nil) {
          track.analyze()
        }
      }
    }
  }

  // MARK: Actions

  /**
      Presents the open panel as a modal to allow the user to select a folder of
      songs to import.
  
      - parameter sender: The object that called this action.
  */
  @IBAction func chooseMusicFolder(sender: AnyObject) {
    dispatch_async(dispatch_get_main_queue()) {
      if self.openPanel.runModal() == NSFileHandlingPanelOKButton {
        self.importProgressAlert.beginSheetModalForWindow(self.view.window!, completionHandler: nil)
        self.importMusicFolder(self.openPanel.URL!)
        self.view.window!.endSheet(self.importProgressAlert.window)
        
        // Begin analysis of tracks after they have been successfully imported
        self.analyzeTracks()
      }
      self.openPanel.close()
    }
  }
  
  /**
      Selects the best next track based on the user's current selected track.
  
      - parameter sender: The object that called this action.
  */
  @IBAction func selectBestNextTrack(sender: AnyObject) {
    let selectedTracks = self.tracksController.selectedObjects as! [TrackEntity]
    if selectedTracks.count > 1 {
      // We should never reach this point as the UI element to select the best
      // next track should be hidden if more than one track is selected
      fatalError("selectBestNextTrack called for multiple selected objects")
    }

    let track = selectedTracks[0]
    self.bestNextTrack = selektor.selectTrack(track)

    self.bestNextTrackController.content = self.bestNextTrack
    self.showSuggestedTrackElements()
  }

  /**
      Takes the suggested best next track and selects it as the new "current"
      track, hiding the suggested track UI elements.
  
      - parameter sender: The object that called this action.
  */
  @IBAction func playBestNextTrack(sender: AnyObject) {
    self.hideSuggestedTrackElements()

    guard let bestNextTrack = self.bestNextTrack else {
      fatalError("playBestNextTrack called before a bestNextTrack was selected!")
    }

    // Mark the best next track as played
    bestNextTrack.played = true

    // Clear selection and programmatically select the suggested song
    let indexSet = self.tracksController.selectionIndexes
    self.tracksController.removeSelectionIndexes(indexSet)
    self.tracksController.addSelectedObjects([bestNextTrack])
  }

  /**
      Displays a confirmation modal when the user tries to delete track(s) before
      removing the tracks from the database and the `tracksController` content
      array.

      - parameter sender: The object that called this action.
  */
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
          self.appDelegate.dataController.save()
        }
      })
    }
  }
}
