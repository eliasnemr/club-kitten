import SwiftUI

enum Minigame: String, CaseIterable, Identifiable {
    case yarn, fish, laser, purr
    var id: String { rawValue }

    var title: String {
        switch self {
        case .yarn: "Yarn chase"
        case .fish: "Fish toss"
        case .laser: "Laser dot"
        case .purr: "Purr rhythm"
        }
    }
    var blurb: String {
        switch self {
        case .yarn: "Tap the rolling yarn before it escapes"
        case .fish: "Stop the meter in the sweet spot to fling fish"
        case .laser: "Keep your finger on the dot as it zips around"
        case .purr: "Tap when the ring meets the circle"
        }
    }
    var stat: StatKind {
        switch self {
        case .yarn: .speed
        case .fish: .power
        case .laser: .hp
        case .purr: .charm
        }
    }
    var icon: String {
        switch self {
        case .yarn: "circle.dotted.circle"
        case .fish: "fish.fill"
        case .laser: "smallcircle.filled.circle"
        case .purr: "music.note"
        }
    }
    /// Score needed for each training point.
    var perPoint: Int {
        switch self {
        case .yarn: 5
        case .fish: 6
        case .laser: 40
        case .purr: 8
        }
    }
    var duration: Double { 20 }
}

struct PlayView: View {
    @Environment(GameStore.self) private var store
    @State private var game: Minigame?
    @State private var noEnergy = false

    var body: some View {
        @Bindable var store = store
        NavigationStack {
            content
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(isPresented: $store.showArena) {
                    BattleLobbyView().navigationBarTitleDisplayMode(.inline)
                }
        }
    }

    private var arenaCard: some View {
        Button {
            Haptics.tap(.medium)
            store.showArena = true
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "burst.fill").font(.system(size: 28, weight: .semibold)).foregroundStyle(.white)
                    .frame(width: 70, height: 70)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.rose))
                VStack(alignment: .leading, spacing: 4) {
                    Text("Battle arena").font(Theme.font(17, .heavy))
                    Text("Take on rivals for XP, coins and eggs").font(Theme.font(12)).foregroundStyle(Theme.muted)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").foregroundStyle(Theme.muted)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.white))
        }
        .buttonStyle(PressableStyle())
        .foregroundStyle(Theme.text)
    }

    private var content: some View {
        Screen {
            ScreenHeader(eyebrow: "Play with \(store.activeCat?.name ?? "your cat")", title: "Play") { EnergyPill() }
            if store.activeCat != nil {
                ChallengesCard()
                arenaCard
                Text("Minigames").font(Theme.font(17, .bold)).padding(.top, 4)
                Text("Each game trains one stat and earns XP and coins. Great scores can win an egg.")
                    .font(Theme.font(14)).foregroundStyle(Theme.muted)
                ForEach(Minigame.allCases) { g in row(g) }
            } else {
                NoCatYet()
            }
        }
        #if DEBUG
        .onAppear {
            let args = ProcessInfo.processInfo.arguments
            if let i = args.firstIndex(of: "-game"), i + 1 < args.count { game = Minigame(rawValue: args[i + 1]) }
        }
        #endif
        .fullScreenCover(item: $game) { g in
            if let cat = store.activeCat { MinigameContainer(game: g, cat: cat) }
        }
        .alert("Out of energy", isPresented: $noEnergy) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Energy refills 1 every minute.")
        }
    }

    private func row(_ g: Minigame) -> some View {
        Card(padding: 12) {
            HStack(spacing: 14) {
                Image(systemName: g.icon).font(.system(size: 28, weight: .semibold)).foregroundStyle(Theme.rose)
                    .frame(width: 70, height: 70)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.roseTint))
                VStack(alignment: .leading, spacing: 4) {
                    Text(g.title).font(Theme.font(16, .heavy))
                    Text(g.blurb).font(Theme.font(12)).foregroundStyle(Theme.muted).fixedSize(horizontal: false, vertical: true)
                    Tag(text: "+ \(g.stat.title)", color: Theme.text)
                }
                Spacer(minLength: 0)
                Button {
                    if store.spendEnergy() {
                        Haptics.tap(.medium)
                        game = g
                    } else {
                        Haptics.warning()
                        noEnergy = true
                    }
                } label: {
                    Text("Play").font(Theme.font(15, .bold)).foregroundStyle(Theme.rose)
                        .padding(.horizontal, 16).frame(height: 44)
                        .overlay(Capsule().stroke(Theme.rose, lineWidth: 1.5))
                }
                .buttonStyle(PressableStyle())
            }
        }
    }
}

// MARK: - Shell: intro countdown → game → results

struct MinigameContainer: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let game: Minigame
    let cat: Cat

    enum Phase { case countdown(Int), playing(Date), done }
    @State private var phase: Phase = .countdown(3)
    @State private var score = 0
    @State private var result: (points: Int, xp: Int, coins: Int, egg: Rarity?, report: GrowthReport?)?

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("TRAINING \(game.stat.title.uppercased())").font(Theme.font(12, .bold)).tracking(0.6).foregroundStyle(Theme.muted)
                    Text(game.title).font(Theme.font(26, .heavy))
                }
                Spacer()
                Text("\(score)").font(Theme.font(34, .heavy)).monospacedDigit().foregroundStyle(Theme.rose)
                    .contentTransition(.numericText())
                    .animation(.snappy, value: score)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)

            ZStack {
                RoundedRectangle(cornerRadius: 26, style: .continuous).fill(Theme.beige)
                switch phase {
                case .countdown(let n):
                    VStack(spacing: 12) {
                        CatSprite(cat: cat, size: 150, mood: .happy)
                        Text(game.blurb).font(Theme.font(15, .semibold)).multilineTextAlignment(.center).padding(.horizontal, 30)
                        Text("\(n)").font(Theme.font(64, .heavy)).foregroundStyle(Theme.rose)
                            .id(n).transition(.scale.combined(with: .opacity))
                    }
                case .playing(let start):
                    VStack(spacing: 0) {
                        TimelineView(.periodic(from: start, by: 0.1)) { ctx in
                            let left = max(0, game.duration - ctx.date.timeIntervalSince(start))
                            StatBar(label: formatTime(left), value: left, max: game.duration, color: left < 5 ? Theme.rose : Theme.text)
                                .padding(16)
                        }
                        gameView(start)
                    }
                case .done:
                    resultsView
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .padding(.horizontal, 12)

            if case .done = phase {
                Button("Done") { dismiss() }.buttonStyle(PrimaryButtonStyle()).padding(.horizontal, 20)
            } else if case .countdown = phase {
                Button("Quit") { dismiss() }.buttonStyle(SecondaryButtonStyle()).padding(.horizontal, 20)
            }
        }
        .padding(.bottom, 12)
        .foregroundStyle(Theme.text)
        .background(Theme.cream.ignoresSafeArea())
        .task { await run() }
    }

    @ViewBuilder
    private func gameView(_ start: Date) -> some View {
        switch game {
        case .yarn: YarnChaseGame(score: $score)
        case .fish: FishTossGame(score: $score, start: start)
        case .laser: LaserDotGame(score: $score, start: start)
        case .purr: PurrRhythmGame(score: $score, start: start)
        }
    }

    private var resultsView: some View {
        VStack(spacing: 14) {
            CatSprite(cat: store.cats.first { $0.id == cat.id } ?? cat, size: 170, mood: .happy)
            if let r = result {
                Text(r.points > 0 ? "Great session!" : "Good try!").font(Theme.font(24, .heavy))
                VStack(spacing: 8) {
                    rewardRow(icon: game.stat.icon, text: "\(game.stat.title) +\(r.points * game.stat.step)")
                    rewardRow(icon: "star.fill", text: "+\(r.xp) XP")
                    rewardRow(icon: "pawprint.circle.fill", text: "+\(r.coins) coins")
                    if let egg = r.egg { rewardRow(icon: "oval.portrait.fill", text: "You found a \(egg.title.lowercased()) egg!") }
                    if let rep = r.report, rep.levelsGained > 0 { rewardRow(icon: "arrow.up.circle.fill", text: "Level up! Now Lv \(store.cats.first { $0.id == cat.id }?.level ?? cat.level)") }
                    if let rep = r.report, rep.evolved { rewardRow(icon: "sparkles", text: "Grew into \(rep.newStage == .adult ? "an" : "a") \(rep.newStage.title) cat!") }
                }
                .padding(.horizontal, 24)
            }
            ConfettiView(count: 30)
        }
    }

    private func rewardRow(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundStyle(Theme.rose).frame(width: 24)
            Text(text).font(Theme.font(16, .bold))
            Spacer()
        }
        .padding(.horizontal, 14).frame(height: 44)
        .background(RoundedRectangle(cornerRadius: 12).fill(.white))
    }

    @MainActor
    private func run() async {
        for n in stride(from: 3, through: 1, by: -1) {
            withAnimation(.spring) { phase = .countdown(n) }
            Haptics.tap()
            try? await Task.sleep(for: .seconds(0.8))
        }
        Haptics.tap(.heavy)
        let start = Date()
        phase = .playing(start)
        try? await Task.sleep(for: .seconds(game.duration))
        guard !Task.isCancelled else { return }
        finish()
    }

    private func finish() {
        let points = min(10, score / game.perPoint)
        let xp = 10 + score
        let coins = 5 + score / 2
        store.updateCat(cat.id) { $0.add(game.stat, points * game.stat.step) }
        store.record(.playGames)
        store.record(.highScore, amount: score)
        store.addCoins(coins)
        let report = store.grow(cat.id, xp: xp)
        var egg: Rarity?
        if points >= 4, Double.random(in: 0..<1) < 0.25 {
            let r = Rarity.roll()
            store.addEgg(r, source: "\(game.title) high score")
            egg = r
        }
        Haptics.success()
        result = (points, xp, coins, egg, report)
        withAnimation(.easeInOut) { phase = .done }
    }
}
