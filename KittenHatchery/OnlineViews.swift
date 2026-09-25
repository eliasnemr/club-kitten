import SwiftUI
import Supabase

/// What the Friends and Lounge screens present when a real playdate starts.
struct PlaydateRequest: Identifiable {
    let id = UUID()
    let friend: Friend
    /// Set when accepting someone else's invite; nil when you are the one inviting.
    let invite: RemotePlaydate?
}

// MARK: - Status and friend codes

struct OnlineStatusCard: View {
    @Environment(GameStore.self) private var store
    @State private var code = ""
    @State private var message: String?
    @State private var adding = false

    var body: some View {
        if let online = store.online, online.multiplayer {
            Card {
                HStack(spacing: 10) {
                    Circle().fill(online.isOnline ? Theme.success : (online.status == .connecting ? Theme.warning : Theme.rose))
                        .frame(width: 10, height: 10)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title(online)).font(Theme.font(15, .bold))
                        Text(online.gameCenterLinked ? "Game Center linked · friends who play are added automatically"
                                                     : "Sign in to Game Center in Settings to find friends automatically")
                            .font(Theme.font(12)).foregroundStyle(Theme.muted)
                    }
                }
                if online.isOnline {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Your friend code").font(Theme.font(12, .semibold)).foregroundStyle(Theme.muted)
                            Text(online.friendCode ?? "…").font(Theme.font(20, .heavy)).tracking(2)
                        }
                        Spacer()
                        if let c = online.friendCode {
                            ShareLink(item: "Visit my cat lounge in Club Kitten! My friend code is \(c)") {
                                Text("Share").font(Theme.font(14, .bold)).padding(.horizontal, 16).frame(height: 40)
                                    .overlay(Capsule().stroke(Theme.border, lineWidth: 1))
                            }
                            .foregroundStyle(Theme.text)
                        }
                    }
                    HStack(spacing: 8) {
                        TextField("Friend code, e.g. KIT-3F9A2C", text: $code)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .font(Theme.font(15, .semibold))
                            .padding(.horizontal, 14).frame(height: 44)
                            .background(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
                        Button(adding ? "…" : "Add") { add(online) }
                            .font(Theme.font(15, .bold)).foregroundStyle(.white)
                            .padding(.horizontal, 18).frame(height: 44)
                            .background(Capsule().fill(Theme.rose))
                            .disabled(code.count < 5 || adding)
                    }
                    if let message { Text(message).font(Theme.font(12, .semibold)).foregroundStyle(Theme.rose) }
                } else if case .failed(let why) = online.status {
                    Text(why).font(Theme.font(12)).foregroundStyle(Theme.rose)
                    Button("Try again") { Task { await online.start() } }
                        .font(Theme.font(14, .bold)).foregroundStyle(Theme.rose).frame(minHeight: 44)
                }
            }
        }
    }

    private func title(_ o: OnlineService) -> String {
        switch o.status {
        case .online: "Online as \(o.myName)"
        case .connecting: "Connecting…"
        case .failed: "Offline"
        }
    }

    private func add(_ online: OnlineService) {
        adding = true
        Task {
            do {
                try await online.addFriend(code: code)
                message = "Friend added!"
                code = ""
                Haptics.success()
            } catch {
                message = "No player has that code."
                Haptics.warning()
            }
            adding = false
        }
    }
}

// MARK: - Online playdate

struct OnlinePlaydateView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let friend: Friend
    let myCat: Cat
    let invite: RemotePlaydate?

    enum Phase: Equatable {
        case connecting
        case waiting
        case live
        case done(result: Int?, chance: Int)
        case failed(String)
    }

    @State private var phase: Phase = .connecting
    @State private var pd: RemotePlaydate?
    @State private var bond = 10
    @State private var cooldowns: [PlaydateActivity: Date] = [:]
    @State private var bubbles: [UUID: Bubble] = [:]
    @State private var channel: RealtimeChannelV2?
    @State private var finishing = false

    private var online: OnlineService? { store.online }
    private var iAmHost: Bool { invite == nil }
    private var theirCat: Cat { (iAmHost ? pd?.guestCat : pd?.hostCat) ?? friend.star }
    private var odds: PlaydateOdds { PlaydateOdds.make(mine: myCat, theirs: theirCat, bond: bond, friendLevel: friend.level) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("PLAYDATE WITH \(friend.name.uppercased())").font(Theme.font(12, .bold)).tracking(0.6).foregroundStyle(Theme.muted)
                    Text(headline).font(Theme.font(26, .heavy)).lineLimit(1).minimumScaleFactor(0.7)
                }
                switch phase {
                case .connecting, .waiting: waitingView
                case .live: liveView
                case .done(let result, let chance): doneView(result: result, chance: chance)
                case .failed(let why):
                    Text(why).font(Theme.font(15)).foregroundStyle(Theme.rose)
                    Button("Close") { dismiss() }.buttonStyle(SecondaryButtonStyle())
                }
            }
            .padding(20)
        }
        .scrollIndicators(.hidden)
        .foregroundStyle(Theme.text)
        .background(Theme.cream.ignoresSafeArea())
        .task { await run() }
        .onDisappear { cleanUp() }
    }

    private var headline: String {
        switch phase {
        case .waiting, .connecting: iAmHost ? "Waiting for \(friend.name)…" : "Joining…"
        case .live: "\(myCat.name) + \(theirCat.name)"
        case .done(let r, _): r == nil ? "What a fun playdate" : "You found an egg!"
        case .failed: "Playdate didn't start"
        }
    }

    private var waitingView: some View {
        VStack(spacing: 16) {
            HStack(alignment: .bottom, spacing: 24) {
                CatSprite(cat: myCat, size: 130, mood: .happy)
                CatSprite(cat: theirCat, size: 130).opacity(0.45)
            }
            .frame(maxWidth: .infinity).frame(height: 220)
            .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Theme.beige))
            ProgressView()
            Text(iAmHost ? "\(friend.name) has 15 minutes to accept your invite." : "Getting your cats together…")
                .font(Theme.font(14)).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
            Button("Cancel") {
                if let id = pd?.id, iAmHost { online?.decline(id) }
                dismiss()
            }
            .buttonStyle(SecondaryButtonStyle())
        }
    }

    private var liveView: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let start = pd?.startedAt {
                TimelineView(.periodic(from: .now, by: 1)) { ctx in
                    let left = max(0, PlaydateView.duration - ctx.date.timeIntervalSince(start))
                    HStack {
                        Pill(icon: "clock", text: formatTime(left), tint: left < 10 ? Theme.rose : Theme.text)
                        Spacer()
                        Text("Live with \(friend.name)").font(Theme.font(12, .semibold)).foregroundStyle(Theme.success)
                    }
                    .onChange(of: left == 0) { _, done in if done { finish() } }
                }
            }
            RoomView(lounge: store.lounge, residents: [],
                     guests: [RoomGuest(cat: myCat, label: "You · \(myCat.name)", isYou: true),
                              RoomGuest(cat: theirCat, label: "\(friend.name)'s \(theirCat.name)")],
                     height: 260, bubbles: bubbles,
                     shelfBreeds: Breed.allCases.reversed().filter { store.discovered.contains($0) })
            Card {
                HStack {
                    Text("Bond").font(Theme.font(14, .bold))
                    Spacer()
                    Text("\(bond) / 100").font(Theme.font(13, .semibold)).foregroundStyle(Theme.muted).monospacedDigit()
                }
                StatBar(label: "", value: Double(bond), max: 100, color: Theme.rose).animation(.easeOut, value: bond)
                Divider()
                ForEach(Array(odds.lines.enumerated()), id: \.offset) { _, line in
                    HStack { Text(line.0); Spacer(); Text("+\(line.1)%") }.font(Theme.font(13)).foregroundStyle(Theme.muted)
                }
                HStack { Text("Egg chance when the timer ends"); Spacer(); Text("\(odds.total)%") }.font(Theme.font(14, .heavy))
                Text("The server rolls the egg, so you and \(friend.name) always get the same one.")
                    .font(Theme.font(11)).foregroundStyle(Theme.muted)
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
                        Text(ready ? "+\(a.bond) bond\(a.cost > 0 ? " · \(a.cost) coins" : "")" : "Again soon")
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

    @ViewBuilder
    private func doneView(result: Int?, chance: Int) -> some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Theme.beige)
            HStack(alignment: .bottom, spacing: -10) {
                CatSprite(cat: myCat, size: 130, mood: .happy)
                if let r = result {
                    let egg = Rarity(index: r)
                    VStack(spacing: 8) {
                        EggView(rarity: egg, size: 96)
                        Tag(text: "\(egg.title) egg", color: egg.color, filled: egg == .legendary)
                    }
                    .padding(.bottom, 30)
                } else {
                    Image(systemName: "heart.fill").font(.system(size: 36)).foregroundStyle(Theme.rose).padding(.bottom, 80)
                }
                CatSprite(cat: theirCat, size: 130, mood: .happy)
            }
            .padding(.bottom, 16)
            if result != nil { ConfettiView() }
        }
        .frame(height: 280)
        Card {
            if let r = result {
                Text("You and \(friend.name) both got \(Rarity(index: r) == .epic ? "an" : "a") \(Rarity(index: r).title) egg. It's in your hatchery, or the nest if your slots are full.")
                    .font(Theme.font(14, .semibold))
            } else {
                Text("No egg this time (\(chance)% chance). Your friendship still grew.")
                    .font(Theme.font(14)).foregroundStyle(Theme.muted)
            }
        }
        Button("Done") { dismiss() }.buttonStyle(PrimaryButtonStyle())
    }

    // MARK: Flow

    private func run() async {
        guard let online else { phase = .failed("You're offline."); return }
        do {
            let id: UUID
            if let invite {
                try await online.accept(invite.id, cat: myCat)
                id = invite.id
            } else {
                id = try await online.invite(friend.id, cat: myCat)
                phase = .waiting
            }
            let (ch, updates) = online.playdateUpdates(id)
            channel = ch
            await ch.subscribe()
            if let current = await online.playdate(id) { apply(current) }
            for await row in updates { apply(row) }
        } catch {
            phase = .failed(Self.message(error))
        }
    }

    private func apply(_ row: RemotePlaydate) {
        let oldBond = bond
        pd = row
        bond = row.bond
        switch row.status {
        case "active":
            if phase != .live { Haptics.success() }
            phase = .live
            if row.bond > oldBond, oldBond != 10 || row.bond != 10 { flash(theirCat.id, "heart.fill") }
        case "done":
            phase = .done(result: row.result, chance: row.chance ?? 0)
            Task { await online?.claimEggs() }
        case "declined":
            phase = .failed("\(friend.name) couldn't make it this time.")
        default:
            break
        }
    }

    private func act(_ a: PlaydateActivity) {
        guard let id = pd?.id, let online else { return }
        if a.cost > 0 && !store.spendCoins(a.cost) { Haptics.warning(); return }
        Haptics.tap(.medium)
        cooldowns[a] = Date().addingTimeInterval(a.cooldown)
        flash(myCat.id, a == .nap ? "moon.zzz.fill" : "heart.fill")
        Task {
            if let newBond = try? await online.act(id, a) { withAnimation { bond = max(bond, newBond) } }
        }
    }

    private func finish() {
        guard !finishing, let id = pd?.id, let online else { return }
        finishing = true
        Task {
            do {
                let r = try await online.finish(id)
                store.record(.playdate)
                r.result == nil ? Haptics.tap(.medium) : Haptics.success()
                withAnimation { phase = .done(result: r.result, chance: r.chance) }
            } catch {
                finishing = false
            }
        }
    }

    private func flash(_ id: UUID, _ symbol: String) {
        withAnimation(.spring(response: 0.3)) { bubbles[id] = Bubble(symbol: symbol) }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.4))
            withAnimation { bubbles[id] = nil }
        }
    }

    private func cleanUp() {
        if let channel, let online { Task { await online.client.removeChannel(channel) } }
        if phase == .waiting, iAmHost, let id = pd?.id { online?.decline(id) }
    }

    private static func message(_ error: Error) -> String {
        let text = "\(error)"
        if text.contains("No playdates left") { return "No playdates left today. Come back tomorrow!" }
        if text.contains("expired") { return "That invite has expired." }
        return "Couldn't start the playdate. Check your connection and try again."
    }
}

// MARK: - Cloud save status

/// A quiet line in the Den showing whether progress is backed up.
struct CloudSaveBadge: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        if let online = store.online {
            TimelineView(.periodic(from: .now, by: 30)) { _ in
                HStack(spacing: 6) {
                    Image(systemName: icon(online)).font(.system(size: 12, weight: .semibold))
                    Text(text(online)).font(Theme.font(12, .semibold))
                }
                .foregroundStyle(color(online))
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .combine)
            }
        }
    }

    private func icon(_ o: OnlineService) -> String {
        switch o.sync {
        case .synced: "checkmark.icloud.fill"
        case .syncing: "arrow.triangle.2.circlepath.icloud"
        case .failed: "icloud.slash"
        case .idle: "icloud"
        }
    }

    private func text(_ o: OnlineService) -> String {
        switch o.sync {
        case .synced(let at):
            let ago = Date().timeIntervalSince(at)
            return ago < 60 ? "Progress saved to the cloud" : "Saved to the cloud \(formatDuration(ago)) ago"
        case .syncing: return "Saving to the cloud…"
        case .failed: return "Offline · progress is saved on this phone"
        case .idle: return "Connecting cloud save…"
        }
    }

    private func color(_ o: OnlineService) -> Color {
        if case .failed = o.sync { return Theme.muted }
        return Theme.success
    }
}
