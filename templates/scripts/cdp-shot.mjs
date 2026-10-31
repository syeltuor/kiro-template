#!/usr/bin/env node
// kiro-template v2.0.0
// Screenshot a URL at an exact CSS viewport via the Chrome DevTools Protocol (no dependencies; Node's global
// WebSocket, so it needs a Node.js version that ships one). Used by screenshots.sh for mobile shots,
// because headless Chrome clamps --window-size to a ~500 px minimum width.
//
// Usage: node scripts/cdp-shot.mjs OUT.png URL WIDTH HEIGHT
import { spawn } from "node:child_process";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const [out, url, w, h] = process.argv.slice(2);
if (!out || !url || !(Number(w) > 0) || !(Number(h) > 0)) {
  console.error("Usage: node scripts/cdp-shot.mjs OUT.png URL WIDTH HEIGHT");
  process.exit(2);
}
const CHROME = process.env.CHROME ?? "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";
const profile = mkdtempSync(join(tmpdir(), "cdp-shot-"));
const chrome = spawn(CHROME, [
  "--headless", "--disable-gpu", "--hide-scrollbars", "--no-first-run", "--no-default-browser-check",
  `--user-data-dir=${profile}`, "--remote-debugging-port=0", "about:blank",
], { stdio: ["ignore", "ignore", "pipe"] });

const cleanup = () => {
  try { chrome.kill(); } catch { /* already gone */ }
  setTimeout(() => rmSync(profile, { recursive: true, force: true }), 300);
};
const fail = (msg) => { console.error(`❌ ${msg}`); cleanup(); process.exit(1); };
const timer = setTimeout(() => fail("timed out"), 30000);

const wsUrl = await new Promise((resolve) => {
  let buf = "";
  chrome.stderr.on("data", (d) => {
    buf += d.toString();
    const m = buf.match(/DevTools listening on (ws:\/\/\S+)/);
    if (m) resolve(m[1]);
  });
});

const ws = new WebSocket(wsUrl);
await new Promise((resolve, reject) => { ws.onopen = resolve; ws.onerror = reject; });
let id = 0;
const pending = new Map();
const waiters = [];
ws.onmessage = (ev) => {
  const msg = JSON.parse(ev.data);
  if (msg.id && pending.has(msg.id)) {
    const { resolve, reject } = pending.get(msg.id);
    pending.delete(msg.id);
    if (msg.error) reject(new Error(msg.error.message));
    else resolve(msg.result);
  } else if (msg.method) {
    for (const wt of waiters) if (wt.method === msg.method) wt.resolve(msg.params);
  }
};
const send = (method, params = {}, sessionId) => new Promise((resolve, reject) => {
  id += 1;
  pending.set(id, { resolve, reject });
  ws.send(JSON.stringify({ id, method, params, ...(sessionId ? { sessionId } : {}) }));
});
const once = (method) => new Promise((resolve) => waiters.push({ method, resolve }));

try {
  const { targetId } = await send("Target.createTarget", { url: "about:blank" });
  const { sessionId } = await send("Target.attachToTarget", { targetId, flatten: true });
  await send("Emulation.setDeviceMetricsOverride", { width: Number(w), height: Number(h), deviceScaleFactor: 1, mobile: true }, sessionId);
  await send("Page.enable", {}, sessionId);
  const loaded = once("Page.loadEventFired");
  await send("Page.navigate", { url }, sessionId);
  await loaded;
  await new Promise((r) => setTimeout(r, 2500)); // let modules, fonts and fetches settle
  const { data } = await send("Page.captureScreenshot", { format: "png" }, sessionId);
  writeFileSync(out, Buffer.from(data, "base64"));
  await send("Browser.close").catch(() => {});
} catch (e) {
  fail(e.message);
}
clearTimeout(timer);
cleanup();
