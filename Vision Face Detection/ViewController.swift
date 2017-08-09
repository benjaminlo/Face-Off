//
//  ViewController.swift
//  Vision Face Detection
//
//  Created by Pawel Chmiel on 21.06.2017.
//  Copyright © 2017 Droids On Roids. All rights reserved.
//

import UIKit
import AVFoundation
import Vision

final class ViewController: UIViewController {
    var session: AVCaptureSession?
    let shapeLayer = CAShapeLayer()
    
    let faceDetection = VNDetectFaceRectanglesRequest()
    let faceLandmarks = VNDetectFaceLandmarksRequest()
    let faceLandmarksDetectionRequest = VNSequenceRequestHandler()
    let faceDetectionRequest = VNSequenceRequestHandler()
    
    let drawingManager = DrawingManager()
    
    lazy var previewLayer: AVCaptureVideoPreviewLayer? = {
        guard let session = self.session else { return nil }
        
        var previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        
        return previewLayer
    }()
    
    var frontCamera: AVCaptureDevice? = {
        return AVCaptureDevice.default(AVCaptureDevice.DeviceType.builtInWideAngleCamera, for: AVMediaType.video, position: .front)
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        sessionPrepare()
        session?.startRunning()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.frame
        shapeLayer.frame = view.frame
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard let previewLayer = previewLayer else { return }
        
//        view.layer.addSublayer(previewLayer)
        
        shapeLayer.strokeColor = UIColor.red.cgColor
        shapeLayer.lineWidth = 2.0
        
        //needs to filp coordinate system for Vision
        shapeLayer.setAffineTransform(CGAffineTransform(scaleX: -1, y: -1))
        
        view.layer.addSublayer(shapeLayer)
    }
    
    func sessionPrepare() {
        session = AVCaptureSession()
        guard let session = session, let captureDevice = frontCamera else { return }
        
        do {
            let deviceInput = try AVCaptureDeviceInput(device: captureDevice)
            session.beginConfiguration()
            
            if session.canAddInput(deviceInput) {
                session.addInput(deviceInput)
            }
            
            let output = AVCaptureVideoDataOutput()
            output.videoSettings = [
                String(kCVPixelBufferPixelFormatTypeKey) : Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)
            ]
            
            output.alwaysDiscardsLateVideoFrames = true
            
            if session.canAddOutput(output) {
                session.addOutput(output)
            }
            
            session.commitConfiguration()
            let queue = DispatchQueue(label: "output.queue")
            output.setSampleBufferDelegate(self, queue: queue)
            print("setup delegate")
        } catch {
            print("can't setup session")
        }
    }
}

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        
        let attachments = CMCopyDictionaryOfAttachments(kCFAllocatorDefault, sampleBuffer, kCMAttachmentMode_ShouldPropagate)
        let ciImage = CIImage(cvImageBuffer: pixelBuffer!, options: attachments as! [String : Any]?)
        
        //leftMirrored for front camera
        let ciImageWithOrientation = ciImage.oriented(forExifOrientation: Int32(UIImageOrientation.leftMirrored.rawValue))
        
        detectFace(on: ciImageWithOrientation)
    }
}

extension ViewController {
    func detectFace(on image: CIImage) {
        try? faceDetectionRequest.perform([faceDetection], on: image)
        if let results = faceDetection.results as? [VNFaceObservation] {
            if !results.isEmpty {
                faceLandmarks.inputFaceObservations = results
                detectLandmarks(on: image)
                
                DispatchQueue.main.async {
                    self.shapeLayer.sublayers?.removeAll()
                }
            }
        }
    }
    
    func detectLandmarks(on image: CIImage) {
        try? faceLandmarksDetectionRequest.perform([faceLandmarks], on: image)
        if let landmarksResults = faceLandmarks.results as? [VNFaceObservation] {
            for observation in landmarksResults {
                DispatchQueue.main.async {
                    if let boundingBox = self.faceLandmarks.inputFaceObservations?.first?.boundingBox {
                        let faceBoundingBox = boundingBox.scaled(to: self.view.bounds.size)
                        
                        //different types of landmarks
                        let faceContour = observation.landmarks?.faceContour
                        if let faceContourPoints = self.convertPointsForFace(faceContour, faceBoundingBox) {
                            DispatchQueue.main.async {
                                self.drawFeature(featurePoints: faceContourPoints)
                            }
                        }
                        
                        let leftEyebrow = observation.landmarks?.leftEyebrow
                        if let leftEyebrowPoints = self.convertPointsForFace(leftEyebrow, faceBoundingBox) {
                            DispatchQueue.main.async {
                                self.drawFeature(featurePoints: leftEyebrowPoints)
                            }
                        }
                        
                        let rightEyebrow = observation.landmarks?.rightEyebrow
                        if let rightEyebrowPoints = self.convertPointsForFace(rightEyebrow, faceBoundingBox) {
                            DispatchQueue.main.async {
                                self.drawFeature(featurePoints: rightEyebrowPoints)
                            }
                        }
                        
                        let earDrawing = self.drawingManager.getRandomDrawing(type: FeatureType.LeftEar)
                        if let faceContourPoints = self.convertPointsForFace(faceContour, faceBoundingBox) {
                            DispatchQueue.main.async {
                                self.drawEars(faceContourPoints: faceContourPoints, drawing: earDrawing)
                            }
                        }

                        let eyeDrawing = self.drawingManager.getRandomDrawing(type: FeatureType.LeftEye)
                        let leftEye = observation.landmarks?.leftEye
                        if let leftEyePoints = self.convertPointsForFace(leftEye, faceBoundingBox) {
                            DispatchQueue.main.async {
                                self.drawDrawing(featurePoints: leftEyePoints, drawing: eyeDrawing)
                            }
                        }

                        let rightEye = observation.landmarks?.rightEye
                        if let rightEyePoints = self.convertPointsForFace(rightEye, faceBoundingBox) {
                            DispatchQueue.main.async {
                                self.drawDrawing(featurePoints: rightEyePoints, drawing: eyeDrawing, horizontalFlip: true)
                            }
                        }
                        
                        let noseDrawing = self.drawingManager.getRandomDrawing(type: FeatureType.Nose)
                        let nose = observation.landmarks?.nose
                        if let nosePoints = self.convertPointsForFace(nose, faceBoundingBox) {
                            DispatchQueue.main.async {
                                self.drawDrawing(featurePoints: nosePoints, drawing: noseDrawing)
                            }
                        }
                        
                        let mouthDrawing = self.drawingManager.getRandomDrawing(type: FeatureType.Mouth)
                        let outerLips = observation.landmarks?.outerLips
                        if let outerLipsPoints = self.convertPointsForFace(outerLips, faceBoundingBox) {
                            DispatchQueue.main.async {
                                self.drawDrawing(featurePoints: outerLipsPoints, drawing: mouthDrawing)
                            }
                        }
                    }
                }
            }
        }
    }
    
    func convert(_ points: UnsafePointer<vector_float2>, with count: Int) -> [(x: CGFloat, y: CGFloat)] {
        var convertedPoints = [(x: CGFloat, y: CGFloat)]()
        for i in 0...count {
            convertedPoints.append((CGFloat(points[i].x), CGFloat(points[i].y)))
        }
        
        return convertedPoints
    }
    
    func convertPointsForFace(_ landmark: VNFaceLandmarkRegion2D?, _ boundingBox: CGRect) -> [CGPoint]? {
        if let points = landmark?.points, let count = landmark?.pointCount {
            let convertedPoints = convert(points, with: count)
            
            return convertedPoints.map { (point: (x: CGFloat, y: CGFloat)) -> CGPoint in
                let pointX = point.x * boundingBox.width + boundingBox.origin.x
                let pointY = point.y * boundingBox.height + boundingBox.origin.y
                
                return CGPoint(x: pointX, y: pointY)
            }
        }
        return nil
    }
    
    func getBoundingBox(points: [CGPoint]) -> CGRect {
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
    
    func createDrawingLayer(strokes: [Stroke], drawingBb: CGRect, featureBb: CGRect, featureWidth: CGFloat, featureHeight: CGFloat, rotationAngle: CGFloat = 0, horizontalFlip: Bool = false, verticalFlip: Bool = false) {
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
    
    func drawFeature(featurePoints: [CGPoint]) {
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
    
    func drawDrawing(featurePoints: [CGPoint], drawing: Drawing, horizontalFlip: Bool = false, verticalFlip: Bool = false, showFeatureBb: Bool = false) {
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
        
        createDrawingLayer(strokes: drawing.strokes, drawingBb: drawingBb, featureBb: featureBb, featureWidth: featureBb.width, featureHeight: featureBb.height, horizontalFlip: horizontalFlip, verticalFlip: verticalFlip)
    }
    
    func drawEars(faceContourPoints: [CGPoint], drawing: Drawing, showFeatureBb: Bool = false) {
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
        
        createDrawingLayer(strokes: drawing.strokes, drawingBb: drawingBb, featureBb: leftEarBb, featureWidth: earWidth, featureHeight: earHeight, rotationAngle: rotationAngle)
        createDrawingLayer(strokes: drawing.strokes, drawingBb: drawingBb, featureBb: rightEarBb, featureWidth: earWidth, featureHeight: earHeight, rotationAngle: rotationAngle, horizontalFlip: true)
    }
}
