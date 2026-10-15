import UIKit

@MainActor
struct IDCNoopAnalyzerProvider: IDCAnalyzerProvider {
    func makePassportAnalyzer() -> IDCPassportAnalyzer { IDCNoopPassportAnalyzer() }
    func makeSelfieAnalyzer() -> IDCSelfieAnalyzer { IDCNoopSelfieAnalyzer() }
}

private final class IDCNoopPassportAnalyzer: IDCPassportAnalyzer {
    func prepare() {}
    nonisolated func analyzeFrame(_ frame: IDCCameraFrame, isForBackPage: Bool) -> IDCPassportAnalysis? { nil }
    nonisolated func frameQuality(_ frame: IDCCameraFrame) -> IDCFrameQuality { IDCFrameQuality(brightness: 0, sharpness: 0) }
    func analyzePhoto(_ image: UIImage, isForBackPage: Bool) async -> IDCPassportAnalysis? { nil }
}

private final class IDCNoopSelfieAnalyzer: IDCSelfieAnalyzer {
    func prepare() {}
    func liveAnalysisWillStart() {}
    func liveAnalysisDidStop() {}
    nonisolated func analyzeFrame(_ frame: IDCCameraFrame) -> IDCSelfieAnalysis? { nil }
    func analyzePhoto(_ image: UIImage) async -> IDCSelfiePhotoAnalysis? { nil }
}
