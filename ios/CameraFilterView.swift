import UIKit
import AVFoundation
import Vision
import CoreImage

// MARK: - Enums & Data Structures

enum FilterId {
    case none
    case smoothSkin
    case brightenGlow
    case slimFace
    case eyeEnhance
    case lipstick
    case lipstickRed
    case lipstickPink
    case lipstickCoral
    case lipstickPlum
    case bigHead
    case fisheyeBulge
    case oldAge
    case babyFace
    case dogEars
    case catEars
    case flowerCrown
    case glassesClassic
    case glassesSun
    case glassesRetro
    case glassesHeart
    case glassesSport
    case hatWizard
    case hatCowboy
    case hatSanta
    case snapButterflies
    case snapNeonOutline
    case snapNeonNeon
    case snapSunsetCowboy
    case snapIcyDalmatian
    case snapRetroBloom
    case snapNoirKitty
    case snapEvilBw
    case snapBowAesthetic
    case snapDarkMoon
    case snapPinkHearts
    case snapDayStamp
    case snapHeartFrame
    case snapCityTime
    case snapPookie
    case snapPandaFace
    case snapVintageGrain
    case snapSpiderman
    case snapEyesReveal
    case snapWantedPoster
    case snapPinkFlower
    case snapRetroSkull
    case snapFashionOverlay
    case snapTalkingForest
    case snapLensVerified
    case snapCreatorHud
    case snapCartoonToon
    case vintage
    case blackWhite
    case vibrant
    case coolTone
    case warmTone

    static func fromJs(_ value: String?) -> FilterId {
        switch value {
        case "smoothSkin": return .smoothSkin
        case "brightenGlow": return .brightenGlow
        case "slimFace": return .slimFace
        case "eyeEnhance": return .eyeEnhance
        case "lipstick": return .lipstick
        case "lipstick_red": return .lipstickRed
        case "lipstick_pink": return .lipstickPink
        case "lipstick_coral": return .lipstickCoral
        case "lipstick_plum": return .lipstickPlum
        case "bigHead": return .bigHead
        case "fisheyeBulge": return .fisheyeBulge
        case "oldAge": return .oldAge
        case "babyFace": return .babyFace
        case "dogEars": return .dogEars
        case "catEars": return .catEars
        case "flowerCrown": return .flowerCrown
        case "glasses", "glasses_classic": return .glassesClassic
        case "glasses_sun": return .glassesSun
        case "glasses_retro": return .glassesRetro
        case "glasses_heart": return .glassesHeart
        case "glasses_sport": return .glassesSport
        case "hat", "hat_wizard": return .hatWizard
        case "hat_cowboy": return .hatCowboy
        case "hat_santa": return .hatSanta
        case "snap_butterflies": return .snapButterflies
        case "snap_neon_outline": return .snapNeonOutline
        case "snap_neon_neon": return .snapNeonNeon
        case "snap_sunset_cowboy": return .snapSunsetCowboy
        case "snap_icy_dalmatian": return .snapIcyDalmatian
        case "snap_retro_bloom": return .snapRetroBloom
        case "snap_noir_kitty": return .snapNoirKitty
        case "snap_evil_bw": return .snapEvilBw
        case "snap_bow_aesthetic": return .snapBowAesthetic
        case "snap_dark_moon": return .snapDarkMoon
        case "snap_pink_hearts": return .snapPinkHearts
        case "snap_day_stamp": return .snapDayStamp
        case "snap_heart_frame": return .snapHeartFrame
        case "snap_city_time": return .snapCityTime
        case "snap_pookie": return .snapPookie
        case "snap_panda_face": return .snapPandaFace
        case "snap_vintage_grain": return .snapVintageGrain
        case "snap_spiderman": return .snapSpiderman
        case "snap_eyes_reveal": return .snapEyesReveal
        case "snap_wanted_poster": return .snapWantedPoster
        case "snap_pink_flower": return .snapPinkFlower
        case "snap_retro_skull": return .snapRetroSkull
        case "snap_fashion_overlay": return .snapFashionOverlay
        case "snap_talking_forest": return .snapTalkingForest
        case "snap_lens_verified": return .snapLensVerified
        case "snap_creator_hud": return .snapCreatorHud
        case "snap_cartoon_toon": return .snapCartoonToon
        case "vintage": return .vintage
        case "blackWhite": return .blackWhite
        case "vibrant": return .vibrant
        case "coolTone": return .coolTone
        case "warmTone": return .warmTone
        default: return .none
        }
    }
}

enum DogStyleType {
    case brown, dalmatian
}

enum CatStyleType {
    case gray, pink
}

enum FlowerStyleType {
    case pink, gold
}

enum GlassStyleType {
    case classic, sun, retro, heart, sport
}

enum HatStyleType {
    case wizard, cowboy, santa
}

struct ControlPoint {
    var x: CGFloat
    var y: CGFloat
    var radius: CGFloat
    var strength: CGFloat
}

struct DetectedFace {
    var boundingBox: CGRect
    var rollAngle: CGFloat
    var yawAngle: CGFloat
    var pitchAngle: CGFloat
    var leftEye: CGPoint?
    var rightEye: CGPoint?
    var noseBase: CGPoint?
    var leftEar: CGPoint?
    var rightEar: CGPoint?
    var leftCheek: CGPoint?
    var rightCheek: CGPoint?
    var faceContour: [CGPoint]?
    var upperLip: [CGPoint]?
    var lowerLip: [CGPoint]?
    var upperLipBottom: [CGPoint]?
    var lowerLipTop: [CGPoint]?
    var smilingProbability: CGFloat?
    var leftEyeOpenProbability: CGFloat?
    var rightEyeOpenProbability: CGFloat?
    var smoothedEyeDistance: CGFloat = 0
}

// MARK: - Color Matrices Catalog

struct ColorMatrices {
    static let VINTAGE: [Float] = [
        0.393, 0.769, 0.189, 0, 0,
        0.349, 0.686, 0.168, 0, 0,
        0.272, 0.534, 0.131, 0, 0,
        0, 0, 0, 1, 0
    ]
    static let BLACK_WHITE: [Float] = [
        0.299, 0.587, 0.114, 0, 0,
        0.299, 0.587, 0.114, 0, 0,
        0.299, 0.587, 0.114, 0, 0,
        0, 0, 0, 1, 0
    ]
    static let VIBRANT: [Float] = [
        1.3935, -0.3575, -0.036, 0, 0,
        -0.1065, 1.1425, -0.036, 0, 0,
        -0.1065, -0.3575, 1.464, 0, 0,
        0, 0, 0, 1, 0
    ]
    static let COOL_TONE: [Float] = [
        0.9, 0, 0, 0, 0,
        0, 1.0, 0, 0, 0,
        0, 0, 1.15, 0, 0,
        0, 0, 0, 1, 0
    ]
    static let WARM_TONE: [Float] = [
        1.15, 0, 0, 0, 0,
        0, 1.05, 0, 0, 0,
        0, 0, 0.85, 0, 0,
        0, 0, 0, 1, 0
    ]
    static let CYBERPUNK: [Float] = [
        1.2, 0, 0.2, 0, 0.05,
        0.1, 0.8, 0, 0, 0,
        0.3, 0, 1.4, 0, 0.05,
        0, 0, 0, 1, 0
    ]
    static let SUNSET: [Float] = [
        1.35, 0, 0, 0, 0.05,
        0.1, 1.0, 0, 0, 0,
        0, 0, 0.7, 0, -0.05,
        0, 0, 0, 1, 0
    ]
    static let ICE: [Float] = [
        0.75, 0.1, 0, 0, 0,
        0, 1.1, 0.1, 0, 0.02,
        0, 0.1, 1.35, 0, 0.06,
        0, 0, 0, 1, 0
    ]
    static let RETRO_FILM: [Float] = [
        0.95, 0.05, 0, 0, 0.05,
        0.05, 0.85, 0, 0, 0.02,
        0, 0.05, 0.70, 0, -0.02,
        0, 0, 0, 1, 0
    ]
    static let BMW_DARK: [Float] = [
        0.75, 0,    0.05, 0, -0.03,
        0,    0.85, 0.05, 0, -0.01,
        0.10, 0.05, 1.30, 0,  0.04,
        0,    0,    0,    1,  0
    ]
    static let AESTHETIC_PINK: [Float] = [
        1.10, 0.04, 0,    0, 0.04,
        0,    1.04, 0.02, 0, 0.03,
        0,    0.02, 1.05, 0, 0.04,
        0,    0,    0,    1, 0
    ]
    static let NOIR: [Float] = [
        0.5, 0.5, 0, 0, -0.08,
        0.5, 0.5, 0, 0, -0.08,
        0.5, 0.5, 0, 0, -0.08,
        0, 0, 0, 1, 0
    ]
    static let DARK_MOON: [Float] = [
        0.25, 0.50, 0.09, 0, -0.03,
        0.25, 0.50, 0.09, 0, -0.03,
        0.25, 0.50, 0.09, 0, -0.03,
        0,    0,    0,    1,  0
    ]
    static let CARTOON: [Float] = [
        2.5777, -0.9862, -0.1915, 0, -0.1569,
        -0.5023, 2.0938, -0.1915, 0, -0.1569,
        -0.5023, -0.9862, 2.8885, 0, -0.1569,
        0,       0,       0,      1, 0
    ]
    static let DAY_STAMP: [Float] = [
        1.04, 0.04, 0.00, 0, 0.04,
        0.02, 1.00, 0.02, 0, 0.02,
        0.00, 0.03, 0.96, 0, 0.01,
        0,    0,    0,    1,  0
    ]
    static let BRIGHT_WHITE: [Float] = [
        1.22, 0.00, 0.00, 0, 0.06,
        0.00, 1.22, 0.00, 0, 0.06,
        0.00, 0.00, 1.22, 0, 0.06,
        0,    0,    0,    1,  0
    ]
    static let VINTAGE_GRAIN: [Float] = [
        0.239, 0.470, 0.091, 0, 0.05,
        0.239, 0.470, 0.091, 0, 0.04,
        0.239, 0.470, 0.091, 0, 0.02,
        0,     0,     0,     1, 0
    ]
    static let GLOW: [Float] = [
        1.15, 0, 0, 0, 0.04,
        0, 1.12, 0, 0, 0.03,
        0, 0, 1.05, 0, 0,
        0, 0, 0, 1, 0
    ]
    static let CREAMY_SOFT_GLOW: [Float] = [
        1.08, 0.02, 0,    0, 0.059,
        0,    1.03, 0.01, 0, 0.031,
        0,    0,    0.95, 0, -0.016,
        0,    0,    0,    1, 0
    ]
}

// MARK: - Main CameraFilterView Class

class CameraFilterView: UIView, AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {

    // MARK: - Properties

    @objc var filter: String = "none" {
        didSet {
            self.currentFilter = FilterId.fromJs(filter)
        }
    }

    private var currentFilter: FilterId = .none

    // UI & Render elements
    private let imageView = UIImageView()
    private var captureSession: AVCaptureSession?
    private var videoOutput: AVCaptureVideoDataOutput?
    private var audioOutput: AVCaptureAudioDataOutput?
    private let sessionQueue = DispatchQueue(label: "com.filtercam.session")
    private let bufferQueue = DispatchQueue(label: "com.filtercam.buffer", qos: .userInteractive)
    private let ciContext = CIContext(options: nil)

    // Video Recording
    private var videoRecorder: FilterVideoRecorder?
    private var isRecording = false
    private var recordPromiseResolve: RCTPromiseResolveBlock?
    private var recordPromiseReject: RCTPromiseRejectBlock?

    // Face detection & tracking
    private var smoothedFaces: [DetectedFace] = []
    private var lastFacesUpdateTime: Double = 0
    private var noiseImage: CGImage?

    // Lazy assets
    private lazy var bowBitmap: CGImage? = UIImage(named: "bow_pookie", in: Bundle(for: CameraFilterView.self), compatibleWith: nil)?.cgImage
    private lazy var pandaBitmap: CGImage? = {
        guard let rawImage = UIImage(named: "panda_face", in: Bundle(for: CameraFilterView.self), compatibleWith: nil)?.cgImage else { return nil }
        let maskingComponents: [CGFloat] = [180, 255, 0, 120, 180, 255]
        guard let maskedImage = rawImage.copy(maskingColorComponents: maskingComponents) else { return rawImage }
        
        let width = rawImage.width
        let height = rawImage.height
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(data: nil,
                                      width: width,
                                      height: height,
                                      bitsPerComponent: 8,
                                      bytesPerRow: 4 * width,
                                      space: colorSpace,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return maskedImage
        }
        
        context.draw(maskedImage, in: CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))
        return context.makeImage()
    }()
    private lazy var skullBitmap: CGImage? = UIImage(named: "retro_skull", in: Bundle(for: CameraFilterView.self), compatibleWith: nil)?.cgImage
    private lazy var fashionBitmap: CGImage? = UIImage(named: "fashion_girl", in: Bundle(for: CameraFilterView.self), compatibleWith: nil)?.cgImage
    private lazy var forestBitmap: CGImage? = UIImage(named: "talking_forest", in: Bundle(for: CameraFilterView.self), compatibleWith: nil)?.cgImage

    // Lens Verified Card States
    private var cardName = "Raksha 🌈"
    private var cardUserId = "RAK_SHA80"
    private var cardDepartment = "printing engineer"
    private var cardRole = "Midnight Scroller ★★★"
    private var cardHobby = "Opening Snapchat 94x/Day"
    private var cardAttentionRate = "5.1 sec"
    private var cardSleepHours = "5.3"
    private var cardDeluluLevel = "97%"
    
    private var currentDeluluVal: CGFloat = 97.0
    private var currentSleepHoursVal: CGFloat = 5.3
    private var currentAttentionRateVal: CGFloat = 5.1

    private var deluluModifier: CGFloat = 0
    private var sleepModifier: CGFloat = 0
    private var attentionModifier: CGFloat = 0

    // Creator HUD States
    private var creatorViewerCount = "1.2TCR"
    private let viewerCounts = ["1.2TCR", "2.8TCR", "5.4CR", "8.9CR", "10.5B", "3.2M", "1.2B", "9.7CR", "15.4TCR", "99.9K"]

    private let names = ["Raksha 🌈", "Abhay 🚀", "Ananya ✨", "Vikram 🦁", "Neha 🌸", "Rahul 🎧", "Sneha 🦄", "Ishaan 🍕", "Priya 🍭", "Kabir 🎸", "Karan 🦁", "Tanya 🦋", "Udesh 📱", "Shreya 🎨"]
    private let departments = ["printing engineer", "sleeping expert", "delulu scientist", "coffee consumer", "meme creator", "bug creator", "vibe inspector", "midnight scroller", "reels therapist", "snack tester"]
    private let roles = ["Midnight Scroller ★★★", "Certified Yapper ★★★", "Professional Overthinker ★★★", "Procrastinator Pro ★★★", "Meme Lord ★★★", "Code Breaker ★★★", "Drama Critic ★★★", "Nap Enthusiast ★★★"]
    private let hobbies = ["Opening Snapchat 94x/Day", "Staring at ceiling", "Creating fake scenarios", "Drinking iced coffee", "Ignoring red flags", "Scrolling until 4 AM", "Buying stuff online", "Talking to pets"]

    // MARK: - Initializers

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupImageView()
        noiseImage = makeNoiseImage()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupImageView()
        noiseImage = makeNoiseImage()
    }

    private func setupImageView() {
        imageView.contentMode = .scaleAspectFill
        imageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
        
        // Tap recognizer to randomize verified card
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        self.addGestureRecognizer(tap)
        self.isUserInteractionEnabled = true
    }

    @objc private func handleTap() {
        if currentFilter == .snapLensVerified {
            randomizeLensVerifiedCard()
        }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            startCamera()
        } else {
            stopCamera()
        }
    }

    // MARK: - Camera Pipeline Setup

    private func startCamera() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if self.captureSession != nil { return }

            let session = AVCaptureSession()
            session.beginConfiguration()
            session.sessionPreset = .hd1280x720

            // Find Front Camera
            guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
                print("Failed to get front camera")
                return
            }

            guard let videoInput = try? AVCaptureDeviceInput(device: videoDevice) else {
                print("Failed to get camera input")
                return
            }

            if session.canAddInput(videoInput) {
                session.addInput(videoInput)
            }

            let output = AVCaptureVideoDataOutput()
            output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
            output.alwaysDiscardsLateVideoFrames = true
            output.setSampleBufferDelegate(self, queue: self.bufferQueue)

            if session.canAddOutput(output) {
                session.addOutput(output)
            }

            if let connection = output.connection(with: .video) {
                if connection.isVideoOrientationSupported {
                    connection.videoOrientation = .portrait
                }
                if connection.isVideoMirroringSupported {
                    connection.isVideoMirrored = true
                }
            }
            
            // Audio setup
            if let audioDevice = AVCaptureDevice.default(for: .audio),
               let audioInput = try? AVCaptureDeviceInput(device: audioDevice),
               session.canAddInput(audioInput) {
                session.addInput(audioInput)
            }
            let aOutput = AVCaptureAudioDataOutput()
            aOutput.setSampleBufferDelegate(self, queue: self.bufferQueue)
            if session.canAddOutput(aOutput) {
                session.addOutput(aOutput)
            }

            session.commitConfiguration()
            session.startRunning()

            self.captureSession = session
            self.videoOutput = output
            self.audioOutput = aOutput
        }
    }

    private func stopCamera() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.captureSession?.stopRunning()
            self.captureSession = nil
            self.videoOutput = nil
        }
    }

    // MARK: - AVCaptureSampleBufferDelegate

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if output == audioOutput {
            if isRecording {
                videoRecorder?.appendAudio(sampleBuffer: sampleBuffer)
            }
            return
        }
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let imageSize = CGSize(width: width, height: height)

        // 1. Run Face Detection
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        let request = VNDetectFaceLandmarksRequest { [weak self] req, err in
            guard let self = self else { return }
            if let results = req.results as? [VNFaceObservation] {
                let detected = self.processFaceObservations(results, imageSize: imageSize)
                self.smoothedFaces = self.smoothFaceData(newFaces: detected)
            }
        }
        
        if #available(iOS 13.0, *) {
            request.revision = VNDetectFaceLandmarksRequestRevision3
        }
        
        try? handler.perform([request])

        // 2. Convert pixel buffer to CIImage
        var ciImage = CIImage(cvImageBuffer: pixelBuffer)

        // 3. Apply Warp Distortions first (CPU process) if required
        if currentFilter == .slimFace || currentFilter == .eyeEnhance || currentFilter == .fisheyeBulge || currentFilter == .babyFace {
            if let cgFrame = ciContext.createCGImage(ciImage, from: ciImage.extent) {
                var warpPoints: [ControlPoint] = []
                if let face = smoothedFaces.first {
                    switch currentFilter {
                    case .slimFace:
                        warpPoints = slimFacePoints(face: face)
                    case .eyeEnhance:
                        warpPoints = eyeEnhancePoints(face: face)
                    case .fisheyeBulge:
                        warpPoints = fisheyePoints(face: face)
                    case .babyFace:
                        warpPoints = babyFacePoints(face: face)
                    default: break
                    }
                }
                
                if !warpPoints.isEmpty {
                    if let warpedCG = applyWarp(image: cgFrame, points: warpPoints) {
                        ciImage = CIImage(cgImage: warpedCG)
                    }
                }
            }
        }

        // 4. Apply Color Matrix Filters
        ciImage = applyColorFilter(ciImage)

        // 5. Draw Overlays using Core Graphics Context
        guard let finalCG = ciContext.createCGImage(ciImage, from: ciImage.extent) else { return }
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerRow = 4 * width
        var pixelData = [UInt8](repeating: 0, count: width * height * 4)
        
        guard let context = CGContext(data: &pixelData,
                                      width: width,
                                      height: height,
                                      bitsPerComponent: 8,
                                      bytesPerRow: bytesPerRow,
                                      space: colorSpace,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue) else {
            return
        }

        // Translate and scale to match UIKit Y-down coordinates
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1.0, y: -1.0)

        // Draw original filtered frame right-side up
        drawCGImageCorrect(finalCG, in: CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)), context: context)

        if currentFilter == .snapCartoonToon {
            drawCartoonEdges(context: context, finalCG: finalCG, size: imageSize)
        }

        // Apply Core Graphics custom drawing/overlays
        UIGraphicsPushContext(context)
        drawOverlayDecorations(context: context, finalCG: finalCG, size: imageSize)
        UIGraphicsPopContext()

        // Generate finished CGImage
        if let finalFrame = context.makeImage() {
            if isRecording {
                let time = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                videoRecorder?.appendVideo(cgImage: finalFrame, time: time)
            }
            
            let uiImage = UIImage(cgImage: finalFrame)
            DispatchQueue.main.async { [weak self] in
                self?.imageView.image = uiImage
            }
        }
    }
    
    // MARK: - Capture API
    
    @objc func capturePhoto(_ resolve: @escaping RCTPromiseResolveBlock, rejecter reject: @escaping RCTPromiseRejectBlock) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let image = self.imageView.image else {
                reject("no_frame", "No camera frame available", nil)
                return
            }
            
            if let data = image.jpegData(compressionQuality: 1.0) {
                let file = NSTemporaryDirectory().appending("filter_photo_\(Date().timeIntervalSince1970).jpg")
                let url = URL(fileURLWithPath: file)
                do {
                    try data.write(to: url)
                    resolve("file://\(file)")
                } catch {
                    reject("error", "Failed to save photo", nil)
                }
            } else {
                reject("error", "Failed to convert image to JPEG", nil)
            }
        }
    }
    
    // MARK: - Recording API
    
    @objc func startRecording(_ resolve: @escaping RCTPromiseResolveBlock, rejecter reject: @escaping RCTPromiseRejectBlock) {
        if isRecording {
            reject("recording", "Already recording", nil)
            return
        }
        
        let file = NSTemporaryDirectory().appending("filter_video_\(Date().timeIntervalSince1970).mp4")
        videoRecorder = FilterVideoRecorder(outputFile: file, width: 720, height: 1280)
        
        if videoRecorder == nil {
            reject("error", "Failed to start recorder", nil)
            return
        }
        
        videoRecorder?.start()
        isRecording = true
        resolve(nil)
    }
    
    @objc func stopRecording(_ resolve: @escaping RCTPromiseResolveBlock, rejecter reject: @escaping RCTPromiseRejectBlock) {
        if !isRecording {
            reject("not_recording", "Not recording", nil)
            return
        }
        
        isRecording = false
        videoRecorder?.stop { path in
            if let p = path {
                resolve(p)
            } else {
                reject("error", "Failed to save video", nil)
            }
        }
    }

    // MARK: - Face Observation Processing

    private func processFaceObservations(_ observations: [VNFaceObservation], imageSize: CGSize) -> [DetectedFace] {
        return observations.map { face in
            let box = face.boundingBox
            // Convert Vision coordinate space (0..1 bottom-left) to display coordinate space (top-left)
            let x = box.origin.x * imageSize.width
            let y = (1.0 - box.origin.y - box.size.height) * imageSize.height
            let w = box.size.width * imageSize.width
            let h = box.size.height * imageSize.height
            let boundingBox = CGRect(x: x, y: y, width: w, height: h)

            var roll: CGFloat = 0
            if let r = face.roll {
                roll = CGFloat(r.floatValue) * 180.0 / .pi
            }
            var yaw: CGFloat = 0
            if let y = face.yaw {
                yaw = CGFloat(y.floatValue) * 180.0 / .pi
            }
            var pitch: CGFloat = 0
            if #available(iOS 15.0, *), let p = face.pitch {
                pitch = CGFloat(p.floatValue) * 180.0 / .pi
            }

            func getPoints(_ landmark: VNFaceLandmarkRegion2D?) -> [CGPoint]? {
                guard let landmark = landmark, landmark.pointCount > 0 else { return nil }
                return (0..<landmark.pointCount).map { i in
                    let p = landmark.normalizedPoints[i]
                    let px = boundingBox.origin.x + CGFloat(p.x) * boundingBox.width
                    let py = boundingBox.origin.y + (1.0 - CGFloat(p.y)) * boundingBox.height
                    return CGPoint(x: px, y: py)
                }
            }

            let landmarks = face.landmarks
            let faceContour = getPoints(landmarks?.faceContour)
            let leftEyePts = getPoints(landmarks?.leftEye)
            let rightEyePts = getPoints(landmarks?.rightEye)
            let nosePts = getPoints(landmarks?.nose)

            let leftEye = leftEyePts != nil ? averagePoint(leftEyePts!) : nil
            let rightEye = rightEyePts != nil ? averagePoint(rightEyePts!) : nil
            let noseBase = nosePts != nil ? nosePts!.last : nil

            let eyeDist = (leftEye != nil && rightEye != nil) ? hypot(rightEye!.x - leftEye!.x, rightEye!.y - leftEye!.y) : w * 0.4
            
            // Cheeks and ears fallbacks
            let leftCheek = leftEye != nil ? CGPoint(x: leftEye!.x - eyeDist * 0.1, y: leftEye!.y + eyeDist * 0.35) : nil
            let rightCheek = rightEye != nil ? CGPoint(x: rightEye!.x + eyeDist * 0.1, y: rightEye!.y + eyeDist * 0.35) : nil
            let leftEar = leftEye != nil ? CGPoint(x: boundingBox.minX, y: leftEye!.y) : nil
            let rightEar = rightEye != nil ? CGPoint(x: boundingBox.maxX, y: rightEye!.y) : nil

            var upperLip: [CGPoint]? = nil
            var lowerLip: [CGPoint]? = nil
            var upperLipBottom: [CGPoint]? = nil
            var lowerLipTop: [CGPoint]? = nil
            
            if let outer = getPoints(landmarks?.outerLips) {
                let n = outer.count
                upperLip = Array(outer[0..<(n/2)])
                lowerLip = Array(outer[(n/2)..<n].reversed())
            }
            
            if let inner = getPoints(landmarks?.innerLips) {
                let m = inner.count
                upperLipBottom = Array(inner[0..<(m/2)])
                lowerLipTop = Array(inner[(m/2)..<m].reversed())
            }

            return DetectedFace(
                boundingBox: boundingBox,
                rollAngle: roll,
                yawAngle: yaw,
                pitchAngle: pitch,
                leftEye: leftEye,
                rightEye: rightEye,
                noseBase: noseBase,
                leftEar: leftEar,
                rightEar: rightEar,
                leftCheek: leftCheek,
                rightCheek: rightCheek,
                faceContour: faceContour,
                upperLip: upperLip,
                lowerLip: lowerLip,
                upperLipBottom: upperLipBottom,
                lowerLipTop: lowerLipTop,
                smilingProbability: 0.5,
                leftEyeOpenProbability: 0.9,
                rightEyeOpenProbability: 0.9,
                smoothedEyeDistance: eyeDist
            )
        }
    }

    private func averagePoint(_ pts: [CGPoint]) -> CGPoint {
        var x: CGFloat = 0
        var y: CGFloat = 0
        for p in pts {
            x += p.x
            y += p.y
        }
        return CGPoint(x: x / CGFloat(pts.count), y: y / CGFloat(pts.count))
    }

    private func smoothFaceData(newFaces: [DetectedFace]) -> [DetectedFace] {
        if self.smoothedFaces.isEmpty {
            return newFaces
        }
        
        var output: [DetectedFace] = []
        for newFace in newFaces {
            if let matchIdx = self.smoothedFaces.firstIndex(where: {
                hypot($0.boundingBox.midX - newFace.boundingBox.midX, $0.boundingBox.midY - newFace.boundingBox.midY) < 150
            }) {
                let prevFace = self.smoothedFaces[matchIdx]
                let smoothedRoll = prevFace.rollAngle * 0.7 + newFace.rollAngle * 0.3
                let smoothedYaw = prevFace.yawAngle * 0.7 + newFace.yawAngle * 0.3
                let smoothedPitch = prevFace.pitchAngle * 0.7 + newFace.pitchAngle * 0.3
                
                let smoothedBox = CGRect(
                    x: prevFace.boundingBox.origin.x * 0.7 + newFace.boundingBox.origin.x * 0.3,
                    y: prevFace.boundingBox.origin.y * 0.7 + newFace.boundingBox.origin.y * 0.3,
                    width: prevFace.boundingBox.size.width * 0.7 + newFace.boundingBox.size.width * 0.3,
                    height: prevFace.boundingBox.size.height * 0.7 + newFace.boundingBox.size.height * 0.3
                )
                
                func smoothPoint(_ p1: CGPoint?, _ p2: CGPoint?) -> CGPoint? {
                    guard let p1 = p1, let p2 = p2 else { return p2 ?? p1 }
                    return CGPoint(x: p1.x * 0.7 + p2.x * 0.3, y: p1.y * 0.7 + p2.y * 0.3)
                }
                
                func smoothPoints(_ pts1: [CGPoint]?, _ pts2: [CGPoint]?) -> [CGPoint]? {
                    guard let pts1 = pts1, let pts2 = pts2, pts1.count == pts2.count else { return pts2 ?? pts1 }
                    return (0..<pts1.count).map { i in
                        CGPoint(x: pts1[i].x * 0.7 + pts2[i].x * 0.3, y: pts1[i].y * 0.7 + pts2[i].y * 0.3)
                    }
                }
                
                var smoothedFace = DetectedFace(
                    boundingBox: smoothedBox,
                    rollAngle: smoothedRoll,
                    yawAngle: smoothedYaw,
                    pitchAngle: smoothedPitch,
                    leftEye: smoothPoint(prevFace.leftEye, newFace.leftEye),
                    rightEye: smoothPoint(prevFace.rightEye, newFace.rightEye),
                    noseBase: smoothPoint(prevFace.noseBase, newFace.noseBase),
                    leftEar: smoothPoint(prevFace.leftEar, newFace.leftEar),
                    rightEar: smoothPoint(prevFace.rightEar, newFace.rightEar),
                    leftCheek: smoothPoint(prevFace.leftCheek, newFace.leftCheek),
                    rightCheek: smoothPoint(prevFace.rightCheek, newFace.rightCheek),
                    faceContour: smoothPoints(prevFace.faceContour, newFace.faceContour),
                    upperLip: smoothPoints(prevFace.upperLip, newFace.upperLip),
                    lowerLip: smoothPoints(prevFace.lowerLip, newFace.lowerLip),
                    upperLipBottom: smoothPoints(prevFace.upperLipBottom, newFace.upperLipBottom),
                    lowerLipTop: smoothPoints(prevFace.lowerLipTop, newFace.lowerLipTop),
                    smilingProbability: newFace.smilingProbability,
                    leftEyeOpenProbability: newFace.leftEyeOpenProbability,
                    rightEyeOpenProbability: newFace.rightEyeOpenProbability
                )
                
                let curEyeDist = eyeDistance(smoothedFace)
                smoothedFace.smoothedEyeDistance = prevFace.smoothedEyeDistance * 0.7 + curEyeDist * 0.3
                
                output.append(smoothedFace)
            } else {
                var f = newFace
                f.smoothedEyeDistance = eyeDistance(f)
                output.append(f)
            }
        }
        return output
    }

    private func eyeDistance(_ face: DetectedFace) -> CGFloat {
        guard let l = face.leftEye, let r = face.rightEye else { return face.boundingBox.width * 0.4 }
        return hypot(r.x - l.x, r.y - l.y)
    }

    // MARK: - Color Filters Application

    private func applyColorFilter(_ image: CIImage) -> CIImage {
        switch currentFilter {
        case .vintage, .snapWantedPoster:
            return applyColorMatrix(image, matrix: ColorMatrices.VINTAGE)
        case .blackWhite, .snapButterflies, .snapEvilBw, .snapPinkHearts, .snapPandaFace, .snapSpiderman:
            return applyColorMatrix(image, matrix: ColorMatrices.BLACK_WHITE)
        case .vibrant, .snapNeonOutline:
            return applyColorMatrix(image, matrix: ColorMatrices.VIBRANT)
        case .coolTone:
            return applyColorMatrix(image, matrix: ColorMatrices.COOL_TONE)
        case .warmTone, .snapPookie:
            return applyColorMatrix(image, matrix: ColorMatrices.WARM_TONE)
        case .snapNeonNeon:
            return applyColorMatrix(image, matrix: ColorMatrices.CYBERPUNK)
        case .snapSunsetCowboy:
            return applyColorMatrix(image, matrix: ColorMatrices.SUNSET)
        case .snapIcyDalmatian:
            return applyColorMatrix(image, matrix: ColorMatrices.ICE)
        case .snapRetroBloom:
            return applyColorMatrix(image, matrix: ColorMatrices.RETRO_FILM)
        case .snapNoirKitty:
            return applyColorMatrix(image, matrix: ColorMatrices.BRIGHT_WHITE)
        case .snapDarkMoon, .snapRetroSkull:
            return applyColorMatrix(image, matrix: ColorMatrices.DARK_MOON)
        case .snapCartoonToon:
            return applyColorMatrix(image, matrix: ColorMatrices.CARTOON)
        case .snapBowAesthetic, .snapPinkFlower:
            return applyColorMatrix(image, matrix: ColorMatrices.AESTHETIC_PINK)
        case .snapDayStamp:
            return applyColorMatrix(image, matrix: ColorMatrices.DAY_STAMP)
        case .snapVintageGrain:
            return applyColorMatrix(image, matrix: ColorMatrices.VINTAGE_GRAIN)
        case .snapCreatorHud:
            return applyColorMatrix(image, matrix: ColorMatrices.CREAMY_SOFT_GLOW)
        default:
            return image
        }
    }

    private func applyColorMatrix(_ image: CIImage, matrix: [Float]) -> CIImage {
        let filter = CIFilter(name: "CIColorMatrix")!
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(CIVector(x: CGFloat(matrix[0]), y: CGFloat(matrix[1]), z: CGFloat(matrix[2]), w: CGFloat(matrix[3])), forKey: "inputRVector")
        filter.setValue(CIVector(x: CGFloat(matrix[5]), y: CGFloat(matrix[6]), z: CGFloat(matrix[7]), w: CGFloat(matrix[8])), forKey: "inputGVector")
        filter.setValue(CIVector(x: CGFloat(matrix[10]), y: CGFloat(matrix[11]), z: CGFloat(matrix[12]), w: CGFloat(matrix[13])), forKey: "inputBVector")
        filter.setValue(CIVector(x: CGFloat(matrix[15]), y: CGFloat(matrix[16]), z: CGFloat(matrix[17]), w: CGFloat(matrix[18])), forKey: "inputAVector")
        filter.setValue(CIVector(x: CGFloat(matrix[4]), y: CGFloat(matrix[9]), z: CGFloat(matrix[14]), w: CGFloat(matrix[19])), forKey: "inputBiasVector")
        return filter.outputImage ?? image
    }

    // MARK: - Core Graphics Overlay Rendering

    private func drawOverlayDecorations(context: CGContext, finalCG: CGImage, size: CGSize) {
        // General Color Stamp text or letterbox overlays
        if currentFilter == .snapDayStamp {
            drawDayStampText(context: context, size: size)
        }

        if currentFilter == .snapVintageGrain {
            drawVintageGrainLetterbox(context: context, size: size)
        }

        if currentFilter == .snapWantedPoster {
            if let cgImg = context.makeImage() {
                drawWantedPoster(context: context, frame: cgImg, size: size)
            }
        }

        if currentFilter == .snapLensVerified {
            if let cgImg = context.makeImage() {
                drawLensVerifiedCard(context: context, frame: cgImg, face: smoothedFaces.first, size: size)
            }
        }

        if currentFilter == .snapHeartFrame {
            drawHeartFrame(context: context, size: size)
        }

        if currentFilter == .snapCityTime {
            drawCityTime(context: context, size: size)
        }

        if currentFilter == .snapFashionOverlay {
            drawFashionOverlay(context: context, finalCG: finalCG, size: size)
        }

        // Face-specific overlays
        for face in smoothedFaces {
            // Apply beauty treatments
            if currentFilter == .smoothSkin {
                if let cgImg = context.makeImage() {
                    drawSmoothSkin(context: context, frame: cgImg, face: face)
                }
            }
            if currentFilter == .brightenGlow {
                drawBrightenGlow(context: context, face: face)
            }
            if currentFilter == .lipstick || currentFilter == .lipstickRed {
                drawLipstick(context: context, face: face, colorType: "red")
            } else if currentFilter == .lipstickPink {
                drawLipstick(context: context, face: face, colorType: "pink")
            } else if currentFilter == .lipstickCoral {
                drawLipstick(context: context, face: face, colorType: "coral")
            } else if currentFilter == .lipstickPlum {
                drawLipstick(context: context, face: face, colorType: "plum")
            }

            // Draw custom overlays
            switch currentFilter {
            case .dogEars, .snapIcyDalmatian:
                drawDogEars(context: context, face: face, isDalmatian: currentFilter == .snapIcyDalmatian)
            case .catEars, .snapNoirKitty:
                drawCatEars(context: context, face: face, isPink: currentFilter == .snapNoirKitty)
            case .flowerCrown, .snapRetroBloom:
                drawFlowerCrown(context: context, face: face, isGold: currentFilter == .snapRetroBloom)
            case .glassesClassic:
                drawGlasses(context: context, face: face, style: .classic)
            case .glassesSun:
                drawGlasses(context: context, face: face, style: .sun)
            case .glassesRetro:
                drawGlasses(context: context, face: face, style: .retro)
            case .glassesHeart:
                drawGlasses(context: context, face: face, style: .heart)
            case .glassesSport, .snapNeonNeon:
                drawGlasses(context: context, face: face, style: .sport)
            case .hatWizard:
                drawHat(context: context, face: face, style: .wizard)
            case .hatCowboy, .snapSunsetCowboy:
                drawHat(context: context, face: face, style: .cowboy)
            case .hatSanta:
                drawHat(context: context, face: face, style: .santa)
            case .snapButterflies:
                drawButterflies(context: context, face: face)
            case .snapNeonOutline:
                drawNeonOutline(context: context, face: face, size: size)
            case .snapEvilBw:
                drawEvilHorns(context: context, face: face)
            case .snapBowAesthetic:
                drawPinkBows(context: context, face: face)
            case .snapDarkMoon:
                drawCrescentMoons(context: context, face: face)
            case .snapPinkHearts:
                drawPinkHearts(context: context, face: face)
            case .snapPookie:
                drawPookieBow(context: context, face: face)
            case .snapPandaFace:
                drawPandaFaces(context: context, face: face)
            case .snapSpiderman:
                drawSpidermanMask(context: context, face: face)
            case .snapEyesReveal:
                if let cgImg = context.makeImage() {
                    drawEyesReveal(context: context, frame: cgImg, face: face, size: size)
                }
            case .snapPinkFlower:
                drawPlumeriaFlower(context: context, face: face)
            case .snapRetroSkull:
                drawSkullFixed(context: context, size: size)
            case .snapTalkingForest:
                if let cgImg = context.makeImage() {
                    drawTalkingForest(context: context, frame: cgImg, face: face, size: size)
                }
            case .oldAge:
                if let cgImg = context.makeImage() {
                    drawOldAge(context: context, frame: cgImg, face: face)
                }
            case .bigHead:
                if let cgImg = context.makeImage() {
                    drawBigHead(context: context, frame: cgImg, face: face)
                }
            default: break
            }
        }

        // Top level overlays
        if currentFilter == .snapCreatorHud {
            drawCreatorHud(context: context, size: size)
        }
    }

    // MARK: - Overlay Implementations

    private func withHeadRotation(context: CGContext, anchor: CGPoint, rollAngle: CGFloat, draw: () -> Void) {
        context.saveGState()
        context.translateBy(x: anchor.x, y: anchor.y)
        context.rotate(by: -rollAngle * .pi / 180.0)
        context.translateBy(x: -anchor.x, y: -anchor.y)
        draw()
        context.restoreGState()
    }

    private func withFaceCoordSystem(context: CGContext, anchor: CGPoint, rollAngle: CGFloat, draw: () -> Void) {
        context.saveGState()
        context.translateBy(x: anchor.x, y: anchor.y)
        context.rotate(by: -rollAngle * .pi / 180.0)
        draw()
        context.restoreGState()
    }

    private func getLocalPoint(screenPt: CGPoint, anchor: CGPoint, rollAngle: CGFloat) -> CGPoint {
        let dx = screenPt.x - anchor.x
        let dy = screenPt.y - anchor.y
        let rad = -rollAngle * .pi / 180.0
        let cosA = cos(rad)
        let sinA = sin(rad)
        let rx = dx * cosA + dy * sinA
        let ry = -dx * sinA + dy * cosA
        return CGPoint(x: rx, y: ry)
    }

    private func colorFromHex(_ hex: String) -> UIColor {
        var cString: String = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        if cString.hasPrefix("#") {
            cString.remove(at: cString.startIndex)
        }

        if cString.count != 6 {
            return UIColor.gray
        }

        var rgbValue: UInt64 = 0
        Scanner(string: cString).scanHexInt64(&rgbValue)

        return UIColor(
            red: CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0,
            green: CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0,
            blue: CGFloat(rgbValue & 0x0000FF) / 255.0,
            alpha: 1.0
        )
    }

    private func faceOvalPath(face: DetectedFace) -> CGPath? {
        guard let pts = face.faceContour, !pts.isEmpty else { return nil }
        let path = CGMutablePath()
        
        let b = face.boundingBox
        let cx = b.midX
        let cy = b.midY
        
        let rad = -face.rollAngle * .pi / 180.0
        let cosA = cos(rad)
        let sinA = sin(rad)
        
        func toLocal(_ pt: CGPoint) -> CGPoint {
            let dx = pt.x - cx
            let dy = pt.y - cy
            let lx = dx * cosA + dy * sinA
            let ly = -dx * sinA + dy * cosA
            return CGPoint(x: lx, y: ly)
        }
        
        func toScreen(_ pt: CGPoint) -> CGPoint {
            let rx = pt.x * cosA - pt.y * sinA
            let ry = pt.x * sinA + pt.y * cosA
            return CGPoint(x: cx + rx, y: cy + ry)
        }
        
        var localPts: [CGPoint] = []
        for pt in pts {
            let localPt = toLocal(pt)
            // Expand cheeks/jaw horizontally by 1.22x and chin vertically by 1.16x to ensure full-face coverage
            let expandedLocal = CGPoint(x: localPt.x * 1.22, y: localPt.y * 1.16)
            localPts.append(expandedLocal)
        }
        
        path.move(to: toScreen(localPts[0]))
        for i in 1..<localPts.count {
            path.addLine(to: toScreen(localPts[i]))
        }
        
        let rightTempleLocal = localPts[localPts.count - 1]
        let leftTempleLocal = localPts[0]
        // Shift forehead boundary 38% higher above the bounding box top to cover full hairline
        let localTopY = -b.height * 0.88
        
        let localControl1 = CGPoint(x: rightTempleLocal.x + b.width * 0.15, y: localTopY)
        let localControl2 = CGPoint(x: leftTempleLocal.x - b.width * 0.15, y: localTopY)
        
        path.addCurve(to: toScreen(leftTempleLocal),
                      control1: toScreen(localControl1),
                      control2: toScreen(localControl2))
        
        path.closeSubpath()
        return path
    }

    private func upperLipPath(face: DetectedFace) -> CGPath? {
        guard let top = face.upperLip, let bottom = face.upperLipBottom else { return nil }
        let path = CGMutablePath()
        path.move(to: top[0])
        for i in 1..<top.count { path.addLine(to: top[i]) }
        for i in (0..<bottom.count).reversed() { path.addLine(to: bottom[i]) }
        path.closeSubpath()
        return path
    }

    private func lowerLipPath(face: DetectedFace) -> CGPath? {
        guard let top = face.lowerLipTop, let bottom = face.lowerLip else { return nil }
        let path = CGMutablePath()
        path.move(to: top[0])
        for i in 1..<top.count { path.addLine(to: top[i]) }
        for i in (0..<bottom.count).reversed() { path.addLine(to: bottom[i]) }
        path.closeSubpath()
        return path
    }

    private func topOfHeadPoint(face: DetectedFace) -> CGPoint? {
        guard let pts = face.faceContour, !pts.isEmpty else { return nil }
        var top = pts[0]
        for p in pts {
            if p.y < top.y { top = p }
        }
        return top
    }

    // MARK: - Beauty Filters

    private func drawSmoothSkin(context: CGContext, frame: CGImage, face: DetectedFace) {
        guard let path = faceOvalPath(face: face) else { return }
        let rect = face.boundingBox
        
        let frameRect = CGRect(x: 0, y: 0, width: CGFloat(frame.width), height: CGFloat(frame.height))
        let cropRect = rect.intersection(frameRect)
        if cropRect.isEmpty || cropRect.width <= 1 || cropRect.height <= 1 { return }
        
        guard let cropped = frame.cropping(to: cropRect),
              let blurred = blurImage(cropped, radius: 12) else { return }
        
        context.saveGState()
        context.addPath(path)
        context.clip()
        context.setAlpha(0.55)
        drawCGImageCorrect(blurred, in: cropRect, context: context)
        context.restoreGState()
    }

    private func drawBrightenGlow(context: CGContext, face: DetectedFace) {
        guard let path = faceOvalPath(face: face) else { return }
        
        context.saveGState()
        context.addPath(path)
        context.clip()
        
        // Simulating GLOW with 50% opacity overlays
        context.setFillColor(red: 1.0, green: 0.98, blue: 0.95, alpha: 0.12)
        context.addPath(path)
        context.fillPath()
        context.restoreGState()
    }

    private func drawLipstick(context: CGContext, face: DetectedFace, colorType: String) {
        let upper = upperLipPath(face: face)
        let lower = lowerLipPath(face: face)
        if upper == nil && lower == nil { return }
        
        let color: UIColor
        switch colorType {
        case "pink": color = UIColor(red: 1.0, green: 60.0/255.0, blue: 150.0/255.0, alpha: 0.37)
        case "coral": color = UIColor(red: 1.0, green: 115.0/255.0, blue: 65.0/255.0, alpha: 0.37)
        case "plum": color = UIColor(red: 128.0/255.0, green: 0, blue: 128.0/255.0, alpha: 0.43)
        default: color = UIColor(red: 220.0/255.0, green: 20.0/255.0, blue: 60.0/255.0, alpha: 0.41)
        }
        
        context.saveGState()
        context.setFillColor(color.cgColor)
        if let u = upper {
            context.addPath(u)
            context.fillPath()
        }
        if let l = lower {
            context.addPath(l)
            context.fillPath()
        }
        context.restoreGState()
    }

    private func blurImage(_ image: CGImage, radius: CGFloat) -> CGImage? {
        let ciInput = CIImage(cgImage: image)
        let clamped = ciInput.clampedToExtent()
        let filter = CIFilter(name: "CIGaussianBlur")!
        filter.setValue(clamped, forKey: kCIInputImageKey)
        filter.setValue(radius, forKey: kCIInputRadiusKey)
        guard let ciOutput = filter.outputImage else { return nil }
        let cropped = ciOutput.cropped(to: ciInput.extent)
        return ciContext.createCGImage(cropped, from: cropped.extent)
    }

    // MARK: - Face Warp CPU implementation

    private func applyWarp(image: CGImage, points: [ControlPoint]) -> CGImage? {
        let width = image.width
        let height = image.height
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        
        var pixelData = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(data: &pixelData,
                                      width: width,
                                      height: height,
                                      bitsPerComponent: 8,
                                      bytesPerRow: bytesPerRow,
                                      space: colorSpace,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue) else {
            return nil
        }
        
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1.0, y: -1.0)
        context.draw(image, in: CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))
        let srcPixels = pixelData
        
        for point in points {
            guard point.radius > 0 else { continue }
            
            let minX = max(0, Int(point.x - point.radius))
            let maxX = min(width - 1, Int(point.x + point.radius))
            let minY = max(0, Int(point.y - point.radius))
            let maxY = min(height - 1, Int(point.y + point.radius))
            
            for y in minY...maxY {
                for x in minX...maxX {
                    let dx = CGFloat(x) - point.x
                    let dy = CGFloat(y) - point.y
                    let dist = hypot(dx, dy)
                    
                    let idx = (y * width + x) * 4
                    if dist >= point.radius || dist < 0.0001 {
                        continue
                    }
                    
                    let normalized = dist / point.radius
                    let normClamped = max(0, min(1, normalized))
                    let falloff = 1.0 - (normClamped * normClamped * (3.0 - 2.0 * normClamped))
                    
                    let dirX = dx / dist
                    let dirY = dy / dist
                    
                    let srcX = max(0, min(width - 1, Int(CGFloat(x) - dirX * point.strength * falloff)))
                    let srcY = max(0, min(height - 1, Int(CGFloat(y) - dirY * point.strength * falloff)))
                    
                    let srcIdx = (srcY * width + srcX) * 4
                    pixelData[idx] = srcPixels[srcIdx]
                    pixelData[idx+1] = srcPixels[srcIdx+1]
                    pixelData[idx+2] = srcPixels[srcIdx+2]
                    pixelData[idx+3] = srcPixels[srcIdx+3]
                }
            }
        }
        return context.makeImage()
    }

    private func eyeEnhancePoints(face: DetectedFace) -> [ControlPoint] {
        guard let le = face.leftEye, let re = face.rightEye else { return [] }
        let dist = eyeDistance(face)
        if dist == 0 { return [] }
        let radius = dist * 0.45
        let strength = dist * 0.16
        return [
            ControlPoint(x: le.x, y: le.y, radius: radius, strength: strength),
            ControlPoint(x: re.x, y: re.y, radius: radius, strength: strength)
        ]
    }

    private func slimFacePoints(face: DetectedFace) -> [ControlPoint] {
        guard let lc = face.leftCheek, let rc = face.rightCheek else { return [] }
        let dist = eyeDistance(face)
        if dist == 0 { return [] }
        let radius = dist * 0.9
        let strength = -dist * 0.18
        return [
            ControlPoint(x: lc.x, y: lc.y, radius: radius, strength: strength),
            ControlPoint(x: rc.x, y: rc.y, radius: radius, strength: strength)
        ]
    }

    private func fisheyePoints(face: DetectedFace) -> [ControlPoint] {
        let dist = eyeDistance(face)
        if dist == 0 { return [] }
        let cx = face.boundingBox.midX
        let cy = face.boundingBox.midY
        return [ControlPoint(x: cx, y: cy, radius: face.boundingBox.width * 0.95, strength: dist * 0.28)]
    }

    private func babyFacePoints(face: DetectedFace) -> [ControlPoint] {
        return eyeEnhancePoints(face: face) + slimFacePoints(face: face)
    }

    // MARK: - Distortions

    private func drawBigHead(context: CGContext, frame: CGImage, face: DetectedFace) {
        let b = face.boundingBox
        let cx = b.midX
        let cy = b.midY
        let scaleFactor: CGFloat = 1.55
        
        context.saveGState()
        
        let path = faceOvalPath(face: face)
        if let p = path {
            var transform = CGAffineTransform(translationX: cx, y: cy)
                .scaledBy(x: scaleFactor, y: scaleFactor)
                .translatedBy(x: -cx, y: -cy)
            if let transformedPath = p.copy(using: &transform) {
                context.addPath(transformedPath)
                context.clip()
            }
        } else {
            let radius = max(b.width, b.height) * 0.50 * scaleFactor
            context.addEllipse(in: CGRect(x: cx - radius, y: cy - radius, width: radius * 2, height: radius * 2))
            context.clip()
        }
        
        // Scale content around (cx, cy)
        context.translateBy(x: cx, y: cy)
        context.scaleBy(x: scaleFactor, y: scaleFactor)
        context.translateBy(x: -cx, y: -cy)
        
        drawCGImageCorrect(frame, in: CGRect(x: 0, y: 0, width: CGFloat(frame.width), height: CGFloat(frame.height)), context: context)
        context.restoreGState()
    }

    private func drawOldAge(context: CGContext, frame: CGImage, face: DetectedFace) {
        guard let path = faceOvalPath(face: face) else { return }
        let b = face.boundingBox
        let eyeDist = eyeDistance(face)
        
        context.saveGState()
        context.addPath(path)
        context.clip()
        
        // Aged color effect overlay
        context.setFillColor(red: 0.4, green: 0.35, blue: 0.3, alpha: 0.25)
        context.addPath(path)
        context.fillPath()
        
        // Forehead lines
        context.setStrokeColor(red: 0, green: 0, blue: 0, alpha: 0.35)
        context.setLineWidth(max(1.0, b.width * 0.01))
        let foreheadY = b.minY + b.height * 0.18
        for i in 0..<3 {
            let lineY = foreheadY + CGFloat(i) * eyeDist * 0.12
            context.move(to: CGPoint(x: b.minX + b.width * 0.25, y: lineY))
            context.addLine(to: CGPoint(x: b.minX + b.width * 0.75, y: lineY))
            context.strokePath()
        }
        
        // Crow's feet
        if let le = face.leftEye { drawCrowsFeet(context: context, eye: le, eyeDist: eyeDist, side: -1) }
        if let re = face.rightEye { drawCrowsFeet(context: context, eye: re, eyeDist: eyeDist, side: 1) }
        
        context.restoreGState()
        
        // Gray hair oval
        if let top = topOfHeadPoint(face: face) {
            context.saveGState()
            context.setFillColor(red: 0.7, green: 0.7, blue: 0.7, alpha: 0.6)
            let hairRect = CGRect(
                x: top.x - b.width * 0.45,
                y: top.y - b.height * 0.15,
                width: b.width * 0.9,
                height: b.height * 0.35
            )
            context.fillEllipse(in: hairRect)
            context.restoreGState()
        }
    }

    private func drawCrowsFeet(context: CGContext, eye: CGPoint, eyeDist: CGFloat, side: CGFloat) {
        let len = eyeDist * 0.18
        let baseX = eye.x + side * eyeDist * 0.28
        let baseY = eye.y
        context.setLineWidth(max(1.0, eyeDist * 0.015))
        context.setStrokeColor(red: 0, green: 0, blue: 0, alpha: 0.35)
        for i in -1...1 {
            let angle = CGFloat(i) * 20.0 * .pi / 180.0
            let dx = cos(angle) * len * side
            let dy = sin(angle) * len + CGFloat(i) * 2.0
            context.move(to: CGPoint(x: baseX, y: baseY))
            context.addLine(to: CGPoint(x: baseX + dx, y: baseY + dy))
            context.strokePath()
        }
    }

    // MARK: - AR Overlays

    private func drawDogEars(context: CGContext, face: DetectedFace, isDalmatian: Bool) {
        let box = face.boundingBox
        let faceW = box.width
        let faceH = box.height
        
        let rollAngle = face.rollAngle
        let faceCx = (face.leftEye != nil && face.rightEye != nil) ? (face.leftEye!.x + face.rightEye!.x) / 2.0 : box.midX
        let faceCy = (face.leftEye != nil && face.rightEye != nil) ? (face.leftEye!.y + face.rightEye!.y) / 2.0 : box.minY + faceH * 0.45
        let eyeDist = (face.leftEye != nil && face.rightEye != nil) ? eyeDistance(face) : faceW * 0.35
        
        let nose = face.noseBase ?? CGPoint(x: faceCx, y: faceCy + eyeDist * 0.35)
        
        let earLocalY = -eyeDist * 1.45
        let noseLocalY = nose.y - faceCy

        withFaceCoordSystem(context: context, anchor: CGPoint(x: faceCx, y: faceCy), rollAngle: rollAngle) {
            // Colors
            let earColor = isDalmatian ? UIColor.white : UIColor(red: 110/255, green: 71/255, blue: 47/255, alpha: 1)
            let innerEarColor = isDalmatian ? UIColor(red: 255/255, green: 204/255, blue: 213/255, alpha: 1) : UIColor(red: 217/255, green: 154/255, blue: 124/255, alpha: 1)
            let borderColor = isDalmatian ? UIColor(red: 220/255, green: 220/255, blue: 220/255, alpha: 1) : UIColor(red: 91/255, green: 58/255, blue: 36/255, alpha: 1)

            let leftEarX = eyeDist * 0.60
            let rightEarX = -eyeDist * 0.60

            // 1. Left Ear
            let leftPath = CGMutablePath()
            leftPath.move(to: CGPoint(x: leftEarX, y: earLocalY + eyeDist * 0.1))
            leftPath.addCurve(to: CGPoint(x: leftEarX + eyeDist * 0.7, y: earLocalY + eyeDist * 0.15),
                              control1: CGPoint(x: leftEarX + eyeDist * 0.25, y: earLocalY - eyeDist * 0.18),
                              control2: CGPoint(x: leftEarX + eyeDist * 0.55, y: earLocalY - eyeDist * 0.08))
            leftPath.addCurve(to: CGPoint(x: leftEarX + eyeDist * 0.5, y: earLocalY + eyeDist * 0.88),
                              control1: CGPoint(x: leftEarX + eyeDist * 0.88, y: earLocalY + eyeDist * 0.45),
                              control2: CGPoint(x: leftEarX + eyeDist * 0.82, y: earLocalY + eyeDist * 0.75))
            leftPath.addCurve(to: CGPoint(x: leftEarX, y: earLocalY + eyeDist * 0.25),
                              control1: CGPoint(x: leftEarX + eyeDist * 0.25, y: earLocalY + eyeDist * 0.8),
                              control2: CGPoint(x: leftEarX + eyeDist * 0.12, y: earLocalY + eyeDist * 0.45))
            leftPath.closeSubpath()

            // Fill left ear background
            context.saveGState()
            context.setFillColor(earColor.cgColor)
            context.addPath(leftPath)
            context.fillPath()
            context.restoreGState()

            // Clip for left inner ear / spots
            let leftInner = CGMutablePath()
            leftInner.move(to: CGPoint(x: leftEarX + eyeDist * 0.12, y: earLocalY + eyeDist * 0.22))
            leftInner.addCurve(to: CGPoint(x: leftEarX + eyeDist * 0.4, y: earLocalY + eyeDist * 0.7),
                               control1: CGPoint(x: leftEarX + eyeDist * 0.35, y: earLocalY + eyeDist * 0.28),
                               control2: CGPoint(x: leftEarX + eyeDist * 0.48, y: earLocalY + eyeDist * 0.52))
            leftInner.addCurve(to: CGPoint(x: leftEarX + eyeDist * 0.06, y: earLocalY + eyeDist * 0.28),
                               control1: CGPoint(x: leftEarX + eyeDist * 0.28, y: earLocalY + eyeDist * 0.7),
                               control2: CGPoint(x: leftEarX + eyeDist * 0.15, y: earLocalY + eyeDist * 0.52))
            leftInner.closeSubpath()

            context.saveGState()
            context.addPath(leftPath)
            context.clip()
            
            context.setFillColor(innerEarColor.cgColor)
            context.addPath(leftInner)
            context.fillPath()

            if isDalmatian {
                context.setFillColor(UIColor.black.cgColor)
                context.fillEllipse(in: CGRect(x: leftEarX + eyeDist * 0.12, y: earLocalY + eyeDist * 0.05, width: eyeDist * 0.2, height: eyeDist * 0.2))
                context.fillEllipse(in: CGRect(x: leftEarX + eyeDist * 0.33, y: earLocalY + eyeDist * 0.2, width: eyeDist * 0.24, height: eyeDist * 0.24))
                context.fillEllipse(in: CGRect(x: leftEarX + eyeDist * 0.47, y: earLocalY + eyeDist * 0.38, width: eyeDist * 0.22, height: eyeDist * 0.22))
            }
            context.restoreGState()

            // Left ear border
            context.setStrokeColor(borderColor.cgColor)
            context.setLineWidth(eyeDist * 0.015)
            context.addPath(leftPath)
            context.strokePath()

            // 2. Right Ear
            let rightPath = CGMutablePath()
            rightPath.move(to: CGPoint(x: rightEarX, y: earLocalY + eyeDist * 0.1))
            rightPath.addCurve(to: CGPoint(x: rightEarX - eyeDist * 0.7, y: earLocalY + eyeDist * 0.15),
                               control1: CGPoint(x: rightEarX - eyeDist * 0.25, y: earLocalY - eyeDist * 0.18),
                               control2: CGPoint(x: rightEarX - eyeDist * 0.55, y: earLocalY - eyeDist * 0.08))
            rightPath.addCurve(to: CGPoint(x: rightEarX - eyeDist * 0.5, y: earLocalY + eyeDist * 0.88),
                               control1: CGPoint(x: rightEarX - eyeDist * 0.88, y: earLocalY + eyeDist * 0.45),
                               control2: CGPoint(x: rightEarX - eyeDist * 0.82, y: earLocalY + eyeDist * 0.75))
            rightPath.addCurve(to: CGPoint(x: rightEarX, y: earLocalY + eyeDist * 0.25),
                               control1: CGPoint(x: rightEarX - eyeDist * 0.25, y: earLocalY + eyeDist * 0.8),
                               control2: CGPoint(x: rightEarX - eyeDist * 0.12, y: earLocalY + eyeDist * 0.45))
            rightPath.closeSubpath()

            // Fill right ear background
            context.saveGState()
            context.setFillColor(earColor.cgColor)
            context.addPath(rightPath)
            context.fillPath()
            context.restoreGState()

            // Clip for right inner ear / spots
            let rightInner = CGMutablePath()
            rightInner.move(to: CGPoint(x: rightEarX - eyeDist * 0.12, y: earLocalY + eyeDist * 0.22))
            rightInner.addCurve(to: CGPoint(x: rightEarX - eyeDist * 0.4, y: earLocalY + eyeDist * 0.7),
                                control1: CGPoint(x: rightEarX - eyeDist * 0.35, y: earLocalY + eyeDist * 0.28),
                                control2: CGPoint(x: rightEarX - eyeDist * 0.48, y: earLocalY + eyeDist * 0.52))
            rightInner.addCurve(to: CGPoint(x: rightEarX - eyeDist * 0.06, y: earLocalY + eyeDist * 0.28),
                                control1: CGPoint(x: rightEarX - eyeDist * 0.28, y: earLocalY + eyeDist * 0.7),
                                control2: CGPoint(x: rightEarX - eyeDist * 0.15, y: earLocalY + eyeDist * 0.52))
            rightInner.closeSubpath()

            context.saveGState()
            context.addPath(rightPath)
            context.clip()
            
            context.setFillColor(innerEarColor.cgColor)
            context.addPath(rightInner)
            context.fillPath()

            if isDalmatian {
                context.setFillColor(UIColor.black.cgColor)
                context.fillEllipse(in: CGRect(x: rightEarX - eyeDist * 0.32, y: earLocalY + eyeDist * 0.05, width: eyeDist * 0.2, height: eyeDist * 0.2))
                context.fillEllipse(in: CGRect(x: rightEarX - eyeDist * 0.57, y: earLocalY + eyeDist * 0.2, width: eyeDist * 0.24, height: eyeDist * 0.24))
                context.fillEllipse(in: CGRect(x: rightEarX - eyeDist * 0.69, y: earLocalY + eyeDist * 0.38, width: eyeDist * 0.22, height: eyeDist * 0.22))
            }
            context.restoreGState()

            // Right ear border
            context.setStrokeColor(borderColor.cgColor)
            context.setLineWidth(eyeDist * 0.015)
            context.addPath(rightPath)
            context.strokePath()

            // 3. Muzzle (Cheeks/Jowls)
            context.saveGState()
            let muzzlePath = CGMutablePath()
            let muzzleL = CGRect(x: -eyeDist * 0.35, y: noseLocalY - eyeDist * 0.14, width: eyeDist * 0.4, height: eyeDist * 0.4)
            let muzzleR = CGRect(x: -eyeDist * 0.05, y: noseLocalY - eyeDist * 0.14, width: eyeDist * 0.4, height: eyeDist * 0.4)
            muzzlePath.addEllipse(in: muzzleL)
            muzzlePath.addEllipse(in: muzzleR)
            
            context.setFillColor(isDalmatian ? UIColor.white.cgColor : UIColor(red: 245/255, green: 245/255, blue: 240/255, alpha: 1).cgColor)
            context.addPath(muzzlePath)
            context.fillPath()
            
            context.setStrokeColor(UIColor(red: 224/255, green: 224/255, blue: 224/255, alpha: 1).cgColor)
            context.setLineWidth(eyeDist * 0.01)
            context.addPath(muzzlePath)
            context.strokePath()

            if isDalmatian {
                context.saveGState()
                context.addPath(muzzlePath)
                context.clip()
                context.setFillColor(UIColor.black.cgColor)
                context.fillEllipse(in: CGRect(x: -eyeDist * 0.26, y: noseLocalY, width: eyeDist * 0.08, height: eyeDist * 0.08))
                context.fillEllipse(in: CGRect(x: eyeDist * 0.18, y: noseLocalY + eyeDist * 0.04, width: eyeDist * 0.06, height: eyeDist * 0.06))
                context.restoreGState()
            }
            context.restoreGState()

            // Whisker dots
            context.setFillColor(UIColor(red: 85/255, green: 85/255, blue: 85/255, alpha: 1).cgColor)
            let dotR = eyeDist * 0.012
            context.fillEllipse(in: CGRect(x: -eyeDist * 0.112, y: noseLocalY + eyeDist * 0.038, width: dotR*2, height: dotR*2))
            context.fillEllipse(in: CGRect(x: -eyeDist * 0.172, y: noseLocalY + eyeDist * 0.058, width: dotR*2, height: dotR*2))
            context.fillEllipse(in: CGRect(x: eyeDist * 0.088, y: noseLocalY + eyeDist * 0.038, width: dotR*2, height: dotR*2))
            context.fillEllipse(in: CGRect(x: eyeDist * 0.148, y: noseLocalY + eyeDist * 0.058, width: dotR*2, height: dotR*2))

            // 4. Dog Nose
            let nosePath = CGMutablePath()
            let ncx: CGFloat = 0
            let ncy = noseLocalY - eyeDist * 0.04
            let nw = eyeDist * 0.14
            let nh = eyeDist * 0.09
            nosePath.move(to: CGPoint(x: ncx - nw, y: ncy))
            nosePath.addCurve(to: CGPoint(x: ncx + nw, y: ncy),
                              control1: CGPoint(x: ncx - nw, y: ncy - nh),
                              control2: CGPoint(x: ncx + nw, y: ncy - nh))
            nosePath.addCurve(to: CGPoint(x: ncx, y: ncy + nh * 1.2),
                              control1: CGPoint(x: ncx + nw, y: ncy + nh * 0.8),
                              control2: CGPoint(x: ncx, y: ncy + nh * 1.2))
            nosePath.addCurve(to: CGPoint(x: ncx - nw, y: ncy),
                              control1: CGPoint(x: ncx, y: ncy + nh * 1.2),
                              control2: CGPoint(x: ncx - nw, y: ncy + nh * 0.8))
            nosePath.closeSubpath()
            context.setFillColor(UIColor.black.cgColor)
            context.addPath(nosePath)
            context.fillPath()

            context.setFillColor(UIColor.white.withAlphaComponent(0.8).cgColor)
            context.fillEllipse(in: CGRect(x: -eyeDist * 0.075, y: noseLocalY - eyeDist * 0.105, width: eyeDist * 0.05, height: eyeDist * 0.05))
        }
    }

    private func drawCatEars(context: CGContext, face: DetectedFace, isPink: Bool) {
        guard let le = face.leftEye, let re = face.rightEye else { return }
        let rollAngle = face.rollAngle
        let eyeDist = eyeDistance(face)
        let faceCx = (le.x + re.x) / 2.0
        let faceCy = (le.y + re.y) / 2.0
        let faceW = face.boundingBox.width
        let faceH = face.boundingBox.height
        
        let earWidth = eyeDist * 0.65
        let earHeight = eyeDist * 0.72
        let leftEarX = -eyeDist * 0.60
        let rightEarX = eyeDist * 0.60
        let earLocalY = -eyeDist * 1.45
        
        let nose = face.noseBase ?? CGPoint(x: faceCx, y: faceCy + eyeDist * 0.35)

        withFaceCoordSystem(context: context, anchor: CGPoint(x: faceCx, y: faceCy), rollAngle: rollAngle) {
            // 1. Draw ears
            func drawSingleEar(ex: CGFloat, isLeft: Bool) {
                let tilt: CGFloat = isLeft ? -8.0 : 8.0
                context.saveGState()
                context.translateBy(x: ex, y: earLocalY)
                context.rotate(by: tilt * .pi / 180.0)

                // Outer
                let outer = CGMutablePath()
                outer.move(to: CGPoint(x: -earWidth * 0.5, y: earHeight * 0.35))
                outer.addCurve(to: CGPoint(x: 0, y: -earHeight * 0.75),
                               control1: CGPoint(x: -earWidth * 0.45, y: -earHeight * 0.45),
                               control2: CGPoint(x: -earWidth * 0.05, y: -earHeight * 0.75))
                outer.addCurve(to: CGPoint(x: earWidth * 0.5, y: earHeight * 0.35),
                               control1: CGPoint(x: earWidth * 0.05, y: -earHeight * 0.75),
                               control2: CGPoint(x: earWidth * 0.45, y: -earHeight * 0.45))
                outer.closeSubpath()

                context.setFillColor(isPink ? self.colorFromHex("#ffa6c9").cgColor : self.colorFromHex("#5e5e5e").cgColor)
                context.addPath(outer)
                context.fillPath()

                // Inner pink
                let inner = CGMutablePath()
                inner.move(to: CGPoint(x: -earWidth * 0.32, y: earHeight * 0.28))
                inner.addCurve(to: CGPoint(x: 0, y: -earHeight * 0.52),
                               control1: CGPoint(x: -earWidth * 0.28, y: -earHeight * 0.32),
                               control2: CGPoint(x: -earWidth * 0.03, y: -earHeight * 0.52))
                inner.addCurve(to: CGPoint(x: earWidth * 0.32, y: earHeight * 0.28),
                               control1: CGPoint(x: earWidth * 0.03, y: -earHeight * 0.52),
                               control2: CGPoint(x: earWidth * 0.28, y: -earHeight * 0.32))
                inner.closeSubpath()

                context.setFillColor(isPink ? self.colorFromHex("#ff5c8a").cgColor : self.colorFromHex("#f096a8").cgColor)
                context.addPath(inner)
                context.fillPath()

                // Gemstones / Sparkles
                let sparkleColors = [
                    self.colorFromHex("#ffc6ff"), // Lavender
                    self.colorFromHex("#ffadad"), // Pastel red
                    self.colorFromHex("#fdffb6"), // Yellow
                    UIColor.white,
                    self.colorFromHex("#ff70a6")  // Pink
                ]
                
                // Deterministic coordinates based on seed for stable rendering
                for i in 0..<18 {
                    let rx = CGFloat(sin(Double(i)*45.0) * Double(earWidth) * 0.18)
                    let ry = CGFloat(cos(Double(i)*63.0) * Double(earHeight) * 0.18 - Double(earHeight)*0.1)
                    let rSize = eyeDist * CGFloat(0.015 + Double(i % 3) * 0.01)
                    
                    context.setFillColor(sparkleColors[i % sparkleColors.count].cgColor)
                    context.fillEllipse(in: CGRect(x: rx - rSize, y: ry - rSize, width: rSize*2, height: rSize*2))
                }

                context.restoreGState()
            }

            drawSingleEar(ex: leftEarX, isLeft: true)
            drawSingleEar(ex: rightEarX, isLeft: false)

            // 2. Draw Cat Nose
            let noseLocalY = nose.y - faceCy
            let nw = eyeDist * 0.12
            let nh = eyeDist * 0.07

            let nosePath = CGMutablePath()
            nosePath.move(to: CGPoint(x: 0, y: noseLocalY - nh * 0.2))
            nosePath.addCurve(to: CGPoint(x: -nw * 0.2, y: noseLocalY + nh * 0.4),
                              control1: CGPoint(x: -nw * 0.5, y: noseLocalY - nh * 0.7),
                              control2: CGPoint(x: -nw, y: noseLocalY - nh * 0.1))
            nosePath.addLine(to: CGPoint(x: 0, y: noseLocalY + nh * 0.7))
            nosePath.addLine(to: CGPoint(x: nw * 0.2, y: noseLocalY + nh * 0.4))
            nosePath.addCurve(to: CGPoint(x: 0, y: noseLocalY - nh * 0.2),
                              control1: CGPoint(x: nw, y: noseLocalY - nh * 0.1),
                              control2: CGPoint(x: nw * 0.5, y: noseLocalY - nh * 0.7))
            nosePath.closeSubpath()

            context.setFillColor(self.colorFromHex("#ff85a2").cgColor)
            context.addPath(nosePath)
            context.fillPath()

            // Nose Highlight shine
            context.setFillColor(UIColor.white.withAlphaComponent(220.0/255.0).cgColor)
            context.fillEllipse(in: CGRect(x: -nw * 0.22 - nw * 0.15, y: noseLocalY - nh * 0.15 - nw * 0.15, width: nw * 0.3, height: nw * 0.3))

            // 3. Draw Cat Whiskers (3 on each cheek)
            context.saveGState()
            context.setStrokeColor(UIColor.white.withAlphaComponent(200.0/255.0).cgColor)
            context.setLineWidth(eyeDist * 0.015)
            context.setLineCap(.round)

            let leftStart = -eyeDist * 0.16
            context.move(to: CGPoint(x: leftStart, y: noseLocalY + eyeDist * 0.03))
            context.addLine(to: CGPoint(x: -eyeDist * 0.65, y: noseLocalY - eyeDist * 0.05))
            context.strokePath()

            context.move(to: CGPoint(x: leftStart, y: noseLocalY + eyeDist * 0.06))
            context.addLine(to: CGPoint(x: -eyeDist * 0.68, y: noseLocalY + eyeDist * 0.06))
            context.strokePath()

            context.move(to: CGPoint(x: leftStart, y: noseLocalY + eyeDist * 0.09))
            context.addLine(to: CGPoint(x: -eyeDist * 0.65, y: noseLocalY + eyeDist * 0.17))
            context.strokePath()

            let rightStart = eyeDist * 0.16
            context.move(to: CGPoint(x: rightStart, y: noseLocalY + eyeDist * 0.03))
            context.addLine(to: CGPoint(x: eyeDist * 0.65, y: noseLocalY - eyeDist * 0.05))
            context.strokePath()

            context.move(to: CGPoint(x: rightStart, y: noseLocalY + eyeDist * 0.06))
            context.addLine(to: CGPoint(x: eyeDist * 0.68, y: noseLocalY + eyeDist * 0.06))
            context.strokePath()

            context.move(to: CGPoint(x: rightStart, y: noseLocalY + eyeDist * 0.09))
            context.addLine(to: CGPoint(x: eyeDist * 0.65, y: noseLocalY + eyeDist * 0.17))
            context.strokePath()

            context.restoreGState()

            // 4. Draw Floating Pink Hearts
            let time = CGFloat(CACurrentMediaTime() * 1000.0)
            let heartLocations: [(CGFloat, CGFloat, CGFloat)] = [
                (-0.68, -0.42, 0.09),
                (-0.35, -0.65, 0.07),
                ( 0.35, -0.65, 0.07),
                ( 0.68, -0.42, 0.09),
                (-0.85,  0.05, 0.08),
                ( 0.85,  0.05, 0.08),
                (-0.55,  0.42, 0.06),
                ( 0.55,  0.42, 0.06)
            ]

            for (index, (rx, ry, sizeMult)) in heartLocations.enumerated() {
                let bobY = sin(time * 0.0028 + CGFloat(index) * 1.2) * faceH * 0.03
                let bobScale = 1.0 + sin(time * 0.0035 + CGFloat(index)) * 0.12
                let hCx = rx * faceW
                let hCy = ry * faceH + bobY
                let w = faceW * sizeMult * bobScale
                let h = w * 1.05

                context.saveGState()
                context.translateBy(x: hCx, y: hCy)
                context.rotate(by: sin(time * 0.002 + CGFloat(index)) * 8.0 * .pi / 180.0)

                let heartPath = CGMutablePath()
                heartPath.move(to: CGPoint(x: 0, y: h * 0.35))
                heartPath.addCurve(to: CGPoint(x: -w * 0.15, y: -h * 0.45),
                                   control1: CGPoint(x: -w * 0.45, y: -h * 0.1),
                                   control2: CGPoint(x: -w * 0.40, y: -h * 0.45))
                heartPath.addCurve(to: CGPoint(x: 0, y: -h * 0.1),
                                   control1: CGPoint(x: 0, y: -h * 0.45),
                                   control2: CGPoint(x: 0, y: -h * 0.1))
                heartPath.addCurve(to: CGPoint(x: w * 0.15, y: -h * 0.45),
                                   control1: CGPoint(x: 0, y: -h * 0.1),
                                   control2: CGPoint(x: 0, y: -h * 0.45))
                heartPath.addCurve(to: CGPoint(x: 0, y: h * 0.35),
                                   control1: CGPoint(x: w * 0.40, y: -h * 0.45),
                                   control2: CGPoint(x: w * 0.45, y: -h * 0.08))
                heartPath.closeSubpath()

                context.setFillColor(self.colorFromHex("#ffa6c9").cgColor)
                context.addPath(heartPath)
                context.fillPath()

                context.setStrokeColor(UIColor.white.cgColor)
                context.setLineWidth(eyeDist * 0.012)
                context.setLineCap(.round)
                context.setLineJoin(.round)
                context.addPath(heartPath)
                context.strokePath()

                context.restoreGState()
            }
        }
    }

    private func drawFlowerCrown(context: CGContext, face: DetectedFace, isGold: Bool) {
        guard let le = face.leftEye, let re = face.rightEye else { return }
        let rollAngle = face.rollAngle
        let eyeDist = eyeDistance(face)
        
        let top = topOfHeadPoint(face: face)
        let centerX = (le.x + re.x) / 2.0
        let bandY = top != nil ? (top!.y - eyeDist * 0.95) : (min(le.y, re.y) - eyeDist * 1.05)
        let anchor = CGPoint(x: centerX, y: bandY)
        let flowerSize = eyeDist * 0.32
        
        let goldColors = ["#ffd700", "#ffc300", "#ffa000", "#ffb700", "#ffe066"]
        let flowerColors = ["#ff6f91", "#ffc75f", "#f9f871", "#ff9671", "#d65db1"]
        let colors = isGold ? goldColors : flowerColors
        let centerColor = isGold ? self.colorFromHex("#ff5722") : self.colorFromHex("#f5c542")
        
        withHeadRotation(context: context, anchor: anchor, rollAngle: rollAngle) {
            for i in -2...2 {
                let fx = centerX + CGFloat(i) * flowerSize * 1.3
                let fy = bandY + abs(CGFloat(i)) * flowerSize * 0.25
                
                let petalColor = self.colorFromHex(colors[(i + 2) % colors.count])
                context.setFillColor(petalColor.cgColor)
                
                for j in 0..<5 {
                    context.saveGState()
                    let angle = CGFloat(j) * 2.0 * .pi / 5.0
                    let px = fx + cos(angle) * flowerSize * 0.55
                    let py = fy + sin(angle) * flowerSize * 0.55
                    context.fillEllipse(in: CGRect(x: px - flowerSize * 0.4, y: py - flowerSize * 0.4, width: flowerSize * 0.8, height: flowerSize * 0.8))
                    context.restoreGState()
                }
                
                context.setFillColor(centerColor.cgColor)
                context.fillEllipse(in: CGRect(x: fx - flowerSize * 0.32, y: fy - flowerSize * 0.32, width: flowerSize * 0.64, height: flowerSize * 0.64))
            }
        }
    }

    private func drawGlasses(context: CGContext, face: DetectedFace, style: GlassStyleType) {
        guard let le = face.leftEye, let re = face.rightEye else { return }
        let rollAngle = face.rollAngle
        let eyeDist = eyeDistance(face)
        let faceCx = (le.x + re.x) / 2.0
        let faceCy = (le.y + re.y) / 2.0

        let lensW = eyeDist * 0.82
        let lensH = eyeDist * 0.62
        let cornerRadius = lensH * 0.4
        let frameW = eyeDist * 0.05

        withHeadRotation(context: context, anchor: CGPoint(x: faceCx, y: faceCy), rollAngle: rollAngle) {
            let leftRect = CGRect(x: faceCx - eyeDist * 0.46 - lensW/2, y: faceCy - lensH/2, width: lensW, height: lensH)
            let rightRect = CGRect(x: faceCx + eyeDist * 0.46 - lensW/2, y: faceCy - lensH/2, width: lensW, height: lensH)

            // 1. Draw lenses
            func drawLens(_ r: CGRect) {
                let path = UIBezierPath(roundedRect: r, cornerRadius: cornerRadius).cgPath
                context.saveGState()
                context.addPath(path)
                context.clip()

                // Gradient
                var colors: [CGColor] = []
                switch style {
                case .sun:
                    colors = [UIColor(white: 0.1, alpha: 0.98).cgColor, UIColor(white: 0.2, alpha: 0.8).cgColor]
                case .sport:
                    colors = [UIColor.cyan.withAlphaComponent(0.8).cgColor, UIColor.purple.withAlphaComponent(0.8).cgColor]
                case .heart:
                    colors = [UIColor(red: 255/255, green: 77/255, blue: 109/255, alpha: 0.6).cgColor, UIColor(red: 255/255, green: 179/255, blue: 193/255, alpha: 0.25).cgColor]
                default:
                    colors = [UIColor(white: 0.1, alpha: 0.55).cgColor, UIColor(white: 0.3, alpha: 0.31).cgColor]
                }
                
                guard let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: nil) else {
                    context.restoreGState()
                    return
                }
                context.drawLinearGradient(grad, start: CGPoint(x: r.minX, y: r.minY), end: CGPoint(x: r.minX, y: r.maxY), options: [])
                context.restoreGState()
            }

            if style == .heart {
                func drawHeartLens(_ r: CGRect) {
                    let path = CGMutablePath()
                    let w = r.width
                    let h = r.height
                    let cx = r.midX
                    let cy = r.midY
                    path.move(to: CGPoint(x: cx, y: cy + h * 0.35))
                    path.addCurve(to: CGPoint(x: cx - w * 0.15, y: cy - h * 0.45),
                                  control1: CGPoint(x: cx - w * 0.45, y: cy - h * 0.1),
                                  control2: CGPoint(x: cx - w * 0.4, y: cy - h * 0.45))
                    path.addCurve(to: CGPoint(x: cx, y: cy - h * 0.1),
                                  control1: CGPoint(x: cx, y: cy - h * 0.45),
                                  control2: CGPoint(x: cx, y: cy - h * 0.1))
                    path.addCurve(to: CGPoint(x: cx + w * 0.15, y: cy - h * 0.45),
                                  control1: CGPoint(x: cx, y: cy - h * 0.1),
                                  control2: CGPoint(x: cx, y: cy - h * 0.45))
                    path.addCurve(to: CGPoint(x: cx, y: cy + h * 0.35),
                                  control1: CGPoint(x: cx + w * 0.4, y: cy - h * 0.45),
                                  control2: CGPoint(x: cx + w * 0.45, y: cy - h * 0.1))
                    path.closeSubpath()

                    context.saveGState()
                    context.addPath(path)
                    context.clip()
                    
                    let colors = [UIColor(red: 255/255, green: 77/255, blue: 109/255, alpha: 0.6).cgColor, UIColor(red: 255/255, green: 179/255, blue: 193/255, alpha: 0.25).cgColor]
                    guard let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: nil) else {
                        context.restoreGState()
                        return
                    }
                    context.drawLinearGradient(grad, start: CGPoint(x: r.minX, y: r.minY), end: CGPoint(x: r.minX, y: r.maxY), options: [])
                    context.restoreGState()
                }
                drawHeartLens(leftRect)
                drawHeartLens(rightRect)
            } else {
                drawLens(leftRect)
                drawLens(rightRect)
            }

            // 2. Draw bridge & arms
            let frameColor: UIColor
            switch style {
            case .sport: frameColor = UIColor.green
            case .heart: frameColor = UIColor.red
            case .retro: frameColor = UIColor.white
            default: frameColor = UIColor(red: 44/255, green: 44/255, blue: 46/255, alpha: 1)
            }

            context.setStrokeColor(frameColor.cgColor)
            context.setLineWidth(frameW)
            context.setLineCap(.round)

            // Bridge
            let bridge = CGMutablePath()
            bridge.move(to: CGPoint(x: leftRect.maxX, y: faceCy - lensH * 0.05))
            bridge.addQuadCurve(to: CGPoint(x: rightRect.minX, y: faceCy - lensH * 0.05), control: CGPoint(x: faceCx, y: faceCy - lensH * 0.12))
            context.addPath(bridge)
            context.strokePath()

            // Temple arms
            context.move(to: CGPoint(x: leftRect.minX, y: faceCy))
            context.addLine(to: CGPoint(x: faceCx - eyeDist * 1.25, y: faceCy - eyeDist * 0.38))
            context.strokePath()

            context.move(to: CGPoint(x: rightRect.maxX, y: faceCy))
            context.addLine(to: CGPoint(x: faceCx + eyeDist * 1.25, y: faceCy - eyeDist * 0.38))
            context.strokePath()

            // Lenses outer borders
            if style == .heart {
                func drawHeartBorder(_ r: CGRect) {
                    let path = CGMutablePath()
                    let w = r.width
                    let h = r.height
                    let cx = r.midX
                    let cy = r.midY
                    path.move(to: CGPoint(x: cx, y: cy + h * 0.35))
                    path.addCurve(to: CGPoint(x: cx - w * 0.15, y: cy - h * 0.45),
                                  control1: CGPoint(x: cx - w * 0.45, y: cy - h * 0.1),
                                  control2: CGPoint(x: cx - w * 0.4, y: cy - h * 0.45))
                    path.addCurve(to: CGPoint(x: cx, y: cy - h * 0.1),
                                  control1: CGPoint(x: cx, y: cy - h * 0.45),
                                  control2: CGPoint(x: cx, y: cy - h * 0.1))
                    path.addCurve(to: CGPoint(x: cx + w * 0.15, y: cy - h * 0.45),
                                  control1: CGPoint(x: cx, y: cy - h * 0.1),
                                  control2: CGPoint(x: cx + w * 0.45, y: cy - h * 0.45))
                    path.addCurve(to: CGPoint(x: cx, y: cy + h * 0.35),
                                  control1: CGPoint(x: cx + w * 0.4, y: cy - h * 0.45),
                                  control2: CGPoint(x: cx + w * 0.45, y: cy - h * 0.1))
                    path.closeSubpath()
                    context.addPath(path)
                    context.strokePath()
                }
                drawHeartBorder(leftRect)
                drawHeartBorder(rightRect)
            } else {
                let lp = UIBezierPath(roundedRect: leftRect, cornerRadius: cornerRadius).cgPath
                let rp = UIBezierPath(roundedRect: rightRect, cornerRadius: cornerRadius).cgPath
                context.addPath(lp)
                context.addPath(rp)
                context.strokePath()
            }
        }
    }

    private func drawHat(context: CGContext, face: DetectedFace, style: HatStyleType) {
        guard let le = face.leftEye, let re = face.rightEye else { return }
        let rollAngle = face.rollAngle
        let eyeDist = eyeDistance(face)
        let faceCx = (le.x + re.x) / 2.0
        let faceCy = (le.y + re.y) / 2.0

        let yawRad = face.yawAngle * .pi / 180.0
        let pitchRad = face.pitchAngle * .pi / 180.0

        let baseOffsetX = -yawRad * eyeDist * 0.15
        let baseOffsetY = pitchRad * eyeDist * 0.15

        let localBrimY = faceCy - eyeDist * (style == .wizard ? 0.95 : (style == .cowboy ? 0.82 : 0.80))
        let brimX = faceCx + baseOffsetX
        let brimY = localBrimY + baseOffsetY

        if style == .santa {
            withHeadRotation(context: context, anchor: CGPoint(x: faceCx, y: faceCy), rollAngle: rollAngle) {
                self.drawSantaBeard(context: context, face: face, cx: faceCx, cy: faceCy, eyeDist: eyeDist)
            }
        }

        withHeadRotation(context: context, anchor: CGPoint(x: faceCx, y: faceCy), rollAngle: rollAngle) {
            switch style {
            case .wizard:
                let hatWidth = eyeDist * 2.2
                let hatHeight = eyeDist * 2.2
                let brimW = hatWidth * 1.15
                let brimH = eyeDist * 0.38

                // Cone
                let cone = CGMutablePath()
                cone.move(to: CGPoint(x: brimX - hatWidth * 0.35, y: brimY + brimH * 0.1))
                cone.addCurve(to: CGPoint(x: brimX - hatWidth * 0.12, y: brimY - hatHeight),
                              control1: CGPoint(x: brimX - hatWidth * 0.3, y: brimY - hatHeight * 0.6),
                              control2: CGPoint(x: brimX - hatWidth * 0.2, y: brimY - hatHeight * 0.95))
                cone.addCurve(to: CGPoint(x: brimX + hatWidth * 0.35, y: brimY + brimH * 0.1),
                              control1: CGPoint(x: brimX + hatWidth * 0.05, y: brimY - hatHeight * 0.85),
                              control2: CGPoint(x: brimX + hatWidth * 0.25, y: brimY - hatHeight * 0.5))
                cone.addQuadCurve(to: CGPoint(x: brimX - hatWidth * 0.35, y: brimY + brimH * 0.1), control: CGPoint(x: brimX, y: brimY + brimH * 0.25))
                cone.closeSubpath()

                context.setFillColor(UIColor(red: 74/255, green: 12/255, blue: 163/255, alpha: 1).cgColor)
                context.addPath(cone)
                context.fillPath()

                // Stars
                context.setFillColor(UIColor(red: 245/255, green: 197/255, blue: 66/255, alpha: 1).cgColor)
                func drawConeStar(t: CGFloat, dx: CGFloat, dy: CGFloat, r: CGFloat) {
                    let sx = brimX + dx
                    let sy = brimY - hatHeight * t + dy
                    let star = CGMutablePath()
                    for i in 0..<10 {
                        let radius = (i % 2 == 0) ? r : r * 0.4
                        let angle = CGFloat(i) * .pi / 5.0 - .pi / 2.0
                        let px = sx + cos(angle) * radius
                        let py = sy + sin(angle) * radius
                        if i == 0 { star.move(to: CGPoint(x: px, y: py)) }
                        else { star.addLine(to: CGPoint(x: px, y: py)) }
                    }
                    star.closeSubpath()
                    context.addPath(star)
                    context.fillPath()
                }
                drawConeStar(t: 0.65, dx: -hatWidth*0.1, dy: 0, r: eyeDist*0.11)
                drawConeStar(t: 0.40, dx: hatWidth*0.12, dy: 0, r: eyeDist*0.13)

                // Brim oval
                context.setFillColor(UIColor(red: 49/255, green: 16/255, blue: 106/255, alpha: 1).cgColor)
                context.fillEllipse(in: CGRect(x: brimX - brimW/2, y: brimY - brimH*0.4, width: brimW, height: brimH))

            case .cowboy:
                let crownW = eyeDist * 1.8
                let crownH = eyeDist * 1.4
                let crownTopY = brimY - crownH

                let crown = CGMutablePath()
                crown.move(to: CGPoint(x: brimX - crownW * 0.44, y: brimY + crownH * 0.08))
                crown.addCurve(to: CGPoint(x: brimX - crownW * 0.22, y: crownTopY),
                               control1: CGPoint(x: brimX - crownW * 0.48, y: brimY - crownH * 0.5),
                               control2: CGPoint(x: brimX - crownW * 0.35, y: crownTopY - crownH * 0.05))
                crown.addQuadCurve(to: CGPoint(x: brimX + crownW * 0.22, y: crownTopY), control: CGPoint(x: brimX, y: crownTopY + crownH * 0.12))
                crown.addCurve(to: CGPoint(x: brimX + crownW * 0.44, y: brimY + crownH * 0.08),
                               control1: CGPoint(x: brimX + crownW * 0.35, y: crownTopY - crownH * 0.05),
                               control2: CGPoint(x: brimX + crownW * 0.48, y: brimY - crownH * 0.5))
                crown.addQuadCurve(to: CGPoint(x: brimX - crownW * 0.44, y: brimY + crownH * 0.08), control: CGPoint(x: brimX, y: brimY + crownH * 0.16))
                crown.closeSubpath()

                context.setFillColor(UIColor(red: 160/255, green: 82/255, blue: 45/255, alpha: 1).cgColor)
                context.addPath(crown)
                context.fillPath()

                // Hatband
                let band = CGMutablePath()
                band.move(to: CGPoint(x: brimX - crownW * 0.43, y: brimY + crownH * 0.07))
                band.addQuadCurve(to: CGPoint(x: brimX + crownW * 0.43, y: brimY + crownH * 0.07), control: CGPoint(x: brimX, y: brimY + crownH * 0.14))
                band.addLine(to: CGPoint(x: brimX + crownW * 0.43, y: brimY + crownH * 0.15))
                band.addQuadCurve(to: CGPoint(x: brimX - crownW * 0.43, y: brimY + crownH * 0.15), control: CGPoint(x: brimX, y: brimY + crownH * 0.22))
                band.closeSubpath()
                context.setFillColor(UIColor(red: 42/255, green: 21/255, blue: 8/255, alpha: 1).cgColor)
                context.addPath(band)
                context.fillPath()

                // Brim
                let brimW = eyeDist * 2.8
                let brimH = eyeDist * 0.42
                let brim = CGMutablePath()
                brim.move(to: CGPoint(x: brimX - brimW/2, y: brimY - brimH*0.4))
                brim.addQuadCurve(to: CGPoint(x: brimX + brimW/2, y: brimY - brimH*0.4), control: CGPoint(x: brimX, y: brimY + brimH*0.35))
                brim.addQuadCurve(to: CGPoint(x: brimX + brimW/2, y: brimY), control: CGPoint(x: brimX + brimW/2 + eyeDist * 0.08, y: brimY - brimH * 0.1))
                brim.addQuadCurve(to: CGPoint(x: brimX - brimW/2, y: brimY), control: CGPoint(x: brimX, y: brimY + brimH*0.75))
                brim.addQuadCurve(to: CGPoint(x: brimX - brimW/2, y: brimY - brimH*0.4), control: CGPoint(x: brimX - brimW/2 - eyeDist*0.08, y: brimY - brimH*0.1))
                brim.closeSubpath()

                context.setFillColor(UIColor(red: 112/255, green: 54/255, blue: 18/255, alpha: 1).cgColor)
                context.addPath(brim)
                context.fillPath()

            case .santa:
                let trimW = eyeDist * 2.2
                let trimH = eyeDist * 0.38
                let redH = eyeDist * 1.8
                let pomX = brimX + trimW * 0.32
                let pomY = brimY - redH * 0.14

                // Santa Red Cone
                let red = CGMutablePath()
                red.move(to: CGPoint(x: brimX - trimW * 0.42, y: brimY - trimH * 0.3))
                red.addCurve(to: CGPoint(x: pomX - eyeDist * 0.16, y: pomY - eyeDist * 0.08),
                             control1: CGPoint(x: brimX - trimW * 0.35, y: brimY - redH * 0.7),
                             control2: CGPoint(x: brimX - trimW * 0.05, y: brimY - redH * 0.98))
                red.addLine(to: CGPoint(x: pomX, y: pomY))
                red.addCurve(to: CGPoint(x: brimX, y: brimY - redH * 0.45),
                             control1: CGPoint(x: brimX + trimW * 0.2, y: brimY - redH * 0.45),
                             control2: CGPoint(x: brimX + trimW * 0.1, y: brimY - redH * 0.65))
                red.addQuadCurve(to: CGPoint(x: brimX - trimW * 0.42, y: brimY - trimH * 0.3), control: CGPoint(x: brimX, y: brimY - trimH * 0.1))
                red.closeSubpath()

                context.setFillColor(UIColor(red: 217/255, green: 4/255, blue: 41/255, alpha: 1).cgColor)
                context.addPath(red)
                context.fillPath()

                // Fur Trim
                let trim = CGMutablePath()
                trim.move(to: CGPoint(x: brimX - trimW/2, y: brimY - trimH*0.4))
                trim.addQuadCurve(to: CGPoint(x: brimX + trimW/2, y: brimY - trimH*0.4), control: CGPoint(x: brimX, y: brimY - trimH * 0.1))
                trim.addLine(to: CGPoint(x: brimX + trimW/2, y: brimY + trimH*0.2))
                trim.addQuadCurve(to: CGPoint(x: brimX - trimW/2, y: brimY + trimH*0.2), control: CGPoint(x: brimX, y: brimY + trimH * 0.5))
                trim.closeSubpath()

                context.setFillColor(UIColor.white.cgColor)
                context.addPath(trim)
                context.fillPath()

                // Pom Pom
                context.fillEllipse(in: CGRect(x: pomX - eyeDist*0.2, y: pomY - eyeDist*0.2, width: eyeDist*0.4, height: eyeDist*0.4))
            }
        }
    }

    private func drawSantaBeard(context: CGContext, face: DetectedFace, cx: CGFloat, cy: CGFloat, eyeDist: CGFloat) {
        guard let upper = face.upperLip else { return }
        let beardCenter = upper.first ?? CGPoint(x: cx, y: cy + eyeDist * 0.8)
        
        let path = CGMutablePath()
        let w = eyeDist * 1.8
        let h = eyeDist * 2.2
        
        path.move(to: CGPoint(x: beardCenter.x - w/2, y: beardCenter.y))
        path.addCurve(to: CGPoint(x: beardCenter.x, y: beardCenter.y + h),
                      control1: CGPoint(x: beardCenter.x - w * 0.45, y: beardCenter.y + h * 0.4),
                      control2: CGPoint(x: beardCenter.x - w * 0.25, y: beardCenter.y + h * 0.95))
        path.addCurve(to: CGPoint(x: beardCenter.x + w/2, y: beardCenter.y),
                      control1: CGPoint(x: beardCenter.x + w * 0.25, y: beardCenter.y + h * 0.95),
                      control2: CGPoint(x: beardCenter.x + w * 0.45, y: beardCenter.y + h * 0.4))
        path.addQuadCurve(to: CGPoint(x: beardCenter.x - w/2, y: beardCenter.y), control: CGPoint(x: beardCenter.x, y: beardCenter.y + h * 0.2))
        path.closeSubpath()

        context.setFillColor(UIColor(white: 0.98, alpha: 0.95).cgColor)
        context.addPath(path)
        context.fillPath()

        // Mustache
        let mustache = CGMutablePath()
        let mw = eyeDist * 0.8
        let mh = eyeDist * 0.26
        mustache.move(to: CGPoint(x: beardCenter.x - mw, y: beardCenter.y - eyeDist * 0.05))
        mustache.addQuadCurve(to: CGPoint(x: beardCenter.x, y: beardCenter.y - eyeDist * 0.02), control: CGPoint(x: beardCenter.x - mw * 0.4, y: beardCenter.y - mh * 0.8))
        mustache.addQuadCurve(to: CGPoint(x: beardCenter.x + mw, y: beardCenter.y - eyeDist * 0.05), control: CGPoint(x: beardCenter.x + mw * 0.4, y: beardCenter.y - mh * 0.8))
        mustache.addQuadCurve(to: CGPoint(x: beardCenter.x, y: beardCenter.y + eyeDist * 0.12), control: CGPoint(x: beardCenter.x + mw * 0.5, y: beardCenter.y + mh * 0.7))
        mustache.addQuadCurve(to: CGPoint(x: beardCenter.x - mw, y: beardCenter.y - eyeDist * 0.05), control: CGPoint(x: beardCenter.x - mw * 0.5, y: beardCenter.y + eyeDist * 0.12))
        mustache.closeSubpath()
        context.addPath(mustache)
        context.fillPath()
    }

    private func drawButterflies(context: CGContext, face: DetectedFace) {
        let box = face.boundingBox
        let faceW = box.width
        let faceH = box.height
        let cx = box.midX
        let foreheadY = box.minY - faceH * 0.35
        let anchor = CGPoint(x: cx, y: foreheadY)
        let rollAngle = face.rollAngle
        let time = CACurrentMediaTime()
        let floatPhase = CGFloat(time / 1.4)

        // Relative offsets
        let butterflies = [
            (CGFloat(-0.45), CGFloat(-0.25), CGFloat(1.0)),
            (CGFloat(-0.25), CGFloat(-0.32), CGFloat(0.9)),
            (CGFloat( 0.00), CGFloat(-0.36), CGFloat(1.1)),
            (CGFloat( 0.25), CGFloat(-0.32), CGFloat(0.9)),
            (CGFloat( 0.45), CGFloat(-0.25), CGFloat(1.0)),
            (CGFloat(-0.55), CGFloat(-0.05), CGFloat(0.8)),
            (CGFloat(-0.35), CGFloat(-0.10), CGFloat(1.0)),
            (CGFloat(-0.12), CGFloat(-0.15), CGFloat(0.9)),
            (CGFloat( 0.12), CGFloat(-0.15), CGFloat(0.9)),
            (CGFloat( 0.35), CGFloat(-0.10), CGFloat(1.0)),
            (CGFloat( 0.55), CGFloat(-0.05), CGFloat(0.8)),
            (CGFloat(-0.40), CGFloat( 0.10), CGFloat(0.7)),
            (CGFloat(-0.20), CGFloat( 0.05), CGFloat(0.8)),
            (CGFloat( 0.00), CGFloat( 0.02), CGFloat(1.0)),
            (CGFloat( 0.20), CGFloat( 0.05), CGFloat(0.8)),
            (CGFloat( 0.40), CGFloat( 0.10), CGFloat(0.7))
        ]

        withHeadRotation(context: context, anchor: anchor, rollAngle: rollAngle) {
            for (index, (rx, ry, baseScale)) in butterflies.enumerated() {
                let risePhase = (floatPhase + CGFloat(index) * 0.065).truncatingRemainder(dividingBy: 1.0)
                let rise = risePhase * faceH * 0.16
                let floatX = cos(floatPhase * 0.5 + CGFloat(index) * 0.7) * faceW * 0.025
                let bobY = sin(CGFloat(index) * 0.8 + floatPhase * 0.6) * faceH * 0.035
                
                let bCx = cx + rx * faceW + floatX
                let bCy = foreheadY + ry * faceH + bobY - rise
                let bSize = faceW * 0.08 * baseScale
                
                // Wings flutter
                let flutterScale = 0.25 + 0.75 * abs(sin(time * 18.0 + Double(index) * 1.3))
                let alpha = max(0, min(1.0, 1.0 - Double(risePhase)))

                context.saveGState()
                context.translateBy(x: bCx, y: bCy)
                context.rotate(by: CGFloat(sin(time * 5.0 + Double(index)) * 15.0 * .pi / 180.0))

                // Draw path
                let path = CGMutablePath()
                path.move(to: .zero)
                // Left top
                path.addCurve(to: CGPoint(x: -bSize * 0.1 * CGFloat(flutterScale), y: bSize * 0.1),
                              control1: CGPoint(x: -bSize * 0.9 * CGFloat(flutterScale), y: -bSize * 0.7),
                              control2: CGPoint(x: -bSize * 1.1 * CGFloat(flutterScale), y: -bSize * 0.1))
                // Left bottom
                path.addCurve(to: .zero,
                              control1: CGPoint(x: -bSize * 0.8 * CGFloat(flutterScale), y: bSize * 0.4),
                              control2: CGPoint(x: -bSize * 0.4 * CGFloat(flutterScale), y: bSize * 0.5))
                // Right top
                path.addCurve(to: CGPoint(x: bSize * 0.1 * CGFloat(flutterScale), y: bSize * 0.1),
                              control1: CGPoint(x: bSize * 0.9 * CGFloat(flutterScale), y: -bSize * 0.7),
                              control2: CGPoint(x: bSize * 1.1 * CGFloat(flutterScale), y: -bSize * 0.1))
                // Right bottom
                path.addCurve(to: .zero,
                              control1: CGPoint(x: bSize * 0.8 * CGFloat(flutterScale), y: bSize * 0.4),
                              control2: CGPoint(x: bSize * 0.4 * CGFloat(flutterScale), y: bSize * 0.5))
                path.closeSubpath()

                context.setFillColor(UIColor.white.withAlphaComponent(CGFloat(alpha)).cgColor)
                context.addPath(path)
                context.fillPath()

                context.setStrokeColor(UIColor(red: 250/255, green: 250/255, blue: 255/255, alpha: CGFloat(alpha)).cgColor)
                context.setLineWidth(bSize * 0.08)
                context.addPath(path)
                context.strokePath()

                context.restoreGState()
            }
        }
    }

    private func sketchedHeartPath(cx: CGFloat, cy: CGFloat, w: CGFloat, h: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: cx, y: cy + h * 0.35))
        path.addCurve(to: CGPoint(x: cx - w * 0.15, y: cy - h * 0.45),
                      control1: CGPoint(x: cx - w * 0.45, y: cy - h * 0.1),
                      control2: CGPoint(x: cx - w * 0.4, y: cy - h * 0.45))
        path.addCurve(to: CGPoint(x: cx, y: cy - h * 0.1),
                      control1: CGPoint(x: cx, y: cy - h * 0.45),
                      control2: CGPoint(x: cx, y: cy - h * 0.1))
        path.addCurve(to: CGPoint(x: cx + w * 0.15, y: cy - h * 0.45),
                      control1: CGPoint(x: cx, y: cy - h * 0.1),
                      control2: CGPoint(x: cx, y: cy - h * 0.45))
        path.addCurve(to: CGPoint(x: cx, y: cy + h * 0.35),
                      control1: CGPoint(x: cx + w * 0.4, y: cy - h * 0.45),
                      control2: CGPoint(x: cx + w * 0.45, y: cy - h * 0.1))
        path.addLine(to: CGPoint(x: cx - w * 0.05, y: cy + h * 0.3))
        return path
    }

    private func cloudPath(cx: CGFloat, cy: CGFloat, width: CGFloat, height: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: cx - width * 0.4, y: cy + height * 0.2))
        path.addLine(to: CGPoint(x: cx + width * 0.4, y: cy + height * 0.2))
        path.addQuadCurve(to: CGPoint(x: cx + width * 0.35, y: cy - height * 0.3),
                          control: CGPoint(x: cx + width * 0.55, y: cy - height * 0.1))
        path.addQuadCurve(to: CGPoint(x: cx, y: cy - height * 0.4),
                          control: CGPoint(x: cx + width * 0.20, y: cy - height * 0.6))
        path.addQuadCurve(to: CGPoint(x: cx - width * 0.35, y: cy - height * 0.3),
                          control: CGPoint(x: cx - width * 0.20, y: cy - height * 0.6))
        path.addQuadCurve(to: CGPoint(x: cx - width * 0.4, y: cy + height * 0.2),
                          control: CGPoint(x: cx - width * 0.55, y: cy - height * 0.1))
        path.closeSubpath()
        return path
    }

    private func drawSketchedHeart(context: CGContext, cx: CGFloat, cy: CGFloat, size: CGFloat, alpha: CGFloat, time: CGFloat, index: Int) {
        let w = size
        let h = size * 1.05
        
        context.saveGState()
        let rotation = sin(time * 0.003 + CGFloat(index)) * 12.0 * .pi / 180.0
        
        context.translateBy(x: cx, y: cy)
        context.rotate(by: rotation)
        context.translateBy(x: -cx, y: -cy)
        
        context.setStrokeColor(UIColor(white: 1.0, alpha: alpha).cgColor)
        context.setLineWidth(size * 0.07)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        
        context.saveGState()
        let rX1 = CGFloat.random(in: -0.75...0.75)
        let rY1 = CGFloat.random(in: -0.75...0.75)
        context.translateBy(x: rX1, y: rY1)
        context.addPath(sketchedHeartPath(cx: cx, cy: cy, w: w, h: h))
        context.strokePath()
        context.restoreGState()
        
        context.saveGState()
        let rX2 = CGFloat.random(in: -0.75...0.75)
        let rY2 = CGFloat.random(in: -0.75...0.75)
        let rot2 = CGFloat.random(in: -1.0...1.0) * .pi / 180.0
        context.translateBy(x: rX2, y: rY2)
        context.translateBy(x: cx, y: cy)
        context.rotate(by: rot2)
        context.translateBy(x: -cx, y: -cy)
        context.addPath(sketchedHeartPath(cx: cx, cy: cy, w: w * 0.98, h: h * 0.98))
        context.strokePath()
        context.restoreGState()
        
        context.restoreGState()
    }

    private func drawSketchedCloud(context: CGContext, cx: CGFloat, cy: CGFloat, width: CGFloat, height: CGFloat, alpha: CGFloat, time: CGFloat, index: Int) {
        context.saveGState()
        let bob = sin(time * 0.0022 + CGFloat(index)) * 6.0
        context.translateBy(x: 0, y: bob)
        
        context.setStrokeColor(UIColor(white: 1.0, alpha: alpha).cgColor)
        context.setLineWidth(width * 0.035)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        
        context.saveGState()
        let rX1 = CGFloat.random(in: -1.0...1.0)
        let rY1 = CGFloat.random(in: -1.0...1.0)
        context.translateBy(x: rX1, y: rY1)
        context.addPath(cloudPath(cx: cx, cy: cy, width: width, height: height))
        context.strokePath()
        context.restoreGState()
        
        context.saveGState()
        let rX2 = CGFloat.random(in: -1.0...1.0)
        let rY2 = CGFloat.random(in: -1.0...1.0)
        context.translateBy(x: rX2, y: rY2)
        context.addPath(cloudPath(cx: cx, cy: cy, width: width * 0.99, height: height * 0.99))
        context.strokePath()
        context.restoreGState()
        
        context.restoreGState()
    }

    private func drawNeonOutline(context: CGContext, face: DetectedFace, size: CGSize) {
        let box = face.boundingBox
        let faceW = box.width
        let faceH = box.height
        let cx = box.midX
        
        let top = topOfHeadPoint(face: face)
        let foreheadY = (top?.y ?? box.minY) + faceH * 0.03
        
        let bottomFaceY = face.faceContour?.reduce(box.maxY, { max($0, $1.y) }) ?? box.maxY
        let eyeDist = eyeDistance(face)
        let time = CGFloat(CACurrentMediaTime() * 1000.0)
        
        var outlinePath: CGPath? = nil
        var hasBodyPath = false
        
        if let points = face.faceContour, points.count >= 17 {
            let leftJaw = points[0]
            let rightJaw = points[points.count - 1]
            
            let leftPt = leftJaw.x < rightJaw.x ? leftJaw : rightJaw
            let rightPt = leftJaw.x < rightJaw.x ? rightJaw : leftJaw
            
            let leftShoulderX = leftPt.x - faceW * 0.95
            let leftShoulderY = leftPt.y + faceH * 0.75
            let rightShoulderX = rightPt.x + faceW * 0.95
            let rightShoulderY = rightPt.y + faceH * 0.75
            
            let bottomY = size.height
            
            let path = CGMutablePath()
            path.move(to: CGPoint(x: leftShoulderX, y: bottomY))
            path.addLine(to: CGPoint(x: leftShoulderX, y: leftShoulderY))
            path.addQuadCurve(to: leftPt, control: CGPoint(x: leftPt.x - faceW * 0.20, y: leftPt.y + faceH * 0.30))
            
            // Arch upwards over the top of the hair/head
            let topPoint = CGPoint(x: cx, y: box.minY - faceH * 0.30)
            path.addQuadCurve(to: topPoint, control: CGPoint(x: leftPt.x, y: topPoint.y))
            path.addQuadCurve(to: rightPt, control: CGPoint(x: rightPt.x, y: topPoint.y))
            
            path.addQuadCurve(to: CGPoint(x: rightShoulderX, y: rightShoulderY), control: CGPoint(x: rightPt.x + faceW * 0.20, y: rightPt.y + faceH * 0.30))
            path.addLine(to: CGPoint(x: rightShoulderX, y: bottomY))
            outlinePath = path
            hasBodyPath = true
        }
        
        if !hasBodyPath {
            outlinePath = faceOvalPath(face: face)
        }
        
        if let outlinePath = outlinePath {
            context.saveGState()
            context.setLineCap(.round)
            context.setLineJoin(.round)
            
            func drawOutlinePass(offset: CGPoint, alphaMult: CGFloat) {
                context.saveGState()
                context.translateBy(x: offset.x, y: offset.y)
                
                // Neon outer glows
                context.setStrokeColor(UIColor(white: 1.0, alpha: 0.15 * alphaMult).cgColor)
                context.setLineWidth(eyeDist * 0.132)
                context.addPath(outlinePath)
                context.strokePath()
                
                context.setStrokeColor(UIColor(white: 1.0, alpha: 0.35 * alphaMult).cgColor)
                context.setLineWidth(eyeDist * 0.082)
                context.addPath(outlinePath)
                context.strokePath()
                
                context.setStrokeColor(UIColor(white: 1.0, alpha: 0.6 * alphaMult).cgColor)
                context.setLineWidth(eyeDist * 0.042)
                context.addPath(outlinePath)
                context.strokePath()
                
                // Core white line
                context.setStrokeColor(UIColor(white: 1.0, alpha: alphaMult).cgColor)
                context.setLineWidth(eyeDist * 0.022)
                context.addPath(outlinePath)
                context.strokePath()
                
                context.restoreGState()
            }
            
            let rX1 = CGFloat.random(in: -1.0...1.0)
            let rY1 = CGFloat.random(in: -1.0...1.0)
            drawOutlinePass(offset: CGPoint(x: rX1, y: rY1), alphaMult: 0.9)
            
            let rX2 = CGFloat.random(in: -1.0...1.0)
            let rY2 = CGFloat.random(in: -1.0...1.0)
            drawOutlinePass(offset: CGPoint(x: rX2, y: rY2), alphaMult: 0.9)
            
            context.restoreGState()
        }
        
        let heartLocations: [(CGFloat, CGFloat, CGFloat)] = [
            (-0.72, -0.22, 0.16),
            (-0.45, -0.42, 0.14),
            ( 0.45, -0.42, 0.14),
            ( 0.72, -0.22, 0.16),
            (-0.85,  0.15, 0.15),
            ( 0.85,  0.15, 0.15)
        ]
        
        for (index, loc) in heartLocations.enumerated() {
            let bobY = sin(time * 0.0022 + CGFloat(index) * 1.5) * faceH * 0.03
            let bobX = cos(time * 0.0018 + CGFloat(index) * 0.9) * faceW * 0.02
            let hCx = cx + loc.0 * faceW + bobX
            let hCy = foreheadY + loc.1 * faceH + bobY
            let size = faceW * loc.2
            
            drawSketchedHeart(context: context, cx: hCx, cy: hCy, size: size, alpha: 220.0/255.0, time: time, index: index)
        }
        
        let cloudLocations: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
            (-0.48, 0.22, 0.35, 0.18),
            ( 0.48, 0.22, 0.35, 0.18)
        ]
        
        for (index, loc) in cloudLocations.enumerated() {
            let clX = cx + loc.0 * faceW
            let clY = bottomFaceY + loc.1 * faceH
            let clW = faceW * loc.2
            let clH = faceH * loc.3
            
            drawSketchedCloud(context: context, cx: clX, cy: clY, width: clW, height: clH, alpha: 200.0/255.0, time: time, index: index)
        }
    }

    private func drawEvilHorns(context: CGContext, face: DetectedFace) {
        guard let le = face.leftEye, let re = face.rightEye else { return }
        let rollAngle = face.rollAngle
        let eyeDist = eyeDistance(face)
        let faceCx = (le.x + re.x) / 2.0
        let faceCy = (le.y + re.y) / 2.0
        let anchor = CGPoint(x: faceCx, y: faceCy)

        // Neon stroke thickness layers
        let coreW = eyeDist * 0.038
        let midW  = eyeDist * 0.095
        let glowW = eyeDist * 0.220

        // Horn geometry
        let hornH   = eyeDist * 1.08
        let hornArc = eyeDist * 0.72

        withHeadRotation(context: context, anchor: anchor, rollAngle: rollAngle) {
            
            func drawNeonHorn(cx: CGFloat, cy: CGFloat, sweep: CGFloat) {
                let botX = cx + sweep * eyeDist * 0.04
                let botY = cy + eyeDist * 0.06
                let tipX = cx - sweep * eyeDist * 0.04
                let tipY = cy - hornH

                // OUTER ARC
                let outerPath = CGMutablePath()
                outerPath.move(to: CGPoint(x: botX, y: botY))
                outerPath.addCurve(to: CGPoint(x: tipX, y: tipY),
                                   control1: CGPoint(x: botX + sweep * hornArc * 0.92, y: botY - hornH * 0.24),
                                   control2: CGPoint(x: tipX + sweep * hornArc * 0.46, y: tipY + hornH * 0.52))

                // INNER ARC
                let innerPath = CGMutablePath()
                let inset = eyeDist * 0.15
                innerPath.move(to: CGPoint(x: botX - sweep * inset * 0.30, y: botY - eyeDist * 0.09))
                innerPath.addCurve(to: CGPoint(x: tipX + sweep * inset * 0.04, y: tipY + eyeDist * 0.07),
                                   control1: CGPoint(x: botX + sweep * (hornArc * 0.92 - inset), y: botY - hornH * 0.22),
                                   control2: CGPoint(x: tipX + sweep * (hornArc * 0.46 - inset * 0.65), y: tipY + hornH * 0.50))

                // Radial red bloom behind the arc area
                let bgX = cx + sweep * hornArc * 0.38
                let bgY = cy - hornH * 0.44
                let radius = eyeDist * 0.58

                context.saveGState()
                let circlePath = UIBezierPath(arcCenter: CGPoint(x: bgX, y: bgY), radius: radius, startAngle: 0, endAngle: 2.0 * .pi, clockwise: true).cgPath
                context.addPath(circlePath)
                context.clip()

                let colors = [
                    UIColor(red: 255/255, green: 0/255, blue: 0/255, alpha: 75.0/255.0).cgColor,
                    UIColor.clear.cgColor
                ] as CFArray
                let locations: [CGFloat] = [0.0, 1.0]
                if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: locations) {
                    context.drawRadialGradient(gradient, startCenter: CGPoint(x: bgX, y: bgY), startRadius: 0, endCenter: CGPoint(x: bgX, y: bgY), endRadius: radius, options: .drawsAfterEndLocation)
                }
                context.restoreGState()

                // Layered neon draw function
                func neonDraw(path: CGPath) {
                    // Layer 1 — outermost soft red bloom
                    context.saveGState()
                    context.setStrokeColor(UIColor(red: 255/255, green: 0/255, blue: 0/255, alpha: 75.0/255.0).cgColor)
                    context.setLineWidth(glowW)
                    context.setLineCap(.round)
                    context.addPath(path)
                    context.strokePath()
                    context.restoreGState()

                    // Layer 2 — mid red glow
                    context.saveGState()
                    context.setStrokeColor(UIColor(red: 255/255, green: 20/255, blue: 0/255, alpha: 195.0/255.0).cgColor)
                    context.setLineWidth(midW)
                    context.setLineCap(.round)
                    context.addPath(path)
                    context.strokePath()
                    context.restoreGState()

                    // Layer 3 — bright red (almost solid)
                    context.saveGState()
                    context.setStrokeColor(UIColor(red: 255/255, green: 65/255, blue: 30/255, alpha: 1.0).cgColor)
                    context.setLineWidth(coreW * 1.7)
                    context.setLineCap(.round)
                    context.addPath(path)
                    context.strokePath()
                    context.restoreGState()

                    // Layer 4 — white core
                    context.saveGState()
                    context.setStrokeColor(UIColor.white.cgColor)
                    context.setLineWidth(coreW)
                    context.setLineCap(.round)
                    context.addPath(path)
                    context.strokePath()
                    context.restoreGState()
                }

                neonDraw(path: outerPath)
                neonDraw(path: innerPath)
            }

            drawNeonHorn(cx: le.x - eyeDist * 0.22, cy: faceCy - eyeDist * 1.08, sweep: -1.0)
            drawNeonHorn(cx: re.x + eyeDist * 0.22, cy: faceCy - eyeDist * 1.08, sweep: 1.0)
        }
    }

    private func drawPinkBows(context: CGContext, face: DetectedFace) {
        guard let bow = bowBitmap, let le = face.leftEye, let re = face.rightEye else { return }
        let rollAngle = face.rollAngle
        let eyeDist = eyeDistance(face)
        let faceCx = (le.x + re.x) / 2.0
        let faceCy = (le.y + re.y) / 2.0
        
        let bowW = eyeDist * 0.95
        let bowH = CGFloat(bow.height) * (bowW / CGFloat(bow.width))
        
        let lx = le.x - eyeDist * 0.52
        let rx = re.x + eyeDist * 0.52
        let ly = faceCy - eyeDist * 1.08
        let ry = ly

        withHeadRotation(context: context, anchor: CGPoint(x: faceCx, y: faceCy), rollAngle: rollAngle) {
            // Left bow
            context.saveGState()
            context.translateBy(x: lx, y: ly)
            context.rotate(by: -25.0 * .pi / 180.0)
            drawCGImageCorrect(bow, in: CGRect(x: -bowW/2, y: -bowH/2, width: bowW, height: bowH), context: context)
            context.restoreGState()

            // Right bow
            context.saveGState()
            context.translateBy(x: rx, y: ry)
            context.rotate(by: 25.0 * .pi / 180.0)
            drawCGImageCorrect(bow, in: CGRect(x: -bowW/2, y: -bowH/2, width: bowW, height: bowH), context: context)
            context.restoreGState()
        }
    }

    private func drawCrescentMoons(context: CGContext, face: DetectedFace) {
        let box = face.boundingBox
        let faceW = box.width
        let faceH = box.height
        let cx = box.midX
        let cy = box.midY
        let rollAngle = face.rollAngle
        let anchor = CGPoint(x: cx, y: cy)

        let moons = [
            (CGFloat(-0.24), CGFloat(-0.42), CGFloat(1.00)),
            (CGFloat(-0.06), CGFloat(-0.32), CGFloat(0.85)),
            (CGFloat( 0.20), CGFloat(-0.40), CGFloat(0.95)),
            (CGFloat( 0.32), CGFloat(-0.25), CGFloat(1.00)),
            (CGFloat(-0.30), CGFloat(-0.15), CGFloat(0.80)),
            (CGFloat(-0.04), CGFloat(-0.05), CGFloat(0.70)),
            (CGFloat( 0.05), CGFloat( 0.22), CGFloat(0.80)),
            (CGFloat(-0.35), CGFloat( 0.06), CGFloat(0.90)),
            (CGFloat( 0.32), CGFloat( 0.13), CGFloat(0.95)),
            (CGFloat(-0.33), CGFloat( 0.26), CGFloat(0.85)),
            (CGFloat( 0.24), CGFloat( 0.36), CGFloat(0.85)),
            (CGFloat(-0.16), CGFloat( 0.44), CGFloat(0.90))
        ]

        let baseR = faceW * 0.038

        withHeadRotation(context: context, anchor: anchor, rollAngle: rollAngle) {
            for (rx, ry, sz) in moons {
                let px = cx + rx * faceW
                let py = cy + ry * faceH
                let outerR = baseR * sz
                let innerR = outerR * 0.68
                let offX   = outerR * 0.38

                context.saveGState()
                let path = CGMutablePath()
                // Outer circle
                path.addEllipse(in: CGRect(x: px - outerR, y: py - outerR, width: outerR * 2.0, height: outerR * 2.0))
                // Inner circle
                path.addEllipse(in: CGRect(x: px + offX - innerR, y: py - offX * 0.12 - innerR, width: innerR * 2.0, height: innerR * 2.0))
                
                context.setFillColor(UIColor(red: 255/255, green: 205/255, blue: 20/255, alpha: 235.0/255.0).cgColor)
                context.addPath(path)
                context.fillPath(using: .evenOdd)
                context.restoreGState()
            }
        }
    }

    private func drawPinkHearts(context: CGContext, face: DetectedFace) {
        let box = face.boundingBox
        let faceW = box.width
        let faceH = box.height
        let cx = box.midX
        let top = topOfHeadPoint(face: face)
        let foreheadY = (top?.y ?? box.minY) - faceH * 0.48
        let anchor = CGPoint(x: cx, y: foreheadY)
        let rollAngle = face.rollAngle
        let time = CACurrentMediaTime()
        let floatPhase = CGFloat(time / 1.6)

        let heartColor = UIColor(red: 255/255, green: 65/255, blue: 155/255, alpha: 220.0/255.0)

        let hearts = [
            (CGFloat(-0.48), CGFloat(-0.20), CGFloat(1.00)),
            (CGFloat(-0.34), CGFloat(-0.24), CGFloat(1.00)),
            (CGFloat(-0.20), CGFloat(-0.27), CGFloat(1.00)),
            (CGFloat(-0.06), CGFloat(-0.28), CGFloat(1.00)),
            (CGFloat( 0.08), CGFloat(-0.27), CGFloat(1.00)),
            (CGFloat( 0.22), CGFloat(-0.24), CGFloat(1.00)),
            (CGFloat( 0.36), CGFloat(-0.20), CGFloat(1.00)),
            (CGFloat(-0.50), CGFloat(-0.02), CGFloat(1.00)),
            (CGFloat(-0.36), CGFloat(-0.05), CGFloat(1.00)),
            (CGFloat(-0.22), CGFloat(-0.06), CGFloat(1.00)),
            (CGFloat(-0.08), CGFloat(-0.07), CGFloat(1.00)),
            (CGFloat( 0.06), CGFloat(-0.06), CGFloat(1.00)),
            (CGFloat( 0.20), CGFloat(-0.05), CGFloat(1.00)),
            (CGFloat( 0.34), CGFloat(-0.02), CGFloat(1.00)),
            (CGFloat(-0.46), CGFloat( 0.16), CGFloat(1.00)),
            (CGFloat(-0.31), CGFloat( 0.12), CGFloat(1.00)),
            (CGFloat(-0.16), CGFloat( 0.10), CGFloat(1.00)),
            (CGFloat(-0.01), CGFloat( 0.09), CGFloat(1.00)),
            (CGFloat( 0.14), CGFloat( 0.10), CGFloat(1.00)),
            (CGFloat( 0.29), CGFloat( 0.12), CGFloat(1.00)),
            (CGFloat( 0.44), CGFloat( 0.16), CGFloat(1.00))
        ]

        withHeadRotation(context: context, anchor: anchor, rollAngle: rollAngle) {
            for (index, (rx, ry, sz)) in hearts.enumerated() {
                let risePhase = (floatPhase + CGFloat(index) * 0.08).truncatingRemainder(dividingBy: 1.0)
                let rise = risePhase * faceH * 0.10
                let floatX = cos(floatPhase * 0.45 + CGFloat(index) * 0.65) * faceW * 0.002
                let bobY = sin(CGFloat(index) * 0.92 + floatPhase * 0.75) * faceH * 0.045
                
                let hCx = cx + rx * faceW + floatX
                let hCy = foreheadY + ry * faceH + bobY - rise
                let hW = faceW * 0.092 * sz
                let hH = hW * 1.06
                let rotation = CGFloat((index % 4 == 0) ? -7.0 : ((index % 4 == 1) ? -2.0 : ((index % 4 == 2) ? 3.0 : 8.0)))

                context.saveGState()
                context.translateBy(x: hCx, y: hCy)
                context.rotate(by: rotation * .pi / 180.0)

                let path = CGMutablePath()
                path.move(to: CGPoint(x: 0, y: hH * 0.35))
                path.addCurve(to: CGPoint(x: -hW * 0.12, y: -hH * 0.45),
                              control1: CGPoint(x: -hW * 0.45, y: -hH * 0.08),
                              control2: CGPoint(x: -hW * 0.40, y: -hH * 0.45))
                path.addCurve(to: CGPoint(x: 0, y: -hH * 0.1),
                              control1: CGPoint(x: 0, y: -hH * 0.45),
                              control2: CGPoint(x: 0, y: -hH * 0.1))
                path.addCurve(to: CGPoint(x: hW * 0.12, y: -hH * 0.45),
                              control1: CGPoint(x: 0, y: -hH * 0.1),
                              control2: CGPoint(x: 0, y: -hH * 0.45))
                path.addCurve(to: CGPoint(x: 0, y: hH * 0.35),
                              control1: CGPoint(x: hW * 0.40, y: -hH * 0.45),
                              control2: CGPoint(x: hW * 0.45, y: -hH * 0.08))
                path.closeSubpath()

                context.setFillColor(heartColor.cgColor)
                context.addPath(path)
                context.fillPath()
                context.restoreGState()
            }
        }
    }

    private func drawPookieBow(context: CGContext, face: DetectedFace) {
        guard let bow = bowBitmap, let le = face.leftEye, let re = face.rightEye else { return }
        let rollAngle = face.rollAngle
        let eyeDist = eyeDistance(face)
        let faceCx = (le.x + re.x) / 2.0
        let faceCy = (le.y + re.y) / 2.0

        let bowDisplayW = eyeDist * 1.15
        let scale = bowDisplayW / CGFloat(bow.width)
        let bowDisplayH = CGFloat(bow.height) * scale

        let bx = re.x + eyeDist * 0.15
        let by = re.y - eyeDist * 0.80

        withHeadRotation(context: context, anchor: CGPoint(x: faceCx, y: faceCy), rollAngle: rollAngle) {
            context.saveGState()
            context.translateBy(x: bx, y: by)
            context.rotate(by: 35.0 * .pi / 180.0)
            drawCGImageCorrect(bow, in: CGRect(x: -bowDisplayW/2, y: -bowDisplayH/2, width: bowDisplayW, height: bowDisplayH), context: context)
            context.restoreGState()
        }
    }

    private func drawPandaFaces(context: CGContext, face: DetectedFace) {
        guard let rawPanda = pandaBitmap else { return }
        let box = face.boundingBox
        let faceW = box.width
        let faceH = box.height
        let cx = box.midX
        let cy = box.midY
        let rollAngle = face.rollAngle

        // Setup Stamps
        let stamps = [
            (CGFloat(-0.21), CGFloat(-0.48), CGFloat(0.70), CGFloat(-12)), // forehead left
            (CGFloat( 0.21), CGFloat(-0.48), CGFloat(0.70), CGFloat(15)),  // forehead right
            (CGFloat(-0.33), CGFloat(-0.28), CGFloat(0.65), CGFloat(-20)), // temple left
            (CGFloat( 0.33), CGFloat(-0.28), CGFloat(0.65), CGFloat(25)),  // temple right
            (CGFloat(-0.13), CGFloat(0.05),  CGFloat(0.60), CGFloat(-5)),  // near nose bridge left
            (CGFloat( 0.13), CGFloat(0.05),  CGFloat(0.60), CGFloat(8)),   // near nose bridge right
            (CGFloat(-0.30), CGFloat(0.15),  CGFloat(0.75), CGFloat(-15)), // upper cheek left
            (CGFloat( 0.30), CGFloat(0.15),  CGFloat(0.75), CGFloat(12)),  // upper cheek right
            (CGFloat(-0.21), CGFloat(0.32),  CGFloat(0.68), CGFloat(-8)),  // lower cheek left
            (CGFloat( 0.21), CGFloat(0.32),  CGFloat(0.68), CGFloat(18)),  // lower cheek right
            (CGFloat( 0.00), CGFloat(0.46),  CGFloat(0.72), CGFloat(0)),   // chin
            (CGFloat(-0.11), CGFloat(0.25),  CGFloat(0.55), CGFloat(-10)), // under lips left
            (CGFloat( 0.11), CGFloat(0.25),  CGFloat(0.55), CGFloat(12))   // under lips right
        ]

        withHeadRotation(context: context, anchor: CGPoint(x: cx, y: cy), rollAngle: rollAngle) {
            for stamp in stamps {
                let px = cx + stamp.0 * faceW
                let py = cy + stamp.1 * faceH
                let targetSize = faceW * 0.12 * stamp.2

                context.saveGState()
                context.translateBy(x: px, y: py)
                context.rotate(by: stamp.3 * .pi / 180.0)
                drawCGImageCorrect(rawPanda, in: CGRect(x: -targetSize/2, y: -targetSize/2, width: targetSize, height: targetSize), context: context)
                context.restoreGState()
            }
        }
    }

    private func drawSpidermanMask(context: CGContext, face: DetectedFace) {
        guard let maskPath = faceOvalPath(face: face), let le = face.leftEye, let re = face.rightEye else { return }
        let b = face.boundingBox
        let faceW = b.width
        let faceH = b.height
        let eyeDist = eyeDistance(face)

        let cx = b.midX
        let cy = b.midY
        let rollAngle = face.rollAngle
        let rad = -rollAngle * .pi / 180.0
        let cosA = cos(rad)
        let sinA = sin(rad)

        func toLocal(_ pt: CGPoint) -> CGPoint {
            let dx = pt.x - cx
            let dy = pt.y - cy
            let lx = dx * cosA + dy * sinA
            let ly = -dx * sinA + dy * cosA
            return CGPoint(x: lx, y: ly)
        }

        let localLe = toLocal(le)
        let localRe = toLocal(re)
        let webCx = (localLe.x + localRe.x) / 2.0
        let webCy = (localLe.y + localRe.y) / 2.0 + eyeDist * 0.12

        context.saveGState()
        context.addPath(maskPath)
        context.clip()

        // Translate and rotate canvas to match head rotation
        context.translateBy(x: cx, y: cy)
        context.rotate(by: -rollAngle * .pi / 180.0)

        // Draw black base mask filling the face
        context.setFillColor(UIColor.black.cgColor)
        context.fill(CGRect(x: -faceW * 1.5, y: -faceH * 1.5, width: faceW * 3.0, height: faceH * 3.0))

        // White web pattern
        context.setStrokeColor(UIColor.white.cgColor)
        context.setLineWidth(faceW * 0.010)
        
        let numRadials = 12
        let maxRadius = max(faceW, faceH) * 1.5
        for i in 0..<numRadials {
            let angle = CGFloat(i) * 2.0 * .pi / CGFloat(numRadials)
            context.move(to: CGPoint(x: webCx, y: webCy))
            context.addLine(to: CGPoint(x: webCx + cos(angle) * maxRadius, y: webCy + sin(angle) * maxRadius))
            context.strokePath()
        }

        // Web rings (sagging concentric web rings using quadTo)
        let numRings = 6
        for r in 1...numRings {
            let radius = maxRadius * 0.14 * CGFloat(r)
            let webPath = CGMutablePath()
            for i in 0...numRadials {
                let angle = CGFloat(i) * 2.0 * .pi / CGFloat(numRadials)
                let px = webCx + cos(angle) * radius
                let py = webCy + sin(angle) * radius
                if i == 0 {
                    webPath.move(to: CGPoint(x: px, y: py))
                } else {
                    let anglePrev = CGFloat(i - 1) * 2.0 * .pi / CGFloat(numRadials)
                    let angleMid = (anglePrev + angle) / 2.0
                    let ctrlRadius = radius * 0.86
                    let cx1 = webCx + cos(angleMid) * ctrlRadius
                    let cy1 = webCy + sin(angleMid) * ctrlRadius
                    webPath.addQuadCurve(to: CGPoint(x: px, y: py), control: CGPoint(x: cx1, y: cy1))
                }
            }
            context.addPath(webPath)
            context.strokePath()
        }

        // Spiderman eyes
        let leftEyePath = CGMutablePath()
        leftEyePath.move(to: CGPoint(x: localLe.x + eyeDist * 0.32, y: localLe.y + eyeDist * 0.10))
        leftEyePath.addQuadCurve(to: CGPoint(x: localLe.x - 0.40 * eyeDist, y: localLe.y - 0.30 * eyeDist),
                                 control: CGPoint(x: localLe.x - 0.05 * eyeDist, y: localLe.y - 0.25 * eyeDist))
        leftEyePath.addQuadCurve(to: CGPoint(x: localLe.x - 0.45 * eyeDist, y: localLe.y + 0.15 * eyeDist),
                                 control: CGPoint(x: localLe.x - 0.48 * eyeDist, y: localLe.y - 0.05 * eyeDist))
        leftEyePath.addQuadCurve(to: CGPoint(x: localLe.x + 0.32 * eyeDist, y: localLe.y + 0.10),
                                 control: CGPoint(x: localLe.x - 0.10 * eyeDist, y: localLe.y + 0.28 * eyeDist))
        leftEyePath.closeSubpath()

        let rightEyePath = CGMutablePath()
        rightEyePath.move(to: CGPoint(x: localRe.x - eyeDist * 0.32, y: localRe.y + eyeDist * 0.10))
        rightEyePath.addQuadCurve(to: CGPoint(x: localRe.x + 0.40 * eyeDist, y: localRe.y - 0.30 * eyeDist),
                                  control: CGPoint(x: localRe.x + 0.05 * eyeDist, y: localRe.y - 0.25 * eyeDist))
        rightEyePath.addQuadCurve(to: CGPoint(x: localRe.x + 0.45 * eyeDist, y: localRe.y + 0.15 * eyeDist),
                                  control: CGPoint(x: localRe.x + 0.48 * eyeDist, y: localRe.y - 0.05 * eyeDist))
        rightEyePath.addQuadCurve(to: CGPoint(x: localRe.x - 0.32 * eyeDist, y: localRe.y + 0.10),
                                  control: CGPoint(x: localRe.x + 0.10 * eyeDist, y: localRe.y + 0.28 * eyeDist))
        rightEyePath.closeSubpath()

        context.setFillColor(UIColor.white.cgColor)
        context.addPath(leftEyePath)
        context.addPath(rightEyePath)
        context.fillPath()

        context.setStrokeColor(UIColor.black.cgColor)
        context.setLineWidth(eyeDist * 0.14)
        context.setLineJoin(.round)
        context.setLineCap(.round)
        context.addPath(leftEyePath)
        context.addPath(rightEyePath)
        context.strokePath()

        context.restoreGState()
    }

    private func drawEyesReveal(context: CGContext, frame: CGImage, face: DetectedFace?, size: CGSize) {
        context.setFillColor(UIColor.black.cgColor)
        context.fill(CGRect(origin: .zero, size: size))

        let cx = size.width * 0.5
        let cy = size.height * 0.42
        let halfW = size.width * 0.46
        let halfH = size.height * 0.082

        // Torn path
        let path = CGMutablePath()
        let steps = 80
        let stepSize = (halfW * 2) / CGFloat(steps)

        func getTornOffset(_ x: CGFloat) -> CGFloat {
            return sin(x * 0.04) * 8.0 + cos(x * 0.095) * 5.0 + sin(x * 0.22) * 2.5
        }

        let startX = -halfW
        let startY = -halfH + getTornOffset(startX)
        path.move(to: CGPoint(x: cx + startX, y: cy + startY))

        for i in 1...steps {
            let x = -halfW + CGFloat(i) * stepSize
            let y = -halfH + getTornOffset(x)
            path.addLine(to: CGPoint(x: cx + x, y: cy + y))
        }

        path.addLine(to: CGPoint(x: cx + halfW, y: cy + halfH + getTornOffset(halfW)))

        for i in (0..<steps).reversed() {
            let x = -halfW + CGFloat(i) * stepSize
            let y = halfH + getTornOffset(x)
            path.addLine(to: CGPoint(x: cx + x, y: cy + y))
        }
        path.closeSubpath()

        // Draw cropped grayscale frame inside torn path
        context.saveGState()
        context.addPath(path)
        context.clip()

        // Grayscale conversion
        let ciImg = CIImage(cgImage: frame)
        let gray = ciImg.applyingFilter("CIPhotoEffectMono")
        if let grayCG = ciContext.createCGImage(gray, from: gray.extent) {
            drawCGImageCorrect(grayCG, in: CGRect(origin: .zero, size: size), context: context)
        }
        context.restoreGState()

        // Draw white border
        context.setStrokeColor(UIColor.white.cgColor)
        context.setLineWidth(size.width * 0.012)
        context.addPath(path)
        context.strokePath()

        // Text
        drawFlippedText(context: context, text: "eyes always reveal the truth 👀✨", x: cx, y: size.height * 0.58, fontSize: size.width * 0.046, color: .white, center: true)
    }

    private func drawPlumeriaFlower(context: CGContext, face: DetectedFace) {
        guard let le = face.leftEye, face.rightEye != nil else { return }
        let eyeDist = eyeDistance(face)
        let rollAngle = face.rollAngle

        // Position on top of the left ear if detected; otherwise fallback to the left eye offset
        let earX: CGFloat
        let earY: CGFloat
        if let earPoint = face.leftEar {
            earX = earPoint.x + eyeDist * 0.12
            earY = earPoint.y - eyeDist * 0.32
        } else {
            earX = le.x - eyeDist * 0.32
            earY = le.y - eyeDist * 0.32
        }
        let size = eyeDist * 0.45

        context.saveGState()
        context.translateBy(x: earX, y: earY)
        context.rotate(by: -rollAngle * .pi / 180.0)

        // Subtle shadow
        context.setFillColor(UIColor(white: 0, alpha: 0.15).cgColor)
        let petal = CGMutablePath()
        petal.move(to: .zero)
        petal.addCurve(to: CGPoint(x: 0, y: -size),
                       control1: CGPoint(x: -size * 0.35, y: -size * 0.4),
                       control2: CGPoint(x: -size * 0.25, y: -size))
        petal.addCurve(to: .zero,
                       control1: CGPoint(x: size * 0.25, y: -size),
                       control2: CGPoint(x: size * 0.35, y: -size * 0.4))
        petal.closeSubpath()

        context.saveGState()
        context.translateBy(x: size * 0.08, y: size * 0.08)
        for _ in 0..<5 {
            context.addPath(petal)
            context.fillPath()
            context.rotate(by: 72 * .pi / 180.0)
        }
        context.restoreGState()

        // Petal colors: yellow -> white -> pink
        let colors = [
            UIColor(red: 255/255, green: 204/255, blue: 0/255, alpha: 1),
            UIColor.white,
            UIColor(red: 255/255, green: 77/255, blue: 166/255, alpha: 1)
        ]

        for _ in 0..<5 {
            context.saveGState()
            context.addPath(petal)
            context.clip()

            let cgColors = colors.map { $0.cgColor } as CFArray
            let locations: [CGFloat] = [0.0, 0.45, 1.0]
            if let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: cgColors, locations: locations) {
                context.drawLinearGradient(grad, start: .zero, end: CGPoint(x: 0, y: -size), options: [])
            }
            context.restoreGState()
            context.rotate(by: 72 * .pi / 180.0)
        }

        // Center stamen
        context.setFillColor(UIColor.orange.cgColor)
        context.fillEllipse(in: CGRect(x: -size*0.08, y: -size*0.08, width: size*0.16, height: size*0.16))
        context.restoreGState()
    }

    private func drawSkullFixed(context: CGContext, size: CGSize) {
        guard let skull = skullBitmap else { return }
        let cx = size.width * 0.5
        let cy = size.height * 0.64
        let skullW = size.width * 0.20
        let skullH = skullW * (CGFloat(skull.height) / CGFloat(skull.width))

        drawCGImageCorrect(skull, in: CGRect(x: cx - skullW/2, y: cy - skullH/2, width: skullW, height: skullH), context: context)
    }

    private func drawTalkingForest(context: CGContext, frame: CGImage, face: DetectedFace?, size: CGSize) {
        guard let forest = forestBitmap else { return }
        
        // 1. Draw static forest background (aspect fill / cover)
        drawImageAspectFill(forest, in: CGRect(origin: .zero, size: size), context: context)

        guard let face = face, let le = face.leftEye, let re = face.rightEye, let upper = face.upperLip, let lower = face.lowerLip else { return }

        let eyeDist = eyeDistance(face)
        if eyeDist <= 0 { return }

        let allLips = upper + lower
        let mcX = allLips.map { $0.x }.reduce(0, +) / CGFloat(allLips.count)
        let mcY = allLips.map { $0.y }.reduce(0, +) / CGFloat(allLips.count)

        // Draw feathered eyes and mouth
        drawFeatheredCrop(context: context, frame: frame, center: le, rx: eyeDist * 0.40, ry: eyeDist * 0.28)
        drawFeatheredCrop(context: context, frame: frame, center: re, rx: eyeDist * 0.40, ry: eyeDist * 0.28)
        drawFeatheredCrop(context: context, frame: frame, center: CGPoint(x: mcX, y: mcY), rx: eyeDist * 0.65, ry: eyeDist * 0.40)
    }

    private func drawFeatheredCrop(context: CGContext, frame: CGImage, center: CGPoint, rx: CGFloat, ry: CGFloat) {
        let w = Int(ceil(rx * 2.0))
        let h = Int(ceil(ry * 2.0))
        guard w > 0 && h > 0 else { return }
        
        // 1. Create a grayscale mask context
        let colorSpace = CGColorSpaceCreateDeviceGray()
        guard let maskContext = CGContext(data: nil,
                                          width: w,
                                          height: h,
                                          bitsPerComponent: 8,
                                          bytesPerRow: w,
                                          space: colorSpace,
                                          bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return }
        
        // Clear mask context to black (fully transparent)
        maskContext.setFillColor(gray: 0.0, alpha: 1.0)
        maskContext.fill(CGRect(x: 0, y: 0, width: CGFloat(w), height: CGFloat(h)))
        
        // Draw radial gradient on the mask (white center -> black edge)
        let colors: [CGFloat] = [
            1.0, 1.0,  // White center (fully opaque)
            1.0, 1.0,  // White
            0.0, 1.0   // Black edge (fully transparent)
        ]
        let locations: [CGFloat] = [0.0, 0.40, 1.0]
        guard let gradient = CGGradient(colorSpace: colorSpace, colorComponents: colors, locations: locations, count: 3) else { return }
        
        let localCenter = CGPoint(x: CGFloat(w) / 2.0, y: CGFloat(h) / 2.0)
        let maxRadius = max(rx, ry)
        maskContext.drawRadialGradient(gradient,
                                      startCenter: localCenter, startRadius: 0,
                                      endCenter: localCenter, endRadius: maxRadius,
                                      options: .drawsAfterEndLocation)
        
        // 2. Create the mask image
        guard let maskImage = maskContext.makeImage() else { return }
        
        // 3. Clip the main context using the mask image
        let destRect = CGRect(x: center.x - rx, y: center.y - ry, width: rx * 2.0, height: ry * 2.0)
        context.saveGState()
        context.clip(to: destRect, mask: maskImage)
        
        // 4. Crop the eye/mouth portion from live frame and draw it
        let srcRect = CGRect(x: center.x - rx, y: center.y - ry, width: rx * 2.0, height: ry * 2.0)
        if let croppedFrame = frame.cropping(to: srcRect) {
            drawCGImageCorrect(croppedFrame, in: destRect, context: context)
        } else {
            drawCGImageCorrect(frame, in: destRect, context: context)
        }
        
        context.restoreGState()
    }

    // MARK: - General Decorators (Stamp/Letters/Poster)

    private func drawDayStampText(context: CGContext, size: CGSize) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let timeText = formatter.string(from: Date())
        formatter.dateFormat = "EEEE"
        let dayText = formatter.string(from: Date()).uppercased()

        let x = size.width * 0.12
        let baseline = size.height * 0.80

        drawFlippedText(context: context, text: timeText, x: x, y: baseline - 45, fontSize: size.width * 0.09, color: UIColor(red: 224/255, green: 159/255, blue: 62/255, alpha: 1), center: false)
        drawFlippedText(context: context, text: dayText, x: x, y: baseline, fontSize: size.width * 0.05, color: UIColor(red: 224/255, green: 159/255, blue: 62/255, alpha: 1), center: false)
    }

    private func drawVintageGrainLetterbox(context: CGContext, size: CGSize) {
        let boxSize = min(size.width, size.height)
        let left = (size.width - boxSize) / 2.0
        let top = (size.height - boxSize) / 2.0
        let rect = CGRect(x: left, y: top, width: boxSize, height: boxSize)

        // Letterbox
        context.setFillColor(UIColor.black.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: size.width, height: top))
        context.fill(CGRect(x: 0, y: top + boxSize, width: size.width, height: size.height - (top + boxSize)))

        // Vignette
        drawVignette(context: context, rect: rect)

        // Film grain
        drawFilmGrain(context: context, bounds: rect, alpha: 0.15)

        // Border
        context.setStrokeColor(UIColor(white: 0.94, alpha: 0.86).cgColor)
        context.setLineWidth(boxSize * 0.005)
        context.stroke(rect)
    }

    private func drawWantedPoster(context: CGContext, frame: CGImage, size: CGSize) {
        let w = size.width
        let h = size.height

        // 1. Brick wall background
        let brickColors = [
            UIColor(red: 122/255, green: 36/255, blue: 20/255, alpha: 1),
            UIColor(red: 105/255, green: 31/255, blue: 17/255, alpha: 1),
            UIColor(red: 138/255, green: 53/255, blue: 35/255, alpha: 1),
            UIColor(red: 87/255, green: 26/255, blue: 14/255, alpha: 1),
            UIColor(red: 156/255, green: 68/255, blue: 48/255, alpha: 1) // #9c4430
        ]
        
        let rowH = h / 16.0
        let brickW = w / 3.5
        for row in 0..<17 {
            let top = CGFloat(row) * rowH
            let offset = (row % 2 == 0) ? 0 : -brickW/2.0
            
            var left = offset
            while left < w + brickW {
                let index = Int(abs(sin(Double(row) * 12.3) * Double(brickColors.count))) % brickColors.count
                context.setFillColor(brickColors[index].cgColor)
                context.fill(CGRect(x: left, y: top, width: brickW, height: rowH))
                context.setStrokeColor(UIColor(red: 191/255, green: 178/255, blue: 163/255, alpha: 1).cgColor)
                context.setLineWidth(w * 0.008)
                context.stroke(CGRect(x: left, y: top, width: brickW, height: rowH))
                left += brickW
            }
        }

        // 2. Poster
        let posterW = w * 0.84
        let posterH = posterW * 1.45
        let posterLeft = (w - posterW) / 2.0
        let posterTop = (h - posterH) / 2.0
        let posterRect = CGRect(x: posterLeft, y: posterTop, width: posterW, height: posterH)

        context.setFillColor(UIColor(red: 238/255, green: 218/255, blue: 179/255, alpha: 1).cgColor)
        context.fill(posterRect)

        // Aged vignette style shadow around parchment corners
        context.saveGState()
        context.addRect(posterRect)
        context.clip()
        
        let paperColorSpace = CGColorSpaceCreateDeviceRGB()
        let paperColors = [
            UIColor.clear.cgColor,
            UIColor(red: 0, green: 0, blue: 0, alpha: 0.102).cgColor,
            UIColor(red: 100/255, green: 60/255, blue: 20/255, alpha: 0.333).cgColor
        ] as CFArray
        let paperLocations: [CGFloat] = [0.0, 0.7, 1.0]
        if let paperGradient = CGGradient(colorsSpace: paperColorSpace, colors: paperColors, locations: paperLocations) {
            let center = CGPoint(x: w / 2.0, y: h / 2.0)
            let radius = posterH * 0.7
            context.drawRadialGradient(paperGradient, startCenter: center, startRadius: 0, endCenter: center, endRadius: radius, options: .drawsAfterEndLocation)
        }
        context.restoreGState()

        // Poster Inner border
        let borderOffset = posterW * 0.024
        let innerBorder = posterRect.insetBy(dx: borderOffset, dy: borderOffset)
        context.setStrokeColor(UIColor(red: 43/255, green: 34/255, blue: 26/255, alpha: 1).cgColor)
        context.setLineWidth(posterW * 0.008)
        context.stroke(innerBorder)

        // Cutout frame
        let frameW = posterW * 0.82
        let frameH = frameW * 0.96
        let frameLeft = posterLeft + (posterW - frameW)/2.0
        let frameTop = posterTop + posterH * 0.215
        let frameRect = CGRect(x: frameLeft, y: frameTop, width: frameW, height: frameH)
        
        context.saveGState()
        context.addRect(frameRect)
        context.clip()
        drawCGImageCorrect(frame, in: CGRect(x: 0, y: 0, width: w, height: h), context: context)
        context.restoreGState()

        context.setStrokeColor(UIColor(red: 43/255, green: 34/255, blue: 26/255, alpha: 1).cgColor)
        context.setLineWidth(posterW * 0.016)
        context.stroke(frameRect)

        // Texts
        let cx = w / 2.0
        drawFlippedText(context: context, text: "WANTED", x: cx, y: posterTop + posterH * 0.125, fontSize: posterW * 0.15, color: UIColor(red: 28/255, green: 20/255, blue: 14/255, alpha: 1), center: true, bold: true)
        drawFlippedText(context: context, text: "★ DEAD OR ALIVE ★", x: cx, y: posterTop + posterH * 0.185, fontSize: posterW * 0.062, color: UIColor(red: 28/255, green: 20/255, blue: 14/255, alpha: 1), center: true, bold: true)
        drawFlippedText(context: context, text: "$1,000,000 REWARD", x: cx, y: posterTop + posterH * 0.865, fontSize: posterW * 0.062, color: UIColor(red: 28/255, green: 20/255, blue: 14/255, alpha: 1), center: true, bold: true)
        drawFlippedText(context: context, text: "DANGEROUSLY CUTE", x: cx, y: posterTop + posterH * 0.930, fontSize: posterW * 0.055, color: UIColor(red: 28/255, green: 20/255, blue: 14/255, alpha: 1), center: true, bold: true)
    }

    private func drawHeartFrame(context: CGContext, size: CGSize) {
        let w = size.width
        let h = size.height

        let rectW = w * 0.82
        let rectH = rectW * 0.58
        let rectLeft = (w - rectW) / 2.0
        let rectTop = (h - rectH) / 2.0
        let rect = CGRect(x: rectLeft, y: rectTop, width: rectW, height: rectH)
        let cornerRadius = rectH * 0.12

        // 1. Fill outside of the frame with black using even-odd rule clipping
        context.saveGState()
        let clipPath = CGMutablePath()
        // Outer box
        clipPath.addRect(CGRect(origin: .zero, size: size))
        // Inner rounded rect
        let innerPath = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius).cgPath
        clipPath.addPath(innerPath)
        
        context.addPath(clipPath)
        context.clip(using: .evenOdd)
        
        context.setFillColor(UIColor.black.cgColor)
        context.fill(CGRect(origin: .zero, size: size))
        context.restoreGState()

        // 2. Thin elegance border around the frame
        context.saveGState()
        context.setStrokeColor(UIColor(white: 1.0, alpha: 0.53).cgColor)
        context.setLineWidth(w * 0.006)
        context.addPath(innerPath)
        context.strokePath()
        context.restoreGState()

        // 3. 3D Glossy heart top left
        let heartSize = rectW * 0.18
        // Shift heart slightly inward so it is not cut off on the screen edge
        let heartCx = rect.minX + heartSize * 0.35
        let heartCy = rect.minY + heartSize * 0.15

        context.saveGState()
        context.translateBy(x: heartCx, y: heartCy)
        context.rotate(by: -15.0 * .pi / 180.0)

        let heartPath = CGMutablePath()
        let hw = heartSize
        let hh = heartSize * 1.05
        heartPath.move(to: CGPoint(x: 0, y: hh * 0.35))
        heartPath.addCurve(to: CGPoint(x: -hw * 0.12, y: -hh * 0.45),
                           control1: CGPoint(x: -hw * 0.45, y: -hh * 0.08),
                           control2: CGPoint(x: -hw * 0.40, y: -hh * 0.45))
        heartPath.addCurve(to: CGPoint(x: 0, y: -hh * 0.10),
                           control1: CGPoint(x: 0, y: -hh * 0.45),
                           control2: CGPoint(x: 0, y: -hh * 0.10))
        heartPath.addCurve(to: CGPoint(x: hw * 0.12, y: -hh * 0.45),
                           control1: CGPoint(x: 0, y: -hh * 0.10),
                           control2: CGPoint(x: 0, y: -hh * 0.45))
        heartPath.addCurve(to: CGPoint(x: 0, y: hh * 0.35),
                           control1: CGPoint(x: hw * 0.40, y: -hh * 0.45),
                           control2: CGPoint(x: hw * 0.45, y: -hh * 0.08))
        heartPath.closeSubpath()

        // Multi-layered drop shadow for realistic look
        context.saveGState()
        for i in 1...4 {
            let offset = heartSize * 0.02 * CGFloat(i)
            let alpha = 0.14 / CGFloat(i)
            context.setFillColor(UIColor(white: 0.0, alpha: alpha).cgColor)
            context.saveGState()
            context.translateBy(x: offset, y: offset)
            context.addPath(heartPath)
            context.fillPath()
            context.restoreGState()
        }
        context.restoreGState()

        // Draw radial gradient/glossy fill for the heart
        context.saveGState()
        context.addPath(heartPath)
        context.clip()
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let colors = [
            UIColor(red: 255/255, green: 139/255, blue: 182/255, alpha: 1.0).cgColor,
            UIColor(red: 255/255, green: 46/255, blue: 116/255, alpha: 1.0).cgColor,
            UIColor(red: 179/255, green: 0/255, blue: 59/255, alpha: 1.0).cgColor
        ] as CFArray
        let locations: [CGFloat] = [0.0, 0.6, 1.0]
        if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: locations) {
            let startCenter = CGPoint(x: -hw * 0.15, y: -hh * 0.15)
            let endCenter = CGPoint(x: -hw * 0.15, y: -hh * 0.15)
            context.drawRadialGradient(gradient,
                                       startCenter: startCenter, startRadius: 0,
                                       endCenter: endCenter, endRadius: hw * 0.8,
                                       options: .drawsAfterEndLocation)
        }
        context.restoreGState()

        // Primary specular glossy white highlight circle
        context.setFillColor(UIColor(white: 1.0, alpha: 0.93).cgColor)
        context.fillEllipse(in: CGRect(x: -hw * 0.15 - hw * 0.07, y: -hh * 0.20 - hw * 0.07, width: hw * 0.14, height: hw * 0.14))

        // Secondary soft specular glass reflection highlight
        context.setFillColor(UIColor(white: 1.0, alpha: 0.40).cgColor)
        context.fillEllipse(in: CGRect(x: -hw * 0.10 - hw * 0.12, y: -hh * 0.15 - hw * 0.12, width: hw * 0.24, height: hw * 0.24))

        context.restoreGState()
    }

    private func drawCityTime(context: CGContext, size: CGSize) {
        let w = size.width
        let h = size.height

        // Letterbox bottom
        let rectH = w * 1.22
        context.setFillColor(UIColor.black.cgColor)
        context.fill(CGRect(x: 0, y: rectH, width: w, height: h - rectH))

        // Clock Text stamp
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let timeStr = formatter.string(from: Date())

        drawFlippedText(context: context, text: timeStr, x: w * 0.12, y: rectH + w * 0.08, fontSize: w * 0.052, color: UIColor(red: 224/255, green: 159/255, blue: 62/255, alpha: 1), center: false)
    }

    private func drawImageAspectFill(_ image: CGImage, in rect: CGRect, context: CGContext) {
        let imgW = CGFloat(image.width)
        let imgH = CGFloat(image.height)
        let rectW = rect.width
        let rectH = rect.height
        
        let scale = max(rectW / imgW, rectH / imgH)
        let drawW = imgW * scale
        let drawH = imgH * scale
        let drawX = rect.minX + (rectW - drawW) / 2.0
        let drawY = rect.minY + (rectH - drawH) / 2.0
        
        drawCGImageCorrect(image, in: CGRect(x: drawX, y: drawY, width: drawW, height: drawH), context: context)
    }

    private func drawFashionOverlay(context: CGContext, finalCG: CGImage, size: CGSize) {
        guard let fashion = fashionBitmap else { return }
        let destRect = CGRect(origin: .zero, size: size)
        
        // 1. Draw static background image (aspect fill / cover)
        drawImageAspectFill(fashion, in: destRect, context: context)
        
        // 2. Draw live camera feed on top with less opacity (alpha = 90 / 255 = 0.35)
        context.saveGState()
        context.setAlpha(90.0 / 255.0)
        drawImageAspectFill(finalCG, in: destRect, context: context)
        context.restoreGState()
    }

    // MARK: - Holographic Citizen Card (Lens Verified)

    private func randomizeLensVerifiedCard() {
        cardName = names.randomElement() ?? "User Identity"
        let baseName = cardName.split(separator: " ").first.map(String.init) ?? "USER"
        cardUserId = "\(baseName)_\(Int.random(in: 10...99))"
        cardDepartment = departments.randomElement() ?? "printing engineer"
        cardRole = roles.randomElement() ?? "Midnight Scroller ★★★"
        cardHobby = hobbies.randomElement() ?? "Snapchat opening"

        deluluModifier = CGFloat.random(in: -15...15)
        sleepModifier = CGFloat.random(in: -2...2)
        attentionModifier = CGFloat.random(in: -1.5...1.5)
    }

    private func drawLensVerifiedCard(context: CGContext, frame: CGImage, face: DetectedFace?, size: CGSize) {
        if let face = face {
            // Calculate targets based on expressions
            let targetDelulu = (50.0 + (face.smilingProbability ?? 0.5) * 40.0 + deluluModifier).clamped(1.0, 100.0)
            let targetSleep = (3.0 + (face.leftEyeOpenProbability ?? 0.9) * 4.5 + sleepModifier).clamped(1.0, 12.0)
            let targetAttention = (1.0 + (face.rightEyeOpenProbability ?? 0.9) * 8.0 + attentionModifier).clamped(0.1, 15.0)

            // Smooth EMA
            currentDeluluVal = currentDeluluVal * 0.85 + targetDelulu * 0.15
            currentSleepHoursVal = currentSleepHoursVal * 0.85 + targetSleep * 0.15
            currentAttentionRateVal = currentAttentionRateVal * 0.85 + targetAttention * 0.15
        } else {
            // Slowly decay back to baseline averages if no face is detected
            currentDeluluVal = currentDeluluVal * 0.95 + min(max(97.0 + deluluModifier, 1.0), 100.0) * 0.05
            currentSleepHoursVal = currentSleepHoursVal * 0.95 + min(max(5.3 + sleepModifier, 1.0), 12.0) * 0.05
            currentAttentionRateVal = currentAttentionRateVal * 0.95 + min(max(5.1 + attentionModifier, 0.1), 15.0) * 0.05
        }

        cardDeluluLevel = "\(Int(currentDeluluVal))%"
        cardSleepHours = String(format: "%.1f", currentSleepHoursVal)
        cardAttentionRate = String(format: "%.1f sec", currentAttentionRateVal)

        let w = size.width
        let h = size.height

        // Calculate visible image width based on scaleAspectFill logic of imageView
        let viewW = self.bounds.width > 0 ? self.bounds.width : 375.0
        let viewH = self.bounds.height > 0 ? self.bounds.height : 812.0
        let scale = h > 0 ? viewH / h : 1.0
        let wScaled = w * scale
        let cropOffsetX = max(0.0, (wScaled - viewW) / 2.0)
        let cropOffsetXInImage = cropOffsetX / scale
        let visibleW = w - 2.0 * cropOffsetXInImage

        let cardW = visibleW * 0.94
        let cardH = cardW * 0.72
        let cardLeft = cropOffsetXInImage + (visibleW - cardW) / 2.0
        let cardTop = h * 0.15
        let cardRect = CGRect(x: cardLeft, y: cardTop, width: cardW, height: cardH)
        let cardRx = cardW * 0.05

        // 1. Holographic card background gradient: light lavender -> light blue -> light pink -> white
        let path = UIBezierPath(roundedRect: cardRect, cornerRadius: cardRx).cgPath
        
        context.saveGState()
        let bgColors = [
            UIColor(red: 234/255, green: 233/255, blue: 248/255, alpha: 1).cgColor,
            UIColor(red: 234/255, green: 243/255, blue: 253/255, alpha: 1).cgColor,
            UIColor(red: 251/255, green: 235/255, blue: 243/255, alpha: 1).cgColor,
            UIColor(red: 245/255, green: 246/255, blue: 252/255, alpha: 1).cgColor
        ] as CFArray
        let bgLocations: [CGFloat] = [0.0, 0.35, 0.7, 1.0]
        context.addPath(path)
        context.clip()
        if let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: bgColors, locations: bgLocations) {
            context.drawLinearGradient(grad, start: CGPoint(x: cardRect.minX, y: cardRect.minY), end: CGPoint(x: cardRect.maxX, y: cardRect.maxY), options: [])
        }
        context.restoreGState()

        // 2. Glassmorphic specular gloss overlay
        context.saveGState()
        context.addPath(path)
        context.clip()
        let glossColors = [
            UIColor.white.withAlphaComponent(0.53).cgColor,
            UIColor.white.withAlphaComponent(0.13).cgColor,
            UIColor.clear.cgColor
        ] as CFArray
        let glossLocations: [CGFloat] = [0.0, 0.5, 1.0]
        if let glossGrad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: glossColors, locations: glossLocations) {
            context.drawLinearGradient(glossGrad, start: CGPoint(x: cardRect.minX, y: cardRect.minY), end: CGPoint(x: cardRect.minX + cardW * 0.3, y: cardRect.minY + cardH * 0.3), options: [])
        }
        context.restoreGState()

        // 3. Watermark Concentric Circles
        let wmCx = cardRect.maxX - cardW * 0.22
        let wmCy = cardTop + cardH * 0.46
        context.saveGState()
        context.setStrokeColor(UIColor(red: 122/255, green: 140/255, blue: 208/255, alpha: 0.1).cgColor) // #7A8CD0 alpha 25/255 ~ 0.1
        context.setLineWidth(cardW * 0.002)
        for i in 1...8 {
            let radius = cardW * 0.03 * CGFloat(i)
            context.strokeEllipse(in: CGRect(x: wmCx - radius, y: wmCy - radius, width: radius * 2, height: radius * 2))
        }
        context.restoreGState()

        // 4. Watermark Shield
        let shieldW = cardW * 0.18
        let shieldH = shieldW * 1.2
        context.saveGState()
        let shieldPath = CGMutablePath()
        shieldPath.move(to: CGPoint(x: wmCx, y: wmCy - shieldH / 2))
        shieldPath.addCurve(to: CGPoint(x: wmCx + shieldW / 2, y: wmCy),
                            control1: CGPoint(x: wmCx + shieldW / 3, y: wmCy - shieldH / 2),
                            control2: CGPoint(x: wmCx + shieldW / 2, y: wmCy - shieldH / 4))
        shieldPath.addCurve(to: CGPoint(x: wmCx, y: wmCy + shieldH / 2),
                            control1: CGPoint(x: wmCx + shieldW / 2, y: wmCy + shieldH / 3),
                            control2: CGPoint(x: wmCx + shieldW / 4, y: wmCy + shieldH / 2))
        shieldPath.addCurve(to: CGPoint(x: wmCx - shieldW / 2, y: wmCy),
                            control1: CGPoint(x: wmCx - shieldW / 4, y: wmCy + shieldH / 2),
                            control2: CGPoint(x: wmCx - shieldW / 2, y: wmCy + shieldH / 3))
        shieldPath.addCurve(to: CGPoint(x: wmCx, y: wmCy - shieldH / 2),
                            control1: CGPoint(x: wmCx - shieldW / 2, y: wmCy - shieldH / 4),
                            control2: CGPoint(x: wmCx - shieldW / 3, y: wmCy - shieldH / 2))
        shieldPath.closeSubpath()
        context.setStrokeColor(UIColor(red: 122/255, green: 140/255, blue: 208/255, alpha: 0.1).cgColor)
        context.setLineWidth(cardW * 0.002)
        context.addPath(shieldPath)
        context.strokePath()
        context.restoreGState()

        // L+ watermark text
        drawFlippedText(context: context, text: "L+", x: wmCx, y: wmCy, fontSize: cardW * 0.05, color: UIColor(red: 122/255, green: 140/255, blue: 208/255, alpha: 0.14), center: true, bold: true)

        // 5. Holographic Gradient Card Border
        context.saveGState()
        let borderColors = [
            UIColor(red: 193/255, green: 200/255, blue: 246/255, alpha: 1).cgColor,
            UIColor(red: 140/255, green: 215/255, blue: 247/255, alpha: 1).cgColor,
            UIColor(red: 247/255, green: 204/255, blue: 228/255, alpha: 1).cgColor,
            UIColor(red: 140/255, green: 215/255, blue: 247/255, alpha: 1).cgColor,
            UIColor(red: 193/255, green: 200/255, blue: 246/255, alpha: 1).cgColor
        ] as CFArray
        let borderLocations: [CGFloat] = [0.0, 0.25, 0.5, 0.75, 1.0]
        context.addPath(path)
        context.setLineWidth(cardW * 0.008)
        context.replacePathWithStrokedPath()
        context.clip()
        if let borderGrad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: borderColors, locations: borderLocations) {
            context.drawLinearGradient(borderGrad, start: CGPoint(x: cardRect.minX, y: cardRect.minY), end: CGPoint(x: cardRect.maxX, y: cardRect.maxY), options: [])
        }
        context.restoreGState()

        // 6. Photo slot
        let photoSlotW = cardW * 0.30
        let photoSlotH = photoSlotW * 1.25
        let photoSlotL = cardLeft + cardW * 0.04
        let photoSlotT = cardTop + cardH * 0.20
        let photoSlotRect = CGRect(x: photoSlotL, y: photoSlotT, width: photoSlotW, height: photoSlotH)
        let photoSlotRx = photoSlotW * 0.06

        // Draw photo slot background (#202228)
        context.saveGState()
        let slotBgPath = UIBezierPath(roundedRect: photoSlotRect, cornerRadius: photoSlotRx).cgPath
        context.setFillColor(UIColor(red: 32/255, green: 34/255, blue: 40/255, alpha: 1.0).cgColor)
        context.addPath(slotBgPath)
        context.fillPath()
        context.restoreGState()

        context.saveGState()
        context.addPath(slotBgPath)
        context.clip()
        
        // Draw cropped face
        if let face = face {
            let fBox = face.boundingBox
            let padW = fBox.width * 1.4
            let padH = padW * 1.25
            let srcRect = CGRect(x: fBox.midX - padW/2, y: fBox.midY - padH * 0.6, width: padW, height: padH)
            if let cropped = frame.cropping(to: srcRect) {
                drawCGImageCorrect(cropped, in: photoSlotRect, context: context)
            }
        } else {
            // Draw central portion of the camera frame if no face is detected
            let cropW = CGFloat(frame.width) * 0.5
            let cropH = cropW * 1.25
            let srcRect = CGRect(x: (CGFloat(frame.width) - cropW)/2.0, y: (CGFloat(frame.height) - cropH)/2.0, width: cropW, height: cropH)
            if let cropped = frame.cropping(to: srcRect) {
                drawCGImageCorrect(cropped, in: photoSlotRect, context: context)
            }
        }
        context.restoreGState()

        // 7. Holographic Photo Border
        context.saveGState()
        let photoBorderPath = UIBezierPath(roundedRect: photoSlotRect, cornerRadius: photoSlotRx).cgPath
        context.addPath(photoBorderPath)
        context.setLineWidth(photoSlotW * 0.024)
        context.replacePathWithStrokedPath()
        context.clip()
        if let borderGrad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: borderColors, locations: borderLocations) {
            context.drawLinearGradient(borderGrad, start: CGPoint(x: photoSlotRect.minX, y: photoSlotRect.minY), end: CGPoint(x: photoSlotRect.maxX, y: photoSlotRect.maxY), options: [])
        }
        context.restoreGState()

        // 8. Top Left Icon Box
        let iconBoxL = cardLeft + cardW * 0.04
        let iconBoxT = cardTop + cardH * 0.06
        let iconBoxSize = cardW * 0.09
        let iconBoxRect = CGRect(x: iconBoxL, y: iconBoxT, width: iconBoxSize, height: iconBoxSize)
        let iconBoxPath = UIBezierPath(roundedRect: iconBoxRect, cornerRadius: iconBoxSize * 0.2).cgPath
        
        context.saveGState()
        context.setFillColor(UIColor(red: 122/255, green: 140/255, blue: 208/255, alpha: 0.16).cgColor) // alpha 40/255
        context.addPath(iconBoxPath)
        context.fillPath()
        
        context.setStrokeColor(UIColor(red: 122/255, green: 140/255, blue: 208/255, alpha: 1.0).cgColor)
        context.setLineWidth(cardW * 0.003)
        context.addPath(iconBoxPath)
        context.strokePath()
        context.restoreGState()

        // Crown inside Left Box
        let crownCx = iconBoxL + iconBoxSize / 2.0
        let crownCy = iconBoxT + iconBoxSize * 0.55
        let crownW = iconBoxSize * 0.6
        let crownH = iconBoxSize * 0.4
        
        context.saveGState()
        let crownPath = CGMutablePath()
        crownPath.move(to: CGPoint(x: crownCx - crownW / 2.0, y: crownCy + crownH / 2.0))
        crownPath.addLine(to: CGPoint(x: crownCx - crownW / 2.0, y: crownCy - crownH * 0.2))
        crownPath.addLine(to: CGPoint(x: crownCx - crownW * 0.25, y: crownCy + crownH * 0.1))
        crownPath.addLine(to: CGPoint(x: crownCx, y: crownCy - crownH / 2.0))
        crownPath.addLine(to: CGPoint(x: crownCx + crownW * 0.25, y: crownCy + crownH * 0.1))
        crownPath.addLine(to: CGPoint(x: crownCx + crownW / 2.0, y: crownCy - crownH * 0.2))
        crownPath.addLine(to: CGPoint(x: crownCx + crownW / 2.0, y: crownCy + crownH / 2.0))
        crownPath.closeSubpath()
        context.setFillColor(UIColor(red: 92/255, green: 107/255, blue: 192/255, alpha: 1.0).cgColor)
        context.addPath(crownPath)
        context.fillPath()
        context.restoreGState()

        // 9. Top Right Level Info
        let trX = cardRect.maxX - cardW * 0.04
        drawFlippedText(context: context, text: "ID LEVEL", x: trX - cardW * 0.05, y: cardTop + cardH * 0.09, fontSize: cardW * 0.02, color: UIColor(red: 90/255, green: 107/255, blue: 140/255, alpha: 1), center: false, bold: true, rightAlign: true)
        drawFlippedText(context: context, text: "PLATINUM", x: trX - cardW * 0.05, y: cardTop + cardH * 0.14, fontSize: cardW * 0.03, color: UIColor(red: 92/255, green: 107/255, blue: 192/255, alpha: 1.0), center: false, bold: true, rightAlign: true)

        // Diamond inside Right Box
        let diamondCx = trX - cardW * 0.02
        let diamondCy = cardTop + cardH * 0.11
        let diaW = cardW * 0.04
        let diaH = diaW
        
        context.saveGState()
        let diaPath = CGMutablePath()
        diaPath.move(to: CGPoint(x: diamondCx, y: diamondCy - diaH / 2.0))
        diaPath.addLine(to: CGPoint(x: diamondCx + diaW / 2.0, y: diamondCy))
        diaPath.addLine(to: CGPoint(x: diamondCx, y: diamondCy + diaH / 2.0))
        diaPath.addLine(to: CGPoint(x: diamondCx - diaW / 2.0, y: diamondCy))
        diaPath.closeSubpath()
        context.setFillColor(UIColor(red: 92/255, green: 107/255, blue: 192/255, alpha: 1.0).cgColor)
        context.addPath(diaPath)
        context.fillPath()
        
        context.setStrokeColor(UIColor(red: 232/255, green: 234/255, blue: 246/255, alpha: 1.0).cgColor)
        context.setLineWidth(cardW * 0.003)
        context.move(to: CGPoint(x: diamondCx, y: diamondCy - diaH / 2.0))
        context.addLine(to: CGPoint(x: diamondCx, y: diamondCy + diaH / 2.0))
        context.strokePath()
        context.move(to: CGPoint(x: diamondCx - diaW / 2.0, y: diamondCy))
        context.addLine(to: CGPoint(x: diamondCx + diaW / 2.0, y: diamondCy))
        context.strokePath()
        context.restoreGState()

        // Text values
        let fieldsL = photoSlotL + photoSlotW + cardW * 0.04
        let rightAreaCx = fieldsL + (cardRect.maxX - cardW * 0.04 - fieldsL) / 2.0
        let startY = cardTop + cardH * 0.32
        let yGap = cardH * 0.18

        drawFlippedText(context: context, text: "LENS+ VERIFIED", x: w/2, y: cardTop + cardH * 0.12, fontSize: cardW * 0.052, color: UIColor(red: 10/255, green: 63/255, blue: 154/255, alpha: 1), center: true, bold: true)
        drawFlippedText(context: context, text: "USER IDENTITY CARD", x: w/2, y: cardTop + cardH * 0.17, fontSize: cardW * 0.024, color: UIColor(red: 90/255, green: 107/255, blue: 140/255, alpha: 1), center: true)

        // Delulu
        drawFlippedText(context: context, text: "DELULU LEVEL", x: rightAreaCx, y: startY - cardH * 0.035, fontSize: cardW * 0.024, color: UIColor(red: 90/255, green: 107/255, blue: 140/255, alpha: 1), center: true)
        drawFlippedText(context: context, text: ": \(cardDeluluLevel)", x: rightAreaCx, y: startY + cardH * 0.035, fontSize: cardW * 0.045, color: UIColor(red: 216/255, green: 27/255, blue: 96/255, alpha: 1), center: true, bold: true)

        // Sleep
        drawFlippedText(context: context, text: "SLEEP HOURS", x: rightAreaCx, y: startY + yGap - cardH * 0.035, fontSize: cardW * 0.024, color: UIColor(red: 90/255, green: 107/255, blue: 140/255, alpha: 1), center: true)
        drawFlippedText(context: context, text: ": \(cardSleepHours)", x: rightAreaCx, y: startY + yGap + cardH * 0.035, fontSize: cardW * 0.045, color: UIColor(red: 10/255, green: 63/255, blue: 154/255, alpha: 1), center: true, bold: true)

        // Attention
        drawFlippedText(context: context, text: "ATTENTION RATE", x: rightAreaCx, y: startY + 2 * yGap - cardH * 0.035, fontSize: cardW * 0.024, color: UIColor(red: 90/255, green: 107/255, blue: 140/255, alpha: 1), center: true)
        drawFlippedText(context: context, text: ": \(cardAttentionRate)", x: rightAreaCx, y: startY + 2 * yGap + cardH * 0.035, fontSize: cardW * 0.045, color: UIColor(red: 10/255, green: 63/255, blue: 154/255, alpha: 1), center: true, bold: true)

        // Citizen banner
        drawFlippedText(context: context, text: "OFFICIAL LENS+ CITIZEN", x: w/2, y: cardTop + cardH * 0.91, fontSize: cardW * 0.028, color: UIColor(red: 10/255, green: 63/255, blue: 154/255, alpha: 1), center: true, bold: true)
    }

    // MARK: - Creator HUD

    private func drawCreatorHud(context: CGContext, size: CGSize) {
        let w = size.width
        let h = size.height

        // 1. Soft pastel peach/cream vignette overlay for that dreamy, aesthetic glow
        context.saveGState()
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let colors = [
            UIColor(red: 255/255, green: 235/255, blue: 215/255, alpha: 0.102).cgColor,
            UIColor(red: 255/255, green: 220/255, blue: 200/255, alpha: 0.055).cgColor,
            UIColor(red: 235/255, green: 205/255, blue: 185/255, alpha: 0.157).cgColor
        ] as CFArray
        let locations: [CGFloat] = [0.0, 0.55, 1.0]
        if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: locations) {
            let center = CGPoint(x: w / 2.0, y: h * 0.4)
            let radius = max(w, h) * 0.85
            context.drawRadialGradient(gradient, startCenter: center, startRadius: 0, endCenter: center, endRadius: radius, options: .drawsAfterEndLocation)
        }
        context.restoreGState()

        // 2. Draw black mask outside of this rounded rectangle to frame the viewport
        let leftMargin = w * 0.04
        let rightMargin = w * 0.04
        let topMargin = h * 0.09
        let bottomMargin = h * 0.16
        let viewportRect = CGRect(x: leftMargin, y: topMargin, width: w - leftMargin - rightMargin, height: h - topMargin - bottomMargin)
        let cornerRadius = w * 0.08

        context.saveGState()
        let path = CGMutablePath()
        path.addRect(CGRect(x: 0, y: 0, width: w, height: h))
        path.addPath(UIBezierPath(roundedRect: viewportRect, cornerRadius: cornerRadius).cgPath)
        context.setFillColor(UIColor.black.cgColor)
        context.addPath(path)
        context.fillPath(using: .evenOdd)
        context.restoreGState()

        // 3. Draw Icons & HUD elements
        let r = w * 0.024
        let strokeWidth = w * 0.006

        // Left sidebar coordinate (relative to screen right in mirrored view)
        let hudLeftX = w * 0.93

        // Heart Icon
        let heartY = h * 0.15
        drawFlippedIcon(context: context, x: hudLeftX, y: heartY) {
            let heart = CGMutablePath()
            heart.move(to: CGPoint(x: 0, y: -r * 0.3))
            heart.addCurve(to: CGPoint(x: 0, y: r * 0.8),
                           control1: CGPoint(x: -r * 0.6, y: -r * 0.9),
                           control2: CGPoint(x: -r * 1.2, y: -r * 0.2))
            heart.addCurve(to: CGPoint(x: 0, y: -r * 0.3),
                           control1: CGPoint(x: r * 1.2, y: -r * 0.2),
                           control2: CGPoint(x: r * 0.6, y: -r * 0.9))
            heart.closeSubpath()
            context.setStrokeColor(UIColor.white.cgColor)
            context.setLineWidth(strokeWidth)
            context.addPath(heart)
            context.strokePath()
        }

        // Share Icon
        let shareY = h * 0.23
        drawFlippedIcon(context: context, x: hudLeftX, y: shareY) {
            let arrow = CGMutablePath()
            arrow.move(to: CGPoint(x: -r * 0.5, y: r * 0.3))
            arrow.addQuadCurve(to: CGPoint(x: r * 0.3, y: -r * 0.2), control: .zero)
            // Arrow head pointing right
            arrow.move(to: CGPoint(x: r * 0.1, y: -r * 0.5))
            arrow.addLine(to: CGPoint(x: r * 0.5, y: -r * 0.2))
            arrow.addLine(to: CGPoint(x: r * 0.1, y: r * 0.1))
            context.setStrokeColor(UIColor.white.cgColor)
            context.setLineWidth(strokeWidth)
            context.addPath(arrow)
            context.strokePath()
        }

        // Eye Icon
        let eyeY = h * 0.31
        drawFlippedIcon(context: context, x: hudLeftX, y: eyeY) {
            let eye = CGMutablePath()
            eye.move(to: CGPoint(x: -r * 0.8, y: 0))
            eye.addQuadCurve(to: CGPoint(x: r * 0.8, y: 0), control: CGPoint(x: 0, y: -r * 0.5))
            eye.addQuadCurve(to: CGPoint(x: -r * 0.8, y: 0), control: CGPoint(x: 0, y: r * 0.5))
            eye.closeSubpath()
            context.setStrokeColor(UIColor.white.cgColor)
            context.setLineWidth(strokeWidth)
            context.addPath(eye)
            context.strokePath()
            
            context.setFillColor(UIColor.white.cgColor)
            context.fillEllipse(in: CGRect(x: -r * 0.25, y: -r * 0.25, width: r * 0.5, height: r * 0.5))
        }

        // Viewer count
        drawFlippedText(context: context, text: creatorViewerCount, x: hudLeftX, y: eyeY + r * 1.4, fontSize: w * 0.026, color: .white, center: true, bold: true)

        // Right sidebar coordinates (relative to screen left in mirrored view)
        let hudRightX = w * 0.07

        // Music Note Icon
        let musicY = h * 0.15
        drawFlippedIcon(context: context, x: hudRightX, y: musicY) {
            let musicPath = CGMutablePath()
            musicPath.move(to: CGPoint(x: -r * 0.2, y: r * 0.4))
            musicPath.addLine(to: CGPoint(x: -r * 0.2, y: -r * 0.6))
            musicPath.addLine(to: CGPoint(x: r * 0.4, y: -r * 0.4))
            musicPath.addLine(to: CGPoint(x: r * 0.4, y: r * 0.6))
            
            musicPath.move(to: CGPoint(x: -r * 0.2, y: -r * 0.6))
            musicPath.addLine(to: CGPoint(x: r * 0.4, y: -r * 0.4))
            
            context.setStrokeColor(UIColor.white.cgColor)
            context.setLineWidth(strokeWidth)
            context.addPath(musicPath)
            context.strokePath()
            
            context.setFillColor(UIColor.white.cgColor)
            context.fillEllipse(in: CGRect(x: -r * 0.4, y: r * 0.2, width: r * 0.4, height: r * 0.4))
            context.fillEllipse(in: CGRect(x: r * 0.2, y: r * 0.4, width: r * 0.4, height: r * 0.4))
        }

        // Dropdown Arrow
        let dropY = h * 0.23
        drawFlippedIcon(context: context, x: hudRightX, y: dropY) {
            let dropPath = CGMutablePath()
            dropPath.move(to: CGPoint(x: -r * 0.4, y: -r * 0.2))
            dropPath.addLine(to: CGPoint(x: 0, y: r * 0.2))
            dropPath.addLine(to: CGPoint(x: r * 0.4, y: -r * 0.2))
            
            context.setStrokeColor(UIColor.white.cgColor)
            context.setLineWidth(strokeWidth)
            context.addPath(dropPath)
            context.strokePath()
        }

        // Music Banner Pill
        let bannerCx = w / 2.0
        let bannerY = h * 0.045
        let bannerW = w * 0.48
        let bannerH = h * 0.038

        context.setFillColor(UIColor.black.withAlphaComponent(0.4).cgColor)
        context.fill(CGRect(x: bannerCx - bannerW/2, y: bannerY, width: bannerW, height: bannerH))

        drawFlippedText(context: context, text: "Noor E Khuda (L...", x: bannerCx - bannerW/2 + bannerH * 0.6, y: bannerY + bannerH * 0.62, fontSize: bannerH * 0.38, color: .white, center: false, bold: true)
    }

    private func drawFlippedIcon(context: CGContext, x: CGFloat, y: CGFloat, action: () -> Void) {
        context.saveGState()
        context.translateBy(x: x, y: y)
        context.scaleBy(x: 1.0, y: 1.0)
        action()
        context.restoreGState()
    }

    // MARK: - Core Graphics Helpers

    private func makeNoiseImage() -> CGImage? {
        var pixels = [UInt8](repeating: 0, count: 64 * 64 * 4)
        for i in 0..<(64 * 64) {
            let v = UInt8.random(in: 0...255)
            let idx = i * 4
            pixels[idx] = v
            pixels[idx+1] = v
            pixels[idx+2] = v
            pixels[idx+3] = 255
        }
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        guard let context = CGContext(data: &pixels,
                                      width: 64,
                                      height: 64,
                                      bitsPerComponent: 8,
                                      bytesPerRow: 64 * 4,
                                      space: colorSpace,
                                      bitmapInfo: bitmapInfo) else {
            return nil
        }
        return context.makeImage()
    }

    private func drawFilmGrain(context: CGContext, bounds: CGRect, alpha: CGFloat) {
        guard let noiseImg = self.noiseImage else { return }
        context.saveGState()
        context.setBlendMode(.screen)
        context.setAlpha(alpha)
        context.clip(to: bounds)
        context.draw(noiseImg, in: CGRect(x: bounds.origin.x, y: bounds.origin.y, width: 64, height: 64), byTiling: true)
        context.restoreGState()
    }

    private func drawVignette(context: CGContext, rect: CGRect) {
        context.saveGState()
        let colors = [CGColor(red: 0, green: 0, blue: 0, alpha: 0),
                      CGColor(red: 0, green: 0, blue: 0, alpha: 0),
                      CGColor(red: 0, green: 0, blue: 0, alpha: 0.66)] as CFArray
        let locations: [CGFloat] = [0.0, 0.55, 1.0]
        guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: locations) else {
            context.restoreGState()
            return
        }
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = max(rect.width, rect.height) * 0.75
        context.drawRadialGradient(gradient, startCenter: center, startRadius: 0, endCenter: center, endRadius: radius, options: .drawsAfterEndLocation)
        context.restoreGState()
    }

    private func drawCGImageCorrect(_ image: CGImage, in rect: CGRect, context: CGContext) {
        context.saveGState()
        context.translateBy(x: 0, y: rect.origin.y + rect.size.height)
        context.scaleBy(x: 1.0, y: -1.0)
        let drawRect = CGRect(x: rect.origin.x, y: 0, width: rect.size.width, height: rect.size.height)
        context.draw(image, in: drawRect)
        context.restoreGState()
    }

    private func drawCartoonEdges(context: CGContext, finalCG: CGImage, size: CGSize) {
        let sw = Int(size.width) / 4
        let sh = Int(size.height) / 4
        guard sw > 0 && sh > 0 else { return }
        
        let totalPixels = sw * sh
        var lumaArr = [UInt8](repeating: 0, count: totalPixels)
        
        let grayColorSpace = CGColorSpaceCreateDeviceGray()
        guard let grayContext = CGContext(data: &lumaArr,
                                          width: sw,
                                          height: sh,
                                          bitsPerComponent: 8,
                                          bytesPerRow: sw,
                                          space: grayColorSpace,
                                          bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return }
        
        // Draw into grayscale downscaled context
        grayContext.draw(finalCG, in: CGRect(x: 0, y: 0, width: sw, height: sh))
        
        var edgeData = [UInt8](repeating: 0, count: sw * sh * 4)
        
        let threshold = 18
        let alphaMax = 220
        
        for y in 1..<(sh - 1) {
            let row = y * sw
            for x in 1..<(sw - 1) {
                let idx00 = row - sw + x - 1
                let idx01 = row - sw + x
                let idx02 = row - sw + x + 1
                let idx10 = row + x - 1
                let idx12 = row + x + 1
                let idx20 = row + sw + x - 1
                let idx21 = row + sw + x
                let idx22 = row + sw + x + 1
                
                let gx = -Int(lumaArr[idx00]) - 2 * Int(lumaArr[idx10]) - Int(lumaArr[idx20])
                       + Int(lumaArr[idx02]) + 2 * Int(lumaArr[idx12]) + Int(lumaArr[idx22])
                       
                let gy = -Int(lumaArr[idx00]) - 2 * Int(lumaArr[idx01]) - Int(lumaArr[idx02])
                       + Int(lumaArr[idx20]) + 2 * Int(lumaArr[idx21]) + Int(lumaArr[idx22])
                       
                let mag = (abs(gx) + abs(gy)) / 2
                
                if mag > threshold {
                    let alpha = (mag - threshold) * alphaMax / (255 - threshold)
                    let finalAlpha = UInt8(max(0, min(alphaMax, alpha)))
                    
                    let offset = (row + x) * 4
                    edgeData[offset + 3] = finalAlpha
                }
            }
        }
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        if let provider = CGDataProvider(data: Data(edgeData) as CFData),
           let edgeCG = CGImage(width: sw,
                                height: sh,
                                bitsPerComponent: 8,
                                bitsPerPixel: 32,
                                bytesPerRow: sw * 4,
                                space: colorSpace,
                                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                                provider: provider,
                                decode: nil,
                                shouldInterpolate: true,
                                intent: .defaultIntent) {
            context.saveGState()
            context.setShouldAntialias(true)
            context.interpolationQuality = .low // Bilinear upscale
            drawCGImageCorrect(edgeCG, in: CGRect(x: 0, y: 0, width: size.width, height: size.height), context: context)
            context.restoreGState()
        }
    }

    private func drawFlippedText(context: CGContext, text: String, x: CGFloat, y: CGFloat, fontSize: CGFloat, color: UIColor, center: Bool, bold: Bool = false, rightAlign: Bool = false) {
        context.saveGState()
        context.translateBy(x: x, y: y)
        context.scaleBy(x: 1.0, y: 1.0)

        let font = bold ? UIFont.boldSystemFont(ofSize: fontSize) : UIFont.systemFont(ofSize: fontSize)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color
        ]
        
        let size = text.size(withAttributes: attributes)
        let drawPt: CGPoint
        if center {
            drawPt = CGPoint(x: -size.width / 2.0, y: -size.height / 2.0)
        } else if rightAlign {
            drawPt = CGPoint(x: -size.width, y: -size.height / 2.0)
        } else {
            drawPt = CGPoint(x: 0, y: -size.height / 2.0)
        }
        text.draw(at: drawPt, withAttributes: attributes)

        context.restoreGState()
    }
}

// MARK: - Utilities

extension Comparable {
    func clamped(_ f: Self, _ t: Self) -> Self {
        return min(max(self, f), t)
    }
}
