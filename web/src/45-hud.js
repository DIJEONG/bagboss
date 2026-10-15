// --- HUD (픽셀): 노선도 · 칸 번호 · 자동/수동 · 체력 칸 · 공격 예고 '!' · 카운터 ---
const uiCv=document.getElementById('ui'), uiCx=uiCv.getContext('2d');
const SPD_CYCLE=[1.25,1.5,2,1];
function abUpdate(){ if(!GS.on) return; const set=(el,t)=>{ if(el && el.textContent!==t) el.textContent=t; }, $=id=>document.getElementById(id);
  set($('abLine'), GS.tower ? `${KE('타워','Tower')} · ${GS.tower.floor}F ${twFloorName(GS.tower.floor)}` : tr($('gWave').textContent));
  { const en=LANG==='en', nf=foes().length, nm=k=>STN[k]?(en?STN[k].n:STN[k].ko):''; let t;   // 숫자 · 상태를 앞에, 긴 역 이름은 뒤로(잘려도 괜찮게)
    if(GS.tower){ const wt=twWeight(), LIM=GS.tower.limit||TW_LIMIT, bt=Math.max((META.tower||{}).best||0, GS.tower.floor); t=en?`Load ${wt}/${LIM} · ${nf} foes · best ${bt}F`:`정원 ${wt}/${LIM} · 적 ${nf} · 최고 ${bt}F`; }
    else if(GS.prologue) t=en?`${Math.max(0,Math.round((CORR_LEN-GS.prologue.x)/10))}m · ${nf} foes · to the door`:`${Math.max(0,Math.round((CORR_LEN-GS.prologue.x)/10))}m · 적 ${nf} · 철문까지`;
    else if(LINE[GS.ci] && GS.atStop) t=en?`Stopped · ${nf} foes · ${nm(GS.atStop)}`:`정차 중 · 적 ${nf} · ${nm(GS.atStop)}`;
    else if(LINE[GS.ci]){ const Lh=LINE[GS.ci], left=Math.max(0,Math.ceil(legDur(Lh)-(GS.legT||0))); t=en?`${left}s · ${nf} foes · to ${nm(Lh.stop)}`:`${left}초 · 적 ${nf} · ${nm(Lh.stop)}까지`; }
    else t=tr($('gEnemy').textContent);
    set($('abSub'), t); }
  let pr=1; if(GS.tower) pr=Math.min(1,GS.tower.pos/((TW_TOP-1)*TWR.FH)); else if(GS.prologue) pr=Math.min(1,GS.prologue.x/CORR_LEN); else if(LINE[GS.ci] && !GS.atStop && ['fight','arrive','board','final'].includes(GS.state)) pr=Math.min(1,(GS.legT||0)/Math.max(1,legDur(LINE[GS.ci])));
  const pg=$('abProg'); if(pg) pg.style.width=(pr*100).toFixed(1)+'%';
  const sp=Math.min(100,GS.sp||0), ready=sp>=100, can=ready&&canSpecial(), b=$('abSpc');
  if(b){ $('abSpcFill').style.height=sp+'%'; b.classList.toggle('ready',can); b.classList.toggle('wait',ready&&!can); set($('abSpcPct'), ready?(can?tr('발동 ▶'):tr('대기')):Math.floor(sp)+'%'); }
  set($('abSpdV'), gamePaused?tr('멈춤'):(playSpeed+'×')); }
function hud(){ if(!GS.on) return; if(GS.prologue){ document.getElementById('gWave').textContent='프롤로그 · 지하 2층 복도'; document.getElementById('gEnemy').textContent=`철문까지 ${Math.max(0,Math.round((CORR_LEN-GS.prologue.x)/10))}m · 남은 적 ${foes().length}`; return; }
  const C=CAR_CONCEPTS[LINE[GS.ci].car]; document.getElementById('gWave').textContent=`${STAGE.short} · ${GS.ci+1}호차 · ${C.name}`;
  const Lh=LINE[GS.ci], left=Math.max(0,Math.ceil(legDur(Lh)-(GS.legT||0))), nf=foes().length;
  document.getElementById('gEnemy').textContent = GS.atStop ? `${STN[GS.atStop].ko} 정차 중${nf?` · 남은 적 ${nf}`:''}` : `${STN[Lh.stop].ko}까지 ${left}초 · 남은 적 ${nf}`; }
function pxText(x,y,str,col){ uiCx.fillStyle=col; for(const ch of str){ const g=GLYPH[ch];
  if(!g){ x+=4; continue; } g.forEach((r,j)=>{ for(let i=0;i<r.length;i++) if(r[i]==='#') uiCx.fillRect(x+i,y+j,1,1); }); x+=(ch==='.'?2:Math.max(...g.map(r=>r.length))+1); } }
// --- 대미지 숫자(던파 · 메이플식): 굵은 도트 숫자 스킨 · 꽂히듯 튀어나옴 · 연속 타격은 위로 쌓임 · CRITICAL / COUNTER / BACK ATTACK 라벨 · 연타 합계 ---
const DMG_K=100;                                                                       // 화면 표시 배율(던파 · 메이플처럼 큰 수)
const DFONT={ '0':[".###.","##.##","##.##","##.##","##.##","##.##",".###."], '1':[".##..","###..",".##..",".##..",".##..",".##..","####."],
  '2':[".###.","##.##","...##","..##.",".##..","##...","#####"], '3':["####.","...##","...##",".###.","...##","...##","####."],
  '4':["##.##","##.##","##.##","#####","...##","...##","...##"], '5':["#####","##...","####.","...##","...##","##.##",".###."],
  '6':[".###.","##...","####.","##.##","##.##","##.##",".###."], '7':["#####","...##","..##.","..##.",".##..",".##..",".##.."],
  '8':[".###.","##.##","##.##",".###.","##.##","##.##",".###."], '9':[".###.","##.##","##.##",".####","...##","...##",".###."],
  '+':[".....","..#..","..#..","#####","..#..","..#..","....."], '-':[".....",".....",".....","#####",".....",".....","....."] };
const DSTYLE={ hit:{ s:2, r:['#fff6d8','#ffd34a','#e8902a'], o:'#2a1208' }, crit:{ s:3, r:['#fff1c0','#ff8a2a','#d8261c'], o:'#2a0808' },
  hurt:{ s:2, r:['#ffd0e0','#ff5a7a','#a01a4a'], o:'#200818' }, heal:{ s:2, r:['#e8ffd8','#6ee87a','#2a9a4a'], o:'#08200e' },
  total:{ s:3, r:['#ffffff','#ffe27a','#ffb02a'], o:'#3a1a08' } };
const DGLY={};
function dGlyph(ch,st){ const k=st+ch; if(DGLY[k]) return DGLY[k]; const S=DSTYLE[st], g=DFONT[ch], w=5*S.s+2, h=7*S.s+2;
  const cv=document.createElement('canvas'); cv.width=w; cv.height=h; const cx=cv.getContext('2d'), on=(x,y)=>x>=0&&y>=0&&x<5&&y<7&&g[y][x]==='#';
  for(let y=0;y<h;y++) for(let x=0;x<w;x++){ const gx=Math.floor((x-1)/S.s), gy=Math.floor((y-1)/S.s);
    if(x>=1&&y>=1&&on(gx,gy)){ const tone = gy<2 ? 0 : gy<5 ? 1 : 2; cx.fillStyle=S.r[tone]; if(!on(gx,gy-1)&&(y-1)%S.s===0) cx.fillStyle='#ffffff'; cx.fillRect(x,y,1,1); }
    else { let n=false; for(let dy=-1;dy<=1&&!n;dy++) for(let dx=-1;dx<=1;dx++){ const xx=x+dx, yy=y+dy; if(xx>=1&&yy>=1&&on(Math.floor((xx-1)/S.s),Math.floor((yy-1)/S.s))){ n=true; break; } } if(n){ cx.fillStyle=S.o; cx.fillRect(x,y,1,1); } } }
  return DGLY[k]=cv; }
const DPOPS=[], DSTACK=new Map(), HITFX=[];
// 투명 충격파(소닉붐): 무게별 단계 — 0 없음 · 2 작은 고리 · 3 큰 돔(+ 방향 번짐 · 흰 김) · 4 이중 고리(고유 마무리 · 두목 무너짐)
const SW_T={ tetsu:3, axe:3, axe_air:3, suplex:3, round:3, round_air:3, charge:3, charge_air:3, fkick:3, throw:3,
  upper:2, kick:2, knee:2, cycle:2, renkan:2, hook:2, bkick:2, uthrust:2, sweep:2, stomp:2 };
const SWP={ 2:{ r0:5, r1:22, w:6, amp:2.6, dark:.08, life:.12 }, 3:{ r0:8, r1:36, w:9, amp:4.2, dark:.17, life:.17 } };
// 받아치기 연출: 작은 충격파 링 · 짧은 슬로 · 반짝(크게는 1.2초에 한 번만)
function chFx(t,f){ GS.stats.chits=(GS.stats.chits||0)+1; const y=t.d.y-32-(t.jug?t.jug.h:0)-(t.airOv||0); swPush(t.d.x-f*2, y, 2, f);
  if(GS.time-(GS.chT||-9)<1.2) return; GS.chT=GS.time; GS.slowT=Math.max(GS.slowT||0,.1);
  if(!OPT.noFlash) HITFX.push({ k:'chstar', x:t.d.x-f*3, y, t:0, life:.24 }); comicT=0; comicSFX(t.d.x, t.d.y-96, tr('받아치기!')); try{ sfx.clack(); }catch(e){} }
function swPush(x,y,tier,f){ if(!GS.on || !tier) return; const now=GS.time, L=GS.swLast;
  if(L && now>=L.t && now-L.t<.07 && tier<=L.tier && Math.abs(L.x-x)<30) return; GS.swLast={ t:now, tier, x };   // 연타가 겹치면 하나만
  const k=(typeof OPT!=='undefined' && OPT.noFlash)?.35:1, list=GS.sw||(GS.sw=[]);
  const add=(P,d,sc)=>list.push({ x, y, t0:now+d, life:P.life*sc, r0:P.r0*sc, r1:P.r1*sc, w:P.w*sc, amp:P.amp*k, dark:P.dark*k });
  if(tier>=4){ add(SWP[3],0,1); add(SWP[3],.07,1.35); } else add(SWP[tier],0,1);
  if(tier>=3){ if(k===1) GS.smear={ x, y, f, t0:now, life:.07, R:30 };
    HITFX.push({ k:'swpuff', x:x-f*2, y:y-4, f, t:0, life:.6, b:Array.from({length:4},()=>({ dx:(Math.random()-.5)*12+f*4, dy:(Math.random()-.5)*8, r:2.5+Math.random()*2.5, vy:10+Math.random()*12, vx:(Math.random()-.5)*8 })) }); }
  if(list.length>8) list.splice(0,list.length-8); }
function swHit(tgt,f,o,att,x,y){ if(att!==GS.hero || o.splash) return; let tier=SW_T[att.anim]||0; if(att.anim==='renkan' && o.react==='launch') tier=3;   // 연환퇴 2타는 묵직
  if(tier) swPush(x, y-(tgt.jug?tgt.jug.h:0)-(tgt.airOv||0), tier, f); }
function hitFx(tgt,f,o,big,att){ const head = !o.low && !['hitB','rKnee','rKick','rSwept'].includes(tgt.anim), y=tgt.d.y+(o.low?-20:head?-50:-40), x=tgt.d.x-f*3, n=big?7:4;
  for(let k=0;k<n+2;k++){ const a=(Math.random()-.5)*1.7, sp=(big?320:240)*(.6+Math.random()*.6); HITFX.push({ k:'streak', x, y:y+(Math.random()-.5)*6, vx:f*Math.cos(a)*sp, vy:Math.sin(a)*sp, t:0, life:big?.2:.14, col:o.crit?'#ff7a3a':'#ffd34a' }); }   // 호박색 · 치명은 주황빨강 — 하얀 번쩍임에 묻히지 않게
  HITFX.push({ k:'flash', x, y, t:0, life:big?.12:.08, big });
  { const F=att===GS.hero && ATK_FEEL[att.anim]; if(F && F.w==='H') HITFX.push({ k:'burst', x, y, t:0, life:.3, f, n:14, r0:8, r1:44 }); else if(F && F.w==='M') HITFX.push({ k:'ring', x, y, t:0, life:.16, r1:14 }); }                                                    // 맞은 지점 십자 섬광
  swHit(tgt,f,o,att,x,y);
  if(head && tgt.e) for(let k=0;k<(big?6:3);k++) HITFX.push({ k:'drop', x:tgt.d.x+f*2, y:y-4, vx:f*(30+Math.random()*70), vy:-(40+Math.random()*60), t:0, life:.5, col:'#cfe8ff' }); }
function hmTrail(H,k){ const f=H.d.flip?-1:1; HITFX.push({ k:'arc', x:H.d.x+f*3, y:H.d.y-(k==='d'?44:38), f, kind:k, t:0, life:.2 }); }
function drawHitFx(dt){
  for(const a of GS.ents){ if(!a.e || a.dead || a.hidden || (a.anim!=='stagger' && a.anim!=='staggerX')) continue; const cx=a.d.x, cy=a.d.y-48-(a.airOv||0), T=gameTime*5.5;   // 휘청: 머리 위로 도는 별 셋
    uiCx.save(); for(let k=0;k<3;k++){ const th=T+k*2.094, x=Math.round(cx+Math.cos(th)*8), y=Math.round(cy+Math.sin(th)*2.5), back=Math.sin(th)<0; uiCx.globalAlpha=back?.45:1; uiCx.fillStyle=back?'#b89a3a':'#ffe27a'; uiCx.fillRect(x-1,y,3,1); uiCx.fillRect(x,y-1,1,3); } uiCx.restore(); }
  if(GS.bossBreak && GS.bossBreak.a && !GS.bossBreak.a.dead){ const B=GS.bossBreak, a=B.a, w=44, k=Math.max(0,B.t/B.T0), x=a.d.x-w/2, y=a.d.y-96;
    uiCx.save(); uiCx.fillStyle='#0e0d14'; uiCx.fillRect(x-1,y-1,w+2,6); uiCx.fillStyle='#ffd36a'; uiCx.fillRect(x,y,Math.round(w*k),4); uiCx.font='700 9px Galmuri11,sans-serif'; uiCx.textAlign='center'; uiCx.fillStyle='#0e0d14'; uiCx.fillText(tr('무너짐'),a.d.x+1,y-3); uiCx.fillStyle='#ffd36a'; uiCx.fillText(tr('무너짐'),a.d.x,y-4); uiCx.restore(); }
  if(GS.tapW && GS.tapW.T){ const W=GS.tapW, u=Math.min(1,W.t/1.5), x=W.T.d.x, y=W.T.d.y-34, Rr=30-20*u;   // 탭 원: 줄어드는 금색 고리
    uiCx.save(); uiCx.strokeStyle='#ffd36a'; uiCx.lineWidth=2; uiCx.beginPath(); uiCx.arc(x,y,Rr,0,7); uiCx.stroke(); uiCx.strokeStyle='rgba(255,255,255,.65)'; uiCx.lineWidth=1; uiCx.beginPath(); uiCx.arc(x,y,9,0,7); uiCx.stroke();
    uiCx.font='700 11px Galmuri11,sans-serif'; uiCx.textAlign='center'; uiCx.fillStyle='#0e0d14'; uiCx.fillText(tr('탭!'),x+1,y-Rr-5); uiCx.fillStyle='#ffd36a'; uiCx.fillText(tr('탭!'),x,y-Rr-6); uiCx.restore(); }
  for(const p of HITFX){ p.t+=dt; const u=p.t/p.life; if(u>=1) continue;
    if(p.k==='sig_ring'){ const R=p.r*(.2+.8*u); uiCx.save(); uiCx.globalAlpha=1-u; uiCx.lineWidth=3; uiCx.strokeStyle='#fff6d0'; uiCx.beginPath(); uiCx.ellipse(p.x,p.y+16,R,R*.32,0,0,7); uiCx.stroke();
      uiCx.lineWidth=2; uiCx.strokeStyle=skinAcc()||'#ffb347'; uiCx.beginPath(); uiCx.ellipse(p.x,p.y+16,R*.68,R*.22,0,0,7); uiCx.stroke(); for(let k=0;k<12;k++){ const a=k/12*6.283; uiCx.beginPath(); uiCx.moveTo(p.x+Math.cos(a)*R*.45,p.y-4+Math.sin(a)*R*.28); uiCx.lineTo(p.x+Math.cos(a)*R*.85,p.y-4+Math.sin(a)*R*.5); uiCx.stroke(); } uiCx.restore(); continue; }
    if(p.k==='sig_quake'){ uiCx.save(); uiCx.globalAlpha=1-u; uiCx.strokeStyle='#e0c89a'; uiCx.lineWidth=3; for(const sd of [-1,1]) for(let k=0;k<3;k++){ const dx=sd*(10+p.r*u*(1-k*.25)); uiCx.beginPath(); uiCx.arc(p.x+dx,p.y+30,8+k*4,Math.PI*1.05,Math.PI*1.95); uiCx.stroke(); } uiCx.restore(); continue; }
    if(p.k==='sig_burst'){ uiCx.save(); uiCx.globalAlpha=1-u; uiCx.strokeStyle='#ffd36a'; uiCx.lineWidth=2.5; for(let k=0;k<14;k++){ const a=k/14*6.283+.2, r0=6+20*u, r1=r0+18*(1-u)+8; uiCx.beginPath(); uiCx.moveTo(p.x+Math.cos(a)*r0,p.y+Math.sin(a)*r0); uiCx.lineTo(p.x+Math.cos(a)*r1,p.y+Math.sin(a)*r1); uiCx.stroke(); } uiCx.restore(); continue; }
    if(p.k==='sig_pillar'){ const w=22*(1-u)+2; uiCx.save(); uiCx.globalAlpha=1-u*u; uiCx.fillStyle='#ffd36a'; uiCx.fillRect(p.x-w/2-2,p.y-130,w+4,160); uiCx.fillStyle='#fffbe8'; uiCx.fillRect(p.x-w/2,p.y-130,w,160); uiCx.restore(); continue; }
    if(p.k==='sig_flash'){ uiCx.save(); uiCx.globalAlpha=.55*(1-u); uiCx.fillStyle='#ffffff'; uiCx.fillRect(p.x-600,p.y-400,1200,800); uiCx.restore(); continue; }
    if(p.k==='sig_trail'){ uiCx.save(); uiCx.globalAlpha=1-u; uiCx.strokeStyle='#f1e6cf'; uiCx.lineWidth=2; for(let k=0;k<7;k++){ const yy=p.y-24+k*8, L=(80+k%3*20)*(1-u*.5); uiCx.beginPath(); uiCx.moveTo(p.x-p.f*12,yy); uiCx.lineTo(p.x-p.f*(12+L),yy); uiCx.stroke(); } uiCx.restore(); continue; }
    if(p.k==='sig_stamp'){ const s0=1.9-.9*Math.min(1,u*5), al=u<.65?1:1-(u-.65)/.35; uiCx.save(); uiCx.globalAlpha=al; uiCx.translate(p.x,p.y-26); uiCx.rotate(-.2); uiCx.scale(s0,s0);
      uiCx.strokeStyle='#d6453a'; uiCx.lineWidth=3; uiCx.strokeRect(-24,-15,48,30); uiCx.lineWidth=1; uiCx.strokeRect(-20,-11,40,22); uiCx.fillStyle='#d6453a'; uiCx.font='700 13px Galmuri11,sans-serif'; uiCx.textAlign='center'; uiCx.textBaseline='middle'; uiCx.fillText(tr('결재'),0,1); uiCx.restore(); continue; }
    if(p.k==='tsring'){ const e=1-Math.pow(1-u,2.2); uiCx.save(); uiCx.globalAlpha=1-u;   // 진각: 납작한 이중 충격파(흙빛) + 양옆으로 갈라지는 균열
      uiCx.strokeStyle='#ffe2a8'; uiCx.lineWidth=2.5; uiCx.beginPath(); uiCx.ellipse(p.x,p.y,10+58*e,3+8*e,0,0,7); uiCx.stroke();
      uiCx.strokeStyle='#c8905a'; uiCx.lineWidth=1.5; uiCx.beginPath(); uiCx.ellipse(p.x,p.y,6+34*e,2+5*e,0,0,7); uiCx.stroke();
      uiCx.globalAlpha=Math.min(1,(1-u)*1.8); uiCx.strokeStyle='#14121c'; uiCx.lineWidth=1.5;
      for(const c of p.cr){ let x=p.x, y=p.y; uiCx.beginPath(); uiCx.moveTo(x,y); for(let k=1;k<=c.n;k++){ x+=c.sd*(7+k*4)*Math.min(1,u*5); y+=(k%2?-1:1)*1.6+c.a*3; uiCx.lineTo(x,y); } uiCx.stroke(); }
      uiCx.restore(); continue; }
    if(p.k==='chstar'){ const s=u<.25?u/.25:1-(u-.25)/.75, L=3+15*s, w=Math.max(1,Math.round(2.4*s)); uiCx.save(); uiCx.globalAlpha=Math.min(1,1.8*(1-u)); uiCx.fillStyle='#fffbe6';   // 받아치기 반짝: 가로로 긴 십자 빛
      uiCx.fillRect(Math.round(p.x-L), Math.round(p.y-w/2), Math.round(L*2), w); uiCx.fillRect(Math.round(p.x-w/2), Math.round(p.y-L*.7), w, Math.round(L*1.4)); uiCx.fillStyle='#ffe27a'; uiCx.fillRect(Math.round(p.x-2), Math.round(p.y-2), 4, 4); uiCx.restore(); continue; }
    if(p.k==='swpuff'){ uiCx.save(); uiCx.fillStyle='#f1ede4';   // 묵직한 타격: 접촉점에서 피어올라 흩어지는 흰 김
      for(const b of p.b){ uiCx.globalAlpha=.22*(1-u)*(1-u)*(u<.15?u/.15:1); uiCx.beginPath(); uiCx.arc(p.x+b.dx+b.vx*u+(p.f||1)*u*8, p.y+b.dy-b.vy*u, b.r*(.7+u*1.1), 0, 7); uiCx.fill(); }   /* 옅고 가볍게 — 얼굴을 덮지 않게 */
      uiCx.restore(); continue; }
    if(p.k==='xcspark'){ const al=1-u; uiCx.save(); uiCx.globalAlpha=al; uiCx.strokeStyle='#dff0ff'; uiCx.lineWidth=1;   // 팬터그래프 불꽃: 청백색 방사선 + 중심 섬광
      for(const q of p.parts){ const L0=q.l*(.4+u*.9); uiCx.beginPath(); uiCx.moveTo(p.x,p.y); uiCx.lineTo(p.x+Math.cos(q.a)*L0, p.y+Math.sin(q.a)*L0*.8+u*6); uiCx.stroke(); }
      uiCx.fillStyle='#ffffff'; uiCx.beginPath(); uiCx.arc(p.x,p.y,3*(1-u)+1,0,7); uiCx.fill(); uiCx.globalAlpha=al*.5; uiCx.fillStyle='#8fc8ff'; uiCx.beginPath(); uiCx.arc(p.x,p.y,7*(1-u)+2,0,7); uiCx.fill(); uiCx.restore(); continue; }
    if(p.k==='cyw'){ const R0=p.r*(.85+.5*u), a0=p.t*30*(p.f||1); uiCx.save(); uiCx.globalAlpha=1-u; uiCx.strokeStyle='#ffe27a'; uiCx.lineWidth=2; uiCx.beginPath(); uiCx.arc(p.x,p.y,R0,0,7); uiCx.stroke();   // 페달 바퀴: 테 + 도는 바큇살
      uiCx.strokeStyle='#fffbe8'; uiCx.lineWidth=1; for(let k=0;k<6;k++){ const a=a0+k*Math.PI/3; uiCx.beginPath(); uiCx.moveTo(p.x+Math.cos(a)*R0*.25,p.y+Math.sin(a)*R0*.25); uiCx.lineTo(p.x+Math.cos(a)*R0,p.y+Math.sin(a)*R0); uiCx.stroke(); }
      uiCx.globalAlpha=(1-u)*.6; uiCx.strokeStyle='#ffe27a'; for(let k=0;k<3;k++){ const yy=p.y-5+k*5; uiCx.beginPath(); uiCx.moveTo(p.x-(p.f||1)*(R0+3),yy); uiCx.lineTo(p.x-(p.f||1)*(R0+12+k*3),yy); uiCx.stroke(); } uiCx.restore(); continue; }
    if(p.k==='cystar'){ const sc=(p.s||1)*(u<.35?u/.35:1)*9, al=1-Math.max(0,(u-.4)/.6); uiCx.save(); uiCx.globalAlpha=al; uiCx.translate(p.x,p.y); uiCx.rotate(.4);   // 연타 별: 네 갈래
      uiCx.fillStyle='#ffe27a'; uiCx.beginPath(); for(let k=0;k<8;k++){ const a=k*Math.PI/4, r=k%2?sc*.28:sc; uiCx.lineTo(Math.cos(a)*r,Math.sin(a)*r); } uiCx.closePath(); uiCx.fill(); uiCx.fillStyle='#fffbe8'; uiCx.fillRect(-1.5,-1.5,3,3); uiCx.restore(); continue; }
    if(p.k==='axv'){ const w=6*(1-u)+1, yb=p.y0+(p.y1-p.y0)*Math.min(1,u*3); uiCx.save(); uiCx.globalAlpha=1-u*u;   // 단두대 칼날: 수직 흰 줄 + 푸른 잔상
      uiCx.fillStyle='#9fd8ff'; uiCx.globalAlpha*=.55; uiCx.fillRect(p.x-w/2-4,p.y0,1,yb-p.y0); uiCx.fillRect(p.x+w/2+3,p.y0,1,yb-p.y0); uiCx.globalAlpha=1-u*u;
      uiCx.fillStyle='#ffffff'; uiCx.fillRect(p.x-w/2,p.y0,w,yb-p.y0); uiCx.fillStyle='#d8f0ff'; uiCx.beginPath(); uiCx.moveTo(p.x-w,yb); uiCx.lineTo(p.x+w,yb); uiCx.lineTo(p.x,yb+8); uiCx.closePath(); uiCx.fill(); uiCx.restore(); continue; }
    if(p.k==='axring'){ const e=1-Math.pow(1-u,2.4); uiCx.save(); uiCx.globalAlpha=1-u; uiCx.strokeStyle='#e8f6ff'; uiCx.lineWidth=2; uiCx.beginPath(); uiCx.ellipse(p.x,p.y,8+40*e,2.5+7*e,0,0,7); uiCx.stroke();   // 바닥에 납작하게 퍼지는 고리 + 균열
      uiCx.strokeStyle='#7fc4ff'; uiCx.lineWidth=1; uiCx.beginPath(); uiCx.ellipse(p.x,p.y,5+24*e,1.5+4*e,0,0,7); uiCx.stroke();
      uiCx.globalAlpha=Math.min(1,(1-u)*1.6); uiCx.strokeStyle='#14121c'; uiCx.lineWidth=1.5; for(const c of p.cr){ let x=p.x, y=p.y; uiCx.beginPath(); uiCx.moveTo(x,y); for(let k=1;k<=c.n;k++){ x+=c.sd*(6+k*3)*Math.min(1,u*4); y+=(k%2?-1:1)*1.5+c.a*3; uiCx.lineTo(x,y); } uiCx.stroke(); } uiCx.restore(); continue; }
    if(p.k==='sxpath'){ const prog=Math.min(1,u*1.7), N=22, a0=(p.f||1)>0?0:Math.PI, dir=(p.f||1)>0?-1:1; uiCx.save(); uiCx.lineWidth=3.5; uiCx.setLineDash([5,3]);   // 앞 → 머리 위 → 뒤: 점선 궤적이 그려지며 따라간다
      for(const [rr,col,al] of [[p.r+5,'#d6453a',.7],[p.r,'#ff8a3a',1],[p.r-6,'#ffc06a',.6]]){ uiCx.globalAlpha=al*(1-Math.max(0,(u-.6)/.4)); uiCx.strokeStyle=col; uiCx.beginPath(); for(let i=0;i<=N*prog;i++){ const a=a0+dir*Math.PI*i/N; const x=p.x+Math.cos(a)*rr, y=p.y+Math.sin(a)*rr*.9; i?uiCx.lineTo(x,y):uiCx.moveTo(x,y); } uiCx.stroke(); }
      uiCx.setLineDash([]); const ah=a0+dir*Math.PI*prog, hx=p.x+Math.cos(ah)*p.r, hy=p.y+Math.sin(ah)*p.r*.9; uiCx.globalAlpha=1-u; uiCx.fillStyle='#ff6a3a'; uiCx.beginPath(); uiCx.arc(hx,hy,3,0,7); uiCx.fill(); uiCx.restore(); continue; }
    if(p.k==='sxboom'){ const e=u<.25?u/.25:1, al=1-Math.max(0,(u-.35)/.65); uiCx.save(); uiCx.globalAlpha=al; uiCx.translate(p.x,p.y);   // 만화식 방사 폭발: 흰 · 주황 가시
      for(let k=0;k<14;k++){ const a=k*Math.PI*2/14-Math.PI/2, L=(k%2?22:34)*e, w=.13; uiCx.fillStyle=k%2?'#ff8a3a':'#fff4e0'; uiCx.beginPath(); uiCx.moveTo(Math.cos(a-w)*6,Math.sin(a-w)*6); uiCx.lineTo(Math.cos(a)*L,Math.sin(a)*L*.7); uiCx.lineTo(Math.cos(a+w)*6,Math.sin(a+w)*6); uiCx.closePath(); uiCx.fill(); }
      uiCx.fillStyle='#d6453a'; uiCx.beginPath(); uiCx.ellipse(0,0,8*e,6*e,0,0,7); uiCx.fill(); uiCx.restore(); continue; }
    if(p.k==='sk_glint'){ uiCx.save(); uiCx.globalAlpha=1-u; uiCx.fillStyle=p.c||'#ffd36a'; for(const q of p.P){ const r=q.v*u, x=p.x+Math.cos(q.a)*r, y=p.y+Math.sin(q.a)*r*.7-14*u, s=q.s*(1-u*.5); uiCx.fillRect(x-s,y-.5,s*2+1,1); uiCx.fillRect(x-.5,y-s,1,s*2+1); } uiCx.restore(); continue; }
    if(p.k==='sk_rain'){ uiCx.save(); uiCx.globalAlpha=(1-u)*.9; uiCx.strokeStyle='#8fd0ff'; uiCx.lineWidth=1; for(let k=0;k<18;k++){ const sx=p.x-44+((k*37)%88), sy=p.y-50+((k*23)%30)+u*70; uiCx.beginPath(); uiCx.moveTo(sx,sy); uiCx.lineTo(sx-4,sy+10); uiCx.stroke(); } uiCx.restore(); continue; }
    if(p.k==='tapok'){ uiCx.save(); uiCx.globalAlpha=1-u; uiCx.strokeStyle='#fff6d0'; uiCx.lineWidth=3; uiCx.beginPath(); uiCx.arc(p.x,p.y,10+40*u,0,7); uiCx.stroke(); uiCx.restore(); continue; }
    if(p.k==='slash'){ uiCx.save(); uiCx.globalAlpha=1-u; uiCx.strokeStyle='#ffffff'; uiCx.lineWidth=4*(1-u)+1; uiCx.beginPath(); uiCx.moveTo(p.x-40,p.y-26); uiCx.lineTo(p.x+40,p.y+20); uiCx.stroke();
      uiCx.strokeStyle='#d6453a'; uiCx.lineWidth=1; uiCx.beginPath(); uiCx.moveTo(p.x-38,p.y-23); uiCx.lineTo(p.x+38,p.y+22); uiCx.stroke(); uiCx.restore(); continue; }
    if(p.k==='pages'){ const t=p.t; uiCx.save(); uiCx.globalAlpha=Math.min(1,(p.life-t)/.5);                 // 흩날리는 서류: 열차 바람을 타고 양쪽 연결 통로로
      for(const q of p.P){ const x=p.x+q.vx*t+Math.sign(q.vx)*46*t*t, y=p.y+q.vy*t+64*t*t+Math.sin(t*7+q.ph)*5;
        uiCx.save(); uiCx.translate(x,y); uiCx.rotate(q.r+q.vr*t); uiCx.fillStyle='#f1e6cf'; uiCx.fillRect(-3,-4,6,8); uiCx.fillStyle='#2a2732'; uiCx.fillRect(-2,-2,4,1); uiCx.fillRect(-2,0,3,1); uiCx.fillRect(-2,2,4,1); uiCx.restore(); }
      uiCx.restore(); continue; }
    if(p.k==='crescent'){ const R=p.r*(1+.18*u), T=p.w*(1-u*.75), N=26, pt=(a,r)=>{ const aa=p.f<0?Math.PI-a:a; return [p.x+Math.cos(aa)*r, p.y+Math.sin(aa)*r]; };
      for(const [k,col,al] of [[1,'#f0b890',.95],[.7,skinAcc()||'#5fe0b0',.95],[.36,'#f6fffa',1]]){ uiCx.globalAlpha=(1-u*u)*al; uiCx.fillStyle=col; uiCx.beginPath();
        for(let i=0;i<=N;i++){ const a=p.a0+(p.a1-p.a0)*i/N, [x,y]=pt(a,R); i?uiCx.lineTo(x,y):uiCx.moveTo(x,y); }
        for(let i=N;i>=0;i--){ const sN=i/N, a=p.a0+(p.a1-p.a0)*sN, [x,y]=pt(a,R-T*k*Math.pow(Math.sin(Math.PI*sN),.7)); uiCx.lineTo(x,y); }
        uiCx.closePath(); uiCx.fill(); } uiCx.globalAlpha=1; continue; }
    if(p.k==='gdust'){ const e=1-Math.pow(1-u,2.2); for(const q of p.puffs){ const v=Math.max(0,(u-q.d)/(1-q.d)); if(v<=0) continue; const x=p.x+q.dx+q.vx*e, y=p.y-1.5-q.rise*e, r=q.r*(.55+v*1.1);
        uiCx.globalAlpha=(1-v)*.5; uiCx.fillStyle='#8f8476'; uiCx.beginPath(); uiCx.arc(x,y,r,0,7); uiCx.fill(); uiCx.globalAlpha=(1-v)*.35; uiCx.fillStyle='#c9bca8'; uiCx.beginPath(); uiCx.arc(x-r*.25,y-r*.3,r*.55,0,7); uiCx.fill(); } uiCx.globalAlpha=1; continue; }
    if(p.k==='twfall'){ for(const q of p.parts){ const x=p.x+q.vx*p.t, y=Math.min(SB.FLOOR-1, p.y+q.vy*p.t+300*p.t*p.t); uiCx.globalAlpha=1-u*.6; uiCx.fillStyle=q.c||'#6e726d'; uiCx.fillRect(Math.round(x),Math.round(y),q.s,q.s); } uiCx.globalAlpha=1; continue; }   // 천장에서 떨어지는 부스러기
    if(p.k==='debris'){ for(const q of p.parts){ const x=p.x+q.vx*p.t, y=Math.min(p.y-1, p.y-2-(q.vy*p.t-420*p.t*p.t)); uiCx.globalAlpha=1-u; uiCx.fillStyle='#4d443c'; uiCx.fillRect(Math.round(x),Math.round(y),q.s,q.s); } uiCx.globalAlpha=1; continue; }
    if(p.k==='crack'){ uiCx.globalAlpha=(1-u)*.8; uiCx.strokeStyle='#16120f'; uiCx.lineWidth=1.2; uiCx.beginPath(); p.pts.forEach(([dx,dy],i)=>i?uiCx.lineTo(p.x+dx,p.y+dy):uiCx.moveTo(p.x+dx,p.y+dy)); uiCx.stroke(); uiCx.globalAlpha=1; continue; }
    if(p.k==='streak'){ const L=(1-u); uiCx.strokeStyle=p.col; uiCx.globalAlpha=(1-u*.5)*(p.a||1); uiCx.lineWidth=1.8*(1-u*.5); uiCx.lineCap='round'; uiCx.beginPath(); uiCx.moveTo(p.x+p.vx*p.t, p.y+p.vy*p.t); uiCx.lineTo(p.x+p.vx*(p.t+.065*L), p.y+p.vy*(p.t+.065*L)); uiCx.stroke(); }
    else if(p.k==='flash'){ const r=(p.big?13:9)*(.6+u*.6); uiCx.globalAlpha=1-u; uiCx.strokeStyle='#ffffff'; uiCx.lineWidth=2*(1-u)+.6; uiCx.beginPath(); uiCx.moveTo(p.x-r,p.y); uiCx.lineTo(p.x+r,p.y); uiCx.moveTo(p.x,p.y-r*.7); uiCx.lineTo(p.x,p.y+r*.7); uiCx.stroke(); }
    else if(p.k==='txt'){ const cx=uiCx; cx.save(); cx.globalAlpha=1-Math.max(0,(u-.6)/.4); cx.font='bold 12px Galmuri11,monospace'; cx.textAlign='center'; cx.lineJoin='round'; cx.lineWidth=3; cx.strokeStyle='#0e0d14'; cx.strokeText(p.text,p.x,p.y-u*18); cx.fillStyle=p.col; cx.fillText(p.text,p.x,p.y-u*18); cx.restore(); }
    else if(p.k==='fire'){ const cx=uiCx, r=3+(1-u)*4; cx.save(); cx.globalAlpha=(1-u)*.9; cx.fillStyle=u<.3?'#fff2a0':u<.6?'#ffaa3a':'#e8422a'; cx.beginPath(); cx.arc(p.x+Math.sin(p.t*14+p.x)*2, p.y-u*26, r, 0, Math.PI*2); cx.fill(); cx.restore(); }
    else if(p.k==='smoke' && p.steam){ const cx=uiCx, r=3+u*10; cx.save(); cx.globalAlpha=(1-u)*.5; cx.fillStyle='#e8eef4'; cx.beginPath(); cx.arc(p.x+Math.sin(p.t*4+p.x)*3, p.y-u*30, r, 0, Math.PI*2); cx.fill(); cx.restore(); }
    else if(p.k==='smoke'){ const cx=uiCx, r=4+u*14; cx.save(); cx.globalAlpha=(1-u)*.45; cx.fillStyle=u<.2?'#3a3a40':'#6a6a72'; cx.beginPath(); cx.arc(p.x+Math.sin(p.t*3+p.x)*4, p.y-u*40, r, 0, Math.PI*2); cx.fill(); cx.restore(); }
    else if(p.k==='swirl'){ const cx=uiCx, a=1-u; cx.save(); cx.translate(p.x,p.y); cx.lineCap='round';
      for(let j=0;j<3;j++){ const rx=(p.big?74:58)-j*12, ry=10+j*3, a0=(p.ph*1.3+j*2.1+u*5)%(Math.PI*2); cx.globalAlpha=a*(.75-j*.2); cx.lineWidth=2.2-j*.5; cx.strokeStyle=j?'#cfe8ff':'#ffffff'; cx.beginPath(); cx.ellipse(0,j*6,rx,ry,0,a0,a0+Math.PI*1.1); cx.stroke(); }
      cx.restore(); }
    else if(p.k==='wave'){ const cx=uiCx, r=8+82*easeO(u); cx.save(); cx.globalAlpha=(1-u)*.85; cx.lineWidth=3*(1-u)+1; cx.strokeStyle='#ffe2a0'; cx.beginPath(); cx.ellipse(p.x,p.y-1,r,r*.16,0,0,Math.PI*2); cx.stroke();
      cx.strokeStyle='#ffffff'; cx.lineWidth=1; cx.beginPath(); cx.ellipse(p.x,p.y-1,r*.8,r*.13,0,0,Math.PI*2); cx.stroke(); cx.restore(); }
    else if(p.k==='arc'){ const u2=Math.min(1,p.t/.08), a=1-u, cx=uiCx; cx.save(); cx.translate(p.x,p.y); cx.scale(p.f,1); cx.lineCap='round';
      const seg=(a0,a1,rx,ry)=>{ for(let j=0;j<3;j++){ cx.globalAlpha=a*(1-j*.3); cx.lineWidth=3.2-j; cx.strokeStyle=j?'#ffcf6a':'#fffbe8'; cx.beginPath(); cx.ellipse(0,0,rx-j*2,ry-j*.6,0,a0,a0+(a1-a0)*u2,a1<a0); cx.stroke(); } };
      if(p.kind==='d') seg(-1.9,.7,26,26); else if(p.kind==='h') seg(Math.PI*.95,Math.PI*2.05,30,9); else seg(Math.PI*.05,-Math.PI*1.05,30,9);
      cx.restore(); }
    else if(p.k==='drop'){ p.vy+=420*dt; p.x+=p.vx*dt; p.y+=p.vy*dt; uiCx.globalAlpha=1-u; uiCx.fillStyle=p.col; uiCx.fillRect(p.x,p.y,1.6,1.6); }
    else if(p.k==='burst'){ const cx=uiCx, e=1-Math.pow(1-u,3); cx.save(); cx.translate(p.x,p.y); cx.lineCap='round';
      for(let j=0;j<p.n;j++){ const a=j/p.n*Math.PI*2+(j%2?.12:0), L=(j%2?.62:1), ra=p.r0+(p.r1-p.r0)*e*.35, rb=p.r0+(p.r1-p.r0)*Math.min(1,e*1.3)*L;
        cx.globalAlpha=(1-u)*(j%2?.7:1); cx.strokeStyle=p.red?(j%3?'#ff7a5a':'#ffd2c4'):(j%3?'#ffe27a':'#ffffff'); cx.lineWidth=(j%2?1.4:2.8)*(1-u*.55); cx.beginPath(); cx.moveTo(Math.cos(a)*ra,Math.sin(a)*ra*.8); cx.lineTo(Math.cos(a)*rb,Math.sin(a)*rb*.8); cx.stroke(); }
      cx.globalAlpha=(1-u)*.85; cx.strokeStyle=p.red?'#ffb4a2':'#fff6d0'; cx.lineWidth=2*(1-u)+.4; cx.beginPath(); cx.ellipse(0,0,p.r0+(p.r1-p.r0)*e*.5,(p.r0+(p.r1-p.r0)*e*.5)*.8,0,0,Math.PI*2); cx.stroke(); cx.restore(); }
    else if(p.k==='ring'){ const cx=uiCx, e=1-Math.pow(1-u,2); cx.save(); cx.globalAlpha=(1-u)*.8; cx.strokeStyle='#ffe9a8'; cx.lineWidth=1.6*(1-u)+.4; cx.beginPath(); cx.ellipse(p.x,p.y,3+p.r1*e,(3+p.r1*e)*.8,0,0,Math.PI*2); cx.stroke(); cx.restore(); } }
  uiCx.globalAlpha=1; for(let i=HITFX.length-1;i>=0;i--) if(HITFX[i].t>=HITFX[i].life) HITFX.splice(i,1); }
function dmgPop(tgt,val,style,label,labelCol){ if(style==='heal' && !(val>0)) return; const now=performance.now()/1000, k=tgt.uid||tgt, s=DSTACK.get(k);
  const stack = s && now-s.t<.6 ? s.n+1 : 0; DSTACK.set(k,{t:now,n:Math.min(stack,5)});                    // 같은 대상이 연달아 맞으면 위로 층층이
  const S0=DSTYLE[style]||{s:2}, w0=String(val).length*(5*S0.s-1), cx=Math.max(CAMX+w0/2+3,Math.min(CAMX+VW-w0/2-3,tgt.d.x)); let st=Math.min(stack,5);
  for(let g=0; g<4; g++){ const clash=DPOPS.some(p=>p.age<.6 && p.stack===st && Math.abs(Math.max(CAMX+3,Math.min(CAMX+VW-3,p.x))-cx) < (w0+String(p.val).length*(5*(DSTYLE[p.style]||{s:2}).s-1))/2+2); if(!clash) break; st++; }   // 다른 숫자와 가로로 겹치면 한 층 위로
  DPOPS.push({ x:tgt.d.x, y:tgt.d.y+(tgt.d.rig&&tgt.d.rig.popY||-58), val, style, label, labelCol, stack:Math.min(st,7), age:0, vx:(Math.random()-.5)*14, life:style==='crit'||style==='total'?1.35:1.05 }); }
function outlined(x,y,str,col){ for(const [dx,dy] of [[-1,0],[1,0],[0,-1],[0,1]]) pxText(x+dx,y+dy,str,'#0e0d14'); pxText(x,y,str,col); }
// --- 코믹스 연출: 효과음 폭발(특별한 타격) · 말풍선(여유 있을 때) — 둥근 말 · 뾰족한 외침 · 구름 생각 ---
const COMIC=[]; let comicT=0, quipT=0;
const QUIPS={ wave:['다음.','이게 전부야?','넥타이가 구겨졌잖아.','몸 좀 풀렸네.'], clear:['정시 도착이다.','다음 역까지 한숨 돌리지.'],
  combo:['리듬 좋고.','이 정도는 해야지.'],
  rest:['…이 도시는 잠들지 않는군.','…다음 역까지 숨 좀 고르지.','…막차는 늘 조용하다가 시끄럽지.','…넥타이 좀 고쳐 매야겠어.','…창밖 불빛이 빨리도 지나가네.'], think:['…커피 한 잔 하고 싶군.','…다음은 어떤 놈들이려나.','…넥타이를 새로 맬까.'] };
const BOSS_LINES={ boss:'내 기관실에서 내려라!', boss2:'기어단 구역에 온 걸 환영하지.', boss3:'청룡방의 이름으로—', boss4:'바이퍼스 구역에선 속도가 법이다.', kaneB:'종점에서 기다린다고 했지. 여기가 종점이다.', mgr:'내 건물에서 소란 피운 놈은 못 내려간다.', headchef:'내 주방에 정장은 출입 금지다.' };
const pickQ=k=>QUIPS[k][Math.floor(Math.random()*QUIPS[k].length)];
// 효과 글자 자리: 인물 몸 · 피해 숫자 기둥을 피해 맞은 쪽 옆(날아가는 방향) 머리 높이 → 위쪽 순으로 빈자리를 고른다 · 화면 밖으로 나가지 않게
function comicSpot(x,y,word){ if(!GS.on || !GS.ents) return [x,y];
  const tw=word.length*7.4, hw=tw*.58+10, hh=(tw*.58+9)*.62+1;                                            // 그릴 때 크기(14px)와 같은 근사
  const live=GS.ents.filter(a=>!a.hidden && !a.pass && (a.e||a===GS.hero) && Math.abs(a.d.x-x)<100), box=a=>[a.d.x-12, a.d.y-58-(a.airOv||0), a.d.x+12, a.d.y+2];
  const B=live.map(box); for(const p of DPOPS) if(p.age<p.life && Math.abs(p.x-x)<100){ const S=DSTYLE[p.style]||{s:1}, hw2=String(p.val).length*(5*S.s-1)*.6+4, top=p.y-p.stack*(7*S.s+3)-10-(p.label?10:0); B.push([p.x-hw2, top, p.x+hw2, p.y+7*S.s+4]); }   // 피해 숫자(크기 · 라벨 포함)
  const H=GS.hero, T=live.filter(a=>a!==H).sort((a,b)=>Math.abs(a.d.x-x)-Math.abs(b.d.x-x))[0]||live[0];
  const cx0=T?T.d.x:x, dir=(T&&H&&T!==H)?(Math.sign(T.d.x-H.d.x)||1):1, top=live.length?Math.min(...live.map(a=>box(a)[1])):y;
  const L=CAMX+hw+2, R=CAMX+VW-hw-2, fit=(cx,cy)=>[Math.max(L,Math.min(R,cx)), Math.max(hh+3,cy)];
  const ov=(cx,cy)=>B.reduce((s,b)=>s+Math.max(0,Math.min(cx+hw,b[2])-Math.max(cx-hw,b[0]))*Math.max(0,Math.min(cy+hh,b[3])-Math.max(cy-hh,b[1])),0);   // 겹치는 넓이
  const C=[[cx0+dir*(hw+14), top+hh-2],[cx0+dir*(hw+14), top-hh*.3],[cx0-dir*(hw+14), top+hh-2],[cx0-dir*(hw+14), top-hh*.3],[cx0+dir*(hw*.5), top-hh-14],[cx0, top-hh-26],[cx0-dir*(hw*.5), top-hh-40],[cx0, top-hh-56]];
  let best=null, bo=1e9; for(const [cx,cy] of C){ const [X,Y]=fit(cx,cy), o=ov(X,Y); if(o<=0) return [X,Y]; if(o<bo){ bo=o; best=[X,Y]; } } return best || fit(isFinite(x)?x:CAMX+VW/2, isFinite(y)?y:120); }   /* 좌표가 이상해도(NaN) 자리는 꼭 돌려준다 */   /* 빈자리가 없으면 가장 덜 겹치는 자리 */
function comicSFX(x,y,word){ const now=performance.now()/1000; if(now-comicT<.5) return; comicT=now; if(word==='KA-BOOM!'){ sfx.boom(); buzz(50); } if(word==='WHOOSH!') sfx.whoosh();
  for(const c of COMIC) if(c.k==='sfx' && c.age<c.life-.1) c.age=c.life-.1;                               // 한 번에 하나만: 앞 글자는 바로 접는다
  const [px,py]=comicSpot(x,y,word); COMIC.push({ k:'sfx', x:px, y:py, word, age:0, life:.6, rot:(Math.random()-.5)*.3 }); }
function comicSay(a,text,kind='speech',force){ const now=performance.now()/1000; if(!a) return; if(!force && now-quipT<5) return; if(kind!=='shout') quipT=now;
  for(const c of COMIC) if(c.a===a) c.age=Math.max(c.age,c.life-.15);                                   // 같은 인물의 앞 풍선은 접는다
  COMIC.push({ k:kind, a, text, age:0, life:kind==='shout'?1.8:2.4 }); }
const comicPop=t=> t<.09 ? .45+.75*(t/.09) : t<.18 ? 1.2-.2*((t-.09)/.09) : 1;                           // 작게 → 살짝 넘치게 → 제 크기
function drawComic(dt){ const cx=uiCx;
  for(const c of COMIC){ c.age+=dt; const s=comicPop(c.age); cx.globalAlpha = c.age>c.life-.25 ? Math.max(0,(c.life-c.age)/.25) : 1;
    if(c.k==='sfx'){ const sh=c.age<.1?(Math.random()-.5)*2:0; if(c.age>.2) cx.globalAlpha*=.9; cx.save(); cx.translate(c.x+sh,c.y+sh); cx.rotate(c.rot); cx.scale(s,s);   /* 작게 · 짧게 · 터진 뒤엔 살짝 비친다 */
      cx.font='italic 900 14px Impact,"Arial Black","Helvetica Neue",sans-serif'; const tw=cx.measureText(c.word).width, R=tw*.58+9;
      const star=(k0,f)=>{ cx.beginPath(); for(let k=0;k<26;k++){ const a=k/26*Math.PI*2, r=(k%2?.7:1)*R*f*(k%6===0?1.14:1); const px=Math.cos(a)*r, py=Math.sin(a)*r*.6; k?cx.lineTo(px,py):cx.moveTo(px,py); } cx.closePath(); };
      star(0,1); cx.fillStyle='#ffe24a'; cx.fill(); cx.lineWidth=1.4; cx.strokeStyle='#0e0d14'; cx.stroke();
      star(0,.74); cx.fillStyle='#ff8a2a'; cx.fill();
      cx.textAlign='center'; cx.textBaseline='middle'; cx.lineJoin='round';
      cx.fillStyle='#3a0a0a'; cx.fillText(c.word,1.8,2.2); cx.lineWidth=3.2; cx.strokeStyle='#0e0d14'; cx.strokeText(c.word,0,0);
      const g=cx.createLinearGradient(0,-6,0,6); g.addColorStop(0,'#fff6c8'); g.addColorStop(1,'#e8322a'); cx.fillStyle=g; cx.fillText(c.word,0,0); cx.restore(); }
    else { const a=c.a; if(a.hidden||a.dead){ c.age=Math.max(c.age,c.life-.2); }
      cx.font='10px Galmuri9,"Apple SD Gothic Neo","Malgun Gothic",sans-serif'; const tw=cx.measureText(c.text).width, w=tw+16, h=18;
      const vx0=(typeof CAMX==='number'?CAMX:0), vx1=vx0+(typeof VW==='number'?VW:W), bx=Math.max(vx0+4,Math.min(vx1-w-4,a.d.x-w/2)), by=a.d.y-104,   /* 세로 화면: 보이는 범위 안에 풍선을 둔다 */ mx=bx+w/2, my=by+h/2, hx=Math.max(bx+6,Math.min(bx+w-6,a.d.x)), hy=a.d.y-72;
      cx.save(); cx.translate(mx,my); cx.scale(s,s); cx.translate(-mx,-my);
      const body=()=>{ cx.beginPath();
        if(c.k==='speech'){ const r=8; cx.moveTo(bx+r,by); cx.arcTo(bx+w,by,bx+w,by+h,r); cx.arcTo(bx+w,by+h,bx,by+h,r); cx.arcTo(bx,by+h,bx,by,r); cx.arcTo(bx,by,bx+w,by,r); cx.closePath();
          cx.moveTo(hx-4,by+h-1); cx.lineTo(hx+3,by+h-1); cx.lineTo(hx+1,hy); cx.closePath(); }
        else if(c.k==='shout'){ const n=24; for(let k=0;k<n;k++){ const t=k/n*Math.PI*2, f=k%2?1:1.28, px=mx+Math.cos(t)*(w/2+2)*f, py=my+Math.sin(t)*(h/2+2)*f; k?cx.lineTo(px,py):cx.moveTo(px,py); } cx.closePath();
          cx.moveTo(hx-3,by+h+1); cx.lineTo(hx+3,by+h+1); cx.lineTo(hx-2,hy); cx.closePath(); }
        else { for(let k=0;k<11;k++){ const t=k/11*Math.PI*2, cxp=mx+Math.cos(t)*w/2*.9, cyp=my+Math.sin(t)*h/2*.92; cx.moveTo(cxp+6.5,cyp); cx.arc(cxp,cyp,6.5,0,Math.PI*2); }
          cx.moveTo(mx+w/2-2,my); cx.ellipse(mx,my,w/2-2,h/2,0,0,Math.PI*2); cx.moveTo(hx+2.4,hy-8); cx.arc(hx,hy-8,2.4,0,Math.PI*2); cx.moveTo(hx+1.4,hy-2.5); cx.arc(hx-1,hy-2.5,1.4,0,Math.PI*2); } };
      body(); cx.lineWidth=2; cx.strokeStyle='#0e0d14'; cx.stroke(); body(); cx.fillStyle=c.k==='shout'?'#fff7d0':'#ffffff'; cx.fill();   // 테두리 → 채우기(겹친 안쪽 선은 덮인다)
      cx.fillStyle='#0e0d14'; cx.textAlign='center'; cx.textBaseline='middle'; cx.fillText(c.text,mx,my+.5); cx.restore(); }
    cx.globalAlpha=1; }
  for(let i=COMIC.length-1;i>=0;i--) if(COMIC[i].age>COMIC[i].life) COMIC.splice(i,1); }

