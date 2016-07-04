//
//  AnalysisStateTransformer.swift
//  Selektor
//
//  Created by James Gray on 2016-07-03.
//  Copyright © 2016 James Gray. All rights reserved.
//

import Foundation

class AnalysisStateTransformer: NSValueTransformer {
  override class func transformedValueClass() -> AnyClass {
    return NSString.self
  }

  override class func allowsReverseTransformation() -> Bool {
    return false
  }

  override func transformedValue(value: AnyObject?) -> AnyObject? {
    guard let num = value as? Int else {
      return ""
    }

    switch num {
      case AnalysisState.InProgress.rawValue:
        return "\u{1F550}" // 🕐
      case AnalysisState.Complete.rawValue:
        return "\u{2714}" // ✔️
      default:
        return ""
    }
  }
}