/* =========================================================
   5. 광원
   ========================================================= */
const torch={ x:58, y:50 };
let beamOn=false;
const lights=[];
const LP=new Float32Array(32), LC=new Float32Array(32), LD=new Float32Array(32);
const hash=n=>{ const s=Math.sin(n*127.1+311.7)*43758.5453; return s-Math.floor(s); };

/* =========================================================
   6. 프레임 구성
   ========================================================= */
let qn=0, drawDepth=0, drawOX=0, drawRemap=0, drawPart=0; // 지금 그리는 층의 깊이 · 패럴랙스 오프셋 · 팔레트 스왑 세트
function quad(name, x, y, flip=0, flash=0){
  const s=SPR[name], a=ATL[name]; if(!s||qn>=MAXQ) return; x+=drawOX;
  const u0=a.x, v0=a.y, u1=a.x+s.w, v1=a.y+s.h;
  const ua = flip?u1:u0, ub = flip?u0:u1;
  const x1=x+s.w, y1=y+s.h;
  const V=[[x,y,ua,v0],[x1,y,ub,v0],[x,y1,ua,v1],[x1,y,ub,v0],[x1,y1,ub,v1],[x,y1,ua,v1]];
  let o=qn*6*FPV;
  for(const v of V){ vdata[o++]=v[0]; vdata[o++]=v[1]; vdata[o++]=v[2]; vdata[o++]=v[3]; vdata[o++]=flip; vdata[o++]=flash; vdata[o++]=drawDepth; vdata[o++]=drawRemap; vdata[o++]=drawPart; }
  qn++;
}
function placeAt(name, jx, jy, flip, flash){
  const s=SPR[name]; if(!s) return;
  const x = flip ? jx-(s.w-1-s.px) : jx-s.px; quad(name, x, jy-s.py, flip?1:0, flash);
}
// 각도 a2는 32방향 인덱스(11.25°). 위치는 반올림해서 항상 정수 픽셀
const rotEnd=(x,y,a2,len)=>{ const th=a2*Math.PI/16; return [x+Math.round(len*Math.sin(th)), y+Math.round(len*Math.cos(th))]; };
// 스프라이트 회전과 같은 규칙으로 벡터를 돌림 (th16: 22.5° 단위)
function rotV(p, th16){ const th=th16*Math.PI/8, c=Math.cos(th), s=Math.sin(th); return [p[0]*c+p[1]*s, -p[0]*s+p[1]*c]; }
// 2관절 IK: 엉덩이 H에서 발 목표 T까지, 무릎은 항상 앞(+x)으로 굽는다. 닿지 않으면 다리를 펴서 목표를 가리킴
function solveLeg(H, T, L1, L2, sgn=1){
  const dx=T[0]-H[0], dy=T[1]-H[1], phi=Math.atan2(dx,dy); let d=Math.hypot(dx,dy), al=0;
  if(d < L1+L2-.01){ d=Math.max(d, Math.abs(L1-L2)+.01); al=Math.acos(Math.max(-1,Math.min(1,(L1*L1+d*d-L2*L2)/(2*L1*d)))); }
  const th=phi+sgn*al, K=[H[0]+L1*Math.sin(th), H[1]+L1*Math.cos(th)];
  const ps = al>0 ? Math.atan2(T[0]-K[0], T[1]-K[1]) : th;
  return { K, aT:th*8/Math.PI, aS:ps*8/Math.PI, F:[K[0]+L2*Math.sin(ps), K[1]+L2*Math.cos(ps)] };
}
// 팔꿈치 IK: 손 방향(a, 22.5° 단위)과 뻗은 정도(e, 0~1)로 손 위치를 정하고, 팔꿈치는 아래로 접히는 해를 고른다
function solveArm(S, a, e, L1, L2, up){
  const th=a*Math.PI/8, L=(L1+L2)*Math.max(.3,Math.min(1,e==null?1:e)), T=[S[0]+L*Math.sin(th), S[1]+L*Math.cos(th)];
  const p=solveLeg(S,T,L1,L2,1), m=solveLeg(S,T,L1,L2,-1); return up ? (m.K[1]<p.K[1] ? m : p) : (m.K[1]>p.K[1] ? m : p);   // up: 훅처럼 팔꿈치를 들어 팔을 수평 ㄱ자로
}
// 보폭 동기 걷기: 위상 gph(0~1)는 이동 거리로만 나아간다. 12단으로 끊어 그리고, 남는 거리만큼 몸을 뒤로 당겨 디딘 발이 미끄러지지 않게
function runPose(c,P0,R){                                                                                       // 전력 질주(레퍼런스 기준): 접지 한가운데 가장 낮고 · 체공 때 가장 높다 · 뒤꿈치가 먼저 올라간 뒤 무릎을 따라 앞으로 · 팔꿈치 90° 크게
  const LL=(R.thigh||6)+(R.shin||7), A=.5*LL, ph=((c.gph||0)%1+1)%1, N=16, q=Math.floor(ph*N)/N, sc=R.sc||1, ST=.30;
  const sm=x=>{ x=Math.max(0,Math.min(1,x)); return x*x*(3-2*x); };
  const foot=u=>{ if(u<ST){ const v=u/ST; return [A*.8-A*1.8*v, 0]; }                                              // 접지: 몸 바로 앞에 닿아 뒤로 밀어낸다
    const v=(u-ST)/(1-ST), xs=sm((v-.22)/.68); return [-A+1.8*A*xs, -(LL*.72)*Math.pow(Math.sin(Math.PI*Math.min(1,v/.88)),.5)]; };   // 떠나자마자 뒤꿈치가 높이 차오른다   // 뒤꿈치 먼저 → 무릎 따라 앞으로 → 앞으로 뻗어 내린다
  const f1=foot(q), f2=foot((q+.5)%1), bob=Math.cos(4*Math.PI*(q-ST/2)), up=Math.max(0,-bob);                      // bob +1 = 접지 한가운데(가장 낮음)
  const arm=ph0=>{ const u=-2.5*Math.cos(2*Math.PI*(q-ph0)), lag=-2.5*Math.cos(2*Math.PI*(q-ph0-.05)); return [u, lag+3.6]; };
  const [uF,lF]=arm(0), [uB,lB]=arm(.5);
  return { ...P0, r:0, t:1.0+.3*(1-up), ty:0, h:[1,0], b:[0,(1.7*bob+.3)/sc], fF:[(f1[0]-R.legF[0]+.5)/LL,f1[1]/LL], fB:[(f2[0]-R.legB[0]-.5)/LL,f2[1]/LL],
    armFK:true, uF, lF, uB, lB, tail:.9*Math.sin(2*Math.PI*q), air:2.2*up }; }
const advGait=(c,dx,run)=>{ c.gph=(c.gph||0)+Math.abs(dx)/(run?66:4*.3*24); };                                   // 달리기: 한 주기(두 걸음) 66px — 초속 150px에서 초당 약 4.5걸음                                   // 직접 옮길 때도 보폭 위상을 넘긴다(다리가 굳지 않게)
function gaitPose(c,P0,R){
  const LL=(R.thigh||6)+(R.shin||7), A=.3*LL, ph=((c.gph||0)%1+1)%1, N=12, q=Math.floor(ph*N)/N, sc=R.sc||1;
  const foot=u=>{ if(u<.5) return [A-2*A*(u/.5),0]; const v=(u-.5)/.5, s=v*v*(3-2*v); return [-A+2*A*s,-3.4*Math.sin(Math.PI*v)]; };
  const f1=foot(q), f2=foot((q+.5)%1), sw=Math.cos(2*Math.PI*q);
  c.gres=(ph-q)*4*A;
  const G={ ...P0, r:0, t:.3, ty:0, h:[0,0], b:[0, 1.1*Math.cos(4*Math.PI*q)/sc], fF:[(f1[0]-R.legF[0]+.5)/LL,f1[1]/LL], fB:[(f2[0]-R.legB[0]-.5)/LL,f2[1]/LL], // 발은 골반 중심 기준으로 앞뒤 대칭
    ...(()=>{ // 팔: 다리와 반대 방향으로, 아래팔은 위팔보다 반 박자 늦게. 앞으로 갈수록 팔꿈치가 더 접힌다
      const arm=(ph0)=>{ const u=-1.25*Math.cos(2*Math.PI*(q-ph0)), lag=-1.25*Math.cos(2*Math.PI*(q-ph0-.08));
        return [u, lag+.15+.5*Math.max(0,(lag+1.25)/2.5)]; };
      const [uF,lF]=arm(0), [uB,lB]=arm(.5); return { armFK:true, uF, lF, uB, lB }; })(),
    tail:.55*Math.sin(2*Math.PI*q), air:0 };
  // 적이 가까우면 걸으면서 가드를 올린다: 손은 대기 자세 쪽으로, 몸은 웅크리고 비틀며, 팔 흔들림·보폭은 줄어든다
  const w=Math.max(0,Math.min(1,c.guardW||0)); if(w<=0) return G;
  const S=toFK(POSES[(c.d.jw?'st0':'m_idle0')],R), sw2=1-w*.85, L=(a,b)=>a+(b-a)*w;
  return { ...G, t:L(G.t,S.t), ty:L(0,S.ty||0), h:[L(0,S.h[0]),L(0,S.h[1])], b:[0, G.b[1]*sw2+L(0,S.b[1])],
    uF:L(G.uF*sw2,S.uF), lF:L(G.lF*sw2+(1-sw2)*G.uF*0,S.lF), uB:L(G.uB*sw2,S.uB), lB:L(G.lB*sw2,S.lB) };
}
// 팔을 위팔·아래팔 각도(FK)로 바꿔 둔다: IK 자세와 FK 자세(걷기)를 서로 섞을 수 있게
function toFK(P,R){ if(P.armFK) return P;
  const ang=(A,B)=>Math.atan2(B[0]-A[0],B[1]-A[1])/(Math.PI/8);
  const fF=solveArm([0,0],P.aF,P.eF,R.upper,R.fore*(P.strF||1)), fB=solveArm([0,0],P.aB,P.eB,R.upper,R.fore*(P.strB||1));
  return { ...P, armFK:true, uF:ang([0,0],fF.K), lF:ang(fF.K,fF.F), uB:ang([0,0],fB.K), lB:ang(fB.K,fB.F) }; }
// 동작이 바뀔 때: 직전에 그린 자세에서 새 자세로 짧게 섞는다 (팔은 FK 각도로)
const BLEND_MS=(from,to)=> REACTS.has(to) && to!=='getup' && to!=='getupP' && to!=='stagger' ? 0 : to==='duck' ? 45 : from==='walk'&&to==='idle' ? 300 : from==='walk' ? 70 : to==='walk' ? 150 : 110;
function blendPose(A,B,u,R){ const a=toFK(A,R), b=toFK(B,R), L=(x,y)=>x+(y-x)*u, la=(x,y)=>{ let d=y-x; while(d>8) d-=16; while(d<-8) d+=16; return x+d*u; };
  const m=lerpPose({...a, b:a.b||[0,0], h:a.h||[0,0], fF:a.fF, fB:a.fB}, b, u);
  return { ...b, ...m, armFK:true, uF:la(a.uF,b.uF), lF:la(a.lF,b.lF), uB:la(a.uB,b.uB), lB:la(a.lB,b.lB), tail:L(a.tail||0,b.tail||0), impact:b.impact, smear:b.smear, smearAt:b.smearAt }; }
function drawChar(c, out){ const _s=c.shk||0, up=!!(c.jug||(c.airOv||0)>2); if(_s){ if(up) c.airOv=(c.airOv||0)+_s; else c.d.x+=_s; } try{ return drawChar0(c,out); } finally{ if(_s){ if(up) c.airOv-=_s; else c.d.x-=_s; } } }   // 정지 중 떨림: 땅에선 가로 · 공중에선 세로   // 정지 중 떨림만큼 옮겨 그린다
function drawChar0(c, out){
  const d=c.d, R=d.rig, rgo=!!(d.gait&&c.anim==='walk'&&c.runU>gameTime), walkG=d.gait&&c.anim==='walk'&&!rgo, runG=d.gait&&(c.anim==='run'||rgo); let P=runG?runPose(c,curPose(c),R):walkG?gaitPose(c,curPose(c),R):curPose(c);
  if(c.jug && (c.jug.roll||c.jug.kick)) P={ ...P, roll:(c.jug.roll||0)+(c.jug.kick||0) };   // 날아가는 피격: 세로축 팽이 대신 화면 안에서 뒤로 구른다
  if(c===GS.hero){ const dtv=Math.min(.1,Math.max(0,gameTime-(c._vt??gameTime))); c._vt=gameTime;   // 주인공 회전 · 높이는 화면 프레임마다 따라간다(12fps 계단 없이)
    const tr=P.roll||0, cr=c._vr??tr, dr=((((tr-cr)%1)+1.5)%1)-.5; c._vr=Math.abs(dr)<.001?tr:cr+dr*Math.min(1,dtv*24);
    const ta=P.air||0, ca=c._va??ta; c._va=ca+(ta-ca)*Math.min(1,dtv*26);
    if(Math.abs(c._vr)>.0005 || c._va>.05 || P.roll || P.air) P={ ...P, roll:c._vr, air:c._va }; }
  if(c.legRun && d.gait && !runG && !walkG){ const RP=runPose(c,P,R); P={ ...P, fF:RP.fF, fB:RP.fB, b:[P.b[0], P.b[1]*.5+RP.b[1]], air:(P.air||0)+RP.air }; }   // 필살기 진격: 상체는 공격 동작, 다리는 이동 거리만큼 달린다
  if(d.model3 && rgo!==!!c._rgo && c._an===c.anim && c.lastP){ c.bFrom=c.lastP; c.bT0=gameTime; c.bDur=.08; } c._rgo=rgo;   /* 걷기 ↔ 대시: 다리 자세를 짧게 섞는다 */
  if(d.model3){ // 전환 블렌딩: 동작 이름이 바뀌면 직전 자세 스냅샷에서 섞어 들어간다
    if(c._an!==c.anim){ const ms=c._an ? BLEND_MS(c._an,c.anim) : 0; c.bFrom = ms>0 ? c.lastP : null; c.bT0=gameTime; c.bDur=ms/1000; c._an=c.anim; }
    if(c.bFrom){ const u=(gameTime-c.bT0)/Math.max(.001,c.bDur); if(u>=1) c.bFrom=null; else P=blendPose(c.bFrom,P,u*u*(3-2*u),R); } // 천천히 출발해 천천히 도착
    c.lastP=P; }
  if(GS.skinPv && c===GS.hero && GS.skinPv.view) P={ ...P, spin:(P.spin||0)+GS.skinPv.view/360 };   /* 자세 편집기: 보기 회전(확인용) */
  const f=d.flip?-1:1, fl=c.flash>0?1:0, a0=R.a0||{}, sc=R.sc||1;
  const tRaw=(P.t||0)*(R.leanK||1)+(c.tilt||0), rr=Math.round(P.r*sc), tq=d.model3 ? tRaw : Math.round(tRaw*2)/2, /* 3D 리그는 몸통 각도를 끊지 않는다(11° 계단 튐 방지) */ q=a=>m32(Math.round(a*2)); // 3D 리그는 몸통이 실제로 기울어서 기울기를 줄여 쓴다
  const RI=v=>[Math.round(v[0]),Math.round(v[1])], add=(a,b)=>[a[0]+b[0],a[1]+b[1]];
  const air=Math.round(((P.air||0)+(c.airOv||0))*sc), gr=walkG?Math.round(c.gres||0):0, W2=l=>[d.x+f*(l[0]+rr-gr), d.y+l[1]-air];
  // 몸통 각도: 포즈마다 3/4(0) · 측면(1) · 정면으로 펼침(2) 원화를 바꿔 끼우고, 어깨 위치도 그 원화에 맞춘다
  const tv=(POSES[c.pose]&&POSES[c.pose].tv)||0, V=(R.views&&R.views[tv])||R;
  const tor=p=>RI(rotV(p,-tq)); // 몸을 숙이면 골반 위 관절들이 함께 돈다
  let hips=[Math.round(P.b[0]*sc), R.hip+Math.round(P.b[1]*sc)];
  let legFK=null; if(P.legFK && d.model3){ const T1=R.thigh||6, T2=R.shin||7, dg=Math.PI/180, csF=Math.cos((P.sprF??P.spr??0)*dg), csB=Math.cos((P.sprB??P.spr??0)*dg);   /* 다리 각도 입력: 0° 몸 앞 · −90° 아래 · 무릎은 허벅지 기준 굽힘 */
    const leg=(th,kn)=>{ const a=th*dg, b=(th+kn)*dg, K=[T1*Math.cos(a), -T1*Math.sin(a)]; return { K, F:[K[0]+T2*Math.cos(b), K[1]-T2*Math.sin(b)] }; };
    legFK={ F:leg(P.lFT,P.lFK), B:leg(P.lBT,P.lBK) }; const drop=Math.max(legFK.F.F[1]*csF, legFK.B.F[1]*csB); hips=[Math.round(P.b[0]*sc), -Math.round(P.legH!=null?P.legH:drop)]; }   /* legH: 골반 높이 직접 지정(공중 자세 등) */
  const shF=add(hips,tor(V.shF)), shB=add(hips,tor(V.shB)), legF=add(hips,R.legF), legB=add(hips,R.legB);
  const headBase=add(hips,tor(R.head)), head=add(headBase,RI([P.h[0]*sc,P.h[1]*sc]));
  if(d.model3 && P.ty){ const sx=Math.sin(P.ty)*6.6; shF[0]+=sx; shB[0]-=sx; }  // 몸통을 비틀면 가까운 어깨가 앞으로, 먼 어깨가 뒤로
  let handF=rotEnd(shF[0],shF[1],q(P.aF),R.armLenF), handB=rotEnd(shB[0],shB[1],q(P.aB),R.armLenB), armF=null, armB=null;
  const fkArm=(S,u,l)=>{ const tu=u*Math.PI/8, tl=l*Math.PI/8, K=[S[0]+R.upper*Math.sin(tu), S[1]+R.upper*Math.cos(tu)];
    return { K, aT:u, aS:l, F:[K[0]+R.fore*Math.sin(tl), K[1]+R.fore*Math.cos(tl)] }; };
  if(R.upper && P.armFK){ armF=fkArm(shF,P.uF,P.lF); armB=fkArm(shB,P.uB,P.lB); handF=RI(armF.F); handB=RI(armB.F); }
  else if(R.upper){ armF=solveArm(shF,P.aF,P.eF,R.upper,R.fore*(P.strF||1),P.upF); armB=solveArm(shB,P.aB,P.eB,R.upper,R.fore*(P.strB||1),P.upB); handF=RI(armF.F); handB=RI(armB.F); }
  const tip=rotEnd(handF[0],handF[1],q(P.w),R.glowLen||12);
  const L1=R.thigh||6, L2=R.shin||7, LL=L1+L2;
  const tgt=(fp,base)=>[base[0]+(fp?fp[0]:0)*LL, Math.min(0,(fp?fp[1]:0)*LL)]; // 발 목표는 몸과 무관하게 바닥 기준 → 몸을 낮추면 무릎이 굽음
  const sprKF=d.model3?1/Math.cos((P.sprF??P.spr??0)*Math.PI/180):1, sprKB=d.model3?1/Math.cos((P.sprB??P.spr??0)*Math.PI/180):1, tgtS=(fp,base,lg,k)=>{ const T=tgt(fp,base); return k===1?T:[T[0], lg[1]+(T[1]-lg[1])*k]; };   /* 다리를 벌리면 발이 들리므로 그만큼 목표를 낮춰 둔다 */
  const kL=P.strL||1, fkL=(lg,L)=>({ K:[lg[0]+L.K[0], lg[1]+L.K[1]], F:[lg[0]+L.F[0], lg[1]+L.F[1]], aT:0, aS:0 });
  const ikF=legFK ? fkL(legF,legFK.F) : solveLeg(legF,tgtS(P.fF,R.legF,legF,sprKF),L1*kL,L2*kL), ikB=legFK ? fkL(legB,legFK.B) : solveLeg(legB,tgtS(P.fB,R.legB,legB,sprKB),L1,L2);   // 차는 다리만 순간 늘이기(과장)
  const kneeF=RI(ikF.K), kneeB=RI(ikB.K), footF=RI(ikF.F), footB=RI(ikB.F);
  c.jw={ W2, f, rr, hips, headBase, head, shF, shB, handF, handB, elbF:armF?armF.K:shF, elbB:armB?armB.K:shB, legF, legB, kneeF, kneeB, tip, footF, footB, LL, neck:add(hips,tor([0,R.head[1]])) };
  if(c.hidden || (c.blink && Math.floor(gameTime*12)%2)) return;
  if(d.model3){
    const wkey = ({it_bat:'bat',it_knife:'knife',w_knife:'knife',w_paper:'paper',w_umb:'umb',w_case:'case',w_wrench:'wrench',w_guitar:'guitar',w_hammer:'hammer',w_pan:'pan',w_cleaver:'cleaver'})[c.wpn]||null;
    const j={ hips, neck:add(hips,tor([0,R.head[1]])), head, legF, legB, kneeF:ikF.K, kneeB:ikB.K, footF:ikF.F, footB:ikB.F,
      shF, shB, elbF:armF?armF.K:shF, elbB:armB?armB.K:shB, handF:armF?armF.F:handF, handB:armB?armB.F:handB };
    for(const k in j) j[k]=[j[k][0]+rr-gr, j[k][1]-air]; j.wpn=wkey; c._topY=d.y+Math.min(j.head[1]-6, j.handF[1], j.handB[1], j.footF[1], j.footB[1]);          // 대시 · 공중 · 걷기 잔여 거리
    const tyv=P.ty||0; j.zF=6.6*Math.cos(tyv); j.zB=-6.6*Math.cos(tyv);
    const rm = c.remap ? (m=>{ const k=(c.remap-1)*6; for(let q=0;q<3;q++) if(REMAP[k+q*2]>0 && REMAP[k+q*2]===m) return REMAP[k+q*2+1]; return m; }) : (m=>m);
    if(c.pass && c.anim==='pass' && c.passPose==='sb_strap' && c.handDX==null){ const f=d.flip?-1:1, hx=j.handF[0], hz=j.zF, xr=hx*CY-hz*SY, zr=hx*SY+hz*CY;   // 손잡이 잡은 손의 화면 위치
      c.handDX=f*xr; c.handDY=j.handF[1]*CP+zr*SP; }
    const bones=charBones(j,(c===GS.hero&&GS.skinPv&&GS.skinPv.spin)?{ ...P, spin:(P.spin||0)+GS.skinPv.spin }:P,R,tq); pushModel(c, bones, d.x+drawOX, d.y, rm, fl>0);
    if(d.face && !(fl>0)) pushFace(c, bones.head, d.x+drawOX, d.y);
    if(P.smear && SPR[d.smear+P.smear]){ const w=W2(P.smearAt==='hip'?add(hips,[2,4]):P.smear==='b'?add(handF,[-14,0]):shF); placeAt(d.smear+P.smear, w[0], w[1], d.flip, 0); }
    return;
  }
  const wpnName=c.wpn||d.p.wpn; drawRemap=c.remap||0;
  const ix=(part,abs)=>d.p[part]+'@'+m32(Math.round((abs-(a0[part]||0))*2)), tIdx=R.upright?0:q(-tq);
  const parts=[];
  if(d.p.scarf){ const sp=add(hips,tor(R.scarf)); parts.push([d.scarfRot ? d.p.scarf+'@'+m32([0,-2,-6][c.scarfF]+Math.round(-tq*2)) : d.p.scarf+c.scarfF, sp]); }
  const armPartsB = armB ? [[ix('armB',armB.aT),shB],[ix('foreB',armB.aS),RI(armB.K)]] : [[ix('armB',P.aB),shB]];
  const armPartsF = armF ? [[ix('armF',armF.aT),shF],[ix('foreF',armF.aS),RI(armF.K)]] : [[ix('armF',P.aF),shF]];
  // 뒷팔을 몸 앞에 그리는 경우: 크로스처럼 뒷손이 몸을 가로지르는 동작, 그리고 MMA 가드(뒷손이 턱 앞) — 머리보다 앞, 앞팔보다 뒤
  const fB=(POSES[c.pose]&&POSES[c.pose].frontB) || (d.mma && c.pose.startsWith('m_'));
  const tailPart = d.p.tail ? [[d.p.tail+'@'+m32(Math.round(((P.tail||0)-tq*.5)*2)), add(hips,[-1,-2])]] : [];
  parts.push([ix('thighB',ikB.aT),legB],[ix('shinB',ikB.aS),kneeB],...(fB?[]:armPartsB),[ix('thighF',ikF.aT),legF],[ix('shinF',ikF.aS),kneeF],...tailPart,
    [((d.p.torsoV&&d.p.torsoV[tv])||d.p.torso)+'@'+tIdx,hips],[d.p.off,handB],[d.p.head+'@'+tIdx,head],...(fB?armPartsB:[]),...armPartsF,[wpnName+'@'+m32(Math.round((P.w-(a0.wpn||0))*2)),handF]);
  if(P.smear && SPR[d.smear+P.smear]) parts.push([d.smear+P.smear, P.smearAt==='hip'?add(hips,[2,4]) : (d.smear==='smearN_' && P.smear==='b') ? add(handF,[-14,0]) : shF, true]);
  parts.forEach(([n,l,noFlash],k)=>{ drawPart = d.lines ? k+1 : 0; const w=W2(l); placeAt(n, w[0], w[1], d.flip, noFlash?0:fl); });
  drawRemap=0; drawPart=0;
  if(d.glow){ const g=W2(tip), k=sc<1?.55:1; out.push({x:g[0]+.5,y:g[1]+.5,z:7*k,r:(P.smear?46:36)*k,c:[1,.78,.33],i:P.smear?1.4:.95}); }
  if(d.eye){ const e=W2(add(head,tor(d.eye))); out.push({x:e[0]+.5,y:e[1]+.5,z:5,r:18,c:[1,.18,.22],i:.9}); }
  // 불러온 파츠의 발광 부위는 파츠를 따라 움직이는 광원이 된다
  if(d.partLights) for(const L of d.partLights){
    const base={wpn:handF, off:handB, head, torso:hips, armF:shF, armB:shB}[L.part]; if(!base) continue;
    const ang={wpn:P.w-(a0.wpn||0), armF:P.aF-(a0.armF||0), armB:P.aB-(a0.armB||0), head:-tq, torso:-tq}[L.part]||0;
    const g=W2(add(base,RI(rotV(L.off,Math.round(ang*2)/2))));
    out.push({x:g[0]+.5,y:g[1]+.5,z:8,r:Math.min(70,18+4*Math.sqrt(L.n)),c:L.c,i:.95}); }
  if(P.charge){ const g=W2(tip), pulse=.6+.4*Math.sin(gameTime*18);
    out.push({x:g[0]+.5,y:g[1]+.5,z:8,r:42,c:[.7,.85,1],i:1.5*pulse}); placeAt(Math.floor(gameTime*12)%2?'spark0':'spark1', g[0], g[1], false, 0); }
}
const flies=[...Array(7)].map((_,i)=>({ bx:20+hash(i)*216, by:64+hash(i+9)*30, ph:hash(i+3)*6.28 }));

