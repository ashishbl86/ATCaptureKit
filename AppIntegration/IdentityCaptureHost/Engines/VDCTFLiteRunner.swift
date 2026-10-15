import ATCaptureKit
import TensorFlowLite

final class VDCTFLiteRunner: IDCModelRunner {

    @MainActor
    static func install() {
        IDCInference.runner = VDCTFLiteRunner()
    }

    func loadModel(at url: URL) throws -> IDCLoadedModel {
        try VDCTFLiteModel(url: url)
    }
}

private final class VDCTFLiteModel: IDCLoadedModel {
    private let interpreter: Interpreter

    init(url: URL) throws {
        var options = Interpreter.Options()
        options.threadCount = 1
        interpreter = try Interpreter(modelPath: url.path, options: options)
        try interpreter.allocateTensors()
    }

    func run(_ input: Data) throws -> IDCTensor {
        try interpreter.copy(input, toInputAt: 0)
        try interpreter.invoke()
        let output = try interpreter.output(at: 0)
        return IDCTensor(data: output.data, shape: output.shape.dimensions)
    }
}

extension IDCPassportChecks {
    init(_ settings: PassportOcrSettings?) {
        self.init(glare: !(settings?.skipGlare ?? false), fingers: !(settings?.skipFingers ?? false))
    }
}

extension IDCSelfieChecks {
    init(_ settings: SelfieCaptureSettings) {
        self.init(
            closedEyes: settings.checkClosedEyes,
            coveredFace: settings.checkCoveredFace,
            glasses: settings.checkGlasses,
            faceInCenter: settings.checkFaceInCenter,
            faceStraight: settings.checkFaceStraight,
            smile: settings.checkSmile,
            tooClose: settings.checkTooClose
        )
    }
}

extension PassportFieldDetections {
    init(_ detections: IDCFieldDetections) {
        photo = detections.photo
        signature = detections.signature
        mrz = detections.mrz
    }
}
