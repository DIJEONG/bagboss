#!/usr/bin/env node
// HUD 오버레이 캡처(N5 HUD 충실도 대조용): 웹판 지하철 판을 실제로 돌린 뒤 루프를 붙잡고, 장면(순간)마다 HUD 상태
// (DPOPS · HITFX · COMIC · GS.critFx · GS.cut · GS.wipe · GS.cmdLog · 연타 · 두목 …)를 정해 넣은 다음 drawUI() 를 한 번 불러
// `#ui` 캔버스(VW·3 × H·3) 픽셀을 getImageData 로 읽는다. 같은 순간의 '그리기 입력'(HUDState + HUDFrame JSON)을 함께 쓴다.
// Swift(BBPresentation HUDOverlay.build → BBRender OverlayRenderer)는 같은 입력으로 같은 픽셀을 내야 한다(Tests/BBRenderTests/HUDParityTests).
//
//   native/Tests/Fixtures/hud/<순간>.json          그리기 입력(state · frame)
//   native/Tests/Fixtures/hud/<순간>.rgba.deflate  웹 #ui 픽셀(곧은 RGBA, 위→아래 행, raw DEFLATE)
//   native/Tests/Fixtures/hud/art.json             컷인 원화 · 피해 숫자 글리프 비트맵(정확 일치 대조)
//   tools/js/out/hud/<순간>.png                    미리 보기
//
// 시간은 멈춘다: performance.now 를 고정하고 lastDT 를 같게 → drawDmg 의 dt = 0(나이 · 물리 그대로), Math.random = .5(흔들림 0).
// 앱과 같게 만화 글자(Impact · Arial Black)는 Anton 으로 묶는다(web/app/fonts.css 와 같은 대체).
//   node tools/js/extract/hud.mjs [순간 …]
import fs from 'node:fs';
import path from 'node:path';
import zlib from 'node:zlib';
import { openGame, ROOT } from './page.mjs';
import { encodePng } from './png.mjs';

const OUT = path.join(ROOT, 'native', 'Tests', 'Fixtures', 'hud');
const PREVIEW = path.join(ROOT, 'tools', 'js', 'out', 'hud');
const want = process.argv.slice(2).filter(a => !a.startsWith('-'));

// ---- 순간 정의(페이지 안에서 실행: S = __BB_SCOPE__, env = 이 판의 인물 위치) ----
// 각 함수는 HUD 상태를 꾸민다. 공통으로 비운 뒤 부른다.
const MOMENTS = {
  // 도트 글자만: 노선도 · 점수 · AUTO · 체력 칸 · 필살 게이지 · 피해 숫자(제 크기 · 정수 자리) · 라벨 · 연타 → 정확 일치 기대
  pixel: `(S, env) => { const G=S('GS'), D=S('DPOPS'), H=env.hero, F=env.foe;
    G.sp=60; G.combo=7; G.lastHit=G.time-.5; G.comboDmg=12345;
    const put=(x,y,val,style,stack,label,lc)=>{ const st=S('DSTYLE')[style], s=st.s, age=.5, rise=-10*(1-Math.exp(-age*12)), w=((style==='heal'?'+':'')+val).length*(5*s-1);
      D.push({ x:Math.round(x)+w/2, y:Math.round(y)+stack*(7*s+3)-rise, val, style, label, labelCol:lc, stack, age, vx:0, life:1.05 }); };
    put(F.x-10, F.y-80, 1234, 'hit', 0, null); put(F.x-10, F.y-80, 567, 'hit', 1, 'BACK ATTACK', '#7ad7ff'); put(F.x-30, F.y-90, 8888, 'crit', 2, 'CRITICAL', '#ff9a4a');
    put(H.x-6, H.y-70, 90, 'heal', 0, null); put(H.x+30, H.y-60, 45, 'hurt', 0, null); }`,
  // 연타 중: 숫자 쌓기 · 기술 줄 · 잔상 · 섬광 · 고리 · 별 터짐 · 물방울
  combo: `(S, env) => { const G=S('GS'), D=S('DPOPS'), X=S('HITFX'), F=env.foe, H=env.hero, f=F.x>=H.x?1:-1;
    G.combo=4; G.lastHit=G.time-.08; G.comboDmg=3120; G.sp=100;
    D.push({ x:F.x, y:F.y-58, val:812, style:'hit', label:null, stack:0, age:.32, vx:-3.1, life:1.05 });
    D.push({ x:F.x, y:F.y-58, val:1040, style:'hit', label:'COUNTER', labelCol:'#ffe27a', stack:1, age:.18, vx:4.2, life:1.05 });
    D.push({ x:F.x, y:F.y-58, val:1268, style:'crit', label:'CRITICAL', labelCol:'#ff9a4a', stack:2, age:.07, vx:1.5, life:1.35 });
    const now=performance.now()/1000; G.cmdLog=[{ name:'어퍼컷', fam:'fist', crit:true, t:now-.05 }, { name:'로우킥', fam:'foot', t:now-.6 }, { name:'잽', fam:'fist', link:true, t:now-1.6 }];
    const x=F.x-f*3, y=F.y-50;
    for(let k=0;k<6;k++){ const a=(k/5-.5)*1.5, sp=260; X.push({ k:'streak', x, y:y+(k%3-1)*2, vx:f*Math.cos(a)*sp, vy:Math.sin(a)*sp, t:.05, life:.14, col:k%2?'#ff7a3a':'#ffd34a' }); }
    X.push({ k:'flash', x, y, t:.03, life:.12, big:true });
    X.push({ k:'burst', x, y, t:.08, life:.3, f, n:14, r0:8, r1:44 });
    X.push({ k:'ring', x:x+30*f, y:y+10, t:.05, life:.16, r1:14 });
    for(let k=0;k<4;k++) X.push({ k:'drop', x:F.x+f*2+k*3, y:y-4-k*2, vx:f*50, vy:-60, t:.1, life:.5, col:'#cfe8ff' }); }`,
  // 치명타: 커지는 숫자 · 별 점 · X 섬광 · 받아치기 반짝 · 흰 김
  crit: `(S, env) => { const G=S('GS'), D=S('DPOPS'), X=S('HITFX'), F=env.foe, H=env.hero, f=F.x>=H.x?1:-1;
    D.push({ x:F.x, y:F.y-58, val:24680, style:'crit', label:'CRITICAL!!', labelCol:'#ff9a4a', stack:0, age:.06, vx:0, life:1.35 });
    G.critFx=[{ x:F.x, y:F.y-38, t:.05, big:false, f }];
    X.push({ k:'chstar', x:F.x-f*3, y:F.y-36, t:.06, life:.24 });
    X.push({ k:'swpuff', x:F.x-f*4, y:F.y-40, f, t:.12, life:.6, b:[{dx:2,dy:-1,r:3,vy:12,vx:1},{dx:-3,dy:2,r:4,vy:15,vx:-2},{dx:5,dy:0,r:3.5,vy:18,vx:3},{dx:0,dy:3,r:2.8,vy:11,vx:0}] });
    X.push({ k:'burst', x:H.x, y:H.y-44, t:.06, life:.26, f:1, n:12, r0:7, r1:34, red:true }); }`,
  // 만화 효과음 글자(별 터짐 + Anton 기울임 굵게 · 외곽선 · 그라디언트)
  comic: `(S, env) => { const C=S('COMIC'), F=env.foe, H=env.hero;
    C.push({ k:'sfx', x:F.x+30, y:F.y-96, word:'WHAM!', age:.3, life:.6, rot:-.08 });
    C.push({ k:'sfx', x:H.x-40, y:H.y-120, word:'KA-BOOM!', age:.05, life:.6, rot:.1 }); }`,
  // 말풍선: 말 · 외침 · 생각
  bubbles: `(S, env) => { const C=S('COMIC'), G=S('GS'), F=env.foeA, H=G.hero, F2=env.foeB;
    C.push({ k:'speech', a:H, text:'정시 도착이다.', age:.5, life:2.4 });
    if(F) C.push({ k:'shout', a:F, text:'이놈!', age:.3, life:1.8 });
    if(F2) C.push({ k:'think', a:F2, text:'…커피 한 잔.', age:.12, life:2.4 }); }`,
  // 필살기 컷인(주먹 계열)
  cut_spc: `(S, env) => { const G=S('GS'); G.cut={ k:'spc', kind:'fist', t:.62, dur:1.05, pause:true }; }`,
  cut_spc_in: `(S, env) => { const G=S('GS'); G.cut={ k:'spc', kind:'foot', t:.16, dur:1.05, pause:true }; }`,
  // 두목 등장 VS
  cut_vs: `(S, env) => { const G=S('GS'); G.cut={ k:'vs', boss:{ e:{ t:'boss' } }, t:.7, dur:1.9, pause:true }; }`,
  // 두목 분노
  cut_rage: `(S, env) => { const G=S('GS'); G.cut={ k:'rage', boss:{ e:{ t:'boss2' } }, t:.5, dur:1.0, pause:true }; }`,
  // 칸 이동 문 전환
  wipe: `(S, env) => { const G=S('GS'); G.wipe={ t:.24, label:'→ 3호차' }; }`,
  wipe_open: `(S, env) => { const G=S('GS'); G.wipe={ t:.36, label:'→ 3호차' }; }`,
  // 벡터 효과 모음(웹 HITFX 종류별)
  vectors: `(S, env) => { const X=S('HITFX'), F=env.foe, H=env.hero, f=F.x>=H.x?1:-1, hx=H.x, hy=H.y;
    X.push({ k:'arc', x:hx+f*3, y:hy-44, f, kind:'d', t:.05, life:.2 });
    X.push({ k:'arc', x:hx+f*3+60, y:hy-38, f, kind:'h', t:.1, life:.2 });
    X.push({ k:'arc', x:hx+f*3-60, y:hy-38, f:-f, kind:'b', t:.04, life:.2 });
    X.push({ k:'crescent', x:hx-4*f, y:hy-31-70, r:34, w:13, f, a0:84*Math.PI/180, a1:-104*Math.PI/180, t:.06, life:.22 });
    X.push({ k:'axring', x:F.x, y:F.y, t:.2, life:.6, cr:[{sd:-1,a:.1,n:3},{sd:1,a:-.2,n:4},{sd:-1,a:.05,n:5},{sd:1,a:.15,n:3}] });
    X.push({ k:'tsring', x:hx-50, y:hy, t:.15, life:.7, cr:[{sd:1,a:.2,n:3},{sd:-1,a:-.1,n:4},{sd:1,a:0,n:5}] });
    X.push({ k:'sxboom', x:F.x+40, y:F.y-60, t:.1, life:.34 });
    X.push({ k:'sxpath', x:hx, y:hy-26-60, r:36, f, t:.2, life:.55 });
    X.push({ k:'cyw', x:hx+f*13-40, y:hy-28-50, f, r:9, t:.08, life:.2 });
    X.push({ k:'cystar', x:F.x-20, y:F.y-90, t:.05, life:.14, s:1.25 });
    X.push({ k:'axv', x:F.x-f*4-30, y0:hy-96, y1:F.y-26, t:.06, life:.22 });
    X.push({ k:'gdust', x:hx+20, y:hy, t:.2, life:.8, puffs:[{dx:-4,vx:-30,rise:5,r:3,d:.02},{dx:4,vx:30,rise:6,r:3.5,d:.05},{dx:-6,vx:-20,rise:8,r:4,d:.08},{dx:7,vx:25,rise:4,r:2.8,d:0}] });
    X.push({ k:'debris', x:hx+20, y:hy, t:.1, life:.6, parts:[{vx:-40,vy:80,s:1},{vx:30,vy:100,s:2},{vx:60,vy:60,s:1}] });
    X.push({ k:'crack', x:hx+20, y:hy, t:.2, life:1.1, pts:[[-20,0],[-16,.8],[-12,-.5],[-8,1],[-3,0],[2,-.9],[7,.4],[12,1.1],[17,-.3]] });
    X.push({ k:'wave', x:F.x, y:F.y, t:.15, life:.55 });
    X.push({ k:'swirl', x:hx, y:hy-30, t:.12, life:.4, ph:2 });
    X.push({ k:'tapok', x:F.x, y:F.y-100, t:.1, life:.32 });
    X.push({ k:'sig_ring', x:F.x-60, y:F.y-60, t:.2, life:.6, r:74 });
    X.push({ k:'sig_burst', x:hx-90, y:hy-120, t:.1, life:.6 });
    X.push({ k:'sig_quake', x:hx, y:hy-30, t:.2, life:.6, r:64 });
    X.push({ k:'sig_stamp', x:F.x-40, y:F.y-110, f, t:.3, life:1.1, r:72 });
    X.push({ k:'pages', x:hx, y:hy-60, t:.4, life:2.4, P:[{vx:120,vy:-80,r:1,vr:3,ph:1},{vx:-90,vy:-60,r:2,vr:-4,ph:2},{vx:160,vy:-40,r:.5,vr:6,ph:3},{vx:-140,vy:-120,r:4,vr:-2,ph:4}] }); }`,
  // 두목: 두목 막대 · 초상 · 무너짐 막대 · 휘청 별 · 저스트 고리
  boss: `(S, env) => { const G=S('GS'), B=env.boss; if(!B) return; B.e.raged=false; B.e.hp=B.e.max*.62; B.e.lag=.8;
    G.bossBreak={ a:B, t:2.1, T0:3.2 }; B.anim='stagger'; }`,
};

// ---- 모드 순간(N5 모드 HUD — HUDFrame.modes): 순간마다 모드를 연 뒤(jumpTo) 찍는다 ----
// mode: 게임을 그 모드로 돌려 놓는 방법(MODE_SETUP) · src: 위와 같은 꾸미기
const MODE_MOMENTS = {
  // 타워: 층 · 야근 배지 · 정원 초과(문 열림 hold) 띠 · 작업 막대(수리 기사)
  tower_over: { mode: 'tower', src: `(S, env) => { const G=S('GS'), T=G.tower; T.floor=7; T.ot=2; T.daily=null; T.t0=G.time-83.4; T.phase='hold';
    if(!S('foes')().some(a=>a.e.tech)) S('twSpawn')('tech',0); if(!S('foes')().some(a=>a.e.presser)) S('twSpawn')('accountant',1);
    for(const a of S('foes')()){ if(a.e.tech) a.e.work=3; if(a.e.presser) a.e.work=1.2; }
    T.limit=Math.max(1, S('twWeight')()-2); }` },
  // 타워(오늘의 타워 배지 · 정원 여유)
  tower_daily: { mode: 'tower', src: `(S, env) => { const G=S('GS'), T=G.tower; T.floor=12; T.ot=0; T.daily='2026-10-09'; T.t0=G.time-641; T.phase='move'; T.limit=9; }` },
  // 보너스: 남은 시간 · 점수 · 차 체력 막대 + 숫자/효과
  bonus_go: { mode: 'bonus', src: `(S, env) => { const G=S('GS'), BN=G.bonus, D=S('DPOPS'), H=env.hero; BN.phase='go'; BN.t=BN.dur-3.4; BN.score=48250; BN.hp=BN.max*.37;
    D.push({ x:H.x+60, y:H.y-58, val:812, style:'hit', label:null, stack:0, age:.32, vx:0, life:1.05 }); }` },
  // 보너스 결산 단계: 등급 글자
  bonus_owner: { mode: 'bonus', src: `(S, env) => { const G=S('GS'), BN=G.bonus; BN.phase='owner'; BN.t=BN.dur; BN.pt=2.0; BN.score=61200; BN.hp=0; BN.res={ g:'A' }; }` },
  // 무도장: 동작 정보 줄(주인공 · 상대 · 거리 + 마지막 타격) · 속도/반복/확대
  dojo_hit: { mode: 'dojo', src: `(S, env) => { const DJ=S('DJ'); DJ.hit={ me:false, n:'hook', dmg:12, crit:true, air:true, r:'stagger' }; DJ.rep=true; DJ.zoom=2; }` },
  // 거리 연출: 레터박스 22 · 하얀 빛 · 어둠 + 만화 글자
  cine: { mode: 'cine', src: `(S, env) => { const G=S('GS'), C=G.cine, CM=S('COMIC'); C.flash=.35; C.fade=.2;
    CM.push({ k:'sfx', x:env.hero.x-10, y:env.hero.y-80, word:'클랭!', age:.3, life:.6, rot:-.08 }); }` },
  // 복도: B2 CORRIDOR 진행 막대 · 점수(140) · 레터박스 20
  corridor: { mode: 'corridor', src: `(S, env) => { const G=S('GS'); G.lbox=1; G.prologue.x=S('CORR_LEN')*.42; }` },
  // 쇼 칸 전구(밝기 단계 넷)
  show_lamps: { mode: 'show', src: `(S, env) => { const L=S('SHOW_LAMPS'); [1,.5,1.6,.1].forEach((k,i)=>{ L[i].k=k; }); }` },
  // 만화 페이지(프롤로그 drawStory): 1칸 · 2칸 · 3칸 · 어두워짐
  story_p1: { mode: 'subway', src: `(S, env) => { S('GS').cut={ k:'story', t:1.2, dur:7.1 }; }` },
  story_p2: { mode: 'subway', src: `(S, env) => { S('GS').cut={ k:'story', t:2.62, dur:7.1 }; }` },
  story_p3: { mode: 'subway', src: `(S, env) => { S('GS').cut={ k:'story', t:5.1, dur:7.1 }; }` },
  story_end: { mode: 'subway', src: `(S, env) => { S('GS').cut={ k:'story', t:6.85, dur:7.1 }; }` },
};
// 모드 열기(페이지 안 · 루프가 도는 중에)
const MODE_SETUP = {
  tower: `S('jumpTo')('tower')`, bonus: `S('jumpTo')('bonus')`, dojo: `S('jumpTo')('dojo')`, corridor: `S('jumpTo')('corridor')`,
  cine: `S('jumpTo')('cine'); S('startCine')()`,
  show: `(() => { const ST=S('STAGES'), CC=S('CAR_CONCEPTS'); for(let li=0; li<ST.length; li++){ const ln=ST[li].line; for(let ci=0; ci<ln.length; ci++) if(CC[ln[ci].car] && CC[ln[ci].car].marquee){ S('jumpTo')({ line:li, car:ci }); return; } } })()`,
};
const MODE_WAIT = { tower: 6000, bonus: 3200, dojo: 2500, corridor: 3000, cine: 1300, show: 3500 };

const names = want.length ? want : [...Object.keys(MOMENTS), ...Object.keys(MODE_MOMENTS)];
const anton = fs.readFileSync(path.join(ROOT, 'web', 'app', 'fonts', 'anton-latin-400-normal.woff2')).toString('base64');

const g = await openGame({ run: true, viewport: { width: 390, height: 844 } });
fs.mkdirSync(OUT, { recursive: true }); fs.mkdirSync(PREVIEW, { recursive: true });
try {
  const p = g.page;
  await p.addStyleTag({ content: `@font-face{font-family:'Impact';src:url(data:font/woff2;base64,${anton}) format('woff2');font-weight:400}
    @font-face{font-family:'Arial Black';src:url(data:font/woff2;base64,${anton}) format('woff2');font-weight:400}` });
  await p.waitForTimeout(1200);
  await p.click('#modeSeg button[data-m="game"]');
  await p.waitForTimeout(1200);
  await p.evaluate(`window.__dotlab.jumpTo('subway')`);
  await p.waitForTimeout(4500);
  await p.evaluate(async () => {
    for (const f of ['italic 900 14px Impact', '10px Galmuri9', '700 9px Galmuri11', 'bold 12px Galmuri11', '10px Galmuri11'])
      await document.fonts.load(f, 'AaWHAM!가나다정시 도착이다…');
    await document.fonts.ready;
  });
  await p.evaluate(() => { window.__bbHold = true; });
  await p.waitForTimeout(250);

  // 도트 그림 대조: 컷인 원화 · 초상(스킨 · 선글라스) · 피해 숫자 글리프
  const art = await p.evaluate(captureArt);
  fs.writeFileSync(path.join(OUT, 'art.json'), JSON.stringify(art) + '\n');
  console.log(`[hud] art: 원화 ${art.cut.length} · 글리프 ${art.glyph.length}`);

  // 만화 페이지 원화(storyArt p1~p3 — pShade 까지) 정확 일치 대조용
  const story = await p.evaluate(() => { const S = __BB_SCOPE__;
    return ['p1', 'p2', 'p3'].map(k => { const cv = S('storyArt')(k), d = cv.getContext('2d').getImageData(0, 0, cv.width, cv.height).data; let s = '';
      for (let i = 0; i < d.length; i += 0x8000) s += String.fromCharCode.apply(null, d.subarray(i, i + 0x8000)); return { key: k, w: cv.width, h: cv.height, b64: btoa(s) }; }); });
  fs.writeFileSync(path.join(OUT, 'story_art.json'), JSON.stringify({ _about: 'hud.mjs — 웹 storyArt(p1~p3) 픽셀(곧은 RGBA)', story }) + '\n');

  // 지하철 순간 먼저, 그다음 모드별로 묶어서(모드를 바꾸면 루프를 잠깐 풀었다가 다시 붙잡는다)
  const order = [...names.filter(n => MOMENTS[n] || (MODE_MOMENTS[n] && MODE_MOMENTS[n].mode === 'subway')), ...names.filter(n => MODE_MOMENTS[n] && MODE_MOMENTS[n].mode !== 'subway')];
  let curMode = 'subway';
  for (const name of order) {
    const M = MODE_MOMENTS[name], src = MOMENTS[name] || (M && M.src);
    if (!src) { console.error(`[hud] 모르는 순간: ${name}`); continue; }
    if (M && M.mode !== curMode) {
      await p.evaluate(() => { window.__bbHold = false; const cb = window.__bbHeld; window.__bbHeld = null; if (cb) requestAnimationFrame(cb); });
      const err = await p.evaluate(code => { const S = __BB_SCOPE__; try { const G = S('GS'); if (G.talk) S('tkSkip')(); (0, eval)('(S) => { ' + code + ' }')(S); return null; } catch (e) { return String(e && e.stack || e); } }, MODE_SETUP[M.mode]);
      if (err) { console.error(`[hud] 모드 ${M.mode}: ${err}`); continue; }
      await p.waitForTimeout(MODE_WAIT[M.mode] || 2500);
      await p.evaluate(() => { const S = __BB_SCOPE__, G = S('GS'); if (G.talk) S('tkSkip')(); window.__bbHold = true; });
      await p.waitForTimeout(250);
      curMode = M.mode;
    }
    const r = await p.evaluate(captureMoment, { name, src });
    if (r.error) { console.error(`[hud] ${name}: ${r.error}`); continue; }
    const raw = Buffer.from(r.b64, 'base64');
    fs.writeFileSync(path.join(OUT, `${name}.rgba.deflate`), zlib.deflateRawSync(raw, { level: 9 }));
    fs.writeFileSync(path.join(OUT, `${name}.json`), JSON.stringify({ _about: 'tools/js/extract/hud.mjs — 웹 #ui 캔버스 그리기 입력(HUDState · HUDFrame)', sourceSha16: g.sourceSha16, name, width: r.w, height: r.h, state: r.state, frame: r.frame }) + '\n');
    fs.writeFileSync(path.join(PREVIEW, `${name}.png`), encodePng(r.w, r.h, raw));
    console.log(`[hud] ${name}: ${r.w}×${r.h} · 숫자 ${r.state.pops.length} · 효과 ${r.state.hitFx.length} · 만화 ${r.state.comic.length} · 컷인 ${r.state.cut ? r.state.cut.k : '-'} · 불투명 픽셀 ${r.opaque}`);
  }
} finally { await g.close(); }

// ---- 페이지 안 ----
function captureArt() {
  const S = __BB_SCOPE__, OPT = S('OPT');
  const px = cv => { const d = cv.getContext('2d').getImageData(0, 0, cv.width, cv.height).data; let s = ''; for (let i = 0; i < d.length; i += 0x8000) s += String.fromCharCode.apply(null, d.subarray(i, i + 0x8000)); return { w: cv.width, h: cv.height, b64: btoa(s) }; };
  const cut = [];
  const keep = { skin: OPT.skin, shades: OPT.shades };
  for (const [skin, shades] of [['jw', false], ['gala', false], ['rain', true], ['chicago', false]]) {
    OPT.skin = skin; OPT.shades = shades;
    const keys = skin === 'jw' && !shades
      ? ['face:hero', 'face:hero_strain', 'face:hero_hurt', 'face:hero_crit', 'face:hero_flinch', 'face:hero_shout', 'face:boss', 'face:boss2', 'face:boss3', 'face:boss4', 'face:kaneB', 'face:mgr', 'face:headchef', 'eyes:hero', 'rage:boss', 'rage:boss2', 'fist:x', 'shoe:x']
      : ['face:hero', 'face:hero_crit', 'eyes:hero'];
    for (const k of keys) cut.push({ key: k, skin, shades, ...px(S('cutArt')(k)) });
  }
  OPT.skin = keep.skin; OPT.shades = keep.shades;
  const glyph = [];
  for (const st of ['hit', 'crit', 'hurt', 'heal', 'total']) for (const ch of '0123456789+') glyph.push({ style: st, ch, ...px(S('dGlyph')(ch, st)) });
  return { cut, glyph };
}

function captureMoment({ name, src }) {
  const S = __BB_SCOPE__;
  try {
    const G = S('GS'), D = S('DPOPS'), X = S('HITFX'), C = S('COMIC'), cv = S('uiCv'), cx = S('uiCx');
    const realNow = performance.now.bind(performance), realRandom = Math.random;
    const T = realNow();
    // 상태 비우기(이 순간에 정한 것만 그린다)
    D.length = 0; X.length = 0; C.length = 0; G.critFx = []; G.cut = null; G.wipe = null; G.cmdLog = []; G.combo = 0; G.comboDmg = 0; G.lastHit = -9;
    G.flashT = 0; G.bossBreak = null; G.tapW = null; G.fade = 0; G.lbox = 0; G.manualT = 0; G.faceUntil = 0; G.shoveX = 0; S('shakeX = 0');
    G.viewZ = 1; G.viewC = [.5, .5]; G.zoomK = 0; S('CAMX = Math.round(CAMX)');   // 카메라를 정수 픽셀에(웹도 소수 CAMX 면 도트가 안티에일리어싱된다)
    const foes = S('foes')(), H = G.hero;
    const near = foes.slice().sort((a, b) => Math.abs(a.d.x - H.d.x) - Math.abs(b.d.x - H.d.x));
    const fakeFoe = { d: { x: H.d.x + 50, y: H.d.y } };
    const env = { hero: { x: H.d.x, y: H.d.y }, foe: near[0] ? { x: near[0].d.x, y: near[0].d.y } : fakeFoe.d, foeA: near[0], foeB: near[1], boss: null };
    // 두목 순간: 가장 가까운 적을 잠시 두목으로(BOSS_INFO 있는 종류)
    const restore = [];
    if (name === 'boss' && near[0]) { const a = near[0], e = a.e; restore.push(() => { Object.assign(a.e, e0); a.anim = anim0; }); const e0 = { ...e }, anim0 = a.anim; e.boss = true; e.t = 'boss'; env.boss = a; }
    G.hp = Math.min(G.max, Math.max(1, G.max * .55)); G.lagH = Math.min(G.max, G.hp + 14);
    (0, eval)(src)(S, env);
    // 시간 멈춤: performance.now 고정 · dt 0 · 무작위 .5
    performance.now = () => T; Math.random = () => .5; S('lastDT = performance.now()');
    const ctx0 = () => { cx.setTransform(1, 0, 0, 1, 0, 0); cx.globalAlpha = 1; cx.lineCap = 'butt'; cx.lineJoin = 'miter'; cx.lineWidth = 1; cx.textAlign = 'left'; cx.textBaseline = 'alphabetic'; cx.setLineDash([]); cx.imageSmoothingEnabled = false; };
    ctx0();
    let frame, state, img;
    try {
      S('drawUI')();
      img = cx.getImageData(0, 0, cv.width, cv.height);
      ({ frame, state } = readState(S, T / 1000));
    } finally { performance.now = realNow; Math.random = realRandom; for (const f of restore) f(); }
    let s = '', opaque = 0; const d = img.data;
    for (let i = 3; i < d.length; i += 4) if (d[i]) opaque++;
    for (let i = 0; i < d.length; i += 0x8000) s += String.fromCharCode.apply(null, d.subarray(i, i + 0x8000));
    return { w: cv.width, h: cv.height, b64: btoa(s), state, frame, opaque };
  } catch (e) { return { error: String(e && e.stack || e) }; }

  // drawUI 가 읽은 값(HUDFrame) · 그린 상태(HUDState) — Swift 이름 그대로
  function readState(S, now) {
    const G = S('GS'), VW = S('VW'), H = S('H'), W = S('W'), CAMX = S('CAMX'), OPT = S('OPT'), STN = S('STN'), STOPS = S('STOPS'), LINE = S('LINE'), STAGE = S('STAGE');
    const foes = S('foes')(), FOE_W = S('FOE_W'), BOSS_INFO = S('BOSS_INFO');
    const shv = Math.max(-5, Math.min(5, S('shakeX') + Math.round(G.shoveX || 0)));
    const r = G.hp / G.max, tr = G.faceUntil > now ? G.faceMood : null, m = tr || (r > .7 ? '' : r > .4 ? 'strain' : r > .15 ? 'hurt' : 'crit');
    const BS = foes.find(a => a.e.boss && BOSS_INFO[a.e.t]);
    const Hh = G.hero;
    const inc = Hh && G.shots.some(s => !s.dead && !s.dodged && Math.sign(Hh.d.x - s.x) === Math.sign(s.vx) && Math.abs(s.x - Hh.d.x) < 130);
    const frame = {
      vw: VW, h: H, w: W, uis: S('UIS'), camX: CAMX, viewZ: G.on ? (G.viewZ || 1) : 1, viewC: G.viewC || [.5, .5], shv,
      now, time: G.time, on: !!G.on, hero: !!G.hero, lbox: G.lbox || 0, tower: !!G.tower, bonus: !!G.bonus,
      stageColor: STAGE.color,
      stops: STOPS.map((id, i) => ({ label: STN[id].h || STN[id].cap, here: G.atStop === id, passed: i <= G.leg && !(G.atStop === id) && i < G.leg, next: G.nextStop === id && !G.atStop })),
      score: G.score,
      timeBar: (!G.tower && ((G.state === 'fight' && !LINE[G.ci].end) || G.arriving)) ? Math.max(0, 1 - (G.legT || 0) / S('legDur')(LINE[G.ci])) : null,
      foesLeft: foes.length, manual: G.manualT > 0,
      portrait: 'face:hero' + (m ? '_' + m : ''), portraitDX: 0,
      hp: G.hp, max: G.max, lagH: G.lagH, sp: G.sp || 0,
      boss: BS ? { t: BS.e.t, hp: BS.e.hp, max: BS.e.max, raged: !!BS.e.raged, lag: BS.e.lag } : null,
      foes: foes.map(a => ({ x: a.d.x, y: a.d.y, hp: a.e.hp, max: a.e.max, boss: !!a.e.boss, bossInfo: !!BOSS_INFO[a.e.t],
        hasAction: !!(a.action && !a.action.fired), w: FOE_W[a.anim] || null, tt: (a.action && !a.action.fired) ? S('timeToCue')(a) : null })),
      heroX: Hh ? Hh.d.x : null, justW: S('JUST_W')(),
      flash: G.flashT > 0 ? G.flash : null,
      duck: (inc && S('duckReady')() && !S('isDucking')(Hh) && Math.floor(G.time * 8) % 2 === 0) ? [Hh.d.x, Hh.d.y] : null,
      stagger: G.ents.filter(a => a.e && !a.dead && !a.hidden && (a.anim === 'stagger' || a.anim === 'staggerX')).map(a => [a.d.x, a.d.y - 48 - (a.airOv || 0), S('gameTime') * 5.5]),
      bossBreak: (G.bossBreak && G.bossBreak.a && !G.bossBreak.a.dead) ? { x: G.bossBreak.a.d.x, y: G.bossBreak.a.d.y, k: Math.max(0, G.bossBreak.t / G.bossBreak.T0) } : null,
      tapW: (G.tapW && G.tapW.T) ? { x: G.tapW.T.d.x, y: G.tapW.T.d.y, t: G.tapW.t } : null,
      doze: G.ents.filter(a => a.idle === 'doze' && !a.hidden && a.goal == null && a.passPose === 'sb_sit').map(a => [a.d.x, a.d.y, (now * .6 + a.d.x * .013) % 1]),
      combo: (G.combo || 0) >= 2 ? { n: G.combo, since: G.time - (G.lastHit || 0), win: S('comboWin')(), dmg: G.comboDmg || 0 } : null,
      skin: OPT.skin || 'jw', shades: !!OPT.shades, noFlash: !!OPT.noFlash, fade: G.fade || 0,
      modes: readModes(S, G, foes),
    };
    const state = {
      pops: S('DPOPS').map(p => ({ x: p.x, y: p.y, val: p.val, style: p.style, label: p.label ?? null, labelCol: p.labelCol ?? null, stack: p.stack, age: p.age, vx: p.vx, life: p.life })),
      hitFx: S('HITFX').filter(p => p.t < p.life).map(p => JSON.parse(JSON.stringify(p))),
      critFx: (G.critFx || []).map(c => ({ x: c.x, y: c.y, t: c.t, big: !!c.big, f: c.f || 1 })),
      comic: S('COMIC').map(c => c.k === 'sfx' ? { k: 'sfx', x: c.x, y: c.y, word: c.word, age: c.age, life: c.life, rot: c.rot }
        : { k: c.k, x: c.a.d.x, y: c.a.d.y, text: c.text, age: c.age, life: c.life }),
      cmdLog: (G.cmdLog || []).map(e => ({ name: e.name, age: now - e.t, sp: !!e.sp, crit: !!e.crit, link: !!e.link, fam: e.fam || null })),
      cut: G.cut ? { k: G.cut.k, kind: G.cut.kind || null, boss: (G.cut.boss && G.cut.boss.e) ? G.cut.boss.e.t : null, t: G.cut.t, dur: G.cut.dur } : null,
      wipe: G.wipe ? { t: G.wipe.t, label: G.wipe.label || null } : null,
    };
    return { frame, state };
  }

  // 모드 HUD 값(HUDModes — Swift 이름 그대로)
  function readModes(S, G, foes) {
    const META = S('META'), LINE = S('LINE'), CC = S('CAR_CONCEPTS');
    const m = { en: S('LANG') === 'en', tower: null, bonus: null, dojo: null, cine: null, corridor: null, lamps: null, story: null };
    const T = G.tower;
    if (T) m.tower = { floor: T.floor, name: S('twFloorName')(T.floor), daily: !!T.daily, ot: T.ot || 0, weight: S('twWeight')(), limit: T.limit || S('TW_LIMIT'),
      secs: Math.max(0, Math.floor(G.time - T.t0)),
      best: Math.max(T.daily ? (((META.tower || {}).daily || {})[T.daily] || {}).f || 0 : ((((META.tower || {}).lv || {})[T.ot || 0]) || {}).f || 0, T.floor),
      hold: T.phase === 'hold',
      workers: foes.filter(a => (a.e.tech || a.e.presser) && a.e.work > 0).map(a => [a.d.x, a.d.y, Math.min(1, a.e.work / (a.e.presser ? 3 : 5)), a.e.presser ? 1 : 0]) };
    const BN = G.bonus;
    if (BN) m.bonus = { score: Math.round(BN.score), left: Math.max(0, BN.dur - BN.t), go: BN.phase === 'go', hp: BN.hp, max: BN.max,
      grade: (BN.phase === 'owner' && BN.pt > 1.2 && BN.res) ? BN.res.g : null };
    if (G.demo && G.hero) {   // drawDojoHUD 와 같은 식(그린 뒤라 c._djT 가 같다)
      const tick = S('tick'), LOOP = S('LOOP'), seqOf = S('seqOf'), tr = S('tr'), DJ = S('DJ'), D = S('dojoDummy')(), Hh = G.hero;
      const info = c => { const sq = seqOf(c.anim, c) || []; return `${c.anim}  ${Math.min((c.si || 0) + 1, sq.length || 1)}/${sq.length || 1}  ${c.pose || ''}  ${tick - c._djT}f`; };
      const L = DJ.hit, rows = [[tr('주인공'), info(Hh), '#ffd34a']];
      if (D) rows.push([tr('상대'), info(D) + (D.jug ? `  ↑${Math.round(D.jug.h)}` : ''), '#ff9a7a']);
      rows.push([tr('거리'), (D ? String(Math.round(Math.abs(D.d.x - Hh.d.x))) : '-') + (L ? `   ${L.me ? tr('맞음') : tr('타격')} ${L.n} ${L.dmg}${L.crit ? ' ' + tr('치명') : ''}${L.air ? ' ' + tr('공중') : ''}${L.r ? ' · ' + L.r : ''}` : ''), '#9fd6ff']);
      const paused = !!S('gamePaused'), st = (paused ? tr('멈춤') : (Math.round(S('playSpeed') * 100) / 100) + '×') + (DJ.rep ? '  ' + tr('반복') : '') + ((DJ.zoom || 1) > 1 ? `  ${tr('확대')} ${DJ.zoom}×` : '');
      m.dojo = { rows, status: st, paused };
    }
    if (G.cine) m.cine = { flash: G.cine.flash, fade: G.cine.fade };
    else if (G.prologue) m.corridor = G.prologue.x / S('CORR_LEN');
    const Lc = G.on && S('scene') === 'subway' && LINE[G.ci] && CC[LINE[G.ci].car];
    if (Lc && Lc.marquee) m.lamps = S('SHOW_LAMPS').map(L => [L.x, L.k]);
    return m;
  }
}
