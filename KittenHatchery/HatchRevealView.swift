import SwiftUI

struct HatchRevealView: View {
    @Environment(GameStore.self) private var store
    @State var cat: Cat
    let rarity: Rarity

    enum Phase { case egg, burst, named }
    @State private var phase: Phase = .egg
    @State private var taps = 0
    @State private var shake = false
    @State private var fly = false
    @State private var name = ""
    @FocusState private var nameFocused: Bool

    private let tapsNeeded = 4

    var body: some View {
        VStack(spacing: 18) {
            VStack(spacing: 4) {
                Text(phase == .egg ? "SOMETHING IS MOVING" : (rarity == .legendary ? "LEGENDARY FIND" : "A NEW FRIEND"))
                    .font(Theme.font(12, .bold)).tracking(0.6).foregroundStyle(Theme.muted)
                Text(phase == .egg ? "Tap to crack the egg" : "It's a \(cat.kind.title)!")
                    .multilineTextAlignment(.center)
                    .font(Theme.font(28, .heavy))
            }
            .padding(.top, 16)

            ZStack {
                RoundedRectangle(cornerRadius: 26, style: .continuous).fill(Theme.beige)
                if phase == .egg {
                    EggView(rarity: rarity, size: 200, crack: CGFloat(taps) / CGFloat(tapsNeeded))
                        .rotationEffect(.degrees(shake ? 9 : -9), anchor: .bottom)
                        .transition(.opacity)
                } else {
                    CatSprite(cat: cat, size: 260, mood: .happy)
                        .transition(.scale(scale: 0.2).combined(with: .opacity))
                    EggHalf(rarity: rarity, top: true, size: 200)
                        .rotationEffect(.degrees(fly ? -50 : 0))
                        .offset(x: fly ? -130 : 0, y: fly ? -200 : 0)
                        .opacity(fly ? 0 : 1)
                    EggHalf(rarity: rarity, top: false, size: 200)
                        .rotationEffect(.degrees(fly ? 30 : 0))
                        .offset(x: fly ? 140 : 0, y: fly ? 160 : 0)
                        .opacity(fly ? 0 : 1)
                    ConfettiView()
                }
            }
            .frame(height: 360)
            .contentShape(Rectangle())
            .onTapGesture { crack() }
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(phase == .egg ? "Crack the egg" : cat.name)

            if phase != .egg {
                HStack(spacing: 8) {
                    Tag(text: cat.kind.title, color: rarity.color)
                    Tag(text: cat.personality.title, color: Theme.text)
                    Tag(text: rarity.title, color: rarity.color)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))

                Card {
                    Text(cat.kind.blurb).font(Theme.font(13)).foregroundStyle(Theme.muted)
                    Text("Name your kitten").font(Theme.font(14, .bold))
                    TextField("Name", text: $name)
                        .font(Theme.font(18, .semibold))
                        .textInputAutocapitalization(.words)
                        .submitLabel(.done)
                        .focused($nameFocused)
                        .padding(.horizontal, 16)
                        .frame(height: 50)
                        .background(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
                    HStack {
                        Text("Good at: \(cat.kind.gift.title)").font(Theme.font(12)).foregroundStyle(Theme.muted)
                        Spacer()
                        Button("Surprise me") { name = Names.random(); Haptics.tap() }
                            .font(Theme.font(13, .bold)).foregroundStyle(Theme.rose)
                    }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                Text("\(tapsNeeded - taps) more \(tapsNeeded - taps == 1 ? "tap" : "taps")")
                    .font(Theme.font(15, .semibold)).foregroundStyle(Theme.muted)
            }

            Spacer(minLength: 0)

            if phase != .egg {
                Button("Welcome home") { adopt() }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
        .foregroundStyle(Theme.text)
        .background(Theme.cream.ignoresSafeArea())
        .onAppear { name = cat.name }
        #if DEBUG
        .task {
            guard ProcessInfo.processInfo.arguments.contains("-autoplay") else { return }
            for _ in 0..<tapsNeeded {
                try? await Task.sleep(for: .milliseconds(400))
                crack()
            }
        }
        #endif
    }

    private func crack() {
        guard phase == .egg else { return }
        taps += 1
        Haptics.tap(taps >= tapsNeeded ? .heavy : .medium)
        withAnimation(.spring(response: 0.12, dampingFraction: 0.2)) { shake.toggle() }
        if taps >= tapsNeeded {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                Haptics.success()
                withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { phase = .burst }
                withAnimation(.easeOut(duration: 0.9).delay(0.05)) { fly = true }
            }
        }
    }

    private func adopt() {
        var named = cat
        named.name = name.trimmingCharacters(in: .whitespaces)
        Haptics.success()
        store.adopt(named)
        store.tab = .den
    }
}
