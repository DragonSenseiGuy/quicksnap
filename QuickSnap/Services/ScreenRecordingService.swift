import Foundation
import ScreenCaptureKit
import AVFoundation
import AppKit

enum ScreenRecordingError: LocalizedError {
    case noDisplaysAvailable
    case permissionDenied
    case streamSetupFailed
    case writerSetupFailed
    case recordingNotStarted
    case encodingFailed
    
    var errorDescription: String? {
        switch self {
        case .noDisplaysAvailable:
            return "No displays available for recording"
        case .permissionDenied:
            return "Screen recording permission denied"
        case .streamSetupFailed:
            return "Failed to set up screen capture stream"
        case .writerSetupFailed:
            return "Failed to set up video writer"
        case .recordingNotStarted:
            return "No recording in progress"
        case .encodingFailed:
            return "Failed to encode video"
        }
    }
}

@MainActor
class ScreenRecordingService: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var currentRecordingURL: URL?
    
    private var stream: SCStream?
    private var streamOutput: RecordingStreamOutput?
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?
    private var recordingTimer: Timer?
    private var startTime: Date?
    
    private let settings = AppSettings.shared
    
    func startRecordingFullScreen(includeAudio: Bool = false) async throws {
        let displays = try await availableDisplays()
        guard let display = displays.first else {
            throw ScreenRecordingError.noDisplaysAvailable
        }
        
        try await setupStream(for: display, cropRect: nil, includeAudio: includeAudio)
        try await startStream()
    }
    
    func startRecordingRegion(_ rect: CGRect, includeAudio: Bool = false) async throws {
        let displays = try await availableDisplays()
        guard let display = displays.first else {
            throw ScreenRecordingError.noDisplaysAvailable
        }
        
        try await setupStream(for: display, cropRect: rect, includeAudio: includeAudio)
        try await startStream()
    }
    
    func stopRecording() async throws -> URL {
        guard isRecording, let stream = stream else {
            throw ScreenRecordingError.recordingNotStarted
        }
        
        try await stream.stopCapture()
        
        recordingTimer?.invalidate()
        recordingTimer = nil
        
        await finishWriting()
        
        self.stream = nil
        self.streamOutput = nil
        isRecording = false
        
        guard let url = currentRecordingURL else {
            throw ScreenRecordingError.recordingNotStarted
        }
        
        return url
    }
    
    func cancelRecording() {
        Task {
            if let stream = stream {
                try? await stream.stopCapture()
            }
            
            recordingTimer?.invalidate()
            recordingTimer = nil
            
            assetWriter?.cancelWriting()
            
            if let url = currentRecordingURL {
                try? FileManager.default.removeItem(at: url)
            }
            
            stream = nil
            streamOutput = nil
            assetWriter = nil
            videoInput = nil
            audioInput = nil
            currentRecordingURL = nil
            isRecording = false
            recordingDuration = 0
        }
    }
    
    func availableDisplays() async throws -> [SCDisplay] {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            return content.displays
        } catch {
            throw ScreenRecordingError.permissionDenied
        }
    }
    
    private func setupStream(for display: SCDisplay, cropRect: CGRect?, includeAudio: Bool) async throws {
        let filter = SCContentFilter(display: display, excludingWindows: [])
        
        let configuration = SCStreamConfiguration()
        
        if let cropRect = cropRect {
            configuration.sourceRect = cropRect
            configuration.width = Int(cropRect.width) * 2
            configuration.height = Int(cropRect.height) * 2
        } else {
            configuration.width = display.width * 2
            configuration.height = display.height * 2
        }
        
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: 60)
        configuration.pixelFormat = kCVPixelFormatType_32BGRA
        configuration.showsCursor = true
        configuration.queueDepth = 5
        
        if includeAudio {
            configuration.capturesAudio = true
            configuration.sampleRate = 48000
            configuration.channelCount = 2
        }
        
        let outputURL = try createAssetWriter(
            width: cropRect.map { Int($0.width) * 2 } ?? display.width * 2,
            height: cropRect.map { Int($0.height) * 2 } ?? display.height * 2,
            includeAudio: includeAudio
        )
        currentRecordingURL = outputURL
        
        stream = SCStream(filter: filter, configuration: configuration, delegate: nil)
        
        streamOutput = RecordingStreamOutput()
        streamOutput?.assetWriter = assetWriter
        streamOutput?.videoInput = videoInput
        streamOutput?.adaptor = pixelBufferAdaptor
        streamOutput?.audioInput = audioInput
        
        guard let stream = stream, let streamOutput = streamOutput else {
            throw ScreenRecordingError.streamSetupFailed
        }
        
        try stream.addStreamOutput(streamOutput, type: .screen, sampleHandlerQueue: DispatchQueue(label: "com.quicksnap.videoQueue"))
        
        if includeAudio {
            try stream.addStreamOutput(streamOutput, type: .audio, sampleHandlerQueue: DispatchQueue(label: "com.quicksnap.audioQueue"))
        }
    }
    
    private func startStream() async throws {
        guard let stream = stream else {
            throw ScreenRecordingError.streamSetupFailed
        }
        
        try await stream.startCapture()
        
        isRecording = true
        startTime = Date()
        recordingDuration = 0
        
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, let startTime = self.startTime else { return }
                self.recordingDuration = Date().timeIntervalSince(startTime)
            }
        }
    }
    
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    
    private func createAssetWriter(width: Int, height: Int, includeAudio: Bool) throws -> URL {
        let fileManager = FileManager.default
        let saveLocation = settings.defaultSaveLocation
        
        if !fileManager.fileExists(atPath: saveLocation.path) {
            try fileManager.createDirectory(at: saveLocation, withIntermediateDirectories: true)
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        let timestamp = dateFormatter.string(from: Date())
        
        let videoFormat = settings.videoFormat
        let filename = "Recording \(timestamp).\(videoFormat.fileExtension)"
        let outputURL = saveLocation.appendingPathComponent(filename)
        
        let fileType: AVFileType = videoFormat == .mp4 ? .mp4 : .mov
        
        assetWriter = try AVAssetWriter(outputURL: outputURL, fileType: fileType)
        
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 10_000_000,
                AVVideoExpectedSourceFrameRateKey: 60,
                AVVideoMaxKeyFrameIntervalKey: 60
            ]
        ]
        
        videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput?.expectsMediaDataInRealTime = true
        
        let sourcePixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height
        ]
        
        pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoInput!,
            sourcePixelBufferAttributes: sourcePixelBufferAttributes
        )
        
        if let videoInput = videoInput, assetWriter?.canAdd(videoInput) == true {
            assetWriter?.add(videoInput)
        }
        
        if includeAudio {
            let audioSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 48000,
                AVNumberOfChannelsKey: 2,
                AVEncoderBitRateKey: 128000
            ]
            
            audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
            audioInput?.expectsMediaDataInRealTime = true
            
            if let audioInput = audioInput, assetWriter?.canAdd(audioInput) == true {
                assetWriter?.add(audioInput)
            }
        }
        
        assetWriter?.startWriting()
        
        return outputURL
    }
    
    private func finishWriting() async {
        videoInput?.markAsFinished()
        audioInput?.markAsFinished()
        
        await withCheckedContinuation { continuation in
            assetWriter?.finishWriting {
                continuation.resume()
            }
        }
        
        assetWriter = nil
        videoInput = nil
        audioInput = nil
    }
}

class RecordingStreamOutput: NSObject, SCStreamOutput {
    var assetWriter: AVAssetWriter?
    var videoInput: AVAssetWriterInput?
    var adaptor: AVAssetWriterInputPixelBufferAdaptor?
    var audioInput: AVAssetWriterInput?
    var isFirstSample = true
    private let queue = DispatchQueue(label: "com.quicksnap.streamOutput")
    
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard sampleBuffer.isValid else { return }
        guard let assetWriter = assetWriter else { return }
        guard assetWriter.status == .writing || isFirstSample else { return }
        
        queue.sync {
            if isFirstSample && type == .screen {
                let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                assetWriter.startSession(atSourceTime: presentationTime)
                isFirstSample = false
            }
            
            guard !isFirstSample else { return }
            
            switch type {
            case .screen:
                guard let videoInput = videoInput, videoInput.isReadyForMoreMediaData else { return }
                if let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
                    let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                    adaptor?.append(imageBuffer, withPresentationTime: presentationTime)
                }
                
            case .audio:
                guard let audioInput = audioInput, audioInput.isReadyForMoreMediaData else { return }
                audioInput.append(sampleBuffer)
                
            case .microphone:
                break
                
            @unknown default:
                break
            }
        }
    }
}
