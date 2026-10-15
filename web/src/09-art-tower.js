// =========================================================
// 엘리베이터 타워(실험 모드): 화물 엘리베이터 칸 · 승강로 · 층 문 · 문이 열리면 보이는 층 풍경
// 칸 안 x 72~408 · 천장 104 · 바닥 222 · 철창 문 172~308 × 126~222 · 층 간격 300px
// =========================================================
const TWR={ L:72, R:408, G0:172, G1:308, GT:126, CEIL:104, PX:330, FH:300, CEIL_H:62, CX:56, CY:88 };   // CEIL_H: 서서 떠오른 몸의 머리가 천장(104)에 닿는 높이
const TW_NEEDLE=[-80,-70,-60,-50,-40,-30,-20,-10,0,10,20,30,40,50,60,70,80], TW_LAMP_A=[-30,-25,-20,-15,-10,-5,0,5,10,15,20,25,30], TW_LAMPX=[128,352];
function genTower(out){ const rnd=mulberry(9091), R=(a,b)=>a+Math.floor(rnd()*(b-a+1));
  // ── 승강로 벽(150px 세로 반복): 거푸집 자국 콘크리트 · 물 자국 · T형 가이드 레일과 브래킷
  { const p=paint(SB.W,150);
    for(let y=0;y<150;y++) for(let x=0;x<SB.W;x++){ const seam=(y%30===0)||(x%64===0), dot=((x*13+y*7)%37===0); p.set(x,y,M.CONC, seam||dot?0:(((x>>3)+(y>>2))%5===0?2:1)); }
    for(let k=0;k<46;k++){ const x=R(0,SB.W-1), y=R(0,149), l=R(4,18); for(let j=0;j<l;j++) p.set(x,(y+j)%150,M.MDARK,2); }
    for(const rx of [40,432]){ p.rect(rx,0,8,150,M.STEEL,(q)=>q===0?3:q===7?0:1); p.rect(rx+3,0,2,150,M.STEEL,3);
      for(const by of [22,97]){ p.rect(rx-6,by,20,6,M.MDARK,(q,j)=>j===0?3:2); p.set(rx-4,by+2,M.STEEL,4); p.set(rx+11,by+2,M.STEEL,4); } }
    out.tw_shaft=p.s; }
  // ── 칸 위 와이어 넷 · 샤클
  { const p=paint(24,88); for(const x of [3,8,15,20]) for(let y=0;y<88;y++) p.set(x,y,M.STEEL,(y%6<3)?1:3); p.rect(0,80,24,8,M.MDARK,(q,j)=>j===0?3:1); out.tw_cable=p.s; }
  // ── 칸(368×156, 화면 x 56 · y 88에 놓는다): 꼭대기 보 · 천장판 · 모서리 기둥 · 뒷벽(패널 · 범퍼 레일 · 체크 철판) · 문틀 · 층 표시기 · 버튼 패널 · 정원판 · 구급함 · 바닥판 · 아래 보
  { const W=368, H=156, p=paint(W,H), X=x=>x-TWR.CX, Y=y=>y-TWR.CY;
    p.rect(0,0,W,8,M.MDARK,(q,j)=>j===0?3:j===7?0:((q%24)===0?3:1),{ny:.6}); for(let x=6;x<W;x+=24) p.set(x,4,M.STEEL,3);
    p.rect(8,8,W-16,8,M.VAN,(q,j)=>j===7?0:j===0?3:((q%56)===0?1:2),{ny:-.5});
    for(let y=TWR.CEIL;y<222;y++) for(let x=TWR.L;x<TWR.R;x++){ if(x>=TWR.G0 && x<TWR.G1 && y>=TWR.GT) continue;   // 문 자리는 비운다(승강로 · 층이 보이게)
      const dz=((x+y)&1); let m=M.VAN, k = y<108 ? 1 : y<140 ? 3 : y<164 ? (dz?3:2) : 2, o={};   /* 천장 밑 그림자 · 위는 밝게 · 아래로 디더 */
      if(y>=198){ m=M.STEEL; k=((x+y)%4===0)?3:((((x-y)%4)+4)%4===0?0:1); o={ny:.5}; }                  // 체크 플레이트(미끄럼 방지 철판)
      else if((y>=164&&y<170)||(y>=190&&y<196)){ m=M.WOOD; k=(y===164||y===190)?4:((x%40)===0?1:3); o={ny:.4}; }   // 나무 범퍼 레일 두 줄
      else { const c=(x-TWR.L)%56; if(c===0) k=1; else if(c===1) k=4; else if(c>=52) k=Math.max(1,k-1); else if((y-TWR.CEIL)%22===6 && (x-TWR.L)%8===4) k=4; if(y>=180 && y<190 && ((x*7+y)%5===0)) k=1; }   // 패널 이음(왼쪽 밝은 결 · 오른쪽 그늘) · 리벳 · 아래쪽 때
      p.set(X(x),Y(y),m,k,o); }
    for(let k=0;k<90;k++){ const x=R(TWR.L,TWR.R-1), y=R(TWR.CEIL+4,196); if(x>=TWR.G0-6&&x<TWR.G1+6&&y>=TWR.GT-8) continue; p.set(X(x),Y(y),rnd()<.55?M.BRICK:M.MDARK,rnd()<.5?2:3); }   // 녹 · 긁힘
    for(const [x0,sd] of [[0,1],[W-16,-1]]) for(let y=8;y<146;y++) for(let q=0;q<16;q++){ const edge = sd>0 ? (q===15?0:q<2?3:2) : (q===0?0:q>13?3:2); p.set(x0+q,y,M.STEEL,((y%20)===10&&(q===4||q===11))?4:edge,{r:.3}); }   // 모서리 기둥
    p.rect(X(TWR.G0)-5,Y(TWR.GT)-7,5,222-TWR.GT+7,M.STEEL,(q)=>q===0?1:q===4?4:2); p.rect(X(TWR.G1),Y(TWR.GT)-7,5,222-TWR.GT+7,M.STEEL,(q)=>q===4?1:q===0?4:2);   // 문틀
    for(let x=TWR.G0-5;x<TWR.G1+5;x++) for(let y=TWR.GT-7;y<TWR.GT;y++){ const b=Math.floor((x+y)/5)%2; p.set(X(x),Y(y),b?M.MDARK:M.TAXI,b?1:4); }   // 노랑 · 검정 위험 띠
    { const cx=X(240), cy=Y(117); for(let dy=-11;dy<=0;dy++) for(let dx=-14;dx<=14;dx++){ const r=Math.hypot(dx,dy*1.27); if(r>14) continue; const rim=r>12.6; p.set(cx+dx,cy+dy,rim?M.GOLD:M.CANVAS,rim?3:4,rim?{}:{e:.28}); }   // 반원 층 표시기
      for(let i=0;i<10;i++){ const t=(-80+i*160/9)*Math.PI/180; p.set(cx+Math.round(Math.sin(t)*11),cy-Math.round(Math.cos(t)*8.5),M.INK,1); } }
    { const x0=X(TWR.PX)-8, y0=Y(140); p.rect(x0,y0,18,50,M.STEEL,(q,j)=>q===0||j===0?4:(q===17||j===49)?0:2,{ny:.2});   // 버튼 패널: 층 버튼 2×5 · 비상 정지
      for(let r=0;r<5;r++) for(let c=0;c<2;c++){ const bx=x0+4+c*7, by=y0+5+r*7; p.rect(bx,by,4,4,M.MDARK,(q,j)=>(q===0||j===0)?3:1); }
      p.rect(x0+5,y0+41,8,6,M.RED,(q,j)=>j===0?4:2); }
    { const x0=X(94), y0=Y(130); p.rect(x0+48,y0+3,8,7,M.RED,(q,j)=>q===0||j===0?2:0); }   // 꺼진 초과등(정원판은 따로)
    { const x0=X(356), y0=Y(134); p.rect(x0,y0,24,22,M.RED,(q,j)=>(q===0||j===0)?4:(q===23||j===21)?1:3,{ny:.2}); p.rect(x0+10,y0+5,4,12,M.CANVAS,5); p.rect(x0+6,y0+9,12,4,M.CANVAS,5); p.rect(x0+2,y0+2,20,1,M.GLASS,5,{e:.2}); }   // 비상 구급함
    signText(p,X(84),Y(110),'FREIGHT',M.TAXI,3); signText(p,X(360),Y(110),'B-07',M.TAXI,2);
    for(let y=222;y<230;y++) for(let x=TWR.CX+8;x<TWR.CX+W-8;x++){ const k=y===222?5:((x+y)%4===0?4:((((x-y)%4)+4)%4===0?1:3)); p.set(X(x),Y(y),M.STEEL,k,{ny:.9}); }   // 바닥판(체크 플레이트)
    p.rect(X(TWR.G0),Y(222),TWR.G1-TWR.G0,2,M.MDARK,1);
    for(let y=230;y<244;y++) for(let x=TWR.CX;x<TWR.CX+W;x++){ const ap=y>=237, b=Math.floor((x+y)/6)%2; p.set(X(x),Y(y), ap&&!b?M.TAXI:M.MDARK, ap?(b?1:4):(y===230?3:((x%32)===0?2:1))); }   // 아래 보 · 앞치마(위험 띠)
    out.tw_cab=p.s; }
  // ── 접이식 철창 문(놋쇠): 0(닫힘) ~ 6(접힘) · 왼쪽 문틀로 접힌다
  for(let k=0;k<=6;k++){ const w=136-k*20, h=96, p=paint(w,h+4), n=11, xs=Array.from({length:n+1},(_,i)=>Math.round(i*(w-1)/n)), seg=Math.max(6,Math.round((w/n)*1.6));
    p.rect(0,0,w,3,M.GOLD,(q,j)=>j===0?4:2); p.rect(0,h+1,w,3,M.GOLD,(q,j)=>j===0?3:1);
    for(let i=0;i<n;i++){ const a=xs[i], b=xs[i+1]; if(b-a<1) continue; for(let y0=3;y0<h;y0+=seg){ const y1=Math.min(h,y0+seg/2), y2=Math.min(h,y0+seg); p.line(a,y0,b,y1,M.GOLD,3); p.line(b,y0,a,y1,M.GOLD,1); p.line(a,y1,b,y2,M.GOLD,3); p.line(b,y1,a,y2,M.GOLD,1); } }
    for(const x of xs) for(let y=3;y<=h;y++) p.set(x,y,M.GOLD,(y%16===8)?5:3,{r:.5});
    p.rect(Math.max(0,w-5),40,5,16,M.MDARK,(q)=>q===0?3:1);
    out['tw_gate@'+k]=p.s; }
  // ── 층 문(승강로 쪽): 문 두 짝(작은 창에 층 불빛) · 문틀과 슬래브 · 문 밑 틈 빛 · 층 번호
  { const p=paint(68,96); p.rect(0,0,68,96,M.VAN,(q,j)=>(q===0||j===0)?3:(q===67)?0:1);
    for(let j=4;j<82;j+=19) p.rect(2,j,64,1,M.VAN,2);
    for(let j=84;j<96;j++) for(let q=0;q<68;q++){ const b=Math.floor((q+j)/5)%2; p.set(q,j,b?M.MDARK:M.TAXI,b?1:3); }
    p.rect(40,20,20,12,M.GLASS,(q,j)=>(q===0||j===0)?1:4,{e:.6}); out.tw_ld=p.s; }
  { const p=paint(156,116); p.rect(0,106,156,10,M.CONC,(q,j)=>j<2?3:(j===9?0:2),{ny:.5}); p.rect(4,105,148,2,M.STEEL,4,{ny:.8});
    p.rect(0,0,10,106,M.STEEL,(q)=>q===0?3:q===9?0:1); p.rect(146,0,10,106,M.STEEL,(q)=>q===0?3:q===9?0:1); p.rect(0,0,156,10,M.STEEL,(q,j)=>j===0?3:j===9?0:1);
    for(let x=14;x<146;x+=8) p.set(x,5,M.MDARK,0); out.tw_land=p.s; }
  { const p=paint(136,2); p.rect(0,0,136,2,M.CANVAS,5,{e:.95}); out.tw_leak=p.s; }
  for(let n=1;n<=50;n++){ const s=String(n), p=paint(s.length*12+2,16); signText(p,1,1,s,M.TAXI,4,{},2); out['tw_fn@'+n]=p.s; }
  // ── 바늘 · 전등(붙은 · 매달린) · 찌그러짐 · 뚫린 천장 · 초과등 · 버튼 불 · 깨진 구급함
  { const p=paint(5,12); p.s.px=2; p.s.py=10; p.rect(2,0,1,10,M.RED,4,{e:.3}); p.rect(1,9,3,3,M.MDARK,3); TW_NEEDLE.forEach((a,k)=>out['tw_needle@'+k]=rotSmall(p.s,a)); }
  const lampRaw=(on,wire)=>{ const p=paint(16,wire+12); p.s.px=8; p.s.py=0; if(wire) for(let y=0;y<wire;y++) p.set(8+((y>>2)&1),y,M.MDARK,1);
    const y0=wire; p.rect(4,y0,8,2,M.MDARK,3); for(let y=y0+2;y<y0+11;y++){ const hw=y<y0+4?3:y<y0+9?5:3; for(let x=8-hw;x<8+hw;x++) p.set(x,y,M.CANVAS,on?5:2,on?{e:.95}:{}); }
    for(let y=y0+2;y<y0+11;y++){ p.set(8-5,y,M.MDARK,2); p.set(8+4,y,M.MDARK,2); } for(const y of [y0+5,y0+8]) for(let x=3;x<13;x++) p.set(x,y,M.MDARK,2); return p.s; };
  out.tw_lamp=lampRaw(true,0); out.tw_lampOff=lampRaw(false,0);
  { const on=lampRaw(true,18), off=lampRaw(false,18); TW_LAMP_A.forEach((a,k)=>{ out['tw_lampH@'+k]=rotSmall(on,a); out['tw_lampHo@'+k]=rotSmall(off,a); }); }
  { const p=paint(18,6); for(let y=0;y<6;y++) for(let x=0;x<18;x++){ const e=((x-9)/9)**2+((y-1)/5)**2; if(e<=1 && rnd()<.85) p.set(x,y,rnd()<.5?M.MDARK:M.VAN,rnd()<.5?0:1,{ny:-.3}); } out.tw_dent=p.s; }
  { const p=paint(44,10); p.s.px=22; p.s.py=0; for(let y=0;y<8;y++) for(let x=0;x<44;x++){ const edge=Math.abs(x-22)>18-((x*7)%5)-y*.3; if(!edge) p.set(x,y,M.INK,0); else if(rnd()<.5) p.set(x,y,M.VAN,1); }
    for(const [x,l] of [[12,9],[30,7],[19,10]]) for(let y=0;y<l;y++) p.set(x+((y>>1)&1),y,y===l-1?M.TAXI:M.MDARK,y===l-1?4:2); out.tw_hole=p.s; }
  { const p=paint(8,7); p.rect(0,0,8,7,M.RED,(q,j)=>(q===0||j===0)?4:5,{e:1}); out.tw_over=p.s; }
  for(let n=4;n<=9;n++){ const p=paint(44,14); p.rect(0,0,44,14,M.GOLD,(q,j)=>(q===0||j===0)?4:(q===43||j===13)?1:2,{ny:.3}); signText(p,5,4,'MAX '+n,M.INK,1); out['tw_plate@'+n]=p.s; }   // 놋쇠 정원판
  { const p=paint(4,4); p.rect(0,0,4,4,M.WINLIT,5,{e:1}); out.tw_btnL=p.s; }
  { const p=paint(24,22); p.rect(0,0,24,22,M.RED,(q,j)=>(q===0||j===0)?4:(q===23||j===21)?1:2); p.rect(2,2,20,18,M.INK,0); for(const [x,y] of [[3,3],[6,2],[20,4],[18,17],[4,16]]) p.set(x,y,M.GLASS,5,{e:.3}); out.tw_kitB=p.s; }
  // ── 층 풍경(136×96): 한 점 투시의 방 — 먼 벽 · 바닥 · 천장 · 양옆 벽 + 그 층의 물건과 불빛
  const room=(o)=>{ const W=136, Hh=96, p=paint(W,Hh), fx0=o.fx0??24, fx1=o.fx1??112, fy0=o.fy0??12, fy1=o.fy1??70;
    for(let y=0;y<Hh;y++) for(let x=0;x<W;x++){ const cl = x<=fx0 ? x*fy0/fx0 : x>=fx1 ? (W-1-x)*fy0/(W-1-fx1) : fy0, fl = x<=fx0 ? Hh-1-x*(Hh-1-fy1)/fx0 : x>=fx1 ? Hh-1-(W-1-x)*(Hh-1-fy1)/(W-1-fx1) : fy1;
      if(y<cl) p.set(x,y,o.ceil,o.ceilK??1);
      else if(y>fl){ const t=(y-fy1)/(Hh-1-fy1), hw=(fx1-fx0)/2+(W/2-(fx1-fx0)/2)*t, u=(x-W/2)/hw; p.set(x,y,o.floor,o.floorF?o.floorF(u,t):(o.floorK??2),{ny:.7}); }
      else if(x<fx0||x>fx1) p.set(x,y,o.side??o.wall,o.sideF?o.sideF(x,y):(o.sideK??Math.max(0,(o.wallK??2)-1)),{nx:x<fx0?.4:-.4});
      else p.set(x,y,o.wall,o.wallF?o.wallF(x,y):(o.wallK??2)); }
    return p; };
  const check=(n,a,b)=>(u,t)=>((Math.floor((u+1)*n)+Math.floor(Math.sqrt(t)*7))%2)?a:b;
  const ell=(p,cx,cy,rx,ry,m,k,o)=>{ for(let y=-ry;y<=ry;y++) for(let x=-rx;x<=rx;x++) if((x*x)/(rx*rx)+(y*y)/(ry*ry)<=1) p.set(cx+x,cy+y,m,typeof k==='function'?k(x,y):k,o); };
  // 층마다 두 장: 멀쩡한 모습 · 날아든 적에 부서진 모습(b)
  const crack=(p,cx,cy,n,len,m,k)=>{ for(let i=0;i<n;i++){ const a=i/n*Math.PI*2+rnd()*.4; let x=cx, y=cy; for(let s=0;s<len;s++){ x+=Math.cos(a)+(rnd()-.5)*.8; y+=Math.sin(a)+(rnd()-.5)*.8; p.set(x,y,m,k,{e:.15}); } } };
  const shards=(p,x0,x1,y,n,m)=>{ for(let i=0;i<n;i++){ const x=x0+Math.floor(rnd()*(x1-x0)), yy=y+Math.floor(rnd()*6); p.set(x,yy,m,5,{e:.25}); if(rnd()<.5) p.set(x+1,yy,m,4); } };
  // 1 주차장: 나트륨등 · 기둥(층 번호) · 주차선 · 세워 둔 차 뒤 · EXIT — 부서지면 뒷유리 금 · 트렁크 찌그러짐 · 비상등(깜빡임은 따로)
  const S_park=b=>{ const p=room({ wall:M.CONC, wallK:2, ceil:M.CONC, ceilK:1, floor:M.ASPH, floorF:(u,t)=>((Math.floor(u*9+t*21))%7===0)?0:1, side:M.CONC, sideK:1 });
    for(const i of [-1,-.34,.34,1]) p.line(68+i*44,70,68+i*82,95,M.TAXI,4);
    for(const x of [40,96]){ p.rect(x-6,2,12,2,M.LEAFO,5,{e:1}); p.rect(x-4,4,8,1,M.LEAFO,3,{e:.6}); }
    p.rect(6,0,16,96,M.CONC,(q,j)=>q===0?4:q===15?1:3,{nx:.3}); for(let j=74;j<96;j++) for(let q=0;q<16;q++) p.set(6+q,j,(Math.floor((q+j)/4)%2)?M.TAXI:M.MDARK,(Math.floor((q+j)/4)%2)?4:1); signText(p,8,30,'P1',M.TAXI,4);
    p.rect(74,18,26,9,M.GRASS,(q,j)=>(q===0||j===0)?3:4,{e:b?.35:.8}); signText(p,76,20,'EXIT',M.INK,0);
    p.rect(64,46,54,24,M.SUIT,(q,j)=>j<2?4:j<11?3:2,{ny:.3}); p.rect(70,40,42,8,M.SUIT,3); p.rect(74,41,34,6,M.GLASS,3,{e:.1}); p.rect(66,55,8,4,M.RED,5,{e:1}); p.rect(108,55,8,4,M.RED,5,{e:1}); p.rect(84,58,14,5,M.CANVAS,4); p.rect(64,66,54,3,M.STEEL,3);
    for(const x of [68,108]) p.rect(x,69,10,5,M.INK,1); ell(p,44,86,10,3,M.INK,1);
    if(b){ crack(p,90,44,7,8,M.CANVAS,5); for(let k=0;k<10;k++) p.set(80+R(0,20),48+R(0,6),M.INK,0); p.rect(64,66,20,3,M.STEEL,1); p.line(64,66,74,70,M.STEEL,4); shards(p,70,110,72,14,M.GLASS); }
    return p.s; };
  // 2 하역장: 셔터 너머 밤거리 · 팔레트 상자 · 볼라드 · 지게차 · 작업등 — 부서지면 상자 더미가 무너져 바닥에 흩어지고 하나는 터진다
  const S_dock=b=>{ const p=room({ wall:M.BRICK, wallK:2, ceil:M.MDARK, ceilK:1, floor:M.CONC, floorF:(u,t)=>((Math.floor(u*6)+Math.floor(t*5))%3===0)?1:2, side:M.BRICK, sideK:1 });
    p.rect(30,16,76,26,M.STEEL,(q,j)=>j%3===0?1:3,{ny:.2}); p.rect(30,42,76,28,M.SKY,(q,j)=>j<10?1:2); for(let x=34;x<104;x+=9) p.rect(x,46+((x*7)%9),3,4,M.WINLIT,4,{e:.7});
    p.rect(54,52,30,18,M.VAN,(q,j)=>j===0?4:2); p.rect(58,62,4,3,M.RED,5,{e:.9}); p.rect(76,62,4,3,M.RED,5,{e:.9}); p.rect(30,40,76,3,M.TAXI,4);
    p.rect(14,8,8,6,M.CANVAS,5,{e:1}); p.rect(13,7,10,1,M.MDARK,1); p.rect(13,14,10,1,M.MDARK,1);
    p.rect(4,84,40,6,M.WOOD,(q,j)=>j===0?4:(q%9===0?1:2));
    if(!b){ p.rect(8,66,16,18,M.COAT,(q,j)=>j===0?4:3); p.rect(24,72,16,12,M.COAT,(q,j)=>j===0?4:2); p.rect(8,74,16,1,M.TAXI,4); p.rect(14,58,12,8,M.COAT,3); }
    else { for(const [x,y,w,h] of [[2,78,14,10],[18,80,12,9],[34,84,14,8],[48,86,10,7],[10,88,12,7]]) p.rect(x,y,w,h,M.COAT,(q,j)=>j===0?4:(q===0?2:3)); p.rect(18,80,12,1,M.TAXI,4);
      for(let k=0;k<22;k++) p.set(30+R(0,26),82+R(0,12),M.CANVAS,R(3,5)); p.line(36,70,42,64,M.COAT,3); for(const [x,y] of [[30,74],[40,68],[52,76]]) p.set(x,y,M.COAT,2); }
    for(const x of [112,126]){ p.rect(x,72,5,20,M.TAXI,(q)=>q===0?5:3); p.rect(x,76,5,2,M.MDARK,1); }
    p.rect(92,58,18,20,M.TAXI,(q,j)=>j===0?5:3); p.rect(86,40,3,40,M.STEEL,2); p.rect(80,74,10,2,M.STEEL,3); for(const x of [94,106]) ell(p,x,80,3,3,M.INK,1);
    return p.s; };
  // 3 로비: 대리석 · 나무 벽 · 회전문 · 샹들리에 · 야자 화분 · 안내 데스크 — 부서지면 화분이 넘어져 흙이 쏟아지고 회전문 유리가 금 간다
  const S_lobby=b=>{ const p=room({ wall:M.WOODD, wallF:(x,y)=>(x%12===0)?1:3, ceil:M.WOODD, ceilK:1, floor:M.STONEL, floorF:check(5,4,2), side:M.WOODD, sideK:2 });
    p.rect(48,22,40,48,M.GOLD,(q,j)=>(q===0||j===0)?5:(q===39)?2:3,{r:.5}); p.rect(51,26,34,44,M.GLASS,(q,j)=>j<20?1:2,{e:.05}); for(const [x,y] of [[56,40],[66,36],[74,44],[80,38],[60,50]]) p.set(x,y,M.WINLIT,5,{e:.9}); p.rect(67,26,2,44,M.GOLD,4); p.line(52,48,84,40,M.GOLD,3);
    p.rect(44,18,48,4,M.GOLD,4,{e:.15}); signText(p,52,10,'LOBBY',M.GOLD,4,{e:.3});
    p.rect(66,0,4,4,M.GOLD,3); for(let i=-3;i<=3;i++){ const sw=b?1:0; p.set(68+i*4+sw,6+Math.abs(i)+(b&&i>0?1:0),M.WINLIT,5,{e:1}); p.set(68+i*4+sw,5+Math.abs(i),M.GOLD,4); }
    for(const x of [32,104]){ p.rect(x-2,30,5,6,M.WINLIT,5,{e:.95}); p.rect(x-3,36,7,1,M.GOLD,3); }
    if(!b){ p.rect(22,78,12,12,M.BRICK,(q,j)=>j===0?4:2); for(const [dx,dy] of [[-10,-14],[10,-12],[-6,-20],[8,-22],[0,-24]]) p.line(28,78,28+dx,78+dy,M.LEAF,4); }
    else { p.rect(18,86,14,8,M.BRICK,(q,j)=>q===0?4:2); for(let k=0;k<26;k++) p.set(32+R(0,16),88+R(0,6),M.WOODD,R(1,3)); for(const [dx,dy] of [[18,-4],[22,2],[20,-8],[26,-2],[16,4]]) p.line(26,90,26+dx,90+dy,M.LEAF,4); crack(p,62,50,6,10,M.CANVAS,5); shards(p,48,90,72,12,M.GLASS); }
    p.rect(94,62,32,14,M.WOOD,(q,j)=>j===0?5:j===1?4:2); p.rect(94,62,32,1,M.GOLD,4); p.rect(114,54,8,4,M.IVY,5,{e:.9}); p.rect(117,58,2,4,M.GOLD,3);
    return p.s; };
  // 4 우편실: 우편함 벽 · 형광등 · 우편 수레 · 소포 — 부서지면 칸칸이 편지가 쏟아져 바닥에 쌓이고 수레가 넘어진다
  const S_mail=b=>{ const p=room({ wall:M.CURT, wallK:2, ceil:M.FRAME, ceilK:2, floor:M.CURB, floorF:check(4,3,2), side:M.CURT, sideK:1 });
    for(const x of [30,82]) p.rect(x,3,26,2,M.CANVAS,5,{e:b&&x===82?.3:.95});
    p.rect(26,16,84,48,M.WOOD,1); for(let r=0;r<6;r++) for(let c=0;c<10;c++){ const x=28+c*8, y=18+r*7; p.rect(x,y,7,6,M.MDARK,1); if(((r*7+c*3)%4)!==0 && !(b && (r+c)%3===0)) p.rect(x+1,y+2+((r+c)%2),5,3,M.CANVAS,(r+c)%3?4:5); if((r*3+c)%11===0) p.rect(x+2,y+1,3,2,M.RED,4); }
    if(!b){ p.rect(88,70,34,16,M.STEEL,(q,j)=>(q%5===0||j%5===0)?3:1); p.rect(90,62,30,8,M.CANVAS,4); p.rect(96,58,12,6,M.COAT,3); for(const x of [92,118]) ell(p,x,88,2,2,M.INK,1); }
    else { for(let k=0;k<70;k++){ const x=24+R(0,90), y=74+R(0,20); p.rect(x,y,3,2,M.CANVAS,R(3,5)); } p.line(88,90,120,80,M.STEEL,3); p.line(90,92,122,82,M.STEEL,1); for(const [x,y] of [[118,74],[124,80]]) ell(p,x,y,2,2,M.INK,1); p.rect(100,86,12,6,M.COAT,3); }
    p.rect(6,72,20,18,M.COAT,(q,j)=>j===0?4:3); p.rect(8,60,16,12,M.COAT,(q,j)=>j===0?4:2); p.rect(6,80,20,1,M.TAXI,4); p.rect(14,60,1,12,M.TAXI,4);
    return p.s; };
  // 5 기계실: 배관 · 밸브 · 압력계 · 배전반 — 부서지면 배관이 터져 김이 뿜어지고 압력계 유리가 깨지고 배전반 문이 열린다
  const S_mech=b=>{ const p=room({ wall:M.CONC, wallK:1, ceil:M.MDARK, ceilK:0, floor:M.MDARK, floorF:(u,t)=>((Math.floor((u+1)*10)+Math.floor(t*9))%2)?2:1, side:M.CONC, sideK:0 });
    for(const y of [22,30]) p.rect(24,y,88,4,M.STEEL,(q,j)=>j===0?3:j===3?0:2,{ny:.4}); for(const x of [34,60,92]) for(const y of [21,29]) p.rect(x,y,3,6,M.STEEL,4);
    p.rect(40,26,4,44,M.STEEL,(q)=>q===0?3:1); p.rect(96,30,4,40,M.STEEL,(q)=>q===0?3:1); for(const [x,y] of [[42,46],[50,24],[98,52]]) p.rect(x,y,3,3,M.BRICK,3);
    for(const [x,y] of [[42,40],[98,46]]){ ell(p,x,y,5,5,M.RED,(dx,dy)=>Math.abs(dx*dx+dy*dy-20)<9?4:0); p.rect(x-5,y,11,1,M.RED,3); p.rect(x,y-5,1,11,M.RED,3); }
    for(const x of [62,74]){ ell(p,x,44,4,4,M.CANVAS,3,{e:.25}); p.line(x,44,x+2,41,M.INK,0); }
    p.rect(104,28,22,44,M.VAN,(q,j)=>(q===0||j===0)?3:1); p.rect(110,34,4,4,M.RED,5,{e:1}); p.rect(118,34,4,4,M.GRASS,2); p.line(108,50,114,42,M.TAXI,4); p.line(114,42,120,50,M.TAXI,4); p.line(108,50,120,50,M.TAXI,4);
    p.rect(64,1,8,3,M.RED,5,{e:1});
    if(b){ p.rect(56,21,6,6,M.INK,0); for(const [x,y,r] of [[60,16,5],[66,10,6],[54,8,4],[72,6,5]]) ell(p,x,y,r,Math.max(2,r-2),M.CANVAS,(dx,dy)=>((dx+dy)&1)?5:4,{e:.2});
      for(const x of [62,74]){ ell(p,x,44,4,4,M.INK,1); crack(p,x,44,4,4,M.CANVAS,5); } p.rect(104,28,10,44,M.MDARK,0); p.rect(96,28,8,44,M.VAN,(q,j)=>(q===0||j===0)?4:2); for(let k=0;k<10;k++) p.set(106+R(0,6),40+R(0,24),M.TAXI,5,{e:.8}); }
    return p.s; };
  // 6 세탁실: 드럼 세탁기 · 김 · 수건 수레 · 타일 — 부서지면 가운데 세탁기 문이 튕겨 열려 거품 물이 바닥에 쏟아진다
  const S_laundry=b=>{ const p=room({ wall:M.STONEL, wallF:(x,y)=>(x%8===0||y%8===0)?2:3, ceil:M.FRAME, ceilK:2, floor:M.CANVAS, floorF:check(4,3,2), side:M.STONEL, sideK:2 });
    p.rect(52,3,32,2,M.CANVAS,5,{e:.9});
    for(let i=0;i<3;i++){ const x=30+i*26; p.rect(x,38,24,32,M.CANVAS,(q,j)=>j===0?5:(q===23?2:4),{ny:.2}); p.rect(x+2,40,20,4,M.STEEL,2); p.set(x+4,42,M.NEONT,5,{e:1}); p.set(x+7,42,M.NEONT,4,{e:.8});
      if(b && i===1){ ell(p,x+12,56,8,8,M.INK,1); ell(p,x+2,60,6,8,M.STEEL,(dx,dy)=>dx*dx+dy*dy>24?4:2); continue; }
      ell(p,x+12,56,8,8,M.STEEL,(dx,dy)=>dx*dx+dy*dy>40?3:1); ell(p,x+12,56,6,6,M.WATER,(dx,dy)=>((dx+dy+i*3)%5===0)?5:4,{e:.65}); }
    for(const [x,y,r] of [[40,30,6],[58,26,8],[86,28,7],[70,22,5]]) ell(p,x,y,r,Math.max(2,r-3),M.CANVAS,(dx,dy)=>((dx+dy)&1)?5:4,{e:.15});
    if(b){ for(let y=62;y<96;y++){ const hw=Math.round(6+(y-62)*1.2); for(let x=68-hw;x<68+hw;x++) if(x>=0&&x<136&&rnd()<.9) p.set(x,y,y<70?M.CANVAS:M.WATER,y<70?5:((x+y)%3?4:5),{e:y<70?.2:.35,ny:.9}); }
      for(let k=0;k<30;k++){ const x=40+R(0,56), y=60+R(0,30); ell(p,x,y,2,1,M.CANVAS,5,{e:.25}); } }
    p.rect(8,72,24,16,M.STEEL,(q,j)=>(q%4===0||j%4===0)?3:1); p.rect(10,64,20,8,M.CANVAS,(q,j)=>j%3===0?3:5); for(const x of [10,30]) ell(p,x,90,2,2,M.INK,1);
    return p.s; };
  // 7 룸서비스(호텔 복도): 카펫 · 벽등 · 객실 문 · 창밖 야경 · 룸서비스 카트 — 부서지면 카트가 넘어져 은빛 덮개가 구르고 꽃병이 쏟아진다
  const S_room=b=>{ const p=room({ fx0:46, fx1:90, fy0:24, fy1:58, wall:M.SKY, wallK:1, ceil:M.CURT, ceilK:2, floor:M.RED, floorF:(u,t)=>{ const a=(u+1)*6, c=Math.sqrt(t)*10; return (Math.abs((a%2)-1)+Math.abs((c%2)-1)<.5)?4:2; }, side:M.CURT, sideK:3 });
    for(const [x,y] of [[52,30],[60,38],[70,32],[80,42],[86,34],[56,46],[76,50]]) p.set(x,y,M.WINLIT,5,{e:.9}); p.rect(46,24,45,2,M.WOOD,2);
    for(const [x0,x1,yt,yb] of [[10,20,22,72],[28,34,28,64],[102,112,28,64],[116,126,22,72]]){ p.rect(x0,yt,x1-x0,yb-yt,M.WOOD,(q,j)=>(q===0||j===0)?4:2,{ny:.1}); p.rect(x0+2,yt+6,3,2,M.GOLD,5,{e:.2}); }
    for(const x of [24,40,96,110]){ p.rect(x,34,3,4,M.WINLIT,5,{e:1}); p.rect(x-1,38,5,1,M.GOLD,3); }
    if(!b){ p.rect(46,72,44,14,M.CANVAS,(q,j)=>j===0?5:4); p.rect(46,86,44,2,M.CANVAS,3); for(const x of [50,86]) p.rect(x,88,2,6,M.STEEL,3);
      ell(p,66,70,10,6,M.STEEL,(dx,dy)=>dy<-3?5:dx<-4?4:3,{r:.6}); p.rect(65,63,3,2,M.STEEL,5); p.rect(80,64,3,8,M.GLASS,4); p.set(81,62,M.NEONP,5,{e:.3}); p.set(80,61,M.NEONP,4); p.set(82,61,M.RED,4); }
    else { p.line(44,90,88,78,M.CANVAS,4); p.line(44,92,88,80,M.CANVAS,5); p.line(46,94,90,82,M.CANVAS,3); p.line(88,78,94,92,M.STEEL,3); ell(p,30,90,8,4,M.STEEL,(dx,dy)=>dy<-1?5:3,{r:.6});
      for(let k=0;k<8;k++) p.set(96+R(0,14),88+R(0,6),k%2?M.NEONP:M.RED,4); shards(p,90,112,86,8,M.GLASS); p.rect(116,22,4,50,M.WINLIT,4,{e:.6}); }
    return p.s; };
  // 8 경비실: CCTV 화면 벽 · 책상 · 열쇠판 · 의자 — 부서지면 화면이 지지직 흰 잡음과 금, 의자가 넘어지고 커피가 쏟아진다
  const S_sec=b=>{ const p=room({ wall:M.SUIT, wallK:3, ceil:M.SUIT, ceilK:1, floor:M.CURB, floorF:check(4,2,1), side:M.SUIT, sideK:2 });
    for(let r=0;r<2;r++) for(let c=0;c<3;c++){ const x=32+c*24, y=16+r*18; p.rect(x,y,22,16,M.GLASS,0);
      if(b && (r+c)%2===0){ for(let j=2;j<14;j++) for(let q=2;q<20;q++) p.set(x+q,y+j,M.CANVAS,R(2,5),{e:.5}); crack(p,x+11,y+8,5,6,M.CANVAS,5); continue; }
      p.rect(x+2,y+2,18,12,(r+c)%2?M.NEONT:M.WATER,(q,j)=>j%2?3:4,{e:.7});
      if((r*3+c)%2===0){ p.rect(x+6+c*2,y+6,2,5,M.INK,1); p.rect(x+6+c*2,y+5,2,1,M.INK,1); } else p.rect(x+3,y+9,14,1,M.INK,1); p.set(x+18,y+3,M.RED,5,{e:1}); }
    p.rect(14,66,108,12,M.WOODD,(q,j)=>j===0?4:2); p.rect(30,60,18,6,M.MDARK,(q,j)=>j===0?2:1); p.rect(84,62,16,3,M.STEEL,(q)=>q<3?4:2); p.rect(100,61,3,5,M.CANVAS,5,{e:.6});
    if(!b){ p.rect(60,60,5,6,M.CANVAS,4); p.rect(65,62,2,2,M.CANVAS,3); p.rect(26,78,12,10,M.MDARK,(q,j)=>j===0?3:1); p.rect(28,68,8,10,M.MDARK,2); }
    else { p.rect(60,64,6,3,M.CANVAS,4); p.rect(52,66,10,1,M.WOODD,0); for(let y=78;y<86;y++) p.set(62+((y*3)%3),y,M.WOODD,0); p.rect(18,84,14,6,M.MDARK,2); p.rect(30,80,10,4,M.MDARK,1); }
    for(let k=0;k<6;k++) p.rect(4+(k%2)*8,26+Math.floor(k/2)*9,2,5,M.GOLD,4,{e:.15}); p.rect(2,24,18,28,M.WOOD,1);
    return p.s; };
  // 9 직원 식당: 자판기 두 대 · 식탁과 의자 · 메뉴판 — 부서지면 자판기 유리가 박살나 캔이 쏟아지고 식탁이 뒤집힌다
  const S_canteen=b=>{ const p=room({ wall:M.CANVAS, wallF:(x,y)=>(x%9===0||y%9===0)?2:3, ceil:M.FRAME, ceilK:2, floor:M.CURB, floorF:check(5,3,1), side:M.CANVAS, sideK:2 });
    p.rect(40,3,56,2,M.CANVAS,5,{e:.9});
    for(const [x,m,k] of [[30,M.NEONP,0],[58,M.NEONT,1]]){ p.rect(x,18,26,52,M.STEEL,(q,j)=>(q===0||j===0)?4:2); p.rect(x+3,22,16,30,m,(q,j)=>j%8===0?5:3,{e:b&&k===0?.25:.55});
      for(let r=0;r<4;r++) for(let c=0;c<3;c++) if(!(b&&k===0&&(r+c)%2)) p.rect(x+5+c*5,24+r*8,3,4,[M.RED,M.TAXI,M.GRASS,M.WATER][(r+c)%4],4,{e:.3});
      p.rect(x+21,30,3,8,M.MDARK,1); p.rect(x+4,58,16,6,M.INK,0); if(b&&k===0){ crack(p,x+11,36,8,9,M.CANVAS,5); } }
    p.rect(92,16,30,20,M.MDARK,1); for(let k=0;k<4;k++) p.rect(95,19+k*4,18-k*3,1,M.CANVAS,4);
    if(!b){ p.rect(74,70,50,4,M.STEEL,(q,j)=>j===0?5:3); for(const x of [78,118]) p.rect(x,74,2,14,M.STEEL,2); for(const x of [70,124]){ p.rect(x-3,74,8,3,M.RED,4); p.rect(x-3,77,2,12,M.RED,2); } }
    else { p.rect(86,72,4,20,M.STEEL,(q)=>q===0?5:3); for(const y of [74,88]) p.rect(90,y,16,2,M.STEEL,2); p.rect(112,86,10,3,M.RED,4); p.rect(118,80,2,8,M.RED,2);
      for(let k=0;k<12;k++){ const x=26+R(0,50), y=74+R(0,18); p.rect(x,y,3,2,[M.RED,M.TAXI,M.GRASS,M.WATER][k%4],4,{e:.2}); } shards(p,30,60,72,14,M.GLASS); }
    return p.s; };
  // 10 관리실: 나무 판벽 · 큰 창 야경 · 책상 · 초록 등 · 열쇠 보관함 · 청사진 — 부서지면 창에 거미줄 금 · 서류가 흩날리고 등이 쓰러진다
  const S_office=b=>{ const p=room({ wall:M.WOOD, wallF:(x,y)=>(x%14===0)?1:2, ceil:M.WOODD, ceilK:1, floor:M.WOODD, floorF:(u,t)=>((Math.floor(t*12))%2)?2:3, side:M.WOOD, sideK:1 });
    p.rect(30,14,76,42,M.SKY,(q,j)=>j<12?0:1); for(const [x,w,h] of [[32,10,22],[44,8,30],[54,12,18],[68,9,34],[80,12,24],[94,10,28]]){ p.rect(x,56-h,w,h,M.INK,1); for(let k=0;k<w*h/18;k++) p.set(x+1+((k*5)%(w-2)),56-h+2+((k*7)%(h-3)),M.WINLIT,5,{e:.9}); }
    p.rect(30,14,76,2,M.WOODD,1); p.rect(66,14,2,42,M.WOODD,1); p.rect(30,55,76,2,M.WOODD,2);
    p.rect(28,64,80,14,M.WOOD,(q,j)=>j===0?5:j===1?4:2); ell(p,74,62,3,2,M.GOLD,4,{e:.2});
    if(!b){ p.rect(40,60,16,4,M.CANVAS,5); p.rect(44,59,10,1,M.CANVAS,4); p.rect(90,52,10,4,M.IVY,5,{e:.9}); p.rect(94,56,2,8,M.GOLD,3); }
    else { crack(p,50,32,10,14,M.CANVAS,5); crack(p,88,26,7,9,M.CANVAS,5); p.line(96,62,104,56,M.GOLD,3); p.rect(100,52,6,4,M.IVY,4,{e:.6});
      for(let k=0;k<26;k++){ const x=10+R(0,116), y=60+R(0,34); p.rect(x,y,4,2,M.CANVAS,R(4,5)); } }
    p.rect(4,22,16,36,M.GLASS,(q,j)=>(q===0||j===0)?2:1); for(let r=0;r<5;r++) for(let c=0;c<2;c++) p.rect(7+c*7,26+r*6,3,4,M.GOLD,5,{e:.2});
    p.rect(116,24,16,24,M.ARMOR,3); for(let k=0;k<5;k++) p.rect(118,27+k*4,10,1,M.CANVAS,4); p.rect(120,30,1,14,M.CANVAS,4);
    return p.s; };
  for(const [k,f] of Object.entries({ park:S_park, dock:S_dock, lobby:S_lobby, mail:S_mail, mech:S_mech, laundry:S_laundry, room:S_room, sec:S_sec, canteen:S_canteen, office:S_office })){ out['fs_'+k]=f(false); out['fs_'+k+'_b']=f(true); }
  // ── 2구간 식당가(11~20층) 층 풍경: 멀쩡한 모습 · 부서진 모습
  const S_food=b=>{ const p=room({ wall:M.CURT, wallK:2, ceil:M.FRAME, ceilK:2, floor:M.CANVAS, floorF:check(5,3,2), side:M.CURT, sideK:1 });   // 11 푸드코트: 네온 메뉴판 · 계산대 · 쟁반 · 식탁
    for(const x of [34,86]) p.rect(x,2,18,2,M.CANVAS,5,{e:.9});
    [[28,M.NEONO],[56,M.NEONP],[84,M.NEONT]].forEach(([x,m],i)=>{ const dead=b&&i===1; p.rect(x,14,24,12,m,(q,j)=>(q===0||j===0||q===23||j===11)?5:2,{e:dead?.08:.6}); for(let k=0;k<3;k++) p.rect(x+3,17+k*3,14-k*3,1,M.CANVAS,dead?2:5,{e:dead?0:.5}); if(dead) for(let k=0;k<6;k++) p.set(x+R(2,21),14+R(1,10),M.TAXI,5,{e:.9}); });
    p.rect(26,46,84,18,M.STEEL,(q,j)=>j===0?5:j<3?3:2,{ny:.3}); for(const x of [36,64,92]) p.rect(x,42,10,4,M.COAT,3);
    if(!b){ p.rect(14,76,36,4,M.STEEL,(q,j)=>j===0?5:3); for(const x of [16,46]) p.rect(x,80,2,12,M.STEEL,2); p.rect(86,78,36,4,M.STEEL,(q,j)=>j===0?5:3); for(const x of [88,118]) p.rect(x,82,2,10,M.STEEL,2); p.rect(24,72,10,4,M.TAXI,4); p.rect(96,74,10,4,M.RED,4); }
    else { p.rect(14,76,36,4,M.STEEL,(q,j)=>j===0?5:3); for(const x of [16,46]) p.rect(x,80,2,12,M.STEEL,2); p.rect(92,72,4,20,M.STEEL,(q)=>q===0?5:3); p.line(96,74,116,90,M.STEEL,2);
      for(let k=0;k<26;k++) p.rect(54+R(0,60),80+R(0,14),2,2,[M.TAXI,M.RED,M.LEAF,M.CANVAS][k%4],4); p.rect(70,88,12,3,M.STEEL,4); }
    return p.s; };
  const S_kitchen=b=>{ const p=room({ wall:M.STEEL, wallF:(x,y)=>(x%8===0||y%8===0)?2:3, ceil:M.MDARK, ceilK:1, floor:M.CURB, floorF:check(6,2,1), side:M.STEEL, sideK:2 });   // 12 주방: 화구 불꽃 · 걸린 프라이팬 · 김 · 육수 냄비 · 조리대
    p.rect(26,10,84,8,M.STEEL,(q,j)=>j===7?1:4,{ny:-.3}); p.rect(30,18,76,1,M.MDARK,1); for(let i=0;i<6;i++){ const x=34+i*12; p.line(x,19,x,24,M.MDARK,1); ell(p,x,27,4,3,M.MDARK,(dx,dy)=>dy<0?2:1); }
    p.rect(28,50,80,16,M.MDARK,(q,j)=>j===0?3:j<2?2:1,{ny:.2}); p.rect(28,50,80,1,M.STEEL,5); for(const x of [34,50,70,90,104]) p.rect(x,58,3,3,M.STEEL,4); for(const x of [40,60,80,96]){ const tall=b?8:5; for(let k=0;k<tall;k++){ const w=Math.max(1,3-Math.floor(k/2)); p.rect(x-w,48-k,w*2,1,k<2?M.WATER:M.NEONO,k<2?4:5,{e:1}); } }
    ell(p,60,42,8,5,M.STEEL,(dx,dy)=>dy<-2?5:3); p.rect(52,42,16,6,M.STEEL,3);
    for(const [x,y,r] of [[60,30,5],[66,24,4],[56,22,4]]) ell(p,x,y,r,Math.max(2,r-2),M.CANVAS,(dx,dy)=>((dx+dy)&1)?5:4,{e:.15});
    p.rect(96,70,34,6,M.STEEL,(q,j)=>j===0?5:3); for(const x of [98,126]) p.rect(x,76,2,14,M.STEEL,2);
    if(b){ ell(p,60,42,9,5,M.INK,0); for(let y=66;y<90;y++){ const hw=Math.round(4+(y-66)*.9); for(let x=60-hw;x<60+hw;x++) if(rnd()<.85) p.set(x,y,M.TAXI,(x+y)%3?3:4,{ny:.8}); } for(const [x,y] of [[30,84],[44,90],[104,88]]) ell(p,x,y,5,2,M.MDARK,(dx,dy)=>dy<0?2:1); }
    return p.s; };
  const S_freezer=b=>{ const p=room({ wall:M.WATER, wallF:(x,y)=>((x*3+y*7)%11===0)?5:(y%10===0?2:3), ceil:M.FRAME, ceilK:3, floor:M.CANVAS, floorF:(u,t)=>((Math.floor((u+1)*8)+Math.floor(t*6))%5===0)?3:4, side:M.WATER, sideK:2 });   // 13 냉동 창고: 성에 · 고드름 · 쇠 선반 · 얼어붙은 상자 · 차가운 김
    for(let x=4;x<132;x+=5) for(let k=0;k<1+((x*7)%4);k++) p.set(x,8+k,M.CANVAS,5,{e:.25});
    const shelf=(x0,tilt)=>{ for(let k=0;k<3;k++){ const y=24+k*16; p.line(x0,y+(tilt?k*3:0),x0+34,y+(tilt?k*3+8:0),M.STEEL,4); } p.rect(x0,22,2,48,M.STEEL,3); p.rect(x0+33,22,2,48,M.STEEL,3); };
    if(!b){ shelf(26,false); shelf(76,false); for(const [x,y] of [[28,16],[40,16],[80,16],[94,32],[30,48],[82,48],[96,16]]) p.rect(x,y,10,8,M.CANVAS,(q,j)=>j===0?5:4,{e:.1}); }
    else { shelf(76,false); p.line(26,70,50,30,M.STEEL,3); p.line(30,72,58,38,M.STEEL,3); for(const [x,y] of [[82,16],[96,32],[82,48]]) p.rect(x,y,10,8,M.CANVAS,(q,j)=>j===0?5:4,{e:.1});
      for(const [x,y] of [[20,80],[34,86],[48,82],[12,90]]) p.rect(x,y,10,7,M.CANVAS,(q,j)=>j===0?5:3); shards(p,10,70,78,26,M.CANVAS); }
    for(const [x,y,r] of [[30,74,8],[70,78,10],[104,74,7]]) ell(p,x,y,r,3,M.CANVAS,(dx,dy)=>((dx+dy)&1)?5:4,{e:.12});
    return p.s; };
  const S_banquet=b=>{ const p=room({ wall:M.GOLD, wallF:(x,y)=>(((x>>2)+(y>>2))%2)?1:0, ceil:M.WOODD, ceilK:1, floor:M.RED, floorF:(u,t)=>((Math.floor((u+1)*5)+Math.floor(t*6))%2)?2:1, side:M.GOLD, sideK:1 });   // 14 연회장: 금빛 벽 · 붉은 무대 막 · 샹들리에 · 흰 식탁보 · 촛불
    p.rect(44,14,48,48,M.RED,(q,j)=>(q%6<2)?2:3); p.rect(42,12,52,4,M.GOLD,4,{e:.2});
    for(const cx of [30,106]){ const tilt=b&&cx===30?3:0; p.rect(cx-1,0,2,4,M.GOLD,3); for(let i=-3;i<=3;i++){ p.set(cx+i*3+tilt,7+Math.abs(i),M.WINLIT,5,{e:1}); p.set(cx+i*3+tilt,6+Math.abs(i),M.GOLD,4); } }
    const table=(cx,cy,pulled)=>{ if(!pulled){ ell(p,cx,cy,16,4,M.CANVAS,(dx,dy)=>dy<0?5:4,{e:.08}); p.rect(cx-16,cy,32,10,M.CANVAS,(q,j)=>(q%5===0)?3:4); for(const dx of [-8,0,8]){ p.rect(cx+dx,cy-6,1,4,M.CANVAS,5); p.set(cx+dx,cy-7,M.WINLIT,5,{e:1}); } }
      else { ell(p,cx,cy,16,4,M.WOOD,(dx,dy)=>dy<0?4:3); p.rect(cx-2,cy,4,10,M.WOOD,2); for(let y=cy+8;y<96;y++) for(let x=cx-8-(y-cy);x<cx+12;x++) if(rnd()<.8) p.set(x,y,M.CANVAS,4); shards(p,cx-14,cx+16,cy+12,12,M.GLASS); } };
    table(34,74,false); table(100,76,b);
    return p.s; };
  const S_cellar=b=>{ const p=room({ wall:M.BRICK, wallF:(x,y)=>((y%8===0)||((x+(Math.floor(y/8)%2)*6)%12===0))?1:2, ceil:M.BRICK, ceilK:1, floor:M.STONEL, floorF:check(4,1,2), side:M.BRICK, sideK:1 });   // 15 와인 셀러(정전): 아치 · 와인 통 · 병 선반 · 촛불
    for(let x=24;x<112;x++){ const a=Math.round(10*Math.sin(Math.PI*(x-24)/88)); p.set(x,14-a+10,M.STONEL,3); p.set(x,15-a+10,M.STONEL,2); }
    p.rect(48,24,40,40,M.WOODD,1); for(let r=0;r<6;r++) for(let c=0;c<7;c++){ const x=50+c*5, y=26+r*6; ell(p,x+2,y+2,2,2,M.GLASS,1); p.set(x+2,y+2,M.RED,3); }
    const barrel=(x,y,broken)=>{ ell(p,x,y,10,9,M.WOOD,(dx,dy)=>Math.abs(dx)>7?2:(dy<-3?4:3)); for(const dx of [-6,0,6]) for(let dy=-8;dy<=8;dy++) p.set(x+dx,y+dy,M.MDARK,1); if(broken){ ell(p,x,y,5,5,M.INK,0); } };
    barrel(32,66,b); barrel(108,66,false); barrel(32,48,false);
    for(const [x,y] of [[32,38],[108,56],[90,68]]){ p.rect(x,y,2,5,M.CANVAS,4); p.set(x,y-1,M.WINLIT,5,{e:1}); p.set(x+1,y-2,M.NEONO,5,{e:.8}); }
    if(b){ for(let y=72;y<96;y++){ const hw=Math.round(6+(y-72)*1.4); for(let x=38-hw/2;x<38+hw;x++) if(x>=0&&rnd()<.88) p.set(x,y,M.RED,(x+y)%4?2:3,{ny:.9,e:.05}); } shards(p,40,90,80,16,M.GLASS); for(let k=0;k<6;k++) p.rect(56+R(0,24),36+R(0,20),3,2,M.INK,0); }
    return p.s; };
  const S_bar=b=>{ const p=room({ wall:M.MDARK, wallK:1, ceil:M.MDARK, ceilK:0, floor:M.WOODD, floorF:(u,t)=>((Math.floor(t*10))%2)?2:1, side:M.MDARK, sideK:2 });   // 16 바 라운지: 불 켜진 술병 선반 · BAR 네온 · 거울 · 카운터 · 의자
    p.rect(24,8,32,13,M.NEONP,(q,j)=>(q===0||j===0||q===31||j===12)?5:0,{e:b?.25:.7}); signText(p,31,11,'BAR',M.CANVAS,5,{e:b?.2:1});
    for(let r=0;r<3;r++){ p.rect(24,26+r*12,88,1,M.NEONT,4,{e:.7}); for(let k=0;k<14;k++){ if(b && (k+r)%2===0) continue; const x=26+k*6, h=6+((k*7+r*3)%4); p.rect(x,26+r*12-h,3,h,[M.GLASS,M.GRASS,M.TAXI,M.NEONO][(k+r)%4],(q,j)=>j<2?5:3,{e:.25}); } }
    p.rect(60,10,48,10,M.GLASS,(q,j)=>j%3===0?3:2,{e:.15});
    p.rect(20,62,96,10,M.WOOD,(q,j)=>j===0?5:j===1?4:2); p.rect(20,72,96,6,M.WOODD,1);
    for(const x of [34,56,78,100]){ const fall=b&&x===56; if(!fall){ p.rect(x-4,78,8,2,M.RED,4); p.rect(x-1,80,2,10,M.STEEL,3); } else { p.rect(x-6,90,10,2,M.RED,4); p.line(x-2,88,x+8,84,M.STEEL,3); } }
    if(b){ shards(p,24,112,52,30,M.GLASS); for(let y=82;y<96;y++) for(let x=60;x<100;x++) if(rnd()<.6) p.set(x,y,[M.NEONP,M.NEONT,M.TAXI][(x+y)%3],2,{e:.15,ny:.9}); }
    return p.s; };
  const S_lounge=b=>{ const p=room({ wall:M.FRAME, wallK:2, ceil:M.FRAME, ceilK:3, floor:M.CURB, floorF:check(4,3,2), side:M.FRAME, sideK:1 });   // 17 직원 휴게실(쉬는 층): 사물함 · 소파 · 커피 머신 · 벽걸이 TV
    p.rect(50,3,36,2,M.CANVAS,5,{e:.9});
    for(let i=0;i<4;i++){ const x=24+i*9; p.rect(x,22,8,48,M.STEEL,(q,j)=>(q===0||j===0)?4:2); p.rect(x+2,28,4,1,M.MDARK,1); p.rect(x+2,30,4,1,M.MDARK,1); p.rect(x+6,44,1,4,M.MDARK,1); }
    if(b){ p.rect(33,22,8,48,M.INK,0); p.line(42,22,48,30,M.STEEL,4); p.line(42,70,48,64,M.STEEL,4); for(let k=0;k<6;k++) p.set(34+R(0,6),40+R(0,24),M.CANVAS,4); }
    p.rect(70,24,26,16,M.GLASS,(q,j)=>(q===0||j===0)?1:3,{e:.35}); if(b) crack(p,82,32,6,8,M.CANVAS,5);
    if(!b){ p.rect(62,62,40,12,M.BRICK,(q,j)=>j===0?4:2); p.rect(62,56,40,7,M.BRICK,3); p.rect(60,56,4,18,M.BRICK,2); p.rect(100,56,4,18,M.BRICK,2); }
    else { p.rect(62,76,40,10,M.BRICK,(q,j)=>j===0?4:2); p.rect(58,70,8,16,M.BRICK,3); }
    p.rect(108,46,16,26,M.MDARK,(q,j)=>(q===0||j===0)?3:1); p.set(112,50,M.RED,5,{e:1}); p.rect(112,58,8,6,M.INK,0); p.rect(114,64,4,3,M.CANVAS,4);
    if(b){ for(let y=80;y<92;y++) for(let x=108;x<126;x++) if(rnd()<.6) p.set(x,y,M.WOODD,1,{ny:.9}); }
    return p.s; };
  const S_dish=b=>{ const p=room({ wall:M.STONEL, wallF:(x,y)=>(x%7===0||y%7===0)?3:4, ceil:M.FRAME, ceilK:2, floor:M.CANVAS, floorF:(u,t)=>((Math.floor((u+1)*7)+Math.floor(t*7))%2)?3:2, side:M.STONEL, sideK:3 });   // 18 식기 세척실: 접시 더미 · 세척기 · 김 · 젖은 바닥
    p.rect(60,3,24,2,M.CANVAS,5,{e:.9});
    p.rect(56,30,56,36,M.STEEL,(q,j)=>(q===0||j===0)?5:(j<4?4:2),{ny:.2}); p.rect(62,38,44,16,M.MDARK,1); p.rect(64,40,40,12,M.WATER,(q,j)=>j%3?3:4,{e:.3});
    for(const [x,y,r] of [[72,24,6],[86,20,7],[100,26,5]]) ell(p,x,y,r,Math.max(2,r-3),M.CANVAS,(dx,dy)=>((dx+dy)&1)?5:4,{e:.15});
    if(!b){ for(const x of [24,40]) for(let k=0;k<10;k++) ell(p,x+4,70-k*3,8,1,M.CANVAS,(dx,dy)=>dy<0?5:4); }
    else { for(let k=0;k<70;k++){ const x=18+R(0,64), y=74+R(0,20); p.rect(x,y,2+(k%2),1,M.CANVAS,R(4,5),{e:.1}); } for(let k=0;k<4;k++) ell(p,28+k*6,70,8,1,M.CANVAS,4); }
    for(let y=74;y<96;y++) for(let x=40;x<120;x++) if(((x*7+y*3)%9)===0) p.set(x,y,M.WATER,4,{e:.15,ny:.9});
    return p.s; };
  const S_roof=b=>{ const W=136, Hh=96, p=paint(W,Hh);   // 19 루프탑 테라스: 밤하늘 · 스카이라인 · 전구 줄 · 파라솔 · 나무 데크 · 난간
    for(let y=0;y<64;y++) for(let x=0;x<W;x++) p.set(x,y,M.SKY,y<20?0:y<44?1:2);
    for(const [x,w,h] of [[0,14,26],[14,10,34],[26,18,20],[46,12,40],[60,16,24],[78,10,36],[90,18,22],[110,12,30],[122,14,18]]){ p.rect(x,64-h,w,h,M.INK,1); for(let k=0;k<w*h/16;k++) p.set(x+1+((k*5)%Math.max(1,w-2)),64-h+2+((k*7)%Math.max(1,h-3)),M.WINLIT,5,{e:.85}); }
    for(let y=64;y<Hh;y++) for(let x=0;x<W;x++) p.set(x,y,M.WOOD,(y%5===0)?1:(x%40===0?2:3),{ny:.7});
    p.rect(0,60,W,2,M.STEEL,4); for(let x=0;x<W;x+=12) p.rect(x,60,1,8,M.STEEL,3);
    const bulbs=(y0,sag,cut)=>{ for(let x=0;x<W;x++){ if(cut && x>56 && x<80) continue; const y=Math.round(y0+sag*Math.sin(Math.PI*x/W)); p.set(x,y,M.MDARK,1); if(x%8===4) p.set(x,y+1,M.WINLIT,5,{e:1}); } if(cut){ for(let k=0;k<14;k++){ p.set(56,y0+sag*.9+k,M.MDARK,1); if(k%5===4) p.set(56,y0+sag*.9+k+1,M.WINLIT,5,{e:1}); p.set(80,y0+sag*.9+k*.8,M.MDARK,1); } } };
    bulbs(8,10,false); bulbs(16,8,b);
    const umb=(cx,fall)=>{ if(!fall){ for(let dx=-14;dx<=14;dx++){ const y=40+Math.round(Math.abs(dx)*.4); for(let yy=y;yy<y+4;yy++) p.set(cx+dx,yy,((dx+20)>>2)%2?M.RED:M.CANVAS,4); } p.rect(cx,40,1,34,M.STEEL,3); p.rect(cx-10,72,20,3,M.STEEL,4); }
      else { p.line(cx-16,86,cx+14,76,M.STEEL,3); for(let k=0;k<12;k++) p.line(cx-18+k,88,cx-10+k,76,((k>>1)%2)?M.RED:M.CANVAS,4); } };
    umb(34,false); umb(100,b);
    if(b) for(let k=0;k<10;k++) p.rect(60+R(0,50),82+R(0,10),3,2,M.CANVAS,4);
    return p.s; };
  const S_chefroom=b=>{ const p=room({ wall:M.STEEL, wallF:(x,y)=>(x%10===0||y%10===0)?2:3, ceil:M.MDARK, ceilK:1, floor:M.CURB, floorF:check(6,1,2), side:M.STEEL, sideK:2 });   // 20 총주방장실(두목 층): 구리 냄비 · 불꽃 기둥 · 열등 · 주문표 줄
    for(let i=0;i<7;i++){ const x=28+i*12, y=b&&i%3===1?80+((i*5)%8):20; ell(p,x,y+6,5,4,M.GOLD,(dx,dy)=>dy<-1?5:3,{r:.5}); if(!(b&&i%3===1)) p.line(x,12,x,y+2,M.MDARK,1); }
    p.rect(24,52,88,14,M.MDARK,(q,j)=>j===0?3:1,{ny:.2}); p.rect(24,52,88,1,M.STEEL,5); for(const x of [30,46,66,86,102]) p.rect(x,59,3,3,M.GOLD,4); for(const x of [36,56,76,96]){ const tall=b?16:10; for(let k=0;k<tall;k++){ const w=Math.max(1,4-Math.floor(k/3)); p.rect(x-w+((k*3)%3-1),50-k,w*2,1,k<2?M.WATER:k<tall-4?M.NEONO:M.TAXI,k<2?4:5,{e:1}); } }
    p.rect(16,32,8,4,M.RED,5,{e:1}); p.rect(112,32,8,4,M.RED,5,{e:1});
    p.rect(30,8,76,2,M.STEEL,4); for(let k=0;k<8;k++){ if(b && k%2) continue; p.rect(34+k*9,10,6,8,M.CANVAS,5); }
    if(b){ for(let k=0;k<12;k++) p.rect(20+R(0,96),70+R(0,22),5,3,M.CANVAS,5); for(let k=0;k<10;k++) p.set(30+R(0,80),62+R(0,30),M.NEONO,5,{e:.9}); }
    return p.s; };
  for(const [k,f] of Object.entries({ food:S_food, kitchen:S_kitchen, freezer:S_freezer, banquet:S_banquet, cellar:S_cellar, bar:S_bar, lounge:S_lounge, dish:S_dish, roof:S_roof, chefroom:S_chefroom })){ out['fs_'+k]=f(false); out['fs_'+k+'_b']=f(true); }
  // 접시(날아가는 · 4프레임) · 불꽃(3프레임) · 얼음 판
  for(let k=0;k<4;k++){ const p=paint(9,9); p.s.px=4; p.s.py=4; const rx=[4,3,1,3][k], ry=[1,2,4,2][k]; ell(p,4,4,rx,ry,M.CANVAS,(dx,dy)=>(dx*dx+dy*dy<=1)?3:5); out['tw_dish@'+k]=p.s; }
  for(let k=0;k<3;k++){ const p=paint(22,26); p.s.px=11; p.s.py=25; for(let y=0;y<26;y++){ const t=y/25, hw=Math.round(9*Math.sin(Math.PI*Math.min(1,t*1.2))*(0.8+.2*Math.sin(k*2+y*.7))); for(let x=11-hw;x<=11+hw;x++){ const core=Math.abs(x-11)<hw*.45; if(rnd()<(y<6?.6:.95)) p.set(x+((k+y)%3===0?1:0),y,core?(y>16?M.TAXI:M.WINLIT):M.NEONO,core?5:4,{e:1}); } } out['tw_fire@'+k]=p.s; }
  { const p=paint(18,3); for(let x=0;x<18;x++) for(let y=0;y<3;y++) if(!(y!==1 && (x<2||x>15))) p.set(x,y,M.CANVAS,(x*3+y)%4?4:5,{e:.2,ny:.9}); out.tw_ice=p.s; }
  // 날아드는 몸(작아지며 굴러 들어간다): 크기 3 × 회전 4
  { const fig=(h)=>{ const p=paint(Math.ceil(h*.8)+3,h+3), w=p.w, cx=w>>1; p.s.px=cx; p.s.py=h>>1; const hd=Math.max(2,Math.round(h*.18)), bw=Math.max(2,Math.round(h*.3)), bh=Math.round(h*.38);
      const lim=(x0,y0,x1,y1,k)=>{ p.line(x0,y0,x1,y1,M.SUIT,k); if(h>14) p.line(x0+1,y0,x1+1,y1,M.SUIT,k-1); };
      lim(cx-1,hd+1,cx-Math.round(h*.34),Math.round(h*.52),3); lim(cx+1,hd+1,cx+Math.round(h*.36),Math.round(h*.28),3);                 // 팔(허우적)
      lim(cx-1,hd+bh,cx-Math.round(h*.26),h,2); lim(cx+1,hd+bh,cx+Math.round(h*.22),h-1,2);                                             // 다리
      p.rect(cx-(bw>>1),hd,bw,bh,M.COAT,(q,j)=>q===0?4:3); p.rect(cx-(hd>>1),0,hd,hd,M.SKIN,(q,j)=>j===0?4:3);                           // 몸통 · 머리(잘 보이게 밝게)
      for(let y=0;y<h;y++) for(let x=0;x<w;x++){ if(!p.get(x,y)) continue; if(!p.get(x-1,y) && x>0) p.set(x-1,y,M.INK,0); } return p.s; };   // 왼쪽 윤곽선
    [26,18,11].forEach((h,si)=>{ const raw=fig(h); for(let r=0;r<4;r++) out[`fr_body${si}@${r}`]=r?rotSmall(raw,r*90):raw; }); }
  { const p=paint(6,4); p.rect(0,0,6,4,M.TAXI,5,{e:1}); out.fr_hazard=p.s; }
}
// 그리기: 승강로(세로로 흐름) → 층 문들(멈춘 층은 문 뒤 풍경) → 케이블 → 칸 → 칸 위 물건(바늘 · 초과등 · 버튼 · 구급함 · 찌그러짐 · 전등) → 철창 문 → 바닥 물건
function twLamps(){ const T=GS.tower; return TW_LAMPX.map((x,i)=>{ const S=T.lamps[i], len=S.hang?24:4; return { x:x+Math.sin(S.a)*len, y:TWR.CEIL+(TR.dy||0)+Math.cos(S.a)*len+(S.hang?6:4), a:S.a, hang:S.hang, on:!T.dark && !(S.flick>0 && (Math.floor(GS.time*30)%2)), bx:x }; }); }
function twSill(n){ return Math.round(222+(GS.tower.pos-(n-1)*TWR.FH)); }
function drawTowerBack(time){ const T=GS.tower; if(!T) return; const dy=TR.dy||0;
  drawDepth=.95; { const off=((T.pos%150)+150)%150; for(let y=off-150;y<SB.H;y+=150) quad('tw_shaft',0,Math.round(y)); }
  const f0=Math.floor(T.pos/TWR.FH)+1, stopped=T.phase!=='move';
  for(let n=Math.max(1,f0-1);n<=f0+2;n++){ const sill=twSill(n); if(sill<-30||sill>SB.H+110) continue; const here=stopped && n===T.floor, F=TW_FLOORS[n], o=here?T.door:0, dx=Math.round(o*68);
    if(here && F && o>0){ const jx=T.shk>0?Math.round((Math.random()-.5)*4*T.shk/.5):0, jy=T.shk>0?Math.round((Math.random()-.5)*3*T.shk/.5):0;
      drawDepth=.93; quad('fs_'+F.fs+(T.wreck[n]?'_b':''), TWR.G0+jx, sill-96+jy);
      if(F.fs==='park' && T.alarm>0 && Math.floor(time*4)%2===0){ drawDepth=.928; quad('fr_hazard', TWR.G0+64, sill-96+51); quad('fr_hazard', TWR.G0+108, sill-96+51); }
      drawDepth=.925; for(const f of T.fly){ const u=Math.min(1,f.t/f.dur), x=f.x0+(f.x1-f.x0)*u, y=f.y0+(f.y1-f.y0)*u-Math.sin(u*Math.PI)*14, si=u<.34?0:u<.67?1:2; placeAt(`fr_body${si}@${(f.r0+Math.floor(u*6))&3}`, Math.round(x), Math.round(y), false, 0); } }
    drawDepth=.92; quad('tw_ld', TWR.G0-dx, sill-96); quad('tw_ld', TWR.G0+68+dx, sill-96, 1);
    if(o<.4 && SPR['tw_fn@'+Math.min(50,n)]) quad('tw_fn@'+Math.min(50,n), TWR.G0-dx+8, sill-90);
    if(o<.05) quad('tw_leak', TWR.G0, sill-1);
    drawDepth=.91; quad('tw_land', TWR.G0-10, sill-106); }
  drawDepth=.88; quad('tw_cable', 228, dy);
  drawDepth=.3; quad('tw_cab', TWR.CX, TWR.CY+dy);
  drawDepth=.29; const zf=T.pos/TWR.FH, fpos=Math.max(0,Math.min(9, zf-10*Math.floor(Math.min(zf,TW_TOP-1)/10))), ang=-80+fpos*160/9+(T.sagV||0)*1.2;   // 구간마다 1~10
  placeAt('tw_needle@'+djIdx(TW_NEEDLE,ang), 240, 116+dy, false, 0);
  quad('tw_plate@'+Math.max(4,Math.min(9,T.limit||TW_LIMIT)), 94, 130+dy); if(T.over && Math.floor(time*4)%2===0) quad('tw_over', 142, 133+dy);
  { const lit=n0=>{ if(n0<1) return; const n=(n0-1)%10+1, r=4-Math.floor((n-1)/2), c=(n-1)%2; quad('tw_btnL', TWR.PX-8+4+c*7, 145+r*7+dy); };
    lit(Math.min(10,T.floor+(T.phase==='move'?1:0))); if(T.panelT>0) for(let k=0;k<3;k++) lit(1+Math.floor(Math.random()*10)); }
  if(!T.kit) quad('tw_kitB', 356, 134+dy);
  for(const x of T.dent) quad('tw_dent', x-9, 96+dy);
  for(const L of twLamps()){ if(L.hang){ placeAt('tw_hole', L.bx, 96+dy, false, 0); placeAt((L.on?'tw_lampH@':'tw_lampHo@')+djIdx(TW_LAMP_A, L.a*180/Math.PI), L.bx, 100+dy, false, 0); } else placeAt(L.on?'tw_lamp':'tw_lampOff', L.bx, TWR.CEIL+dy, false, 0); }
  drawDepth=.28; quad('tw_gate@'+Math.max(0,Math.min(6,Math.round(T.door*6))), TWR.G0, TWR.GT-2+dy);
  drawDepth=.25; for(const p of (GS.props||[])) if(p.k==='puddle') quad(p.ice?'tw_ice':'sb_puddle', Math.round(p.x), SB.FLOOR-2+dy);
  drawDepth=.22; for(const f of (T.fires||[])) placeAt('tw_fire@'+((Math.floor(time*10)+(f.x>>3))%3), f.x, SB.FLOOR+3+dy, false, 0);   // 플랑베 불꽃
  for(const it of GS.items){ const nm='it_'+it.kind, y=SB.FLOOR+Math.round(it.z||0)-2-Math.round(Math.abs(Math.sin(it.t*4))*2)+dy;
    if(it.kind!=='gear' && SPR[nm]) placeAt(nm, Math.round(it.x), y, false, 0); else if(it.kind==='gear'){ const ic=GITEMS[it.id]&&GITEMS[it.id].icon; placeAt(SPR[ic]?ic:'it_gem', Math.round(it.x), y-4, false, 0); } }
  for(const s of GS.shots){ if(s.friendly){ quad('sb_box', Math.round(s.x)-5, Math.round(s.y)-4+dy); continue; } placeAt('tw_dish@'+(Math.floor(s.t*14)&3), Math.round(s.x), Math.round(s.y)+dy, false, 0); }   /* 타워에선 던지는 게 접시 */
  drawOX=0; drawDepth=0; }
// 광원(7개 한도): 손전등 → 칸 전등 둘 → 문으로 드는 층 불빛(또는 지나가는 층 문틈 빛) → 초과등 → 약한 채움
function towerLights(time){ const T=GS.tower, L=[], dy=TR.dy||0, F=TW_FLOORS[T.floor]||{};
  for(const a of foes()) if(a.e.lamp && !isDown(a) && !a.jug && L.length<2){ const f=a.d.flip?-1:1; L.push({ x:a.d.x+f*12, y:a.d.y-40, z:16, r:230, c:[1,.95,.82], i:T.dark?1.7:.85, spot:[f,.16], cone:.9 }); }
  if(T.dark){ const pu=.7+.3*Math.sin(time*5); L.push({ x:96, y:114+dy, z:20, r:210, c:[1,.1,.06], i:1.55*pu, em:true }); L.push({ x:384, y:114+dy, z:20, r:170, c:[1,.1,.06], i:1.05*pu, em:true }); }
  else for(const lp of twLamps()) if(lp.on) L.push({ x:lp.x, y:lp.y+6, z:18, r:132, c:[1,.88,.7], i:1.7 });
  if(T.alarm>0 && T.phase!=='move' && T.door>.3 && Math.floor(time*4)%2===0) L.push({ x:TWR.G0+90, y:160+dy, z:-20, r:170, c:[1,.62,.12], i:1.4, em:true });   // 차 경보 비상등
  for(const f of (T.fires||[]).slice(0,2)) L.push({ x:f.x, y:206+dy, z:14, r:120, c:[1,.52,.18], i:1.3+Math.random()*.45, em:true });   // 플랑베 불꽃 빛
  if(T.phase!=='move' && T.door>.02){ let col=F.col||[1,1,1], k=1; if(F.strobe){ const bt=GS.time*2.1, bb=Math.floor(bt); col=[[1,.25,.85],[.2,.95,1],[1,.6,.15],[.6,.3,1]][bb%4]; k=1.3*(1-(bt-bb)*.6); } if(F.flame) k*=.82+.36*Math.random();   // 바 네온 · 주방 불꽃 일렁임
    L.push({ x:240, y:172+dy, z:-30, r:220, c:col, i:1.6*T.door*k*(1+(T.fl||0)*2.4) }); L.push({ x:240, y:210+dy, z:22, r:130, c:col, i:.55*T.door*k }); }
  else { const f0=Math.floor(T.pos/TWR.FH)+1; for(let n=f0;n<=f0+1;n++){ const s=twSill(n); if(s<90||s>250) continue; const Fn=TW_FLOORS[n]||{}; L.push({ x:240, y:s-2, z:-22, r:150, c:Fn.col||[1,1,1], i:1.25*Math.max(0,1-Math.abs(s-176)/90) }); } }
  if(T.over && Math.floor(time*4)%2===0) L.push({ x:146, y:136+dy, z:8, r:46, c:[1,.15,.1], i:1.5, em:true });
  L.push({ x:240, y:232, z:12, r:200, c:[.95,.8,.62], i:T.dark?.04:.14 });   // 바닥에서 되튀는 빛
  L.push({ x:240, y:150, z:80, r:300, c:[.58,.64,.8], i:T.dark?.03:.08 });
  return L; }
function towerFX(){ const T=GS.tower, F=TW_FLOORS[T.floor]||{}, vols=[], dy=TR.dy||0, inv=GS.invF>0?1:0; if(GS.invF>0) GS.invF--;
  if(!T.dark) for(const lp of twLamps()) if(lp.on) vols.push({ x:lp.x, y:lp.y+8, dx:Math.sin(lp.a), dy:Math.cos(lp.a), c:[1,.9,.72], i:.15, cone:.74, len:104, halo:8 });
  if(T.phase!=='move' && T.door>.05) vols.push({ x:240, y:152+dy, dx:0, dy:1, c:F.col||[1,1,1], i:.13*T.door, cone:.5, len:72, halo:0 });
  for(const a of foes()) if(a.e.lamp && !isDown(a) && !a.jug){ const f=a.d.flip?-1:1; vols.push({ x:a.d.x+f*12, y:a.d.y-40, dx:f, dy:.16, c:[1,.95,.82], i:T.dark?.22:.09, cone:.9, len:150, halo:4 }); }
  const g=(T.phase!=='move' && T.door>.3 && F.col) ? F.col : [1,.96,.9];
  return { expo:T.dark?.6:1.02, winR:0, winY:[0,0], press:0, bloom:T.dark?1.4:1.0, reflY:SB.FLOOR-1, rain:0, vig:T.dark?.75:.5, fog:.05, fogC:[.08,.08,.1], inv, grade:[.95+.07*g[0],.95+.06*g[1],.95+.06*g[2]], sat:1.03, vols }; }

