// =========================================================
// 오프닝 '지하 복도': 측면 롱테이크로 밀고 나가는 좁은 복도 난투(장도리) — 끝의 철문을 나서면 지하철로
//   연출 문법 오마주: 끊김 없는 좌→우 측면 트래킹 · 좁은 복도 · 다수 대 1 · 저채도 녹색 톤 · 측면 강한 광원
// =========================================================
const CORR_LEN=1500;
const CORR_WAVES=[ [0,['stick','stick','stick'],1], [170,['stick','pipe'],1], [260,['stick'],0], [330,['stick','stick'],-1], [470,['pipe','stick','stick'],1], [600,['stick','pipe'],0],
  [780,['stick'],1,'thunder'], [1000,['stick','stick'],1,'bridge'], [1220,['brute'],1,'signoff'] ];   // 금고실(보스의 가방) 뒤: 콤보 쇼
const CORR_VAULT=6;   // 0 = 화면 안의 문에서
const doorAt=wxc=>{ const P=GS.prologue; P.doors=P.doors||{}; return P.doors[wxc]||(P.doors[wxc]={st:'shut',t:0}); };
function visibleDoors(){ const P=GS.prologue, out=[]; for(let wxc=Math.floor((P.x)/240)*240+120; wxc<P.x+SB.W; wxc+=240){ const sx=wxc-P.x; if(sx>CAMX+40 && sx<CAMX+VW-40) out.push(wxc); } return out; }
function doorOpen(wxc,list){ const P=GS.prologue, D=doorAt(wxc); D.st='open'; D.t=0; sfx.door(true); if(SND.on) nz(SND.ctx.currentTime,.4,{f:700,to:300,q:6,g:.12});   // 끼이익
  if(!list||!list.length) return; const before=new Set(GS.ents); spawnWave(list,false); GS.ents.filter(a=>!before.has(a)).forEach((a,k)=>{ a.d.x=wxc-P.x+(k-((list.length-1)/2))*12; a.d.flip = a.d.x>GS.hero.d.x; a.e.cdT=-.8-k*.4; }); }
function doorTick(dt){ const P=GS.prologue; if(!P.doors) P.doors={};
  for(const k in P.doors){ const D=P.doors[k], wxc=+k; D.t+=dt;
    if(D.st==='open' && D.t>1.8){ D.st='shut'; sfx.door(false); }
    if(D.st==='bang'){ const n=Math.floor(D.t/.5); if(n!==D.n){ D.n=n; if(n<D.max){ sfx.thud(); comicT=0; comicSFX(wxc-P.x, SB.FLOOR-96, '쿵!'); for(let j=0;j<4;j++) HITFX.push({ k:'drop', x:wxc-P.x-16+Math.random()*32, y:SB.FLOOR-82, vx:(Math.random()-.5)*20, vy:10, t:0, life:.7, col:'#9a9488' }); }
        else { if(D.burst && foes().length<7){ doorOpen(wxc,['stick']); shakeAmp=2; comicT=0; comicSFX(wxc-P.x, SB.FLOOR-96, 'BAM!'); } else D.st='shut'; } } } }
  P.bangT=(P.bangT??6)-dt;
  if(P.bangT<=0){ P.bangT=9+Math.random()*8; const vis=visibleDoors().filter(w=>doorAt(w).st==='shut'); if(vis.length){ const D=doorAt(vis[Math.floor(Math.random()*vis.length)]); D.st='bang'; D.t=0; D.n=-1; D.max=3+Math.floor(Math.random()*3); D.burst=!P.bag && Math.random()<.5; } } }   /* 보스의 가방 쇼 동안엔 문을 두드리기만 한다 */
function genCorridor(){ const out={}, rnd=mulberry(2003);
  { const p=paint(160,SB.FLOOR); for(let y=0;y<SB.FLOOR;y++) for(let x=0;x<160;x++){                                     // 벽: 위는 녹회색 칠 · 아래 굽도리는 더 어둡게 · 얼룩 · 벗겨진 칠
      const low=y>SB.FLOOR-52, n=rnd(); let t = low ? (n<.08?1:2) : (n<.07?2:3); if(y<30) t=0;
      p.set(x,y, y<30?M.MDARK:M.IVY, y<30?1:t); }
    for(let k=0;k<5;k++){ const x0=Math.floor(rnd()*150), y0=40+Math.floor(rnd()*110); for(let j=0;j<10+rnd()*30;j++) p.set(x0+Math.floor(rnd()*3),y0+j,M.IVY,1); }      // 흘러내린 얼룩
    for(let k=0;k<2;k++){ const x0=10+Math.floor(rnd()*120), y0=60+Math.floor(rnd()*80), w=Math.floor(6+rnd()*8), h=Math.floor(4+rnd()*5);       // 벗겨진 칠: 테두리가 어두운 단단한 조각(흩뿌린 밝은 점은 조명에 별처럼 반짝였다)
      for(let j=0;j<h;j++) for(let i=0;i<w;i++){ const edge=i===0||j===0||i===w-1||j===h-1; if(edge && rnd()<.3) continue; p.set(x0+i,y0+j,M.IVY,edge?1:2); } }
    for(let x=0;x<160;x++) p.set(x,SB.FLOOR-52,M.MDARK,2);
    out.cr_wall=p.s; }
  const G=(p,x,y,str,m,t)=>{ for(const ch of str){ const g=GLYPH[ch]; if(!g){ x+=3; continue; } g.forEach((r,j)=>{ for(let i=0;i<r.length;i++) if(r[i]==='#') p.set(x+i,y+j,m,t); }); x+=Math.max(...g.map(r=>r.length))+1; } };
  { const p=paint(44,82); p.rect(0,0,44,82,M.MDARK,1); p.rect(1,1,42,81,M.STEEL,2); p.rect(4,4,36,78,M.MDARK,1);            // 문틀(케이싱) · 문짝 · 판넬 · 철망 유리 · 번호판 · 레버 · 경첩 · 발판 · 녹물 · 문턱
    p.rect(5,5,34,77,M.IVY,1); for(let y=8;y<78;y++){ p.set(9,y,M.IVY,0); p.set(34,y,M.IVY,0); } p.rect(9,8,26,1,M.IVY,0); p.rect(9,46,26,1,M.IVY,0);
    p.rect(12,12,20,14,M.MDARK,1); p.rect(13,13,18,12,M.GLASS,1,{e:.06}); for(let k=0;k<18;k+=3){ p.set(13+k,13+((k*2)%12),M.STEEL,2); p.set(13+((k*3)%18),13+k%12,M.STEEL,2); }
    p.rect(14,30,16,8,M.FRAME,3); G(p,16,31,'B2',M.MDARK,1); p.rect(31,48,7,2,M.STEEL,4,{r:.7}); p.rect(31,48,2,5,M.STEEL,3);
    for(const y of [12,40,70]) p.rect(4,y,3,6,M.STEEL,3,{r:.5}); p.rect(5,70,34,10,M.STEEL,2,{r:.4}); for(let y=52;y<70;y++) if(y%2) p.set(33+(y%3),y,M.WOODD,2);
    p.rect(0,80,44,2,M.STEEL,1); out.cr_door=p.s;
    const q=paint(44,82); q.rect(0,0,44,82,M.MDARK,1); q.rect(1,1,42,81,M.STEEL,2); q.rect(4,4,36,78,M.MDARK,0); for(let y=10;y<78;y++) for(let x=10;x<38;x++) if(((x+y)&3)===0) q.set(x,y,M.IVY,0);   // 열린 문: 어두운 안쪽 · 안쪽으로 젖혀진 문짝
    for(let y=4;y<80;y++){ const w=Math.round(7-(y<40?(40-y)*.05:(y-40)*.05)); for(let x=0;x<w;x++) q.set(4+x,y,M.IVY,x===w-1?2:1); } q.rect(0,80,44,2,M.STEEL,1); out.cr_door_o=q.s; }
  { const p=paint(160,12); for(let x=0;x<160;x++){ p.set(x,3,M.STEEL,4,{r:.75}); p.set(x,4,M.STEEL,4,{r:.6}); p.set(x,5,M.STEEL,3,{r:.4}); p.set(x,6,M.STEEL,2); p.set(x,7,M.STEEL,1); }   // 벽에 고정한 배수관
    for(const x of [20,100]){ p.rect(x,1,5,9,M.MDARK,2); p.rect(x+1,2,3,1,M.STEEL,4); p.rect(x+1,9,3,2,M.MDARK,1); }                                                  // U자 클램프
    p.rect(58,1,4,9,M.STEEL,3,{r:.6}); p.rect(57,2,6,7,M.STEEL,2);                                                                                                 // 이음 플랜지
    for(let a=0;a<Math.PI*2;a+=.4) p.set(Math.round(140+Math.cos(a)*3),Math.round(5+Math.sin(a)*3),M.RED,3); p.rect(139,4,3,3,M.RED,4); out.cr_wpipe=p.s; }  // 붉은 밸브
  { const p=paint(15,10); p.rect(7,0,1,2,M.MDARK,1); p.rect(5,2,5,2,M.IVY,1);                                                    // 원뿔형 법랑 갓 + 아래로 빛나는 전구
    for(let y=4;y<8;y++){ const w=4+(y-4)*2; for(let x=0;x<w*2+1;x++) p.set(7-w+x,y,M.IVY, x===0||x===w*2?3:(y===4?2:1)); } p.rect(1,7,13,1,M.IVY,3,{r:.5}); p.rect(5,8,5,2,M.FRAME,5,{e:1}); out.cr_lamp=p.s; }
  { const p=paint(16,40); p.rect(6,0,3,22,M.STEEL,2); p.rect(0,22,16,18,M.STEEL,2); p.rect(1,23,14,16,M.STEEL,3,{r:.3}); p.rect(3,26,10,1,M.MDARK,1); p.rect(12,31,2,3,M.RED,4,{e:.4}); G(p,3,33,'HV',M.GOLD,4); out.cr_panel=p.s; }   // 배전함 · 전선관
  { const p=paint(18,20); p.rect(0,0,18,20,M.RED,2); p.rect(2,2,14,16,M.RED,3); p.rect(3,3,12,11,M.GLASS,1,{e:.04}); for(let a=0;a<Math.PI*2;a+=.3) p.set(Math.round(9+Math.cos(a)*4),Math.round(8+Math.sin(a)*4),M.RED,1); p.rect(6,15,6,2,M.FRAME,4); out.cr_hose=p.s; }   // 소화전함
  { const p=paint(22,10); p.rect(0,0,22,10,M.MDARK,1); for(let y=2;y<9;y+=2) p.rect(2,y,18,1,M.STEEL,3); out.cr_vent=p.s; }                          // 환기구
  { const p=paint(160,6); for(let x=0;x<160;x++){ p.set(x,0,M.STEEL,2); p.set(x,5,M.STEEL,2); } for(let x=0;x<160;x+=10) p.rect(x,0,1,6,M.STEEL,1); for(let x=2;x<158;x+=3) p.set(x,2+(x%2),M.MDARK,1); out.cr_tray=p.s; }   // 천장 케이블 트레이
  { const p=paint(26,4); p.rect(0,0,26,4,M.MDARK,1); for(let x=2;x<24;x+=3) p.rect(x,1,1,2,M.STEEL,2); out.cr_drain=p.s; }                          // 바닥 배수구
  { const p=paint(34,74); p.rect(0,0,34,74,M.MDARK,2); p.rect(2,2,30,72,M.STEEL,1); p.rect(4,4,26,68,M.IVY,1); p.rect(10,12,14,10,M.GLASS,1,{e:.05}); p.rect(25,38,4,3,M.STEEL,4,{r:.6});
    for(const [x,y] of [[6,6],[27,6],[6,66],[27,66]]) p.set(x,y,M.STEEL,4); out.cr_door=p.s; }                                                              // 강철 문
  { const p=paint(160,30); for(let x=0;x<160;x++){ p.set(x,6,M.STEEL,3,{r:.5}); p.set(x,7,M.STEEL,2); p.set(x,8,M.STEEL,1); p.set(x,13,M.STEEL,2,{r:.4}); p.set(x,14,M.STEEL,1);   // 천장 배관 두 줄 · 매달린 전선
      const sag=Math.sin((x/160)*Math.PI*2)*4+Math.sin((x/80)*Math.PI)*3; p.set(x,Math.round(20+sag),M.MDARK,1); p.set(x,Math.round(23+Math.cos(x/25)*3),M.MDARK,1); }
    for(const x of [20,100]) p.rect(x,4,3,12,M.MDARK,2); out.cr_pipe=p.s; }
  { const p=paint(160,10); for(let x=0;x<160;x++){ p.set(x,3,M.STEEL,4,{r:.7}); p.set(x,4,M.STEEL,3,{r:.5}); p.set(x,5,M.STEEL,2); p.set(x,6,M.STEEL,1); }      // 손이 닿는 배수관(매달려 차기)
    for(const x of [30,110]){ p.rect(x,2,6,6,M.MDARK,2); p.rect(x+1,3,4,1,M.STEEL,3); } out.cr_lowpipe=p.s;
    const h=paint(2,150); h.rect(0,0,2,150,M.MDARK,1); out.cr_hanger=h.s; const d=paint(1,1); d.set(0,0,M.MDARK,1); out.cr_dot=d.s; }
  { const p=paint(9,12); p.rect(4,0,1,3,M.MDARK,1); p.rect(2,3,5,2,M.STEEL,2); for(let y=5;y<11;y++) for(let x=1;x<8;x++) if((x-4)*(x-4)+(y-8)*(y-8)<=9) p.set(x,y,M.FRAME,5,{e:1}); for(const x of [1,4,7]) p.rect(x,5,1,6,M.MDARK,1); out.cr_bulb=p.s; }   // 철망 씌운 맨전구
  { const p=paint(160,SB.H-SB.FLOOR+6); for(let y=0;y<SB.H-SB.FLOOR+6;y++) for(let x=0;x<160;x++){ const n=rnd(); p.set(x,y,M.WOODD, y<2?3:(n<.1?1:2)); } for(let k=0;k<6;k++){ const x0=Math.floor(rnd()*150); for(let i=0;i<10;i++) p.set(x0+i,3+Math.floor(rnd()*20),M.WOODD,1); } out.cr_floor=p.s; }   // 닳은 바닥
  { const p=paint(48,92); p.rect(0,0,48,92,M.MDARK,2); p.rect(3,14,42,78,M.STEEL,1); p.rect(6,17,17,72,M.STEEL,2); p.rect(25,17,17,72,M.STEEL,2); p.rect(10,2,28,9,M.MDARK,1); for(let x=13;x<36;x+=2) p.set(x,6,M.NEONT,5,{e:1}); out.cr_exit=p.s;
    const q=paint(48,92); q.rect(0,0,48,92,M.MDARK,2); q.rect(3,14,42,78,M.FRAME,5,{e:1}); q.rect(3,14,8,78,M.STEEL,2); q.rect(10,2,28,9,M.MDARK,1); for(let x=13;x<36;x+=2) q.set(x,6,M.NEONT,5,{e:1}); out.cr_exit_o=q.s; }   // 열린 철문(빛)   // 끝 철문 · 비상구 표시등
  return out; }
// =========================================================
// 복도 퀄리티업: 청록 칠 벽 · 굽도리 얼룩 · 천장 배관 · 전선 다발 · 접이식 철창 · 배전함 · 뉴욕식 그래피티 · 반사되는 물웅덩이 · 벽 밑 잡동사니
// =========================================================
function genCorridor2(){ const out={}, rnd=mulberry(1982), WALLM=M.NEONT||M.ARMOR;
  const ell=(p,cx,cy,rx,ry,m,t,o)=>{ for(let y=-ry;y<=ry;y++) for(let x=-rx;x<=rx;x++) if((x*x)/(rx*rx)+(y*y)/(ry*ry)<=1) p.set(Math.round(cx+x),Math.round(cy+y),m,typeof t==='function'?t(x,y):t,o); };
  // 벽(240): 위 청록 칠 · 구분띠 · 아래 짙은 굽도리(흘러내린 얼룩 · 곰팡이) · 걸레받이 · 세로 이음매
  { const p=paint(240,SB.FLOOR); for(let y=0;y<SB.FLOOR;y++) for(let x=0;x<240;x++){ const n=rnd();
      if(y<40) p.set(x,y,M.MDARK,1);
      else if(y<150){ const g=(y-40)/110; p.set(x,y,WALLM, n<.05?3:(g>.85&&n<.3?3:4)); }                                     // 밝은 청록 칠
      else if(y<154) p.set(x,y,WALLM, y===150?1:2);
      else p.set(x,y,WALLM, n<.12?1:2); }
    for(let k=0;k<14;k++){ const x0=Math.floor(rnd()*236), y0=154+Math.floor(rnd()*6), L=8+rnd()*48; for(let j=0;j<L;j++) p.set(x0+(j>L*.7&&rnd()<.3?1:0),y0+j,WALLM,0); }   // 흘러내린 얼룩
    for(let k=0;k<5;k++){ const cx=Math.floor(rnd()*230), cy=200+Math.floor(rnd()*18); ell(p,cx,cy,6+rnd()*10,3+rnd()*4,M.MOSS||M.IVY,(x,y)=>rnd()<.6?1:0); }           // 곰팡이 · 습기
    for(let k=0;k<3;k++){ const x0=Math.floor(rnd()*220), y0=70+Math.floor(rnd()*60), w=6+rnd()*10|0, h=4+rnd()*5|0; for(let j=0;j<h;j++) for(let i=0;i<w;i++) if(!((i===0||i===w-1)&&(j===0||j===h-1))) p.set(x0+i,y0+j,(i===0||j===0)?WALLM:M.CURB,(i===0||j===0)?2:2); }   // 벗겨진 칠(드러난 회반죽 · 적게)
    for(const x of [0,120]) for(let y=40;y<SB.FLOOR;y++) p.set(x,y,WALLM,y<150?3:1);
    p.rect(0,SB.FLOOR-6,240,6,M.MDARK,1); p.rect(0,SB.FLOOR-6,240,1,M.STEEL,2); out.cr_wall2=p.s; }
  // 천장(240×44): 배관 4줄(녹슨 관) · 덕트 · 브래킷
  { const p=paint(240,44); p.rect(0,0,240,44,M.STEEL,1); for(let y=0;y<44;y+=11) p.rect(0,y,240,1,M.MDARK,1);
    const pipe=(y,r,m)=>{ for(let x=0;x<240;x++) for(let k=-r;k<=r;k++) p.set(x,y+k,m, k<=-r+1?4:k>=r-1?1:k<0?3:2,{r:.4}); };
    pipe(8,3,M.STEEL); pipe(17,2,M.WOODD); pipe(24,4,M.STEEL); pipe(34,2,M.STEEL);
    p.rect(150,2,60,12,M.STEEL,2); for(let x=152;x<208;x+=4) p.rect(x,4,2,8,M.STEEL,1);                                                       // 덕트
    for(const x of [30,110,190]){ p.rect(x,0,3,40,M.MDARK,1); p.rect(x-2,38,7,2,M.MDARK,1); }
    for(let x=0;x<240;x+=20) p.rect(x,16,3,3,M.WOODD,1); out.cr_ceil=p.s; }
  // 전선 다발: 천장 걸이(30 · 110 · 190)의 J자 고리에 케이블 타이로 묶이고, 고리 사이에서만 현수선으로 처진다 · 두 변형을 번갈아
  const cables=(seed)=>{ const r=mulberry(seed), p=paint(240,64), HK=[30,110,190,270], Y0=8;
    const strand=(x0,x1,y0,sag,m,t)=>{ for(let x=x0;x<=x1;x++){ const u=(x-x0)/(x1-x0), y=y0+sag*4*u*(1-u); p.set(((x%240)+240)%240,Math.round(y),m,t); } };
    const bundles=[ { n:5, base:[10,16], off:0 }, { n:3, base:[16,24], off:3 } ];
    for(let h=0;h<3;h++){ const x0=HK[h], x1=HK[h+1];
      for(const B of bundles){ if(B.n===3 && r()<.3) continue; const sag=B.base[0]+r()*(B.base[1]-B.base[0]);
        for(let k=0;k<B.n;k++){ const m = k===1&&B.n===5 ? M.STEEL : (k===2&&B.n===3 ? M.RED : M.MDARK), t = m===M.MDARK ? (k%2?1:0) : (m===M.RED?1:2);
          strand(x0,x1,Y0+B.off+k*.9,sag+k*.6,m,t); } } }
    { const h=Math.floor(r()*3), x0=HK[h], x1=HK[h+1], sag=30+r()*10; strand(x0,x1,Y0+2,sag,M.MDARK,1);                              // 한 가닥은 깊게 처지고 · 끝에 감긴 고리
      const cx=Math.round((x0+x1)/2+(r()-.5)*20)%240, cy=Math.round(Y0+2+sag+4); for(let a=0;a<Math.PI*2;a+=.15){ p.set(cx+Math.round(Math.cos(a)*3),cy+Math.round(Math.sin(a)*4),M.MDARK,1); p.set(cx+Math.round(Math.cos(a)*2),cy+Math.round(Math.sin(a)*3),M.MDARK,0); } }
    for(const hx of [30,110,190]){ p.rect(hx-1,0,3,Y0,M.STEEL,2); p.rect(hx-3,Y0,7,2,M.STEEL,3); p.set(hx+3,Y0-1,M.STEEL,3); p.rect(hx-2,Y0+2,5,5,M.STEEL,1); p.rect(hx-2,Y0+3,5,1,M.FRAME,3); }   // J자 고리 · 케이블 타이
    return p.s; };
  out.cr_cables=cables(4711); out.cr_cables2=cables(9283);
  // 접이식 철창 게이트(46×82): 대각 격자 · 어두운 안쪽
  { const p=paint(46,82); p.rect(0,0,46,82,M.MDARK,1); p.rect(2,2,42,80,M.MDARK,0); for(let y=0;y<80;y++) for(let x=0;x<42;x++){ if(((x+y)%10===0)||((x-y+400)%10===0)) p.set(3+x,2+y,M.STEEL,3,{r:.6}); }
    for(let x=3;x<44;x+=10) p.rect(x,2,1,80,M.STEEL,2); p.rect(0,0,46,3,M.STEEL,2); p.rect(0,79,46,3,M.STEEL,1); p.rect(40,36,3,8,M.STEEL,4); out.cr_gate=p.s; }
  // 배전함 · 전선관 · 주황 배관 · 붉은 표시등(28×110)
  { const p=paint(28,110); p.rect(10,0,3,60,M.STEEL,2); p.rect(16,0,2,64,M.STEEL,2); p.rect(2,58,24,30,M.STEEL,3,{r:.3}); p.rect(4,60,20,26,M.STEEL,2); p.rect(6,64,16,1,M.MDARK,1); p.rect(6,70,10,1,M.MDARK,1);
    p.rect(20,80,3,3,M.RED,5,{e:1}); for(let y=88;y<110;y++){ p.set(12,y,M.NEONO||M.GOLD,3); p.set(13,y,M.NEONO||M.GOLD,4); p.set(14,y,M.NEONO||M.GOLD,2); } p.rect(9,96,9,4,M.NEONO||M.GOLD,2); out.cr_jbox=p.s; }
  // 벽 밑 잡동사니: 나무 상자 · 양동이 · 쓰레기봉투
  { const p=paint(60,24); p.rect(0,6,22,18,M.WOOD,3); for(let y=8;y<24;y+=5) p.rect(0,y,22,1,M.WOOD,1); p.rect(10,6,2,18,M.WOOD,2); p.rect(4,0,16,8,M.WOOD,2); p.rect(4,3,16,1,M.WOOD,1);
    ell(p,34,16,6,7,M.STEEL,3); p.rect(28,9,12,2,M.STEEL,4); ell(p,50,17,9,7,M.MDARK,(x,y)=>y<-2?2:1); p.set(48,10,M.STEEL,3); out.cr_junk=p.s; }
  // 바닥(240): 앞쪽이 밝아지는 콘크리트 · 얼룩 · 금 · 웅덩이(젖은 재질 → 반사)
  { const h=SB.H-SB.FLOOR+6, p=paint(240,h); for(let y=0;y<h;y++) for(let x=0;x<240;x++){ const n=rnd(); p.set(x,y,M.CURB, y<3?1:(n<.08?1:(y>h*.55?3:2))); }
    for(let k=0;k<5;k++){ let x=Math.floor(rnd()*230), y=4+Math.floor(rnd()*30); for(let j=0;j<16;j++){ p.set(x,y,M.CURB,0); x+=rnd()<.5?1:0; y+=rnd()<.6?1:0; } }
    for(const [cx,cy,rx,ry] of [[60,18,16,3],[178,26,22,4],[118,40,12,2]]) ell(p,cx,cy,rx,ry,M.ROADW,(x,y)=>Math.abs(x)>rx-3?3:5); out.cr_floor2=p.s; }
  // 뉴욕식 그래피티: 버블 스로업(은색 · 핑크 · 노랑 + 검은 외곽선 + 그림자) · 마커 태그 · 왕관 · 스티커 · 흘러내린 물감
  const bubble=(word,fill,ft,shadow,sc=3)=>{ const glyphs=[...word].map(ch=>GLYPH[ch]).filter(Boolean), w=glyphs.reduce((a,g)=>a+(Math.max(...g.map(r=>r.length))+1)*sc,0)+6, h=5*sc+8, p=paint(w,h);
    const mask=new Set(); let x0=3; for(const g of glyphs){ g.forEach((r,j)=>{ for(let i=0;i<r.length;i++) if(r[i]==='#') for(let a=0;a<sc;a++) for(let b=0;b<sc;b++) mask.add((x0+i*sc+a)+','+(3+j*sc+b-((i%2)?1:0))); }); x0+=(Math.max(...g.map(r=>r.length))+1)*sc; }
    const has=(x,y)=>mask.has(x+','+y);
    for(const k of mask){ const [x,y]=k.split(',').map(Number); p.set(x+2,y+2,shadow,1); }                                   // 그림자
    for(const k of mask){ const [x,y]=k.split(',').map(Number); for(const [dx,dy] of [[-1,0],[1,0],[0,-1],[0,1],[-1,-1],[1,1]]) if(!has(x+dx,y+dy)) p.set(x+dx,y+dy,M.MDARK,0); }   // 두꺼운 검은 외곽선
    for(const k of mask){ const [x,y]=k.split(',').map(Number); p.set(x,y,fill, has(x,y-1)?ft:ft+1); if(!has(x-1,y)&&!has(x,y-1)) p.set(x,y,M.FRAME,5); }        // 채움 · 윗면 하이라이트
    for(let k=0;k<4;k++){ const dx=4+Math.floor(rnd()*(w-8)); for(let j=0;j<4+rnd()*6;j++) p.set(dx,h-3+j>h-1?h-1:h-3+j,fill,ft); }   // 흘러내림
    return p.s; };
  out.gf_ltn=bubble('LTN',M.STEEL,3,M.ARMOR,4); out.gf_mob=bubble('MOB',M.NEONP||M.RED,3,M.MDARK,4); out.gf_nyc=bubble('NYC',M.GOLD,3,M.RED,2); out.gf_b2=bubble('B2X',M.NEONT||M.ARMOR,3,M.MDARK,2);
  const tag=(word,m,t)=>{ const glyphs=[...word].map(ch=>GLYPH[ch]).filter(Boolean), w=glyphs.length*5+18, p=paint(w,14); let x0=2;
    for(const g of glyphs){ g.forEach((r,j)=>{ for(let i=0;i<r.length;i++) if(r[i]==='#') p.set(x0+i+Math.round((5-j)*.5),2+j,m,t); }); x0+=Math.max(...g.map(r=>r.length))+1; }
    for(let x=2;x<w-2;x++) p.set(x,10+Math.round(Math.sin(x*.4)*1.2),m,t); p.set(w-3,8,m,t); p.set(w-2,7,m,t); return p.s; };                      // 마커 태그 + 밑줄 스우시
  out.gf_tag1=tag('DOTS 82',M.MDARK,0); out.gf_tag2=tag('RUSH',M.RED,3); out.gf_tag3=tag('B2 KING',M.STEEL,4);
  { const p=paint(14,10); for(const [x,y] of [[1,8],[2,8],[3,8],[4,8],[5,8],[6,8],[7,8],[8,8],[9,8],[10,8],[11,8],[12,8]]) p.set(x,y,M.GOLD,4); for(const x of [1,4,7,10,12]) for(let y=3;y<8;y++) if(y>8-Math.abs(((x-6.5))*-.6+5)) p.set(x,y,M.GOLD,4);
    for(const [x,y] of [[1,2],[6,0],[12,2]]) p.set(x,y,M.GOLD,5); out.gf_crown=p.s; }                                                             // 왕관
  { const p=paint(14,10); p.rect(0,0,14,10,M.FRAME,4); p.rect(0,0,14,3,M.RED,3); p.rect(2,5,10,1,M.MDARK,1); p.rect(2,7,7,1,M.MDARK,1); out.gf_sticker=p.s; }   // 스티커
  { const p=paint(34,6); p.rect(0,0,34,6,M.STEEL,2); p.rect(2,2,30,3,M.FRAME,5,{e:1}); p.rect(0,0,34,1,M.STEEL,3); out.cr_fluo=p.s; }   // 천장 형광등
  return out; }
// 구간(240)마다 정해진 조합: 문 / 철창 · 배전함 · 그래피티 · 잡동사니
const CORR_SEG=[ { door:'door', gf:[['gf_ltn',8,74],['gf_tag1',150,112]], jbox:52, junk:180 }, { door:'gate', gf:[['gf_mob',10,82],['gf_crown',26,72],['gf_sticker',176,128]], jbox:186, junk:12 },
  { door:'door', gf:[['gf_nyc',156,86],['gf_tag2',14,126],['gf_tag3',160,132]], jbox:30, junk:186 }, { door:'gate', gf:[['gf_b2',150,80],['gf_tag1',10,120],['gf_sticker',60,104]], jbox:54, junk:178 } ];

function drawCorridor(time){ const P=GS.prologue, x0=P.x; drawDepth=.85;
  for(let k=-1;k<4;k++){ const x=k*240-(x0%240); quad('cr_wall2',Math.round(x),0); quad('cr_floor2',Math.round(x),SB.FLOOR-6); }
  for(let wx=Math.floor((x0-240)/240)*240; wx<x0+SB.W+240; wx+=240){ const bx=Math.round(wx-x0), seg=CORR_SEG[((Math.round(wx/240)%4)+4)%4];
    for(const [g,gx,gy] of seg.gf) quad(g, bx+gx, gy);                                                                                     // 뉴욕식 그래피티
    quad('cr_jbox', bx+seg.jbox, 40); quad('cr_vent', bx+(seg.jbox>120?60:150), 50);
    { const D=(GS.prologue.doors||{})[wx+120], st=D?D.st:'shut', jit = st==='bang' && (D.t%.5)<.12 ? (Math.random()<.5?-1:1) : 0;
      if(seg.door==='gate' && st!=='open') quad('cr_gate', bx+97+jit, SB.FLOOR-81); else quad(st==='open'?'cr_door_o':'cr_door', bx+98+jit, SB.FLOOR-81); }
    quad('cr_junk', bx+seg.junk, SB.FLOOR-24); quad('cr_drain', bx+168, SB.FLOOR-2); }
  for(let k=-1;k<4;k++){ const x=Math.round(k*240-(x0%240)); quad('cr_ceil',x,0); quad('cr_fluo',x+150,42); }
  for(let k=-1;k<5;k++) quad('cr_wpipe', Math.round(k*160-(x0%160)), CR_PIPE_Y-5);                                       // 문 위 벽에 고정한 배수관
  for(let k=-1;k<4;k++){ const seg=Math.floor(x0/240)+k; quad((seg&1)?'cr_cables2':'cr_cables', Math.round(k*240-(x0%240)), 30); }      // 걸이 사이로 처진 전선 다발(두 변형 번갈아)
  for(const L of corrLamps()){ const n=Math.ceil(LAMP_L/2); for(let i=1;i<n;i++){ const u=i/n; quad('cr_dot', Math.round(L.ax+(L.x-L.ax)*u), Math.round(LAMP_TOP+(L.y-LAMP_TOP)*u)); }   // 흔들리는 전선
    quad('cr_lamp', Math.round(L.x)-7, Math.round(L.y)-1); }
  const ex=CORR_LEN+440-x0; if(ex<SB.W+60) quad(P.out?'cr_exit_o':'cr_exit', Math.round(ex)-24, SB.FLOOR-98);
  drawDepth=0; }
const CR_PIPE_Y=130, LAMP_TOP=36, LAMP_L=62;
function corrLamps(){ const P=GS.prologue, out=[]; P.lamps=P.lamps||{};                                                   // 진자처럼 흔들리는 전등(빛과 그림자도 함께)
  for(let wx=Math.floor((P.x-80)/200)*200+60; wx<P.x+SB.W+80; wx+=200){ const st=P.lamps[wx]||(P.lamps[wx]={a:(Math.random()-.5)*.1, v:0}), ax=wx-P.x;
    out.push({ ax, x:ax+Math.sin(st.a)*LAMP_L, y:LAMP_TOP+Math.cos(st.a)*LAMP_L, st, wx }); } return out; }
function lampTick(dt){ const P=GS.prologue; if(!P||!P.lamps) return; for(const k in P.lamps){ const st=P.lamps[k];
    st.v += (-(9.8*60/LAMP_L)*Math.sin(st.a) - .55*st.v)*dt + (Math.random()-.5)*.25*dt; st.a += st.v*dt; } }
function lampKick(sx,str){ const P=GS.prologue; if(!P) return; for(const L of corrLamps()){ const d=L.ax-sx; if(Math.abs(d)<90) L.st.v += Math.sign(d||1)*str*(1-Math.abs(d)/90); } }   // 근처 충격 · 배관 울림
function corridorLights(){ const P=GS.prologue, L=[];
  for(const lp of corrLamps()){ const fl=Math.sin(GS.time*13+lp.wx)>.97?.4:1, a=lp.st.a;
    L.push({x:lp.x, y:lp.y+8, z:20, r:240, c:[1,.88,.65], i:2.1*fl, spot:[Math.sin(a),Math.cos(a)], cone:.78}); L.push({x:lp.x, y:lp.y+4, z:6, r:26, c:[1,.8,.5], i:.8*fl}); }   // 맨전구(가끔 깜빡) — 흔들리는 자리에서
  const ex=CORR_LEN+440-P.x; if(ex<SB.W+80) L.push({x:ex, y:SB.FLOOR-90, z:20, r:90, c:[.4,1,.6], i:1.2});
  if(P.out) L.push({x:ex, y:SB.FLOOR-40, z:30, r:260, c:[.85,1,.88], i:Math.min(3.2,P.outT*3)});                                                // 열린 철문 너머의 빛
  for(let wx=Math.floor((P.x-240)/240)*240; wx<P.x+SB.W+240; wx+=240) L.push({x:wx+167-P.x, y:52, z:34, r:300, c:[.86,.96,1], i:2.2});   // 천장 형광등: 벽을 고르게
  L.push({x:SB.W/2, y:140, z:80, r:460, c:[.6,.85,.82], i:.6}); return L; }
// =========================================================
// 복도 → 지하철 만화 페이지(도트 원화 3칸): 칸마다 원화 + 움직이는 덧그림(빛 먼지 · 비 · 구형 등) + 캡션 · 효과음 레터링
// =========================================================
Object.assign(ICON_PAL,{ D:'#14241a', d:'#22402c', v:'#0a1028', V:'#18224a', u:'#2e3c66', a:'#eaffec', q:'#5a3424', Q:'#7a4a32', i:'#2a1e16' });
const backView=(b,x,y,s,coat,rim)=>{ const P=(pts,c)=>b.poly(pts.map(([px,py])=>[x+px*s,y+py*s]),c);                                   // 뒷모습(정장 · 깃 · 넘긴 머리) + 한쪽 테두리 빛
  P([[-7,-28],[7,-28],[8,-12],[5,-12],[4,0],[1,0],[0,-10],[-1,-10],[-2,0],[-5,0],[-6,-12],[-8,-12]],coat); P([[-3,-31],[3,-31],[2,-28],[-2,-28]],coat);
  b.ell(x,y-35*s,4.2*s,4.6*s,'K'); b.ell(x-.5*s,y-36.5*s,3.4*s,3.2*s,'N'); P([[-4,-29],[-2,-31],[0,-29],[2,-31],[4,-29],[0,-27]],'G');
  if(rim) for(let k=-28;k<0;k+=1){ b.set(x+Math.round((k>-12?5:7.5)*s),y+k*s,rim); } };
const STORY_ART={};
function storyArt(k){ if(STORY_ART[k]) return STORY_ART[k]; let b;
  if(k==='p1'){ b=pBuf(224,118); b.rect(0,0,224,118,'D'); for(let y=0;y<86;y++) for(let x=0;x<224;x++) if(((x+y)&3)===0) b.set(x,y,'d');              // 녹색 복도 벽 · 망점
    b.rect(0,86,224,32,'i'); for(let x=0;x<224;x+=2) b.set(x,86,'x'); b.rect(0,14,224,4,'G'); b.rect(0,15,224,1,'g');                                  // 바닥 · 배수관
    b.rect(118,20,52,70,'N'); b.rect(122,24,44,66,'a'); for(let y=24;y<90;y++) for(let x=122;x<166;x++) if(y>60 && ((x*3+y)%7)===0) b.set(x,y,'h');     // 열린 철문 · 문틈 빛
    b.poly([[166,24],[196,16],[196,98],[166,90]],'K'); b.poly([[168,26],[194,19],[194,95],[168,88]],'d');                                               // 이쪽으로 젖혀진 문짝
    b.poly([[122,90],[166,90],[224,118],[60,118]],'W'); for(let y=90;y<118;y++) for(let x=40;x<224;x++) if(b.get(x,y)==='W' && ((x+y)&1) && y>98) b.set(x,y,'i');   // 바닥에 떨어진 빛 쐐기(옅은 흰빛 · 멀수록 성글게)
    backView(b,144,90,1.5,'K','a'); b.rect(152,66,2,14,'C'); b.rect(149,78,8,3,'W'); b.rect(155,78,2,2,'g'); }                                          // 장도리를 든 뒷모습
  if(k==='p2'){ b=pBuf(222,118); for(let y=0;y<118;y++) b.rect(0,y,222,1,y<40?'v':y<80?'V':'v');
    for(const [bx,bw,bh,c] of [[0,48,92,'q'],[46,40,104,'Q'],[86,54,86,'q'],[140,44,108,'Q'],[184,38,96,'q']]){ b.rect(bx,118-bh,bw,bh,c); b.rect(bx,118-bh,bw,3,'i');   // 브라운스톤 · 창 · 비상계단
      for(let wy=118-bh+8; wy<100; wy+=14) for(let wx=bx+5; wx<bx+bw-6; wx+=10){ const lit=((wx*7+wy*3)%5)<2; b.rect(wx,wy,5,7,lit?'t':'N'); if(lit) b.set(wx+1,wy+1,'h'); }
      for(let fy=118-bh+14; fy<96; fy+=14){ b.line(bx+bw-14,fy,bx+bw-2,fy,'N'); b.line(bx+bw-14,fy,bx+bw-2,fy+14,'N'); } }
    b.rect(0,100,222,18,'N'); for(let x=0;x<222;x+=3) if(((x*5)%11)<4) b.line(x,101,x,101+((x*7)%12),'u');                                             // 젖은 아스팔트 · 비친 창빛
    for(const rx of [30,104,176]) for(let y=102;y<116;y+=2) b.set(rx+((y*3)%4),y,'y');
    b.rect(196,40,2,62,'N'); b.rect(190,36,14,4,'N'); b.ell(197,42,4,2,'t');                                                                              // 가로등
    b.rect(28,82,14,18,'g'); b.rect(26,80,18,3,'G'); for(let y=84;y<98;y+=3) b.line(29,y,40,y,'G'); b.rect(36,68,2,13,'C'); b.rect(32,66,9,3,'W');          // 장도리가 꽂힌 쓰레기통
    backView(b,128,102,1.25,'K','u'); b.poly([[123,-30*1.25+102],[133,-30*1.25+102],[131,-27*1.25+102],[125,-27*1.25+102]],'n'); }                         // 깃 세운 뒷모습
  if(k==='p3'){ b=pBuf(452,112); for(let y=0;y<112;y++) b.rect(0,y,452,1,y<50?'v':'V'); for(const [bx,bw,bh] of [[0,70,60],[60,50,80],[330,60,70],[390,62,90]]){ b.rect(bx,112-bh,bw,bh,'N'); for(let wy=112-bh+6;wy<96;wy+=12) for(let wx=bx+4;wx<bx+bw-5;wx+=9) if(((wx+wy)%4)===0) b.rect(wx,wy,4,5,'t'); }
    b.rect(0,96,452,16,'G'); for(let x=0;x<452;x+=16) b.set(x,96,'g');                                                                                    // 보도
    b.rect(166,70,120,42,'K'); for(let k2=0;k2<6;k2++){ const yy=74+k2*6, ins=k2*7; b.rect(170+ins,yy,112-ins*2,5,k2%2?'g':'W'); b.rect(170+ins,yy+5,112-ins*2,1,'G'); }   // 타일 계단 · 아래에서 올라오는 빛
    b.rect(206,104,40,8,'t'); for(let x=208;x<246;x+=2) b.set(x,103,'y');
    for(const sx of [160,286]){ b.rect(sx,58,6,42,'N'); for(let y=60;y<98;y+=6) b.line(sx,y,sx+5,y+4,'G'); }                                             // 철제 난간
    for(const gx of [148,304]){ b.rect(gx-1,36,3,62,'N'); b.ell(gx,30,7,7,'e'); b.ell(gx-2,28,2.5,2.5,'h'); b.rect(gx-3,37,7,2,'N'); }                     // 초록 구형 등
    b.rect(176,40,100,16,'K'); b.rect(178,42,96,12,'N');                                                                                                  // 간판(글자는 위에 덧그림)
    backView(b,226,94,1.0,'K','t'); }
  pShade(b); return STORY_ART[k]=pCanvas(b); }
function storyPanel(x,y,w,h,art,cap,a,dx,dy,over){ const cx=uiCx; cx.save(); cx.globalAlpha=a; cx.translate(dx,dy); cx.beginPath(); cx.rect(x,y,w,h); cx.save(); cx.clip();
  cx.imageSmoothingEnabled=false; cx.drawImage(storyArt(art),x,y,w,h); if(over) over(cx); cx.restore();
  cx.lineWidth=4; cx.strokeStyle='#0e0d14'; cx.strokeRect(x,y,w,h); cx.lineWidth=1.2; cx.strokeStyle='#f1ece0'; cx.strokeRect(x+.6,y+.6,w-1.2,h-1.2);
  if(cap){ cx.font='10px Galmuri9,monospace'; const tw=cx.measureText(cap).width; cx.fillStyle='#0e0d14'; cx.fillRect(x+6,y+6,tw+12,16); cx.fillStyle='#f6e27a'; cx.fillRect(x+4,y+4,tw+12,16); cx.strokeStyle='#0e0d14'; cx.lineWidth=1.5; cx.strokeRect(x+4,y+4,tw+12,16); cx.fillStyle='#1a1206'; cx.textBaseline='middle'; cx.fillText(cap,x+10,y+12.5); }
  cx.restore(); }
function drawStory(C){ const t=C.t, P=[0,2.1,4.2], al=k=>Math.max(0,Math.min(1,(t-P[k])/.3)), sl=k=>(1-easeO((t-P[k])/.35));
  uiCx.fillStyle='#14121c'; uiCx.fillRect(0,0,W,H); uiCx.fillStyle='rgba(255,255,255,.03)'; for(let yy=0;yy<H;yy+=4) for(let xx=(yy/4)%2*2;xx<W;xx+=4) uiCx.fillRect(xx,yy,1,1);   // 원고지 망점
  if(t>=P[0]) storyPanel(14,16,224,118,'p1','철문 너머는 바깥이었다.',al(0),-sl(0)*240,0, cx=>{ for(let k=0;k<14;k++){ const px=150+((k*29+t*12)%70), py=40+((k*17+t*9)%70); cx.fillStyle=`rgba(255,255,240,${.35+.3*Math.sin(t*3+k)})`; cx.fillRect(px,py,1,1); }   // 빛 속 먼지
      if(t>.5) letter('끼이익',200,34,10,'#cfe8d0',-.1); });
  if(t>=P[1]) storyPanel(244,16,222,118,'p2','비. 장도리는 쓰레기통에 버렸다.',al(1),sl(1)*240,0, cx=>{ cx.strokeStyle='rgba(170,200,255,.5)'; cx.lineWidth=.8; for(let k=0;k<46;k++){ const rx=244+((k*37+t*120)%230), ry=16+((k*53+t*240)%118); cx.beginPath(); cx.moveTo(rx,ry); cx.lineTo(rx-3,ry+9); cx.stroke(); }   // 비
      cx.fillStyle=`rgba(255,231,168,${.18+.1*Math.sin(t*9)})`; cx.beginPath(); cx.arc(441,58,14,0,Math.PI*2); cx.fill(); if(t>P[1]+.4) letter('클랭!',300,86,13,'#ffd34a',-.15); letter('쏴아아',420,118,9,'#a8c4ff',-.05); });
  if(t>=P[2]) storyPanel(14,140,452,114,'p3','가장 가까운 지하철역 — 애틀랜틱 애비뉴.',al(2),0,sl(2)*120, cx=>{ for(const gx of [162,318]){ const g=cx.createRadialGradient(gx,170,1,gx,170,26); g.addColorStop(0,`rgba(110,232,122,${.55+.15*Math.sin(t*4)})`); g.addColorStop(1,'rgba(110,232,122,0)'); cx.fillStyle=g; cx.fillRect(gx-26,144,52,52); }
      cx.font='bold 12px Galmuri11,monospace'; cx.textAlign='center'; cx.fillStyle='#ffffff'; cx.fillText('SUBWAY',240,190); cx.font='10px Galmuri9,monospace'; cx.fillStyle='#ff9a4a'; cx.fillText('● D',212,206); cx.fillStyle='#cfc6e6'; cx.fillText('Atlantic Av',258,206); cx.textAlign='left';
      if(t>P[2]+.5) letter('저벅',300,232,10,'#e9e4f7',-.08); });
  if(t>6.6){ uiCx.fillStyle=`rgba(0,0,0,${Math.min(1,(t-6.6)/.5)})`; uiCx.fillRect(0,0,W,H); } }

// =========================================================
// 복도 → 엔진 느와르 거리(실시간 조명 · 비 · 젖은 노면 반사) → 지하철 입구 → 객차
// =========================================================
const CINE={ start:160, trash:560, ent:1000, y:NFLOOR+26, spd:150 };
function genCine(){ const out={};
  { const p=paint(20,26); p.rect(2,4,16,22,M.STEEL,2,{r:.5}); for(let y=7;y<25;y+=3) p.rect(3,y,14,1,M.STEEL,1); p.rect(0,2,20,3,M.STEEL,3,{r:.6}); p.rect(3,0,14,2,M.STEEL,1);   // 철제 쓰레기통
    out.cn_trash=p.s; const h=paint(10,14); h.rect(4,3,2,11,M.WOOD,3); h.rect(0,0,10,4,M.STEEL,4,{r:.8}); out.cn_hammer=h.s; }
  { const p=paint(20,84); p.rect(9,18,3,62,M.MDARK,2); p.rect(10,18,1,62,M.STEEL,3); p.rect(6,78,9,6,M.MDARK,1); p.rect(7,16,7,3,M.MDARK,2);   // 초록 구형 등(크게 · 받침대)
    for(let y=0;y<18;y++) for(let x=0;x<20;x++){ const d=(x-10)**2+(y-8.5)**2; if(d<=72) p.set(x,y,M.NEONG||M.IVY, d<20?5:d<45?4:3,{e:1}); } p.set(7,5,M.FRAME,5,{e:1}); p.set(8,4,M.FRAME,5,{e:1}); out.cn_globe=p.s; }
  { const p=paint(124,72); p.rect(0,0,124,20,M.MDARK,1); p.rect(2,2,120,16,M.MDARK,0); p.rect(2,17,120,1,M.STEEL,3);                   // 지하철 입구: 큰 간판 · 노선 표시 · 철제 난간 · 아래에서 빛이 올라오는 계단
    const G=(p,x,y,str,m,t,sc=1)=>{ for(const ch of str){ const g=GLYPH[ch]; if(!g){ x+=3*sc; continue; } g.forEach((r,j)=>{ for(let i=0;i<r.length;i++) if(r[i]==='#') for(let a=0;a<sc;a++) for(let b2=0;b2<sc;b2++) p.set(x+i*sc+a,y+j*sc+b2,m,t,{e:.95}); }); x+=(Math.max(...g.map(r=>r.length))+1)*sc; } };
    G(p,18,5,'SUBWAY',M.FRAME,5,2); for(let y=4;y<15;y++) for(let x=96;x<108;x++) if((x-101.5)**2+(y-9.5)**2<26) p.set(x,y,M.NEONO||M.RED,4,{e:.85});
    for(let k=0;k<9;k++){ const yy=24+k*5, ins=k*3; p.rect(12+ins,yy,100-ins*2,4,M.STONEL||M.STEEL,k%2?2:3); p.rect(12+ins,yy+4,100-ins*2,1,M.MDARK,1); }
    p.rect(40,69,44,3,M.GOLD,5,{e:.9}); for(const x of [4,116]){ p.rect(x,20,4,52,M.MDARK,2); for(let y=22;y<70;y+=5) p.rect(x,y,4,1,M.STEEL,3); } out.cn_subway=p.s; }
  return out; }
function startCine(){ const H=GS.hero; GS.cine={ t:0, stage:0, fade:0, flash:1 }; GS.prevSceneSb=true; setScene('brawl'); GS.on=true;
  GS.ents=[H]; H.hidden=false; H.d.x=CINE.start; H.d.y=CINE.y; H.z=0; H.d.flip=false; H.wpn=GS.pBag?'w_case':'w_hammer'; setAnim(H,'walk'); GS.items=[]; GS.cam=Math.max(0,H.d.x-W/2);
  GS.lbox=1; setAnim(H,'run'); say('', '철문 너머는 바깥이었다.', 2.0); }
function cineUpdate(dt){ const C=GS.cine, H=GS.hero; C.t+=dt; C.flash=Math.max(0,C.flash-dt*1.6);
  if(SND.on){ const t=SND.ctx.currentTime; SND.windF.frequency.setTargetAtTime(3600,t,.2); SND.windG.gain.setTargetAtTime(.16,t,.3); SND.rumG.gain.setTargetAtTime(.02,t,.3); }   // 빗소리
  const runStep=(v)=>{ const dx=v*dt; H.d.x+=dx; advGait(H,dx,true); if(H.anim!=='run') setAnim(H,'run'); C.stepT=(C.stepT||0)+dx; if(C.stepT>26){ C.stepT=0; if(SND.on) nz(SND.ctx.currentTime,.06,{f:900,q:1,g:.12}); } };   // 발소리(첨벙)
  if(C.stage===0){ runStep(CINE.spd); if(GS.pBag && !C.cap2 && H.d.x>=CINE.trash-56){ C.cap2=true; say('',tr('비. 보스의 가방을 끌어안고 뛰었다.'),2.2); }
    if(!GS.pBag && !C.toss && H.d.x>=CINE.trash-56){ C.toss={ t:0, x0:H.d.x+10, y0:H.d.y-40 }; H.wpn=null; }                  // 지나치며 던진다
    if(C.toss){ C.toss.t+=dt; if(C.toss.t>=.42 && !C.hammerIn){ C.hammerIn=true; sfx.hitK('hammer',false,0); comicT=0; comicSFX(CINE.trash-GS.cam, CINE.y-50, '클랭!'); say('','비. 장도리는 쓰레기통에 버렸다.',2.2); } }
    if(H.d.x>=CINE.ent-60 && !C.cap3){ C.cap3=true; say('','가장 가까운 지하철역 — 애틀랜틱 애비뉴.',2.4); }
    if(H.d.x>=CINE.ent-6){ C.stage=3; C.t3=0; } }
  else if(C.stage===3){ C.t3+=dt; const dx=70*dt; H.d.x+=dx; H.d.y+=46*dt; advGait(H,dx,true); C.fade=Math.min(1,C.t3/.9); if(C.t3>1.05) endCine(); }   // 계단을 달려 내려가며 어두워진다
  const tx=Math.max(0,Math.min(NBW-W, H.d.x-W*.4)); GS.cam += (tx-GS.cam)*Math.min(1,dt*5); GS.camOX=-Math.round(GS.cam); }
function endCine(){ GS.cine=null; GS.hero.d.y=SB.FLOOR; setScene('subway'); GS.on=true; endPrologue(); GS.fade=1; }
function drawCineProps(dyn){ if(!GS.cine) return; const C=GS.cine, ox=-Math.round(GS.cam);
  drawDepth=.02; quad('cn_trash', CINE.trash-10, CINE.y-26); if(C.hammerIn) quad('cn_hammer', CINE.trash-4, CINE.y-36);
  else if(C.toss){ const u=Math.min(1,C.toss.t/.42), x=C.toss.x0+(CINE.trash-C.toss.x0)*u, y=C.toss.y0+(CINE.y-30-C.toss.y0)*u-40*u*(1-u)*4; quad('cn_hammer', Math.round(x)-5, Math.round(y)-7); }   // 포물선으로 날아가는 장도리
  for(const gx of [CINE.ent-52, CINE.ent+82]){ quad('cn_globe', gx-10, CINE.y-84); dyn.push({ x:gx+ox, y:CINE.y-76, z:22, r:130, c:[.45,1,.55], i:2.2 }); }
  quad('cn_subway', CINE.ent-42, CINE.y-72); dyn.push({ x:CINE.ent+20+ox, y:CINE.y, z:4, r:80, c:[1,.85,.55], i:1.4 }); drawDepth=0; }

