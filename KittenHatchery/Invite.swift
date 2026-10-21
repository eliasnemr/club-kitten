import SwiftUI

enum AppLinks {
    /// The landing page. Swap for the App Store link once Club Kitten is live.
    static let invite = URL(string: "https://eliasnemr.github.io/club-kitten/")!

    /// Your personal invite: the web page opens Club Kitten (or the App Store) and adds you as a friend.
    static func invite(code: String?) -> URL {
        guard let code else { return invite }
        var c = URLComponents(string: "https://eliasnemr.github.io/club-kitten/add/")!
        c.queryItems = [URLQueryItem(name: "code", value: code)]
        return c.url ?? invite
    }
}

/// Reads the friend code from an invite link, either the web page or the app's own link.
enum InviteLink {
    static func code(from url: URL) -> String? {
        let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let isApp = url.scheme == "clubkitten" && url.host == "add"
        let isWeb = url.host == "eliasnemr.github.io" && url.path.hasPrefix("/club-kitten/add")
        guard isApp || isWeb,
              let raw = comps?.queryItems?.first(where: { $0.name == "code" })?.value?.uppercased(),
              raw.range(of: #"^KIT-[0-9A-F]{6}$"#, options: .regularExpression) != nil else { return nil }
        return raw
    }
}

/// Shown when you have no friends in the game yet: invite someone to download it.
struct InviteFriendsCard: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: -14) {
                ForEach(Array([Breed.siamese, .scottishFold, .tuxedo].enumerated()), id: \.offset) { i, b in
                    Image(b.imageName).resizable().scaledToFit().frame(width: 70, height: 70)
                        .background(Circle().fill(Theme.beige).padding(-4))
                        .zIndex(i == 1 ? 1 : 0)
                }
            }
            .padding(.top, 6)
            Text("No friends here yet").font(Theme.font(20, .heavy))
            Text("Club Kitten is more fun with friends. Invite someone to download it, then visit each other's lounges and go on playdates for eggs.")
                .font(Theme.font(14)).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
            ShareLink(item: AppLinks.invite(code: store.online?.friendCode),
                      subject: Text("Play Club Kitten with me"),
                      message: Text(message)) {
                Label("Invite a friend", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(PrimaryButtonStyle())
            .simultaneousGesture(TapGesture().onEnded { Haptics.tap(.medium) })
            if store.online?.gameCenterLinked == true {
                Button {
                    Haptics.tap(.medium)
                    GameCenter.shared.presentFriendRequestCreator()
                } label: {
                    Label("Add Game Center friends", systemImage: "gamecontroller.fill")
                }
                .buttonStyle(SecondaryButtonStyle())
                Text("Game Center friends who play Club Kitten join your list automatically.")
                    .font(Theme.font(12)).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
            } else {
                Text("Send it by Messages, WhatsApp or anywhere you like.")
                    .font(Theme.font(12)).foregroundStyle(Theme.muted)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(.white))
    }

    private var message: String {
        if let cat = store.activeCat {
            return "I'm raising \(cat.name) the \(cat.kind.title) in Club Kitten! Come hatch your own kitten and visit my lounge 🐾"
        }
        return "Come hatch kittens with me in Club Kitten! 🐾"
    }
}
