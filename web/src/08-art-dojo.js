// =========================================================
// 무도장 배경(무도장 데모 전용): 밤 정원이 보이는 창호 · 흔들리는 현판 · 부서지고 흔들리는 수련 기구
// =========================================================
const DJ_POLES=[96,384];                                   // 무도장 나무 기둥(기둥 튕기기)
const DJ_WIN=[[120,220],[260,360]];
const DJ_ANDON=[200,304];                                  // 천장 종이 등 두 개                         // 창호 두 짝(화면 x)
const DJ_PROPS=[ { id:'mook', x:112, hw:12, top:52 }, { id:'brd', x:168, hw:10, top:62 }, { id:'rack', x:214, hw:14, top:46 },
                 { id:'drum', x:336, hw:13, top:40 }, { id:'bag',  x:410, hw:9,  top:70 } ];   // 확대돼도 화면 안에 들도록 가운데 쪽으로
function rotSmall(raw, deg){ const th=deg*Math.PI/180, c=Math.cos(th), s=Math.sin(th);
  const R=Math.ceil(Math.hypot(Math.max(raw.px,raw.w-raw.px), Math.max(raw.py,raw.h-raw.py)))+1, N=2*R+1, o=newSprite(N,N); o.px=R; o.py=R; o.mask=raw.mask;
  for(let oy=0;oy<N;oy++) for(let ox=0;ox<N;ox++){ const dx=ox-R, dy=oy-R, lx=dx*c+dy*s, ly=-dx*s+dy*c, sx=Math.round(raw.px+lx), sy=Math.round(raw.py+ly);
    if(sx<0||sy<0||sx>=raw.w||sy>=raw.h) continue; const i=sy*raw.w+sx; if(!raw.mat[i]) continue; const j=oy*N+ox;
    o.mat[j]=raw.mat[i]; o.tone[j]=raw.tone[i]; o.emit[j]=raw.emit[i]; o.nx[j]=raw.nx[i]; o.ny[j]=raw.ny[i]; o.rel[j]=raw.rel[i]; }
  return o; }
const DJ_SIGN_A=[-10,-7.5,-5,-2.5,0,2.5,5,7.5,10], DJ_LAMP_A=[-15,-10,-5,0,5,10,15], DJ_BAG_A=[-30,-24,-18,-12,-6,0,6,12,18,24,30];
// =========================================================
// 건널목 무도장(노을 · 가을): 노을 하늘 · 흐르는 구름 · 단풍 숲 · 지나가는 전차 · 건널목 · 전선 · 단풍 깔린 바닥
// 아틀라스를 아끼려고 하늘 · 선로 · 바닥은 가로로 반복하는 좁은 타일
// =========================================================
function genCross(out){ const rnd=mulberry(4242);
  { const p=paint(16,206), st=[[0,0],[26,1],[56,2],[86,3],[110,4],[134,5]];   // 지평선 쪽(산 위)으로 주황 · 금빛 띠가 보이게                         // 하늘 띠(16px 반복)
    for(let y=0;y<206;y++){ let k=0; for(const [y0,t] of st) if(y>=y0) k=t; const nb=st.find(([y0])=>y0>y);
      for(let x=0;x<16;x++) p.set(x,y,M.DUSK, (nb && nb[0]-y<6 && ((x+y)&1)===0) ? Math.min(5,k+1) : k, {e:.3}); }
    out.xc_sky=p.s; }
  { const p=paint(44,44); p.s.px=22; p.s.py=22;                                                         // 지는 해
    for(let dy=-21;dy<=21;dy++) for(let dx=-21;dx<=21;dx++){ const r=Math.hypot(dx,dy);
      if(r<=11) p.set(22+dx,22+dy,M.LEAFO,5,{e:1}); else if(r<=14) p.set(22+dx,22+dy,M.LEAFO,4,{e:.9}); else if(r<=21 && r>16 && ((dx+dy)&1)===0) p.set(22+dx,22+dy,M.DUSK,5,{e:.7}); }
    out.xc_sun=p.s; }
  const cloud=(w,h,seed)=>{ const r=mulberry(seed), p=paint(w,h), bl=[];                               // 뭉게구름: 오른쪽 아래(해 쪽)가 금빛, 왼쪽 위는 보라 그늘
    const n=Math.round(w/14); for(let i=0;i<n;i++){ const u=r(), cx=w*.12+u*w*.76, e=1-Math.abs(cx/w-.5); bl.push([cx, h*.3+r()*h*.45*e, h*.16+r()*h*.3*e]); }
    bl.push([w*.5,h*.62,h*.34],[w*.32,h*.68,h*.26],[w*.68,h*.68,h*.26]);
    for(let y=0;y<h;y++) for(let x=0;x<w;x++){ let inside=false, lit=-9; if(y>h*.9) continue;
      for(const [cx,cy,rr] of bl){ const d=Math.hypot(x-cx,(y-cy)*1.1); if(d<rr){ inside=true; lit=Math.max(lit,((x-cx)/rr)*.55+((y-cy)/rr)*.35+(1-d/rr)*.4); } }
      if(!inside) continue; const t = lit>.72?5: lit>.48?4: lit>.24?3: (y>h*.78?1:2); p.set(x,y,M.CLOUD,(t===3 && ((x+y)&1) && lit<.3)?2:t,{e:.2}); }
    return p.s; };
  out.xc_cloud0=cloud(200,86,11); out.xc_cloud1=cloud(140,58,23); out.xc_cloud2=cloud(96,40,37);
  { const p=paint(240,58);                                                                              // 먼 산 + 단풍 숲(노을 역광)
    for(let x=0;x<240;x++){ const h1=18+Math.round(8*Math.sin(x*.026)+5*Math.sin(x*.071+2)); for(let y=h1;y<58;y++) p.set(x,y,M.HILL, y<h1+3?2:1,{e:.05}); }
    for(let k=0;k<14;k++){ const cx=8+k*17+Math.round(rnd()*6), cy=36+Math.round(rnd()*7), rr=7+Math.round(rnd()*5), mat=rnd()<.55?M.MAPLE:M.LEAFO;
      for(let y=cy+rr-2;y<58;y++) p.set(cx,y,M.WOODD,1);
      for(let dy=-rr;dy<=rr;dy++) for(let dx=-rr-2;dx<=rr+2;dx++){ if(dx*dx/((rr+2)*(rr+2))+dy*dy/(rr*rr)>1) continue; const x=cx+dx, y=cy+dy; if(x<0||x>=240||y<0||y>=58) continue;
        p.set(x,y,mat, (dx>2&&dy<0)?3:(((dx+dy)&1)?1:2),{e:.08}); } }
    out.xc_hills=p.s; }
  { const p=paint(96,18);                                                                               // 선로(96px 반복): 자갈 · 침목 · 레일
    for(let y=0;y<18;y++) for(let x=0;x<96;x++) p.set(x,y,M.STONE,((x*7+y*13)%5===0)?2:1);
    for(let x=0;x<96;x+=12) p.rect(x,7,8,4,M.WOODD,2); p.rect(0,5,96,1,M.STEEL,5,{e:.25}); p.rect(0,6,96,1,M.STEEL,2); p.rect(0,0,96,2,M.HILL,1);
    out.xc_track=p.s; }
  // 전차(한 칸 208×88, 위 16줄은 팬터그래프 자리): 둥근 운전석 · 큰 앞유리 · 불 켜진 행선판 · 금색 띠 · 투명한 창(뒤 하늘과 해가 비친다) · 승객 실루엣 · 손잡이
  const car=(lower,lowK,stripe,doorM)=>{ const C=XC_CAR, W=C.W, H=C.H, p=paint(W,H), r2=mulberry(lower*7+3), inWin=(x,y)=>y>=C.wy0&&y<=C.wy1&&C.wins.some(([a,b])=>x>=a&&x<=b);
    for(let y=18;y<72;y++) for(let x=2;x<W;x++){ const nose=x>=190 ? Math.max(0, x-198) : 0;                                   // 운전석 쪽은 위아래 모서리를 둥글게
      if(y<18+Math.max(0,4-x+2) || y<18+Math.floor(nose*nose/10) || y>71-Math.floor(nose*nose/14)) continue;
      if(inWin(x,y)) continue;
      if(y<24) p.set(x,y,M.TRAMC,y===18?5:3,{ny:.6,e:y===18?.28:0});                                                             // 지붕(노을 하이라이트 한 줄)
      else if(y<48) p.set(x,y,M.TRAMC,4,{ny:.3,e:.06});                                                                           // 크림
      else if(y===48) p.set(x,y,stripe,5,{e:.18});                                                                                // 금색 띠
      else if(y<68) p.set(x,y,lower,lowK,{ny:.3});                                                                                 // 아래 몸통
      else p.set(x,y,M.MDARK,2); }                                                                                                 // 치마
    for(const [a,b] of C.wins){ for(let x=a-1;x<=b+1;x++){ p.set(x,C.wy0-1,M.TRAMC,2); p.set(x,C.wy1+1,M.TRAMC,2); } for(let y=C.wy0-1;y<=C.wy1+1;y++){ p.set(a-1,y,M.TRAMC,2); p.set(b+1,y,M.TRAMC,2); }
      p.set(a+2,C.wy0+2,M.GLASS,4,{e:.35}); p.set(a+3,C.wy0+1,M.GLASS,4,{e:.35});                                                // 유리 반사 한 점
      if(b-a<10) continue; for(let x=a+3;x<b;x+=6){ p.set(x,C.wy0,M.MDARK,1); p.set(x,C.wy0+1,M.MDARK,1); p.set(x-1,C.wy0+2,M.MDARK,1); p.set(x+1,C.wy0+2,M.MDARK,1); }   // 손잡이 고리
      const kind=Math.floor(r2()*4), hx=a+3+Math.floor(r2()*(b-a-8));                                                             // 승객: 앉은 둘 · 선 사람 · 책가방 학생 · 빈 창
      if(kind===0){ for(const q of [hx,hx+6]){ if(q+4>b) continue; p.rect(q,C.wy1-5,5,6,M.MDARK,1); p.rect(q+1,C.wy1-8,3,3,M.MDARK,1); } }
      else if(kind===1){ p.rect(hx,C.wy0+5,4,C.wy1-C.wy0-4,M.MDARK,1); p.rect(hx,C.wy0+2,4,3,M.MDARK,1); p.set(hx+3,C.wy0+1,M.MDARK,1); p.set(hx+3,C.wy0,M.MDARK,1); }
      else if(kind===2){ p.rect(hx,C.wy0+6,4,C.wy1-C.wy0-5,M.MDARK,1); p.rect(hx,C.wy0+3,4,3,M.MDARK,1); p.rect(hx-2,C.wy0+7,2,5,M.WOODD,2); } }
    for(const [a,b] of C.doors){ for(let y=26;y<68;y++) for(let x=a;x<=b;x++){ if(inWin(x,y)) continue; p.set(x,y,doorM,(x===a||x===b)?1:2,{ny:.3}); } p.rect(Math.round((a+b)/2),40,1,26,M.MDARK,1); }
    p.rect(192,19,14,5,M.TRAMC,5,{e:.9}); for(const x of [194,196,199,201,203]) p.set(x,21,M.INK,1);                            // 행선판(불 켜짐)
    p.rect(200,52,5,3,M.FRAME,5,{e:1}); p.rect(193,52,2,2,M.RED,4,{e:.7});                                                       // 전조등 · 후미등
    { const cx=C.panto; for(let k=0;k<=8;k++){ p.set(cx-k,17-k,M.MDARK,1); p.set(cx+k,17-k,M.MDARK,1); p.set(cx-8+k,9-k,M.MDARK,1); p.set(cx+8-k,9-k,M.MDARK,1); } p.rect(cx-7,0,15,1,M.STEEL,4); p.rect(cx-3,17,7,1,M.MDARK,2); }   // 팬터그래프(가선에 닿음)
    p.rect(6,70,W-12,9,M.MDARK,1); for(const bx of [52,78,112,138]) p.rect(bx,71,16,6,M.STEEL,1); for(let x=8;x<W-8;x+=6) p.set(x,78,M.MDARK,2);   // 하부: 어두운 바닥틀 · 기기 상자(차체와 레일 사이가 비어 보이지 않게)
    for(const bx of C.bog){ p.rect(bx-14,70,28,8,M.MDARK,1); p.rect(bx-3,73,6,2,M.STEEL,3); }                                     // 대차
    p.s.px=W/2; p.s.py=H; return p.s; };
  out.xc_carA=car(M.TRAMG,3,M.GOLD,M.TRAMG); out.xc_carB=car(M.MAPLE,2,M.GOLD,M.MAPLE);
  for(let k=0;k<4;k++){ const p=paint(11,11); p.s.px=5; p.s.py=5; const th=k*Math.PI/8;                                         // 바퀴(4프레임 회전)
    for(let dy=-5;dy<=5;dy++) for(let dx=-5;dx<=5;dx++){ const r=Math.hypot(dx,dy); if(r<=5.2 && r>3.6) p.set(5+dx,5+dy,M.MDARK,r>4.6?1:2); else if(r<=1.4) p.set(5+dx,5+dy,M.STEEL,3); }
    for(let q=0;q<4;q++){ const a=th+q*Math.PI/2; for(let t=1.6;t<3.8;t+=.6) p.set(5+Math.round(Math.cos(a)*t),5+Math.round(Math.sin(a)*t),M.MDARK,2); }
    out['xc_wh@'+k]=p.s; }
  { const p=paint(8,46); p.s.px=4; p.s.py=46; for(let y=0;y<46;y++) for(let x=0;x<8;x++) p.set(x,y,M.MDARK,(y%4<2)?1:2); out.xc_bel=p.s; }   // 연결 주름막
  { const p=paint(480,20); for(let x=0;x<480;x++){ const sg=Math.round(5*Math.sin(Math.PI*((x+444)%204)/204)); p.set(x,1+sg,M.MDARK,1); p.set(x,17,M.STEEL,2); if(x%24===0) for(let y=2+sg;y<17;y++) p.set(x,y,M.MDARK,1); }   // 가선: 조가선 · 드로퍼 · 전차선
    out.xc_cat=p.s; }
  { const p=paint(14,108); p.s.px=4; p.s.py=108; p.rect(3,0,3,108,M.MDARK,1); p.rect(3,18,11,2,M.MDARK,2); p.rect(12,16,1,6,M.MDARK,1); out.xc_cpole=p.s; }   // 가선 기둥(팔이 전차선을 잡는다)
  for(const [k,e] of [[1,.1],[2,.38],[3,.72]]){ const p=paint(22,8); p.s.px=11; p.s.py=0; for(let y=0;y<8;y++) for(let x=0;x<14;x++) p.set(x+7-y,y,M.LEAFO,y<2||y>5?4:5,{e:e*(y<2||y>5?.6:1)}); out['xc_patch@'+k]=p.s; }   // 바닥 빛 조각(창 모양 · 비스듬히)
  { const p=paint(44,124), cx=22; p.s.px=cx; p.s.py=124;                                              // 건널목 기둥: X자 표지 · 적색등 두 개 · 노랑 검정 줄무늬
    p.rect(cx-1,8,3,116,M.STEEL,(q,j)=>q===0?4:2,{r:.3});
    for(let y=92;y<124;y++){ const band=Math.floor((y-92)/6)%2; p.rect(cx-2,y,5,1,band?M.INK:M.TAXI,band?1:4); }
    for(let t=-16;t<=16;t++) for(const sg of [1,-1]){ const x=cx+t, y=22+sg*t*.62, band=Math.floor((t+20)/5)%2; for(let w=-1;w<=1;w++) p.set(Math.round(x),Math.round(y+w),band?M.INK:M.TAXI,band?1:5); }
    for(const dx of [-9,9]){ for(let dy=-3;dy<=3;dy++) for(let ddx=-3;ddx<=3;ddx++) if(ddx*ddx+dy*dy<=9) p.set(cx+dx+ddx,46+dy,M.MDARK,ddx*ddx+dy*dy<4?2:1); p.rect(cx+dx-4,42,9,1,M.MDARK,2); }
    p.rect(cx-10,46,20,1,M.MDARK,1);
    out.xc_post=p.s; }
  { const p=paint(7,7); p.s.px=3; p.s.py=3; for(let dy=-3;dy<=3;dy++) for(let dx=-3;dx<=3;dx++){ const r=dx*dx+dy*dy; if(r<=9) p.set(3+dx,3+dy,M.RED,r<3?5:4,{e:1}); } out.xc_lamp=p.s; }
  { const p=paint(480,44);                                                                              // 전선 · 전신주
    for(let x=0;x<480;x++){ const s1=Math.round(6*Math.sin(Math.PI*x/480)), s2=Math.round(4*Math.sin(Math.PI*((x+120)%240)/240)); p.set(x,8+s1,M.MDARK,1); p.set(x,14+s1,M.MDARK,1); p.set(x,30+s2,M.MDARK,1); }
    for(const px of [36,444]){ p.rect(px-1,0,3,44,M.MDARK,1); p.rect(px-8,6,17,2,M.MDARK,2); }
    out.xc_wires=p.s; }
  { const p=paint(96,48);                                                                               // 바닥(96px 반복): 노을빛 콘크리트 · 노란 선 · 떨어진 단풍
    for(let y=0;y<48;y++) for(let x=0;x<96;x++) p.set(x,y,M.ROADS, y<2?5:((x*5+y*11)%13===0)?3:(y<14?4:3),{ny:.8});
    p.rect(0,0,96,1,M.TAXI,4); p.rect(0,2,1,46,M.ROADS,1); p.rect(48,2,1,46,M.ROADS,1);
    for(let k=0;k<26;k++){ const x=2+Math.round(rnd()*92), y=4+Math.round(rnd()*40), mat=rnd()<.55?M.MAPLE:M.LEAFO, t=3+Math.floor(rnd()*3); p.set(x,y,mat,t); p.set(x+1,y,mat,t); p.set(x,y+1,mat,t-1); if(rnd()<.5) p.set(x-1,y,mat,t-1); }
    out.xc_floor=p.s; }
  const leafRaw=(mat,sh)=>{ const p=paint(7,7); p.s.px=3; p.s.py=3;                                     // 단풍잎: 단풍 · 둥근 잎 · 옆모습(펄럭임)
    const pts = sh===0 ? [[0,-2],[-1,-1],[0,-1],[1,-1],[-2,0],[-1,0],[0,0],[1,0],[2,0],[-1,1],[0,1],[1,1],[0,2]] : sh===1 ? [[-1,-1],[0,-1],[1,-1],[-1,0],[0,0],[1,0],[0,1],[0,2]] : [[-2,0],[-1,0],[0,0],[1,0],[2,0],[0,1]];
    for(const [dx,dy] of pts) p.set(3+dx,3+dy,mat,((dx+dy)&1)?3:4); p.set(3,3,mat,5); return p.s; };
  for(const [ci,mat] of [[0,M.MAPLE],[1,M.LEAFO]]) for(let sh=0;sh<3;sh++){ const raw=leafRaw(mat,sh); for(let r=0;r<4;r++) out[`xc_leaf${ci}${sh}@${r}`]=r?rotSmall(raw,r*45):raw; }
}
function genDojo(out){
  const rnd=mulberry(7311);
  // ── 바깥: 밤 정원
  { const p=paint(SB.W,SB.H);
    for(let y=0;y<SB.H;y++) for(let x=0;x<SB.W;x++) p.set(x,y,M.SKYD, y<110?1:y<150?2:3);
    for(let dy=-7;dy<=7;dy++) for(let dx=-7;dx<=7;dx++) if(dx*dx+dy*dy<=49) p.set(318+dx,128+dy,M.MOON,dx*dx+dy*dy<22?5:4,{e:.9});
    for(let x=0;x<SB.W;x++){ const hg=156+Math.round(7*Math.sin(x*.021)+4*Math.sin(x*.063+1)); for(let y=hg;y<178;y++) p.set(x,y,M.PFAR,1); }
    for(let x=0;x<SB.W;x++){ if(x%6<3) p.set(x,176,M.MDARK,1); p.set(x,177,M.WOODD,1); p.set(x,178,M.MDARK,2); for(let y=179;y<197;y++) p.set(x,y,M.MDARK,(x%14===0||y===188)?1:2); }
    for(let k=0;k<24;k++){ const bx=8+k*20+((k*7)%9); for(let y=146;y<197;y++) p.set(bx,y,M.PINE,y%9===0?1:2); for(let j=0;j<4;j++){ const yy=148+j*11+(k%5); for(let q=-4;q<=4;q++) p.set(bx+q,yy+Math.floor(Math.abs(q)/2),M.LEAF,2); } }
    for(const lx of [150,300]){ p.rect(lx-3,184,6,13,M.STONE,3); p.rect(lx-5,180,10,4,M.STONE,2); p.rect(lx-2,185,4,4,M.GOLD,5,{e:1}); }
    p.rect(0,197,SB.W,SB.H-197,M.MDARK,1); out.dj_out=p.s; }
  // ── 방: 천장 들보 · 회벽 · 창호 · 징두리 판벽 · 기둥 · 족자 · 벽걸이 무기
  { const Y0=80, p=paint(SB.W,222-Y0), Y=v=>v-Y0;
    p.rect(0,0,SB.W,Y(100),M.WOODD,(q,j)=>j%7===0?1:(q%40<3?1:2),{ny:.4});                       // 천장 들보
    p.rect(0,Y(100),SB.W,Y(150)-Y(100),M.CANVAS,(q,j)=>(q*7+j*13)%29===0?3:4);                   // 회벽
    p.rect(0,Y(146),SB.W,4,M.WOOD,(q,j)=>j===0?4:2,{ny:.5});                                       // 인방(가로 나무)
    p.rect(0,Y(196),SB.W,Y(222)-Y(196),M.WOODD,(q,j)=>j===0?4:(q%12===0?1:2));                   // 징두리 판벽
    p.rect(0,Y(150),SB.W,Y(196)-Y(150),M.CANVAS,(q,j)=>3);
    for(const [a,b] of DJ_WIN){ p.rect(a-3,Y(150),b-a+6,Y(198)-Y(150),M.WOODD,2);                 // 창호: 살 · 한지 · 열린 칸
      for(let y=Y(152);y<Y(196);y++) for(let x=a;x<b;x++){ const gx=(x-a)%10===0, gy=(y-Y(152))%9===0, open=(a===120 ? x>=a+56 : x<a+38);
        if(gx||gy) p.set(x,y,M.WOOD,gx&&gy?2:3); else if(open) p.s.mat[y*SB.W+x]=0; else p.set(x,y,M.CANVAS,5,{e:.18}); } }
    for(const x of [0,SB.W-6]) p.rect(x,0,6,Y(222),M.WOOD,(q,j)=>q===0?4:q===5?1:3);
    for(const x of DJ_POLES) p.rect(x-4,0,8,Y(222),M.WOOD,(q,j)=>q===0?5:q===7?1:(j%30===0?2:3),{r:.4});   // 나무 기둥
    p.rect(22,Y(104),24,Y(144)-Y(104),M.CANVAS,5); p.rect(20,Y(102),28,2,M.WOODD,2); p.rect(20,Y(144),28,2,M.WOODD,2);   // 족자
    for(let k=0;k<5;k++){ const x0=30+((k*3)%4)-2; for(let y=Y(108)+k*7;y<Y(108)+k*7+5;y++){ p.set(x0+(y%3),y,M.INK,1); p.set(x0+1+(y%3),y,M.INK,1); } p.set(38,Y(110)+k*7,M.INK,1); p.set(39,Y(111)+k*7,M.INK,1); }
    p.rect(30,Y(139),6,3,M.RED,3);                                                                 // 낙관
    for(const [x,len] of [[404,40],[414,44],[424,38],[434,42],[444,40]]){ for(let y=Y(104);y<Y(104)+len;y++) p.set(x,y,M.WOOD,(y%11===0)?2:3); p.rect(x-1,Y(104)-3,3,3,M.STEEL,4); }   // 벽걸이 봉 · 창
    p.rect(398,Y(118),52,2,M.WOODD,2); p.rect(398,Y(136),52,2,M.WOODD,2);
    out.dj_room=p.s; }
  // ── 마루
  { const p=paint(SB.W,SB.H-222);
    for(let y=0;y<SB.H-222;y++) for(let x=0;x<SB.W;x++){ const plank=Math.floor(y/6), seam=y%6===0, joint=(x+plank*53)%96===0; p.set(x,y,M.WOOD, seam?1:joint?1:(plank%2?3:4),{ny:.8}); }
    p.rect(0,0,SB.W,1,M.WOODD,4); out.dj_floor=p.s; }
  // ── 현판(두 줄에 매달림): 武 · MAKCHA DOJO · 武
  { const p=paint(96,34), W=96; p.s.px=48; p.s.py=0;
    p.line(14,0,14,9,M.CURT,2); p.line(81,0,81,9,M.CURT,2);
    p.rect(0,9,W,25,M.WOODD,(q,j)=>q===0||j===0?3:(q===W-1||j===24)?0:1); p.rect(3,12,W-6,19,M.WOOD,(q,j)=>((q+j*3)%17===0)?1:2);
    const WU=["......#.#..","#####.#..#.","......#....","####.######","..#...#....","..#.#.#....","..#.#..#...","..#.##.#...","..#.#...#.#",".##.#...#.#","#######..##"];
    for(const ox of [6,W-17]) WU.forEach((r,j)=>{ for(let i=0;i<r.length;i++) if(r[i]==='#') p.set(ox+i,15+j,M.GOLD,4,{e:.18}); });
    signText(p,(W-35)>>1,13,'MAKCHA',M.GOLD,4,{e:.18}); signText(p,(W-23)>>1,22,'DOJO',M.GOLD,4,{e:.18});
    DJ_SIGN_A.forEach((a,k)=>out['dj_sign@'+k]=rotSmall(p.s,a)); }
  // ── 종이 등롱
  { const p=paint(12,24); p.s.px=6; p.s.py=0; p.line(6,0,6,5,M.CURT,1); p.rect(4,5,4,2,M.WOODD,2);
    for(let y=7;y<21;y++){ const hw=Math.round(5*Math.sin((y-6)/15*Math.PI))+1; for(let x=6-hw;x<6+hw;x++) p.set(x,y,y%4===0?M.GOLD:M.RED,y%4===0?4:5,{e:.75}); }
    p.rect(4,21,4,2,M.WOODD,2); DJ_LAMP_A.forEach((a,k)=>out['dj_lamp@'+k]=rotSmall(p.s,a)); }
  // ── 샌드백(사슬)
  { const p=paint(16,60); p.s.px=8; p.s.py=0; for(let y=0;y<22;y+=3){ p.set(8,y,M.STEEL,3); p.set(7,y+1,M.STEEL,2); p.set(9,y+2,M.STEEL,2); }
    p.rect(3,22,10,3,M.MDARK,2); for(let y=25;y<58;y++) for(let x=2;x<14;x++) p.set(x,y,M.COAT,x===2?1:x===13?1:(y%10===0?4:(x<6?3:2)),{r:.5});
    for(const yy of [32,48]) p.rect(2,yy,12,2,M.CANVAS,4); p.rect(3,58,10,2,M.COAT,1); DJ_BAG_A.forEach((a,k)=>out['dj_bag@'+k]=rotSmall(p.s,a)); }
  // ── 목인장
  { const p=paint(28,54); p.s.px=14; p.s.py=53;
    for(let y=4;y<44;y++) for(let x=8;x<20;x++) p.set(x,y,M.WOOD,x===8?2:x===19?1:(x<12?4:3),{r:.5}); p.rect(9,2,10,2,M.WOOD,3);
    for(const [y,dir] of [[12,-1],[16,1],[26,1]]){ for(let q=0;q<9;q++) p.set(dir>0?20+q:7-q, y+(q>>2), M.WOODD, 3); }
    p.line(14,40,24,46,M.WOODD,2); p.rect(4,44,20,3,M.WOODD,2); p.rect(2,47,24,7,M.WOODD,(q,j)=>j===0?3:1);
    out.dj_mook=p.s; }
  // ── 송판 받침대(멀쩡 · 부러짐)
  for(const broken of [0,1]){ const p=paint(26,64); p.s.px=13; p.s.py=63;
    p.line(5,63,9,26,M.STEEL,2); p.line(21,63,17,26,M.STEEL,2); p.rect(7,28,12,2,M.STEEL,3);
    if(!broken){ for(let k=0;k<3;k++) p.rect(3,14+k*4,20,3,M.WOOD,(q,j)=>j===0?4:3); }
    else { for(let k=0;k<3;k++){ for(let q=0;q<9;q++) p.set(3+q,14+k*4+Math.floor(q/3),M.WOOD,3); for(let q=0;q<9;q++) p.set(14+q,16+k*4-Math.floor(q/3),M.WOOD,3); }
      for(let k=0;k<6;k++) p.set(12+(k%2),14+k*2,M.CANVAS,5); }
    out[broken?'dj_brd_b':'dj_brd']=p.s; }
  // ── 병기대(봉 네 자루 · 쓰러짐)
  for(const broken of [0,1]){ const p=paint(40,50); p.s.px=20; p.s.py=49;
    if(!broken){ p.rect(6,44,28,5,M.WOODD,2); p.rect(6,18,28,3,M.WOODD,2); for(const x of [10,16,22,28]) for(let y=2;y<44;y++) p.set(x,y,M.WOOD,(y%9===0)?2:3); }
    else { p.rect(2,44,28,5,M.WOODD,1); p.line(4,46,22,30,M.WOODD,2); for(const [x0,y0,x1,y1] of [[0,48,38,42],[2,46,30,34],[8,49,39,47],[12,40,26,49]]) p.line(x0,y0,x1,y1,M.WOOD,3); }
    out[broken?'dj_rack_b':'dj_rack']=p.s; }
  // ── 큰 북(받침대)
  { const p=paint(30,42); p.s.px=15; p.s.py=41;
    p.line(4,41,22,22,M.WOODD,2); p.line(26,41,8,22,M.WOODD,2);
    for(let y=4;y<26;y++){ const hw=11+Math.round(2*Math.sin((y-4)/22*Math.PI)); for(let x=15-hw;x<15+hw;x++) p.set(x,y,M.RED,(x===15-hw||x===15+hw-1)?1:(y%11===0?2:3),{r:.4}); }
    for(let y=6;y<25;y+=3){ p.set(4,y,M.GOLD,4); p.set(25,y,M.GOLD,4); } p.rect(4,3,22,2,M.CANVAS,4); p.rect(4,25,22,2,M.CANVAS,3);
    out.dj_drum=p.s; }
  // ── 나무 천장(들보 위): 널판 · 서까래
  { const p=paint(SB.W,80); for(let y=0;y<80;y++) for(let x=0;x<SB.W;x++){ const raf=x%48<5, seam=y%10===0; p.set(x,y,raf?M.WOODD:M.WOOD, raf?(x%48===0?4:2):(seam?2:(y>66?4:3)),{ny:.3}); }
    p.rect(0,74,SB.W,6,M.WOODD,(q,j)=>j===0?3:1); out.dj_ceil=p.s; }
  // ── 천장 종이 등(안돈): 나무 틀 · 빛나는 한지
  { const p=paint(24,22); p.s.px=12; p.s.py=0; p.line(12,0,12,5,M.CURT,1); p.rect(2,5,20,2,M.WOODD,2);
    for(let y=7;y<20;y++) for(let x=2;x<22;x++){ const fr=x===2||x===21||y===19||(x-2)%5===0; p.set(x,y,fr?M.WOODD:M.CANVAS,fr?2:5,fr?{}:{e:.9}); }
    p.rect(2,19,20,2,M.WOODD,2); out.dj_andon=p.s; }
  // ── 수련용 고리(줄)
  { const p=paint(12,46); p.s.px=6; p.s.py=0; p.line(6,0,6,34,M.CURT,2); for(let a=0;a<24;a++){ const t=a/24*Math.PI*2; p.set(6+Math.round(Math.cos(t)*5), 39+Math.round(Math.sin(t)*5), M.WOOD,3); } out.dj_ring=p.s; }
  // ── 창 밖을 지나가는 사람(실루엣 · 2프레임) · 우산
  for(const um of [0,1]) for(const fr of [0,1]){ const p=paint(16,30); p.s.px=8; p.s.py=29;
    p.rect(6,2,5,5,M.MDARK,1); p.rect(5,7,7,11,M.MDARK,1); p.rect(4,9,2,7,M.MDARK,1); p.rect(11,9,2,7,M.MDARK,1);
    if(fr===0){ p.line(7,18,5,29,M.MDARK,1); p.line(9,18,11,29,M.MDARK,1); } else { p.line(7,18,7,29,M.MDARK,1); p.line(9,18,9,29,M.MDARK,1); }
    if(um){ p.line(12,8,12,0,M.MDARK,1); for(let q=-7;q<=7;q++) p.set(12+q,0+Math.floor(Math.abs(q)/3),M.MDARK,1); }
    out[`dj_walk${um}${fr}`]=p.s; }
}
// 상태 · 흔들림(스프링) · 충돌 · 지나가는 사람
const DJ={ on:true };
function djReset(){ Object.assign(DJ,{ sign:{a:0,v:0}, lamps:[{a:0,v:0},{a:0,v:0}], bag:{a:0,v:0}, mook:0, drum:0, brd:false, rack:false, walkers:DJ.walkers||[], wt:DJ.wt??2 }); }
djReset();
function djJolt(p){ if(!DJ.sign) djReset(); const r=()=>Math.random()<.5?-1:1; DJ.sign.v+=r()*(.22+p*.28); DJ.lamps.forEach(l=>l.v+=r()*(.4+p*.5)); }
function djTick(dt){ if(!DJ.sign) djReset(); xcEnsure(); if(DJ.bg==='cross'){ xcTick(dt); return; }   // 건널목: 수련 기구 · 행인 없음
  const spring=(s,k,c)=>{ s.v+=(-k*s.a-c*s.v)*dt; s.a+=s.v*dt; };
  spring(DJ.sign,26,2.4); DJ.lamps.forEach(l=>spring(l,18,1.6)); spring(DJ.bag,7,.55); DJ.mook=Math.max(0,DJ.mook-dt); DJ.drum=Math.max(0,DJ.drum-dt);
  DJ.wt-=dt; if(DJ.wt<=0){ const left=Math.random()<.5; DJ.walkers.push({ x:left?96:384, v:(left?1:-1)*(9+Math.random()*7), um:Math.random()<.35?1:0, t:0 }); DJ.wt=4+Math.random()*6; }
  DJ.walkers.forEach(w=>{ w.x+=w.v*dt; w.t+=dt; }); DJ.walkers=DJ.walkers.filter(w=>w.x>80&&w.x<400);
  const D=GS.ents.find(a=>a.e&&a.dojo); if(!D||!D.jug){ if(D) D._djHit=null; return; }
  const J=D.jug, sp=Math.abs(J.vx); D._djHit=D._djHit||{}; if(sp<90) return;
  for(const P of DJ_PROPS){ if(D._djHit[P.id] || Math.abs(D.d.x-P.x)>P.hw || J.h>P.top) continue; D._djHit[P.id]=1; const f=Math.sign(J.vx)||1, y=D.d.y-20-J.h;
    if(P.id==='bag'){ DJ.bag.v+=f*Math.min(3.2,sp/90); comicSFX(P.x, y-20, 'THUD!'); }
    else if(P.id==='mook'){ DJ.mook=.45; HITFX.push({ k:'debris', x:P.x, y:D.d.y-24, t:0, life:.7, parts:Array.from({length:6},()=>({ vx:(Math.random()*2-1)*70, vy:60+Math.random()*80, s:1 })) }); comicSFX(P.x, y-16, 'CLACK!'); J.vx*=.55; }
    else if(P.id==='brd' && !DJ.brd){ DJ.brd=true; HITFX.push({ k:'debris', x:P.x, y:D.d.y-42, t:0, life:.9, parts:Array.from({length:12},()=>({ vx:(Math.random()*2-1)*120, vy:40+Math.random()*120, s:Math.random()<.5?1:2 })) }); comicSFX(P.x, y-24, 'CRACK!'); J.vx*=.8; }
    else if(P.id==='drum'){ DJ.drum=.55; comicSFX(P.x, y-20, 'BOOM!'); shakeAmp=Math.max(shakeAmp||0,2.2); }
    else if(P.id==='rack' && !DJ.rack){ DJ.rack=true; HITFX.push({ k:'debris', x:P.x, y:D.d.y-20, t:0, life:.8, parts:Array.from({length:7},()=>({ vx:(Math.random()*2-1)*90, vy:50+Math.random()*70, s:2 })) }); comicSFX(P.x, y-16, 'CLATTER!'); J.vx*=.7; }
    try{ sfx.clack(); }catch(e){} djJolt(.8); } }
const djIdx=(arr,a)=>{ let k=0, b=1e9; arr.forEach((v,i)=>{ const d=Math.abs(v-a); if(d<b){ b=d; k=i; } }); return k; };
const XC_SUN=[332,152], XC_TY=210, XC_CW=123, XC_CS=[36,240,444];   // 해 위치 · 전차 바닥 기준선(바퀴가 레일 위) · 전차선 높이 · 가선 기둥
const XC_CAR={ W:208, H:88, wy0:28, wy1:42, wins:[[12,28],[32,48],[52,68],[96,112],[116,132],[136,152],[74,84],[158,168],[192,199],[200,206]], doors:[[72,86],[156,170]], panto:104, bog:[30,178] };
function xcCars(X){ const T=X.tr; if(!T) return []; const W=XC_CAR.W; return [0,1].map(k=>{ const cx=T.x-T.dir*k*(W+6), lead=k===0, fl=lead ? T.dir<0 : T.dir>0; return { cx, fl, lead }; }); }   // 앞칸은 운전석이 가는 쪽, 뒤칸은 반대
const xcSpan=(c,a,b)=>{ const W=XC_CAR.W; return c.fl ? [c.cx+W/2-b, c.cx+W/2-a] : [c.cx-W/2+a, c.cx-W/2+b]; };
function xcWinList(X){ const out=[]; for(const c of xcCars(X)) for(const [a,b] of XC_CAR.wins){ const [x0,x1]=xcSpan(c,a,b); out.push({ x:(x0+x1)/2, x0, x1, y:XC_TY-XC_CAR.H+(XC_CAR.wy0+XC_CAR.wy1)/2 }); } return out; }
function xcSunK(X){ const T=X.tr; if(!T || T.warn>0) return 1; const sx=XC_SUN[0];   // 해가 차체에 가리면 어둡고, 창이 지나가면 밝다
  for(const c of xcCars(X)){ const W=XC_CAR.W; if(sx<c.cx-W/2 || sx>c.cx+W/2) continue; return xcWinList({tr:T}).some(w=>sx>=w.x0-1 && sx<=w.x1+1) ? 1 : .35; } return 1; }
function xcHead(X){ const T=X.tr; return { x:T.x+T.dir*(XC_CAR.W/2-6), y:XC_TY-XC_CAR.H+53 }; }
function xcEnsure(){ if(DJ.bg==null) DJ.bg=(typeof OPT!=='undefined'&&OPT.djbg)||'dojo'; if(!DJ.xc) xcReset(); }
function xcReset(){ const X=DJ.xc={ tr:null, nextT:4+Math.random()*4, bell:false, bellT:0, leaves:[], fall:[], fallT:0, prev:new Map() };
  for(let k=0;k<72;k++) X.leaves.push(xcLeaf(14+Math.random()*(SB.W-28), k%5<3 ? 223+Math.random()*12 : 236+Math.random()*26)); }   // 60%는 사람이 서는 줄(발밑) 근처에
function xcLeaf(x,gy){ return { x, gy, h:0, vx:0, vh:0, ph:Math.random()*6.28, rot:Math.floor(Math.random()*4), vr:0, c:Math.random()<.55?0:1, s:Math.floor(Math.random()*3) }; }
const xcKey=L=>`xc_leaf${L.c}${L.s}@${Math.floor(L.rot)&3}`;
function xcKick(x,gy,pw,rad){ const X=DJ.xc; if(!X) return; for(const L of X.leaves){ if(L.h>0) continue; const dx=L.x-x; if(Math.abs(dx)>rad || Math.abs(L.gy-gy)>26) continue;   // 발밑 · 충격 자리의 잎을 띄운다
  const k=1-Math.abs(dx)/rad; L.vh=(50+Math.random()*90)*pw*(.5+k); L.vx=(Math.sign(dx)||(Math.random()<.5?-1:1))*(30+Math.random()*80)*pw; L.vr=(Math.random()-.5)*14; L.h=.5; } }
function xcSpark(x){ const X=DJ.xc; if(!X) return; X.spk=.14; X.spkX=x;   // 팬터그래프 불꽃: 청백색 섬광 · 튀는 불티 · 지직
  HITFX.push({ k:'xcspark', x, y:XC_CW, t:0, life:.2, parts:Array.from({length:9},()=>({ a:Math.random()*Math.PI*2, l:6+Math.random()*14 })) });
  sparks.push({ x, y:XC_CW, age:0 }); skNoise(.09,4200,.07); skTone(1400,260,.08,'sawtooth',.02); }
const xcOn=()=>scene==='subway' && GS.demo && DJ.on && DJ.bg==='cross';
function xcTick(dt){ xcEnsure(); const X=DJ.xc;
  X.nextT-=dt; if(!X.tr && X.nextT<=0){ const dir=Math.random()<.5?1:-1; X.tr={ dir, x:dir>0?-520:SB.W+520, v:260+Math.random()*60, warn:2.0, kind:Math.random()<.7?'A':'B', dist:0, pp:null }; X.bell=true; }   // 14~24초마다 전차 · 오기 2초 전부터 경보
  if(X.tr){ const T=X.tr; if(T.warn>0) T.warn-=dt; else { const mv=T.v*dt; T.x+=T.dir*mv; T.dist+=mv; } if(T.warn<=0 && Math.random()<dt*4) skNoise(.25,90,.06);
    if(T.warn<=0){ const cars=xcCars(X), pp=cars.map(c=>c.cx);
      if(T.pp) pp.forEach((x,i)=>{ const x0=T.pp[i]; for(const sx of XC_CS) if((sx-x0)*(sx-x)<=0 && x0!==x) xcSpark(sx);   // 팬터그래프가 가선 기둥을 지날 때 불꽃
        for(const bg of [-74,74]){ const a=x0+bg, b=x+bg; if(Math.floor(a/120)!==Math.floor(b/120) && a>-20 && a<SB.W+20){ skNoise(.035,1500,.05); setTimeout(()=>skNoise(.035,1200,.045),70); } } });   // 레일 이음매: 덜컹-덜컹
      T.pp=pp; if(cars.some(c=>c.cx>-120&&c.cx<SB.W+120) && Math.random()<dt*.5) xcSpark(cars[0].cx);   // 가끔 작은 불꽃
      if(Math.abs(T.x-SB.W/2)<SB.W/2+260){ for(const L of X.leaves){ if(L.h<=0){ if(Math.random()<dt*1.7*(L.gy<240?1:.45)){ L.vh=40+Math.random()*80; L.vx=T.dir*(80+Math.random()*130); L.vr=(Math.random()-.5)*16; L.h=.5; } } else L.vx+=T.dir*120*dt; }   // 전차 바람: 바닥 단풍이 가는 쪽으로 쓸려 날린다
        for(const F of X.fall) F.x+=T.dir*80*dt; } }
    if((T.dir>0&&T.x>SB.W+420)||(T.dir<0&&T.x<-420)){ X.tr=null; X.nextT=14+Math.random()*10; X.bellT=.8; } }
  if(X.bellT>0){ X.bellT-=dt; if(X.bellT<=0) X.bell=false; }
  if(X.spk>0) X.spk=Math.max(0,X.spk-dt);
  if(X.bell){ X.bk=(X.bk||0)+dt; if(X.bk>=.42){ X.bk=0; X.bt=!X.bt; skTone(X.bt?760:640,X.bt?760:640,.16,'square',.022); } }   // 땡땡
  X.fallT-=dt; if(X.fallT<=0 && X.fall.length<22){ X.fallT=.35+Math.random()*.6; X.fall.push({ ...xcLeaf(Math.random()*SB.W, Math.random()<.6 ? 223+Math.random()*12 : 236+Math.random()*26), y:40+Math.random()*80, vy:16+Math.random()*14, sw:8+Math.random()*10 }); }   // 떨어지는 단풍
  for(const F of X.fall){ F.ph+=dt*3; F.y+=F.vy*dt; F.x+=Math.sin(F.ph)*F.sw*dt+10*dt; F.rot=F.ph*1.3; }
  X.fall=X.fall.filter(F=>{ if(F.y<F.gy) return true; const L=xcLeaf(F.x,F.gy); L.c=F.c; L.s=F.s; X.leaves.push(L); return false; }); if(X.leaves.length>96) X.leaves.splice(0,X.leaves.length-96);
  for(const L of X.leaves){ if(L.h<=0) continue; L.vh-=230*dt; L.h+=L.vh*dt; L.ph+=dt*7; L.x+=L.vx*dt+Math.sin(L.ph)*6*dt; L.vx*=Math.pow(.25,dt); L.rot+=L.vr*dt;   // 날린 잎: 펄럭이며 다시 내려앉는다
    if(L.h<=0){ L.h=0; L.vh=0; L.vx=0; L.vr=0; } if(L.x<4) L.x=4; if(L.x>SB.W-4) L.x=SB.W-4; }
  for(const a of [GS.hero, ...GS.ents.filter(e=>e.e||e.dojo)]){ if(!a||a.hidden||a.jug) continue; const px=X.prev.get(a); X.prev.set(a,a.d.x); if(px==null) continue;   // 움직이면 발밑 잎이 날린다
    const sp=Math.abs(a.d.x-px)/Math.max(dt,1e-3); if(sp>40) xcKick(a.d.x,a.d.y,Math.min(1.6,sp/130),14+Math.min(14,sp/25)); }
  for(const d of dusts){ if(d._xc) continue; d._xc=1; xcKick(d.x,d.y,.8,22); } }   // 걸음 · 착지 · 타격 먼지 자리도 잎이 튄다
function drawCrossBack(time){ xcEnsure(); const X=DJ.xc;
  drawDepth=.95; for(let x=0;x<SB.W;x+=16) quad('xc_sky',x,0); placeAt('xc_sun',XC_SUN[0],XC_SUN[1],false,0);
  drawDepth=.93; [['xc_cloud0',60,40,4.5],['xc_cloud1',300,22,7],['xc_cloud2',180,98,10]].forEach(([n,x0,y,sp])=>{ const w=SPR[n].w, span=SB.W+w; quad(n,Math.round((((x0+time*sp)%span)+span)%span-w),y); });   // 구름은 천천히 흐른다
  drawDepth=.9; quad('xc_hills',0,150); quad('xc_hills',240,150);
  drawDepth=.85; for(let x=0;x<SB.W;x+=96) quad('xc_track',x,198);
  drawDepth=.83; for(const x of XC_CS) placeAt('xc_cpole',x,211,false,0);
  if(X.tr){ const T=X.tr, cars=xcCars(X), wk=Math.floor(T.dist/4)&3; drawDepth=.8;
    if(cars.length===2){ const gx=Math.round((cars[0].cx+cars[1].cx)/2); placeAt('xc_bel',gx,XC_TY-20,false,0); }
    cars.forEach((c,i)=>{ const bump=(Math.floor((c.cx+i*37)/40)&1), cx=Math.round(c.cx); placeAt(T.kind==='B'?'xc_carB':'xc_carA', cx, XC_TY-bump, c.fl, 0);   // 이음매마다 1px 출렁
      for(const b of XC_CAR.bog) for(const o of [-8,8]){ const [x0]=xcSpan(c,b+o,b+o); placeAt('xc_wh@'+wk, Math.round(x0), 198, false, 0); } }); }
  drawDepth=.8; quad('xc_cat',0,XC_CW-17);
  drawDepth=.6; DJ_POLES.forEach((x,i)=>{ placeAt('xc_post',x,222,false,0); if(X.bell){ const on=(Math.floor(time*2.4)+i)%2===0; placeAt('xc_lamp',x+(on?-9:9),144,false,0); } });   // 건널목 기둥 = 기둥 튕기기 자리
  drawDepth=.55; quad('xc_wires',0,24);
  drawDepth=.3; for(let x=0;x<SB.W;x+=96) quad('xc_floor',x,222);
  if(X.tr && X.tr.warn<=0){ drawDepth=.28; for(const w of xcWinList(X)){ if(w.x<-30||w.x>SB.W+30) continue; const b=Math.max(0,1-Math.abs(w.x-XC_SUN[0])/130); if(b<.08 && ((Math.round(w.x)>>4)&1)) continue; const k=b>.6?3:b>.3?2:1; placeAt('xc_patch@'+k, Math.round(w.x-30), 228+((Math.round(w.x)>>3)&1)*4, false, 0); } }   // 창으로 든 빛이 바닥에 비스듬히
  drawDepth=.25; for(const L of X.leaves) if(L.h<=0) placeAt(xcKey(L),Math.round(L.x),Math.round(L.gy),false,0);
  for(const s of GS.shots){ if(s.friendly){ quad('sb_box', Math.round(s.x)-5, Math.round(s.y)-4); continue; } const k=m32(Math.round(s.t*40)*(s.vx<0?-1:1)); placeAt('sb_bottle@'+k, Math.round(s.x), Math.round(s.y), false, 0); }
  drawOX=0; drawDepth=0; }
function drawCrossFront(){ if(!xcOn() || !DJ.xc) return; const X=DJ.xc; drawDepth=0;   // 날리는 잎 · 떨어지는 잎은 사람 앞에
  for(const L of X.leaves) if(L.h>0) placeAt(xcKey(L),Math.round(L.x),Math.round(L.gy-L.h),false,0);
  for(const F of X.fall) placeAt(xcKey(F),Math.round(F.x),Math.round(F.y),false,0); }
function crossLights(time){ const L=[], X=DJ.xc||{}, T=X.tr&&X.tr.warn<=0?X.tr:null, k=xcSunK(X);   // 광원 8개 한도: 전차가 지날 땐 바닥 되튐 대신 전조등 · 불꽃
  L.push({ x:XC_SUN[0], y:XC_SUN[1]+10, z:120, r:620, c:[1,.6,.36], i:.75*(.35+.65*k) });                 // 지는 해(차체에 가리면 어두워진다)
  L.push({ x:80, y:30, z:90, r:520, c:[.62,.44,.82], i:.4 });                                            // 하늘빛(보라) 채움
  L.push({ x:240, y:150, z:70, r:280, c:[1,.76,.56], i:.5*(.55+.45*k) });                               // 사람 앞쪽 따뜻한 채움(창빛 명멸을 따라)
  if(X.bell) DJ_POLES.forEach((x,i)=>{ const on=(Math.floor(time*2.4)+i)%2===0; L.push({ x:x+(on?-9:9), y:144, z:16, r:70, c:[1,.18,.12], i:1.1, em:true }); });   // 건널목 적색등
  if(T){ const W=xcWinList(X).filter(w=>w.x>-20&&w.x<SB.W+20).sort((a,b)=>Math.abs(a.x-XC_SUN[0])-Math.abs(b.x-XC_SUN[0]))[0];
    if(W) L.push({ x:W.x, y:200, z:-40, r:210, c:[1,.7,.4], i:1.4*k });                                // 해 쪽 창빛: 사람 뒤에서 테두리를 비춘다
    const hd=xcHead(X); if(hd.x>-320 && hd.x<SB.W+320) L.push({ x:hd.x+T.dir*30, y:hd.y, z:22, r:260, c:[1,.9,.7], i:.95, spot:[T.dir,.05], cone:.96 }); }   // 전조등
  else L.push({ x:240, y:236, z:10, r:300, c:[1,.7,.5], i:.25 });                                        // 바닥 되튐
  if(X.spk>0) L.push({ x:X.spkX, y:XC_CW+6, z:30, r:340, c:[.7,.85,1], i:2.4*X.spk/.14, em:true });       // 팬터그래프 불꽃 섬광
  return L; }
function crossFX(){ const X=DJ.xc||{}, T=X.tr&&X.tr.warn<=0?X.tr:null, vols=[{ x:XC_SUN[0], y:XC_SUN[1], dx:-.5, dy:-.2, c:[1,.7,.45], i:.07, cone:2, len:1, halo:22 }]; let expo=.94, bloom=.9;
  if(T){ expo*=.9+.1*xcSunK(X);
    xcWinList(X).map(w=>({ ...w, b:Math.max(0,1-Math.abs(w.x-XC_SUN[0])/110) })).filter(w=>w.b>.05).sort((a,b)=>b.b-a.b).slice(0,4)
      .forEach(w=>vols.push({ x:w.x, y:w.y, dx:-.3, dy:.95, c:[1,.72,.42], i:.2*w.b, cone:.9, len:80, halo:4 }));   // 창으로 뚫고 나오는 빛줄기
    const hd=xcHead(X); vols.push({ x:hd.x, y:hd.y, dx:T.dir, dy:.03, c:[1,.92,.75], i:.13, cone:.96, len:240, halo:5 }); }   // 전조등 빛기둥(전차보다 먼저 들어온다)
  if(X.spk>0){ const q=X.spk/.14; expo+=.3*q; bloom+=.6*q; }
  return { expo, winR:0, winY:[0,0], press:0, bloom, reflY:SB.FLOOR-1, rain:0, vig:.3, fog:.07, fogC:[.36,.16,.14], inv:0, grade:[1.1,.97,.86], sat:1.08, vols }; }
function drawDojoBack(time){ if(!DJ.sign) djReset(); xcEnsure(); if(DJ.bg==='cross'){ drawCrossBack(time); return; }
  drawDepth=.9; quad('dj_out',0,0);
  drawDepth=.6; for(const w of DJ.walkers){ const win=DJ_WIN.find(([a,b])=>w.x>a+4&&w.x<b-4); if(!win) continue; placeAt(`dj_walk${w.um}${Math.floor(w.t*3)%2}`, Math.round(w.x), 194, w.v<0, 0); }
  drawDepth=.3; quad('dj_ceil',0,0); quad('dj_room',0,80); quad('dj_floor',0,222);
  const deg=r=>r*180/Math.PI;
  placeAt('dj_sign@'+djIdx(DJ_SIGN_A,deg(DJ.sign.a)), 240, 100, false, 0);
  [150,330].forEach((x,k)=>placeAt('dj_lamp@'+djIdx(DJ_LAMP_A,deg(DJ.lamps[k].a)+Math.sin(time*.9+k)*2), x, 100, false, 0));
  { const rx=STRAP_X.slice().sort((a,b)=>Math.abs(a-250)-Math.abs(b-250))[0]; placeAt('dj_ring', rx, 112, false, 0); }
  for(const x of DJ_ANDON) placeAt('dj_andon', x, 84, false, 0);
  const jit=t=>t>0?Math.round(Math.sin(time*80)*2*t/.5):0;
  const PX=id=>DJ_PROPS.find(p=>p.id===id).x;
  placeAt('dj_mook', PX('mook')+jit(DJ.mook), 222, false, 0); placeAt(DJ.brd?'dj_brd_b':'dj_brd', PX('brd'), 222, false, 0); placeAt(DJ.rack?'dj_rack_b':'dj_rack', PX('rack'), 222, false, 0);
  placeAt('dj_drum', PX('drum')+jit(DJ.drum), 222, false, 0); placeAt('dj_bag@'+djIdx(DJ_BAG_A,deg(DJ.bag.a)), PX('bag'), 100, false, 0);
  for(const s of GS.shots){ if(s.friendly){ quad('sb_box', Math.round(s.x)-5, Math.round(s.y)-4); continue; } const k=m32(Math.round(s.t*40)*(s.vx<0?-1:1)); placeAt('sb_bottle@'+k, Math.round(s.x), Math.round(s.y), false, 0); }
  drawOX=0; drawDepth=0; }
function dojoLights(time){ if(!DJ.sign) djReset(); xcEnsure(); if(DJ.bg==='cross') return crossLights(time); const L=[];
  for(const x of DJ_ANDON) L.push({ x, y:98, z:46, r:205, c:[1,.88,.7], i:1.15 });                                   // 천장 종이 등(안돈): 수련 자리를 넓게
  for(const x of DJ_ANDON) L.push({ x, y:66, z:16, r:120, c:[1,.82,.6], i:.6 });                                     // 등이 천장 널판을 비추는 윗빛
  [150,330].forEach((x,k)=>{ const sw=Math.sin(DJ.lamps[k].a)*10; L.push({ x:x+sw, y:112, z:18, r:150, c:[1,.6,.32], i:1.3, em:true }); });   // 붉은 등롱
  for(const [a,b] of DJ_WIN) L.push({ x:(a+b)/2, y:172, z:34, r:130, c:[.6,.74,1], i:.75 });                         // 창으로 드는 달빛(차가운 대비)
  L.push({ x:240, y:104, z:14, r:64, c:[1,.82,.55], i:.45 });                                                          // 현판
  L.push({ x:256, y:226, z:8, r:250, c:[1,.75,.5], i:.32 });                                                           // 마루에서 되튀는 빛(그림자 채움)
  return L; }
// 무도장 후처리: 따뜻한 노출 · 옅은 비네트 · 마루 반사 · 달빛 빛줄기 · 등 빛 원뿔
function dojoFX(){ if(DJ.bg==='cross') return crossFX(); const vols=[];
  for(const [a,b] of DJ_WIN) vols.push({ x:(a+b)/2, y:156, dx:.36, dy:.93, c:[.72,.84,1], i:.2, cone:.82, len:120, halo:8 });
  for(const x of DJ_ANDON) vols.push({ x, y:100, dx:0, dy:1, c:[1,.9,.72], i:.2, cone:.72, len:110, halo:10 });
  [150,330].forEach((x,k)=>vols.push({ x:x+Math.sin(DJ.lamps[k].a)*10, y:116, dx:0, dy:1, c:[1,.7,.4], i:.22, cone:2, len:1, halo:14 }));
  return { expo:1.12, winR:0, winY:[0,0], press:0, bloom:1.0, reflY:SB.FLOOR-1, rain:0, vig:.34, fog:.05, fogC:[.18,.12,.07], inv:0, grade:[1.07,1.0,.9], sat:1.06, vols }; }

