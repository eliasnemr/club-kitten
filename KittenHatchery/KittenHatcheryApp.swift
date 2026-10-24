import SwiftUI

@main
struct KittenHatcheryApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var store = GameStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .preferredColorScheme(.light)
                .debugNarrow()
        }
    }
}

struct RootView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    /// A playdate invite you said yes to from the banner.
    @State private var joining: PlaydateRequest?
    private let clock = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        @Bindable var store = store
        TabView(selection: $store.tab) {
            DenView().tabItem { Label("Den", systemImage: "house.fill") }.tag(Tab.den)
            HatcheryView().tabItem { Label("Eggs", systemImage: "oval.portrait.fill") }.tag(Tab.eggs)
            PlayView().tabItem { Label("Play", systemImage: "gamecontroller.fill") }.tag(Tab.play)
            CollectionView().tabItem { Label("Cats", systemImage: "square.grid.2x2.fill") }.tag(Tab.cats)
            LoungeView().tabItem { Label("Lounge", systemImage: "sofa.fill") }.tag(Tab.lounge)
        }
        .tint(Theme.rose)
        #if DEBUG
        // Sits in the empty strip under the Dynamic Island, clear of headers and buttons.
        .overlay(alignment: .top) { DevBadge().padding(.top, 2) }
        #endif
        .onReceive(clock) { _ in store.tick() }
        .task {
            PushCenter.shared.start(store: store)
            await store.online?.start()
            PushCenter.shared.uploadToken()
        }
        // Invites reach you on every screen, including while visiting a friend.
        .overlay(alignment: .top) {
            InviteBanner { joining = $0 }
        }
        .overlay(alignment: .bottom) {
            if let text = store.toastMessage {
                Text(text)
                    .font(Theme.font(14, .bold)).foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 18).padding(.vertical, 12)
                    .background(Capsule().fill(Theme.text.opacity(0.92)))
                    .padding(.horizontal, 24).padding(.bottom, 118)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .allowsHitTesting(false)
                    .accessibilityAddTraits(.updatesFrequently)
            }
        }
        // Invite links: clubkitten://add?code=KIT-XXXXXX (or the web page that opens it).
        .onOpenURL { url in
            guard let code = InviteLink.code(from: url) else { return }
            store.tab = .lounge
            Task { await store.online?.redeemInvite(code) }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background:
                // Send the latest save and lounge before the app is suspended.
                store.online?.flushSave()
                store.online?.pushProfile(now: true)
            case .active:
                Task { await store.online?.becameActive() }
            default:
                break
            }
        }
        .fullScreenCover(item: $joining) { r in
            if let cat = store.activeCat { OnlinePlaydateView(friend: r.friend, myCat: cat, invite: r.invite) }
        }
        #if DEBUG
        .onAppear { applyDebugArguments() }
        #endif
        .fullScreenCover(isPresented: Binding(
            get: { store.pendingHatch != nil },
            set: { if !$0 { store.pendingHatch = nil } }
        )) {
            if let pending = store.pendingHatch {
                HatchRevealView(cat: pending.cat, rarity: pending.rarity)
            }
        }
    }
}

#if DEBUG
extension RootView {
    /// Launch arguments for testing: `-demo` seeds a save, `-tab eggs|cats|battle|play`, `-hatch` opens a reveal.
    func applyDebugArguments() {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-demo") { store.seedDemo() }
        if args.contains("-showcasePlaces") { store.devShowcasePlaces() }
        if let i = args.firstIndex(of: "-matchLevel"), i + 1 < args.count, let n = Int(args[i + 1]) { store.setMatchLevel(n) }
        if let i = args.firstIndex(of: "-tab"), i + 1 < args.count {
            store.tab = ["eggs": .eggs, "cats": .cats, "lounge": .lounge, "battle": .play, "play": .play][args[i + 1]] ?? .den
            if args[i + 1] == "battle" { store.showArena = true }
        }
        if let i = args.firstIndex(of: "-hatch") {
            let breed = i + 1 < args.count ? Breed(rawValue: args[i + 1]) : nil
            let cat = Cat.random(rarity: breed?.rarity ?? .rare, breed: breed)
            store.pendingHatch = (cat, cat.rarity)
        }
        if args.contains("-visitor") { store.forceVisitor() }
        if let i = args.firstIndex(of: "-addCoins"), i + 1 < args.count, let n = Int(args[i + 1]) { store.addCoins(n) }
        if let i = args.firstIndex(of: "-active"), i + 1 < args.count,
           let cat = store.cats.first(where: { $0.kind.rawValue == args[i + 1] }) {
            store.setActive(cat.id)
        }
    }
}
#endif

extension View {
    /// Debug -narrow: lay out 320 points wide, like an iPhone with Display Zoom turned on.
    func debugNarrow() -> some View {
        #if DEBUG
        frame(maxWidth: ProcessInfo.processInfo.arguments.contains("-narrow") ? 320 : .infinity)
        #else
        self
        #endif
    }
}

/// Shared screen scaffold: cream background, padded scroll content.
struct Screen<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) { content }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .background(Theme.cream.ignoresSafeArea())
        .foregroundStyle(Theme.text)
    }
}

struct EnergyPill: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        let text = store.secondsToNextEnergy.map { "\(store.energy) · \(formatTime($0))" } ?? "\(store.energy)"
        Pill(icon: "bolt.fill", text: text, tint: store.energy == 0 ? Theme.rose : Theme.text)
            .accessibilityLabel("Energy \(store.energy) of \(GameStore.maxEnergy)")
    }
}

struct CoinPill: View {
    @Environment(GameStore.self) private var store
    @State private var gains: [CoinGain] = []
    @State private var bump = 0

    struct CoinGain: Identifiable { let id = UUID(); let amount: Int }

    var body: some View {
        Pill(icon: "pawprint.circle.fill", text: "\(store.coins)", tint: Theme.warning)
            .animation(.snappy, value: store.coins)
            .keyframeAnimator(initialValue: 1.0, trigger: bump) { content, s in
                content.scaleEffect(s)
            } keyframes: { _ in
                SpringKeyframe(1.18, duration: 0.15)
                SpringKeyframe(1, duration: 0.3, spring: .bouncy)
            }
            // "+25" floats up from the pill whenever coins come in.
            .overlay(alignment: .top) {
                ZStack {
                    ForEach(gains) { g in CoinGainLabel(amount: g.amount) }
                }
                .allowsHitTesting(false)
            }
            .onChange(of: store.coins) { old, new in
                guard new > old else { return }
                bump += 1
                let gain = CoinGain(amount: new - old)
                gains.append(gain)
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(1.3))
                    gains.removeAll { $0.id == gain.id }
                }
            }
            .accessibilityLabel("\(store.coins) coins")
    }
}

private struct CoinGainLabel: View {
    let amount: Int
    @State private var up = false

    var body: some View {
        Text("+\(amount)")
            .font(Theme.font(15, .heavy)).foregroundStyle(Theme.warning)
            .shadow(color: .white, radius: 2)
            .offset(y: up ? 34 : 6)
            .opacity(up ? 0 : 1)
            .onAppear { withAnimation(.easeOut(duration: 1.1)) { up = true } }
    }
}

/// Shown on tabs that need a cat when none has hatched yet.
struct NoCatYet: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        VStack(spacing: 16) {
            EggView(rarity: .basic, size: 120)
            Text("Hatch your first kitten").font(Theme.font(20, .bold))
            Text("Your first egg is warm and ready.").font(Theme.font(15)).foregroundStyle(Theme.muted)
            Button("Go to the hatchery") { store.tab = .eggs }
                .buttonStyle(PrimaryButtonStyle())
                .frame(width: 240)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}
