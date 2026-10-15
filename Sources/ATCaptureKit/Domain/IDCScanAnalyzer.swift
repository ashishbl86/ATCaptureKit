import AVFoundation
import SwiftUI
import UIKit

// MARK: - Frames

struct IDCCameraFrame {
    let sampleBuffer: CMSampleBuffer
    let isFrontCamera: Bool
    let viewfinderSize: CGSize

    var pixelBuffer: CVPixelBuffer? { CMSampleBufferGetImageBuffer(sampleBuffer) }
}

// MARK: - Results

public struct IDCFieldDetections: Sendable {
    public let photo: CGRect?
    public let signature: CGRect?
    public let mrz: CGRect?

    public init(photo: CGRect? = nil, signature: CGRect? = nil, mrz: CGRect? = nil) {
        self.photo = photo
        self.signature = signature
        self.mrz = mrz
    }

    var hasAny: Bool { photo != nil || signature != nil || mrz != nil }
}

struct IDCPassportDetection: Sendable {
    let bounds: CGRect
    let isMRZVisible: Bool
    let isTravelDocument: Bool
    let hasFingers: Bool
    let hasGlare: Bool
    let fieldDetections: IDCFieldDetections?
}

enum IDCPassportAnalysis: Sendable {
    case failed
    case noPassport(wrongPageInFrame: Bool)
    case passport(IDCPassportDetection)
}

struct IDCFrameQuality: Sendable {
    let brightness: Float
    let sharpness: Float
}

struct IDCSelfieAnalysis: Sendable {
    let guidance: IDCSelfieGuidance
    let sharpness: Float
    let faceRects: [CGRect]
}

enum IDCSelfiePhotoAnalysis: Sendable {
    case document
    case analyzed(IDCSelfieGuidance)
}

enum IDCPassportGuidance {
    case searching
    case moveCloser
    case tooClose
    case outOfBox
    case fingers
    case glare
    case lightReflection
    case travelDoc
    case wrongPage
    case holdStill
}

// MARK: - Analyzers

protocol IDCPassportAnalyzer: AnyObject {
    @MainActor func prepare()
    nonisolated func analyzeFrame(_ frame: IDCCameraFrame, isForBackPage: Bool) -> IDCPassportAnalysis?
    nonisolated func frameQuality(_ frame: IDCCameraFrame) -> IDCFrameQuality
    @MainActor func analyzePhoto(_ image: UIImage, isForBackPage: Bool) async -> IDCPassportAnalysis?
}

protocol IDCSelfieAnalyzer: AnyObject {
    @MainActor func prepare()
    @MainActor func liveAnalysisWillStart()
    @MainActor func liveAnalysisDidStop()
    nonisolated func analyzeFrame(_ frame: IDCCameraFrame) -> IDCSelfieAnalysis?
    @MainActor func analyzePhoto(_ image: UIImage) async -> IDCSelfiePhotoAnalysis?
}

@MainActor
protocol IDCAnalyzerProvider {
    func makePassportAnalyzer() -> IDCPassportAnalyzer
    func makeSelfieAnalyzer() -> IDCSelfieAnalyzer
}

@MainActor
final class IDCAnalyzerHolder<Analyzer>: ObservableObject {
    let analyzer: Analyzer
    init(_ analyzer: Analyzer) { self.analyzer = analyzer }
}
