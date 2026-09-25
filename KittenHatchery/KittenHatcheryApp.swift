import SwiftUI

@main
struct KittenHatcheryApp: App {
    @State private var store = GameStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .preferredColorScheme(.light)
        }
    }
}

struct RootView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    private let clock = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        @Bindable var store = store
        TabView(selection: $store.tab) {
            DenView().tabItem { Label("Den", systemImage: "house.fill") }.tag(Tab.den)
            HatcheryView().tabItem { Label("Eggs", systemImage: "oval.portrait.fill") }.tag(Tab.eggs)
            CollectionView().tabItem { Label("Cats", systemImage: "square.grid.2x2.fill") }.tag(Tab.cats)
            LoungeView().tabItem { Label("Lounge", systemImage: "sofa.fill") }.tag(Tab.lounge)
            PlayView().tabItem { Label("Play", systemImage: "gamecontroller.fill") }.tag(Tab.play)
        }
        .tint(Theme.rose)
        #if DEBUG
        // Sits in the empty strip under the Dynamic Island, clear of headers and buttons.
        .overlay(alignment: .top) { DevBadge().padding(.top, 2) }
        #endif
        .onReceive(clock) { _ in store.tick() }
        .task { await store.online?.start() }
        .onChange(of: scenePhase) { _, phase in
            // Send the latest save before the app is suspended.
            if phase == .background { store.online?.flushSave() }
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
    var body: some View {
        Pill(icon: "pawprint.circle.fill", text: "\(store.coins)", tint: Theme.warning)
            .accessibilityLabel("\(store.coins) coins")
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
