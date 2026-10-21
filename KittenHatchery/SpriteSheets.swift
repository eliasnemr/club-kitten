import SwiftUI

/// Side-view walk and jump frames made with Higgsfield (Assets.xcassets/Sprites).
/// Breeds without frames keep the animated front-facing art.
struct SpriteSheet {
    struct Clip {
        let frames: Int
        /// Width ÷ height of each frame.
        let aspect: CGFloat
        /// Frame height compared with the walk frames (the jump has headroom for the leap).
        var heightRatio: CGFloat = 1
        /// Horizontal nudge, as a fraction of the walk height, so both clips stand in the same spot.
        var centerShift: CGFloat = 0
    }
    let walk: Clip
    let jump: Clip
    /// Turning to face you and sitting down, played when the cat stops walking.
    var sit: Clip? = nil
    static let fps: Double = 12

    static func name(_ breed: Breed, _ clip: String, _ i: Int) -> String {
        "Sprite-\(breed.rawValue)-\(clip)-\(String(format: "%02d", i))"
    }

    // Measured by the sprite script when the frames were made.
    static let all: [Breed: SpriteSheet] = [
        .cream: SpriteSheet(walk: Clip(frames: 12, aspect: 1.119),
                            jump: Clip(frames: 19, aspect: 1.0433, heightRatio: 1.2095, centerShift: -0.0293),
                            sit: Clip(frames: 20, aspect: 1.1818, heightRatio: 0.9952, centerShift: 0.0594)),
        .tabby: SpriteSheet(walk: Clip(frames: 11, aspect: 1.1952),
                            jump: Clip(frames: 22, aspect: 1.0705, heightRatio: 1.1476, centerShift: 0.0168),
                            sit: Clip(frames: 20, aspect: 1.239, heightRatio: 0.9762, centerShift: 0.071)),
        .tuxedo: SpriteSheet(walk: Clip(frames: 13, aspect: 1.1714),
                            jump: Clip(frames: 22, aspect: 1.0451, heightRatio: 1.1619, centerShift: 0.0014),
                            sit: Clip(frames: 23, aspect: 1.107, heightRatio: 1.0238, centerShift: 0.0866)),
        .calico: SpriteSheet(walk: Clip(frames: 14, aspect: 1.2),
                            jump: Clip(frames: 22, aspect: 1.0357, heightRatio: 1.2, centerShift: -0.0192),
                            sit: Clip(frames: 22, aspect: 1.1528, heightRatio: 1.0286, centerShift: 0.1033)),
        .siamese: SpriteSheet(walk: Clip(frames: 12, aspect: 1.1381),
                            jump: Clip(frames: 22, aspect: 1.049, heightRatio: 1.1667, centerShift: -0.0201),
                            sit: Clip(frames: 22, aspect: 1.149, heightRatio: 0.9905, centerShift: 0.0499)),
        .russianBlue: SpriteSheet(walk: Clip(frames: 12, aspect: 1.1095),
                            jump: Clip(frames: 22, aspect: 1.0079, heightRatio: 1.2048, centerShift: -0.0617),
                            sit: Clip(frames: 24, aspect: 1.2783, heightRatio: 1.0095, centerShift: -0.0215)),
        .maineCoon: SpriteSheet(walk: Clip(frames: 16, aspect: 1.0524),
                            jump: Clip(frames: 22, aspect: 1.0177, heightRatio: 1.0762, centerShift: 0.0041),
                            sit: Clip(frames: 22, aspect: 1.0714, heightRatio: 1.0, centerShift: 0.0462)),
        .bengal: SpriteSheet(walk: Clip(frames: 11, aspect: 1.1571),
                            jump: Clip(frames: 22, aspect: 1.0826, heightRatio: 1.1524, centerShift: 0.0074),
                            sit: Clip(frames: 23, aspect: 1.0918, heightRatio: 0.9857, centerShift: 0.0509)),
        .britishShorthair: SpriteSheet(walk: Clip(frames: 12, aspect: 1.1524),
                            jump: Clip(frames: 22, aspect: 1.0635, heightRatio: 1.2, centerShift: -0.0213),
                            sit: Clip(frames: 26, aspect: 1.2196, heightRatio: 1.019, centerShift: 0.0135)),
        .scottishFold: SpriteSheet(walk: Clip(frames: 14, aspect: 1.1619),
                            jump: Clip(frames: 22, aspect: 1.0412, heightRatio: 1.1571, centerShift: -0.0067),
                            sit: Clip(frames: 21, aspect: 1.2075, heightRatio: 1.0095, centerShift: 0.0227)),
    ]

    static func `for`(_ breed: Breed) -> SpriteSheet? { all[breed] }
}

/// Plays a looping walk, or a one-off jump, from sprite frames.
struct SpriteClipView: View {
    let breed: Breed
    let clip: String
    let info: SpriteSheet.Clip
    /// Height of the walk frames; the jump is drawn taller from the same floor line.
    let height: CGFloat
    var loop = true
    /// Each clip starts from its first frame when it appears.
    @State private var start = Date()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / SpriteSheet.fps)) { ctx in
            let elapsed = max(0, ctx.date.timeIntervalSince(start))
            let raw = Int(elapsed * SpriteSheet.fps)
            let i = loop ? raw % info.frames : min(raw, info.frames - 1)
            let h = height * info.heightRatio
            Image(SpriteSheet.name(breed, clip, i))
                .resizable()
                .interpolation(.high)
                .frame(width: h * info.aspect, height: h)
                .offset(x: info.centerShift * height)
        }
        .frame(height: height, alignment: .bottom)
    }
}
