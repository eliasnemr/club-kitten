import SwiftUI
import UIKit

enum Theme {
    // Mixtiles tokens (cream-100, beige-100, beige-300, brown-900, brown-500) converted from HSL.
    static let cream = Color(red: 0.963, green: 0.949, blue: 0.938)
    static let beige = Color(red: 0.944, green: 0.918, blue: 0.896)
    static let border = Color(red: 0.88, green: 0.848, blue: 0.82)
    static let text = Color(red: 0.24, green: 0.193, blue: 0.16)
    static let muted = Color(red: 0.47, green: 0.41, blue: 0.37)
    static let rose = Color(red: 0.855, green: 0.184, blue: 0.322)
    static let roseDeep = Color(red: 0.72, green: 0.16, blue: 0.27)
    static let roseTint = Color(red: 0.99, green: 0.93, blue: 0.945)
    static let success = Color(red: 0.25, green: 0.62, blue: 0.43)
    static let warning = Color(red: 0.93, green: 0.64, blue: 0.2)
    /// Background colour baked into the Higgsfield idle video.
    static let videoBackdrop = Color(red: 0.974, green: 0.897, blue: 0.770)

    static func font(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

enum Haptics {
    static func tap(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func warning() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
}

// MARK: - Buttons

struct PrimaryButtonStyle: ButtonStyle {
    var fill: Color = Theme.rose
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.font(17, .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(Capsule().fill(isEnabled ? (configuration.isPressed ? Theme.roseDeep : fill) : Theme.muted.opacity(0.45)))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.font(17, .semibold))
            .foregroundStyle(isEnabled ? Theme.text : Theme.muted)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(Capsule().fill(configuration.isPressed ? Theme.beige : .white))
            .overlay(Capsule().stroke(Theme.border, lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Small building blocks

struct Card<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) { content }
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.white))
            .shadow(color: .black.opacity(0.05), radius: 10, y: 4)
    }
}

struct Pill: View {
    let icon: String
    let text: String
    var tint: Color = Theme.text

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 13, weight: .bold))
            Text(text).font(Theme.font(14, .bold)).monospacedDigit()
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 12)
        .frame(height: 34)
        .background(Capsule().fill(.white))
    }
}

struct Tag: View {
    let text: String
    var color: Color = Theme.muted
    var filled = false

    var body: some View {
        Text(text.uppercased())
            .font(Theme.font(11, .bold))
            .tracking(0.6)
            .foregroundStyle(filled ? .white : color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(filled ? color : color.opacity(0.14)))
    }
}

struct StatBar: View {
    let label: String
    let value: Double
    let max: Double
    var trailing: String? = nil
    var color: Color = Theme.text

    var body: some View {
        HStack(spacing: 12) {
            Text(label).font(Theme.font(13, .semibold)).frame(width: 54, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.beige)
                    Capsule().fill(color)
                        .frame(width: geo.size.width * CGFloat(Swift.max(0, Swift.min(1, value / Swift.max(max, 1)))))
                }
            }
            .frame(height: 9)
            if let trailing {
                Text(trailing).font(Theme.font(12, .semibold)).foregroundStyle(Theme.muted)
                    .monospacedDigit().frame(minWidth: 34, alignment: .trailing)
            }
        }
    }
}

struct ScreenHeader<Trailing: View>: View {
    let eyebrow: String
    let title: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(eyebrow.uppercased()).font(Theme.font(12, .bold)).tracking(0.6).foregroundStyle(Theme.muted)
                Text(title).font(Theme.font(27, .heavy)).foregroundStyle(Theme.text).lineLimit(1).minimumScaleFactor(0.7)
            }
            Spacer(minLength: 0)
            trailing
        }
    }
}

struct FloatingHeart: Identifiable {
    let id = UUID()
    let x: CGFloat
}

/// Hearts that float up and fade, used when petting a cat.
struct HeartBurst: View {
    let hearts: [FloatingHeart]

    var body: some View {
        ZStack {
            ForEach(hearts) { heart in
                RisingHeart(x: heart.x)
            }
        }
        .allowsHitTesting(false)
    }
}

private struct RisingHeart: View {
    let x: CGFloat
    @State private var up = false

    var body: some View {
        Image(systemName: "heart.fill")
            .font(.system(size: 26))
            .foregroundStyle(Theme.rose)
            .offset(x: x, y: up ? -140 : -20)
            .opacity(up ? 0 : 1)
            .scaleEffect(up ? 1.3 : 0.6)
            .onAppear { withAnimation(.easeOut(duration: 1.1)) { up = true } }
    }
}

/// Simple confetti burst for hatches, wins and evolutions.
struct ConfettiView: View {
    var count = 40
    @State private var go = false
    private let pieces: [(CGFloat, CGFloat, Double, Color)] = (0..<60).map { _ in
        (CGFloat.random(in: -180...180), CGFloat.random(in: -420 ... -120), Double.random(in: -360...360),
         [Theme.rose, Theme.warning, Theme.success, Color.blue.opacity(0.7), Color.purple.opacity(0.7)].randomElement()!)
    }

    var body: some View {
        ZStack {
            ForEach(0..<min(count, pieces.count), id: \.self) { i in
                let p = pieces[i]
                RoundedRectangle(cornerRadius: 2)
                    .fill(p.3)
                    .frame(width: 8, height: 12)
                    .rotationEffect(.degrees(go ? p.2 : 0))
                    .offset(x: go ? p.0 : 0, y: go ? p.1 + 380 : 0)
                    .opacity(go ? 0 : 1)
            }
        }
        .allowsHitTesting(false)
        .onAppear { withAnimation(.easeOut(duration: 1.8)) { go = true } }
    }
}
