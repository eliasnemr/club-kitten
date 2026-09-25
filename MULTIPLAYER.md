# Multiplayer setup: Supabase + Game Center

Without keys the app runs in offline practice mode (Sam, Mia and Leo are simulated).
With keys it signs in, links Game Center, and uses real friends, lounges, guestbooks and playdates.

## What runs where

| Piece | Where | Notes |
|---|---|---|
| Sign-in | Supabase Auth, anonymous | Every install gets an account with no email or password. |
| Identity | Game Center → `link-game-center` Edge Function | Apple-signed proof of the player, checked on the server, then stored as `gc_player_id`. |
| Friends | `friendships` table | Added by friend code, or automatically for Game Center friends who play. |
| Lounges | `profiles.lounge` / `profiles.showcase` | Your layout and top 5 cats, pushed 2s after changes. |
| Live visits | Realtime private channel `lounge:<owner>` | Presence (who is there) plus safe chat. Only indexes are sent, never free text. Only the owner and their friends can join. |
| Guestbook | `guestbook` table | Stickers, phrases and gifts are indexes. Gifts give +1 Charm or Speed once. |
| Playdates | `playdates` table + RPCs | The server enforces 3 a day, activity cooldowns and bond, and rolls the egg for both players. |
| Eggs | `egg_grants` → `claim_eggs()` | Claimed into the hatchery, or the nest when full. |

Coins, stats and battles are still stored on the device. Moving the economy to the server is the next step if cheating becomes a concern.

## 1. Supabase

1. Create a project at supabase.com.
2. In **Authentication → Sign In / Providers**, turn on **Anonymous sign-ins**.
3. Install the CLI and deploy from this folder:

   ```bash
   brew install supabase/tap/supabase
   supabase login
   supabase link --project-ref YOUR_PROJECT_REF
   supabase db push
   supabase secrets set APP_BUNDLE_ID=com.eliasnemr.clubkitten
   supabase functions deploy link-game-center
   ```

4. Copy `Config/Secrets.xcconfig.example` to `Config/Secrets.xcconfig` and fill in the project ref and the anon (publishable) key from **Project Settings → API**. That file is git-ignored.

### Local development

Start Docker Desktop, then run `supabase start`. Set `SUPABASE_PROJECT_REF = local` and use the anon key printed by `supabase status`. The simulator reaches `127.0.0.1:54321` on your Mac.

## 2. Game Center

1. The bundle ID is `com.eliasnemr.clubkitten` (it must match `APP_BUNDLE_ID` above).
2. Game Center is switched off for v1. To turn it on, set `CODE_SIGN_ENTITLEMENTS = Config/KittenHatchery.entitlements` for the app target (Signing & Capabilities → + Capability → Game Center does the same).
3. In App Store Connect, create the app record for that bundle ID and turn on Game Center for it.
4. Test on a device or the simulator signed in to a Game Center sandbox account (**Settings → Game Center**). On first run the app asks to see your Game Center friends. Friends who allow it and also play are added automatically.

Friend codes (`KIT-XXXXXX`) work without Game Center, for players who aren't signed in.

## Safety

- Chat is preset phrases and emotes only. The network carries numbers; each device turns them back into text from its own list.
- Lounge channels are private and checked by Row Level Security.
- Clients cannot write friendships, playdates or eggs directly. All of it goes through functions that check the rules.
- If the game is for kids, review COPPA and similar rules before launch: parental consent, data retention, and a way to report or block players (not built yet).
