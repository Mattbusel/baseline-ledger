// In-App Event media for Store/events.py: a 1920x1080 card (three raw app screens on lacquer, no text:
// the App Store draws the event name over it) and a 1080x1920 details page per event.
//   node Store/art/event_media.mjs <dir of raw CI shots> <out dir>
import { chromium } from "file:///C:/Users/Matthew/lastmile/node_modules/playwright/index.mjs";
import { readFileSync, readdirSync, mkdirSync } from "fs";

const [raw, out] = process.argv.slice(2);
mkdirSync(out, { recursive: true });
const files = readdirSync(raw);
const shot = (k) => `data:image/png;base64,${readFileSync(`${raw}/${files.find((f) => f.endsWith(`-${k}.png`))}`).toString("base64")}`;
const EV = {
  premiere: { card: ["score", "lockscreen", "plan"], details: "lockscreen" },
  serve: { card: ["live", "challenge", "plan"], details: "challenge" },
};
const bg = "radial-gradient(1400px 900px at 50% -10%, rgba(212,175,55,.30), transparent 60%), radial-gradient(900px 700px at 100% 100%, rgba(156,122,34,.14), transparent 60%), #0b0a08";
const phone = (src, w) => `<div style="width:${w}px;border-radius:${w * 0.11}px;padding:${w * 0.02}px;background:linear-gradient(135deg,#6b4f1a,#d4af37 30%,#3a2e14 55%,#cca33a 80%,#6b4f1a);box-shadow:0 40px 100px rgba(0,0,0,.75)"><img src="${src}" style="display:block;width:100%;border-radius:${w * 0.095}px"></div>`;
const b = await chromium.launch();
for (const [key, e] of Object.entries(EV)) {
  let p = await b.newPage({ viewport: { width: 1920, height: 1080 } });
  // Phones sit low so the App Store's title overlay (top left) stays readable.
  await p.setContent(`<body style="margin:0"><div style="width:1920px;height:1080px;background:${bg};position:relative;overflow:hidden">
    <div style="position:absolute;left:560px;top:250px;transform:rotate(-7deg)">${phone(shot(e.card[0]), 380)}</div>
    <div style="position:absolute;left:1360px;top:250px;transform:rotate(7deg)">${phone(shot(e.card[2]), 380)}</div>
    <div style="position:absolute;left:940px;top:150px">${phone(shot(e.card[1]), 440)}</div>
  </div></body>`);
  await p.waitForTimeout(200);
  await p.screenshot({ path: `${out}/card-${key}.png`, clip: { x: 0, y: 0, width: 1920, height: 1080 } });
  await p.close();
  p = await b.newPage({ viewport: { width: 1080, height: 1920 } });
  await p.setContent(`<body style="margin:0"><div style="width:1080px;height:1920px;background:${bg};display:flex;align-items:flex-end;justify-content:center;overflow:hidden">
    <div style="margin-bottom:-260px">${phone(shot(e.details), 820)}</div></div></body>`);
  await p.waitForTimeout(200);
  await p.screenshot({ path: `${out}/details-${key}.png`, clip: { x: 0, y: 0, width: 1080, height: 1920 } });
  await p.close();
  console.log("wrote", key);
}
await b.close();
