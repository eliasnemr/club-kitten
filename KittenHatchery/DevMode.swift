import SwiftUI

/// Dev mode: for testing on the simulator or your own phone.
/// - The server is off, so nothing reaches the real Supabase project.
/// - The practice friends (Sam, Mia, Leo) appear, so lounge visits and playdates can be tested.
/// - A DEV badge opens a panel with coins, energy and egg shortcuts.
///
/// Turn it on with the "Club Kitten (Dev)" scheme, the `-devMode` launch argument, or
/// `CLUB_KITTEN_DEV_MODE = YES` in Config/Secrets.xcconfig. Release builds never have it.
enum DevMode {
    static let isOn: Bool = {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-devMode") { return true }
        let flag = (Bundle.main.infoDictionary?["ClubKittenDevMode"] as? String ?? "").uppercased()
        return flag == "YES" || flag == "TRUE" || flag == "1"
        #else
        return false
        #endif
    }()
}

#if DEBUG
/// Small badge in the corner while dev mode is on; tap it for the dev panel.
struct DevBadge: View {
    @State private var showPanel = false

    var body: some View {
        if DevMode.isOn {
            Button {
                showPanel = true
            } label: {
                Label("DEV", systemImage: "hammer.fill")
                    .font(Theme.font(11, .heavy))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10).frame(height: 26)
                    .background(Capsule().fill(Color.purple))
            }
            .accessibilityLabel("Developer tools")
            .sheet(isPresented: $showPanel) {
                DevPanel().presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
            }
        }
    }
}

struct DevPanel: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var note: String?
    @State private var confirmReset = false

    var body: some View {
        Screen {
            ScreenHeader(eyebrow: "Dev mode", title: "Developer tools") { CoinPill() }
            Text("Server off · practice friends on · nothing here reaches players.")
                .font(Theme.font(12)).foregroundStyle(Theme.muted)
            if let note { Text(note).font(Theme.font(13, .bold)).foregroundStyle(Theme.success) }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                tool("pawprint.circle.fill", "+1,000 coins") { store.addCoins(1000); return "Added 1,000 coins" }
                tool("pawprint.circle.fill", "+10,000 coins") { store.addCoins(10000); return "Added 10,000 coins" }
                tool("bolt.fill", "Full energy") { store.devFillEnergy(); return "Energy is full" }
                tool("timer", "Hatch eggs now") { store.devFinishEggs(); return "All eggs are ready" }
                tool("oval.portrait.fill", "Add a legendary egg") { store.addEgg(.legendary, source: "Dev panel"); return "Added a legendary egg" }
                tool("person.2.fill", "Friend visits now") { store.forceVisitor(); return "A friend dropped by your lounge" }
                tool("checklist", "Finish challenges") { store.devFinishChallenges(); return "Challenges are ready to claim" }
                tool("wand.and.stars", "Sample save") { store.seedDemo(); return "Loaded the sample save" }
            }
            Button(role: .destructive) { confirmReset = true } label: {
                Label("Start over (erase this save)", systemImage: "trash")
            }
            .buttonStyle(SecondaryButtonStyle())
            Button("Done") { dismiss() }.buttonStyle(PrimaryButtonStyle())
        }
        .confirmationDialog("Erase this save and start from the first egg?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Erase", role: .destructive) { store.devResetSave(); dismiss() }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func tool(_ icon: String, _ title: String, action: @escaping () -> String) -> some View {
        Button {
            Haptics.tap(.medium)
            withAnimation { note = action() }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 20, weight: .semibold)).foregroundStyle(Color.purple)
                Text(title).font(Theme.font(13, .bold)).multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 76)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.white))
        }
        .buttonStyle(PressableStyle())
        .foregroundStyle(Theme.text)
    }
}
#endif
