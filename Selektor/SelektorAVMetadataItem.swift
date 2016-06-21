//
//  SelektorAVMetadataItem.swift
//  Selektor
//
//  Created by James Gray on 2016-06-20.
//  Copyright © 2016 James Gray. All rights reserved.
//

import AVFoundation
import Foundation

extension AVMetadataItem {
  /**
   * Ugly mess of type conversion, pointers and C strings to generate a string
   * representation of the metadata item's key. Whyyy is this not a part of the
   * AVFoundation API already, Apple?!
   *
   * Based on code by Bob McCune in "Learning AV Foundation: A Hands-on Guide to
   * Mastering the AV Foundation Framework."
   * See https://itunes.apple.com/us/book/learning-av-foundation/id934379880?mt=11
   */
  var keyString: String {
    let specialChars: [Int8] = [97, -87] // © and ï, respectively

    if var key = self.key as? String {
      // Advance past the null byte which, for some reason, is showing up in
      // ID3 v2.x tag names to obtain the 3-character tag name
      if key[key.startIndex] == Character("\0") {
        let substring = key.startIndex.advancedBy(1) ..< key.endIndex
        key = key[substring]
      }
      return key
    }

    if let key = self.key as? Int {
      var keyValue = UInt32(truncatingBitPattern: key)
      var length = sizeof(UInt32)

      // Most keys are 4 characters, however ID3v2.2 keys are 3 characters
      // long - adjust the length as necessary
      if (keyValue >> 24) == 0 { length -= 1 }
      if (keyValue >> 16) == 0 { length -= 1 }
      if (keyValue >> 8) == 0 { length -= 1 }
      if (keyValue >> 0) == 0 { length -= 1 }

      var address: UnsafeMutablePointer<UInt32> = withUnsafeMutablePointer(&keyValue, { $0 })
      address += (sizeof(UInt32) - length)

      // Keys are stored in big-endian format so we must swap
      keyValue = CFSwapInt32BigToHost(keyValue)

      let cstring = UnsafeMutablePointer<CChar>.alloc(length)
      strncpy(cstring, UnsafePointer<CChar>(address), length)

      // <Gross Hack> to null terminate C string. There has to be another way!
      cstring[length] = CChar(Array("\0".utf8)[0])
      // </Gross Hack>

      if specialChars.contains(cstring[0]) {
        // Replace special characters with @
        cstring[0] = CChar(Array("@".utf8)[0])
      }

      return NSString(UTF8String: cstring) as! String

    } else {
      return "<<unknown>>"
    }
  }
}
