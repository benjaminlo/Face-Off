//
//  DrawingManager.swift
//  Vision Face Detection
//
//  Created by Benjamin Lo on 2017-08-07.
//

import Foundation
import CoreGraphics

class DrawingManager {
    static var drawings = [String : [Drawing]]()
    
    static func loadDrawings(filename: String) {
        drawings[filename] = getDrawingsFromFile(filename: filename)
    }
    
    static func getDrawingFile(type: FeatureType) -> String {
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
    
    static func getDrawingsFromFile(filename: String) -> [Drawing]?
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
    
    func getRandomDrawing(type: FeatureType) -> Drawing {
        let filename = DrawingManager.getDrawingFile(type: type)
        if DrawingManager.drawings[filename] == nil {
            DrawingManager.loadDrawings(filename: filename)
        }
        let drawings = DrawingManager.drawings[filename]
        let randomIndex = Int(arc4random_uniform(UInt32(drawings!.count)))
        
        return drawings![randomIndex]
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
