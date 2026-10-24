import SwiftUI

// MARK: - Yarn chase (Speed)

struct YarnChaseGame: View {
    @Binding var score: Int
    @State private var pos = CGPoint(x: 0.5, y: 0.5)
    @State private var spin = 0.0
    @State private var pops: [FloatingHeart] = []

    var body: some View {
        GeometryReader { geo in
            let size: CGFloat = 76
            let p = CGPoint(x: size / 2 + pos.x * (geo.size.width - size), y: size / 2 + pos.y * (geo.size.height - size))
            ZStack {
                Color.clear.contentShape(Rectangle())
                Button {
                    Haptics.tap(.medium)
                    score += 1
                    pops.append(FloatingHeart(x: 0))
                    jump()
                } label: {
                    YarnBall().frame(width: size, height: size).rotationEffect(.degrees(spin))
                }
                .buttonStyle(PressableStyle())
                .position(p)
                .accessibilityLabel("Yarn ball")
                HeartBurst(hearts: pops).position(p)
            }
        }
        .task {
            while !Task.isCancelled {
                let interval = max(0.55, 1.25 - Double(score) * 0.035)
                try? await Task.sleep(for: .seconds(interval))
                jump()
            }
        }
    }

    private func jump() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            pos = CGPoint(x: .random(in: 0...1), y: .random(in: 0...1))
            spin += .random(in: 120...300)
        }
    }
}

struct YarnBall: View {
    var body: some View {
        ZStack {
            Circle().fill(Theme.rose)
            ForEach(0..<4, id: \.self) { i in
                Ellipse().stroke(.white.opacity(0.55), lineWidth: 2.5)
                    .scaleEffect(x: 0.9, y: 0.35 + CGFloat(i) * 0.12)
                    .rotationEffect(.degrees(Double(i) * 45))
            }
            Circle().stroke(Theme.roseDeep, lineWidth: 2)
        }
        .overlay(alignment: .bottomTrailing) {
            Capsule().fill(Theme.rose).frame(width: 26, height: 3).rotationEffect(.degrees(30)).offset(x: 14, y: -4)
        }
    }
}

// MARK: - Purr rhythm (Charm)

struct PurrRhythmGame: View {
    @Binding var score: Int
    let start: Date
    @State private var combo = 0
    @State private var lastScoredBeat = -1
    @State private var feedback: (String, Color)?

    private func period(_ t: Double) -> Double { max(0.7, 1.1 - t * 0.015) }

    /// Beat times are accumulated so the tempo can speed up smoothly.
    private func beatInfo(at date: Date) -> (index: Int, frac: Double, nearestIndex: Int, nearestDelta: Double) {
        var t = date.timeIntervalSince(start) - 0.8
        var i = 0
        while t > period(Double(i)) {
            t -= period(Double(i))
            i += 1
        }
        let p = period(Double(i))
        let frac = max(0, t) / p
        let toNext = p - t
        return t < toNext ? (i, frac, i - 1, t) : (i, frac, i, -toNext)
    }

    var body: some View {
        VStack {
            HStack {
                Text(combo > 1 ? "Combo x\(combo)" : " ").font(Theme.font(18, .heavy)).foregroundStyle(Theme.rose)
                Spacer()
                if let feedback { Text(feedback.0).font(Theme.font(18, .heavy)).foregroundStyle(feedback.1) }
            }
            .padding(.horizontal, 20)
            Spacer()
            TimelineView(.animation) { ctx in
                let b = beatInfo(at: ctx.date)
                let ringScale = 1 + 1.6 * (1 - b.frac)
                ZStack {
                    Circle().stroke(Theme.rose.opacity(0.35), lineWidth: 6).frame(width: 110, height: 110).scaleEffect(ringScale)
                    Circle().fill(Theme.roseTint).frame(width: 110, height: 110)
                    Circle().stroke(Theme.rose, lineWidth: 4).frame(width: 110, height: 110)
                    Image(systemName: "heart.fill").font(.system(size: 40)).foregroundStyle(Theme.rose)
                        .scaleEffect(b.frac < 0.12 ? 1.2 : 1)
                }
            }
            .frame(height: 320)
            Spacer()
            Button("Purr") { tap() }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 40)
                .padding(.bottom, 24)
        }
    }

    private func tap() {
        let b = beatInfo(at: Date())
        let delta = abs(b.nearestDelta)
        guard b.nearestIndex >= 0, b.nearestIndex != lastScoredBeat else {
            miss()
            return
        }
        let pts = delta < 0.08 ? 3 : (delta < 0.16 ? 2 : (delta < 0.25 ? 1 : 0))
        guard pts > 0 else { miss(); return }
        lastScoredBeat = b.nearestIndex
        combo += 1
        score += pts + (combo >= 5 ? 1 : 0)
        Haptics.tap(pts == 3 ? .heavy : .medium)
        feedback = pts == 3 ? ("Purrfect!", Theme.success) : (pts == 2 ? ("Nice", Theme.warning) : ("Okay", Theme.muted))
    }

    private func miss() {
        combo = 0
        feedback = ("Off beat", Theme.rose)
        Haptics.tap(.rigid)
    }
}
