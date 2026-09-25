import SwiftUI

enum ChallengeKind: String, Codable, CaseIterable {
    case playGames, winBattles, petCats, highScore, hatchEgg, visitFriend, shop, playdate

    func title(_ target: Int) -> String {
        switch self {
        case .playGames: "Play \(target) minigames"
        case .winBattles: target == 1 ? "Win a battle" : "Win \(target) battles"
        case .petCats: "Pet your cats \(target) times"
        case .highScore: "Score \(target)+ in any minigame"
        case .hatchEgg: "Hatch an egg"
        case .visitFriend: "Visit a friend's lounge"
        case .shop: "Buy something at the shop"
        case .playdate: "Go on a playdate"
        }
    }
    var icon: String {
        switch self {
        case .playGames: "gamecontroller.fill"
        case .winBattles: "burst.fill"
        case .petCats: "hand.raised.fill"
        case .highScore: "star.fill"
        case .hatchEgg: "oval.portrait.fill"
        case .visitFriend: "person.2.fill"
        case .shop: "bag.fill"
        case .playdate: "heart.fill"
        }
    }
    /// Challenges that need a friend to visit or have a playdate with.
    var needsFriends: Bool { self == .visitFriend || self == .playdate }

    /// Where the "Go" button takes you.
    var tab: Tab {
        switch self {
        case .playGames, .highScore, .winBattles: .play
        case .petCats: .den
        case .hatchEgg: .eggs
        case .visitFriend, .shop, .playdate: .lounge
        }
    }
}

struct DailyChallenge: Codable, Identifiable, Equatable {
    var id = UUID()
    var kind: ChallengeKind
    var target: Int
    var progress = 0
    var reward: Int
    var claimed = false

    var done: Bool { progress >= target }
    var title: String { kind.title(target) }
}

enum ChallengeBook {
    static let bonusBase = 50

    static func dayKey(_ date: Date = Date()) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    /// Three challenges per day, the same for the whole day.
    static func make(for day: String, social: Bool = true) -> [DailyChallenge] {
        var rng = SeededRandom(seed: stableSeed(day))
        let options: [(ChallengeKind, ClosedRange<Int>, Int)] = [
            (.playGames, 2...3, 30), (.winBattles, 1...2, 40), (.petCats, 10...15, 20), (.highScore, 12...20, 45),
            (.hatchEgg, 1...1, 35), (.visitFriend, 1...1, 25), (.shop, 1...1, 25), (.playdate, 1...1, 40),
        ]
        var picked: [DailyChallenge] = []
        var pool = options.filter { social || !$0.0.needsFriends }
        while picked.count < 3, !pool.isEmpty {
            let i = Int(rng.next() % UInt64(pool.count))
            let (kind, range, reward) = pool.remove(at: i)
            let target = range.lowerBound + Int(rng.next() % UInt64(range.count))
            picked.append(DailyChallenge(kind: kind, target: target, reward: reward + (target - range.lowerBound) * 5))
        }
        return picked
    }

    /// FNV-1a, so the seed is the same on every launch and every device (String.hashValue is not).
    static func stableSeed(_ text: String) -> UInt64 {
        var h: UInt64 = 0xcbf29ce484222325
        for b in text.utf8 { h = (h ^ UInt64(b)) &* 0x100000001b3 }
        return h
    }

    /// Bonus for claiming all three: grows 10 coins per streak day, up to a week.
    static func bonus(streak: Int) -> Int { bonusBase + min(max(streak - 1, 0), 6) * 10 }
}

/// Small deterministic generator so every player gets the same challenges and deals on a given day.
struct SeededRandom {
    private var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E3779B97F4A7C15 }
    mutating func next() -> UInt64 {
        state = state &+ 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

// MARK: - Card

struct ChallengesCard: View {
    @Environment(GameStore.self) private var store
    var compact = false

    var body: some View {
        let list = store.challenges
        let claimed = list.filter(\.claimed).count
        Card {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Daily challenges").font(Theme.font(17, .heavy))
                    Text("New ones every day · \(claimed)/\(list.count) claimed").font(Theme.font(12)).foregroundStyle(Theme.muted)
                }
                Spacer()
                if store.streak > 0 {
                    Pill(icon: "flame.fill", text: "\(store.streak) day\(store.streak == 1 ? "" : "s")", tint: Theme.warning)
                }
            }
            ForEach(list) { c in row(c) }
            bonusRow(claimedAll: claimed == list.count)
        }
    }

    private func row(_ c: DailyChallenge) -> some View {
        HStack(spacing: 12) {
            Image(systemName: c.claimed ? "checkmark.circle.fill" : c.kind.icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(c.claimed ? Theme.success : Theme.rose)
                .frame(width: 36, height: 36)
                .background(Circle().fill(c.claimed ? Theme.success.opacity(0.14) : Theme.roseTint))
            VStack(alignment: .leading, spacing: 4) {
                Text(c.title).font(Theme.font(14, .bold)).strikethrough(c.claimed, color: Theme.muted)
                    .foregroundStyle(c.claimed ? Theme.muted : Theme.text)
                if !compact || !c.claimed {
                    HStack(spacing: 8) {
                        Capsule().fill(Theme.beige).frame(height: 6)
                            .overlay(alignment: .leading) {
                                GeometryReader { g in
                                    Capsule().fill(c.done ? Theme.success : Theme.rose)
                                        .frame(width: g.size.width * min(1, Double(c.progress) / Double(max(c.target, 1))))
                                }
                            }
                        Text("\(min(c.progress, c.target))/\(c.target)").font(Theme.font(11, .semibold)).foregroundStyle(Theme.muted).monospacedDigit()
                    }
                }
            }
            Spacer(minLength: 0)
            if c.claimed {
                Text("+\(c.reward)").font(Theme.font(13, .bold)).foregroundStyle(Theme.muted)
            } else if c.done {
                Button {
                    Haptics.success()
                    store.claim(c.id)
                } label: {
                    Label("\(c.reward)", systemImage: "pawprint.circle.fill")
                        .font(Theme.font(14, .bold)).foregroundStyle(.white)
                        .padding(.horizontal, 12).frame(height: 36)
                        .background(Capsule().fill(Theme.rose))
                }
                .accessibilityLabel("Claim \(c.reward) coins")
            } else {
                Button("Go") { store.tab = c.kind.tab; if c.kind == .winBattles { store.showArena = true } }
                    .font(Theme.font(13, .bold)).foregroundStyle(Theme.rose)
                    .padding(.horizontal, 14).frame(height: 36)
                    .overlay(Capsule().stroke(Theme.rose, lineWidth: 1.5))
            }
        }
    }

    private func bonusRow(claimedAll: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "gift.fill").foregroundStyle(Theme.warning)
            Text(store.bonusClaimedToday ? "Daily bonus collected. See you tomorrow!"
                 : "Claim all three for a +\(ChallengeBook.bonus(streak: store.streak + 1)) coin bonus")
                .font(Theme.font(12, .semibold)).foregroundStyle(Theme.muted)
            Spacer(minLength: 0)
        }
        .padding(.top, 2)
    }
}
