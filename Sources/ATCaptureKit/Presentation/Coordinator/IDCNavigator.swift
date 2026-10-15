import UIKit

enum IDCNavigator {

    @MainActor
    static func push(
        _ viewController: UIViewController,
        from presenter: UIViewController
    ) {
        if let navigationController = resolveNavigationController(from: presenter) {
            navigationController.pushViewController(viewController, animated: true)
            return
        }

        let navigationController = UINavigationController(rootViewController: viewController)
        navigationController.setNavigationBarHidden(true, animated: false)
        navigationController.modalPresentationStyle = .overFullScreen
        navigationController.modalTransitionStyle = .crossDissolve
        presenter.present(navigationController, animated: true)
    }

    @MainActor
    static func dismiss(_ viewController: UIViewController?, then completion: @escaping () -> Void) {
        guard let viewController else {
            completion()
            return
        }

        nonisolated(unsafe) let completion = completion
        let runOnMain: () -> Void = { DispatchQueue.main.async { completion() } }

        if let navigationController = viewController.navigationController,
           navigationController.viewControllers.contains(viewController) {
            if navigationController.viewControllers.first === viewController,
               navigationController.presentingViewController != nil {
                navigationController.dismiss(animated: true, completion: runOnMain)
            } else {
                CATransaction.begin()
                CATransaction.setCompletionBlock(runOnMain)
                navigationController.popViewController(animated: true)
                CATransaction.commit()
            }
            return
        }

        if viewController.presentingViewController != nil {
            viewController.dismiss(animated: true, completion: runOnMain)
            return
        }

        runOnMain()
    }

    @MainActor
    private static func resolveNavigationController(from presenter: UIViewController) -> UINavigationController? {
        var current: UIViewController? = presenter
        while let controller = current {
            if let navigationController = controller.navigationController {
                return navigationController
            }
            if let navigationController = controller as? UINavigationController {
                return navigationController
            }
            current = controller.presentingViewController ?? controller.parent
        }
        return nil
    }
}
