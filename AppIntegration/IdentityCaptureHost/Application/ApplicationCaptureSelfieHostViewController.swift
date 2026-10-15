import UIKit

final class ApplicationCaptureSelfieHostViewController: UIViewController {

    private let context: ApplicationCaptureContext
    private let onCapturedImage: ApplicationCaptureLauncher.CapturedImageHandler?
    private let onStored: ApplicationCaptureLauncher.SelfieStoredHandler
    private let onFlowExit: (() -> Void)?
    private var didStartCapture = false

    init(
        context: ApplicationCaptureContext,
        onCapturedImage: ApplicationCaptureLauncher.CapturedImageHandler? = nil,
        onStored: @escaping ApplicationCaptureLauncher.SelfieStoredHandler,
        onFlowExit: (() -> Void)? = nil
    ) {
        self.context = context
        self.onCapturedImage = onCapturedImage
        self.onStored = onStored
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
        ApplicationCaptureLauncher.presentSelfieModally(
            from: self,
            context: context,
            onCapturedImage: onCapturedImage,
            onStored: { [weak self] capturedLive in
                self?.onStored(capturedLive)
            },
            onExit: { [weak self] in
                self?.handleFlowExit()
            }
        )
    }

    /// Without a host-supplied exit handler this shell would stay on screen showing nothing but its
    /// own background. Self-dismissing is only safe when the shell is itself the presented view
    /// controller — when it is a child inside a representable, `dismiss` would tear down the
    /// presenting screen and desync its state.
    private func handleFlowExit() {
        if let onFlowExit {
            onFlowExit()
        } else if presentingViewController?.presentedViewController === self {
            dismiss(animated: true)
        }
    }
}
