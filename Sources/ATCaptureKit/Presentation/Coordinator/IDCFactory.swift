import UIKit

public enum IDCFactory {

    @MainActor
    public static func push(
        from presenter: UIViewController,
        configuration: IDCConfiguration,
        verifier: IDCVerifier,
        scanEngines: IDCScanEngineProvider,
        callbacks: IDCCallbacks
    ) {
        let context = IDCPushContext()

        var wiredCallbacks = callbacks
        let hostExit = callbacks.onExit
        wiredCallbacks.onExit = {
            IDCNavigator.dismiss(context.viewController, then: hostExit)
        }

        let viewController = makeViewController(
            configuration: configuration,
            verifier: verifier,
            scanEngines: scanEngines,
            callbacks: wiredCallbacks
        )
        context.viewController = viewController

        IDCNavigator.push(viewController, from: presenter)
    }

    @MainActor
    public static func makeViewController(
        configuration: IDCConfiguration,
        verifier: IDCVerifier,
        scanEngines: IDCScanEngineProvider,
        callbacks: IDCCallbacks
    ) -> UIViewController {
        let viewModel = IDCFlowViewModel(
            configuration: configuration,
            verifier: verifier,
            scanEngines: scanEngines,
            callbacks: callbacks
        )
        return IDCFlowViewController(viewModel: viewModel)
    }
}

@MainActor
private final class IDCPushContext {
    weak var viewController: UIViewController?
}
