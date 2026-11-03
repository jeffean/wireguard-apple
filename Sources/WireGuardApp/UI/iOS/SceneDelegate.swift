// SPDX-License-Identifier: MIT
// Copyright © 2018-2026 WireGuard LLC. All Rights Reserved.

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    static let tunnelDetailActivityType = "com.wireguard.ios.tunnel-detail"
    private static let tunnelNameKey = "TunnelName"
    private static let tunnelDetailRestorationPrefix = "TunnelDetailVC:"

    var window: UIWindow?
    var mainVC: MainViewController?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let window = UIWindow(windowScene: windowScene)
        self.window = window

        let mainVC = MainViewController()
        window.rootViewController = mainVC
        window.makeKeyAndVisible()

        self.mainVC = mainVC

        // A launch for a specific action takes precedence over restoring the previous state.
        if let urlContext = connectionOptions.urlContexts.first {
            mainVC.importFromDisposableFile(url: urlContext.url)
        } else if let shortcutItem = connectionOptions.shortcutItem {
            _ = performQuickAction(shortcutItem)
        } else if let tunnelName = session.stateRestorationActivity?.userInfo?[Self.tunnelNameKey] as? String {
            mainVC.showTunnelDetailForTunnel(named: tunnelName, animated: false, shouldToggleStatus: false)
        }
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        for urlContext in URLContexts {
            mainVC?.importFromDisposableFile(url: urlContext.url)
        }
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        mainVC?.refreshTunnelConnectionStatuses()
    }

    func sceneWillResignActive(_ scene: UIScene) {
        guard let allTunnelNames = mainVC?.allTunnelNames() else { return }
        UIApplication.shared.shortcutItems = QuickActionItem.createItems(allTunnelNames: allTunnelNames)
    }

    func windowScene(_ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        completionHandler(performQuickAction(shortcutItem))
    }

    func stateRestorationActivity(for scene: UIScene) -> NSUserActivity? {
        guard let tunnelName = Self.tunnelDetailName(in: mainVC) else { return nil }
        let activity = NSUserActivity(activityType: Self.tunnelDetailActivityType)
        activity.userInfo = [Self.tunnelNameKey: tunnelName]
        return activity
    }

    private func performQuickAction(_ shortcutItem: UIApplicationShortcutItem) -> Bool {
        guard shortcutItem.type == QuickActionItem.type else { return false }
        let tunnelName = shortcutItem.localizedTitle
        mainVC?.showTunnelDetailForTunnel(named: tunnelName, animated: false, shouldToggleStatus: true)
        return true
    }

    private static func tunnelDetailName(in viewController: UIViewController?) -> String? {
        guard let viewController = viewController else { return nil }
        if let identifier = viewController.restorationIdentifier, identifier.hasPrefix(tunnelDetailRestorationPrefix) {
            return String(identifier.dropFirst(tunnelDetailRestorationPrefix.count))
        }
        for child in viewController.children.reversed() {
            if let tunnelName = tunnelDetailName(in: child) {
                return tunnelName
            }
        }
        return nil
    }
}
