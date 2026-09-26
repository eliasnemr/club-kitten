import SwiftUI

// MARK: - Room arrows

/// Shows one room of a place with arrows to walk left and right. At the last room, an optional
/// plus button offers to build the next one.
struct RoomStage<Room: View>: View {
    @Binding var room: Int
    let count: Int
    let place: Location
    var onExtend: (() -> Void)? = nil
    @ViewBuilder let content: (Int) -> Room

    @State private var forward = true

    var body: some View {
        ZStack {
            content(room)
                .id("\(place.rawValue)-\(room)")
                .transition(.push(from: forward ? .trailing : .leading))
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            HStack {
                if room > 0 {
                    arrow("chevron.left", "Previous \(place.roomWord)") { go(-1) }
                }
                Spacer()
                if room < count - 1 {
                    arrow("chevron.right", "Next \(place.roomWord)") { go(1) }
                } else if let onExtend {
                    arrow("plus", "Build another \(place.roomWord)", filled: true) { onExtend() }
                }
            }
            .padding(.horizontal, 6)
        }
        .overlay(alignment: .top) {
            if count > 1 {
                HStack(spacing: 5) {
                    ForEach(0..<count, id: \.self) { i in
                        Capsule().fill(i == room ? Theme.rose : Theme.muted.opacity(0.35))
                            .frame(width: i == room ? 16 : 6, height: 6)
                    }
                }
                .padding(.horizontal, 8).padding(.vertical, 6)
                .background(Capsule().fill(.white.opacity(0.9)))
                .padding(.top, 12)
                .animation(.spring(response: 0.3), value: room)
                .accessibilityElement()
                .accessibilityLabel("\(place.roomWord.capitalized) \(room + 1) of \(count)")
            }
        }
        .onChange(of: count) { _, n in if room >= n { room = max(0, n - 1) } }
    }

    private func go(_ step: Int) {
        Haptics.tap()
        forward = step > 0
        withAnimation(.easeInOut(duration: 0.35)) { room = min(max(0, room + step), count - 1) }
    }

    private func arrow(_ icon: String, _ label: String, filled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 16, weight: .heavy))
                .foregroundStyle(filled ? .white : Theme.text)
                .frame(width: 40, height: 40)
                .background(Circle().fill(filled ? Theme.rose : .white.opacity(0.92)).shadow(color: .black.opacity(0.15), radius: 4, y: 2))
                .frame(width: 44, height: 44)
        }
        .accessibilityLabel(label)
    }
}

// MARK: - Place picker

/// Chips for your places. Places you don't own yet show their price and open a preview.
struct PlacePicker: View {
    let lounge: Lounge
    let selected: Location
    /// Hide places the player doesn't own (used when visiting a friend).
    var ownedOnly = false
    let pick: (Location) -> Void
    var preview: (Location) -> Void = { _ in }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(Location.allCases.filter { !ownedOnly || lounge.owns($0) }) { chip($0).id($0) }
                }
            }
            .scrollIndicators(.hidden)
            // Keep the place you're in visible, even when it's at the end of the row.
            .onAppear { proxy.scrollTo(selected, anchor: .center) }
            .onChange(of: selected) { _, p in withAnimation { proxy.scrollTo(p, anchor: .center) } }
        }
    }

    private func chip(_ place: Location) -> some View {
        let owned = lounge.owns(place)
        let on = selected == place
        return Button {
            Haptics.tap()
            owned ? pick(place) : preview(place)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: owned ? place.icon : "lock.fill").font(.system(size: 12, weight: .bold))
                Text(place.title).font(Theme.font(14, .bold))
                if !owned {
                    HStack(spacing: 2) {
                        Image(systemName: "pawprint.circle.fill").font(.system(size: 11)).foregroundStyle(Theme.warning)
                        Text("\(place.price)").font(Theme.font(12, .heavy))
                    }
                } else if lounge.rooms(in: place) > 1 {
                    Text("\(lounge.rooms(in: place))").font(Theme.font(11, .heavy))
                        .padding(.horizontal, 6).padding(.vertical, 1)
                        .background(Capsule().fill(on ? .white.opacity(0.25) : Theme.beige))
                }
            }
            .foregroundStyle(on ? .white : (owned ? Theme.text : Theme.muted))
            .padding(.horizontal, 14).frame(height: 38)
            .background(Capsule().fill(on ? Theme.text : .white))
            .overlay(Capsule().stroke(owned ? .clear : Theme.border, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
        }
        .accessibilityLabel(owned ? place.title : "\(place.title), locked, \(place.price) coins")
    }
}

// MARK: - Build sheet

/// Something that can be bought for your lounge: a whole new place, or one more room in a place.
enum BuildOption: Identifiable, Equatable {
    case place(Location)
    case room(Location)

    var id: String {
        switch self {
        case .place(let p): "place-\(p.rawValue)"
        case .room(let p): "room-\(p.rawValue)"
        }
    }
    var location: Location {
        switch self {
        case .place(let p), .room(let p): p
        }
    }
}

/// A preview of a new place or room with your cats in it, before any coins are spent.
struct BuildSheet: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let option: BuildOption
    /// Called after buying with the place and the room to show.
    var built: (Location, Int) -> Void = { _, _ in }

    private var place: Location { option.location }
    private var price: Int {
        switch option {
        case .place(let p): p.price
        case .room(let p): store.nextRoomPrice(p) ?? 0
        }
    }
    private var newRoom: Int {
        if case .room = option { return store.lounge.rooms(in: place) }
        return 0
    }
    /// Your lounge standing in the place being previewed.
    private var preview: Lounge {
        var l = store.lounge
        if case .place = option { l.ownedPlaces.append(place) }
        l.place = place
        return l
    }

    var body: some View {
        let short = max(0, price - store.coins)
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                RoomView(lounge: preview, residents: Array(store.cats.prefix(3)), height: 280,
                         shelfBreeds: Breed.allCases.reversed().filter { store.discovered.contains($0) },
                         place: place, room: newRoom)
                    .overlay(alignment: .topTrailing) {
                        Tag(text: "Preview", color: Theme.text)
                            .background(Capsule().fill(.white)).padding(10)
                    }
                    .padding(.top, 8)
                HStack(spacing: 8) {
                    Tag(text: place.title, color: Theme.rose)
                    switch option {
                    case .place: Tag(text: "Up to \(place.maxRooms) \(place.roomPlural)", color: Theme.muted)
                    case .room: Tag(text: "\(place.roomWord.capitalized) \(newRoom + 1) of \(place.maxRooms)", color: Theme.muted)
                    }
                }
                switch option {
                case .place:
                    Text(place.title).font(Theme.font(26, .heavy))
                    Text(place.blurb).font(Theme.font(15)).foregroundStyle(Theme.muted)
                    Text("It starts with one \(place.roomWord), and you can build more later. Your furniture storage is shared between all your places.")
                        .font(Theme.font(13)).foregroundStyle(Theme.muted)
                case .room:
                    Text("Build another \(place.roomWord)").font(Theme.font(26, .heavy))
                    Text("More space in your \(place.title.lowercased()) for furniture and cats. Walk between \(place.roomPlural) with the arrows.")
                        .font(Theme.font(15)).foregroundStyle(Theme.muted)
                }
                Button {
                    buy()
                } label: {
                    Label(short > 0 ? "Need \(short) more coins" : "Buy for \(price)", systemImage: "pawprint.circle.fill")
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(short > 0)
                if short > 0 {
                    Button("Earn coins in Play") {
                        store.tab = .play
                        dismiss()
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
                Button("Not now") { dismiss() }.buttonStyle(SecondaryButtonStyle())
            }
            .padding(20)
        }
        .foregroundStyle(Theme.text)
        .background(Theme.cream.ignoresSafeArea())
    }

    private func buy() {
        switch option {
        case .place(let p):
            guard store.buyPlace(p) else { Haptics.warning(); return }
            Haptics.success()
            built(p, 0)
        case .room(let p):
            guard let r = store.extend(p) else { Haptics.warning(); return }
            Haptics.success()
            built(p, r)
        }
        dismiss()
    }
}
