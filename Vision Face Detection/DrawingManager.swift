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
        let features = getFeaturesFromFile(filename: filename)
        
        return features!.first!
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
    
    func getFeaturesFromFile(filename: String) -> [Feature]?
    {
        if let path = Bundle.main.path(forResource: filename, ofType: "json") {
            do {
                let data = try Data(contentsOf: URL(fileURLWithPath: path), options: .alwaysMapped)
                let json = try JSONSerialization.jsonObject(with: data, options: [])
                if let contents = json as? [Any] {
                    var features = [Feature]()
                    for entry in contents {
                        if let item = entry as? [String: Any], let drawing = item["drawing"] as? [Any] {
                            var feature = Feature()
                            for stroke in drawing {
                                if let strokeComponents = stroke as? [Any], let xValues = strokeComponents[0] as? [Int], let yValues = strokeComponents[1] as? [Int] {
                                    var newStroke = Stroke()
                                    for (xValue, yValue) in zip(xValues, yValues) {
                                        newStroke.points.append(CGPoint(x: xValue, y: yValue))
                                    }
                                    feature.strokes.append(newStroke)
                                }
                            }
                            features.append(feature)
                        }
                    }
                    return features
                } else {
                    print("JSON is invalid")
                }
            } catch let error {
                print(error.localizedDescription)
            }
        } else {
            print("Invalid filename/path.")
        }
        return nil
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
