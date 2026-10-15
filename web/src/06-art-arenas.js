/* =========================================================
   2-c. MMA 옥타곤 — 중계 메인 카메라 각도의 경기장 (320×180)
   ========================================================= */
const OW=320, OH=180;
function genOctagon(){
  const rnd=mulberry(77), p=paint(OW,OH), out={};
  p.rect(0,0,OW,OH,M.CROWD,0);
  // 관중석: 뒷줄은 작고 어둡게, 케이지에 가까운 줄일수록 크고 빛이 살짝 닿는다
  const rows=[[22,3,0],[29,3,0],[36,4,0],[43,4,1],[50,5,1],[57,5,1],[64,6,2]];
  for(const [y,s,lit] of rows){
    for(let x0=-4; x0<OW+6; x0+=s+1+Math.floor(rnd()*2)){
      const x=x0, yj=rnd()<.3?1:0, r=rnd(), m = r<.1?M.RED : r<.2?M.ARMOR : r<.3?M.CURT : r<.36?M.FRAME : M.CROWD, sk=rnd()<.5?M.SKIN2:M.CROWD;
      p.rect(x-(s>>1), y+yj, s, 4, m, (q,j)=> (m===M.CROWD?1:0)+(j===0?lit:0), {ny:.4});          // 어깨·상의
      const hw=Math.max(2,s-2); p.rect(x-(hw>>1), y+yj-2-(s>4?1:0), hw, 2+(s>4?1:0), sk, (q,j)=> j===0?Math.min(2,lit):0, {ny:.5}); // 머리
    }
  }
  // 천장 트러스 · 조명
  for(let x=18;x<302;x++){ p.set(x,4,M.MDARK,3); p.set(x,9,M.MDARK,2); if((x%6)<1) for(let y=5;y<9;y++) p.set(x,y,M.MDARK,2); }
  for(let x=18;x<302;x+=6) p.line(x,5,x+5,8,M.MDARK,1);
  for(const lx of [64,112,160,208,256]){ p.rect(lx-3,10,7,3,M.MDARK,3); p.rect(lx-2,13,5,1,M.EYE,4,{e:.95}); }
  // 빛줄기(헤이즈): 조명에서 아래로 퍼지는 아주 옅은 점묘
  for(const lx of [112,160,208]) for(let y=15;y<54;y++){ const hw=2+(y-15)*.42;
    for(let x=Math.round(lx-hw);x<=Math.round(lx+hw);x++) if(((x+y*3)%7)===0 && rnd()<.7) p.set(x,y,M.CROWD,5,{e:.06}); }
  // 뒤쪽 펜스: 검은 패드 기둥 · 윗난간 · 철망 · LED 광고판
  const posts=[48,104,160,216,272];
  for(let x=44;x<=276;x++){ p.set(x,55,M.MDARK,4,{r:.6,ny:.6}); p.set(x,56,M.MDARK,2,{r:.6}); }
  for(let y=57;y<92;y++) for(let x=44;x<=276;x++) if(((x+y)%4===0)||(((x-y)%4+4)%4===0)) p.set(x,y,M.WIRE,2,{r:.5});
  const LED=[[M.RED,3],[M.ARMOR,3],[M.GOLD,3],[M.ARMOR,3]];
  for(let k=0;k<4;k++){ const x0=posts[k]+2, x1=posts[k+1]-2, [lm,lt]=LED[k];
    for(let y=92;y<101;y++) for(let x=x0;x<=x1;x++){ const dark=(y===92||y===100)||((x-x0)%9<2&&y>94&&y<98);
      p.set(x,y, dark?M.MDARK:lm, dark?1:(y<96?lt+1:lt), {e:dark?0:.75}); } }
  for(const px of posts) for(let y=53;y<103;y++) for(let q=0;q<4;q++) p.set(px-2+q,y,M.MDARK,q===0?3:(q===3?0:1),{r:.7,nx:q===0?-.5:.2});
  // 캔버스 바닥 (원근 사다리꼴) · 로고 링 · 코너 표시
  for(let y=102;y<151;y++){ const u=(y-102)/48, xl=Math.round(40+(6-40)*u), xr=Math.round(280+(314-280)*u);
    for(let x=xl;x<=xr;x++){ let k=(rnd()<.07)?3:4; if(x===xl||x===xr) k=1;
      const ex=(x-160)/110, ey=(y-126)/17, rr=ex*ex+ey*ey; if(rr>.86&&rr<1) k=2;
      p.set(x,y, (rr>.86&&rr<1)?M.RED:M.CANVAS, k, {ny:.6}); } }
  for(let x=4;x<317;x++){ p.set(x,151,M.MDARK,3,{ny:.6}); for(let y=152;y<160;y++) p.set(x,y,M.MDARK,y<154?1:0); }
  out.oct_bg=p.s;
  // 앞쪽 레이어: 앞 기둥 · 앞 난간 · 앞줄 관중 실루엣 · 휴대폰 불빛
  const f=paint(OW,OH);
  for(const fx of [8,306]) for(let y=56;y<160;y++) for(let q=0;q<6;q++) f.set(fx+q,y,M.MDARK,q===0?4:(q===5?0:1),{r:.7,nx:q===0?-.5:.2});
  for(let x=8;x<312;x++){ f.set(x,56,M.MDARK,3,{r:.6,ny:.6}); f.set(x,57,M.MDARK,1,{r:.6}); }
  for(let x=-6;x<OW+8;x+=11+Math.floor(rnd()*4)){ const hx=x+Math.floor(rnd()*3);
    f.rect(hx-7,170,15,10,M.CROWD,(q,j)=>j===0?2:1,{ny:.4}); f.rect(hx-3,162,7,8,M.CROWD,(q,j)=>j===0?2:(q===0?1:1),{ny:.5});
    if(rnd()<.18){ f.rect(hx+5,158,2,3,M.EYE,4,{e:.9}); f.set(hx+5,161,M.CROWD,2); } }
  out.oct_front=f.s;
  const fl=newSprite(3,3); for(const [x,y] of [[1,0],[0,1],[1,1],[2,1],[1,2]]){ const i=y*3+x; fl.mat[i]=M.EYE; fl.tone[i]=.95; fl.emit[i]=1; } fl.px=1; fl.py=1; fl.mask=.5; out.oct_flash=fl;
  const f1=newSprite(1,1); f1.mat[0]=M.EYE; f1.tone[0]=.9; f1.emit[0]=1; f1.mask=.5; out.oct_flash1=f1;
  return out;
}

/* =========================================================
   2-d. 벨트 스크롤 스테이지: 창고 뒷골목 (1280×180)
   ========================================================= */
const BW=1280, BFLOOR=124; // 바닥 맨 뒤 줄(벽과 만나는 선). 발 y = BFLOOR + z (z 0~48)
function genStage(){
  const rnd=mulberry(131), p=paint(BW,180), out={};
  // 벽: 회녹색 판넬 + 가로 띠 + 볼트 + 얼룩
  p.rect(0,0,BW,BFLOOR,M.VAN,(q,j)=> j<3?2 : (j===34||j===35)?2 : (j%9===0)?3 : 3,{});
  for(let x=0;x<BW;x+=80) for(let y=0;y<BFLOOR;y++){ p.set(x,y,M.VAN,1); p.set(x+1,y,M.VAN,4); }
  for(let x=6;x<BW;x+=16){ p.set(x,8,M.VAN,1); p.set(x,BFLOOR-8,M.VAN,1); }
  for(let k=0;k<70;k++){ const x=Math.floor(rnd()*BW), y=10+Math.floor(rnd()*100), L=3+Math.floor(rnd()*14); for(let j=0;j<L;j++) if(rnd()<1-j/L) p.set(x,y+j,M.VAN,2); }
  // 높은 창 · 환기구
  for(const x of [40,250,470,690,910,1130]){ p.rect(x,12,24,12,M.MDARK,1); for(let q=2;q<24;q+=4) for(let j=1;j<11;j++) p.set(x+q,12+j,M.VAN,4); p.rect(x-1,24,26,1,M.VAN,1); }
  for(const x of [170,410,620,860,1060,1230]){ p.rect(x,70,14,9,M.MDARK,1); for(let q=1;q<14;q+=3) for(let j=1;j<8;j++) p.set(x+q,70+j,M.MDARK,3); }
  // 배관 · 스위치 박스
  for(let x=0;x<BW;x++){ p.set(x,44,M.STEEL,3,{ny:.6}); p.set(x,45,M.STEEL,2); p.set(x,46,M.STEEL,1); if(x%60===0) p.rect(x,42,3,6,M.MDARK,2); }
  for(const x of [356,980]){ for(let y=46;y<74;y++){ p.set(x,y,M.STEEL,2); p.set(x+1,y,M.STEEL,1); } p.rect(x-5,74,12,14,M.FRAME,3); p.rect(x-3,77,8,6,M.FRAME,2); p.rect(x-1,79,3,2,M.MDARK,1); }
  // 사다리 (붉은 철제)
  for(const x of [120,760]){ for(let y=2;y<BFLOOR-2;y++){ p.set(x,y,M.RED,3); p.set(x+1,y,M.RED,1); p.set(x+14,y,M.RED,3); p.set(x+15,y,M.RED,1); }
    for(let y=6;y<BFLOOR-2;y+=7) for(let q=2;q<14;q++){ p.set(x+q,y,M.RED,4); p.set(x+q,y+1,M.RED,1); } }
  // 초록 철문 (2짝) + 위 표지
  for(const x of [300,880]){ p.rect(x-3,58,46,BFLOOR-58,M.MDARK,2); for(const dx of [0,21]){ p.rect(x+dx,61,19,BFLOOR-61,M.GRASS,(q,j)=> q===0?4 : q===18?1 : (j===8||j===30)?2 : 3);
      p.rect(x+dx+4,66,10,8,M.GRASS,2); } p.rect(x+18,80,4,3,M.MDARK,3);
    p.rect(x+8,44,24,9,M.STONE,3); p.rect(x+10,46,4,4,M.GOLD,4,{e:.7}); p.rect(x+16,46,4,4,M.FRAME,4); p.rect(x+22,46,4,4,M.FRAME,4); }
  // 상자 더미 (테이프 · 스텐실)
  const box=(x,y,w,h)=>{ p.rect(x,y,w,h,M.CURT,(q,j)=> j===0?5 : (q===0)?4 : (q===w-1||j===h-1)?1 : 3);
    p.rect(x,y+Math.floor(h/2)-1,w,2,M.FRAME,3); for(let k=0;k<6;k++) p.set(x+5+k*2,y+5,M.PANEL,1); p.rect(x+w-10,y+h-8,6,4,M.RED,2); };
  for(const [x,stack] of [[0,3],[38,2],[520,2],[556,1],[1150,3],[1188,3],[1226,2]]) for(let k=0;k<stack;k++) box(x,BFLOOR-26*(k+1),36,26);
  // 컨베이어 (끝 구역)
  p.rect(1080,BFLOOR-20,60,8,M.ARMOR,(q,j)=> j===0?4:(j<3?3:2)); p.rect(1080,BFLOOR-12,60,12,M.MDARK,(q,j)=> (q%6===0)?3:1);
  // 벽 아래 걸레받이
  for(let x=0;x<BW;x++){ p.set(x,BFLOOR-2,M.VAN,1); p.set(x,BFLOOR-1,M.MDARK,2); }
  // 바닥: 콘크리트 판, 원근 사선 이음매(더블 드래곤처럼)
  for(let y=BFLOOR;y<180;y++){ const u=(y-BFLOOR)/56;
    for(let x=0;x<BW;x++){ let k=(rnd()<.05)?2:3; const sx=((x-(y-BFLOOR)*0.9)%96+96)%96; if(sx<1) k=1;
      if(y===BFLOOR+16||y===BFLOOR+36) k=1; if(y===BFLOOR+17||y===BFLOOR+37) k=4;
      p.set(x,y,M.CURB,k,{ny:.6}); } }
  // 천장 등 (빛나는 갓)
  for(const lx of [110,330,550,770,990,1210]){ p.rect(lx-6,0,13,3,M.MDARK,2); p.rect(lx-4,3,9,2,M.EYE,4,{e:.95}); }
  // (창고 배경은 느와르 거리로 대체되어 굽지 않음)
  for(let k=0;k<0;k++){ const t=newSprite(320,180); t.mask=.5;
    for(let y=0;y<180;y++) for(let x=0;x<320;x++){ const i=y*BW+k*320+x, j=y*320+x; t.mat[j]=p.s.mat[i]; t.tone[j]=p.s.tone[i]; t.emit[j]=p.s.emit[i]; t.nx[j]=p.s.nx[i]; t.ny[j]=p.s.ny[i]; t.rel[j]=p.s.rel[i]; }
    out['st_bg'+k]=t; }
  // 줍기 아이템
  const leg=(rows,piv)=>finish(fromAscii(rows,piv),2);
  out.it_meat=leg(["..rrr..",".ruUur.","rruUurr",".mrrrm.","..FF...",".F..F.."],[3,3]);
  out.it_coin=leg([".hgh.","hgGgh","hG+Gh","hgGgh",".hgh."],[2,2]);
  out.it_bandage=leg([".FFF.","FiiiF","FiFiF","FiiiF",".FFF."],[2,2]);
  return out;
}

// 간판용 5×7 픽셀 글꼴 (대문자 · & · 숫자 일부)
const F57={
A:["01110","10001","10001","11111","10001","10001","10001"],B:["11110","10001","10001","11110","10001","10001","11110"],
C:["01111","10000","10000","10000","10000","10000","01111"],D:["11110","10001","10001","10001","10001","10001","11110"],
E:["11111","10000","10000","11110","10000","10000","11111"],F:["11111","10000","10000","11110","10000","10000","10000"],
G:["01111","10000","10000","10011","10001","10001","01111"],H:["10001","10001","10001","11111","10001","10001","10001"],
I:["11111","00100","00100","00100","00100","00100","11111"],J:["00111","00010","00010","00010","00010","10010","01100"],
K:["10001","10010","10100","11000","10100","10010","10001"],L:["10000","10000","10000","10000","10000","10000","11111"],
M:["10001","11011","10101","10101","10001","10001","10001"],N:["10001","11001","10101","10011","10001","10001","10001"],
O:["01110","10001","10001","10001","10001","10001","01110"],P:["11110","10001","10001","11110","10000","10000","10000"],
Q:["01110","10001","10001","10001","10101","10010","01101"],R:["11110","10001","10001","11110","10100","10010","10001"],
S:["01111","10000","10000","01110","00001","00001","11110"],T:["11111","00100","00100","00100","00100","00100","00100"],
U:["10001","10001","10001","10001","10001","10001","01110"],V:["10001","10001","10001","10001","10001","01010","00100"],
W:["10001","10001","10001","10101","10101","10101","01010"],X:["10001","10001","01010","00100","01010","10001","10001"],
Y:["10001","10001","01010","00100","00100","00100","00100"],Z:["11111","00001","00010","00100","01000","10000","11111"],
'&':["01100","10010","10100","01000","10101","10010","01101"],
'0':["01110","10001","10011","10101","11001","10001","01110"],'1':["00100","01100","00100","00100","00100","00100","01110"],
'3':["11110","00001","00001","01110","00001","00001","11110"],'5':["11111","10000","11110","00001","00001","10001","01110"],
'6':["00110","01000","10000","11110","10001","10001","01110"],'7':["11111","00001","00010","00100","01000","01000","01000"],
'8':["01110","10001","10001","01110","10001","10001","01110"],'9':["01110","10001","10001","01111","00001","00010","01100"],
'.':["00000","00000","00000","00000","00000","01100","01100"],'-':["00000","00000","00000","11111","00000","00000","00000"],' ':["00000","00000","00000","00000","00000","00000","00000"],
'2':["01110","10001","00001","00010","00100","01000","11111"],'4':["00010","00110","01010","10010","11111","00010","00010"],
};
function signText(p,x,y,str,m,k,o={},sc=1){ let cx=x;
  for(const ch of str){ const g=F57[ch]||F57[' '];
    for(let j=0;j<7;j++) for(let i=0;i<5;i++) if(g[j][i]==='1') for(let a=0;a<sc;a++) for(let b=0;b<sc;b++) p.set(cx+i*sc+a,y+j*sc+b,m,k,o);
    cx+=6*sc; }
  return cx-x; }
const textW=(str,sc=1)=>str.length*6*sc-sc;

/* =========================================================
   2-e. 느와르 밤거리 (480×270 화면, 거리 1920px)
   ========================================================= */
const NVW=480, NVH=270, NBW=1920, NFLOOR=196; // 건물 밑선(보도 뒤쪽). 발 y = NFLOOR + z
const NLAMPS=[200,560,940,1300,1680], NOIR_LIGHTS=[];
function genNoir(){
  const rnd=mulberry(907), p=paint(NBW,NVH), out={};
  // 밤하늘 (건물 사이로 조금만 보인다)
  p.rect(0,0,NBW,NVH,M.SKY,(q,j)=> j<20?1:0);
  // --- 건물들 ---
  const win=(x,y,w,h,lit,o={})=>{ // 창: 틀 · 유리(켜지면 따뜻한 빛) · 블라인드/커튼 실루엣
    p.rect(x-1,y-1,w+2,h+2,o.frame||M.STONEL,1); p.rect(x,y,w,h,lit?M.COAT:M.GLASS,(q,j)=> lit ? (j<2?5:4) : (j<2?2:1),{e:lit?.32:0});
    for(let q=x+Math.floor(w/2);q<=x+Math.floor(w/2);q++) for(let j=y;j<y+h;j++) p.set(q,j,o.frame||M.STONEL,1);
    if(lit && rnd()<.6){ const sx=x+2+Math.floor(rnd()*(w-6)); for(let j=y+h-7;j<y+h;j++) for(let q=sx;q<sx+4;q++) p.set(q,j,M.WOODD,1,{e:.08}); } // 실내 실루엣
    if(lit && rnd()<.55) for(let j=y+2;j<y+h;j+=3) for(let q=x;q<x+w;q++) if(rnd()<.9) p.set(q,j,M.COAT,3,{e:.2});            // 블라인드 결
    if(lit) for(let j=y;j<y+h;j++) for(let q=x;q<x+w;q+=Math.max(6,Math.floor(w/4))) p.set(q,j,o.frame||M.STONEL,1);      // 창살
    p.rect(x-2,y+h+1,w+4,2,o.frame||M.STONEL,(q,j)=>j?0:2); };
  const bricks=(x0,y0,w,h)=>{ for(let y=y0;y<y0+h;y++) for(let x=x0;x<x0+w;x++){ const r=y%5===0, c=((x+(Math.floor(y/5)%2)*4)%8===0);
    p.set(x,y,M.BRICK, r||c ? 1 : (rnd()<.12?3:2)); } };
  const ivy=(x0,x1,y0,len)=>{ for(let x=x0;x<x1;x++){ const L=Math.floor(len*(.3+rnd()*.9)); for(let j=0;j<L;j++) if(rnd()<.8-j/L*.5) p.set(x,y0+j,M.IVY, rnd()<.25?3:(rnd()<.5?2:1),{ny:.3}); } };
  // B1 0~330: 밝은 석재 가구점 (흰 간판 + 위아래 형광등)
  p.rect(0,0,330,NFLOOR,M.STONEL,(q,j)=> (j%14===0)?2:3);
  for(const x of [30,110,190,270]) win(x,22,40,34,rnd()<.45);
  p.rect(0,92,330,4,M.STONEL,1); p.rect(6,100,318,40,M.FRAME,(q,j)=> j<2||j>37?2:4,{});
  p.rect(6,97,318,2,M.FRAME,5,{e:.95}); p.rect(6,142,318,2,M.FRAME,5,{e:.95});                                // 형광등
  signText(p,165-textW('KIM & SONS',3)/2,106,'KIM & SONS',M.DARK,1,{},3);
  for(const yy of [131]) for(let x=40;x<290;x++) if(x<120||x>210) p.set(x,yy,M.DARK,1);
  p.rect(20,150,44,NFLOOR-150,M.STONEL,1); p.rect(24,154,36,NFLOOR-154,M.NEONT,1); p.rect(28,158,28,14,M.GLASS,2); p.rect(52,174,2,3,M.GOLD,3); // 문
  p.rect(40,146,10,3,M.FRAME,5,{e:.9});                                                                           // 문 위 등
  p.rect(150,152,160,38,M.WOODD,0); p.rect(152,154,156,34,M.GLASS,0);                                              // 쇼윈도(어두움)
  { // 원형 네온 (주황): 둥근 테두리 + 글씨
    const cx=230, cy=170, R=15; for(let a=0;a<360;a+=3){ const t=a*Math.PI/180; p.set(cx+Math.round(R*Math.cos(t)), cy+Math.round(R*.8*Math.sin(t)), M.NEONO,5,{e:1}); }
    signText(p,cx-textW('LAW')/2,cy-8,'LAW',M.NEONO,5,{e:1}); signText(p,cx-textW('OFFICE')/2,cy+1,'OFFICE',M.NEONO,4,{e:.9}); }
  // B2 330~700: 어두운 벽돌 + 석조 기둥 + 담쟁이 + 움푹한 입구
  bricks(330,0,370,NFLOOR);
  for(const x of [330,450,580,690]) p.rect(x,0,12,NFLOOR,M.STONEL,(q,j)=> q===0?3:q===11?0:(j%20===0?1:2));
  p.rect(330,84,370,10,M.STONEL,(q,j)=>j===0?3:j===9?0:2); p.rect(330,140,370,6,M.STONEL,(q,j)=>j===0?3:1);
  for(const x of [350,470,600]) win(x,20,84,48,x===470,{frame:M.WOODD});
  ivy(342,690,94,40); ivy(380,560,0,18);
  p.rect(470,150,90,NFLOOR-150,M.WOODD,0); p.rect(490,158,50,NFLOOR-158,M.WOODD,1); p.rect(495,163,40,NFLOOR-168,M.WOODD,(q,j)=>q===20?0:2);
  p.rect(600,160,40,NFLOOR-160,M.WOODD,0);
  // B3 700~1000: 붉은 벽돌 약국 (청록 네온 간판, 밝은 쇼윈도)
  bricks(700,0,300,NFLOOR);
  for(const x of [720,800,880,950]) win(x,24,40,38,rnd()<.6,{frame:M.STONEL});
  p.rect(700,92,300,4,M.STONEL,2);
  p.rect(718,112,264,26,M.NEONT,1); signText(p,850-textW('DRUGSTORE',2)/2,118,'DRUGSTORE',M.NEONT,5,{e:1},2);
  p.rect(722,100,14,30,M.MDARK,1); p.rect(725,104,8,22,M.NEONT,4,{e:.8});                                          // 튀어나온 작은 간판
  p.rect(730,150,90,40,M.STONEL,1); p.rect(733,153,84,34,M.COAT,(q,j)=> j<3?5:4,{e:.4});                       // 밝은 쇼윈도
  for(let k=0;k<6;k++){ const bx=740+k*12; p.rect(bx,172,8,12,[M.RED,M.ARMOR,M.GOLD,M.GRASS,M.FRAME,M.RED][k],2,{e:.25}); }
  p.rect(880,150,48,NFLOOR-150,M.STONEL,1); p.rect(884,154,40,NFLOOR-154,M.NEONT,1); p.rect(888,158,32,16,M.GLASS,2); // 문
  p.rect(940,166,6,8,M.FRAME,2); // 초인종
  // 골목 1000~1050: 어둠 · 비상계단
  p.rect(1000,0,50,NFLOOR,M.SUIT,(q,j)=> j>NFLOOR-30?1:0);
  for(let y=30;y<150;y+=34){ p.rect(1004,y,42,2,M.MDARK,3); for(let x=1004;x<1046;x+=3) p.rect(x,y-10,1,10,M.MDARK,2); p.line(1006,y+2,1040,y+32,M.MDARK,2); }
  // B4 1050~1360: 호텔 (세로 붉은 네온, 차양)
  p.rect(1050,0,310,NFLOOR,M.STONEL,(q,j)=> (q%30===0)?1:(j%10===0?2:3));
  for(let r=0;r<2;r++) for(const x of [1070,1130,1190,1250,1310]) win(x,20+r*44,30,32,rnd()<.4);
  p.rect(1336,24,18,100,M.MDARK,1); 'HOTEL'.split('').forEach((ch,k)=>signText(p,1342,30+k*19,ch,M.RED,5,{e:1}));
  p.rect(1140,140,120,10,M.RED,(q,j)=> j===0?3:((q>>3)%2?2:1)); p.rect(1140,150,120,2,M.MDARK,1);                // 차양
  p.rect(1176,152,48,NFLOOR-152,M.WOODD,0); p.rect(1180,156,40,NFLOOR-156,M.COAT,(q,j)=>q===20?1:4,{e:.3});   // 유리문(로비 불빛)
  signText(p,1200-textW('HOTEL')/2,128,'HOTEL',M.GOLD,4,{e:.6});
  // B5 1360~1660: 바 (분홍 네온 BAR, 벽돌, 포스터)
  bricks(1360,0,300,NFLOOR);
  for(const x of [1380,1460,1540,1610]) win(x,26,36,40,rnd()<.5,{frame:M.WOODD});
  p.rect(1360,100,300,4,M.STONEL,2);
  signText(p,1450,116,'BAR',M.NEONP,5,{e:1},3); p.rect(1446,112,62,2,M.NEONP,4,{e:.9}); p.rect(1446,142,62,2,M.NEONP,4,{e:.9});
  p.rect(1540,150,50,NFLOOR-150,M.WOODD,0); p.rect(1544,154,42,NFLOOR-154,M.WOODD,2); p.rect(1552,160,26,14,M.COAT,4,{e:.35});
  for(const [x,c] of [[1400,M.FRAME],[1418,M.GOLD],[1610,M.FRAME]]){ p.rect(x,150,14,20,c,3); for(let j=153;j<168;j+=3) for(let q=x+2;q<x+12;q++) if(rnd()<.6) p.set(q,j,M.DARK,1); }
  // B6 1660~1920: 극장 (전구 테두리 간판)
  p.rect(1660,0,260,NFLOOR,M.STONEL,(q,j)=> j%16===0?1:2);
  for(const x of [1680,1760,1840]) win(x,22,50,44,rnd()<.5);
  p.rect(1690,96,200,40,M.MDARK,1); signText(p,1790-textW('CINEMA',3)/2,104,'CINEMA',M.FRAME,4,{e:.35},3);
  for(let x=1690;x<1890;x+=5){ p.set(x,96,M.WINLIT,5,{e:1}); p.set(x,135,M.WINLIT,5,{e:1}); }
  for(let y=96;y<136;y+=5){ p.set(1690,y,M.WINLIT,5,{e:1}); p.set(1889,y,M.WINLIT,5,{e:1}); }
  p.rect(1740,150,100,NFLOOR-150,M.WOODD,0); p.rect(1745,154,90,NFLOOR-156,M.COAT,(q,j)=>(q%30===0)?1:4,{e:.28});
  // 건물 사이 홈통 · 그림자
  for(const x of [330,700,1000,1050,1360,1660]) for(let y=0;y<NFLOOR;y++) p.set(x,y,M.SUIT,0);
  // --- 보도 · 연석 · 젖은 도로 ---
  for(let y=NFLOOR;y<NFLOOR+30;y++) for(let x=0;x<NBW;x++){ const seam=(x%32===0)||(y===NFLOOR+15);
    p.set(x,y,M.CURB, seam?0:(y<NFLOOR+2?0:(rnd()<.08?2:1)),{ny:.6}); }
  for(let x=0;x<NBW;x++){ p.set(x,NFLOOR+30,M.CURB,4,{ny:.7}); p.set(x,NFLOOR+31,M.CURB,1); p.set(x,NFLOOR+32,M.ROADW,0); }
  for(let y=NFLOOR+33;y<NVH;y++) for(let x=0;x<NBW;x++) p.set(x,y,M.ROADW, rnd()<.06?2:1,{ny:.6});
  for(let k=0;k<26;k++){ const cx=Math.floor(rnd()*NBW), cy=NFLOOR+40+Math.floor(rnd()*30), rx=10+Math.floor(rnd()*26), ry=2+Math.floor(rnd()*3);
    for(let y=-ry;y<=ry;y++) for(let x=-rx;x<=rx;x++) if(x*x/(rx*rx)+y*y/(ry*ry)<=1) p.set(cx+x,cy+y,M.ROADW,5,{ny:.6}); } // 웅덩이 (톤이 높으면 반사가 강함)
  for(let x=0;x<NBW;x+=48) for(let q=0;q<22;q++) p.set(x+q,NFLOOR+58,M.ROADW,3);                                   // 흐린 차선
  // --- 거리 소품 ---
  const can=(x)=>{ p.rect(x,NFLOOR-2,12,16,M.MDARK,(q,j)=> q===0?3:(j%4===0?1:2)); p.rect(x-1,NFLOOR-4,14,2,M.MDARK,3); };
  for(const x of [120,640,1010,1480]) can(x);
  for(const x of [300,860,1580]){ for(let k=0;k<5;k++) p.set(x+k*3,NFLOOR+10+(k%2),M.FRAME,3); p.rect(x,NFLOOR+8,12,3,M.FRAME,2); } // 신문지
  for(const x of [420,1120,1760]){ p.rect(x,NFLOOR+2,3,6,M.GRASS,2,{e:.1}); p.set(x+1,NFLOOR,M.GRASS,3); p.rect(x+5,NFLOOR+4,2,4,M.WOODD,3); } // 병
  for(const x of [760]){ p.rect(x,NFLOOR+2,8,10,M.RED,2); p.rect(x+1,NFLOOR,6,2,M.RED,3); }                         // 소화전
  // 가로등 (곡선 팔 + 등갓)
  for(const lx of NLAMPS){ for(let y=58;y<NFLOOR+12;y++){ p.set(lx,y,M.MDARK,3); p.set(lx+1,y,M.MDARK,1); }
    p.rect(lx-3,NFLOOR+6,8,6,M.MDARK,2); p.line(lx,58,lx-2,52,M.MDARK,3); p.line(lx-2,52,lx-8,50,M.MDARK,3); p.line(lx-8,50,lx-12,54,M.MDARK,3);
    p.rect(lx-16,54,9,3,M.MDARK,2); p.rect(lx-15,57,7,2,M.WINLIT,5,{e:1}); }
  // 배경을 480px 타일로
  for(let k=0;k<4;k++){ const t=newSprite(NVW,NVH); t.mask=.5;
    for(let y=0;y<NVH;y++) for(let x=0;x<NVW;x++){ const i=y*NBW+k*NVW+x, j=y*NVW+x; t.mat[j]=p.s.mat[i]; t.tone[j]=p.s.tone[i]; t.emit[j]=p.s.emit[i]; t.nx[j]=p.s.nx[i]; t.ny[j]=p.s.ny[i]; }
    out['nb'+k]=t; }
  // 앞쪽 주차 차량 실루엣 (택시)
  const car=paint(150,40);
  car.rect(10,14,130,16,M.TAXI,(q,j)=> j===0?4:j<4?3:2); car.rect(40,2,62,13,M.TAXI,(q,j)=> j===0?3:2);
  car.rect(46,5,24,9,M.GLASS,1); car.rect(74,5,24,9,M.GLASS,1); car.rect(64,0,14,3,M.FRAME,3,{e:.2});
  for(let q=12;q<138;q+=4) car.set(q,24,M.MDARK,1); for(const wx of [32,112]){ car.rect(wx-11,24,22,16,M.MDARK,(q,j)=> j<3?2:0); car.rect(wx-5,29,10,6,M.STEEL,2); }
  car.rect(136,18,4,3,M.WINLIT,5,{e:.9}); car.rect(10,18,3,3,M.RED,4,{e:.8});
  out.n_car=car.s; out.n_car.px=0; out.n_car.py=40;
  // 광원 목록 (세계 좌표)
  NOIR_LIGHTS.length=0;
  for(const lx of NLAMPS) NOIR_LIGHTS.push({x:lx-11,y:58,kind:'lamp'});
  NOIR_LIGHTS.push({x:165,y:120,kind:'tube'},{x:230,y:170,kind:'neonO'},{x:850,y:125,kind:'neonT'},{x:775,y:170,kind:'shop'},{x:1345,y:80,kind:'neonR'},
    {x:1200,y:170,kind:'shop'},{x:1478,y:128,kind:'neonP'},{x:1790,y:116,kind:'bulb'},{x:1790,y:172,kind:'shop'},{x:45,y:150,kind:'door'});
  return out;
}

