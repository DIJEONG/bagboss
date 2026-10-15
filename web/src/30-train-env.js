// --- 열차: 가감속 · 레일 이음매 · 진동 · 손잡이 진자 ---
function trainUpdate(dt){
  TR.t+=dt;
  { const Lb=LINE[GS.leg]; if(Lb && Lb.bridge && GS.prevEx!=null){ const e0=GS.legStart+Lb.bridge.b0, e1=e0+Lb.bridge.len;
      if(GS.prevEx<e1 && TR.ex>=e1){ GS.press=.42; sfx.press(); TR.jolt=1.6; TR.strapV+=2.2*(Math.random()<.5?1:-1); shakeAmp=Math.max(shakeAmp,2); say('','귀가 먹먹해진다 — 터널 진입 압력파',1.4); }
      if(GS.prevEx<e0 && TR.ex>=e0){ GS.press=.16; TR.jolt=.8; } } GS.prevEx=TR.ex;
    GS.press=Math.max(0,(GS.press||0)-dt*.5); }
  if(GS.departT>0){ GS.departT-=dt; if(GS.departT<=.9) GS.doorWant=false; if(GS.departT<=0 && TR.door<.05){ GS.departT=0; TR.phase='accel'; GS.legStart=TR.ex; GS.atStop=null; GS.qi=0; } }
  // 짧은 정차역: 다가오면 제동 → 서서 문 열고 승하차 → 문 닫고 출발
  const Lq=LINE[GS.leg], q=Lq&&Lq.quick&&Lq.quick[GS.qi||0];
  if(q && !GS.quickStop && !GS.arriving && (TR.phase==='cruise'||TR.phase==='accel') && GS.state==='fight' && TR.ex>=GS.legStart+q[1]-1100){
    TR.phase='brake'; TR.stopAt=GS.legStart+q[1]; GS.quickStop=q; say(`${STN[q[0]].ko}`, `${STN[q[0]].n} — 잠시 정차합니다`, 2.2); }
  if(GS.quickStop && TR.phase==='stop'){ GS.atStop=GS.quickStop[0];
    if(GS.qDwell==null){ GS.qDwell=3.2; GS.doorWant=true; GS.boarded=false; }
    if(!GS.boarded && TR.door>.95){ GS.boarded=true; boardAt(GS.quickStop[2]); }
    GS.qDwell-=dt; if(GS.qDwell<=0) GS.doorWant=false;
    if(GS.qDwell<=0 && TR.door<.03){ TR.phase='accel'; GS.quickStop=null; GS.qDwell=null; GS.qi=(GS.qi||0)+1; GS.atStop=null; } }
  const onBridge = Lq && Lq.bridge && TR.ex>GS.legStart+Lq.bridge.b0-400 && TR.ex<GS.legStart+Lq.bridge.b0+Lq.bridge.len;
  const vmax = onBridge && foes().length ? 380 : GS.expr ? 1100 : 720;                         // 싸우는 동안엔 다리를 천천히, 끝나면 정속으로
  const tgt = TR.phase==='cruise'||TR.phase==='accel' ? vmax : 0;
  if(TR.phase==='accel'){ TR.a=260; if(TR.v>=vmax-20) TR.phase='cruise'; }
  else if(TR.phase==='cruise'){ TR.a=(tgt-TR.v)*.8; }
  else if(TR.phase==='brake'){ const remain=TR.stopAt-TR.ex; TR.a = remain>4 ? -Math.min(420, TR.v*TR.v/(2*Math.max(20,remain))) : -TR.v*6; if(TR.v<6 && remain<30){ TR.v=0; TR.a=0; TR.phase='stop'; } }
  else { TR.a=0; }
  TR.v=Math.max(0,TR.v+TR.a*dt); TR.ex+=TR.v*dt;
  TR.joint-=TR.v*dt; if(TR.joint<=0 && TR.v>40){ TR.joint+=430; TR.bumps.push(0,.13); }      // 앞 대차 · 뒤 대차가 이음매를 차례로 밟는다
  for(let i=TR.bumps.length-1;i>=0;i--){ TR.bumps[i]-=dt; if(TR.bumps[i]<=0){ TR.jolt=1; sfx.clack(); TR.strapV+=1.4*(Math.random()<.5?1:-1); TR.bumps.splice(i,1); } }
  TR.jolt=Math.max(0,TR.jolt-dt*9);
  const fast=Math.min(1,TR.v/600);
  TR.dy=Math.round(TR.jolt*1.6 + Math.sin(TR.t*3.3)*.7*fast + (fast>.5 && Math.random()<.12?1:0));
  TR.strapV += (-16*TR.strap - 2.0*TR.strapV - TR.a*.0045)*dt; TR.strap+=TR.strapV*dt;
  TR.door += ((TR.phase==='stop' && GS.doorWant)?1:-1)*dt*2.2; TR.door=Math.max(0,Math.min(1,TR.door));
  if(Math.random()<dt*.4) TR.flick=.12;  TR.flick=Math.max(0,TR.flick-dt);
}
// 조명 전환: lightK(광원) · emitK(발광)를 부드럽게. 깜빡임은 계단이 아니라 짧은 곡선
function updateLightTrans(dt){
  const T=GS.trans; let k=1;
  let ek=null;
  if(T){ T.t+=dt; const HOLD=T.to?1.0:0, OUT=T.to?1.5:.6, IN=T.to?1.2:1.1, t=T.t-HOLD;
    if(t<0){ k=1; }                                                                   // 들어선 직후: 아직 불이 켜져 있다
    else if(t<OUT){ const u=t/OUT, sm=x=>x*x*(3-2*x);
      const flick = T.to ? 1-.7*sm(Math.max(0,Math.sin(u*26)))*(u>.15&&u<.6?1:0) : 1;   // 꺼지기 전 두어 번 깜빡 (계단 아닌 곡선)
      k=Math.pow(1-sm(u),1.4)*flick; }
    else { if(!T.switched){ T.switched=true; GS.oneBit=T.to; }                       // 정전 상태로(컬러 그대로) — 화면 방식은 바꾸지 않는다
      const u=Math.min(1,(t-OUT)/IN);
      const start = T.to ? 1 : (u<.4 ? .3+.7*Math.pow(.5+.5*Math.sin(u*55),3) : 1);     // 나올 땐 형광등 시동처럼 지직 (부드러운 깜빡)
      k=u*u*(3-2*u)*start; if(u>=1){ GS.trans=null; k=1; } }
    if(T && T.to && T.switched) ek=0; }                                              // 정전 칸: 형광등 발광은 꺼진 채, 비상등만 서서히
  else if(GS.oneBit) ek=0;
  GS.lightK=k; GS.emitK=ek??k;
  TR.flickS=(TR.flickS||0)+((TR.flick>0?1:0)-(TR.flickS||0))*Math.min(1,dt*18);           // 비상등 깜빡임도 곡선으로
}
const WHEELS=[48,84,396,432];                                                          // 바퀴 · 레일 접점 x
function brakeUpdate(dt){ GS.brakeSp=GS.brakeSp||[];
  const braking = TR.phase==='brake' && TR.v>25 && TR.a<-40;
  if(braking){ const rate=Math.min(1,TR.v/500)*(Math.min(1,-TR.a/300));
    for(const wx of WHEELS) for(let k=0;k<3;k++) if(Math.random()<rate*.9) GS.brakeSp.push({ x:wx+(Math.random()-.5)*4, y:259, vx:-(70+Math.random()*170)*(.4+rate), vy:-(15+Math.random()*80), t:0, life:.18+Math.random()*.3 }); }
  else if(TR.phase==='brake' && TR.v>2 && TR.v<=25 && Math.random()<dt*6){ const wx=WHEELS[Math.floor(Math.random()*4)]; dusts.push({x:wx,y:262,age:1,flip:false}); }   // 멈추기 직전 제동 먼지
  for(const p of GS.brakeSp){ p.t+=dt; p.x+=p.vx*dt; p.y+=p.vy*dt; p.vy+=380*dt; if(p.y>261){ p.y=261; p.vy*=-.35; p.vx*=.6; } }
  GS.brakeSp=GS.brakeSp.filter(p=>p.t<p.life);
  GS.brakeGlow=braking ? Math.min(1,(GS.brakeGlow||0)+dt*4) : Math.max(0,(GS.brakeGlow||0)-dt*2); }
function gameUpdate(dt){
  if(!GS.on) return;
  if(GS.skinPv){ skinPvTick(dt); return; }                                                         // 스킨 미리보기: 세상은 멈추고 주인공만
  if(GS.cine){ cineUpdate(dt); return; }
  if(GS.talk) return;                                                                              // 대화 중엔 멈춘다
  talkTick();
  if(GS.kane) kaneUpdate(dt);
  if(GS.state!=='bonus' && !GS.tower){ trainUpdate(dt); brakeUpdate(dt); } updateLightTrans(dt); sndUpdate();                    // 보너스(거리) 중엔 열차 진행을 멈춘다
  if(GS.cut && GS.cut.pause) return;                                                                            GS.shoveX=Math.max(-5,Math.min(5,(GS.shoveX||0)))*Math.exp(-dt*13);   // 컷인 동안은 전투가 멈춘다
  for(const a of GS.ents){ if(a.e && FALLS.has(a.anim) && a.pose==='kd3' && a.landP!=='kd3'){ dusts.push({x:a.d.x,y:a.d.y,age:0,flip:a.d.flip}); sfx.thud(); GS.shoveX+=0; } if(a.e) a.landP=a.pose; }   // 바닥에 떨어지는 쿵
  if(GS.comboDmg && GS.time-(GS.lastHit||-9)>comboWin()){ if((GS.combo||0)>=8 && GS.hero) comicSay(GS.hero, pickQ('combo'));
    if((GS.combo||0)>=3 && GS.hero) for(const c of COMIC) if(c.k==='sfx' && c.age<c.life-.1) c.age=c.life-.1;   // 연타 합계가 뜨면 효과 글자는 접는다
    if((GS.combo||0)>=3 && GS.hero) DPOPS.push({ x:GS.hero.d.x, y:GS.hero.d.y-104, val:GS.comboDmg, style:'total', label:`${GS.combo} HIT TOTAL`, labelCol:'#ffe27a', stack:0, age:0, vx:0, life:1.5 }); GS.comboDmg=0; }   /* 연타가 끝나면 합계 */
  if(freeze>0) return;
  const H=GS.hero; GS.lagH+=(GS.hp-GS.lagH)*Math.min(1,dt*2.5); GS.mcd=Math.max(0,GS.mcd-dt); GS.manualT=Math.max(0,GS.manualT-dt); GS.fade=Math.max(0,GS.fade-dt*2); if(GS.flashT>0) GS.flashT-=dt;
  // 관성: 가감속 때 서 있는 사람은 앞뒤로 기울고 조금 미끄러진다
  // 가드 가중치: 상대가 120px 안이면 걸으면서 가드를 올린다(약 0.3초에 걸쳐)
  { const F=foes(); for(const a of GS.ents){ if(a.pass) continue; const opp = a===H ? F : [H];
      const dmin=opp.length ? Math.min(...opp.map(o=>Math.abs(o.d.x-a.d.x))) : 999; const tg = dmin<140 ? 1 : 0;
      a.guardW=(a.guardW||0)+(tg-(a.guardW||0))*Math.min(1,dt*3.5); } }
  // 관성 기울기: 최대 약 7°(0.32단위), 0.3초 정도에 걸쳐 따라간다. 싸우는 동작 중엔 30%만
  const lean=Math.max(-.32,Math.min(.32,-TR.a*.0011));
  for(const a of GS.ents){ const tg = lean*(a.pass && a.pose==='sb_sit' ? .35 : 1);
    a.tiltS=(a.tiltS||0)+(tg-(a.tiltS||0))*Math.min(1,dt*3.2);
    a.tilt = a.tiltS*((a.pass||a.anim==='idle'||a.anim==='walk') ? 1 : .3);
    if(!a.pass){ a.d.x+= -TR.a*.012*dt*(a.e&&a.e.heavy?.4:1);
      if(holding(a)){ a.kb=0; a.dash=0; a.dashT=0; }
    if(a.jug) jugStep(a,dt);
    if(a.kb && !(a.hs>0)){ a.d.x+=a.kb*dt; a.kb*=Math.pow(.02,dt); if(Math.abs(a.kb)<2) a.kb=0; } if(a.e && !a.dojo && !GS.demo && (Math.abs(a.kb||0)>70 || (a.jug && Math.abs(a.jug.vx||0)>70 && a.jug.h<34))) bowlCheck(a);
      if(a.spike){ const S=a.spike; S.t+=dt; a.airOv=S.h0*Math.max(0,1-S.t/S.dur); if(S.t>=S.dur){ a.spike=null; a.airOv=0; groundImpact(a.d.x,a.d.y,1.3); shakeAmp=Math.max(shakeAmp||0,2.4); dusts.push({x:a.d.x,y:a.d.y,age:0,flip:false}); dusts.push({x:a.d.x,y:a.d.y,age:0,flip:true}); } }   // 도끼 차기: 꽂히는 0.07초
      if(a.dash){ a.d.x+=a.dash*Math.min(dt,Math.max(0,a.dashT)); a.dashT-=dt; if(a.dashT<=0){ a.dash=0; if(a.anim==='walk') setAnim(a,'idle'); } }   // 남은 돌진 시간만큼만(프레임이 느려도 지나치지 않게)
      if(a.e && !a.dead && !a.dojo && Math.abs(a.kb)>55 && doorOpenAt(a.d.x)){ a.dead=true; a.hidden=true; GS.kills++; GS.stats.outs++; GS.score+=400; metaFoe(a.e.t,true); if(GS.tower) twOut(a); comicSFX(a.d.x, a.d.y-50, 'WHOOSH!'); pops.push({x:a.d.x-8,y:a.d.y-60,t:'400',set:'C',age:0}); drop(a); } // 열린 문 밖으로!
      if(a.e && !a.hidden) wallCheck(a); a.d.x=Math.max(AW0()-2,Math.min(AW1()+2,a.d.x)); }
    a.d.y=FLOOR+Math.round(a.z)+TR.dy; }
  bodySep();   // 몸끼리 겹치지 않게
  for(const a of GS.ents){ if(!a.held) continue; const Hh=a.held.by, f=Hh.d.flip?-1:1;
    if((Hh.anim!=='throw' && Hh.anim!=='suplex') || Hh.dead || GS.time-(a.held.t0??GS.time)>2.2){ a.held=null; a.airOv=0; setAnim(a,'fall'); a.after='getup'; continue; }   // 주인공이 맞거나 동작이 끊기면 놓친다 · 2.2초 안전장치
    const S = Hh.anim==='suplex' ? ({ sx_grab:[11,0,'hl0'], sx_lift:[7,8,'hl1'], sx_arch:[-4,20,'hl2'], sx_slam:[-22,0,'kd3'] }[Hh.pose]||[12,0,'hl0']) : Hh.pose==='gr_lift' ? [2,SPC_LIFT,(Math.floor(GS.time*10)%2)?'hl1':'hl1b'] : Hh.pose==='gr_throw' ? [24,10,'hl2'] : [13,0,'hl0'];
    a.d.x=Hh.d.x+f*S[0]; a.airOv=S[1]; a.pose=a.prev=S[2]; a.d.flip=!Hh.d.flip; a.z=Hh.z+1; a.kb=0; }
  for(const a of GS.ents) if(a.pass) passengerUpdate(a,dt);
  GS.ents=GS.ents.filter(a=>!a.hidden||a===H);
  // 병 · 캔
  for(const s of GS.shots){ s.x+=s.vx*dt; s.t+=dt;
    if(s.friendly){ const e=foes().find(a=>!isDown(a)&&Math.abs(a.d.x-s.x)<9); if(e){ s.dead=true; damage(H,e,Math.round(12*(1+.12*GS.ci)),{knock:true,splash:true}); comicSFX(e.d.x,e.d.y-86,'THUNK!'); } if(s.x<0||s.x>SB.W) s.dead=true; continue; }
    const toward = Math.sign(H.d.x-s.x)===Math.sign(s.vx), dist=Math.abs(s.x-H.d.x);
    if(toward && dist<44 && !s.ai){ s.ai=true; if(GS.manualT<=0) heroDuck(); }                              // 가방의 쭈그리기가 준비돼 있으면 자동으로
    if(!s.dead && !s.dodged && dist<6 && !H.dead && isDucking(H)){ s.dodged=true; sfx.dodge(); GS.score+=60; linkFire(duckSlot(),'dodge'); GS.stats.dodges=(GS.stats.dodges||0)+1; GS.flash='DODGE'; GS.flashT=.7;
      dusts.push({x:H.d.x,y:H.d.y,age:1,flip:H.d.flip}); }                                                 // 머리 위로 휙
    if(!s.dead && !s.dodged && dist<6 && !H.dead){ s.dead=true; sfx.glass();
      const umb=GS.bag.find(b=>b&&GITEMS[b.id].block); if(umb && Math.random()<.6+.07*((umb.tier||1)-1)){ sparks.push({x:s.x,y:s.y,age:1}); } else damage({d:{flip:s.vx<0,x:s.x,y:s.y,rig:{}}},H,7,{react:'head'}); }
    if(s.x<0||s.x>SB.W) s.dead=true; }
  GS.shots=GS.shots.filter(s=>!s.dead);
  for(const c of GS.cans){ c.v+= -TR.a*.03*dt; c.v*=Math.pow(.6,dt); c.x+=c.v*dt; if(c.x<16||c.x>SB.W-16){ c.v=-c.v*.5; c.x=Math.max(16,Math.min(SB.W-16,c.x)); } }
  // 시간제 운행: 구간마다 정해진 시간 → 다음 역 도착(적이 남아 있어도). 정시 클리어면 보너스 · 매점, 못 잡으면 남은 적이 따라오고 역에서 더 탄다
  const FIGHTING=['fight','arrive','board','final','corridor','bonus'].includes(GS.state);
  if(FIGHTING){
    GS.time+=dt; GS.items.forEach(it=>it.t+=dt);
    GS.bag.forEach((b,i)=>{ if(!b) return; const it=GITEMS[b.id];
      if(it.kind==='skill'||it.kind==='dodge') b.t=Math.min(sStats(i).cd,b.t+dt);
      else if(it.kind==='heal'){ const hc=it.cd-((b.tier||1)-1); b.t=Math.min(hc,b.t+dt); if(b.t>=hc && GS.hp<GS.max*.5 && !H.dead){ b.t=0; const v=Math.min(it.heal+6*((b.tier||1)-1),GS.max-GS.hp); GS.hp+=v; dmgPop(H, v*DMG_K, 'heal'); } } });
    if(!(H.hs>0) && !GS.spc) heroAI(dt); comboTick(dt); if(GS.demo && GS.dojoSeq && !(H.hs>0)) dojoSeqTick(dt); if(GS.demo){ dojoDummyTick(dt); djTick(dt); djRepTick(dt); } if(!GS.spc) foes().forEach(a=>{ if(!(a.hs>0)) foeAI(a,dt); }); pickup(); spcUpdate(dt);
    if(OPT.autoSpc && (GS.sp||0)>=100 && (foes().length>=3 || foes().some(a=>a.e.boss))) trySpecial();
    if(GS.equipHint){ GS.equipHint.t-=dt; if(GS.equipHint.t<=0){ const u=GS.equipHint.uid; GS.equipHint=null; if(GS.manualT<=0 && !(drag&&drag.moved)) quickEquip(u); else renderBag(); } }   passTrainUpdate(dt); evUpdate(dt); slipUpdate(); strapUpdate(dt); showLampUpdate(dt); GS.envCD=Math.max(0,(GS.envCD||0)-dt);   // 방치 중이면 알아서 장착
    if(H.dead){ if(H.anim==='down'&&(GS.wait+=dt)>1.2){ GS.wait=0; if(GS.tower) towerResult(false); else showResult(false); } return; } }
  if(GS.state==='corridor'){ corridorUpdate(dt); return; }
  if(GS.state==='bonus'){ bonusUpdate(dt); return; }
  if(GS.tower && GS.state==='fight'){ towerTick(dt); return; }   // 엘리베이터 타워: 층 진행
  const L=LINE[GS.ci], dur=legDur(L);
  if(FIGHTING && !H.dead){ const nf=foes().length;
    if((GS.prevFoes||0)>0 && nf===0 && GS.state==='fight' && GS.wave<L.waves.length && Math.random()<.6) comicSay(H, pickQ('wave'));
    GS.prevFoes=nf; GS.idleT = nf ? 0 : (GS.idleT||0)+dt; if(GS.idleT>6 && !GS.thought && !H.rest){ GS.thought=true; comicSay(H, pickQ('think'), 'think'); } if(nf) GS.thought=false; }
  if(GS.state==='fight' && !GS.demo){
    GS.expr = GS.clearT!=null && !L.end && GS.wave>=L.waves.length && !foes().length && GS.legT-GS.clearT>1.8 && !GS.arriving && !GS.quickStop && (GS.qi||0)>=(L.quick||[]).length && !GS.prologue && !GS.cine;
    if(GS.expr && !GS.exprSaid){ GS.exprSaid=true; say('', tr('급행 운행 — 다음 역까지 빠르게'), 1.6); }
    if((TR.phase!=='stop'||!GS.departT) && !GS.spc) GS.legT+=dt*(GS.expr?4:1);
    const FW=foes(), last1=FW.length===1 && !FW[0].e.boss && (FW[0].jug || isDown(FW[0]) || FW[0].e.hp<FW[0].e.max*.35);   // 마지막 한 명이 떠 있거나 쓰러졌거나 빈사면 다음 웨이브가 미리 들어온다(웨이브 사이 공백 줄이기)
    if(GS.wave<L.waves.length){ if(!FW.length || last1) GS.waveT-=dt;                                    // 웨이브: 시간표대로(구간의 약 1/3마다) 또는 다 잡으면 곧바로
      if((GS.legT>=GS.nextWaveAt || ((!FW.length || last1) && GS.waveT<=0)) && FW.length+L.waves[GS.wave].length>FOE_CAP()) GS.nextWaveAt=GS.legT+4;   /* 꽉 차 있으면 웨이브는 미뤄진다 */
      else if(GS.legT>=GS.nextWaveAt || ((!FW.length || last1) && GS.waveT<=0)){ spawnWave(L.waves[GS.wave], false); GS.wave++; GS.nextWaveAt=GS.legT+dur*.32; GS.waveT=.6; } }
    else if(!foes().length && GS.clearT!=null && !L.end && (GS.filler||0)<2 && dur-GS.legT>18 && GS.legT-GS.clearT>1.6){ GS.filler=(GS.filler||0)+1;
      const R2=STAGE.reinf, list=[R2[Math.floor(Math.random()*R2.length)], R2[Math.floor(Math.random()*R2.length)], ...(GS.ci>1?[R2[Math.floor(Math.random()*R2.length)]]:[])];
      spawnWave(list,false); say('옆 칸에서 넘어왔다!', list.map(t=>ETYPES[t].n).join(' · '), 1.8); }
    else if(!foes().length && GS.clearT==null){ GS.clearT=GS.legT; if(!L.end){ GS.flash='CLEAR'; GS.flashT=1.0; sfx.clear(); comicSay(H, pickQ('clear'), 'speech', true); skinGesture(); say('', `${STN[L.stop].ko}까지 ${Math.max(0,Math.ceil(dur-GS.legT))}초 — 정시 클리어`, 2.0); } }
    if(GS.clearT!=null && foes().length) GS.clearT=null;
    if(!GS.arriving && GS.legT>=dur-3.2 && !GS.quickStop && (TR.phase==='cruise'||TR.phase==='accel')){ const S=STN[L.stop];     // 도착: 남은 시간 3초에 제동
      GS.arriving=true; TR.phase='brake'; TR.stopAt=TR.ex+1100; GS.nextStop=L.stop; say(L.end ? `이번 역은 종점 ${S.ko}입니다` : `곧 ${S.ko}에 도착합니다`, `This is ${S.n}`, 2.6); }
    if(GS.arriving && TR.phase==='stop'){ GS.arriving=false; GS.state='arrive'; GS.doorWant=true; GS.atStop=L.stop; GS.arrOpen=false; } }
  else if(GS.state==='arrive'){
    if(!GS.arrOpen && TR.door>.95){ GS.arrOpen=true; boardAt([]); const left=foes().length;
      if(!L.end && !H.dead){ const v=Math.min(GS.max-GS.hp, Math.round(GS.max*.12)); if(v>0){ GS.hp+=v; dmgPop(H, v*DMG_K, 'heal'); } }   /* 역에 서면 숨 돌리기: 체력 12% */
      if(L.end){ GS.state = left ? 'final' : 'end'; GS.wait=0; if(left) say('종점 — 끝까지','남은 적을 모두 쓰러뜨려야 내릴 수 있어요',2.2); }
      else if(!left){ const bonus=500+Math.round(Math.max(0,dur-(GS.clearT??dur))*25); GS.score+=bonus; GS.tokens+=2; GS.stats.onTime=(GS.stats.onTime||0)+1;
        pops.push({x:H.d.x-10,y:H.d.y-84,t:'+'+bonus,set:'C',age:0}); say('정시 클리어', `보너스 ${bonus}점 · 토큰 +2 · 급행 게이지 +25`, 2.0); spcGain(25);
        if(L.shop){ GS.state='shop'; openShop(); } else startBoard(); }
      else { GS.stats.late=(GS.stats.late||0)+1; say(`남은 적 ${left}명`, '매점은 닫혔다 — 남은 적이 따라오고, 이 역에서 더 탄다', 2.4); startBoard(); } } }
  else if(GS.state==='board'){ GS.boardT-=dt; if(GS.boardT<=0) GS.doorWant=false;
    if(GS.boardT<=0 && TR.door<.03){ TR.phase='accel'; GS.state='fight'; GS.atStop=null; GS.legT=0; GS.expr=false; GS.exprSaid=false; GS.nextWaveAt=1.2; GS.waveT=0; GS.clearT=null; } }
  else if(GS.state==='final'){ if(!foes().length){ GS.state='end'; GS.wait=0; } }
  else if(GS.state==='end' && STAGES[(GS.stageIdx||0)+1]){ if(TR.phase==='stop' && (GS.wait+=dt)>1.6){ if(!RUNCFG.daily && !(GS.bonusSt||{})[GS.stageIdx||0]) startBonus(); else startTransfer(); } }   // 노선과 노선 사이(환승 구간)마다: 차 부수기로 빌드 중간 점검
  else if(GS.state==='bonus'){ bonusUpdate(dt); }
  else if(GS.state==='transfer'){ transferUpdate(dt); }
  else if(GS.state==='arrange'){ if(!GS.arrTouched) GS.arrT-=dt; const el=document.getElementById('arrT'), lab=document.querySelector('#sbArrange span');
    if(GS.arrTouched){ if(lab && !lab.dataset.t){ lab.dataset.t=1; lab.innerHTML='정리 중 · 준비되면'; } } else if(el) el.textContent=Math.max(0,Math.ceil(GS.arrT));
    if(GS.arrT<=0) finishArrange(); }
  else if(GS.state==='end'){ if(TR.phase==='stop' && (GS.wait+=dt)>1.5){ GS.wait=0; showResult(true); } }
}
function startTransfer(){ hideArrange(); GS.state='transfer'; GS.trT=0; GS.trLoaded=false; GS.trNext=(GS.stageIdx||0)+1; GS.trCard=STAGES[GS.trNext].card; sayEl.hidden=true; sayT=0; }
function transferUpdate(dt){
  GS.trT+=dt; GS.fade=Math.min(1,GS.trT/.8);                                                   // 0.8초에 걸쳐 암전
  if(GS.trT>.8) showTransfer(GS.trCard, Math.min(1,(GS.trT-.8)/.5));
  if(GS.trT>2.2 && !GS.trLoaded){ GS.trLoaded=true; loadStage(GS.trNext); GS.state='transfer'; }
  if(GS.trT>4.4){ hideTransfer(); GS.fade=1; GS.state='fight'; saveRun(); const C=CAR_CONCEPTS[LINE[0].car]; say(`${STAGE.short} · 1호차 · ${C.name}`, STAGE.intro, 3.2); }                               // 글이 사라지고 새 노선이 밝아진다
}
function loadStage(k){ sayEl.hidden=true; if(!GS.devRun){ META.lines[k]=1; META.best.stage=Math.max(META.best.stage,k); metaDirty=true; }   // 개발 테스트 판은 노선 열림 기록을 남기지 않는다
  setStage(k); GS.hp=Math.min(GS.max,GS.hp+Math.round(GS.max*.5));
  TR.v=0; TR.ex=0; TR.phase='stop'; TR.door=1; TR.stopAt=0; GS.leg=0; GS.legStart=0; GS.qi=0; GS.quickStop=null; GS.qDwell=null; GS.departT=2.4; GS.doorWant=true;
  GS.atStop=START_STOP; GS.nextStop=LINE[0].stop; GS.stationDone=-1; GS.undo=[]; GS.adA=null; GS.outS=null; GS.prevEx=null; enterCar(0); }
function showTransfer(card,a){ let el=document.getElementById('sbTransfer');
  if(!el){ el=document.createElement('div'); el.id='sbTransfer'; el.className='sb-transfer'; stage.appendChild(el); }
  el.innerHTML=`<small>${card[0]}</small><p>${card[1]}</p><b>${card[2]}</b><p>${card[3]}</p>`; el.style.opacity=a; el.hidden=false; }
function hideTransfer(){ const el=document.getElementById('sbTransfer'); if(el){ el.hidden=true; el.style.opacity=0; } }
function startRun(cfg){ if(cfg && !(cfg instanceof Event)) RUNCFG={...RUNCFG,...cfg}; GS.tower=null; GS.croute=null; GS.comboCD=0; GS.comboUse={}; GS.lastCombo=null;
  setTimeout(routeHintMaybe, 2400);
  GS.daily=!!RUNCFG.daily; GS.rerolls=0;                                                                // 오늘의 노선: 매점은 날짜 · 노선 · 칸으로 시드를 따로 뽑아 누구에게나 같게
  if(GS.prologue){ GS.prologue=null; COMIC.length=0; GS.props=[]; GS.cans=[]; GS.ev=null; GS.pt=null; }   // 남아 있던 프롤로그(지하 복도)를 끝낸다: 이어 하기 · 새 판이 복도에서 시작하지 않게
  setStage(0); hideTransfer(); GS.metaSnap={}; GS.newUnlocks=[]; GS.contrib={}; GS.contribRun={}; GS.cmdLog=[]; GS.imprints=genImprints(); GS.sp=0; GS.spc=null; GS.cut=null; GS.bonus=null; GS.bonusDone=false; GS.bonusSt={};
  GS.on=true; GS.expr=false; GS.exprSaid=false; GS.undo=[]; GS.adA=null; GS.outS=null; GS.press=0; GS.prevEx=null; GS.bits=[]; GS.zoomK=0; GS.slowT=0; GS.invF=0; GS.score=0; GS.kills=0; GS.stats={dealt:0,taken:0,crits:0,counters:0,outs:0}; GS.sel=-1; GS.log=[]; GS.time=0; GS.stationDone=-1; GS.doorWant=false;
  GS.bag=[]; GS.stash=[]; GS.tokens=0; GS.selUid=null;
  const kit = RUNCFG.daily ? dailyKit() : (KITS.find(k=>k.id===RUNCFG.kit && kitOpen(k)) || KITS[0]);
  for(const [id,x,y,rot,opt] of kit.bag){ GS.bag.push({...newItem(id,1,opt?{...opt}:null),x,y,rot}); metaItem(id,1); }   // 시작 가방
  fitBag();
  GS.max=heroMax(); GS.hp=GS.max; GS.lagH=GS.hp; GS.hero=mkActor(JW_HERO,{x:40,z:3,pose:'st0'});
  TR.v=0; TR.ex=0; TR.phase='stop'; TR.door=1; TR.stopAt=0; GS.leg=0; GS.legStart=0; GS.qi=0; GS.quickStop=null; GS.qDwell=null; GS.oneBit=null; GS.arriving=false; GS.atStop=START_STOP; GS.departT=2.2; GS.doorWant=true; GS.nextStop=LINE[0].stop;
  pops.length=0; sparks.length=0; dusts.length=0; freeze=0;
  enterCar(0); renderBag(); gOverlay.hidden=true;
  const sg = RUNCFG.daily ? 0 : Math.min(RUNCFG.stage||0, STAGES.length-1);
  const dev=!!GS.devStart || (sg>0 && !META.lines[sg] && !!OPT.devLines && !GS.resuming); GS.devRun=dev;   // 개발자 도구 · 노선 테스트 판(개발로만 연 노선 포함): 이어 하기 저장 · 노선 기록을 건드리지 않는다
  if(!GS.resuming && GS.booted && !dev) clearRunSave(); GS.booted=true; GS.demo=false; djLayout(false);                                                   // 부팅 때의 첫 시작은 저장을 지우지 않는다(타이틀에서 이어 하기)
  if(sg===0 && !RUNCFG.daily && OPT.prologue!==false && !navigator.webdriver && !GS.resuming && !dev) startPrologue();
  if(sg>0 && lineOpen(sg)){ loadStage(sg); GS.tokens+=6; const pool=REAL_ITEMS().filter(k=>GITEMS[k].kind==='skill'); addToStash(pool[Math.floor(Math.random()*pool.length)],1,false,rollOpt('punch',.6)); renderBag(); }   // 중간 노선 시작: 아이템 하나 · 토큰 6
}
const startStage=()=>enterCar(GS.ci), spawnSection=k=>enterCar(k);
