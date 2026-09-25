import SwiftUI

struct CollectionView: View {
    @Environment(GameStore.self) private var store
    @State private var filter: Stage?

    private var shown: [Cat] { store.cats.filter { filter == nil || $0.stage == filter } }

    var body: some View {
        Screen {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-breedbook") { BreedBook() }
            #endif
            ScreenHeader(eyebrow: "Collection", title: "Your cats") {
                Pill(icon: "square.grid.2x2.fill", text: "\(store.cats.count)")
            }
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    chip("All", nil)
                    ForEach(Stage.allCases, id: \.self) { chip($0.title, $0) }
                }
            }
            .scrollIndicators(.hidden)

            if store.cats.isEmpty {
                NoCatYet()
            } else {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    ForEach(shown) { cat in card(cat) }
                    if filter == nil {
                        ForEach(0..<(store.cats.count.isMultiple(of: 2) ? 2 : 1), id: \.self) { _ in locked }
                    }
                }
                Text("Tap a cat to make it your active buddy.").font(Theme.font(13)).foregroundStyle(Theme.muted)
            }
            BreedBook()
        }
    }

    private func chip(_ title: String, _ stage: Stage?) -> some View {
        let on = filter == stage
        return Button(title) {
            Haptics.tap()
            filter = stage
        }
        .font(Theme.font(14, .bold))
        .foregroundStyle(on ? .white : Theme.text)
        .padding(.horizontal, 16)
        .frame(height: 38)
        .background(Capsule().fill(on ? Theme.text : .white))
    }

    private func card(_ cat: Cat) -> some View {
        let active = cat.id == store.activeCat?.id
        return Button {
            Haptics.tap(.medium)
            store.setActive(cat.id)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                CatSprite(cat: cat, size: 110, animated: active)
                    .frame(maxWidth: .infinity)
                    .frame(height: 120)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.beige))
                HStack {
                    Text(cat.name).font(Theme.font(16, .heavy)).lineLimit(1)
                    Spacer()
                    Text("Lv \(cat.level)").font(Theme.font(12, .semibold)).foregroundStyle(Theme.muted)
                }
                Text(cat.kind.title).font(Theme.font(12, .semibold)).foregroundStyle(Theme.muted).lineLimit(1)
                HStack(spacing: 6) {
                    Tag(text: cat.stage.title, color: cat.stage == .legend ? Rarity.epic.color : Theme.rose)
                    Tag(text: cat.rarity.title, color: cat.rarity.color)
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.white))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(active ? Theme.rose : .clear, lineWidth: 2.5))
            .overlay(alignment: .topTrailing) {
                if active {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 22)).foregroundStyle(Theme.rose)
                        .background(Circle().fill(.white)).padding(6)
                }
            }
        }
        .buttonStyle(PressableStyle())
        .foregroundStyle(Theme.text)
        .accessibilityLabel("\(cat.name), level \(cat.level)\(active ? ", active" : "")")
    }

    private var locked: some View {
        VStack(spacing: 8) {
            Image(systemName: "lock.fill").font(.system(size: 20))
            Text("Hatch more eggs").font(Theme.font(12, .semibold))
        }
        .foregroundStyle(Theme.muted)
        .frame(maxWidth: .infinity, minHeight: 206)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Theme.muted.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])))
    }
}

struct SkillsView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let catID: UUID

    var body: some View {
        if let cat = store.cats.first(where: { $0.id == catID }) {
            Screen {
                ScreenHeader(eyebrow: "Upskill \(cat.name)", title: "Skills") {
                    Pill(icon: "star.fill", text: "\(cat.skillPoints) \(cat.skillPoints == 1 ? "point" : "points")", tint: cat.skillPoints > 0 ? Theme.rose : Theme.text)
                }
                Card {
                    Text("Stats").font(Theme.font(17, .bold))
                    ForEach(StatKind.allCases) { kind in
                        HStack(spacing: 10) {
                            StatBar(label: kind.title, value: Double(cat.stat(kind)), max: kind.displayMax, trailing: "\(cat.stat(kind))")
                            Button {
                                Haptics.tap(.medium)
                                store.spendPoint(cat.id, on: kind)
                            } label: {
                                Image(systemName: "plus").font(.system(size: 16, weight: .bold))
                                    .frame(width: 44, height: 44)
                                    .background(Circle().fill(cat.skillPoints > 0 ? Theme.rose : Theme.beige))
                                    .foregroundStyle(cat.skillPoints > 0 ? .white : Theme.muted)
                            }
                            .buttonStyle(PressableStyle())
                            .disabled(cat.skillPoints == 0)
                            .accessibilityLabel("Add \(kind.step) \(kind.title)")
                        }
                    }
                    Text("Each point adds +5 HP or +2 to another stat. You earn 2 points per level.")
                        .font(Theme.font(12)).foregroundStyle(Theme.muted)
                }
                Card {
                    HStack {
                        Text("Moves").font(Theme.font(17, .bold))
                        Spacer()
                        Text("\(cat.equipped.count) / 4 equipped").font(Theme.font(12, .semibold)).foregroundStyle(Theme.muted)
                    }
                    ForEach(Move.allCases) { move in moveRow(cat, move) }
                }
                Button("Done") { dismiss() }.buttonStyle(SecondaryButtonStyle())
            }
            .presentationDragIndicator(.visible)
        }
    }

    private func moveRow(_ cat: Cat, _ move: Move) -> some View {
        let known = cat.knows(move)
        let equipped = cat.equipped.contains(move)
        return Button {
            Haptics.tap()
            store.toggleEquip(cat.id, move)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: known ? move.icon : "lock.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(known ? Theme.roseTint : Theme.beige))
                    .foregroundStyle(known ? Theme.rose : Theme.muted)
                VStack(alignment: .leading, spacing: 2) {
                    Text(move.title).font(Theme.font(15, .bold)).foregroundStyle(known ? Theme.text : Theme.muted)
                    Text(known ? "\(move.blurb) · \(move.focusCost) focus" : move.unlockText)
                        .font(Theme.font(12)).foregroundStyle(Theme.muted)
                }
                Spacer()
                if known {
                    Tag(text: equipped ? "Equipped" : "Equip", color: equipped ? Theme.success : Theme.muted, filled: equipped)
                }
            }
            .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
        .disabled(!known || move == .swipe)
    }
}

/// Every breed from basic to legendary; ones you haven't hatched show as silhouettes.
struct BreedBook: View {
    @Environment(GameStore.self) private var store
    @State private var inspecting: Breed?

    var body: some View {
        let found = store.discovered
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Breed book").font(Theme.font(20, .heavy))
                Spacer()
                Text("\(found.count) / \(Breed.allCases.count) found").font(Theme.font(13, .semibold)).foregroundStyle(Theme.muted)
            }
            ForEach(Rarity.allCases, id: \.self) { rarity in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Tag(text: rarity.title, color: rarity.color, filled: rarity == .legendary)
                        Text(oddsText(rarity)).font(Theme.font(12)).foregroundStyle(Theme.muted)
                    }
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                        ForEach(Breed.allCases.filter { $0.rarity == rarity }) { breed in
                            entry(breed, known: found.contains(breed))
                        }
                    }
                }
            }
        }
        .padding(.top, 8)
        .sheet(item: $inspecting) { breed in
            BreedDetail(breed: breed, known: found.contains(breed))
                .presentationDetents([.medium])
        }
    }

    private func oddsText(_ r: Rarity) -> String {
        switch r {
        case .basic: "60% of mystery eggs"
        case .rare: "27% of mystery eggs"
        case .epic: "10% of mystery eggs"
        case .legendary: "3% of mystery eggs"
        }
    }

    private func entry(_ breed: Breed, known: Bool) -> some View {
        Button {
            Haptics.tap()
            inspecting = breed
        } label: {
            VStack(spacing: 4) {
                Image(breed.imageName).resizable().scaledToFit()
                    .frame(height: 58)
                    .colorMultiply(known ? .white : .black)
                    .opacity(known ? 1 : 0.18)
                Text(known ? breed.title : "???").font(Theme.font(10, .bold)).lineLimit(1).minimumScaleFactor(0.7)
                    .foregroundStyle(known ? Theme.text : Theme.muted)
            }
            .padding(6)
            .frame(maxWidth: .infinity, minHeight: 88)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.white))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(breed.rarity == .legendary ? Rarity.legendary.color.opacity(known ? 0.9 : 0.35) : .clear, lineWidth: 1.5))
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(known ? breed.title : "Undiscovered \(breed.rarity.title.lowercased()) breed")
    }
}

struct BreedDetail: View {
    let breed: Breed
    let known: Bool

    var body: some View {
        VStack(spacing: 14) {
            Image(breed.imageName).resizable().scaledToFit().frame(height: 170)
                .colorMultiply(known ? .white : .black).opacity(known ? 1 : 0.2)
                .shadow(color: breed.rarity == .legendary ? Rarity.legendary.color.opacity(0.6) : .clear, radius: 16)
            Text(known ? breed.title : "Undiscovered").font(Theme.font(24, .heavy))
            HStack(spacing: 8) {
                Tag(text: breed.rarity.title, color: breed.rarity.color, filled: breed.rarity == .legendary)
                Tag(text: "Good at \(breed.gift.title)", color: Theme.text)
            }
            Text(known ? breed.blurb : "Hatch a \(breed.rarity.title.lowercased()) egg to find this breed.")
                .font(Theme.font(15)).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.cream.ignoresSafeArea())
        .foregroundStyle(Theme.text)
    }
}
