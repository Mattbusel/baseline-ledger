// App Store screenshots: a serif headline in gold over each raw simulator shot, on lacquer.
//   node Store/art/frame.mjs <dir of CI shots>
// Writes fastlane/screenshots/en-US/NN_iPhone.png at 1320x2868 (the 6.9" size).
import { chromium } from "file:///C:/Users/Matthew/lastmile/node_modules/playwright/index.mjs";
import { readFileSync, readdirSync, rmSync, mkdirSync } from "fs";

const src = process.argv[2];
const out = "C:/Users/Matthew/fairway-ledger/fastlane/screenshots/en-US";
const plan = [
  ["home", "Your game,<br>in one ledger.", "Handicap, practice and rounds, <b>finished in gold.</b>"],
  ["scorecard", "Every hole,<br>every putt.", "Score, putts, fairways, penalties, <b>and your net.</b>"],
  ["widgets", "Your round on<br>the Lock Screen.", "Score to par as you play, <b>and a handicap widget.</b>"],
  ["plan", "Practice what<br>costs you strokes.", "A weekly plan <b>built from your own numbers.</b>"],
  ["rounds", "Saved courses,<br>nine or eighteen.", "Pars, rating and slope <b>fill in by themselves.</b>"],
  ["course", "Know every hole<br>you play.", "The ones that cost you, <b>and the ones to attack.</b>"],
  ["stats", "See where the<br>strokes go.", "Par 3s, 4s and 5s, <b>penalties and three-putts.</b>"],
  ["poster", "A round worth<br>framing.", "Gold-leaf scorecards <b>to share.</b>"],
  ["live", "Log the range,<br>ball by ball.", "Strike, shape, misses <b>and real carries.</b>"],
  ["paywall", "Free to log.<br>Pro, once.", "The full stat book for <b>one payment, no subscription.</b>"],
];
const files = readdirSync(src);
rmSync(out, { recursive: true, force: true });
mkdirSync(out, { recursive: true });
const b = await chromium.launch();
const p = await b.newPage({ viewport: { width: 1320, height: 2868 } });
let n = 1;
for (const [key, head, sub] of plan) {
  const f = files.find((x) => x.endsWith(`-${key}.png`));
  if (!f) { console.log("missing", key); continue; }
  const img = readFileSync(`${src}/${f}`).toString("base64");
  await p.setContent(`<!doctype html><html><head>
<link href="https://fonts.googleapis.com/css2?family=Cormorant+Garamond:wght@500;600&family=Inter:wght@500;600&display=block" rel="stylesheet">
<style>
  body{margin:0;width:1320px;height:2868px;overflow:hidden;background:#0b0a08;font-family:Inter,sans-serif}
  .glow{position:absolute;inset:0;background:radial-gradient(1200px 900px at 50% -8%,rgba(212,175,55,.26),transparent 62%),radial-gradient(900px 700px at 100% 100%,rgba(156,122,34,.10),transparent 60%)}
  .rule{position:absolute;left:96px;right:96px;top:150px;height:2px;background:linear-gradient(90deg,transparent,rgba(247,231,176,.6),transparent)}
  .col{position:absolute;left:96px;right:96px;top:196px;display:flex;flex-direction:column;align-items:center;text-align:center}
  h1{margin:0;font-family:'Cormorant Garamond',serif;font-weight:600;font-size:118px;line-height:1.0;letter-spacing:-1px;
     background:linear-gradient(135deg,#9e7824 0%,#f7e6a3 30%,#cca33a 52%,#fff0bd 74%,#a8802a 100%);-webkit-background-clip:text;color:transparent}
  p{margin:30px 0 0;color:rgba(243,235,216,.62);font-weight:500;font-size:46px;line-height:1.25}
  p b{color:#f7e7b0;font-weight:600}
  .phone{margin:70px auto 0;width:1060px;border-radius:118px;padding:20px;background:linear-gradient(135deg,#6b4f1a,#d4af37 30%,#3a2e14 55%,#cca33a 80%,#6b4f1a);box-shadow:0 60px 140px rgba(0,0,0,.75)}
  .phone img{display:block;width:100%;border-radius:100px}
</style></head><body><div class="glow"></div><div class="rule"></div>
<div class="col"><h1>${head}</h1><p>${sub}</p>
<div class="phone"><img src="data:image/png;base64,${img}"></div></div>
</body></html>`);
  await p.evaluate(() => document.fonts.ready);
  await p.waitForTimeout(300);
  const name = `${String(n).padStart(2, "0")}_iPhone.png`;
  await p.screenshot({ path: `${out}/${name}`, clip: { x: 0, y: 0, width: 1320, height: 2868 } });
  console.log("wrote", name, key);
  n++;
}
await b.close();
