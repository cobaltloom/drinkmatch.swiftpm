import UIKit
import UserNotifications

/// Requests notification permission and turns the resulting device token
/// into a hex string drinkmatch-backend's push_tokens table expects — see
/// its README "Push notifications" for the delivery worker that reads it.
enum PushNotificationManager {
    /// Wires the AppDelegate's device-token callback to `onToken`. Call
    /// this before requestAuthorization() so a token arriving right after
    /// permission is granted isn't dropped.
    static func configure(onToken: @escaping (String) -> Void) {
        AppDelegate.deviceTokenHandler = { data in
            onToken(data.map { String(format: "%02x", $0) }.joined())
        }
    }

    /// Returns whether permission was granted. If so, also registers for
    /// remote notifications, which triggers the AppDelegate callback wired
    /// above once Apple hands back a device token.
    @discardableResult
    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .badge, .sound])) ?? false
        if granted {
            await MainActor.run { UIApplication.shared.registerForRemoteNotifications() }
        }
        return granted
    }
}
