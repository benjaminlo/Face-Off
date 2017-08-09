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
        
        view.layer.addSublayer(previewLayer)
        
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
//                        let faceContour = observation.landmarks?.faceContour
//                        self.convertPointsForFace(faceContour, faceBoundingBox)

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
                                self.drawDrawing(featurePoints: rightEyePoints, drawing: eyeDrawing)
                            }
                        }
                        
                        let noseDrawing = self.drawingManager.getRandomDrawing(type: FeatureType.Nose)
                        let nose = observation.landmarks?.nose
                        if let nosePoints = self.convertPointsForFace(nose, faceBoundingBox) {
                            DispatchQueue.main.async {
                                self.drawDrawing(featurePoints: nosePoints, drawing: noseDrawing)
                            }
                        }

//                        let lips = observation.landmarks?.innerLips
//                        self.convertPointsForFace(lips, faceBoundingBox)
//
//                        let leftEyebrow = observation.landmarks?.leftEyebrow
//                        self.convertPointsForFace(leftEyebrow, faceBoundingBox)
//
//                        let rightEyebrow = observation.landmarks?.rightEyebrow
//                        self.convertPointsForFace(rightEyebrow, faceBoundingBox)
//
//                        let noseCrest = observation.landmarks?.noseCrest
//                        self.convertPointsForFace(noseCrest, faceBoundingBox)
                        
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
    
    func drawDrawing(featurePoints: [CGPoint], drawing: Drawing, showFeatureBb: Bool = false) {
        
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
        
        for stroke in drawing.strokes {
            var drawingPoints = stroke.points
            
            for index in drawingPoints.indices {
                drawingPoints[index].x = drawingPoints[index].x/drawingBb.width * featureBb.width + featureBb.origin.x
                drawingPoints[index].y = (1 - drawingPoints[index].y/drawingBb.height) * featureBb.height + featureBb.origin.y
            }
            
            let drawingLayer = CAShapeLayer()
            drawingLayer.strokeColor = UIColor.red.cgColor
            drawingLayer.lineWidth = 2.0
            
            let drawingPath = UIBezierPath()
            drawingPath.move(to: drawingPoints[0])
            for i in 0..<drawingPoints.count - 1 {
                drawingPath.addLine(to: drawingPoints[i])
                drawingPath.move(to: drawingPoints[i])
            }
            drawingPath.addLine(to: drawingPoints[0])
            drawingLayer.path = drawingPath.cgPath
            
            shapeLayer.addSublayer(drawingLayer)
        }
    }
    
    func getBoundingBox(points: [CGPoint]) -> CGRect {
        var minX = points.first!.x
        var maxX = points.first!.x
        var minY = points.first!.y
        var maxY = points.first!.y
        
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
    
    func convert(_ points: UnsafePointer<vector_float2>, with count: Int) -> [(x: CGFloat, y: CGFloat)] {
        var convertedPoints = [(x: CGFloat, y: CGFloat)]()
        for i in 0...count {
            convertedPoints.append((CGFloat(points[i].x), CGFloat(points[i].y)))
        }
        
        return convertedPoints
    }
}
