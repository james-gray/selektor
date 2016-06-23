//
//  MetadataParser.swift
//  Selektor
//
//  Created by James Gray on 2016-06-20.
//  Copyright © 2016 James Gray. All rights reserved.
//

import AVFoundation
import Foundation

// MARK: Custom lets for 3-character ID3 v2.3 tag names
let AVMetadataID322MetadataKeyTitle: String = "TT2"
let AVMetadataID322MetadataKeyArtist: String = "TP1"
let AVMetadataID322MetadataKeyAlbum: String = "TAL"
let AVMetadataID322MetadataKeyInitialKey: String = "TKE"
let AVMetadataID322MetadataKeyBeatsPerMin: String = "TBP"

class MetadataParser {
  let formats: Dictionary<String, String> = [
    "itunes": AVMetadataFormatiTunesMetadata,
    "id3": AVMetadataFormatID3Metadata,
  ]

  let tags: Dictionary<String, Dictionary<String, String>> = [
    // iTunes
    AVMetadataFormatiTunesMetadata: [
      AVMetadataiTunesMetadataKeySongName: "name",
      AVMetadataiTunesMetadataKeyArtist: "artist",
      AVMetadataiTunesMetadataKeyAlbum: "album",
      AVMetadataiTunesMetadataKeyUserGenre: "genre",
      AVMetadataiTunesMetadataKeyBeatsPerMin: "tempo",
      AVMetadataiTunesMetadataKeyPublisher: "label",
    ],
    // id3
    AVMetadataFormatID3Metadata: [
      AVMetadataID3MetadataKeyTitleDescription: "name",
      AVMetadataID3MetadataKeyOriginalArtist: "artist",
      AVMetadataID3MetadataKeyLeadPerformer: "artist",
      AVMetadataID3MetadataKeyBand: "artist",
      AVMetadataID3MetadataKeyAlbumTitle: "album",
      AVMetadataID3MetadataKeyInitialKey: "key",
      AVMetadataID3MetadataKeyBeatsPerMinute: "tempo",
      AVMetadataID322MetadataKeyTitle: "name",
      AVMetadataID322MetadataKeyArtist: "artist",
      AVMetadataID322MetadataKeyAlbum: "album",
      AVMetadataID322MetadataKeyInitialKey: "key",
      AVMetadataID322MetadataKeyBeatsPerMin: "tempo",
      AVMetadataID3MetadataKeyPublisher: "label",
    ],
    // Quicktime Meta
    AVMetadataFormatQuickTimeMetadata: [
      AVMetadataQuickTimeMetadataKeyTitle: "name",
      AVMetadataQuickTimeMetadataKeyArtist: "artist",
      AVMetadataQuickTimeMetadataKeyOriginalArtist: "artist",
      AVMetadataQuickTimeMetadataKeyAlbum: "album",
      AVMetadataQuickTimeMetadataKeyGenre: "genre",
      AVMetadataQuickTimeMetadataKeyPublisher: "label",
    ],
    // Quicktime User
    AVMetadataFormatQuickTimeUserData: [
      AVMetadataQuickTimeUserDataKeyTrackName: "name",
      AVMetadataQuickTimeUserDataKeyArtist: "artist",
      AVMetadataQuickTimeUserDataKeyOriginalArtist: "artist",
      AVMetadataQuickTimeUserDataKeyAlbum: "album",
      AVMetadataQuickTimeUserDataKeyPublisher: "label",
    ],
    AVMetadataFormatISOUserData: [
      AVMetadataISOUserDataKeyCopyright: "label",
    ]
  ]

  /**
      Parse a given asset's metadata, choosing from among the available metadata
      formats.
   
      - parameter asset: The song asset to parse metadata from.
   
      - returns: A dictionary of values that can be used to instantiate
          a `SongEntity`.
  */
  func parse(asset: AVURLAsset) -> [String: AnyObject] {
    var songMeta = [String: AnyObject]()
    for format in asset.availableMetadataFormats {
      songMeta = parseMetadataFormat(asset, songMeta: songMeta, format: format)
    }
    return songMeta
  }

  /**
      Extract metadata of format `format` from the given asset's metadata tags
      and add it to the `songMeta` dictionary.
   
      - parameter asset: The asset to extract metadata from
      - parameter songMeta: The metadata dict to populate
      - parameter format: The string metadata format (for example "com.apple.itunes")
   
      - returns: The mutated `songMeta` dict
  */
  func parseMetadataFormat(asset: AVURLAsset, songMeta: [String: AnyObject], format: String)
      -> [String: AnyObject] {
    var songMeta = songMeta
    var key: String = ""

    guard let tags = self.tags[format] else {
      print("Found unknown tag format '\(format)', skipping")
      return songMeta
    }

    let meta = asset.metadataForFormat(format).filter {
      (item) in tags.keys.contains(item.keyString)
    }

    for item in meta {
      // Set each metadata item in the song meta dict if it isn't already set
      key = tags[item.keyString]!
      if let value = item.value {
        songMeta[key] = songMeta[key] ?? value
      }
    }

    return songMeta
  }

}