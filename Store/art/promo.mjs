// Promoted in-app purchase images, 1024x1024, no text and no price: the court seen from above in each
// finish's colours, and for Plus every finish at once around the gold seal.
//   node Store/art/promo.mjs   -> Store/art/promo/<product suffix>.png
import { chromium } from "file:///C:/Users/Matthew/lastmile/node_modules/playwright/index.mjs";
import { mkdirSync } from "fs";

const out = "C:/Users/Matthew/baseline-ledger/Store/art/promo";
mkdirSync(out, { recursive: true });
const bands = {
  gold: ["#9e7824", "#f7e6a3", "#cca338", "#fff0bd", "#a88029"],
  clay: ["#96401e", "#f8cdb2", "#d06c3e", "#ffdcc6", "#a04a26"],
  lawn: ["#3e7426", "#d9f2c6", "#74b44f", "#eafadf", "#46802c"],
  hard: ["#255c96", "#cde4fb", "#4f90d6", "#e4f1ff", "#2b66a6"],
  night: ["#8a9c18", "#f4fcc8", "#cde43c", "#fbffe2", "#98ac1c"],
};
const foil = (b) => `linear-gradient(135deg,${b[0]} 0%,${b[1]} 28%,${b[2]} 50%,${b[3]} 72%,${b[4]} 100%)`;
const court = (b, w, h) => `
  <div style="position:relative;width:${w}px;height:${h}px;border-radius:36px;background:${foil(b)};padding:10px;box-sizing:border-box;box-shadow:0 40px 120px rgba(0,0,0,.6)">
    <div style="position:absolute;inset:10px;border-radius:28px;background:radial-gradient(circle at 50% 30%, rgba(255,255,255,.06), rgba(0,0,0,.25)), ${b[2]}"></div>
    <svg viewBox="0 0 100 200" preserveAspectRatio="none" style="position:absolute;inset:44px;width:calc(100% - 88px);height:calc(100% - 88px)">
      <g stroke="${b[3]}" stroke-width="1.1" fill="none" opacity=".95">
        <rect x="0" y="0" width="100" height="200"/>
        <line x1="12" y1="0" x2="12" y2="200"/><line x1="88" y1="0" x2="88" y2="200"/>
        <line x1="12" y1="54" x2="88" y2="54"/><line x1="12" y1="146" x2="88" y2="146"/>
        <line x1="50" y1="54" x2="50" y2="146"/>
      </g>
      <line x1="-4" y1="100" x2="104" y2="100" stroke="#f3ebd8" stroke-width="2.2"/>
    </svg>
  </div>`;
const seal = (size) => `
  <div style="width:${size}px;height:${size}px;border-radius:50%;background:${foil(bands.gold)};display:flex;align-items:center;justify-content:center;box-shadow:0 0 140px rgba(212,175,55,.55)">
    <svg width="${size * 0.62}" height="${size * 0.62}" viewBox="0 0 100 100"><g stroke="#0b0a08" stroke-width="6" fill="none" stroke-linecap="round" opacity=".8">
      <path d="M22 10 C 50 34, 50 66, 22 90"/><path d="M78 10 C 50 34, 50 66, 78 90"/></g></svg>
  </div>`;
const page = (inner) => `<body style="margin:0"><div style="width:1024px;height:1024px;background:radial-gradient(circle at 50% 0%, #2a2210 0%, #14110c 55%, #0b0a08 100%);display:flex;align-items:center;justify-content:center;position:relative;overflow:hidden">${inner}</div></body>`;

const b = await chromium.launch();
const p = await b.newPage({ viewport: { width: 1024, height: 1024 } });
async function shot(name, html) {
  await p.setContent(page(html));
  await p.waitForTimeout(150);
  await p.screenshot({ path: `${out}/${name}.png`, clip: { x: 0, y: 0, width: 1024, height: 1024 } });
  console.log("wrote", name);
}
for (const id of ["clay", "lawn", "hard", "night"]) {
  await shot(`court.${id}`, `<div style="transform:rotate(-8deg)">${court(bands[id], 470, 820)}</div>`);
}
// Plus: the four finishes fanned out behind the seal. Yearly gets the full fan, monthly a tighter one.
const fan = (spread) => ["clay", "lawn", "hard", "night"].map((id, i) =>
  `<div style="position:absolute;left:50%;top:50%;transform:translate(-50%,-50%) rotate(${(i - 1.5) * spread}deg) translateY(-40px)">${court(bands[id], 300, 560)}</div>`).join("");
await shot("plus.yearly", `${fan(16)}<div style="position:relative;z-index:2;margin-top:300px">${seal(330)}</div>`);
await shot("plus.monthly", `${fan(9)}<div style="position:relative;z-index:2;margin-top:300px">${seal(290)}</div>`);
await b.close();
