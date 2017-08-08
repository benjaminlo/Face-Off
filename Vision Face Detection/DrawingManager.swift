//
//  DrawingManager.swift
//  Vision Face Detection
//
//  Created by Benjamin Lo on 2017-08-07.
//

import Foundation
import CoreGraphics

class DrawingManager {
    
    func getDrawing(type: FeatureType) -> Drawing {
        let filename = getDrawingFile(type: type)
        let drawings = getDrawingsFromFile(filename: filename)
        
        return drawings!.first!
    }
    
    func getDrawingFile(type: FeatureType) -> String {
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
    
    func getDrawingsFromFile(filename: String) -> [Drawing]?
    {
        if let path = Bundle.main.path(forResource: filename, ofType: "json") {
            do {
                let data = try Data(contentsOf: URL(fileURLWithPath: path), options: .alwaysMapped)
                let json = try JSONSerialization.jsonObject(with: data, options: [])
                if let contents = json as? [Any] {
                    var drawings = [Drawing]()
                    for entry in contents {
                        if let item = entry as? [String: Any], let drawingObject = item["drawing"] as? [Any] {
                            var drawing = Drawing()
                            for stroke in drawingObject {
                                if let strokeComponents = stroke as? [Any], let xValues = strokeComponents[0] as? [Int], let yValues = strokeComponents[1] as? [Int] {
                                    var newStroke = Stroke()
                                    for (xValue, yValue) in zip(xValues, yValues) {
                                        newStroke.points.append(CGPoint(x: xValue, y: yValue))
                                    }
                                    drawing.strokes.append(newStroke)
                                }
                            }
                            drawings.append(drawing)
                        }
                    }
                    return drawings
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

struct Drawing {
    var strokes = [Stroke]()
}

struct Stroke {
    var points = [CGPoint]()
}
