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

  // Songs table view
  @IBOutlet weak var songsTableView: NSTableView!

  // Controller used by the table view for displaying songs in a list
  @IBOutlet var songsController: NSArrayController!

  // Data controller acts as the interface to the Core Data stack, allowing
  // interaction with the database.
  let dc = DataController()
  let mp = MetadataParser()

  // Array of songs which will be used by the songsController for
  // populating the songs table view.
  var songs = [SongEntity]()

  // Memoized artist, album, and genre dicts
  var artists = [String: ArtistEntity]()
  var albums = [String: AlbumEntity]()
  var genres = [String: GenreEntity]()
  var labels = [String: LabelEntity]()

  // Set of supported audio file extensions
  let validExtensions: Set<String> = ["mp3", "m4a", "wav", "m3u", "wma", "aif", "ogg"]

  override func viewDidLoad() {
    super.viewDidLoad()

    // Populate the songs array and attach to the songsController
    dispatch_async(dispatch_get_main_queue()) {
      self.songs = self.dc.fetchEntities()

      // Memoize album, artist, and genre names
      let artists: [ArtistEntity] = self.dc.fetchEntities()
      let albums: [AlbumEntity] = self.dc.fetchEntities()
      let genres: [GenreEntity] = self.dc.fetchEntities()
      let labels: [LabelEntity] = self.dc.fetchEntities()

      // TODO: Make this a method on SelektorObject arrays
      for artist in artists {
        self.artists[artist.name!] = artist
      }
      for album in albums {
        self.albums[album.name!] = album
      }
      for genre in genres {
        self.genres[genre.name!] = genre
      }
      for label in labels {
        self.labels[label.name!] = label
      }

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

    let song: SongEntity = dc.createEntity()
    let asset = AVURLAsset(URL: url)
    let meta = mp.parse(asset)

    song.name = meta["name"] as? String ?? url.lastPathComponent
    song.filename = url.path
    song.tempo = meta["tempo"] as? Int ?? 0

    if let artistName = meta["artist"] as? String {
      song.artist = ArtistEntity.createOrFetchArtist(artistName, dc: dc, artistsDict: &self.artists)
    }

    if let albumName = meta["album"] as? String {
      song.album = AlbumEntity.createOrFetchAlbum(albumName, dc: dc, albumsDict: &self.albums)
    }

    if let genreName = meta["genre"] as? String {
      song.genre = GenreEntity.createOrFetchGenre(genreName, dc: dc, genresDict: &self.genres)
    }

    if let labelName = meta["label"] as? String {
      song.label = LabelEntity.createOrFetchLabel(labelName, dc: dc, labelsDict: &self.labels)
    }

    self.songs.append(song)
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

          self.dc.save()

          // Update the table view by refreshing the array controller
          self.songsController.content = self.songs
          self.songsController.rearrangeObjects()
        }
      }
    }
  }
}