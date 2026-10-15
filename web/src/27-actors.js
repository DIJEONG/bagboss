// 열차 상태: 속도 v · 가속 a · 누적 거리 ex · 상태(phase) · 레일 이음매 덜컹 · 손잡이 진자 · 문 열림
const TR={ v:0, a:0, ex:0, phase:'stop', t:0, joint:0, bumps:[], jolt:0, dy:0, strap:0, strapV:0, door:0, station:-1, stopAt:0, flick:0 };
const adj=i=>{ const x=i%COLS, y=(i/COLS)|0, o=[]; if(x>0) o.push(i-1); if(x<COLS-1) o.push(i+1); if(y>0) o.push(i-COLS); if(y<ROWS-1) o.push(i+COLS); return o; };
const has=k=>GS.bag.filter(b=>b&&GITEMS[b.id].kind===k).length;
function sStats(i){ const b=GS.bag[i], it=GITEMS[b.id]; let gem=0, stone=0, gb=0, sb=0, cr=CRIT_BASE, cdm2=CRITD_BASE, pins=0, rings=0, metros=0, cuffs=0;
  for(const o of adjItems(i)){ const k=GITEMS[o.id].kind, t=o.tier||1; if(k==='gem'){ gem++; gb+=.25+.08*(t-1); } if(k==='stone'){ stone++; sb+=.18+.05*(t-1); }   // 닿은 부적 · 캔커피
    if(k==='crit'){ pins++; cr+=.12+.04*(t-1); } if(k==='critd'){ rings++; cdm2+=.40+.15*(t-1); } }                                  // 닿은 넥타이핀 · 인장 반지
  { const mc=cellsOf(b); for(const o of GS.bag){ if(o===b) continue; const k=GITEMS[o.id].kind; if(k!=='metro'&&k!=='cuff') continue; const D=dirRel(mc,cellsOf(o)), t=o.tier||1;
      if(k==='metro'&&D.v){ sb+=.12+.03*(t-1); metros++; } if(k==='cuff'&&D.d&&!D.o){ cr+=.10+.03*(t-1); cuffs++; } } }
  const imp=impOf(b); if(imp.pocket) cr+=.08;
  const op=b.opt||{}; if(op.k==='crit') cr+=op.v; if(op.k==='critd') cdm2+=op.v; if(op.k==='dmg') gb+=op.v; if(op.k==='cd') sb+=op.v;
  const set=inSet(b), cdm=tCd(b.tier)*(1-Math.min(.6,sb))*(1-Math.min(.3,pv('shoes',.10,.02)))*(set?.9:1)*(imp.holster?.9:1);
  return { dmg:(it.dmg||0)*tDmg(b.tier)*(1+gb)*(it.fist?1+pv('knuckle',.25,.08):1)*(set?1.2:1)*(imp.worn?.8:1), cd:Math.max(it.cd*.35, it.cd*cdm), gem, stone, set, crit:Math.min(.75,cr), critD:cdm2, pins, rings, metros, cuffs, imp }; }
const heroMax=()=>120+Math.round(pv('armor',30,15)), heroSpd=()=>46*(1+pv('shoes',.3,.05));
// --- 인물 ---
const PASS_MODEL=[noirModel({cap:true}), noirModel({hatMat:M.SUIT}), noirModel({cap:true, coat:M.SUIT})];
function mkActor(def,o){ const d={...def, x:o.x, y:FLOOR+(o.z||0), flip:!!o.flip};
  return { d, anim:'idle', si:0, hold:6, pose:o.pose||'m_idle0', prev:o.pose||'m_idle0', k:0, phaseN:6, flash:0, lastR:0, scarfHold:0, scarfF:0, blink:false, jw:null,
    hidden:false, dead:false, remap:o.remap||0, wpn:null, grammar:o.grammar||null, action:null, queue:[], after:null, z:o.z||0, kb:0, e:o.e||null, gph:0, pass:!!o.pass, tilt:0 }; }
const PASSENGERS={ commute:[[60,'sit'],[200,'sit'],[240,'strap'],[300,'sit'],[420,'strap']], night:[[230,'sleep'],[410,'sit']], ads:[[60,'strap'],[280,'sit']],
  cargo:[[120,'sit'],[350,'sit']], works:[], cab:[], dark:[[200,'sit']], show:[[60,'sit'],[200,'sit'],[260,'strap'],[300,'sit'],[420,'sit']] };
const SPOTS=[[50,'sit'],[80,'sit'],[190,'sit'],[220,'strap'],[250,'sit'],[300,'sit'],[400,'sit'],[430,'strap']];
function enterCar(i, carry){
  const L=LINE[i], C=CAR_CONCEPTS[L.car], keep = carry ? foes() : []; GS.ci=i; GS.wave=0; GS.waveT=1.2; GS.nextWaveAt=1.2; GS.legT=0; GS.clearT=null; GS.arriving=false; GS.state='fight'; GS.fade=1; GS.items=[]; GS.shots=[]; GS.cans=[];
  const H=GS.hero, hx=H.d.x; H.d.x = (GS.on && hx>0) ? Math.max(30,Math.min(SB.W-30,hx)) : (carry?120:40); H.z=3; H.kb=0; H.rest=null; GS.ents=[H]; GS.filler=0;
  keep.forEach((a,k)=>{ a.d.x=Math.max(16,Math.min(SB.W-16,a.d.x||16+k*14)); a.kb=0; a.action=null; a.queue=[]; setAnim(a,'idle'); GS.ents.push(a); });   // 못 잡은 적이 통로로 따라 들어온다
  if(GS.stash.length && GS.bag.length){ const n=autoPack(); if(n) say('', `보류함의 ${n}개를 서류가방 빈자리에 넣었어요`, 1.6); }   // 칸을 옮길 때 남은 물건은 맞는 자리에
  (PASSENGERS[C.key]||[]).forEach(([x0,pose],k)=>{ const def={...NOIR_THUG, model3:PASS_MODEL[k%3], name:'승객'}, x=inDoor(x0)?outDoor(x0):x0;   /* 문 앞엔 세우지 않는다 */
    const a=mkActor(def,{x,z:pose==='strap'?1:-2,flip:k%2===1,remap:[0,6,7,5][k%4],pass:true,pose:pose==='sleep'?'death2':pose==='sit'?'sb_sit':'sb_strap'});
    a.passPose=pose==='sleep'?'death2':pose==='sit'?'sb_sit':'sb_strap'; if(pose==='sleep') a.z=-16; a.idle = pose==='sit' ? ['paper','phone','doze',null][(k+GS.ci)%4] : pose==='strap' ? (k%2?'phone':null) : null; setAnim(a,'pass'); GS.ents.push(a); });
  if(C.key==='night') for(let k=0;k<3;k++) GS.cans.push({x:120+k*110,v:0});
  propsInit(C); GS.pt=null; legEvent();
  if(GS.oneBit==null){ GS.oneBit=false; const k=PRESETS.findIndex(p=>p.scene==='noir'); if(k>=0) loadPreset(k); }
  { const want=!!C.oneBit; if(GS.trans && GS.trans.to!==want){ GS.trans=null; GS.lightK=1; GS.emitK=1; }      /* 진행 중이던 다른 전환은 취소 */
    if(GS.oneBit!==want && !(GS.trans && GS.trans.to===want)){ GS.trans={ to:want, t:0 }; GS.fade=0; } }       // 암전 연출: 꺼짐 → (가장 어두울 때 화면 방식 전환) → 켜짐
  say(`${STAGE.short} · ${i+1}호차 · ${C.name}`, i===0 ? STAGE.intro : C.desc, 3.2);
}
const FOE_CAP=()=>7+Math.min(2,GS.stageIdx||0);                                                 // 한 칸에 동시에 있을 수 있는 적(스테이지마다 +1)
const legDur=L=> L.dur || (L.end ? 64 : (L.bridge ? 48 : 44) + 6*((L.quick||[]).length));
function startBoard(){ GS.undo=[]; GS.contrib={}; setTimeout(saveRun,300); const L=LINE[GS.ci], carry=foes().length; GS.wipe={ t:0, label:`→ ${GS.ci+2}호차` }; sfx.door(false);
  enterCar(GS.ci+1, true); GS.fade=0; GS.leg=GS.ci; GS.legStart=TR.ex; GS.qi=0;   /* 통로 문이 가려 주니 검은 페이드는 없이 */
  const extra = carry ? Array.from({length:1+Math.floor(carry/4)},()=>STAGE.reinf[Math.floor(Math.random()*STAGE.reinf.length)]) : [];
  const base = carry ? (L.fight||[]).slice(0,1) : (L.fight||[]);                               /* 지각이면 승차 적은 1명 + 지원군(이중 벌점 없이) */
  const room=Math.max(0,FOE_CAP()-foes().length), list=[...base, ...extra].slice(0,room); if(list.length){   /* 꽉 찼으면 더 타지 않는다 */ spawnWave(list,true); say(carry?'지원군이 탔다!':'적이 탔다!', list.map(t=>ETYPES[t].n).join(' · '), 1.8); }
  GS.state='board'; GS.boardT=2.2; GS.doorWant=true; GS.nextStop=(LINE[GS.ci]||{}).stop; }
function boardAt(enemies){
  const pass=GS.ents.filter(a=>a.pass&&!a.hidden&&a.goal==null), door=x=>DOORS.reduce((b,[d0,d1])=>Math.abs((d0+d1)/2-x)<Math.abs(b-x)?(d0+d1)/2:b, 9999);
  pass.sort(()=>Math.random()-.5).slice(0, Math.floor(Math.random()*3)).forEach(a=>{ a.goal=door(a.d.x); a.exiting=true; a.z=0; setAnim(a,'walk'); });   // 내리는 사람
  const n=1+Math.floor(Math.random()*3), taken=x=>GS.ents.some(o=>o.pass&&!o.exiting&&Math.abs((o.goal??o.d.x)-x)<16);
  for(let k=0;k<n;k++){ const free=SPOTS.filter(([x])=>!taken(x)); if(!free.length) break; const [gx,pose]=free[Math.floor(Math.random()*free.length)], dx=DOORS[k%2];
    const def={...NOIR_THUG, model3:PASS_MODEL[(k+GS.uid)%3], name:'승객'}, a=mkActor(def,{x:(dx[0]+dx[1])/2, z:0, flip:gx<(dx[0]+dx[1])/2, remap:[0,6,7,5][(k+GS.ci)%4], pass:true, pose:'b_walk0'});
    a.passPose = pose==='sit'?'sb_sit':'sb_strap'; a.goal=gx; a.goalZ = pose==='sit'?-2:1; setAnim(a,'walk'); GS.ents.push(a); }        // 타는 사람
  if(enemies && enemies.length){ spawnWave(enemies,true); say('적이 탔다!', enemies.map(t=>ETYPES[t].n).join(' · '), 1.8); }
}
const STRAP_X=(()=>{ const o=[]; for(let x=18;x<SB.W-18;x+=26) if(!DOORS.some(([a,b])=>x>a-6&&x<b+6)) o.push(x); return o; })();
const inDoor=x=>DOORS.some(([a,b])=>x>a-8&&x<b+8), outDoor=x=>{ for(const [a,b] of DOORS) if(x>a-8&&x<b+8) return x<(a+b)/2 ? a-10 : b+10; return x; };
function passengerUpdate(a,dt){
  if(a.goal==null && !a.dancer && (a.passPose==='sb_sit'||a.passPose==='sb_sitc')){ const near=GS.ents.some(o=>!o.pass && !o.dead && Math.abs(o.d.x-a.d.x)<40 && !['idle','walk'].includes(o.anim));
    const want=near?'sb_sitc':'sb_sit'; if(a.passPose!==want){ a.passPose=want; setAnim(a,'pass'); } }
  if(a.idle==='doze' && a.goal==null) a.tilt += (Math.sin(GS.time*1.1+a.d.x)>.55 ? .16 : 0);
  if(a.goal==null && !a.exiting && TR.door>.05 && inDoor(a.d.x)){ a.goal=outDoor(a.d.x); a.goalZ=a.z; setAnim(a,'walk'); return; }      // 문이 열리면 문 앞에서 비켜선다
  if(a.goal==null && a.passPose==='sb_strap' && a.anim==='pass' && a.handDX!=null && a.strapX==null){                                    // 손이 손잡이 고리 아래 오게
    const hx=a.d.x+a.handDX, sx=STRAP_X.reduce((b,x)=>Math.abs(x-hx)<Math.abs(b-hx)?x:b, STRAP_X[0]); a.strapX=sx; a.d.x+=sx-hx; }
  if(a.goal==null) return;
  face(a,a.goal); const there=moveTo(a,a.goal,30,dt);
  if(there){ if(a.exiting){ a.hidden=true; return; } a.goal=null; a.z=a.goalZ??0; a.d.flip=Math.random()<.5; a.handDX=null; a.strapX=null; setAnim(a,'pass'); }
}
const LOOK_CACHE=new Map();
function defFor(T,k){ const L=T.look; if(!L) return T.boss?JW_BOSS:JW_THUG;
  const hair=Array.isArray(L.hair)?L.hair[(k+GS.uid)%L.hair.length]:L.hair, key=[hair,L.fat,L.coat,T.boss,L.tie,L.mandarin].join('|');
  if(!LOOK_CACHE.has(key)) LOOK_CACHE.set(key, { ...(T.boss?JW_BOSS:JW_THUG), name:T.n, model3:noirModel({suit:true, coat:M[L.coat||'COAT'], hair, fat:L.fat, tie:L.tie, mandarin:L.mandarin}) });
  return LOOK_CACHE.get(key); }
function spawnWave(list, fromDoors){
  const sg=GS.stageIdx||0, m=(1+.12*GS.ci)*(1+.25*sg), hx=GS.hero?GS.hero.d.x:40;
  const dL=hx-22, dR=SB.W-22-hx, nearL = dL<dR ? dL>=70 : dR<70;   // 첫 적은 주인공에게 가까운 쪽 끝 문에서(70px 안이면 반대쪽) · 다음 적은 반대쪽 — 양쪽에서 번갈아
  list.forEach((t,k)=>{ const T=ETYPES[t], left = fromDoors ? false : (k%2===0 ? nearL : (nearL ? dR>=70 ? false : true : dL>=70 ? true : false)),
    x = fromDoors ? DOORS[k%2][0]+17 : (left? 22+(k>2?14:0) : SB.W-22-(k>1?18*(k-1):0));
    const e={ t, ...T, hp:Math.round(T.hp*m), dmg:Math.round(T.dmg*.8*(1+.08*GS.ci)*(1+.15*(GS.stageIdx||0))), cd:T.cd*1.2, cdT:-.8-k*.6, shieldT:0, stun:0 }; // 프레임 단위 동작으로 바뀐 뒤 균형
    e.max=e.hp; metaFoe(t); const a=mkActor(defFor(T,k),{x,z:1+((k*3)%5),flip:!left,remap:T.remap,grammar:T.grammar,e,pose:'st0'});
    GS.ents.push(a); if(T.boss) bossIntro(a); else if(k===0 && Math.random()<.7) bark(a, BARKS[Math.floor(Math.random()*BARKS.length)]); });
}
const foes=()=>GS.ents.filter(a=>a.e && !a.dead);
const canAct=c=>c.anim==='idle'||c.anim==='walk';
const holding=c=> c && c.anim==='throw' && GS.ents.some(a=>a.held && a.held.by===c);
// 잡아 던지는 동안엔 방향을 바꾸지 않는다
function face(c,tx){ if(holding(c)) return; c.d.flip = tx < c.d.x; }
function moveTo(c,tx,spd,dt){ const dx=tx-c.d.x; if(Math.abs(dx)<1.5){ if(c.anim==='walk') setAnim(c,'idle'); return true; }
  const mx=Math.sign(dx)*Math.min(Math.abs(dx),spd*dt); c.d.x+=mx; c.gph=(c.gph||0)+Math.abs(mx)/(4*.3*24)*((mx*(c.d.flip?-1:1))<-.01?-1:1);
  if(c.anim==='idle') setAnim(c,'walk'); return false; }
// 대시 접근: 멀리 있으면 달려서 붙는다 — 다리는 달리기 자세(보폭 위상은 달리기 주기) · 출발 먼지 · 주인공은 속도선
function runTo(c,tx,spd,dt){ const dx=tx-c.d.x; if(Math.abs(dx)<1.5){ if(c.anim==='walk') setAnim(c,'idle'); return true; }
  const mx=Math.sign(dx)*Math.min(Math.abs(dx),spd*dt); c.d.x+=mx; c.gph=(c.gph||0)+Math.abs(mx)/Math.max(40,Math.min(66,spd*.42));
  if(c.anim==='idle') setAnim(c,'walk'); const was=(c.runU||0)>gameTime-.05; c.runU=gameTime+.09; dashFx(c,Math.sign(mx),!was,dt); return false; }
function dashFx(c,md,start,dt){ if(!md) return; const hero=c===GS.hero;
  if(start){ dusts.push({ x:c.d.x-md*5, y:c.d.y, age:0, flip:c.d.flip }); if(hero) try{ sfx.whoosh(); }catch(e){} }
  if(!hero) return; c.dfx=(c.dfx||0)+dt; if(c.dfx<.06) return; c.dfx=0;
  for(let k=0;k<2;k++) HITFX.push({ k:'streak', x:c.d.x-md*(5+Math.random()*6), y:c.d.y-12-Math.random()*26, vx:-md*(140+Math.random()*80), vy:0, t:0, life:.13+Math.random()*.05, col:'#f4efe2', a:.5 }); }
function approach(c,tx,spd,dt,rs,chase){ const far=Math.abs(tx-c.d.x); if(rs>spd && (far>(c===GS.hero?34:56) || (chase && far>1) || ((c.runU||0)>gameTime-.05 && far>2))) return runTo(c,tx,rs,dt); return moveTo(c,tx,spd,dt); }   // 주인공 34px · 적 56px 넘게 멀면 달린다(달리기 시작하면 도착할 때까지)
const inFront=(att,t,reach)=>{ const f=att.d.flip?-1:1, dx=(t.d.x-att.d.x)*f; return dx>-4 && dx<=reach+4; }; // +4 = 상대 몸통 앞면까지
// 기술별 실제 사거리: 그 타격 자세에서 주먹·발·무기 끝이 닿는 거리(팔다리 길이 + 몸통 비틀기 + 내딛는 거리)
const MOVE_REACH={ renkan:24, tetsu:24, cycle:26, axe:22, suplex:18, fkick:30, hm_swing:30, hm_back:28, hm_up:22, hm_down:26, bkick:30, bfist:24, jab:24, cross:28, hook:25, upper:20, kick:30, round:32, hbutt:18, elbow:18, knee:17, sweep:34, charge:22, throw:20, stomp:24 };
const wpnReach=(mv,wpn)=> mv==='bat' ? (wpn==='w_wrench'?36:wpn==='w_case'?32:30) : (mv==='jab' && wpn==='w_umb') ? 40 : (mv==='jab' && wpn==='w_paper') ? 28 : MOVE_REACH[mv]||24;
const doorOpenAt=x=> GS.tower ? (GS.tower.door>.75 && x>TWR.G0+8 && x<TWR.G1-8) : TR.door>.6 && DOORS.some(([a,b])=>x>a-4&&x<b+4);
const AW0=()=>GS.tower?TWR.L+8:14, AW1=()=>GS.tower?TWR.R-8:SB.W-14;   // 싸울 수 있는 좌우 끝(타워는 칸 벽)
function damage(att,tgt,dmg,o={}){ if(tgt===GS.hero) GS.hurtAt=GS.time;
  if(att===GS.hero && GS.bossBreak && tgt===GS.bossBreak.a) dmg=Math.round(dmg*(GS.croute?1.6:1.3));   // 무너진 두목: 콤보 ×1.6 · 그 밖 ×1.3
  if(att===GS.hero && tgt.jug) dmg=Math.max(1,Math.round(dmg*Math.max(JUG.scaleMin,Math.pow(JUG.scaleK,tgt.jug.n+1))));   // 공중 타격 피해 감소
  if(GS.demo && GS.dojoSeq && att===GS.hero && tgt.dojo && GS.dojoSeq.cur!=null){ const S=GS.dojoSeq, k=S.cur; S.hits[k]=(S.hits[k]||0)+1; if(tgt.jug) S.airs[k]=true; }   // 무도장: 단계별 적중 기록
  if(att===GS.hero && tgt.anim==='spinout' && (tgt.pose==='so1'||tgt.pose==='so2')){ o={...o, crit:true, backHit:true}; dmg=Math.round(dmg*1.5); }   // 돌아선 등: 반드시 치명타
  if(!tgt.e && (GS.spc||GS.cut)) return;                                                                       // 필살기 · 컷인 중엔 주인공 무적
  if(att===GS.hero && GS.prologue){ dmg=Math.round(dmg*1.5); lampKick(tgt.d.x,(o.knock||o.crit)?1.6:.7); }
  if(att===GS.hero && tgt.e && GS.curSrc!=null) contribAdd(GS.curSrc, dmg);      // 장도리 · 충격에 전등이 흔들린다
  const ft=tgt.d.flip?-1:1, f=(att.d.flip?-1:1)*(o.back?-1:1), TR2=tgt.d.rig;
  if(tgt.e && tgt.e.evade && att===GS.hero && canAct(tgt) && !o.crit && !o.splash && Math.random()<tgt.e.evade){   // 얍삽한 놈: 쓱 빠진다
    setAnim(tgt,'evade'); tgt.kb=f*120; tgt.e.cdT=Math.max(tgt.e.cdT,tgt.e.cd-.5); GS.flash='MISS'; GS.flashT=.5; return; }
  if(tgt.e && tgt.e.shield && !o.counter && GS.time>tgt.e.shieldT && inFront(tgt,att,40)){ tgt.e.shieldT=GS.time+(tgt.e.parry?2.2:3); setAnim(tgt,tgt.e.parry?'parry':'hitB'); sparks.push({x:tgt.d.x+ft*6,y:tgt.d.y-38,age:2}); freeze=2; if(tgt.e.parry){ GS.flash='BLOCK'; GS.flashT=.4; } else if(tgt.e.lamp){ GS.flash='BLIND'; GS.flashT=.4; } else if(tgt.e.pan){ GS.flash='CLANG'; GS.flashT=.4; try{ skTone(1600,1200,.18,'triangle',.05); }catch(e){} } return; } // 우산으로 막음 · 권법가는 팔로 쳐낸다
  const chit = att===GS.hero && !!tgt.e && !o.counter && !o.splash && !GS.demo && !tgt.dead && !tgt.jug && !!tgt.action && !tgt.action.fired && tgt.windup!=null && GS.time-tgt.windup<1 && !!FOE_W[tgt.lastMove] && !REACTS.has(tgt.anim); if(chit) dmg=Math.round(dmg*1.25);   // 받아치기: 적이 치려고 준비하는 순간에 맞히면 피해 ×1.25
  if(tgt.e){ tgt.e.hp-=dmg; GS.stats.dealt+=dmg; GS.score+=Math.round(dmg*10*crowdK()); GS.log.push([GS.time,dmg]); } else { GS.hp-=dmg; GS.stats.taken+=dmg; }
  if(GS.demo && (tgt.dojo || tgt===GS.hero)) DJ.hit={ me:tgt===GS.hero, n:tgt===GS.hero ? (att.anim||'') : djMoveName(), dmg, crit:!!o.crit, air:!!tgt.jug, r:o.react||(o.knock?'knock':o.blast?'blast':'') };   // 무도장 화면: 마지막 타격
  if(tgt===GS.hero && GS.devRun && OPT.devGod) GS.hp=Math.max(GS.hp, GS.max);   // 노선 테스트 · 무적
  if(att===GS.hero && tgt.e){ spcGain(o.crit?3:2); }
  if(!tgt.e) spcGain(1);
  if(tgt.e && tgt.e.boss && BOSS_INFO[tgt.e.t] && !tgt.e.raged && tgt.e.hp>0 && tgt.e.hp<tgt.e.max*.5 && !GS.spc) bossRage(tgt);   // 두목 분노
  if(tgt.e && tgt.e.boss && tgt.e.hp>0 && !GS.spc && !GS.bossBreak && !GS.demo){ const k=tgt.e.hp/tgt.e.max, n=tgt.e.brk||0; if((n===0&&k<.75)||(n===1&&k<.3)) bossBreak(tgt); }   // 두목 무너지는 순간
  if(att===GS.hero && tgt.e){ GS.combo = (GS.time-(GS.lastHit||-9)<comboWin()) ? (GS.combo||0)+1 : 1; if(GS.combo%5===0) spcGain(5); GS.lastHit=GS.time; GS.stats.maxCombo=Math.max(GS.stats.maxCombo||0,GS.combo); }
  const dead = tgt.e ? tgt.e.hp<=0 : GS.hp<=0, kres=tgt.e&&tgt.e.heavy?.35:1;
  let rk = tgt.d.jw ? reactKey(att,o) : (o.knock?'fall':o.react==='launch'?'launch':o.react==='body'?'hitB':'hit');
  if(rk==='rKnee' && att===GS.hero && tgt.e && !tgt.e.boss && srcLinked('crumple')) rk='crumple';   // 무너뜨리기 연계
  if(rk==='rHook' && att===GS.hero && att.anim==='hook' && tgt.e && !tgt.e.boss && !tgt.jug && srcLinked('spinout')) rk='spinout';   // 돌려 세우기 연계
  if(att===GS.hero && att.anim==='uthrust' && tgt.e && !tgt.e.boss && !tgt.jug && Math.abs(tgt.d.x-att.d.x)>22 && srcLinked('pull')) rk='pulled';   // 우산 걸어 당기기
  if(!dead && rk==='rStomp'){ rings.push({x:tgt.d.x,y:tgt.d.y-8,age:0}); groundImpact(tgt.d.x,tgt.d.y,.6); }
  if(att===GS.hero && att.anim==='scoop' && FALLS.has(tgt.anim) && !tgt.jug){ tgt.anim='idle'; }   // 바닥에서 들어 올리기: 누운 상태를 풀고 띄운다
  if(o.blast && att===GS.hero && tgt.e && !tgt.e.boss && tgt.d.jw && ['rKick','hitB','rSpin','rHook','fall'].includes(rk)) rk='rBlast';   // 콤보 마무리(■): 일직선으로 날려 보낸다
  if(chit && !dead && !tgt.e.boss && tgt.d.jw && ['hitB','rKnee','rElbow'].includes(rk)) rk='crumple';
  if(o.just && !dead && tgt.e && !tgt.e.boss && tgt.d.jw && !tgt.jug) rk='crumple';   // 저스트 받아치기: 무릎부터 무너진다   // 받아치기 몸통 타격: 무너진다
  const spike = att===GS.hero && (att.anim==='axe'||att.anim==='axe_air'||att.anim==='hm_down') && !!tgt.e && tgt.d.jw && !tgt.held && !GS.bonus;   // 도끼 차기: 떠 있든 서 있든 얼굴부터 바닥에 꽂는다
  if(spike){ rk='rSpike'; const h0=tgt.jug?Math.max(0,tgt.jug.h):Math.max(0,tgt.airOv||0); tgt.jug=null; tgt.spike={ h0, t:0, dur:h0>2?.07:.02 }; tgt.airOv=h0; tgt.action=null; tgt.queue=[]; }
  const airy = !spike && tgt.e && tgt.d.jw && !tgt.held && !GS.bonus && (tgt.jug || (LAUNCH[rk] && (dead || !tgt.e.boss)));   // 공중 콤보: 띄우는 반응이거나 이미 떠 있으면 물리로
  if(att===GS.hero && tgt.e && GS.stats){ const K=GS.stats.rk||(GS.stats.rk={}), key=(spike?'rSpike':airy?(tgt.jug?'공중:':'뜸:')+rk:rk)+(dead?'†':''); K[key]=(K[key]||0)+1; }   // 개발용: 실전 반응 분포
  if(dead){ tgt.dead=true; if(!tgt.e){ GS.hp=0; tgt.keepBody=true; } if(airy){ jugHit(tgt,rk,f,att,o,kres); tgt.jug.die=true; } else { setAnim(tgt, tgt.d.jw ? ((o.crit||chit) && att===GS.hero && ['hit','hitB','rCross','rHook','rKnee','rElbow'].includes(rk) ? 'crumpleD' : deathOf(rk)) : 'death');   /* 급소 · 받아치기로 쓰러뜨리면 무릎부터 무너진다 */ tgt.kb=f*(REACT_KB[rk]??80)*kres; } if(tgt.e){ GS.kills++; GS.score+=100*(tgt.e.boss?10:1); drop(tgt); metaFoe(tgt.e.t,true); } }
  else if(tgt.e && tgt.e.boss && (tgt.anim==='bat'||tgt.anim==='round') && !FALLS.has(rk)){ }        // 두목은 큰 휘두르기 중엔 버틴다
  else if(airy) jugHit(tgt,rk,f,att,o,kres);
  else if(spike){ setAnim(tgt,'rSpike'); tgt.after='getupP'; tgt.kb=0; }   /* 엎어진 채 손 짚고 일어난다 */
  else if(tgt.anim==='crumple' && rk!=='crumple' && !o.knock){ tgt.kb=f*8; }   // 무너지는 중: 가벼운 타격엔 그대로 무너진다(띄우기 · 넘어뜨리기는 위에서 처리)
  else { setAnim(tgt,rk); if(FALLS.has(rk)) tgt.after='getup'; tgt.kb=f*(REACT_KB[rk]??40)*kres;
    if(rk==='rKnee' && tgt.e) tgt.e.stun=Math.max(tgt.e.stun||0,.45);
    if(tgt.e && !tgt.e.boss && !FALLS.has(rk)){ if(chit) tgt.e.stun=Math.max(tgt.e.stun||0,.8);   /* 받아치기: 맞고 나서 휘청 */
      else if(!tgt.e.stagD && tgt.e.hp<tgt.e.max*.3){ tgt.e.stagD=true; tgt.e.stun=Math.max(tgt.e.stun||0,.7); } } }   /* 빈사: 한 번 휘청(마무리 타이밍) */
  { const big = o.crit||o.knock||o.react==='launch', hs=Math.max(1,Math.round(BF(G.stop)*(o.bigCrit?1.9:o.crit?1.5:o.knock?1.3:.8)));
    const hsT = tgt.jug ? Math.min(hs, BF(big?2.6:1.8)) : hs;   // 공중은 멈춤 상한(약 0.15~0.22초): 길면 공중에 떠서 멈춘 것처럼 보인다 · 때린 쪽도 같은 길이
    tgt.flash = big ? 2 : 1; tgt.hs=spike?1:hsT; tgt.hs0=tgt.hs; tgt.shkA = big ? 2 : 1;   /* 도끼 차기: 맞는 쪽은 멈추지 않고 곧장 꽂힌다(때린 쪽만 묵직하게 멈춤) */ if(att && att.d && att.d.jw){ att.hs=Math.max(att.hs||0,hsT); if(!o.back) att.d.x+=f*2; }   // 때린 쪽 · 맞은 쪽만 멈춘다 · 맞은 쪽은 부들부들
    GS.shoveX=(GS.shoveX||0)+f*(o.bigCrit?6:big?4:2.2); shakeAmp=big?2:1;                                    // 카메라를 맞은 방향으로 민다
    if(dead && att===GS.hero && tgt.e && (foes().length===0 || tgt.e.boss)) freeze=BF(G.stop);                 // 마지막 한 방만 화면 전체를 멈춘다
    hitFx(tgt, f, o, big, att); if(chit) chFx(tgt,f);
    if(att===GS.hero && tgt.e){ const hk=hitKind(att.anim, big||rk==='rSlam'); if(hk==='hammer') sfx.hitK('hammer',!!o.crit,GS.combo||0); else { const tr3=hitTier(att.anim,o,rk); if(GS.stats){ const S3=GS.stats.snd||(GS.stats.snd=[0,0,0]); S3[tr3]++; } sfx.hit3(tr3, { crit:!!o.crit, combo:GS.combo||0, air:!!(tgt.jug && tgt.jug.n>0), big:tr3===2 && (dead || o.blast || HEAVY_RK.has(rk)) }); } } }
  { const shown=Math.round(dmg*DMG_K*(.93+Math.random()*.14)); tgt.uid=tgt.uid||++GS.uid;          /* 던파 · 메이플식 숫자 */
    const label = o.just ? 'JUST!' : (o.counter||chit) ? 'COUNTER' : (o.back||o.backHit) ? (o.crit?'BACK CRITICAL':'BACK ATTACK') : o.crit ? (o.bigCrit?'CRITICAL!!':'CRITICAL') : null, lc = (o.counter||chit) ? '#ffe27a' : (o.back||o.backHit) ? '#7ad7ff' : '#ff9a4a';
    dmgPop(tgt, shown, tgt.e ? (o.crit?'crit':'hit') : 'hurt', label, lc);
    if(att===GS.hero && tgt.e) GS.comboDmg=(GS.combo>1?(GS.comboDmg||0):0)+shown; }
  if(att.d && att.d.jw) rings.push({ x:tgt.d.x-f*5, y:tgt.d.y+(o.low?-22:-44), age:0 }); else sparks.push({ x:tgt.d.x-f*2, y:tgt.d.y+(o.low?-18:(TR2.sparkY||-25)), age:0 });
  if(o.knock||o.react==='launch') dusts.push({ x:tgt.d.x, y:tgt.d.y, age:0, flip:tgt.d.flip });
  // 큰 타격: 임팩트 프레임 · 줌 펀치 · 별 터짐 · 파편 · 강한 흔들림, 마지막 적이면 느린 화면
  const heavy = o.knock||o.react==='launch'||(o.crit&&dead);
  if(!tgt.e){ sfx.hurt(!!att.e && FOE_W[att.lastMove]==='H'); buzz(25); GS.faceMood='flinch'; GS.faceUntil=performance.now()/1000+.35; } else if(att===GS.hero && (o.knock||o.crit||o.react==='launch')) buzz(o.bigCrit?28:16);
  if(att===GS.hero && tgt.e){ const word = dead && (foes().length===0 || tgt.e.boss) ? 'KA-BOOM!' : o.counter ? 'BLAM!' : rk==='rSlam' ? 'SLAM!' : o.bigCrit ? 'KRAK!' : (o.back && (o.crit||FALLS.has(rk))) ? 'THWAK!' : FALLS.has(rk) ? 'WHAM!' : null;
    if(word && !chit && !o.just) comicSFX(tgt.d.x+(Math.random()<.5?-1:1)*(10+Math.random()*8), tgt.d.y-86, word); }     /* 숫자 위쪽에 — 피해 숫자를 가리지 않게 */
  if(att===GS.hero && tgt.e && o.crit){ (GS.critFx=GS.critFx||[]).push({ x:tgt.d.x, y:tgt.d.y-38, t:0, big:!!o.bigCrit, f });
    if(!heavy){ GS.zoomK=Math.min(.06,(GS.zoomK||0)+(o.bigCrit?.035:.022)); GS.zoomC=[tgt.d.x/W,(tgt.d.y-40)/H]; shakeAmp=o.bigCrit?2:1; } }
  if(att===GS.hero && tgt.e && heavy){ GS.invF=OPT.noFlash?0:2; GS.zoomK=Math.min(.09,(GS.zoomK||0)+.055); GS.zoomC=[tgt.d.x/W,(tgt.d.y-40)/H]; shakeAmp=3;
    rings.push({ x:tgt.d.x-f*4, y:tgt.d.y-42, age:0, burst:true });
    for(let k=0;k<8;k++) GS.bits.push({ x:tgt.d.x-f*3, y:tgt.d.y-42, vx:f*(40+Math.random()*130)+(Math.random()-.5)*60, vy:-(50+Math.random()*140), t:0 });
    if(dead && (foes().length===0 || tgt.e.boss)){ GS.slowT=.9; GS.zoomK=.12; }
    if(dead && tgt.e.t==='kaneB') setTimeout(()=>{ say(tr('빅터 케인'), tr('…보스가 왜 너를 골랐는지 알겠군.'), 2.8); }, 700); }   // 최종: 케인의 마지막 말(쓰러진 뒤라 자막으로)
  else if(!tgt.e && heavy){ GS.zoomK=Math.min(.05,(GS.zoomK||0)+.03); GS.zoomC=[tgt.d.x/W,(tgt.d.y-40)/H]; }
  if(tgt===GS.hero && att && att.e && FOE_W[att.anim]){ const w=FOE_W[att.anim], K={L:{hs:.8,sh:1},M:{hs:1,sh:1.6},H:{hs:1.35,sh:2.6}}[w];
    tgt.hs=Math.max(1,Math.round((tgt.hs||1)*K.hs)); att.hs=Math.max(att.hs||0,tgt.hs); shakeAmp=Math.max(shakeAmp,K.sh);
    if(w==='H'){ HITFX.push({ k:'burst', x:tgt.d.x, y:tgt.d.y-44, t:0, life:.26, f:1, n:12, r0:7, r1:34, red:true }); GS.zoomK=Math.min(.1,Math.max(GS.zoomK||0,.05)); GS.zoomC=[tgt.d.x/W,(tgt.d.y-40)/H]; } }
  if(att===GS.hero && tgt.e && tgt.hp<=0 && LINE[GS.ci] && CAR_CONCEPTS[LINE[GS.ci].car] && CAR_CONCEPTS[LINE[GS.ci].car].key==='show' && Math.random()<.75) comicSFX(tgt.d.x, tgt.d.y-92, 'BRAVO!');
  if(att===GS.hero && ATK_FEEL[att.anim]){ const F=ATK_FEEL[att.anim];
    tgt.hs=Math.max(1,Math.round((tgt.hs||1)*F.hs)); att.hs=Math.max(att.hs||0, tgt.hs); shakeAmp=Math.max(shakeAmp, F.shake);
    if(F.zoom){ GS.zoomK=Math.min(.12,Math.max(GS.zoomK||0,F.zoom)); GS.zoomC=[tgt.d.x/W,(tgt.d.y-40)/H]; }
    if(F.dust) dusts.push({ x:att.d.x-(att.d.flip?-1:1)*5, y:att.d.y, age:0, flip:att.d.flip }); }
}
function heroSkill(i, manual){
  const b=GS.bag[i]; if(!b) return; const it=GITEMS[b.id], st=sStats(i), H=GS.hero;
  const reach = it.combo ? MOVE_REACH[['jab','cross','hook','upper'][b.combo||0]] : it.reach+(it.cond==='counter'?pv('ear',6,2):0);
  const inBack=(t,r)=>{ const dx=(t.d.x-H.d.x)*(H.d.flip?-1:1); return dx<4 && dx>=-(r+4); };
  let T=foes().filter(t=>(it.back?inBack(t,reach):inFront(H,t,reach+(t.jug?8:0))) && !t.held && !(t.jug && t.jug.h>66) && (it.cond!=='air' || !!t.jug) && (it.cond==='down' ? (isFalling(t) || (t.jug && !t.jug.gb && t.jug.h<36 && bagHasLink('gbounce'))) : (!isDown(t) || (H.anim==='scoop' && GS.time-(t.tripLandT||-9)<.6)))).sort((a,c)=>Math.abs(a.d.x-H.d.x)-Math.abs(c.d.x-H.d.x)); if(!it.area) T=T.slice(0,1);
  const cm=b.combo||0, dm=it.combo?[1,1.6,2,2.4][cm]:1, react=it.cond==='down'?'down':it.combo?['head','head','head','launch'][cm]:it.react;
  const emp=(b.emp||(GS.dodgeEmp||0)>GS.time)?1.5:1; if(T.length){ b.emp=false; GS.dodgeEmp=0; }                                              // 피하고 반격: 다음 한 방 +50%
  const sigB=sigCheck(b), finB=!!(GS.croute && GS.croute.uids.includes(b.uid));   // 콤보 중 타격 · 고유 콤보 마지막 타
  for(const t of T){ t.finKill=!!(finB||sigB); t.sigKill=!!sigB; }
  let anyCrit=false; GS.curSrc=b.uid;
  for(const t of T){ const crit=it.crit||Math.random()<st.crit+(manual?.1:0); if(crit){ GS.stats.crits++; anyCrit=true; }
    damage(H,t,Math.max(1,Math.round(st.dmg*dm*emp*comboMul(b)*(b.opener?.4:1)*(crit?st.critD:1))),{crit,bigCrit:crit&&st.critD>=2.2,knock:it.knock,react,back:!!it.back,low:it.low||['kick','sweep','stomp','bkick'].includes(H.anim),blast:croleOf(b.id)==='F' && (!!(finB && GS.croute && GS.croute.fin) || !!(GS.demo && GS.dojoSeq && !GS.dojoSeq.single && GS.dojoSeq.steps.length>1 && GS.dojoSeq.cur===GS.dojoSeq.steps.length-1))});
    if(it.stun && t.e && !t.dead){ t.e.stun=it.stun; t.action=null; t.queue=[]; } }
  for(const t of T) if(!t.dead){ t.finKill=false; t.sigKill=false; }
  if(sigB && T.length){ if(GS.croute) GS.croute.sig=true; sigFire(sigB, T[0]); }
  if(GS.bossBreak && GS.croute && T.includes(GS.bossBreak.a)) GS.slowT=Math.max(GS.slowT||0,.1);   // 무너진 두목에게 콤보: 타격마다 짧은 슬로
  GS.curSrc=null; bagFire(b,T.length>0,anyCrit); if(T.length) contribTrig(b.uid);
  cmdSkill(b,anyCrit,cm); if(T.length) watchFlow(b);
  if(T.length){ const bi=GS.bag.indexOf(b); linkFire(bi,'hit'); if(it.knock||react==='sweep') linkFire(bi,'knock'); if(react==='launch') linkFire(bi,'launch'); if(b.id==='sweep') linkFire(bi,'trip');
    if(b.id==='punch' && T.some(t=>t.anim==='spinout')) linkFire(bi,'spin'); if(b.id==='umb' && T.some(t=>t.anim==='pulled')) linkFire(bi,'pull');
    comboOpen(bi,T.slice().sort((a,c)=>Math.abs(a.d.x-H.d.x)-Math.abs(c.d.x-H.d.x))[0]); if(GS.croute && GS.croute.uids.includes(b.uid)) GS.croute.hits++; }   /* 콤보 대상: 가장 가까운 적 */
}
function foeHit(a){ const H=GS.hero; if(H.dead||!a.e||a.e.stun>0) return; if(a.e.hitrun) a.e.retreatT=1.1; if(!inFront(a,H,wpnReach(a.lastMove,a.e.wpn))) return;
  if(FOE_W[a.lastMove]==='H' && isDucking(H)){ a.e.stun=1.0; a.e.cdT=-.4; GS.dodgeEmp=GS.time+3; GS.slowT=Math.max(GS.slowT||0,.25); sfx.dodge(); GS.score+=120;
    GS.stats.dodges=(GS.stats.dodges||0)+1; GS.stats.perfectDodges=(GS.stats.perfectDodges||0)+1; GS.flash='DODGE!'; GS.flashT=.8; comicSFX(a.d.x, a.d.y-86, '빈틈!');
    { const di=duckSlot(); if(di>=0) linkFire(di,'dodge'); } cmdPush({ name:'완벽 회피', sp:false, fam:null }); return; }
  if(a.e.hitrun){ const st=Math.min(GS.score,150); GS.score-=st; if(st) pops.push({x:H.d.x-8,y:H.d.y-78,t:'-'+st,set:'B',age:0}); }
  const k={jab:1,hook:1.3,hbutt:1.2,kick:1.3,bat:1.5,round:1.6,upper:1.5,charge:1.4,fkick:1.6}[a.lastMove]||1;
  damage(a,H,Math.round(a.e.dmg*k*(a.e.flankHit?.8:1)*Math.max(.5,1-pv('armor',.1,.03))*(GS.sets&&GS.sets.grap?1-FAMS.grap.guard:1)),{knock:(['bat','round'].includes(a.lastMove)&&a.e.heavy)||a.lastMove==='charge'||a.lastMove==='fkick',react:a.lastMove==='upper'?'launch':'head'}); }
function drop(a){ if(a.e.boss && GS.bossBreak && GS.bossBreak.a===a && (a.finKill||a.sigKill)) bossScene(a);   // 무너진 동안 콤보로 쓰러뜨리면 명장면
  const r=Math.random(), gp=GS.prologue?0:a.e.boss?1:a.sigKill?.55:a.finKill?.3:.14;   // 서류: 기본 14% · 콤보 중 처치 30% · 고유 콤보 마무리 55%
  if(a.finKill||a.sigKill) GS.stats.comboKills=(GS.stats.comboKills||0)+1;
  if(a.e.meat) GS.items.push({kind:'meat',x:a.d.x+6,z:a.z,t:0});   // 배달원: 음식을 꼭 떨어뜨린다
  if(r<gp){ GS.items.push({kind:'gear',id:pickGear(),x:a.d.x,z:a.z,t:0}); if(a.finKill||a.sigKill){ GS.stats.finPages=(GS.stats.finPages||0)+1; pops.push({x:a.d.x-12,y:a.d.y-74,t:tr('서류!'),age:0,c:'#ffd36a'}); } }
  else if(r<gp+.31) GS.items.push({kind:'meat',x:a.d.x,z:a.z,t:0}); else if(r<gp+.56) GS.items.push({kind:'coin',x:a.d.x,z:a.z,t:0}); }
const pickGear=()=>{ const ks=REAL_ITEMS(); return ks[Math.floor(Math.random()*ks.length)]; };
function quickEquip(uid){ const b=GS.stash.find(o=>o.uid===uid); if(!b) return false; const sp=findSpot(b); if(!sp){ say('','빈자리를 만들면 넣을 수 있어요',1.2); return false; }
  pushUndo(); Object.assign(b,sp); GS.stash=GS.stash.filter(o=>o!==b); GS.bag.push(b); b.isNew=false; cdReset(b); GS.selUid=b.uid; if(GS.equipHint&&GS.equipHint.uid===uid) GS.equipHint=null; if(!GS.stash.some(o=>o.isNew)) GS.bagTabU=null;
  sfx.click(); renderBag(); const el=bagEl.querySelector(`.ii[data-uid="${uid}"]`); if(el) el.classList.add('fx-ok'); return true; }
function gainGear(id,tier,opt){ const n=addToStash(id,tier,true,opt); if(!n) return null; n.isNew=true; GS.selUid=n.uid; GS.bagTabU={ c:inCombat(), t:'p' }; const sp=findSpot(n); if(sp) GS.equipHint={ uid:n.uid, t:6 };   // 새 장비: 빈자리 하이라이트 · 탭으로 장착
  renderBag(); if(!GS.pBag) say('', sp?`${GITEMS[id].n} 획득 — 보류함을 탭하면 빈자리에 바로 넣어요`:`${GITEMS[id].n}을(를) 주워 보류함에 넣었어요`, 2); return n; }   /* 콤보 쇼 중엔 줍기 알림을 띄우지 않는다 */
function pickup(){ const H=GS.hero; for(let i=GS.items.length-1;i>=0;i--){ const it=GS.items[i]; if(Math.abs(it.x-H.d.x)>10) continue;
    if(it.kind==='meat'){ const v=Math.min(25,GS.max-GS.hp); if(v<=0) continue; GS.hp+=v; dmgPop(H, v*DMG_K, 'heal'); }
    else if(it.kind==='coin'){ GS.score+=300; GS.tokens++; sfx.coin(); pops.push({x:H.d.x-6,y:H.d.y-70,t:'+1',set:'C',age:0}); renderBag(); }
    else gainGear(it.id,it.tier||1,rollOpt(it.id,.35));
    GS.items.splice(i,1); } }
// --- 자동 조종 ---
// 쿨다운이 찼고 조건도 맞는 기술 중에서 고른다. 조건 기술은 상황이 왔을 때 우선(가중치 2.2배)
function pickSkill(H,T,F){ const c=[]; GS.bag.forEach((b,i)=>{ if(!b) return; const it=GITEMS[b.id]; if(it.kind!=='skill' || b.t<sStats(i).cd || !condOK(it.cond,H,T,F) || soloSkip(b)) return; c.push([i, sStats(i).dmg*(it.cond?2.2:1)]); });
  if(!c.length) return -1; let w=c.reduce((a,r)=>a+r[1],0)*Math.random(); for(const [i,d] of c){ w-=d; if(w<=0) return i; } return c[0][0]; }
const readySkill=H=>{ const F=foes().filter(a=>a.anim!=='death'&&!a.held), T=F.filter(a=>!isDown(a)).sort((a,b)=>Math.abs(a.d.x-H.d.x)-Math.abs(b.d.x-H.d.x))[0]; return pickSkill(H,T,F); };
