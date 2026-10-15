#!/usr/bin/env node
// K 기준선: 프롤로그(지하 복도 → 거리 → 케인 → 첫 칸) · 무도장(콤보 시연 · 기술 · 반응 · 적 공격 · 필살기) · 오늘의 노선(지하철)을
// simtrace.mjs · modetrace.mjs 와 같은 방식(시드 고정 · 고정 스텝 · 렌더 없음 · 규칙 자리 RULE_SITES)으로 돌린다.
// 웹은 navigator.webdriver 면 프롤로그를 건너뛴다 → 하네스가 startRun 뒤 startPrologue 를 직접 부른다.
// 프롤로그 · 케인 장면은 setTimeout(서류 흩어짐 0.86초 · 첫 소개 0.4초 …)이 규칙에 닿는다 → 여기서는 setTimeout 을 '시뮬레이션 실제 시간' 예약으로 바꾼다
// (Swift World.schedule 과 같은 규칙: 프레임 시작에 시계를 1/60 올리고, 프레임 끝에 때가 된 것을 넣은 순서대로).
//
//   node tools/js/extract/storytrace.mjs --lockstep   → native/Tests/Fixtures/sim/story_lockstep.json (StoryLockstepTests)
//   node tools/js/extract/storytrace.mjs --fx         → native/Tests/Fixtures/sim/story_fx.json (StoryFixtureTests: TALK 대본 · 대화 흐름 · 도움말 미루기 · lampTick · doorTick)
import fs from 'node:fs';
import path from 'node:path';
import { openGame, ROOT } from './page.mjs';
import { ruleLineMap } from './simtrace.mjs';

const FIX = path.join(ROOT, 'native', 'Tests', 'Fixtures', 'sim');

export async function runStory(seed, cfg) {
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
    }, [true, ruleLineMap()]);
    await p.reload();
    await p.waitForFunction(() => typeof window.__BB_SCOPE__ === 'function');
    return await p.evaluate(simulateStory, cfg);
  } finally { await g.close(); }
}

function simulateStory({ kind, seconds, kit = 'basic', speed = 1.25, script = false, cmds = [], fine = null }) {
  const S = __BB_SCOPE__, GS = S('GS');
  // setTimeout → 시뮬레이션 실제 시간 예약(Swift World.schedule 과 같은 규칙)
  let rt = 0, tid = 1; const Q = [];
  window.setTimeout = (fn, ms) => { if (typeof fn !== 'function') return 0; const id = tid++; Q.push({ id, at: rt + (+ms || 0) / 1000, fn }); return id; };
  window.clearTimeout = id => { const k = Q.findIndex(q => q.id === id); if (k >= 0) Q.splice(k, 1); };
  window.__bbReseed();
  S('setMode')('game');
  { const M = S('META'); M.kits[kit] = 1; }
  try { S('closeMenu')(); } catch (e) {}
  S('RUNCFG = {...RUNCFG, kit: ' + JSON.stringify(kit) + ', stage: 0, daily: ' + (kind === 'daily') + '}');
  if (kind === 'prologue') { S('startRun')({ kit, stage: 0, daily: false }); S('startPrologue')(); }
  else if (kind === 'daily') S('startRun')({ kit, stage: 0, daily: true });
  else if (kind === 'dojo') S('startDojo')();
  window.__bbAuto = true;
  S('playSpeed = ' + speed);
  const DT = 1 / 60, step = 1 / S('animFps');
  const out = { lock: [], dateKey: S('todayKey')(), beats: [] };
  const DJC = { combo: k => S('dojoCombo')(k), hero: (id, c) => S('dojoHero')(id, c), misc: k => S('dojoMisc')(k), special: f => S('dojoSpc')(f), react: r => S('dojoReact')(r),
    foe: mv => S('dojoFoe')(mv), customRun: () => S('dojoCustomRun')(), dummy: t => S('dojoSetDummy')(t), demoBag: k => S('dojoDemoBag')(k), bagRoute: k => S('dojoBagRoute')(k), reset: () => S('dojoReset')(24) };
  const extra = () => {
    const P = GS.prologue, C = GS.cine, K = GS.kane, W = GS.tapW, Sq = GS.dojoSeq;
    if (P) return `P:${P.x.toFixed(1)}:${P.wi}:${!!P.bag}:${!!P.out}:${Object.keys(P.doors || {}).map(k => k + P.doors[k].st).join(',')}:${W ? 'W' + W.t.toFixed(2) : '-'}:${GS.bag.map(b => b.id).join(',')}`;
    if (C) return `C:${C.stage}:${C.t.toFixed(3)}`;
    if (K) return `K:${K.ph}:${K.t.toFixed(3)}:${GS.bag.map(b => b.id).join(',')}`;
    if (GS.demo) { const D = GS.ents.find(a => a.e && a.dojo); return `D:${Sq ? Sq.i + '/' + Sq.steps.length + ':' + Sq.t.toFixed(3) : '-'}:${D ? D.d.x.toFixed(2) + ':' + D.anim + ':' + (D.jug ? D.jug.h.toFixed(2) : '-') : '-'}`; }
    return (+S('TR').ex.toFixed(1)) + ':' + GS.bag.map(b => b.id).join(',');
  };
  let ci = 0;
  for (let i = 0; i < seconds * 60; i++) {
    window.__bbFrame = i;
    while (ci < cmds.length && cmds[ci][0] === i) { const [, c, ...a] = cmds[ci]; DJC[c](...a); ci++; }
    if (script && GS.on && GS.hero && !GS.hero.dead) {
      const H = GS.hero, F = GS.ents.filter(a => a.e && !a.dead).sort((a, b) => Math.abs(a.d.x - H.d.x) - Math.abs(b.d.x - H.d.x));
      const tap = side => GS.tapW ? S('tapFire')(true) : GS.cine ? (GS.cine.t > .6 && S('endCine')()) : S('manual')(side);
      if (i % 37 === 0 && F.length) tap(F[0].d.x >= H.d.x ? 1 : -1);
      if (i % 211 === 0) { if (GS.tapW) S('tapFire')(true); else S('heroDuck')(true); }
      if (i % 97 === 0) S('trySpecial')();
      if (i % 53 === 0) { const A = F.find(a => a.action && !a.action.fired && S('FOE_W')[a.anim] && Math.abs(a.d.x - H.d.x) < 46); if (A) tap(A.d.x >= H.d.x ? 1 : -1); }
    }
    if (fine && i >= fine[0] && i <= fine[1]) { const H = GS.hero; (out.fine = out.fine || []).push([i, +H.d.x.toFixed(3), H.anim, H.pose, H.si, H.hold, +GS.time.toFixed(4), +S('acc').toFixed(4), +(H.dash || 0).toFixed(3), +(H.dashT || 0).toFixed(3), +(H.kb || 0).toFixed(3),
      GS.ents.filter(a => a.e).map(a => [a.e.t, +a.d.x.toFixed(3), a.anim, a.pose, +(a.kb || 0).toFixed(3), a.jug ? +a.jug.vx.toFixed(3) : null].join(',')).join(' | ')]); }
    if (i % 30 === 0) out.lock.push([i, GS.state, GS.ci, +GS.time.toFixed(3), +GS.hp.toFixed(2), GS.score, GS.kills, +GS.hero.d.x.toFixed(2), GS.hero.anim, GS.combo,
      GS.ents.filter(a => a.e && !a.dead).map(a => a.e.t + '@' + a.d.x.toFixed(1) + ':' + a.anim + ':' + Math.round(a.e.hp)).join(' '), extra()]);
    const sp = S('playSpeed');
    rt += DT;
    if (GS.on && GS.slowT > 0) GS.slowT -= DT;
    if (GS.tapW) { GS.tapW.t += DT; if (GS.tapW.t > 1.5) S('tapFire')(false); }
    if (GS.on) S('spcCamTick')(DT);
    S('camTick')(DT);
    const dt = DT * sp * ((GS.on && GS.slowT > 0) ? .28 : 1) * (GS.on ? (GS.spcTime || 1) : 1);
    S('gameTime += ' + dt); S('acc += ' + dt);
    let n = 0; while (S('acc') >= step && n < 8) { S('acc -= ' + step); n++; if (!S('paused')) S('stepAnim')(); }
    if (!S('paused')) S('gameUpdate')(dt);
    if (S('acc') > step) S('acc = 0');
    { const C = GS.cut; if (C && C.k !== 'story') { C.t += Math.min(.1, DT) * sp; if (C.t >= C.dur) { GS.cut = null; if (C.k === 'spc') S('spcBegin')(C.kind); } } }
    { const due = Q.filter(q => q.at <= rt); for (const q of due) Q.splice(Q.indexOf(q), 1); for (const q of due) { try { q.fn(); } catch (e) {} } }
    if (GS.state === 'shop') { const b = document.querySelector('#gOverlay .lc') || document.querySelector('#gOverlay .skip'); if (b) b.click(); }
    if (GS.state === 'arrange') { const b = document.querySelector('#sbArrange button'); if (b) b.dispatchEvent(new PointerEvent('pointerup', { bubbles: true })); }
    const beat = GS.cine ? 'cine' : GS.prologue ? 'corridor' : GS.kane ? 'kane' : GS.state;
    if (out.beats[out.beats.length - 1]?.[1] !== beat) out.beats.push([i, beat]);
    if (GS.state === 'over' || GS.state === 'end') break;
  }
  const st = GS.stats || {};
  out.result = { state: GS.state, ci: GS.ci, hp: +GS.hp.toFixed(2), score: GS.score, kills: GS.kills, dealt: Math.round(st.dealt || 0), taken: Math.round(st.taken || 0), bag: GS.bag.map(b => b.id).join(','), talks: Object.keys(S('META').talks || {}).join(','), hints: Object.keys(S('META').hints || {}).join(',') };
  out.rt = window.__bbRT;
  return out;
}

// 무도장 대본: (프레임, 명령, 인자…) — Swift 테스트가 같은 프레임에 같은 DojoCommand 를 넣는다
function dojoScript() {
  const C = []; let f = 30; const add = (...a) => { C.push([f, ...a]); f += 240; };
  for (let k = 0; k < 21; k++) add('combo', k);
  for (const [id, c] of [['punch', 0], ['punch', 3], ['kick'], ['round'], ['upper'], ['knee'], ['sweep'], ['charge'], ['throw'], ['stomp'], ['bkick'], ['bfist'], ['fkick'], ['skick'], ['cycle'], ['axe'], ['suplex'], ['tetsu'], ['renkan'], ['umb']]) add('hero', id, c ?? null);
  for (const r of ['rCross', 'launch', 'fall', 'rSpike', 'crumple']) add('react', r);
  for (const mv of ['jab', 'hook', 'bat', 'charge', 'round', 'fkick']) add('foe', mv);
  for (const m of ['duck', 'polespin', 'hm_down']) add('misc', m);
  add('special', 'fist'); add('special', 'foot'); add('special', 'grap');
  add('dummy', 'heavy'); add('combo', 2); add('combo', 14); add('dummy', 'brute'); add('combo', 4); add('customRun');
  add('demoBag', 1); add('bagRoute', 0); add('bagRoute', 1); add('reset');
  return { cmds: C, seconds: Math.ceil((f + 120) / 60) };
}

// ---- 함수 픽스처 ----
async function fixtures() {
  const g = await openGame({ run: true, viewport: { width: 390, height: 844 } });
  try {
    return await g.page.evaluate(() => {
      const S = __BB_SCOPE__, GS = S('GS'), out = {};
      S('setMode')('game');
      const TALK = S('TALK'), ser = L => L.map(l => l[0] === 'me' ? ['me', l[1].map(o => [o[0], o[1] || null, o[2] || null])] : [l[0], l[1]]);
      out.talk = {}; for (const k of Object.keys(TALK)) out.talk[k] = ser(k === 'book' ? TALK.book({ n: '하늘 난타' }) : TALK[k]());
      // 대화 흐름: talkTest(자동 점검에서도 대화) · 고르기 끼워 넣기 · 고른 값 · 줄 서기 · done 순서
      GS.talkTest = true; const R = Math.random; Math.random = () => .5;
      const lines = [['cond', '하나'], ['me', [['가', ['minnie', '가-답'], 'A'], ['나', null, 'B']]], ['saboo', '둘'], ['me', [['다', ['cond', '다-답']]]], ['cond', '셋']];
      const flow = [], log = [];
      const snap = tag => { const T = GS.talk; flow.push([tag, T ? T.i : -1, T ? T.lines.length : 0, T && T.choices ? T.choices.map(o => o[0]).join('|') : (T ? T.lines[T.i][0] + ':' + T.lines[T.i][1] : '-')]); };
      S('talk')(lines, p => log.push('done1:' + p)); snap('start');
      S('talk')([['cond', '줄 선 대화']], p => log.push('done2:' + p)); snap('queued');
      for (const a of ['next', 'pick0', 'next', 'next', 'pick0', 'next', 'next', 'next', 'next']) {
        if (a === 'next') { const T = GS.talk; if (T && !T.choices) { S('tkFinish')(); S('tkNext')(); } }
        else S('tkPick')(+a.slice(4));
        snap(a);
      }
      S('talk')(lines, p => log.push('done3:' + p)); S('tkNext')(); S('tkPick')(1); snap('pick1'); S('tkSkip')(); snap('skip');
      out.flow = { lines, actions: ['next', 'pick0', 'next', 'next', 'pick0', 'next', 'next', 'next', 'next'], flow, log };
      // talkOnce: 이미 한 열쇠 · 자동 점검(talkTest 끔) → done 만
      { const M = S('META'); M.talks = {}; const L2 = []; GS.talkTest = false; S('talkOnce')('x1', [['cond', 'a']], () => L2.push('skip')); GS.talkTest = true;
        S('talkOnce')('x2', [['cond', 'b']], () => L2.push('done')); S('tkSkip')(); S('talkOnce')('x2', [['cond', 'b']], () => L2.push('again')); out.once = L2; }
      Math.random = R; GS.talkTest = false; GS.talk = null; GS.talkQ = [];
      // 도움말 미루기: 거리 연출 · 보너스 · 보스의 가방 · 케인 장면 동안엔 false(기록 안 함)
      out.hint = [];
      for (const [k, set] of [['cine', () => { GS.cine = {}; }], ['bonus', () => { GS.bonus = {}; }], ['pBag', () => { GS.pBag = true; }], ['kane', () => { GS.kane = {}; }], ['none', () => {}]]) {
        const M = S('META'); M.hints = {}; GS.cine = null; GS.bonus = null; GS.pBag = false; GS.kane = null; set();
        const r1 = S('hint')('move'), had = !!M.hints.move, r2 = S('hint')('move'), r3 = S('hint')('nope');
        out.hint.push({ k, r1, had, r2, r3 }); GS.cine = null; GS.bonus = null; GS.pBag = false; GS.kane = null;
      }
      out.hints = S('HINTS');
      // lampTick(Math.random 0.5 고정 = 떨림 0): 진자 감쇠
      { Math.random = () => .5; S('startRun')({ stage: 0, daily: false }); S('startPrologue')(); const P = GS.prologue; P.lamps = { 60: { a: .3, v: 0 }, 260: { a: -.2, v: 1.5 } };
        const rows = []; for (let i = 0; i < 90; i++) { S('lampTick')(1 / 60); if (i % 10 === 9) rows.push([+P.lamps[60].a.toFixed(9), +P.lamps[60].v.toFixed(9), +P.lamps[260].a.toFixed(9), +P.lamps[260].v.toFixed(9)]); }
        S('lampKick')(100, 1.6); rows.push(Object.keys(P.lamps).sort((a, b) => a - b).map(k => [+k, +P.lamps[k].v.toFixed(9)]));
        out.lamp = rows; Math.random = R; }
      // doorTick(규칙 난수 0.5 고정): 두드림 → 쿵 → (보스의 가방 전이면) BAM 열림 · 열린 문 1.8초 뒤 닫힘
      out.door = [];
      for (const [px, bag, cam, rv] of [[0, false, 60, .3], [300, false, 0, .5], [700, true, 120, .3], [1100, false, 60, .3], [460, false, 160, .8]]) {
        Math.random = () => rv; S('startRun')({ stage: 0, daily: false }); S('startPrologue')(); const P = GS.prologue; P.x = px; P.bag = bag; P.bangT = .05; S('CAMX = ' + cam);
        const rows = [];
        for (let i = 0; i < 300; i++) { S('doorTick')(1 / 30); if (i % 15 === 0) rows.push([i, Object.keys(P.doors).sort((a, b) => a - b).map(k => `${k}:${P.doors[k].st}:${P.doors[k].n ?? '-'}:${P.doors[k].max ?? '-'}:${!!P.doors[k].burst}`).join(','), +P.bangT.toFixed(4), GS.ents.filter(a => a.e).map(a => a.e.t + '@' + a.d.x.toFixed(2) + ':' + a.d.flip + ':' + a.e.cdT.toFixed(2)).join(' ')]); }
        out.door.push({ px, bag, cam, rv, vw: S('VW'), rows }); Math.random = R;
      }
      // 스킨 미리보기(skinPvTick): 서기 → 걷기 → 몸짓 → 돌기 → 돌려차기 — 0.25초마다 주인공 자리 · 동작 · 돌기
      { Math.random = () => .5; S('startRun')({ stage: 0, daily: false }); S('skinPvOpen')(); const H = GS.hero, rows = [], DT = 1 / 60, st = 1 / S('animFps'); let acc = 0;
        for (let i = 0; i < 60 * 10; i++) { acc += DT; let n = 0; while (acc >= st && n < 8) { acc -= st; n++; S('stepAnim')(); } S('gameUpdate')(DT); if (acc > st) acc = 0;
          if (i % 15 === 14) rows.push([i, +H.d.x.toFixed(3), +H.d.y.toFixed(3), H.anim, H.d.flip, +(GS.skinPv.spin || 0).toFixed(4), GS.skinPv.ph, +(GS.camZ || 0).toFixed(3)]); }
        out.skinPv = { cx: GS.skinPv.cx, rows }; S('skinPvClose')(); Math.random = R; }
      return out;
    });
  } finally { await g.close(); }
}

if (import.meta.url === `file://${process.argv[1]}`) {
  if (process.argv.includes('--fx')) {
    const r = await fixtures();
    fs.writeFileSync(path.join(FIX, 'story_fx.json'), JSON.stringify({ _about: 'storytrace.mjs --fx — TALK 대본 · 대화 흐름 · 도움말 미루기 · lampTick · doorTick', ...r }) + '\n');
    console.log('[storytrace] fx', Object.keys(r.talk).length, r.flow.flow.length, r.hint.length, r.lamp.length, r.door.length); process.exit(0);
  }
  if (process.argv.includes('--fine')) {   // --fine seed kind kit seconds from to [script] → 스크래치 파일(--fine-out)
    const i = process.argv.indexOf('--fine'), [seed, kind, kit, sec, from, to, sc] = process.argv.slice(i + 1, i + 8);
    const D = dojoScript();
    const r = await runStory(+seed, { kind, kit, seconds: +sec, fine: [+from, +to], script: sc === 'script', cmds: kind === 'dojo' ? D.cmds : [] });
    const o = process.argv.includes('--fine-out') ? process.argv[process.argv.indexOf('--fine-out') + 1] : 'story_fine.json';
    fs.writeFileSync(o, JSON.stringify({ fine: r.fine, rt: r.rt }) + '\n'); console.log('[storytrace] fine', (r.fine || []).length, '→', o); process.exit(0);
  }
  if (process.argv.includes('--lockstep')) {
    const only = process.argv.includes('--only') ? process.argv[process.argv.indexOf('--only') + 1] : null;
    const D = dojoScript();
    const LIST = [
      [9101, { kind: 'prologue', seconds: 240, kit: 'basic' }],
      [9102, { kind: 'prologue', seconds: 240, kit: 'foot' }],
      [9103, { kind: 'prologue', seconds: 200, kit: 'grap', script: true }],
      [9104, { kind: 'prologue', seconds: 200, kit: 'link', speed: 1 }],
      [9201, { kind: 'dojo', seconds: D.seconds, cmds: D.cmds }],
      [9301, { kind: 'daily', seconds: 300, kit: 'basic', speed: 1 }],
      [9302, { kind: 'daily', seconds: 300, kit: 'basic', script: true }],
    ].filter(([, c]) => !only || c.kind === only);
    const runs = [];
    for (const [seed, cfg] of LIST) {
      const r = await runStory(seed, cfg);
      runs.push({ seed, ...cfg, dateKey: r.dateKey, result: r.result, beats: r.beats, lock: r.lock, rt: r.rt });
      process.stdout.write(`\r[storytrace] 락스텝 ${runs.length}/${LIST.length}`);
    }
    fs.writeFileSync(path.join(FIX, 'story_lockstep.json'), JSON.stringify({ _about: 'storytrace.mjs --lockstep — 프롤로그 · 무도장 · 오늘의 노선(규칙 자리만 시드 수열 · setTimeout 은 시뮬레이션 시간)', runs }) + '\n');
    console.log('\n[storytrace] → story_lockstep.json'); process.exit(0);
  }
  console.log('사용: --lockstep [--only prologue|dojo|daily] · --fx');
}
