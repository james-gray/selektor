//
//  CountTransformer.swift
//  Selektor
//
//  Created by James Gray on 2016-06-22.
//  Copyright © 2016 James Gray. All rights reserved.
//

import Foundation

/**
    Transformer that accepts an integer count and returns a string representing
    the total count, as might be displayed at the bottom of a UI list. For instance,
    given an array with a count of 20, the transformer would return "20 items total".
*/
class CountTransformer: NSValueTransformer {
  override func transformedValue(value: AnyObject?) -> AnyObject? {
    guard let num = value as? Int else {
      return ""
    }

    let plural = num == 1 ? "" : "s"
    return "\(num) item\(plural) total"
  }
}

/**
    Transformer that strips the absolute path from a filename and simply displays
    the last path component.
*/
class FilenameTransformer: NSValueTransformer {
  override func transformedValue(value: AnyObject?) -> AnyObject? {
    return value?.lastPathComponent
  }
}

/**
    Transformer that accepts an integer number of seconds and returns a duration
    string in the format "mm:ss".
*/
class DurationTransformer: NSValueTransformer {
  override func transformedValue(value: AnyObject?) -> AnyObject? {
    guard let num = value as? Int else {
      return ""
    }

    let minutes = num / 60
    let seconds = String(format: "%02d", num % 60)
    return "\(minutes):\(seconds)"
  }
}

/**
    Transformer that accepts an analysis state integer and returns a unicode
    string emoji representing the state (a clock emoji for in progress analysis,
    and a checkmark for complete analysis.)
*/
class AnalysisStateTransformer: NSValueTransformer {
  override func transformedValue(value: AnyObject?) -> AnyObject? {
    guard let num = value as? Int else {
      return ""
    }

    switch num {
    case AnalysisState.inProgress.rawValue:
      return "\u{1F550}" // 🕐
    case AnalysisState.complete.rawValue:
      return "\u{2714}" // ✔️
    default:
      return ""
    }
  }
}

class SelectionTransformer: NSValueTransformer {
  override func transformedValue(value: AnyObject?) -> AnyObject? {
    // XXX: Return false to prevent hiding for any selected tracks, since for some
    // reason the name of certain tracks is causing the "Select Next Track" button
    // to be hidden
    return false
  }
}
