// App Store screenshots: a serif headline in gold over each raw simulator shot, on lacquer.
//   node Store/art/frame.mjs <dir of CI shots> [locale: en-US | ja | ko | zh-Hans]
// Writes fastlane/screenshots/en-US/NN_iPhone.png at 1320x2868 (the 6.9" size).
import { chromium } from "file:///C:/Users/Matthew/lastmile/node_modules/playwright/index.mjs";
import { readFileSync, readdirSync, rmSync, mkdirSync } from "fs";

const src = process.argv[2];
const loc = process.argv[3] || "en-US";
const out = `C:/Users/Matthew/baseline-ledger/fastlane/screenshots/${loc}`;
const plan = [
  ["score", "Score it live,<br>point by point.", "Two buttons. <b>The stats fill themselves in.</b>"],
  ["lockscreen", "Score from your<br>Lock Screen.", "Won, Lost, Fault. <b>No unlocking between points.</b>"],
  ["plan", "A new plan<br>every week.", "Four drills built from <b>your own numbers.</b>"],
  ["stats", "Win the points<br>that matter.", "Hold, break, deuce points <b>and the full stat book.</b>"],
  ["opponents", "Know your record<br>against everyone.", "Head to head, sets, <b>and your own notes.</b>"],
  ["scout", "Scout the<br>rematch.", "What's worked, and <b>a three-point plan.</b>"],
  ["challenge", "A new challenge<br>every month.", "Targets that count themselves, <b>and a medal.</b>"],
  ["live", "Practice, ball<br>by ball.", "Every stroke, every serve, <b>every miss.</b>"],
  ["match", "Every match,<br>with momentum.", "The swing of every point, <b>scored live.</b>"],
  ["clay", "Pick your<br>court.", "Clay, lawn, hard court, night, <b>each with its own icon.</b>"],
];
// Captions for the Japanese, Korean and Simplified Chinese store pages; the app screens themselves stay English.
const L10N = {
  "ja": [
    ["score", "1ポイントずつ<br>ライブで記録。", "ボタンは2つ。<b>データは自動で集計。</b>"],
    ["lockscreen", "ロック画面から<br>スコア入力。", "取った、取られた、フォルト。<b>ロック解除は不要。</b>"],
    ["plan", "毎週、新しい<br>練習プラン。", "<b>自分のデータから</b>4つのドリル。"],
    ["stats", "大事なポイントを<br>取りきる。", "キープ率、ブレーク率、デュース、<b>そして全スタッツ。</b>"],
    ["opponents", "全員との<br>対戦成績を。", "勝敗、セット、<b>自分のメモ。</b>"],
    ["scout", "再戦に<br>備える。", "うまくいった戦い方と、<b>3つのプラン。</b>"],
    ["challenge", "毎月、新しい<br>チャレンジ。", "目標は自動でカウント。<b>達成でメダル。</b>"],
    ["live", "練習を<br>1球ずつ。", "すべてのストローク、サーブ、<b>ミスを記録。</b>"],
    ["match", "すべての試合を、<br>流れとともに。", "1ポイントごとの流れを<b>ライブで記録。</b>"],
    ["clay", "コートを<br>選ぼう。", "クレー、芝、ハード、ナイト。<b>それぞれ専用アイコン。</b>"],
  ],
  "ko": [
    ["score", "포인트마다<br>실시간 기록.", "버튼은 두 개. <b>통계는 알아서 채워집니다.</b>"],
    ["lockscreen", "잠금 화면에서<br>점수 기록.", "득점, 실점, 폴트. <b>잠금 해제 없이.</b>"],
    ["plan", "매주 새로운<br>연습 플랜.", "<b>내 기록으로 만든</b> 네 가지 드릴."],
    ["stats", "중요한 포인트를<br>잡으세요.", "서비스 게임, 브레이크, 듀스 <b>그리고 전체 통계.</b>"],
    ["opponents", "모든 상대와의<br>전적을 한눈에.", "상대 전적, 세트, <b>나만의 메모.</b>"],
    ["scout", "재대결을<br>준비하세요.", "통했던 전략과 <b>세 가지 플랜.</b>"],
    ["challenge", "매달 새로운<br>챌린지.", "목표는 자동 집계, <b>달성하면 메달.</b>"],
    ["live", "연습을<br>공 하나하나.", "모든 스트로크, 모든 서브, <b>모든 범실.</b>"],
    ["match", "모든 경기를<br>흐름과 함께.", "포인트마다의 흐름을 <b>실시간으로.</b>"],
    ["clay", "코트를<br>고르세요.", "클레이, 잔디, 하드, 나이트, <b>각각 전용 아이콘.</b>"],
  ],
  "zh-Hans": [
    ["score", "逐分<br>实时记分。", "两个按钮,<b>数据自动生成。</b>"],
    ["lockscreen", "在锁屏上<br>直接记分。", "得分、失分、发球失误,<b>无需解锁。</b>"],
    ["plan", "每周一份<br>新训练计划。", "<b>根据你自己的数据</b>生成四项练习。"],
    ["stats", "拿下<br>关键分。", "保发、破发、平分<b>和完整数据。</b>"],
    ["opponents", "和每位对手的<br>交手记录。", "战绩、盘数,<b>还有你的笔记。</b>"],
    ["scout", "为再战<br>做好侦察。", "哪些打法奏效,<b>外加三点计划。</b>"],
    ["challenge", "每月一个<br>新挑战。", "目标自动统计,<b>完成赢奖牌。</b>"],
    ["live", "练习,<br>逐球记录。", "每一拍、每一发、<b>每一次失误。</b>"],
    ["match", "每场比赛,<br>都有走势。", "每一分的起伏,<b>实时记录。</b>"],
    ["clay", "选择你的<br>球场。", "红土、草地、硬地、夜场,<b>各有专属图标。</b>"],
  ],
};
const steps = loc === "en-US" ? plan : L10N[loc];
const cjk = { ja: "Noto Sans JP", ko: "Noto Sans KR", "zh-Hans": "Noto Sans SC" }[loc];
const cjkSerif = { ja: "Noto Serif JP", ko: "Noto Serif KR", "zh-Hans": "Noto Serif SC" }[loc];
const files = readdirSync(src);
rmSync(out, { recursive: true, force: true });
mkdirSync(out, { recursive: true });
const b = await chromium.launch();
const p = await b.newPage({ viewport: { width: 1320, height: 2868 } });
let n = 1;
for (const [key, head, sub] of steps) {
  const f = files.find((x) => x.endsWith(`-${key}.png`));
  if (!f) { console.log("missing", key); continue; }
  const img = readFileSync(`${src}/${f}`).toString("base64");
  await p.setContent(`<!doctype html><html><head>
<link href="https://fonts.googleapis.com/css2?family=Cormorant+Garamond:wght@500;600&family=Inter:wght@500;600&display=block" rel="stylesheet">${cjk ? `
<link href="https://fonts.googleapis.com/css2?family=${cjkSerif.replace(/ /g, "+")}:wght@600;700;900&family=${cjk.replace(/ /g, "+")}:wght@500;600;700;800;900&display=block" rel="stylesheet">` : ""}
<style>
  body{margin:0;width:1320px;height:2868px;overflow:hidden;background:#0b0a08;font-family:Inter,${cjk ? `"${cjk}",` : ""}sans-serif}
  .glow{position:absolute;inset:0;background:radial-gradient(1200px 900px at 50% -8%,rgba(212,175,55,.26),transparent 62%),radial-gradient(900px 700px at 100% 100%,rgba(156,122,34,.10),transparent 60%)}
  .seam{position:absolute;left:0;top:30px}
  .col{position:absolute;left:96px;right:96px;top:196px;display:flex;flex-direction:column;align-items:center;text-align:center}
  h1{margin:0;font-family:'Cormorant Garamond',${cjk ? `"${cjkSerif}",` : ""}serif;font-weight:600;font-size:118px;line-height:1.0;letter-spacing:-1px;
     background:linear-gradient(135deg,#9e7824 0%,#f7e6a3 30%,#cca33a 52%,#fff0bd 74%,#a8802a 100%);-webkit-background-clip:text;color:transparent}
  p{margin:30px 0 0;color:rgba(243,235,216,.62);font-weight:500;font-size:46px;line-height:1.25}
  p b{color:#f7e7b0;font-weight:600}
  .phone{margin:70px auto 0;width:1060px;border-radius:118px;padding:20px;background:linear-gradient(135deg,#6b4f1a,#d4af37 30%,#3a2e14 55%,#cca33a 80%,#6b4f1a);box-shadow:0 60px 140px rgba(0,0,0,.75)}
  .phone img{display:block;width:100%;border-radius:100px}
${cjk ? "h1,p{text-wrap:balance}" : ""}</style></head><body><div class="glow"></div><svg class="seam" width="1320" height="180" viewBox="0 0 1320 180"><defs><linearGradient id="sg" x1="0" x2="1"><stop offset="0" stop-color="#9e7824" stop-opacity="0"/><stop offset=".5" stop-color="#f7e6a3"/><stop offset="1" stop-color="#9e7824" stop-opacity="0"/></linearGradient></defs><path d="M60 40 C 460 190, 860 190, 1260 40" stroke="url(#sg)" stroke-width="3" fill="none"/><path d="M60 150 C 460 0, 860 0, 1260 150" stroke="url(#sg)" stroke-width="3" fill="none" opacity=".55"/></svg>
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
