import SwiftUI

// MARK: - Lobby

enum Difficulty: String, CaseIterable, Identifiable {
    case easy, even, tough
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var levelOffset: Int { [-1, 0, 2][index] }
    var reward: Double { [0.7, 1.0, 1.6][index] }
    var eggChance: Double { [0.2, 0.3, 0.45][index] }
    private var index: Int { Difficulty.allCases.firstIndex(of: self)! }
}

struct Rival: Identifiable {
    let id = UUID()
    let cat: Cat
    let difficulty: Difficulty
}

struct BattleLobbyView: View {
    @Environment(GameStore.self) private var store
    @State private var rivals: [Rival] = []
    @State private var fight: Rival?
    @State private var noEnergy = false

    var body: some View {
        Screen {
            ScreenHeader(eyebrow: "Arena", title: "Battle") { EnergyPill() }
            if let cat = store.activeCat {
                Card {
                    HStack(spacing: 14) {
                        CatSprite(cat: cat, size: 76)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(cat.name).font(Theme.font(18, .heavy))
                            Text("Lv \(cat.level) · \(cat.stage.title) · \(cat.wins) wins").font(Theme.font(13)).foregroundStyle(Theme.muted)
                            HStack(spacing: 4) {
                                ForEach(cat.equipped) { m in
                                    Image(systemName: m.icon).font(.system(size: 11)).foregroundStyle(Theme.rose)
                                        .frame(width: 24, height: 24).background(Circle().fill(Theme.roseTint))
                                }
                            }
                        }
                        Spacer()
                    }
                }
                HStack {
                    Text("Pick a rival").font(Theme.font(17, .bold))
                    Spacer()
                    Button {
                        Haptics.tap()
                        rollRivals(for: cat)
                    } label: {
                        Label("New rivals", systemImage: "arrow.clockwise").font(Theme.font(14, .bold))
                    }
                    .foregroundStyle(Theme.rose)
                    .frame(minHeight: 44)
                }
                ForEach(rivals) { rival in rivalRow(rival) }
                Text("Each battle uses 1 energy. Energy refills 1 every minute.")
                    .font(Theme.font(13)).foregroundStyle(Theme.muted)
            } else {
                NoCatYet()
            }
        }
        .onAppear {
            if rivals.isEmpty, let cat = store.activeCat { rollRivals(for: cat) }
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-battle"), fight == nil { fight = rivals.dropFirst().first }
            #endif
        }
        .onChange(of: store.activeCat?.id) { _, _ in if let cat = store.activeCat { rollRivals(for: cat) } }
        .fullScreenCover(item: $fight, onDismiss: { if let cat = store.activeCat { rollRivals(for: cat) } }) { rival in
            if let cat = store.activeCat { BattleView(player: cat, rival: rival) }
        }
        .alert("Out of energy", isPresented: $noEnergy) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your cat needs a catnap. Energy refills 1 every minute.")
        }
    }

    private func rollRivals(for cat: Cat) {
        rivals = Difficulty.allCases.map { d in
            Rival(cat: .random(rarity: .roll(), level: max(1, cat.level + d.levelOffset)), difficulty: d)
        }
    }

    private func rivalRow(_ rival: Rival) -> some View {
        Button {
            if store.spendEnergy() {
                Haptics.tap(.medium)
                fight = rival
            } else {
                Haptics.warning()
                noEnergy = true
            }
        } label: {
            HStack(spacing: 14) {
                CatSprite(cat: rival.cat, size: 64, animated: false)
                    .frame(width: 72, height: 72)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.beige))
                VStack(alignment: .leading, spacing: 4) {
                    Text(rival.cat.name).font(Theme.font(16, .heavy))
                    Text("Lv \(rival.cat.level) · \(rival.cat.kind.title)").font(Theme.font(13)).foregroundStyle(Theme.muted)
                    Tag(text: rival.difficulty.title, color: [Theme.success, Theme.warning, Theme.rose][Difficulty.allCases.firstIndex(of: rival.difficulty)!])
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(Theme.muted)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.white))
        }
        .buttonStyle(PressableStyle())
        .foregroundStyle(Theme.text)
    }
}

// MARK: - Engine

struct Fighter {
    var cat: Cat
    var hp: Int
    var focus = 3
    var powerMod = 1.0
    var dodging = false
    var maxHP: Int { cat.hp }

    init(_ cat: Cat) {
        self.cat = cat
        hp = cat.hp
    }
}

struct HitResult {
    var text: String
    var damage = 0
    var heal = 0
    var missed = false
    var crit = false
}

enum BattleEngine {
    static func resolve(_ move: Move, attacker a: inout Fighter, defender d: inout Fighter) -> HitResult {
        a.focus -= move.focusCost
        let name = a.cat.name
        switch move {
        case .hiss:
            d.powerMod = max(0.5, d.powerMod * 0.75)
            return HitResult(text: "\(name) hisses! \(d.cat.name) feels less brave.")
        case .purr:
            let heal = min(a.maxHP - a.hp, Int(Double(a.maxHP) * 0.25) + a.cat.charm / 2)
            a.hp += heal
            return HitResult(text: "\(name) purrs and heals \(heal) HP.", heal: heal)
        case .swipe, .pounce, .zoomies:
            if d.dodging {
                d.dodging = false
                return HitResult(text: "\(d.cat.name) zooms out of the way!", missed: true)
            }
            let accuracy = move == .pounce ? 0.75 : 0.95
            let dodge = min(0.2, max(0, Double(d.cat.speed - a.cat.speed) * 0.01))
            if Double.random(in: 0..<1) > accuracy - dodge {
                return HitResult(text: "\(name)'s \(move.title.lowercased()) misses!", missed: true)
            }
            let mult: Double = move == .pounce ? 1.8 : (move == .zoomies ? 0.6 : 1.0)
            let crit = Double.random(in: 0..<1) < Double(a.cat.charm) / 200
            var dmg = Double(a.cat.power) * mult * a.powerMod * Double.random(in: 0.85...1.15)
            if crit { dmg *= 1.5 }
            let damage = max(1, Int(dmg.rounded()))
            d.hp = max(0, d.hp - damage)
            if move == .zoomies { a.dodging = true }
            let verb = move == .pounce ? "pounces" : (move == .zoomies ? "zooms past" : "swipes")
            return HitResult(text: "\(name) \(verb) for \(damage)\(crit ? ", a cute crit!" : ".")", damage: damage, crit: crit)
        }
    }

    static func rivalChoice(_ me: Fighter) -> Move {
        let options = me.cat.equipped.filter { $0.focusCost <= me.focus }
        if options.contains(.purr), me.hp < me.maxHP * 35 / 100, Bool.random() { return .purr }
        if options.contains(.pounce), Double.random(in: 0..<1) < 0.45 { return .pounce }
        if options.contains(.hiss), me.powerMod >= 1, Double.random(in: 0..<1) < 0.2 { return .hiss }
        if options.contains(.zoomies), Double.random(in: 0..<1) < 0.2 { return .zoomies }
        return .swipe
    }
}

// MARK: - Fight

struct BattleView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let rival: Rival

    @State private var me: Fighter
    @State private var foe: Fighter
    @State private var log = "Your turn. Pick a move!"
    @State private var busy = false
    @State private var round = 1
    @State private var lunge: Side?
    @State private var hurt: Side?
    @State private var popups: [Popup] = []
    @State private var outcome: Outcome?

    enum Side { case me, foe }
    struct Popup: Identifiable { let id = UUID(); let side: Side; let text: String; let color: Color }
    struct Outcome { let won: Bool; let report: GrowthReport?; let coins: Int; let egg: Rarity? }

    init(player: Cat, rival: Rival) {
        self.rival = rival
        _me = State(initialValue: Fighter(player))
        _foe = State(initialValue: Fighter(rival.cat))
    }

    var body: some View {
        ZStack {
            Theme.cream.ignoresSafeArea()
            if let outcome {
                BattleResultView(cat: store.cats.first { $0.id == me.cat.id } ?? me.cat, outcome: outcome) { dismiss() }
                    .transition(.opacity)
            } else {
                fight
            }
        }
        .foregroundStyle(Theme.text)
        #if DEBUG
        .task {
            guard ProcessInfo.processInfo.arguments.contains("-autoplay") else { return }
            while outcome == nil {
                try? await Task.sleep(for: .milliseconds(700))
                if !busy, outcome == nil,
                   let move = me.cat.equipped.filter({ $0.focusCost <= me.focus }).randomElement() { play(move) }
            }
        }
        #endif
    }

    private var fight: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("BATTLE · ROUND \(round)").font(Theme.font(12, .bold)).tracking(0.6).foregroundStyle(Theme.muted)
                    Text("\(me.cat.name) vs \(foe.cat.name)").font(Theme.font(24, .heavy)).lineLimit(1).minimumScaleFactor(0.7)
                }
                Spacer()
                Button {
                    finish(won: false)
                } label: {
                    Text("Flee").font(Theme.font(14, .bold)).padding(.horizontal, 14).frame(height: 40)
                        .background(Capsule().fill(.white))
                }
                .disabled(busy)
            }
            fighterCard(foe, you: false)
            arena
            fighterCard(me, you: true)
            HStack {
                Text("Your move").font(Theme.font(16, .bold))
                Spacer()
                focusDots
            }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(me.cat.equipped) { move in moveButton(move) }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var arena: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Theme.beige)
            HStack(alignment: .bottom) {
                CatSprite(cat: me.cat, size: 140)
                    .offset(x: lunge == .me ? 60 : 0)
                    .modifier(Shake(amount: hurt == .me ? 1 : 0))
                    .colorMultiply(hurt == .me ? Color(red: 1, green: 0.6, blue: 0.6) : .white)
                    .overlay(alignment: .top) { popupStack(.me) }
                Spacer()
                CatSprite(cat: foe.cat, size: 140)
                    .scaleEffect(x: -1, y: 1)
                    .offset(x: lunge == .foe ? -60 : 0)
                    .modifier(Shake(amount: hurt == .foe ? 1 : 0))
                    .colorMultiply(hurt == .foe ? Color(red: 1, green: 0.6, blue: 0.6) : .white)
                    .overlay(alignment: .top) { popupStack(.foe) }
            }
            .padding(.horizontal, 8)
            VStack {
                Spacer()
                Text(log).font(Theme.font(14, .semibold)).multilineTextAlignment(.center)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(Capsule().fill(.white.opacity(0.9)))
                    .padding(10)
                    .animation(nil, value: log)
            }
        }
        .frame(height: 230)
    }

    private func popupStack(_ side: Side) -> some View {
        ZStack {
            ForEach(popups.filter { $0.side == side }) { p in
                RisingText(text: p.text, color: p.color)
            }
        }
    }

    private var focusDots: some View {
        HStack(spacing: 4) {
            Text("Focus").font(Theme.font(12, .semibold)).foregroundStyle(Theme.muted)
            ForEach(0..<6, id: \.self) { i in
                Circle().fill(i < me.focus ? Theme.rose : Theme.border).frame(width: 9, height: 9)
            }
        }
        .accessibilityLabel("Focus \(me.focus) of 6")
    }

    private func fighterCard(_ f: Fighter, you: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(f.cat.name).font(Theme.font(15, .heavy))
                if f.powerMod < 1 { Tag(text: "Nervous", color: Theme.warning) }
                if f.dodging { Tag(text: "Zooming", color: Theme.success) }
                Spacer()
                Text("\(you ? "You" : "Rival") · Lv \(f.cat.level)").font(Theme.font(12, .semibold)).foregroundStyle(Theme.muted)
            }
            StatBar(label: "HP", value: Double(f.hp), max: Double(f.maxHP), trailing: "\(f.hp)",
                    color: Double(f.hp) / Double(f.maxHP) < 0.3 ? Theme.rose : Theme.success)
                .animation(.easeOut(duration: 0.4), value: f.hp)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white))
    }

    private func moveButton(_ move: Move) -> some View {
        let affordable = move.focusCost <= me.focus
        return Button {
            play(move)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: move.icon).font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.rose)
                    Text(move.title).font(Theme.font(16, .heavy))
                    Spacer()
                    if move.focusCost > 0 {
                        Text("\(move.focusCost)").font(Theme.font(12, .bold)).foregroundStyle(Theme.muted)
                        Circle().fill(Theme.rose).frame(width: 7, height: 7)
                    }
                }
                Text(move.blurb).font(Theme.font(12)).foregroundStyle(Theme.muted)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 70, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.border, lineWidth: 1))
            .opacity(affordable && !busy ? 1 : 0.45)
        }
        .buttonStyle(PressableStyle())
        .foregroundStyle(Theme.text)
        .disabled(!affordable || busy)
    }

    // MARK: Turn flow

    private func play(_ move: Move) {
        busy = true
        Haptics.tap(.medium)
        Task { @MainActor in
            let meFirst = me.cat.speed >= foe.cat.speed
            let order: [Side] = meFirst ? [.me, .foe] : [.foe, .me]
            for side in order {
                let chosen = side == .me ? move : BattleEngine.rivalChoice(foe)
                await act(side, chosen)
                if me.hp == 0 || foe.hp == 0 { break }
                try? await Task.sleep(for: .milliseconds(450))
            }
            if foe.hp == 0 || me.hp == 0 {
                try? await Task.sleep(for: .milliseconds(600))
                finish(won: foe.hp == 0)
                return
            }
            me.focus = min(6, me.focus + 2)
            foe.focus = min(6, foe.focus + 2)
            round += 1
            log = "Your turn. Pick a move!"
            busy = false
        }
    }

    @MainActor
    private func act(_ side: Side, _ move: Move) async {
        let result: HitResult
        if side == .me {
            result = BattleEngine.resolve(move, attacker: &me, defender: &foe)
        } else {
            result = BattleEngine.resolve(move, attacker: &foe, defender: &me)
        }
        let target: Side = side == .me ? .foe : .me
        let attacking = [.swipe, .pounce, .zoomies].contains(move)
        if attacking {
            withAnimation(.easeIn(duration: 0.14)) { lunge = side }
            try? await Task.sleep(for: .milliseconds(140))
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { lunge = nil }
        }
        log = result.text
        if result.damage > 0 {
            Haptics.tap(result.crit ? .heavy : .medium)
            popups.append(Popup(side: target, text: "-\(result.damage)", color: result.crit ? Theme.warning : Theme.rose))
            withAnimation(.linear(duration: 0.35)) { hurt = target }
            try? await Task.sleep(for: .milliseconds(350))
            hurt = nil
        } else if result.missed {
            popups.append(Popup(side: target, text: "miss", color: Theme.muted))
        } else if result.heal > 0 {
            popups.append(Popup(side: side, text: "+\(result.heal)", color: Theme.success))
        } else {
            popups.append(Popup(side: target, text: "yikes", color: Theme.warning))
        }
        try? await Task.sleep(for: .milliseconds(500))
    }

    private func finish(won: Bool) {
        let d = rival.difficulty
        let baseXP = 20 + rival.cat.level * 8
        let xp = Int(Double(won ? baseXP : baseXP / 3) * d.reward)
        let coins = won ? Int(Double(Int.random(in: 15...30)) * d.reward) : 5
        var egg: Rarity?
        if won, Double.random(in: 0..<1) < d.eggChance {
            let r = Rarity.roll(luck: d == .tough ? 0.1 : 0)
            store.addEgg(r, source: "Won vs \(rival.cat.name)")
            egg = r
        }
        if won {
            store.updateCat(me.cat.id) { $0.wins += 1 }
            store.record(.winBattles)
        }
        store.addCoins(coins)
        let report = store.grow(me.cat.id, xp: xp)
        won ? Haptics.success() : Haptics.warning()
        withAnimation(.easeInOut(duration: 0.35)) {
            outcome = Outcome(won: won, report: report, coins: coins, egg: egg)
        }
    }
}

struct Shake: GeometryEffect {
    var amount: CGFloat
    var animatableData: CGFloat {
        get { amount }
        set { amount = newValue }
    }
    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 8 * sin(amount * .pi * 6), y: 0))
    }
}

struct RisingText: View {
    let text: String
    let color: Color
    @State private var up = false

    var body: some View {
        Text(text).font(Theme.font(26, .heavy)).foregroundStyle(color)
            .shadow(color: .white, radius: 2)
            .offset(y: up ? -60 : 0)
            .opacity(up ? 0 : 1)
            .onAppear { withAnimation(.easeOut(duration: 0.9)) { up = true } }
            .allowsHitTesting(false)
    }
}

// MARK: - Result

struct BattleResultView: View {
    let cat: Cat
    let outcome: BattleView.Outcome
    let done: () -> Void
    @State private var fill = false
    @State private var showEvolve = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("BATTLE OVER").font(Theme.font(12, .bold)).tracking(0.6).foregroundStyle(Theme.muted)
                    Text(outcome.won ? "You won!" : "Nap time...").font(Theme.font(30, .heavy))
                }
                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Theme.beige)
                    CatSprite(cat: cat, size: 220, mood: outcome.won ? .happy : .sleepy)
                        .scaleEffect(showEvolve ? 1.12 : 1)
                        .brightness(showEvolve ? 0.25 : 0)
                    if outcome.won || outcome.report?.evolved == true { ConfettiView() }
                }
                .frame(height: 260)

                Card {
                    HStack {
                        Text("XP earned").font(Theme.font(15, .bold))
                        Spacer()
                        Text("+\(outcome.report?.xp ?? 0)").font(Theme.font(15, .heavy)).foregroundStyle(Theme.rose)
                    }
                    StatBar(label: "Lv \(cat.level)", value: fill ? Double(cat.xp) : 0, max: Double(cat.xpNeeded), color: Theme.rose)
                    if let r = outcome.report, r.levelsGained > 0 {
                        Text("\(cat.name) reached level \(cat.level)! +\(r.levelsGained * 2) skill points")
                            .font(Theme.font(14, .bold))
                    }
                    if let r = outcome.report, r.evolved {
                        Text("\(cat.name) grew into \(r.newStage == .adult ? "an" : "a") \(r.newStage.title) cat!").font(Theme.font(16, .heavy)).foregroundStyle(Theme.rose)
                    }
                    HStack(spacing: 8) {
                        ForEach(Stage.allCases, id: \.self) { s in
                            VStack(spacing: 4) {
                                Image(systemName: s <= cat.stage ? "pawprint.fill" : "pawprint")
                                    .font(.system(size: 16))
                                Text(s.title).font(Theme.font(11, .bold))
                            }
                            .foregroundStyle(s <= cat.stage ? Theme.text : Theme.muted)
                            .frame(maxWidth: .infinity, minHeight: 54)
                            .background(RoundedRectangle(cornerRadius: 12).fill(s == cat.stage ? Theme.roseTint : Theme.beige))
                        }
                    }
                }
                Card {
                    HStack {
                        Text("Rewards").font(Theme.font(15, .bold))
                        Spacer()
                        Pill(icon: "pawprint.circle.fill", text: "+\(outcome.coins)", tint: Theme.warning)
                        if let egg = outcome.egg { Pill(icon: "oval.portrait.fill", text: "\(egg.title) egg", tint: egg.color) }
                    }
                    if !outcome.won {
                        Text("No hard feelings. \(cat.name) still learned something.").font(Theme.font(13)).foregroundStyle(Theme.muted)
                    }
                }
                Button("Back to arena", action: done).buttonStyle(PrimaryButtonStyle())
            }
            .padding(20)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1).delay(0.3)) { fill = true }
            if outcome.report?.evolved == true {
                withAnimation(.easeInOut(duration: 0.5).repeatCount(3, autoreverses: true).delay(0.6)) { showEvolve = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.3) { withAnimation { showEvolve = false } }
            }
        }
    }
}
