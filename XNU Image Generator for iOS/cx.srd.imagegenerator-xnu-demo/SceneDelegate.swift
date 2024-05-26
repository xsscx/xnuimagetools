import UIKit

/// The SceneDelegate class defines the behavior of the app's scene.
class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    // MARK: - UIWindowSceneDelegate

    /// Tells the delegate about the addition of a scene to the app.
    ///
    /// - Parameters:
    ///   - scene: The scene object being added to the app.
    ///   - session: The session object containing details about the scene.
    ///   - connectionOptions: The configuration data used to create the scene.
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        print("Scene will connect to session: \(session)")
        guard let windowScene = (scene as? UIWindowScene) else { return }
        
        let window = UIWindow(windowScene: windowScene)
        let viewController = ViewController()
        let navigationController = UINavigationController(rootViewController: viewController)
        window.rootViewController = navigationController
        self.window = window
        window.makeKeyAndVisible()
    }

    /// Tells the delegate that the scene is being released by the system.
    ///
    /// - Parameter scene: The scene object being released.
    func sceneDidDisconnect(_ scene: UIScene) {
        print("Scene did disconnect: \(scene)")
    }

    /// Tells the delegate that the scene has moved from an inactive state to an active state.
    ///
    /// - Parameter scene: The scene object that moved to an active state.
    func sceneDidBecomeActive(_ scene: UIScene) {
        print("Scene did become active: \(scene)")
    }

    /// Tells the delegate that the scene will move from an active state to an inactive state.
    ///
    /// - Parameter scene: The scene object that will move to an inactive state.
    func sceneWillResignActive(_ scene: UIScene) {
        print("Scene will resign active: \(scene)")
    }

    /// Tells the delegate that the scene is about to enter the foreground.
    ///
    /// - Parameter scene: The scene object that is about to enter the foreground.
    func sceneWillEnterForeground(_ scene: UIScene) {
        print("Scene will enter foreground: \(scene)")
    }

    /// Tells the delegate that the scene has entered the background.
    ///
    /// - Parameter scene: The scene object that entered the background.
    func sceneDidEnterBackground(_ scene: UIScene) {
        print("Scene did enter background: \(scene)")
    }
}
