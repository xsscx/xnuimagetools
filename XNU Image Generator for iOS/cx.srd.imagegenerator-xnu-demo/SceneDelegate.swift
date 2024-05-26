/**
 *  @file ViewController.swift
 *  @brief XNU Image Generator for iOS
 *  @date 21 MAY 2024
 *  @version 1.7.0
 *
 *  This program is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program. If not, see <http://www.gnu.org/licenses/>.
 *
 */

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
