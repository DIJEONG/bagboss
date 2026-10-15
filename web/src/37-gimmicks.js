// =========================================================
// 열차 기믹: 기둥 · 손잡이 액션 · 반대편 열차 교행 · 승객 이벤트(쇼타임 댄서 · 버스커 · 구경꾼) · 바닥 사물(커피 웅덩이 · 캔 · 짐 상자)
// =========================================================
const POLES=[98,160,240,320,382];
function genPosters(){ const out={}, G=(p,x,y,str,m,t,e)=>{ for(const ch of str){ const g=GLYPH[ch]; if(!g){ x+=3; continue; } g.forEach((r,j)=>{ for(let i=0;i<r.length;i++) if(r[i]==='#') p.set(x+i,y+j,m,t,{e}); }); x+=Math.max(...g.map(r=>r.length))+1; } };
  const P=[ [M.NEONT,'DR.GLOW',(p)=>{ p.rect(33,1,6,6,M.CURT,4,{e:.2}); p.set(35,3,M.MDARK,1); p.set(37,3,M.MDARK,1); }],                       // 피부과
    [M.GOLD,'1-800',(p)=>{ p.rect(30,2,10,2,M.WOODD,2); p.rect(34,4,2,3,M.WOODD,2); }],                                                     // 변호사(의사봉)
    [M.WOOD,'BAGEL',(p)=>{ for(let a=0;a<Math.PI*2;a+=.3) p.set(Math.round(36+Math.cos(a)*3),Math.round(4+Math.sin(a)*2.4),M.GOLD,4,{e:.15}); }],   // 베이글
    [M.NEONP,'SHOW',(p)=>{ for(const [x,y] of [[32,2],[36,4],[40,2]]){ p.set(x,y,M.GOLD,5,{e:.6}); p.set(x-1,y,M.GOLD,4,{e:.4}); p.set(x+1,y,M.GOLD,4,{e:.4}); } }],   // 브로드웨이
    [M.RED,'SLICE 1',(p)=>{ for(let y=1;y<5;y++) for(let x=34+Math.floor(y*.7);x<=40-Math.floor(y*.7);x++) p.set(x,y,M.GOLD,4,{e:.2}); }], [M.ARMOR,'SEE SAY',(p)=>{ p.rect(36,2,3,4,M.FRAME,5,{e:.3}); }] ];
  P.forEach(([bg,txt,ic],k)=>{ const p=paint(42,6); p.rect(0,0,42,6,bg,3,{e:.12}); G(p,2,0,txt,M.FRAME,5,.35); ic(p); out['ad_'+k]=p.s; });
  for(let k=0;k<3;k++){ const p=paint(16,22), rnd=mulberry(300+k), col=[M.NEONP,M.NEONT,M.NEONO][k];                                     // 네온 낙서(마커 · 스프레이)
    let x=3,y=4+rnd()*4; for(let n=0;n<40;n++){ x+= (rnd()-.4)*3; y+= (rnd()-.5)*3; x=Math.max(1,Math.min(14,x)); y=Math.max(1,Math.min(20,y)); p.set(Math.round(x),Math.round(y),col,4,{e:.35}); p.set(Math.round(x)+1,Math.round(y),col,3,{e:.25}); }
    for(let n=0;n<6;n++) p.set(Math.round(2+rnd()*12),Math.round(14+rnd()*6),col,3,{e:.2}); out['tag_'+k]=p.s; }
  return out; }
function genGimmicks(){ const out={}, rnd=mulberry(77);
  { const p=paint(6,74); for(let y=2;y<72;y++){ p.set(1,y,M.STEEL,5,{r:.7,e:.22}); p.set(2,y,M.FRAME,4,{r:.7,e:.18}); p.set(3,y,M.STEEL,3,{r:.5}); p.set(4,y,M.STEEL,1); }     // 세로 기둥: 크롬처럼 빛을 받는 줄
    p.rect(0,0,6,3,M.MDARK,2); p.rect(0,71,6,3,M.MDARK,2); p.set(1,1,M.STEEL,4); p.set(1,72,M.STEEL,4); out.sb_pole=p.s; }
  { const p=paint(192,46);                                                                                                        // 교행 열차 한 칸(불 켜진 창이 길게)
    for(let x=0;x<192;x++){ for(let y=0;y<4;y++) p.set(x,y,M.MDARK,2); for(let y=4;y<46;y++) p.set(x,y,M.STEEL,y>40?1:y<8?3:2); }
    for(let x=4;x<188;x+=24){ if((x>=0&&x<16)||(x>=96&&x<112)) continue; for(let y=9;y<25;y++) for(let i=0;i<20;i++){ const lit=!((i>5&&i<10&&y>13&&rnd()<.9)||(i>13&&i<17&&y>15)); p.set(x+i,y,lit?M.FRAME:M.MDARK,lit?5:1,{e:lit?.9:0}); } }
    for(const dx of [2,98]){ for(let y=6;y<44;y++) for(let i=0;i<14;i++) p.set(dx+i,y,M.STEEL,i===0||i===13?1:3); for(let y=11;y<22;y++) for(let i=3;i<11;i++) p.set(dx+i,y,M.FRAME,5,{e:.8}); }
    for(let x=0;x<192;x++){ p.set(x,30,M.ARMOR,3); p.set(x,31,M.ARMOR,2); } out.pt_car=p.s; }
  { const p=paint(22,46); for(let y=0;y<46;y++) for(let x=0;x<22;x++){ const k=x<4?(y<6||y>40?-1:0):0; if(k<0) continue; p.set(x,y,M.STEEL,y<8?3:2); }   // 앞머리: 유리창 · 전조등 · 노선 표지
    p.rect(6,8,14,14,M.GLASS,1); for(const yy of [32,36]) p.rect(10,yy,4,3,M.GOLD,5,{e:1}); for(let y=-3;y<=3;y++) for(let x=-3;x<=3;x++) if(x*x+y*y<=9) p.set(17+x,4+y,M.NEONO,4,{e:.6}); out.pt_head=p.s; }
  { const p=paint(16,3); for(let x=0;x<16;x++){ const h=Math.abs(x-8)<6?3:Math.abs(x-8)<8?2:0; for(let y=3-h;y<3;y++) p.set(x,y,M.WOODD,y===3-h?3:2); } p.set(5,1,M.FRAME,4,{e:.2}); out.sb_puddle=p.s;   // 쏟아진 커피
    const c=paint(6,4); c.rect(0,0,5,4,M.FRAME,4); c.rect(5,1,1,2,M.WOODD,2); c.rect(1,1,3,1,M.CURT,3); out.sb_cup=c.s; }                                         // 쓰러진 종이컵
  { const p=paint(10,8); p.rect(0,0,10,8,M.WOOD,(q,j)=>q===0||j===0?4:(q===9||j===7?2:3)); p.rect(4,0,2,8,M.CURT,4); p.rect(0,3,10,1,M.WOODD,2); out.sb_box=p.s; }   // 짐 상자
  { const p=paint(11,9); p.rect(0,0,11,9,M.FRAME,4); for(let y=2;y<8;y+=2) p.rect(1,y,4,1,M.STEEL,2); p.rect(6,2,4,3,M.STEEL,1); p.rect(6,6,4,1,M.STEEL,2); p.rect(5,0,1,9,M.FRAME,2); out.sb_news=p.s;   // 펼친 신문
    const q=paint(7,9); q.rect(0,0,7,9,M.FRAME,4); for(let y=2;y<8;y+=2) q.rect(1,y,5,1,M.STEEL,2); out.sb_news2=q.s; }                                                  // 넘기는 중
  { const p=paint(5,7); p.rect(0,0,5,7,M.MDARK,1); p.rect(1,1,3,5,M.FRAME,5,{e:1}); p.set(1,1,M.ARMOR,5,{e:1}); p.set(3,5,M.ARMOR,5,{e:1}); out.sb_phone=p.s; }   // 휴대폰(화면이 빛난다)                                                    // 휴대폰
  return out; }
// --- 기둥 회전 발차기 · 손잡이 매달려 두 발 차기 · 짐 상자 던지기(환경 기술, 6초 간격) ---
function envHit(H,reach,dmg,o){ const f=H.d.flip?-1:1; for(const a of foes()){ const dx=(a.d.x-H.d.x)*f; if(dx>-6 && dx<reach && !isDown(a) && !a.held) damage(H,a,Math.round(dmg*(1+.12*GS.ci)),o); } }
function envMove(H,live){ if(GS.tower || GS.envCD>0 || !canAct(H) || GS.croute || GS.tapW || (GS.prologue&&GS.prologue.bag)) return false;   /* 콤보 중 · 보스의 가방 쇼 동안엔 기둥 · 손잡이 동작이 끼어들지 않는다 */ const near=live.filter(a=>Math.abs(a.d.x-H.d.x)<40);
  const pole=GS.prologue ? null : POLES.find(px=>Math.abs(px-H.d.x)<16);                                   // 복도엔 기둥이 없다
  if(pole!=null && (near.length>=2 || (near.some(a=>behindOf(H,a)) && near.some(a=>!behindOf(H,a))))){ const f=H.d.flip?-1:1;   // 기둥을 잡고 한 바퀴 — 앞뒤 모두
    H.d.x=pole-f*5; setAnim(H,'idle'); cmdPush({ name:'기둥 회전차기', env:true }); requestAction(H,'polespin',{ cues:{ ps1:()=>envHit(H,42,13,{knock:true}), ps2:()=>{ H.d.flip=!H.d.flip; envHit(H,42,13,{knock:true}); } } });
    GS.envCD=6; GS.flash='POLE'; GS.flashT=.5; return true; }
  const sx=GS.prologue ? Math.round(H.d.x) : STRAP_X.find(x=>Math.abs(x-H.d.x)<9), tgt=live.find(a=>!behindOf(H,a)&&Math.abs(a.d.x-H.d.x)<34);
  if(sx!=null && tgt && Math.random()<.4){ H.d.x=sx; setAnim(H,'idle'); if(GS.prologue){ H.airOv=20; lampKick(H.d.x,2.4); sfx.clack(); }   // 복도: 문 위 배수관까지 뛰어올라 잡는다
    cmdPush({ name:'매달려 차기', env:true }); requestAction(H,'hangkick',{ cues:{ hk2:()=>{ H.airOv=0; }, hk1:()=>envHit(H,40,15,{knock:true,splash:true}) } }); GS.envCD=GS.prologue?12:6; GS.hangX=sx; return true; }   // 손잡이에 매달려 두 발로
  const bx=(GS.props||[]).find(p=>p.k==='box'&&Math.abs(p.x-H.d.x)<14), far=live.filter(a=>!behindOf(H,a)&&Math.abs(a.d.x-H.d.x)>30&&Math.abs(a.d.x-H.d.x)<170)[0];
  if(bx && far){ GS.props=GS.props.filter(p=>p!==bx); face(H,far.d.x); const f=H.d.flip?-1:1; setAnim(H,'idle');                                  // 짐 상자를 집어 던진다
    requestAction(H,'cross',{ cue:JW_CUE.cross, onCue:()=>{ GS.shots.push({ x:H.d.x+f*10, y:H.d.y-42, vx:f*280, t:0, friendly:true }); sfx.swing(); } }); GS.envCD=4; return true; }
  return false; }
// --- 반대편 열차 교행 ---
function passTrainUpdate(dt){ GS.ptT=(GS.ptT||0)+dt; if(GS.ptNext==null) GS.ptNext=14+Math.random()*12;
  if(!GS.pt && GS.ptT>GS.ptNext && TR.phase==='cruise' && TR.v>300 && !bridgeSpan() && !GS.quickStop && !GS.arriving && GS.state==='fight'){
    GS.pt={t:0}; GS.ptT=0; GS.ptNext=20+Math.random()*20; sfx.pass();
    for(const a of foes()) if(!a.e.boss && !isDown(a)){ a.e.stun=Math.max(a.e.stun||0,.5); if(a.action && !a.action.fired){ a.action=null; a.queue=[]; setAnim(a,'idle'); } }   // 움찔
  }
  if(GS.pt){ GS.pt.t+=dt; if(GS.pt.t>1.9) GS.pt=null; } }
function drawPassTrain(){ if(!GS.pt) return; const x0=SB.W+30-GS.pt.t*1500, y=SB.WIN_Y0-10+TR.dy;
  quad('pt_head',Math.round(x0)-22,y); for(let k=0;k<8;k++){ const x=Math.round(x0+k*192); if(x<SB.W && x>-192) quad('pt_car',x,y); } }
function passTrainLights(L){ if(!GS.pt) return; const x0=SB.W+30-GS.pt.t*1500; let n=0;
  for(let k=0;k<8&&n<2;k++){ const x=x0+k*192+60; if(x>-40&&x<SB.W+40){ L.unshift({x, y:176, z:40, r:170, c:[.95,.97,1], i:1.9*(.7+.3*Math.random())}); n++; } } }
// --- 승객 이벤트(구간마다 한 번, 45%) ---
// 타격음 등급: 기술 무게(ATK_FEEL L/M/H)가 기본 · 꽂힘/메치기/일직선 날림 같은 결정타는 무거움 · 치명타는 한 단계 위 · 결정타와 처치만 배경음을 누른다
const HEAVY_RK=new Set(['rSlam','rSpike','rTetsu','rBlast','crumple','rCharge']);   // 결정타 반응(꽂힘 · 메치기 · 일직선 날림 · 무너짐 · 돌진)
const hitTier=(a,o,rk)=>{ const base=(a||'').replace(/_air$/,''), F=ATK_FEEL[a]||ATK_FEEL[base]; let n=F?{L:0,M:1,H:2}[F.w]:(base==='jab'?0:1); if(o.blast||HEAVY_RK.has(rk)) n=2; else if(o.crit && n<2) n++; return n; };
const hitKind=(a,heavy)=> (GS.prologue && a && a.startsWith('hm_')) ? 'hammer' : heavy ? 'heavy' : a==='jab' ? 'jab' : ['kick','round','sweep','knee','bkick','stomp','polespin','hangkick','charge'].includes(a) ? 'kick' : 'punch';
function legEvent(force){ GS.ev=null; const L=LINE[GS.ci]; if(!force && Math.random()>.45) return;
  const pass=GS.ents.filter(a=>a.pass&&!a.hidden&&a.goal==null), kinds=['dance','busk']; if(pass.length>=2) kinds.push('crowd'); if(L.end) { if(pass.length<2) return; kinds.length=0; kinds.push('crowd'); }
  const k=force||kinds[Math.floor(Math.random()*kinds.length)], E={ k, t:0, dur: k==='crowd'?999:k==='dance'?12:16, actors:[] }; GS.ev=E;
  if(k==='dance'){ for(const [x,c] of [[220,'RED'],[262,'GOLD']]){ const T={ n:'댄서', look:{ hair:'pomp', coat:c } }, d=mkActor(defFor(T,0),{x, z:2, flip:x>240, pass:true, pose:'st0'}); d.dancer=true; d.passPose='st0'; setAnim(d,'idle'); GS.ents.push(d); E.actors.push(d); }
    comicSay(E.actors[0],'쇼타임! 쇼타임!','shout',true); say('쇼타임!','지하철 댄서가 통로에서 공연한다 — 근처 적은 휘두르는 다리에 걸려 넘어진다',2.4); }
  if(k==='busk'){ const T={ n:'버스커', look:{ hair:'bandana', coat:'WOOD' } }, d=mkActor(defFor(T,1),{x:452, z:-1, flip:true, pass:true, pose:'gt0'}); d.wpn='w_guitar'; d.passPose='gt0'; setAnim(d,'busk'); GS.ents.push(d); E.actors.push(d);
    comicSay(d,'♪ 한 곡 할게요','speech',true); say('버스커','기타 연주가 흐르는 동안 체력이 조금씩 회복된다',2.4); }
  if(k==='crowd'){ E.actors=pass.slice(0,4); E.actors.forEach(a=>a.filming=true); say('구경꾼','승객들이 휴대폰으로 찍는다 — 연타가 길수록 점수 배율이 오른다',2.4); } }
function evUpdate(dt){ const E=GS.ev; if(!E || GS.demo) return; E.t+=dt; const H=GS.hero;
  if(E.k==='dance') for(const d of E.actors){ if(d.hidden) continue;
    if(E.t<E.dur){ if(d.anim==='idle'){ const mv=['round','kick','upper','round'][Math.floor(Math.random()*4)]; d.d.flip=Math.random()<.5;
        requestAction(d,mv,{ cue:JW_CUE[mv], onCue:()=>{ const f=d.d.flip?-1:1; for(const a of foes()){ const dx=(a.d.x-d.d.x)*f; if(dx>-4&&dx<34&&!isDown(a)&&!a.e.boss) damage(d,a,5,{knock:true}); } } }); } }
    else if(!d.exiting && d.anim==='idle'){ d.exiting=true; d.goal=SB.W-6; setAnim(d,'walk'); } }
  if(E.k==='busk'){ const d=E.actors[0]; if(E.t<E.dur){ E.heal=(E.heal||0)+dt; if(E.heal>=1 && !H.dead){ E.heal=0; if(GS.hp<GS.max){ GS.hp+=1; if(Math.random()<.2) dmgPop(H,100,'heal'); } } }
    else if(d && !d.exiting){ d.exiting=true; d.wpn=null; d.goal=SB.W-6; setAnim(d,'walk'); } }
  if(E.k==='crowd'){ for(const a of E.actors) if(a.filming && !a.hidden && Math.random()<.008){ sparks.push({x:a.d.x+(a.d.flip?-4:4),y:a.d.y-40,age:0}); }      // 카메라 플래시
    const c=GS.combo||0; if((c===5||c===10||c===15) && E.lastCheer!==c){ E.lastCheer=c; const a=E.actors.find(x=>!x.hidden); if(a) comicSay(a,['와!','대박!','찍었어!'][Math.floor(Math.random()*3)],'shout',true); } }
  if(E.actors.length && E.actors.every(a=>a.hidden)) GS.ev=null; }
const crowdK=()=> GS.ev&&GS.ev.k==='crowd' ? 1+.08*Math.min(GS.combo||0,10) : 1;
// --- 바닥 사물: 미끄러짐(커피 웅덩이 · 캔) ---
function propsInit(C){ GS.props=[]; const spot=()=>{ let x; do{ x=40+Math.random()*400; } while(inDoor(x)); return x; };
  if(Math.random()<.5) GS.props.push({k:'puddle', x:spot()}); if(Math.random()<.55) GS.props.push({k:'box', x:spot()});
  if(C.key!=='night' && Math.random()<.35) for(let k=0;k<1+Math.floor(Math.random()*2);k++) GS.cans.push({x:spot(),v:0}); }
function slipUpdate(){ for(const a of foes()){ if(isDown(a)||a.held||(a.slipT||0)>GS.time||!['walk','idle'].includes(a.anim)) continue;
    const pd=(GS.props||[]).find(p=>p.k==='puddle'&&Math.abs(p.x+8-a.d.x)<6), cn=GS.cans.find(c=>Math.abs(c.x-a.d.x)<4);
    if(pd||cn){ a.slipT=GS.time+4; setAnim(a,'rSwept'); a.after='getup'; a.kb=(a.d.flip?1:-1)*20; comicSFX(a.d.x,a.d.y-80,'SLIP!'); sfx.dodge(); if(cn) cn.v=(Math.random()<.5?-1:1)*170; } } }

