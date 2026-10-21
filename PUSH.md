# Push notifications: one-time setup

Club Kitten sends a push when someone invites you to a playdate, sends a friend request, or when your arena defender earns coins. The app, database triggers and the `notify` edge function are already in the repo. These steps connect them to Apple.

## 1. Create an APNs key (Apple Developer, ~2 min)

1. Go to developer.apple.com → Certificates, IDs & Profiles → **Keys** → **+**.
2. Name it "Club Kitten push", tick **Apple Push Notifications service (APNs)**, choose **Sandbox & Production**, and click **Continue → Register**.
3. **Download** the `AuthKey_XXXXXXXXXX.p8` file. You can only download it once, so keep it somewhere safe and out of the repo.
4. Note the **Key ID** (the `XXXXXXXXXX` part). Your Team ID is `X9C498R3DH`.

The App ID `com.eliasnemr.clubkitten` gets the Push Notifications capability automatically the next time Xcode signs the app.

## 2. Give the edge function its secrets (terminal, in this folder)

Pick any long random string for `NOTIFY_SECRET`, for example from `openssl rand -hex 32`.

```bash
supabase secrets set APNS_KEY_P8="$(cat ~/path/to/AuthKey_XXXXXXXXXX.p8)" APNS_KEY_ID=XXXXXXXXXX APNS_TEAM_ID=X9C498R3DH APNS_TOPIC=com.eliasnemr.clubkitten NOTIFY_SECRET=<your random string>
```

Then deploy the function:

```bash
supabase functions deploy notify
```

## 3. Tell the database where to send pushes (Supabase dashboard → SQL editor)

Use the same random string as `NOTIFY_SECRET`:

```sql
select vault.create_secret('https://zdinecoljijyrairsfyh.supabase.co/functions/v1/notify', 'notify_url');
select vault.create_secret('<your random string>', 'notify_secret');
```

Until these two secrets exist, the triggers quietly send nothing, so nothing breaks before setup.

## Testing

- **TestFlight builds** use Apple's production push service. Install from TestFlight, then send an invite or friend request from a second account and close the app.
- **Debug builds** from Xcode on a real iPhone use the sandbox service. Simulators get no real pushes.
