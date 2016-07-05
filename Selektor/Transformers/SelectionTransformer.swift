//
//  SelectionTransformer.swift
//  Selektor
//
//  Created by James Gray on 2016-07-05.
//  Copyright © 2016 James Gray. All rights reserved.
//

import Foundation

class SelectionTransformer: NSValueTransformer {
  override class func transformedValueClass() -> AnyClass {
    return NSString.self
  }

  override class func allowsReverseTransformation() -> Bool {
    return false
  }

  override func transformedValue(value: AnyObject?) -> AnyObject? {
    // XXX: Return false to prevent hiding any selected songs, since for some
    // reason the name of certain songs is causing the "Pick Next Song" button
    // to be hidden
    return false
  }
}