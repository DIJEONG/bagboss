#!/usr/bin/env node
// 결정적 웹 시뮬레이션(N3 기준선): Math.random 을 시드 고정(mulberry32)으로 바꾸고, 화면 루프 대신 고정 스텝으로
// stepAnim(12fps 칸) · gameUpdate(dt) 만 직접 돌린다(렌더 없음). 한 번의 evaluate 안에서 동기로 돌므로 setTimeout 도 끼어들지 않는다.
// → 같은 시드면 같은 판. Swift BBSim 과 '통계'(여러 시드의 분포)로 비교하는 기준선을 만든다.
//
//   node tools/js/extract/simtrace.mjs --check            같은 시드 두 번 → 같은 결과인지(결정성)
//   node tools/js/extract/simtrace.mjs --runs 40           시드 40개로 자동 전투 → native/Tests/Fixtures/sim/baseline.json
import fs from 'node:fs';
import path from 'node:path';
import { openGame, ROOT } from './page.mjs';

const arg = (k, d) => { const i = process.argv.indexOf(k); return i > 0 ? process.argv[i + 1] : d; };
const RUNS = +arg('--runs', 20), SECONDS = +arg('--seconds', 90), STAGE = +arg('--stage', 0), KIT = arg('--kit', 'basic');
const OUT = path.join(ROOT, 'native', 'Tests', 'Fixtures', 'sim', arg('--out', 'baseline.json'));
const SEED0 = +arg('--seed0', 1000);

// 락스텝(--lockstep): 규칙 자리(Swift BBSim 이 난수를 쓰는 웹 줄)에서 부른 Math.random 만 시드 수열을 쓰고,
// 연출 자리(입자 · 말풍선 · 흔들림 …)는 다른 수열을 쓴다 → Swift 와 규칙 난수 소비 순서가 같아져 같은 씨앗이면 같은 판이 된다.
// 규칙 자리 표: 조각 이름 → [줄, 웹 함수 이름]. Swift 이식에서 rnd() 를 부르는 곳과 1:1(연출 난수는 Swift 가 쓰지 않는다)
export const RULE_SITES = {
  // N5 타워(modetrace.mjs): 회계사 버튼 추가 탑승 · 주방장 플랑베 · 청소부 · 관리인 · 덜컹 흔들림(TR.dy) · 밤바람
  '24-tower.js': [[76, 'twArrive'], [124, 'twFoeTick'], [126, 'twFoeTick'], [128, 'twFoeTick'], [136, 'towerTick'], [144, 'towerTick']],
  '26-bag-model.js': [[32, 'rollOpt'], [33, 'rollOpt']],
  // K 프롤로그(storytrace.mjs): 두드리는 문 고르기(bangT · 문 · 횟수 · BAM) · 웨이브가 나올 문 고르기
  '39-prologue.js': [[19, 'doorTick']],
  '44-story.js': [[127, 'corridorUpdate']],
  '27-actors.js': [[42, 'startBoard'], [48, 'boardAt'], [49, 'boardAt'], [50, 'boardAt'], [66, 'passengerUpdate'], [80, 'spawnWave'], [114, 'damage'], [194, 'heroSkill'], [214, 'drop'], [219, 'pickGear'], [233, 'pickSkill']],
  '29-combat-flow.js': [[105, 'heroAI'], [169, 'foeAI'], [170, 'foeAI'], [188, 'flankCall']],
  '30-train-env.js': [[111, 'gameUpdate'], [142, 'gameUpdate'], [201, 'startRun']],
  '33-bag-ui2.js': [[119, 'genImprints'], [125, 'shopCarve']],
  '34-shop.js': [[3, 'shopPick'], [4, 'shopPick']],
  '37-gimmicks.js': [[41, 'envMove'], [48, 'passTrainUpdate'], [50, 'passTrainUpdate'], [63, 'legEvent'], [65, 'legEvent'], [73, 'evUpdate'], [83, 'propsInit'], [84, 'propsInit'], [85, 'propsInit'], [88, 'slipUpdate']],
};
/** 조각 줄 → 임시 HTML 의 줄(page.mjs instrumentedHtml 과 같은 이어 붙이기) */
export function ruleLineMap() {
  const SRC = path.join(ROOT, 'web', 'src');
  const order = fs.readFileSync(path.join(SRC, 'ORDER.txt'), 'utf8').split(/\s+/).filter(Boolean);
  const map = {}; let nl = 0;
  for (const n of order) {
    const txt = fs.readFileSync(path.join(SRC, n), 'utf8');
    for (const [ln, fn] of RULE_SITES[n] || []) map[nl + ln] = fn;
    nl += (txt.match(/\n/g) || []).length;
  }
  return map;
}

export async function runSeed(seed, { seconds = SECONDS, stage = STAGE, kit = KIT, trace = false, lockstep = false, fine = null, opts = {} } = {}) {
  const g = await openGame({ run: true, viewport: { width: 390, height: 844 } });
  try {
    const p = g.page;
    // 부팅 전에 난수를 시드로 고정 · 루프는 처음부터 붙잡는다(첫 rAF 부터 맡아 둠)
    await p.addInitScript(() => {});   // (openGame 이 이미 goto 했으므로 여기선 안 씀 — 아래 reload 로 적용)
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
          if (fn) { const v = rule(); if (window.__bbRT.length < 40000) window.__bbRT.push([window.__bbFrame, fn]); return v; }
          return pres();
        };
      }
      window.__bbHold = true; localStorage.clear(); localStorage.setItem('dotlab-lang', 'ko');
    }, [lockstep, lockstep ? ruleLineMap() : {}]);
    await p.reload();
    await p.waitForFunction(() => typeof window.__BB_SCOPE__ === 'function');
    return await p.evaluate(simulate, { seconds, stage, kit, trace, lockstep, fine, opts });
  } finally { await g.close(); }
}

// ---- 페이지 안: 고정 스텝 진행 ----
function simulate({ seconds, stage, kit, trace, lockstep, fine, opts = {} }) {
  const S = __BB_SCOPE__, GS = S('GS');
  if (lockstep) window.__bbReseed();   // 부팅 중 소비분을 버리고 setMode 부터 같은 수열
  S('setMode')('game');
  { const M = S('META'); M.lines[stage] = 1; M.kits[kit] = 1; }   // 노선 · 가방을 열어 둔다(새 기록이면 잠긴 것은 기본으로 바뀜)
  S('startRun')({ kit, stage, daily: false });
  S('closeMenu') && (() => { try { S('closeMenu')(); } catch (e) {} })();
  window.__bbAuto = true;
  if (opts.bag) { GS.bag = opts.bag.map(([id, x, y, rot]) => ({ ...S('newItem')(id, 1, null), x, y, rot })); S('fitBag')(); S('renderBag')(); }   // 맞춤 가방(락스텝 대조용)
  if (opts.autoSpc) S('OPT').autoSpc = true;
  if (opts.speed) S('playSpeed = ' + opts.speed);
  // 게임 모드는 animFps=20(48-input setMode) — 애니 칸은 1/animFps 마다(옛 하네스의 1/12 는 실험실 값이었다)
  const DT = 1 / 60, step = 1 / S('animFps');
  const out = { samples: [], events: [] };
  let t = 0;
  const snap = () => ({ t: +t.toFixed(3), state: GS.state, ci: GS.ci, wave: GS.wave, hp: +GS.hp.toFixed(2), score: GS.score, kills: GS.kills,
    foes: GS.ents.filter(a => a.e && !a.dead).length, heroX: +GS.hero.d.x.toFixed(2), combo: GS.combo, sp: +(GS.sp || 0).toFixed(2) });
  const byCar = [];   // 칸마다 누적(받은 피해 · 준 피해 · 처치 · 머문 시간)
  if (lockstep) out.lock = [];
  for (let i = 0; i < seconds * 60; i++) {
    window.__bbFrame = i;
    // 직접 조작 대본(락스텝 대조용 — Swift 테스트가 같은 규칙으로 같은 프레임에 같은 의도를 넣는다)
    if (opts.script && GS.on && GS.hero && !GS.hero.dead) {
      const H = GS.hero, F = GS.ents.filter(a => a.e && !a.dead).sort((a, b) => Math.abs(a.d.x - H.d.x) - Math.abs(b.d.x - H.d.x));
      if (i % 37 === 0 && F.length) S('manual')(F[0].d.x >= H.d.x ? 1 : -1);
      if (i % 211 === 0) S('heroDuck')(true);
      if (i % 97 === 0) S('trySpecial')();
      if (i % 53 === 0) { const A = F.find(a => a.action && !a.action.fired && S('FOE_W')[a.anim] && Math.abs(a.d.x - H.d.x) < 46); if (A) S('manual')(A.d.x >= H.d.x ? 1 : -1); }
    }
    if (fine && i >= fine[0] && i <= fine[1]) { const H = GS.hero; out.fine = out.fine || [];
      out.fine.push([i, +GS.time.toFixed(4), +GS.slowT.toFixed(4), +(GS.spcTime || 1).toFixed(4), +S('acc').toFixed(4), S('freeze'), H.anim, H.pose, H.si, H.hold, H.hs || 0, +H.d.x.toFixed(3), +(GS.sp || 0).toFixed(2), GS.score,
        GS.ents.filter(a => a.e && !a.dead).map(a => [a.e.t, +a.d.x.toFixed(3), a.anim, a.pose, a.si, a.hold, a.hs || 0, +a.e.hp.toFixed(1), +a.e.cdT.toFixed(3), +a.e.stun.toFixed(3), a.jug ? +a.jug.h.toFixed(2) : null, +a.kb.toFixed(2)].join(',')).join(' | ')]); }
    if (lockstep && i % 30 === 0) out.lock.push([i, GS.state, GS.ci, +GS.time.toFixed(3), +GS.hp.toFixed(2), GS.score, GS.kills, +GS.hero.d.x.toFixed(2), GS.hero.anim, GS.combo,
      GS.ents.filter(a => a.e && !a.dead).map(a => a.e.t + '@' + a.d.x.toFixed(1) + ':' + a.anim + ':' + Math.round(a.e.hp)).join(' '), +S('TR').ex.toFixed(1)]);
    { const c = byCar[GS.ci] || (byCar[GS.ci] = { taken: 0, dealt: 0, kills: 0, t: 0, t0: GS.stats.taken, d0: GS.stats.dealt, k0: GS.kills });
      c.taken = Math.round(GS.stats.taken - c.t0); c.dealt = Math.round(GS.stats.dealt - c.d0); c.kills = GS.kills - c.k0; c.t = +(c.t + 1 / 60).toFixed(3); }
    // 웹 loop() 와 같은 순서(렌더 · UI 제외): 속도 · 슬로 · 애니 칸 · 게임 갱신
    const sp = S('playSpeed');
    if (GS.on && GS.slowT > 0) GS.slowT -= DT;
    if (GS.tapW) { GS.tapW.t += DT; if (GS.tapW.t > 1.5) S('tapFire')(false); }
    if (GS.on) S('spcCamTick')(DT);                       // 필살기 시간 배율(spcTime) — 규칙에 영향
    S('camTick')(DT);                                     // 세로 화면 카메라(CAMX) — 필살기는 화면 안 적만 친다
    const dt = DT * sp * ((GS.on && GS.slowT > 0) ? .28 : 1) * (GS.on ? (GS.spcTime || 1) : 1);
    S('gameTime += ' + dt); S('acc += ' + dt);
    let n = 0; while (S('acc') >= step && n < 8) { S('acc -= ' + step); n++; if (!S('paused')) S('stepAnim')(); }
    if (!S('paused')) S('gameUpdate')(dt);
    if (S('acc') > step) S('acc = 0');
    // 컷인(두목 등장 VS · 분노 · 필살기)은 웹에선 그리기(drawCut0)가 시간을 민다 — 렌더가 없으니 여기서 같은 규칙으로 민다
    { const C = GS.cut; if (C && C.k !== 'story') { C.t += Math.min(.1, DT) * sp; if (C.t >= C.dur) { GS.cut = null; if (C.k === 'spc') S('spcBegin')(C.kind); } } }
    t += DT;
    // 진행을 막는 화면(매점 · 정리 · 환승 카드)은 웹 테스트와 같이 바로 넘긴다
    if (GS.state === 'shop') { out.events.push({ t: +t.toFixed(2), ci: GS.ci, shop: (GS.shopList || []).map(o => o.id) }); }
    if (GS.state === 'shop') { const b = document.querySelector('#gOverlay .lc') || document.querySelector('#gOverlay .skip'); if (b) b.click(); }
    if (GS.state === 'arrange') { const b = document.querySelector('#sbArrange button'); if (b) b.dispatchEvent(new PointerEvent('pointerup', { bubbles: true })); }
    if (trace && i % 30 === 0) out.samples.push(snap());
    if (GS.state === 'over' || GS.state === 'end') break;
  }
  const st = GS.stats || {};
  out.result = { t: +t.toFixed(3), state: GS.state, stageIdx: GS.stageIdx, ci: GS.ci, hp: +GS.hp.toFixed(2), max: GS.max, score: GS.score, kills: GS.kills,
    dealt: Math.round(st.dealt || 0), taken: Math.round(st.taken || 0), crits: st.crits || 0, maxCombo: st.maxCombo || 0, links: st.links || 0, justs: st.justs || 0,
    tokens: GS.tokens, combos: st.combos || 0, outs: st.outs || 0, walls: st.walls || 0, bowls: st.bowls || 0, stag: st.stag || 0, flanks: st.flanks || 0,
    dodges: st.dodges || 0, onTime: st.onTime || 0, late: st.late || 0, sigs: st.sigs || 0, throws: st.throws || 0, chits: st.chits || 0, rk: st.rk || {}, snd: st.snd || [0, 0, 0],
    byCar: byCar.map(c => c && { taken: c.taken, dealt: c.dealt, kills: c.kills, t: c.t }),
    sp: +(GS.sp || 0).toFixed(1), bag: GS.bag.map(b => b.id).join(','), stash: GS.stash.map(b => b.id).join(',') };
  out.result.shops = out.events.filter(e => e.shop).map(e => e.shop.join('/'));
  if (lockstep) out.rt = window.__bbRT;
  return out;
}

if (import.meta.url === `file://${process.argv[1]}`) {
  if (process.argv.includes('--check')) {
    const a = await runSeed(12345, { seconds: 40, trace: true }), b = await runSeed(12345, { seconds: 40, trace: true });
    const same = JSON.stringify(a) === JSON.stringify(b);
    console.log(`[simtrace] 결정성 ${same ? '같음' : '다름!'} · 40초 결과`, a.result);
    if (!same) { for (let i = 0; i < a.samples.length; i++) if (JSON.stringify(a.samples[i]) !== JSON.stringify(b.samples[i])) { console.log('첫 차이', a.samples[i], b.samples[i]); break; } }
    process.exit(same ? 0 : 1);
  }
  if (process.argv.includes('--fine')) {   // 한 판 세밀 기록: --fine seed kit seconds from to → 스크래치 파일(--fine-out)
    const i = process.argv.indexOf('--fine'), [seed, kit, sec, from, to] = process.argv.slice(i + 1, i + 6);
    const r = await runSeed(+seed, { seconds: +sec, kit, lockstep: true, fine: [+from, +to] });
    fs.writeFileSync(arg('--fine-out', 'fine.json'), JSON.stringify({ seed: +seed, kit, seconds: +sec, from: +from, to: +to, fine: r.fine, rt: r.rt }) + '\n');
    console.log('[simtrace] fine 기록', (r.fine || []).length); process.exit(0);
  }
  if (process.argv.includes('--lockstep')) {   // 락스텝 기준: 씨앗 몇 개 × 짧게 — 규칙 난수 자리 순서 + 30프레임마다 상태
    const runs = [];
    const LIST = [[7001, 'basic', 120, 0], [7002, 'basic', 120, 0], [7003, 'foot', 120, 0], [7004, 'link', 90, 0],
      [7005, 'basic', 480, 0], [7006, 'grap', 300, 0], [7007, 'crit', 300, 0], [7008, 'guard', 300, 0], [7009, 'basic', 360, 2],
      [7010, 'foot', 300, 1], [7011, 'basic', 300, 3], [7012, 'basic', 300, 4], [7013, 'link', 300, 0], [7014, 'foot', 480, 0],
      [7015, 'basic', 300, 0, { autoSpc: true }], [7016, 'grap', 300, 0, { autoSpc: true, speed: 1.25 }], [7017, 'basic', 300, 0, { script: true }],
      [7018, 'guard', 300, 0, { script: true, autoSpc: true }], [7019, 'foot', 300, 2, { script: true, speed: 1.25 }], [7020, 'crit', 300, 0, { script: true }]];
    const BAGS = {
      A: [['upper', 0, 0, 0], ['punch', 1, 0, 0], ['round', 2, 0, 0], ['watch', 0, 3, 0], ['cuff', 1, 2, 0], ['bandage', 5, 3, 0]],
      B: [['renkan', 0, 0, 0], ['axe', 2, 0, 0], ['cycle', 3, 2, 0], ['upper', 5, 0, 0], ['metro', 2, 3, 0]],
      C: [['sweep', 0, 0, 0], ['stomp', 0, 1, 0], ['kick', 1, 1, 0], ['upper', 3, 0, 0], ['punch', 4, 0, 0], ['duck', 5, 0, 0]],
      D: [['knee', 0, 0, 0], ['punch', 1, 0, 0], ['suplex', 2, 0, 0], ['elbow', 4, 0, 0], ['tetsu', 0, 2, 0], ['gum', 3, 2, 0]],
      E: [['umb', 0, 0, 0], ['punch', 2, 0, 0], ['charge', 3, 0, 0], ['skick', 1, 1, 0], ['paper', 0, 2, 0], ['fkick', 2, 3, 0], ['earph', 5, 0, 0]],
      F: [['knee', 0, 0, 0], ['paper', 1, 0, 0], ['case', 2, 0, 0], ['throw', 0, 2, 0], ['bfist', 4, 0, 0], ['bkick', 3, 3, 0], ['shoes', 4, 2, 0]],
    };
    LIST.push([7021, 'basic', 300, 0, { bag: BAGS.A }], [7022, 'basic', 300, 0, { bag: BAGS.B, script: true }], [7023, 'basic', 300, 0, { bag: BAGS.C, autoSpc: true }],
      [7024, 'basic', 300, 0, { bag: BAGS.D }], [7025, 'basic', 300, 1, { bag: BAGS.E, script: true }], [7026, 'basic', 300, 3, { bag: BAGS.F, autoSpc: true }],
      [7027, 'basic', 360, 4, { bag: BAGS.A, script: true, autoSpc: true, speed: 1.25 }], [7028, 'basic', 300, 2, { bag: BAGS.D, script: true }]);
    for (const [seed, kit, sec, stage, opts = {}] of LIST) {
      const r = await runSeed(seed, { seconds: sec, kit, stage, lockstep: true, opts });
      runs.push({ seed, kit, stage, seconds: sec, opts, result: r.result, lock: r.lock, rt: r.rt });
      process.stdout.write(`\r[simtrace] 락스텝 ${runs.length}`);
    }
    const LOUT = path.join(ROOT, 'native', 'Tests', 'Fixtures', 'sim', 'lockstep.json');
    fs.writeFileSync(LOUT, JSON.stringify({ _about: 'simtrace.mjs --lockstep — 규칙 자리만 시드 수열(RULE_SITES)', runs }) + '\n');
    console.log(`\n[simtrace] → ${path.relative(ROOT, LOUT)}`); process.exit(0);
  }
  const results = [];
  for (let s = 1; s <= RUNS; s++) { const r = await runSeed(SEED0 + s); results.push({ seed: SEED0 + s, ...r.result }); process.stdout.write(`\r[simtrace] ${s}/${RUNS}`); }
  fs.mkdirSync(path.dirname(OUT), { recursive: true });
  fs.writeFileSync(OUT, JSON.stringify({ _about: 'tools/js/extract/simtrace.mjs — 시드 고정 웹 자동 전투 결과(통계 기준선)', seconds: SECONDS, stage: STAGE, kit: KIT, results }, null, 1) + '\n');
  console.log(`\n[simtrace] ${RUNS}판 → ${path.relative(ROOT, OUT)}`);
}
