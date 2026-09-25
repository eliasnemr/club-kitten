import SwiftUI

enum Rarity: String, Codable, CaseIterable, Comparable {
    case basic, rare, epic, legendary

    /// Older saves used common / mythic.
    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = Rarity(rawValue: raw) ?? (raw == "mythic" ? .epic : .basic)
    }

    static func < (a: Rarity, b: Rarity) -> Bool { a.order < b.order }
    private var order: Int { Rarity.allCases.firstIndex(of: self)! }

    var title: String { rawValue.capitalized }
    var hatchSeconds: Double { [45, 120, 240, 420][order] }
    var statBonus: Int { [0, 3, 6, 10][order] }
    var color: Color {
        switch self {
        case .basic: Theme.muted
        case .rare: Color(red: 0.2, green: 0.47, blue: 0.78)
        case .epic: Color(red: 0.52, green: 0.3, blue: 0.82)
        case .legendary: Color(red: 0.64, green: 0.42, blue: 0.02)
        }
    }
    var shell: [Color] {
        switch self {
        case .basic: [Color(red: 0.99, green: 0.96, blue: 0.9), Color(red: 0.93, green: 0.86, blue: 0.76)]
        case .rare: [Color(red: 0.9, green: 0.95, blue: 1), Color(red: 0.58, green: 0.74, blue: 0.95)]
        case .epic: [Color(red: 0.94, green: 0.9, blue: 1), Color(red: 0.66, green: 0.52, blue: 0.95)]
        case .legendary: [Color(red: 1, green: 0.96, blue: 0.78), Color(red: 0.95, green: 0.72, blue: 0.22)]
        }
    }
    var breeds: [Breed] { Breed.allCases.filter { $0.rarity == self && $0 != .cream } }

    /// Egg odds: legendary 3%, epic 10%, rare 27%, basic 60%. `luck` shifts toward rarer eggs.
    static func roll(luck: Double = 0) -> Rarity {
        let r = Double.random(in: 0..<1) - luck
        if r < 0.03 { return .legendary }
        if r < 0.13 { return .epic }
        if r < 0.40 { return .rare }
        return .basic
    }
}

enum Breed: String, Codable, CaseIterable, Identifiable {
    case cream, tabby, tuxedo, calico, siamese, russianBlue, maineCoon, bengal, britishShorthair, scottishFold
    var id: String { rawValue }

    var title: String {
        switch self {
        case .cream: "Cream puff"
        case .tabby: "Orange tabby"
        case .tuxedo: "Tuxedo"
        case .calico: "Calico"
        case .siamese: "Siamese"
        case .russianBlue: "Russian Blue"
        case .maineCoon: "Maine Coon"
        case .bengal: "Bengal"
        case .britishShorthair: "British Shorthair"
        case .scottishFold: "Scottish Fold"
        }
    }
    var rarity: Rarity {
        switch self {
        case .cream, .tabby, .tuxedo, .calico: .basic
        case .siamese, .russianBlue: .rare
        case .maineCoon, .bengal: .epic
        case .britishShorthair, .scottishFold: .legendary
        }
    }
    /// The stat this breed is naturally good at.
    var gift: StatKind {
        switch self {
        case .cream, .tabby, .bengal, .russianBlue: .speed
        case .tuxedo: .power
        case .calico, .siamese, .scottishFold: .charm
        case .maineCoon, .britishShorthair: .hp
        }
    }
    var blurb: String {
        switch self {
        case .cream: "Sunny and playful, fresh from the very first egg."
        case .tabby: "Always hungry, always zooming."
        case .tuxedo: "Dressed for battle at all times."
        case .calico: "Three colours, endless charm."
        case .siamese: "Chatty, clever and very dramatic."
        case .russianBlue: "Shy, silver and lightning quick."
        case .maineCoon: "A gentle giant with a lion's mane."
        case .bengal: "A tiny leopard with big adventures."
        case .britishShorthair: "Round, royal and impossibly plush."
        case .scottishFold: "Folded ears, owl eyes, total royalty."
        }
    }
    /// Background colour baked into this breed's idle video.
    var videoBackdrop: Color {
        switch self {
        case .britishShorthair: Color(red: 0.967, green: 0.890, blue: 0.757)
        case .scottishFold: Color(red: 0.970, green: 0.893, blue: 0.760)
        default: Theme.videoBackdrop
        }
    }
    var imageName: String { self == .cream ? "MochiCutout" : "Breed-\(rawValue)" }
    /// Higgsfield idle loop bundled for this breed, if there is one.
    var idleVideo: String? {
        switch self {
        case .cream: "mochi_idle"
        case .britishShorthair: "bsh_idle"
        case .scottishFold: "fold_idle"
        default: nil
        }
    }
}

enum Element: String, Codable, CaseIterable {
    case sunbeam, moonlight, mint, berry, storm

    var title: String { rawValue.capitalized }
    /// Hue shift applied to Mochi's art to make each element look distinct.
    var hue: Double {
        switch self {
        case .sunbeam: 0
        case .moonlight: 195
        case .mint: 105
        case .berry: 305
        case .storm: 235
        }
    }
    var saturation: Double {
        switch self {
        case .sunbeam: 1
        case .moonlight: 0.8
        case .mint: 1.1
        case .berry: 1.2
        case .storm: 0.9
        }
    }
    var color: Color {
        switch self {
        case .sunbeam: Theme.warning
        case .moonlight: Color(red: 0.35, green: 0.55, blue: 0.8)
        case .mint: Theme.success
        case .berry: Theme.rose
        case .storm: Color(red: 0.4, green: 0.4, blue: 0.75)
        }
    }
}

enum Personality: String, Codable, CaseIterable {
    case playful, sleepy, brave, curious, sweet

    var title: String { rawValue.capitalized }
    var favored: StatKind {
        switch self {
        case .playful, .curious: .speed
        case .sleepy: .hp
        case .brave: .power
        case .sweet: .charm
        }
    }
}

enum StatKind: String, Codable, CaseIterable, Identifiable {
    case hp, power, speed, charm
    var id: String { rawValue }
    var title: String { self == .hp ? "HP" : rawValue.capitalized }
    /// How much one skill point (or one training point) adds.
    var step: Int { self == .hp ? 5 : 2 }
    var icon: String {
        switch self {
        case .hp: "heart.fill"
        case .power: "flame.fill"
        case .speed: "hare.fill"
        case .charm: "sparkles"
        }
    }
    var displayMax: Double { self == .hp ? 200 : 80 }
}

enum Stage: Int, Codable, CaseIterable, Comparable {
    case kitten, young, adult, legend

    static func < (a: Stage, b: Stage) -> Bool { a.rawValue < b.rawValue }
    static func forLevel(_ level: Int) -> Stage {
        switch level {
        case 15...: .legend
        case 10...: .adult
        case 5...: .young
        default: .kitten
        }
    }
    var title: String { rawValue == 0 ? "Kitten" : String(describing: self).capitalized }
    var startLevel: Int { [1, 5, 10, 15][rawValue] }
    var scale: CGFloat { [0.78, 0.88, 0.96, 1.0][rawValue] }
}

enum Move: String, Codable, CaseIterable, Identifiable {
    case swipe, pounce, hiss, purr, zoomies
    var id: String { rawValue }

    var title: String { self == .purr ? "Purr heal" : rawValue.capitalized }
    var blurb: String {
        switch self {
        case .swipe: "Quick hit"
        case .pounce: "Big hit, may miss"
        case .hiss: "Lowers rival power"
        case .purr: "Heals HP"
        case .zoomies: "Hit and dodge next"
        }
    }
    var focusCost: Int {
        switch self {
        case .swipe: 0
        case .pounce: 3
        case .hiss, .purr, .zoomies: 2
        }
    }
    var unlockLevel: Int {
        switch self {
        case .swipe, .pounce: 1
        case .hiss: 3
        case .zoomies: 5
        case .purr: 6
        }
    }
    var unlockText: String { unlockLevel == 5 ? "Unlocks at Young stage" : "Unlocks at Lv \(unlockLevel)" }
    var icon: String {
        switch self {
        case .swipe: "hand.raised.fill"
        case .pounce: "bolt.fill"
        case .hiss: "exclamationmark.bubble.fill"
        case .purr: "heart.circle.fill"
        case .zoomies: "wind"
        }
    }
}

struct Cat: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var element: Element
    var personality: Personality
    var rarity: Rarity
    var level = 1
    var xp = 0
    var skillPoints = 0
    var hp: Int
    var power: Int
    var speed: Int
    var charm: Int
    var equipped: [Move] = [.swipe, .pounce]
    var wins = 0
    var isStarter = false
    /// Optional so saves from before breeds existed still load (they become Cream puffs).
    var breed: Breed?

    var kind: Breed { breed ?? .cream }
    var stage: Stage { .forLevel(level) }
    var xpNeeded: Int { 40 + level * 20 }

    func stat(_ kind: StatKind) -> Int {
        switch kind {
        case .hp: hp
        case .power: power
        case .speed: speed
        case .charm: charm
        }
    }

    mutating func add(_ kind: StatKind, _ amount: Int) {
        switch kind {
        case .hp: hp += amount
        case .power: power += amount
        case .speed: speed += amount
        case .charm: charm += amount
        }
    }

    func knows(_ move: Move) -> Bool { level >= move.unlockLevel }

    /// Adds XP and applies level-ups. Returns how many levels were gained.
    @discardableResult
    mutating func gainXP(_ amount: Int) -> Int {
        xp += amount
        var gained = 0
        while xp >= xpNeeded {
            xp -= xpNeeded
            level += 1
            gained += 1
            skillPoints += 2
            hp += 3
            power += 1
            speed += 1
            charm += 1
            for move in Move.allCases where move.unlockLevel == level && equipped.count < 4 && !equipped.contains(move) {
                equipped.append(move)
            }
        }
        return gained
    }

    static func random(rarity: Rarity, level: Int = 1, name: String? = nil, breed: Breed? = nil) -> Cat {
        let breed = breed ?? rarity.breeds.randomElement()!
        let rarity = breed.rarity
        let personality = Personality.allCases.randomElement()!
        let bonus = rarity.statBonus
        var cat = Cat(
            name: name ?? Names.random(),
            element: Element.allCases.randomElement()!,
            personality: personality,
            rarity: rarity,
            hp: 42 + Int.random(in: 0...6) + bonus * 2,
            power: 10 + Int.random(in: 0...3) + bonus,
            speed: 10 + Int.random(in: 0...3) + bonus,
            charm: 10 + Int.random(in: 0...3) + bonus,
            breed: breed
        )
        cat.add(personality.favored, personality.favored.step * 2)
        cat.add(breed.gift, breed.gift.step * 2)
        if level > 1 {
            cat.gainXP((1..<level).reduce(0) { $0 + 40 + $1 * 20 })
            // Rivals spend their points on their favoured stat.
            cat.add(personality.favored, cat.skillPoints / 2 * personality.favored.step)
            cat.add(.hp, cat.skillPoints / 2 * StatKind.hp.step)
            cat.skillPoints = 0
            cat.equipped = Move.allCases.filter { cat.knows($0) }.prefix(4).map { $0 }
        }
        return cat
    }

    static func starter() -> Cat {
        Cat(name: "Mochi", element: .sunbeam, personality: .playful, rarity: .basic,
            hp: 46, power: 12, speed: 15, charm: 12, isStarter: true, breed: .cream)
    }
}

struct Egg: Codable, Identifiable, Equatable {
    var id = UUID()
    var rarity: Rarity
    var startedAt = Date()
    var duration: Double
    var isStarter = false

    init(rarity: Rarity, duration: Double? = nil, isStarter: Bool = false) {
        self.rarity = rarity
        self.duration = duration ?? rarity.hatchSeconds
        self.isStarter = isStarter
    }

    var readyAt: Date { startedAt.addingTimeInterval(duration) }
    func remaining(_ now: Date) -> Double { max(0, readyAt.timeIntervalSince(now)) }
    func progress(_ now: Date) -> Double { duration <= 0 ? 1 : min(1, now.timeIntervalSince(startedAt) / duration) }
    func isReady(_ now: Date) -> Bool { remaining(now) <= 0 }
}

enum Names {
    static let pool = ["Tofu", "Pickles", "Nugget", "Biscuit", "Pepper", "Waffles", "Noodle", "Sprout", "Pudding",
                       "Ziggy", "Maple", "Bean", "Clover", "Sesame", "Dumpling", "Pip", "Kiwi", "Taro", "Juniper", "Churro"]
    static func random() -> String { pool.randomElement()! }
}

func formatDuration(_ seconds: Double) -> String {
    let s = max(0, Int(seconds))
    return s >= 3600 ? "\(s / 3600)h \(s % 3600 / 60)m" : formatTime(Double(s))
}

func formatTime(_ seconds: Double) -> String {
    let s = Int(seconds.rounded(.up))
    return s >= 60 ? String(format: "%d:%02d", s / 60, s % 60) : "\(s)s"
}
