#!/usr/bin/env node
// 동작 점검(에이전트 R): 무도장에서 모든 동작(주인공 기술 · 콤보 시연 · 기타 · 필살기 · 반응 · 적 공격 · 저스트/숙이기 · 다가가기)을
// 웹판으로 한 판에 이어 돌리며(storytrace 와 같은 락스텝 — 규칙 자리만 시드 수열) 틱마다 상태 · 연출 호출을 기록하고,
// 표본 틱의 장면(post) + HUD(#ui) 를 잘라 2배 최근접으로 합친 띠 그림을 남긴다.
// 네이티브 쪽(Swift `BB_AUDIT=1 swift test --filter ActionAuditTests`)이 같은 대본 · 같은 씨앗 · 같은 표본 틱으로 돌려 나란히 붙인다.
//
//   node tools/js/extract/audit.mjs [동작이름 …]     → tools/js/out/audit/web/<동작>.json · <동작>.png · plan.json
//   node tools/js/extract/audit.mjs --list           → 동작 목록만
//
// 실제 게임과 같게 매 틱 render() + drawUI() 를 부른다(그린 자세 lastP → 자동 착지 다리 · 컷인 시간은 drawCut0 가 민다).
// 그래서 네이티브는 SimConfig.trackDrawnPose = true(앱과 같은 값)로 맞춘다. performance.now 는 시뮬레이션 실제 시간으로 바꾼다(HUD dt · 만화 글자 0.5초 간격).
import fs from 'node:fs';
import path from 'node:path';
import { openGame, ROOT, GEN } from './page.mjs';
import { ruleLineMap } from './simtrace.mjs';

const OUT = path.join(ROOT, 'tools', 'js', 'out', 'audit', 'web');
const SEED = 9311;
// 잘라 낼 칸(장면 픽셀): 두 인물 가운데를 기준으로 폭 CW · 바닥 위 CH_UP · 아래 CH_DN
export const CROP = { w: 208, up: 112, dn: 12, scale: 2, perRow: 10 };

// ---- 동작 목록(웹 DOJO 표 + 점검용 추가) ----
export function actions() {
  const D = JSON.parse(fs.readFileSync(path.join(GEN, 'content', '42-dojo.json'), 'utf8')).DOJO;
  const A = [];
  const add = (name, cat, cmds, o = {}) => A.push({ name, cat, label: o.label || name, cmds, win: o.win || 240, dummy: o.dummy || 'punk', trig: o.trig || null });
  for (const [n, id, c] of D.hero) add(`hero_${id}${c != null ? '_' + c : ''}`, 'hero', [[0, 'reset'], [0, 'hero', id, c ?? null]], { label: n });
  add('hero_case', 'hero', [[0, 'reset'], [0, 'hero', 'case', null]], { label: '서류가방(휘두르기)' });
  D.combo.forEach(([n], k) => add(`combo_${String(k).padStart(2, '0')}`, 'combo', [[0, 'combo', k]], { label: n, win: 420 }));
  for (const [n, k] of D.misc) add(`misc_${k}`, 'misc', [[0, 'misc', k]], { label: n });
  for (const [n, k] of [['피하기(evade)', 'evade'], ['막기(parry)', 'parry'], ['몸짓 gx_jw', 'gx_jw'], ['앉아 쉬기', 'rest_sit'], ['기대 쉬기', 'rest_lean']])
    add(`misc_${k}`, 'misc', [[0, 'misc', k]], { label: n, win: k.startsWith('rest') ? 90 : 200 });
  for (const [n, r] of D.react) add(`react_${r}`, 'react', [[0, 'react', r]], { label: n, win: r === 'staggerX' ? 300 : 200 });
  for (const [n, r] of [['맞음(hit)', 'hit'], ['뒤에서 맞음(hitB)', 'hitB'], ['휘청(stagger)', 'stagger'], ['돌며 넘어짐(spinout)', 'spinout'], ['끌려옴(pulled)', 'pulled'],
    ['날아감(rBlast)', 'rBlast'], ['철산고에 맞음(rTetsu)', 'rTetsu'], ['죽음(death)', 'death'], ['무너져 죽음(crumpleD)', 'crumpleD'], ['저글 착지(jland)', 'jland']])
    add(`react_${r}`, 'react', [[0, 'react', r]], { label: n, win: r.endsWith('D') || r === 'death' ? 220 : 200 });
  for (const [n, mv] of D.foe) add(`foe_${mv}`, 'foe', [[0, 'foe', mv]], { label: '건달 ' + n });
  for (const [t, mv, n] of [['heavy', 'bat', '덩치 서류가방'], ['heavy', 'kick', '덩치 앞차기'], ['boss', 'bat', '두목 렌치'], ['boss', 'round', '두목 돌려차기'], ['boss', 'upper', '두목 어퍼'],
    ['boss4', 'fkick', '두목4 날아차기'], ['rusher', 'hbutt', '돌격대 박치기'], ['rusher', 'charge', '돌격대 돌진'], ['chef', 'bat', '요리사 프라이팬'], ['slasher', 'hook', '칼잡이 훅'],
    ['punkg', 'bat', '기타 펑크 기타'], ['thrower', 'throw', '투척꾼 던지기']])
    add(`foe_${t}_${mv}`, 'foe', [[0, 'foe', mv]], { label: n, dummy: t });
  add('just_jab', 'counter', [[0, 'foe', 'jab']], { label: '저스트 카운터(잽)', trig: 'just' });
  add('just_hook', 'counter', [[0, 'foe', 'hook']], { label: '저스트 카운터(훅)', trig: 'just' });
  add('manual_bat', 'counter', [[0, 'foe', 'bat']], { label: '무거운 공격에 수동 탭(몽둥이)', trig: 'just' });
  add('duck_round', 'counter', [[0, 'foe', 'round']], { label: '숙여 피하기(돌려차기)', trig: 'duck' });
  for (const [dx, n] of [[40, '가까움 40px'], [70, '중간 70px'], [140, '멀리 140px']])
    add(`approach_${dx}`, 'move', [[0, 'reset'], [0, 'dummyX', 250 + dx], [1, 'hero', 'kick', null]], { label: '다가가 앞차기 · ' + n });
  add('approach_far_jab', 'move', [[0, 'reset'], [0, 'dummyX', 400], [1, 'hero', 'punch', 0]], { label: '멀리 150px 다가가 잽' });
  // 필살기는 맨 끝: 컷인 끝(1.05초 = 정확히 63틱)이 부동소수 경계라 웹/네이티브가 한 틱 갈려 뒤 동작 전부의 애니 위상이 밀린다(하네스 현상)
  for (const [n, f] of D.spc) add(`spc_${f}`, 'special', [[0, 'special', f]], { label: n, win: 600 });
  return A;
}

// ---- 페이지 안: 준비 ----
function setup({ seed }) {
  const S = __BB_SCOPE__, GS = S('GS');
  let rt = 0, tid = 1; const Q = [];
  window.setTimeout = (fn, ms) => { if (typeof fn !== 'function') return 0; const id = tid++; Q.push({ id, at: rt + (+ms || 0) / 1000, fn }); return id; };
  window.clearTimeout = id => { const k = Q.findIndex(q => q.id === id); if (k >= 0) Q.splice(k, 1); };
  window.__bbReseed();
  S('setMode')('game');
  { const M = S('META'); M.kits.basic = 1; }
  try { S('closeMenu')(); } catch (e) {}
  S('RUNCFG = {...RUNCFG, kit: "basic", stage: 0, daily: false}');
  S('startDojo')();
  window.__bbAuto = true;
  S('playSpeed = 1');
  // 연출 호출 기록
  const log = []; window.__audLog = log;
  const sfx = S('sfx');
  for (const k of Object.keys(sfx)) { const o = sfx[k]; if (typeof o !== 'function') continue; sfx[k] = function (...a) { log.push(['sfx', k, ...a.slice(0, 3).map(v => typeof v === 'number' ? +v.toFixed(3) : v)]); return o.apply(this, a); }; }
  window.__bbVib = [];
  const seen = new WeakSet();
  const scan = () => {
    const out = [];
    const fresh = (arr, fn) => { if (!arr) return; for (const o of arr) if (o && typeof o === 'object' && !seen.has(o)) { seen.add(o); out.push(fn(o)); } };
    fresh(S('HITFX'), o => ['fx', o.k]);
    fresh(S('DPOPS'), o => ['pop', o.style, o.val, o.label || '']);
    fresh(S('COMIC'), o => o.k === 'sfx' ? ['comic', o.word] : ['bubble', o.k, o.text || '']);
    fresh(S('dusts'), () => ['dust']); fresh(S('sparks'), () => ['spark']); fresh(S('rings'), o => [o.burst ? 'burstRing' : 'ring']);
    fresh(GS.bits, () => ['bit']); fresh(GS.critFx, o => ['critFx', o.big ? 'big' : '']); fresh(GS.sw, o => ['sw', +(o.r1 || 0).toFixed(0)]);
    fresh(GS.cmdLog, o => ['cmd', o.name || '']);
    if (GS.smear && !seen.has(GS.smear)) { seen.add(GS.smear); out.push(['smear']); }
    if (GS.cut && !seen.has(GS.cut)) { seen.add(GS.cut); out.push(['cut', GS.cut.k, GS.cut.kind || '']); }
    while (window.__bbVib.length) out.push(['vib', JSON.stringify(window.__bbVib.shift())]);
    while (log.length) out.push(log.shift());
    return out;
  };
  scan();   // 시작 전 것은 버린다
  const DT = 1 / 60, step = 1 / S('animFps'), gl = S('gl');
  let frame = 0;
  const dummy = () => GS.ents.find(a => a.e && a.dojo);
  window.__aud = {
    get frame() { return frame; },
    cmd(c) {
      const [, k, ...a] = c, H = GS.hero;
      if (k === 'combo') S('dojoCombo')(a[0]); else if (k === 'hero') S('dojoHero')(a[0], a[1]); else if (k === 'misc') S('dojoMisc')(a[0]);
      else if (k === 'special') S('dojoSpc')(a[0]); else if (k === 'react') S('dojoReact')(a[0]); else if (k === 'foe') S('dojoFoe')(a[0]);
      else if (k === 'dummy') S('dojoSetDummy')(a[0]); else if (k === 'reset') S('dojoReset')(24);
      else if (k === 'dummyX') { const D = dummy(); D.d.x = a[0]; S('face')(D, H.d.x); }
      else throw new Error('모르는 명령 ' + k);
    },
    // 대본 방아쇠(틱 시작마다): just = 적 공격 큐 0.06초 전 탭 · duck = 0.2초 전 숙이기
    trig(kind, st) {
      if (st.done) return; const D = dummy(), H = GS.hero; if (!D || !D.action || D.action.fired) return;
      const tt = S('timeToCue')(D); if (tt == null) return;
      if (kind === 'just' && tt <= 0.06) { st.done = true; S('manual')(D.d.x >= H.d.x ? 1 : -1); }
      if (kind === 'duck' && tt <= 0.2) { st.done = true; S('heroDuck')(true); }
    },
    // 한 틱(웹 loop() 와 같은 순서 + 렌더 · HUD)
    tick() {
      window.__bbFrame = frame;
      rt += DT; window.__bbNowMs = rt * 1000;
      const sp = S('playSpeed');
      if (GS.on && GS.slowT > 0) GS.slowT -= DT;
      if (GS.tapW) { GS.tapW.t += DT; if (GS.tapW.t > 1.5) S('tapFire')(false); }
      if (GS.on) S('spcCamTick')(DT);
      S('camTick')(DT);
      const dt = DT * sp * ((GS.on && GS.slowT > 0) ? .28 : 1) * (GS.on ? (GS.spcTime || 1) : 1);
      S('gameTime += ' + dt); S('acc += ' + dt);
      let n = 0; while (S('acc') >= step && n < 8) { S('acc -= ' + step); n++; if (!S('paused')) S('stepAnim')(); }
      if (!S('paused')) S('gameUpdate')(dt);
      if (S('acc') > step) S('acc = 0');
      const ev = scan();
      S('render')(window.__bbNowMs); S('drawUI')();
      ev.push(...scan());
      { const due = Q.filter(q => q.at <= rt); for (const q of due) Q.splice(Q.indexOf(q), 1); for (const q of due) { try { q.fn(); } catch (e) {} } }
      frame++;
      return ev;
    },
    state() {
      const H = GS.hero, D = dummy(), r = v => v == null ? null : +(+v).toFixed(2);
      const A = a => a ? [a.anim, a.pose, a.si, r(a.d.x), r(a.d.y), a.d.flip ? 1 : 0, r(a.hs || 0), a.jug ? r(a.jug.h) : null, r(a.airOv || 0), a.action ? (a.action.fired ? 'F' : 'A') : '', a.wpn || (a.action && a.action.wpn) || ''] : null;
      return { H: A(H), D: A(D), dhp: D ? +D.e.hp.toFixed(2) : null, hp: +GS.hp.toFixed(2), freeze: S('freeze'), shakeAmp: +S('shakeAmp').toFixed(2), shk: S('SHK')(),
        zoomK: +(GS.zoomK || 0).toFixed(4), invF: GS.invF || 0, slowT: +Math.max(0, GS.slowT || 0).toFixed(3), spcTime: +(GS.spcTime || 1).toFixed(3), camX: +S('CAMX').toFixed(2),
        cut: GS.cut ? GS.cut.k : null, spc: !!GS.spc, seq: GS.dojoSeq ? GS.dojoSeq.i : null, canAct: S('canAct')(H) };
    },
    // 장면 post(W×H) 잘라 + #ui(VW·3) 얹어 2배 최근접 → 띠 캔버스 칸 k
    capture(strip, k, x0, y0, cw, ch, sc, perRow) {
      const W = S('W'), Hh = S('H'), VW = S('VW'), UIS = S('UIS'), camX = Math.max(0, Math.min(W - VW, S('CAMX')));
      gl.bindFramebuffer(gl.READ_FRAMEBUFFER, S('pFB')); gl.readBuffer(gl.COLOR_ATTACHMENT0);
      const px = new Uint8Array(cw * ch * 4);
      gl.readPixels(x0, Hh - y0 - ch, cw, ch, gl.RGBA, gl.UNSIGNED_BYTE, px);
      gl.bindFramebuffer(gl.READ_FRAMEBUFFER, null);
      const ui = document.getElementById('ui').getContext('2d');
      const ux0 = Math.round((x0 - camX) * UIS), uy0 = y0 * UIS, uw = cw * UIS, uh = ch * UIS;
      const U = ui.getImageData(ux0, uy0, uw, uh).data;
      const ow = cw * sc, oh = ch * sc, img = new ImageData(ow, oh), o = img.data;
      for (let y = 0; y < oh; y++) for (let x = 0; x < ow; x++) {
        const sx = Math.floor(x / sc), sy = Math.floor(y / sc), si = ((ch - 1 - sy) * cw + sx) * 4;
        const ux = Math.floor((x + .5) * UIS / sc), uy = Math.floor((y + .5) * UIS / sc), ui4 = (uy * uw + ux) * 4, a = U[ui4 + 3] / 255, d = (y * ow + x) * 4;
        for (let c = 0; c < 3; c++) o[d + c] = Math.round(px[si + c] * (1 - a) + U[ui4 + c] * a);
        o[d + 3] = 255;
      }
      strip.getContext('2d').putImageData(img, (k % perRow) * ow, Math.floor(k / perRow) * oh);
    },
  };
  return { W: S('W'), H: S('H'), VW: S('VW'), UIS: S('UIS'), animFps: S('animFps') };
}

// ---- 페이지 안: 동작 하나 ----
function runAction({ A, crop }) {
  const S = __BB_SCOPE__, GS = S('GS'), X = window.__aud;
  const t0 = X.frame, rows = [], evs = [], caps = new Map();
  if (GS.ents.find(a => a.e && a.dojo).e.t !== A.dummy) X.cmd([0, 'dummy', A.dummy]);
  GS.hp = GS.max = 9999;   // 무도장 필살기 시연(trySpecial → renderBag)이 체력을 heroMax(120)로 되돌려 적 공격 시연이 주인공을 죽인다 — 점검 대본은 매번 채운다(네이티브도 같게)
  const st = {};
  let ci = 0, cx = null, gy = null, cueH = null, cueF = null;
  const strip = document.createElement('canvas');
  const cw = crop.w, ch = crop.up + crop.dn, sc = crop.scale, per = crop.perRow;
  const maxCells = Math.ceil(A.win / 3) + 4;
  strip.width = cw * sc * per; strip.height = ch * sc * Math.ceil(maxCells / per);
  const shot = [];
  for (let i = 0; i < A.win; i++) {
    while (ci < A.cmds.length && A.cmds[ci][0] === i) { X.cmd(A.cmds[ci]); ci++; }
    if (A.trig) X.trig(A.trig, st);
    const before = X.state();
    const ev = X.tick();
    const s = X.state();
    if (cx == null) { cx = Math.round((s.H[3] + s.D[3]) / 2); gy = Math.round(s.H[4]); }
    if (cueH == null && s.dhp < before.dhp - 1e-6) cueH = i;
    if (cueF == null && s.hp < before.hp - 1e-6) cueF = i;
    rows.push([i, s.H, s.D, s.dhp, s.hp, s.freeze, s.shakeAmp, s.shk, s.zoomK, s.invF, s.slowT, s.spcTime, s.camX, s.cut, s.spc ? 1 : 0, s.seq, s.canAct ? 1 : 0]);
    if (ev.length) evs.push([i, ev]);
    const grid = i % 3 === 2, cue = (cueH === i || cueF === i);
    if (grid || cue) {
      const x0 = Math.max(0, Math.min(S('W') - cw, cx - (cw >> 1))), y0 = Math.max(0, Math.min(S('H') - ch, gy - crop.up));
      if (shot.length < maxCells) { X.capture(strip, shot.length, x0, y0, cw, ch, sc, per); shot.push(i); }
    }
  }
  // 끝(가라앉음): 주인공이 다시 움직일 수 있고 허수아비가 서 있고 시연 · 컷인 · 필살기가 없는 첫 틱 이후
  let calm = -1;
  for (let k = rows.length - 1; k >= 0; k--) { const r = rows[k];
    const quiet = r[16] && r[1][0] === 'idle' && r[2] && r[2][7] == null && ['idle', 'walk'].includes(r[2][0]) && r[13] == null && !r[14] && r[15] == null;
    if (!quiet) { calm = k + 1; break; } }
  return { t0, cx, gy, cueH, cueF, calm, rows, evs, shots: shot, png: strip.toDataURL('image/png') };
}

// ---- 실행 ----
if (import.meta.url === `file://${process.argv[1]}`) {
  const ALL = actions().slice(0, +(process.env.AUD_MAX || 1e9));
  if (process.argv.includes('--list')) { for (const a of ALL) console.log(a.cat.padEnd(8), a.name.padEnd(22), a.label, a.dummy !== 'punk' ? `[${a.dummy}]` : ''); process.exit(0); }
  const want = new Set(process.argv.slice(2).filter(a => !a.startsWith('-')));
  // 락스텝이라 앞 동작이 뒤에 영향 → 일부만 원해도 처음부터 돌리고 저장만 고른다
  fs.mkdirSync(OUT, { recursive: true });
  const g = await openGame({ run: true, viewport: { width: 390, height: 844 } });
  const p = g.page;
  try {
    await p.evaluate(s => { sessionStorage.setItem('bbSeed', String(s)); }, SEED);
    await p.addInitScript(([sites]) => {
      const s0 = +sessionStorage.getItem('bbSeed'); if (!s0) return;
      const mk = s => { let a = s | 0; return () => { a |= 0; a = a + 0x6D2B79F5 | 0; let t = Math.imul(a ^ a >>> 15, 1 | a); t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t; return ((t ^ t >>> 14) >>> 0) / 4294967296; }; };
      let rule = mk(s0), pres = mk(s0 ^ 0x5bd1e995);
      window.__bbRT = []; window.__bbFrame = 0;
      window.__bbReseed = () => { rule = mk(s0); pres = mk(s0 ^ 0x5bd1e995); window.__bbRT = []; };
      Math.random = () => {
        const ln = +((new Error().stack.split('\n')[2] || '').match(/:(\d+):\d+\)?$/) || [0, 0])[1];
        const fn = sites[ln];
        if (fn) { const v = rule(); if (window.__bbRT.length < 200000) window.__bbRT.push([window.__bbFrame, fn]); return v; }
        return pres();
      };
      window.__bbHold = true; localStorage.clear(); localStorage.setItem('dotlab-lang', 'ko');
      // HUD 시간 = 시뮬레이션 실제 시간 · 진동 기록(웹 buzz 는 pointer:coarse 일 때만 부른다)
      const pn = performance.now.bind(performance); window.__bbNowMs = null; performance.now = () => window.__bbNowMs ?? pn();
      try { Object.defineProperty(Navigator.prototype, 'vibrate', { configurable: true, value: function (pat) { (window.__bbVib = window.__bbVib || []).push(pat); return true; } }); } catch (e) {}
      const mm = window.matchMedia.bind(window);
      window.matchMedia = q => q === '(pointer:coarse)' ? { matches: true, media: q, addEventListener() {}, removeEventListener() {}, addListener() {}, removeListener() {} } : mm(q);
    }, [ruleLineMap()]);
    await p.reload();
    await p.waitForFunction(() => typeof window.__BB_SCOPE__ === 'function');
    const env = await p.evaluate(setup, { seed: SEED });
    console.log('[audit] 웹 준비', env);
    // 30틱 쉬고 시작(storytrace 와 같게)
    await p.evaluate(() => { for (let i = 0; i < 30; i++) window.__aud.tick(); });
    const plan = { _about: 'tools/js/extract/audit.mjs — 무도장 동작 점검 대본(네이티브 ActionAuditTests 가 같은 틱에 같은 명령)', seed: SEED, env, crop: CROP, warm: 30, actions: [] };
    for (const A of ALL) {
      const t = Date.now();
      const r = await p.evaluate(runAction, { A, crop: CROP });
      plan.actions.push({ ...A, t0: r.t0, cx: r.cx, gy: r.gy, shots: r.shots });
      if (!want.size || want.has(A.name)) {
        fs.writeFileSync(path.join(OUT, `${A.name}.png`), Buffer.from(r.png.split(',')[1], 'base64'));
        const { png, ...rest } = r;
        fs.writeFileSync(path.join(OUT, `${A.name}.json`), JSON.stringify({ action: A, ...rest }) + '\n');
      }
      process.stdout.write(`\r[audit] ${plan.actions.length}/${ALL.length} ${A.name.padEnd(22)} 큐 ${r.cueH ?? r.cueF ?? '-'} 끝 ${r.calm} (${Date.now() - t}ms)   `);
    }
    plan.rt = await p.evaluate(() => window.__bbRT.length);
    fs.writeFileSync(path.join(OUT, 'plan.json'), JSON.stringify(plan, null, 1) + '\n');
    console.log(`\n[audit] → ${path.relative(ROOT, OUT)} (${ALL.length} 동작)`);
    if (g.errors.length) console.warn('[audit] 페이지 오류', g.errors.slice(0, 5));
  } finally { await g.close(); }
}
