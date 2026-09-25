import SwiftUI

// MARK: - My lounge (tab root)

struct LoungeView: View {
    @Environment(GameStore.self) private var store
    @State private var showDecorate = false
    @State private var showShop = false
    @State private var showGuestbook = false
    @State private var showFriends = false
    @State private var playdate: Friend?
    @State private var request: PlaydateRequest?
    @State private var limitAlert = false

    var body: some View {
        NavigationStack {
            Screen {
                ScreenHeader(eyebrow: "Your lounge", title: store.lounge.name) {
                    Pill(icon: "person.2.fill", text: "\(guests.count) visiting")
                }
                if store.cats.isEmpty {
                    NoCatYet()
                } else {
                    RoomView(lounge: store.lounge, residents: store.cats, guests: guests, height: 400,
                             bubbles: bubbles, shelfBreeds: shelfBreeds, portrait: store.activeCat?.kind,
                             onPetCat: { cat in if store.cats.contains(where: { $0.id == cat.id }) { store.record(.petCats) } })
                    if let online = store.online, online.isLive {
                        if let v = online.visitors.first, let f = store.friend(v.userID) { visitorBanner(f) }
                    } else if let v = store.visitor, let f = store.friend(v.friendID) {
                        visitorBanner(f)
                    }
                    HStack(spacing: 10) {
                        ActionTile(icon: "bag.fill", title: "Shop") { showShop = true }
                        ActionTile(icon: "paintbrush.fill", title: "Decorate", badge: store.lounge.stored.count) { showDecorate = true }
                        ActionTile(icon: "book.closed.fill", title: "Guests", badge: store.unthanked) { showGuestbook = true }
                        ActionTile(icon: "person.2.fill", title: "Friends") { showFriends = true }
                    }
                    Text("Your cats wander here. Tap one to pet it. Friends who drop by can pet them and leave gifts.")
                        .font(Theme.font(13)).foregroundStyle(Theme.muted)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $showFriends) { FriendsView() }
        }
        .fullScreenCover(isPresented: $showDecorate) { DecorateView() }
        .fullScreenCover(isPresented: $showShop) {
            ShopView(placeNow: { kind, tint in
                store.placeStored(kind, tint: tint)
                showShop = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { showDecorate = true }
            })
        }
        .sheet(isPresented: $showGuestbook) { GuestbookView().presentationDragIndicator(.visible) }
        .fullScreenCover(item: $playdate) { f in
            if let cat = store.activeCat { PlaydateView(friendID: f.id, myCat: cat, theirCat: f.star) }
        }
        .fullScreenCover(item: $request) { r in
            if let cat = store.activeCat { OnlinePlaydateView(friend: r.friend, myCat: cat, invite: r.invite) }
        }
        .alert("No playdates left today", isPresented: $limitAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("You get \(GameStore.playdatesPerDay) playdates a day. Come back tomorrow!")
        }
        #if DEBUG
        .onAppear {
            let args = ProcessInfo.processInfo.arguments
            if args.contains("-decorate") { showDecorate = true }
            if args.contains("-shop") { showShop = true }
            if args.contains("-guestbook") { showGuestbook = true }
            if args.contains("-friends") { showFriends = true }
        }
        #endif
    }

    private var shelfBreeds: [Breed] {
        Breed.allCases.reversed().filter { store.discovered.contains($0) }
    }

    private var guests: [RoomGuest] {
        if let online = store.online, online.isLive {
            return online.visitors.map { RoomGuest(cat: $0.cat, label: $0.name) }
        }
        guard let v = store.visitor, let f = store.friend(v.friendID) else { return [] }
        return [RoomGuest(cat: f.star, label: "\(f.name)'s \(f.star.name)")]
    }

    private var bubbles: [UUID: Bubble] {
        if let online = store.online, online.isLive {
            var out: [UUID: Bubble] = [:]
            for v in online.visitors { if let m = online.visitorChat[v.userID] { out[v.cat.id] = m.bubble } }
            return out
        }
        guard let v = store.visitor, let f = store.friend(v.friendID), let text = v.bubble else { return [:] }
        return [f.star.id: Bubble(text: text)]
    }

    private func visitorBanner(_ f: Friend) -> some View {
        Button {
            if store.isOnline {
                request = PlaydateRequest(friend: f, invite: nil)
            } else if store.startPlaydate() {
                Haptics.tap(.medium)
                playdate = f
            } else {
                limitAlert = true
            }
        } label: {
            HStack(spacing: 12) {
                CatAvatar(cat: f.star, size: 46)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(f.name) is hanging out with you").font(Theme.font(15, .bold))
                    Text("Start a playdate for a chance at an egg · \(store.playdatesLeft) left today")
                        .font(Theme.font(12)).foregroundStyle(Theme.muted)
                }
                Spacer(minLength: 0)
                Text("Start").font(Theme.font(14, .heavy)).foregroundStyle(Theme.rose)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.roseTint))
        }
        .buttonStyle(PressableStyle())
        .foregroundStyle(Theme.text)
    }
}

struct CatAvatar: View {
    let cat: Cat
    var size: CGFloat = 48
    var ring: Color? = nil

    var body: some View {
        Image(cat.kind.imageName).resizable().scaledToFit()
            .frame(width: size * 0.92)
            .offset(y: size * 0.1)
            .frame(width: size, height: size)
            .background(Theme.beige)
            .clipShape(Circle())
            .overlay(Circle().stroke(ring ?? .clear, lineWidth: 2))
    }
}

// MARK: - Guestbook

struct GuestbookView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let week = store.guestbook.filter { $0.date > Date().addingTimeInterval(-7 * 86400) }
        Screen {
            ScreenHeader(eyebrow: "Your lounge", title: "Guestbook") {
                Pill(icon: "book.closed.fill", text: "\(store.unthanked) new")
            }
            Card {
                Text("This week").font(Theme.font(17, .bold))
                HStack(spacing: 12) {
                    stat("\(week.count)", "visits")
                    stat("\(week.filter { $0.gift != nil }.count)", "gifts")
                    stat("\(Set(week.map(\.friendName)).count)", "friends")
                }
                Text("Gifts from visitors give your cats small stat boosts. Thanking a friend raises your friendship.")
                    .font(Theme.font(12)).foregroundStyle(Theme.muted)
            }
            if store.guestbook.isEmpty {
                Text("No visitors yet. Friends drop by while you play.").font(Theme.font(14)).foregroundStyle(Theme.muted)
                    .frame(maxWidth: .infinity).padding(.vertical, 30)
            }
            ForEach(store.guestbook) { entry in
                Card(padding: 12) {
                    HStack(spacing: 12) {
                        Image(entry.breed.imageName).resizable().scaledToFit().frame(width: 44)
                            .frame(width: 50, height: 50).background(Circle().fill(Theme.beige)).clipShape(Circle())
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text(entry.friendName).font(Theme.font(15, .bold))
                                Text(entry.date, style: .relative).font(Theme.font(11)).foregroundStyle(Theme.muted)
                            }
                            Text(entry.note).font(Theme.font(12)).foregroundStyle(Theme.muted)
                            if let gift = entry.gift {
                                Label(gift, systemImage: "gift.fill").font(Theme.font(12, .semibold)).foregroundStyle(Theme.rose)
                            }
                        }
                        Spacer(minLength: 0)
                        Button(entry.thanked ? "Thanked" : "Thank") {
                            Haptics.tap()
                            store.thank(entry.id)
                        }
                        .font(Theme.font(13, .bold))
                        .foregroundStyle(entry.thanked ? Theme.muted : Theme.rose)
                        .padding(.horizontal, 12).frame(height: 36)
                        .overlay(Capsule().stroke(entry.thanked ? Theme.border : Theme.rose, lineWidth: 1.5))
                        .disabled(entry.thanked)
                    }
                }
            }
            Button("Done") { dismiss() }.buttonStyle(SecondaryButtonStyle())
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(Theme.font(22, .heavy))
            Text(label).font(Theme.font(12)).foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.beige))
    }
}

// MARK: - Friends

struct FriendsView: View {
    @Environment(GameStore.self) private var store
    @State private var playdate: Friend?
    @State private var limitAlert = false
    @State private var debugVisit = false
    @State private var request: PlaydateRequest?

    var body: some View {
        Screen {
            ScreenHeader(eyebrow: "Social", title: "Friends") {
                if !store.isOnline {
                    Pill(icon: "heart.fill", text: "\(store.playdatesLeft) / \(GameStore.playdatesPerDay) playdates")
                }
            }
            OnlineStatusCard()
            if let online = store.online, online.isLive {
                ForEach(online.invites) { inv in
                    if let f = store.friend(inv.hostID) { onlineInvite(inv, from: f) }
                }
            } else if let id = store.invite, let f = store.friend(id) {
                Button {
                    if store.startPlaydate() { playdate = f } else { limitAlert = true }
                } label: {
                    HStack(spacing: 12) {
                        CatAvatar(cat: f.star, size: 48, ring: .white)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(f.name) invited you to a playdate").font(Theme.font(15, .bold))
                            Text("\(f.star.name) (\(f.star.rarity.title)) wants to meet \(store.activeCat?.name ?? "your cat")")
                                .font(Theme.font(12)).opacity(0.9)
                        }
                        Spacer(minLength: 0)
                        Text("Join").font(Theme.font(15, .heavy))
                    }
                    .foregroundStyle(.white)
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.rose))
                }
                .buttonStyle(PressableStyle())
            }
            Text("Friends").font(Theme.font(17, .bold))
            if store.friends.isEmpty {
                Text("No friends yet. Share your code or add a friend's code above.")
                    .font(Theme.font(14)).foregroundStyle(Theme.muted).padding(.vertical, 12)
            }
            ForEach(store.friends) { f in
                Card(padding: 12) {
                    HStack(spacing: 12) {
                        CatAvatar(cat: f.star, size: 52)
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Text(f.name).font(Theme.font(16, .bold))
                                Circle().fill(f.online ? Theme.success : Theme.border).frame(width: 9, height: 9)
                                    .accessibilityLabel(f.online ? "online" : "offline")
                            }
                            Text(f.status).font(Theme.font(12)).foregroundStyle(Theme.muted)
                            HStack(spacing: 6) {
                                Text("Friendship Lv \(f.level)").font(Theme.font(11, .semibold)).foregroundStyle(Theme.muted)
                                Capsule().fill(Theme.beige).frame(width: 60, height: 6)
                                    .overlay(alignment: .leading) { Capsule().fill(Theme.rose).frame(width: 60 * f.progress, height: 6) }
                            }
                        }
                        Spacer(minLength: 0)
                        NavigationLink {
                            VisitView(friendID: f.id)
                        } label: {
                            Text("Visit").font(Theme.font(14, .bold)).foregroundStyle(Theme.text)
                                .padding(.horizontal, 16).frame(height: 40)
                                .overlay(Capsule().stroke(Theme.border, lineWidth: 1))
                        }
                    }
                }
            }
            if !store.isOnline {
                Text("Sam, Mia and Leo are in-game pals who live in the neighbourhood. You get \(GameStore.playdatesPerDay) playdates a day.")
                    .font(Theme.font(12)).foregroundStyle(Theme.muted)
            } else {
                Text("\(GameStore.playdatesPerDay) playdates a day. Chat uses preset phrases only.")
                    .font(Theme.font(12)).foregroundStyle(Theme.muted)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $debugVisit) { VisitView(friendID: store.friends[0].id) }
        #if DEBUG
        .onAppear {
            let args = ProcessInfo.processInfo.arguments
            if args.contains("-visit") { debugVisit = true }
            if args.contains("-playdate") { playdate = store.friends.first }
        }
        #endif
        .fullScreenCover(item: $playdate) { f in
            if let cat = store.activeCat { PlaydateView(friendID: f.id, myCat: cat, theirCat: f.star) }
        }
        .fullScreenCover(item: $request) { r in
            if let cat = store.activeCat { OnlinePlaydateView(friend: r.friend, myCat: cat, invite: r.invite) }
        }
        .refreshable { await store.online?.refresh() }
        .alert("No playdates left today", isPresented: $limitAlert) {
            Button("OK", role: .cancel) {}
        }
    }
}

extension FriendsView {
    func onlineInvite(_ inv: RemotePlaydate, from f: Friend) -> some View {
        HStack(spacing: 12) {
            CatAvatar(cat: inv.hostCat, size: 48, ring: .white)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(f.name) invited you to a playdate").font(Theme.font(15, .bold))
                Text("\(inv.hostCat.name) (\(inv.hostCat.rarity.title)) wants to meet \(store.activeCat?.name ?? "your cat")")
                    .font(Theme.font(12)).opacity(0.9)
            }
            Spacer(minLength: 0)
            VStack(spacing: 6) {
                Button("Join") { request = PlaydateRequest(friend: f, invite: inv) }
                    .font(Theme.font(15, .heavy))
                Button("Not now") { store.online?.decline(inv.id) }
                    .font(Theme.font(11, .semibold)).opacity(0.85)
            }
        }
        .foregroundStyle(.white)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.rose))
    }
}

// MARK: - Visiting a friend

struct VisitView: View {
    @Environment(GameStore.self) private var store
    let friendID: UUID
    @State private var bubbles: [UUID: Bubble] = [:]
    @State private var pets = 0
    @State private var signed = false
    @State private var toast: String?
    @State private var playdate = false
    @State private var request: PlaydateRequest?
    @State private var limitAlert = false
    @State private var session: LoungeSession?
    @State private var lastPhrase: Int?

    var body: some View {
        if let f = store.friend(friendID), let me = store.activeCat {
            Screen {
                ScreenHeader(eyebrow: "Visiting", title: "\(f.name)'s lounge") {
                    Pill(icon: "person.2.fill", text: "\(visitors(me).count) visiting")
                }
                RoomView(lounge: f.lounge, residents: f.cats, guests: visitors(me),
                         height: 340, bubbles: allBubbles, shelfBreeds: f.cats.map(\.kind), portrait: f.star.kind, onPetCat: { cat in pet(cat, friend: f) })
                if let toast {
                    Text(toast).font(Theme.font(13, .semibold)).foregroundStyle(Theme.rose)
                        .frame(maxWidth: .infinity).transition(.opacity)
                }
                Card {
                    HStack {
                        Text("Say something").font(Theme.font(16, .bold))
                        Spacer()
                        Text("Safe chat · pick a phrase").font(Theme.font(12)).foregroundStyle(Theme.muted)
                    }
                    ScrollView(.horizontal) {
                        HStack(spacing: 8) {
                            ForEach(Array(Chat.phrases.enumerated()), id: \.offset) { i, p in
                                Button(p) { lastPhrase = i; say(Bubble(text: p), me: me, friend: f, phrase: i) }
                                    .font(Theme.font(13, .semibold)).foregroundStyle(Theme.text)
                                    .padding(.horizontal, 14).frame(height: 38)
                                    .background(Capsule().fill(Theme.beige))
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                    HStack(spacing: 8) {
                        ForEach(Array(Chat.emotes.enumerated()), id: \.offset) { i, e in
                            Button {
                                say(Bubble(symbol: e.icon), me: me, friend: f, emote: i)
                            } label: {
                                Image(systemName: e.icon).font(.system(size: 18))
                                    .frame(width: 44, height: 44).background(Circle().fill(Theme.beige))
                                    .foregroundStyle(Theme.text)
                            }
                            .accessibilityLabel(e.label)
                        }
                    }
                }
                HStack(spacing: 10) {
                    ActionTile(icon: "pawprint.fill", title: "Pet") { pet(f.star, friend: f) }
                    ActionTile(icon: "gift.fill", title: "Treat · \(GameStore.treatPrice)") {
                        if store.giveTreat(to: f.id) {
                            Haptics.success()
                            show("\(f.star.name) loved the treat! Friendship +3")
                        } else {
                            Haptics.warning()
                            show("You need \(GameStore.treatPrice) coins")
                        }
                    }
                    ActionTile(icon: "book.closed.fill", title: signed ? "Signed" : "Sign book") {
                        guard !signed else { return }
                        signed = true
                        store.befriend(f.id, 1)
                        if let online = store.online, online.isLive {
                            let phrase = lastPhrase
                            Task { try? await online.sign(f.id, sticker: Int.random(in: 0..<Chat.stickers.count), phrase: phrase, gift: nil) }
                        }
                        Haptics.success()
                        show("You signed \(f.name)'s guestbook")
                    }
                }
                if store.isOnline {
                    Button("Invite \(f.name) to a playdate") { request = PlaydateRequest(friend: f, invite: nil) }
                        .buttonStyle(PrimaryButtonStyle())
                    Text(session?.connected == true ? "You're live in \(f.name)'s lounge. \(f.name) gets your invite right away."
                                                   : "Connecting to the lounge…")
                        .font(Theme.font(12)).foregroundStyle(Theme.muted).frame(maxWidth: .infinity)
                } else {
                    Button(f.online ? "Ask for a playdate" : "\(f.name) is offline") {
                        if store.startPlaydate() { playdate = true } else { limitAlert = true }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(!f.online)
                    Text(f.online ? "\(store.playdatesLeft) of \(GameStore.playdatesPerDay) playdates left today" : "Playdates need you both online.")
                        .font(Theme.font(12)).foregroundStyle(Theme.muted).frame(maxWidth: .infinity)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .fullScreenCover(isPresented: $playdate) {
                PlaydateView(friendID: f.id, myCat: me, theirCat: f.star)
            }
            .fullScreenCover(item: $request) { r in
                OnlinePlaydateView(friend: r.friend, myCat: me, invite: nil)
            }
            .onAppear { store.record(.visitFriend) }
            .task {
                guard let online = store.online, online.isLive, session == nil else { return }
                let s = online.visit(f.id, as: me)
                session = s
                await s.join()
            }
            .onDisappear {
                if let s = session { Task { await s.leave() } }
                session = nil
            }
            .alert("No playdates left today", isPresented: $limitAlert) {
                Button("OK", role: .cancel) {}
            }
        }
    }

    private func visitors(_ me: Cat) -> [RoomGuest] {
        [RoomGuest(cat: me, label: "You · \(me.name)", isYou: true)]
            + (session?.others ?? []).map { RoomGuest(cat: $0.cat, label: $0.name) }
    }

    private var allBubbles: [UUID: Bubble] {
        var out = bubbles
        for o in session?.others ?? [] { if let m = session?.chat[o.userID] { out[o.cat.id] = m.bubble } }
        return out
    }

    private func say(_ bubble: Bubble, me: Cat, friend: Friend, phrase: Int? = nil, emote: Int? = nil) {
        Haptics.tap()
        withAnimation(.spring(response: 0.3)) { bubbles[me.id] = bubble }
        if let session {
            // Real players answer for themselves; no pretend replies online.
            Task {
                await session.say(phrase: phrase, emote: emote)
                try? await Task.sleep(for: .seconds(3))
                withAnimation { if bubbles[me.id] == bubble { bubbles[me.id] = nil } }
            }
            return
        }
        let replyCat = friend.cats.randomElement() ?? friend.star
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.2))
            let reply = bubble.text == "Playdate?" ? "Yes please!" : Chat.replies.randomElement()!
            withAnimation(.spring(response: 0.3)) { bubbles[replyCat.id] = Bubble(text: reply) }
            try? await Task.sleep(for: .seconds(2.5))
            withAnimation { bubbles[me.id] = nil; bubbles[replyCat.id] = nil }
        }
    }

    private func pet(_ cat: Cat, friend: Friend) {
        guard friend.cats.contains(where: { $0.id == cat.id }) else { return }
        pets += 1
        if pets <= 5 {
            store.befriend(friend.id, 1)
            if pets == 5 { show("\(cat.name) is purring. Friendship +5 this visit") }
        }
        withAnimation(.spring(response: 0.3)) { bubbles[cat.id] = Bubble(symbol: "heart.fill") }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.2))
            withAnimation { bubbles[cat.id] = nil }
        }
    }

    private func show(_ text: String) {
        withAnimation { toast = text }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.5))
            withAnimation { if toast == text { toast = nil } }
        }
    }
}

// MARK: - Playdate

struct PlaydateView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let friendID: UUID
    let myCat: Cat
    let theirCat: Cat

    static let duration: Double = 60

    @State private var start = Date()
    @State private var bond = 10
    @State private var cooldowns: [PlaydateActivity: Date] = [:]
    @State private var bubbles: [UUID: Bubble] = [:]
    @State private var log = "Your cats are sniffing each other..."
    @State private var result: PlaydateResult?
    @State private var finalOdds: PlaydateOdds?

    private var friend: Friend? { store.friend(friendID) }
    private var odds: PlaydateOdds {
        PlaydateOdds.make(mine: myCat, theirs: theirCat, bond: bond, friendLevel: friend?.level ?? 1)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let result { resultView(result) } else { liveView }
            }
            .padding(20)
        }
        .scrollIndicators(.hidden)
        .foregroundStyle(Theme.text)
        .background(Theme.cream.ignoresSafeArea())
        .task { await friendPlays() }
        #if DEBUG
        .task {
            guard ProcessInfo.processInfo.arguments.contains("-autoplay") else { return }
            for a in PlaydateActivity.allCases {
                try? await Task.sleep(for: .seconds(0.8))
                act(a)
            }
            try? await Task.sleep(for: .seconds(1.5))
            finish()
        }
        #endif
    }

    private var liveView: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("PLAYDATE WITH \(friend?.name.uppercased() ?? "")").font(Theme.font(12, .bold)).tracking(0.6).foregroundStyle(Theme.muted)
                    Text("\(myCat.name) + \(theirCat.name)").font(Theme.font(26, .heavy)).lineLimit(1).minimumScaleFactor(0.7)
                }
                Spacer()
                TimelineView(.periodic(from: start, by: 1)) { ctx in
                    let left = max(0, Self.duration - ctx.date.timeIntervalSince(start))
                    Pill(icon: "clock", text: formatTime(left), tint: left < 10 ? Theme.rose : Theme.text)
                        .onChange(of: left == 0) { _, done in if done { finish() } }
                }
            }
            RoomView(lounge: store.lounge, residents: [],
                     guests: [RoomGuest(cat: myCat, label: "You · \(myCat.name)", isYou: true),
                              RoomGuest(cat: theirCat, label: "\(friend?.name ?? "")'s \(theirCat.name)")],
                     height: 280, bubbles: bubbles,
                     shelfBreeds: Breed.allCases.reversed().filter { store.discovered.contains($0) })
                .overlay(alignment: .top) {
                    Text(log).font(Theme.font(13, .semibold)).padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Capsule().fill(.white.opacity(0.92))).padding(10)
                }
            Card {
                HStack {
                    Text("Bond").font(Theme.font(14, .bold))
                    Spacer()
                    Text("\(bond) / 100").font(Theme.font(13, .semibold)).foregroundStyle(Theme.muted).monospacedDigit()
                }
                StatBar(label: "", value: Double(bond), max: 100, color: Theme.rose)
                    .animation(.easeOut, value: bond)
                Divider()
                ForEach(Array(odds.lines.enumerated()), id: \.offset) { _, line in
                    HStack { Text(line.0); Spacer(); Text("+\(line.1)%") }
                        .font(Theme.font(13)).foregroundStyle(Theme.muted)
                }
                HStack { Text("Egg chance when the timer ends"); Spacer(); Text("\(odds.total)%") }
                    .font(Theme.font(14, .heavy))
            }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(PlaydateActivity.allCases) { a in activityButton(a) }
            }
            Button("End playdate now") { finish() }
                .font(Theme.font(14, .bold)).foregroundStyle(Theme.muted).frame(maxWidth: .infinity, minHeight: 44)
        }
    }

    private func activityButton(_ a: PlaydateActivity) -> some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { ctx in
            let ready = (cooldowns[a] ?? .distantPast) <= ctx.date
            Button {
                act(a)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: a.icon).font(.system(size: 18, weight: .semibold)).foregroundStyle(Theme.rose).frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(a.title).font(Theme.font(14, .bold))
                        Text(ready ? "+\(a.bond) bond\(a.cost > 0 ? " · \(a.cost) coins" : "")"
                                   : "Again in \(Int(((cooldowns[a] ?? ctx.date).timeIntervalSince(ctx.date)).rounded(.up)))s")
                            .font(Theme.font(11)).foregroundStyle(Theme.muted)
                    }
                    Spacer(minLength: 0)
                }
                .padding(12)
                .frame(maxWidth: .infinity, minHeight: 60)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.white))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.border, lineWidth: 1))
                .opacity(ready ? 1 : 0.5)
            }
            .buttonStyle(PressableStyle())
            .foregroundStyle(Theme.text)
            .disabled(!ready || bond >= 100)
        }
    }

    private func act(_ a: PlaydateActivity) {
        if a.cost > 0 && !store.spendCoins(a.cost) {
            Haptics.warning()
            log = "You need \(a.cost) coins to swap treats"
            return
        }
        Haptics.tap(.medium)
        cooldowns[a] = Date().addingTimeInterval(a.cooldown)
        withAnimation { bond = min(100, bond + a.bond) }
        log = "\(myCat.name) and \(theirCat.name): \(a.title.lowercased())!"
        flash(myCat.id, a == .nap ? "moon.zzz.fill" : "heart.fill")
        flash(theirCat.id, "heart.fill")
    }

    private func flash(_ id: UUID, _ symbol: String) {
        withAnimation(.spring(response: 0.3)) { bubbles[id] = Bubble(symbol: symbol) }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.4))
            withAnimation { bubbles[id] = nil }
        }
    }

    /// Stand-in for the other player: they join in every few seconds.
    private func friendPlays() async {
        while !Task.isCancelled && result == nil {
            try? await Task.sleep(for: .seconds(Double.random(in: 4...7)))
            guard result == nil, let f = friend else { return }
            let a = PlaydateActivity.allCases.filter { $0 != .treats }.randomElement()!
            withAnimation { bond = min(100, bond + a.bond / 2) }
            log = "\(f.name) chose \(a.title.lowercased())"
            flash(theirCat.id, Bool.random() ? "heart.fill" : "pawprint.fill")
        }
    }

    private func finish() {
        guard result == nil else { return }
        let o = odds
        finalOdds = o
        let r = store.finishPlaydate(friendID: friendID, odds: o)
        r.egg == nil ? Haptics.tap(.medium) : Haptics.success()
        withAnimation(.easeInOut) { result = r }
    }

    @ViewBuilder
    private func resultView(_ r: PlaydateResult) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("PLAYDATE OVER").font(Theme.font(12, .bold)).tracking(0.6).foregroundStyle(Theme.muted)
            Text(r.egg == nil ? "What a fun playdate" : "You found an egg!").font(Theme.font(28, .heavy))
        }
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Theme.beige)
            HStack(alignment: .bottom, spacing: -10) {
                CatSprite(cat: myCat, size: 130, mood: .happy)
                if let egg = r.egg {
                    VStack(spacing: 8) {
                        EggView(rarity: egg, size: 96)
                        Tag(text: "\(egg.title) egg", color: egg.color, filled: egg == .legendary)
                    }
                    .padding(.bottom, 30)
                    .zIndex(1)
                } else {
                    Image(systemName: "heart.fill").font(.system(size: 36)).foregroundStyle(Theme.rose).padding(.bottom, 80)
                }
                CatSprite(cat: theirCat, size: 130, mood: .happy)
            }
            .padding(.bottom, 16)
            if r.egg != nil { ConfettiView() }
        }
        .frame(height: 280)
        Card {
            if let egg = r.egg {
                HStack(spacing: 8) {
                    CatAvatar(cat: myCat, size: 40)
                    CatAvatar(cat: theirCat, size: 40)
                    Text("You and \(friend?.name ?? "your friend") both get \(egg == .epic ? "an" : "a") \(egg.title) egg")
                        .font(Theme.font(15, .bold))
                }
                Text(r.toNest ? "Your incubator is full, so it's waiting in the egg nest for 24 hours."
                              : "It's warming up in your hatchery now.")
                    .font(Theme.font(13)).foregroundStyle(Theme.muted)
            } else {
                Text("No egg this time (\(finalOdds?.total ?? 0)% chance). A stronger bond and rarer cats raise the odds.")
                    .font(Theme.font(14)).foregroundStyle(Theme.muted)
            }
            if let f = friend {
                HStack {
                    Text("Friendship with \(f.name)").font(Theme.font(13, .semibold))
                    Spacer()
                    Text("Lv \(f.level) · +\(r.friendship)").font(Theme.font(13, .bold)).foregroundStyle(Theme.rose)
                }
                StatBar(label: "", value: f.progress, max: 1, color: Theme.text)
            }
        }
        if r.egg != nil {
            Button(r.toNest ? "See the nest" : "Go to hatchery") {
                store.tab = .eggs
                dismiss()
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        Button("Done") { dismiss() }.buttonStyle(SecondaryButtonStyle())
    }
}
