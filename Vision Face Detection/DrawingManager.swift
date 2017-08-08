//
//  DrawingManager.swift
//  Vision Face Detection
//
//  Created by Benjamin Lo on 2017-08-07.
//

import Foundation
import CoreGraphics

class DrawingManager {
    
    func getFeature(type: FeatureType) -> Feature {
        let filename = getFeatureFile(type: type)
        return Feature()
    }
    
    func getFeatureFile(type: FeatureType) -> String {
        switch type {
        case .LeftEye, .RightEye:
            return "eye"
        case .LeftEar, .RightEar:
            return "ear"
        case .Mouth:
            return "mouth"
        case .Nose:
            return "nose"
        }
    }
}

enum FeatureType {
    case LeftEye
    case RightEye
    case Nose
    case Mouth
    case LeftEar
    case RightEar
}

struct Feature {
    var strokes = [Stroke]()
}

struct Stroke {
    var points = [CGPoint]()
}
