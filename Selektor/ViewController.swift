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
  let fileManager = NSFileManager.defaultManager()

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

  func analyzeSongs() {
    let songsToAnalyze = self.songs.filter { Bool($0.analyzed) == false }

    dispatch_async(dispatch_get_global_queue(Int(QOS_CLASS_BACKGROUND.rawValue), 0)) {
      for song in songsToAnalyze {
        self.analyzeSong(song)
        song.analyzed = true
      }
      self.appDelegate.dc.save()
    }
  }

  func getOrCreateWavURLForSong(song: SongEntity) -> (NSURL, Bool)? {
    var wavURL: NSURL

    let isWav = NSURL(fileURLWithPath: song.filename!).pathExtension == "wav"
    if !isWav {
      print("Converting \(song.relativeFilename!) to .wav")

      // Use ffmpeg to create a temporary wav copy of the song
      guard let ffmpegPath = self.ffmpegPath else {
        print("Unable to locate the ffmpeg binary")
        return nil
      }

      let filename = NSURL(fileURLWithPath: song.filename!).URLByDeletingPathExtension?.lastPathComponent
      wavURL = NSURL(fileURLWithPath: NSTemporaryDirectory() as String).URLByAppendingPathComponent(filename! + "_temp.wav")

      let task = NSTask()
      task.launchPath = ffmpegPath
      task.arguments = ["-i", song.filename!, wavURL.path!]
      task.launch()
      task.waitUntilExit()
    } else {
      // Simply use the song's file path as the WAV URL
      wavURL = NSURL(fileURLWithPath: song.filename!)
    }

    // Invert the boolean to indicate whether or not we had to convert the file
    let converted = !isWav
    return (wavURL, converted)
  }

  func analyzeSong(song: SongEntity) {
    var task: NSTask
    let tempDir = NSURL(fileURLWithPath: NSTemporaryDirectory() as String)

    // Get (or create via conversion) the WAV URL for the song
    guard let (wavURL, converted) = getOrCreateWavURLForSong(song) else {
      // There was some issue creating the Wav file - most likely the
      // FFMPEG binary couldn't be located
      return
    }

    // Write a temporary .mf file containing the song's URL for Marsyas
    let tempMfURL = tempDir.URLByAppendingPathComponent("\(song.relativeFilename!).mf")
    do {
      try wavURL.path!.writeToURL(tempMfURL, atomically: false, encoding: NSUTF8StringEncoding)
    } catch {
      print("Error writing filename to temporary .mf file")
      return
    }

    guard let mirexPath = self.mirexPath else {
      print("Unable to locate the mirex_extract binary")
      return
    }
    let tempArffURL = tempDir.URLByAppendingPathComponent("\(song.relativeFilename!).arff")

    // Execute the mirex_extract command to analyze the song
    task = NSTask()
    task.launchPath = mirexPath
    task.arguments = [tempMfURL.path!, tempArffURL.path!]
    task.launch()
    task.waitUntilExit()

    // Store the timbre data in the song object
    song.store64DimensionalTimbreVector(tempArffURL)

    // Clean up temporary files. Wav files are huge - we don't want them cluttering
    // up the user's disk until the app quits!
    do {
      try fileManager.removeItemAtURL(tempMfURL)
      try fileManager.removeItemAtURL(tempArffURL)
    } catch {
      print("Could not remove files at \(tempMfURL), \(tempArffURL): \(error)")
    }

    if converted {
      do {
        try fileManager.removeItemAtURL(wavURL)
      } catch {
        print("Could not remove file at \(wavURL): \(error)")
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
        }
      })
    }
  }
}