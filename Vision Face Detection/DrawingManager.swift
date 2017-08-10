//
//  DrawingManager.swift
//  Vision Face Detection
//
//  Created by Benjamin Lo on 2017-08-07.
//

import Foundation
import CoreGraphics
import UIKit

class DrawingManager {
    static var faceCustomization = FaceCustomization()
    static var drawings = [String : [Drawing]]()
    
    static func loadDrawings(filename: String) {
        drawings[filename] = getDrawingsFromFile(filename: filename)
    }
    
    static func getDrawingFile(type: FeatureType) -> String {
        var file: String
        
        switch type {
        case .LeftEye:
            file = "eye"
            if (faceCustomization.leftEyeClosed) {
                file.append("-closed")
            }
            break
        case .RightEye:
            file = "eye"
            if (faceCustomization.rightEyeClosed) {
                file.append("-closed")
            }
            break
        case .LeftEar, .RightEar:
            file = "ear"
            break
        case .Mouth:
            file = "mouth"
            if (faceCustomization.emotion != Emotion.Neutral) {
                file.append("-happy-sad-angry")
            }
            break
        case .Nose:
            file = "nose"
            break
        }
        
        return file
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
    
    static func getRandomDrawing(type: FeatureType) -> Drawing {
        let filename = DrawingManager.getDrawingFile(type: type)
        if DrawingManager.drawings[filename] == nil {
            DrawingManager.loadDrawings(filename: filename)
        }
        let drawings = DrawingManager.drawings[filename]
        let randomIndex = Int(arc4random_uniform(UInt32(drawings!.count)))
        
        return drawings![randomIndex]
    }
    
    static func getBoundingBox(points: [CGPoint]) -> CGRect {
        var minX = points[0].x
        var maxX = points[0].x
        var minY = points[0].y
        var maxY = points[0].y
        
        for i in 0..<points.count - 1 {
            if (points[i].x < minX) {
                minX = points[i].x
            }
            if (points[i].x > maxX) {
                maxX = points[i].x
            }
            if (points[i].y < minY) {
                minY = points[i].y
            }
            if (points[i].y > maxY) {
                maxY = points[i].y
            }
        }
        return (CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY))
    }
    
    static func createDrawingLayer(shapeLayer: CAShapeLayer, strokes: [Stroke], drawingBb: CGRect, featureBb: CGRect, featureWidth: CGFloat, featureHeight: CGFloat, rotationAngle: CGFloat = 0, horizontalFlip: Bool = false, verticalFlip: Bool = false) {
        for stroke in strokes {
            var drawingPoints = stroke.points
            
            for index in drawingPoints.indices {
                drawingPoints[index].x = (horizontalFlip ? 1 - drawingPoints[index].x/drawingBb.width : drawingPoints[index].x/drawingBb.width) * featureWidth + featureBb.origin.x
                drawingPoints[index].y = (verticalFlip ? drawingPoints[index].y/drawingBb.height : 1 - drawingPoints[index].y/drawingBb.height) * featureHeight + featureBb.origin.y
            }
            
            let drawingPath = UIBezierPath()
            drawingPath.move(to: drawingPoints[0])
            for drawingPoint in drawingPoints {
                drawingPath.addLine(to: drawingPoint)
                drawingPath.move(to: drawingPoint)
            }
            drawingPath.addLine(to: drawingPoints[0])
            
            if (rotationAngle != 0) {
                drawingPath.apply(CGAffineTransform(translationX: -featureBb.midX, y: -featureBb.midY))
                drawingPath.apply(CGAffineTransform(rotationAngle: rotationAngle))
                drawingPath.apply(CGAffineTransform(translationX: featureBb.midX, y: featureBb.midY))
            }
            
            let drawingLayer = CAShapeLayer()
            drawingLayer.strokeColor = UIColor.red.cgColor
            drawingLayer.lineWidth = 2.0
            drawingLayer.path = drawingPath.cgPath
            
            shapeLayer.addSublayer(drawingLayer)
        }
    }
    
    static func drawFeature(shapeLayer: CAShapeLayer, featurePoints: [CGPoint]) {
        let newLayer = CAShapeLayer()
        newLayer.strokeColor = UIColor.red.cgColor
        newLayer.lineWidth = 2.0
        
        let path = UIBezierPath()
        path.move(to: featurePoints[0])
        for i in 0..<featurePoints.count - 1 {
            path.addLine(to: featurePoints[i])
            path.move(to: featurePoints[i])
        }
        newLayer.path = path.cgPath
        
        shapeLayer.addSublayer(newLayer)
    }
    
    static func drawDrawing(shapeLayer: CAShapeLayer, featureType: FeatureType, featurePoints: [CGPoint], drawing: Drawing, showFeatureBb: Bool = false) {
        let verticalFlip = featureType == FeatureType.Mouth && (faceCustomization.emotion == Emotion.Angry || faceCustomization.emotion == Emotion.Sad)
        let horizontalFlip = featureType == FeatureType.RightEar || featureType == FeatureType.RightEye
        
        let featureBb = getBoundingBox(points: featurePoints)
        if (showFeatureBb) {
            let featureBbPath = UIBezierPath(rect: featureBb)
            let featureBbLayer = CAShapeLayer()
            
            featureBbLayer.fillColor = UIColor.clear.cgColor
            featureBbLayer.strokeColor = UIColor.blue.cgColor
            featureBbLayer.lineWidth = 2.0
            featureBbLayer.path = featureBbPath.cgPath
            
            shapeLayer.addSublayer(featureBbLayer)
        }
        
        var allDrawingPoints = [CGPoint]()
        for stroke in drawing.strokes {
            allDrawingPoints.append(contentsOf: stroke.points)
        }
        let drawingBb = getBoundingBox(points: allDrawingPoints)
        
        createDrawingLayer(shapeLayer: shapeLayer, strokes: drawing.strokes, drawingBb: drawingBb, featureBb: featureBb, featureWidth: featureBb.width, featureHeight: featureBb.height, horizontalFlip: horizontalFlip, verticalFlip: verticalFlip)
    }
    
    static func drawEars(shapeLayer: CAShapeLayer, faceContourPoints: [CGPoint], drawing: Drawing, showFeatureBb: Bool = false) {
        let faceContourBb = getBoundingBox(points: faceContourPoints)
        let earWidth = faceContourBb.width/5
        let earHeight = faceContourBb.height/2
        let rotationAngle = atan((faceContourPoints[faceContourPoints.count - 2].y - faceContourPoints[0].y)/faceContourBb.width)
        let leftEarBb = CGRect(x: faceContourPoints[faceContourPoints.count - 2].x, y: faceContourPoints[faceContourPoints.count - 2].y - earHeight, width: earWidth, height: earHeight)
        let rightEarBb = CGRect(x: faceContourPoints[0].x - earWidth, y: faceContourPoints[0].y - earHeight, width: earWidth, height: earHeight)
        
        if (showFeatureBb) {
            let leftEarBbPath = UIBezierPath(rect: leftEarBb)
            let leftEarBbLayer = CAShapeLayer()
            
            leftEarBbPath.apply(CGAffineTransform(translationX: -leftEarBb.midX, y: -leftEarBb.midY))
            leftEarBbPath.apply(CGAffineTransform(rotationAngle: rotationAngle))
            leftEarBbPath.apply(CGAffineTransform(translationX: leftEarBb.midX, y: leftEarBb.midY))
            
            leftEarBbLayer.fillColor = UIColor.clear.cgColor
            leftEarBbLayer.strokeColor = UIColor.blue.cgColor
            leftEarBbLayer.lineWidth = 2.0
            leftEarBbLayer.path = leftEarBbPath.cgPath
            
            shapeLayer.addSublayer(leftEarBbLayer)
            
            let rightEarBbPath = UIBezierPath(rect: rightEarBb)
            let rightEarBbLayer = CAShapeLayer()
            
            rightEarBbPath.apply(CGAffineTransform(translationX: -rightEarBb.midX, y: -rightEarBb.midY))
            rightEarBbPath.apply(CGAffineTransform(rotationAngle: rotationAngle))
            rightEarBbPath.apply(CGAffineTransform(translationX: rightEarBb.midX, y: rightEarBb.midY))
            
            rightEarBbLayer.fillColor = UIColor.clear.cgColor
            rightEarBbLayer.strokeColor = UIColor.blue.cgColor
            rightEarBbLayer.lineWidth = 2.0
            rightEarBbLayer.path = rightEarBbPath.cgPath
            
            shapeLayer.addSublayer(rightEarBbLayer)
        }
        
        var allDrawingPoints = [CGPoint]()
        for stroke in drawing.strokes {
            allDrawingPoints.append(contentsOf: stroke.points)
        }
        let drawingBb = getBoundingBox(points: allDrawingPoints)
        
        createDrawingLayer(shapeLayer: shapeLayer, strokes: drawing.strokes, drawingBb: drawingBb, featureBb: leftEarBb, featureWidth: earWidth, featureHeight: earHeight, rotationAngle: rotationAngle)
        createDrawingLayer(shapeLayer: shapeLayer, strokes: drawing.strokes, drawingBb: drawingBb, featureBb: rightEarBb, featureWidth: earWidth, featureHeight: earHeight, rotationAngle: rotationAngle, horizontalFlip: true)
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

enum Emotion {
    case Neutral
    case Happy
    case Sad
    case Angry
}

struct FaceCustomization {
    var emotion: Emotion
    var leftEyeClosed: Bool
    var rightEyeClosed: Bool
    
    init(emotion: Emotion = Emotion.Neutral, leftEyeClosed: Bool = false, rightEyeClosed: Bool = false) {
        self.emotion = emotion
        self.leftEyeClosed = leftEyeClosed
        self.rightEyeClosed = rightEyeClosed
    }
}

struct Drawing {
    var strokes = [Stroke]()
}

struct Stroke {
    var points = [CGPoint]()
}
