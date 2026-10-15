#!/usr/bin/env node
// N5 모드 기준선: 엘리베이터 타워(startTower — 야근 단계 · 오늘의 타워) · 보너스 차 부수기(jumpTo('bonus'))를
// simtrace.mjs 와 같은 방식(시드 고정 · 고정 스텝 · 렌더 없음)으로 돌린다. 규칙 자리 표(RULE_SITES)는 simtrace.mjs 것을 같이 쓴다.
//
//   node tools/js/extract/modetrace.mjs --lockstep     타워 · 보너스 몇 판 → native/Tests/Fixtures/sim/modes_lockstep.json
//   node tools/js/extract/modetrace.mjs --runs 24      분포 기준선(타워 정시 · 야근 3 · 보너스) → modes_baseline.json
//   node tools/js/extract/modetrace.mjs --fx           함수 픽스처(twSpawn 배율 · 오늘의 타워 조건 · bonusGrade · carStage 문턱 · carBones) → modes_fx.json
import fs from 'node:fs';
import path from 'node:path';
import { openGame, ROOT } from './page.mjs';
import { ruleLineMap } from './simtrace.mjs';

const arg = (k, d) => { const i = process.argv.indexOf(k); return i > 0 ? process.argv[i + 1] : d; };
const FIX = path.join(ROOT, 'native', 'Tests', 'Fixtures', 'sim');

export async function runMode(seed, { mode = 'tower', seconds = 300, kit = 'basic', ot = 0, daily = false, lockstep = false, opts = {} } = {}) {
  const g = await openGame({ run: true, viewport: { width: 390, height: 844 } });
  try {
    const p = g.page;
    await p.evaluate(s => { sessionStorage.setItem('bbSeed', String(s)); }, seed);
    await p.addInitScript(([lock, sites]) => {
      const s0 = +sessionStorage.getItem('bbSeed'); if (!s0) return;
      const mk = s => { let a = s | 0; return () => { a |= 0; a = a + 0x6D2B79F5 | 0; let t = Math.imul(a ^ a >>> 15, 1 | a); t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t; return ((t ^ t >>> 14) >>> 0) / 4294967296; }; };
      if (!lock) Math.random = mk(s0);
      else {
        let rule = mk(s0), pres = mk(s0 ^ 0x5bd1e995);
        window.__bbRT = []; window.__bbFrame = 0;
        window.__bbReseed = () => { rule = mk(s0); pres = mk(s0 ^ 0x5bd1e995); window.__bbRT = []; };
        Math.random = () => {
          const ln = +((new Error().stack.split('\n')[2] || '').match(/:(\d+):\d+\)?$/) || [0, 0])[1];
          const fn = sites[ln];
          if (fn) { const v = rule(); if (window.__bbRT.length < 60000) window.__bbRT.push([window.__bbFrame, fn]); return v; }
          return pres();
        };
      }
      window.__bbHold = true; localStorage.clear(); localStorage.setItem('dotlab-lang', 'ko');
    }, [lockstep, lockstep ? ruleLineMap() : {}]);
    await p.reload();
    await p.waitForFunction(() => typeof window.__BB_SCOPE__ === 'function');
    return await p.evaluate(simulateMode, { mode, seconds, kit, ot, daily, lockstep, opts });
  } finally { await g.close(); }
}

function simulateMode({ mode, seconds, kit, ot, daily, lockstep, opts = {} }) {
  const S = __BB_SCOPE__, GS = S('GS');
  if (lockstep) window.__bbReseed();
  S('setMode')('game');
  { const M = S('META'); M.kits[kit] = 1; M.tower = { best: 0, bestT: 0, runs: 0, ot: 6 }; }   // 가방 · 야근 단계를 열어 둔다
  S('RUNCFG = {...RUNCFG, kit: ' + JSON.stringify(kit) + ', stage: 0, daily: false}');
  try { S('closeMenu')(); } catch (e) {}   // (closeMenu 는 속도를 1 로 되돌린다 — 모드 시작 전에 불러 웹 그대로 GAME_SPD 1.25 가 남게)
  if (mode === 'tower') S('startTower')({ ot, daily });
  else { S('startRun')({ kit, stage: 0, daily: false }); S('jumpTo')('bonus'); }
  window.__bbAuto = true;
  if (opts.speed) S('playSpeed = ' + opts.speed);
  const DT = 1 / 60, step = 1 / S('animFps');
  const out = { lock: [], dateKey: S('todayKey')() };
  let t = 0, bres = null;
  const extra = () => { const T = GS.tower, B = GS.bonus;
    if (T) return `${T.floor}:${T.phase}:${T.pos.toFixed(1)}:${T.door.toFixed(2)}:${S('twWeight')()}:${T.dark}:${T.outs}:${T.ceilN}`;
    if (B) return `${B.phase}:${B.hp.toFixed(1)}:${B.score}:${B.car.stage}`;
    return '-'; };
  for (let i = 0; i < seconds * 60; i++) {
    window.__bbFrame = i;
    if (opts.script && GS.on && GS.hero && !GS.hero.dead) {
      const H = GS.hero, F = GS.ents.filter(a => a.e && !a.dead).sort((a, b) => Math.abs(a.d.x - H.d.x) - Math.abs(b.d.x - H.d.x));
      if (i % 37 === 0 && F.length) S('manual')(F[0].d.x >= H.d.x ? 1 : -1);
      if (i % 211 === 0) S('heroDuck')(true);
      if (i % 97 === 0) S('trySpecial')();
      if (i % 53 === 0) { const A = F.find(a => a.action && !a.action.fired && S('FOE_W')[a.anim] && Math.abs(a.d.x - H.d.x) < 46); if (A) S('manual')(A.d.x >= H.d.x ? 1 : -1); }
    }
    if (lockstep && i % 30 === 0) out.lock.push([i, GS.state, GS.ci, +GS.time.toFixed(3), +GS.hp.toFixed(2), GS.score, GS.kills, +GS.hero.d.x.toFixed(2), GS.hero.anim, GS.combo,
      GS.ents.filter(a => a.e && !a.dead).map(a => a.e.t + '@' + a.d.x.toFixed(1) + ':' + a.anim + ':' + Math.round(a.e.hp)).join(' '), extra()]);
    const sp = S('playSpeed');
    if (GS.on && GS.slowT > 0) GS.slowT -= DT;
    if (GS.on) S('spcCamTick')(DT);
    S('camTick')(DT);
    const dt = DT * sp * ((GS.on && GS.slowT > 0) ? .28 : 1) * (GS.on ? (GS.spcTime || 1) : 1);
    S('gameTime += ' + dt); S('acc += ' + dt);
    let n = 0; while (S('acc') >= step && n < 8) { S('acc -= ' + step); n++; if (!S('paused')) S('stepAnim')(); }
    if (!S('paused')) S('gameUpdate')(dt);
    if (S('acc') > step) S('acc = 0');
    { const C = GS.cut; if (C && C.k !== 'story') { C.t += Math.min(.1, DT) * sp; if (C.t >= C.dur) { GS.cut = null; if (C.k === 'spc') S('spcBegin')(C.kind); } } }
    t += DT;
    if (GS.state === 'shop') { const b = document.querySelector('#gOverlay .lc') || document.querySelector('#gOverlay .skip'); if (b) b.click(); }
    if (GS.state === 'arrange') { const b = document.querySelector('#sbArrange button'); if (b) b.dispatchEvent(new PointerEvent('pointerup', { bubbles: true })); }
    if (GS.bonus && GS.bonus.res && !bres) { const B = GS.bonus; bres = { g: B.res.g, tk: B.res.tk, left: +B.res.left.toFixed(3), done: B.res.done, total: B.tally.total, hit: B.tally.hit, part: B.tally.part,
      dealt: Math.round(B.dealt), hits: B.hits, maxCombo: B.maxCombo, stage: B.car.stage, t: +B.t.toFixed(3) }; }
    if (GS.state === 'over' || (mode === 'bonus' && GS.state === 'transfer')) break;
  }
  const T = GS.tower, st = GS.stats || {};
  out.result = { t: +t.toFixed(3), state: GS.state, hp: +GS.hp.toFixed(2), score: GS.score, kills: GS.kills, tokens: GS.tokens, dealt: Math.round(st.dealt || 0), taken: Math.round(st.taken || 0),
    floor: T ? (T.done ? 20 : T.floor) : 0, secs: T ? Math.round(GS.time - T.t0) : 0, outs: T ? T.outs : 0, ceils: T ? T.ceilN : 0, wrecks: T ? (T.wrecks || 0) : 0, daily: T ? T.daily : null,
    bonus: bres };
  if (lockstep) out.rt = window.__bbRT;
  return out;
}

// ---- 함수 픽스처(순수 부분) ----
async function fixtures() {
  const g = await openGame({ run: true });
  try {
    return await g.page.evaluate(() => {
      const S = __BB_SCOPE__, GS = S('GS');
      S('setMode')('game'); const M = S('META'); M.tower = { best: 0, bestT: 0, runs: 0, ot: 6 };
      const out = { spawn: [], daily: [], ot: [], grade: [], stages: [], bones: [] };
      // twSpawn 배율: 층 1~20 × 야근 0 · 1 · 4 · 6 — 종류마다 hp · dmg · cd · cdT · x · z
      for (const ot of [0, 1, 4, 6]) {
        S('startTower')({ ot });
        const T = GS.tower;
        for (const fl of [1, 2, 5, 9, 10, 11, 14, 19, 20]) for (const [k, t] of ['valet', 'courier', 'mgr', 'headchef', 'butcher', 'accountant'].entries()) {
          T.floor = fl; GS.ents = [GS.hero]; S('twSpawn')(t, k); const a = GS.ents[GS.ents.length - 1];
          out.spawn.push({ ot, fl, t, k, hp: a.e.hp, dmg: a.e.dmg, cd: +a.e.cd.toFixed(6), cdT: +a.e.cdT.toFixed(6), x: a.d.x, z: a.z, flip: a.d.flip });
        }
        out.ot.push({ ot, limit: T.limit, kit: T.kit, hpK: T.hpK, dmgK: T.dmgK, bossK: T.bossK, restK: T.restK, black: [...T.blackSet].sort((a, b) => a - b), w10: T.waves[10], w20: T.waves[20] });
        GS.cut = null;
      }
      // 오늘의 타워 조건: 날짜 열쇠 여럿 → 층별 탑승 목록 · 정전 층 · 정원 · 조건 id
      const TWF = S('TW_FLOORS'), TOP = S('TW_TOP');
      for (let d = 0; d < 40; d++) {
        const dk = `2026-${String(1 + (d % 12)).padStart(2, '0')}-${String(1 + ((d * 7) % 28)).padStart(2, '0')}`;
        const T = { waves: {}, blackSet: new Set(TWF.map((F, n) => F && F.black ? n : 0).filter(Boolean)), limit: S('TW_LIMIT'), mods: [] };
        for (let n = 1; n <= TOP; n++) T.waves[n] = (TWF[n].w || []).slice();
        const D = S('twDaily')(dk);
        for (let n = 1; n <= TOP; n++) if (!TWF[n].boss) { const w = T.waves[n]; for (let i = w.length - 1; i > 0; i--) { const j = Math.floor(D.r() * (i + 1)); [w[i], w[j]] = [w[j], w[i]]; } }
        for (const m of D.mods) { m.ap(T, D.r); T.mods.push(m.id); }
        out.daily.push({ dk, hash: S('hashStr')(dk), kit: S('KITS')[S('hashStr')(dk) % S('KITS').length].id, mods: T.mods, limit: T.limit, black: [...T.blackSet].sort((a, b) => a - b), waves: Array.from({ length: TOP }, (_, i) => T.waves[i + 1]) });
      }
      // bonusGrade
      for (const [hp, t, dealt] of [[0, 10, 460], [0, 17.9, 460], [0, 18, 460], [0, 24, 460], [0, 29.9, 460], [100, 30, 360], [184, 30, 276], [185, 30, 275], [400, 30, 60], [460, 30, 0], [0, 0.5, 460]]) {
        const r = S('bonusGrade')({ hp, max: 460, t, dur: 30, dealt });
        out.grade.push({ hp, t, dealt, g: r.g, tk: r.tk, pts: r.pts, left: r.left, done: r.done, pct: r.pct, dps: r.dps });
      }
      // carHit 문턱: 같은 피해 열을 넣고 단계 · 점수 · 부품 점수 · 파편
      for (const seq of [[10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10],
        [55, 56, 60, 70, 80, 140], [460], [30, 1, 2, 3, 4, 200, 100, 64]]) {
        S('jumpTo')('bonus'); const BN = GS.bonus; BN.phase = 'go'; const rows = [];
        for (const [i, loss] of seq.entries()) { GS.combo = i % 25; S('carHit')(loss); rows.push([BN.car.stage, BN.score, BN.hitPts, BN.partPts, +BN.hp.toFixed(3), Object.keys(BN.car.gone).sort().join(','), BN.car.debris.length, +BN.car.tilt.toFixed(3), BN.alarm, !!BN.fire]); }
        out.stages.push({ seq, rows, debris: BN.car.debris.map(d => [d.key, +d.x.toFixed(4), +d.y.toFixed(4), +d.z.toFixed(4), +d.th.toFixed(5)]) });
      }
      // carBones(흔들림 0)
      for (const [stage, dmgF, gone, tilt] of [[0, 0, [], 0], [3, .4, ['mirror', 'hubF'], 0], [6, .7, ['mirror', 'hubF', 'bumperF', 'doorF'], 0], [7, .85, ['mirror', 'hubF', 'bumperF', 'doorF', 'hood', 'doorR', 'wheelF', 'wheelF2'], .07], [8, 1, ['trunk'], .09]]) {
        const C = { stage, dmgF, shake: 0, gone: Object.fromEntries(gone.map(k => [k, 1])), tilt }; const B = S('carBones')(C);
        out.bones.push({ stage, dmgF, gone, tilt, dentN: C.dentN, bones: Object.fromEntries(Object.entries(B).map(([k, b]) => [k, [+b.x.toFixed(6), +b.y.toFixed(6), +b.z.toFixed(6), +b.th.toFixed(6), b.sy == null ? null : +b.sy.toFixed(6)]])) });
      }
      return out;
    });
  } finally { await g.close(); }
}

if (import.meta.url === `file://${process.argv[1]}`) {
  if (process.argv.includes('--fx')) {
    const r = await fixtures();
    fs.writeFileSync(path.join(FIX, 'modes_fx.json'), JSON.stringify({ _about: 'modetrace.mjs --fx — 타워 · 보너스 순수 함수 픽스처', ...r }) + '\n');
    console.log('[modetrace] fx', r.spawn.length, r.daily.length, r.grade.length, r.stages.length, r.bones.length); process.exit(0);
  }
  if (process.argv.includes('--lockstep')) {
    const LIST = [[8101, 'tower', 'basic', 300, 0], [8102, 'tower', 'foot', 300, 0], [8103, 'tower', 'basic', 420, 3], [8104, 'tower', 'grap', 300, 6],
      [8105, 'tower', 'link', 300, 0, true], [8106, 'tower', 'crit', 300, 2, false, { script: true }], [8107, 'tower', 'basic', 600, 0],
      [8108, 'tower', 'guard', 300, 5, false, { script: true, speed: 1 }],
      [8201, 'bonus', 'basic', 60], [8202, 'bonus', 'foot', 60], [8203, 'bonus', 'grap', 60], [8204, 'bonus', 'crit', 60, 0, false, { script: true }]];
    const runs = [];
    for (const [seed, mode, kit, sec, ot = 0, daily = false, opts = {}] of LIST) {
      const r = await runMode(seed, { mode, kit, seconds: sec, ot, daily, lockstep: true, opts });
      runs.push({ seed, mode, kit, seconds: sec, ot, daily, opts, dateKey: r.dateKey, result: r.result, lock: r.lock, rt: r.rt });
      process.stdout.write(`\r[modetrace] 락스텝 ${runs.length}/${LIST.length}`);
    }
    fs.writeFileSync(path.join(FIX, 'modes_lockstep.json'), JSON.stringify({ _about: 'modetrace.mjs --lockstep — 타워 · 보너스(규칙 자리만 시드 수열)', runs }) + '\n');
    console.log('\n[modetrace] → modes_lockstep.json'); process.exit(0);
  }
  const RUNS = +arg('--runs', 24), SEED0 = +arg('--seed0', 9000);
  const sets = [['tower0', { mode: 'tower', seconds: 900, ot: 0 }], ['tower3', { mode: 'tower', seconds: 900, ot: 3 }], ['bonus', { mode: 'bonus', seconds: 60 }]];
  const out = { _about: 'modetrace.mjs --runs — 타워 · 보너스 분포 기준선(시드 고정 자동 전투)', sets: {} };
  for (const [name, o] of sets) {
    out.sets[name] = { ...o, results: [] };
    for (let s = 1; s <= RUNS; s++) { const r = await runMode(SEED0 + s, o); out.sets[name].results.push({ seed: SEED0 + s, ...r.result }); process.stdout.write(`\r[modetrace] ${name} ${s}/${RUNS}`); }
  }
  fs.writeFileSync(path.join(FIX, 'modes_baseline.json'), JSON.stringify(out, null, 1) + '\n');
  console.log('\n[modetrace] → modes_baseline.json');
}
