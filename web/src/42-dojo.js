// =========================================================
// 동작 데모 무도장(개발자 도구): 버튼을 누르면 각 동작을 실제 게임 경로 그대로 재생한다
// =========================================================
const DOJO={
  hero:[['잽','punch',0],['크로스','punch',1],['훅','punch',2],['어퍼컷(콤보)','punch',3],['앞차기','kick'],['돌려차기','round'],['어퍼컷','upper'],['팔꿈치','elbow'],['니킥','knee'],
        ['다리걸기','sweep'],['어깨 돌진','charge'],['잡아 메치기','throw'],['밟기','stomp'],['뒤차기','bkick'],['백피스트','bfist'],['날아차기','fkick'],['섬머솔트 킥','skick'],['공중 자전거 차기','cycle'],['도끼 차기','axe'],['저먼 수플렉스','suplex'],['철산고','tetsu'],['연환퇴','renkan'],['신문','paper'],['장우산','umb']],
  misc:[['쭈그리기','duck'],['기둥 회전차기','polespin'],['매달려 차기','hangkick'],['장도리 옆','hm_swing'],['장도리 되돌려','hm_back'],['장도리 올려','hm_up'],['장도리 내려찍기','hm_down']],
  spc:[['막차 러시','fist'],['회전 폭풍','foot'],['종착역','grap']],
  react:[['크로스에 맞음','rCross'],['훅에 맞음','rHook'],['니킥에 맞음','rKnee'],['발차기에 맞음','rKick'],['돌려차기에 맞음','rSpin'],['다리걸기에 걸림','rSwept'],['돌진에 맞음','rCharge'],
         ['메치기에 꽂힘','rSlam'],['밟힘','rStomp'],['띄워짐','launch'],['넘어짐','fall'],['일어남','getup'],['앞으로 쓰러짐','deathFwd'],['경직','rElbow'],['휘청','staggerX'],['엎어져 일어나기','rSpike'],['벽꽝','rWall'],['무너짐','crumple']],
  foe:[['잽','jab'],['훅','hook'],['앞차기','kick'],['몽둥이','bat'],['박치기','hbutt'],['배치기','charge'],['돌려차기','round'],['어퍼컷','upper'],['날아차기','fkick']],
  moves:[['잽','punch:0'],['크로스','punch:1'],['훅','punch:2'],['어퍼(콤보)','punch:3'],['어퍼컷','upper'],['퍼올리기','upper:scoop'],['앞차기','kick'],['돌려차기','round'],['팔꿈치','elbow'],['니킥','knee'],
         ['다리걸기','sweep'],['어깨 돌진','charge'],['메치기','throw'],['밟기','stomp'],['날아차기','fkick'],['섬머솔트','skick'],['자전거 차기','cycle'],['도끼 차기','axe'],['수플렉스','suplex'],['철산고','tetsu'],['연환퇴','renkan'],['신문','paper'],['장우산','umb'],['매달려 차기','@strap']],
  combo:[ ['올려 꽂기 · 연환퇴 → 도끼 차기', [['renkan'],['axe']]],
          ['철산 마무리 · 다리걸기 → 밟기 → 철산고', [['sweep'],['stomp'],['tetsu']]],
          ['낙뢰 · 어퍼컷 → 공중 자전거 차기 → 도끼 차기', [['upper'],['cycle'],['axe']]],
          ['무너뜨려 꽂기 · 니킥 → 잽 → 저먼 수플렉스', [['knee'],['punch',0],['suplex']]],
          ['공중 4연타 · 어퍼 → 잽 → 크로스 → 훅', [['punch',3],['punch',0],['punch',1],['punch',2]]],
          ['날려 보내기 · 어퍼 → 잽 → 돌려차기',   [['punch',3],['punch',0],['round']]],
          ['재띄우기 · 어퍼 → 잽 → 어퍼컷 → 훅',    [['punch',3],['punch',0],['upper'],['punch',2]]],
          ['공중 5연타 · 어퍼 → 잽 → 크로스 → 훅 → 돌려차기', [['punch',3],['punch',0],['punch',1],['punch',2],['round']]],
          ['공중 5연타 · 어퍼 → 잽 → 크로스 → 훅 → 어깨 돌진', [['punch',3],['punch',0],['punch',1],['punch',2],['charge']]],
          ['어깨 돌진 날려 보내기',                 [['charge']]],
          ['다리걸기 → 밟기',                       [['sweep'],['stomp']]],
          ['잡아 메치기 꽂기',                      [['throw']]],
          ['걸고 퍼올리기 · 다리걸기 → 퍼올리기 → 잽 → 크로스', [['sweep'],['upper',null,'scoop'],['punch',0],['punch',1]]],
          ['무너뜨리기 · 니킥 → 훅 → 어퍼 → 잽',     [['knee'],['punch',2],['punch',3],['punch',0]]],
          ['기둥 튕기기 · 어깨 돌진 → 마중 훅 → 어퍼', [['charge'],['punch',2],['punch',3]]],
          ['공중 잡아 꽂기 · 어퍼 → 잽 → 크로스 → 공중 메치기', [['punch',3],['punch',0],['punch',1],['throw']]],
          ['돌려 세우기 · 크로스 → 훅 → 앞차기(등)', [['punch',1],['punch',2],['kick']]],
          ['바닥 튕기기 · 어퍼 → 잽 → 밟기 → 어퍼', [['punch',3],['punch',0],['stomp'],['upper']]],
          ['우산 걸어 당기기 · 장우산 → 잽 → 크로스 → 훅', [['umb'],['punch',0],['punch',1],['punch',2]]],
          ['손잡이 공중전 · 어퍼 → 매달려 차기', [['punch',3],['@strap']]],
          ['섬머솔트 · 섬머솔트 킥 → 잽 → 크로스 → 훅', [['skick'],['punch',0],['punch',1],['punch',2]]] ],
};
const dojoDummy=()=>GS.ents.find(a=>a.e && a.dojo);
function dojoReset(dx, down){ const H=GS.hero, D=dojoDummy(); if(!H||!D) return; GS.cut=null; GS.spc=null; GS.slowT=0;
  GS.dojoSeq=null; GS.dojoPole=false; djReset(); for(const c of [H,D]){ c.action=null; c.queue=[]; c.dash=0; c.dashT=0; c.kb=0; c.airOv=0; c.hs=0; c.held=null; c.dead=false; c.hidden=false; c.flash=0; c.jug=null; c.legRun=false; }
  H.d.x=250; H.d.flip=false; setAnim(H,'idle'); D.d.x=250+dx; D.d.flip=dx>0; D.e.hp=D.e.max=99999; D.e.stun=0; D.after=null; setAnim(D, down?'down':'idle'); if(down) D.pose='kd5'; }
function dojoHero(id, combo){ const H=GS.hero, D=dojoDummy(), back=GITEMS[id]&&GITEMS[id].back; if(!H||!D) return;
  if(!back && !(id==='stomp' && !FALLS.has(D.anim) && !D.jug)){   // 실전처럼: 허수아비가 있는 자리로 다가가 친다
    GS.bag=[{ id, uid:9900, t:99, tier:2, x:0, y:0, rot:0, combo:0, last:-9 }]; GS.dojoSeq={ steps:[[id, combo!=null?combo:null]], i:0, t:0, name:'', single:true, hits:[], airs:[], maxH:0 }; return; }
  dojoHeroReset(id, combo); }
function dojoHeroReset(id, combo){ const H=GS.hero, gap=['fkick'].includes(id), back=GITEMS[id]&&GITEMS[id].back;
  const rc=(GITEMS[id]&&GITEMS[id].reach)||24; dojoReset(gap?85:back?-Math.max(12,rc-6):id==='throw'?18:Math.max(12,Math.min(rc>30?rc-6:24,rc-3)), id==='stomp'); const D=dojoDummy();
  GS.bag=[{ id, uid:9900, t:99, tier:2, x:0, y:0, rot:0, combo:combo!=null?(combo+3)%4:0, last:combo!=null&&combo>0?GS.time:-9 }]; if(combo===0) GS.bag[0].last=-9;
  useSkill(0, D, true); }
// 콤보 시연: 단계마다 실전과 같은 경로(useSkill)로 친다 · 멀면 빠르게 다가가고 · 떠 있으면 회복을 끊고 이어 친다
function dojoCombo(k){ const C=DOJO.combo[k]; if(!C) return; dojoRun(C[1], C[0]); }
const ccToStep=v=>{ const [id,x]=v.split(':'); return x==='scoop' ? [id,null,'scoop'] : x!=null ? [id,+x] : [id]; };
function dojoCustomRun(){ const L=GS.cc||[]; if(!L.length) return; GS.ccRes=null; ccRender(); dojoRun(L.map(ccToStep), '커스텀 콤보', true); }
function dojoRun(steps, name, custom){ dojoReset(steps[0][0]==='throw'?18:steps[0][0]==='umb'?36:20); const D=dojoDummy();
  if(steps.some(st=>st[0]==='@strap')){ const H=GS.hero, sx=STRAP_X.slice().sort((a,b)=>Math.abs(a-250)-Math.abs(b-250))[0]; H.d.x=sx; D.d.x=sx+20; }   // 손잡이 아래에서 시작
  const ids=[...new Set(steps.map(st=>st[0]).filter(id=>id[0]!=='@'))]; GS.bag=ids.map((id,n)=>({ id, uid:9910+n, t:99, tier:2, x:0, y:0, rot:0, combo:0, last:-9 }));
  GS.dojoSeq={ steps, i:0, t:0, name, custom:!!custom, hits:[], airs:[], maxH:0 }; GS.dojoPole=(name||'').includes('기둥'); if(GS.dojoPole && DJ.on){ const H=GS.hero; H.d.x=318; D.d.x=342; } say(custom?'커스텀 콤보':'콤보 시연', name, 1.4); }
// 결과: 단계별 적중 · 공중 · 최고 높이
function dojoResult(S){ const n=S.steps.length, hit=S.steps.filter((_,k)=>S.hits[k]>0).length, air=S.steps.filter((_,k)=>S.airs[k]).length;
  const txt=`${n}타 중 ${hit}타 적중 · 공중 ${air}타 · 최고 ${Math.round(S.maxH||0)}`; const el=document.getElementById('djRes'); if(el) el.textContent=tr(txt);
  if(S.custom){ GS.ccRes=S.steps.map((_,k)=>S.hits[k]>0?(S.airs[k]?'air':'hit'):'miss'); ccRender(); } if(!S.single) say(tr(S.name||'콤보'), tr(txt), 2.2); }
// 허수아비: 날아가면 일어나 주인공 앞으로 걸어와 멈춘다(순간이동 없이 실전처럼)
function dojoDummyTick(dt){ const D=dojoDummy(), H=GS.hero; if(!D||!H||D.dead||D.held||D.jug) return;
  if(D.anim==='idle'||D.anim==='walk'){ const dx=H.d.x-D.d.x, d=Math.abs(dx); if(d>30){ face(D,H.d.x); moveTo(D, H.d.x-Math.sign(dx)*22, 70, dt); } else if(D.anim==='walk'){ setAnim(D,'idle'); face(D,H.d.x); } } }
function dojoSeqTick(dt){ const S=GS.dojoSeq, H=GS.hero, D=dojoDummy(); if(!S||!H||!D){ GS.dojoSeq=null; return; } S.t+=dt; S.maxH=Math.max(S.maxH||0, D.jug?D.jug.h:0);
  if(S.i>=S.steps.length){ if((S.t>1.4 && !D.jug) || S.t>4){ dojoResult(S); GS.dojoSeq=null; } return; }
  if(S.t>6){ dojoResult(S); GS.dojoSeq=null; return; }   // 안전장치
  const st=S.steps[S.i], id=st[0], air=!!D.jug;
  if(id==='@strap'){ if(!(air && D.jug.h>=20)) return; if(!canAct(H)){ if(H.action && H.action.fired && !heroAirborne(H)){ H.action=null; H.queue=[]; setAnim(H,'idle'); } else return; }
    const sx=STRAP_X.slice().sort((a,b)=>Math.abs(a-H.d.x)-Math.abs(b-H.d.x))[0]; if(H.anim==='walk') setAnim(H,'idle'); S.cur=S.i; strapAir(H,D,Math.abs(sx-H.d.x)<40?sx:H.d.x); S.i++; S.t=0; return; }
  if(id==='stomp' && air && (D.jug.h>30 || D.jug.vy>0)) return;   // 밟기는 떨어지며 낮아질 때
  const it=GITEMS[id];
  const busy=!canAct(H), cancel=busy && H.action && H.action.fired && !heroAirborne(H) && (air || FALLS.has(D.anim));
  if(busy && !cancel) return;
  if(air && D.jug.h>60) return;                                                   // 너무 높으면 내려올 때까지
  const rc=(it.combo ? MOVE_REACH[['jab','cross','hook','upper'][st[1]]] : it.reach) + (air?8:0), dx=D.d.x-H.d.x, d=Math.abs(dx);
  if(id==='fkick'){ if(d<34){ if(busy) return; moveTo(H, D.d.x-Math.sign(dx||1)*72, heroSpd()*1.8, dt); return; } if(d>110){ if(busy) return; face(H,D.d.x); moveTo(H, D.d.x-Math.sign(dx)*80, heroSpd()*1.8, dt); return; } }   // 날아차기: 거리를 벌렸다가 날아든다
  else if(d>rc+5 && id!=='charge'){ if(busy){ if(heroAirborne(H)) return; H.action=null; H.queue=[]; setAnim(H,'idle'); }   /* 공중 동작은 내려앉은 뒤에 다가간다 */ face(H,D.d.x); approach(H, D.d.x-Math.sign(dx)*Math.max(SEP_HF,rc-4), heroSpd()*1.8, dt, heroSpd()*3.4); return; }
  if(busy){ H.action=null; H.queue=[]; setAnim(H,'idle'); }
  const bi=GS.bag.findIndex(b=>b.id===id), b=GS.bag[bi]; b.t=99; if(it.combo){ b.combo=((st[1]??0)+3)%4; b.last=GS.time; }
  if(st[2]==='scoop') H.scoopNext=true; if(H.anim==='walk') setAnim(H,'idle'); S.cur=S.i; face(H,D.d.x); useSkill(bi, D, true); S.i++; S.t=0; }
function dojoMisc(k){ const H=GS.hero; dojoReset(30); 
  if(k==='duck'){ GS.bag=[{ id:'duck', uid:9901, t:99, tier:1, x:0, y:0, rot:0 }]; heroDuck(true); return; }
  if(k.startsWith('hm_')){ requestAction(H, k, { cue:JW_CUE[k], wpn:'w_hammer', onCue:()=>{} }); return; }
  requestAction(H, k, { onCue:()=>{} }); }
function dojoSpc(fam){ dojoReset(30); GS.bag=[{ id:{fist:'punch',foot:'kick',grap:'knee'}[fam], uid:9902, t:0, tier:2, x:0, y:0, rot:0 }]; GS.sp=100; trySpecial(); }
function dojoReact(r){ const D=dojoDummy(); dojoReset(24); face(D,GS.hero.d.x); setAnim(D, r); if(['fall','launch','rKick','rSpin','rSwept','rCharge','rSlam','rStomp','crumple'].includes(r)) D.after='getup'; if(r==='rSpike') D.after='getupP'; }
function dojoFoe(mv){ const gap=mv==='fkick'; dojoReset(gap?85:Math.max(12,wpnReach(mv,ETYPES.punk.wpn)-4)); const D=dojoDummy(); D.e.cdT=0; GS.bag=[{ id:'duck', uid:9903, t:99, tier:1, x:0, y:0, rot:0 }]; GS.manualT=9; foeStrike(D, mv); }
// 무도장 상대(허수아비): 체형을 바꿔 가며 동작을 본다 · 막기 · 피하기는 끈다
const DJ_DUMMY=[['punk','건달'],['heavy','덩치'],['brute','배불뚝이'],['boss4','두목']];
function dojoMakeDummy(t){ const T=ETYPES[t]||ETYPES.punk, e={ t:ETYPES[t]?t:'punk', ...T, hp:99999, max:99999, cdT:0, stun:0, shieldT:0, shield:false, parry:false, evade:0 };
  const D=mkActor(defFor(T,0), { x:274, z:0, flip:true, remap:T.remap, e, pose:'st0' }); D.dojo=true; setAnim(D,'idle'); return D; }
function dojoSetDummy(t){ if(!ETYPES[t]) return; OPT.djDummy=t; optSave(); GS.ents=GS.ents.filter(a=>!(a.e&&a.dojo)); GS.ents.push(dojoMakeDummy(t)); DJ.hit=null; dojoReset(24); }
function startDojo(){ const keep={...RUNCFG}; GS.devStart=true; try{ startRun({stage:0,daily:false}); } finally{ GS.devStart=false; } RUNCFG=keep;   // 무도장은 이어 하기 저장을 지우지 않는다
  hideTitle(true); GS.prologue=null; COMIC.length=0; sayEl.hidden=true;
  GS.demo=true; GS.state='fight'; GS.ents=[GS.hero]; GS.cans=[]; GS.items=[]; GS.shots=[]; GS.ev=null; GS.wave=99; GS.nextWaveAt=1e9; GS.departT=null; TR.phase='stop'; TR.v=0;
  GS.max=GS.hp=9999; GS.ents.push(dojoMakeDummy(OPT.djDummy||'punk')); DJ.hit=null; DJ.last=null; DJ.repT=0; GS.stepReq=0;
  const H=GS.hero; H.d.x=250; H.d.flip=false; H.hidden=false; H.wpn=null; setAnim(H,'idle'); setGameSpeed(1); showDojoPanel(); }
function dojoBagRoute(k){ const r=routesOf(GS.bag)[k]; if(!r) return; let pc=0; dojoRun(r.items.map(o=>o.id==='punch'?['punch',(pc++)%4]:[o.id]), tr(r.name)); }
const DEMO_BAGS=[   // 무도장 콤보 시험 가방: 1 · 월광 질풍 + 짓밟기 3단 / 2 · 새 기술(낙뢰 + 무너뜨려 꽂기)
  { n:'예시 가방 1', L:[['skick',0,0],['punch',1,0],['paper',2,0],['round',3,0],['sweep',0,3],['stomp',3,2],['kick',4,2],['charm',5,1]] },
  { n:'예시 가방 2 · 새 기술', L:[['upper',0,0],['cycle',1,0],['axe',3,0],['suplex',4,0],['punch',5,2],['knee',3,3,1],['charm',0,3]] } ];
function dojoDemoBag(k=0){ const D=DEMO_BAGS[k]||DEMO_BAGS[0];
  GS.bag=D.L.filter(([id])=>GITEMS[id]).map(([id,x,y,rot])=>Object.assign(newItem(id,1,null),{x,y,rot:rot||0})); try{ renderBag(); }catch(e){} }
function stopDojo(){ GS.demo=false; GS.stepReq=0; DJ.rep=false; djLayout(false); const S=loadRunSave();   // 나가면 들어오기 전의 판으로(저장이 없으면 새 판)
  if(S) resumeRun(S); else { startRun({stage:0,daily:false}); hideTitle(true); } setGameSpeed(GAME_SPD); }
// 무도장 화면 배치: 가방 · 행동 줄을 숨기고 패널이 무대 바로 아래부터 채운다
function djLayout(on){ document.body.classList.toggle('dj-on', !!on); const p=document.getElementById('dojoPanel'); if(p && !on) p.hidden=true; if(on) djFit(); }
function djFit(){ const p=document.getElementById('dojoPanel'), st=document.getElementById('stage'); if(!p||p.hidden||!st) return; const sc=st.offsetParent;
  const top=st.offsetTop+st.offsetHeight+6+(sc&&sc!==p.parentElement?sc.offsetTop-sc.scrollTop:0); p.style.setProperty('--dj-top', Math.round(top)+'px'); }
window.addEventListener('resize',()=>{ if(GS.demo) requestAnimationFrame(djFit); });
// 재생 조절: 멈춤 · 한 프레임씩 · 반복
const DJ_PLAY=['cmb','hero','misc','spc','react','foe','broute','ccrun'];
function djDo(a){ if(a.cmb!=null) dojoCombo(+a.cmb); else if(a.hero) dojoHero(a.hero, a.combo!=null&&a.combo!==''?+a.combo:null); else if(a.misc) dojoMisc(a.misc); else if(a.spc) dojoSpc(a.spc); else if(a.react) dojoReact(a.react); else if(a.foe) dojoFoe(a.foe);
  else if(a.broute!=null) dojoBagRoute(+a.broute); else if(a.ccrun) dojoCustomRun(); }
function djPlayState(){ const p=document.getElementById('dojoPanel'); if(!p) return; const pb=p.querySelector('[data-play]'), sb=p.querySelector('[data-step]'), rb=p.querySelector('[data-rep]');
  if(pb){ pb.innerHTML=gamePaused?`<i class="dj-ic play" aria-hidden="true"></i>${tr('재생')}`:`<i class="dj-ic pause" aria-hidden="true"></i>${tr('멈춤')}`; pb.classList.toggle('on',gamePaused); pb.setAttribute('aria-pressed',gamePaused); }
  if(sb) sb.disabled=!gamePaused; if(rb){ rb.classList.toggle('on',!!DJ.rep); rb.setAttribute('aria-pressed',!!DJ.rep); }
  p.querySelectorAll('[data-spd]').forEach(x=>x.classList.toggle('on', Math.abs(playSpeed-(+x.dataset.spd))<.01)); }
// 반복: 둘 다 가만히 선 채로 잠깐 지나면 마지막 동작을 다시
function djRepTick(dt){ if(!DJ.rep || !DJ.last) return; const H=GS.hero, D=dojoDummy(); if(!H||!D) return;
  const calm=!GS.dojoSeq && !GS.spc && !GS.cut && canAct(H) && H.anim==='idle' && !D.jug && !D.held && D.anim==='idle' && !(D.action && !D.action.fired);
  if(!calm){ DJ.repT=0; return; } DJ.repT=(DJ.repT||0)+dt; if(DJ.repT>.8){ DJ.repT=0; djDo(DJ.last); } }
const djMoveName=()=>{ const b=GS.bag.find(x=>x&&x.uid===GS.curSrc), it=b&&GITEMS[b.id]; return it ? tr(it.n) : (GS.hero&&GS.hero.anim)||''; };
function showDojoPanel(){ xcEnsure(); let p=document.getElementById('dojoPanel'); const dev=document.getElementById('device')||document.body;
  if(!p){ p=document.createElement('div'); p.id='dojoPanel'; p.className='dojo'; dev.appendChild(p);
    ['pointerdown','touchstart','mousedown'].forEach(t=>p.addEventListener(t,e=>e.stopPropagation()));
    p.addEventListener('click',e=>{ const b=e.target.closest('button'); if(!b || b.disabled) return; sndInit(); const a=b.dataset;
      if(DJ_PLAY.some(k=>a[k]!=null)){ DJ.last={...a}; DJ.repT=0; p.querySelectorAll('.last').forEach(x=>x.classList.remove('last')); if(b.matches('.dj-mv,.dj-card')) b.classList.add('last'); djDo(DJ.last); djPlayState(); return; }
      if(a.bdemo!=null){ dojoDemoBag(+a.bdemo); showDojoPanel(); }
      else if(a.ccclr){ GS.cc=[]; GS.ccRes=null; ccSave(); ccRender(); } else if(a.dreset){ dojoReset(24); DJ.hit=null; } else if(a.djbg){ const nb=a.djbg==='1'?(DJ.bg==='cross'?'dojo':'cross'):a.djbg; if(nb!==DJ.bg){ DJ.bg=nb; OPT.djbg=DJ.bg; optSave(); xcReset(); } p.querySelectorAll('[data-djbg]').forEach(x=>x.classList.toggle('on',x.dataset.djbg===DJ.bg)); }   // 무도장 ↔ 건널목
      else if(a.dummy){ dojoSetDummy(a.dummy); p.querySelectorAll('[data-dummy]').forEach(x=>x.classList.toggle('on',x===b)); }
      else if(a.zoom){ DJ.zoom=+a.zoom; OPT.djZoom=DJ.zoom; optSave(); p.querySelectorAll('[data-zoom]').forEach(x=>x.classList.toggle('on',x===b)); }
      else if(a.play){ setGameSpeed(gamePaused?playSpeed:0); djPlayState(); }
      else if(a.step){ if(gamePaused) GS.stepReq=(GS.stepReq||0)+1; }
      else if(a.rep){ DJ.rep=!DJ.rep; DJ.repT=0; djPlayState(); }
      else if(a.tab){ OPT.djTab=a.tab; optSave(); p.querySelectorAll('[data-tab]').forEach(x=>{ const on=x===b; x.classList.toggle('on',on); x.setAttribute('aria-selected',on); }); p.querySelectorAll('[data-pane]').forEach(x=>x.hidden=x.dataset.pane!==a.tab); p.scrollTop=0; }
      else if(a.spd){ setGameSpeed(+a.spd); djPlayState(); } else if(a.devt){ openDev(); } else if(a.exit) stopDojo(); }); }
  if(DJ.zoom==null) DJ.zoom=OPT.djZoom||1;
  const G={S:'▶',L:'●',F:'■'}, tab=['combo','custom','move','react'].includes(OPT.djTab)?OPT.djTab:'combo', dm=ETYPES[OPT.djDummy]?OPT.djDummy:'punk';
  const split=n=>{ const k=n.indexOf(' · '); return k<0?[n,'']:[n.slice(0,k),n.slice(k+3)]; };
  const mv=(list,key)=>`<div class="dj-grid">${list.map(([n,v,c])=>`<button type="button" class="dj-mv" data-${key}="${v}"${c!=null?` data-combo="${c}"`:''}>${key==='hero'?`<em aria-hidden="true">${G[croleOf(v)]||''}</em>`:''}${tr(n)}</button>`).join('')}</div>`;
  const pane=(k,html)=>`<section data-pane="${k}"${k===tab?'':' hidden'}>${html}</section>`;
  const seg=(lab,key,list,cur)=>`<span class="dj-lb">${tr(lab)}</span><div class="dj-seg" role="group" aria-label="${tr(lab)}">${list.map(([v,l])=>`<button type="button" data-${key}="${v}" class="${String(cur)===String(v)?'on':''}">${tr(l)}</button>`).join('')}</div>`;
  const routes=routesOf(GS.bag), RTS=routes.length ? `<div class="dj-cards">${routes.map((r,k)=>`<button type="button" class="dj-card" data-broute="${k}" style="--rc:${r.col}"><b>${tr(r.name)}</b><small>${r.items.map(o=>`${G[croleOf(o.id)]||''} ${tr(GITEMS[o.id].n)}`).join(' → ')}</small></button>`).join('')}</div>`
    : `<p class="dj-note">${tr('가방에 시작기 ▶와 이어지는 기술이 있으면 여기에 경로가 생겨요')}</p>`;
  p.innerHTML=`<div class="dj-top">
      <div class="dj-h1"><b>${tr('무도장')}</b><span>${tr('동작을 골라 바로 연습해요')}</span><button type="button" class="dj-exit" data-devt="1">${tr('개발자 도구')}</button><button type="button" class="dj-exit" data-exit="1">${tr('나가기')}</button></div>
      <div class="dj-tools">
        <button type="button" class="dj-tool" data-play="1"></button>
        <button type="button" class="dj-tool" data-step="1" title="${tr('멈춘 상태에서 한 프레임(1/12초)씩')}"><i class="dj-ic step" aria-hidden="true"></i>${tr('한 프레임')}</button>
        <button type="button" class="dj-tool" data-rep="1" title="${tr('마지막 동작을 계속 다시')}"><i class="dj-ic rep" aria-hidden="true"></i>${tr('반복')}</button>
        <span class="dj-gap"></span>
        <button type="button" class="dj-tool" data-dreset="1" title="${tr('위치 초기화')}" aria-label="${tr('위치 초기화')}">↺ ${tr('초기화')}</button>
      </div>
      <div class="dj-tools">${seg('속도','spd',[['.1','0.1×'],['.25','0.25×'],['.5','0.5×'],['1','1×']],'')}${seg('확대','zoom',[['1','1×'],['1.5','1.5×'],['2','2×']],DJ.zoom)}</div>
      <div class="dj-tools">${seg('상대','dummy',DJ_DUMMY,dm)}${seg('배경','djbg',[['dojo','무도장'],['cross','건널목']],DJ.bg)}</div>
      <nav class="dj-line" role="tablist" aria-label="${tr('무도장 메뉴')}">${[['combo','콤보'],['custom','커스텀'],['move','기술'],['react','반응']].map(([k,l])=>`<button type="button" role="tab" data-tab="${k}" aria-selected="${k===tab}" class="${k===tab?'on':''}"><i aria-hidden="true"></i>${tr(l)}</button>`).join('')}</nav>
    </div>
    <div class="dj-body">
    ${pane('combo', `<h4>${tr('콤보 시연')}</h4><div class="dj-cards">${DOJO.combo.map(([n],k)=>{ const [t,r]=split(n); return `<button type="button" class="dj-card" data-cmb="${k}"><b>${tr(t)}</b>${r?`<small>${tr(r)}</small>`:''}</button>`; }).join('')}</div>
      <h4>${tr('지금 가방의 콤보 경로')}</h4>${RTS}<div class="dj-mini">${DEMO_BAGS.map((D,k)=>`<button type="button" data-bdemo="${k}">${tr(D.n)} ${tr('넣기')}</button>`).join('')}</div>`)}
    ${pane('custom', `<h4>${tr('커스텀 콤보')}<small>${tr('최대')} ${CC_MAX}${tr('단')}</small></h4>
      <div class="dj-cc"><div class="dj-slots" id="djSlots"></div>
        <div class="dj-cc-act"><button type="button" class="dj-run" data-ccrun="1">▶ ${tr('실행')}</button><button type="button" class="dj-tool" data-ccclr="1">${tr('지우기')}</button><span class="dj-res" id="djRes"></span></div>
        <p class="dj-note">${tr('동작을 누르면 뒤에 붙어요. 순서 칩을 누르면 빠지고, 끌면 자리를 바꿔요.')}</p>
        <div class="dj-pal">${DOJO.moves.map(([n,v])=>`<span class="dj-chip" data-mv="${v}">${tr(n)}</span>`).join('')}</div></div>`)}
    ${pane('move', `<h4>${tr('주인공 공격')}<small>▶ ${tr('시작기')}  ● ${tr('이음기')}  ■ ${tr('마무리기')}</small></h4>${mv(DOJO.hero,'hero')}<h4>${tr('기타 동작')}</h4>${mv(DOJO.misc,'misc')}<h4>${tr('필살기')}</h4>${mv(DOJO.spc,'spc')}`)}
    ${pane('react', `<h4>${tr('허수아비 반응')}</h4>${mv(DOJO.react,'react')}<h4>${tr('적 공격')}<small>${tr('허수아비가 주인공을 공격')}</small></h4>${mv(DOJO.foe,'foe')}`)}
    </div>`;
  p.hidden=false; djLayout(true); requestAnimationFrame(djFit); djPlayState(); if(!GS.cc) GS.cc=ccLoad(); ccRender(); ccBind(p); }
// 커스텀 콤보: 칩을 끌어 순서를 짠다(탭하면 추가 · 순서 칩 탭은 삭제 · 밖으로 끌어내면 삭제)
const CC_MAX=8;
function ccLoad(){ try{ const v=JSON.parse(localStorage.getItem('dotlab-cc')||'null'); if(Array.isArray(v)) return v.slice(0,CC_MAX); }catch(e){} return ['punch:3','punch:0','punch:1','punch:2','round']; }
function ccSave(){ try{ localStorage.setItem('dotlab-cc', JSON.stringify(GS.cc||[])); }catch(e){} }
function ccLabel(v){ const m=DOJO.moves.find(x=>x[1]===v); return m?tr(m[0]):v; }
function ccRender(){ const el=document.getElementById('djSlots'); if(!el) return; const R=GS.ccRes||[];
  el.innerHTML=(GS.cc||[]).map((v,k)=>`<span class="dj-chip dj-slot ${R[k]||''}" data-k="${k}"><i>${k+1}</i>${ccLabel(v)}</span>`).join('') || `<span class="dj-hint">${tr('여기로 끌어 놓거나 아래 동작을 눌러 추가')}</span>`; }
function ccBind(p){ if(p._ccBound) return; p._ccBound=true; let D=null;
  const slotsEl=()=>document.getElementById('djSlots');
  const dropIndex=(x,y)=>{ const ss=[...slotsEl().querySelectorAll('.dj-slot')]; let n=0; for(const s of ss){ const r=s.getBoundingClientRect(), cy=r.top+r.height/2; if(cy < y-r.height/2 || (Math.abs(cy-y)<=r.height/2 && r.left+r.width/2 < x)) n++; } return n; };
  p.addEventListener('pointerdown',e=>{ const c=e.target.closest('.dj-chip'); if(!c) return; e.preventDefault(); D={ c, mv:c.dataset.mv, k:c.dataset.k!=null?+c.dataset.k:null, x0:e.clientX, y0:e.clientY, moved:false, g:null }; });
  window.addEventListener('pointermove',e=>{ if(!D) return; if(!D.moved && Math.hypot(e.clientX-D.x0,e.clientY-D.y0)>6){ D.moved=true; D.g=document.createElement('div'); D.g.className='dj-ghost'; D.g.textContent=D.c.textContent; document.body.appendChild(D.g); }
    if(D.g){ D.g.style.left=e.clientX+'px'; D.g.style.top=e.clientY+'px'; } });
  window.addEventListener('pointerup',e=>{ if(!D) return; const d=D; D=null; if(d.g) d.g.remove(); const L=GS.cc||(GS.cc=[]);
    if(!d.moved){ if(d.k!=null) L.splice(d.k,1); else if(d.mv && L.length<CC_MAX) L.push(d.mv); }
    else { const r=slotsEl().getBoundingClientRect(), inside=e.clientX>=r.left&&e.clientX<=r.right&&e.clientY>=r.top-6&&e.clientY<=r.bottom+6;
      if(d.k!=null){ const v=L.splice(d.k,1)[0]; if(inside){ let i=dropIndex(e.clientX,e.clientY); L.splice(Math.min(i,L.length),0,v); } }
      else if(inside && d.mv && L.length<CC_MAX){ L.splice(Math.min(dropIndex(e.clientX,e.clientY),L.length),0,d.mv); } }
    GS.ccRes=null; const res=document.getElementById('djRes'); if(res) res.textContent=''; ccSave(); ccRender(); sndInit(); }); }

function jumpTo(k){ if(GS.talk) tkSkip(); hideArrange(); const H=GS.hero; gOverlay.hidden=true; hideTitle(true); hideTransfer(); setGameSpeed(GAME_SPD); GS.cut=null; GS.spc=null; GS.cine=null; GS.bonus=null; sayEl.hidden=true; COMIC.length=0;   // 설정 > 바로 가기
  if(GS.prologue){ GS.prologue=null; if(H){ H.wpn=null; H.hidden=false; H.airOv=0; } restoreKit(); }
  if(GS.demo && k!=='dojo'){ GS.demo=false; GS.stepReq=0; DJ.rep=false; djLayout(false); }   // 무도장에서 다른 곳으로
  if(scene!=='subway'){ setScene('subway'); GS.on=true; }
  if(k && typeof k==='object'){ devStageRun(k.line||0, k.car||0, k.bag||'start'); return; }   // 개발자 도구 · 노선 테스트
  if(k==='bonus'){ loadStage(1); GS.ents=GS.ents.filter(a=>!a.e); GS.bonusDone=false; GS.bonusSt={}; startBonus(); }
  else if(k==='corridor'){ startRun({stage:0,daily:false}); if(!GS.prologue) startPrologue(); }
  else if(k==='dojo'){ startDojo(); }
  else if(k==='tower'){ startTower(); }
  else if(k==='cine'){ startRun({stage:0,daily:false}); if(!GS.prologue) startPrologue(); const P=GS.prologue; P.x=CORR_LEN; P.wi=99; GS.ents=GS.ents.filter(a=>!a.e); GS.hero.d.x=380; } }
