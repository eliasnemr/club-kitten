import SwiftUI
import AVFoundation

/// What a cat is doing right now, for livelier rooms. `settle` is the moment after walking,
/// when cats with sprite frames turn to face you and sit down.
enum CatAction: Equatable { case idle, walk, settle, stretch, nap }

/// A cat drawn from its breed's Higgsfield art and sized by growth stage.
struct CatSprite: View {
    let cat: Cat
    var size: CGFloat = 160
    var animated = true
    var mood: Mood = .idle
    var action: CatAction = .idle
    /// Bump to make the cat jump (for example when it's petted).
    var jump = 0

    enum Mood { case idle, happy, sleepy }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathe = false
    @State private var hop = false
    @State private var tilt: Double = 0
    /// True while the sprite jump plays.
    @State private var jumping = false

    /// Side-view frames for this breed, if it has them (not for old element-tinted cats).
    private var sheet: SpriteSheet? { cat.breed == nil || !lively ? nil : SpriteSheet.for(cat.kind) }
    /// Frames are drawn at the same height as the front art, so poses line up.
    private var spriteHeight: CGFloat { size * cat.stage.scale }

    private enum Shown: Equatable { case front, walk, jump, sit }
    private var shown: Shown {
        guard let sheet else { return .front }
        if jumping { return .jump }
        if action == .walk { return .walk }
        if action == .settle, sheet.sit != nil { return .sit }
        return .front
    }

    private var lively: Bool { animated && !reduceMotion }
    private var shownMood: Mood { action == .nap ? .sleepy : mood }

    var body: some View {
        // Crossfades between clips; the turn-and-sit ends on the front pose, so stopping
        // settles into sitting instead of snapping.
        ZStack {
            switch (shown, sheet) {
            case (.jump, let sheet?):
                clip("jump", sheet.jump, loop: false).id("jump-\(jump)")
            case (.walk, let sheet?):
                clip("walk", sheet.walk, loop: true)
            case (.sit, let sheet?):
                if let sit = sheet.sit { clip("sit", sit, loop: false) }
            default:
                frontView
                    .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.96, anchor: .bottom)),
                                            removal: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.28), value: shown)
        .onChange(of: jump) { _, _ in
            guard let sheet else { return }
            jumping = true
            let mine = jump
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(Double(sheet.jump.frames) / SpriteSheet.fps))
                if jump == mine { jumping = false }
            }
        }
    }

    private func clip(_ name: String, _ info: SpriteSheet.Clip, loop: Bool) -> some View {
        SpriteClipView(breed: cat.kind, clip: name, info: info, height: spriteHeight, loop: loop)
            .frame(width: size, height: size, alignment: .bottom)
            .transition(.opacity)
    }

    /// The front-facing art with code animation (idle, stretch, nap, and walking/jumping
    /// for breeds without sprite frames).
    private var frontView: some View {
        sprite
            // Walking: a little bounce and waddle on every step.
            .offset(y: hop ? -size * 0.05 : 0)
            .rotationEffect(.degrees(action == .walk && lively ? (hop ? 3 : -3) : tilt), anchor: .bottom)
            // Stretching: long and low for a moment.
            .scaleEffect(x: action == .stretch ? 1.14 : 1, y: action == .stretch ? 0.86 : 1, anchor: .bottom)
            .animation(.spring(response: 0.45, dampingFraction: 0.6), value: action)
            .keyframeAnimator(initialValue: JumpPose(), trigger: jump) { content, pose in
                content
                    .scaleEffect(x: pose.sx, y: pose.sy, anchor: .bottom)
                    .offset(y: pose.y * size)
            } keyframes: { _ in
                KeyframeTrack(\.y) {
                    CubicKeyframe(0, duration: 0.08)
                    SpringKeyframe(reduceMotion || sheet != nil ? 0 : -0.32, duration: 0.24, spring: .snappy)
                    CubicKeyframe(0, duration: 0.2)
                    CubicKeyframe(0, duration: 0.18)
                }
                KeyframeTrack(\.sy) {
                    CubicKeyframe(0.86, duration: 0.08)
                    CubicKeyframe(1.08, duration: 0.24)
                    CubicKeyframe(0.9, duration: 0.2)
                    SpringKeyframe(1, duration: 0.18)
                }
                KeyframeTrack(\.sx) {
                    CubicKeyframe(1.1, duration: 0.08)
                    CubicKeyframe(0.94, duration: 0.24)
                    CubicKeyframe(1.08, duration: 0.2)
                    SpringKeyframe(1, duration: 0.18)
                }
            }
            .onChange(of: action) { _, a in setHop(a == .walk) }
            .onAppear { setHop(action == .walk) }
            .task(id: action == .idle && lively) {
                // Now and then an idle cat looks around.
                guard action == .idle, lively else { tilt = 0; return }
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(Double.random(in: 3.5...8)))
                    guard !Task.isCancelled else { return }
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.55)) { tilt = Bool.random() ? 6 : -6 }
                    try? await Task.sleep(for: .seconds(Double.random(in: 0.8...1.6)))
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { tilt = 0 }
                }
            }
    }

    private func setHop(_ on: Bool) {
        guard lively else { hop = false; return }
        if on {
            withAnimation(.easeInOut(duration: 0.2).repeatForever(autoreverses: true)) { hop = true }
        } else {
            withAnimation(.easeOut(duration: 0.15)) { hop = false }
        }
    }

    private var sprite: some View {
        Image(cat.kind.imageName)
            .resizable()
            .scaledToFit()
            // Cats from before breeds existed keep their element tint.
            .hueRotation(.degrees(cat.breed == nil ? cat.element.hue : 0))
            .saturation(cat.breed == nil ? cat.element.saturation : 1)
            .frame(width: size, height: size)
            .scaleEffect(cat.stage.scale)
            .scaleEffect(x: 1, y: breathe ? 1.035 : 1, anchor: .bottom)
            .offset(y: shownMood == .happy && breathe ? -10 : 0)
            .rotationEffect(.degrees(shownMood == .sleepy ? -12 : 0), anchor: .bottom)
            .shadow(color: glow, radius: cat.stage == .legend ? 18 : 10)
            .overlay {
                if cat.rarity == .legendary && animated { Sparkles(size: size) }
            }
            .overlay(alignment: .topTrailing) {
                if shownMood == .sleepy {
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

    private struct JumpPose {
        var y: CGFloat = 0
        var sx: CGFloat = 1
        var sy: CGFloat = 1
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
