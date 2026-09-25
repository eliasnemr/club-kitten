import GameKit
import UIKit

/// Signs the player in to Game Center and reads their friends and identity signature.
@MainActor
final class GameCenter {
    static let shared = GameCenter()

    private(set) var isAuthenticated = false
    var displayName: String? { isAuthenticated ? GKLocalPlayer.local.displayName : nil }

    /// Resolves once Game Center has answered, signed in or not. Presents Apple's sign-in sheet if needed.
    func authenticate() async -> Bool {
        if GKLocalPlayer.local.isAuthenticated {
            isAuthenticated = true
            return true
        }
        return await withCheckedContinuation { cont in
            var resumed = false
            GKLocalPlayer.local.authenticateHandler = { viewController, error in
                if let viewController {
                    Self.topViewController()?.present(viewController, animated: true)
                    return
                }
                self.isAuthenticated = error == nil && GKLocalPlayer.local.isAuthenticated
                if !resumed {
                    resumed = true
                    cont.resume(returning: self.isAuthenticated)
                }
            }
        }
    }

    struct Identity: Encodable {
        let publicKeyURL: String
        let signature: String
        let salt: String
        let timestamp: UInt64
        let teamPlayerID: String
        let bundleID: String
        let displayName: String
    }

    /// Apple-signed proof of who the player is, checked by the link-game-center Edge Function.
    func identity() async throws -> Identity {
        let player = GKLocalPlayer.local
        let (url, signature, salt, timestamp) = try await player.fetchItemsForIdentityVerificationSignature()
        return Identity(publicKeyURL: url.absoluteString,
                        signature: signature.base64EncodedString(),
                        salt: salt.base64EncodedString(),
                        timestamp: timestamp,
                        teamPlayerID: player.teamPlayerID,
                        bundleID: Bundle.main.bundleIdentifier ?? "",
                        displayName: player.displayName)
    }

    /// Team player IDs of Game Center friends who allowed this app to see them.
    func friendIDs() async -> [String] {
        let player = GKLocalPlayer.local
        do {
            var status = try await player.loadFriendsAuthorizationStatus()
            if status == .notDetermined {
                _ = try await player.loadFriends()
                status = try await player.loadFriendsAuthorizationStatus()
            }
            guard status == .authorized else { return [] }
            return try await player.loadFriends().map(\.teamPlayerID)
        } catch {
            return []
        }
    }

    /// Apple's sheet for sending Game Center friend requests by message or email.
    /// Friends who accept and play Club Kitten show up in your Friends list automatically.
    func presentFriendRequestCreator() {
        guard isAuthenticated, let vc = Self.topViewController() else { return }
        try? GKLocalPlayer.local.presentFriendRequestCreator(from: vc)
    }

    private static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        var top = scene?.keyWindow?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}
