import SwiftUI

enum Minigame: String, CaseIterable, Identifiable {
    case yarn, purr, match, pond
    var id: String { rawValue }

    var title: String {
        switch self {
        case .yarn: "Yarn chase"
        case .purr: "Purr rhythm"
        case .match: "Kitty match"
        case .pond: "Pond fishing"
        }
    }
    var blurb: String {
        switch self {
        case .yarn: "Tap the rolling yarn before it escapes"
        case .purr: "Tap when the ring meets the circle"
        case .match: "Remember where the cats are, then find every pair"
        case .pond: "Hold to lower your hook and catch fish. Watch out for old boots!"
        }
    }
    var stat: StatKind {
        switch self {
        case .yarn: .speed
        case .purr: .charm
        case .match: .power
        case .pond: .hp
        }
    }
    var icon: String {
        switch self {
        case .yarn: "circle.dotted.circle"
        case .purr: "music.note"
        case .match: "rectangle.on.rectangle.angled"
        case .pond: "figure.fishing"
        }
    }
    /// Score needed for each training point.
    var perPoint: Int {
        switch self {
        case .yarn: 5
        case .purr: 8
        case .match: 1
        case .pond: 2
        }
    }
    /// The score that earns the full 20 coins; less earns a share of it (at least 3).
    var coinTarget: Int {
        switch self {
        case .yarn: 45
        case .purr: 50
        case .pond: 18
        case .match: 1   // Kitty match works out its own coins
        }
    }

    /// Fishing needs a little longer to reel things in.
    var duration: Double { self == .pond ? 30 : 20 }
}

struct PlayView: View {
    @Environment(GameStore.self) private var store
    @State private var game: Minigame?
    @State private var noEnergy = false
    /// Briefly highlights the minigames after a challenge's Go button scrolls to them.
    @State private var highlightGames = false

    var body: some View {
        @Bindable var store = store
        NavigationStack {
            ScrollViewReader { proxy in content(proxy) }
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

    private func content(_ proxy: ScrollViewProxy) -> some View {
        Screen {
            ScreenHeader(eyebrow: "Play with \(store.activeCat?.name ?? "your cat")", title: "Play") {
                CoinPill()
                EnergyPill()
            }
            if store.activeCat != nil {
                ChallengesCard(onGo: { kind in
                    // Already on Play: minigame challenges scroll down to the games instead.
                    guard kind == .playGames || kind == .highScore else { return false }
                    withAnimation(.easeInOut(duration: 0.5)) { proxy.scrollTo("minigames", anchor: .top) }
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(450))
                        withAnimation(.easeInOut(duration: 0.3)) { highlightGames = true }
                        try? await Task.sleep(for: .seconds(1.2))
                        withAnimation(.easeInOut(duration: 0.5)) { highlightGames = false }
                    }
                    return true
                })
                arenaCard
                Text("Minigames").font(Theme.font(17, .bold)).padding(.top, 4).id("minigames")
                Text("Each game trains one stat and earns XP and coins. Great scores can win an egg.")
                    .font(Theme.font(14)).foregroundStyle(Theme.muted)
                ForEach(Minigame.allCases) { g in
                    row(g)
                        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Theme.rose, lineWidth: highlightGames ? 3 : 0))
                        .scaleEffect(highlightGames ? 1.02 : 1)
                }
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
                    HStack(spacing: 6) {
                        Tag(text: "+ \(g.stat.title)", color: Theme.text)
                        if g == .match { Tag(text: "Level \(store.matchLevel)", color: Theme.rose) }
                    }
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
    /// Kitty match only: how the round went.
    @State private var matchOutcome: MatchOutcome?

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
                case .playing where game == .match:
                    CardMatchGame(level: MatchLevel(level: store.matchLevel), score: $score) { finishMatch($0) }
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
        case .purr: PurrRhythmGame(score: $score, start: start)
        case .match: EmptyView()   // shown directly by the container, with its own timer
        case .pond: PondFishingGame(score: $score, start: start, cat: cat)
        }
    }

    private var resultsView: some View {
        VStack(spacing: 14) {
            CatSprite(cat: store.cats.first { $0.id == cat.id } ?? cat, size: 170, mood: .happy)
            if let r = result {
                Text(matchOutcome.map { $0.cleared ? "Board cleared!" : "Time's up!" } ?? (r.points > 0 ? "Great session!" : "Good try!"))
                    .font(Theme.font(24, .heavy))
                VStack(spacing: 8) {
                    if let m = matchOutcome {
                        rewardRow(icon: "rectangle.on.rectangle.angled",
                                  text: m.cleared ? "Level \(m.level) cleared · next up: level \(m.level + 1)"
                                                  : "\(m.found) of \(m.pairs) pairs · try level \(m.level) again")
                    }
                    rewardRow(icon: game.stat.icon, text: "\(game.stat.title) +\(r.points * game.stat.step)")
                    rewardRow(icon: "star.fill", text: "+\(r.xp) XP")
                    rewardRow(icon: "pawprint.circle.fill", text: "+\(r.coins) coins")
                    if let egg = r.egg { rewardRow(icon: "oval.portrait.fill", text: "You found a \(egg.title.lowercased()) egg!") }
                    if let rep = r.report, rep.levelsGained > 0 {
                        LevelUpBurst(text: "Level up! Now Lv \(store.cats.first { $0.id == cat.id }?.level ?? cat.level)")
                            .frame(maxWidth: .infinity).padding(.vertical, 6)
                    }
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
        // Kitty match has its own preview, shuffle and timer, and reports back when it ends.
        guard game != .match else { return }
        try? await Task.sleep(for: .seconds(game.duration))
        guard !Task.isCancelled else { return }
        finish()
    }

    /// Rewards for Kitty match grow with the level, plus a bonus for clearing the board early.
    private func finishMatch(_ m: MatchOutcome) {
        let mult = MatchLevel(level: m.level).multiplier
        let points = min(10, m.found + (m.cleared ? m.level : 0))
        let xp = Int(Double(15 + m.found * 6) * mult) + (m.cleared ? 10 * m.level : 0)
        // Coins are kept small: up to 10 for the pairs you find, plus up to 10 more for clearing
        // the board quickly. Never more than 20.
        let pairCoins = Int((Double(m.found) / Double(max(m.pairs, 1)) * 10).rounded())
        let speedCoins = m.cleared ? Int((Double(m.secondsLeft) / MatchLevel(level: m.level).time * 10).rounded()) : 0
        let coins = min(20, pairCoins + speedCoins)
        store.updateCat(cat.id) { $0.add(game.stat, points * game.stat.step) }
        store.record(.playGames)
        store.record(.highScore, amount: m.score)
        store.addCoins(coins)
        let report = store.grow(cat.id, xp: xp)
        var egg: Rarity?
        if m.cleared, m.level >= 3, Double.random(in: 0..<1) < min(0.5, 0.1 + 0.04 * Double(m.level)) {
            let r = Rarity.roll(luck: min(0.3, 0.03 * Double(m.level)))
            store.addEgg(r, source: "Kitty match level \(m.level)")
            egg = r
        }
        if m.cleared { store.setMatchLevel(m.level + 1) }
        m.cleared ? Haptics.success() : Haptics.tap(.medium)
        matchOutcome = m
        result = (points, xp, coins, egg, report)
        withAnimation(.easeInOut) { phase = .done }
    }

    private func finish() {
        let points = min(10, score / game.perPoint)
        let xp = 10 + score
        // Coins grow with the score up to a cap of 20, so no game is a coin farm.
        let coins = max(3, min(20, Int((Double(score) / Double(game.coinTarget) * 20).rounded())))
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
