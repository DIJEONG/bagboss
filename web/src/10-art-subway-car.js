function genSubway(){
  const rnd=mulberry(5150), out={};
  CAR_CONCEPTS.forEach((C,ci)=>{
    const p=paint(SB.W,98); const Y=v=>v-SB.CAR_Y; // 화면 y → 스프라이트 y
    // 지붕 · 천장 · 형광등
    p.rect(0,0,SB.W,4,M.MDARK,(q,j)=>j===0?4:2,{ny:.6});
    p.rect(0,4,SB.W,6,C.cab?M.STEEL:M.FRAME,(q,j)=> C.neon?1:(j<1?2:3));
    if(C.neon) p.rect(0,4,SB.W,6,M.NEONP,(q,j)=>((q>>3)%2)?2:1,{e:.15});
    for(const [k,x] of [[0,40],[1,160],[2,280],[3,400]]){ const broken=(C.broken&&k===2);
      p.rect(x,6,48,2,C.works?M.TAXI:(C.neon?M.NEONP:M.FRAME),broken?1:5,{e:broken?0:(C.works?.6:.95)}); }
    // 광고 띠 (천장과 창 사이)
    p.rect(0,10,SB.W,Y(SB.WIN_Y0)-10,C.wall,C.wallK-1);
    for(let x=14;x<SB.W-40;x+=58){ if(DOORS.some(([a,b])=>x+44>a-4&&x<b+4)) continue; const am=C.ad[Math.floor(rnd()*C.ad.length)];
      p.rect(x,11,44,8,M.FRAME,4); p.rect(x+1,12,42,6,am,3,{e:C.neon?.5:.08}); for(let q=x+4;q<x+30;q+=2) if(rnd()<.7) p.set(q,14,M.FRAME,5,{e:C.neon?.4:0});
      p.rect(x+32,13,8,4,M.FRAME,(C.neon?5:4),{e:C.neon?.4:0}); }
    // 손잡이 가로봉
    for(let x=6;x<SB.W-6;x++) p.set(x,Y(155),M.STEEL,4,{ny:.5});
    // 뒷벽 (창 아래)
    p.rect(0,Y(SB.WIN_Y0),SB.W,Y(SB.FLOOR)-Y(SB.WIN_Y0),C.wall,(q,j)=> (j%8===0)?C.wallK-1:C.wallK);
    // 창(구멍) — 창밖 레이어가 비친다
    const wins=[[18,100],[160,320],[382,462]];
    for(const [a,b] of wins){ const n=Math.max(1,Math.round((b-a)/72)), step=(b-a)/n;
      for(let k=0;k<n;k++){ const x=Math.round(a+k*step)+3, w=Math.round(step)-6;
        p.rect(x-2,Y(SB.WIN_Y0)-2,w+4,(SB.WIN_Y1-SB.WIN_Y0)+4,M.STEEL,(q,j)=> j===0||q===0?4:2);
        for(let y=Y(SB.WIN_Y0);y<Y(SB.WIN_Y1);y++) for(let q=x;q<x+w;q++) p.s.mat[y*SB.W+q]=0; } }
    // 옆문: 문틀만 남기고 구멍(문짝은 따로 그려서 정차 때 열린다)
    for(const [a,b] of DOORS){ p.rect(a-3,Y(SB.WIN_Y0)-4,b-a+6,Y(SB.FLOOR)-Y(SB.WIN_Y0)+4,M.STEEL,(q,j)=>q<2||q>b-a+3?3:1);
      for(let y=Y(SB.WIN_Y0)-2;y<Y(SB.FLOOR);y++) for(let q=a;q<b;q++) p.s.mat[y*SB.W+q]=0;
      for(let q=a-3;q<b+3;q++) p.set(q,Y(SB.FLOOR)-1,M.TAXI,3); }
    // 좌석 (등받이 · 방석 · 받침)
    const seatRuns=[[14,104],[154,326],[376,466]];
    if(!C.cab) for(const [a,b] of seatRuns){
      p.rect(a,Y(191),b-a,15,C.seat,(q,j)=> j===0?4:(q%16===0?1:3),{ny:.3});
      p.rect(a,Y(206),b-a,4,C.seat,(q,j)=> j===0?5:3,{ny:.7});
      p.rect(a+2,Y(210),b-a-4,10,M.STEEL,(q,j)=> j===0?2:(q%20<2?2:1)); }
    // 기둥 (문 옆)
    for(const x of [104,154,326,376]) for(let y=10;y<Y(SB.FLOOR);y++){ p.set(x,y,M.STEEL,4,{r:.5}); p.set(x+1,y,M.STEEL,2,{r:.5}); }
    // 바닥 · 차체 아랫단
    p.rect(0,Y(SB.FLOOR)-2,SB.W,4,C.floor,(q,j)=> j<1?3:2,{ny:.7});
    p.rect(0,Y(SB.FLOOR)+2,SB.W,14,M.MDARK,(q,j)=> j===0?3:(j<3?1:0));
    // 양 끝 연결문
    for(const x of [0,SB.W-12]){ p.rect(x,4,12,Y(SB.FLOOR)-4,M.STEEL,(q,j)=> q===0||q===11?1:3); p.rect(x+3,Y(SB.WIN_Y0),6,22,M.GLASS,2); }
    // 칸별 소품
    if(C.graffiti){ // 큰 낙서 태그 (등받이 · 기둥 사이 벽)
      for(const [tx,ty,txt,m,sc] of [[24,Y(193),'NOX',M.NEONP,2],[176,Y(194),'K2',M.GRASS,2],[236,Y(192),'RAT',M.GOLD,2],[392,Y(194),'ZZ',M.NEONT,2],[290,Y(196),'NO',M.RED,1]])
        signText(p,tx,ty,txt,m,3,{},sc);
      for(const x of [60,250,430]){ p.rect(x,Y(SB.FLOOR)-5,3,4,M.GRASS,2,{e:.15}); p.rect(x+6,Y(SB.FLOOR)-3,8,2,M.FRAME,3); } }
    if(C.graffiti) for(let k=0;k<40;k++){ const gx=20+Math.floor(rnd()*440), gy=Y(SB.WIN_Y1)+2+Math.floor(rnd()*14); if(p.get(gx,gy)===0) continue;
      const gm=[M.NEONP,M.GRASS,M.NEONT,M.GOLD,M.RED][k%5]; for(let s=0;s<9;s++) p.set(gx+s, gy+Math.round(Math.sin(s*.9+k)*2), gm,3); }
    if(C.neon){ // 광고로 감싼 칸: 기둥 사이 벽마다 아이돌 포스터(하트 · 얼굴 실루엣)
      for(const x of [106,156,328,378]) p.rect(x-1,Y(SB.WIN_Y0),2,Y(SB.FLOOR)-Y(SB.WIN_Y0),M.NEONT,4,{e:.6});
      for(const [x,w] of [[18,82],[160,160],[382,80]]) for(let y=Y(SB.WIN_Y1)+1;y<Y(191);y++) for(let q=x;q<x+w;q++) p.set(q,y,M.NEONP,((q+y)>>2)%2?4:3,{e:.25});
      const heart=(cx,cy,m)=>{ for(const [dx,dy] of [[-2,0],[-1,-1],[1,-1],[2,0],[-2,1],[-1,1],[0,1],[1,1],[2,1],[-1,2],[0,2],[1,2],[0,3],[0,0]]) p.set(cx+dx,cy+dy,m,5,{e:.9}); };
      for(const x of [40,120,220,300,420]) heart(x,Y(SB.WIN_Y0)-6,M.FRAME); }
    if(C.neon) for(const x of [36,206,256,406]){ p.rect(x,Y(193),26,12,M.MDARK,1); p.rect(x+2,Y(195),22,8,M.NEONT,4,{e:.85}); for(let q=x+4;q<x+22;q+=3) p.set(q,Y(198),M.NEONP,5,{e:1}); }
    if(C.cargo){ for(const [x,w,h] of [[66,14,9],[300,16,8],[440,12,9]]){ p.rect(x,Y(SB.FLOOR)-2-h,w,h,M.CURT,(q,j)=> j===0?4:(q%3===0?2:3),{r:.4}); p.rect(x+w/2-1,Y(SB.FLOOR)-2-h-2,3,2,M.CURT,1); } // 자루
      p.rect(250,Y(SB.FLOOR)-14,30,10,M.WOOD,(q,j)=>j===0?4:2,{r:.5}); for(const wx of [254,274]) p.rect(wx,Y(SB.FLOOR)-4,4,4,M.MDARK,3); }
    if(C.cargo) for(const [x,w,h,m] of [[30,22,16,M.WOOD],[54,18,12,M.CURT],[190,26,18,M.WOOD],[220,16,10,M.RED],[290,20,14,M.CURT],[400,24,20,M.WOOD],[426,16,12,M.GRASS]]){
      p.rect(x,Y(SB.FLOOR)-2-h,w,h,m,(q,j)=> j===0?4:(q===0?3:(q===w-1||j===h-1)?1:2),{r:.4}); p.rect(x,Y(SB.FLOOR)-2-Math.floor(h/2),w,1,M.FRAME,3,{r:.4}); }
    if(C.works){ // 뜯겨 나간 벽 패널: 안쪽 배선이 드러남 · 사다리
      for(const [x,w] of [[24,40],[200,56],[400,46]]){ p.rect(x,Y(192),w,16,M.MDARK,0); for(let k=0;k<5;k++){ let y=Y(194)+k*3; for(let q=x+2;q<x+w-2;q++){ if(rnd()<.15) y+=rnd()<.5?1:-1; p.set(q,Math.max(Y(193),Math.min(Y(206),y)),[M.RED,M.TAXI,M.ARMOR,M.GRASS,M.FRAME][k],3); } } }
      for(let y=Y(SB.WIN_Y0);y<Y(SB.FLOOR)-2;y++){ p.set(166,y,M.TAXI,3); p.set(176,y,M.TAXI,3); if(y%6===0) for(let q=166;q<=176;q++) p.set(q,y,M.TAXI,4); } }
    if(C.works){ for(let x=0;x<SB.W;x+=2) p.set(x,Y(SB.FLOOR)-3,(x>>2)%2?M.TAXI:M.MDARK,4);
      for(let k=0;k<7;k++){ const x0=30+k*64; let y=10; for(let s=0;s<26;s++){ y+=rnd()<.5?1:0; p.set(x0+s,y+Math.round(Math.sin(s*.4)*2),[M.RED,M.TAXI,M.ARMOR][k%3],3); } }
      for(const x of [60,180,300,420]){ p.rect(x,Y(193),10,6,M.TAXI,5,{e:.8}); p.rect(x+2,Y(199),6,3,M.MDARK,2); } }
    if(C.banners){ for(const bx of [118,238,358]){ if(DOORS.some(([a,b])=>bx+14>a-2&&bx<b+2)) continue;           // 창 사이 기둥에 붉은 깃발 · 금실 테 · 구름 무늬
        p.rect(bx,Y(SB.WIN_Y0)-4,14,40,M.RED,(q,j)=>q===0||q===13||j===0?5:(j%9===4&&q>3&&q<10?5:3)); p.rect(bx+1,Y(SB.WIN_Y0)-3,12,1,M.GOLD,4,{e:.15}); p.rect(bx+1,Y(SB.WIN_Y0)+34,12,1,M.GOLD,4,{e:.15});
        for(let j=0;j<4;j++) p.rect(bx+4+((j%2)*2),Y(SB.WIN_Y0)+6+j*7,4,2,M.GOLD,4,{e:.12}); for(let q=0;q<14;q+=3) p.rect(bx+q,Y(SB.WIN_Y0)+36,2,3,M.GOLD,3); } }
    if(C.scratch){ for(let k=0;k<26;k++){ const x0=20+Math.floor(rnd()*440), y0=Y(SB.WIN_Y0)+2+Math.floor(rnd()*22); if(DOORS.some(([a,b])=>x0>a-2&&x0<b+2)) continue;
        let x=x0, y=y0; for(let q=0;q<10+Math.floor(rnd()*14);q++){ if(p.get(x,y)===0) p.set(x,y,M.FRAME,3,{e:.05}); x+=1; y+=rnd()<.4?(rnd()<.5?-1:1):0; } } }      // 스크래치티
    if(C.cab){ p.rect(300,10,170,Y(SB.FLOOR)-12,M.STEEL,3); for(let y=Y(SB.WIN_Y0)-6;y<Y(SB.WIN_Y1)+4;y++) for(let q=316;q<462;q++) p.s.mat[y*SB.W+q]=0;
      p.rect(310,Y(SB.WIN_Y1)+6,160,12,M.MDARK,2); for(let k=0;k<9;k++) p.rect(318+k*16,Y(SB.WIN_Y1)+9,6,4,[M.GRASS,M.RED,M.GOLD,M.NEONT][k%4],5,{e:.9}); }
    out['car_'+C.key]=p.s;
  });
  // 문짝(반쪽) — 작은 창 포함
  { const p=paint(17,SB.FLOOR-SB.WIN_Y0+2); p.rect(0,0,17,p.h,M.STEEL,(q,j)=> q===0?4:(q===16?1:3)); p.rect(3,6,11,22,M.GLASS,1);
    for(let y=7;y<27;y++) for(let q=4;q<13;q++) p.s.mat[y*17+q]=0; p.rect(0,p.h-4,17,2,M.TAXI,3); out.sb_door=p.s; }
  // 손잡이(고리+끈) — 위 끝이 회전축
  { const s=fromAscii(["z","z","z","z","z","z","z","szs","s.s","szs"],[0,0]); bakeRot(s,2).forEach((r,a)=>out['sb_strap@'+a]=r);
    out.sb_strapseg=fromAscii(["z","z","z","z","z","z"],[0,0]); }
  { const p=paint(8,80); for(let y=0;y<80;y++) for(let x=0;x<8;x++){ const pl=(y%4); p.set(x,y,M.MDARK, pl===0?3:pl===3?1:2); } p.rect(0,0,8,2,M.STEEL,2); p.rect(0,78,8,2,M.STEEL,2); out.sb_gangway=p.s; }   // 주름진 고무 연결 통로                                                              // 손잡이 끈 연장 조각
  // 창밖: 터널 벽 타일 (가로로 흐른다) — 링 이음매 · 케이블 트레이 · 비상구 표지 · 거리 표지 · 배전함
  { const p=paint(SB.W,SB.H);
    p.rect(0,0,SB.W,SB.H,M.VAN,(q,j)=> j<14?0:(j>246?0:((j%22===0)?1:(rnd()<.05?3:2))));
    for(let x=0;x<SB.W;x+=80) for(let y=14;y<246;y++){ p.set(x,y,M.VAN,0); p.set(x+1,y,M.VAN,4); if(y%30===0){ p.set(x+4,y,M.STEEL,4); p.set(x-3,y,M.STEEL,4); } }
    for(const [y0,cols] of [[84,[M.MDARK,M.RED,M.MDARK,M.ARMOR,M.MDARK]],[192,[M.MDARK,M.GOLD,M.MDARK]]]){
      for(let x=0;x<SB.W;x++){ p.set(x,y0-1,M.STEEL,3); cols.forEach((m,k)=>p.set(x,y0+k,m,k%2?3:2)); p.set(x,y0+cols.length,M.STEEL,1); }
      for(let x=10;x<SB.W;x+=40){ p.rect(x,y0-3,2,cols.length+5,M.STEEL,2); } }
    for(const x of [30,270]){ p.rect(x,150,18,22,M.MDARK,2); p.rect(x+2,152,14,8,M.FRAME,3); p.rect(x+5,162,8,6,M.RED,2,{e:.15}); }
    for(const x of [150,390]){ p.rect(x,110,22,9,M.MDARK,1); p.rect(x+1,111,20,7,M.GRASS,4,{e:.9}); p.line(x+5,114,x+15,114,M.FRAME,5,{e:.9}); p.line(x+12,112,x+15,114,M.FRAME,5,{e:.9}); p.line(x+12,116,x+15,114,M.FRAME,5,{e:.9}); }
    for(const x of [90,330]){ p.rect(x,124,16,10,M.FRAME,4); signText(p,x+2,125,'2',M.MDARK,1); signText(p,x+8,125,'4',M.MDARK,1); }
    for(let x=0;x<SB.W;x+=32) p.rect(x,240,8,4,M.MDARK,1);
    out.sb_tunnel=p.s;
    // 빨리 달릴 때: 가로로 번진 잔상 타일 (밝기를 가로로 끌어 줄무늬로)
    const bl=newSprite(SB.W,SB.H); bl.mask=.5;
    for(let y=0;y<SB.H;y++){ let acc=0, n=0; const row=[];
      for(let x=0;x<SB.W*2;x++){ const i=y*SB.W+(x%SB.W); acc=acc*.82+p.s.tone[i]*.18; if(x>=SB.W) row[x-SB.W]=acc; }
      for(let x=0;x<SB.W;x++){ const i=y*SB.W+x; bl.mat[i]=p.s.mat[i]; bl.tone[i]=row[x]; bl.emit[i]=p.s.emit[i]*.6; bl.ny[i]=p.s.ny[i]; } }
    out.sb_tunnelB=bl; }
  // 터널등 (창 높이로 지나간다) · 빠를 때의 빛 꼬리
  { const l=paint(6,4); l.rect(0,0,6,4,M.MDARK,2); l.rect(1,1,4,2,M.WINLIT,5,{e:1}); out.sb_lamp=l.s;
    const st=paint(46,2); for(let x=0;x<46;x++){ st.set(x,0,M.WINLIT,5,{e:1-x/50}); st.set(x,1,M.WINLIT,4,{e:.8-x/60}); } out.sb_streak=st.s; }
  // 정차역 플랫폼 (밝은 타일벽 · 역명판 · 기둥 · 의자)
  for(const [k,name] of []){ const p=paint(960,SB.H);
    p.rect(0,0,960,SB.H,M.CONC,(q,j)=> j<40?1:((q%12===0||j%12===0)?3:4));
    p.rect(0,40,960,6,M.MDARK,2);
    for(let x=0;x<960;x+=120){ p.rect(x+40,46,26,180,M.CONC,(q,j)=> q===0?5:(q===25?2:4)); }
    for(const x of [120,600]){ p.rect(x,126,170,26,M.ARMOR,(q,j)=> j===0||j===25?1:2,{e:.08}); signText(p,x+85-textW(name)/2,135,name,M.FRAME,5,{e:.5}); }
    for(let x=0;x<960;x+=60) p.rect(x+10,48,30,3,M.FRAME,5,{e:.9});
    for(const x of [30,330,780]){ p.rect(x,196,40,6,M.WOOD,3); p.rect(x+4,202,3,12,M.MDARK,2); p.rect(x+33,202,3,12,M.MDARK,2); }
    p.rect(0,226,960,6,M.TAXI,(q,j)=>((q>>3)%2)?4:1,{e:.15}); p.rect(0,232,960,40,M.CURB,2);
    out['sb_station'+k]=p.s; }
  // 선로(레일은 바퀴 바닥 높이) · 침목 · 자갈
  { const p=paint(SB.W,34); p.rect(0,0,SB.W,34,M.ASPH,(q,j)=> rnd()<.14?2:(rnd()<.08?3:1));
    for(let x=0;x<SB.W;x+=20){ p.rect(x,21,13,5,M.WOODD,(q,j)=>j===0?3:2); p.set(x+3,22,M.STEEL,3); p.set(x+9,22,M.STEEL,3); }
    for(let x=0;x<SB.W;x++){ p.set(x,18,M.STEEL,5,{r:.6}); p.set(x,19,M.STEEL,4); p.set(x,20,M.STEEL,2); p.set(x,21,M.MDARK,1); }
    out.sb_track=p.s; }
  // 대차: 측면 프레임 · 코일 스프링 · 차축 상자 · 제동 블록 · 바퀴(테 · 플랜지 · 바큇살 · 허브 볼트). 회전 8장
  for(let f=0;f<8;f++){ const p=paint(76,30), C=[[20,18],[56,18]];
    for(const [cx,cy] of C){ for(let y=-11;y<=11;y++) for(let x=-11;x<=11;x++){ const r=Math.hypot(x,y); if(r>11.2) continue;
        const k = r>10.2 ? 1 : r>9.0 ? (x+y<-4?5:3) : r>8.0 ? 2 : r<2.4 ? 4 : r<3.4 ? 2 : 3;                     // 플랜지 · 테(위 왼쪽 반짝) · 바퀴판 · 허브
        p.set(cx+x,cy+y,M.STEEL,k,{r:r>9&&r<=10.2?.5:0, e: r>9&&r<=10.2 ? (x+y<-4?.42:.2) : r>10.2 ? .1 : r<2.4 ? .25 : .06}); }   // 어두운 차 밑에서도 테 · 허브 윤곽이 읽히게
      for(let s2=0;s2<6;s2++){ const t=(s2*60+f*7.5)*Math.PI/180; for(let r=3.6;r<8;r+=.5) p.set(cx+Math.round(r*Math.cos(t)),cy+Math.round(r*Math.sin(t)),M.MDARK,0); }   // 바큇살 사이 구멍(돌아간다)
      for(let s2=0;s2<4;s2++){ const t=(s2*90+45+f*7.5)*Math.PI/180; p.set(cx+Math.round(1.6*Math.cos(t)),cy+Math.round(1.6*Math.sin(t)),M.STEEL,5); }
      p.rect(cx-4,cy-4,8,7,M.STEEL,(q,j)=>j===0?4:(q===7?1:3),{e:.12}); p.set(cx-2,cy-2,M.STEEL,5,{e:.3});                        // 차축 상자
      for(const sd of [-1,1]) p.rect(cx+sd*12-(sd>0?0:2),cy-6,3,10,M.WOODD,(q,j)=>j===0?3:1); }                                   // 제동 블록
    for(let x=4;x<72;x++){ const y0=x<12?6+(12-x)*.4:x>64?6+(x-64)*.4:6; for(let y=Math.round(y0);y<12;y++) p.set(x,y,M.MDARK,y===Math.round(y0)?3:(y===11?0:1)); }   // 측면 프레임
    p.rect(30,3,16,9,M.MDARK,(q,j)=>j===0?3:1); for(const sx of [33,42]) p.set(sx,6,M.STEEL,4);                                    // 가운데 받침
    for(const [cx] of C){ for(let y=0;y<6;y++) for(const dx of [-3,-2,2,3]) p.set(cx+dx+(y%2?1:0)*Math.sign(dx),y,M.STEEL,y%2?4:2); } // 코일 스프링
    p.line(10,13,66,13,M.MDARK,1); out['sb_bogie'+f]=p.s; }
  // 제동 불꽃(희게 · 노랗게 · 주황으로 식는다)
  for(const [k,m,t] of [[0,M.FRAME,5],[1,M.GOLD,5],[2,M.NEONO,4]]){ const sp=newSprite(3,1); sp.px=1; sp.py=0; sp.mask=.5; for(let i=0;i<3;i++){ sp.mat[i]=m; sp.tone[i]=T6[t]; sp.emit[i]=1; } out['fx_spark'+k]=sp; }
  // 굴러다니는 캔 · 병(투척)
  { const c=paint(5,3); c.rect(0,0,5,3,M.RED,(q,j)=>j===0?4:2); c.set(0,1,M.STEEL,4); out.sb_can=c.s; out.sb_can.px=2; out.sb_can.py=2;
    const b=fromAscii(["..F..",".gGg.",".gGg.","gGhGg","gGhGg","gGhGg","gGGGg",".ggg."],[2,4]); b.mask=.5; for(let i=0;i<b.emit.length;i++) if(b.mat[i]) b.emit[i]=.35;
    bakeRot(b,2,{outline:true}).forEach((r,k)=>{ for(let i=0;i<r.emit.length;i++) if(r.mat[i]) r.emit[i]=Math.max(r.emit[i],.3); out['sb_bottle@'+k]=r; }); }
  genDojo(out); genCross(out); genTower(out);
  return out;
}

