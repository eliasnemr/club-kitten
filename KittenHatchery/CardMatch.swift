import SwiftUI

// MARK: - Kitty match (memory)

/// How hard a Kitty match board is. Every cleared board moves you up a level.
struct MatchLevel {
    let level: Int
    var pairs: Int { [3, 4, 6, 8, 10][min(level, 5) - 1] }
    var columns: Int { pairs <= 3 ? 3 : 4 }
    /// Seconds to memorise the cards before they flip face down.
    /// Bigger boards get a little longer; past level 5 it shrinks again.
    var preview: Double { max(2.5, 2.0 + Double(pairs) * 0.22 - Double(max(0, level - 5)) * 0.25) }
    /// Seconds to find every pair.
    var time: Double {
        let base: [Double] = [30, 35, 45, 55, 65]
        let extra = level > 5 ? Double(level - 5) * 3 : 0       // past level 5 the clock just gets tighter
        return level > 5 ? max(35, base[4] - extra) : base[level - 1]
    }
    /// Rewards grow with the level.
    var multiplier: Double { 1 + Double(level - 1) * 0.35 }
}

/// What happened in one round, for the results screen and rewards.
struct MatchOutcome {
    let level: Int
    let pairs: Int
    let found: Int
    let secondsLeft: Int
    var cleared: Bool { found == pairs }
    /// The number shown as the score (used by the high-score challenge too).
    var score: Int { found * 5 + (cleared ? secondsLeft : 0) }
}

struct CardMatchGame: View {
    let level: MatchLevel
    @Binding var score: Int
    let onDone: (MatchOutcome) -> Void

    private struct Card: Identifiable, Equatable {
        let id = UUID()
        let breed: Breed
        var matched = false
    }

    private enum Stage: Equatable { case preview, playing, over }

    @State private var cards: [Card] = []
    @State private var stage: Stage = .preview
    @State private var faceUp: Set<UUID> = []
    @State private var start = Date()
    @State private var wrong: Set<UUID> = []
    @State private var finished = false

    var body: some View {
        VStack(spacing: 10) {
            header
            GeometryReader { geo in
                let cols = level.columns
                let rows = Int((Double(cards.count) / Double(cols)).rounded(.up))
                let gap: CGFloat = 8
                let cw = (geo.size.width - gap * CGFloat(cols - 1)) / CGFloat(cols)
                let ch = min(cw * 1.25, (geo.size.height - gap * CGFloat(max(rows - 1, 0))) / CGFloat(max(rows, 1)))
                let w = min(cw, ch / 1.25)
                let gridW = w * CGFloat(cols) + gap * CGFloat(cols - 1)
                let gridH = w * 1.25 * CGFloat(rows) + gap * CGFloat(max(rows - 1, 0))
                let x0 = (geo.size.width - gridW) / 2, y0 = (geo.size.height - gridH) / 2
                ZStack {
                    ForEach(Array(cards.enumerated()), id: \.element.id) { i, card in
                        CardView(breed: card.breed, faceUp: faceUp.contains(card.id) || card.matched,
                                 matched: card.matched, shake: wrong.contains(card.id))
                            .frame(width: w, height: w * 1.25)
                            .position(x: x0 + CGFloat(i % cols) * (w + gap) + w / 2,
                                      y: y0 + CGFloat(i / cols) * (w * 1.25 + gap) + w * 0.625)
                            .onTapGesture { tap(card) }
                            .accessibilityLabel(faceUp.contains(card.id) || card.matched ? card.breed.title : "Hidden card")
                            .accessibilityAddTraits(.isButton)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 14)
        }
        .task { await play() }
    }

    @ViewBuilder
    private var header: some View {
        switch stage {
        case .preview:
            Text("Remember the cats!").font(Theme.font(18, .heavy)).padding(.top, 14)
            TimelineView(.periodic(from: start, by: 0.1)) { ctx in
                let left = max(0, level.preview - ctx.date.timeIntervalSince(start))
                StatBar(label: String(format: "%.0fs", left.rounded(.up)), value: left, max: level.preview, color: Theme.warning)
                    .padding(.horizontal, 16)
            }
        case .playing, .over:
            HStack {
                Text("Level \(level.level) · \(cards.filter(\.matched).count / 2)/\(level.pairs) pairs")
                    .font(Theme.font(14, .bold)).foregroundStyle(Theme.muted)
                Spacer()
            }
            .padding(.horizontal, 16).padding(.top, 14)
            TimelineView(.periodic(from: start, by: 0.1)) { ctx in
                let left = max(0, level.time - ctx.date.timeIntervalSince(start))
                StatBar(label: formatTime(left), value: left, max: level.time, color: left < 8 ? Theme.rose : Theme.text)
                    .padding(.horizontal, 16)
                    .onChange(of: left <= 0) { _, out in if out { end() } }
            }
        }
    }

    // MARK: Flow

    private func play() async {
        let breeds = Array(Breed.allCases.shuffled().prefix(level.pairs))
        cards = (breeds + breeds).map { Card(breed: $0) }.shuffled()
        // Show every card face up to memorise.
        start = Date()
        faceUp = Set(cards.map(\.id))
        try? await Task.sleep(for: .seconds(level.preview))
        guard !Task.isCancelled else { return }
        // Flip them all face down in place: now find the pairs from memory.
        withAnimation(.easeInOut(duration: 0.3)) { faceUp = [] }
        Haptics.tap(.medium)
        try? await Task.sleep(for: .milliseconds(350))
        start = Date()
        stage = .playing
        #if DEBUG
        // -matchAuto: plays the board (one wrong guess first) to check matching and rewards.
        if ProcessInfo.processInfo.arguments.contains("-matchAuto") {
            try? await Task.sleep(for: .seconds(1))
            if let a = cards.first, let b = cards.first(where: { $0.breed != a.breed }) {
                tap(a); try? await Task.sleep(for: .milliseconds(300)); tap(b)
                try? await Task.sleep(for: .seconds(1.4))
            }
            for breed in Set(cards.map(\.breed)) {
                let pair = cards.filter { $0.breed == breed }
                tap(pair[0]); try? await Task.sleep(for: .milliseconds(350)); tap(pair[1])
                try? await Task.sleep(for: .seconds(0.9))
            }
        }
        #endif
    }

    private func tap(_ card: Card) {
        guard stage == .playing, !card.matched, !faceUp.contains(card.id), faceUp.count < 2 else { return }
        Haptics.tap()
        withAnimation(.easeInOut(duration: 0.22)) { _ = faceUp.insert(card.id) }
        guard faceUp.count == 2 else { return }
        let open = cards.filter { faceUp.contains($0.id) }
        if open[0].breed == open[1].breed {
            Haptics.success()
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(250))
                withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                    for c in open { if let i = cards.firstIndex(where: { $0.id == c.id }) { cards[i].matched = true } }
                    faceUp = []
                }
                score = cards.filter(\.matched).count / 2 * 5
                if cards.allSatisfy(\.matched) { end() }
            }
        } else {
            Haptics.warning()
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(450))
                wrong = Set(open.map(\.id))
                try? await Task.sleep(for: .milliseconds(450))
                wrong = []
                withAnimation(.easeInOut(duration: 0.22)) { faceUp = [] }
            }
        }
    }

    private func end() {
        guard !finished, stage == .playing else { return }
        finished = true
        stage = .over
        let found = cards.filter(\.matched).count / 2
        let left = max(0, Int(level.time - Date().timeIntervalSince(start)))
        let outcome = MatchOutcome(level: level.level, pairs: level.pairs, found: found, secondsLeft: left)
        score = outcome.score
        withAnimation(.easeInOut(duration: 0.3)) { faceUp = Set(cards.map(\.id)) }   // show the answers
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.2))
            onDone(outcome)
        }
    }
}

/// One card: a paw-print back, or a breed's portrait on the front.
private struct CardView: View {
    let breed: Breed
    let faceUp: Bool
    let matched: Bool
    let shake: Bool

    var body: some View {
        ZStack {
            front.opacity(faceUp ? 1 : 0)
            back.opacity(faceUp ? 0 : 1)
        }
        .rotation3DEffect(.degrees(faceUp ? 0 : 180), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
        .scaleEffect(matched ? 0.94 : 1)
        .modifier(Shake(amount: shake ? 1 : 0))
        .animation(.easeInOut(duration: 0.3), value: shake)
    }

    private var front: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(.white)
            .overlay(
                Image(breed.imageName).resizable().scaledToFit().padding(6)
            )
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(matched ? Theme.success : breed.rarity.color.opacity(0.6), lineWidth: matched ? 3 : 2))
            .overlay(alignment: .topTrailing) {
                if matched {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.success)
                        .font(.system(size: 16, weight: .bold)).padding(5)
                }
            }
            // Undo the card flip so the picture isn't mirrored.
            .rotation3DEffect(.degrees(0), axis: (x: 0, y: 1, z: 0))
    }

    private var back: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(LinearGradient(colors: [Theme.rose, Theme.roseDeep], startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(
                Image(systemName: "pawprint.fill").font(.system(size: 22, weight: .bold)).foregroundStyle(.white.opacity(0.85))
            )
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(.white.opacity(0.6), lineWidth: 2).padding(4))
            .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
    }
}
