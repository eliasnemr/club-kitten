import SwiftUI

struct SettingsView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var confirmDelete = false
    @State private var deleting = false
    @State private var error: String?
    @State private var done = false

    private var online: OnlineService? { store.online }

    var body: some View {
        Screen {
            ScreenHeader(eyebrow: "Club Kitten", title: "Settings") {
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 15, weight: .bold))
                        .frame(width: 44, height: 44).background(Circle().fill(.white))
                }
                .accessibilityLabel("Close settings")
            }
            if done {
                Card {
                    Label("Your account and data were deleted", systemImage: "checkmark.circle.fill")
                        .font(Theme.font(15, .bold)).foregroundStyle(Theme.success)
                    Text("You're starting fresh with a new egg.").font(Theme.font(13)).foregroundStyle(Theme.muted)
                }
            }
            Card {
                Text("Account").font(Theme.font(17, .bold))
                row("person.crop.circle", "Account", online == nil ? "Offline (on this phone only)"
                    : online!.isOnline ? "Anonymous account" : "Not connected")
                if let code = online?.friendCode, online?.multiplayer == true {
                    row("number", "Friend code", code)
                }
                if online?.multiplayer == true {
                    row("gamecontroller", "Game Center", online?.gameCenterLinked == true ? "Linked" : "Not signed in")
                }
                if let online {
                    row("icloud", "Cloud save", cloudText(online))
                }
            }
            Card {
                Text("Help").font(Theme.font(17, .bold))
                Link(destination: URL(string: "https://eliasnemr.github.io/club-kitten/privacy")!) {
                    linkRow("hand.raised", "Privacy policy")
                }
                Link(destination: URL(string: "https://eliasnemr.github.io/club-kitten/support")!) {
                    linkRow("questionmark.circle", "Support")
                }
            }
            Card {
                Text(online == nil ? "Game data" : "Delete account").font(Theme.font(17, .bold))
                Text(online == nil
                     ? "Erase everything on this phone and start again from the first egg."
                     : "Permanently delete your account and everything stored with it: your cats, lounge, coins, friends, guestbook and cloud save, on our server and on this phone. This can't be undone.")
                    .font(Theme.font(13)).foregroundStyle(Theme.muted).fixedSize(horizontal: false, vertical: true)
                if let error { Text(error).font(Theme.font(13, .semibold)).foregroundStyle(Theme.rose) }
                Button(role: .destructive) {
                    confirmDelete = true
                } label: {
                    Label(deleting ? "Deleting…" : (online == nil ? "Erase game data" : "Delete account and data"),
                          systemImage: "trash")
                        .font(Theme.font(16, .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(Capsule().fill(Theme.rose))
                }
                .disabled(deleting)
            }
            Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "") (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""))")
                .font(Theme.font(12)).foregroundStyle(Theme.muted).frame(maxWidth: .infinity)
        }
        .confirmationDialog(online == nil ? "Erase your game?" : "Delete your account?",
                            isPresented: $confirmDelete, titleVisibility: .visible) {
            Button(online == nil ? "Erase game data" : "Delete account and data", role: .destructive) { delete() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(online == nil ? "All your cats, coins and lounge on this phone will be erased."
                 : "Your cats, lounge, friends and cloud save will be deleted for good.")
        }
    }

    private func row(_ icon: String, _ title: String, _ value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(Theme.rose).frame(width: 24)
            Text(title).font(Theme.font(14, .semibold))
            Spacer()
            Text(value).font(Theme.font(13)).foregroundStyle(Theme.muted).multilineTextAlignment(.trailing)
        }
        .frame(minHeight: 36)
    }

    private func linkRow(_ icon: String, _ title: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(Theme.rose).frame(width: 24)
            Text(title).font(Theme.font(14, .semibold)).foregroundStyle(Theme.text)
            Spacer()
            Image(systemName: "arrow.up.right").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.muted)
        }
        .frame(minHeight: 44)
    }

    private func cloudText(_ o: OnlineService) -> String {
        switch o.sync {
        case .synced: "Up to date"
        case .syncing: "Saving…"
        case .failed: "Offline"
        case .idle: "Connecting…"
        }
    }

    private func delete() {
        error = nil
        guard let online else {
            store.eraseEverything()
            Haptics.success()
            done = true
            return
        }
        deleting = true
        Task {
            do {
                try await online.deleteAccount()
                Haptics.success()
                done = true
            } catch {
                self.error = "Couldn't delete your account. Check your connection and try again."
            }
            deleting = false
        }
    }
}
