# Club Kitten roadmap

## In progress: cloud save (v1.1)

- [x] `saves` table and `push_save` (newest version wins), tested on local Supabase
- [x] App uploads after changes and on background, restores after reinstall, never overwrites progress with a fresh install
- [x] Cloud save works with multiplayer still off (`SUPABASE_MULTIPLAYER = NO`)
- [ ] Game Center restore on a new phone: change `link-game-center` to sign in to the existing account instead of moving the Game Center ID
- [x] Create the real Supabase project (`club-kitten`, Frankfurt, ref `zdinecoljijyrairsfyh`) and deploy both migrations; anonymous sign-ins on
- [ ] Update App Privacy answers and the privacy policy before shipping
- [ ] Decide on the Supabase plan: free projects pause after a week with no traffic (the app then falls back to on-device saves); Pro ($25/mo) never pauses

## ⏸ Paused: online multiplayer (Supabase + Game Center)

The code is in place but switched off. With no `Config/Secrets.xcconfig`, the app runs locally with the practice friends (Sam, Mia, Leo). Xcode shows a build warning from `Online.swift` as a reminder.

When you're ready to resume, follow [MULTIPLAYER.md](MULTIPLAYER.md):

- [ ] Try it locally first: start Docker, run `supabase start`, set `SUPABASE_PROJECT_REF = local`
- [ ] Create the Supabase project and turn on anonymous sign-ins
- [ ] `supabase link`, `supabase db push`, `supabase functions deploy link-game-center`
- [ ] Fill in `Config/Secrets.xcconfig`
- [ ] Re-add the Game Center entitlement (removed for v1) and turn on Game Center in App Store Connect
- [ ] Test sign-in, friend codes, a lounge visit and a playdate on two devices
- [ ] Then: move coins and furniture purchases to the server so they can't be cheated

## Done

- Hatching, 10 breeds from Basic to Legendary, breed book
- Battles, four minigames, skills
- Cat Lounge, decorating, guestbook, playdate eggs, egg nest
- Furniture shop, colours, wallpaper, lounge names, daily challenges
