import SwiftUI
import UIKit

final class IDCFlowViewController: UIHostingController<IDCFlowView> {

    init(viewModel: IDCFlowViewModel) {
        super.init(rootView: IDCFlowView(viewModel: viewModel))
    }

    @available(*, unavailable)
    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
    }

    override var prefersStatusBarHidden: Bool { false }
}
