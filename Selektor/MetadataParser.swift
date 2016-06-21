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

  let keys: Dictionary<String, Dictionary<String, String>> = [
    // iTunes
    AVMetadataFormatiTunesMetadata: [
      AVMetadataiTunesMetadataKeySongName: "title",
      AVMetadataiTunesMetadataKeyArtist: "artist",
      AVMetadataiTunesMetadataKeyAlbum: "album",
      AVMetadataiTunesMetadataKeyUserGenre: "genre",
      AVMetadataiTunesMetadataKeyBeatsPerMin: "tempo",
    ],
    // id3
    AVMetadataFormatID3Metadata: [
      AVMetadataID322MetadataKeyTitle: "title",
      AVMetadataID322MetadataKeyArtist: "artist",
      AVMetadataID322MetadataKeyAlbum: "album",
      AVMetadataID322MetadataKeyInitialKey: "key",
      AVMetadataID322MetadataKeyBeatsPerMin: "tempo",
    ],
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

    // TODO: Can do without the formats dict entirely - just iterate over the
    // availableMetadataFormats array and pass the format into parseMetadataFormat,
    // raising an error if the format isn't in the keys dict - may as well handle
    // as many AVMetadataFormats as possible
    if asset.availableMetadataFormats.contains(formats["itunes"]!) {
      songMeta = parseMetadataFormat(asset, songMeta: songMeta, format: formats["itunes"]!)
    }
    if asset.availableMetadataFormats.contains(formats["id3"]!) {
      songMeta = parseMetadataFormat(asset, songMeta: songMeta, format: formats["id3"]!)
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

    let meta = asset.metadataForFormat(format).filter {
      (item) in keys[format]!.keys.contains(item.keyString)
    }

    for item in meta {
      // Set each metadata item in the song meta dict if it isn't already set
      key = keys[format]![item.keyString]!
      if let value = item.value {
        songMeta[key] = songMeta[key] ?? value
      }
    }

    return songMeta
  }

}