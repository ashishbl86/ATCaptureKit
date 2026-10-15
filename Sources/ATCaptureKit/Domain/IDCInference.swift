import Foundation

public enum IDCModel: String, CaseIterable, Sendable {
    case passportDetector = "passport_multi_class_detection"
    case glareClassifier = "glare_model_fp16"
    case selfieClassifier = "selfie_model"

    public var url: URL? {
        Bundle.module.url(forResource: rawValue, withExtension: "tflite")
    }
}

public struct IDCTensor: Sendable {
    public let data: Data
    public let shape: [Int]

    public init(data: Data, shape: [Int]) {
        self.data = data
        self.shape = shape
    }
}

public protocol IDCModelRunner: AnyObject {
    func loadModel(at url: URL) throws -> IDCLoadedModel
}

public protocol IDCLoadedModel: AnyObject {
    func run(_ input: Data) throws -> IDCTensor
}

public enum IDCInference {
    @MainActor public static var runner: IDCModelRunner?
}
