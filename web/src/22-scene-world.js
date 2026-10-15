/* =========================================================
   11-d. 장면 전환
   ========================================================= */
function setScene(name){
  if(typeof editing!=='undefined' && editing) setEditing(false);
  scene=name; W=SCN[name].W; H=SCN[name].H;
  stage.style.aspectRatio=`${W} / ${H}`;
  stage.style.width = H>W ? `min(100%, calc(76vh * ${(W/H).toFixed(4)}))` : ''; stage.style.marginInline = H>W ? 'auto' : '';
  const cityN=name==='city'||name==='cityV';
  if(cityN){ camX=(CC().world-CC().W)/2; birds.forEach(b=>{ b.x=Math.random()*W; b.y=CC().birdY[0]+Math.random()*(CC().birdY[1]-CC().birdY[0]); });
    dogs.forEach((d,i)=>d.x=CC().dogs[i]); }
  allocTargets(); fit();
  const [x0,x1]=SCN[name].chars, g=SCN[name].ground, mini=cityN, oct=name==='octagon';
  const nr=name==='noir';
  if(builtinK(CHARS[0].d)) CHARS[0].d = oct ? FIGHTER_A : nr ? NOIR_HERO : mini ? KNIGHT_MINI : KNIGHT;
  CHARS[1].d = oct ? FIGHTER_B : nr ? NOIR_THUG : mini ? SKEL_MINI : SKEL; CHARS[1].remap = oct ? 4 : nr ? 5 : 0;
  for(const d of [KNIGHT,KNIGHT_MINI,FIGHTER_A,CHARS[0].d]){ d.x=x0; d.y=g; } for(const d of [SKEL,SKEL_MINI,FIGHTER_B,NOIR_THUG]){ d.x=x1; d.y=g; }
  if(nr){ NOIR_HERO.y=NFLOOR+22; NOIR_THUG.y=NFLOOR+40; NOIR_HERO.x=camX+120; NOIR_THUG.x=camX+380; }
  OCT.hp=[100,100]; OCT.st=[100,100]; OCT.time=300; OCT.round=1; OCT.flashes.length=0;
  CHARS.forEach(c=>resetChar(c)); pops.length=0; sparks.length=0; dusts.length=0;
  torch.x = name==='city'?58:58; torch.y = name==='city'?44:50;
  document.querySelectorAll('.city-only').forEach(e=>e.hidden=!cityN);
  document.querySelectorAll('#scenes button').forEach(b=>b.setAttribute('aria-pressed', b.dataset.s===name?'true':'false'));
  document.getElementById('resTag').textContent=`${W}x${H} · stepped rig · deferred light`;
  document.getElementById('dragCap').textContent = cityN ? '화면을 좌우로 끌면 카메라가 움직이고, 깊이마다 다른 속도로 흘러가요(패럴랙스).'
    : name==='noir' ? '느와르 밤거리: 가로등 빛줄기 · 네온 번짐 · 젖은 도로 반사 · 비는 후처리 단계에서 더해져요. 화면을 좌우로 끌면 카메라가 움직여요.'
    : oct ? 'MMA 옥타곤 목업: 레드와 블루가 잽·크로스·로우킥을 자동으로 주고받아요. 강타와 녹다운에는 관중석 카메라 플래시가 터져요.' : '화면을 끌면 횃불이 따라와요.';
  loadPreset(Math.max(0, PRESETS.findIndex(p=>(p.scene||'forest')===(cityN?'city':(name==='noir'||name==='brawl'||name==='subway')?'noir':oct?'octagon':'forest'))));
}
document.querySelectorAll('#scenes button').forEach(b=>b.addEventListener('click',()=>{ if(b.dataset.s!==scene) setScene(b.dataset.s); }));
const todEl=document.getElementById('tod'), todOut=document.getElementById('todOut');
todEl.addEventListener('input',()=>{ tod=+todEl.value; todOut.textContent = tod<.3?'낮':tod<.62?'해질녘':'밤'; });
const bPan=document.getElementById('bPan'), bChars=document.getElementById('bChars');
bPan.addEventListener('click',()=>{ panOn=!panOn; bPan.setAttribute('aria-pressed',panOn); });
bChars.addEventListener('click',()=>{ showChars=!showChars; bChars.setAttribute('aria-pressed',showChars); CHARS.forEach(c=>resetChar(c)); });

/* 지하철 장면 그리기: 창밖(터널 · 뉴욕 역) → 터널등 · 선로 사이 기둥 → 선로·대차 → 객차(덜컹) → 문짝 → 손잡이 → 캔 · 병 */
// 지금 보이는 역들: 구간 출발역 · 통과역(급행이 그대로 지나감) · 도착역. 중심 위치는 열차 누적 거리(ex) 기준
function nycStations(){
  const L=[], leg=LINE[GS.leg]||LINE[LINE.length-1];
  L.push({ id:STOPS[GS.leg||0], c:GS.legStart||0 });
  for(const [id,off] of (leg.passes||[])) L.push({ id, c:(GS.legStart||0)+off, pass:true });
  for(const [id,off] of (leg.quick||[])) L.push({ id, c:(GS.legStart||0)+off });           // 짧게 서는 역
  if((GS.arriving || ['arrive','shop','arrange','final','end'].includes(GS.state)) && GS.nextStop) L.push({ id:GS.nextStop, c:TR.stopAt });
  return L.map(o=>({ ...o, sx:o.c-TR.ex+SB.W/2 })).filter(o=>Math.abs(o.sx-SB.W/2)<NY.LEN/2+SB.W);
}
const inStation=(x,st)=>st.some(o=>Math.abs(x-o.sx)<NY.LEN/2);
function drawStation(o){
  const S=STN[o.id], x0=Math.round(o.sx-NY.LEN/2), x1=x0+NY.LEN, vis=x=>x>-260&&x<SB.W+20;
  if(S.vault){ for(let x=x0;x<x1;x+=240) if(vis(x)){ quad('ch_vault',x,0); for(const lx of [52,172]) quad('ch_lamp',x+lx,96); } }     // 옛 시티 홀 역: 아치 천장 · 샹들리에
  else for(let x=x0;x<x1;x+=240){ if(!vis(x)) continue; quad('ny_ceil',x,0); quad(S.ruin?'ny_ruin':S.wall==='brick'?'ny_brick':'ny_wall',x,NY.CEIL); if(S.band) quad('ny_band_'+o.id,x,NY.BAND); }
  if(SPR['ny_cap_'+o.id]) for(let x=x0+44;x<x1-20;x+=120) if(vis(x)) quad('ny_cap_'+o.id,x,S.band?NY.CAP:NY.BAND+2);
  if(S.big) for(let x=x0+70;x<x1-60;x+=160) if(vis(x)) quad('ny_big_'+o.id,x,NY.BAND-4);
  if(S.tab){ const T=SPR['ny_tab_'+o.id], D=SPR['ny_dir_'+o.id];
    for(let k=-1;k<=1;k++){ const x=Math.round(o.sx+k*320-T.w/2);   // 가운데 이름판이 정차 때 가운데 창에 오게
      if(vis(x)){ quad('ny_tab_'+o.id,x,NY.TAB); if(D) quad('ny_dir_'+o.id,x+((T.w-D.w)>>1),NY.DIR); } } }
  for(let x=x0+28;x<x1;x+=64) if(vis(x)) quad('ny_beam_'+S.beam,x,0);                 // 선로 사이 I-빔 (역마다 색)
  for(const ex of [x0,x1-4]) if(vis(ex)) quad('ny_beam_black',ex,0);                   // 승강장 끝
}
// 다리 구간이 화면 어디에 걸쳤는지 (p0 = 들어가는 터널 입구, p1 = 나가는 입구)
function bridgeSpan(){ const L=LINE[GS.leg]; if(!L||!L.bridge||!GS.on) return null; const p0=GS.legStart+L.bridge.b0-TR.ex+SB.W/2, p1=p0+L.bridge.len;
  return (p1<-40||p0>SB.W+40) ? null : { p0, p1, full: p0<=0 && p1>=SB.W, sunK: Math.max(0,Math.min(1,(Math.min(p1,SB.W)-Math.max(p0,0))/SB.W)) }; }
const inBridge=(x,B)=> B && x>B.p0 && x<B.p1;
// 고가선(밤): 하늘 → 먼 맨해튼 → (출발역 근처) 양키 스타디움 → 벽돌 아파트 → 고가 역 · 옆 선로 거더
function drawElBack(time){
  const ex=TR.ex, st=nycStations(); drawDepth=.85;
  const Q=STAGE.el==='q';                                                                                   // 7 열차: 퀸스 네온 변형
  quad(Q?'q_sky':'el_sky',0,0); const fo=-Math.round((ex*.03)%960); if(Q){ quad('q_far',fo,EL.HZ-74); quad('q_far',fo+960,EL.HZ-74); } else { quad('el_far',fo,EL.HZ-50); quad('el_far',fo+960,EL.HZ-50); }
  if(!Q && GS.leg===0){ const yx=Math.round(250-(ex-GS.legStart)*.22); if(yx>-380 && yx<SB.W) quad('el_yankee',yx,EL.HZ-74); }
  if(Q && LINE[GS.leg] && LINE[GS.leg].stop==='mets'){ const yx=Math.round(SB.W+40-(ex-GS.legStart)*.22+900); if(yx>-400 && yx<SB.W) quad('q_ball',yx,EL.HZ-70); }   // 메츠–윌레츠 포인트 앞: 야구장
  const bo=-Math.round((ex*.45)%480); if(Q){ quad('q_bld',bo,58); quad('q_bld',bo+480,58); } else { quad('el_bld',bo,92); quad('el_bld',bo+480,92); }
  for(const o of st) drawElStation(o);
  const so=-Math.round(ex%192); for(let x=so;x<SB.W;x+=192) if(!inStation(x+96,st)) quad('el_struct',x,150);
  drawPassTrain(); drawCarLayer(time);
}
function drawElStation(o){
  const S=STN[o.id], x0=Math.round(o.sx-NY.LEN/2), x1=x0+NY.LEN, vis=x=>x>-260&&x<SB.W+20, sg=SPR['el_sign_'+o.id];
  for(let x=x0;x<x1;x+=240) if(vis(x)) quad('el_plat',x,0);
  if(sg) for(let k=-1;k<=1;k++){ const x=Math.round(o.sx+k*300-sg.w/2); if(vis(x)){ quad('el_sign_'+o.id,x,26); quad('el_sign_'+o.id,x,166); } }
}
function drawSubwayBack(time){
  if(GS.prologue){ drawCorridor(time); return; }
  if(GS.tower){ drawTowerBack(time); return; }   // 엘리베이터 타워
  if(GS.demo && DJ.on){ drawDojoBack(time); return; }   // 무도장 데모: 진짜 무도장
  if(STAGE.el){ drawElBack(time); return; }
  const C=CAR_CONCEPTS[LINE[GS.ci||0].car], dy=TR.dy, ex=TR.ex, st=nycStations();
  const tt=TR.v>380?'sb_tunnelB':'sb_tunnel', BRG=bridgeSpan();
  drawDepth=.85;
  if(BRG){ // 실외: 하늘 → 스카이라인 → 브루클린 다리 → 강 → 갈매기 → 바로 앞 트러스, 양 끝은 터널 입구
    const bx=ex-(GS.legStart+LINE[GS.leg].bridge.b0);
    quad('br_sky',0,0); const so=-Math.round((bx*.04)%960); quad('br_skyline',so,BR.HZ-84); quad('br_skyline',so+960,BR.HZ-84);
    quad('br_bk',Math.round(430-bx*.09),BR.HZ-128);
    const wo=-Math.round((bx*.3)%SB.W); quad('br_water',wo,BR.HZ); quad('br_water',wo+SB.W,BR.HZ);
    for(let k=0;k<26;k++){ const gy=BR.HZ+3+((k*7)%28), spread=2+gy-BR.HZ, gx=BR.SUN[0]-spread+((k*37+Math.floor(time*9)*13)%(spread*2+1));     // 해 아래 반짝이는 물비늘 기둥
      if(((k+Math.floor(time*7))%3)) quad('br_glint',Math.round(gx),gy); }
    for(let k=0;k<3;k++) quad('br_gull',Math.round((380-k*90-bx*.06+time*12*(k+1))%520+20)-20,40+k*14+Math.round(Math.sin(time*2+k)*2));
    const to=-Math.round(ex%192); for(let x=to;x<SB.W;x+=192) quad('br_truss',x,0);
    if(BRG.p0>-24){ for(let x=BRG.p0-SB.W;x>-SB.W;x-=SB.W) quad(tt,x,0); quad('br_portal',BRG.p0-24,0); }
    if(BRG.p1<SB.W+24){ for(let x=BRG.p1;x<SB.W;x+=SB.W) quad(tt,x,0); quad('br_portal',BRG.p1,0); }
  } else { const off=-Math.round(ex%SB.W); quad(tt,off,0); quad(tt,off+SB.W,0); } // 빠르면 잔상 타일
  const k0=Math.floor(ex/260);
  for(let k=k0;k<k0+4;k++){ const x=Math.round(k*260-ex)+40; if(x<-60||x>SB.W+20||inStation(x,st)||inBridge(x,BRG)) continue;
    placeAt('sb_lamp',x,172,false,0); placeAt('sb_lamp',x,62,false,0); if(TR.v>250){ quad('sb_streak',x+5,173); quad('sb_streak',x+5,63); } }
  for(const o of st) drawStation(o);
  const co=-Math.round((ex*1.15)%48);                                                     // 선로 사이 강철 기둥: 벽보다 가까워 더 빨리 지나간다
  for(let x=co;x<SB.W;x+=48) if(!inStation(x,st)&&!inBridge(x,BRG)) quad('ny_col',x,26);
  drawPassTrain(); drawCarLayer(time);
}
function drawCarLayer(time){
  const C=CAR_CONCEPTS[LINE[GS.ci||0].car], dy=TR.dy, ex=TR.ex;
  drawDepth=.5; const toff=-Math.round(ex%20); quad('sb_track',toff-SB.W,SB.H-27); quad('sb_track',toff,SB.H-27); quad('sb_track',toff+SB.W,SB.H-27);   /* 레일 = 화면 y 261 */
  const wf=Math.floor(ex/1.31)%8; for(const bx of [28,376]) quad('sb_bogie'+wf, bx, 232+Math.round(TR.jolt));   // 바퀴 지름 22px: 60°(바큇살 간격)=11.5px 굴러갈 때 8장
  if(GS.brakeSp) for(const p of GS.brakeSp) placeAt('fx_spark'+(p.t<.12?0:p.t<.25?1:2), Math.round(p.x), Math.round(p.y), false, 0);
  drawDepth=.3; quad('car_'+C.key, 0, SB.CAR_Y+dy);
  { const h=(GS.ci*7+(GS.stageIdx||0)*3)%6; [14,188,246,420].forEach((x,k)=>quad('ad_'+((h+k*5)%6), x+1, SB.CAR_Y+12+dy)); }    // 패러디 광고 포스터
  if(['night','works','dark','redbird','gang','cargo'].includes(C.key)) [118,358].forEach((x,k)=>quad('tag_'+((GS.ci+k)%3), x-1, SB.WIN_Y0+2+dy));   // 네온 낙서
  { const G=8; quad('car_'+C.key, -SB.W-G, SB.CAR_Y+dy); quad('car_'+C.key, SB.W+G, SB.CAR_Y+dy); quad('sb_gangway', -G, SB.CAR_Y+12+dy); quad('sb_gangway', SB.W, SB.CAR_Y+12+dy); }   // 앞뒤 칸 · 주름 연결 통로(화면이 밀려도 빈 바깥 대신 열차가 보인다)
  for(const [a,b] of DOORS){ const o=Math.round(TR.door*15); quad('sb_door', a-o, SB.WIN_Y0-2+dy); quad('sb_door', a+17+o, SB.WIN_Y0-2+dy); }
  if(C.fans) for(const x of [112,232,352]) quad('sb_fan'+(Math.floor(TR.t*14+x)%3), x-9, SB.CAR_Y+9+dy);                 // 천장 선풍기
  if(C.lanterns) for(const x of [96,216,336]){ const sw=Math.round(Math.sin(TR.t*2.2+x)*1.5+TR.a*-.004); quad('sb_lanternR', x-4+sw, SB.CAR_Y+10+dy); }
    if(C.marquee){ const ph=Math.floor(TR.t*9), bs=(on,lk)=> lk<.3?'sb_bulbOff' : lk>1.4?'sb_bulbOn' : (on?'sb_bulbOn':'sb_bulbOff');
      for(let k=0;k<39;k++){ const x=10+k*12; quad(bs((k+ph)%3, showBulbK(x)), x-1, SB.CAR_Y+4+dy); quad(bs((k+ph+1)%3, showBulbK(x+6)), x+5, SB.CAR_Y+30+dy); } }   // 붉은 등롱(흔들린다)
  if(C.gears){ for(const x of [72,192,312,432]) placeAt('sb_gear', x, SB.CAR_Y+15+dy, (Math.floor(TR.t*4)+x)%2===0, 0);   // 놋쇠 톱니
    for(const x of [132,252,372]) quad('sb_lantern', x, SB.CAR_Y+22+dy); }
  for(let x=18;x<SB.W-18;x+=26){ if(DOORS.some(([a,b])=>x>a-6&&x<b+6)) continue;
    const holder=GS.ents.find(p=>p.pass && !p.hidden && p.goal==null && p.strapX===x);
    if(holder){ const loopY=Math.round(holder.d.y+holder.handDY)-8, top=156+dy;                        // 잡힌 손잡이: 고리가 손 위치에
      for(let yy=top; yy<loopY; yy+=6) placeAt('sb_strapseg', x, yy, false, 0); placeAt('sb_strap@0', x, Math.max(top-4,loopY), false, 0); continue; }
    const ang=TR.strap+Math.sin(x*.7+TR.t*.8)*.05+((STRAPS[x]&&STRAPS[x].a)||0); placeAt('sb_strap@'+m32(Math.round(ang/(Math.PI/16))), x, 156+dy, false, 0); }
  for(const x of POLES) quad('sb_pole', x-3, SB.CAR_Y+12+dy);                                                  // 세로 기둥
  for(const p of (GS.props||[])){ if(p.k==='puddle'){ quad('sb_puddle', Math.round(p.x), SB.FLOOR-2+dy); quad('sb_cup', Math.round(p.x)+13, SB.FLOOR-4+dy); } else quad('sb_box', Math.round(p.x)-5, SB.FLOOR-8+dy); }
  for(const c of GS.cans) placeAt('sb_can', Math.round(c.x), SB.FLOOR-1+dy, c.v<0, 0);
  for(const s of GS.shots){ if(s.friendly){ quad('sb_box', Math.round(s.x)-5, Math.round(s.y)-4+dy); continue; } const k=m32(Math.round(s.t*40)*(s.vx<0?-1:1)); placeAt('sb_bottle@'+k, Math.round(s.x), Math.round(s.y)+dy, false, 0); } // 돌면서 날아가는 병 · 던진 짐 상자
  if(C.works && Math.random()<.025){ const sx=[30,210,410][Math.floor(Math.random()*3)]+Math.floor(Math.random()*30); sparks.push({x:sx,y:SB.CAR_Y+60+dy,age:1});   // 뜯긴 패널 배선에서 튀는 불꽃
    if(GS.bits) for(let k=0;k<4;k++) GS.bits.push({ x:sx, y:SB.CAR_Y+60+dy, vx:(Math.random()-.5)*70, vy:-(20+Math.random()*60), t:.3 }); }
}
function subwayLights(time){
  if(GS.prologue) return corridorLights();
  if(GS.tower) return towerLights(time);
  if(GS.demo && DJ.on) return dojoLights(time);
  const L=[], C=CAR_CONCEPTS[LINE[GS.ci||0].car], dy=TR.dy, st=nycStations(), BRG=bridgeSpan();
  if(C.oneBit && GS.oneBit){ // 정전 칸(암전 뒤): 작은 붉은 비상등 두 개(가끔 꺼진다) · 터널등이 창으로 스칠 때만 밝아진다
    for(const x of [130,350]) L.push({x, y:SB.CAR_Y+44+dy, z:30, r:100, c:[1,.36,.28], i:1.2*(x===350?1-(TR.flickS||0)*.85:1), em:true});   /* 컬러일 땐 원래 세기, 1비트는 문턱이 높아 세게 */   // 좌석 높이의 비상등: 작은 빛 웅덩이 (1비트는 문턱이 높아 세게)
  } else for(const [k,x] of [[0,64],[1,184],[2,304],[3,424]]){ if(C.broken&&k===2) continue; let i=1.05; if((C.broken||C.works) && k===1) i*=1-.85*(TR.flickS||0);
    if(BRG && (k===0||k===3)) continue; if(BRG) i*=.5;                              // 낮 구간: 실내등은 반쯤만
    L.push({x, y:SB.CAR_Y+7+dy, z:24, r:118, c:C.light, i:i*(C.li??1)}); }
  if(BRG){ for(const [px,dir] of [[BRG.p0,-1],[BRG.p1,1]]) if(px>-140 && px<SB.W+140){   // 터널 입구: 바깥 햇빛이 터널 안쪽 벽으로 번진다
      L.push({x:px+dir*26, y:96, z:40, r:210, c:[1,.74,.48], i:1.5}); } }
  if(BRG){ // 창으로 쏟아지는 노을빛. 트러스 기둥이 지나갈 때마다 그림자가 창을 훑는다
    for(const wx of [59,200,280,422]){ if(!inBridge(wx,BRG)) continue; const ph=((wx+TR.ex)%96+96)%96, d=Math.min(ph,96-ph), open=d<9?.25:1;
      L.push({x:wx, y:176, z:10, r:120, c:[1,.62,.32], i:1.55*open}); }
    L.push({dirl:[-.55,.35,.3], c:[1,.6,.32], i:.5*BRG.sunK});
    return L; }
  // 역 안이면 역 형광등이 창으로 쏟아져 들어오고, 터널이면 터널등이 훑고 지나간다
  const sl=[]; for(const o of st){ const x0=o.sx-NY.LEN/2, x1=x0+NY.LEN, cover=Math.max(0,Math.min(1,(Math.min(x1,SB.W)-Math.max(x0,0))/240)); // 역이 화면을 덮은 만큼만 밝아진다
    for(let x=x0+60;x<x1;x+=180) if(x>-60&&x<SB.W+60) { const S2=STN[o.id], fl=S2.ruin ? (Math.sin(GS.time*23+x)*Math.sin(GS.time*7.3)>.55 ? .25 : 1) : 1; sl.push({x, y:30, z:50, r:230, c:S2.vault?[1,.78,.52]:S2.ruin?[.55,.86,.62]:[.92,.97,1], i:(S2.ruin?.8:1.45)*cover*fl}); } }   /* 옛 시티 홀: 샹들리에 불빛 */
  if(sl.length) L.push(...sl.sort((a,b)=>Math.abs(a.x-240)-Math.abs(b.x-240)).slice(0,2));
  else if(STAGE.el){ const k0=Math.floor(TR.ex*.45/300), tl=[]; for(let k=k0;k<k0+3;k++){ const x=Math.round(k*300-TR.ex*.45)+60; if(x>-60 && x<SB.W+60) tl.push({x, y:200, z:20, r:150, c:[1,.6,.28], i:.95}); } L.push(...tl.slice(0,2)); }  // 거리의 나트륨 가로등
  else { const k0=Math.floor(TR.ex/260), tl=[]; for(let k=k0;k<k0+4;k++){ const x=Math.round(k*260-TR.ex)+43; if(x>-40 && x<SB.W+40) tl.push({x, y:176, z:7, r:115, c:[1,.74,.42], i:1.25}); } L.push(...tl.slice(0,2)); }
  if(C.gears) for(const x of [134,374]) L.push({x, y:SB.CAR_Y+26+dy, z:16, r:70, c:[1,.62,.25], i:1.1});
  if(C.lanterns) for(const x of [96,336]) L.push({x, y:SB.CAR_Y+18+dy, z:14, r:84, c:[1,.38,.22], i:1.2});
  if(C.strobe){ const bt=GS.time*2.1, b=Math.floor(bt), ph=bt-b, pulse=1-ph*.7, COLS=[[1,.25,.85],[.2,.95,1],[1,.6,.15],[.6,.3,1]];   // 클럽 칸: 박자마다 색이 바뀌며 칸을 훑는 조명
    for(let k=0;k<2;k++){ const x=k? 360-((b*97)%160) : 120+((b*61)%140); L.push({x, y:SB.CAR_Y+12+dy, z:16, r:126, c:COLS[(b+k*2)%4], i:1.35*pulse}); } }
  if(C.marquee) for(const Lp of SHOW_LAMPS){ if(Lp.k>.02) L.push({x:Lp.x, y:SB.CAR_Y+8+dy, z:14, r:110, c:[1,.82,.5], i:1.15*Lp.k});
    if(Lp.sparkT>0) L.unshift({x:Lp.x, y:SB.CAR_Y+10+dy, z:8, r:46, c:[1,.95,.75], i:2.4*Math.min(1,Lp.sparkT/.08)}); }
  if(GS.brakeGlow>.02) for(const x of [66,414]) L.unshift({x, y:256, z:6, r:52, c:[1,.62,.26], i:(1.1+Math.random()*.6)*GS.brakeGlow});   // 제동 불꽃 빛(잘리지 않게 앞에)
  if(C.cab) L.push({x:468,y:176,z:18,r:320,c:[1,.95,.8],i:1.5,spot:[1,0],cone:.82});
  passTrainLights(L);
  if(C.oneBit && GS.oneBit) for(const l of L) if(!l.em) l.i*=.45;                           // 정전 칸: 창으로 스치는 바깥 빛만 약하게
  return L;
}
// 눈 적응(자동 노출): 장면 밝기 Ls를 눈이 따라가는 적응값 A. 밝음 적응은 빠르고(≈0.5초) 어둠 적응은 느리다(≈2.6초)
// 화면 배율 = (Ls/A)^0.55 → 터널 → 다리: 과노출(화이트홀) 뒤 가라앉음, 다리 → 터널: 새카맸다가(블랙홀) 서서히 보임
function eyeAdapt(BRG, st){
  const now=performance.now()/1000, dt=Math.min(.1,now-(GS.adT||now))*(playSpeed||1); GS.adT=now;
  // 기준은 '승객(객차)이 지금 바깥에 있는가' — 입구를 지나는 순간 계단처럼 바뀐다(0.15초로 살짝만 부드럽게)
  const Lb=LINE[GS.leg], out = Lb&&Lb.bridge && TR.ex>=GS.legStart+Lb.bridge.b0 && TR.ex<GS.legStart+Lb.bridge.b0+Lb.bridge.len ? 1 : 0;
  GS.outS=(GS.outS??out)+(out-(GS.outS??out))*(1-Math.exp(-dt/.15));
  const stK = st.reduce((m,o)=>Math.max(m, Math.max(0,1-Math.abs(o.sx-SB.W/2)/(NY.LEN/2+80))),0);
  const Ls = (.18 + .82*GS.outS + .3*stK*(1-GS.outS)) * (GS.oneBit ? .35 : 1);     // 터널 0.18 · 역 약 0.5 · 낮의 다리 1.0 · 정전 칸은 더 어둡게
  GS.darkA=(GS.darkA||0)+((GS.oneBit?1:0)-(GS.darkA||0))*(1-Math.exp(-dt/(GS.oneBit?3:.8)));          // 어둠에 눈이 적응: 약 3초에 걸쳐 노출이 오른다
  if(GS.adA==null) GS.adA=Ls;
  const tgtA = GS.oneBit ? Ls/.35*.85 : Ls;                                           // 정전: 눈이 적응해도 원래보다 어둡게 남는다
  const tau = tgtA>GS.adA ? .45 : 1.6; GS.adA += (tgtA-GS.adA)*(1-Math.exp(-dt/tau));
  return { m: Math.max(.32, Math.min(3, Math.pow(Ls/GS.adA, .6))) * (1 + .15*(GS.darkA||0)) };
}
const LINE_GRADE=[ { grade:[1.06,1.0,.9], sat:1.05 }, { grade:[.9,1.0,1.1], sat:.92 }, { grade:[1.07,.97,.97], sat:1.1 }, { grade:[1.04,.93,1.1], sat:1.12 }, { grade:[.93,1.0,1.03], sat:.88 } ];   // D 나트륨 · 4 밤의 청록 · 6 붉은 등롱 · 7 네온 자홍 · L 차가운 회색
function subwayFX(){ if(GS.prologue){ const inv=GS.invF>0?1:0; if(GS.invF>0) GS.invF--; return { expo:1.3, winR:0, winY:[0,0], press:0, bloom:.75, reflY:SB.FLOOR-4, rain:0, vig:.55, fog:.1, fogC:[.06,.12,.13], inv, grade:[.8,1.0,1.06], sat:.72,
    vols: corrLamps().slice(0,6).map(lp=>({ x:lp.x, y:lp.y+8, dx:Math.sin(lp.st.a), dy:Math.cos(lp.st.a), c:[1,.92,.78], i:.24, cone:.86, len:150, halo:6 })) }; }   // 갓 아래로 떨어지는 빛 삼각형   // 복도: 저채도 녹색 · 짙은 비네트
  if(GS.demo && DJ.on) return dojoFX();
  if(GS.tower) return towerFX();
  return { ...subwayFX0(), ...(LINE_GRADE[GS.stageIdx||0]||{}) }; }
function subwayFX0(){
  const C=CAR_CONCEPTS[LINE[GS.ci||0].car], vols=[], st=nycStations(), BRG=bridgeSpan(), inv=GS.invF>0?1:0; if(GS.invF>0) GS.invF--;
  if(STAGE.el){ const ad=eyeAdapt(null, st); return { expo:ad.m, winR:.55, winY:[SB.WIN_Y0,SB.WIN_Y1], press:GS.press||0, bloom:.85, reflY:-999, rain:0, vig:.55, fog:.1, fogC:[.12,.07,.12], inv, vols:[] }; }
  const ad=eyeAdapt(BRG, st), winFx={ expo:ad.m, winR:(window.__dotlab&&window.__dotlab.WINR_OFF)?0:.62, winY:[SB.WIN_Y0,SB.WIN_Y1], press:GS.press||0 };
  if(BRG){ const k=BRG.sunK;
    return { ...winFx, bloom:.5, reflY:-999, rain:0, vig:.48, fog:.08*k, fogC:[.3,.14,.08], inv,
      vols:[ {x:BR.SUN[0],y:BR.SUN[1],dx:0,dy:1,c:[1,.7,.36],i:.55*k,cone:2,len:1,halo:30}, {x:BR.SUN[0],y:BR.SUN[1],dx:-.34,dy:.94,c:[1,.62,.3],i:.42*k,cone:.94,len:240,halo:6},
        ...[[BRG.p0,-1],[BRG.p1,1]].filter(([px])=>px>-60&&px<SB.W+60).map(([px,dir])=>({x:px,y:70,dx:dir*.9,dy:.44,c:[1,.8,.55],i:.75,cone:.86,len:190,halo:16})) ] }; }

  if(C.cab) vols.push({x:466,y:176,dx:1,dy:0,c:[1,.95,.8],i:1.1,cone:.9,len:220,halo:8});
  const k0=Math.floor(TR.ex/260); for(let k=k0;k<k0+4;k++){ const x=Math.round(k*260-TR.ex)+43; if(x>-30 && x<SB.W+30 && !inStation(x,st)) vols.push({x,y:174,dx:0,dy:1,c:[1,.74,.42],i:.5,cone:2,len:1,halo:12}); }
  return { ...winFx, bloom:.9, reflY:-999, rain:0, vig:.62, fog:.06, fogC:[.02,.02,.04], inv, vols:vols.slice(0,6) };
}

