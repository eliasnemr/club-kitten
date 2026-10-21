import SwiftUI
import UIKit
import UserNotifications

/// Push notifications for playdate invites, friend requests and arena coins.
/// Permission is only asked after the player does something social, never at launch.
@MainActor
final class PushCenter: NSObject, UNUserNotificationCenterDelegate {
    static let shared = PushCenter()
    weak var store: GameStore?
    private var token: String?

    /// Debug builds talk to Apple's sandbox; TestFlight and App Store builds to production.
    private var env: String {
        #if DEBUG
        "development"
        #else
        "production"
        #endif
    }

    func start(store: GameStore) {
        self.store = store
        UNUserNotificationCenter.current().delegate = self
        // Already allowed earlier: refresh the token quietly.
        Task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            if settings.authorizationStatus == .authorized {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }

    /// Asks once, at a moment where notifications clearly help (sending an invite or request,
    /// setting a defender). Later calls do nothing.
    func askIfNeeded() {
        Task {
            let center = UNUserNotificationCenter.current()
            guard await center.notificationSettings().authorizationStatus == .notDetermined else { return }
            if (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) == true {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }

    func didRegister(_ deviceToken: Data) {
        let hex = deviceToken.map { String(format: "%02x", $0) }.joined()
        token = hex
        uploadToken()
    }

    /// Sends the token once signed in (called again when the online service starts).
    func uploadToken() {
        guard let token, let online = store?.online, online.isOnline else { return }
        Task { await online.registerDevice(token: token, env: env) }
    }

    // In the app, the invite banner and toasts already show these; no system banner.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        []
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let kind = response.notification.request.content.userInfo["kind"] as? String
        await MainActor.run { open(kind) }
    }

    /// Tapping a notification takes you to what it's about.
    private func open(_ kind: String?) {
        guard let store else { return }
        switch kind {
        case "playdate":
            // The invite banner appears on top of whatever screen is showing.
            Task { await store.online?.refreshInvites() }
        case "friend_request":
            store.tab = .lounge
            store.loungeRoute = .friends
        case "arena":
            store.tab = .play
            store.showArena = true
        default:
            break
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        MainActor.assumeIsolated { PushCenter.shared.didRegister(deviceToken) }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        #if DEBUG
        print("[push] registration failed: \(error)")
        #endif
    }
}
