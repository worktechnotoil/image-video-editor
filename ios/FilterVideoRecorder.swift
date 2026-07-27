import Foundation
import AVFoundation
import CoreImage
import UIKit

class FilterVideoRecorder {
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    
    private var isRecording = false
    private var hasStartedSession = false
    private let renderQueue = DispatchQueue(label: "com.filtercam.recorder")
    
    private let outputFileUrl: URL
    
    init?(outputFile: String, width: Int, height: Int) {
        self.outputFileUrl = URL(fileURLWithPath: outputFile)
        
        do {
            if FileManager.default.fileExists(atPath: outputFileUrl.path) {
                try FileManager.default.removeItem(at: outputFileUrl)
            }
            assetWriter = try AVAssetWriter(outputURL: outputFileUrl, fileType: .mp4)
            
            let videoSettings: [String: Any] = [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: width,
                AVVideoHeightKey: height
            ]
            
            videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
            videoInput?.expectsMediaDataInRealTime = true
            
            if let vi = videoInput, assetWriter?.canAdd(vi) == true {
                assetWriter?.add(vi)
            }
            
            let sourcePixelBufferAttributes: [String: Any] = [
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
                kCVPixelBufferWidthKey as String: width,
                kCVPixelBufferHeightKey as String: height
            ]
            
            pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
                assetWriterInput: videoInput!,
                sourcePixelBufferAttributes: sourcePixelBufferAttributes
            )
            
            var audioChannelLayout = AudioChannelLayout()
            audioChannelLayout.mChannelLayoutTag = kAudioChannelLayoutTag_Mono
            let audioLayoutData = Data(bytes: &audioChannelLayout, count: MemoryLayout.size(ofValue: audioChannelLayout))
            
            let audioSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 1,
                AVEncoderBitRateKey: 128000,
                AVChannelLayoutKey: audioLayoutData
            ]
            
            audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
            audioInput?.expectsMediaDataInRealTime = true
            if let ai = audioInput, assetWriter?.canAdd(ai) == true {
                assetWriter?.add(ai)
            }
            
        } catch {
            print("Failed to setup AVAssetWriter: \(error)")
            return nil
        }
    }
    
    func start() {
        renderQueue.async {
            self.assetWriter?.startWriting()
            self.isRecording = true
            self.hasStartedSession = false
        }
    }
    
    func appendVideo(cgImage: CGImage, time: CMTime) {
        renderQueue.async {
            guard self.isRecording, let writer = self.assetWriter, let input = self.videoInput, let adaptor = self.pixelBufferAdaptor else { return }
            
            if !self.hasStartedSession {
                writer.startSession(atSourceTime: time)
                self.hasStartedSession = true
            }
            
            if input.isReadyForMoreMediaData {
                var pixelBufferOut: CVPixelBuffer?
                CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool!, &pixelBufferOut)
                
                guard let pixelBuffer = pixelBufferOut else { return }
                
                CVPixelBufferLockBaseAddress(pixelBuffer, [])
                let data = CVPixelBufferGetBaseAddress(pixelBuffer)
                let colorSpace = CGColorSpaceCreateDeviceRGB()
                
                let width = cgImage.width
                let height = cgImage.height
                
                let context = CGContext(
                    data: data,
                    width: width,
                    height: height,
                    bitsPerComponent: 8,
                    bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
                    space: colorSpace,
                    bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
                )
                
                context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))
                CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
                
                adaptor.append(pixelBuffer, withPresentationTime: time)
            }
        }
    }
    
    func appendAudio(sampleBuffer: CMSampleBuffer) {
        renderQueue.async {
            guard self.isRecording, let writer = self.assetWriter, let input = self.audioInput else { return }
            
            if self.hasStartedSession && input.isReadyForMoreMediaData {
                input.append(sampleBuffer)
            }
        }
    }
    
    func stop(completion: @escaping (String?) -> Void) {
        renderQueue.async {
            self.isRecording = false
            self.videoInput?.markAsFinished()
            self.audioInput?.markAsFinished()
            
            self.assetWriter?.finishWriting {
                DispatchQueue.main.async {
                    if self.assetWriter?.status == .completed {
                        completion(self.outputFileUrl.path)
                    } else {
                        completion(nil)
                    }
                }
            }
        }
    }
}
