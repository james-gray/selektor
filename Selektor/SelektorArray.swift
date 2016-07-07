//
//  SelektorArray.swift
//  Selektor
//
//  Created by James Gray on 2016-07-03.
//  Copyright © 2016 James Gray. All rights reserved.
//

import Foundation

extension _ArrayType where Generator.Element == Double {
  func distanceFrom(vector vector: [Double], withFormula formula: String = "euclidean") -> Double {
    if vector.count != self.count {
      print("Vector distance calculation only works on vectors of the same dimensionality")
      return Double(FP_INFINITE)
    }

    switch formula {
      case "euclidean":
        // Compute the Euclidean distance between self and vector
        var runningSum: Double = 0
        for i in 0..<self.count {
          let p = self[i]
          let q = vector[i]
          runningSum += pow((q-p), Double(2)) // (q-p)^2
        }
        return sqrt(runningSum)

      case "manhattan":
        var runningSum: Double = 0
        for i in 0..<self.count {
          let p = self[i]
          let q = vector[i]
          runningSum += abs(p-q) // |p-q|
        }
        return runningSum

      default:
        fatalError("Invalid formula specified")

    }
  }
}