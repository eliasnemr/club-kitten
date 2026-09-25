import SwiftUI

// MARK: - Lounge decor

enum DecorCategory: String, CaseIterable, Identifiable {
    case furniture, toys, wallDecor, walls, floors, patterns
    var id: String { rawValue }
    var title: String {
        switch self {
        case .wallDecor: "Wall decor"
        default: rawValue.capitalized
        }
    }
    var isItems: Bool { self == .furniture || self == .toys || self == .wallDecor }
}

enum Furniture: String, Codable, CaseIterable, Identifiable {
    case catTree, cushion, fishTank, window, breedShelf, hammock, yarnBasket, scratchPost, rug, plant, lamp
    case catBed, sofa, painting, fairyLights, bookshelf
    // Illustrated with Higgsfield.
    case boxCastle, throne, fireplace, beanBag, monstera, pawClock
    var id: String { rawValue }

    /// Asset-catalog image for Higgsfield-illustrated pieces; nil means the item is drawn in code.
    var imageAsset: String? {
        switch self {
        case .boxCastle, .throne, .fireplace, .beanBag, .monstera, .pawClock: "Furniture-\(rawValue)"
        default: nil
        }
    }

    var title: String {
        switch self {
        case .catTree: "Cat tree"
        case .cushion: "Cushion"
        case .fishTank: "Fish tank"
        case .window: "Sunny window"
        case .breedShelf: "Breed shelf"
        case .hammock: "Hammock"
        case .yarnBasket: "Yarn basket"
        case .scratchPost: "Scratch post"
        case .rug: "Round rug"
        case .plant: "Cat grass"
        case .lamp: "Floor lamp"
        case .catBed: "Cat bed"
        case .sofa: "Comfy sofa"
        case .painting: "Cat portrait"
        case .fairyLights: "Fairy lights"
        case .bookshelf: "Bookshelf"
        case .boxCastle: "Box castle"
        case .throne: "Royal throne"
        case .fireplace: "Cozy fireplace"
        case .beanBag: "Bean bag"
        case .monstera: "Monstera"
        case .pawClock: "Paw clock"
        }
    }
    var blurb: String {
        switch self {
        case .catTree: "Three plush platforms for climbing and napping."
        case .cushion: "A soft spot for a quick catnap."
        case .fishTank: "Endless entertainment. Look, don't touch."
        case .window: "Sunbeams all afternoon."
        case .breedShelf: "Shows off the rarest breeds you've found."
        case .hammock: "Swing gently between two posts."
        case .yarnBasket: "Three balls of yarn, ready to unravel."
        case .scratchPost: "Saves your sofa. Probably."
        case .rug: "Round, soft and very sit-on-able."
        case .plant: "Fresh cat grass to nibble."
        case .lamp: "A warm glow for cozy evenings."
        case .catBed: "A donut bed with a fluffy middle."
        case .sofa: "Big enough for every cat and one human."
        case .painting: "A framed portrait of your active cat."
        case .fairyLights: "Twinkly lights strung along the wall."
        case .bookshelf: "Books to knock off, one by one."
        case .boxCastle: "Every cat's dream: a castle made of boxes."
        case .throne: "Gold, velvet and a crown. Fit for a legendary cat."
        case .fireplace: "A warm glow to curl up in front of."
        case .beanBag: "Squishy, mint and covered in paw prints."
        case .monstera: "Big leafy shade for sunny naps."
        case .pawClock: "Tells the time in toe beans."
        }
    }
    var price: Int {
        switch self {
        case .cushion, .plant: 30
        case .yarnBasket, .rug: 40
        case .lamp: 60
        case .scratchPost: 70
        case .catBed: 80
        case .fishTank, .fairyLights: 90
        case .breedShelf: 100
        case .catTree, .painting: 120
        case .bookshelf: 140
        case .hammock: 150
        case .sofa: 180
        case .window: 200
        case .monstera: 70
        case .pawClock: 80
        case .beanBag: 90
        case .boxCastle: 110
        case .fireplace: 220
        case .throne: 250
        }
    }
    var tier: String { price <= 60 ? "Basic" : (price <= 120 ? "Cozy" : "Deluxe") }
    var category: DecorCategory {
        switch self {
        case .yarnBasket, .scratchPost, .hammock, .boxCastle: .toys
        case .window, .breedShelf, .painting, .fairyLights, .pawClock: .wallDecor
        default: .furniture
        }
    }
    var onWall: Bool { category == .wallDecor }
    /// Items with fabric that can be recoloured.
    var tintable: Bool { [.cushion, .rug, .catBed, .sofa, .hammock, .catTree].contains(self) }
    /// Size in points for a 340-point-wide room.
    var size: CGSize {
        switch self {
        case .catTree: CGSize(width: 70, height: 170)
        case .cushion: CGSize(width: 96, height: 34)
        case .fishTank: CGSize(width: 78, height: 70)
        case .window: CGSize(width: 96, height: 76)
        case .breedShelf: CGSize(width: 110, height: 56)
        case .hammock: CGSize(width: 110, height: 70)
        case .yarnBasket: CGSize(width: 54, height: 40)
        case .scratchPost: CGSize(width: 40, height: 100)
        case .rug: CGSize(width: 150, height: 44)
        case .plant: CGSize(width: 44, height: 60)
        case .lamp: CGSize(width: 40, height: 130)
        case .catBed: CGSize(width: 90, height: 40)
        case .sofa: CGSize(width: 130, height: 72)
        case .painting: CGSize(width: 66, height: 70)
        case .fairyLights: CGSize(width: 160, height: 30)
        case .bookshelf: CGSize(width: 80, height: 124)
        case .boxCastle: CGSize(width: 104, height: 118)
        case .throne: CGSize(width: 84, height: 111)
        case .fireplace: CGSize(width: 118, height: 124)
        case .beanBag: CGSize(width: 96, height: 80)
        case .monstera: CGSize(width: 84, height: 100)
        case .pawClock: CGSize(width: 50, height: 68)
        }
    }
}

/// Fabric colours for tintable furniture. Changing colour is free once you own the item.
enum ItemTint: String, Codable, CaseIterable, Identifiable {
    case rose, honey, mint, sky, lavender, cocoa
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var color: Color {
        switch self {
        case .rose: Color(red: 0.95, green: 0.78, blue: 0.8)
        case .honey: Color(red: 0.98, green: 0.83, blue: 0.55)
        case .mint: Color(red: 0.72, green: 0.9, blue: 0.78)
        case .sky: Color(red: 0.7, green: 0.83, blue: 0.97)
        case .lavender: Color(red: 0.82, green: 0.76, blue: 0.96)
        case .cocoa: Color(red: 0.7, green: 0.56, blue: 0.46)
        }
    }
}

enum WallStyle: String, Codable, CaseIterable, Identifiable {
    case cream, blush, mint, sky, lavender
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var price: Int { self == .cream ? 0 : 50 }
    var color: Color {
        switch self {
        case .cream: Color(red: 0.98, green: 0.955, blue: 0.92)
        case .blush: Color(red: 0.99, green: 0.9, blue: 0.9)
        case .mint: Color(red: 0.89, green: 0.96, blue: 0.91)
        case .sky: Color(red: 0.88, green: 0.93, blue: 0.99)
        case .lavender: Color(red: 0.93, green: 0.9, blue: 0.99)
        }
    }
}

enum WallPattern: String, Codable, CaseIterable, Identifiable {
    case plain, stripes, dots, paws, hearts
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var price: Int { self == .plain ? 0 : 60 }
}

enum FloorStyle: String, Codable, CaseIterable, Identifiable {
    case oak, sage, rose, slate
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var price: Int { self == .oak ? 0 : 50 }
    var colors: [Color] {
        switch self {
        case .oak: [Color(red: 0.87, green: 0.74, blue: 0.58), Color(red: 0.8, green: 0.66, blue: 0.5)]
        case .sage: [Color(red: 0.78, green: 0.84, blue: 0.74), Color(red: 0.69, green: 0.77, blue: 0.65)]
        case .rose: [Color(red: 0.93, green: 0.8, blue: 0.8), Color(red: 0.87, green: 0.7, blue: 0.71)]
        case .slate: [Color(red: 0.74, green: 0.76, blue: 0.8), Color(red: 0.64, green: 0.67, blue: 0.72)]
        }
    }
}

/// Lounge names are built from preset words so they are always safe to show to visitors.
enum LoungeName {
    static let first = ["Cozy", "Sunny", "Purrfect", "Sleepy", "Royal", "Fluffy", "Snuggly", "Starry"]
    static let second = ["Corner", "Den", "Palace", "Nook", "Castle", "Hideout", "Cottage", "Clubhouse"]
    static func make(_ a: Int, _ b: Int) -> String {
        "\(first[min(max(a, 0), first.count - 1)]) \(second[min(max(b, 0), second.count - 1)])"
    }
}

/// A piece of furniture in a room. `x`, `y` are normalised; `y` is where it touches the floor (or wall centre).
struct PlacedItem: Codable, Identifiable, Equatable {
    var id = UUID()
    var kind: Furniture
    var x: Double
    var y: Double
    var flipped = false
    var tint: ItemTint?
}

struct Lounge: Codable, Equatable {
    var items: [PlacedItem]
    var stored: [Furniture] = []
    var wall: WallStyle = .cream
    var floor: FloorStyle = .oak
    var ownedWalls: [WallStyle] = [.cream]
    var ownedFloors: [FloorStyle] = [.oak]
    var pattern: WallPattern = .plain
    var ownedPatterns: [WallPattern] = [.plain]
    var nameFirst = 0
    var nameSecond = 0

    var name: String { LoungeName.make(nameFirst, nameSecond) }

    init(items: [PlacedItem], wall: WallStyle = .cream, floor: FloorStyle = .oak) {
        self.items = items
        self.wall = wall
        self.floor = floor
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        items = try c.decode([PlacedItem].self, forKey: .items)
        stored = try c.decodeIfPresent([Furniture].self, forKey: .stored) ?? []
        wall = try c.decodeIfPresent(WallStyle.self, forKey: .wall) ?? .cream
        floor = try c.decodeIfPresent(FloorStyle.self, forKey: .floor) ?? .oak
        ownedWalls = try c.decodeIfPresent([WallStyle].self, forKey: .ownedWalls) ?? [.cream]
        ownedFloors = try c.decodeIfPresent([FloorStyle].self, forKey: .ownedFloors) ?? [.oak]
        pattern = try c.decodeIfPresent(WallPattern.self, forKey: .pattern) ?? .plain
        ownedPatterns = try c.decodeIfPresent([WallPattern].self, forKey: .ownedPatterns) ?? [.plain]
        nameFirst = try c.decodeIfPresent(Int.self, forKey: .nameFirst) ?? 0
        nameSecond = try c.decodeIfPresent(Int.self, forKey: .nameSecond) ?? 0
    }

    static let starter = Lounge(items: [
        PlacedItem(kind: .window, x: 0.5, y: 0.22),
        PlacedItem(kind: .cushion, x: 0.55, y: 0.86),
    ])

    static func clamp(_ kind: Furniture, x: Double, y: Double) -> (Double, Double) {
        let cx = min(0.9, max(0.1, x))
        let cy = kind.onWall ? min(0.4, max(0.12, y)) : min(0.96, max(0.62, y))
        return (cx, cy)
    }
}

// MARK: - Friends (simulated until the online service exists)

struct Friend: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var code: String
    var cats: [Cat]
    var lounge: Lounge
    var online: Bool
    var status: String
    var friendship = 0

    var level: Int { 1 + friendship / 30 }
    var progress: Double { Double(friendship % 30) / 30 }
    var star: Cat { cats.max { $0.rarity < $1.rarity } ?? cats[0] }
}

struct GuestEntry: Codable, Identifiable, Equatable {
    var id = UUID()
    /// The visitor's player ID when it came from the server (used for report and block).
    var friendID: UUID?
    var friendName: String
    var breed: Breed
    var note: String
    var gift: String?
    var date = Date()
    var thanked = false
}

struct NestEgg: Codable, Identifiable, Equatable {
    var id = UUID()
    var egg: Egg
    var source: String
    var expires: Date
}

enum Chat {
    static let phrases = ["Hi!", "Cute cat!", "Playdate?", "Nice lounge!", "Love your decor!", "See you!"]
    static let stickers = ["paw", "heart", "star", "crown", "fish", "yarn"]
    static let replies = ["Hi hi!", "Thank you!", "Yes please!", "Mrrp!", "So cute!", "Come back soon!"]
    static let emotes: [(icon: String, label: String)] = [
        ("hand.wave.fill", "Wave"), ("heart.fill", "Love"), ("face.smiling.inverse", "Happy"),
        ("moon.zzz.fill", "Sleepy"), ("pawprint.fill", "Paw bump"),
    ]
}

enum PlaydateActivity: String, CaseIterable, Identifiable {
    case yarn, groom, nap, treats
    var id: String { rawValue }
    var title: String {
        switch self {
        case .yarn: "Share yarn"
        case .groom: "Groom"
        case .nap: "Nap together"
        case .treats: "Swap treats"
        }
    }
    var bond: Int { [10, 8, 15, 6][PlaydateActivity.allCases.firstIndex(of: self)!] }
    var cooldown: Double { [4, 3, 10, 5][PlaydateActivity.allCases.firstIndex(of: self)!] }
    var cost: Int { self == .treats ? 5 : 0 }
    var icon: String {
        switch self {
        case .yarn: "circle.dotted.circle"
        case .groom: "comb.fill"
        case .nap: "moon.zzz.fill"
        case .treats: "fish.fill"
        }
    }
}

struct PlaydateOdds {
    var lines: [(String, Int)]
    var total: Int { min(60, lines.reduce(0) { $0 + $1.1 }) }

    static func rarityBonus(_ r: Rarity) -> Int { [0, 5, 10, 15][Rarity.allCases.firstIndex(of: r)!] }

    static func make(mine: Cat, theirs: Cat, bond: Int, friendLevel: Int) -> PlaydateOdds {
        var lines: [(String, Int)] = [("Base chance", 10)]
        for c in [mine, theirs] where c.rarity != .basic {
            lines.append(("\(c.name) is \(c.rarity.title)", rarityBonus(c.rarity)))
        }
        if bond >= 80 { lines.append(("Bond over 80", 12)) } else if bond >= 50 { lines.append(("Bond over 50", 6)) }
        if friendLevel > 1 { lines.append(("Friendship Lv \(friendLevel)", friendLevel - 1)) }
        return PlaydateOdds(lines: lines)
    }
}

struct PlaydateResult: Equatable {
    var egg: Rarity?
    var toNest: Bool
    var friendship: Int
}

enum Seed {
    static func friends() -> [Friend] {
        [
            Friend(name: "Sam", code: "SAM-4821",
                   cats: [Cat.random(rarity: .rare, level: 4, name: "Sapphire", breed: .siamese),
                          Cat.random(rarity: .basic, level: 2, name: "Biscuit", breed: .calico)],
                   lounge: Lounge(items: [PlacedItem(kind: .scratchPost, x: 0.14, y: 0.8),
                                          PlacedItem(kind: .window, x: 0.62, y: 0.22),
                                          PlacedItem(kind: .rug, x: 0.5, y: 0.9),
                                          PlacedItem(kind: .plant, x: 0.88, y: 0.72)],
                                  wall: .sky, floor: .slate),
                   online: true, status: "In their lounge"),
            Friend(name: "Mia", code: "MIA-1507",
                   cats: [Cat.random(rarity: .legendary, level: 6, name: "Owlie", breed: .scottishFold),
                          Cat.random(rarity: .basic, level: 3, name: "Sprout", breed: .tabby)],
                   lounge: Lounge(items: [PlacedItem(kind: .hammock, x: 0.7, y: 0.78),
                                          PlacedItem(kind: .breedShelf, x: 0.3, y: 0.24),
                                          PlacedItem(kind: .yarnBasket, x: 0.2, y: 0.9),
                                          PlacedItem(kind: .lamp, x: 0.9, y: 0.75)],
                                  wall: .lavender, floor: .rose),
                   online: true, status: "Playing Yarn chase"),
            Friend(name: "Leo", code: "LEO-3390",
                   cats: [Cat.random(rarity: .legendary, level: 9, name: "Earl", breed: .britishShorthair),
                          Cat.random(rarity: .epic, level: 7, name: "Rufus", breed: .maineCoon)],
                   lounge: Lounge(items: [PlacedItem(kind: .catTree, x: 0.14, y: 0.82),
                                          PlacedItem(kind: .fishTank, x: 0.8, y: 0.78),
                                          PlacedItem(kind: .window, x: 0.5, y: 0.22),
                                          PlacedItem(kind: .cushion, x: 0.5, y: 0.92)],
                                  wall: .mint, floor: .oak),
                   online: false, status: "Last seen 2h ago"),
        ]
    }
}
