import ATCaptureKit
import UIKit

final class ApplicationCapturePassportHostViewController: UIViewController {

    private let context: ApplicationCaptureContext
    private let pieces: [IDCPiece]
    private let copy: [IDCPiece: IDCCaptureCopy]
    private let onCapturedImage: ApplicationCaptureLauncher.CapturedImageHandler?
    private let storePassport: ApplicationCaptureLauncher.StorePassportHandler
    private let onFlowComplete: () -> Void
    private let onFlowExit: (() -> Void)?
    private var didStartCapture = false

    init(
        context: ApplicationCaptureContext,
        pieces: [IDCPiece],
        copy: [IDCPiece: IDCCaptureCopy] = [:],
        onCapturedImage: ApplicationCaptureLauncher.CapturedImageHandler? = nil,
        storePassport: @escaping ApplicationCaptureLauncher.StorePassportHandler,
        onFlowComplete: @escaping () -> Void,
        onFlowExit: (() -> Void)? = nil
    ) {
        self.context = context
        self.pieces = pieces
        self.copy = copy
        self.onCapturedImage = onCapturedImage
        self.storePassport = storePassport
        self.onFlowComplete = onFlowComplete
        self.onFlowExit = onFlowExit
        super.init(nibName: nil, bundle: nil)
        view.backgroundColor = .systemBackground
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !didStartCapture else { return }
        didStartCapture = true
        ApplicationCaptureLauncher.presentPassportModally(
            from: self,
            context: context,
            pieces: pieces,
            copy: copy,
            onCapturedImage: onCapturedImage,
            storePassport: storePassport,
            onComplete: { [weak self] in
                self?.onFlowComplete()
            },
            onExit: { [weak self] in
                self?.handleFlowExit()
            }
        )
    }

    private func handleFlowExit() {
        if let onFlowExit {
            onFlowExit()
        } else if presentingViewController?.presentedViewController === self {
            dismiss(animated: true)
        }
    }
}
