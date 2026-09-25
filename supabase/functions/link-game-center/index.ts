// Verifies a Game Center identity signature and links the player's teamPlayerID to their profile.
// The app gets these fields from GKLocalPlayer.fetchItemsForIdentityVerificationSignature().
import { createClient } from "npm:@supabase/supabase-js@2";
import { createVerify } from "node:crypto";
import { Buffer } from "node:buffer";

type Body = {
  publicKeyURL: string;
  signature: string; // base64
  salt: string; // base64
  timestamp: number; // milliseconds since 1970, from GameKit
  teamPlayerID: string;
  bundleID: string;
  displayName?: string;
};

const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });

Deno.serve(async (req) => {
  if (req.method !== "POST") return json(405, { error: "POST only" });

  const auth = req.headers.get("Authorization");
  if (!auth) return json(401, { error: "Missing session" });
  const url = Deno.env.get("SUPABASE_URL")!;
  const userClient = createClient(url, Deno.env.get("SUPABASE_ANON_KEY")!, {
    global: { headers: { Authorization: auth } },
  });
  const { data: { user } } = await userClient.auth.getUser();
  if (!user) return json(401, { error: "Invalid session" });

  let body: Body;
  try {
    body = await req.json();
  } catch {
    return json(400, { error: "Bad JSON" });
  }

  const expectedBundle = Deno.env.get("APP_BUNDLE_ID") ?? "com.eliasnemr.clubkitten";
  if (body.bundleID !== expectedBundle) return json(400, { error: "Wrong app" });

  // Only fetch Apple's signing certificate from Apple.
  let keyURL: URL;
  try {
    keyURL = new URL(body.publicKeyURL);
  } catch {
    return json(400, { error: "Bad key URL" });
  }
  if (keyURL.protocol !== "https:" || !keyURL.hostname.endsWith(".apple.com")) {
    return json(400, { error: "Key URL is not Apple's" });
  }
  if (Math.abs(Date.now() - body.timestamp) > 10 * 60 * 1000) {
    return json(400, { error: "Signature is too old" });
  }

  const der = Buffer.from(await (await fetch(keyURL)).arrayBuffer());
  const pem = "-----BEGIN CERTIFICATE-----\n" +
    der.toString("base64").match(/.{1,64}/g)!.join("\n") +
    "\n-----END CERTIFICATE-----\n";

  // Signed payload: teamPlayerID + bundleID (UTF-8) + timestamp (UInt64 big-endian) + salt.
  const ts = Buffer.alloc(8);
  ts.writeBigUInt64BE(BigInt(body.timestamp));
  const payload = Buffer.concat([
    Buffer.from(body.teamPlayerID, "utf8"),
    Buffer.from(body.bundleID, "utf8"),
    ts,
    Buffer.from(body.salt, "base64"),
  ]);
  const verifier = createVerify("RSA-SHA256");
  verifier.update(payload);
  if (!verifier.verify(pem, Buffer.from(body.signature, "base64"))) {
    return json(401, { error: "Game Center signature did not verify" });
  }

  const admin = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  // A Game Center player belongs to one profile: unlink it from any older anonymous profile.
  await admin.from("profiles").update({ gc_player_id: null })
    .eq("gc_player_id", body.teamPlayerID).neq("id", user.id);
  const update: Record<string, unknown> = { gc_player_id: body.teamPlayerID };
  if (body.displayName) update.display_name = body.displayName.slice(0, 24);
  const { error } = await admin.from("profiles").update(update).eq("id", user.id);
  if (error) return json(500, { error: error.message });

  return json(200, { linked: true });
});
