#!/usr/bin/env node
// 캐릭터 픽스처(N2): 실제로 도는 웹판에서 캐릭터 한 명을 그릴 때 거치는 네 단계의 입력 · 출력을 기록한다.
//   ① 포즈 평가  drawChar0 앞뒤의 캐릭터 상태 → 최종 포즈 P (보간 · 보행 · 전환 블렌드 · 주인공 추종)
//   ② 관절 풀이  P + 리그 → 관절 j            (charBones 로 넘어가는 값)
//   ③ 뼈        charBones(j, P, tq) → B
//   ④ 메시      pushModel(c, B, ox, oy, remap, flash) · pushFace → 정점(10 float)
// Swift BBAnim 은 단계마다 같은 출력을 내야 한다(Tests/BBAnimTests).
//
//   native/Tests/Fixtures/characters.json.deflate   raw DEFLATE JSON { models: {id: model3}, samples: [...] }
//   정점 배열은 Float32 리틀 엔디언 base64(웹 v3 가 Float32Array 라 값이 그대로 같다). 표본은 동작 · 자세가 겹치지 않게 MAX 개로 고른다
//   node tools/js/extract/characters.mjs     (스냅숏 — 다시 찍으면 동작이 달라진다)
import fs from 'node:fs';
import path from 'node:path';
import zlib from 'node:zlib';
import { openGame, ROOT } from './page.mjs';

const OUT = path.join(ROOT, 'native', 'Tests', 'Fixtures', 'characters.json.deflate');
const MAX = 64;
const SCENES = [
  { name: 'subway', setup: `window.__dotlab.jumpTo('subway')`, warm: 2500 },
  { name: 'tower', setup: `(()=>{ const L=window.__dotlab; L.jumpTo('tower'); L.demoBag(1); L.towerGo(4); })()`, warm: 2500 },
];
const SHOTS = 12, GAP = 260;

const all = { models: {}, samples: [] };
let sourceSha16 = '';
for (const sc of SCENES) {
  const g = await openGame({ run: true, viewport: { width: 390, height: 844 } });
  sourceSha16 = g.sourceSha16;
  try {
    const p = g.page;
    await p.waitForTimeout(1200);
    await p.click('#modeSeg button[data-m="game"]');
    await p.waitForTimeout(1200);
    await p.evaluate(sc.setup);
    await p.waitForTimeout(sc.warm);
    for (let s = 0; s < SHOTS; s++) {
      await p.evaluate(() => { window.__bbHold = true; });
      await p.waitForTimeout(60);
      const r = await p.evaluate(captureCharacters);
      // 모델 번호는 페이지마다 m0 부터 다시 매겨진다 → 장면 이름을 붙여 섞이지 않게
      for (const [k, m] of Object.entries(r.models)) all.models[`${sc.name}.${k}`] = m;
      for (const x of r.samples) all.samples.push({ scene: sc.name, shot: s, ...x, model: `${sc.name}.${x.model}` });
      // 루프 놓아주기: 맡아 둔 콜백으로 다시 돈다
      await p.evaluate(() => { window.__bbHold = false; const cb = window.__bbHeld; window.__bbHeld = null; if (cb) requestAnimationFrame(cb); });
      await p.waitForTimeout(GAP);
    }
  } finally { await g.close(); }
}
// 표본 고르기: 블렌드 중 · 주인공 · 얼굴 · 처음 보는 (동작, 자세) 우선
const seen = new Set(), chosen = [];
const score = s => (s.before.bFrom ? 4 : 0) + (s.hero ? 2 : 0) + (s.face ? 1 : 0);
for (const s of [...all.samples].sort((a, b) => score(b) - score(a))) {
  const k = s.before.anim + '/' + s.before.pose + '/' + (s.before.bFrom ? 'b' : '') + (s.hero ? 'h' : '');
  if (seen.has(k) || !s.mesh) continue; seen.add(k); chosen.push(s); if (chosen.length >= MAX) break;
}
const f32 = a => Buffer.from(new Float32Array(a).buffer).toString('base64');
for (const s of chosen) { s.mesh.verts = f32(s.mesh.verts); if (s.face) s.face.verts = f32(s.face.verts); }
const used = new Set(chosen.map(s => s.model)), models = Object.fromEntries(Object.entries(all.models).filter(([k]) => used.has(k)));
const json = JSON.stringify({ _about: 'tools/js/extract/characters.mjs 로 찍은 웹 캐릭터 단계별 입출력 — 스냅숏', sourceSha16, models, samples: chosen });
fs.mkdirSync(path.dirname(OUT), { recursive: true });
fs.writeFileSync(OUT, zlib.deflateRawSync(Buffer.from(json), { level: 9 }));
const anims = new Set(chosen.map(s => s.before.anim));
console.log(`[characters] 표본 ${chosen.length}/${all.samples.length}개 · 모델 ${Object.keys(models).length}종 · 동작 ${anims.size}종(${[...anims].join(' ')}) → ${path.relative(ROOT, OUT)} (${(fs.statSync(OUT).size / 1024) | 0}KB)`);

// ---- 페이지 안 ----
function captureCharacters() {
  const S = __BB_SCOPE__;
  const GS = S('GS'), OPT = S('OPT');
  const orig = { drawChar0: S('drawChar0'), charBones: S('charBones'), pushModel: S('pushModel'), pushFace: S('pushFace') };
  const models = {}, samples = [];
  window.__bbModelIds ??= new WeakMap(); window.__bbModelN ??= 0;
  const modelId = m => { if (!window.__bbModelIds.has(m)) window.__bbModelIds.set(m, 'm' + (window.__bbModelN++)); const id = window.__bbModelIds.get(m); models[id] = m; return id; };
  const pick = (o, keys) => { const r = {}; for (const k of keys) if (o[k] !== undefined) r[k] = o[k]; return r; };
  const clone = v => v == null ? v : JSON.parse(JSON.stringify(v));
  const ACT = ['anim', 'pose', 'prev', 'k', 'phaseN', 'hold', 'si', 'gph', 'guardW', 'runU', 'legRun', 'airOv', 'tilt', 'flash', 'hidden', 'blink',
    'remap', 'wpn', 'pass', 'passPose', '_an', '_rgo', '_vr', '_va', '_vt', 'bT0', 'bDur', 'gres', 'shk'];
  const state = c => ({ ...clone(pick(c, ACT)), bFrom: clone(c.bFrom), lastP: clone(c.lastP), jug: c.jug ? pick(c.jug, ['roll', 'kick']) : null,
    d: pick(c.d, ['x', 'y', 'flip', 'name', 'gait', 'face', 'smear', 'msT', 'jw']) });
  let cur = null;
  const W = {
    drawChar0(c, out) {
      if (!c.d || !c.d.model3) return orig.drawChar0(c, out);
      cur = { hero: c === GS.hero, model: modelId(c.d.model3), rig: c.d.rig, before: state(c) };
      const n0 = S('n3');
      const r = orig.drawChar0(c, out);
      cur.after = state(c); cur.n3 = [n0, S('n3')];
      samples.push(cur); cur = null;
      return r;
    },
    charBones(j, P, R, tq) { const B = orig.charBones(j, P, R, tq); if (cur) cur.bones = { j: clone(j), P: clone(P), tq, B: clone(B) }; return B; },
    pushModel(c, B, ox, oy, remapFn, flash) {
      const n0 = S('n3'); const r = orig.pushModel(c, B, ox, oy, remapFn, flash);
      if (cur) { const v3 = S('v3'); cur.mesh = { ox, oy, flash: !!flash, remap: c.remap || 0, verts: Array.from(v3.subarray(n0 * 10, S('n3') * 10)) }; }
      return r;
    },
    pushFace(c, headBone, ox, oy) {
      const n0 = S('n3'); const r = orig.pushFace(c, headBone, ox, oy);
      if (cur) { const v3 = S('v3'); cur.face = { key: S('faceOf')(c), ox, oy, verts: Array.from(v3.subarray(n0 * 10, S('n3') * 10)) }; }
      return r;
    },
  };
  window.__bbW = W;
  for (const n in W) S(`${n} = window.__bbW.${n}`);
  try { S('render')(performance.now()); }
  finally { for (const n in orig) { window.__bbO = orig[n]; S(`${n} = window.__bbO`); } }
  return { models, samples: samples.map(s => ({ ...s, gameTime: S('gameTime'), shades: !!OPT.shades })) };
}
