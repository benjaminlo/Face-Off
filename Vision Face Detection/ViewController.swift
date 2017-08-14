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
                                DrawingManager.drawFeature(ofType: FeatureType.FaceContour, withPoints: faceContourPoints, onLayer: self.shapeLayer)
                                DrawingManager.drawEars(withPoints: faceContourPoints, onLayer: self.shapeLayer)
                            }
                        }
                        
                        let leftEyebrow = observation.landmarks?.rightEyebrow // flipped for vision
                        if let leftEyebrowPoints = self.convertPointsForFace(leftEyebrow, faceBoundingBox) {
                            DispatchQueue.main.async {
                                DrawingManager.drawFeature(ofType: FeatureType.Eyebrow, withPoints: leftEyebrowPoints, onLayer: self.shapeLayer)
                            }
                        }
                        
                        let rightEyebrow = observation.landmarks?.leftEyebrow // flipped for vision
                        if let rightEyebrowPoints = self.convertPointsForFace(rightEyebrow, faceBoundingBox) {
                            DispatchQueue.main.async {
                                DrawingManager.drawFeature(ofType: FeatureType.Eyebrow, withPoints: rightEyebrowPoints, onLayer: self.shapeLayer)
                            }
                        }

                        let leftEye = observation.landmarks?.rightEye // flipped for vision
                        let rightEye = observation.landmarks?.leftEye // flipped for vision
                        if let leftEyePoints = self.convertPointsForFace(leftEye, faceBoundingBox), let rightEyePoints = self.convertPointsForFace(rightEye, faceBoundingBox) {
                            DispatchQueue.main.async {
                                DrawingManager.drawEyes(withLeftEyePoints: leftEyePoints, andRightEyePoints: rightEyePoints, onLayer: self.shapeLayer)
                                if DrawingManager.faceCustomization.hasEyeglasses, let faceContourPoints = self.convertPointsForFace(faceContour, faceBoundingBox) {
                                    DrawingManager.drawEyeglasses(withLeftEyePoints: leftEyePoints, andRightEyePoints: rightEyePoints, andFaceContourPoints: faceContourPoints, onLayer: self.shapeLayer)
                                }
                            }
                        }
                        
                        let nose = observation.landmarks?.nose
                        if let nosePoints = self.convertPointsForFace(nose, faceBoundingBox) {
                            DispatchQueue.main.async {
                                DrawingManager.drawDrawing(ofType: FeatureType.Nose, withPoints: nosePoints, onLayer: self.shapeLayer)
                            }
                        }
                        
                        let outerLips = observation.landmarks?.outerLips
                        if let outerLipsPoints = self.convertPointsForFace(outerLips, faceBoundingBox) {
                            DispatchQueue.main.async {
                                DrawingManager.drawDrawing(ofType: FeatureType.Mouth, withPoints: outerLipsPoints, onLayer: self.shapeLayer)
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
}
