// --- 차 부수기: 아케이드식 점수 · 경보 · 비상등 · 김 · 불길 · 초읽기 · 결산판 ---
const CAR_PTS={ mirror:[500,'사이드미러'], hubF:[500,'휠캡'], bumperF:[1000,'앞범퍼'], doorF:[1500,'앞문'], doorR:[1500,'뒷문'], hood:[2000,'보닛'], wheelF:[2000,'앞바퀴'], trunk:[1500,'트렁크'], bumperR:[1000,'뒷범퍼'] };
function carPts(C,key){ const v=CAR_PTS[key]; if(!v) return; const BN=GS.bonus; BN.partPts+=v[0]; BN.score+=v[0];
  HITFX.push({ k:'txt', x:C.x-20+Math.random()*30, y:C.y-60, t:0, life:1.3, text:`+${v[0]} ${v[1]}!`, col:'#ffe27a' }); sfx.coin(); }
function alarmTick(dt){ const BN=GS.bonus; if(!BN) return; const on=BN.alarm && !BN.alarmOff;
  if(!SND.on) return; const c=SND.ctx;
  if(on && !BN.alarmO){ const o=c.createOscillator(), g=c.createGain(), f=c.createBiquadFilter(); o.type='square'; f.type='bandpass'; f.frequency.value=1100; f.Q.value=1.2; g.gain.value=0; o.connect(f).connect(g).connect(SND.sfx); o.start(); BN.alarmO=o; BN.alarmG=g; }
  if(BN.alarmO){ const t=c.currentTime, ph=Math.floor(t*4)%2; BN.alarmO.frequency.setTargetAtTime(on?(ph?880:1180):300, t, on?.01:.6); BN.alarmG.gain.setTargetAtTime(on?.045:0, t, on?.05:.5);
    if(!on && !BN.alarmStopT){ BN.alarmStopT=t; setTimeout(()=>{ try{ BN.alarmO.stop(); }catch(e){} },1800); } } }
function bonusFx(dt,dyn){ }
function drawBonusResult(){ const BN=GS.bonus; if(!BN || !BN.tally) return; const T=BN.tally, t=BN.pt-1.6, el=document.getElementById('bonusRes')||(()=>{ const d=document.createElement('div'); d.id='bonusRes'; d.className='bonus-res'; stage.appendChild(d); return d; })();
  const rows=[['타격 점수',T.hit],['부품 보너스',T.part],['파괴 보너스',T.destroy],['시간 보너스',T.time],['최대 연타 보너스',T.combo]], n=Math.min(rows.length,Math.floor(t/.45)+1);
  const cnt=(v,k)=>{ const u=Math.max(0,Math.min(1,(t-k*.45)/.4)); return Math.round(v*u).toLocaleString(); };
  const tot=Math.round(rows.reduce((a,[,v],k)=>a+v*Math.max(0,Math.min(1,(t-k*.45)/.4)),0));
  el.innerHTML=`<b class="br-h">BONUS · 차 부수기</b>${rows.slice(0,n).map(([nm,v],k)=>`<p><span>${nm}</span><i>${cnt(v,k)}</i></p>`).join('')}
    ${t>rows.length*.45?`<p class="br-tot"><span>합계</span><i>${tot.toLocaleString()}</i></p><p class="br-g">${BN.res.g}등급${BN.res.tk?` · 토큰 +${BN.res.tk}`:''}${T.best?' · <em>NEW RECORD</em>':''}</p>${contribHTML(GS.contrib,3,'기여 상위')}`:''}`;
  el.hidden=false;
  const k=Math.floor(t/.08); if(k!==BN.tick && t<rows.length*.45+.3){ BN.tick=k; if(SND.on) tone(SND.ctx.currentTime,.03,{f:1600,type:'square',g:.04}); } }

// --- 도트 연기 · 김 · 불길(게임 세계 스프라이트: 조명을 받고, 반투명 대신 디더로 사라진다) ---
function genPuffs(){ const out={}, rnd=mulberry(4242);
  const puff=(r,mat,tLo,tMid,tHi,fade)=>{ const S=r*2+3, p=paint(S,S), c=S/2;
    for(let y=0;y<S;y++) for(let x=0;x<S;x++){ const dx=x-c+.5, dy=y-c+.5, a=Math.atan2(dy,dx), rr=r*(1+.18*Math.sin(a*3+r)+.1*Math.sin(a*5)), d=Math.hypot(dx,dy);
      if(d>rr) continue; const edge=d>rr-1.6; if(edge && ((x+y)&1)) continue;                                    // 울퉁불퉁한 외곽 · 가장자리 체크 디더
      if(fade && ((x*3+y*5)%4<(fade))) continue;                                                                  // 사라질 때: 픽셀을 성글게
      const lit=(dx+dy)<-r*.4, shade=(dx+dy)>r*.5; p.set(x,y,mat, lit?tHi:shade?tLo:tMid); }
    return p.s; };
  [3,6,9,12].forEach((r,k)=>{ out['pf_smk'+k]=puff(r,M.CURB,0,1,2,0); out['pf_smkD'+k]=puff(r,M.CURB,0,1,2,2); out['pf_stm'+k]=puff(r,M.FRAME,2,3,4,0); out['pf_stmD'+k]=puff(r,M.FRAME,2,3,4,2); });
  for(let f=0;f<4;f++){ const p=paint(9,14), r2=mulberry(300+f);                                                  // 도트 불꽃 4프레임
    for(let y=0;y<14;y++){ const w=Math.max(0,Math.round((y/13)*4.2+ (r2()-.5)*1.4)); const sway=Math.round(Math.sin(y*.7+f*1.6)*1.2*(1-y/14));
      for(let x=-w;x<=w;x++){ const X=4+x+sway; if(X<0||X>8) continue; const core=Math.abs(x)<=w*.35 && y>5, mid=Math.abs(x)<=w*.7 && y>2;
        p.set(X,y, core?M.FRAME:mid?(M.NEONO||M.GOLD):M.RED, core?5:mid?5:4, {e:core?1:mid?.95:.8}); } }
    out['pf_fire'+f]=p.s; }
  return out; }
function pfxPush(BN,k,x,y,life,vx,vy){ (BN.pfx=BN.pfx||[]).push({ k, x, y, t:0, life, vx:vx??(Math.random()-.5)*6, vy:vy??(k==='fire'?-10:-18-Math.random()*8) }); }
function pfxTick(BN,dt){ if(!BN.pfx) return; for(const p of BN.pfx){ p.t+=dt; p.x+=p.vx*dt; p.y+=p.vy*dt; if(p.k!=='fire') p.vx+=Math.sin(p.t*2+p.x)*4*dt; } BN.pfx=BN.pfx.filter(p=>p.t<p.life); }
function drawPfx(BN){ if(!BN.pfx) return; drawDepth=.01;
  for(const p of BN.pfx){ const u=p.t/p.life;
    if(p.k==='fire'){ const f=Math.floor(p.t*12+p.x)%4; if(u<.85) quad('pf_fire'+f, Math.round(p.x-4), Math.round(p.y-13)); continue; }
    const k=Math.min(3,Math.floor(u*4.2)), base=p.k==='stm'?'pf_stm':'pf_smk', nm=base+(u>.7?'D':'')+k, r=[3,6,9,12][k];
    quad(nm, Math.round(p.x-r-1), Math.round(p.y-r-1)); }
  drawDepth=0; }

const hideArrange=()=>{ const el=document.getElementById('sbArrange'); if(el) el.hidden=true; };
function startBonus(){ hideArrange(); const H=GS.hero; GS.state='bonus'; GS.bonusDone=true; (GS.bonusSt=GS.bonusSt||{})[GS.stageIdx||0]=true; sayEl.hidden=true; setScene('brawl'); GS.on=true; GS.cam=0; GS.items=[]; GS.ev=null;
  const car={ x:330, y:NFLOOR+30, stage:0, gone:{}, tilt:0, shake:0, flash:0, debris:[], dentN:0 };
  GS.bonus={ t:0, dur:CAR_TIME, hp:CAR_HP, max:CAR_HP, dealt:0, car, phase:'intro', pt:0, score:0, hitPts:0, partPts:0, maxCombo:0, hits:0 };
  GS.ents=[H]; spawnWave(['brute'],false); const D=GS.ents.find(a=>a.e); D.carDummy=true; D.invis=true;                                                      /* 숨김(hidden)은 '탈 차례 기다리는 적'이라 정리 대상 — 그리기만 생략 */ D.e.hp=D.e.max=1e7; D.e.cd=1e9; D.e.cdT=-1e9; GS.bonus.dummy=D; COMIC.length=0;                    /* 깡패 모델의 등장 대사는 지운다 */
  H.d.x=70; H.d.y=NFLOOR+26; H.d.flip=false; H.hidden=false; H.wpn=null; setAnim(H,'idle'); GS.fade=1;
  say('보너스 스테이지 · 차 부수기', `${CAR_TIME}초 안에 이 차를 부숴라 — 지금 서류가방의 화력을 확인할 시간`, 2.6); sfx.chime(); }
function carDetach(C,key,vx,vy,vth){ const B=carBones({...C,shake:0}), b=B[key]; if(!b) return; C.gone[key]=1; C.debris.push({ key, x:C.x+b.x, y:C.y+b.y, z:b.z, th:b.th, vx, vy, vth }); if(GS.bonus) carPts(C,key); }
function carStage(C,n){ const sx=C.x-GS.cam; comicT=0; C.flash=.05; shakeAmp=Math.max(shakeAmp,2);
  const glass=(x,y,nn)=>{ for(let k=0;k<nn;k++) HITFX.push({ k:'drop', x:x+Math.random()*30-15, y, vx:(Math.random()-.4)*140, vy:-60-Math.random()*120, t:0, life:.9, col:Math.random()<.7?'#cfe8ff':'#ffffff' }); };
  const W=(t)=>comicSFX(sx,C.y-56,t);
  if(n===1){ carDetach(C,'mirror',80,-190,7); sfx.carHit(true); W('CRASH!'); GS.bonus.alarm=true; }                                  // 경보가 울리기 시작한다
  if(n===2){ carDetach(C,'hubF',130,-120,14); sfx.carHit(false); W('KLANG!'); }                                                  // 휠캡이 튕겨 굴러간다
  if(n===3){ glass(C.x+6,C.y-30,22); sfx.glass(); W('SMASH!'); }
  if(n===4){ carDetach(C,'bumperF',110,-150,-5); sfx.carHit(true); W('BAM!'); }
  if(n===5){ carDetach(C,'doorF',90,-220,4.5); glass(C.x+52,C.y-14,10); sfx.glass(); sfx.carHit(true); W('KRAK!'); }
  if(n===6){ carDetach(C,'hood',40,-300,-9); carDetach(C,'doorR',60,-190,-4); sfx.carHit(true); W('WHAM!'); }                       // 보닛이 회전하며 날아간다
  if(n===7){ carDetach(C,'wheelF',150,-90,12); carDetach(C,'wheelF2',150,-90,12); C.tilt=.07; glass(C.x-10,C.y-26,12); sfx.carHit(true); sfx.hiss(); if(SND.on) nz(SND.ctx.currentTime,.08,{f:1400,q:.8,g:.5}); W('THUD!'); }   // 타이어가 터지며 바람이 샌다
  if(n===8){ carDetach(C,'trunk',-60,-260,-6); carDetach(C,'bumperR',-100,-160,-7); C.tilt=.09; sfx.boom(); GS.slowT=.6; GS.zoomK=.12; GS.zoomC=[sx/W,(C.y-20)/H]; shakeAmp=4; buzz([50,30,80]);
    glass(C.x,C.y-24,24); W('KA-BOOM!'); GS.bonus.alarmOff=true; GS.bonus.fire=true; } }
function carHit(loss){ const BN=GS.bonus, C=BN.car; BN.hp=Math.max(0,BN.hp-loss); BN.dealt+=loss; BN.hits++; BN.maxCombo=Math.max(BN.maxCombo,GS.combo||0);
  { const pts=Math.round((100+loss*8)*(1+Math.min(1,(GS.combo||0)*.05))/10)*10; BN.hitPts+=pts; BN.score+=pts; }                       C.shake=1; if(loss>15) C.flash=.035;   // 타격 점수: 피해량 비례 · 연타 배율(최대 2배) · 번쩍임은 큰 타격에만 짧게
  C.dmgF=1-BN.hp/BN.max; sparks.push({ x:C.x-52+Math.random()*12, y:C.y-18+Math.random()*10, age:0 }); if(Math.random()<.5) sfx.carHit(loss>12);
  const n=2+Math.min(4,Math.round(loss/6)); for(let k=0;k<n;k++) HITFX.push({ k:'drop', x:C.x-50+Math.random()*14, y:C.y-16+Math.random()*8, vx:(Math.random()-.2)*110, vy:-50-Math.random()*90, t:0, life:.7, col:['#3a5fd0','#2c4aa8','#9aa3b4','#5a6070'][k%4] });   // 도장 · 쇳조각
  if(C.stage>=3 && Math.random()<.5) HITFX.push({ k:'drop', x:C.x-30+Math.random()*30, y:C.y-24, vx:(Math.random()-.3)*90, vy:-40-Math.random()*70, t:0, life:.6, col:'#cfe8ff' });
  const fr=BN.hp/BN.max; while(C.stage<CAR_STAGES.length && fr<=CAR_STAGES[C.stage]){ C.stage++; carStage(C,C.stage); } }
function bonusGrade(BN){ const left=Math.max(0,BN.dur-BN.t), done=BN.hp<=0, pct=1-BN.hp/BN.max;
  const g = done ? (left>=12?'S':left>=6?'A':'B') : (pct>=.6?'C':'D'), R={S:[5000,4],A:[3000,3],B:[2000,2],C:[1000,1],D:[300,0]}[g];
  return { g, left, done, pct, pts:R[0], tk:R[1], dps:BN.dealt/Math.max(1,BN.t) }; }
function bonusUpdate(dt){ const BN=GS.bonus, C=BN.car, H=GS.hero, D=BN.dummy; if(!BN) return;
  C.shake=Math.max(0,C.shake-dt*5); C.flash=Math.max(0,C.flash-dt);
  if(D){ D.d.x=C.x-50; D.d.y=H.d.y; D.kb=0; D.e.stun=0; D.held=null; D.airOv=0; if(D.anim!=='idle'){ D.anim='idle'; D.action=null; D.queue=[]; } }
  if(H.d.x>C.x-58) H.d.x=C.x-58;                                                                                  // 차체에 막힌다
  if(D){ const loss=1e7-D.e.hp; D.e.hp=1e7; if(loss>0 && BN.phase==='go') carHit(loss); }
  for(const d of C.debris){ d.vy+=420*dt; d.x+=d.vx*dt; d.y+=d.vy*dt; d.th+=d.vth*dt; if(d.y>C.y-3){ d.y=C.y-3; d.vy*=-.35; d.vx*=.62; d.vth*=.55; if(Math.abs(d.vy)<25) d.vy=0; } }
  pfxTick(BN,dt);
  if(C.stage>=CAR_STAGES.length && (BN.smT=(BN.smT||0)+dt)>.09){ BN.smT=0; pfxPush(BN,'smk',C.x+4+Math.random()*30,C.y-24,3.0,(Math.random()-.3)*8,-20-Math.random()*10); }   // 짙은 연기 기둥
  if(C.gone.hood && C.stage<CAR_STAGES.length && (BN.stT=(BN.stT||0)+dt)>.2){ BN.stT=0; pfxPush(BN,'stm',C.x+34+Math.random()*16,C.y-20,1.3,undefined,-26); }   // 엔진에서 김
  if(BN.fire && (BN.fiT=(BN.fiT||0)+dt)>.045){ BN.fiT=0; pfxPush(BN,'fire',C.x+14+Math.random()*40,C.y-12-Math.random()*4,.5+Math.random()*.5); if(SND.on && Math.random()<.3) nz(SND.ctx.currentTime,.05,{f:2200+Math.random()*1500,q:3,g:.05}); }   // 불길 · 타닥
  for(const d of C.debris){ if(d.vy===0 && !d.landed && d.y>=C.y-3.5){ d.landed=true; } if(d.y>=C.y-3.2 && Math.abs(d.lastVy||0)>90 && !d.clanked){ d.clanked=true; if(SND.on) tone(SND.ctx.currentTime,.12,{f:520,to:260,type:'triangle',g:.12}); } d.lastVy=d.vy; }
  alarmTick(dt);
  if(BN.phase==='go'){ const left=BN.dur-BN.t, sec=Math.ceil(left); if(left<=5 && sec!==BN.beepS && sec>0){ BN.beepS=sec; if(SND.on) tone(SND.ctx.currentTime,.09,{f:sec<=2?1320:880,type:'square',g:.08}); } }
  if(BN.phase==='intro'){ BN.pt+=dt; if(BN.pt>2.2){ BN.phase='go'; comicT=0; comicSFX(SB.W/2,96,'FIGHT!'); sfx.brass(); } return; }
  if(BN.phase==='go'){ BN.t+=dt; if(BN.hp<=0 || BN.t>=BN.dur){ BN.phase='owner'; BN.pt=0; BN.res=bonusGrade(BN); GS.tokens+=BN.res.tk; BN.alarmOff=true; comicT=0;
      if(BN.hp>0) comicSFX(SB.W/2,90,'TIME UP!'); else if(BN.res.g==='S') setTimeout(()=>{ comicT=0; comicSFX(SB.W/2,90,'PERFECT!'); },500);
      const T={ hit:BN.hitPts, part:BN.partPts, destroy:BN.hp<=0?10000:0, time:BN.hp<=0?Math.ceil(BN.res.left)*1000:0, combo:BN.maxCombo*100 }; T.total=T.hit+T.part+T.destroy+T.time+T.combo;
      META.bonusBest=META.bonusBest||0; T.best=T.total>META.bonusBest; META.bonusBest=Math.max(META.bonusBest,T.total); metaDirty=true; GS.score+=T.total; BN.tally=T;
      if(D){ GS.ents=GS.ents.filter(a=>a!==D); BN.dummy=null; } setAnim(H,'idle');
      const before=new Set(GS.ents); spawnWave(['punk'],false); const O=GS.ents.find(a=>!before.has(a)); O.carOwner=true; O.e.cd=1e9; O.e.cdT=-1e9; O.d.x=SB.W+20; O.d.flip=true; BN.owner=O; for(let i=COMIC.length-1;i>=0;i--) if(COMIC[i].a===O) COMIC.splice(i,1); } return; }
  if(BN.phase==='owner'){ BN.pt+=dt; const O=BN.owner;
    if(O && !BN.knelt){ const dx=-120*dt; O.d.x+=dx; advGait(O,dx,true); if(O.anim!=='run') setAnim(O,'run'); if(O.d.x<=C.x+56){ BN.knelt=true; setAnim(O,'duck'); comicSay(O,'내 차아아!','shout',true); sfx.hurt(); } }
    if(O && BN.knelt && O.anim!=='duck') setAnim(O,'duck');
    if(BN.pt>1.6 && !BN.said){ BN.said=true; sfx.clear(); }
    if(BN.pt>1.6) drawBonusResult();
    if(BN.pt>8.2 || (BN.skip && BN.pt>2.2)) finishBonus(); } }
function finishBonus(){ const H=GS.hero; const el=document.getElementById('bonusRes'); if(el) el.hidden=true; GS.bonus=null; GS.ents=[H]; H.d.y=SB.FLOOR; setScene('subway'); GS.on=true; startTransfer(); }
function drawBonusHUD(){ const BN=GS.bonus; if(!BN) return; const cx=VW/2, left=Math.max(0,BN.dur-BN.t);
  pxText(10,8,'BONUS STAGE','#ffd34a'); pxText(10,18,'SCORE '+String(Math.round(BN.score)).padStart(7,'0'),'#f1ece0');
  const tcol = BN.phase==='go' && left<5 && Math.floor(performance.now()/200)%2 ? '#ff5a4a' : '#ffffff';
  letter(String(Math.ceil(left)).padStart(2,'0'), cx, 22, 20, tcol, 0);
  const w=Math.min(170,VW-80), x=cx-w/2, y=38, k=BN.hp/BN.max; uiCx.fillStyle='#0e0d14'; uiCx.fillRect(x-1,y-1,w+2,7); uiCx.fillStyle='#2a1018'; uiCx.fillRect(x,y,w,5);
  uiCx.fillStyle='#e0a33a'; uiCx.fillRect(x,y,Math.round(w*k),5); uiCx.fillStyle='rgba(255,255,255,.3)'; uiCx.fillRect(x,y,Math.round(w*k),1);
  uiCx.fillStyle='#0e0d14'; for(const t of CAR_STAGES) if(t>0) uiCx.fillRect(x+Math.round(w*t),y,1,5); pxText(x-26,y,'CAR','#cfc6e6');
  if(BN.phase==='owner' && BN.pt>1.2 && BN.res){ letter(BN.res.g, cx, H/2-10, 46, {S:'#ffd34a',A:'#ff8a2a',B:'#6ec6ff',C:'#cfc6e6',D:'#9a8a8a'}[BN.res.g], -.08); } }

