import SwiftUI
import Observation

enum Tab: Hashable { case den, eggs, cats, lounge, play }

struct SaveData: Codable {
    var cats: [Cat] = []
    var activeCatID: UUID?
    var eggs: [Egg] = [Egg(rarity: .basic, duration: 0, isStarter: true)]
    var coins = 50
    var energy = 5
    var energyStamp = Date()
    // Added with the lounge update; decoded leniently so older saves still load.
    var lounge = Lounge.starter
    var friends = Seed.friends()
    var guestbook: [GuestEntry] = []
    var nest: [NestEgg] = []
    var playdateDay = ""
    var playdatesToday = 0
    var lastVisitCheck = Date()
    var appliedGifts: [UUID] = []
    var challengeDay = ""
    var challenges: [DailyChallenge] = []
    var streak = 0
    var lastBonusDay = ""
    /// Goes up on every save; the cloud keeps whichever copy has the highest number.
    var saveVersion = 0
    /// Duplicate kittens sent to the Kitty Hotel.
    var hotelGuests = 0

    init() {}

    init(cats: [Cat], activeCatID: UUID?, eggs: [Egg], coins: Int, energy: Int, energyStamp: Date) {
        self.cats = cats
        self.activeCatID = activeCatID
        self.eggs = eggs
        self.coins = coins
        self.energy = energy
        self.energyStamp = energyStamp
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = SaveData()
        cats = try c.decode([Cat].self, forKey: .cats)
        activeCatID = try c.decodeIfPresent(UUID.self, forKey: .activeCatID)
        eggs = try c.decode([Egg].self, forKey: .eggs)
        coins = try c.decode(Int.self, forKey: .coins)
        energy = try c.decode(Int.self, forKey: .energy)
        energyStamp = try c.decode(Date.self, forKey: .energyStamp)
        lounge = try c.decodeIfPresent(Lounge.self, forKey: .lounge) ?? d.lounge
        friends = try c.decodeIfPresent([Friend].self, forKey: .friends) ?? d.friends
        guestbook = try c.decodeIfPresent([GuestEntry].self, forKey: .guestbook) ?? []
        nest = try c.decodeIfPresent([NestEgg].self, forKey: .nest) ?? []
        playdateDay = try c.decodeIfPresent(String.self, forKey: .playdateDay) ?? ""
        playdatesToday = try c.decodeIfPresent(Int.self, forKey: .playdatesToday) ?? 0
        lastVisitCheck = try c.decodeIfPresent(Date.self, forKey: .lastVisitCheck) ?? Date()
        appliedGifts = try c.decodeIfPresent([UUID].self, forKey: .appliedGifts) ?? []
        challengeDay = try c.decodeIfPresent(String.self, forKey: .challengeDay) ?? ""
        challenges = try c.decodeIfPresent([DailyChallenge].self, forKey: .challenges) ?? []
        streak = try c.decodeIfPresent(Int.self, forKey: .streak) ?? 0
        lastBonusDay = try c.decodeIfPresent(String.self, forKey: .lastBonusDay) ?? ""
        saveVersion = try c.decodeIfPresent(Int.self, forKey: .saveVersion) ?? 0
        hotelGuests = try c.decodeIfPresent(Int.self, forKey: .hotelGuests) ?? 0
    }
}

/// Outcome of giving a cat XP, used to drive level-up and evolve moments.
struct GrowthReport: Equatable {
    var xp: Int
    var levelsGained: Int
    var oldStage: Stage
    var newStage: Stage
    var evolved: Bool { newStage > oldStage }
}

/// A friend currently hanging out in your lounge.
struct Visitor: Equatable {
    var friendID: UUID
    var until: Date
    var bubble: String?
}

@MainActor
@Observable
final class GameStore {
    static let maxEggs = 4
    static let maxEnergy = 5
    static let energyRegenSeconds: Double = 60
    static let eggPrice = 60
    static let goldenEggPrice = 250
    static let playdatesPerDay = 3
    static let nestHours: Double = 24
    static let treatPrice = 10

    private(set) var data: SaveData
    var now = Date()
    var tab: Tab = .den
    /// Opens the battle arena inside the Play tab.
    var showArena = false
    /// A freshly hatched cat waiting to be named on the reveal screen.
    var pendingHatch: (cat: Cat, rarity: Rarity)?
    var visitor: Visitor?
    /// A friend who has asked for a playdate.
    var invite: UUID?
    /// Supabase + Game Center, when configured. Nil means offline practice friends.
    let online: OnlineService?
    var isOnline: Bool { online?.isLive == true }

    private let key = "kitten-hatchery-save-v1"

    init() {
        if let raw = UserDefaults.standard.data(forKey: key),
           let saved = try? JSONDecoder().decode(SaveData.self, from: raw) {
            data = saved
        } else {
            data = SaveData()
        }
        online = OnlineConfig.client.map { OnlineService(client: $0) }
        online?.store = self
        // Cats from before ages existed start counting today.
        if data.cats.contains(where: { $0.bornAt == nil }) {
            for i in data.cats.indices where data.cats[i].bornAt == nil { data.cats[i].bornAt = Date() }
            save()
        }
        refreshChallenges()
    }

    // MARK: Reads

    var cats: [Cat] { data.cats }
    var eggs: [Egg] { data.eggs }
    var coins: Int { data.coins }
    var energy: Int { data.energy }
    var activeCat: Cat? { data.cats.first { $0.id == data.activeCatID } ?? data.cats.first }
    var discovered: Set<Breed> { Set(data.cats.map(\.kind)) }
    var lounge: Lounge { data.lounge }
    /// Sam, Mia and Leo are practice characters for development; App Store builds don't show them.
    /// Only in dev mode; normal Debug builds behave like the App Store version.
    static let practiceFriends: Bool = DevMode.isOn

    var friends: [Friend] {
        if let online, online.isLive { return online.friends.map(\.asFriend) }
        return Self.practiceFriends ? data.friends : []
    }
    /// Whether there is anyone to visit or have a playdate with.
    var hasFriends: Bool { !friends.isEmpty }
    var guestbook: [GuestEntry] {
        if let online, online.isLive { return online.guestbook.map(\.asEntry) }
        return data.guestbook
    }
    var nest: [NestEgg] { data.nest }
    var unthanked: Int { guestbook.filter { !$0.thanked }.count }
    func friend(_ id: UUID) -> Friend? { friends.first { $0.id == id } }

    var secondsToNextEnergy: Double? {
        guard data.energy < Self.maxEnergy else { return nil }
        return max(0, Self.energyRegenSeconds - now.timeIntervalSince(data.energyStamp))
    }

    // MARK: Clock

    func tick() {
        now = Date()
        if data.energy < Self.maxEnergy {
            let gained = Int(now.timeIntervalSince(data.energyStamp) / Self.energyRegenSeconds)
            if gained > 0 {
                data.energy = min(Self.maxEnergy, data.energy + gained)
                data.energyStamp = data.energyStamp.addingTimeInterval(Double(gained) * Self.energyRegenSeconds)
                save()
            }
        }
        if data.nest.contains(where: { $0.expires < now }) {
            data.nest.removeAll { $0.expires < now }
            save()
        }
        if let v = visitor, v.until < now { visitor = nil }
        simulateFriends()
        refreshChallenges()
    }

    // MARK: Daily challenges

    var challenges: [DailyChallenge] { data.challenges }
    var bonusClaimedToday: Bool { data.lastBonusDay == ChallengeBook.dayKey() }
    /// Days in a row the daily bonus was collected (0 if the streak broke).
    var streak: Int {
        let yesterday = ChallengeBook.dayKey(Date().addingTimeInterval(-86400))
        return data.lastBonusDay == ChallengeBook.dayKey() || data.lastBonusDay == yesterday ? data.streak : 0
    }

    private func refreshChallenges() {
        let today = ChallengeBook.dayKey()
        // Friend challenges can't be done without friends, so swap today's set if it has any.
        let impossible = !hasFriends && data.challenges.contains { $0.kind.needsFriends && !$0.claimed }
        guard data.challengeDay != today || impossible else { return }
        data.challengeDay = today
        data.challenges = ChallengeBook.make(for: today, social: hasFriends)
        save()
    }

    /// Counts progress toward today's challenges.
    func record(_ kind: ChallengeKind, amount: Int = 1) {
        refreshChallenges()
        var changed = false
        for i in data.challenges.indices where data.challenges[i].kind == kind && !data.challenges[i].claimed {
            if kind == .highScore {
                if amount > data.challenges[i].progress { data.challenges[i].progress = amount; changed = true }
            } else {
                data.challenges[i].progress += amount
                changed = true
            }
        }
        if changed { save() }
    }

    func claim(_ id: UUID) {
        guard let i = data.challenges.firstIndex(where: { $0.id == id }),
              data.challenges[i].done, !data.challenges[i].claimed else { return }
        data.challenges[i].claimed = true
        data.coins += data.challenges[i].reward
        if data.challenges.allSatisfy(\.claimed), !bonusClaimedToday {
            data.streak = streak + 1
            data.lastBonusDay = ChallengeBook.dayKey()
            data.coins += ChallengeBook.bonus(streak: data.streak)
        }
        save()
    }

    // MARK: Cats

    func setActive(_ id: UUID) {
        data.activeCatID = id
        save()
    }

    func updateCat(_ id: UUID, _ change: (inout Cat) -> Void) {
        guard let i = data.cats.firstIndex(where: { $0.id == id }) else { return }
        change(&data.cats[i])
        save()
    }

    func grow(_ id: UUID, xp: Int) -> GrowthReport? {
        guard let i = data.cats.firstIndex(where: { $0.id == id }) else { return nil }
        let old = data.cats[i].stage
        let levels = data.cats[i].gainXP(xp)
        save()
        return GrowthReport(xp: xp, levelsGained: levels, oldStage: old, newStage: data.cats[i].stage)
    }

    func spendPoint(_ id: UUID, on kind: StatKind) {
        updateCat(id) { cat in
            guard cat.skillPoints > 0 else { return }
            cat.skillPoints -= 1
            cat.add(kind, kind.step)
        }
    }

    func toggleEquip(_ id: UUID, _ move: Move) {
        updateCat(id) { cat in
            guard cat.knows(move), move != .swipe else { return }
            if let i = cat.equipped.firstIndex(of: move) {
                cat.equipped.remove(at: i)
            } else if cat.equipped.count < 4 {
                cat.equipped.append(move)
            }
        }
    }

    // MARK: Economy

    func addCoins(_ n: Int) {
        data.coins += n
        save()
    }

    @discardableResult
    func spendCoins(_ n: Int) -> Bool {
        guard data.coins >= n else { return false }
        data.coins -= n
        save()
        return true
    }

    func spendEnergy() -> Bool {
        tick()
        guard data.energy > 0 else { return false }
        if data.energy == Self.maxEnergy { data.energyStamp = Date() }
        data.energy -= 1
        save()
        return true
    }

    // MARK: Eggs

    var hasFreeEggSlot: Bool { data.eggs.count < Self.maxEggs }

    /// Puts a won egg in the incubator, or in the nest when every slot is full.
    /// Returns true when it went to the nest.
    @discardableResult
    func addEgg(_ rarity: Rarity, source: String = "Found") -> Bool {
        if hasFreeEggSlot {
            data.eggs.append(Egg(rarity: rarity))
            save()
            return false
        }
        data.nest.append(NestEgg(egg: Egg(rarity: rarity), source: source,
                                 expires: Date().addingTimeInterval(Self.nestHours * 3600)))
        save()
        return true
    }

    /// Mystery eggs roll the normal odds; golden eggs are always rare or better.
    func buyEgg(golden: Bool = false) -> Rarity? {
        let price = golden ? Self.goldenEggPrice : Self.eggPrice
        guard hasFreeEggSlot, data.coins >= price else { return nil }
        data.coins -= price
        let rarity = golden ? max(.rare, Rarity.roll(luck: 0.12)) : Rarity.roll()
        addEgg(rarity)
        return rarity
    }

    /// Tapping an egg keeps it warm and shaves a little time off.
    func warm(_ id: UUID) {
        guard let i = data.eggs.firstIndex(where: { $0.id == id }) else { return }
        data.eggs[i].startedAt = data.eggs[i].startedAt.addingTimeInterval(-1.5)
        save()
    }

    func skipCost(_ egg: Egg) -> Int { Int((egg.remaining(now) / 3).rounded(.up)) }

    func hatch(_ id: UUID, paying: Bool = false) {
        guard let i = data.eggs.firstIndex(where: { $0.id == id }) else { return }
        let egg = data.eggs[i]
        if !egg.isReady(Date()) {
            guard paying, data.coins >= skipCost(egg) else { return }
            data.coins -= skipCost(egg)
        }
        data.eggs.remove(at: i)
        // The oldest nest egg takes the free slot and starts incubating.
        if !data.nest.isEmpty {
            let next = data.nest.removeFirst()
            data.eggs.append(Egg(rarity: next.egg.rarity))
        }
        save()
        let cat = egg.isStarter ? Cat.starter() : Cat.random(rarity: egg.rarity)
        pendingHatch = (cat, egg.rarity)
    }

    /// You can only have one cat of each breed.
    func owns(_ breed: Breed) -> Bool { data.cats.contains { $0.kind == breed } }

    static func hotelReward(_ rarity: Rarity) -> Int { [20, 40, 80, 150][rarity.index] }
    var hotelGuests: Int { data.hotelGuests }

    /// A duplicate kitten moves into the Kitty Hotel, which thanks you with coins.
    func sendToHotel(_ cat: Cat) {
        record(.hatchEgg)
        data.hotelGuests += 1
        data.coins += Self.hotelReward(cat.rarity)
        pendingHatch = nil
        save()
    }

    func adopt(_ cat: Cat) {
        record(.hatchEgg)
        data.cats.append(cat)
        if data.cats.count == 1 || data.activeCatID == nil { data.activeCatID = cat.id }
        pendingHatch = nil
        save()
    }

    func giftNestEgg(_ id: UUID, to friendID: UUID) {
        guard let i = data.nest.firstIndex(where: { $0.id == id }) else { return }
        data.nest.remove(at: i)
        befriend(friendID, 10)
    }

    // MARK: Lounge

    private func placementSpot(for kind: Furniture) -> (Double, Double) {
        kind.onWall ? (Double.random(in: 0.25...0.75), 0.24) : (Double.random(in: 0.25...0.75), 0.8)
    }

    // MARK: Shop

    static let dealDiscount = 0.3

    /// Two items are 30% off each day.
    var dailyDeals: [Furniture] {
        var rng = SeededRandom(seed: ChallengeBook.stableSeed("deals-" + ChallengeBook.dayKey()))
        var pool = Furniture.allCases
        var out: [Furniture] = []
        while out.count < 2 { out.append(pool.remove(at: Int(rng.next() % UInt64(pool.count)))) }
        return out
    }

    func price(_ kind: Furniture) -> Int {
        dailyDeals.contains(kind) ? Int((Double(kind.price) * (1 - Self.dealDiscount)).rounded()) : kind.price
    }

    func owned(_ kind: Furniture) -> Int {
        data.lounge.items.filter { $0.kind == kind }.count + data.lounge.stored.filter { $0 == kind }.count
    }

    /// Buys an item into lounge storage. Each item can be owned once.
    /// Returns false without enough coins or if you already own it.
    func buy(_ kind: Furniture) -> Bool {
        guard owned(kind) == 0, spendCoins(price(kind)) else { return false }
        data.lounge.stored.append(kind)
        record(.shop)
        save()
        return true
    }

    func setTint(_ id: UUID, _ tint: ItemTint) {
        guard let i = data.lounge.items.firstIndex(where: { $0.id == id }) else { return }
        data.lounge.items[i].tint = tint
        save()
    }

    func choosePattern(_ p: WallPattern) {
        if !data.lounge.ownedPatterns.contains(p) {
            guard spendCoins(p.price) else { return }
            data.lounge.ownedPatterns.append(p)
            record(.shop)
        }
        data.lounge.pattern = p
        save()
    }

    func renameLounge(first: Int, second: Int) {
        data.lounge.nameFirst = first
        data.lounge.nameSecond = second
        save()
    }

    func placeStored(_ kind: Furniture, tint: ItemTint? = nil) {
        guard let i = data.lounge.stored.firstIndex(of: kind) else { return }
        data.lounge.stored.remove(at: i)
        let (x, y) = placementSpot(for: kind)
        data.lounge.items.append(PlacedItem(kind: kind, x: x, y: y, tint: kind.tintable ? tint : nil))
        save()
    }

    func moveItem(_ id: UUID, x: Double, y: Double) {
        guard let i = data.lounge.items.firstIndex(where: { $0.id == id }) else { return }
        let (cx, cy) = Lounge.clamp(data.lounge.items[i].kind, x: x, y: y)
        data.lounge.items[i].x = cx
        data.lounge.items[i].y = cy
        save()
    }

    func flipItem(_ id: UUID) {
        guard let i = data.lounge.items.firstIndex(where: { $0.id == id }) else { return }
        data.lounge.items[i].flipped.toggle()
        save()
    }

    func storeItem(_ id: UUID) {
        guard let i = data.lounge.items.firstIndex(where: { $0.id == id }) else { return }
        data.lounge.stored.append(data.lounge.items.remove(at: i).kind)
        save()
    }

    /// Selects a wall colour, buying it first if needed.
    func chooseWall(_ w: WallStyle) {
        if !data.lounge.ownedWalls.contains(w) {
            guard spendCoins(w.price) else { return }
            data.lounge.ownedWalls.append(w)
            record(.shop)
        }
        data.lounge.wall = w
        save()
    }

    func chooseFloor(_ f: FloorStyle) {
        if !data.lounge.ownedFloors.contains(f) {
            guard spendCoins(f.price) else { return }
            data.lounge.ownedFloors.append(f)
            record(.shop)
        }
        data.lounge.floor = f
        save()
    }

    func thank(_ id: UUID) {
        if let online, online.isLive {
            online.thank(id)
            if let e = online.guestbook.first(where: { $0.id == id }),
               let f = online.friends.first(where: { $0.displayName == e.visitorName }) { online.bump(f.id, 2) }
            return
        }
        guard let i = data.guestbook.firstIndex(where: { $0.id == id }), !data.guestbook[i].thanked else { return }
        data.guestbook[i].thanked = true
        if let f = data.friends.first(where: { $0.name == data.guestbook[i].friendName }) { befriend(f.id, 2) }
        save()
    }

    // MARK: Friends

    func befriend(_ id: UUID, _ amount: Int) {
        if let online, online.isLive {
            online.bump(id, amount)
            return
        }
        guard let i = data.friends.firstIndex(where: { $0.id == id }) else { return }
        data.friends[i].friendship += amount
        save()
    }

    func giveTreat(to id: UUID) -> Bool {
        guard spendCoins(Self.treatPrice) else { return false }
        befriend(id, 3)
        if let online, online.isLive {
            Task { try? await online.sign(id, sticker: 4, phrase: nil, gift: "treat") }
        }
        return true
    }

    private var today: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    var playdatesLeft: Int {
        data.playdateDay == today ? max(0, Self.playdatesPerDay - data.playdatesToday) : Self.playdatesPerDay
    }

    func startPlaydate() -> Bool {
        guard playdatesLeft > 0 else { return false }
        if data.playdateDay != today {
            data.playdateDay = today
            data.playdatesToday = 0
        }
        data.playdatesToday += 1
        if invite != nil { invite = nil }
        save()
        return true
    }

    /// Rolls the playdate egg. Both players get the same tier.
    func finishPlaydate(friendID: UUID, odds: PlaydateOdds) -> PlaydateResult {
        record(.playdate)
        let friendship = 5
        befriend(friendID, friendship)
        var roll = Double.random(in: 0..<100)
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-lucky") { roll = 0 }
        #endif
        guard roll < Double(odds.total) else {
            return PlaydateResult(egg: nil, toNest: false, friendship: friendship)
        }
        let luck = Double(odds.total - 10) / 200
        let rarity = Rarity.roll(luck: luck)
        let name = friend(friendID)?.name ?? "a friend"
        let toNest = addEgg(rarity, source: "Playdate with \(name)")
        return PlaydateResult(egg: rarity, toNest: toNest, friendship: friendship)
    }

    /// Stand-in for the online service: friends drop by, sign the guestbook and ask for playdates.
    /// Gifts friends left in your guestbook boost your cats once.
    func applyGuestGifts(_ entries: [RemoteGuestEntry]) {
        var changed = false
        for e in entries where e.gift != nil && !data.appliedGifts.contains(e.id) {
            if let i = data.cats.indices.randomElement() {
                data.cats[i].add(e.gift == "treat" ? .charm : .speed, 1)
            }
            data.appliedGifts.append(e.id)
            changed = true
        }
        if changed { save() }
    }

    private func simulateFriends() {
        guard Self.practiceFriends, !isOnline, !data.cats.isEmpty, now.timeIntervalSince(data.lastVisitCheck) > 90 else { return }
        data.lastVisitCheck = now
        let online = data.friends.filter(\.online)
        guard let friend = online.randomElement(), Double.random(in: 0..<1) < 0.6 else { save(); return }
        var gift: String?
        if Double.random(in: 0..<1) < 0.45, let i = data.cats.indices.randomElement() {
            let stat: StatKind = Bool.random() ? .charm : .speed
            data.cats[i].add(stat, 1)
            gift = "\(stat == .charm ? "Treat" : "Yarn toy") for \(data.cats[i].name) · +1 \(stat.title)"
        }
        let notes = ["Left a paw sticker · \u{201C}\(Chat.phrases.randomElement()!)\u{201D}",
                     "Petted your cats", "Left a heart sticker · \u{201C}\(Chat.phrases.randomElement()!)\u{201D}"]
        data.guestbook.insert(GuestEntry(friendName: friend.name, breed: friend.star.kind, note: notes.randomElement()!, gift: gift), at: 0)
        if data.guestbook.count > 40 { data.guestbook.removeLast() }
        visitor = Visitor(friendID: friend.id, until: now.addingTimeInterval(180), bubble: Chat.phrases.randomElement())
        if invite == nil, Double.random(in: 0..<1) < 0.35 { invite = friend.id }
        save()
    }

    // MARK: Persistence

    var saveVersion: Int { data.saveVersion }

    private func save() {
        data.saveVersion += 1
        if let raw = try? JSONEncoder().encode(data) {
            UserDefaults.standard.set(raw, forKey: key)
        }
        online?.saveChanged()
        online?.pushProfile()
    }

    /// Replaces this phone's game with a newer copy from the cloud (after a reinstall, for example).
    func restoreFromCloud(_ saved: SaveData) {
        data = saved
        pendingHatch = nil
        visitor = nil
        if let raw = try? JSONEncoder().encode(data) {
            UserDefaults.standard.set(raw, forKey: key)
        }
    }

    #if DEBUG
    /// `-demo` launch argument: a mid-game save for screenshots and testing.
    func seedDemo() {
        var mochi = Cat.starter()
        mochi.gainXP(420)
        let cats = [mochi,
                    Cat.random(rarity: .basic, level: 2, name: "Pepper", breed: .tuxedo),
                    Cat.random(rarity: .rare, level: 4, name: "Sapphire", breed: .siamese),
                    Cat.random(rarity: .epic, level: 8, name: "Leo", breed: .maineCoon),
                    Cat.random(rarity: .legendary, level: 12, name: "Duchess", breed: .britishShorthair),
                    Cat.random(rarity: .legendary, level: 6, name: "Owlie", breed: .scottishFold)]
        // Varied ages for testing: 45 days, 2 days, 12 days, 5 months, 14 months, today.
        let ages = [45, 2, 12, 150, 420, 0]
        var aged = cats
        for i in aged.indices { aged[i].bornAt = Calendar.current.date(byAdding: .day, value: -ages[i % ages.count], to: Date()) }
        data = SaveData(cats: aged, activeCatID: mochi.id,
                        eggs: [Egg(rarity: .rare), Egg(rarity: .legendary, duration: 0), Egg(rarity: .epic), Egg(rarity: .basic)],
                        coins: 640, energy: 5, energyStamp: Date())
        var lounge = Lounge(items: [PlacedItem(kind: .window, x: 0.2, y: 0.22),
                                    PlacedItem(kind: .pawClock, x: 0.42, y: 0.2),
                                    PlacedItem(kind: .fairyLights, x: 0.5, y: 0.12),
                                    PlacedItem(kind: .breedShelf, x: 0.8, y: 0.3),
                                    PlacedItem(kind: .fireplace, x: 0.55, y: 0.66),
                                    PlacedItem(kind: .boxCastle, x: 0.14, y: 0.78),
                                    PlacedItem(kind: .monstera, x: 0.9, y: 0.7),
                                    PlacedItem(kind: .throne, x: 0.8, y: 0.84),
                                    PlacedItem(kind: .beanBag, x: 0.36, y: 0.95)],
                            wall: .blush, floor: .oak)
        lounge.stored = [.bookshelf, .plant, .rug]
        lounge.pattern = .paws
        lounge.ownedPatterns = [.plain, .paws]
        lounge.ownedWalls = [.cream, .blush]
        lounge.nameFirst = 2
        lounge.nameSecond = 2
        data.lounge = lounge
        data.challenges = ChallengeBook.make(for: ChallengeBook.dayKey(), social: true)
        data.challengeDay = ChallengeBook.dayKey()
        data.challenges[0].progress = data.challenges[0].target
        data.nest = [NestEgg(egg: Egg(rarity: .rare), source: "Playdate with Sam", expires: Date().addingTimeInterval(23 * 3600)),
                     NestEgg(egg: Egg(rarity: .legendary), source: "Won vs a tough rival", expires: Date().addingTimeInterval(6 * 3600))]
        data.guestbook = [GuestEntry(friendName: "Sam", breed: .siamese, note: "Left a paw sticker · \u{201C}Cute lounge!\u{201D}", gift: "Treat for Mochi · +1 Charm"),
                          GuestEntry(friendName: "Mia", breed: .scottishFold, note: "Petted your cats"),
                          GuestEntry(friendName: "Leo", breed: .britishShorthair, note: "Left a heart sticker · \u{201C}See you!\u{201D}", gift: "Yarn toy for Duchess · +1 Speed", thanked: true)]
        save()
    }

    func forceVisitor() {
        data.lastVisitCheck = .distantPast
        if let f = data.friends.first {
            visitor = Visitor(friendID: f.id, until: Date().addingTimeInterval(180), bubble: "Cute lounge!")
            invite = f.id
        }
    }

    // Dev panel helpers.
    func devFillEnergy() {
        data.energy = Self.maxEnergy
        data.energyStamp = Date()
        save()
    }

    func devFinishEggs() {
        for i in data.eggs.indices { data.eggs[i].startedAt = Date().addingTimeInterval(-data.eggs[i].duration - 1) }
        save()
    }

    func devFinishChallenges() {
        for i in data.challenges.indices where !data.challenges[i].claimed {
            data.challenges[i].progress = data.challenges[i].target
        }
        save()
    }

    func devResetSave() {
        data = SaveData()
        pendingHatch = nil
        visitor = nil
        invite = nil
        save()
    }
    #endif
}
