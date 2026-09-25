import SwiftUI

struct DenView: View {
    @Environment(GameStore.self) private var store
    @State private var hearts: [FloatingHeart] = []
    @State private var showSkills = false
    @State private var squish = false

    var body: some View {
        Screen {
            if let cat = store.activeCat {
                ScreenHeader(eyebrow: "Your den", title: "\(cat.name) · Lv \(cat.level)") {
                    CoinPill()
                }
                stage(cat)
                stats(cat)
                actions(cat)
                CloudSaveBadge()
            } else {
                ScreenHeader(eyebrow: "Your den", title: "Club Kitten") { CoinPill() }
                NoCatYet()
            }
        }
        .sheet(isPresented: $showSkills) {
            if let cat = store.activeCat { SkillsView(catID: cat.id) }
        }
    }

    private func stage(_ cat: Cat) -> some View {
        Button {
            pet()
        } label: {
            ZStack {
                if let video = cat.kind.idleVideo, Bundle.main.url(forResource: video, withExtension: "mp4") != nil {
                    LoopingVideo(resource: video)
                        .id(video)
                        .scaleEffect(cat.stage.scale + 0.12)
                } else {
                    CatSprite(cat: cat, size: 250)
                        .padding(.top, 20)
                }
                HeartBurst(hearts: hearts)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 300)
            .background(cat.kind.idleVideo != nil ? cat.kind.videoBackdrop : Theme.beige)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .scaleEffect(squish ? 0.97 : 1)
            .overlay(alignment: .topLeading) {
                HStack(spacing: 6) {
                    Tag(text: "\(cat.stage.title) stage", color: Theme.rose).background(Capsule().fill(.white))
                    Tag(text: cat.kind.title, color: cat.rarity.color).background(Capsule().fill(.white))
                }
                .padding(12)
            }
            .overlay(alignment: .bottom) {
                Text("Tap to pet").font(Theme.font(12, .semibold)).foregroundStyle(Theme.muted)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Capsule().fill(.white.opacity(0.8)))
                    .padding(10)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Pet \(cat.name)")
    }

    private func stats(_ cat: Cat) -> some View {
        Card {
            HStack(spacing: 10) {
                Image(systemName: "birthday.cake.fill").font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.rose)
                    .frame(width: 34, height: 34).background(Circle().fill(Theme.roseTint))
                VStack(alignment: .leading, spacing: 1) {
                    Text(cat.ageText).font(Theme.font(15, .bold))
                    Text(cat.humanAgeText).font(Theme.font(12)).foregroundStyle(Theme.muted)
                }
                Spacer()
                Text("Lv \(cat.level)").font(Theme.font(13, .bold)).foregroundStyle(Theme.muted)
            }
            .accessibilityElement(children: .combine)
            Divider().padding(.vertical, 2)
            ForEach(StatKind.allCases) { kind in
                StatBar(label: kind.title, value: Double(cat.stat(kind)), max: kind.displayMax, trailing: "\(cat.stat(kind))")
            }
            Divider().padding(.vertical, 2)
            HStack {
                Text("XP to next level")
                    .font(Theme.font(12, .semibold)).foregroundStyle(Theme.muted)
                Spacer()
                Text("\(cat.xp) / \(cat.xpNeeded)").font(Theme.font(12, .semibold)).foregroundStyle(Theme.muted).monospacedDigit()
            }
            StatBar(label: "XP", value: Double(cat.xp), max: Double(cat.xpNeeded), color: Theme.rose)
            if let next = Stage(rawValue: cat.stage.rawValue + 1) {
                Text("Grows into \(next == .adult ? "an" : "a") \(next.title) cat at Lv \(next.startLevel)")
                    .font(Theme.font(12)).foregroundStyle(Theme.muted)
            }
        }
    }

    private func actions(_ cat: Cat) -> some View {
        HStack(spacing: 12) {
            ActionTile(icon: "burst.fill", title: "Battle") { store.tab = .play; store.showArena = true }
            ActionTile(icon: "gamecontroller.fill", title: "Play") { store.tab = .play }
            ActionTile(icon: "star.fill", title: "Skills", badge: cat.skillPoints) { showSkills = true }
        }
    }

    private func pet() {
        Haptics.tap(.soft)
        store.record(.petCats)
        hearts.append(FloatingHeart(x: .random(in: -60...60)))
        if hearts.count > 8 { hearts.removeFirst() }
        withAnimation(.spring(response: 0.2, dampingFraction: 0.4)) { squish = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { squish = false }
        }
    }
}

struct ActionTile: View {
    let icon: String
    let title: String
    var badge = 0
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 22, weight: .semibold))
                Text(title).font(Theme.font(15, .bold))
            }
            .foregroundStyle(Theme.text)
            .frame(maxWidth: .infinity, minHeight: 88)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.white))
            .overlay(alignment: .topTrailing) {
                if badge > 0 {
                    Text("\(badge)").font(Theme.font(12, .heavy)).foregroundStyle(.white)
                        .frame(minWidth: 22, minHeight: 22)
                        .background(Circle().fill(Theme.rose))
                        .padding(8)
                }
            }
        }
        .buttonStyle(PressableStyle())
    }
}
