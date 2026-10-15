/* =========================================================
   7. 렌더
   ========================================================= */
let compProg=null, compU=null, nodeU=[], view=0, fixFlip=true;
// --- 장면 ---
let scene='forest', tod=0, camX=0, panOn=true, showChars=false;
const SCN={ forest:{ W:256, H:144, ground:101, userX:62, chars:[88,168] }, city:CITY_CFG.city, cityV:CITY_CFG.cityV,
  octagon:{ W:320, H:180, ground:150, userX:60, chars:[140,182] },
  brawl:{ W:480, H:270, ground:NFLOOR+28, userX:60, chars:[60,200] },
  noir:{ W:480, H:270, ground:NFLOOR+30, userX:60, chars:[200,262] },
  subway:{ W:480, H:270, ground:SB.FLOOR, userX:60, chars:[100,300] } };
// 느와르 거리 광원: 종류별 색 · 세기 (세계 좌표 → 화면)
const NOIR_KIND={ lamp:{c:[1,.8,.52],i:1.5,r:210,z:30}, tube:{c:[.88,.94,1],i:1.15,r:180,z:22}, neonO:{c:[1,.42,.14],i:1.2,r:100,z:8},
  neonT:{c:[.2,.9,.95],i:1.15,r:140,z:12}, neonR:{c:[1,.18,.2],i:1.15,r:120,z:10}, neonP:{c:[1,.28,.62],i:1.2,r:120,z:10},
  shop:{c:[1,.84,.58],i:.95,r:95,z:10}, bulb:{c:[1,.84,.5],i:1.0,r:150,z:14}, door:{c:[.92,.95,1],i:.8,r:60,z:8} };
function noirLights(ox, time){
  const L=[{dirl:[-.3,.6,.7], c:[.42,.52,.78], i:.1}], cx=W/2-ox;
  const near=NOIR_LIGHTS.slice().sort((a,b)=>Math.abs(a.x-cx)-Math.abs(b.x-cx)).slice(0,7);
  for(const l of near){ const k=NOIR_KIND[l.kind], fl=l.kind.startsWith('neon')? (.9+.1*hash(Math.floor(time*14)+l.x)) : 1;
    L.push(l.kind==='lamp' ? {x:l.x+ox,y:l.y,z:k.z,r:k.r,c:k.c,i:k.i*.9,spot:[0,1],cone:.74} : {x:l.x+ox,y:l.y,z:k.z,r:k.r,c:k.c,i:k.i*fl}); }
  return L;
}
function noirFX(ox, rain=.55){
  const vols=NOIR_LIGHTS.filter(l=>l.kind==='lamp').map(l=>({x:l.x+ox,y:l.y+2,dx:0,dy:1,c:[1,.78,.48],i:1,cone:.86,len:150,halo:10}))
    .concat(NOIR_LIGHTS.filter(l=>l.kind.startsWith('neon')||l.kind==='tube').map(l=>({x:l.x+ox,y:l.y,dx:0,dy:1,c:NOIR_KIND[l.kind].c,i:.45,cone:2,len:1,halo:20})))
    .filter(v=>v.x>-80&&v.x<W+80).slice(0,6);
  return { bloom:.95, reflY:NFLOOR, rain, vig:.55, fog:.18, fogC:[.05,.06,.09], vols };
}
const ACT=()=> (scene==='brawl'||scene==='subway') && GS.on ? GS.ents : CHARS;   // 거리 연출(brawl 무대)도 게임 인물로
const isCity=()=>scene==='city'||scene==='cityV', CC=()=>CITY_CFG[scene];
// 옥타곤 목업 상태 (중계 HUD · 카메라 플래시)
const OCT={ hp:[100,100], st:[100,100], time:300, round:1, dist:0, flashes:[], kd:0 };
function octFlash(n){ for(let i=0;i<n;i++){ const front=Math.random()<.25; OCT.flashes.push({ x:Math.floor(Math.random()*OW), y: front? 156+Math.floor(Math.random()*8) : 20+Math.floor(Math.random()*50), age:0 }); } }
const sceneGround=()=>SCN[scene].ground, sceneUserX=()=>SCN[scene].userX;
const layerOX=w=>{ const c=CC(); return -Math.round(camX*(w-c.W)/(c.world-c.W)); };
const smooth=(a,b,x)=>{ const u=Math.max(0,Math.min(1,(x-a)/(b-a))); return u*u*(3-2*u); };
const mix3=(a,b,u)=>a.map((v,i)=>v+(b[i]-v)*u);
// 시간대 → 하늘빛(방향광) · 환경광 · 창문 점등 비율 · 가로등 · 안개색
function cityTime(t){
  const night=smooth(.55,.95,t), dusk=Math.exp(-Math.pow((t-.5)/.17,2)), day=1-smooth(.2,.7,t);
  let col=mix3([.96,.96,.93],[1,.66,.46],Math.min(1,dusk*1.1)); col=mix3(col,[.45,.55,.88],night);
  const inten=Math.max(.13, .55*day+.45*dusk*(1-day)+.14*night);
  const dir=[.2-.95*dusk, .65-.4*dusk, .73];
  return { dir, col, inten, amb:1-.6*night-.12*dusk, win:smooth(.33,.95,t)*.62, lamp:smooth(.4,.68,t),
    sky:mix3(mix3([.933,.935,.905],[.95,.68,.52],dusk),[.12,.14,.22],night), sun:[dir[0],-dir[1]] };
}
const dogs=[{x:150,v:7,k:'A'},{x:322,v:-5,k:'A'},{x:340,v:-5,k:'B'}], birds=[...Array(6)].map((_,i)=>({x:hash(i+40)*384, y:14+hash(i+50)*40, v:6+hash(i+60)*6}));
let vanX=-60;
function drawCityProps(time, dyn, dt){
  // 개: 보도 위를 어슬렁
  const c=CC();
  for(const d of dogs){ d.x+=d.v*dt; if(d.x<30||d.x>c.world-30) d.v=-d.v; d.x=Math.max(30,Math.min(c.world-30,d.x));
    placeAt('c_dog'+d.k+(Math.floor(time*6)%2), Math.round(d.x), c.dogY, d.v<0, 0); }
}
function drawCityFront(time, dyn, ox, cs){
  const c=CC(), K=scene, L=c.lamps, flipAt=c.world*.6;
  drawDepth=.25;
  for(const x of L.xs){ const fl=x>flipAt; placeAt(K+'_lamp', x, L.base, fl, 0);
    if(cs.lamp>.01){ const sx=x+ox+(fl?-6:6); if(sx>-60&&sx<c.W+60) dyn.push({x:sx+.5,y:L.base-L.h+7.5,z:16,r:76,c:[1,.83,.58],i:1.35*cs.lamp,d:.25}); } }
  drawDepth=.24; quad(K+'_fence1',0,c.fence1.y);
  drawDepth=.2; quad(K+'_road',0,c.roadOY);
  drawDepth=.18; vanX+=16*(time-(drawCityFront.t||time)); drawCityFront.t=time; if(vanX>c.world+60) vanX=-80;
  placeAt('c_van', Math.round(vanX), c.vanY, false, 0);
  if(cs.lamp>.01){ const sx=Math.round(vanX)+ox+20; if(sx>-40&&sx<c.W+60) dyn.push({x:sx+.5,y:c.vanY-8.5,z:6,r:56,c:[1,.95,.82],i:1.1*cs.lamp,d:.18}); }
  drawDepth=.1; quad(K+'_fence2',0,c.fence2.y);
}
let t0=performance.now(), last=t0, acc=0, gameTime=0, lastRT=0;
function render(now){
  const time=gameTime, rdt=Math.max(0,Math.min(.1,time-lastRT)); lastRT=time;
  // --- 스프라이트 목록 ---
  qn=0; n3=0; let q3b=-1; const dyn=[]; drawDepth=0; drawOX=0;
  const city=isCity(), showC=!city||showChars, cs=city?cityTime(tod):null;
  // 느와르 실험실: 두 사람이 화면 안에서 오가며 걷는다 (보폭 동기 걷기 시연)
  if(scene==='noir' && !GS.on && !paused) for(const [i,spd] of [[0,32],[1,26]]){ const c=CHARS[i], d=c.d; if(c.anim==='idle') setAnim(c,'walk'); if(c.anim!=='walk') continue;
    const f=d.flip?-1:1, mv=spd*rdt; d.x+=f*mv; c.gph=(c.gph||0)+mv/(4*.3*24);
    if(d.x>camX+W-40 && !d.flip) d.flip=true; if(d.x<camX+40 && d.flip) d.flip=false; }
  let charOX=0;
  if(GS.on && GS.skinPv){ charOX=0; drawOX=0; }   // 스킨 미리보기: 배경 없이 스튜디오
  else if(city){
    const c=CC(), half=(c.world-c.W)/2;
    if(panOn) camX=half-half*Math.cos(time*.08);
    for(const L of c.layers){ const sky=L.name.endsWith('_sky'); drawDepth=L.depth; drawOX=sky?0:layerOX(L.w); quad(L.name,0,L.oy);
      if(sky){ drawDepth=.95; for(const b of birds){ b.x+=b.v*rdt; if(b.x>c.W+10){ b.x=-10; b.y=c.birdY[0]+Math.random()*(c.birdY[1]-c.birdY[0]); }
        placeAt(Math.floor(time*5+b.v)%2?'c_bird0':'c_bird1', Math.round(b.x), Math.round(b.y+Math.sin(time*1.3+b.v)*2), false, 0); } } }
    charOX=layerOX(c.world);
  } else if(scene==='octagon') quad('oct_bg',0,0);
  else if(scene==='noir'){ if(panOn) camX=720-720*Math.cos(time*.05); charOX=-Math.round(camX); drawOX=charOX;
    for(let k=0;k<4;k++) if(k*NVW+charOX<W && (k+1)*NVW+charOX>0) quad('nb'+k,k*NVW,0); drawOX=0; }
  else if(scene==='subway'){ drawSubwayBack(time); drawOX=0; drawDepth=0; }
  else if(scene==='brawl'){ charOX=-Math.round(GS.cam); drawOX=charOX; for(let k=0;k<4;k++) if(k*NVW+charOX<W && (k+1)*NVW+charOX>0) quad('nb'+k,k*NVW,0); drawOX=0; }
  else quad('bg',0,0);
  drawOX=charOX; drawDepth=city?.26:0;
  const nShadowStart=qn;
  if(showC) for(const c of ACT()){ if(c.hidden||c.invis) continue; const P=curPose(c), sc=c.d.rig.sc||1, sx=c.d.x+(c.d.flip?-1:1)*Math.round((P.b[0]+P.r)*sc);
    if(sc<1) quad('shadow_s', sx-5, c.d.y-1); else quad('shadow', sx-11, c.d.y-2); }
  if(actor) quad('shadow', sceneUserX()-11, sceneGround()-2);
  const nShadowEnd=qn;
  if(scene==='octagon'){ for(const f of OCT.flashes) placeAt(f.age<1?'oct_flash':'oct_flash1', f.x, f.y, false, 0); }
  else if(scene==='brawl'){ drawOX=charOX; drawCineProps(dyn); drawBonusCar(dyn); drawOX=charOX; for(const it of GS.items){ const nm=it.kind==='gear'?null:'it_'+it.kind, y=NFLOOR+it.z-2-Math.round(Math.abs(Math.sin(it.t*4))*2);
      if(nm) placeAt(nm, Math.round(it.x), y, false, 0); else { const ic=GITEMS[it.id].icon; placeAt(SPR[ic]?ic:'it_gem', Math.round(it.x), y-4, false, 0); }
      if(it.kind==='gear') dyn.push({x:it.x+charOX+.5,y:y-6,z:8,r:30,c:[1,.85,.5],i:.8}); } }
  else if(!city){ if(scene!=='subway') for(const f of flies){                                                  /* 반딧불이는 실험실 장면에만(지하철 · 복도엔 그리지 않는다) */ const k=Math.floor(time*6); quad('ff', Math.round(f.bx+5*Math.sin(f.ph+k*.35)), Math.round(f.by+3*Math.sin(f.ph*1.7+k*.5))); } }
  else drawCityProps(time, dyn, rdt);
  drawOX=charOX; drawDepth=city?.26:0;
  const d0=dyn.length;
  actorDraw(dyn);
  if(showC){
    for(const p of dusts) placeAt(p.age<3?'dust0':'dust1', p.x, p.y, p.flip, 0);
    for(const c of ACT().slice().sort((a,b)=>a.d.y-b.d.y)){ if(c.invis) continue; drawChar(c, dyn); c.ox=charOX; }
    q3b=qn;
    if(GS.on) for(const a of GS.ents){ if(!a.pass||a.hidden||a.goal!=null||a.filming||a.dancer||!['sb_sit','sb_strap'].includes(a.passPose)) continue; const f=a.d.flip?-1:1, sit=a.passPose==='sb_sit';
      if(a.idle==='paper') quad(Math.floor((GS.time+a.d.x)/4)%2?'sb_news':'sb_news2', Math.round(a.d.x+f*(sit?7:-3))-5, Math.round(a.d.y+(sit?-42:-52)));   // 신문(가끔 넘긴다)
      if(a.idle==='phone'){ quad('sb_phone', Math.round(a.d.x+f*(sit?6:-6))-2, Math.round(a.d.y+(sit?-36:-50))); dyn.push({x:a.d.x+f*6, y:a.d.y-36, z:12, r:18, c:[.75,.85,1], i:.6}); } }
    if(GS.on && GS.ev && GS.ev.k==='crowd') for(const a of GS.ev.actors) if(a.filming && !a.hidden){ const f=a.d.flip?-1:1, sit=a.passPose==='sb_sit'; quad('sb_phone', Math.round(a.d.x+f*(sit?9:-9))-2, Math.round(a.d.y+(sit?-40:-56))); dyn.push({x:a.d.x+f*(sit?9:-9), y:a.d.y+(sit?-38:-54), z:14, r:26, c:[.75,.85,1], i:.9}); }   // 휴대폰(얼굴 옆) · 화면 불빛
    for(const r of rings) placeAt(r.burst ? 'fx_burst'+Math.min(1,Math.floor(r.age/1.5)) : 'fx_ring'+Math.min(2,Math.floor(r.age)), r.x, r.y, false, 0);
    if(GS.on && GS.bits){ for(const b of GS.bits){ b.t+=rdt; b.x+=b.vx*rdt; b.y+=b.vy*rdt; b.vy+=420*rdt; if(b.y<SB.FLOOR) placeAt('fx_bit',Math.round(b.x),Math.round(b.y),false,0); }
      GS.bits=GS.bits.filter(b=>b.t<.8); }
    drawCrossFront();
    for(const p of sparks){ placeAt(p.age<2?'spark0':'spark1', p.x, p.y, false, 0);
      if(p.age<2) dyn.push({x:p.x+.5,y:p.y+.5,z:10,r:48,c:[1,.95,.85],i:1.6}); }
  }
  for(let i=d0;i<dyn.length;i++) dyn[i].x+=charOX;
  if(city) drawCityFront(time, dyn, charOX, cs);
  drawOX=charOX; drawDepth=city?.26:0;
  if(showC) for(const p of pops){ let x=p.x-Math.floor(p.t.length*2), y=p.y-Math.min(Math.round(p.age),6);
    if(p.age>12 && Math.floor(p.age)%2) continue;
    for(const ch of p.t){ quad('g'+(p.set||'')+ch, x, y); x+= ch==='.'?2:4; } }
  drawOX=0; drawDepth=0;
  if(scene==='octagon'){ drawDepth=0; quad('oct_front',0,0); }
  if(scene==='noir'||scene==='brawl'){ drawOX=Math.round(charOX*1.18); for(const x of [380,1150,1720]) placeAt('n_car', x, NVH+2, x===1150, 0); drawOX=0; }
  if(!city && scene!=='octagon' && scene!=='brawl' && scene!=='noir' && scene!=='subway') placeAt(Math.floor(time*6)%2?'torch1':'torch0', Math.round(torch.x), Math.round(torch.y), false, 0);
  // --- 광원 ---
  const ft=Math.floor(time*12), fl = .86+.14*hash(ft), fl2=.9+.1*hash(ft*3+1);
  lights.length=0;
  if(GS.on && GS.skinPv && GS.hero){ const Hh=GS.hero, x=Hh.d.x, y=Hh.d.y;   // 스튜디오 조명: 위 스폿 · 앞 키 라이트 · 뒤 림 라이트
    lights.push({x, y:y-130, z:30, r:240, c:[1,.95,.86], i:1.15, spot:[0,1], cone:.955}, {x:x+20, y:y-58, z:42, r:150, c:[1,.96,.9], i:1.25}, {x:x-28, y:y-52, z:-24, r:120, c:[.62,.76,1], i:1.0});
  } else if(city){
    lights.push({dirl:cs.dir, c:cs.col, i:cs.inten});
  } else if(scene==='subway'){ const lk=GS.lightK??1; lights.push(...subwayLights(time).slice(0,7).map(l=>l.dirl?{...l,i:l.i*lk}:{...l,i:l.i*lk}));
    const Hh=GS.hero; if(Hh && !Hh.hidden && lk>.02) lights.push({x:Hh.d.x+(Hh.d.flip?-10:10), y:Hh.d.y-48, z:30, r:78, c:[.82,.88,1], i:.6*lk*(GS.oneBit?.5:1)}); // 검은 양복이 어둠에 묻히지 않게
  } else if(scene==='noir' || scene==='brawl'){ lights.push(...noirLights(charOX,time).slice(0,6));
    // 인물을 따라다니는 약한 보조광: 어두운 거리에서도 실루엣과 얼굴이 읽히게
    const who = scene==='brawl' ? [GS.hero, ...GS.ents.filter(a=>a.e&&!a.dead)] : CHARS;
    const H0=who[0]; if(H0 && !H0.hidden) lights.push({x:H0.d.x+charOX+(H0.d.flip?-8:8), y:H0.d.y-46, z:26, r:72, c:[.78,.84,1], i:.45});
    const rest=who.slice(1).filter(c=>c&&!c.hidden); if(rest.length){ const mx=rest.reduce((a,c)=>a+c.d.x,0)/rest.length, my=rest.reduce((a,c)=>a+c.d.y,0)/rest.length;
      lights.push({x:mx+charOX, y:my-50, z:34, r:150, c:[.7,.78,1], i:.4}); } // 적 무리 전체를 덮는 넓은 보조광
  } else if(scene==='brawl'){ // 천장 등: 스테이지가 바뀔수록 어둡고 따뜻하게
    const st=GS.stage, warm=[[1,.94,.82],[1,.72,.45],[.85,.82,1]][st], li=[1.15,1.25,1.35][st];
    lights.push({dirl:[.35,.55,.8], c:[[1,.97,.92],[1,.8,.62],[.6,.7,1]][st], i:[.42,.3,.12][st]}); // 창고 안을 채우는 옅은 보조광
    for(const lx of [110,330,550,770,990,1210]){ const sx=lx+charOX; if(sx>-160&&sx<W+160) lights.push({x:sx,y:6,z:46,r:170,c:warm,i:li*(st===2?(.85+.15*hash(Math.floor(time*10)+lx)):1)}); }
  } else if(scene==='octagon'){ // 천장 트러스 스폿 3개 + 케이지 위 옅은 보조광
    for(const lx of [112,160,208]) lights.push({x:lx,y:13,z:40,r:230,c:[1,.96,.9],i:1.05,spot:[0,1],cone:.955});
    lights.push({x:160,y:96,z:70,r:170,c:[.72,.8,1],i:.38});
    if(OCT.flashes.some(f=>f.age<1&&f.big)) lights.push({x:160,y:40,z:90,r:260,c:[1,1,1],i:.6});
  } else {
    lights.push({x:torch.x+.5,y:torch.y+.5,z:16,r:100,c:[1,.6,.28],i:1.75*fl});
    lights.push({x:47,y:61,z:9,r:66,c:[1,.78,.44],i:1.15*fl2});
    lights.push({x:206,y:24,z:150,r:560,c:[.55,.66,1],i:.6});
  }
  lights.push(...dyn);
  if(beamOn){ const a=.62+.42*Math.sin(time*.4); lights.push({x:-20,y:-24,z:60,r:640,c:[.93,.96,1],i:1.3,spot:[Math.cos(a),Math.sin(a)],cone:.9935}); }
  const n=Math.min(8,lights.length);
  for(let i=0;i<n;i++){ const L=lights[i];
    if(L.dirl){ LP.set([0,0,0,1],i*4); LC.set([L.c[0],L.c[1],L.c[2],L.i],i*4); LD.set([L.dirl[0],L.dirl[1],L.dirl[2],2],i*4); continue; }
    LP.set([L.x,L.y,L.z,L.r],i*4); LC.set([L.c[0],L.c[1],L.c[2],L.i],i*4);
    LD.set(L.spot?[L.spot[0],L.spot[1],L.cone,1]:[0,0,L.d||0,0],i*4); }
  const DJON=scene==='subway'&&GS.demo&&DJ.on, uAmbV=city?cs.amb:scene==='subway'?(DJON?.82:(GS.on&&GS.tower)?(GS.tower.dark?.14:.44):.55):(scene==='noir'||scene==='brawl')?.45:scene==='octagon'?.7:scene==='brawl'?[1,.7,.35][GS.stage]:1, uSkyV=city?cs.sky:DJON?[.26,.19,.12]:[.106,.16,.26], uSunV=city?cs.sun:[0,-1], uWinV=city?cs.win:(scene==='noir'||scene==='brawl')?1:0;
  // --- G-버퍼 ---
  gl.bindFramebuffer(gl.FRAMEBUFFER,gFB); gl.viewport(0,0,W,H);
  gl.clearColor(0,0,0,0); gl.depthMask(true); gl.clear(gl.COLOR_BUFFER_BIT|gl.DEPTH_BUFFER_BIT);
  gl.useProgram(sprProg); gl.bindVertexArray(vao);
  gl.bindBuffer(gl.ARRAY_BUFFER,vbo); gl.bufferSubData(gl.ARRAY_BUFFER,0,vdata,0,qn*6*FPV);
  gl.activeTexture(gl.TEXTURE0); gl.bindTexture(gl.TEXTURE_2D,ATL._a);
  gl.activeTexture(gl.TEXTURE1); gl.bindTexture(gl.TEXTURE_2D,ATL._n);
  gl.uniform1i(sprU.uA,0); gl.uniform1i(sprU.uN,1);
  gl.uniform1f(sprU.uTime,time); gl.uniform1f(sprU.uFix,fixFlip?1:0); gl.uniform2f(sprU.uRes,W,H); gl.uniform2f(sprU.uShake,SHK(),0);
  gl.uniform1f(sprU.uShadow,0); gl.uniform1f(sprU.uWin,uWinV); gl.uniform1fv(sprU.uRemap,REMAP);
  gl.drawArrays(gl.TRIANGLES,0,nShadowStart*6);
  gl.enable(gl.BLEND); gl.blendFunc(gl.DST_COLOR,gl.ZERO); gl.colorMask(false,true,false,false);
  gl.uniform1f(sprU.uShadow,1); gl.drawArrays(gl.TRIANGLES,nShadowStart*6,(nShadowEnd-nShadowStart)*6);
  gl.disable(gl.BLEND); gl.colorMask(true,true,true,true); gl.uniform1f(sprU.uShadow,0);
  const qa = q3b>=0 ? q3b : qn;
  gl.drawArrays(gl.TRIANGLES,nShadowEnd*6,(qa-nShadowEnd)*6);
  if(n3>0){ // 3D 캐릭터: 배경·그림자 위, 앞쪽 효과 아래. 깊이 검사로 서로 가린다
    gl.enable(gl.DEPTH_TEST); gl.depthFunc(gl.LESS); gl.useProgram(prog3); gl.bindVertexArray(vao3); gl.bindBuffer(gl.ARRAY_BUFFER,vbo3);
    gl.bufferSubData(gl.ARRAY_BUFFER,0,v3,0,n3*F3); gl.uniform2f(U(prog3,'uRes'),W,H); gl.uniform2f(U(prog3,'uShake'),SHK(),0);
    gl.drawArrays(gl.TRIANGLES,0,n3); gl.disable(gl.DEPTH_TEST);
    gl.useProgram(sprProg); gl.bindVertexArray(vao); gl.bindBuffer(gl.ARRAY_BUFFER,vbo); }
  if(qn>qa) gl.drawArrays(gl.TRIANGLES,qa*6,(qn-qa)*6);
  // --- 합성 (노드 그래프 셰이더) ---
  gl.bindFramebuffer(gl.FRAMEBUFFER,cFB); gl.viewport(0,0,W,H);
  const P = view===0 && compProg ? compProg : dbgProg;
  gl.useProgram(P); gl.bindVertexArray(emptyVAO);
  gl.activeTexture(gl.TEXTURE0); gl.bindTexture(gl.TEXTURE_2D,gInfo);
  gl.activeTexture(gl.TEXTURE1); gl.bindTexture(gl.TEXTURE_2D,gNorm);
  gl.activeTexture(gl.TEXTURE2); gl.bindTexture(gl.TEXTURE_2D,palTex);
  gl.uniform1i(U(P,'uInfo'),0); gl.uniform1i(U(P,'uNorm'),1); gl.uniform1i(U(P,'uPal'),2);
  gl.uniform2f(U(P,'uRes'),W,H); gl.uniform1f(U(P,'uTime'),time); gl.uniform1i(U(P,'uLN'),n);
  { const sh=SHK(); if(sh) for(let i=0;i<n;i++) LP[i*4]+=sh; }                                                       // 광원도 화면 흔들림만큼(그림은 밀리고 빛은 남던 어긋남)
  gl.uniform4fv(U(P,'uLP'),LP); gl.uniform4fv(U(P,'uLC'),LC); gl.uniform4fv(U(P,'uLD'),LD);
  gl.uniform1f(U(P,'uAmb'),uAmbV*(scene==='subway'&&GS.on?(GS.prologue ? 1.45 : GS.oneBit ? .08 : (.2+.8*(GS.lightK??1))):1));   /* 정전 칸: 환경광을 낮게 유지(비상등 웅덩이만) */ gl.uniform1f(U(P,'uEmitK'),scene==='subway'&&GS.on?(GS.emitK??1):1); gl.uniform3f(U(P,'uSky'),...uSkyV); gl.uniform2f(U(P,'uSun'),...uSunV);
  if(P===dbgProg) gl.uniform1f(U(P,'uMode'),view);
  else for(const u of nodeU){ if(!u.loc) continue; const v=u.node.p[u.k];
    if(u.kind==='color'){ const c=hexRGB(v); gl.uniform3f(u.loc,c[0]/255,c[1]/255,c[2]/255); } else gl.uniform1f(u.loc,+v); }
  gl.drawArrays(gl.TRIANGLES,0,3);
  // --- 정수배 확대 출력 ---
  gl.bindFramebuffer(gl.FRAMEBUFFER,null);
  gl.viewport(0,0,canvas.width,canvas.height);
  // 후처리(느와르): 블룸 · 빛줄기 · 반사 · 비
  const wx = GS.cine ? {rain:.9,fog:.22} : GS.bonus ? {rain:.3,fog:.14} : scene==='brawl' ? [{rain:.55,fog:.18},{rain:.15,fog:.42},{rain:.95,fog:.22}][GS.stage||0] : {rain:.55,fog:.18};
  const outTex = view!==0 ? compTex : scene==='subway' ? runPost(subwayFX(), time) : (scene==='noir'||scene==='brawl') ? runPost({...noirFX(charOX,wx.rain), fog:wx.fog}, time) : compTex;
  gl.bindFramebuffer(gl.FRAMEBUFFER,null); gl.viewport(0,0,canvas.width,canvas.height);
  gl.useProgram(blitProg); gl.activeTexture(gl.TEXTURE0); gl.bindTexture(gl.TEXTURE_2D,outTex);
  gl.uniform1i(U(blitProg,'uT'),0); gl.uniform2f(U(blitProg,'uSrc'),W,H); gl.uniform2f(U(blitProg,'uDst'),canvas.width,canvas.height);
    const cz=(GS.on&&GS.camZ>1)?GS.camZ-1:0, zk=((GS.on&&GS.zoomK)||0)+cz, zc=cz>0?GS.camC:(GS.zoomC||[.5,.5]); GS.viewZ=1+zk; GS.viewC=zc;
    gl.uniform1f(U(blitProg,'uZoom'),1+zk); gl.uniform2f(U(blitProg,'uZC'),zc[0],1-zc[1]); gl.uniform1f(U(blitProg,'uCamX'),(GS.on&&(scene==='subway'||GS.cine||GS.bonus))?Math.max(0,Math.min(W-VW,CAMX)):0); gl.uniform1f(U(blitProg,'uVW'),VW); if(GS.on) GS.zoomK=((GS.on&&GS.zoomK)||0)*.86;
  gl.drawArrays(gl.TRIANGLES,0,3);
}
function loop(now){
  const rdtL=Math.min(.1,(now-last)/1000); if(GS.on && GS.slowT>0) GS.slowT-=rdtL; if(GS.tapW){ GS.tapW.t+=rdtL; if(GS.tapW.t>1.5) tapFire(false); }   // 탭 창: 1.5초 안에 안 누르면 자동
    if(GS.on) spcCamTick(rdtL); camTick(rdtL);
    if(GS.on){ if((drag&&drag.moved) || document.querySelector('.inv-merge')) { if(inCombat()) GS.bagSlowT=.6; } GS.bagSlowT=Math.max(0,(GS.bagSlowT||0)-rdtL); }
  const dt=rdtL*playSpeed*((GS.on&&GS.slowT>0)?.28:1)*(GS.on?(GS.spcTime||1):1)*((GS.on&&GS.bagSlowT>0)?.2:1); last=now; gameTime+=dt; acc+=dt;   // 마지막 일격은 느리게 · 필살기는 슬로우 · 가방 정리 중엔 0.2배
  const step=1/animFps; let n=0;
  while(acc>=step && n<8){ acc-=step; n++; if(!paused) stepAnim(); }
  if(!paused && typeof advanceActor==='function') advanceActor(dt*1000);
  if(!paused && typeof gameUpdate==='function') gameUpdate(dt);
  if(paused && GS.on && GS.stepReq>0){ GS.stepReq--; const s1=1/animFps; stepAnim(); for(let i=0;i<4;i++) gameUpdate(s1/4); }   // 무도장 · 한 프레임씩: 멈춘 채 1/12초만 진행
  if(acc>step) acc=0;
  render(now); if(GS.capReq){ GS.capReq=false; try{ newsPhoto(canvas.toDataURL('image/png')); }catch(e){} }
  if(typeof updateHandles==='function') updateHandles(); if(typeof drawUI==='function') drawUI(); requestAnimationFrame(loop);
}

// 캔버스 크기: 기기 픽셀 기준 정수배
const stage=document.getElementById('stage');
let VW=W, CAMX=0, PORTRAIT=false;
const SHK=()=>Math.max(-5,Math.min(5,shakeX+Math.round((GS&&GS.shoveX)||0)));                                     // 화면 흔들림(스프라이트 · 인물 · 광원 · 빛줄기 공통)                                                                      // 세로 화면: 무대를 4:3으로 좌우를 잘라 보여 주고, 카메라가 따라간다
const PC_MQ=matchMedia('(min-width:521px) and (min-height:640px) and (hover:hover) and (pointer:fine)');
let DEV_K=1; const devK=()=> (document.body.classList.contains('game-mode') && PC_MQ.matches) ? DEV_K : 1;   // PC 앱 목업의 실제 배율(기본 1 · 창이 낮으면 줄어듦) — 해상도 계산에 쓴다
function fit(){
  PORTRAIT = document.body.classList.contains('game-mode') || (innerHeight>innerWidth && innerWidth<760); document.body.classList.toggle('portrait', PORTRAIT);
  VW = (PORTRAIT && (scene==='subway'||(scene==='brawl'&&(GS.cine||GS.bonus)))) ? Math.round(H*4/3) : W;
  const K=devK(), r=stage.getBoundingClientRect(), dpr=(window.devicePixelRatio||1)*K;   // PC 앱 목업은 1.5배로 키워 보이므로 화면 크기는 K로 나누고, 해상도는 K만큼 높인다
  const cw=Math.min(r.width/K, r.height/K*VW/H);
  // 기기 픽셀 기준 정수배에 가까우면 정수배로 스냅, 아니면 sharp-bilinear로 채움
  let bw=Math.round(cw*dpr); const si=Math.floor(bw/VW);
  if(si>=1 && VW*si>=bw*.94) bw=VW*si;
  canvas.width=bw; canvas.height=Math.round(bw*H/VW);
  canvas.style.width=(bw/dpr)+'px'; canvas.style.height=(canvas.height/dpr)+'px';
  if(typeof placeUI==='function') placeUI();
}
new ResizeObserver(fit).observe(stage); fit(); if(document.fonts&&document.fonts.ready) document.fonts.ready.then(()=>{ for(const k in ART_CACHE) delete ART_CACHE[k]; NOIR.reset(); try{ renderBag(); }catch(e){} }); PC_MQ.addEventListener('change',()=>fit());   // PC 배율 조건이 바뀌면 해상도 다시 맞춤
function toNative(e){ const r=canvas.getBoundingClientRect(); return [ (e.clientX-r.left)/r.width*W, (e.clientY-r.top)/r.height*H ]; }
let dragging=false;
let dragStart=null;
stage.addEventListener('pointerdown',e=>{ if(e.target.closest('.g-ov')) return; // 전리품·결과 카드 위 클릭은 무대 드래그로 가로채지 않음
  if(scene==='octagon') return;
  dragging=true; stage.setPointerCapture(e.pointerId); const p=toNative(e);
  if(isCity()||scene==='noir'){ dragStart=[p[0],camX]; panOn=false; document.getElementById('bPan').setAttribute('aria-pressed','false'); return; }
  torch.x=Math.max(2,Math.min(W-3,p[0])); torch.y=Math.max(4,Math.min(H-4,p[1])); });
stage.addEventListener('pointermove',e=>{ if(!dragging) return; const p=toNative(e);
  if(isCity()||scene==='noir'){ if(dragStart) camX=Math.max(0,Math.min(isCity()?CC().world-CC().W:NBW-NVW,dragStart[1]-(p[0]-dragStart[0]))); return; }
  torch.x=Math.max(2,Math.min(W-3,p[0])); torch.y=Math.max(4,Math.min(H-4,p[1])); });
stage.addEventListener('pointerup',()=>dragging=false); stage.addEventListener('pointercancel',()=>dragging=false);

