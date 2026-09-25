import SwiftUI

/// "…" menu with Report and Block for another player. Only shown for real players (multiplayer on).
struct PlayerSafetyMenu: View {
    @Environment(GameStore.self) private var store
    let playerID: UUID
    let name: String
    let context: ReportContext
    var onBlocked: () -> Void = {}

    @State private var reporting = false
    @State private var confirmBlock = false
    @State private var error: String?

    var body: some View {
        if store.isOnline {
            Menu {
                Button { reporting = true } label: { Label("Report \(name)", systemImage: "exclamationmark.bubble") }
                Button(role: .destructive) { confirmBlock = true } label: { Label("Block \(name)", systemImage: "hand.raised") }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .bold))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
                    .foregroundStyle(Theme.muted)
            }
            .accessibilityLabel("More options for \(name)")
            .sheet(isPresented: $reporting) {
                ReportSheet(playerID: playerID, name: name, context: context, onBlocked: onBlocked)
                    .presentationDetents([.medium, .large])
            }
            .confirmationDialog("Block \(name)?", isPresented: $confirmBlock, titleVisibility: .visible) {
                Button("Block", role: .destructive) { block() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(BlockCopy.explanation)
            }
            .alert("Couldn't block", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("OK", role: .cancel) {}
            } message: { Text(error ?? "") }
        }
    }

    private func block() {
        guard let online = store.online else { return }
        Task {
            do {
                try await online.block(playerID)
                Haptics.success()
                onBlocked()
            } catch {
                self.error = "Check your connection and try again."
            }
        }
    }
}

enum BlockCopy {
    static let explanation = "You won't see each other as friends, they can't visit your lounge, sign your guestbook or invite you to playdates. They won't be told. You can unblock them later in Friends."
}

struct ReportSheet: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let playerID: UUID
    let name: String
    let context: ReportContext
    var onBlocked: () -> Void = {}

    @State private var reason: ReportReason?
    @State private var alsoBlock = true
    @State private var sending = false
    @State private var sent = false
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if sent {
                Spacer()
                Image(systemName: "checkmark.shield.fill").font(.system(size: 48)).foregroundStyle(Theme.success)
                    .frame(maxWidth: .infinity)
                Text("Thanks for telling us").font(Theme.font(24, .heavy)).frame(maxWidth: .infinity)
                Text(alsoBlock ? "We'll look into it. \(name) is blocked, so they can't reach you." : "We'll look into it.")
                    .font(Theme.font(15)).foregroundStyle(Theme.muted).multilineTextAlignment(.center).frame(maxWidth: .infinity)
                Spacer()
                Button("Done") { dismiss() }.buttonStyle(PrimaryButtonStyle())
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("REPORT A PLAYER").font(Theme.font(12, .bold)).tracking(0.6).foregroundStyle(Theme.muted)
                    Text("What's wrong with \(name)?").font(Theme.font(22, .heavy))
                }
                ForEach(ReportReason.allCases) { r in
                    Button {
                        Haptics.tap()
                        reason = r
                    } label: {
                        HStack {
                            Text(r.title).font(Theme.font(16, .semibold))
                            Spacer()
                            Image(systemName: reason == r ? "largecircle.fill.circle" : "circle")
                                .foregroundStyle(reason == r ? Theme.rose : Theme.border)
                        }
                        .padding(.horizontal, 16).frame(minHeight: 52)
                        .background(RoundedRectangle(cornerRadius: 14).fill(.white))
                    }
                    .foregroundStyle(Theme.text)
                    .accessibilityAddTraits(reason == r ? .isSelected : [])
                }
                Toggle(isOn: $alsoBlock) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Also block \(name)").font(Theme.font(15, .bold))
                        Text("They won't be able to visit or invite you.").font(Theme.font(12)).foregroundStyle(Theme.muted)
                    }
                }
                .tint(Theme.rose)
                if let error { Text(error).font(Theme.font(13, .semibold)).foregroundStyle(Theme.rose) }
                Spacer(minLength: 0)
                Button(sending ? "Sending…" : "Send report") { send() }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(reason == nil || sending)
            }
        }
        .padding(20)
        .foregroundStyle(Theme.text)
        .background(Theme.cream.ignoresSafeArea())
    }

    private func send() {
        guard let reason, let online = store.online else { return }
        sending = true
        Task {
            do {
                try await online.report(playerID, reason: reason, context: context)
                if alsoBlock {
                    try await online.block(playerID)
                    onBlocked()
                }
                Haptics.success()
                withAnimation { sent = true }
            } catch {
                self.error = "Couldn't send the report. Check your connection and try again."
            }
            sending = false
        }
    }
}

/// Players you've blocked, with Unblock.
struct BlockedPlayersView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Screen {
            ScreenHeader(eyebrow: "Safety", title: "Blocked players") { EmptyView() }
            let list = store.online?.blocked ?? []
            if list.isEmpty {
                Text("You haven't blocked anyone.").font(Theme.font(15)).foregroundStyle(Theme.muted)
                    .frame(maxWidth: .infinity).padding(.vertical, 30)
            }
            ForEach(list) { p in
                Card(padding: 12) {
                    HStack {
                        Image(systemName: "hand.raised.fill").foregroundStyle(Theme.muted)
                            .frame(width: 40, height: 40).background(Circle().fill(Theme.beige))
                        Text(p.displayName).font(Theme.font(16, .bold))
                        Spacer()
                        Button("Unblock") {
                            Task { try? await store.online?.unblock(p.id) }
                        }
                        .font(Theme.font(14, .bold)).foregroundStyle(Theme.rose)
                        .padding(.horizontal, 14).frame(height: 40)
                        .overlay(Capsule().stroke(Theme.rose, lineWidth: 1.5))
                    }
                }
            }
            Text("Unblocking doesn't make you friends again. You can add each other with a friend code or through Game Center.")
                .font(Theme.font(12)).foregroundStyle(Theme.muted)
            Button("Done") { dismiss() }.buttonStyle(SecondaryButtonStyle())
        }
    }
}
