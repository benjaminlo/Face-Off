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
        getFeatureFromFile(filename: filename)
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
    
    func getFeatureFromFile(filename: String)
    {
        if let path = Bundle.main.path(forResource: filename, ofType: "json") {
            do {
                let data = try Data(contentsOf: URL(fileURLWithPath: path), options: .alwaysMapped)
                let json = try JSONSerialization.jsonObject(with: data, options: [])
                if let contents = json as? [String: Any] {
                    // json is a dictionary
                    print(contents)
                } else if let contents = json as? [Any] {
                    // json is an array
                    print(contents)
                } else {
                    print("JSON is invalid")
                }
            } catch let error {
                print(error.localizedDescription)
            }
        } else {
            print("Invalid filename/path.")
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
