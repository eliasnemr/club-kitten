import Foundation
import Observation
import Supabase

// MARK: - Configuration

// With Supabase keys the app gets cloud save. Multiplayer stays paused until SUPABASE_MULTIPLAYER = YES.
// Resume with the checklist in ROADMAP.md (and MULTIPLAYER.md for the full steps).
#warning("Multiplayer paused — see ROADMAP.md to set up Supabase + Game Center")

enum OnlineConfig {
    /// Built from SUPABASE_PROJECT_REF / SUPABASE_ANON_KEY in Config/Secrets.xcconfig. Nil means offline practice mode.
    static let client: SupabaseClient? = {
        let info = Bundle.main.infoDictionary ?? [:]
        let ref = (info["SupabaseProjectRef"] as? String ?? "").trimmingCharacters(in: .whitespaces)
        let key = (info["SupabaseAnonKey"] as? String ?? "").trimmingCharacters(in: .whitespaces)
        guard !ref.isEmpty, !key.isEmpty, !DevMode.isOn else { return nil }
        #if !DEBUG
        // The Supabase running on your Mac only exists in development; release builds stay offline.
        if ref == "local" { return nil }
        #endif
        let url = ref == "local" ? URL(string: "http://127.0.0.1:54321")! : URL(string: "https://\(ref).supabase.co")!
        return SupabaseClient(supabaseURL: url, supabaseKey: key)
    }()

    /// Friends, lounge visits and playdates. Off unless SUPABASE_MULTIPLAYER = YES.
    static let multiplayer: Bool = {
        let raw = (Bundle.main.infoDictionary?["SupabaseMultiplayer"] as? String ?? "").uppercased()
        return raw == "YES" || raw == "TRUE" || raw == "1"
    }()
}

// MARK: - Rows

struct RemoteFriend: Decodable, Identifiable, Equatable {
    let id: UUID
    let displayName: String
    let friendCode: String
    let lounge: Lounge?
    let showcase: [Cat]
    let onlineAt: Date
    var points: Int

    enum CodingKeys: String, CodingKey {
        case id, lounge, showcase, points
        case displayName = "display_name", friendCode = "friend_code", onlineAt = "online_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        displayName = try c.decode(String.self, forKey: .displayName)
        friendCode = try c.decode(String.self, forKey: .friendCode)
        lounge = try? c.decode(Lounge.self, forKey: .lounge)
        showcase = (try? c.decode([Cat].self, forKey: .showcase)) ?? []
        onlineAt = try c.decode(Date.self, forKey: .onlineAt)
        points = try c.decodeIfPresent(Int.self, forKey: .points) ?? 0
    }

    var isOnline: Bool { onlineAt > Date().addingTimeInterval(-300) }

    var asFriend: Friend {
        let cats = showcase.isEmpty ? [Cat.starter()] : showcase
        let ago = Date().timeIntervalSince(onlineAt)
        let status = isOnline ? "Online" : "Last seen \(formatDuration(ago)) ago"
        return Friend(id: id, name: displayName, code: friendCode, cats: cats, lounge: lounge ?? .starter,
                      online: isOnline, status: status, friendship: points)
    }
}

struct RemoteGuestEntry: Decodable, Identifiable, Equatable {
    let id: UUID
    let visitorID: UUID?
    let visitorName: String
    let visitorShowcase: [Cat]
    let sticker: Int
    let phrase: Int?
    let gift: String?
    var thanked: Bool
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, sticker, phrase, gift, thanked
        case visitorID = "visitor_id", visitorName = "visitor_name", visitorShowcase = "visitor_showcase", createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        visitorID = try c.decodeIfPresent(UUID.self, forKey: .visitorID)
        visitorName = try c.decode(String.self, forKey: .visitorName)
        visitorShowcase = (try? c.decode([Cat].self, forKey: .visitorShowcase)) ?? []
        sticker = try c.decode(Int.self, forKey: .sticker)
        phrase = try c.decodeIfPresent(Int.self, forKey: .phrase)
        gift = try c.decodeIfPresent(String.self, forKey: .gift)
        thanked = try c.decode(Bool.self, forKey: .thanked)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
    }

    var asEntry: GuestEntry {
        let stickerName = Chat.stickers[min(max(sticker, 0), Chat.stickers.count - 1)]
        let quote = phrase.map { " · \u{201C}\(Chat.phrases[min(max($0, 0), Chat.phrases.count - 1)])\u{201D}" } ?? ""
        let giftText = gift.map { $0 == "treat" ? "Treat · +1 Charm" : "Yarn toy · +1 Speed" }
        return GuestEntry(id: id, friendID: visitorID, friendName: visitorName, breed: visitorShowcase.first?.kind ?? .cream,
                          note: "Left a \(stickerName) sticker\(quote)", gift: giftText, date: createdAt, thanked: thanked)
    }
}

struct RemotePlaydate: Decodable, Identifiable, Equatable {
    let id: UUID
    let hostID: UUID
    let guestID: UUID
    let hostCat: Cat
    let guestCat: Cat?
    let status: String
    let bond: Int
    let startedAt: Date?
    let chance: Int?
    let result: Int?
    /// Who sent the invite; only filled in by `my_invites`, not by realtime rows.
    let hostName: String?
    let hostShowcase: [Cat]?

    enum CodingKeys: String, CodingKey {
        case id, status, bond, chance, result
        case hostID = "host_id", guestID = "guest_id", hostCat = "host_cat", guestCat = "guest_cat", startedAt = "started_at"
        case hostName = "host_name", hostShowcase = "host_showcase"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        hostID = try c.decode(UUID.self, forKey: .hostID)
        guestID = try c.decode(UUID.self, forKey: .guestID)
        hostCat = try c.decode(Cat.self, forKey: .hostCat)
        guestCat = try? c.decodeIfPresent(Cat.self, forKey: .guestCat)
        status = try c.decode(String.self, forKey: .status)
        bond = try c.decode(Int.self, forKey: .bond)
        startedAt = try c.decodeIfPresent(Date.self, forKey: .startedAt)
        chance = try c.decodeIfPresent(Int.self, forKey: .chance)
        result = try c.decodeIfPresent(Int.self, forKey: .result)
        hostName = try c.decodeIfPresent(String.self, forKey: .hostName)
        hostShowcase = try? c.decodeIfPresent([Cat].self, forKey: .hostShowcase)
    }
}

/// A friend request to you (incoming) or from you.
struct FriendRequest: Decodable, Identifiable, Equatable {
    let playerID: UUID
    let displayName: String
    let showcase: [Cat]
    let incoming: Bool
    var id: UUID { playerID }
    var star: Cat { showcase.first ?? .starter() }

    enum CodingKeys: String, CodingKey {
        case showcase, incoming
        case playerID = "player_id", displayName = "display_name"
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        playerID = try c.decode(UUID.self, forKey: .playerID)
        displayName = try c.decode(String.self, forKey: .displayName)
        showcase = (try? c.decode([Cat].self, forKey: .showcase)) ?? []
        incoming = try c.decode(Bool.self, forKey: .incoming)
    }
}

/// Someone you might know: a friend of a friend, or a player you met in the arena.
struct SuggestedPlayer: Decodable, Identifiable, Equatable {
    let playerID: UUID
    let displayName: String
    let star: Cat?
    let mutualFriends: Int
    let metInArena: Bool
    var id: UUID { playerID }

    enum CodingKeys: String, CodingKey {
        case star
        case playerID = "player_id", displayName = "display_name", mutualFriends = "mutual_friends", metInArena = "met_in_arena"
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        playerID = try c.decode(UUID.self, forKey: .playerID)
        displayName = try c.decode(String.self, forKey: .displayName)
        star = try? c.decodeIfPresent(Cat.self, forKey: .star)
        mutualFriends = try c.decode(Int.self, forKey: .mutualFriends)
        metInArena = try c.decode(Bool.self, forKey: .metInArena)
    }

    var why: String {
        if mutualFriends > 0 { return mutualFriends == 1 ? "1 friend in common" : "\(mutualFriends) friends in common" }
        return metInArena ? "You met in the arena" : "Plays Club Kitten"
    }
}

/// Another player's cat waiting in the arena.
struct ArenaDefender: Decodable, Identifiable, Equatable {
    let userID: UUID
    let displayName: String
    let cat: Cat
    let level: Int
    let wins: Int
    let losses: Int
    var id: UUID { userID }
    enum CodingKeys: String, CodingKey {
        case cat, level, wins, losses
        case userID = "user_id", displayName = "display_name"
    }
}

/// Your own cat in the arena and how it's doing.
struct MyDefender: Decodable, Equatable {
    let cat: Cat
    let level: Int
    let wins: Int
    let losses: Int
    let coinsEarned: Int
    enum CodingKeys: String, CodingKey {
        case cat, level, wins, losses
        case coinsEarned = "coins_earned"
    }
}

struct BlockedPlayer: Decodable, Identifiable, Equatable {
    let id: UUID
    let displayName: String
    enum CodingKeys: String, CodingKey { case id, displayName = "display_name" }
}

/// Why a player is being reported. Stored as the raw value on the server.
enum ReportReason: String, CaseIterable, Identifiable {
    case name, mean, cheating, other
    var id: String { rawValue }
    var title: String {
        switch self {
        case .name: "Inappropriate name"
        case .mean: "Mean or bullying"
        case .cheating: "Cheating"
        case .other: "Something else"
        }
    }
}

/// Where the report was made from.
enum ReportContext: String {
    case friends, lounge, guestbook, playdate, invite
}

struct EggGrant: Decodable {
    let rarity: Int
    let source: String
}

struct LoungePresence: Codable, Equatable {
    let userID: UUID
    let name: String
    let cat: Cat
}

struct ChatMessage: Codable, Equatable {
    let from: UUID
    let phrase: Int?
    let emote: Int?

    /// Only indexes travel over the network; the text and icons come from the app's own lists.
    var bubble: Bubble? {
        if let p = phrase, Chat.phrases.indices.contains(p) { return Bubble(text: Chat.phrases[p]) }
        if let e = emote, Chat.emotes.indices.contains(e) { return Bubble(symbol: Chat.emotes[e].icon) }
        return nil
    }
}

extension JSONDecoder {
    /// Realtime rows carry Postgres timestamps, sometimes with a space instead of "T" and a short offset.
    static let realtimeRows: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let raw = try decoder.singleValueContainer().decode(String.self)
            var text = raw.replacingOccurrences(of: " ", with: "T")
            if let r = text.range(of: #"[+-]\d{2}$"#, options: .regularExpression) { text.replaceSubrange(r, with: text[r] + ":00") }
            let withFraction = ISO8601DateFormatter()
            withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = withFraction.date(from: text) ?? ISO8601DateFormatter().date(from: text) { return date }
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Bad date \(raw)"))
        }
        return d
    }()
}

extension Rarity {
    var index: Int { Rarity.allCases.firstIndex(of: self)! }
    init(index: Int) { self = Rarity.allCases[min(max(index, 0), 3)] }
}

// MARK: - Service

@MainActor
@Observable
final class OnlineService {
    enum Status: Equatable {
        case connecting
        case online
        case failed(String)
    }

    let client: SupabaseClient
    private(set) var status: Status = .connecting
    private(set) var me: UUID?
    private(set) var myName = "Kitten keeper"
    private(set) var friendCode: String?
    private(set) var gameCenterLinked = false
    private(set) var friends: [RemoteFriend] = []
    private(set) var guestbook: [RemoteGuestEntry] = []
    private(set) var invites: [RemotePlaydate] = []
    /// Friends currently standing in your lounge.
    private(set) var visitors: [LoungePresence] = []
    private(set) var visitorChat: [UUID: ChatMessage] = [:]
    /// Players you blocked. They can't see you, visit or invite you.
    private(set) var blocked: [BlockedPlayer] = []
    private(set) var requests: [FriendRequest] = []
    private(set) var suggestions: [SuggestedPlayer] = []
    /// Your cat in the arena, if you've put one there.
    private(set) var myDefender: MyDefender?
    /// An invite link opened before sign-in finished; redeemed once online.
    @ObservationIgnored private var pendingInvite: String?
    @ObservationIgnored private var requestChannel: RealtimeChannelV2?

    @ObservationIgnored weak var store: GameStore?
    @ObservationIgnored private var myLounge: RealtimeChannelV2?
    @ObservationIgnored private var inviteChannel: RealtimeChannelV2?
    @ObservationIgnored private var pushTask: Task<Void, Never>?
    @ObservationIgnored private var lastActiveRefresh: Date?

    /// Friends, lounges and playdates are only live when multiplayer is switched on.
    let multiplayer: Bool

    // Cloud save
    enum SyncState: Equatable { case idle, syncing, synced(Date), failed }
    private(set) var sync: SyncState = .idle
    @ObservationIgnored private var syncReady = false
    @ObservationIgnored private var saveTask: Task<Void, Never>?

    init(client: SupabaseClient, multiplayer: Bool = OnlineConfig.multiplayer) {
        self.client = client
        self.multiplayer = multiplayer
    }

    /// Signed in to the server (cloud save works).
    var isOnline: Bool { status == .online }
    /// Signed in and multiplayer switched on.
    var isLive: Bool { isOnline && multiplayer }

    func start() async {
        do {
            // Reuse the saved session (kept in the Keychain) or start a new anonymous account.
            if let session = try? await client.auth.session {
                me = session.user.id
            } else {
                me = try await client.auth.signInAnonymously().user.id
            }
            status = .online
        } catch {
            status = .failed("Couldn't reach the server: \(error.localizedDescription)")
            sync = .failed
            return
        }
        await syncOnLaunch()
        guard multiplayer else { return }
        // Listen first, so invites and visitors arrive even while Game Center is still
        // signing in (its sign-in sheet can take a while, or never be answered).
        await openMyLounge()
        await watchInvites()
        await watchRequests()
        await refresh()
        if let code = pendingInvite {
            pendingInvite = nil
            await redeemInvite(code)
        }
        pushProfile()
        Task {
            await linkGameCenter()
            if gameCenterLinked { await refresh() }
        }
    }

    /// The app came back to the foreground: realtime can miss changes made while it was
    /// suspended, so fetch friends' lounges and invites again.
    func becameActive() async {
        guard isLive, me != nil else { return }
        if let last = lastActiveRefresh, Date().timeIntervalSince(last) < 5 { return }
        lastActiveRefresh = Date()
        await refresh()
    }

    // MARK: Cloud save

    private struct SaveRow: Decodable {
        let data: AnyJSON
        let version: Int
    }
    private struct PushParams: Encodable {
        let p_data: AnyJSON
        let p_version: Int
        let p_device: String
    }
    private struct PushResult: Decodable {
        let accepted: Bool
        let version: Int
    }

    /// Only the platform is sent, not a per-device ID, so the App Privacy answers stay
    /// User ID + Gameplay Content.
    private static let platform = "ios"

    /// On launch: restore a newer save from the server (a reinstall or restored account),
    /// or upload this phone's save if it is newer.
    func syncOnLaunch() async {
        guard let me, store != nil else { debugLog("not signed in yet"); return }
        debugLog("syncing as \(me)")
        sync = .syncing
        do {
            let remote = try await fetchRemote(me)
            guard let store else { return }
            if let remote, !hasSynced(me) || remote.version > store.saveVersion {
                // A phone that has never synced this account (a reinstall or new phone) always
                // takes the server's copy, so a fresh starter save can never overwrite real progress.
                try restore(remote)
                markSynced(me)
                syncReady = true
                sync = .synced(Date())
            } else if remote == nil || store.saveVersion > remote!.version {
                syncReady = true
                try await upload()
                markSynced(me)
            } else {
                syncReady = true
                markSynced(me)
                sync = .synced(Date())
            }
        } catch {
            syncReady = true
            sync = .failed
            debugLog("sync on launch failed: \(error)")
        }
    }

    private func fetchRemote(_ me: UUID) async throws -> SaveRow? {
        let rows: [SaveRow] = try await client.from("saves").select("data, version")
            .eq("user_id", value: me).execute().value
        return rows.first
    }

    private func restore(_ remote: SaveRow) throws {
        let raw = try JSONEncoder().encode(remote.data)
        var restored = try JSONDecoder().decode(SaveData.self, from: raw)
        restored.saveVersion = remote.version
        store?.restoreFromCloud(restored)
        debugLog("restored version \(remote.version)")
    }

    /// Whether this install has synced with this account before (kept outside the save itself).
    private func hasSynced(_ me: UUID) -> Bool { UserDefaults.standard.bool(forKey: "club-kitten-synced-\(me)") }
    private func markSynced(_ me: UUID) { UserDefaults.standard.set(true, forKey: "club-kitten-synced-\(me)") }

    private func debugLog(_ text: String) {
        #if DEBUG
        print("[cloud save] \(text)")
        #endif
    }

    /// Called after every local save; uploads a few seconds later so bursts of changes send once.
    func saveChanged() {
        guard syncReady, isOnline else { return }
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            try? await upload()
        }
    }

    /// Uploads right away, for when the app goes to the background.
    func flushSave() {
        guard syncReady, isOnline else { return }
        saveTask?.cancel()
        saveTask = Task { try? await upload() }
    }

    private func upload() async throws {
        guard let store else { return }
        sync = .syncing
        do {
            let raw = try JSONEncoder().encode(store.data)
            let json = try JSONDecoder().decode(AnyJSON.self, from: raw)
            let r: PushResult = try await client.rpc("push_save", params: PushParams(
                p_data: json, p_version: store.saveVersion, p_device: Self.platform)).execute().value
            if !r.accepted {
                // The server already has this version or a newer one (from another device): take it
                // instead of retrying, so two copies can't bounce back and forth.
                if let me, let remote = try await fetchRemote(me) { try restore(remote) }
                sync = .synced(Date())
                return
            }
            debugLog("uploaded version \(r.version)")
            sync = .synced(Date())
        } catch {
            sync = .failed
            debugLog("upload failed: \(error)")
            throw error
        }
    }

    // MARK: Game Center

    func linkGameCenter() async {
        guard await GameCenter.shared.authenticate() else { return }
        do {
            let identity = try await GameCenter.shared.identity()
            try await client.functions.invoke("link-game-center", options: .init(body: identity))
            myName = identity.displayName
            gameCenterLinked = true
            let ids = await GameCenter.shared.friendIDs()
            if !ids.isEmpty {
                try await client.rpc("link_game_center_friends", params: ["p_ids": ids]).execute()
            }
        } catch {
            gameCenterLinked = false
        }
    }

    // MARK: Profile, friends, guestbook, eggs

    struct Profile: Decodable {
        let displayName: String
        let friendCode: String
        enum CodingKeys: String, CodingKey { case displayName = "display_name", friendCode = "friend_code" }
    }

    func refresh() async {
        guard let me else { return }
        if let p: Profile = try? await client.from("profiles").select("display_name, friend_code").eq("id", value: me).single().execute().value {
            friendCode = p.friendCode
            myName = p.displayName
        }
        if let f: [RemoteFriend] = try? await client.rpc("list_friends").execute().value { friends = f }
        if let b: [BlockedPlayer] = try? await client.rpc("list_blocked").execute().value { blocked = b }
        if let g: [RemoteGuestEntry] = try? await client.rpc("my_guestbook").execute().value {
            guestbook = g
            store?.applyGuestGifts(g)
        }
        await refreshInvites()
        await refreshRequests()
        await refreshArena()
        await claimEggs()
        await claimCoins()
    }

    /// Open invites to you, each with the sender's name, so none are hidden while the
    /// friends list is still catching up.
    func refreshInvites() async {
        guard me != nil else { return }
        if let i: [RemotePlaydate] = try? await client.rpc("my_invites").execute().value { invites = i }
    }

    /// Fetches one friend's latest lounge and cats, for when you visit them.
    func refreshFriend(_ id: UUID) async {
        guard isLive else { return }
        guard let rows: [RemoteFriend] = try? await client.rpc("friend_profile", params: ["p_id": id]).execute().value,
              let fresh = rows.first else { return }
        if let i = friends.firstIndex(where: { $0.id == id }) { friends[i] = fresh } else { friends.append(fresh) }
    }

    /// Sends your lounge and top five cats so friends see them when they visit. Debounced,
    /// unless `now` (used when the app goes to the background).
    func pushProfile(now: Bool = false) {
        guard isLive, let me, let store else { return }
        pushTask?.cancel()
        let lounge = store.lounge
        let showcase = Array(store.cats.sorted { $0.rarity > $1.rarity || ($0.rarity == $1.rarity && $0.level > $1.level) }.prefix(5))
        let channel = myLounge
        pushTask = Task { [client] in
            if !now { try? await Task.sleep(for: .seconds(2)) }
            guard !Task.isCancelled else { return }
            struct Update: Encodable {
                let lounge: Lounge
                let showcase: [Cat]
                let online_at: Date
                let updated_at: Date
            }
            do {
                try await client.from("profiles")
                    .update(Update(lounge: lounge, showcase: showcase, online_at: Date(), updated_at: Date()))
                    .eq("id", value: me).execute()
                // Friends standing in your lounge reload it, so they see changes as you make them.
                try? await channel?.broadcast(event: "lounge-updated", message: ["at": Date().timeIntervalSince1970])
            } catch {
                #if DEBUG
                print("[online] profile push failed: \(error)")
                #endif
            }
        }
    }

    // MARK: Safety

    private struct PlayerParam: Encodable { let p_player: UUID }
    private struct ReportParams: Encodable { let p_player: UUID; let p_reason: String; let p_context: String }

    /// Blocks a player: removes the friendship on the server and hides them everywhere here.
    func block(_ player: UUID) async throws {
        try await client.rpc("block_player", params: PlayerParam(p_player: player)).execute()
        friends.removeAll { $0.id == player }
        invites.removeAll { $0.hostID == player }
        visitors.removeAll { $0.userID == player }
        guestbook.removeAll { $0.visitorID == player }
        await refresh()
    }

    func unblock(_ player: UUID) async throws {
        try await client.rpc("unblock_player", params: PlayerParam(p_player: player)).execute()
        blocked.removeAll { $0.id == player }
    }

    func report(_ player: UUID, reason: ReportReason, context: ReportContext) async throws {
        try await client.rpc("report_player", params: ReportParams(
            p_player: player, p_reason: reason.rawValue, p_context: context.rawValue)).execute()
    }

    func isBlocked(_ player: UUID) -> Bool { blocked.contains { $0.id == player } }

    // MARK: Account deletion

    /// Deletes the account and everything stored with it on the server, signs out,
    /// and starts a fresh anonymous account for a brand-new game.
    func deleteAccount() async throws {
        try await client.rpc("delete_my_account").execute()
        if let me { UserDefaults.standard.removeObject(forKey: "club-kitten-synced-\(me)") }
        try? await client.auth.signOut()
        me = nil
        friendCode = nil
        gameCenterLinked = false
        friends = []
        guestbook = []
        invites = []
        requests = []
        suggestions = []
        myDefender = nil
        visitors = []
        blocked = []
        syncReady = false
        sync = .idle
        status = .connecting
        store?.eraseEverything()
        // Start the fresh account in the background; Game Center sign-in can take a while
        // and the deletion itself is already done.
        Task { await start() }
    }

    // MARK: Friend requests, invite links and suggestions

    enum AddResult { case requested(String), friends(String) }
    private struct CodeResult: Decodable {
        let status: String
        let displayName: String
        enum CodingKeys: String, CodingKey { case status, displayName = "display_name" }
    }

    /// Typing someone's friend code sends them a request (or makes you friends if they asked you first).
    func addFriend(code: String) async throws -> AddResult {
        PushCenter.shared.askIfNeeded()
        let rows: [CodeResult] = try await client.rpc("request_friend_by_code", params: ["p_code": code]).execute().value
        guard let r = rows.first else { throw URLError(.badServerResponse) }
        await refresh()
        return r.status == "friends" ? .friends(r.displayName) : .requested(r.displayName)
    }

    /// Sends a request to a player you met in the arena or a suggested player.
    func requestFriend(_ player: UUID) async throws -> Bool {
        PushCenter.shared.askIfNeeded()
        let status: String = try await client.rpc("request_friend", params: ["p_player": player]).execute().value
        suggestions.removeAll { $0.id == player }
        await refresh()
        return status == "friends"
    }

    private struct RespondParams: Encodable { let p_from: UUID; let p_accept: Bool }

    func respond(to request: FriendRequest, accept: Bool) async {
        requests.removeAll { $0.id == request.id }
        _ = try? await client.rpc("respond_friend_request", params: RespondParams(p_from: request.playerID, p_accept: accept)).execute()
        await refresh()
    }

    private struct DeviceParams: Encodable { let p_token: String; let p_env: String }

    func registerDevice(token: String, env: String) async {
        _ = try? await client.rpc("register_device", params: DeviceParams(p_token: token, p_env: env)).execute()
    }

    func cancelRequest(to player: UUID) async {
        requests.removeAll { $0.id == player }
        _ = try? await client.rpc("cancel_friend_request", params: ["p_to": player]).execute()
    }

    func refreshRequests() async {
        guard me != nil else { return }
        if let r: [FriendRequest] = try? await client.rpc("my_friend_requests").execute().value { requests = r }
        if let s: [SuggestedPlayer] = try? await client.rpc("suggested_players", params: ["p_limit": 8]).execute().value { suggestions = s }
    }

    private struct Redeemed: Decodable {
        let displayName: String
        enum CodingKeys: String, CodingKey { case displayName = "display_name" }
    }

    /// Opening a friend's invite link makes you friends straight away.
    func redeemInvite(_ code: String) async {
        guard isLive, me != nil else { pendingInvite = code; return }
        do {
            let rows: [Redeemed] = try await client.rpc("redeem_invite", params: ["p_code": code]).execute().value
            await refresh()
            if let name = rows.first?.displayName { store?.toast("You and \(name) are now friends! 🐾") }
        } catch {
            store?.toast("That invite link didn't work. Ask your friend for a new one.")
        }
    }

    private func watchRequests() async {
        guard let me else { return }
        let id = me.uuidString.lowercased()
        let channel = client.channel("requests:\(id)")
        requestChannel = channel
        let incoming = channel.postgresChange(AnyAction.self, table: "friend_requests", filter: .eq("to_id", value: id))
        let outgoing = channel.postgresChange(AnyAction.self, table: "friend_requests", filter: .eq("from_id", value: id))
        Task { [weak self] in
            for await _ in incoming { await self?.refresh() }
        }
        Task { [weak self] in
            // An outgoing request disappearing usually means they accepted: reload friends.
            for await _ in outgoing { await self?.refresh() }
        }
        do { try await channel.subscribeWithError() } catch { debugLog("request channel failed: \(error)") }
    }

    // MARK: Arena

    private struct DefenderParams: Encodable { let p_cat: Cat; let p_level: Int }
    private struct ReportArenaParams: Encodable { let p_defender: UUID; let p_defender_won: Bool }

    func refreshArena() async {
        guard let me else { return }
        let rows: [MyDefender]? = try? await client.from("arena_defenders")
            .select("cat, level, wins, losses, coins_earned").eq("user_id", value: me).execute().value
        myDefender = rows?.first
    }

    func setDefender(_ cat: Cat) async throws {
        PushCenter.shared.askIfNeeded()
        try await client.rpc("set_defender", params: DefenderParams(p_cat: cat, p_level: cat.level)).execute()
        await refreshArena()
    }

    func clearDefender() async {
        myDefender = nil
        _ = try? await client.rpc("clear_defender").execute()
    }

    /// Real players' defenders near your level.
    func arenaOpponents(level: Int) async -> [ArenaDefender] {
        (try? await client.rpc("arena_opponents", params: ["p_level": level]).execute().value) ?? []
    }

    func reportArena(defender: UUID, defenderWon: Bool) {
        Task { [client] in
            _ = try? await client.rpc("report_arena_result", params: ReportArenaParams(p_defender: defender, p_defender_won: defenderWon)).execute()
        }
    }

    private struct CoinGrant: Decodable { let amount: Int; let source: String }

    /// Coins your defender won while you were away.
    func claimCoins() async {
        guard let grants: [CoinGrant] = try? await client.rpc("claim_coins").execute().value, !grants.isEmpty else { return }
        let total = grants.reduce(0) { $0 + $1.amount }
        let wins = grants.filter { $0.source == "arena" }.count
        store?.addCoins(total)
        let name = myDefender?.cat.name ?? "Your defender"
        store?.toast(wins > 0 ? "\(name) won \(wins) arena \(wins == 1 ? "battle" : "battles") for you: +\(total) coins"
                               : "+\(total) coins")
        await refreshArena()
    }

    func bump(_ friend: UUID, _ amount: Int) {
        if let i = friends.firstIndex(where: { $0.id == friend }) { friends[i].points += min(amount, 5) }
        Task { [client] in
            _ = try? await client.rpc("bump_friendship", params: BumpParams(p_friend: friend, p_amount: amount)).execute()
        }
    }

    private struct BumpParams: Encodable { let p_friend: UUID; let p_amount: Int }

    func sign(_ owner: UUID, sticker: Int, phrase: Int?, gift: String?) async throws {
        guard let me else { return }
        struct Row: Encodable { let owner_id: UUID; let visitor_id: UUID; let sticker: Int; let phrase: Int?; let gift: String? }
        try await client.from("guestbook").insert(Row(owner_id: owner, visitor_id: me, sticker: sticker, phrase: phrase, gift: gift)).execute()
    }

    func thank(_ id: UUID) {
        if let i = guestbook.firstIndex(where: { $0.id == id }) { guestbook[i].thanked = true }
        Task { [client] in
            _ = try? await client.from("guestbook").update(["thanked": true]).eq("id", value: id).execute()
        }
    }

    func claimEggs() async {
        guard let grants: [EggGrant] = try? await client.rpc("claim_eggs").execute().value else { return }
        for g in grants { store?.addEgg(Rarity(index: g.rarity), source: g.source) }
    }

    // MARK: Lounges

    private func openMyLounge() async {
        guard let me else { return }
        let channel = client.channel("lounge:\(me.uuidString.lowercased())") { $0.isPrivate = true }
        myLounge = channel
        let presence = channel.presenceChange()
        let chat = channel.broadcastStream(event: "chat")
        Task { [weak self] in
            for await change in presence {
                guard let self else { return }
                let joins = (try? change.decodeJoins(as: LoungePresence.self)) ?? []
                let leaves = (try? change.decodeLeaves(as: LoungePresence.self)) ?? []
                var list = self.visitors.filter { v in !leaves.contains { $0.userID == v.userID } }
                for j in joins where !list.contains(where: { $0.userID == j.userID }) && !self.isBlocked(j.userID) { list.append(j) }
                self.visitors = list
            }
        }
        Task { [weak self] in
            for await msg in chat {
                guard let self, let m = Self.decodeChat(msg) else { continue }
                self.visitorChat[m.from] = m
                try? await Task.sleep(for: .seconds(3))
                if self.visitorChat[m.from] == m { self.visitorChat[m.from] = nil }
            }
        }
        do { try await channel.subscribeWithError() } catch { debugLog("my lounge channel failed: \(error)") }
    }

    nonisolated static func decodeChat(_ msg: JSONObject) -> ChatMessage? {
        // Broadcast payloads arrive wrapped as {"event": ..., "payload": {...}}.
        let payload = msg["payload"]?.objectValue ?? msg
        guard let data = try? JSONEncoder().encode(payload) else { return nil }
        return try? JSONDecoder().decode(ChatMessage.self, from: data)
    }

    func visit(_ friend: UUID, as cat: Cat) -> LoungeSession {
        LoungeSession(service: self, owner: friend, cat: cat)
    }

    // MARK: Playdates

    private func watchInvites() async {
        guard let me else { return }
        let channel = client.channel("invites:\(me.uuidString.lowercased())")
        inviteChannel = channel
        let id = me.uuidString.lowercased()
        // New invites, and invites that were cancelled, accepted or expired.
        let changes = channel.postgresChange(AnyAction.self, table: "playdates", filter: .eq("guest_id", value: id))
        Task { [weak self] in
            for await _ in changes {
                guard let self else { return }
                // Fetch through my_invites so each invite carries its sender's name.
                await self.refreshInvites()
                if self.invites.contains(where: { inv in !self.friends.contains { $0.id == inv.hostID } }) {
                    await self.refresh()
                }
            }
        }
        do { try await channel.subscribeWithError() } catch { debugLog("invite channel failed: \(error)") }
    }

    /// The friend who sent an invite, even if they aren't in the friends list yet.
    func host(of invite: RemotePlaydate) -> Friend {
        if let f = friends.first(where: { $0.id == invite.hostID }) { return f.asFriend }
        let cats = invite.hostShowcase?.isEmpty == false ? invite.hostShowcase! : [invite.hostCat]
        return Friend(id: invite.hostID, name: invite.hostName ?? "A friend", code: "", cats: cats,
                      lounge: .starter, online: true, status: "Online", friendship: 0)
    }

    private struct InviteParams: Encodable { let p_friend: UUID; let p_cat: Cat; let p_rarity: Int }
    private struct AcceptParams: Encodable { let p_id: UUID; let p_cat: Cat; let p_rarity: Int }
    private struct ActParams: Encodable { let p_id: UUID; let p_activity: String }
    private struct IDParams: Encodable { let p_id: UUID }
    struct FinishResult: Decodable { let result: Int?; let chance: Int }

    func invite(_ friend: UUID, cat: Cat) async throws -> UUID {
        PushCenter.shared.askIfNeeded()
        return try await client.rpc("invite_playdate", params: InviteParams(p_friend: friend, p_cat: cat, p_rarity: cat.rarity.index)).execute().value
    }

    func accept(_ id: UUID, cat: Cat) async throws {
        try await client.rpc("accept_playdate", params: AcceptParams(p_id: id, p_cat: cat, p_rarity: cat.rarity.index)).execute()
        invites.removeAll { $0.id == id }
    }

    func decline(_ id: UUID) {
        invites.removeAll { $0.id == id }
        Task { [client] in _ = try? await client.rpc("decline_playdate", params: IDParams(p_id: id)).execute() }
    }

    func act(_ id: UUID, _ activity: PlaydateActivity) async throws -> Int {
        try await client.rpc("playdate_act", params: ActParams(p_id: id, p_activity: activity.rawValue)).execute().value
    }

    func finish(_ id: UUID) async throws -> FinishResult {
        let r: FinishResult = try await client.rpc("finish_playdate", params: IDParams(p_id: id)).execute().value
        await claimEggs()
        return r
    }

    func playdate(_ id: UUID) async -> RemotePlaydate? {
        try? await client.from("playdates").select().eq("id", value: id).single().execute().value
    }

    /// Live updates to one playdate row: acceptance, bond changes and the result.
    func playdateUpdates(_ id: UUID) -> (RealtimeChannelV2, AsyncStream<RemotePlaydate>) {
        let channel = client.channel("playdate:\(id.uuidString.lowercased())")
        let updates = channel.postgresChange(UpdateAction.self, table: "playdates", filter: .eq("id", value: id))
        let stream = AsyncStream<RemotePlaydate> { cont in
            let task = Task {
                for await u in updates {
                    if let pd = try? u.decodeRecord(as: RemotePlaydate.self, decoder: .realtimeRows) { cont.yield(pd) }
                }
                cont.finish()
            }
            cont.onTermination = { _ in task.cancel() }
        }
        return (channel, stream)
    }
}

/// You standing in a friend's lounge: presence of everyone there and safe-chat messages.
@MainActor
@Observable
final class LoungeSession {
    private(set) var others: [LoungePresence] = []
    private(set) var chat: [UUID: ChatMessage] = [:]
    private(set) var connected = false

    @ObservationIgnored private let channel: RealtimeChannelV2
    @ObservationIgnored private let me: UUID
    @ObservationIgnored private let owner: UUID
    @ObservationIgnored private let presence: LoungePresence
    @ObservationIgnored private weak var service: OnlineService?

    init(service: OnlineService, owner: UUID, cat: Cat) {
        self.service = service
        me = service.me ?? UUID()
        self.owner = owner
        presence = LoungePresence(userID: me, name: service.myName, cat: cat)
        channel = service.client.channel("lounge:\(owner.uuidString.lowercased())") { $0.isPrivate = true }
    }

    func join() async {
        let changes = channel.presenceChange()
        let messages = channel.broadcastStream(event: "chat")
        let updates = channel.broadcastStream(event: "lounge-updated")
        Task { [weak self] in
            for await _ in updates {
                guard let self else { return }
                await self.service?.refreshFriend(self.owner)
            }
        }
        Task { [weak self] in
            for await change in changes {
                guard let self else { return }
                let joins = (try? change.decodeJoins(as: LoungePresence.self)) ?? []
                let leaves = (try? change.decodeLeaves(as: LoungePresence.self)) ?? []
                var list = self.others.filter { o in !leaves.contains { $0.userID == o.userID } }
                for j in joins where j.userID != self.me && !list.contains(where: { $0.userID == j.userID })
                    && self.service?.isBlocked(j.userID) != true { list.append(j) }
                self.others = list
            }
        }
        Task { [weak self] in
            for await msg in messages {
                guard let self, let m = OnlineService.decodeChat(msg), m.from != self.me else { continue }
                self.chat[m.from] = m
                try? await Task.sleep(for: .seconds(3))
                if self.chat[m.from] == m { self.chat[m.from] = nil }
            }
        }
        do {
            try await channel.subscribeWithError()
            try await channel.track(presence)
            connected = true
        } catch {
            connected = false
        }
    }

    func say(phrase: Int? = nil, emote: Int? = nil) async {
        try? await channel.broadcast(event: "chat", message: ChatMessage(from: me, phrase: phrase, emote: emote))
    }

    func leave() async {
        await channel.untrack()
        await service?.client.removeChannel(channel)
    }
}
