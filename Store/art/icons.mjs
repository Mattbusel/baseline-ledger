// The four court icons: the Baseline Ledger seal (the two curved seams of a ball), refinished.
// Writes Resources/Assets.xcassets/AppIcon-<Name>.appiconset.
import { chromium } from "file:///C:/Users/Matthew/lastmile/node_modules/playwright/index.mjs";
import { mkdirSync, writeFileSync } from "fs";

// Five bands, dark to bright and back, matching Court.band in Theme.swift; glow rgb; warm centre.
const courts = {
  RedClay: [["#96401e", "#f8cdb2", "#d06c3e", "#ffdcc6", "#a04a26"], "217,119,74", "#2e140a"],
  Lawn: [["#3e7426", "#d9f2c6", "#74b44f", "#eafadf", "#46802c"], "127,191,90", "#13240c"],
  HardCourt: [["#255c96", "#cde4fb", "#4f90d6", "#e4f1ff", "#2b66a6"], "90,155,224", "#0c1a2e"],
  NightSession: [["#8a9c18", "#f4fcc8", "#cde43c", "#fbffe2", "#98ac1c"], "214,238,69", "#1a1f06"],
};
const root = "C:/Users/Matthew/baseline-ledger/Resources/Assets.xcassets";
const b = await chromium.launch();
const p = await b.newPage({ viewport: { width: 1024, height: 1024 } });
for (const [name, [band, glow, warm]] of Object.entries(courts)) {
  const foil = `linear-gradient(135deg,${band[0]} 0%,${band[1]} 28%,${band[2]} 50%,${band[3]} 72%,${band[4]} 100%)`;
  const lacquer = `radial-gradient(circle at 50% 0%, ${warm} 0%, #14110c 55%, #0b0a08 100%)`;
  const stops = band.map((c, i) => `<stop offset="${[0, 0.3, 0.55, 0.78, 1][i]}" stop-color="${c}"/>`).join("");
  await p.setContent(`<body style="margin:0"><div style="width:1024px;height:1024px;background:${lacquer};display:flex;align-items:center;justify-content:center">
     <div style="width:700px;height:700px;border-radius:50%;padding:14px;box-sizing:border-box;background:${foil};box-shadow:0 0 120px rgba(${glow},.35)">
      <div style="width:100%;height:100%;border-radius:50%;background:#100d08;position:relative;overflow:hidden">
       <svg width="672" height="672" viewBox="0 0 672 672" style="position:absolute;inset:0"><defs><linearGradient id="g" x1="0" y1="0" x2="1" y2="1">${stops}</linearGradient></defs>
        <path d="M130 60 C 330 220, 330 452, 130 612" stroke="url(#g)" stroke-width="30" fill="none" stroke-linecap="round"/>
        <path d="M542 60 C 342 220, 342 452, 542 612" stroke="url(#g)" stroke-width="30" fill="none" stroke-linecap="round"/></svg>
      </div></div></div></body>`);
  const dir = `${root}/AppIcon-${name}.appiconset`;
  mkdirSync(dir, { recursive: true });
  await p.screenshot({ path: `${dir}/icon-1024.png`, clip: { x: 0, y: 0, width: 1024, height: 1024 } });
  writeFileSync(`${dir}/Contents.json`, JSON.stringify({ images: [{ filename: "icon-1024.png", idiom: "universal", platform: "ios", size: "1024x1024" }], info: { author: "xcode", version: 1 } }, null, 2));
  console.log("wrote", name);
}
await b.close();
