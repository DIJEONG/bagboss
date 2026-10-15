#!/usr/bin/env node
// 인물 모델 픽스처(생김새 · 승객 · 스킨): 웹판에서 실제로 만든 Model3(뼈 이름 → prism 목록)를 그대로 기록한다.
//   noirModel / suitModel(12-webgl) · defFor + LOOK_CACHE(27-actors) · PASS_MODEL(27) · skinModel / SKINS(13-rig-grammar)
// Swift BBAnim/Models 는 같은 입력으로 같은 조각(q 사각면 · mat · tone · part · c)을 내야 한다(Tests/BBAnimTests/ModelParityTests).
//
//   native/Tests/Fixtures/models.json.deflate   raw DEFLATE JSON { cases: [{ id, kind, input, model }] }
//     kind 'look'  — ETYPES(+타워 · 장치 · 무도장) 생김새별 defFor 결과. input.key 는 Swift ActorDef.look 열쇠 형식
//     kind 'noir'  — noirModel(opts) 직접(기본 정의 JW_* · NOIR_THUG + 머리 모양 전 갈래 격자)
//     kind 'pass'  — PASS_MODEL[i]
//     kind 'skin'  — skinModel(k) (SKINS 전부)
//   node tools/js/extract/models.mjs        (결정적 — 다시 찍어도 같다)
import fs from 'node:fs';
import path from 'node:path';
import zlib from 'node:zlib';
import { openGame, ROOT } from './page.mjs';

const OUT = path.join(ROOT, 'native', 'Tests', 'Fixtures', 'models.json.deflate');
const g = await openGame();
let res;
try { res = await g.page.evaluate(dump); } finally { await g.close(); }
const json = JSON.stringify({ _about: 'tools/js/extract/models.mjs — 웹 noirModel · suitModel · defFor · PASS_MODEL · skinModel 결과', sourceSha16: g.sourceSha16, ...res });
fs.mkdirSync(path.dirname(OUT), { recursive: true });
fs.writeFileSync(OUT, zlib.deflateRawSync(Buffer.from(json), { level: 9 }));
const by = {}; for (const c of res.cases) by[c.kind] = (by[c.kind] || 0) + 1;
console.log(`[models] ${res.cases.length}건 ${JSON.stringify(by)} → ${path.relative(ROOT, OUT)} (${(fs.statSync(OUT).size / 1024) | 0}KB)`);

// ---- 페이지 안 ----
function dump() {
  const S = __BB_SCOPE__;
  const M = S('M'), ETYPES = S('ETYPES'), noirModel = S('noirModel'), skinModel = S('skinModel'), SKINS = S('SKINS'), PASS_MODEL = S('PASS_MODEL');
  const cases = [], seen = new Set();
  // 깊은 복사(공유 꼭짓점 배열을 그대로 펼친다)
  const plain = m => JSON.parse(JSON.stringify(m));
  const str = v => v === undefined || v === null ? '' : String(v);
  // 생김새: defFor 와 같은 식. 머리 배열은 모든 원소를 따로
  const addLook = (src, T) => {
    const L = T.look; if (!L) return;
    const hairs = Array.isArray(L.hair) ? L.hair : [L.hair];
    for (const hair of hairs) {
      const key = [hair === undefined ? 'undefined' : hair, str(L.fat), str(L.coat), T.boss ? 'true' : '', str(L.tie), str(L.mandarin)].join('|');
      if (seen.has(key)) continue; seen.add(key);
      const model = noirModel({ suit: true, coat: M[L.coat || 'COAT'], hair, fat: L.fat, tie: L.tie, mandarin: L.mandarin });
      cases.push({ id: `look:${src}`, kind: 'look', input: { key, hair: hair ?? null, fat: !!L.fat, coat: L.coat || 'COAT', boss: !!T.boss, tie: L.tie ?? null, mandarin: !!L.mandarin }, model: plain(model) });
    }
  };
  for (const [t, T] of Object.entries(ETYPES)) addLook(t, T);
  addLook('dance.RED', { look: { hair: 'pomp', coat: 'RED' } });
  addLook('dance.GOLD', { look: { hair: 'pomp', coat: 'GOLD' } });
  addLook('busk', { look: { hair: 'bandana', coat: 'WOOD' } });
  // 기본 정의 모델
  const noir = (id, o) => cases.push({ id, kind: 'noir', input: o, model: plain(noirModel(o)) });
  noir('JW_HERO', { suit: true, coat: M.SUIT, trou: M.SUIT });
  noir('JW_THUG', { suit: true, coat: M.COAT, cap: true });
  noir('JW_BOSS', { suit: true, coat: M.COAT });
  noir('NOIR_THUG', { cap: true });
  noir('noir.default', {});
  noir('noir.hat', { hatMat: M.SUIT, coat: M.RED, trou: M.WOOD });
  // 머리 모양 전 갈래 × 배 · 차이나 칼라 · 넥타이 · 모자 재질
  const hairs = [undefined, 'tophat', 'mohawk', 'pomp', 'goggle', 'bandana', 'fedora', 'bald', 'crop'];
  let n = 0;
  for (const hair of hairs) for (const fat of [false, true]) for (const mandarin of [false, true]) {
    const o = { suit: true, coat: [M.COAT, M.SUIT, M.RED, M.WOODD][n % 4], hair, fat, mandarin };
    if (n % 3 === 0) o.tie = ['RED', 'GOLD', 'NEONT'][n % 3 === 0 ? (n / 3) % 3 : 0];
    if (n % 5 === 1) o.noTie = true;
    if (n % 4 === 2) { o.hatMat = M.WOODD; o.bandMat = M.MDARK; }
    if (n % 7 === 3) o.cap = true;
    if (n % 6 === 4) o.trou = M.CANVAS;
    noir(`grid.${n}`, o); n++;
  }
  PASS_MODEL.forEach((m, i) => cases.push({ id: `pass.${i}`, kind: 'pass', input: { i }, model: plain(m) }));
  for (const k of Object.keys(SKINS)) cases.push({ id: `skin.${k}`, kind: 'skin', input: { k }, model: plain(skinModel(k)) });
  return { M: plain(M), cases };
}
