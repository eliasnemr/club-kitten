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
            ZStack(alignment: .topLeading) {
                Rectangle().fill(lounge.wall.color).frame(height: h * 0.55)
                WallPatternView(pattern: lounge.pattern).frame(height: h * 0.55).allowsHitTesting(false)
                if showSign {
                    Text(lounge.name).font(Theme.font(11 * scale, .heavy)).foregroundStyle(Theme.text)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(RoundedRectangle(cornerRadius: 6).fill(.white).shadow(color: .black.opacity(0.1), radius: 2, y: 1))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Rarity.legendary.color.opacity(0.5), lineWidth: 1.5))
                        .padding(10)
                        .zIndex(200)
                }
                LinearGradient(colors: lounge.floor.colors, startPoint: .top, endPoint: .bottom)
                    .frame(height: h * 0.45).offset(y: h * 0.55)
                Rectangle().fill(.white.opacity(0.7)).frame(height: 6).offset(y: h * 0.55 - 3)
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

                ForEach(lounge.items) { item in
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
