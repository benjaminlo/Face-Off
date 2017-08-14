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
        var file = String()
        
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
        case .Eyeglasses:
            file = "eyeglasses"
            break
        default:
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
    
    static func createDrawingLayer(shapeLayer: CAShapeLayer, strokes: [Stroke], drawingBb: CGRect, featureBb: CGRect, featureWidth: CGFloat, featureHeight: CGFloat, color: UIColor = UIColor.black, rotationAngle: CGFloat = 0, horizontalFlip: Bool = false, verticalFlip: Bool = false) {
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
            drawingLayer.strokeColor = color.cgColor
            drawingLayer.lineWidth = 2.0
            drawingLayer.path = drawingPath.cgPath
            
            shapeLayer.addSublayer(drawingLayer)
        }
    }
    
    static func drawFeature(ofType featureType: FeatureType, withPoints featurePoints: [CGPoint], onLayer shapeLayer: CAShapeLayer) {
        let color = faceCustomization.getColor(type: featureType)
        let newLayer = CAShapeLayer()
        newLayer.strokeColor = color.cgColor
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
    
    static func drawDrawing(ofType featureType: FeatureType, withPoints featurePoints: [CGPoint], onLayer shapeLayer: CAShapeLayer, withBb showFeatureBb: Bool = false, givenDrawing: Drawing? = nil) {
        let drawing = givenDrawing == nil ? getRandomDrawing(type: featureType) : givenDrawing!
        let color = faceCustomization.getColor(type: featureType)
        let verticalFlip = featureType == FeatureType.Mouth && (faceCustomization.emotion == Emotion.Angry || faceCustomization.emotion == Emotion.Sad)
        let horizontalFlip = featureType == FeatureType.RightEar || featureType == FeatureType.RightEye
        
        let featureBb = getBoundingBox(points: featurePoints)
        if (showFeatureBb) {
            let featureBbPath = UIBezierPath(rect: featureBb)
            let featureBbLayer = CAShapeLayer()
            
            featureBbLayer.fillColor = UIColor.clear.cgColor
            featureBbLayer.strokeColor = color.cgColor
            featureBbLayer.lineWidth = 2.0
            featureBbLayer.path = featureBbPath.cgPath
            
            shapeLayer.addSublayer(featureBbLayer)
        }
        
        var allDrawingPoints = [CGPoint]()
        for stroke in drawing.strokes {
            allDrawingPoints.append(contentsOf: stroke.points)
        }
        let drawingBb = getBoundingBox(points: allDrawingPoints)
        
        createDrawingLayer(shapeLayer: shapeLayer, strokes: drawing.strokes, drawingBb: drawingBb, featureBb: featureBb, featureWidth: featureBb.width, featureHeight: featureBb.height, color: color, horizontalFlip: horizontalFlip, verticalFlip: verticalFlip)
    }
    
    static func drawEyes(withLeftEyePoints leftEyePoints: [CGPoint], andRightEyePoints rightEyePoints: [CGPoint], onLayer shapeLayer: CAShapeLayer) {
        let leftEyeDrawing = getRandomDrawing(type: FeatureType.LeftEye)
        let rightEyeDrawing = faceCustomization.leftEyeClosed != faceCustomization.rightEyeClosed ?  getRandomDrawing(type: FeatureType.RightEye) : leftEyeDrawing
        
        drawDrawing(ofType: FeatureType.LeftEye, withPoints: leftEyePoints, onLayer: shapeLayer, givenDrawing: leftEyeDrawing)
        drawDrawing(ofType: FeatureType.RightEye, withPoints: rightEyePoints, onLayer: shapeLayer, givenDrawing: rightEyeDrawing)
    }
    
    static func drawEyeglasses(withLeftEyePoints leftEyePoints: [CGPoint], andRightEyePoints rightEyePoints: [CGPoint], andFaceContourPoints faceContourPoints: [CGPoint], onLayer shapeLayer: CAShapeLayer, withBb showFeatureBb: Bool = false) {
        var points = [CGPoint(x: faceContourPoints[0].x, y: rightEyePoints[0].y), CGPoint(x: faceContourPoints[faceContourPoints.count - 2].x, y: leftEyePoints[0].y)] // only care about x values of faceCountourPoints
        for i in 0..<leftEyePoints.count - 1 { // last point in array is invalid
            points.append(leftEyePoints[i])
        }
        for i in 0..<rightEyePoints.count {
            points.append(rightEyePoints[i])
        }
        
        let drawing = getRandomDrawing(type: FeatureType.Eyeglasses)
        let color = faceCustomization.getColor(type: FeatureType.Eyeglasses)
        let faceContourBb = getBoundingBox(points: faceContourPoints)
        let rotationAngle = atan((faceContourPoints[faceContourPoints.count - 2].y - faceContourPoints[0].y)/faceContourBb.width)
        let featureBb = getBoundingBox(points: points)
        let eyeglassesHeight = getBoundingBox(points: leftEyePoints).height * 2
        
        if (showFeatureBb) {
            let featureBbPath = UIBezierPath(rect: featureBb)
            let featureBbLayer = CAShapeLayer()

            featureBbLayer.fillColor = UIColor.clear.cgColor
            featureBbLayer.strokeColor = color.cgColor
            featureBbLayer.lineWidth = 2.0
            featureBbLayer.path = featureBbPath.cgPath

            shapeLayer.addSublayer(featureBbLayer)
        }
    
        var allDrawingPoints = [CGPoint]()
        for stroke in drawing.strokes {
            allDrawingPoints.append(contentsOf: stroke.points)
        }
        let drawingBb = getBoundingBox(points: allDrawingPoints)
        
        createDrawingLayer(shapeLayer: shapeLayer, strokes: drawing.strokes, drawingBb: drawingBb, featureBb: featureBb, featureWidth: featureBb.width, featureHeight: eyeglassesHeight, color: color, rotationAngle: rotationAngle)
    }
    
    static func drawEars(withPoints faceContourPoints: [CGPoint], onLayer shapeLayer: CAShapeLayer, withBb showFeatureBb: Bool = false) {
        let drawing = getRandomDrawing(type: FeatureType.LeftEar)
        let color = faceCustomization.getColor(type: FeatureType.LeftEar)
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
            leftEarBbLayer.strokeColor = color.cgColor
            leftEarBbLayer.lineWidth = 2.0
            leftEarBbLayer.path = leftEarBbPath.cgPath
            
            shapeLayer.addSublayer(leftEarBbLayer)
            
            let rightEarBbPath = UIBezierPath(rect: rightEarBb)
            let rightEarBbLayer = CAShapeLayer()
            
            rightEarBbPath.apply(CGAffineTransform(translationX: -rightEarBb.midX, y: -rightEarBb.midY))
            rightEarBbPath.apply(CGAffineTransform(rotationAngle: rotationAngle))
            rightEarBbPath.apply(CGAffineTransform(translationX: rightEarBb.midX, y: rightEarBb.midY))
            
            rightEarBbLayer.fillColor = UIColor.clear.cgColor
            rightEarBbLayer.strokeColor = color.cgColor
            rightEarBbLayer.lineWidth = 2.0
            rightEarBbLayer.path = rightEarBbPath.cgPath
            
            shapeLayer.addSublayer(rightEarBbLayer)
        }
        
        var allDrawingPoints = [CGPoint]()
        for stroke in drawing.strokes {
            allDrawingPoints.append(contentsOf: stroke.points)
        }
        let drawingBb = getBoundingBox(points: allDrawingPoints)
        
        createDrawingLayer(shapeLayer: shapeLayer, strokes: drawing.strokes, drawingBb: drawingBb, featureBb: leftEarBb, featureWidth: earWidth, featureHeight: earHeight, color: color, rotationAngle: rotationAngle)
        createDrawingLayer(shapeLayer: shapeLayer, strokes: drawing.strokes, drawingBb: drawingBb, featureBb: rightEarBb, featureWidth: earWidth, featureHeight: earHeight, color: color, rotationAngle: rotationAngle, horizontalFlip: true)
    }
}

enum FeatureType {
    case LeftEye
    case RightEye
    case Nose
    case Mouth
    case LeftEar
    case RightEar
    case FaceContour
    case Eyebrow
    case Eyeglasses
}

enum Emotion {
    case Neutral
    case Happy
    case Sad
    case Angry
}

class FaceCustomization {
    var emotion = Emotion.Neutral
    var leftEyeClosed = false
    var rightEyeClosed = false
    var hasEyeglasses = false
    var eyeColor = UIColor.black
    var noseColor = UIColor.black
    var mouthColor = UIColor.black
    var earColor = UIColor.black
    var faceContourColor = UIColor.black
    var eyebrowColor = UIColor.black
    var eyeglassesColor = UIColor.black
    
    func getColor(type: FeatureType) -> UIColor {
        switch(type) {
        case .LeftEye, .RightEye:
            return eyeColor
        case .Nose:
            return noseColor
        case .Mouth:
            return mouthColor
        case .LeftEar, .RightEar:
            return earColor
        case .FaceContour:
            return faceContourColor
        case .Eyebrow:
            return eyebrowColor
        case .Eyeglasses:
            return eyeglassesColor
        }
    }
}

struct Drawing {
    var strokes = [Stroke]()
}

struct Stroke {
    var points = [CGPoint]()
}
