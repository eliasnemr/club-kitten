import SwiftUI

// MARK: - Pond fishing (HP)

/// Hold to lower the hook, let go to reel it back up. Fish of different sizes swim past;
/// touch one with the hook and it's reeled in for points. Boots and cans waste time.
struct PondFishingGame: View {
    @Binding var score: Int
    let start: Date
    let cat: Cat

    @State private var pond = PondModel()
    @State private var holding = false

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack(alignment: .topLeading) {
                backdrop(size)
                ForEach(pond.swimmers) { s in
                    SwimmerView(kind: s.kind, facingLeft: s.speed < 0)
                        .position(x: s.x, y: s.y)
                }
                lineAndHook(size)
                CatSprite(cat: cat, size: 84, mood: pond.carrying != nil ? .happy : .idle)
                    .position(x: size.width * 0.16, y: pond.waterTop - 34)
                ForEach(pond.pops) { p in
                    PondPop(text: p.text, color: p.color)
                        .position(x: pond.hookX + 34, y: pond.waterTop - 20)
                }
                if Date().timeIntervalSince(start) < 3.5 {
                    Text("Hold to lower the hook · let go to reel in")
                        .font(Theme.font(13, .bold)).foregroundStyle(.white)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Capsule().fill(.black.opacity(0.28)))
                        .frame(maxWidth: .infinity)
                        .position(x: size.width / 2, y: size.height - 24)
                        .transition(.opacity)
                }
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { _ in if !holding { holding = true; Haptics.tap(.light) } }
                .onEnded { _ in holding = false })
            .accessibilityElement()
            .accessibilityLabel("Pond. Hold to lower the hook, let go to reel in.")
            .accessibilityAddTraits(.allowsDirectInteraction)
            .onAppear { pond.layout(size) }
            .onChange(of: size) { _, s in pond.layout(s) }
            .task {
                var last = Date()
                while !Task.isCancelled {
                    try? await Task.sleep(for: .milliseconds(16))
                    let now = Date()
                    if let caught = pond.step(dt: min(0.05, now.timeIntervalSince(last)), holding: holding,
                                              elapsed: now.timeIntervalSince(start)) {
                        score += caught.points
                        caught.points > 0 ? Haptics.success() : Haptics.warning()
                    }
                    last = now
                }
            }
        }
    }

    private func backdrop(_ size: CGSize) -> some View {
        ZStack(alignment: .topLeading) {
            // Sky and far bank.
            LinearGradient(colors: [Color(red: 0.86, green: 0.94, blue: 0.99), Color(red: 0.95, green: 0.97, blue: 0.93)],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: pond.waterTop)
            Ellipse().fill(Color(red: 0.62, green: 0.8, blue: 0.52))
                .frame(width: size.width * 1.2, height: 60)
                .position(x: size.width * 0.6, y: pond.waterTop - 4)
            // Water, getting deeper.
            LinearGradient(colors: [Color(red: 0.5, green: 0.76, blue: 0.9), Color(red: 0.22, green: 0.46, blue: 0.66)],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: max(0, size.height - pond.waterTop))
                .offset(y: pond.waterTop)
            // Ripples and pebbles.
            ForEach(0..<6, id: \.self) { i in
                Capsule().fill(.white.opacity(0.18))
                    .frame(width: 40 + CGFloat(i % 3) * 18, height: 3)
                    .position(x: size.width * CGFloat([0.2, 0.55, 0.85, 0.35, 0.7, 0.1][i]),
                              y: pond.waterTop + 16 + CGFloat(i) * (size.height - pond.waterTop - 40) / 6)
            }
            ForEach(0..<5, id: \.self) { i in
                Ellipse().fill(Color(red: 0.42, green: 0.36, blue: 0.3).opacity(0.55))
                    .frame(width: 26 + CGFloat(i * 7 % 18), height: 12)
                    .position(x: size.width * CGFloat([0.12, 0.33, 0.58, 0.77, 0.93][i]), y: size.height - 8)
            }
            // Reeds on the right bank.
            ForEach(0..<4, id: \.self) { i in
                Capsule().fill(Color(red: 0.36, green: 0.6, blue: 0.36))
                    .frame(width: 5, height: 46 + CGFloat(i) * 8)
                    .rotationEffect(.degrees(Double(i - 2) * 6), anchor: .bottom)
                    .position(x: size.width - 26 + CGFloat(i) * 6, y: pond.waterTop - 18 - CGFloat(i) * 4)
            }
            // The dock the cat sits on.
            RoundedRectangle(cornerRadius: 4).fill(Color(red: 0.62, green: 0.45, blue: 0.3))
                .frame(width: size.width * 0.34, height: 12)
                .position(x: size.width * 0.15, y: pond.waterTop + 2)
            ForEach(0..<2, id: \.self) { i in
                Rectangle().fill(Color(red: 0.5, green: 0.36, blue: 0.24))
                    .frame(width: 8, height: 34)
                    .position(x: size.width * (0.05 + CGFloat(i) * 0.2), y: pond.waterTop + 22)
            }
        }
    }

    private func lineAndHook(_ size: CGSize) -> some View {
        let tip = CGPoint(x: pond.hookX, y: pond.waterTop - 46)
        let rodBase = CGPoint(x: size.width * 0.2, y: pond.waterTop - 20)
        return ZStack {
            Path { p in p.move(to: rodBase); p.addLine(to: tip) }
                .stroke(Color(red: 0.45, green: 0.3, blue: 0.2), style: StrokeStyle(lineWidth: 4, lineCap: .round))
            Path { p in p.move(to: tip); p.addLine(to: CGPoint(x: pond.hookX, y: pond.hookY)) }
                .stroke(.white.opacity(0.85), lineWidth: 1.2)
            if let carried = pond.carrying {
                SwimmerView(kind: carried, facingLeft: false)
                    .rotationEffect(.degrees(-80))
                    .position(x: pond.hookX, y: pond.hookY + carried.size * 0.35)
            } else {
                HookShape()
                    .stroke(Color(red: 0.75, green: 0.75, blue: 0.8), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .frame(width: 12, height: 16)
                    .position(x: pond.hookX, y: pond.hookY + 6)
                Circle().fill(Theme.rose).frame(width: 9, height: 9)   // bobber-style weight
                    .position(x: pond.hookX, y: pond.hookY - 6)
            }
        }
    }
}

// MARK: - Model

enum PondCatch: Equatable {
    case small, medium, big, golden, boot, can

    var points: Int {
        switch self {
        case .small: 1
        case .medium: 2
        case .big: 3
        case .golden: 6
        case .boot, .can: 0
        }
    }
    var size: CGFloat {
        switch self {
        case .small: 26
        case .medium: 34
        case .big: 44
        case .golden: 34
        case .boot, .can: 30
        }
    }
    var isJunk: Bool { self == .boot || self == .can }
}

struct Swimmer: Identifiable {
    let id = UUID()
    var kind: PondCatch
    var x: CGFloat
    var y: CGFloat
    var speed: CGFloat
    var wobble: Double
}

struct PondPopItem: Identifiable {
    let id = UUID()
    let text: String
    let color: Color
}

@Observable
final class PondModel {
    var swimmers: [Swimmer] = []
    var hookY: CGFloat = 0
    var carrying: PondCatch?
    var pops: [PondPopItem] = []
    private(set) var waterTop: CGFloat = 140
    private(set) var hookX: CGFloat = 160
    private var size: CGSize = .zero

    func layout(_ s: CGSize) {
        guard s.width > 0, s.height > 0 else { return }
        let first = size == .zero
        size = s
        waterTop = s.height * 0.3
        hookX = s.width * 0.46
        if first {
            hookY = waterTop + 10
            for _ in 0..<5 { spawn(elapsed: 0, anywhere: true) }
        }
    }

    /// Advances the pond by `dt` seconds. Returns what was landed on this step, if anything.
    func step(dt: Double, holding: Bool, elapsed: Double) -> PondCatch? {
        guard size != .zero else { return nil }
        let bottom = size.height - 22
        var landed: PondCatch?

        if let c = carrying {
            // Reel the catch up; junk is heavy and slow.
            hookY -= CGFloat(dt) * (c.isJunk ? 170 : 330)
            if hookY <= waterTop + 4 {
                hookY = waterTop + 4
                landed = c
                carrying = nil
                pop(c)
            }
        } else if holding {
            hookY = min(bottom, hookY + CGFloat(dt) * 230)
        } else {
            hookY = max(waterTop + 4, hookY - CGFloat(dt) * 300)
        }

        // Fish get a little faster as the round goes on.
        let pace = 1 + CGFloat(min(elapsed, 30)) / 30 * 0.6
        for i in swimmers.indices {
            swimmers[i].x += swimmers[i].speed * pace * CGFloat(dt)
            swimmers[i].wobble += dt * 3
            swimmers[i].y += CGFloat(sin(swimmers[i].wobble)) * 0.25
        }
        swimmers.removeAll { $0.x < -60 || $0.x > size.width + 60 }

        if carrying == nil, hookY > waterTop + 12,
           let i = swimmers.firstIndex(where: { abs($0.x - hookX) < $0.kind.size * 0.6 && abs($0.y - hookY) < $0.kind.size * 0.55 }) {
            carrying = swimmers[i].kind
            swimmers.remove(at: i)
            Haptics.tap(.medium)
        }

        while swimmers.count < 5 { spawn(elapsed: elapsed, anywhere: false) }
        return landed
    }

    private func spawn(elapsed: Double, anywhere: Bool) {
        let roll = Double.random(in: 0..<1)
        let kind: PondCatch
        switch roll {
        case ..<0.06: kind = .golden
        case ..<0.2: kind = Bool.random() ? .boot : .can
        case ..<0.45: kind = .big
        case ..<0.72: kind = .medium
        default: kind = .small
        }
        let fromLeft = Bool.random()
        let base: CGFloat = kind == .golden ? 150 : (kind == .big ? 60 : (kind == .small ? 105 : 80))
        let speed = (base + .random(in: -15...20)) * (fromLeft ? 1 : -1)
        // Bigger fish and the golden one live deeper.
        let depthBias: CGFloat = kind == .big || kind == .golden ? 0.45 : 0.1
        let y = waterTop + 36 + (size.height - waterTop - 70) * CGFloat.random(in: depthBias...1)
        let x = anywhere ? CGFloat.random(in: 0...size.width) : (fromLeft ? -40 : size.width + 40)
        swimmers.append(Swimmer(kind: kind, x: x, y: y, speed: speed, wobble: .random(in: 0...6)))
    }

    private func pop(_ c: PondCatch) {
        let item: PondPopItem
        switch c {
        case .golden: item = PondPopItem(text: "Golden! +6", color: Theme.warning)
        case .boot: item = PondPopItem(text: "An old boot…", color: .white)
        case .can: item = PondPopItem(text: "A tin can…", color: .white)
        default: item = PondPopItem(text: "+\(c.points)", color: .white)
        }
        pops.append(item)
        let id = item.id
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1))
            self.pops.removeAll { $0.id == id }
        }
    }
}

// MARK: - Pieces

struct SwimmerView: View {
    let kind: PondCatch
    let facingLeft: Bool

    var body: some View {
        Group {
            switch kind {
            case .boot:
                Image(systemName: "shoe.fill").foregroundStyle(Color(red: 0.36, green: 0.3, blue: 0.26))
            case .can:
                Image(systemName: "cylinder.fill").foregroundStyle(Color(red: 0.62, green: 0.66, blue: 0.7))
            case .golden:
                Image(systemName: "fish.fill").foregroundStyle(
                    LinearGradient(colors: [Color(red: 1, green: 0.86, blue: 0.3), Theme.warning], startPoint: .top, endPoint: .bottom))
                    .shadow(color: Theme.warning.opacity(0.8), radius: 6)
            default:
                Image(systemName: "fish.fill").foregroundStyle(kind == .big ? Color(red: 0.98, green: 0.55, blue: 0.4)
                                                              : kind == .medium ? Color(red: 0.98, green: 0.7, blue: 0.5)
                                                              : Color(red: 0.75, green: 0.88, blue: 0.98))
            }
        }
        .font(.system(size: kind.size))
        .scaleEffect(x: facingLeft ? 1 : -1, y: 1)   // the symbol faces left
        .accessibilityHidden(true)
    }
}

private struct HookShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.midX, y: r.minY))
        p.addLine(to: CGPoint(x: r.midX, y: r.maxY - r.width / 2))
        p.addArc(center: CGPoint(x: r.midX - r.width / 4, y: r.maxY - r.width / 2), radius: r.width / 4,
                 startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
        return p
    }
}

private struct PondPop: View {
    let text: String
    let color: Color
    @State private var up = false

    var body: some View {
        Text(text).font(Theme.font(18, .heavy)).foregroundStyle(color)
            .shadow(color: .black.opacity(0.35), radius: 2)
            .offset(y: up ? -44 : 0)
            .opacity(up ? 0 : 1)
            .onAppear { withAnimation(.easeOut(duration: 1)) { up = true } }
            .allowsHitTesting(false)
    }
}
