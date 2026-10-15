// =========================================================
// 코믹스 컷인(필살기 · 두목 등장 VS · 두목 분노) + 필살기 3종(계열별) + 급행 게이지
// =========================================================
const OPT=(()=>{ const d={ autoSpc:false, shortCut:true, noFlash:false }; try{ return { ...d, ...JSON.parse(localStorage.getItem('dotlab-opt')||'{}') }; }catch(e){ return d; } })();
const optSave=()=>{ try{ localStorage.setItem('dotlab-opt', JSON.stringify(OPT)); }catch(e){} };
try{ if(OPT.skin && OPT.skin!=='jw') applySkin(OPT.skin,true); }catch(e){}
const SPC={ fist:{ n:'막차 러시', en:'LAST TRAIN RUSH', fx:'KA-POW!', art:'fist:x' }, foot:{ n:'회전 폭풍', en:'SPIN STORM', fx:'WHOOOSH!', art:'shoe:x' }, grap:{ n:'종착역', en:'END OF THE LINE', fx:'KA-BOOM!', art:'fist:x' } };
const BOSS_INFO={ boss:{ n:'기관실 두목', nick:'D선의 주인', col:'#ff6319', rage:'…이제 진짜다.' }, boss2:{ n:'기어단 두목', nick:'고가선의 톱니', col:'#00933c', rage:'톱니가 맞물렸군!' }, boss4:{ n:'바이퍼 두목', nick:'퀸스의 네온', col:'#b933ad', rage:'네온이 꺼지기 전에 끝내 주지!' }, kaneB:{ n:'빅터 케인', nick:'배신자', col:'#e8e2d0', rage:'보스도 끝까지 너를 믿었지. 그래서 졌다.' }, mgr:{ n:'빌딩 관리인', nick:'열쇠 꾸러미', col:'#c9a24a', rage:'이 건물 열쇠는 전부 내 거다!' }, headchef:{ n:'총주방장', nick:'불꽃의 주방', col:'#ff7a2e', rage:'주방에서 버틴 놈은 처음이군!' }, boss3:{ n:'청룡방 두목', nick:'시티 홀의 그림자', col:'#e8322a', rage:'놀이는 끝이다.' } };
function cutDur(key,full){ META.seenCut=META.seenCut||{}; const seen=META.seenCut[key]; META.seenCut[key]=1; metaDirty=true; return OPT.shortCut && seen ? Math.min(full,.5) : full; }
function spcGain(v){ if(GS.spc) return; const was=GS.sp||0; GS.sp=Math.min(100,was+v); if(was<100 && GS.sp>=100){ sfx.ready(); hint('sp'); comicSay(GS.hero,'…끝내 볼까.','think',true); } }
const spcKind=()=>{ const sum={fist:0,foot:0,grap:0}; for(const b of GS.bag){ const f=GITEMS[b.id].fam; if(f) sum[f]+=b.tier||1; } return Object.keys(sum).reduce((a,k)=>sum[k]>sum[a]?k:a,'fist'); };
const buzz=p=>{ try{ if(OPT.vibe!==false && navigator.vibrate && matchMedia('(pointer:coarse)').matches) navigator.vibrate(p); }catch(e){} };
const canSpecial=()=> GS.on && !GS.spc && !GS.cut && GS.hero && !GS.hero.dead && ['fight','arrive','board','final'].includes(GS.state) && foes().length>0;
function trySpecial(){ if((GS.sp||0)>=100 && canSpecial()){ startSpecial(); return true; } return false; }
function startSpecial(){ { const k0=spcKind(); cmdPush({ name:{fist:'막차 러시',foot:'회전 폭풍',grap:'종착역'}[k0]||'필살기', sp:true }); } const H=GS.hero, kind=spcKind(); GS.sp=0; sfx.gong(); buzz([40,30,60]); GS.faceMood='shout'; GS.faceUntil=performance.now()/1000+1.6; if(!OPT.noFlash) GS.invF=1;
  for(const a of foes()){ a.action=null; a.queue=[]; } H.action=null; H.queue=[]; setAnim(H,'idle');
  GS.cut={ k:'spc', kind, t:0, dur:cutDur('spc_'+kind,1.05), pause:true }; META.spc=META.spc||{}; META.spc[kind]=(META.spc[kind]||0)+1; metaDirty=true; }
function spcBegin(kind){ const H=GS.hero, S=GS.spc={ kind, t:0, hits:new Map(), hl:new Map(), x0:H.d.x, n:0 }; sfx.slowIn(); GS.camC=[H.d.x/W,(H.d.y-44)/SB.H];
  for(const a of foes()) a.e.stun=Math.max(a.e.stun||0,9);
  if(kind==='fist'){ const L=foes().filter(a=>a.d.x<H.d.x).length, R=foes().length-L; S.dir=R>=L?1:-1; S.x1=S.dir>0?SB.W-28:28; H.d.flip=S.dir<0; }
  if(kind==='foot'){ S.pole = (GS.prologue||GS.tower) ? H.d.x : POLES.reduce((b,x)=>Math.abs(x-H.d.x)<Math.abs(b-H.d.x)?x:b, POLES[0]); }
  if(kind==='grap'){ S.tgt=foes().slice().sort((a,b)=>b.e.hp-a.e.hp)[0]; S.dir = S.tgt.d.x<SB.W/2 ? 1 : -1; } }
const spcVis=a=>{ const x=a.d.x; return x>=CAMX-6 && x<=CAMX+VW+6 && x>-4 && x<SB.W+4; };                       // 필살기는 화면에 보이는 적만(크롭 밖 · 복도 대기 중 제외)
const legRunOff=()=>{ for(const a of GS.ents) a.legRun=false; };
const SPC_LIFT=2;    // 들어 올린 적: 자세 자체가 13 떠 있어 이만큼이면 손 위에 얹힌다(24면 손에서 떠서 천장을 뚫었다)
function spcUpdate(dt){ const S=GS.spc; if(!S) return; S.t+=dt; const H=GS.hero, K=(1+.12*GS.ci)*(1+.2*(GS.stageIdx||0)), bk=a=>a.e.boss?.5:1;
  const hit=(a,d,o)=>{ if(a.dead || !spcVis(a)) return; damage(H,a,Math.max(1,Math.round(d*K*bk(a))),o); S.n++; GS.spcHitT=.09; };
  if(S.kind==='fist'){ const dur=.85;                                                     // 막차 러시: 칸 끝까지 달리며 연타 → 어퍼컷으로 전원 띄우기
    if(S.t<dur){ const nx=S.x0+(S.x1-S.x0)*Math.min(1,S.t/dur), mdx=nx-H.d.x; H.d.x=nx; advGait(H,mdx,true); H.legRun=true; const sw=Math.floor(S.t/.1); if(sw!==S.sw){ S.sw=sw; setAnim(H,['jab','cross','hook'][sw%3]); sfx.swing(); }
      S.carry=S.carry||[];
      for(const a of foes()) if(!a.dead && spcVis(a) && (a.d.x-H.d.x)*S.dir>-6 && Math.abs(a.d.x-H.d.x)<18 && (S.hits.get(a)||0)<3 && S.t-(S.hl.get(a)??-1)>.07){ S.hits.set(a,(S.hits.get(a)||0)+1); S.hl.set(a,S.t); hit(a,4,{react:'head'}); if(!S.carry.includes(a)) S.carry.push(a); }
      S.carry.forEach((a,k)=>{ if(a.dead) return; const nx=Math.max(16,Math.min(SB.W-16, H.d.x+S.dir*(14+k*9))); a.gph=(a.gph||0)-Math.abs(nx-a.d.x)/66; a.legRun=true; a.d.x=nx; a.kb=0; a.d.flip=S.dir>0; }); }   // 열차처럼 앞으로 밀고 간다
    else if(!S.fin){ S.fin=true; legRunOff(); setAnim(H,'upper'); const grp=new Set(S.carry||[]); for(const a of foes()) if((a.d.x-H.d.x)*S.dir>-8 && Math.abs(a.d.x-H.d.x)<34) grp.add(a);
      for(const a of grp) hit(a,22,{react:'launch',crit:true}); spcFinish(); } }
  if(S.kind==='foot'){ const dur=1.15;                                                    // 회전 폭풍: 기둥을 잡고 연속 회전 · 주변을 끌어당겨 휩쓴다
    if(S.t<.15) H.d.x+= (S.pole-(H.d.flip?-5:5)-H.d.x)*Math.min(1,dt*14);
    else if(S.t<dur){ if(H.anim!=='polespin') setAnim(H,'polespin'); const tk=Math.floor(S.t/.17); if(tk!==S.tk){ S.tk=tk; H.d.flip=!H.d.flip; sfx.swing(); HITFX.push({ k:'swirl', x:S.pole, y:H.d.y-30, t:0, life:.4, ph:tk });
        for(const a of foes()){ const d=Math.abs(a.d.x-S.pole); if(d<110){ if(d<46) hit(a,5,{}); a.kb=Math.sign(S.pole-a.d.x)*70; } } } }
    else if(!S.fin){ S.fin=true; for(const a of foes()) if(Math.abs(a.d.x-S.pole)<72) hit(a,20,{knock:true}); HITFX.push({ k:'swirl', x:S.pole, y:H.d.y-30, t:0, life:.5, ph:99, big:true }); spcFinish(); } }   // 회전 반경 안만
  if(S.kind==='grap'){ const T=S.tgt;                                                     // 종착역: 가장 센 적을 잡아 칸 끝까지 끌고 가 바닥에 꽂는다 → 충격파
    if(!T || T.dead){ if(!S.fin){ S.fin=true; spcFinish(); } }
    else if(S.t<.3){ const mdx=(T.d.x-S.dir*14-H.d.x)*Math.min(1,dt*12); H.d.x+=mdx; advGait(H,mdx,true); H.legRun=Math.abs(mdx)>.2; face(H,T.d.x); }
    else { const f=S.dir, place=(dx,air,pose)=>{ T.d.x=H.d.x+f*dx; T.airOv=air; T.pose=T.prev=pose; T.d.flip=f>0; T.kb=0; T.dash=0; T.action=null; T.queue=[]; T.anim='held'; };   // 주인공 자세와 짝: 메치기와 같은 위치 규칙
      if(S.t<1.0){ if(!S.grab){ S.grab=true; setAnim(H,'spcHold'); sfx.swing(); } H.d.flip=f<0;
        if(S.t>.42){ const ox=H.d.x; H.d.x=Math.max(30,Math.min(SB.W-30,H.d.x+f*240*dt)); const mdx=H.d.x-ox; advGait(H,mdx,true); H.legRun=Math.abs(mdx)>.05; T.gph=(T.gph||0)-Math.abs(mdx)/66; T.legRun=H.legRun; if((S.dustT=(S.dustT||0)-dt)<=0){ S.dustT=.07; dusts.push({ x:T.d.x+f*4, y:T.d.y, age:0, flip:f<0 }); } }
        place(13,0,'hl0'); }
      else if(S.t<1.28){ if(!S.lift){ S.lift=true; legRunOff(); setAnim(H,'spcLift'); sfx.swing(); } place(2,SPC_LIFT,(Math.floor(GS.time*10)%2)?'hl1':'hl1b'); }
      else if(S.t<1.4){ if(!S.slam){ S.slam=true; setAnim(H,'spcSlam'); } place(24,10,'hl2'); }
      else if(!S.fin){ S.fin=true; T.airOv=0; T.anim='idle'; hit(T,42,{knock:true,crit:true}); groundImpact(T.d.x,T.d.y,1.8); rings.push({x:T.d.x,y:T.d.y-8,age:0,burst:true}); HITFX.push({ k:'wave', x:T.d.x, y:T.d.y, t:0, life:.55 }); for(const a of foes()){ if(a===T) continue; const d=Math.abs(a.d.x-T.d.x); if(d<90) hit(a,Math.max(4,16*(1-d/90)),{knock:d<60,splash:true}); } shakeAmp=3; spcFinish(); } } }
  if(S.fin && S.t>(S.finT??(S.finT=S.t))+.55){ legRunOff(); GS.spc=null; for(const a of foes()) a.e.stun=Math.min(a.e.stun||0,.8); } }
// 필살기 카메라: 컷인 뒤 0.25초에 1.38배로 당겨 주인공을 따라가고, 마무리에 1.55배 → 0.6초에 걸쳐 풀린다. 시간은 0.5배(타격 순간 0.2배) · 마무리 0.15배
function camTick(rdt){ const want=(PORTRAIT && (scene==='subway'||(scene==='brawl'&&(GS.cine||GS.bonus)))) ? Math.round(H*4/3) : W; if(want!==VW) fit();
  if(VW>=W || !GS.on || !GS.hero){ CAMX=0; return; }
  if(GS.tower){ CAMX += ((W-VW)/2-CAMX)*Math.min(1,rdt*6); return; }   // 타워: 칸이 화면에 꼭 맞게 가운데 고정
  if(GS.bonus){ const c=(GS.hero.d.x+GS.bonus.car.x)/2; CAMX += (Math.max(0,Math.min(W-VW, c-VW/2))-CAMX)*Math.min(1,rdt*3); return; }
  if(GS.cine){ const sx=GS.hero.d.x-GS.cam; CAMX += (Math.max(0,Math.min(W-VW, sx-VW/2+20))-CAMX)*Math.min(1,rdt*3); return; }
  const Hh=GS.hero, F=foes(), f=Hh.d.flip?-1:1; let c=Hh.d.x+f*22; if(F.length && !GS.spc){ const fx=F.reduce((q,a)=>q+a.d.x,0)/F.length; c=c*.62+fx*.38; }   // 주인공(바라보는 쪽 앞) + 적 무게중심
  const tx=Math.max(0, Math.min(W-VW, c-VW/2)); CAMX += (tx-CAMX)*Math.min(1, rdt*(GS.spc?6:2.6)); }                                       // 부드럽게 · 양끝은 연결 통로까지
function spcCamTick(rdt){ const S=GS.spc, H=GS.hero; if(!H) return; GS.spcHitT=Math.max(0,(GS.spcHitT||0)-rdt);
  const djZ = GS.demo && !S && (DJ.zoom||1)>1, Dm = djZ ? dojoDummy() : null;   // 무도장 확대: 주인공과 허수아비 사이를 크게
  let zT = GS.bonus ? 1.3 : djZ ? DJ.zoom : 1, tK=1;                                                                            // 보너스: 주인공과 차 사이를 크게
  if(S && !S.fin){ zT=1.38; tK = GS.spcHitT>0 ? .2 : .5; GS.spcRel=0; }
  else if(S && S.fin){ GS.spcRel=(GS.spcRel||0)+rdt; const r=GS.spcRel; zT = r<.12 ? 1.55 : 1.55-(.55)*Math.min(1,(r-.12)/.6); tK = r<.45 ? .15 : .15+.85*Math.min(1,(r-.45)/.35); }
  else if(GS.spcRel!=null && GS.spcRel<1.4){ GS.spcRel+=rdt; const r=GS.spcRel; zT=Math.max(1,1.55-.55*Math.min(1,(r-.12)/.6)); tK=.15+.85*Math.min(1,Math.max(0,(r-.45)/.35)); if(r>=1.4){ zT=1; tK=1; GS.spcRel=null; } }
  GS.camZ = (GS.camZ||1) + (zT-(GS.camZ||1))*Math.min(1,rdt*(zT>(GS.camZ||1)?9:5));
  const tx=GS.bonus ? ((H.d.x+GS.bonus.car.x)/2+10-(GS.cam||0))/W : djZ ? ((H.d.x+(Dm?Dm.d.x:H.d.x))/2)/W : H.d.x/W, ty=GS.bonus ? (GS.bonus.car.y-34)/SB.H : djZ ? (H.d.y-40-(Dm&&Dm.jug?Dm.jug.h*.5:0))/SB.H : (H.d.y-44)/SB.H; GS.camC=GS.camC||[tx,ty]; GS.camC=[GS.camC[0]+(tx-GS.camC[0])*Math.min(1,rdt*10), GS.camC[1]+(ty-GS.camC[1])*Math.min(1,rdt*10)];
  GS.spcTime=(GS.spcTime||1)+(tK-(GS.spcTime||1))*Math.min(1,rdt*14);
  GS.lbox=(GS.lbox||0)+(((S||((GS.spcRel??9)<1)||GS.prologue)?1:0)-(GS.lbox||0))*Math.min(1,rdt*8); }
function spcFinish(){ const S=GS.spc, H=GS.hero; comicT=0; comicSFX(SB.W/2+(Math.random()-.5)*40, 96, SPC[S.kind].fx); sfx.boom(); GS.spcRel=0;
  DPOPS.push({ x:SB.W/2, y:70, val:S.n, style:'total', label:`SPECIAL · ${SPC[S.kind].n}`, labelCol:'#ffe27a', stack:0, age:0, vx:0, life:1.6 }); }
// --- 두목 등장 · 분노 ---
function bossIntro(a){ const I=BOSS_INFO[a.e.t]; if(!I) return; setTimeout(()=>hint('boss'),2600); sfx.brass(); buzz(70); GS.cut={ k:'vs', boss:a, t:0, dur:cutDur('vs_'+a.e.t,1.9), pause:true }; }
function bossRage(a){ const I=BOSS_INFO[a.e.t]; a.e.raged=true; a.e.cd*=.72; a.e.spd*=1.18; sfx.rage(); GS.cut={ k:'rage', boss:a, t:0, dur:cutDur('rage_'+a.e.t,1.0), pause:true }; }
// --- 컷인 그리기(UI 층): 사선 패널이 미끄러져 들어오고 · 망점 배경 · 속도선 · 잉크 테두리 · 레터링 ---
const easeO=u=>1-Math.pow(1-Math.min(1,Math.max(0,u)),3);
function panel(pts,dx,dy,bg,fn){ const cx=uiCx; cx.save(); cx.translate(dx,dy); cx.beginPath(); pts.forEach(([x,y],i)=>i?cx.lineTo(x,y):cx.moveTo(x,y)); cx.closePath();
  cx.save(); cx.clip(); cx.fillStyle=bg[0]; cx.fillRect(0,0,W,H); cx.fillStyle=bg[1]; for(let y=0;y<H;y+=4) for(let x=(y/4)%2?2:0;x<W;x+=4) cx.fillRect(x,y,1.3,1.3);   // 망점
  const mx=pts.reduce((a,p)=>a+p[0],0)/pts.length, my=pts.reduce((a,p)=>a+p[1],0)/pts.length; cx.strokeStyle=bg[2]; cx.lineWidth=.8; for(let k=0;k<26;k++){ const a=k/26*Math.PI*2; cx.beginPath(); cx.moveTo(mx+Math.cos(a)*30,my+Math.sin(a)*30); cx.lineTo(mx+Math.cos(a)*300,my+Math.sin(a)*300); cx.stroke(); }   // 속도선
  fn&&fn(mx,my); cx.restore(); cx.beginPath(); pts.forEach(([x,y],i)=>i?cx.lineTo(x,y):cx.moveTo(x,y)); cx.closePath();     // 테두리는 패널 모양에(마지막 속도선이 아니라)
  cx.lineWidth=4; cx.strokeStyle='#0e0d14'; cx.stroke(); cx.lineWidth=1.2; cx.strokeStyle='#f1ece0'; cx.stroke(); cx.restore(); }
function letter(txt,x,y,size,fill,rot=-.06){ const cx=uiCx; cx.save(); cx.translate(x,y); cx.rotate(rot); cx.font=`italic 900 ${size}px Impact,"Arial Black",Galmuri11,"Apple SD Gothic Neo","Malgun Gothic",sans-serif`; cx.textAlign='center'; cx.textBaseline='middle'; cx.lineJoin='round';
  cx.fillStyle='#0e0d14'; cx.fillText(txt,2.2,2.6); cx.lineWidth=size*.22; cx.strokeStyle='#0e0d14'; cx.strokeText(txt,0,0); const g=cx.createLinearGradient(0,-size/2,0,size/2); g.addColorStop(0,'#fffbe0'); g.addColorStop(1,fill); cx.fillStyle=g; cx.fillText(txt,0,0); cx.restore(); }
function art(k,x,y,s,flip){ const c=cutArt(k), cx=uiCx; cx.save(); cx.imageSmoothingEnabled=false; if(flip){ cx.translate(x+c.width*s,y); cx.scale(-1,1); cx.drawImage(c,0,0,c.width*s,c.height*s); } else cx.drawImage(c,x,y,c.width*s,c.height*s); cx.restore(); }
function drawCut(dt){ if(!GS.cut) return; const cs=VW/W; uiCx.save(); if(cs<1 && GS.cut.k==='story'){ uiCx.fillStyle='#14121c'; uiCx.fillRect(0,0,VW,H); uiCx.setTransform(UIS*cs,0,0,UIS*cs,0,UIS*(H-H*cs)/2); } else if(cs<1){ uiCx.fillStyle='rgba(8,6,16,.62)'; uiCx.fillRect(0,0,VW,H); uiCx.setTransform(UIS*cs,0,0,UIS*cs,0,UIS*(H-H*cs)/2); } drawCut0(dt); uiCx.restore(); }   // 좁은 화면에선 컷인을 줄여서
function drawCut0(dt){ const C=GS.cut; if(!C) return; C.t+=dt;
  if(C.k==='story'){ if(!sayEl.hidden){ sayEl.hidden=true; sayT=0; } drawStory(C); if(C.t>=C.dur){ GS.cut=null; endPrologue(); } return; } if(!sayEl.hidden){ sayEl.hidden=true; sayT=0; }   /* 컷인 위에 안내 상자가 겹치지 않게 */ const u=C.t/C.dur, out=Math.max(0,(u-.86)/.14), cx=uiCx, sh=u<.12?(Math.random()-.5)*3:0;
  cx.fillStyle=`rgba(8,6,16,${.62*(1-out)})`; cx.fillRect(0,0,W,H); cx.globalAlpha=1-out;
  if(C.k==='spc'){ const S=SPC[C.kind], e=k=>easeO((C.t-k*.07)/.22);
    panel([[14,54],[176,46],[164,206],[6,212]], -(1-e(0))*260+sh, 0, ['#1d2650','#2c3a78','rgba(255,255,255,.08)'], (mx,my)=>art('eyes:hero', mx-96, my-36, 2));
    panel([[184,40],[318,48],[306,214],[172,206]], 0, -(1-e(1))*280, ['#ffcf4a','#ffb02a','rgba(255,255,255,.35)'], (mx,my)=>{ letter(S.n, mx, my-8, 30, '#e8322a'); letter(S.en, mx, my+24, 11, '#3a1a08', -.04); });
    panel([[326,44],[474,52],[470,214],[314,206]], (1-e(2))*260-sh, 0, ['#4a1020','#6a1830','rgba(255,200,120,.12)'], (mx,my)=>art(S.art, mx-(S.art==='shoe:x'?64:56), my-(S.art==='shoe:x'?48:56), 2, C.kind==='foot')); }
  if(C.k==='vs'||C.k==='rage'){ const I=BOSS_INFO[C.boss.e.t]||BOSS_INFO.boss;
    if(C.k==='vs'){ const e1=easeO(C.t/.25), e2=easeO((C.t-.08)/.25);
      panel([[0,36],[250,36],[214,232],[0,232]], -(1-e1)*260+sh, 0, ['#1d2650','#2c3a78','rgba(255,255,255,.08)'], ()=>art('face:hero', 30, 70, 2.4));
      panel([[262,36],[480,36],[480,232],[226,232]], (1-e2)*260-sh, 0, ['#2a0e14',I.col,'rgba(255,255,255,.1)'], ()=>art('face:'+C.boss.e.t, 300, 70, 2.4, true));
      if(C.t>.2){ letter('VS', 240, 128, 42, '#ff8a2a', -.12); }
      if(C.t>.3){ const yy=208; cx.fillStyle=I.col; cx.fillRect(250,yy,230,22); cx.fillStyle='#0e0d14'; cx.fillRect(250,yy+22,230,3); letter(I.n, 360, yy+10, 15, '#ffffff', 0); letter(I.nick, 360, yy-10, 9, '#ffe27a', 0); }
      if(C.t>.45){ letter(BOSS_LINES[C.boss.e.t]||'', 128, 214, 12, '#ffe27a', -.03); } }
    else { const e1=easeO(C.t/.2); panel([[0,84],[480,74],[480,180],[0,190]], -(1-e1)*480+sh, 0, ['#2a0a0e','#7a1018','rgba(255,120,80,.18)'], (mx,my)=>art('rage:'+C.boss.e.t, mx-144, my-54, 3));
      if(C.t>.25) letter(I.rage, 360, 196, 15, '#ff6a4a', -.04); } }
  cx.globalAlpha=1;
  if(C.t>=C.dur){ GS.cut=null; if(C.k==='spc') spcBegin(C.kind); if(C.k==='vs'||C.k==='rage'){ const I=BOSS_INFO[C.boss.e.t]; comicSay(C.boss, C.k==='vs'?(BOSS_LINES[C.boss.e.t]||'…'):I.rage, 'shout', true); } } }
// --- 급행 게이지 · 필살 버튼 ---
function hudPortrait(art,x,y,sz,hurt){ const src=cutArt(art), cr=36, sx=14, sy=6;                         // 컷인 원화 머리 부분(36px)을 2배 정수 배율로(UI 층 3배 해상도)
  uiCx.fillStyle='#0e0d14'; uiCx.fillRect(x-2,y-2,sz+4,sz+4); uiCx.fillStyle=hurt&&Math.floor(performance.now()/200)%2?'#7a1a20':'#2a3a6a'; uiCx.fillRect(x,y,sz,sz);
  for(let yy=0;yy<sz;yy+=2) for(let xx=(yy/2)%2;xx<sz;xx+=2){ uiCx.fillStyle='rgba(255,255,255,.07)'; uiCx.fillRect(x+xx,y+yy,.5,.5); }
  uiCx.imageSmoothingEnabled=false; uiCx.drawImage(src,sx,sy,cr,cr,x,y,sz,sz); uiCx.fillStyle='#f1ece0'; uiCx.fillRect(x-1,y-1,sz+2,.5); }
function bossBar(B){ const w=Math.min(170,VW-150), I=BOSS_INFO[B.e.t], x=Math.round(VW-w-14), y=H-15, k=Math.max(0,B.e.hp)/B.e.max; B.e.lag=(B.e.lag??k)+(k-(B.e.lag??k))*.06;
  hudPortrait('face:'+B.e.t, x-24, y-6, 18, B.e.raged);
  uiCx.font='10px Galmuri9,monospace'; uiCx.textBaseline='alphabetic'; uiCx.fillStyle='#0e0d14'; uiCx.fillText(I.n,x+1,y-1); uiCx.fillStyle='#f1ece0'; uiCx.fillText(I.n,x,y-2);
  uiCx.fillStyle=I.col; uiCx.fillText(I.nick, x+uiCx.measureText(I.n).width+6, y-2);
  uiCx.fillStyle='#0e0d14'; uiCx.fillRect(x-1,y+1,w+2,7); uiCx.fillStyle='#2a1018'; uiCx.fillRect(x,y+2,w,5); uiCx.fillStyle='#f3e3c2'; uiCx.fillRect(x,y+2,Math.round(w*B.e.lag),5);
  uiCx.fillStyle= B.e.raged ? (Math.floor(performance.now()/140)%2?'#ff4a3a':'#c8241c') : '#e0a33a'; uiCx.fillRect(x,y+2,Math.round(w*k),5); uiCx.fillStyle='rgba(255,255,255,.35)'; uiCx.fillRect(x,y+2,Math.round(w*k),1);
  uiCx.fillStyle='#0e0d14'; uiCx.fillRect(x+Math.round(w/2),y+2,1,5); }
function drawSpGauge(){ const blocks=Math.ceil(GS.max/10), w=blocks*7-1, y=H-19, x0=34, k=(GS.sp||0)/100, ready=k>=1;
  uiCx.fillStyle='#0e0d14'; uiCx.fillRect(x0-1,y-1,w+2,5); uiCx.fillStyle='#3a2a10'; uiCx.fillRect(x0,y,w,3);
  uiCx.fillStyle= ready ? (Math.floor(performance.now()/120)%2?'#fff1a0':'#ffb02a') : '#ffb547'; uiCx.fillRect(x0,y,Math.round(w*k),3);
  pxText(x0+w+4,y-1, ready?'READY':'SP', ready?'#fff1a0':'#c58a34');
  const b=document.getElementById('spcBtn'); if(b){ const show=ready&&canSpecial()&&gOverlay.hidden&&!GS.cut; if(b.hidden===show) b.hidden=!show; } }   /* 메뉴 · 매점이 열려 있으면 숨김 */

let lastDT=performance.now();
function drawDmg(){ const now=performance.now(), rdt=Math.min(.1,(now-lastDT)/1000)*(playSpeed||1), dt=Math.min(.05,rdt); lastDT=now; uiCx.imageSmoothingEnabled=false;   /* 컷인은 실제 시간에 가깝게(저사양에서도 늘어지지 않게) */
  uiCx.setTransform(UIS,0,0,UIS,0,0); if(GS.on && GS.hero && !GS.cine && !GS.demo) drawSpGauge(); if(GS.on && GS.hero) drawCmdLog();                                       // HUD: 화면 고정
  const vz=GS.on?(GS.viewZ||1):1, vc=GS.viewC||[.5,.5], zx=vc[0]*W, zy=vc[1]*H;
  const shv=GS.on?Math.max(-5,Math.min(5,shakeX+Math.round(GS.shoveX||0))):0;
  uiCx.setTransform(UIS*vz,0,0,UIS*vz, UIS*(zx-CAMX-zx*vz+shv*vz), UIS*(zy-zy*vz));                                       // 화면 줌과 같은 변환(인물 위 숫자 · 말풍선이 어긋나지 않게)
  for(const c of (GS.critFx||[])){ c.t+=dt; const k=1-c.t/.16; if(k<=0) continue; const L=(c.big?34:24)*k+6, th=c.big?3:2;
    for(const [ang,col] of [[-.62,'#fff6d8'],[.62,'#ffcf4a']]){ const dx=Math.cos(ang)*L, dy=Math.sin(ang)*L; uiCx.fillStyle=col;
      for(let q=-1;q<=1;q+=.04){ uiCx.fillRect(Math.round(c.x+dx*q),Math.round(c.y+dy*q),th,th); } }
    if(c.big && !OPT.noFlash){ uiCx.fillStyle='rgba(255,246,216,'+(k*.35)+')'; uiCx.fillRect(0,0,W,H); } }                                        // 큰 치명타: 화면이 한 번 하얗게
  if(GS.critFx) GS.critFx=GS.critFx.filter(c=>c.t<.16);
  drawHitFx(dt); if(titleEl.hidden) drawComic(dt);
  if(GS.on) for(const a of GS.ents){ if(a.idle!=='doze'||a.hidden||a.goal!=null||a.passPose!=='sb_sit') continue; const ph=(performance.now()/1000*.6+a.d.x*.013)%1; uiCx.globalAlpha=1-ph; pxText(Math.round(a.d.x+4+ph*6), Math.round(a.d.y-50-ph*12), 'Z', '#cfe8ff'); uiCx.globalAlpha=1; }   // 조는 승객
  const ease=u=>Math.pow(1-Math.min(1,Math.max(0,u)),3);                                          // 처음엔 빠르게, 끝에서 천천히 내려앉는다
  for(const p of DPOPS){ p.age+=dt; const S=DSTYLE[p.style], str=(p.style==='heal'?'+':'')+p.val, pop=1+(p.style==='crit'?.7:1)*ease(p.age/.14);   // 꽂히듯 커졌다 매끄럽게 줄어든다
    const rise = -10*(1-Math.exp(-p.age*12)) - (p.age>.7 ? (p.age-.7)*26 : 0), alpha = p.age>p.life-.3 ? Math.max(0,(p.life-p.age)/.3) : 1;
    const adv=5*S.s-1, gh=(7*S.s+2), w=str.length*adv*pop, x0=Math.max(CAMX+3, Math.min(CAMX+VW-3-w, p.x+p.vx*Math.min(p.age,.3)-w/2)),   /* 화면 끝에서 잘리지 않게 */ base=p.y-p.stack*(7*S.s+3)+rise+gh, y0=base-gh*pop;   // 바닥선 기준으로 커진다
    uiCx.globalAlpha=alpha; let x=x0; for(const ch of str){ const gl=dGlyph(ch,p.style); uiCx.drawImage(gl,x,y0,gl.width*pop,gl.height*pop); x+=adv*pop; }
    if(p.label && p.age>.04){ const lw=p.label.length*4; outlined(Math.round(x0+w/2-lw/2), y0-8, p.label, p.labelCol||'#ffcf4a'); }
    if(p.style==='crit' && p.age<.12){ uiCx.fillStyle='rgba(255,240,200,.9)'; for(let k=0;k<8;k++){ const a=k*Math.PI/4, r=10+p.age*120; uiCx.fillRect(Math.round(x0+w/2+Math.cos(a)*r),Math.round(y0+10+Math.sin(a)*r*.6),2,2); } }   // 치명타 별 터짐
    uiCx.globalAlpha=1; }
  for(let i=DPOPS.length-1;i>=0;i--) if(DPOPS[i].age>DPOPS[i].life) DPOPS.splice(i,1);
  // 연타: 크게 "N HIT" + 합계(던파식)
  uiCx.setTransform(UIS,0,0,UIS,0,0);

  // 연타: 화면 오른쪽 위. HIT · 합계 · 게이지는 고정 자리, 숫자만 오른쪽 아래 모서리(바닥선)를 기준으로 왼쪽 위로 커진다
  if((GS.combo||0)>=2 && GS.time-(GS.lastHit||-9)<comboWin()){ const n=String(GS.combo), big=GS.combo>=5, st=big?'crit':'hit', since=GS.time-(GS.lastHit||0), pop=1+(big?.5:1)*ease(since/.16);   /* 매 프레임 조금씩 줄어든다 · 큰 숫자는 1.5배까지만 */
    const xr=VW-12, BASE=54, HIT_X=xr-18, HIT_Y=BASE-6, SUM_Y=BASE+4, BAR_Y=BASE+12, BAR_W=50;   // 고정 좌표
    const g0=dGlyph('0',st), gw=(g0.width-1)*pop, gh=g0.height*pop, w=n.length*gw;
    let x=HIT_X-3-w; const y=BASE-gh+1;                                                                 // 숫자: 오른쪽 아래를 붙잡고 커진다
    for(const ch of n){ const gl=dGlyph(ch,st); uiCx.drawImage(gl,x,y,gl.width*pop,gh); x+=gw; }
    outlined(HIT_X, HIT_Y, 'HIT', big?'#ff7a4a':'#ffd77a');
    if(GS.combo>=3 && GS.comboDmg){ const t=String(GS.comboDmg); outlined(xr-t.length*4+1, SUM_Y, t, '#f1ece0'); }
    const k=Math.max(0,1-since/comboWin()); uiCx.fillStyle='#0e0d14'; uiCx.fillRect(xr-BAR_W,BAR_Y,BAR_W,3); uiCx.fillStyle=big?'#ff7a4a':'#ffd77a'; uiCx.fillRect(xr-BAR_W+1,BAR_Y+1,Math.round((BAR_W-2)*k),1); }
  drawWipe(rdt); drawCut(rdt);
}

const UIS=3;                                                                          // UI 층 해상도 배율: 도트 모양은 그대로, 크기 · 위치 변화만 촘촘하게
// 무도장 화면 정보: 지금 동작 · 단계 · 자세 · 프레임 / 허수아비 / 거리 · 마지막 타격 / 재생 상태
function drawDojoHUD(){ const Hh=GS.hero, D=dojoDummy(); if(!Hh) return; const cx=uiCx;
  const fr=c=>{ const si=c.si||0; if(c._djA!==c.anim || c._djT==null || (si<(c._djS||0) && !LOOP.has(c.anim))){ c._djA=c.anim; c._djT=tick; } c._djS=si; return tick-c._djT; };   // 동작이 시작된 뒤 지난 프레임(12fps)
  const info=c=>{ const sq=seqOf(c.anim,c)||[]; return `${c.anim}  ${Math.min((c.si||0)+1,sq.length||1)}/${sq.length||1}  ${c.pose||''}  ${fr(c)}f`; };
  const L=DJ.hit, rows=[[tr('주인공'), info(Hh), '#ffd34a']];
  if(D) rows.push([tr('상대'), info(D)+(D.jug?`  ↑${Math.round(D.jug.h)}`:''), '#ff9a7a']);
  rows.push([tr('거리'), (D?String(Math.round(Math.abs(D.d.x-Hh.d.x))):'-')+(L?`   ${L.me?tr('맞음'):tr('타격')} ${L.n} ${L.dmg}${L.crit?' '+tr('치명'):''}${L.air?' '+tr('공중'):''}${L.r?' · '+L.r:''}`:''), '#9fd6ff']);
  cx.font='10px Galmuri9,monospace'; cx.textBaseline='top'; cx.textAlign='left';
  const lw=Math.max(...rows.map(r=>cx.measureText(r[0]).width))+6, tw=Math.min(VW-12, Math.max(...rows.map(r=>lw+cx.measureText(r[1]).width))+10);
  cx.fillStyle='rgba(8,6,14,.72)'; cx.fillRect(4,4,tw,rows.length*12+5);
  rows.forEach(([k,v,c],i)=>{ cx.fillStyle=c; cx.fillText(k,9,7+i*12); cx.fillStyle='#ece6f8'; cx.fillText(v,9+lw,7+i*12); });
  const st=(gamePaused?tr('멈춤'):(Math.round(playSpeed*100)/100)+'×')+(DJ.rep?'  '+tr('반복'):'')+((DJ.zoom||1)>1?`  ${tr('확대')} ${DJ.zoom}×`:''), sw=cx.measureText(st).width;
  cx.fillStyle=gamePaused?'rgba(120,30,20,.85)':'rgba(8,6,14,.72)'; cx.fillRect(VW-sw-14,SB.H-18,sw+10,14); cx.fillStyle=gamePaused?'#ffd0b8':'#cfc6e6'; cx.fillText(st,VW-sw-9,SB.H-15);
  cx.textBaseline='alphabetic'; }
function drawUI(){
  if(uiCv.width!==VW*UIS||uiCv.height!==H*UIS){ uiCv.width=VW*UIS; uiCv.height=H*UIS; }
  uiCx.setTransform(1,0,0,1,0,0); uiCx.clearRect(0,0,uiCv.width,uiCv.height); uiCx.setTransform(UIS,0,0,UIS,0,0); uiCx.imageSmoothingEnabled=false;
  if(scene==='octagon' && !GS.on){ drawOctHUD(); return; }
  if(sayT>0){ sayT-=1/60; if(sayT<=0) sayEl.hidden=true; }
  if(!GS.on) return;
  if(GS.skinPv) return;   // 스킨 미리보기: HUD 없이 주인공만
  if(GS.bagSlowT>0 && inCombat()){ uiCx.strokeStyle='rgba(110,232,220,.75)'; uiCx.lineWidth=2; uiCx.strokeRect(1,1,VW-2,SB.H-2);   /* 이 함수 안의 H는 주인공이라 화면 높이는 SB.H */ const t='정리 중 · 시간 느림'; uiCx.font='10px Galmuri9,monospace'; const tw=uiCx.measureText(t).width;
    uiCx.fillStyle='rgba(8,20,24,.85)'; uiCx.fillRect(VW/2-tw/2-6,SB.H-48,tw+12,14); uiCx.fillStyle='#8ff0e4'; uiCx.textAlign='center'; uiCx.textBaseline='middle'; uiCx.fillText(t,VW/2,SB.H-41); uiCx.textAlign='left'; uiCx.textBaseline='alphabetic'; }   // 정리 중 표시: 캡션에 가리지 않게 아래 가운데
  if(GS.cine){ const C=GS.cine, bh=22; uiCx.fillStyle='#000'; uiCx.fillRect(0,0,VW,bh); uiCx.fillRect(0,H-bh,VW,bh);              // 거리 연출: 레터박스 · 하얀 빛에서 열리고 어둠으로 닫힌다
    drawDmg(); if(C.flash>0){ uiCx.fillStyle=`rgba(234,255,236,${C.flash})`; uiCx.fillRect(0,0,VW,H); } if(C.fade>0){ uiCx.fillStyle=`rgba(0,0,0,${C.fade})`; uiCx.fillRect(0,0,VW,H); } return; }
  if(GS.lbox>.01){ const bh=Math.round((GS.prologue?20:24)*GS.lbox); uiCx.fillStyle='#000'; uiCx.fillRect(0,0,VW,bh); uiCx.fillRect(0,H-bh,VW,bh); }   // 레터박스(HUD 아래)
  if(GS.demo) drawDojoHUD(); else {   // 무도장: 노선도 · 체력 대신 동작 정보
  // 노선도: A 급행 정차역(번호) — 지난 역은 흐리게, 다음 역은 깜빡임. 파란 선 = 8번가선(A·C·E)
  let x=10; const y=8;
  if(GS.bonus){ drawBonusHUD(); } else if(GS.tower){ drawTowerTop(); } else if(GS.prologue){ pxText(10,y,'B2 CORRIDOR','#9fd6a0'); const k=GS.prologue.x/CORR_LEN; uiCx.fillStyle='#0e0d14'; uiCx.fillRect(9,y+9,122,4); uiCx.fillStyle='#9fd6a0'; uiCx.fillRect(10,y+10,Math.round(120*k),2); } else {
  uiCx.fillStyle=STAGE.color; uiCx.fillRect(10,y+3,STOPS.length*26-12,2);  // 노선 색(D 주황 · 4 초록)
  STOPS.forEach((id,i)=>{ const passed = i<=GS.leg && !(GS.atStop===id) && i<GS.leg, here=GS.atStop===id, next=GS.nextStop===id && !GS.atStop;
    uiCx.fillStyle = here?'#ffb547' : passed?'#4a5578' : (next && Math.floor(GS.time*3)%2)?'#ffb547':'#e8eef8'; uiCx.fillRect(x,y,8,8); uiCx.fillStyle='#0c1224'; uiCx.fillRect(x+2,y+2,4,4);
    pxText(x-1,y+11,STN[id].h||STN[id].cap,here||next?'#ffb547':'#8a93ad'); x+=26; });
  } if(!GS.bonus && !GS.tower) pxText(GS.prologue?140:x+4,y+2,String(GS.score).padStart(6,'0'),'#f1ece0');
  if(!GS.tower && ((GS.state==='fight' && !LINE[GS.ci].end) || GS.arriving)){ const Lh=LINE[GS.ci], k=Math.max(0,1-(GS.legT||0)/legDur(Lh)), w=STOPS.length*26-12, nf=foes().length;   // 다음 역까지 남은 시간 막대
    uiCx.fillStyle='#0e0d14'; uiCx.fillRect(9,y+19,w+2,4); uiCx.fillStyle = k<.25&&nf ? (Math.floor(GS.time*6)%2?'#e8524a':'#ffb547') : nf ? '#ffb547' : '#5fd08a'; uiCx.fillRect(10,y+20,Math.round(w*k),2); }
  const auto=GS.manualT<=0; uiCx.fillStyle=auto?'rgba(124,198,255,.25)':'rgba(255,181,71,.3)'; uiCx.fillRect(VW-58,6,52,13);
  pxText(VW-52,10, auto?'AUTO':'MANUAL', auto?'#7cc6ff':'#ffb547');
  // 체력 칸
  { const now=performance.now()/1000, r=GS.hp/GS.max, tr=GS.faceUntil>now ? GS.faceMood : null, m = tr || (r>.7?'':r>.4?'strain':r>.15?'hurt':'crit');
    hudPortrait('face:hero'+(m?'_'+m:''), 6+(tr==='flinch'?Math.round((Math.random()-.5)*2):0), H-32, 24, r<.3); }
  const blocks=Math.ceil(GS.max/10); for(let k=0;k<blocks;k++){ const v=Math.max(0,Math.min(1,(GS.hp-k*10)/10)), lag=Math.max(0,Math.min(1,(GS.lagH-k*10)/10));
    uiCx.fillStyle='#1d2a55'; uiCx.fillRect(34+k*7,H-12,6,5); if(lag>0){ uiCx.fillStyle='#f3e3c2'; uiCx.fillRect(34+k*7,H-12,Math.round(6*lag),5); }
    if(v>0){ uiCx.fillStyle='#3d7bff'; uiCx.fillRect(34+k*7,H-12,Math.round(6*v),5); uiCx.fillStyle='#9cc4ff'; uiCx.fillRect(34+k*7,H-12,Math.round(6*v),1); } }
  const BS=foes().find(a=>a.e.boss && BOSS_INFO[a.e.t]); if(BS) bossBar(BS);
  }
  uiCx.setTransform(UIS,0,0,UIS,-CAMX*UIS,0);                                                                   // 무대 위 요소는 카메라를 따라
  drawShowLamps();
  // 적 머리 위: 체력 · 공격 예고(카운터 기회)
  for(const a of foes()){ const e=a.e, bw=e.boss?30:16, ax=Math.round(a.d.x-bw/2), ay=a.d.y-66;
    if(e.hp<e.max && !(e.boss&&BOSS_INFO[e.t])){ uiCx.fillStyle='#120c16'; uiCx.fillRect(ax-1,ay-1,bw+2,4); uiCx.fillStyle=e.boss?'#e0a33a':'#d8414a'; uiCx.fillRect(ax,ay,Math.round(bw*Math.max(0,e.hp)/e.max),2); }
    if(a.action && !a.action.fired && FOE_W[a.anim] && GS.hero && Math.abs(a.d.x-GS.hero.d.x)<=56){ const tt=timeToCue(a);   // 저스트 고리: 타격 순간에 맞춰 줄어든다
      if(tt!=null && tt<=.6){ const w=FOE_W[a.anim], cx=Math.round(a.d.x), cy=ay-7, jw=tt<=JUST_W(), r=Math.round(4+15*Math.min(1,tt/.6));
        if(!a.ringSeen && !GS.demo){ a.ringSeen=true; hint('just'); }
        uiCx.save(); uiCx.globalAlpha=jw?1:.85; uiCx.strokeStyle=jw?'#ffffff':w==='H'?'#ff5a44':'#7cd4ff'; uiCx.lineWidth=jw?2:1; uiCx.beginPath(); uiCx.arc(cx+.5,cy+.5,r,0,7); uiCx.stroke();
        if(jw){ uiCx.globalAlpha=.35; uiCx.fillStyle=w==='H'?'#ff5a44':'#ffffff'; uiCx.beginPath(); uiCx.arc(cx+.5,cy+.5,r+3,0,7); uiCx.fill(); } uiCx.restore(); } }
    if(a.action && !a.action.fired){ const w=FOE_W[a.anim]||'L', x=Math.round(a.d.x);
      if(w==='H'){ if(Math.floor(GS.time*14)%2===0){ uiCx.fillStyle='#0e0d14'; uiCx.fillRect(x-5,ay-13,10,10); uiCx.fillStyle='#ff4a3a'; for(const dx of [-3,1]){ uiCx.fillRect(x+dx,ay-12,2,5); uiCx.fillRect(x+dx,ay-6,2,2); } } }
      else if(w==='M'){ if(Math.floor(GS.time*10)%2===0){ uiCx.fillStyle='#0e0d14'; uiCx.fillRect(x-2,ay-12,5,10); uiCx.fillStyle='#ffd34a'; uiCx.fillRect(x-1,ay-11,3,5); uiCx.fillRect(x-1,ay-5,3,2); } }
      else if(Math.floor(GS.time*10)%2===0){ uiCx.fillStyle='#ffb547'; uiCx.fillRect(x-1,ay-9,2,5); uiCx.fillRect(x-1,ay-3,2,1); } } }
  for(const b of (GS.barks||[])){ b.t-=1/60; }
  if(GS.flashT>0) pxText(W/2-14,40,GS.flash,'#ffb547');
  { const Hh=GS.hero, inc=Hh&&GS.shots.some(s=>!s.dead&&!s.dodged&&Math.sign(Hh.d.x-s.x)===Math.sign(s.vx)&&Math.abs(s.x-Hh.d.x)<130);
    if(inc && duckReady() && !isDucking(Hh) && Math.floor(GS.time*8)%2===0){ const x=Math.round(Hh.d.x), y=Hh.d.y-92; uiCx.fillStyle='#ffb547';
      for(let k=0;k<4;k++) uiCx.fillRect(x-3+k,y+k,7-2*k,1); pxText(x-8,y-7,'DUCK','#ffb547'); } }
  drawDmg();
  if(GS.fade>0){ uiCx.fillStyle=`rgba(0,0,0,${GS.fade})`; uiCx.fillRect(0,0,W,H); }
  const dps=GS.log.filter(([t])=>t>GS.time-5).reduce((a,[,d])=>a+d,0)/5;
  document.getElementById('gTime').textContent=`점수 ${GS.score}`; document.getElementById('gDps').textContent=`초당 피해 ${dps.toFixed(1)}`;
  if(Math.floor(GS.time*10)%3===0){ hud(); abUpdate(); }
  updateBagCD();
}
function drawOctHUD(){
  const plate=(x,col,flip)=>{ uiCx.fillStyle='rgba(8,8,14,.72)'; uiCx.fillRect(x,5,104,14); uiCx.fillStyle=col; uiCx.fillRect(flip?x+98:x,5,6,14);
    const i=flip?1:0, bx=flip?x+4:x+9, hw=Math.round(90*OCT.hp[i]/100), sw=Math.round(70*OCT.st[i]/100);
    uiCx.fillStyle='#2a1018'; uiCx.fillRect(bx,8,90,4); uiCx.fillStyle=col; uiCx.fillRect(flip?bx+90-hw:bx,8,hw,4);
    uiCx.fillStyle='#2b2410'; uiCx.fillRect(flip?bx+20:bx,14,70,2); uiCx.fillStyle='#e8c25a'; uiCx.fillRect(flip?bx+90-sw:bx,14,sw,2); };
  plate(6,'#d23a44',false); plate(W-110,'#2f6fd6',true);
  uiCx.fillStyle='rgba(8,8,14,.8)'; uiCx.fillRect(W/2-22,4,44,13); const t=Math.ceil(OCT.time), mm=Math.floor(t/60)+':'+String(t%60).padStart(2,'0');
  pxText(W/2-19,8,'R'+OCT.round,'#ffb547'); pxText(W/2-3,8,mm,'#f1ece0');
  for(let k=0;k<3;k++){ uiCx.fillStyle = k===OCT.dist ? '#ffb547' : 'rgba(80,72,110,.9)'; uiCx.fillRect(W/2-13+k*9,H-8,7,3); }
}
function placeUI(){ const el=document.getElementById('ui'); if(!el) return; el.style.left=canvas.offsetLeft+'px'; el.style.top=canvas.offsetTop+'px'; el.style.width=canvas.style.width; el.style.height=canvas.style.height; }
