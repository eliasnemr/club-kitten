import SwiftUI

// MARK: - Furniture shop

struct ShopView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    /// Called with an item the player wants to place right away.
    var placeNow: (Furniture, ItemTint?) -> Void = { _, _ in }

    @State private var filter: DecorCategory?
    @State private var inspecting: Furniture?

    private var items: [Furniture] {
        Furniture.allCases.filter { filter == nil || $0.category == filter }.sorted { $0.price < $1.price }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("CAT MART").font(Theme.font(12, .bold)).tracking(0.6).foregroundStyle(Theme.muted)
                        Text("Furniture shop").font(Theme.font(27, .heavy))
                    }
                    Spacer()
                    CoinPill()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark").font(.system(size: 15, weight: .bold))
                            .frame(width: 44, height: 44).background(Circle().fill(.white))
                    }
                    .accessibilityLabel("Close shop")
                }
                earnBanner
                Text("Today's deals").font(Theme.font(17, .bold))
                HStack(spacing: 12) {
                    ForEach(store.dailyDeals) { dealCard($0) }
                }
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        chip("All", nil)
                        ForEach(DecorCategory.allCases.filter(\.isItems)) { chip($0.title, $0) }
                    }
                }
                .scrollIndicators(.hidden)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    ForEach(items) { itemCard($0) }
                }
                Card {
                    HStack(spacing: 12) {
                        Image(systemName: "paintbrush.fill").font(.system(size: 20)).foregroundStyle(Theme.rose)
                            .frame(width: 44, height: 44).background(Circle().fill(Theme.roseTint))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Walls, floors and wallpaper").font(Theme.font(15, .bold))
                            Text("Try them on in Decorate before you buy.").font(Theme.font(12)).foregroundStyle(Theme.muted)
                        }
                    }
                }
            }
            .padding(20)
        }
        .scrollIndicators(.hidden)
        .foregroundStyle(Theme.text)
        .background(Theme.cream.ignoresSafeArea())
        #if DEBUG
        .onAppear {
            let args = ProcessInfo.processInfo.arguments
            if let i = args.firstIndex(of: "-shopItem"), i + 1 < args.count { inspecting = Furniture(rawValue: args[i + 1]) }
        }
        #endif
        .sheet(item: $inspecting) { kind in
            ShopItemSheet(kind: kind, placeNow: { k, tint in
                inspecting = nil
                placeNow(k, tint)
            })
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }

    private var earnBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "pawprint.circle.fill").font(.system(size: 30)).foregroundStyle(Theme.warning)
            VStack(alignment: .leading, spacing: 2) {
                Text("Need more coins?").font(Theme.font(15, .bold))
                Text("Play minigames and finish daily challenges.").font(Theme.font(12)).foregroundStyle(Theme.muted)
            }
            Spacer(minLength: 0)
            Button("Earn") {
                store.tab = .play
                dismiss()
            }
            .font(Theme.font(14, .bold)).foregroundStyle(.white)
            .padding(.horizontal, 16).frame(height: 40)
            .background(Capsule().fill(Theme.rose))
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color(red: 1, green: 0.95, blue: 0.84)))
    }

    private func chip(_ title: String, _ c: DecorCategory?) -> some View {
        let on = filter == c
        return Button(title) { Haptics.tap(); filter = c }
            .font(Theme.font(14, .bold))
            .foregroundStyle(on ? .white : Theme.text)
            .padding(.horizontal, 16).frame(height: 38)
            .background(Capsule().fill(on ? Theme.text : .white))
    }

    private func preview(_ kind: Furniture, box: CGFloat) -> some View {
        FurnitureView(kind: kind, scale: min(1.2, box / max(kind.size.width, kind.size.height)),
                      shelfBreeds: Breed.allCases.reversed().filter { store.discovered.contains($0) },
                      portrait: store.activeCat?.kind)
    }

    @ViewBuilder
    private func priceLabel(_ kind: Furniture) -> some View {
        let p = store.price(kind)
        if store.owned(kind) > 0 {
            Label("Owned", systemImage: "checkmark.circle.fill")
                .font(Theme.font(13, .bold)).foregroundStyle(Theme.success)
        } else {
        HStack(spacing: 4) {
            Image(systemName: "pawprint.circle.fill").font(.system(size: 12)).foregroundStyle(Theme.warning)
            Text("\(p)").font(Theme.font(14, .heavy))
            if p != kind.price {
                Text("\(kind.price)").font(Theme.font(12)).strikethrough().foregroundStyle(Theme.muted)
            }
        }
        }
    }

    private func dealCard(_ kind: Furniture) -> some View {
        Button {
            inspecting = kind
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                preview(kind, box: 70)
                    .frame(maxWidth: .infinity).frame(height: 84)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Theme.beige))
                    .overlay(alignment: .topLeading) {
                        Tag(text: "-30%", color: Theme.rose, filled: true).padding(6)
                    }
                Text(kind.title).font(Theme.font(14, .bold)).lineLimit(1)
                priceLabel(kind)
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.rose.opacity(0.5), lineWidth: 1.5))
        }
        .buttonStyle(PressableStyle())
        .foregroundStyle(Theme.text)
    }

    private func itemCard(_ kind: Furniture) -> some View {
        let owned = store.owned(kind)
        return Button {
            Haptics.tap()
            inspecting = kind
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                preview(kind, box: 80)
                    .frame(maxWidth: .infinity).frame(height: 100)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Theme.beige))
                    .overlay(alignment: .topTrailing) {
                        if owned > 0 { Tag(text: "Owned", color: Theme.success).padding(6) }
                    }
                Text(kind.title).font(Theme.font(15, .bold)).lineLimit(1)
                HStack {
                    priceLabel(kind)
                    Spacer()
                    Text(kind.tier).font(Theme.font(11, .bold)).foregroundStyle(Theme.muted)
                }
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white))
        }
        .buttonStyle(PressableStyle())
        .foregroundStyle(Theme.text)
        .accessibilityLabel("\(kind.title), \(store.price(kind)) coins")
    }
}

struct ShopItemSheet: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let kind: Furniture
    var placeNow: (Furniture, ItemTint?) -> Void

    enum PreviewMode: String, CaseIterable { case item = "Item", lounge = "In my lounge" }

    @State private var tint: ItemTint = .rose
    @State private var bought = false
    @State private var mode: PreviewMode = .lounge

    /// Your lounge with this item added, so you can see it before buying.
    private var tryOn: Lounge {
        var l = store.lounge
        let x = kind.onWall ? 0.5 : 0.55
        let y = kind.onWall ? 0.26 : 0.84
        l.items.append(PlacedItem(kind: kind, x: x, y: y, tint: kind.tintable ? tint : nil, place: l.place))
        return l
    }

    var body: some View {
        let price = store.price(kind)
        let short = max(0, price - store.coins)
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Picker("Preview", selection: $mode) {
                    ForEach(PreviewMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.top, 8)
                if mode == .lounge {
                    RoomView(lounge: tryOn, residents: Array(store.cats.prefix(2)), height: 260,
                             shelfBreeds: Breed.allCases.reversed().filter { store.discovered.contains($0) },
                             portrait: store.activeCat?.kind)
                        .overlay(alignment: .bottomLeading) {
                            Tag(text: bought || store.owned(kind) > 0 ? "You own this" : "Preview · not bought yet", color: Theme.text)
                                .background(Capsule().fill(.white)).padding(10)
                        }
                } else {
                    FurnitureView(kind: kind, scale: min(1.9, 200 / max(kind.size.width, kind.size.height)),
                                  shelfBreeds: Breed.allCases.reversed().filter { store.discovered.contains($0) },
                                  tint: kind.tintable ? tint : nil, portrait: store.activeCat?.kind)
                        .frame(maxWidth: .infinity).frame(height: 260)
                        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Theme.beige))
                }
                HStack(spacing: 8) {
                    Tag(text: kind.tier, color: Theme.text)
                    Tag(text: kind.category.title, color: Theme.muted)
                    if price != kind.price { Tag(text: "Deal -30%", color: Theme.rose, filled: true) }
                }
                Text(kind.title).font(Theme.font(26, .heavy))
                Text(kind.blurb).font(Theme.font(15)).foregroundStyle(Theme.muted)
                if kind.tintable {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Pick a colour to preview · change any time for free").font(Theme.font(13, .semibold))
                        TintPicker(selected: tint) { tint = $0 }
                    }
                }
                let owned = store.owned(kind)
                let inStorage = store.lounge.stored.contains(kind)

                if bought {
                    Label("Sent to your lounge storage", systemImage: "shippingbox.fill")
                        .font(Theme.font(15, .bold)).foregroundStyle(Theme.success)
                    Button("Place it now") { placeNow(kind, tint) }.buttonStyle(PrimaryButtonStyle())
                    Button("Keep shopping") { dismiss() }.buttonStyle(SecondaryButtonStyle())
                } else if owned > 0 {
                    // Each item can only be owned once.
                    Label(inStorage ? "You own this · it's in your storage" : "You own this · it's in your lounge",
                          systemImage: "checkmark.circle.fill")
                        .font(Theme.font(15, .bold)).foregroundStyle(Theme.success)
                    if inStorage {
                        Button("Place it now") { placeNow(kind, tint) }.buttonStyle(PrimaryButtonStyle())
                    }
                    Button("Keep shopping") { dismiss() }.buttonStyle(SecondaryButtonStyle())
                } else {
                    Button {
                        if store.buy(kind) {
                            Haptics.success()
                            withAnimation { bought = true }
                        } else {
                            Haptics.warning()
                        }
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
                }
            }
            .padding(20)
        }
        .foregroundStyle(Theme.text)
        .background(Theme.cream.ignoresSafeArea())
    }
}

struct TintPicker: View {
    let selected: ItemTint?
    let pick: (ItemTint) -> Void

    var body: some View {
        HStack(spacing: 10) {
            ForEach(ItemTint.allCases) { t in
                Button {
                    Haptics.tap()
                    pick(t)
                } label: {
                    Circle().fill(t.color).frame(width: 36, height: 36)
                        .overlay(Circle().stroke(selected == t ? Theme.text : Theme.border, lineWidth: selected == t ? 3 : 1))
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel(t.title)
            }
        }
    }
}

// MARK: - Decorate

struct DecorateView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    /// The room being decorated, shared with the lounge so you come back to the same one.
    @Binding var room: Int

    enum Section: String, CaseIterable, Identifiable {
        case storage, walls, floors, wallpaper, name
        var id: String { rawValue }
        var title: String { rawValue.capitalized }
    }

    /// Walls, floors and wallpaper only apply in the lounge; other places have their own look.
    private var sections: [Section] {
        store.lounge.place.customStyle ? Section.allCases : [.storage, .name]
    }

    @State private var selected: UUID?
    @State private var section: Section = .storage
    @State private var note: String?
    @State private var showShop = false
    @State private var first = 0
    @State private var second = 0
    /// A wall, floor or wallpaper you don't own yet, shown in the room until you buy or cancel.
    @State private var tryOn: StyleTryOn?
    @State private var build: BuildOption?

    enum StyleTryOn: Equatable {
        case wall(WallStyle), floor(FloorStyle), pattern(WallPattern)
        var title: String {
            switch self {
            case .wall(let w): "\(w.title) walls"
            case .floor(let f): "\(f.title) floor"
            case .pattern(let p): "\(p.title) wallpaper"
            }
        }
        var price: Int {
            switch self {
            case .wall(let w): w.price
            case .floor(let f): f.price
            case .pattern(let p): p.price
            }
        }
    }

    private var selectedItem: PlacedItem? { store.lounge.items.first { $0.id == selected } }

    /// The lounge as shown: your real lounge plus anything you're trying on.
    private var shown: Lounge {
        var l = store.lounge
        switch tryOn {
        case .wall(let w): l.wall = w
        case .floor(let f): l.floor = f
        case .pattern(let p): l.pattern = p
        case nil: break
        }
        return l
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("DECORATE").font(Theme.font(12, .bold)).tracking(0.6).foregroundStyle(Theme.muted)
                    Text(store.lounge.name).font(Theme.font(26, .heavy)).lineLimit(1).minimumScaleFactor(0.7)
                }
                Spacer()
                CoinPill()
                Button {
                    showShop = true
                } label: {
                    Label("Shop", systemImage: "bag.fill").font(Theme.font(14, .bold))
                        .padding(.horizontal, 14).frame(height: 40)
                        .background(Capsule().fill(Theme.rose)).foregroundStyle(.white)
                }
            }
            let place = store.lounge.place
            let rooms = store.lounge.rooms(in: place)
            PlacePicker(lounge: store.lounge, selected: place,
                        pick: { p in selected = nil; tryOn = nil; withAnimation { room = 0; store.goTo(p) } },
                        preview: { build = .place($0) })
            RoomStage(room: $room, count: rooms, place: place,
                      onExtend: store.nextRoomPrice(place) == nil ? nil : { build = .room(place) }) { r in
                RoomView(lounge: shown, residents: [], height: 290,
                         shelfBreeds: Breed.allCases.reversed().filter { store.discovered.contains($0) },
                         portrait: store.activeCat?.kind,
                         editing: true, selectedItem: selected,
                         onSelectItem: { id in Haptics.tap(); selected = id },
                         onMoveItem: { id, x, y in store.moveItem(id, x: x, y: y) },
                         room: r)
            }
                .overlay(alignment: .bottomTrailing) {
                    if let id = selectedItem?.id {
                        HStack(spacing: 8) {
                            if rooms > 1 {
                                // Carries the item into the next room and follows it there.
                                roundButton("arrow.right.square.fill", "Move to next \(place.roomWord)") {
                                    let next = (room + 1) % rooms
                                    store.moveItem(id, toRoom: next)
                                    withAnimation { room = next }
                                    note = "Moved to \(place.roomWord) \(next + 1)."
                                }
                            }
                            roundButton("arrow.left.and.right.righttriangle.left.righttriangle.right", "Flip") { store.flipItem(id) }
                            roundButton("tray.and.arrow.down.fill", "Put away") {
                                store.storeItem(id)
                                selected = nil
                                note = "Put away in storage."
                            }
                        }
                        .padding(10)
                    }
                }
            if let t = tryOn {
                tryOnBar(t)
            } else if let item = selectedItem, item.kind.tintable {
                HStack {
                    Text(item.kind.title).font(Theme.font(13, .bold))
                    Spacer()
                    TintPicker(selected: item.tint ?? .rose) { store.setTint(item.id, $0) }
                        .scaleEffect(0.85, anchor: .trailing)
                }
            } else {
                Text(note ?? "Drag furniture to move it. Tap to select, then flip, recolour, put it away or carry it to another room.")
                    .font(Theme.font(13)).foregroundStyle(Theme.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Picker("Section", selection: $section) {
                ForEach(sections) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            ScrollView {
                switch section {
                case .storage: storage
                case .walls: swatchGrid(WallStyle.allCases.map { w in
                    Swatch(title: w.title, fill: AnyShapeStyle(w.color), owned: store.lounge.ownedWalls.contains(w),
                           on: store.lounge.wall == w, trying: tryOn == .wall(w), price: w.price, tryOn: .wall(w)) { store.chooseWall(w) } })
                case .floors: swatchGrid(FloorStyle.allCases.map { f in
                    Swatch(title: f.title, fill: AnyShapeStyle(LinearGradient(colors: f.colors, startPoint: .top, endPoint: .bottom)),
                           owned: store.lounge.ownedFloors.contains(f), on: store.lounge.floor == f, trying: tryOn == .floor(f),
                           price: f.price, tryOn: .floor(f)) { store.chooseFloor(f) } })
                case .wallpaper: swatchGrid(WallPattern.allCases.map { p in
                    Swatch(title: p.title, pattern: p, owned: store.lounge.ownedPatterns.contains(p),
                           on: store.lounge.pattern == p, trying: tryOn == .pattern(p), price: p.price, tryOn: .pattern(p)) { store.choosePattern(p) } })
                case .name: namePicker
                }
            }
            Button("Save lounge") { tryOn = nil; Haptics.success(); dismiss() }.buttonStyle(PrimaryButtonStyle())
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .foregroundStyle(Theme.text)
        .background(Theme.cream.ignoresSafeArea())
        .onAppear {
            first = store.lounge.nameFirst
            second = store.lounge.nameSecond
            #if DEBUG
            let args = ProcessInfo.processInfo.arguments
            if let i = args.firstIndex(of: "-tryWall"), i + 1 < args.count, let w = WallStyle(rawValue: args[i + 1]) {
                section = .walls
                DispatchQueue.main.async { tryOn = .wall(w) }
            }
            #endif
        }
        .onChange(of: section) { _, _ in tryOn = nil }
        .onChange(of: store.lounge.place) { _, _ in if !sections.contains(section) { section = .storage } }
        .onChange(of: room) { _, new in
            // Keep the selection only when the item came along to the new room.
            if let item = selectedItem, item.room != new { selected = nil }
        }
        .sheet(item: $build) { option in
            BuildSheet(option: option) { _, r in withAnimation { room = r } }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showShop) {
            ShopView(placeNow: { kind, tint in
                store.placeStored(kind, tint: tint, room: room)
                selected = store.lounge.items.last?.id
                note = "Placed your \(kind.title.lowercased()). Drag it where you like."
                showShop = false
            })
        }
    }

    private var storage: some View {
        let counts = Dictionary(grouping: store.lounge.stored, by: { $0 }).mapValues(\.count)
        let kinds = Furniture.allCases.filter { counts[$0] != nil }
        return Group {
            if kinds.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "shippingbox").font(.system(size: 34)).foregroundStyle(Theme.muted)
                    Text("Storage is empty").font(Theme.font(15, .bold))
                    Text("Buy furniture in the shop, or put items away here.").font(Theme.font(13)).foregroundStyle(Theme.muted)
                    Button("Open the shop") { showShop = true }
                        .font(Theme.font(14, .bold)).foregroundStyle(Theme.rose).frame(minHeight: 44)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 20)
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                    ForEach(kinds) { kind in
                        Button {
                            Haptics.tap(.medium)
                            store.placeStored(kind, room: room)
                            selected = store.lounge.items.last?.id
                            note = "Placed your \(kind.title.lowercased())."
                        } label: {
                            VStack(spacing: 6) {
                                FurnitureView(kind: kind, scale: min(1, 56 / max(kind.size.width, kind.size.height)),
                                              shelfBreeds: Breed.allCases.reversed().filter { store.discovered.contains($0) })
                                    .frame(height: 60)
                                Text(kind.title).font(Theme.font(12, .bold)).lineLimit(1).minimumScaleFactor(0.8)
                                Tag(text: "Place · \(counts[kind] ?? 0)", color: Theme.success)
                            }
                            .padding(8)
                            .frame(maxWidth: .infinity, minHeight: 120)
                            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.white))
                        }
                        .buttonStyle(PressableStyle())
                        .foregroundStyle(Theme.text)
                    }
                }
            }
        }
    }

    private var namePicker: some View {
        VStack(spacing: 10) {
            Text(LoungeName.make(first, second)).font(Theme.font(22, .heavy))
            HStack(spacing: 0) {
                Picker("First word", selection: $first) {
                    ForEach(LoungeName.first.indices, id: \.self) { Text(LoungeName.first[$0]).tag($0) }
                }
                Picker("Second word", selection: $second) {
                    ForEach(LoungeName.second.indices, id: \.self) { Text(LoungeName.second[$0]).tag($0) }
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 130)
            Button("Use this name") {
                Haptics.success()
                store.renameLounge(first: first, second: second)
            }
            .buttonStyle(SecondaryButtonStyle())
            .disabled(first == store.lounge.nameFirst && second == store.lounge.nameSecond)
            Text("Visitors see this on your wall.").font(Theme.font(12)).foregroundStyle(Theme.muted)
        }
    }

    private struct Swatch: Identifiable {
        let id = UUID()
        var title: String
        var fill: AnyShapeStyle = AnyShapeStyle(Color.white)
        var pattern: WallPattern? = nil
        var owned: Bool
        var on: Bool
        var trying = false
        var price: Int
        var tryOn: StyleTryOn
        /// Applies an owned style, or buys and applies one you're trying on.
        var apply: () -> Void
    }

    private func tryOnBar(_ t: StyleTryOn) -> some View {
        let short = max(0, t.price - store.coins)
        return HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Previewing \(t.title)").font(Theme.font(14, .bold))
                Text(short > 0 ? "You need \(short) more coins" : "Not bought yet").font(Theme.font(12)).foregroundStyle(Theme.muted)
            }
            Spacer(minLength: 0)
            Button("Cancel") { withAnimation { tryOn = nil } }
                .font(Theme.font(14, .bold)).foregroundStyle(Theme.text)
                .padding(.horizontal, 14).frame(height: 40)
                .overlay(Capsule().stroke(Theme.border, lineWidth: 1))
            Button {
                Haptics.success()
                switch t {
                case .wall(let w): store.chooseWall(w)
                case .floor(let f): store.chooseFloor(f)
                case .pattern(let p): store.choosePattern(p)
                }
                note = "Bought \(t.title.lowercased())."
                withAnimation { tryOn = nil }
            } label: {
                Label("Buy · \(t.price)", systemImage: "pawprint.circle.fill")
                    .font(Theme.font(14, .bold)).foregroundStyle(.white)
                    .padding(.horizontal, 14).frame(height: 40)
                    .background(Capsule().fill(short > 0 ? Theme.muted.opacity(0.5) : Theme.rose))
            }
            .disabled(short > 0)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.roseTint))
    }

    private func swatchGrid(_ swatches: [Swatch]) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
            ForEach(swatches) { s in
                Button {
                    Haptics.tap()
                    if s.owned {
                        // Owned styles switch instantly and for free.
                        tryOn = nil
                        s.apply()
                    } else {
                        // Unowned styles are only previewed; nothing is spent until you press Buy.
                        withAnimation { tryOn = s.on ? nil : s.tryOn }
                    }
                } label: {
                    VStack(spacing: 6) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10).fill(s.pattern == nil ? s.fill : AnyShapeStyle(store.lounge.wall.color))
                            if let p = s.pattern { WallPatternView(pattern: p).clipShape(RoundedRectangle(cornerRadius: 10)) }
                        }
                        .frame(height: 56)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(s.on || s.trying ? Theme.rose : Theme.border,
                                                                           style: StrokeStyle(lineWidth: s.on || s.trying ? 3 : 1, dash: s.trying ? [5, 3] : [])))
                        Text(s.title).font(Theme.font(12, .bold))
                        if s.trying {
                            Tag(text: "Previewing", color: Theme.rose, filled: true)
                        } else if s.on {
                            Tag(text: "In use", color: Theme.rose)
                        } else if s.owned {
                            Tag(text: "Owned", color: Theme.success)
                        } else {
                            Label("\(s.price)", systemImage: "pawprint.circle.fill").font(Theme.font(12, .bold))
                        }
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, minHeight: 124)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.white))
                }
                .buttonStyle(PressableStyle())
                .foregroundStyle(Theme.text)
            }
        }
    }

    private func roundButton(_ icon: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap(.medium)
            action()
        } label: {
            Image(systemName: icon).font(.system(size: 16, weight: .bold))
                .frame(width: 44, height: 44)
                .background(Circle().fill(.white).shadow(color: .black.opacity(0.12), radius: 4, y: 2))
                .foregroundStyle(Theme.text)
        }
        .accessibilityLabel(label)
    }
}
