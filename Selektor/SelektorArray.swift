//
//  SelektorArray.swift
//  Selektor
//
//  Created by James Gray on 2016-07-03.
//  Copyright © 2016 James Gray. All rights reserved.
//

import Foundation

extension Array {
  /**
      Split an array into subarrays of size `subSize`.
      Based on code by Eric D (eric@aya.io)
      https://gist.github.com/ericdke/fa262bdece59ff786fcb
  */
  func splitBy(subSize: Int) -> [[Element]] {
    return 0.stride(to: self.count, by: subSize).map {
      startIndex in
      let endIndex = startIndex.advancedBy(subSize, limit: self.count)
      return Array(self[startIndex ..< endIndex])
    }
  }
}