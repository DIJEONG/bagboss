#!/usr/bin/env node
// 전투 규칙 함수 픽스처(N3): 웹 닫힌 범위 함수를 직접 불러 입력 → 출력을 기록한다(Math.random 은 고정값으로 바꾼다 — 소비 횟수와 무관하게 같은 값).
//   reactKey · deathOf · legDur · atkStartup · timeToCue(적 동작 칸마다) · hitTier/hitKind · spawnWave(배율 · 자리) ·
//   damage(동작 × 옵션 × 적 × 체력) · 주인공 피격 · jugHit/jugStep 궤적 · trainUpdate 적분
//
//   node tools/js/extract/combatfx.mjs          → native/Tests/Fixtures/sim/combat.json
//   node tools/js/extract/combatfx.mjs --check  두 번 뽑아 같은지
import fs from 'node:fs';
import path from 'node:path';
import { openGame, ROOT, writeJson } from './page.mjs';

const OUT = path.join(ROOT, 'native', 'Tests', 'Fixtures', 'sim', 'combat.json');

async function extract() {
  const g = await openGame();
  try {
    return await g.page.evaluate(collect);
  } finally { await g.close(); }
}

function collect() {
  const S = __BB_SCOPE__, GS = S('GS'), out = {};
  const R = v => { Math.random = () => v; };
  R(0.5);
  S('setMode')('game');
  S('startRun')({ kit: 'basic', stage: 0, daily: false });
  const H = GS.hero;
  const r4 = x => x == null ? null : Math.round(x * 1e4) / 1e4;

  // ---- 표 함수 ----
  const ANIMS = ['jab', 'cross', 'hook', 'upper', 'scoop', 'skick', 'kick', 'knee', 'elbow', 'round', 'round_air', 'bat', 'charge', 'charge_air', 'sweep', 'axe', 'axe_air',
    'tetsu', 'renkan', 'throw', 'suplex', 'bkick', 'bfist', 'hbutt', 'hm_swing', 'hm_back', 'hm_up', 'hm_down', 'idle', 'stomp', 'uthrust', 'swat', 'cycle', 'fkick'];
  const OPTS = [{}, { knock: true }, { react: 'launch' }, { react: 'body' }, { react: 'down' }, { splash: true }, { react: 'head' }, { crit: true }, { blast: true }];
  out.reactKey = [];
  for (const a of ANIMS) for (const o of OPTS) out.reactKey.push({ anim: a, o, rk: S('reactKey')({ anim: a }, o) });
  out.deathOf = ['fall', 'launch', 'rKick', 'rSpin', 'rSwept', 'rCharge', 'rSlam', 'rStomp', 'jland', 'crumple', 'rSpike', 'rTetsu', 'rBlast', 'rKnee', 'hitB', 'rElbow', 'hit', 'rCross', 'rHook']
    .map(rk => ({ rk, d: S('deathOf')(rk) }));
  out.legDur = S('STAGES').map(st => st.line.map(L => S('legDur')(L)));
  out.atkStartup = Object.keys(S('JW_CUE')).map(a => ({ a, t: r4(S('atkStartup')(a)) }));
  out.hitTier = [];
  for (const a of ANIMS) for (const o of [{}, { crit: true }, { blast: true }]) for (const rk of ['hit', 'rSlam', 'launch', 'crumple'])
    out.hitTier.push({ a, o, rk, n: S('hitTier')(a, o, rk), k: S('hitKind')(a, rk === 'rSlam') });

  // ---- 적 만들기 ----
  const reset = () => { GS.ents = [H]; H.d.x = 200; H.d.flip = false; H.anim = 'idle'; H.si = 0; H.action = null; H.queue = []; H.hs = 0; H.kb = 0; H.dead = false; H.jug = null;
    GS.spc = null; GS.cut = null; GS.croute = null; GS.combo = 0; GS.lastHit = null; GS.time = 10; GS.sp = 0; GS.score = 0; GS.bossBreak = null; GS.hp = GS.max; GS.slowT = 0;
    GS.stats = { dealt: 0, taken: 0, crits: 0, counters: 0, outs: 0 }; GS.curSrc = null; GS.ci = 0; GS.stageIdx = 0; GS.hurtAt = null; S('freeze=0'); GS.shots = []; GS.items = []; };
  const spawn = (t, dx) => { S('spawnWave')([t], false); GS.cut = null; const T = GS.ents[GS.ents.length - 1]; T.d.x = 200 + dx; T.d.flip = dx > 0; T.anim = 'idle'; T.si = 0; T.hs = 0; T.kb = 0; return T; };

  // ---- spawnWave: 배율 · 자리 ----
  out.spawn = [];
  for (const [ci, sg] of [[0, 0], [3, 0], [2, 2], [5, 4]]) for (const hx of [40, 240, 440]) for (const fromDoors of [false, true]) {
    reset(); GS.ci = ci; GS.stageIdx = sg; H.d.x = hx;
    const n0 = GS.ents.length; S('spawnWave')(['punk', 'heavy', 'rusher', 'guard'], fromDoors); GS.cut = null;
    out.spawn.push({ ci, sg, hx, fromDoors, ents: GS.ents.slice(n0).map(a => ({ t: a.e.t, hp: a.e.hp, dmg: a.e.dmg, cd: r4(a.e.cd), cdT: r4(a.e.cdT), x: a.d.x, z: a.z, flip: a.d.flip, remap: a.remap })) });
  }

  // ---- timeToCue: 적 동작 칸마다 ----
  out.ttc = [];
  for (const [t, mv] of [['punk', 'jab'], ['punk', 'hook'], ['punk', 'kick'], ['rusher', 'hbutt'], ['rusher', 'charge'], ['heavy', 'bat'], ['guard', 'jab'], ['kungfu', 'fkick'], ['kungfu', 'round'], ['boss', 'upper']]) {
    reset(); const T = spawn(t, 30); GS.engageT = null;
    S('foeStrike')(T, mv);
    const rows = []; let n = 0;
    while (T.action && !T.action.fired && n < 200) { rows.push([T.anim, T.si, T.hold, r4(S('timeToCue')(T))]); S('advance')(T); n++; }
    out.ttc.push({ t, mv, rows });
  }

  // ---- damage: 동작 × 옵션 × 적 × 체력 ----
  const snapT = (T) => ({ hp: r4(T.e.hp), anim: T.anim, pose: T.pose, after: T.after || null, kb: r4(T.kb), hs: T.hs, stun: r4(T.e.stun), dead: !!T.dead,
    jug: T.jug ? { vy: r4(T.jug.vy), vx: r4(T.jug.vx), h: r4(T.jug.h), n: T.jug.n, pts: T.jug.pts } : null,
    hhs: H.hs, hx: r4(H.d.x), combo: GS.combo, score: GS.score, sp: r4(GS.sp), dealt: r4(GS.stats.dealt), freeze: S('freeze'), slowT: r4(GS.slowT) });
  out.damage = [];
  const DANIMS = ['jab', 'cross', 'hook', 'upper', 'kick', 'knee', 'elbow', 'round', 'sweep', 'charge', 'axe', 'tetsu', 'renkan', 'throw', 'bkick', 'stomp', 'scoop', 'skick'];
  const DOPTS = [{}, { crit: true }, { knock: true }, { react: 'launch' }, { react: 'body' }, { crit: true, bigCrit: true }, { back: true }, { blast: true }, { counter: true, crit: true }, { just: true, crit: true }, { react: 'down' }];
  for (const et of ['punk', 'heavy', 'guard', 'boss']) for (const low of [false, true]) for (const air of [false, true]) for (const a of DANIMS) for (const o of DOPTS) {
    reset(); const T = spawn(et, 20); if (low) T.e.hp = 3;
    if (air) { H.anim = 'upper'; S('jugHit')(T, 'launch', 1, H, { react: 'launch' }, 1); T.jug.h = 20; T.hs = 0; H.hs = 0; GS.time = 10.5; }
    H.anim = a;
    S('damage')(H, T, 10, { ...o });
    out.damage.push({ et, low, air, a, o, r: snapT(T) });
  }
  // 주인공 피격
  out.hurt = [];
  for (const mv of ['jab', 'hook', 'kick', 'bat', 'charge', 'round', 'upper', 'fkick', 'hbutt'])
    for (const o of [{ react: 'head' }, { knock: true, react: 'head' }, { react: 'launch' }]) {
      reset(); const T = spawn('punk', 20); T.anim = mv; T.lastMove = mv;
      S('damage')(T, H, 8, { ...o });
      out.hurt.push({ mv, o, r: { hp: r4(GS.hp), anim: H.anim, after: H.after || null, kb: r4(H.kb), hs: H.hs, ths: T.hs, taken: r4(GS.stats.taken), sp: r4(GS.sp), dead: !!H.dead } });
    }

  // ---- 저글 궤적 ----
  out.jug = [];
  for (const rk of ['launch', 'rkPop', 'rKick', 'rBlast', 'rSwept', 'rSpin', 'fall']) for (const heavy of [false, true]) for (const second of [false, true]) {
    reset(); const T = spawn(heavy ? 'heavy' : 'punk', 20); H.anim = 'upper';
    S('jugHit')(T, rk, 1, H, { react: 'launch' }, heavy ? .35 : 1);
    const rows = [];
    for (let i = 0; i < 300 && T.jug; i++) {
      if (second && i === 12) { H.anim = 'kick'; S('jugHit')(T, 'rKick', 1, H, { knock: true }, 1); }
      S('jugStep')(T, 1 / 60);
      if (i % 3 === 0 || !T.jug) rows.push([i, T.jug ? r4(T.jug.h) : null, T.jug ? r4(T.jug.vy) : null, T.pose, r4(T.airOv), r4(T.kb), T.anim]);
    }
    out.jug.push({ rk, heavy, second, rows });
  }

  // ---- 열차 적분 ----
  out.train = [];
  for (const sc of ['depart', 'brake', 'cruise']) {
    reset(); GS.state = 'fight'; GS.leg = 0; GS.legStart = 0; GS.qi = 0; GS.quickStop = null; GS.qDwell = null; GS.arriving = false; GS.expr = false; GS.prevEx = null;
    const TR = S('TR');
    Object.assign(TR, { v: 0, a: 0, ex: 0, phase: 'stop', t: 0, joint: 0, bumps: [], jolt: 0, dy: 0, strap: 0, strapV: 0, door: 1, stopAt: 0 });
    GS.departT = 0; GS.doorWant = false;
    if (sc === 'depart') { GS.departT = 2.2; GS.doorWant = true; }
    if (sc === 'brake') { Object.assign(TR, { v: 700, phase: 'brake', ex: 5000, stopAt: 6100, door: 0 }); GS.legStart = 3000; GS.qi = 9; }
    if (sc === 'cruise') { Object.assign(TR, { v: 300, phase: 'accel', ex: 100, door: 0 }); GS.qi = 9; }
    const rows = [];
    for (let i = 0; i < 900; i++) { S('trainUpdate')(1 / 60); if (i % 15 === 0) rows.push([i, r4(TR.v), r4(TR.a), r4(TR.ex), TR.phase, r4(TR.door), r4(TR.joint), r4(TR.jolt), r4(GS.press || 0)]); }
    out.train.push({ sc, rows });
  }
  return out;
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const a = await extract();
  if (process.argv.includes('--check')) {
    const b = await extract(); const same = JSON.stringify(a) === JSON.stringify(b);
    console.log(`[combatfx] 결정성 ${same ? '같음' : '다름!'}`); process.exit(same ? 0 : 1);
  }
  writeJson(OUT, { _about: 'tools/js/extract/combatfx.mjs — 웹 전투 규칙 함수 입출력(Math.random=0.5 고정)', ...a });
  const n = Object.entries(a).map(([k, v]) => `${k} ${Array.isArray(v) ? v.length : ''}`).join(' · ');
  console.log(`[combatfx] ${n} → ${path.relative(ROOT, OUT)}`);
}
