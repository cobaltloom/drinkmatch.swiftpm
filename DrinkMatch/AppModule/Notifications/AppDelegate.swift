import UIKit

/// SwiftUI's App protocol has no equivalent of `didRegisterForRemoteNotifications
/// WithDeviceToken` — a minimal UIApplicationDelegate via
/// `@UIApplicationDelegateAdaptor` (see DrinkMatchApp.swift) is the only way
/// to receive it. Its one job is handing that token to whatever
/// PushNotificationManager.configure(onToken:) last registered.
final class AppDelegate: NSObject, UIApplicationDelegate {
    static var deviceTokenHandler: ((Data) -> Void)?

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Self.deviceTokenHandler?(deviceToken)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // Push is opt-in and non-critical — in-app notifications (the bell
        // icon) still work without it. Nothing to surface to the user here.
    }
}
