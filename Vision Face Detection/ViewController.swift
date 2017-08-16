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
import ProjectOxfordFace

final class ViewController: UIViewController {
    @IBOutlet weak var layersView: UIView?
    @IBOutlet weak var emotionLabel: UILabel?
    @IBOutlet weak var avatarToggleButton: UIButton?
    @IBOutlet weak var viewFinderToggleButton: UIButton?
    
    @IBAction func toggleAvatar(sender: UIButton) {
        self.shapeLayer.isHidden = !self.shapeLayer.isHidden
    }
    
    @IBAction func toggleViewFinder(sender: UIButton) {
        controlsViewOpacityState += 1
        let opacityOptions = [Float(1.0), Float(0.4), Float(0.0)]
        self.previewLayer?.opacity = opacityOptions[self.controlsViewOpacityState % 3]
    }
    
    var session: AVCaptureSession?
    let shapeLayer = CAShapeLayer()

    let faceDetection = VNDetectFaceRectanglesRequest()
    let faceLandmarks = VNDetectFaceLandmarksRequest()
    let faceLandmarksDetectionRequest = VNSequenceRequestHandler()
    let faceDetectionRequest = VNSequenceRequestHandler()
    let faceClient = MPOFaceServiceClient(endpointAndSubscriptionKey:"https://westcentralus.api.cognitive.microsoft.com/face/v1.0/", key: "1d692a4678fd49939f43e537185ff60e")
 
    var controlsViewOpacityState = 0
    var frameCounter = 0
    var emotionApiBusy = false;
    var currentEmotion = Emotion.Neutral;
    lazy var previewLayer: AVCaptureVideoPreviewLayer? = {
        guard let session = self.session else { return nil }
        
        var previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        
        return previewLayer
    }()
    
    lazy var classificationRequest: VNCoreMLRequest = {
        // Load the ML model through its generated class and create a Vision request for it.
        do {
            let model = try VNCoreMLModel(for: FaceOff10().model)
            return VNCoreMLRequest(model: model, completionHandler: self.handleClassification)
        } catch {
            fatalError("can't load Vision ML model: \(error)")
        }
    }()
    
    func handleClassification(request: VNRequest, error: Error?) {
        guard let observations = request.results as? [VNClassificationObservation]
            else { fatalError("unexpected result type from VNCoreMLRequest") }
        guard let best = observations.first
            else { fatalError("can't get best result") }
        
        DispatchQueue.main.async {
            switch best.identifier {
            case "neutral":
                self.currentEmotion = Emotion.Neutral
                break
            case "happy":
                self.currentEmotion = Emotion.Happy
                break
            case "sad":
                self.currentEmotion = Emotion.Sad
                break
            case "angry":
                self.currentEmotion = Emotion.Angry
                break
            case "disgust":
                self.currentEmotion = Emotion.Surprised
                break
            default:
                self.currentEmotion = Emotion.Neutral
                break
            }
        }
    }
    
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
        
        layersView!.layer.addSublayer(previewLayer)
        
        shapeLayer.strokeColor = UIColor.red.cgColor
        shapeLayer.lineWidth = 2.0
        
        //needs to filp coordinate system for Vision
        shapeLayer.setAffineTransform(CGAffineTransform(scaleX: -1, y: -1))
        
        shapeLayer.isHidden = true
        
        layersView!.layer.addSublayer(shapeLayer)
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
        
        frameCounter += 1
        
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
                if (frameCounter % 2 == 0 && !emotionApiBusy) {
                    self.emotionApiBusy = true
                    let startTime = Date()
                    let uiImage = UIImage(ciImage: image)
                    UIGraphicsBeginImageContextWithOptions(uiImage.size, false, uiImage.scale)
                    defer { UIGraphicsEndImageContext() }
                    uiImage.draw(in: CGRect(origin: .zero, size: uiImage.size))
                    if let redraw = UIGraphicsGetImageFromCurrentImageContext() {
                        let data = UIImageJPEGRepresentation(redraw, 1.0)
                        let faceAttributes = [(MPOFaceAttributeTypeGender).rawValue, (MPOFaceAttributeTypeAge).rawValue, (MPOFaceAttributeTypeHair).rawValue, (MPOFaceAttributeTypeFacialHair).rawValue, (MPOFaceAttributeTypeMakeup).rawValue, (MPOFaceAttributeTypeEmotion).rawValue, (MPOFaceAttributeTypeOcclusion).rawValue, (MPOFaceAttributeTypeExposure).rawValue, (MPOFaceAttributeTypeHeadPose).rawValue, (MPOFaceAttributeTypeAccessories).rawValue]
                        let faceArrayCompletionBlock = {(collection: Array<MPOFace>?, error: Error?) -> () in
                            if (error != nil) {
                                print(error.debugDescription)
                                self.emotionApiBusy = false
                                return
                            }
                            if (collection?.count == 1) {
                                let face = collection![0]
                                if let emotion = face.attributes!.emotion.mostEmotion {
                                    self.emotionLabel?.text = emotion == "surprise" ? "Mind Blown!" : emotion
                                    switch (emotion) {
                                    case "neutral":
                                        self.currentEmotion = Emotion.Neutral
                                        break
                                    case "happiness":
                                        self.currentEmotion = Emotion.Happy
                                        break
                                    case "sadness", "fear":
                                        self.currentEmotion = Emotion.Sad
                                        break
                                    case "anger", "contempt", "disgust":
                                        self.currentEmotion = Emotion.Angry
                                        break
                                    case "surprise":
                                        self.currentEmotion = Emotion.Surprised
                                    default:
                                        break
                                    }
                                }
                                DrawingManager.faceCustomization.hasEyeglasses = false
                                for accessory in face.attributes.accessories.accessories {
                                    var item = accessory as! [String : Any]
                                    if let type = item["type"] as? String, let confidence = item["confidence"] as? Double {
                                        DrawingManager.faceCustomization.hasEyeglasses = type == "glasses" && confidence > 0.5
                                    }
                                }
                            }
                            self.emotionApiBusy = false
                        } as MPOFaceArrayCompletionBlock
                        
                        faceClient?.detect(with: data, returnFaceId: true, returnFaceLandmarks: true, returnFaceAttributes: faceAttributes, completionBlock: faceArrayCompletionBlock)
                        
                        print("Time taken: ")
                        print(Date().timeIntervalSince(startTime))
                    }
                }
                
                let bb = results[0].boundingBox
                let cropped = image.cropped(to: bb.scaled(to:image.extent.size))
                //classifyEmotion(on: cropped)
                
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
                        
                        DrawingManager.faceCustomization.emotion = self.currentEmotion;
                        
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
    
    func classifyEmotion(on image: CIImage) {
//        let mlArray = convertImage(image: image)
//
//        let model = FaceOff9()
//        do {
//            let output = try model.prediction(input1: mlArray!)
//            print (output.classLabel)
//        }
//        catch {
//            print("Error info: \(error)")
//        }
        
        // Run the Core ML MNIST classifier -- results in handleClassification method
        let handler = VNImageRequestHandler(ciImage: image)
        do {
            try handler.perform([classificationRequest])
        } catch {
            print(error)
        }
    }
    
    func convertImage(image:UIImage) -> MLMultiArray? {
        let size = CGSize(width:48, height:48)
        
        guard let pixels = image.resize(to: size).pixelData() else {
            return nil;
        }
        
        guard let array = try? MLMultiArray(shape: [1, 48, 48], dataType: .double) else {
            return nil
        }
        
        let r = pixels.enumerated().filter { $0.offset % 4 == 0 }.map { $0.element }
        let g = pixels.enumerated().filter { $0.offset % 4 == 1 }.map { $0.element }
        let b = pixels.enumerated().filter { $0.offset % 4 == 2 }.map { $0.element }
        
        var gray = [Double]()
        for i in 0..<r.count {
            let dr = Double(r[i]) * 0.3
            let dg = Double(g[i]) * 0.59
            let db = Double(b[i]) * 0.11
            let temp =  dr + dg + db

            gray.append(temp)
        }
        for (index, element) in gray.enumerated() {
            array[index] = NSNumber(value: element)
        }
        //print(gray)
        
        return array
    }
}
