// Sends a push notification to every iPhone a player has registered.
// Called only by the database (send_push in the push migration), which proves itself with
// the shared NOTIFY_SECRET. Apple push keys never leave this function's secrets.
//
// Secrets (supabase secrets set …): APNS_KEY_P8, APNS_KEY_ID, APNS_TEAM_ID, APNS_TOPIC, NOTIFY_SECRET.
import { createClient } from "npm:@supabase/supabase-js@2";
import { importPKCS8, SignJWT } from "npm:jose@5";

type Body = { user_id: string; title: string; body: string; kind: string };

const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });

// Apple accepts a provider token for up to an hour; refresh a little earlier.
let cachedJWT: { token: string; at: number } | null = null;
async function providerToken(): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedJWT && now - cachedJWT.at < 50 * 60) return cachedJWT.token;
  const key = await importPKCS8(Deno.env.get("APNS_KEY_P8")!.replace(/\\n/g, "\n"), "ES256");
  const token = await new SignJWT({})
    .setProtectedHeader({ alg: "ES256", kid: Deno.env.get("APNS_KEY_ID")! })
    .setIssuer(Deno.env.get("APNS_TEAM_ID")!)
    .setIssuedAt(now)
    .sign(key);
  cachedJWT = { token, at: now };
  return token;
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return json(405, { error: "POST only" });
  const secret = Deno.env.get("NOTIFY_SECRET");
  if (!secret || req.headers.get("x-notify-secret") !== secret) return json(401, { error: "Not allowed" });

  const msg = (await req.json()) as Body;
  if (!msg.user_id || !msg.title) return json(400, { error: "Missing fields" });

  const db = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  const { data: tokens, error } = await db.from("device_tokens").select("token, env").eq("user_id", msg.user_id);
  if (error) return json(500, { error: error.message });
  if (!tokens?.length) return json(200, { sent: 0 });

  const jwt = await providerToken();
  const payload = JSON.stringify({
    aps: { alert: { title: msg.title.slice(0, 120), body: msg.body.slice(0, 200) }, sound: "default", "thread-id": msg.kind },
    kind: msg.kind,
  });

  let sent = 0;
  for (const t of tokens) {
    const host = t.env === "production" ? "api.push.apple.com" : "api.sandbox.push.apple.com";
    const res = await fetch(`https://${host}/3/device/${t.token}`, {
      method: "POST",
      headers: {
        authorization: `bearer ${jwt}`,
        "apns-topic": Deno.env.get("APNS_TOPIC") ?? "com.eliasnemr.clubkitten",
        "apns-push-type": "alert",
        "apns-priority": "10",
        "apns-collapse-id": msg.kind,
      },
      body: payload,
    });
    if (res.ok) {
      sent++;
    } else if (res.status === 410 || res.status === 400) {
      // The app was deleted or the token is no good: forget it.
      const reason = await res.text();
      if (res.status === 410 || reason.includes("BadDeviceToken")) {
        await db.from("device_tokens").delete().eq("token", t.token);
      }
    }
  }
  return json(200, { sent });
});
