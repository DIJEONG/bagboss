#!/usr/bin/env node
// 장면 구성 픽스처(N4 BBPresentation 대조용): 웹판을 실제로 돌려 장면을 만든 뒤 루프를 붙잡고,
// 장면 구성 함수(drawSubwayBack · subwayLights · subwayFX — 타워는 그 안에서 drawTowerBack · towerLights · towerFX)를
// 직접 불러 '그 함수가 읽는 입력'과 '출력'(quad 호출 목록 · 광원 목록 · fx 객체 · 숨은 상태 변경)을 기록한다.
//
//   native/Tests/Fixtures/scenes/<이름>.json
//     input   Swift SceneInput 과 같은 모양(그 함수들이 읽는 GS · TR · 타워 · 손잡이 · 쇼 조명 상태)
//     rng     이번 호출에서 Math.random 이 낸 값(시드 고정 mulberry32 수열 · 장면에 따라 앞머리 고정) — Swift 는 같은 수열을 주입받는다
//     fn      함수별 출력: quads([이름, x, y, flip, flash, depth, ox, remap, part]) · verts(배경 정점) · lights · composed(렌더 합성) · fx · after(바뀐 상태)
//     render  (e2e) 같은 입력으로 render() 전체를 한 번 돌려 G-버퍼 첫 그리기 정점 · 합성 · 후처리 유니폼을 기록(Math.random = 상수)
//
// 웹 게임이 결정적이지 않아 다시 찍으면 장면이 달라진다 → --check 없음. 바꾸려면 다시 찍고 커밋한다.
//   node tools/js/extract/scenes.mjs [이름 …]
import path from 'node:path';
import { openGame, ROOT, writeJson } from './page.mjs';

const OUT = path.join(ROOT, 'native', 'Tests', 'Fixtures', 'scenes');

// setup: 들어가기(개발 훅) · wait: 실제로 돌릴 시간(ms) · poke: 붙잡은 뒤 상태 손보기(닫힌 범위 eval) — 갈래를 골고루 지나게
const SNAPS = {
  // D 노선 1호차: 다리 구간(하늘 · 강 · 트러스 · 터널 입구 둘) — 입구가 화면 안에 보이게 위치를 옮긴다
  d0_bridge: { setup: `window.__dotlab.jumpTo({line:0,car:0})`, wait: 2500,
    poke: `TR.ex=GS.legStart+LINE[GS.leg].bridge.b0+120; TR.v=320; GS.on=true;` },
  d0_bridge_exit: { setup: `window.__dotlab.jumpTo({line:0,car:0})`, wait: 2500,
    poke: `TR.ex=GS.legStart+LINE[GS.leg].bridge.b0+LINE[GS.leg].bridge.len-60; TR.v=300; GS.press=.4;` },
  // 심야 칸(broken): 깜빡이는 형광등 · 짧은 정차역
  d1_night_station: { setup: `window.__dotlab.jumpTo({line:0,car:1})`, wait: 1500, poke: `TR.flickS=.7;` },
  // 브로드웨이 쇼 칸: 전구 줄 · 쇼 조명(스파크) · 정차 중
  d3_show: { setup: `window.__dotlab.jumpTo({line:0,car:3})`, wait: 3000, poke: `SHOW_LAMPS[1].sparkT=.05; SHOW_LAMPS[2].k=.1; SHOW_LAMPS[0].k=1.8;` },
  // 공사 칸: 빠른 터널(잔상 · 줄무늬) · 불꽃(난수) · 제동 불꽃 · 교행 열차
  d5_works_fast: { setup: `window.__dotlab.jumpTo({line:0,car:5})`, wait: 2500,
    poke: `TR.v=420; TR.ex+=3000; GS.brakeGlow=.6; GS.brakeSp=[{x:60,y:250,t:.05},{x:80,y:252,t:.2},{x:410,y:251,t:.3}]; GS.pt={t:.4}; GS.invF=2; GS.bits=GS.bits||[];` },
  d6_cab: { setup: `window.__dotlab.jumpTo({line:0,car:6})`, wait: 3000, poke: `GS.lightK=.6; GS.emitK=.8;` },
  // 4 노선(고가선): 기어단 칸
  l4_gang_el: { setup: `window.__dotlab.jumpTo({line:1,car:2})`, wait: 3000 },
  l4_fan_el: { setup: `window.__dotlab.jumpTo({line:1,car:1})`, wait: 3000, poke: `TR.v=200; TR.ex+=500;` },
  // 6 노선: 장보기 칸(등롱)
  l6_market: { setup: `window.__dotlab.jumpTo({line:2,car:1})`, wait: 3000 },
  // 7 노선(퀸스 네온 고가선)
  l7_flushing_q: { setup: `window.__dotlab.jumpTo({line:3,car:3})`, wait: 3000 },
  // L 노선: 클럽 칸(스트로브) · 정전 칸(1비트) · 폐차 칸
  lL_club: { setup: `window.__dotlab.jumpTo({line:4,car:1})`, wait: 3000 },
  lL_dark_onebit: { setup: `window.__dotlab.jumpTo({line:4,car:4})`, wait: 3000, poke: `GS.oneBit=true; TR.flickS=.5;` },
  lL_ruin: { setup: `window.__dotlab.jumpTo({line:4,car:5})`, wait: 3000, poke: `TR.v=300; TR.ex+=700;` },
  // 폐차 칸 불꽃이 튀는 프레임(확률 2.5%) — 난수 앞머리를 정해 갈래를 지나게 한다(sparks · GS.bits 로 새던 숨은 변경)
  lL_ruin_spark: { setup: `window.__dotlab.jumpTo({line:4,car:5})`, wait: 2500, poke: `GS.bits=GS.bits||[];`,
    rngPrefix: [0.01, 0.6, 0.37, 0.2, 0.9, 0.45, 0.05, 0.75, 0.3, 0.99, 0.5] },
  // 타워: 문 열린 층 · 블랙아웃 · 이동 중 · 불꽃 주방 · 스트로브 바 · 주차장 경보
  tw6_open: { setup: `(()=>{ const L=window.__dotlab; L.jumpTo('tower'); L.demoBag(1); L.towerGo(6); })()`, wait: 3000,
    poke: `GS.tower.lamps[1].hang=true; GS.tower.lamps[1].a=.3; GS.tower.dent=[200]; GS.invF=1;` },
  tw5_blackout: { setup: `(()=>{ const L=window.__dotlab; L.jumpTo('tower'); L.demoBag(1); L.towerGo(5); })()`, wait: 3000, poke: `GS.tower.dark=true; GS.tower.over=true;` },
  tw_moving: { setup: `(()=>{ const L=window.__dotlab; L.jumpTo('tower'); L.demoBag(1); L.towerGo(3); })()`, wait: 2500,
    poke: `GS.tower.phase='move'; GS.tower.pos=3.4*TWR.FH; GS.tower.door=0; GS.tower.panelT=.5; GS.tower.lamps[0].flick=.3;` },
  tw12_flame: { setup: `(()=>{ const L=window.__dotlab; L.jumpTo('tower'); L.demoBag(1); L.towerGo(12); })()`, wait: 3000,
    poke: `GS.tower.fires=[{x:200},{x:260},{x:320}]; GS.tower.shk=.3; GS.tower.wreck[12]=true; GS.tower.fly=[{x0:240,y0:150,x1:200,y1:120,t:.2,dur:.5,r0:2}];` },
  tw16_strobe: { setup: `(()=>{ const L=window.__dotlab; L.jumpTo('tower'); L.demoBag(1); L.towerGo(16); })()`, wait: 3000, poke: `GS.tower.fl=.4;` },
  tw1_park_alarm: { setup: `(()=>{ const L=window.__dotlab; L.jumpTo('tower'); L.demoBag(1); L.towerGo(1); })()`, wait: 3000,
    poke: `GS.tower.alarm=2; GS.props=[{k:'puddle',x:150,ice:true},{k:'puddle',x:300}];` },
};

// N5 남은 장면(native/Tests/Fixtures/scenes/modes/<이름>.json — SceneModeParityTests):
//   kind 'brawl'  render() 의 brawl 갈래(느와르 거리 nb0..3 · drawCineProps · drawBonusCar(3D 차 · 연기 입자) · 바닥 물건 · 앞 차 n_car ·
//                 noirLights + 보조광 · noirFX + 날씨) — 함수가 아니라 render() 안 줄이라 같은 줄을 여기서 불러 나눠 기록한다
//   kind 'sub'    drawSubwayBack · subwayLights · subwayFX 가 프롤로그 복도(GS.prologue) · 무도장(GS.demo && DJ.on) 갈래로 가는 장면 + drawCrossFront
const MODES = {
  // 보너스: 소개(멀쩡한 차 · 전조등 스폿) · 타격(흔들림 난수 · 경보 · 부품 분리 · dentN 지연) · 완파(기울기 · 불길 · 연기 입자 · 파편 · 차 주인)
  bonus_intro: { kind: 'brawl', setup: `window.__dotlab.jumpTo('bonus')`, wait: 1200 },
  bonus_hits: { kind: 'brawl', setup: `window.__dotlab.jumpTo('bonus')`, wait: 2600,
    poke: `GS.bonus.phase='go'; for(let i=0;i<5;i++) carHit(30); GS.items=[{kind:'gear',id:pickGear(),x:200,z:4,t:.3},{kind:'coin',x:150,z:0,t:1.1},{kind:'meat',x:262,z:6,t:.05}];` },
  bonus_wreck: { kind: 'brawl', setup: `window.__dotlab.jumpTo('bonus')`, wait: 2600,
    poke: `GS.bonus.phase='go'; for(let i=0;i<9;i++) carHit(60); for(let i=0;i<50;i++) bonusUpdate(1/60); GS.bonus.car.shake=.6; GS.bonus.car.flash=.02;` },
  bonus_alarm: { kind: 'brawl', setup: `window.__dotlab.jumpTo('bonus')`, wait: 2600, blink: true,
    poke: `GS.bonus.phase='go'; carHit(70); carHit(20); GS.bonus.car.shake=0; GS.bonus.car.flash=0;` },
  // 프롤로그 뒤 비 오는 거리(GS.cine): 카메라가 움직인다(charOX) · 던지는 장도리 · 꽂힌 장도리
  cine_run: { kind: 'brawl', setup: `(()=>{ window.__dotlab.jumpTo('corridor'); __BB_SCOPE__('startCine()'); })()`, wait: 1500 },
  cine_toss: { kind: 'brawl', setup: `(()=>{ window.__dotlab.jumpTo('corridor'); __BB_SCOPE__('startCine()'); })()`, wait: 1500,
    poke: `GS.cine.toss={t:.21,x0:GS.hero.d.x+10,y0:GS.hero.d.y-40}; GS.cam=330.6;` },
  cine_subway: { kind: 'brawl', setup: `(()=>{ window.__dotlab.jumpTo('corridor'); __BB_SCOPE__('startCine()'); })()`, wait: 1500,
    poke: `GS.cine.hammerIn=true; GS.cine.toss={t:1,x0:0,y0:0}; GS.cam=NBW-W; GS.hero.d.x=980;` },
  // 프롤로그 복도: 시작 · 문(두드림 떨림 난수 · 열림 · 철창) + 전등 처음 만들기(난수) · 끝 철문 열림(빛 · 화면 반전)
  corr_start: { kind: 'sub', setup: `window.__dotlab.jumpTo('corridor')`, wait: 1800 },
  corr_doors: { kind: 'sub', setup: `window.__dotlab.jumpTo('corridor')`, wait: 1500,
    poke: `const P=GS.prologue; P.x=517; P.lamps={}; P.doors={600:{st:'bang',t:1.05,n:2,max:4},840:{st:'open',t:.4},360:{st:'bang',t:.3,n:0,max:3}};` },
  corr_exit: { kind: 'sub', setup: `window.__dotlab.jumpTo('corridor')`, wait: 1500,
    poke: `const P=GS.prologue; P.x=CORR_LEN; P.out=true; P.outT=.62; GS.invF=2; for(const k in P.lamps) P.lamps[k].a=.21;` },
  // 무도장: 방(행인 · 현판 · 등롱 · 샌드백 흔들림 · 부서진 판자 · 목인 떨림) · 건널목 갈래 첫 프레임(xcReset 난수) · 전차 지나감 · 경보만
  dojo_room: { kind: 'sub', setup: `window.__dotlab.jumpTo('dojo')`, wait: 2500,
    poke: `DJ.bg='dojo'; DJ.mook=.3; DJ.drum=.2; DJ.brd=true; DJ.walkers=[{x:150,v:12,um:1,t:.7},{x:300,v:-10,um:0,t:1.2},{x:240,v:9,um:0,t:.1}]; DJ.sign.a=.1; DJ.bag.a=-.3; DJ.lamps[0].a=.2; DJ.lamps[1].a=-.12;` },
  dojo_fresh: { kind: 'sub', setup: `window.__dotlab.jumpTo('dojo')`, wait: 2000, poke: `DJ.bg='dojo'; DJ.xc=null;` },
  cross_tram: { kind: 'sub', setup: `window.__dotlab.jumpTo('dojo')`, wait: 2000,
    poke: `DJ.bg='cross'; xcReset(); const X=DJ.xc; X.tr={dir:1,x:250,v:280,warn:0,kind:'B',dist:37,pp:null}; X.bell=true; X.spk=.08; X.spkX=240;
      for(let k=0;k<6;k++){ X.leaves[k].h=6+k*3; X.leaves[k].rot=k*1.7; } X.fall=[{...xcLeaf(120,230), y:80, vy:20, sw:9},{...xcLeaf(300,240), y:150.6, vy:18, sw:12}];` },
  cross_warn: { kind: 'sub', setup: `window.__dotlab.jumpTo('dojo')`, wait: 2000,
    poke: `DJ.bg='cross'; xcReset(); const X=DJ.xc; X.tr={dir:-1,x:SB.W+520,v:270,warn:1.2,kind:'A',dist:0,pp:null}; X.bell=true;` },
};
const MODE_OUT = path.join(OUT, 'modes');

const want = process.argv.slice(2).filter(a => !a.startsWith('-'));
const names = want.length ? want : [...Object.keys(SNAPS), ...Object.keys(MODES)];

const g = await openGame({ run: true, viewport: { width: 390, height: 844 } });
try {
  const p = g.page;
  await p.waitForTimeout(1200);
  await p.click('#modeSeg button[data-m="game"]');
  await p.waitForTimeout(1200);
  let seed = 1234;
  for (const name of names) {
    const sc = SNAPS[name] || MODES[name];
    if (!sc) { console.error(`[scenes] 모르는 이름: ${name}`); process.exit(1); }
    // 붙잡은 루프 풀기 → 장면 준비 → 돌리기 → 다시 붙잡기
    await p.evaluate(() => { window.__bbHold = false; if (window.__bbHeld) { const cb = window.__bbHeld; window.__bbHeld = null; requestAnimationFrame(cb); } });
    await p.evaluate(sc.setup);
    await p.waitForTimeout(sc.wait);
    await p.evaluate(() => { window.__bbHold = true; });
    await p.waitForTimeout(200);
    seed += 7919;
    if (MODES[name]) {
      const fn = await p.evaluate(captureMode, { kind: sc.kind, poke: sc.poke || '', seed, mode: 'fn', blink: !!sc.blink });
      const render = await p.evaluate(captureMode, { kind: sc.kind, poke: '', seed, mode: 'render', blink: !!sc.blink });
      writeJson(path.join(MODE_OUT, `${name}.json`), { _about: 'tools/js/extract/scenes.mjs — N5 장면(brawl · 복도 · 무도장) 구성 입출력. 다시 찍으면 장면이 달라진다.', sourceSha16: g.sourceSha16, name, kind: sc.kind, ...fn, render });
      console.log(`[scenes] ${name}: ${fn.input.scene}/${fn.input.state} · 쿼드 ${fn.fn.quads.length}+${(fn.fn.mid || []).length}+${(fn.fn.front || []).length} · 3D ${(fn.fn.mesh || []).length / 10} · 광원 ${fn.fn.lights.length} · 난수 ${fn.rng.length}`);
      continue;
    }
    const fn = await p.evaluate(capture, { poke: sc.poke || '', seed, mode: 'fn', prefix: sc.rngPrefix || [] });
    // e2e: 같은 순간을 render() 전체로 — 상태가 위에서 바뀌었으니(invF · 눈 적응) 입력을 다시 읽는다
    const render = await p.evaluate(capture, { poke: '', seed, mode: 'render', prefix: [] });
    const out = { _about: 'tools/js/extract/scenes.mjs — 장면 구성 함수 입출력(BBPresentation 대조). 다시 찍으면 장면이 달라진다.', sourceSha16: g.sourceSha16, name, ...fn, render };
    writeJson(path.join(OUT, `${name}.json`), out);
    console.log(`[scenes] ${name}: ${fn.input.scene}/${fn.input.state} 칸 ${fn.carKey} · 쿼드 ${fn.fn.quads.length} · 광원 ${fn.fn.lights.length} · 난수 ${fn.rng.length} · e2e 쿼드 ${render.bgVerts.length / 54}`);
  }
  if (g.errors.length) console.warn('[scenes] 페이지 오류:', g.errors.slice(0, 3));
} finally { await g.close(); }

// ---- 페이지 안에서 도는 캡처 ----
function capture({ poke, seed, mode, prefix }) {
  const S = __BB_SCOPE__;
  if (poke) S(poke);
  const GS = S('GS'), TR = S('TR');
  const clone = v => JSON.parse(JSON.stringify(v, (k, x) => (typeof x === 'number' && !Number.isFinite(x)) ? null : x));
  // 난수: 시드 고정 mulberry32 (값 = uint32 / 2^32 → Swift Double 로 정확히 옮겨진다)
  let st = seed >>> 0; const rng = [];
  const mul = () => { st = (st + 0x6D2B79F5) | 0; let t = st; t = Math.imul(t ^ (t >>> 15), t | 1); t ^= t + Math.imul(t ^ (t >>> 7), t | 61); return ((t ^ (t >>> 14)) >>> 0) / 4294967296; };
  const r0 = Math.random, pn0 = performance.now;
  const NOW = pn0.call(performance);
  Math.random = mode === 'render' ? () => 0.375 : () => { const v = rng.length < prefix.length ? prefix[rng.length] : mul(); rng.push(v); return v; };
  performance.now = () => NOW;
  try {
    const input = readInput(S, GS, TR, NOW);
    if (mode === 'render') return renderCapture(S, input);
    const SPR = S('SPR'), time = S('gameTime');
    // quad 감싸기: placeAt 도 안에서 quad 를 부르므로 최종 쿼드만 기록된다(스프라이트 없는 호출은 웹도 건너뛴다)
    const quads = [], q0 = S('quad');
    window.__bbQ0 = q0;
    window.__bbQW = function (name, x, y, flip = 0, flash = 0) {
      if (SPR[name]) quads.push([name, x, y, flip, flash, S('drawDepth'), S('drawOX'), S('drawRemap'), S('drawPart')]);
      return q0(name, x, y, flip, flash);
    };
    const sparks = S('sparks'), sp0 = sparks.length, bits0 = GS.bits ? GS.bits.length : 0;
    S('qn=0; drawDepth=0; drawOX=0; quad = window.__bbQW');
    try { S('drawSubwayBack')(time); } finally { S('quad = window.__bbQ0'); }
    const qn = S('qn'), verts = Array.from(S('vdata').subarray(0, qn * 6 * S('FPV')));
    const nBack = rng.length;
    const lights = S('subwayLights')(time);
    const nLights = rng.length;
    // render() 의 광원 합성(18-render-loop.js 그대로 옮김): 장면 광원 7개 × lightK + 주인공 보조광 · 환경광 · 발광 배율
    const composed = (() => { const lk = GS.lightK ?? 1, out = lights.slice(0, 7).map(l => l.dirl ? { ...l, i: l.i * lk } : { ...l, i: l.i * lk });
      const Hh = GS.hero; if (Hh && !Hh.hidden && lk > .02) out.push({ x: Hh.d.x + (Hh.d.flip ? -10 : 10), y: Hh.d.y - 48, z: 30, r: 78, c: [.82, .88, 1], i: .6 * lk * (GS.oneBit ? .5 : 1) });
      const scene = S('scene'), DJ = S('DJ'), DJON = scene === 'subway' && GS.demo && DJ.on;
      const uAmbV = scene === 'subway' ? (DJON ? .82 : (GS.on && GS.tower) ? (GS.tower.dark ? .14 : .44) : .55) : 1;
      const amb = uAmbV * (scene === 'subway' && GS.on ? (GS.prologue ? 1.45 : GS.oneBit ? .08 : (.2 + .8 * (GS.lightK ?? 1))) : 1);
      const emitK = scene === 'subway' && GS.on ? (GS.emitK ?? 1) : 1;
      return { lights: clone(out), ambient: amb, emitK };
    })();
    const lightsC = clone(lights);
    const fx = clone(S('subwayFX')());
    const after = { invF: GS.invF ?? 0, adT: GS.adT ?? null, outS: GS.outS ?? null, darkA: GS.darkA ?? null, adA: GS.adA ?? null,
      sparks: clone(sparks.slice(sp0)), bits: GS.bits ? clone(GS.bits.slice(bits0)) : [] };
    const CC = S('CAR_CONCEPTS'), LINE = S('LINE');
    return { input, rng, rngSplit: [nBack, nLights], carKey: CC[LINE[GS.ci || 0].car].key,
      fn: { quads, verts, lights: lightsC, composed, fx, after } };
  } finally { Math.random = r0; performance.now = pn0; }

  function readInput(S, GS, TR, NOW) {
    const T = GS.tower, STAGES = S('STAGES'), STAGE = S('STAGE'), DJ = S('DJ'), STRAPS = S('STRAPS');
    const n = v => (typeof v === 'number' && Number.isFinite(v)) ? v : null;
    return {
      scene: S('scene'), state: GS.state,
      time: S('gameTime'), gsTime: GS.time,
      stage: STAGES.indexOf(STAGE), stageIdx: n(GS.stageIdx),
      ci: n(GS.ci), leg: n(GS.leg), legStart: n(GS.legStart), arriving: !!GS.arriving, nextStop: GS.nextStop ?? null,
      on: !!GS.on, prologue: !!GS.prologue, dojo: !!(GS.demo && DJ.on), oneBit: !!GS.oneBit,
      invF: n(GS.invF) ?? 0, press: n(GS.press) ?? 0, brakeGlow: n(GS.brakeGlow) ?? 0,
      brakeSp: GS.brakeSp ? GS.brakeSp.map(p => ({ x: p.x, y: p.y, t: p.t })) : null,
      props: (GS.props || []).map(p => ({ k: p.k, x: p.x, ice: !!p.ice })),
      cans: (GS.cans || []).map(c => ({ x: c.x, v: c.v })),
      shots: (GS.shots || []).map(s => ({ x: s.x, y: s.y, t: s.t, vx: s.vx, friendly: !!s.friendly })),
      items: (GS.items || []).map(it => ({ kind: it.kind, id: it.id ?? null, x: it.x, z: n(it.z) ?? 0, t: it.t })),
      passT: GS.pt ? GS.pt.t : null,
      lightK: n(GS.lightK), emitK: n(GS.emitK), hasBits: !!GS.bits,
      train: { ex: TR.ex, dy: n(TR.dy) ?? 0, v: TR.v, jolt: TR.jolt, door: TR.door, t: TR.t, a: TR.a, strap: TR.strap, flickS: n(TR.flickS) ?? 0, stopAt: n(TR.stopAt) ?? 0 },
      holders: GS.ents.filter(p => p.pass && !p.hidden && p.goal == null).map(p => ({ strapX: n(p.strapX), y: p.d.y, handDY: n(p.handDY) })),
      straps: Object.keys(STRAPS).map(k => ({ x: +k, a: n(STRAPS[k] && STRAPS[k].a) ?? 0 })),
      showLamps: S('SHOW_LAMPS').map(L => ({ x: L.x, k: L.k, sparkT: L.sparkT })),
      hero: GS.hero ? { x: GS.hero.d.x, y: GS.hero.d.y, flip: !!GS.hero.d.flip, hidden: !!GS.hero.hidden } : null,
      foes: S('foes')().map(a => ({ x: a.d.x, y: a.d.y, flip: !!a.d.flip, lamp: !!a.e.lamp, down: !!S('isDown')(a), jug: !!a.jug })),
      eye: { adT: n(GS.adT), outS: n(GS.outS), darkA: n(GS.darkA), adA: n(GS.adA), now: NOW / 1000, playSpeed: S('playSpeed') },
      winROff: !!(window.__dotlab && window.__dotlab.WINR_OFF),
      shake: S('SHK')(), impactInvert: S('IMPF') > 0,
      tower: T ? {
        pos: T.pos, floor: T.floor, phase: T.phase, door: T.door, shk: n(T.shk) ?? 0,
        wreck: Object.keys(T.wreck || {}).filter(k => T.wreck[k]).map(Number),
        alarm: n(T.alarm) ?? 0, fly: (T.fly || []).map(f => ({ t: f.t, dur: f.dur, x0: f.x0, x1: f.x1, y0: f.y0, y1: f.y1, r0: f.r0 })),
        sagV: n(T.sagV) ?? 0, limit: n(T.limit) ?? 0, over: !!T.over, panelT: n(T.panelT) ?? 0, kit: !!T.kit, dent: (T.dent || []).slice(),
        lamps: T.lamps.map(L => ({ a: L.a, hang: !!L.hang, flick: n(L.flick) ?? 0 })), dark: !!T.dark, fires: (T.fires || []).map(f => ({ x: f.x })), fl: n(T.fl) ?? 0,
      } : null,
    };
  }

  // render() 전체 한 번: G-버퍼 첫 스프라이트 그리기(= 배경) 정점 · 합성 · 후처리 유니폼
  function renderCapture(S, input) {
    const gl = S('gl'), progs = { sprite: S('sprProg'), comp: S('compProg'), post: S('postProg') };
    const uni = new Map(), orig = {}; let prog = null, firstSprite = null; const data = {};
    const hook = (nm, f) => { orig[nm] = gl[nm]; gl[nm] = function (...a) { const r = orig[nm].apply(gl, a); f(a, r); return r; }; };
    hook('getUniformLocation', ([, nm], r) => { if (r) r.__n = nm; });
    hook('useProgram', ([p]) => { prog = p; if (!uni.has(p)) uni.set(p, {}); });
    hook('bufferSubData', ([, off, src, so = 0, len]) => { if (prog === progs.sprite && !data.sprite) data.sprite = Array.from(src.subarray(so, so + (len ?? src.length - so))); });
    const setU = vals => a => { const loc = a[0]; if (!loc || !prog) return; uni.get(prog)[loc.__n || '?'] = vals(a); };
    for (const nm of ['uniform1f', 'uniform1i']) hook(nm, setU(a => [a[1]]));
    hook('uniform2f', setU(a => [a[1], a[2]])); hook('uniform3f', setU(a => [a[1], a[2], a[3]])); hook('uniform4f', setU(a => [a[1], a[2], a[3], a[4]]));
    for (const nm of ['uniform1fv', 'uniform4fv']) hook(nm, setU(a => Array.from(a[1])));
    hook('drawArrays', ([, first, count]) => { if (prog === progs.sprite && firstSprite == null) firstSprite = { first, count }; });
    for (const u of S('nodeU')) if (u.loc) u.loc.__n = `u${u.node.id}_${u.k}`;
    try { S('render')(performance.now()); } finally { for (const nm in orig) gl[nm] = orig[nm]; }
    const cu = uni.get(progs.comp) || {}, pu = uni.get(progs.post) || null;
    const pick = (o, ks) => Object.fromEntries(ks.filter(k => o && k in o).map(k => [k, o[k]]));
    return {
      input, random: 0.375,
      bgVerts: (data.sprite || []).slice(firstSprite.first * 9, (firstSprite.first + firstSprite.count) * 9),
      composite: pick(cu, ['uLN', 'uLP', 'uLC', 'uLD', 'uAmb', 'uEmitK']),
      post: pu && pick(pu, ['uExpo', 'uWinR', 'uWinY', 'uPress', 'uBloomK', 'uReflY', 'uGrade', 'uSat', 'uRain', 'uInv', 'uVig', 'uFog', 'uFogC', 'uVN', 'uVP', 'uVC', 'uVD']),
    };
  }
}

// ---- N5 장면 캡처(페이지 안) — brawl 갈래 · 복도 · 무도장 ----
function captureMode({ kind, poke, seed, mode, blink }) {
  const S = __BB_SCOPE__;
  if (poke) S(poke);
  const GS = S('GS'), TR = S('TR'), DJ = S('DJ');
  const clone = v => JSON.parse(JSON.stringify(v, (k, x) => (typeof x === 'number' && !Number.isFinite(x)) ? null : x));
  const n = v => (typeof v === 'number' && Number.isFinite(v)) ? v : null;
  let st = seed >>> 0; const rng = [];
  const mul = () => { st = (st + 0x6D2B79F5) | 0; let t = st; t = Math.imul(t ^ (t >>> 15), t | 1); t ^= t + Math.imul(t ^ (t >>> 7), t | 61); return ((t ^ (t >>> 14)) >>> 0) / 4294967296; };
  const r0 = Math.random, pn0 = performance.now;
  let NOW = pn0.call(performance);
  if (blink) { let k = Math.floor(NOW / 260); if (k % 2 === 0) k++; NOW = k * 260 + 5; }   // 보너스 비상등이 켜진 위상(floor(now/260) 홀수)
  Math.random = mode === 'render' ? () => 0.375 : () => { const v = mul(); rng.push(v); return v; };
  performance.now = () => NOW;
  const xcSer = X => X ? { tr: X.tr ? { dir: X.tr.dir, x: X.tr.x, warn: X.tr.warn, kind: X.tr.kind, dist: X.tr.dist } : null, bell: !!X.bell, spk: n(X.spk) ?? 0, spkX: n(X.spkX) ?? 0,
    nextT: n(X.nextT) ?? 0,
    leaves: X.leaves.map(L => ({ x: L.x, gy: L.gy, h: L.h, rot: L.rot, c: L.c, s: L.s, ph: L.ph })),
    fall: X.fall.map(F => ({ x: F.x, y: F.y, gy: F.gy, rot: F.rot, c: F.c, s: F.s, ph: F.ph })) } : null;
  try {
    const input = readModeInput();
    if (mode === 'render') return renderAll(input);
    const SPR = S('SPR'), time = S('gameTime');
    const quads = [], mid = [], front = []; let sink = quads;
    const q0 = S('quad'); window.__bbQ0 = q0;
    window.__bbQW = function (name, x, y, flip = 0, flash = 0) {
      if (SPR[name]) sink.push([name, x, y, flip, flash, S('drawDepth'), S('drawOX'), S('drawRemap'), S('drawPart')]);
      return q0(name, x, y, flip, flash);
    };
    S('qn=0; n3=0; drawDepth=0; drawOX=0; quad = window.__bbQW');
    try {
      if (kind === 'brawl') {
        const dyn = []; window.__bbDyn = dyn;
        // render(): brawl 배경(느와르 거리 4장)
        S(`(()=>{ const charOX=-Math.round(GS.cam); drawOX=charOX; for(let k=0;k<4;k++) if(k*NVW+charOX<W && (k+1)*NVW+charOX>0) quad('nb'+k,k*NVW,0); drawOX=0; drawOX=charOX; drawDepth=0; })()`);
        const nq = S('qn'), verts = Array.from(S('vdata').subarray(0, nq * 6 * S('FPV')));
        const nBack = rng.length;
        // render(): 그림자 뒤 brawl 소품 · 차 · 바닥 물건
        sink = mid;
        S(`(()=>{ const charOX=-Math.round(GS.cam), dyn=window.__bbDyn; drawOX=charOX; drawCineProps(dyn); drawBonusCar(dyn); drawOX=charOX; for(const it of GS.items){ const nm=it.kind==='gear'?null:'it_'+it.kind, y=NFLOOR+it.z-2-Math.round(Math.abs(Math.sin(it.t*4))*2);
          if(nm) placeAt(nm, Math.round(it.x), y, false, 0); else { const ic=GITEMS[it.id].icon; placeAt(SPR[ic]?ic:'it_gem', Math.round(it.x), y-4, false, 0); }
          if(it.kind==='gear') dyn.push({x:it.x+charOX+.5,y:y-6,z:8,r:30,c:[1,.85,.5],i:.8}); } })()`);
        const mesh = Array.from(S('v3').subarray(0, S('n3') * S('F3')));
        const nMid = rng.length;
        // render(): 맨 앞 주차된 차(시차 1.18)
        sink = front;
        S(`(()=>{ const charOX=-Math.round(GS.cam); drawOX=Math.round(charOX*1.18); for(const x of [380,1150,1720]) placeAt('n_car', x, NVH+2, x===1150, 0); drawOX=0; drawDepth=0; })()`);
        sink = quads;
        const charOX = -Math.round(GS.cam), raw = S('noirLights')(charOX, time);
        const composed = (() => {
          const L = raw.slice(0, 6).map(l => ({ ...l }));
          const who = [GS.hero, ...GS.ents.filter(a => a.e && !a.dead)];
          const H0 = who[0]; if (H0 && !H0.hidden) L.push({ x: H0.d.x + charOX + (H0.d.flip ? -8 : 8), y: H0.d.y - 46, z: 26, r: 72, c: [.78, .84, 1], i: .45 });
          const rest = who.slice(1).filter(c => c && !c.hidden); if (rest.length) { const mx = rest.reduce((a, c) => a + c.d.x, 0) / rest.length, my = rest.reduce((a, c) => a + c.d.y, 0) / rest.length;
            L.push({ x: mx + charOX, y: my - 50, z: 34, r: 150, c: [.7, .78, 1], i: .4 }); }
          L.push(...dyn);
          return { lights: clone(L), ambient: .45, emitK: 1 };
        })();
        const wx = GS.cine ? { rain: .9, fog: .22 } : GS.bonus ? { rain: .3, fog: .14 } : [{ rain: .55, fog: .18 }, { rain: .15, fog: .42 }, { rain: .95, fog: .22 }][GS.stage || 0];
        const fx = clone({ ...S('noirFX')(charOX, wx.rain), fog: wx.fog });
        const after = { invF: GS.invF ?? 0, dentN: GS.bonus && GS.bonus.car ? (GS.bonus.car.dentN ?? 0) : null };
        return { input, rng, rngSplit: [nBack, nMid], fn: { quads, verts, mid, mesh, front, dyn: clone(dyn), lights: clone(raw), composed, fx, after } };
      }
      // 복도 · 무도장: 지하철 장면 함수가 갈래를 고른다
      const P = GS.prologue, lampKeys = P && P.lamps ? new Set(Object.keys(P.lamps)) : new Set(), xc0 = DJ.xc;
      S('drawSubwayBack')(time);
      const nq = S('qn'), verts = Array.from(S('vdata').subarray(0, nq * 6 * S('FPV')));
      const nBack = rng.length;
      const lights = S('subwayLights')(time);
      const nLights = rng.length;
      const composed = (() => { const lk = GS.lightK ?? 1, out = lights.slice(0, 7).map(l => ({ ...l, i: l.i * lk }));
        const Hh = GS.hero; if (Hh && !Hh.hidden && lk > .02) out.push({ x: Hh.d.x + (Hh.d.flip ? -10 : 10), y: Hh.d.y - 48, z: 30, r: 78, c: [.82, .88, 1], i: .6 * lk * (GS.oneBit ? .5 : 1) });
        const scene = S('scene'), DJON = scene === 'subway' && GS.demo && DJ.on;
        const uAmbV = scene === 'subway' ? (DJON ? .82 : (GS.on && GS.tower) ? (GS.tower.dark ? .14 : .44) : .55) : 1;
        const amb = uAmbV * (scene === 'subway' && GS.on ? (GS.prologue ? 1.45 : GS.oneBit ? .08 : (.2 + .8 * (GS.lightK ?? 1))) : 1);
        return { lights: clone(out), ambient: amb, emitK: scene === 'subway' && GS.on ? (GS.emitK ?? 1) : 1 };
      })();
      const lightsC = clone(lights);
      const fx = clone(S('subwayFX')());
      sink = front; S('drawCrossFront')(); sink = quads;
      const P2 = GS.prologue;
      const newLamps = P2 && P2.lamps ? Object.keys(P2.lamps).filter(k => !lampKeys.has(k)).map(k => ({ wx: +k, a: P2.lamps[k].a })) : [];
      const after = { invF: GS.invF ?? 0, newLamps, xc: !xc0 && DJ.xc ? xcSer(DJ.xc) : null };
      return { input, rng, rngSplit: [nBack, nLights], fn: { quads, verts, mid, mesh: [], front, dyn: [], lights: lightsC, composed, fx, after } };
    } finally { S('quad = window.__bbQ0'); }
  } finally { Math.random = r0; performance.now = pn0; }

  function readModeInput() {
    const STAGES = S('STAGES'), STAGE = S('STAGE');
    const base = {
      scene: S('scene'), state: GS.state, time: S('gameTime'), gsTime: GS.time,
      stage: STAGES.indexOf(STAGE), stageIdx: n(GS.stageIdx), ci: n(GS.ci), leg: n(GS.leg), legStart: n(GS.legStart),
      arriving: !!GS.arriving, nextStop: GS.nextStop ?? null, on: !!GS.on, prologue: !!GS.prologue, dojo: !!(GS.demo && DJ.on), oneBit: !!GS.oneBit,
      invF: n(GS.invF) ?? 0, press: n(GS.press) ?? 0, brakeGlow: n(GS.brakeGlow) ?? 0, brakeSp: null,
      props: (GS.props || []).map(p => ({ k: p.k, x: p.x, ice: !!p.ice })), cans: [],
      shots: (GS.shots || []).map(s => ({ x: s.x, y: s.y, t: s.t, vx: s.vx, friendly: !!s.friendly })),
      items: (GS.items || []).map(it => ({ kind: it.kind, id: it.id ?? null, x: it.x, z: n(it.z) ?? 0, t: it.t })),
      passT: null, lightK: n(GS.lightK), emitK: n(GS.emitK), hasBits: !!GS.bits,
      train: { ex: TR.ex, dy: n(TR.dy) ?? 0, v: TR.v, jolt: TR.jolt, door: TR.door, t: TR.t, a: TR.a, strap: TR.strap, flickS: n(TR.flickS) ?? 0, stopAt: n(TR.stopAt) ?? 0 },
      holders: [], straps: [], showLamps: [],
      hero: GS.hero ? { x: GS.hero.d.x, y: GS.hero.d.y, flip: !!GS.hero.d.flip, hidden: !!GS.hero.hidden } : null,
      foes: [], eye: { adT: n(GS.adT), outS: n(GS.outS), darkA: n(GS.darkA), adA: n(GS.adA), now: NOW / 1000, playSpeed: S('playSpeed') },
      winROff: false, shake: S('SHK')(), impactInvert: S('IMPF') > 0, tower: null,
    };
    if (kind === 'brawl') {
      const C = GS.cine, BN = GS.bonus, who = [GS.hero, ...GS.ents.filter(a => a.e && !a.dead)];
      base.brawl = {
        cam: GS.cam, stage: n(GS.stage), perfNow: NOW,
        crowd: who.slice(1).filter(c => c && !c.hidden).map(c => ({ x: c.d.x, y: c.d.y })),
        cine: C ? { hammerIn: !!C.hammerIn, toss: C.toss ? { t: C.toss.t, x0: C.toss.x0, y0: C.toss.y0 } : null } : null,
        bonus: BN ? { alarm: !!BN.alarm, alarmOff: !!BN.alarmOff, fire: !!BN.fire,
          pfx: (BN.pfx || []).map(p => ({ k: p.k, x: p.x, y: p.y, t: p.t, life: p.life })),
          car: BN.car ? { x: BN.car.x, y: BN.car.y, stage: BN.car.stage, gone: Object.keys(BN.car.gone).filter(k => BN.car.gone[k]), tilt: BN.car.tilt || 0,
            shake: BN.car.shake || 0, flash: BN.car.flash || 0, dmgF: BN.car.dmgF || 0, dentN: BN.car.dentN || 0,
            debris: BN.car.debris.map(d => ({ key: d.key, x: d.x, y: d.y, z: d.z, th: d.th })) } : null } : null,
      };
    }
    const P = GS.prologue;
    if (P) base.corridor = { x: P.x, out: !!P.out, outT: n(P.outT) ?? 0,
      doors: Object.keys(P.doors || {}).map(k => ({ wxc: +k, st: P.doors[k].st, t: P.doors[k].t })),
      lamps: Object.keys(P.lamps || {}).map(k => ({ wx: +k, a: P.lamps[k].a })) };
    if (GS.demo && DJ.on) base.dojoRoom = { bg: DJ.bg ?? null, sign: DJ.sign ? DJ.sign.a : 0, lamps: DJ.lamps ? DJ.lamps.map(l => l.a) : [0, 0], bag: DJ.bag ? DJ.bag.a : 0,
      walkers: (DJ.walkers || []).map(w => ({ x: w.x, v: w.v, um: w.um, t: w.t })), mook: DJ.mook || 0, drum: DJ.drum || 0, brd: !!DJ.brd, rack: !!DJ.rack, xc: xcSer(DJ.xc) };
    return base;
  }

  // render() 전체 한 번: 스프라이트 그리기 구간 전부 · 3D 정점 · 스프라이트/합성/후처리 유니폼
  function renderAll(input) {
    const gl = S('gl'), progs = { sprite: S('sprProg'), comp: S('compProg'), post: S('postProg'), mesh: S('prog3') };
    const uni = new Map(), orig = {}; let prog = null; const draws = [], data = {};
    const hook = (nm, f) => { orig[nm] = gl[nm]; gl[nm] = function (...a) { const r = orig[nm].apply(gl, a); f(a, r); return r; }; };
    hook('getUniformLocation', ([, nm], r) => { if (r) r.__n = nm; });
    hook('useProgram', ([p]) => { prog = p; if (!uni.has(p)) uni.set(p, {}); });
    hook('bufferSubData', ([, off, src, so = 0, len]) => { const k = prog === progs.sprite ? 'sprite' : prog === progs.mesh ? 'mesh' : null;
      if (k && !data[k]) data[k] = Array.from(src.subarray(so, so + (len ?? src.length - so))); });
    const setU = vals => a => { const loc = a[0]; if (!loc || !prog) return; uni.get(prog)[loc.__n || '?'] = vals(a); };
    for (const nm of ['uniform1f', 'uniform1i']) hook(nm, setU(a => [a[1]]));
    hook('uniform2f', setU(a => [a[1], a[2]])); hook('uniform3f', setU(a => [a[1], a[2], a[3]])); hook('uniform4f', setU(a => [a[1], a[2], a[3], a[4]]));
    for (const nm of ['uniform1fv', 'uniform4fv']) hook(nm, setU(a => Array.from(a[1])));
    hook('drawArrays', ([, first, count]) => { if (prog === progs.sprite) draws.push({ first, count }); else if (prog === progs.mesh) draws.push({ mesh: true, first, count }); });
    for (const u of S('nodeU')) if (u.loc) u.loc.__n = `u${u.node.id}_${u.k}`;
    { const U0 = S('sprU'); for (const k in U0) if (U0[k] && typeof U0[k] === 'object') U0[k].__n = k; }
    try { S('render')(performance.now()); } finally { for (const nm in orig) gl[nm] = orig[nm]; }
    const su = uni.get(progs.sprite) || {}, cu = uni.get(progs.comp) || {}, pu = uni.get(progs.post) || null;
    const pick = (o, ks) => Object.fromEntries(ks.filter(k => o && k in o).map(k => [k, o[k]]));
    const sp = data.sprite || [];
    const sprite = draws.filter(d => !d.mesh).map(d => sp.slice(d.first * 9, (d.first + d.count) * 9));
    const md = draws.find(d => d.mesh);
    return {
      input, random: 0.375, sprite, mesh: md ? (data.mesh || []).slice(md.first * 10, (md.first + md.count) * 10) : [],
      spriteU: pick(su, ['uWin']),
      composite: pick(cu, ['uLN', 'uLP', 'uLC', 'uLD', 'uAmb', 'uEmitK']),
      post: pu && pick(pu, ['uExpo', 'uWinR', 'uWinY', 'uPress', 'uBloomK', 'uReflY', 'uGrade', 'uSat', 'uRain', 'uInv', 'uVig', 'uFog', 'uFogC', 'uVN', 'uVP', 'uVC', 'uVD']),
    };
  }
}
