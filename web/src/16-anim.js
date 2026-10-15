// 재생 설정: 동작 문법은 12fps 기준 키 프레임으로 적고, 실제 프레임 수는 애니 fps에 맞춰 환산
let animFps=12, playSpeed=1, inbetween=true;
const BF = n => n<=0 ? 0 : Math.max(1, Math.round(n*animFps/12));
const lerpA = (a,b,t) => a + ((((b-a)%16)+24)%16-8)*t;
function lerpPose(A,B,u){
  const L=(x,y)=>x+(y-x)*u;
  return { r:L(A.r,B.r), b:[L(A.b[0],B.b[0]),L(A.b[1],B.b[1])], h:[L(A.h[0],B.h[0]),L(A.h[1],B.h[1])], t:L(A.t||0,B.t||0),
    ty:L(A.ty||0,B.ty||0), strF:L(A.strF||1,B.strF||1), strB:L(A.strB||1,B.strB||1),
    aF:lerpA(A.aF,B.aF,u), aB:lerpA(A.aB,B.aB,u), w:lerpA(A.w,B.w,u), eF:L(A.eF??1,B.eF??1), eB:L(A.eB??1,B.eB??1),
    fF:[L(A.fF[0],B.fF[0]),L(A.fF[1],B.fF[1])], fB:[L(A.fB[0],B.fB[0]),L(A.fB[1],B.fB[1])], air:L(A.air||0,B.air||0), smear:B.smear, charge:B.charge,
    strL:L(A.strL||1,B.strL||1), upF:B.upF, upB:B.upB, smearAt:B.smearAt, spr:L(A.spr||0,B.spr||0), sprF:L(A.sprF??A.spr??0,B.sprF??B.spr??0), sprB:L(A.sprB??A.spr??0,B.sprB??B.spr??0), legH:B.legH,
    lFT:L(A.lFT??-102.6,B.lFT??-102.6), lFK:L(A.lFK??-31.9,B.lFK??-31.9), lBT:L(A.lBT??-53.1,B.lBT??-53.1), lBK:L(A.lBK??-6.4,B.lBK??-6.4),   /* 각도 입력이 없는 자세는 기본 서기 다리 각도로 본다 */
    spin:(A.spin||0)+((((B.spin||0)-(A.spin||0))%1+1.5)%1-.5)*u,
    roll:(A.roll||0)+((((B.roll||0)-(A.roll||0))%1+1.5)%1-.5)*u };
}
// 인비트윈: 키 포즈로 들어가는 구간(앞 60%)만 이징으로 채우고, 나머지는 키 포즈에 머문다
function curPose(c){
  const cur=POSES[c.pose];
  if(!inbetween || cur.snap || !c.prev || c.prev===c.pose) return cur;
  const T=Math.max(1, Math.ceil(c.phaseN*.6)), u=Math.min(1,(c.k+1)/T);
  if(u>=1) return cur;
  const A=POSES[c.prev], e=1-(1-u)*(1-u);
  if(A.armFK||A.legFK||cur.armFK||cur.legFK) return blendPose(A, cur, e, c.d.rig);   /* 팔 · 다리 각도 입력 자세: 사이 프레임에서도 각도를 잃지 않게(중간에 바른 자세로 튀는 문제) */
  return lerpPose(A, cur, e);
}
const pops=[], sparks=[], dusts=[], rings=[];
function enterStep(c){
  let guard=0;
  while(guard++<8){
    const seq=seqOf(c.anim,c);
    if(c.si>=seq.length){
      if(LOOP.has(c.anim)){ c.si=0; continue; }
      if(c.after && !c.dead){ c.anim=c.after; c.after=null; c.si=0; continue; }
      if(c.dead){ if(c.keepBody){ c.anim='down'; c.si=0; continue; } c.hidden=true; } // 쓰러짐이 끝나면 사라지거나(적) 누운 채 남는다(주인공)
      c.anim='idle'; c.si=0; c.action=null; c.wpn=null;
      if(c.queue.length && !c.dead){ const q=c.queue.shift(); c.action=q.opts; c.wpn=q.opts.wpn||null; c.anim=q.anim; }
      continue;
    }
    const [pose,n,flag]=seq[c.si];
    if(n<=0){ c.si++; continue; }
    let nn=n; if(c.e && c.action && !c.action.fired && FOE_W[c.anim] && !(POSES[pose]&&POSES[pose].smear)) nn=n*FOE_TELL[FOE_W[c.anim]];
    if(c.e && c.action && !c.action.fired && c.action.tell && c.si===0) nn+=c.action.tell*1000;   // 저스트 예고: 첫 준비 자세를 더 오래 보여 준다
    c.prev=c.pose; c.pose=pose; c.hold=(c.d&&c.d.msT) ? Math.max(1,Math.round(nn*animFps/1000)) : BF(nn); c.phaseN=c.hold; c.k=0; c.blink=flag==='blink';
    // 동작 요청에 '큐 프레임'이 있으면 그 포즈에 들어서는 순간 콜백 (예: 타격 순간 피해 계산)
    if(pose==='land_q'){ dusts.push({x:c.d.x,y:c.d.y,age:1,flip:false}); dusts.push({x:c.d.x,y:c.d.y,age:1,flip:true}); }
    if(c.action && c.action.cue===pose && !c.action.fired){ c.action.fired=true; c.action.onCue(c); }
    if(c.action && c.action.cues && c.action.cues[pose] && !c.action['f_'+pose]){ c.action['f_'+pose]=true; c.action.cues[pose](c); } // 한 동작 안 여러 타이밍
    else if(!c.action && ((c.anim==='attack' && pose==='strike') || (c.anim==='cast' && pose==='cast2') || (POSES[pose]&&POSES[pose].impact))) strike(c, c.anim==='cast');
    return;
  }
}
// 동작 요청: 쉬고 있으면 바로, 아니면 줄을 세운다. opts = { cue:포즈 이름, onCue(c), wpn:무기 스프라이트 }
// 공중 자세인가: 떠 있음(높이 4 초과) 또는 회전(약 14° 초과). 한 바퀴(-1)는 똑바로와 같다
const poseAir=P=>{ if(!P) return false; const r=Math.abs((((P.roll||0)%1)+1.5)%1-.5); return (P.air||0)>4 || r>.04; };
const heroAirborne=H=>poseAir(POSES[H.pose]);
function requestAction(c, anim, opts={}){
  if(c.dead||c.hidden) return false;
  if(c.anim==='idle'){ c.action=opts; c.wpn=opts.wpn||null;
    c.seqOv=null; if(c===GS.hero && c.d && c.d.jw && poseAir(c.lastP) && JW_SEQ[anim]) c.seqOv={ anim, seq:[['land_q',60], ...JW_SEQ[anim]] };   // 자동 착지 다리: 공중 자세에서 지상 기술로 갈 땐 먼저 내려앉는다
    setAnim(c,anim); return true; }
  if(c.queue.length<2) c.queue.push({anim,opts}); return false;
}
function setAnim(c,name){ c.anim=name; c.si=0; enterStep(c); }
function advance(c){ c.k++; if(--c.hold>0) return; c.si++; enterStep(c); }
function strike(att, ranged){
  const tgt = CHARS.find(c=>c!==att), ft=tgt.d.flip?-1:1, fa=att.d.flip?-1:1;
  if(scene==='octagon' && !GS.on){
    const heavy=att.anim!=='jab', ko=heavy && tgt.anim!=='death' && Math.random()<.09, ai=CHARS.indexOf(att), ti=1-ai;
    if(ko){ setAnim(tgt,'death'); octFlash(22); OCT.flashes[OCT.flashes.length-1].big=true; OCT.kd++; } else setAnim(tgt,'hit');
    tgt.flash=heavy?2:1; freeze=BF(heavy?G.stop:2); shakeAmp=heavy?2:1;
    const TR=tgt.d.rig; sparks.push({ x:tgt.d.x+ft*(att.anim==='kick'?2:TR.sparkX||5), y:tgt.d.y+(att.anim==='kick'?-12:TR.sparkY||-25), age:heavy?0:2 });
    octFlash(heavy?4:1); OCT.hp[ti]=Math.max(0,OCT.hp[ti]-(ko?30:heavy?7:3)); OCT.st[ai]=Math.max(10,OCT.st[ai]-(heavy?6:3)); OCT.dist=att.anim==='kick'?0:1;
    if(OCT.hp[ti]<=0){ OCT.hp=[100,100]; OCT.st=[100,100]; OCT.round=OCT.round%3+1; OCT.time=300; }
    return;
  }
  if(ranged && att.jw){ const g=att.jw.W2(att.jw.tip); sparks.push({ x:g[0], y:g[1], age:0 }); }
  setAnim(tgt,'hit'); tgt.flash=2; freeze=BF(G.stop);
  const dmg=(12+Math.random()*14).toFixed(1)+'K';
  const TR=tgt.d.rig;
  pops.push({ x:tgt.d.x+ft*-2, y:tgt.d.y+(TR.popY||-56), t:dmg, age:0 });
  sparks.push({ x:tgt.d.x+ft*(TR.sparkX||5), y:tgt.d.y+(TR.sparkY||-25), age:0 });
  if(!ranged) dusts.push({ x:att.d.x+fa*4, y:att.d.y, age:0, flip:att.d.flip });
}
function attack(i){ const c=CHARS[i]; if(c.anim==='idle' && CHARS.every(x=>x.anim==='idle')) setAnim(c,'attack'); }
function stepAnim(){
  if(GS.on && GS.cut && GS.cut.pause) return;
  tick++; const k=12/animFps; // 이펙트 수명은 12fps 기준 프레임으로 센다
  for(const c of ACT()) if(c.flash>0) c.flash-=k;
  for(const L of [pops,sparks,dusts,rings]){ for(const p of L) p.age+=k; }
  for(let i=rings.length-1;i>=0;i--) if(rings[i].age>4) rings.splice(i,1);
  for(let i=pops.length-1;i>=0;i--) if(pops[i].age>16) pops.splice(i,1);
  for(let i=sparks.length-1;i>=0;i--) if(sparks[i].age>4) sparks.splice(i,1);
  for(let i=dusts.length-1;i>=0;i--) if(dusts[i].age>5) dusts.splice(i,1);
  if(freeze>0){ freeze--; shakeX = freeze>0 ? (freeze%2?shakeAmp:-shakeAmp) : 0; return; }
  shakeX=0;
  for(const c of ACT()){
    if(c.hs>0){ c.hs--; c.shk = c.hs>0 && c.flash!==undefined ? ((c.hs%2)?1:-1)*(c.shkA||1)*Math.max(.35, c.hs/(c.hs0||c.hs||1)) : 0; continue; } c.shk=0;   // 떨림은 점점 줄어든다     // 인물별 정지: 떨기만 하고 동작은 멈춤
    advance(c);
    // 후속 동작: 몸이 크게 움직인 프레임 뒤로 목도리가 한 박자 늦게 따라온다
    const r=curPose(c).r, v=Math.abs(r-c.lastR)*animFps/12; c.lastR=r;
    if(v>=6) c.scarfHold=2; else if(c.scarfHold>0) c.scarfHold-=k;
    c.scarfF = c.scarfHold>0 ? 2 : (c.pose==='idle1'||c.pose==='windup') ? 1 : 0;
  }
  if(scene==='octagon'){ for(const f of OCT.flashes) f.age+=k; for(let i=OCT.flashes.length-1;i>=0;i--) if(OCT.flashes[i].age>2) OCT.flashes.splice(i,1);
    if(Math.random()<.09) octFlash(1); OCT.time=Math.max(0,OCT.time-k/12); OCT.st=OCT.st.map(v=>Math.min(100,v+.15*k)); }
  if(autoOn && scene==='octagon' && !GS.on && CHARS.every(c=>c.anim==='idle')){ autoT+=k; if(autoT>=9){ autoT=0; const r=Math.random();
      setAnim(CHARS[turn], r<.55?'jab':r<.8?'cross':'kick'); if(Math.random()<.65) turn^=1; } }
  else if(autoOn && (scene==='forest'||showChars) && CHARS.every(c=>c.anim==='idle')){ autoT+=k; if(autoT>=14){ autoT=0; attack(turn); turn^=1; } }
  else autoT=0;
}

