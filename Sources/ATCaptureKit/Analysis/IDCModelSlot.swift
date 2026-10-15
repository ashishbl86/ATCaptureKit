import Foundation

final class IDCModelSlot: @unchecked Sendable {
    private let stateLock = NSLock()
    private let runLock = NSLock()
    private var model: IDCLoadedModel?

    init(_ model: IDCModel, runner: IDCModelRunner?) {
        guard let runner, let url = model.url else { return }
        nonisolated(unsafe) let loader = runner
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            guard let loaded = try? loader.loadModel(at: url) else { return }
            stateLock.lock()
            self.model = loaded
            stateLock.unlock()
        }
    }

    var isReady: Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return model != nil
    }

    func run(_ input: Data) throws -> IDCTensor {
        stateLock.lock()
        let model = self.model
        stateLock.unlock()
        guard let model else { throw IDCAnalysisError.modelNotReady }
        runLock.lock()
        defer { runLock.unlock() }
        return try model.run(input)
    }
}
