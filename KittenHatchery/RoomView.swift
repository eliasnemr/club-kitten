import SwiftUI

// MARK: - Furniture drawings

struct FurnitureView: View {
    let kind: Furniture
    var scale: CGFloat = 1
    var shelfBreeds: [Breed] = []
    var tint: ItemTint? = nil
    var portrait: Breed? = nil

    private let wood = Color(red: 0.72, green: 0.55, blue: 0.4)
    private let woodDark = Color(red: 0.58, green: 0.43, blue: 0.3)
    private var plush: Color { (tint ?? .rose).color }

    var body: some View {
        let s = kind.size
        Group {
            if let asset = kind.imageAsset {
                Image(asset).resizable().scaledToFit()
            } else {
                drawing
            }
        }
        .frame(width: s.width * scale, height: s.height * scale)
    }

    @ViewBuilder
    private var drawing: some View {
        switch kind {
        case .catTree:
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 4).fill(wood).frame(width: 14 * scale)
                VStack(spacing: 34 * scale) {
                    Capsule().fill(plush).frame(width: 56 * scale, height: 14 * scale)
                    Capsule().fill(plush).frame(width: 64 * scale, height: 14 * scale)
                    Capsule().fill(plush).frame(width: 70 * scale, height: 16 * scale)
                }
                .frame(maxHeight: .infinity, alignment: .top)
                RoundedRectangle(cornerRadius: 6).fill(woodDark).frame(width: 70 * scale, height: 12 * scale)
            }
        case .cushion:
            ZStack {
                Ellipse().fill(plush)
                Ellipse().stroke(Theme.rose.opacity(0.4), lineWidth: 2).padding(6 * scale)
            }
        case .fishTank:
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 8).fill(Color(red: 0.72, green: 0.87, blue: 0.97).opacity(0.85))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(red: 0.5, green: 0.68, blue: 0.82), lineWidth: 3))
                    .padding(.bottom, 12 * scale)
                Image(systemName: "fish.fill").font(.system(size: 20 * scale)).foregroundStyle(Theme.warning)
                    .offset(x: -10 * scale, y: -34 * scale)
                RoundedRectangle(cornerRadius: 4).fill(woodDark).frame(height: 14 * scale)
            }
        case .window:
            ZStack {
                RoundedRectangle(cornerRadius: 6).fill(Color(red: 0.8, green: 0.91, blue: 0.99))
                Image(systemName: "sun.max.fill").font(.system(size: 20 * scale)).foregroundStyle(Theme.warning.opacity(0.8))
                    .offset(x: 20 * scale, y: -14 * scale)
                Rectangle().fill(.white).frame(width: 5 * scale)
                Rectangle().fill(.white).frame(height: 5 * scale)
                RoundedRectangle(cornerRadius: 6).stroke(.white, lineWidth: 6 * scale)
            }
            .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
        case .breedShelf:
            VStack(spacing: 0) {
                HStack(alignment: .bottom, spacing: 2) {
                    ForEach(Array(shelfBreeds.prefix(4)), id: \.self) { b in
                        Image(b.imageName).resizable().scaledToFit().frame(height: 38 * scale)
                    }
                    if shelfBreeds.isEmpty {
                        Image(systemName: "trophy.fill").font(.system(size: 22 * scale)).foregroundStyle(Rarity.legendary.color)
                    }
                }
                .frame(maxHeight: .infinity, alignment: .bottom)
                RoundedRectangle(cornerRadius: 3).fill(wood).frame(height: 8 * scale)
            }
        case .hammock:
            ZStack(alignment: .bottom) {
                HStack {
                    RoundedRectangle(cornerRadius: 3).fill(woodDark).frame(width: 8 * scale)
                    Spacer()
                    RoundedRectangle(cornerRadius: 3).fill(woodDark).frame(width: 8 * scale)
                }
                HammockCloth().fill(tint == nil ? Color(red: 0.62, green: 0.78, blue: 0.9) : plush)
                    .frame(height: 40 * scale).offset(y: -18 * scale)
            }
        case .yarnBasket:
            ZStack(alignment: .bottom) {
                HStack(spacing: -6 * scale) {
                    Circle().fill(Theme.rose).frame(width: 22 * scale)
                    Circle().fill(Color(red: 0.4, green: 0.6, blue: 0.9)).frame(width: 20 * scale)
                    Circle().fill(Theme.warning).frame(width: 18 * scale)
                }
                .offset(y: -16 * scale)
                RoundedRectangle(cornerRadius: 8).fill(wood).frame(height: 24 * scale)
            }
        case .scratchPost:
            ZStack(alignment: .bottom) {
                VStack(spacing: 5 * scale) {
                    ForEach(0..<9, id: \.self) { _ in Capsule().fill(Color(red: 0.86, green: 0.76, blue: 0.6)).frame(height: 4 * scale) }
                }
                .frame(width: 20 * scale)
                .padding(.bottom, 10 * scale)
                RoundedRectangle(cornerRadius: 5).fill(woodDark).frame(height: 12 * scale)
            }
        case .rug:
            ZStack {
                Ellipse().fill(plush.opacity(0.55))
                Ellipse().stroke(plush, lineWidth: 3).padding(7 * scale)
                Ellipse().stroke(.white.opacity(0.6), lineWidth: 2).padding(15 * scale)
            }
        case .catBed: catBedView
        case .sofa: sofaView
        case .painting: paintingView
        case .fairyLights: fairyLightsView
        case .bookshelf: bookshelfView
        case .boxCastle, .throne, .fireplace, .beanBag, .monstera, .pawClock: EmptyView()
        case .plant:
            VStack(spacing: -4 * scale) {
                ZStack {
                    ForEach(-2...2, id: \.self) { i in
                        Capsule().fill(Theme.success).frame(width: 5 * scale, height: 30 * scale)
                            .rotationEffect(.degrees(Double(i) * 16), anchor: .bottom)
                    }
                }
                .frame(height: 32 * scale)
                RoundedRectangle(cornerRadius: 6).fill(Color(red: 0.85, green: 0.55, blue: 0.4)).frame(width: 34 * scale, height: 26 * scale)
            }
        case .lamp:
            VStack(spacing: 0) {
                LampShade().fill(Color(red: 1, green: 0.93, blue: 0.75))
                    .frame(width: 40 * scale, height: 30 * scale)
                    .shadow(color: Theme.warning.opacity(0.5), radius: 12)
                Rectangle().fill(woodDark).frame(width: 4 * scale)
                Capsule().fill(woodDark).frame(width: 28 * scale, height: 6 * scale)
            }
        }
    }

    private var catBedView: some View {
        ZStack {
            Ellipse().fill(plush)
            Ellipse().fill(.white.opacity(0.75)).padding(.horizontal, 14 * scale).padding(.vertical, 9 * scale).offset(y: -3 * scale)
            Ellipse().stroke(.black.opacity(0.06), lineWidth: 2)
        }
    }

    private var sofaView: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 16 * scale).fill(plush).brightness(0.05).frame(height: 50 * scale).offset(y: -18 * scale)
            RoundedRectangle(cornerRadius: 10 * scale).fill(plush).brightness(0.1)
                .overlay(RoundedRectangle(cornerRadius: 10 * scale).stroke(.white.opacity(0.5), lineWidth: 2))
                .frame(height: 28 * scale).padding(.horizontal, 12 * scale).offset(y: -6 * scale)
            HStack {
                RoundedRectangle(cornerRadius: 9 * scale).fill(plush).brightness(-0.1).frame(width: 20 * scale, height: 40 * scale)
                Spacer()
                RoundedRectangle(cornerRadius: 9 * scale).fill(plush).brightness(-0.1).frame(width: 20 * scale, height: 40 * scale)
            }
            .offset(y: -6 * scale)
            HStack {
                Capsule().fill(woodDark).frame(width: 6 * scale, height: 8 * scale)
                Spacer()
                Capsule().fill(woodDark).frame(width: 6 * scale, height: 8 * scale)
            }
            .padding(.horizontal, 14 * scale)
        }
    }

    private var paintingView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4).fill(Rarity.legendary.color.opacity(0.85))
            RoundedRectangle(cornerRadius: 2).fill(Color(red: 0.99, green: 0.95, blue: 0.88)).padding(6 * scale)
            if let b = portrait ?? shelfBreeds.first {
                Image(b.imageName).resizable().scaledToFit().padding(9 * scale)
            } else {
                Image(systemName: "cat.fill").font(.system(size: 26 * scale)).foregroundStyle(Theme.muted)
            }
        }
        .shadow(color: .black.opacity(0.12), radius: 3, y: 2)
    }

    private var fairyLightsView: some View {
        Canvas { ctx, size in
            var wire = Path()
            wire.move(to: CGPoint(x: 0, y: 4))
            let n = 4
            for i in 0..<n {
                let x0 = size.width * CGFloat(i) / CGFloat(n), x1 = size.width * CGFloat(i + 1) / CGFloat(n)
                wire.addQuadCurve(to: CGPoint(x: x1, y: 4), control: CGPoint(x: (x0 + x1) / 2, y: size.height * 1.1))
            }
            ctx.stroke(wire, with: .color(woodDark.opacity(0.7)), lineWidth: 1.5)
            let colors: [Color] = [Theme.warning, Theme.rose, Color(red: 0.4, green: 0.7, blue: 0.95), Theme.success]
            for j in 0..<12 {
                let t = (CGFloat(j) + 0.5) / 12
                let seg = t * CGFloat(n), local = seg - floor(seg)
                let y = 4 + (size.height * 1.1 - 4) * 2 * local * (1 - local)
                let r = CGRect(x: t * size.width - 4, y: y - 1, width: 8, height: 10)
                ctx.fill(Path(ellipseIn: r), with: .color(colors[j % colors.count]))
            }
        }
    }

    private var bookshelfView: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 5).fill(wood)
            VStack(spacing: 6 * scale) {
                ForEach(0..<3, id: \.self) { row in
                    HStack(alignment: .bottom, spacing: 2 * scale) {
                        ForEach(0..<5, id: \.self) { i in book(i, row: row) }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .padding(.horizontal, 8 * scale)
                    .background(woodDark.opacity(0.35))
                }
            }
            .padding(6 * scale)
        }
    }

    private func book(_ i: Int, row: Int) -> some View {
        let color: Color = Self.bookColors[(i + row * 2) % Self.bookColors.count]
        let height: CGFloat = CGFloat(22 + (i * 7 + row * 3) % 10) * scale
        return RoundedRectangle(cornerRadius: 1.5).fill(color).frame(width: 9 * scale, height: height)
    }

    private static let bookColors: [Color] = [Theme.rose, Color(red: 0.4, green: 0.6, blue: 0.9), Theme.warning, Theme.success, Color(red: 0.6, green: 0.45, blue: 0.85)]
}

private struct HammockCloth: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX + 4, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.maxX - 4, y: r.minY), control: CGPoint(x: r.midX, y: r.maxY * 1.6))
        p.addQuadCurve(to: CGPoint(x: r.minX + 4, y: r.minY), control: CGPoint(x: r.midX, y: r.maxY * 0.9))
        return p
    }
}

private struct LampShade: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX + r.width * 0.25, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - r.width * 0.25, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        p.closeSubpath()
        return p
    }
}

// MARK: - Room

/// A cat in the room other than the owner's residents: you visiting, or a friend's visiting cat.
struct RoomGuest: Identifiable, Equatable {
    var id: UUID { cat.id }
    var cat: Cat
    var label: String
    var isYou = false
}

struct Bubble: Equatable {
    var text: String?
    var symbol: String?
}

struct RoomView: View {
    let lounge: Lounge
    var residents: [Cat]
    var guests: [RoomGuest] = []
    var height: CGFloat = 380
    var bubbles: [UUID: Bubble] = [:]
    var shelfBreeds: [Breed] = []
    var portrait: Breed? = nil
    var editing = false
    var showSign = true
    var selectedItem: UUID? = nil
    var onSelectItem: (UUID) -> Void = { _ in }
    var onMoveItem: (UUID, Double, Double) -> Void = { _, _, _ in }
    var onPetCat: (Cat) -> Void = { _ in }
    /// Which place and room to show. Defaults to where the owner is, first room.
    var place: Location? = nil
    var room = 0

    @State private var spots: [UUID: CGPoint] = [:]
    @State private var facingLeft: Set<UUID> = []
    @State private var drag: [UUID: CGSize] = [:]
    @State private var hearts: [UUID: [FloatingHeart]] = [:]

    private var everyone: [(cat: Cat, label: String?, isYou: Bool)] {
        residents.prefix(5).map { ($0, $0.name, false) } + guests.map { ($0.cat, $0.label, $0.isYou) }
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let scale = w / 340
            let at = place ?? lounge.place
            ZStack(alignment: .topLeading) {
                PlaceBackdrop(place: at, lounge: lounge, room: room)
                    .frame(width: w, height: h)
                    .allowsHitTesting(false)
                if showSign {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(lounge.name).font(Theme.font(11 * scale, .heavy)).foregroundStyle(Theme.text)
                        if at != .lounge {
                            Text(at.title).font(Theme.font(9 * scale, .bold)).foregroundStyle(Theme.muted)
                        }
                    }
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(RoundedRectangle(cornerRadius: 6).fill(.white).shadow(color: .black.opacity(0.1), radius: 2, y: 1))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Rarity.legendary.color.opacity(0.5), lineWidth: 1.5))
                    .padding(10)
                    .zIndex(200)
                }
                if editing {
                    Canvas { ctx, size in
                        for x in stride(from: 0, through: size.width, by: 28) {
                            ctx.stroke(Path { $0.move(to: CGPoint(x: x, y: 0)); $0.addLine(to: CGPoint(x: x, y: size.height)) }, with: .color(Theme.muted.opacity(0.15)))
                        }
                        for y in stride(from: 0, through: size.height, by: 28) {
                            ctx.stroke(Path { $0.move(to: CGPoint(x: 0, y: y)); $0.addLine(to: CGPoint(x: size.width, y: y)) }, with: .color(Theme.muted.opacity(0.15)))
                        }
                    }
                    .allowsHitTesting(false)
                }

                ForEach(lounge.items(in: at, room: room)) { item in
                    itemView(item, w: w, h: h, scale: scale)
                }
                ForEach(everyone, id: \.cat.id) { entry in
                    catView(entry.cat, label: entry.label, isYou: entry.isYou, w: w, h: h, scale: scale)
                }
            }
            .frame(width: w, height: h)
            .clipped()
            .task(id: everyone.map(\.cat.id)) { await wander() }
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func itemView(_ item: PlacedItem, w: CGFloat, h: CGFloat, scale: CGFloat) -> some View {
        let s = item.kind.size
        let off = drag[item.id] ?? .zero
        let selected = selectedItem == item.id
        return FurnitureView(kind: item.kind, scale: scale, shelfBreeds: shelfBreeds, tint: item.tint, portrait: portrait)
            .scaleEffect(x: item.flipped ? -1 : 1, y: 1)
            .padding(4)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(selected ? Theme.rose : .clear, style: StrokeStyle(lineWidth: 2, dash: [5, 3])))
            .position(x: item.x * w + off.width, y: item.y * h - (item.kind.onWall ? 0 : s.height * scale / 2) + off.height)
            .zIndex(item.kind.onWall ? 0 : item.y * 100)
            .allowsHitTesting(editing)
            .onTapGesture { onSelectItem(item.id) }
            .gesture(DragGesture(minimumDistance: 4)
                .onChanged { v in
                    if selectedItem != item.id { onSelectItem(item.id) }
                    drag[item.id] = v.translation
                }
                .onEnded { v in
                    drag[item.id] = nil
                    onMoveItem(item.id, item.x + v.translation.width / w, item.y + v.translation.height / h)
                })
            .accessibilityLabel(item.kind.title)
    }

    private func catView(_ cat: Cat, label: String?, isYou: Bool, w: CGFloat, h: CGFloat, scale: CGFloat) -> some View {
        let p = spots[cat.id] ?? home(for: cat.id)
        let size = 92 * scale
        return VStack(spacing: 2) {
            ZStack {
                if let b = bubbles[cat.id] { BubbleView(bubble: b).offset(y: -size * 0.62) }
                CatSprite(cat: cat, size: size, animated: true)
                    .scaleEffect(x: facingLeft.contains(cat.id) ? -1 : 1, y: 1)
                HeartBurst(hearts: hearts[cat.id] ?? [])
            }
            if let label {
                Text(label).font(Theme.font(10, .bold)).foregroundStyle(Theme.text)
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    .background(Capsule().fill(.white))
                    .overlay(Capsule().stroke(isYou ? Theme.rose : .clear, lineWidth: 2))
            }
        }
        .position(x: p.x * w, y: p.y * h - size / 2)
        // Cats always draw in front of furniture (items use 0–100), so they can't vanish behind a sofa or tree.
        .zIndex(1000 + p.y * 100)
        .allowsHitTesting(!editing)
        .onTapGesture {
            Haptics.tap(.soft)
            hearts[cat.id, default: []].append(FloatingHeart(x: .random(in: -20...20)))
            onPetCat(cat)
        }
        .accessibilityLabel("\(cat.name)\(isYou ? ", you" : "")")
        .accessibilityAddTraits(.isButton)
    }

    private func home(for id: UUID) -> CGPoint {
        let ids = everyone.map(\.cat.id)
        let i = ids.firstIndex(of: id) ?? 0
        let n = max(1, ids.count)
        return CGPoint(x: 0.18 + 0.64 * Double(i) / Double(max(1, n - 1)), y: 0.78 + Double(i % 2) * 0.1)
    }

    private func wander() async {
        guard !editing else { return }
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(Double.random(in: 1.5...3)))
            guard let mover = everyone.randomElement()?.cat.id else { continue }
            let from = spots[mover] ?? home(for: mover)
            let to = CGPoint(x: Double.random(in: 0.14...0.86), y: Double.random(in: 0.74...0.95))
            if to.x < from.x { facingLeft.insert(mover) } else { facingLeft.remove(mover) }
            withAnimation(.easeInOut(duration: 2.4)) { spots[mover] = to }
        }
    }
}

// MARK: - Place backdrops

/// The walls and floor of a place. The wall meets the floor at 55% of the height in every place,
/// so furniture positions work the same everywhere.
struct PlaceBackdrop: View {
    let place: Location
    let lounge: Lounge
    var room = 0

    var body: some View {
        switch place {
        case .lounge:
            GeometryReader { geo in
                let h = geo.size.height
                ZStack(alignment: .topLeading) {
                    Rectangle().fill(lounge.wall.color).frame(height: h * 0.55)
                    WallPatternView(pattern: lounge.pattern).frame(height: h * 0.55)
                    LinearGradient(colors: lounge.floor.colors, startPoint: .top, endPoint: .bottom)
                        .frame(height: h * 0.45).offset(y: h * 0.55)
                    Rectangle().fill(.white.opacity(0.7)).frame(height: 6).offset(y: h * 0.55 - 3)
                }
            }
        case .park: Canvas { ctx, size in Self.park(&ctx, size, room) }
        case .museum: Canvas { ctx, size in Self.museum(&ctx, size, room) }
        case .mansion: Canvas { ctx, size in Self.mansion(&ctx, size, room) }
        }
    }

    private static func rgb(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) -> GraphicsContext.Shading {
        .color(Color(red: r, green: g, blue: b).opacity(a))
    }

    /// A repeatable 0–1 number, so each room looks a bit different but never changes between redraws.
    private static func jitter(_ room: Int, _ i: Int) -> Double {
        let v = sin(Double(room * 97 + i * 131) * 12.9898) * 43758.5453
        return v - v.rounded(.down)
    }

    private static func park(_ ctx: inout GraphicsContext, _ size: CGSize, _ room: Int) {
        let w = size.width, h = size.height, horizon = h * 0.55
        ctx.clip(to: Path(CGRect(origin: .zero, size: size)))
        ctx.fill(Path(CGRect(x: 0, y: 0, width: w, height: horizon)),
                 with: .linearGradient(Gradient(colors: [Color(red: 0.62, green: 0.83, blue: 0.98), Color(red: 0.88, green: 0.95, blue: 1)]),
                                       startPoint: .zero, endPoint: CGPoint(x: 0, y: horizon)))
        if room == 0 {
            ctx.fill(Path(ellipseIn: CGRect(x: w * 0.78, y: h * 0.06, width: w * 0.12, height: w * 0.12)), with: rgb(1, 0.87, 0.45))
        }
        for i in 0..<3 {
            let cx = w * (0.1 + 0.8 * jitter(room, i)), cy = h * (0.08 + 0.14 * jitter(room, i + 10)), r = w * 0.05
            for (dx, dy, k) in [(-1.1, 0.2, 0.8), (0.0, 0.0, 1.0), (1.1, 0.25, 0.75)] {
                ctx.fill(Path(ellipseIn: CGRect(x: cx + dx * r - r * k, y: cy + dy * r - r * k, width: 2 * r * k, height: 2 * r * k)),
                         with: .color(.white.opacity(0.95)))
            }
        }
        // Rolling hills and trees behind the fence.
        ctx.fill(Path(ellipseIn: CGRect(x: -w * 0.3, y: horizon - h * 0.16, width: w * 0.95, height: h * 0.4)), with: rgb(0.66, 0.84, 0.56))
        ctx.fill(Path(ellipseIn: CGRect(x: w * 0.4, y: horizon - h * 0.12, width: w * 0.95, height: h * 0.4)), with: rgb(0.6, 0.8, 0.5))
        for i in 0..<2 {
            let tx = w * (i == 0 ? 0.12 + 0.2 * jitter(room, 20) : 0.62 + 0.25 * jitter(room, 21)), base = horizon - h * 0.08
            ctx.fill(Path(roundedRect: CGRect(x: tx - 4, y: base - h * 0.1, width: 8, height: h * 0.1), cornerRadius: 3), with: rgb(0.55, 0.4, 0.28))
            ctx.fill(Path(ellipseIn: CGRect(x: tx - w * 0.07, y: base - h * 0.2, width: w * 0.14, height: h * 0.14)), with: rgb(0.42, 0.68, 0.4))
        }
        // Grass.
        ctx.fill(Path(CGRect(x: 0, y: horizon, width: w, height: h - horizon)),
                 with: .linearGradient(Gradient(colors: [Color(red: 0.6, green: 0.81, blue: 0.48), Color(red: 0.48, green: 0.72, blue: 0.4)]),
                                       startPoint: CGPoint(x: 0, y: horizon), endPoint: CGPoint(x: 0, y: h)))
        let flowers: [GraphicsContext.Shading] = [.color(.white), rgb(1, 0.72, 0.8), rgb(1, 0.87, 0.4)]
        for i in 0..<14 {
            let fx = w * jitter(room, 40 + i), fy = horizon + 14 + (h - horizon - 20) * jitter(room, 70 + i)
            ctx.fill(Path(ellipseIn: CGRect(x: fx - 3, y: fy - 3, width: 6, height: 6)), with: flowers[i % flowers.count])
        }
        // White picket fence along the horizon, where wall items can hang.
        let top = horizon - h * 0.09
        ctx.fill(Path(CGRect(x: 0, y: top + h * 0.02, width: w, height: 4)), with: .color(.white))
        ctx.fill(Path(CGRect(x: 0, y: horizon - h * 0.03, width: w, height: 4)), with: .color(.white))
        for x in stride(from: CGFloat(6), through: w, by: 18) {
            var picket = Path()
            picket.move(to: CGPoint(x: x, y: top))
            picket.addLine(to: CGPoint(x: x + 5, y: top + 5))
            picket.addLine(to: CGPoint(x: x + 5, y: horizon))
            picket.addLine(to: CGPoint(x: x - 5, y: horizon))
            picket.addLine(to: CGPoint(x: x - 5, y: top + 5))
            picket.closeSubpath()
            ctx.fill(picket, with: .color(.white))
            ctx.stroke(picket, with: .color(.black.opacity(0.06)), lineWidth: 1)
        }
    }

    private static func museum(_ ctx: inout GraphicsContext, _ size: CGSize, _ room: Int) {
        let w = size.width, h = size.height, horizon = h * 0.55
        ctx.clip(to: Path(CGRect(origin: .zero, size: size)))
        ctx.fill(Path(CGRect(x: 0, y: 0, width: w, height: horizon)), with: rgb(0.95, 0.92, 0.86))
        // Soft gallery spotlights.
        for i in 0..<2 {
            let cx = w * (i == 0 ? 0.33 : 0.67)
            ctx.fill(Path(ellipseIn: CGRect(x: cx - w * 0.2, y: -h * 0.05, width: w * 0.4, height: horizon * 0.95)),
                     with: .radialGradient(Gradient(colors: [.white.opacity(0.7), .white.opacity(0)]),
                                           center: CGPoint(x: cx, y: h * 0.12), startRadius: 0, endRadius: w * 0.22))
        }
        ctx.fill(Path(CGRect(x: 0, y: 0, width: w, height: 10)), with: rgb(0.86, 0.8, 0.7))
        ctx.fill(Path(CGRect(x: 0, y: 10, width: w, height: 3)), with: rgb(0.8, 0.72, 0.6))
        ctx.fill(Path(CGRect(x: 0, y: horizon - h * 0.07, width: w, height: h * 0.07)), with: rgb(0.9, 0.86, 0.78))
        ctx.fill(Path(CGRect(x: 0, y: horizon - h * 0.07, width: w, height: 2)), with: rgb(0.8, 0.72, 0.6))
        // Columns at both edges, so rooms line up like one long hall.
        let cw = w * 0.07
        for cx in [w * 0.045, w * 0.955] {
            ctx.fill(Path(CGRect(x: cx - cw / 2, y: 16, width: cw, height: horizon - 22)), with: rgb(0.99, 0.97, 0.93))
            for k in [-0.25, 0.0, 0.25] {
                ctx.fill(Path(CGRect(x: cx + cw * k - 0.75, y: 30, width: 1.5, height: horizon - 50)), with: rgb(0.85, 0.8, 0.72))
            }
            ctx.fill(Path(roundedRect: CGRect(x: cx - cw * 0.8, y: 13, width: cw * 1.6, height: 12), cornerRadius: 3), with: rgb(0.93, 0.89, 0.82))
            ctx.fill(Path(roundedRect: CGRect(x: cx - cw * 0.75, y: horizon - 12, width: cw * 1.5, height: 12), cornerRadius: 2), with: rgb(0.93, 0.89, 0.82))
        }
        // Marble checkerboard floor.
        let tile = w / 12
        var row = 0
        for y in stride(from: horizon, to: h, by: tile) {
            for (col, x) in stride(from: CGFloat(0), to: w, by: tile).enumerated() {
                let light = (row + col + room) % 2 == 0
                ctx.fill(Path(CGRect(x: x, y: y, width: tile + 0.5, height: tile + 0.5)),
                         with: light ? rgb(0.97, 0.96, 0.94) : rgb(0.84, 0.82, 0.8))
            }
            row += 1
        }
        ctx.fill(Path(CGRect(x: 0, y: horizon, width: w, height: 4)), with: .color(.black.opacity(0.06)))
    }

    private static func mansion(_ ctx: inout GraphicsContext, _ size: CGSize, _ room: Int) {
        let w = size.width, h = size.height, horizon = h * 0.55
        ctx.clip(to: Path(CGRect(origin: .zero, size: size)))
        let gold = rgb(0.88, 0.7, 0.32)
        ctx.fill(Path(CGRect(x: 0, y: 0, width: w, height: horizon)), with: rgb(0.62, 0.22, 0.32))
        // Damask diamonds.
        var r = 0
        for y in stride(from: CGFloat(22), to: horizon - h * 0.12, by: 30) {
            for x in stride(from: CGFloat(r % 2 == 0 ? 15 : 30), to: w, by: 30) {
                var d = Path()
                d.move(to: CGPoint(x: x, y: y - 6)); d.addLine(to: CGPoint(x: x + 5, y: y))
                d.addLine(to: CGPoint(x: x, y: y + 6)); d.addLine(to: CGPoint(x: x - 5, y: y)); d.closeSubpath()
                ctx.fill(d, with: rgb(1, 0.85, 0.6, 0.16))
            }
            r += 1
        }
        ctx.fill(Path(CGRect(x: 0, y: 0, width: w, height: 8)), with: gold)
        // Cream wainscoting with gold panels.
        let wy = horizon - h * 0.12
        ctx.fill(Path(CGRect(x: 0, y: wy, width: w, height: horizon - wy)), with: rgb(0.97, 0.92, 0.85))
        ctx.fill(Path(CGRect(x: 0, y: wy, width: w, height: 3)), with: gold)
        let panels = 4
        for i in 0..<panels {
            let pw = w / CGFloat(panels)
            ctx.stroke(Path(roundedRect: CGRect(x: CGFloat(i) * pw + 8, y: wy + 8, width: pw - 16, height: horizon - wy - 14), cornerRadius: 3),
                       with: rgb(0.85, 0.72, 0.5), lineWidth: 1.5)
        }
        // Chandelier.
        let cx = w * (room % 2 == 0 ? 0.5 : 0.35)
        ctx.fill(Path(CGRect(x: cx - 1, y: 8, width: 2, height: h * 0.05)), with: gold)
        var arm = Path()
        arm.move(to: CGPoint(x: cx - w * 0.09, y: h * 0.07))
        arm.addQuadCurve(to: CGPoint(x: cx + w * 0.09, y: h * 0.07), control: CGPoint(x: cx, y: h * 0.14))
        ctx.stroke(arm, with: gold, lineWidth: 3)
        for k in [-1.0, -0.5, 0.0, 0.5, 1.0] {
            let fx = cx + w * 0.09 * k, fy = h * 0.07 + (k == 0 ? h * 0.035 : (abs(k) < 1 ? h * 0.02 : 0))
            ctx.fill(Path(ellipseIn: CGRect(x: fx - 7, y: fy - 13, width: 14, height: 14)),
                     with: .radialGradient(Gradient(colors: [Color(red: 1, green: 0.93, blue: 0.6), .clear]),
                                           center: CGPoint(x: fx, y: fy - 6), startRadius: 0, endRadius: 8))
            ctx.fill(Path(roundedRect: CGRect(x: fx - 2, y: fy - 6, width: 4, height: 7), cornerRadius: 1), with: .color(.white))
        }
        // Parquet floor with a red runner carpet.
        ctx.fill(Path(CGRect(x: 0, y: horizon, width: w, height: h - horizon)), with: rgb(0.7, 0.5, 0.34))
        var row = 0
        for y in stride(from: horizon, to: h, by: 12) {
            ctx.fill(Path(CGRect(x: 0, y: y, width: w, height: 1)), with: rgb(0.55, 0.38, 0.25, 0.5))
            for x in stride(from: CGFloat(row % 2 == 0 ? 0 : 24), to: w, by: 48) {
                ctx.fill(Path(CGRect(x: x, y: y, width: 1, height: 12)), with: rgb(0.55, 0.38, 0.25, 0.5))
            }
            row += 1
        }
        let rug = CGRect(x: w * 0.12, y: horizon + h * 0.06, width: w * 0.76, height: h - horizon - h * 0.06)
        ctx.fill(Path(rug), with: rgb(0.74, 0.2, 0.28))
        ctx.stroke(Path(rug.insetBy(dx: 5, dy: 5)), with: gold, lineWidth: 2)
        ctx.fill(Path(CGRect(x: 0, y: horizon, width: w, height: 4)), with: .color(.black.opacity(0.12)))
    }
}

/// Repeating wallpaper drawn over the wall colour.
struct WallPatternView: View {
    let pattern: WallPattern

    var body: some View {
        Canvas { ctx, size in
            let ink = GraphicsContext.Shading.color(Theme.text.opacity(0.07))
            switch pattern {
            case .plain:
                break
            case .stripes:
                for x in stride(from: 0, through: size.width, by: 28) {
                    ctx.fill(Path(CGRect(x: x, y: 0, width: 12, height: size.height)), with: ink)
                }
            case .dots:
                for (row, y) in stride(from: 12, through: size.height, by: 24).enumerated() {
                    for x in stride(from: row % 2 == 0 ? 12 : 24, through: size.width, by: 24) {
                        ctx.fill(Path(ellipseIn: CGRect(x: x - 3, y: y - 3, width: 6, height: 6)), with: ink)
                    }
                }
            case .paws, .hearts:
                let symbol = ctx.resolveSymbol(id: 0)
                for (row, y) in stride(from: 18, through: size.height, by: 36).enumerated() {
                    for x in stride(from: row % 2 == 0 ? 18 : 36, through: size.width, by: 36) {
                        if let symbol { ctx.draw(symbol, at: CGPoint(x: x, y: y)) }
                    }
                }
            }
        } symbols: {
            Image(systemName: pattern == .hearts ? "heart.fill" : "pawprint.fill")
                .font(.system(size: 12))
                .foregroundStyle(Theme.text.opacity(0.08))
                .tag(0)
        }
    }
}

struct BubbleView: View {
    let bubble: Bubble

    var body: some View {
        Group {
            if let t = bubble.text {
                Text(t).font(Theme.font(12, .bold)).lineLimit(1).fixedSize()
            } else if let s = bubble.symbol {
                Image(systemName: s).font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.rose)
            }
        }
        .foregroundStyle(Theme.text)
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 12).fill(.white).shadow(color: .black.opacity(0.12), radius: 6, y: 2))
        .transition(.scale.combined(with: .opacity))
    }
}
