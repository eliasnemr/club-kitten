import Foundation
import Observation
import Supabase

// MARK: - Configuration

// Multiplayer is paused: the app runs locally with practice friends until Supabase keys are added.
// Resume with the checklist in ROADMAP.md (and MULTIPLAYER.md for the full steps).
#warning("Multiplayer paused — see ROADMAP.md to set up Supabase + Game Center")

enum OnlineConfig {
    /// Built from SUPABASE_PROJECT_REF / SUPABASE_ANON_KEY in Config/Secrets.xcconfig. Nil means offline practice mode.
    static let client: SupabaseClient? = {
        let info = Bundle.main.infoDictionary ?? [:]
        let ref = (info["SupabaseProjectRef"] as? String ?? "").trimmingCharacters(in: .whitespaces)
        let key = (info["SupabaseAnonKey"] as? String ?? "").trimmingCharacters(in: .whitespaces)
        guard !ref.isEmpty, !key.isEmpty else { return nil }
        let url = ref == "local" ? URL(string: "http://127.0.0.1:54321")! : URL(string: "https://\(ref).supabase.co")!
        return SupabaseClient(supabaseURL: url, supabaseKey: key)
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
    let visitorName: String
    let visitorShowcase: [Cat]
    let sticker: Int
    let phrase: Int?
    let gift: String?
    var thanked: Bool
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, sticker, phrase, gift, thanked
        case visitorName = "visitor_name", visitorShowcase = "visitor_showcase", createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
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
        return GuestEntry(id: id, friendName: visitorName, breed: visitorShowcase.first?.kind ?? .cream,
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

    enum CodingKeys: String, CodingKey {
        case id, status, bond, chance, result
        case hostID = "host_id", guestID = "guest_id", hostCat = "host_cat", guestCat = "guest_cat", startedAt = "started_at"
    }
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

    @ObservationIgnored weak var store: GameStore?
    @ObservationIgnored private var myLounge: RealtimeChannelV2?
    @ObservationIgnored private var inviteChannel: RealtimeChannelV2?
    @ObservationIgnored private var pushTask: Task<Void, Never>?

    init(client: SupabaseClient) {
        self.client = client
    }

    var isOnline: Bool { status == .online }

    func start() async {
        do {
            if client.auth.currentUser == nil {
                try await client.auth.signInAnonymously()
            }
            me = client.auth.currentUser?.id
            status = .online
        } catch {
            status = .failed("Couldn't reach the server: \(error.localizedDescription)")
            return
        }
        await linkGameCenter()
        await refresh()
        pushProfile()
        await openMyLounge()
        await watchInvites()
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
        if let g: [RemoteGuestEntry] = try? await client.rpc("my_guestbook").execute().value {
            guestbook = g
            store?.applyGuestGifts(g)
        }
        if let i: [RemotePlaydate] = try? await client.from("playdates").select()
            .eq("guest_id", value: me).eq("status", value: "invited")
            .gte("created_at", value: Date().addingTimeInterval(-900)).execute().value {
            invites = i
        }
        await claimEggs()
    }

    /// Sends your lounge and top five cats so friends see them when they visit. Debounced.
    func pushProfile() {
        guard isOnline, let me, let store else { return }
        pushTask?.cancel()
        let lounge = store.lounge
        let showcase = Array(store.cats.sorted { $0.rarity > $1.rarity || ($0.rarity == $1.rarity && $0.level > $1.level) }.prefix(5))
        pushTask = Task { [client] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            struct Update: Encodable {
                let lounge: Lounge
                let showcase: [Cat]
                let online_at: Date
                let updated_at: Date
            }
            _ = try? await client.from("profiles")
                .update(Update(lounge: lounge, showcase: showcase, online_at: Date(), updated_at: Date()))
                .eq("id", value: me).execute()
        }
    }

    func addFriend(code: String) async throws {
        _ = try await client.rpc("add_friend_by_code", params: ["p_code": code]).execute()
        await refresh()
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
                for j in joins where !list.contains(where: { $0.userID == j.userID }) { list.append(j) }
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
        await channel.subscribe()
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
        let inserts = channel.postgresChange(InsertAction.self, table: "playdates", filter: .eq("guest_id", value: me))
        Task { [weak self] in
            for await change in inserts {
                guard let self, let pd = try? change.decodeRecord(as: RemotePlaydate.self, decoder: .realtimeRows) else { continue }
                if pd.status == "invited" { self.invites.insert(pd, at: 0) }
            }
        }
        await channel.subscribe()
    }

    private struct InviteParams: Encodable { let p_friend: UUID; let p_cat: Cat; let p_rarity: Int }
    private struct AcceptParams: Encodable { let p_id: UUID; let p_cat: Cat; let p_rarity: Int }
    private struct ActParams: Encodable { let p_id: UUID; let p_activity: String }
    private struct IDParams: Encodable { let p_id: UUID }
    struct FinishResult: Decodable { let result: Int?; let chance: Int }

    func invite(_ friend: UUID, cat: Cat) async throws -> UUID {
        try await client.rpc("invite_playdate", params: InviteParams(p_friend: friend, p_cat: cat, p_rarity: cat.rarity.index)).execute().value
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
    @ObservationIgnored private let presence: LoungePresence
    @ObservationIgnored private weak var service: OnlineService?

    init(service: OnlineService, owner: UUID, cat: Cat) {
        self.service = service
        me = service.me ?? UUID()
        presence = LoungePresence(userID: me, name: service.myName, cat: cat)
        channel = service.client.channel("lounge:\(owner.uuidString.lowercased())") { $0.isPrivate = true }
    }

    func join() async {
        let changes = channel.presenceChange()
        let messages = channel.broadcastStream(event: "chat")
        Task { [weak self] in
            for await change in changes {
                guard let self else { return }
                let joins = (try? change.decodeJoins(as: LoungePresence.self)) ?? []
                let leaves = (try? change.decodeLeaves(as: LoungePresence.self)) ?? []
                var list = self.others.filter { o in !leaves.contains { $0.userID == o.userID } }
                for j in joins where j.userID != self.me && !list.contains(where: { $0.userID == j.userID }) { list.append(j) }
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
