import SwiftUI

struct HatcheryView: View {
    @Environment(GameStore.self) private var store
    @State private var selectedID: UUID?
    @State private var wobble = false
    @State private var boughtNote: String?
    @State private var gifting: NestEgg?

    private var selected: Egg? { store.eggs.first { $0.id == selectedID } ?? store.eggs.first }

    var body: some View {
        Screen {
            ScreenHeader(eyebrow: "Hatchery", title: store.eggs.isEmpty ? "No eggs yet" : "Incubating") {
                Pill(icon: "oval.portrait.fill", text: "\(store.eggs.count) / \(GameStore.maxEggs)")
            }
            if let egg = selected {
                incubator(egg)
            } else {
                emptyIncubator
            }
            Text("Your eggs").font(Theme.font(17, .bold))
            slots
            if !store.nest.isEmpty { nestSection }
            shop
            Text("Win battles and play minigames to earn eggs. Tap an egg to keep it warm: every tap takes a moment off its timer.")
                .font(Theme.font(13)).foregroundStyle(Theme.muted)
        }
    }

    private func incubator(_ egg: Egg) -> some View {
        let now = store.now
        let ready = egg.isReady(now)
        let progress = egg.progress(now)
        return VStack(spacing: 14) {
            Button {
                Haptics.tap()
                store.warm(egg.id)
                withAnimation(.spring(response: 0.18, dampingFraction: 0.3)) { wobble.toggle() }
            } label: {
                EggView(rarity: egg.rarity, size: 170, crack: ready ? 0.35 : 0)
                    .rotationEffect(.degrees(wobble ? 6 : -6), anchor: .bottom)
                    .frame(maxWidth: .infinity)
                    .frame(height: 250)
                    .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Theme.beige))
                    .overlay(alignment: .topLeading) {
                        Tag(text: "\(egg.rarity.title) egg", color: egg.rarity.color).padding(12)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Warm the \(egg.rarity.title) egg")
            .phaseAnimator([false, true], trigger: ready) { view, phase in
                view.rotationEffect(.degrees(ready && phase ? 2 : 0))
            }

            Card {
                HStack {
                    Text(ready ? "Ready to hatch!" : "Hatches in").font(Theme.font(15, .bold))
                    Spacer()
                    if !ready {
                        Label(formatTime(egg.remaining(now)), systemImage: "clock")
                            .font(Theme.font(15, .bold)).monospacedDigit()
                    }
                }
                StatBar(label: "Warmth", value: progress, max: 1, color: ready ? Theme.success : Theme.text)
                if ready {
                    Button("Hatch now") { store.hatch(egg.id) }
                        .buttonStyle(PrimaryButtonStyle())
                } else {
                    let cost = store.skipCost(egg)
                    Button("Hatch now for \(cost) coins") {
                        store.hatch(egg.id, paying: true)
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .disabled(store.coins < cost)
                }
            }
        }
        .onAppear { selectedID = egg.id }
    }

    private var nestSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Egg nest").font(Theme.font(17, .bold))
                Spacer()
                Tag(text: "\(store.nest.count) waiting", color: Theme.warning)
            }
            Text("Eggs you win while the incubator is full wait here. The next free slot takes the oldest one.")
                .font(Theme.font(12)).foregroundStyle(Theme.muted)
            ForEach(store.nest) { n in
                Card(padding: 12) {
                    HStack(spacing: 12) {
                        EggView(rarity: n.egg.rarity, size: 52)
                        VStack(alignment: .leading, spacing: 4) {
                            Tag(text: "\(n.egg.rarity.title) egg", color: n.egg.rarity.color)
                            Text(n.source).font(Theme.font(12)).foregroundStyle(Theme.muted)
                            Label("\(formatDuration(n.expires.timeIntervalSince(store.now))) left", systemImage: "clock")
                                .font(Theme.font(12, .bold)).monospacedDigit()
                        }
                        Spacer(minLength: 0)
                        Button("Gift") { gifting = n }
                            .font(Theme.font(13, .bold)).foregroundStyle(Theme.text)
                            .padding(.horizontal, 14).frame(height: 40)
                            .overlay(Capsule().stroke(Theme.border, lineWidth: 1))
                    }
                }
            }
        }
        .confirmationDialog("Gift this egg to a friend", isPresented: Binding(get: { gifting != nil }, set: { if !$0 { gifting = nil } }),
                            titleVisibility: .visible, presenting: gifting) { n in
            ForEach(store.friends) { f in
                Button(f.name) {
                    Haptics.success()
                    store.giftNestEgg(n.id, to: f.id)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("Gifting raises your friendship.")
        }
    }

    private var emptyIncubator: some View {
        VStack(spacing: 10) {
            Image(systemName: "oval.portrait.inset.filled").font(.system(size: 56)).foregroundStyle(Theme.muted.opacity(0.6))
            Text("The incubator is empty").font(Theme.font(16, .bold))
            Text("Buy an egg below or win one in battle.").font(Theme.font(13)).foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 250)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Theme.muted.opacity(0.5), style: StrokeStyle(lineWidth: 2, dash: [6, 5])))
    }

    private var slots: some View {
        HStack(spacing: 10) {
            ForEach(0..<GameStore.maxEggs, id: \.self) { i in
                if i < store.eggs.count {
                    let egg = store.eggs[i]
                    let isSelected = egg.id == selected?.id
                    Button {
                        Haptics.tap()
                        selectedID = egg.id
                    } label: {
                        VStack(spacing: 6) {
                            EggView(rarity: egg.rarity, size: 48, crack: egg.isReady(store.now) ? 0.35 : 0)
                            Text(egg.isReady(store.now) ? "Ready" : formatTime(egg.remaining(store.now)))
                                .font(Theme.font(11, .bold)).monospacedDigit()
                                .foregroundStyle(egg.isReady(store.now) ? Theme.success : Theme.muted)
                        }
                        .frame(maxWidth: .infinity, minHeight: 92)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(isSelected ? Theme.rose : .clear, lineWidth: 2))
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityLabel("\(egg.rarity.title) egg")
                } else {
                    VStack(spacing: 6) {
                        Image(systemName: "plus").font(.system(size: 18, weight: .semibold))
                        Text("Empty").font(Theme.font(11, .semibold))
                    }
                    .foregroundStyle(Theme.muted)
                    .frame(maxWidth: .infinity, minHeight: 92)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Theme.muted.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])))
                }
            }
        }
    }

    private var shop: some View {
        Card {
            shopRow(title: "Mystery egg", note: boughtNote ?? "Basic to legendary", egg: .rare, price: GameStore.eggPrice, golden: false)
            Divider()
            shopRow(title: "Golden egg", note: "Always rare or better", egg: .legendary, price: GameStore.goldenEggPrice, golden: true)
        }
    }

    private func shopRow(title: String, note: String, egg: Rarity, price: Int, golden: Bool) -> some View {
        let blocked = !store.hasFreeEggSlot || store.coins < price
        return HStack(spacing: 12) {
            EggView(rarity: egg, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(Theme.font(15, .bold))
                Text(note).font(Theme.font(12)).foregroundStyle(Theme.muted)
            }
            Spacer()
            Button {
                if let r = store.buyEgg(golden: golden) {
                    Haptics.success()
                    boughtNote = "You got \(r == .epic ? "an" : "a") \(r.title.lowercased()) egg!"
                    selectedID = store.eggs.last?.id
                }
            } label: {
                Label("\(price)", systemImage: "pawprint.circle.fill")
                    .font(Theme.font(15, .bold))
                    .padding(.horizontal, 16).frame(height: 44)
                    .background(Capsule().fill(golden ? Rarity.legendary.color : Theme.rose))
                    .foregroundStyle(.white)
            }
            .buttonStyle(PressableStyle())
            .disabled(blocked)
            .opacity(blocked ? 0.45 : 1)
            .accessibilityLabel("Buy a \(title.lowercased()) for \(price) coins")
        }
    }
}
