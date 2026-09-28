// HMAC potpis workera koje okida `private.call_worker` (task 51, ADR-0024).
//
// Isti oblik kao `send-push`: `Authorization: Bearer <unix-sekunde>.<HMAC-SHA256>` nad
// `<scope>:<unix-sekunde>`, sa odstupanjem do 60 sekundi. Scope je dio potpisa, pa potpis
// za `cleanup-media` ne otvara `notify-content-reports` ni obrnuto, i kad dijele tajnu.

async function key(secret: string, usage: KeyUsage) {
  return await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    [usage],
  );
}

export async function workerAuthorization(
  secret: string,
  scope: string,
  timestamp = Math.floor(Date.now() / 1000),
) {
  const signature = await crypto.subtle.sign(
    "HMAC",
    await key(secret, "sign"),
    new TextEncoder().encode(`${scope}:${timestamp}`),
  );
  const hex = Array.from(
    new Uint8Array(signature),
    (b) => b.toString(16).padStart(2, "0"),
  ).join("");
  return `Bearer ${timestamp}.${hex}`;
}

export async function authorized(
  request: Request,
  secret: string,
  scope: string,
): Promise<boolean> {
  if (!secret) return false;
  const match = /^Bearer (\d{10})\.([a-f0-9]{64})$/.exec(
    request.headers.get("Authorization") ?? "",
  );
  if (!match || Math.abs(Date.now() / 1000 - Number(match[1])) > 60) {
    return false;
  }
  const signature = Uint8Array.from(
    match[2].match(/../g)!,
    (hex) => parseInt(hex, 16),
  );
  return crypto.subtle.verify(
    "HMAC",
    await key(secret, "verify"),
    signature,
    new TextEncoder().encode(`${scope}:${match[1]}`),
  );
}
