// =========================================================
// 엘리베이터 타워(실험 모드): 한 층 = 한 웨이브. 문이 열리면 타고, 정원을 넘기면 문이 안 닫힌다
// 문이 열려 있는 동안만 밖으로 날려 보낼 수 있다 · 올라가는 동안은 천장 튕기기 · 벽꽝 · 1~10층 시험판
// =========================================================
const TW_FLOORS=[ null,
  { n:'주차장', en:'Parking', fs:'park', col:[1,.62,.28], w:['valet','valet','valet'], d:'나트륨등 아래 발레 요원들이 열쇠를 돌린다' },
  { n:'하역장', en:'Loading Dock', fs:'dock', col:[.82,.9,1], w:['courier','valet','valet'], d:'배달원은 무겁다 — 정원 3칸' },
  { n:'로비', en:'Lobby', fs:'lobby', col:[1,.84,.58], w:['guardL','valet','janitor','valet'], d:'손전등 경비원은 정면을 비추면 막는다 — 뒤를 노려요' },
  { n:'우편실', en:'Mail Room', fs:'mail', col:[.86,1,.92], w:['courier','courier','janitor'], d:'청소부가 바닥을 적신다 — 적이 미끄러진다' },
  { n:'기계실', en:'Machine Room', fs:'mech', col:[1,.28,.18], w:['guardL','guardL','tech'], black:true, d:'전기가 나갔다 — 손전등 불빛만 움직인다' },
  { n:'세탁실', en:'Laundry', fs:'laundry', col:[.55,.82,1], w:['janitor','janitor','courier','valet'], d:'젖은 바닥 · 김 서린 세탁실' },
  { n:'룸서비스', en:'Room Service', fs:'room', col:[1,.74,.48], rest:true, d:'잠깐 쉬어 가요 — 체력 40% · 매점' },
  { n:'경비실', en:'Security', fs:'sec', col:[.45,.66,1], w:['guardL','guardL','tech','valet','valet'], d:'수리 기사가 패널에 붙으면 정전 — 먼저 끊어요' },
  { n:'직원 식당', en:'Staff Canteen', fs:'canteen', col:[.78,1,.86], w:['courier','courier','tech','janitor','valet'], d:'한꺼번에 몰려 탄다 — 정원 초과에 주의' },
  { n:'관리실', en:"Super's Office", fs:'office', col:[1,.8,.52], w:['mgr','guardL','janitor'], boss:true, d:'이 건물의 열쇠를 쥔 사람' },
  // 2구간 식당가
  { n:'푸드코트', en:'Food Court', fs:'food', col:[1,.72,.42], w:['waiter','chef','valet'], d:'웨이터는 멀리서 접시를 던진다 — 숙여서 피해요' },
  { n:'주방', en:'Kitchen', fs:'kitchen', col:[1,.55,.25], w:['chef','chef','waiter'], flame:true, d:'주방장은 프라이팬으로 막는다 — 띄우거나 등 뒤를 노려요' },
  { n:'냉동 창고', en:'Walk-in Freezer', fs:'freezer', col:[.55,.85,1], w:['butcher','janitor','waiter'], ice:true, d:'냉기가 쏟아져 바닥이 언다 — 적이 미끄러진다' },
  { n:'연회장', en:'Banquet Hall', fs:'banquet', col:[1,.84,.55], w:['accountant','accountant','accountant','waiter','guardL'], d:'회계사가 버튼을 누르면 다음 층에 더 탄다 — 먼저 잡아요' },
  { n:'와인 셀러', en:'Wine Cellar', fs:'cellar', col:[1,.5,.25], w:['chef','guardL','tech'], black:true, d:'촛불만 남은 지하 셀러 — 손전등 불빛만 움직인다' },
  { n:'바 라운지', en:'Bar Lounge', fs:'bar', col:[.9,.4,1], w:['waiter','waiter','chef','valet'], strobe:true, d:'네온 조명이 박자마다 칸을 물들인다' },
  { n:'직원 휴게실', en:'Staff Lounge', fs:'lounge', col:[1,.86,.62], rest:true, d:'잠깐 쉬어 가요 — 체력 40% · 매점' },
  { n:'식기 세척실', en:'Dish Room', fs:'dish', col:[.75,.95,1], w:['janitor','chef','butcher','accountant','accountant'], d:'접시 더미와 김 — 젖은 바닥에 미끄러진다' },
  { n:'루프탑 테라스', en:'Rooftop Terrace', fs:'roof', col:[1,.8,.5], w:['waiter','butcher','accountant','accountant','chef'], wind:true, d:'문이 열리면 밤바람이 칸을 밀어붙인다' },
  { n:'총주방장실', en:"Head Chef's Kitchen", fs:'chefroom', col:[1,.6,.3], w:['headchef','chef','waiter'], boss:true, flame:true, d:'불꽃을 다루는 이 건물 주방의 대장' } ];
const TW_TOP=20, TW_LIMIT=7, TW_WT={ valet:1, janitor:1, guardL:2, tech:2, courier:3, mgr:4, chef:2, waiter:1, accountant:1, butcher:3, headchef:4 };
const TW_OT=[ null,   // 야근 단계: 꼭대기를 돌파하면 다음 단계가 열리고, 조건이 하나씩 쌓인다
  { n:'적이 질겨요', en:'Tougher enemies', ap:T=>{ T.hpK*=1.15; } },
  { n:'정원 −1', en:'Capacity −1', ap:T=>{ T.limit-=1; } },
  { n:'정전이 잦아요', en:'More blackouts', ap:T=>{ T.blackSet.add(3); T.blackSet.add(13); } },
  { n:'적이 세져요', en:'Harder hits', ap:T=>{ T.dmgK*=1.2; } },
  { n:'구급함이 비었어요', en:'Empty first-aid box', ap:T=>{ T.kit=false; T.restK=.5; } },
  { n:'두목이 독해요', en:'Ruthless bosses', ap:T=>{ T.bossK*=1.3; for(const n of [10,20]) if(T.waves[n]) T.waves[n].push('guardL'); } } ];
const TW_OT_MAX=TW_OT.length-1, twOtName=l=>l?KE(`야근 ${l}단계`,`Overtime ${l}`):KE('정시','Regular');
const twWt=a=>TW_WT[a.e.t] ?? (a.e.heavy?3:2), twWeight=()=>foes().reduce((s,a)=>s+twWt(a),0);
Object.assign(ETYPES,{   // 1구간(지하 · 로비 · 관리 구역) 적: 생김새 · 동작 · 공략이 서로 다르게
  valet:{ n:'발레 요원', hp:22, dmg:6, cd:1.8, spd:48, remap:6, moves:['jab','kick'], reach:24, hitrun:true, look:{hair:'pomp', coat:'RED', tie:'GOLD'} },
  guardL:{ n:'손전등 경비원', hp:36, dmg:8, cd:2.4, spd:30, remap:5, moves:['bat','jab'], wpn:'it_bat', reach:28, shield:true, lamp:true, look:{hair:'fedora', coat:'SUIT', tie:'GOLD'} },
  courier:{ n:'배달원', hp:50, dmg:10, cd:2.8, spd:24, remap:7, moves:['charge','hook'], wpn:'w_case', reach:26, meat:true, look:{hair:'goggle', coat:'TAXI', fat:true} },
  tech:{ n:'수리 기사', hp:30, dmg:7, cd:2.6, spd:34, remap:4, moves:['bat','jab'], wpn:'w_wrench', reach:28, tech:true, look:{hair:'bandana', coat:'STEEL'} },
  janitor:{ n:'청소부', hp:26, dmg:6, cd:2.2, spd:32, remap:3, moves:['jab','hook'], reach:24, janitor:true, look:{hair:'bald', coat:'IVY'} },
  chef:{ n:'주방장', hp:34, dmg:9, cd:2.4, spd:30, remap:5, moves:['bat','jab'], wpn:'w_pan', reach:28, shield:true, pan:true, look:{hair:'bandana', coat:'CANVAS'} },
  waiter:{ n:'웨이터', hp:22, dmg:7, cd:3.0, spd:30, remap:7, range:120, moves:['throw'], reach:24, look:{hair:'pomp', coat:'SUIT', tie:'RED'} },
  accountant:{ n:'회계사', hp:18, dmg:5, cd:2.0, spd:40, remap:3, moves:['jab'], reach:22, presser:true, look:{coat:'CURT', tie:'ARMOR'} },
  butcher:{ n:'정육사', hp:70, dmg:13, cd:2.8, spd:24, remap:8, moves:['bat','charge'], wpn:'w_cleaver', reach:30, heavy:true, look:{hair:'bald', coat:'BONE', fat:true} },
  headchef:{ n:'총주방장', hp:170, dmg:15, cd:2.3, spd:30, remap:8, moves:['bat','hook','charge','upper'], wpn:'w_pan', reach:30, boss:true, heavy:true, flambe:true, look:{hair:'bandana', coat:'CANVAS', tie:'RED', fat:true} },
  mgr:{ n:'빌딩 관리인', hp:190, dmg:15, cd:2.4, spd:28, remap:8, moves:['bat','charge','hook','upper'], wpn:'w_wrench', reach:30, boss:true, heavy:true, look:{hair:'bald', coat:'COAT', tie:'GOLD', fat:true} } });
const TW_BARKS=['관계자 외 출입 금지예요','이 층에서 내리시죠','정원 초과라고!','열쇠 내놔','경비실, 여기 수상한 놈이','배달 왔습니다 — 주먹으로','엘리베이터는 내 구역이야'];
const TW_MODS=[
  { id:'cap6', n:'정원 6', en:'Capacity 6', ap:T=>{ T.limit=6; } },
  { id:'dark2', n:'정전 층 하나 더', en:'One more blackout floor', ap:(T,r)=>{ const c=[2,3,4,6,8,9]; T.blackSet.add(c[Math.floor(r()*c.length)]); } },
  { id:'rush', n:'배달 폭주', en:'Delivery rush', ap:(T,r)=>{ for(const k in T.waves) T.waves[k]=T.waves[k].map(t=>t==='valet'&&r()<.5?'courier':t); } },
  { id:'guard', n:'경비 강화', en:'Extra security', ap:(T,r)=>{ for(const k in T.waves) if(T.waves[k].length && !TW_FLOORS[k].boss && r()<.6) T.waves[k].push('guardL'); } },
  { id:'mop', n:'청소 시간', en:'Cleaning hour', ap:(T,r)=>{ for(const k in T.waves) if(T.waves[k].length && !TW_FLOORS[k].boss && r()<.6) T.waves[k].push('janitor'); } },
  { id:'wire', n:'배선 공사', en:'Wiring works', ap:T=>{ for(const k of [3,6,9]) if(T.waves[k] && T.waves[k].length) T.waves[k].push('tech'); } } ];
function twDaily(dk){ const r=mulberry(hashStr('tower'+dk)), pool=TW_MODS.slice(), mods=[]; for(let k=0;k<2;k++) mods.push(pool.splice(Math.floor(r()*pool.length),1)[0]); return { r, mods }; }   // 날짜마다 같은 조건 두 개 · 같은 탑승 순서
const twFloorName=n=>{ const F=TW_FLOORS[n]; return F?KE(F.n,F.en):''; };
function startTower(opts={}){ const daily=!!opts.daily, keep={...RUNCFG}; GS.devStart=true; try{ startRun({stage:0,daily}); } finally{ GS.devStart=false; } RUNCFG=keep; GS.devRun=false; GS.daily=daily;   // 오늘의 타워: 오늘의 가방 · 같은 시드 매점
  hideTitle(true); gOverlay.hidden=true; GS.prologue=null; COMIC.length=0; sayEl.hidden=true; GS.ev=null; GS.props=[]; GS.cans=[]; GS.items=[]; GS.shots=[];
  GS.ents=[GS.hero]; GS.state='fight'; GS.wave=99; GS.nextWaveAt=1e9; GS.departT=null; GS.atStop=null; GS.arriving=false; GS.quickStop=null; GS.oneBit=false; GS.trans=null;
  TR.phase='stop'; TR.v=0; TR.a=0; TR.door=0; TR.dy=0; TR.jolt=0;
  const H=GS.hero; H.d.x=140; H.d.flip=false; setAnim(H,'idle');
  GS.tower={ floor:1, phase:'arrive', t:0, door:0, pos:0, vel:0, q:[], qT:0, qn:0, over:false, buzzT:0, dent:[], ceilN:0, lamps:TW_LAMPX.map(()=>({a:0,v:0,hang:false,flick:0})), sag:0, sagV:0,
    kit:true, lurchT:0, blackT:0, blackFloor:false, dark:false, panelT:0, outs:0, wreck:{}, wrecks:0, fly:[], fl:0, shk:0, alarm:0, t0:GS.time, kills0:GS.kills||0,
    limit:TW_LIMIT, waves:{}, blackSet:new Set(TW_FLOORS.map((F,n)=>F&&F.black?n:0).filter(Boolean)), mods:[], daily:null };
  { const T=GS.tower; for(let n=1;n<=TW_TOP;n++) T.waves[n]=(TW_FLOORS[n].w||[]).slice();
    if(daily){ const dk=todayKey(), D=twDaily(dk); T.daily=dk; for(let n=1;n<=TW_TOP;n++) if(!TW_FLOORS[n].boss){ const w=T.waves[n]; for(let i=w.length-1;i>0;i--){ const j=Math.floor(D.r()*(i+1)); [w[i],w[j]]=[w[j],w[i]]; } }
      for(const m of D.mods){ m.ap(T,D.r); T.mods.push(m); } }
    META.tower=META.tower||{ best:0, bestT:0, runs:0 }; T.hpK=1; T.dmgK=1; T.bossK=1; T.restK=1;
    T.ot = daily ? 0 : Math.max(0,Math.min(META.tower.ot||0, opts.ot ?? OPT.twOT ?? 0)); for(let l=1;l<=T.ot;l++) TW_OT[l].ap(T); }   // 야근 단계 조건(누적)
  setGameSpeed(GAME_SPD); try{ sfx.chime(); }catch(e){}
  { const T=GS.tower; say(T.daily?KE('오늘의 타워','Daily Tower')+' · '+T.daily:tr('엘리베이터 타워')+(T.ot?' · '+twOtName(T.ot):''), T.daily ? T.mods.map(m=>KE(m.n,m.en)).join(' · ') : T.ot ? TW_OT.slice(1,T.ot+1).map(o=>KE(o.n,o.en)).join(' · ') : KE('1층 주차장에서 20층 총주방장실까지 · 정원을 넘기면 문이 안 닫혀요','Floor 1 to the 20F head chef · over capacity, the doors stay open'), 3.0); } }
function twArrive(){ const T=GS.tower, F=TW_FLOORS[T.floor]||{}; T.phase='arrive'; T.t=0; T.door=0; T.shopped=false; T.blackFloor=!!(T.blackSet.has(T.floor) && T.blackFloor);
  const M2=META.tower=META.tower||{best:0,bestT:0,runs:0}; if(T.floor>M2.best){ M2.best=T.floor; metaDirty=true; }
  if(T.extra>0 && T.waves[T.floor] && T.waves[T.floor].length && !F.boss){ const pool=T.floor>10?['accountant','waiter','chef']:['valet','janitor','guardL']; for(let k=0;k<T.extra;k++) T.waves[T.floor].push(pool[Math.floor(Math.random()*pool.length)]); T.extra=0; }   // 회계사가 누른 버튼
  GS.tokens+=1; GS.score+=200*T.floor; renderBag(); say(`${T.floor}F · ${twFloorName(T.floor)}`, (T.blackSet.has(T.floor)&&!F.black) ? tr('전기가 나갔다 — 손전등 불빛만 움직인다') : tr(F.d||''), 2.2); }
function twSpawn(t,k){ const T=ETYPES[t]; if(!T) return; const TT=GS.tower, fl=TT.floor, m=(fl<=10?1+.05*(fl-1):1.25+.04*(fl-11))*(TT.hpK||1)*(T.boss?(TT.bossK||1):1), H=GS.hero;
  const x=TWR.G0+24+((k*31)%92), e={ t, ...T, hp:Math.round(T.hp*m), dmg:Math.round(T.dmg*.8*(fl<=10?1+.04*(fl-1):1.2+.03*(fl-11))*(TT.dmgK||1)), cd:T.cd*1.2, cdT:-1.1-k*.35, shieldT:0, stun:0 };
  e.max=e.hp; metaFoe(t); const a=mkActor(defFor(T,k),{ x, z:1+((k*3)%5), flip:x>H.d.x, remap:T.remap, grammar:T.grammar, e, pose:'st0' }); setAnim(a,'idle'); GS.ents.push(a);
  dusts.push({ x, y:SB.FLOOR, age:1, flip:false }); if(T.boss) bossIntro(a); else if(k===0 && Math.random()<.6) bark(a, tr(TW_BARKS[Math.floor(Math.random()*TW_BARKS.length)])); }
// 문밖으로 날린 적: 층 안으로 굴러 들어가 그 층의 물건에 부딪힌다. 처음엔 층이 부서진 모습으로 바뀌고, 그다음부턴 작은 반응
const TW_HIT={ park:[90,56,'WEE-OO!','차 경보',['#c8d0e0','#2c2a1d']], dock:[20,74,'CRASH!','상자 더미',['#a69077','#83705a','#ebe9e4']], lobby:[28,82,'SMASH!','화분',['#47793c','#5e3125','#2f4767']],
  mail:[66,40,'FWOOSH!','우편함',['#ebe9e4','#d6d4cf','#ebe9e4']], mech:[58,24,'PSSSH!','배관',['#ebe9e4','#c2c7df']], laundry:[68,56,'SPLOOSH!','세탁기',['#5fd3d6','#ebe9e4','#c8fbf8']],
  room:[66,74,'CLANG!','룸서비스 카트',['#ebe9e4','#c2c7df','#ff5e95']], sec:[66,30,'ZZZT!','CCTV',['#5fd3d6','#ebe9e4']], canteen:[43,40,'KRSSH!','자판기',['#eb4747','#dcb34a','#4a7c33','#c2c7df']], office:[60,36,'CRACK!','창문',['#ebe9e4','#c2c7df']],
  food:[68,22,'CRASH!','네온 메뉴판',['#ff5e95','#dcb34a','#ebe9e4']], kitchen:[60,44,'CLANG!','육수 냄비',['#dcb34a','#c2c7df','#ebe9e4']], freezer:[42,44,'KRAK!','냉동 선반',['#ebe9e4','#c8fbf8','#f0f2ff']],
  banquet:[100,76,'SMASH!','연회 테이블',['#ebe9e4','#ffc13d','#c2c7df']], cellar:[32,66,'SPLASH!','와인 통',['#891423','#c22131','#7c4923']], bar:[68,34,'KSSH!','술병 선반',['#5fd3d6','#ff5e95','#dcb34a']],
  lounge:[36,46,'BANG!','사물함',['#c2c7df','#9198ba']], dish:[36,62,'KRSSH!','접시 더미',['#ebe9e4','#f0f2ff']], roof:[68,20,'SNAP!','전구 줄',['#fbcf80','#ffe6b8','#2c2a1d']], chefroom:[52,30,'FWOOM!','구리 냄비',['#ffc13d','#ff7a2e','#ebe9e4']] };
function twOut(a){ const T=GS.tower; T.outs++; const F=TW_FLOORS[T.floor]; if(!F || T.phase==='move') return; const h=TW_HIT[F.fs]; if(!h) return;
  const x0=Math.max(TWR.G0+14,Math.min(TWR.G1-14,a.d.x)), y0=a.d.y-34-(a.jug?a.jug.h:0);
  T.fly.push({ x0, y0, x1:TWR.G0+h[0], y1:TWR.GT+h[1], t:0, dur:.5, r0:Math.floor(Math.random()*4) }); }
function twImpact(fl){ const T=GS.tower, F=TW_FLOORS[fl]; if(!F) return; const h=TW_HIT[F.fs]; if(!h) return; const x=TWR.G0+h[0], y=TWR.GT+h[1], first=!T.wreck[fl];
  if(first){ T.wreck[fl]=true; T.wrecks=(T.wrecks||0)+1; }
  const pts=first?600:200; GS.score+=pts; T.fl=first?.5:.25; T.shk=first?.5:.3; shakeAmp=Math.max(shakeAmp||0, first?2.4:1.4);
  HITFX.push({ k:'twfall', x, y, t:0, life:1.1, parts:Array.from({length:first?22:9},()=>({ vx:(Math.random()*2-1)*(first?90:50), vy:-(20+Math.random()*80), s:Math.random()<.5?1:2, c:h[4][Math.floor(Math.random()*h[4].length)] })) });
  HITFX.push({ k:'txt', x:x-24, y:y-18, t:0, life:1.3, text:`+${pts} ${tr(h[3])}${first?'!':''}`, col:first?'#ffe27a':'#ffd0a0' });
  comicT=0; comicSFX(x, y-10, first?h[2]:'BAM!');
  try{ const f=F.fs; if(f==='park'){ T.alarm=first?6:Math.max(T.alarm||0,3); sfx.thud(); } else if(['lobby','canteen','office','room','food','freezer','banquet','bar','dish'].includes(f)){ sfx.glass(); skNoise(.3,1600,.08); } else if(f==='kitchen'||f==='chefroom'){ skTone(1700,900,.35,'triangle',.06); skNoise(.4,900,.08); } else if(f==='cellar'){ skNoise(.6,600,.12); } else if(f==='mech'){ skNoise(.9,5200,.08); sparks.push({x,y,age:0}); } else if(f==='laundry'){ skNoise(.6,800,.1); } else if(f==='sec'){ skNoise(.45,2600,.09); sparks.push({x,y,age:0}); } else if(f==='mail'){ skNoise(.5,3200,.07); } else { sfx.thud(); skNoise(.4,300,.12); } }catch(e){}
  if(first && GS.stats) GS.stats.wrecks=(GS.stats.wrecks||0)+1; }
// 천장 튕기기: 띄운 적이 천장에 부딪혀 꺾여 내려온다 · 천장이 찌그러지고 전등이 흔들린다 · 찌그러짐이 쌓이면 천장판이 떨어져 전등이 매달린다
function twCeil(a,J){ const T=GS.tower; J.h=TWR.CEIL_H; J.vy=-Math.max(90,J.vy*.5); J.hitT=GS.time+.16; a.hs=Math.max(a.hs||0,3); a.shkA=2;
  const x=a.d.x, y=TWR.CEIL+2; sparks.push({ x, y:y+2, age:0 }); sparks.push({ x:x+6, y:y+3, age:1 });
  HITFX.push({ k:'twfall', x, y:y+3, t:0, life:.9, parts:Array.from({length:9},()=>({ vx:(Math.random()*2-1)*50, vy:Math.random()*30, s:Math.random()<.5?1:2, c:Math.random()<.5?'#6e726d':'#2c2a1d' })) });
  comicT=0; comicSFX(x, y+20, tr('쾅!')); try{ sfx.thud(); }catch(e){} shakeAmp=Math.max(shakeAmp||0,2.6); T.sagV+=6;
  if(T.dent.length<7 && !T.dent.some(d=>Math.abs(d-x)<14)) T.dent.push(Math.round(Math.max(TWR.L+10,Math.min(TWR.R-10,x))));
  T.lamps.forEach((L,i)=>{ const d=Math.abs(TW_LAMPX[i]-x); if(d<150){ L.v+=(Math.random()<.5?-1:1)*(1.6+Math.random())*(1-d/150); L.flick=Math.max(L.flick,.25); }
    if(!L.hang && T.dent.filter(dx=>Math.abs(dx-TW_LAMPX[i])<70).length>=2){ L.hang=true; L.v+=2.5; HITFX.push({ k:'twfall', x:TW_LAMPX[i], y:y+2, t:0, life:1.1, parts:Array.from({length:14},()=>({ vx:(Math.random()*2-1)*70, vy:Math.random()*20, s:2, c:'#6e726d' })) }); if(!T.holeSaid){ T.holeSaid=true; say('', tr('천장판이 떨어져 전등이 매달렸다'), 1.6); } } });
  T.ceilN++; GS.stats.ceils=(GS.stats.ceils||0)+1;
  if(a.e && !a.dead){ const dm=Math.max(1,Math.round(5*(1+.06*(T.floor-1)))); if(a.e.hp>dm){ a.e.hp-=dm; GS.stats.dealt+=dm; GS.score+=80; dmgPop(a, Math.round(dm*DMG_K), 'hit', null, '#ffb070'); } }
  if(!T.ceilSaid){ T.ceilSaid=true; hint('tower'); } }
// 적 특수 행동: 수리 기사(패널로 가서 배선을 끊으면 정전) · 청소부(바닥을 적신다) · 관리인(패널을 내리쳐 칸이 덜컹)
function twFoeTick(dt){ const T=GS.tower;
  for(const a of foes()){ const e=a.e;
    if(e.tech){ const ok=!T.dark && !e.techDone && canAct(a) && !a.jug && !isDown(a) && (e.stun||0)<=0 && !a.held;
      e.towerBusy=ok; if(ok){ if(Math.abs(a.d.x-TWR.PX)>6){ face(a,TWR.PX); moveTo(a,TWR.PX,e.spd,dt); }
        else { if(a.anim==='walk') setAnim(a,'idle'); a.d.flip=false; e.work=(e.work||0)+dt; if(Math.random()<dt*4) sparks.push({ x:TWR.PX+2+Math.random()*8, y:146+Math.random()*36, age:1 });
          if(e.work>=5){ e.work=0; e.techDone=true; e.towerBusy=false; T.blackT=10; T.panelT=1.2; comicT=0; comicSFX(TWR.PX, 120, 'ZZT!'); skNoise(.3,2400,.08); say('', tr('수리 기사가 배선을 끊었다 — 정전'), 1.8); } } }
      else if(e.work>0 && !canAct(a)) e.work=Math.max(0,e.work-dt*1.5); }
    if(e.presser){ const ok=!e.pressDone && canAct(a) && !a.jug && !isDown(a) && (e.stun||0)<=0 && !a.held;   // 회계사: 패널로 몰려가 층 버튼을 전부 누른다 → 다음 층에 더 탄다
      e.towerBusy=ok; if(ok){ if(Math.abs(a.d.x-TWR.PX)>6){ face(a,TWR.PX); moveTo(a,TWR.PX,e.spd,dt); }
        else { if(a.anim==='walk') setAnim(a,'idle'); a.d.flip=false; e.work=(e.work||0)+dt; if(e.work>=3){ e.work=0; e.pressDone=true; e.towerBusy=false; T.extra=Math.min(3,(T.extra||0)+1); T.panelT=2.2; comicT=0; comicSFX(TWR.PX, 120, 'BEEP!');
          try{ skTone(1200,1200,.12,'square',.04); setTimeout(()=>skTone(1500,1500,.12,'square',.04),140); }catch(err){} say('', tr('회계사가 버튼을 다 눌렀다 — 다음 층에 더 탄다'), 1.8); } } }
      else if(e.work>0 && !canAct(a)) e.work=Math.max(0,e.work-dt*1.5); }
    if(e.flambe){ e.flT=(e.flT??5)-dt; if(e.flT<=0 && canAct(a) && !a.jug && !isDown(a)){ e.flT=7+Math.random()*2; const Hh=GS.hero, fx=Math.round(Math.max(TWR.L+16,Math.min(TWR.R-16,Hh.d.x+(Math.random()*30-15))));   // 총주방장: 플랑베 — 바닥에 불꽃을 붙인다(불꽃이 광원)
      (T.fires=T.fires||[]).push({ x:fx, t:3.6, hitT:.3 }); if(T.fires.length>3) T.fires.shift(); comicT=0; comicSFX(fx, 150, tr('화르륵!')); try{ skNoise(.7,700,.1); }catch(err){} face(a,Hh.d.x); foeStrike(a,'bat'); } }
    if(e.janitor){ e.mopT=(e.mopT??2.5)-dt; if(e.mopT<=0 && canAct(a) && !a.jug && !isDown(a)){ e.mopT=6+Math.random()*3; const px=Math.round(a.d.x-8);
      GS.props=(GS.props||[]).filter(p=>p.k!=='puddle'||Math.abs(p.x-px)>18); if(GS.props.filter(p=>p.k==='puddle').length<3){ GS.props.push({ k:'puddle', x:px }); comicSFX(a.d.x, a.d.y-70, tr('찰박')); try{ skNoise(.18,700,.05); }catch(err){} } } }
    if(e.t==='mgr'){ e.lurchT=(e.lurchT??7)-dt; if(e.lurchT<=0 && canAct(a) && !a.jug && !isDown(a)){ e.lurchT=9+Math.random()*3; T.lurchT=.8; T.sagV+=14; shakeAmp=Math.max(shakeAmp||0,3.2); T.panelT=1;
      T.lamps.forEach(L=>{ L.v+=(Math.random()<.5?-1:1)*2.2; L.flick=.5; }); comicT=0; comicSFX(240, 130, tr('덜컹!')); try{ sfx.thud(); skNoise(.5,120,.09); }catch(err){} face(a,GS.hero.d.x); foeStrike(a,'charge'); } } } }
function towerTick(dt){ const T=GS.tower, H=GS.hero; if(!T||!H) return; T.t+=dt; const F=TW_FLOORS[T.floor]||{};
  T.sagV+=(-60*T.sag-7*T.sagV)*dt; T.sag+=T.sagV*dt;
  T.lamps.forEach(L=>{ const k=L.hang?5:22, c=L.hang?.35:2.6; L.v+=(-k*L.a-c*L.v)*dt; L.a+=L.v*dt; L.a=Math.max(-.52,Math.min(.52,L.a)); L.flick=Math.max(0,L.flick-dt); });
  T.lurchT=Math.max(0,T.lurchT-dt); T.panelT=Math.max(0,T.panelT-dt); T.fl=Math.max(0,(T.fl||0)-dt*1.6); T.shk=Math.max(0,(T.shk||0)-dt);
  for(const f of T.fly){ f.t+=dt; if(f.t>=f.dur && !f.done){ f.done=true; twImpact(T.floor); } } T.fly=T.fly.filter(f=>!f.done);
  if(T.alarm>0){ T.alarm-=dt; T.alT=(T.alT||0)-dt; if(T.alT<=0){ T.alT=.28; T.alH=!T.alH; try{ skTone(T.alH?920:700,T.alH?920:700,.24,'square',.02); }catch(e){} } }   // 주차장 차 경보
  TR.dy=Math.round(T.sag + (T.lurchT>0?(Math.random()-.5)*4:0) + (T.phase==='move' && T.vel>20 ? Math.sin(T.t*9)*.5 : 0));
  const blk=T.blackSet.has(T.floor); if(T.blackT>0){ T.blackT-=dt; if(T.blackT<=0 && !(blk && T.blackFloor)) say('', tr('전기가 돌아왔다'), 1.4); }
  T.dark=(blk && T.blackFloor) || T.blackT>0;
  if(T.kit && GS.hp<GS.max*.35 && !H.dead){ T.kit=false; const v=Math.round(GS.max*.3); GS.hp=Math.min(GS.max,GS.hp+v); dmgPop(H, v*DMG_K, 'heal'); comicT=0; comicSFX(368, 132, tr('와장창')); try{ sfx.glass(); }catch(e){} say('', tr('비상 구급함 — 체력 30% 회복'), 1.8); }
  twFoeTick(dt);
  if(T.fires && T.fires.length){ for(const f of T.fires){ f.t-=dt; f.hitT-=dt; if(f.hitT<=0){ f.hitT=.6; const src={ d:{ flip:false, x:f.x, y:SB.FLOOR, rig:{} } };   // 불꽃: 밟은 사람은 데인다(적도)
        if(Math.abs(H.d.x-f.x)<14 && !H.dead && !heroAirborne(H)) damage(src, H, Math.round(4*(T.dmgK||1)), { react:'body' });
        for(const a of foes()) if(!a.e.boss && Math.abs(a.d.x-f.x)<14 && !a.jug && !isDown(a)) damage(src, a, 4, { react:'body' }); } } T.fires=T.fires.filter(f=>f.t>0); }
  if(F.wind && T.phase!=='move' && T.door>.5){ T.windT=(T.windT??1.2)-dt; if(T.windT<=0){ T.windT=3.2+Math.random()*1.4; T.gust=1.3; T.gdir=-(T.gdir||1); comicT=0; comicSFX(240, 140, tr('휘잉!')); try{ skNoise(1.3,260,.09); }catch(e){}   // 루프탑: 밤바람이 칸을 민다
      HITFX.push({ k:'twfall', x:240, y:150, t:0, life:1.4, parts:Array.from({length:10},()=>({ vx:T.gdir*(110+Math.random()*130), vy:-(30+Math.random()*60), s:2, c:'#ebe9e4' })) }); } }
  if(T.gust>0){ T.gust-=dt; for(const a of GS.ents){ if(a.held || a.pass || a.dead || !a.d) continue; a.d.x+=(T.gdir||1)*(a===H?16:34)*dt; } T.lamps.forEach(L=>L.v+=T.gdir*dt*2.2); }
  if(T.phase==='move'){ const tgt=T.floor*TWR.FH, nf=foes().length, vmax=nf?62:230, rem=tgt-T.pos, dec=90;
    if(rem<=T.vel*T.vel/(2*dec)+1) T.vel=Math.max(10,T.vel-dec*dt); else T.vel=Math.min(vmax+40,Math.max(0,T.vel+(T.vel<vmax?(nf?70:150):-160)*dt));   // 빈 칸은 빨리
    T.pos=Math.min(tgt,T.pos+T.vel*dt); T.hum=(T.hum||0)+dt; if(T.hum>.6){ T.hum=0; try{ skNoise(.6,80,.025); }catch(e){} }
    if(T.pos>=tgt){ T.pos=tgt; T.vel=0; T.floor++; T.sagV+=5; twArrive(); } return; }
  if(T.phase==='arrive'){ if(T.t>.45){ T.phase='open'; T.t=0; try{ skTone(1318,1318,.4,'sine',.05); setTimeout(()=>skTone(1046,1046,.55,'sine',.045),190); }catch(e){} } return; }
  if(T.phase==='open'){ T.door=Math.min(1,T.door+dt*1.7); if(T.door>=1){ T.phase=F.rest?'rest':'board'; T.t=0; T.q=(T.waves[T.floor]||[]).slice(); T.qn=0; T.qT=.15;
      if(F.ice){ for(const x of [128,226,330]) if(!(GS.props||[]).some(p=>Math.abs(p.x-x)<20)) (GS.props=GS.props||[]).push({ k:'puddle', x, ice:true }); comicSFX(240, 150, tr('쩍')); }   // 냉동 창고: 냉기에 바닥이 언다
      if(blk){ T.blackFloor=true; try{ skNoise(.4,1800,.06); }catch(e){} T.lamps.forEach(L=>L.flick=.6); }
      if(!T.hinted && T.q.length){ T.hinted=true; setTimeout(()=>hint('tower'),1600); } } return; }
  if(T.phase==='board'){ T.qT-=dt; if(T.q.length && T.qT<=0 && foes().length>=6){ T.q.length=0; const A=foes().find(f=>!f.e.boss); if(A) bark(A, tr('꽉 찼네 — 다음 거 탈게')); }   // 칸이 미어터지면 나머지는 다음 엘리베이터를 기다린다
    if(T.q.length && T.qT<=0){ twSpawn(T.q.shift(), T.qn++); T.qT=.42; } if(!T.q.length && T.t>.7){ T.phase='hold'; T.t=0; } return; }
  if(T.phase==='hold'){ const over=twWeight()>T.limit; T.over=over;
    if(over){ T.buzzT-=dt; if(T.buzzT<=0){ T.buzzT=.75; try{ skTone(200,192,.34,'square',.035); }catch(e){} } T.t=0; return; }   // 정원 초과: 삐 — 문이 안 닫힌다
    if(T.t>(F.boss?1.2:foes().length?1.4:.8)){ T.phase='close'; T.t=0; } return; }
  if(T.phase==='rest'){ if(T.t>.9 && !T.shopped){ T.shopped=true; GS.state='shop'; openShop(); } return; }
  if(T.phase==='close'){ T.over=false; T.door=Math.max(0,T.door-dt*1.7);
    if(T.door<=0){ try{ sfx.clack(); }catch(e){} T.sagV+=4; if(F.boss){ T.phase='boss'; T.t=0; } else if(T.floor>=TW_TOP){ T.phase='clear'; T.t=0; } else { T.phase='move'; T.t=0; T.vel=0; } } return; }
  if(T.phase==='boss'){ if(!foes().length){ GS.flash='CLEAR'; GS.flashT=1.2; try{ sfx.clear(); }catch(e){}
      if(T.floor>=TW_TOP){ T.phase='clear'; T.t=0; } else { const z=Math.ceil(T.floor/10); GS.tokens+=4; renderBag(); say(KE(`${z}구간 돌파!`,`Zone ${z} cleared!`), KE(`토큰 +4 · 매점에서 하나 골라요 — ${T.floor+1}층부터 다음 구간`,`+4 tokens · pick one at the shop — next zone from ${T.floor+1}F`), 2.2); T.phase='zone'; T.t=0; } } return; }   // 구간 돌파: 토큰 · 매점(회복 + 하나 고르기) 뒤 계속 오른다
  if(T.phase==='zone'){ if(T.t>1.8 && !T.zoneShop){ T.zoneShop=true; GS.state='shop'; openShop(); } return; }
  if(T.phase==='clear'){ if(T.t>2.6 && !T.done){ T.done=true; towerResult(true); } return; } }
// 결과: 도달 층 · 걸린 시간 · 문밖으로 날린 적 · 천장 튕기기 · 최고 기록
function towerResult(win){ const T=GS.tower; if(!T || GS.state==='over') return; GS.state='over'; hideArrange(); sayEl.hidden=true; sayT=0;
  const fl=win?TW_TOP:T.floor, secs=Math.max(0,Math.round(GS.time-T.t0)), M2=META.tower=META.tower||{best:0,bestT:0,runs:0}; M2.runs=(M2.runs||0)+1;
  const prevB=M2.best||0, prevT=M2.bestT||0; if(fl>prevB) M2.best=fl; const fast=win && (!prevT || secs<prevT); if(fast) M2.bestT=secs;
  let lvBest=null, lvNew=false, unlocked=0; if(!T.daily){ const LV=M2.lv=M2.lv||{}, c=LV[T.ot||0]; lvNew=!c || fl>c.f || (fl===c.f && secs<c.t); if(lvNew) LV[T.ot||0]={ f:fl, t:secs }; lvBest=LV[T.ot||0];
    if(win){ const nx=Math.min(TW_OT_MAX,(T.ot||0)+1); if(nx>(M2.ot||0)){ M2.ot=nx; unlocked=nx; } } }   // 야근 단계별 기록 · 꼭대기 돌파 때 다음 단계 열림
  let dBest=null, dNew=false; if(T.daily){ const D=M2.daily=M2.daily||{}, c=D[T.daily]; dNew=!c || fl>c.f || (fl===c.f && secs<c.t); if(dNew) D[T.daily]={ f:fl, t:secs }; dBest=D[T.daily]; }   // 오늘의 타워 기록
  metaDirty=true; try{ metaSave(); }catch(e){}
  const mmss=s=>`${Math.floor(s/60)}:${String(s%60).padStart(2,'0')}`, kills=(GS.kills||0)-(T.kills0||0), newRec=fl>prevB||fast||dNew||lvNew;
  gOverlay.innerHTML=`<div class="g-card tw-res"><p class="tw-k">${T.daily ? `${KE('오늘의 타워','Daily Tower')} · ${T.daily}` : `${tr('엘리베이터 타워')} · ${twOtName(T.ot||0)}`}</p>${T.ot&&!T.daily?`<div class="tw-mods">${TW_OT.slice(1,T.ot+1).map(o=>`<b>${KE(o.n,o.en)}</b>`).join('')}</div>`:''}${T.daily?`<div class="tw-mods">${T.mods.map(m=>`<b>${KE(m.n,m.en)}</b>`).join('')}</div>`:''}
    <h3>${win?KE(`${TW_TOP}층 ${twFloorName(TW_TOP)} 돌파!`,`Cleared ${TW_TOP}F!`):KE(`${fl}층에서 멈췄다`,`Stopped at ${fl}F`)}</h3>${newRec?`<p class="tw-new">${KE('새 기록','New record')}</p>`:''}${unlocked?`<p class="tw-new ot">${KE(`야근 ${unlocked}단계가 열렸어요`,`Overtime ${unlocked} unlocked`)} — ${KE(TW_OT[unlocked].n,TW_OT[unlocked].en)}</p>`:''}
    <div class="tw-big"><b>${fl}F</b><span>${twFloorName(fl)}</span></div>
    <dl class="tw-st"><dt>${KE('걸린 시간','Time')}</dt><dd>${mmss(secs)}</dd><dt>${KE('쓰러뜨린 적','Defeated')}</dt><dd>${kills}</dd><dt>${KE('문밖으로 날림','Thrown out')}</dt><dd>${T.outs}</dd><dt>${KE('천장 튕기기','Ceiling bounces')}</dt><dd>${T.ceilN}</dd><dt>${KE('부순 층','Floors wrecked')}</dt><dd>${T.wrecks||0}</dd>
      ${dBest?`<dt>${KE('오늘 최고','Today best')}</dt><dd>${dBest.f}F · ${mmss(dBest.t)}</dd>`:''}${lvBest?`<dt>${twOtName(T.ot||0)} ${KE('최고','best')}</dt><dd>${lvBest.f}F · ${mmss(lvBest.t)}</dd>`:''}<dt>${KE('최고 층','Best floor')}</dt><dd>${M2.best}F</dd></dl>
    ${win?`<p class="tw-note">${KE('21층부터는 아직 공사 중이에요','Floors 21+ are still under construction')}</p>`:''}
    <div class="mm-act"><button type="button" class="btn primary" data-tw="again">${KE('다시 오르기 ▶','Climb again ▶')}</button><button type="button" class="btn" data-tw="menu">${KE('메뉴','Menu')}</button></div></div>`;
  gOverlay.hidden=false; gOverlay.querySelectorAll('[data-tw]').forEach(b=>b.onclick=()=>{ sndInit(); try{ sfx.click(); }catch(e){} if(b.dataset.tw==='again') startTower({ daily:!!T.daily, ot:T.ot||0 }); else openMenu('tower'); }); }
// 화면 위 정보: 층 · 이름 · 정원 칸 · 최고 기록 · 시간 · 정원 초과 띠
function drawTowerTop(){ const T=GS.tower; if(!T) return; const F=TW_FLOORS[T.floor]||{}, cx=uiCx, wt=twWeight(), LIM=T.limit||TW_LIMIT, over=wt>LIM, blink=Math.floor(GS.time*4)%2;
  cx.save(); cx.textBaseline='top'; cx.fillStyle='rgba(8,6,14,.72)'; cx.fillRect(5,5,132,33);
  cx.font='bold 14px Galmuri11,monospace'; cx.fillStyle='#ffd34a'; const fl=`${T.floor}F`; cx.fillText(fl,10,8); const fw=cx.measureText(fl).width;
  cx.font='10px Galmuri9,monospace'; cx.fillStyle='#e9e4f7'; cx.fillText(twFloorName(T.floor),15+fw,11); if(T.daily||T.ot){ const nw=cx.measureText(twFloorName(T.floor)).width, tg=T.daily?KE('오늘','DAILY'):KE(`야근${T.ot}`,`OT${T.ot}`); cx.fillStyle=T.daily?'#ffd34a':'#ff7a5c'; cx.fillRect(19+fw+nw,10,cx.measureText(tg).width+6,12); cx.fillStyle='#2a1a10'; cx.fillText(tg,22+fw+nw,11); }
  cx.fillStyle=over?(blink?'#ff6a5a':'#ffd0c0'):'#a99fc2'; cx.fillText(KE('정원','Load'),10,25);
  const n=Math.max(LIM,Math.min(12,wt)); for(let k=0;k<n;k++){ cx.fillStyle = k>=LIM ? (blink?'#ff5a4a':'#7a2420') : k<wt ? (over?'#ff8a5a':'#ffd34a') : '#2a2440'; cx.fillRect(38+k*7,27,5,6); }
  cx.fillStyle=over?'#ff8a7a':'#cfc6e6'; cx.fillText(`${wt}/${LIM}`,40+n*7,25);
  const secs=Math.max(0,Math.floor(GS.time-T.t0)), tm=`${Math.floor(secs/60)}:${String(secs%60).padStart(2,'0')}`, best=Math.max(T.daily ? (((META.tower||{}).daily||{})[T.daily]||{}).f||0 : ((((META.tower||{}).lv||{})[T.ot||0])||{}).f||0, T.floor);
  cx.textAlign='right'; cx.fillStyle='rgba(8,6,14,.6)'; const rt=`${KE('최고','BEST')} ${best}F · ${tm}`, rw=cx.measureText(rt).width; cx.fillRect(VW-rw-10,22,rw+6,13); cx.fillStyle='#cfc6e6'; cx.fillText(rt,VW-7,24); cx.textAlign='left';
  if(over && T.phase==='hold'){ const t=KE('정원 초과 — 문이 열린 동안 밖으로 날려요','Over capacity — throw them out while the doors are open'), w=cx.measureText(t).width; cx.fillStyle=blink?'rgba(150,24,18,.88)':'rgba(110,18,14,.88)'; cx.fillRect(VW/2-w/2-6,44,w+12,15); cx.fillStyle='#ffe0d0'; cx.fillText(t,VW/2-w/2,47); }
  for(const a of foes()){ const e=a.e; if(!(e.tech||e.presser) || !(e.work>0)) continue; const bx=Math.round(a.d.x-CAMX-10), by=a.d.y-78; cx.fillStyle='#120c16'; cx.fillRect(bx-1,by-1,22,5); cx.fillStyle=e.presser?'#ffd34a':'#7cd4ff'; cx.fillRect(bx,by,Math.round(20*Math.min(1,e.work/(e.presser?3:5))),3); }
  cx.restore(); }

