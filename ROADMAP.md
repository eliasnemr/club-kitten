# Kitten Hatchery roadmap

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
