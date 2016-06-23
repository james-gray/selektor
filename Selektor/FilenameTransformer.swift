//
//  FilenameTransformer.swift
//  Selektor
//
//  Created by James Gray on 2016-06-22.
//  Copyright © 2016 James Gray. All rights reserved.
//

import Foundation

class FilenameTransformer: NSValueTransformer {
  override class func transformedValueClass() -> AnyClass {
    return NSString.self
  }

  override class func allowsReverseTransformation() -> Bool {
    return false
  }

  override func transformedValue(value: AnyObject?) -> AnyObject? {
    return value?.lastPathComponent
  }
}