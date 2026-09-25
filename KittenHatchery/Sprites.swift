import SwiftUI
import AVFoundation

/// A cat drawn from its breed's Higgsfield art and sized by growth stage.
struct CatSprite: View {
    let cat: Cat
    var size: CGFloat = 160
    var animated = true
    var mood: Mood = .idle

    enum Mood { case idle, happy, sleepy }

    @State private var breathe = false

    var body: some View {
        Image(cat.kind.imageName)
            .resizable()
            .scaledToFit()
            // Cats from before breeds existed keep their element tint.
            .hueRotation(.degrees(cat.breed == nil ? cat.element.hue : 0))
            .saturation(cat.breed == nil ? cat.element.saturation : 1)
            .frame(width: size, height: size)
            .scaleEffect(cat.stage.scale)
            .scaleEffect(x: 1, y: breathe ? 1.035 : 1, anchor: .bottom)
            .offset(y: mood == .happy && breathe ? -10 : 0)
            .rotationEffect(.degrees(mood == .sleepy ? -12 : 0), anchor: .bottom)
            .shadow(color: glow, radius: cat.stage == .legend ? 18 : 10)
            .overlay {
                if cat.rarity == .legendary && animated { Sparkles(size: size) }
            }
            .overlay(alignment: .topTrailing) {
                if mood == .sleepy {
                    Text("z z z").font(Theme.font(size * 0.12, .heavy)).foregroundStyle(Theme.muted)
                        .offset(x: -size * 0.05, y: size * 0.05)
                }
            }
            .onAppear {
                guard animated else { return }
                let speed = mood == .happy ? 0.35 : (mood == .sleepy ? 1.8 : 1.3)
                withAnimation(.easeInOut(duration: speed).repeatForever(autoreverses: true)) { breathe = true }
            }
    }

    private var glow: Color {
        switch cat.rarity {
        case .legendary: Rarity.legendary.color.opacity(0.7)
        case .epic: Rarity.epic.color.opacity(0.5)
        case .rare: Rarity.rare.color.opacity(0.3)
        case .basic: .black.opacity(cat.stage == .legend ? 0.25 : 0.08)
        }
    }
}

/// Twinkling gold stars around legendary cats.
struct Sparkles: View {
    let size: CGFloat
    @State private var on = false
    private let spots: [(CGFloat, CGFloat, CGFloat, Double)] = [(-0.42, -0.3, 0.09, 0), (0.4, -0.38, 0.07, 0.4), (0.46, 0.1, 0.06, 0.8), (-0.46, 0.2, 0.05, 1.2), (0.05, -0.5, 0.05, 0.6)]

    var body: some View {
        ZStack {
            ForEach(0..<spots.count, id: \.self) { i in
                let s = spots[i]
                Image(systemName: "sparkle")
                    .font(.system(size: size * s.2, weight: .bold))
                    .foregroundStyle(Rarity.legendary.color)
                    .offset(x: size * s.0, y: size * s.1)
                    .opacity(on ? 1 : 0.15)
                    .scaleEffect(on ? 1 : 0.5)
                    .animation(.easeInOut(duration: 0.9).repeatForever().delay(s.3), value: on)
            }
        }
        .allowsHitTesting(false)
        .onAppear { on = true }
    }
}

/// A breed's Higgsfield idle loop, playing silently on repeat.
struct LoopingVideo: UIViewRepresentable {
    let resource: String

    func makeUIView(context: Context) -> PlayerView {
        let view = PlayerView()
        if let url = Bundle.main.url(forResource: resource, withExtension: "mp4") {
            let item = AVPlayerItem(url: url)
            let player = AVQueuePlayer()
            player.isMuted = true
            context.coordinator.looper = AVPlayerLooper(player: player, templateItem: item)
            view.playerLayer.player = player
            view.playerLayer.videoGravity = .resizeAspectFill
            player.play()
        }
        return view
    }

    func updateUIView(_ uiView: PlayerView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator { var looper: AVPlayerLooper? }

    final class PlayerView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }
}

// MARK: - Eggs

struct EggShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let w = r.width, h = r.height
        p.move(to: CGPoint(x: r.midX, y: r.minY))
        p.addCurve(to: CGPoint(x: r.maxX, y: r.minY + h * 0.62),
                   control1: CGPoint(x: r.minX + w * 0.82, y: r.minY),
                   control2: CGPoint(x: r.maxX, y: r.minY + h * 0.36))
        p.addCurve(to: CGPoint(x: r.midX, y: r.maxY),
                   control1: CGPoint(x: r.maxX, y: r.minY + h * 0.86),
                   control2: CGPoint(x: r.minX + w * 0.78, y: r.maxY))
        p.addCurve(to: CGPoint(x: r.minX, y: r.minY + h * 0.62),
                   control1: CGPoint(x: r.minX + w * 0.22, y: r.maxY),
                   control2: CGPoint(x: r.minX, y: r.minY + h * 0.86))
        p.addCurve(to: CGPoint(x: r.midX, y: r.minY),
                   control1: CGPoint(x: r.minX, y: r.minY + h * 0.36),
                   control2: CGPoint(x: r.minX + w * 0.18, y: r.minY))
        return p
    }
}

/// Zig-zag line across the egg; `top` clips the upper shell half.
struct CrackShape: Shape {
    var closed: Bool? = nil // nil = just the crack line, true = top half, false = bottom half

    func path(in r: CGRect) -> Path {
        let y = r.minY + r.height * 0.5
        let teeth = 7
        var pts: [CGPoint] = []
        for i in 0...teeth {
            let x = r.minX + r.width * CGFloat(i) / CGFloat(teeth)
            pts.append(CGPoint(x: x, y: y + (i.isMultiple(of: 2) ? -r.height * 0.05 : r.height * 0.05)))
        }
        var p = Path()
        switch closed {
        case nil:
            p.move(to: pts[0])
            pts.dropFirst().forEach { p.addLine(to: $0) }
        case .some(true):
            p.move(to: CGPoint(x: r.minX, y: r.minY))
            p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
            p.addLine(to: pts.last!)
            pts.reversed().forEach { p.addLine(to: $0) }
            p.closeSubpath()
        case .some(false):
            p.move(to: pts[0])
            pts.dropFirst().forEach { p.addLine(to: $0) }
            p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
            p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
            p.closeSubpath()
        }
        return p
    }
}

struct EggView: View {
    let rarity: Rarity
    var size: CGFloat = 140
    var crack: CGFloat = 0

    var body: some View {
        ZStack {
            EggShape()
                .fill(LinearGradient(colors: rarity.shell, startPoint: .topLeading, endPoint: .bottomTrailing))
            // Spots
            Canvas { ctx, s in
                let spots: [(CGFloat, CGFloat, CGFloat)] = [(0.3, 0.35, 0.12), (0.66, 0.5, 0.09), (0.4, 0.7, 0.1), (0.7, 0.78, 0.06)]
                for (x, y, r) in spots {
                    let rect = CGRect(x: s.width * x - s.width * r / 2, y: s.height * y - s.width * r / 2, width: s.width * r, height: s.width * r)
                    ctx.fill(Path(ellipseIn: rect), with: .color(.white.opacity(0.55)))
                }
            }
            .clipShape(EggShape())
            // Shine
            Ellipse().fill(.white.opacity(0.6))
                .frame(width: size * 0.13, height: size * 0.22)
                .rotationEffect(.degrees(20))
                .offset(x: -size * 0.2, y: -size * 0.28)
            CrackShape()
                .trim(from: 0, to: crack)
                .stroke(Theme.text.opacity(0.7), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
        }
        .frame(width: size * 0.78, height: size)
        .shadow(color: rarity.color.opacity(rarity == .basic ? 0.15 : 0.45), radius: 12, y: 6)
    }
}

/// Upper or lower half of a cracked egg, for the burst animation.
struct EggHalf: View {
    let rarity: Rarity
    let top: Bool
    var size: CGFloat = 140

    var body: some View {
        EggShape()
            .fill(LinearGradient(colors: rarity.shell, startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: size * 0.78, height: size)
            .clipShape(CrackShape(closed: top))
    }
}
