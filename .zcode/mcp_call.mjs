// Minimal MCP-over-HTTP caller for the Supabase hosted MCP server
const TOKEN = process.env.SUPABASE_ACCESS_TOKEN;
if (!TOKEN) {
  console.error("SUPABASE_ACCESS_TOKEN is required in the local environment.");
  process.exit(1);
}
const URL = "https://mcp.supabase.com/mcp?project_ref=zwxswagokhgbuzrrbnhr&read_only=true";
const [,, method, paramsJson] = process.argv;

async function rpc(id, method, params, sessionId) {
  const headers = {
    "Authorization": `Bearer ${TOKEN}`,
    "Content-Type": "application/json",
    "Accept": "application/json, text/event-stream",
  };
  if (sessionId) headers["mcp-session-id"] = sessionId;
  const res = await fetch(URL, {
    method: "POST",
    headers,
    body: JSON.stringify({ jsonrpc: "2.0", id, method, params }),
  });
  const sid = res.headers.get("mcp-session-id");
  const text = await res.text();
  let payload;
  try { payload = JSON.parse(text); }
  catch {
    // SSE: parse data: lines
    const lines = text.split("\n").filter(l => l.startsWith("data:"));
    payload = JSON.parse(lines.map(l => l.slice(5).trim()).join(""));
  }
  return { payload, sid };
}

// initialize to get session
const init = await rpc(0, "initialize", {
  protocolVersion: "2025-03-26",
  capabilities: {},
  clientInfo: { name: "zcode", version: "1.0" },
});
const sid = init.sid;
if (process.env.DEBUG) console.error("SID:", sid);
await fetch(URL, {
  method: "POST",
  headers: { "Authorization": `Bearer ${TOKEN}`, "Content-Type": "application/json", "Accept": "application/json, text/event-stream", "mcp-session-id": sid },
  body: JSON.stringify({ jsonrpc: "2.0", method: "notifications/initialized" }),
});

const { payload } = await rpc(1, method, paramsJson ? JSON.parse(paramsJson) : {}, sid);
if (payload.error) { console.error(JSON.stringify(payload.error, null, 2)); process.exit(1); }
const result = payload.result;
if (process.env.DEBUG) console.error(JSON.stringify(payload).slice(0, 500));
if (result?.content) {
  for (const c of result.content) {
    if (c.type === "text") console.log(c.text);
    else console.log(JSON.stringify(c, null, 2));
  }
} else {
  console.log(JSON.stringify(result, null, 2));
}
