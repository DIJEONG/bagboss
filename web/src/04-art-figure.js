// 선수 v2: 키 약 59px · 머리 17px. 파츠별 외곽선 없이 굽고, 외곽선은 합성 단계의 캐릭터 선 노드가 실루엣에 한 줄만 그린다
const F2ART = {
  f2_torso_1: [[
    "....kccck.....",
    "...kkcCCck....",
    "..kcCCCCCck...",
    ".kcCCCCKKCck..",
    ".kcCCCKKKCCck.",
    ".kccCCCKCCjCk.",
    ".kccCCCCjjCck.",
    ".kccCCCCCCCck.",
    "..kcCCCcCCck..",
    "..kcCCCjCCck..",
    "..kccCCcCCk...",
    "..kccCCjCck...",
    "..kkcCCcCck...",
    "...kccCCCck...",
    "...kkcCCcck...",
    "...FFFFFFFF...",
    "...mrrruurm...",
    "...mrrruurm...",
    "...mrrurrrm...",
    "...mmrrrrmm...",
  ],[7,18]],
  f2_torso_2: [[
    "........kccck.......",
    ".......kkcCCck......",
    "....kkkcCCCCCckkk...",
    "..kkcCCCKKCCKKCCckk.",
    ".kcCCCKKKKCKKKKCCCck",
    ".kcCCCCKKCjCKKCCCCck",
    ".kcCCCCCjjjjjCCCCCck",
    ".kcCCCCCCCCCCCCCCCck",
    "..kcCCCCCcCcCCCCCck.",
    "..kcCCCCCjCjCCCCck..",
    "...kcCCCCcCcCCCCk...",
    "...kcCCCCjCjCCCck...",
    "...kkcCCCcCcCCCck...",
    "....kccCCCCCCCck....",
    "....kkccCCCCCcck....",
    "....FFFFFFFFFFFF....",
    "....mrrrruuurrrm....",
    "....mrrrruuurrrm....",
    "....mrrrruurrrrm....",
    "....mmrrrrrrrrmm....",
  ],[10,18]],
  f2_head: [[
    "....n.nnnn.n...",
    "...nNnNNyNnNn..",
    "..nNNNyyNNNNNn.",
    ".nNNNNNNyNNNNn.",
    ".nNNnNNNNNnNNNn",
    "nnNnnNNNnnNNnn.",
    "nNnnnnnccnnccn.",
    "nnnkcCCCCCCCCc.",
    "nnkcjkCCnnCCnn.",
    "nkcjckCCCCiioC.",
    "nkcckCCCCCCCCKc",
    ".kkkcCCCCCCCCc.",
    "..kjkcCCCCCnnc.",
    "...kjkcCCCCCc..",
    "....kjkkcccc...",
    ".....kkkkk.....",
  ],[7,15]],
  f2_torso: [[
    "......kccck.......",
    ".....kkcCCck......",
    "...kkcCCCCCCckk...",
    "..kcCCCCKKCCCCck..",
    ".kcCCCKKKKCCCCCck.",
    ".kcCCCCKKCCCjCCCk.",
    ".kcCCCCCCjjjCCCck.",
    ".kcCCCCCCCCCCCCck.",
    ".kccCCCCcCCcCCck..",
    "..kcCCCCjCCjCCck..",
    "..kccCCCcCCcCCk...",
    "..kccCCCjCCjCck...",
    "..kkcCCCcCCcCck...",
    "...kccCCCCCCck....",
    "...kkccCCCCcck....",
    "...FFFFFFFFFFF....",
    "...mrrruuurrrm....",
    "...mrrruuurrrm....",
    "...mrrruurrrrm....",
    "...mmrrrrrrrmm....",
  ],[8,18]],
  f2_upper: [[
    "..ccC.",
    ".cCCKc",
    "kcCCKC",
    "kcCCCC",
    "kcCCCk",
    ".kcCCk",
    ".kcCck",
    ".kcCck",
    ".kccck",
    "..kck.",
  ],[3,1]],
  f2_fore: [[
    "..kcCk..",
    "..kcCk..",
    "..kcCk..",
    "..kccC..",
    "..kcCk..",
    "..kcck..",
    ".FFFFFF.",
    "mrruUUrm",
    "mrruUUur",
    "mrrruuur",
    "mrrrrrrm",
    "mmrrrrmm",
    ".mmrrmm.",
    "..mmmm..",
  ],[3,0]],
  f2_thigh: [[
    "mrrrrrm.",
    "mrruurm.",
    ".kcCCck.",
    ".kcCCck.",
    ".kcCCck.",
    ".kcCCck.",
    ".kcCCck.",
    ".kccCck.",
    "..kcCck.",
    "..kcCk..",
    "..kcck..",
    "..kcck..",
  ],[3,0]],
  f2_shin: [[
    ".kcCk....",
    ".kcCCk...",
    ".kcCCk...",
    ".kcCCk...",
    ".kccCk...",
    "..kcCk...",
    "..kcCk...",
    "..kccCk..",
    "..kcCCk..",
    ".kcCCCck.",
    ".kcCCCCck",
    ".kkcccccc",
    "..kkkkkk.",
  ],[3,0]],
};
const BRART = {
  br_fore: [[
    "..kcCk.",
    "..kcCk.",
    "..kcCk.",
    "..kccC.",
    "..kcCk.",
    "..kcck.",
    ".kcCCk.",
    "kcCKCck",
    "kcCCCck",
    "kkcccck",
    ".kkkkk.",
  ],[3,0]],
  it_bat: [[
    ".v.",
    ".w.",
    ".w.",
    ".w.",
    "vwv",
    "wWw",
    "wWw",
    "wWw",
    "wWw",
    "wWw",
    "wWw",
    "vWv",
    ".v.",
  ],[1,1]],
  it_knife: [[
    ".w.",
    ".w.",
    "zSz",
    ".S.",
    ".S*",
    ".S*",
    ".S.",
    ".s.",
  ],[1,1]],
};
const NART = {
  n_head_fed: [[
    "....TTTTTTT....",
    "...TVVXXXXVT...",
    "...TVVXXXXXT...",
    "...TmmmmmmmT...",
    ".TTVVVVVVVVVVTT",
    "TTTTTTTTTTTTTT.",
    "nnnnccccccccc..",
    "nnnkcCCCCCCCCc.",
    "nnkcjkCCnnCCnn.",
    "nkcjckCCCCiioC.",
    "nkcckCCCCCCCCKc",
    ".kkkcCCCCCCCCc.",
    "..kjkcCCCCCnnc.",
    "...kjkcCCCCCc..",
    "....kjkkcccc...",
    ".....kkkkk.....",
  ],[7,15]],
  n_head_cap: [[
    "...............",
    "....TTTTTT.....",
    "...TVVXXXXVT...",
    "..TVVXXXXXXVT..",
    "..TTVVVVVVVVXXX",
    "..TTTTTTTTTTTTT",
    "nNnnnccccccccn.",
    "nnnkcCCCCCCCCc.",
    "nnkcjkCCnnCCnn.",
    "nkcjckCCCCiioC.",
    "nkcckCCCCCCCCKc",
    ".kkkcCCCCCCCCc.",
    "..kjkcCCCCCnnc.",
    "...kjkcCCCCCc..",
    "....kjkkcccc...",
    ".....kkkkk.....",
  ],[7,15]],
  n_tail: [[
    "EIJJJJJJJI.",
    "EIJJOJJJJIE",
    "EIJJOJJJJIE",
    "EIJJOJJJJJIE",
    "EIJJOJJJJJIE",
    "EIJJOJJJJJJIE",
    "EIJJOJJJJJJIE",
    "EIJJOJJJJJJJIE",
    "EIJJOJJJJJJJIE",
    "EIJJOJJJJJJJJIE",
    "EIIIJJJJJJJJIIE",
    "EEEEIIIIIIIEEEE",
  ],[5,0]],
};
const SPR = {};
function buildSprites(){
  // 거리 싸움꾼: 피부 일부를 민소매(ARMOR) · 트렁크를 청바지(DARK) · 허리밴드를 벨트 · 발을 운동화로 — 톤은 그대로 두고 재질만 바꾼다
  const recolor=(rows,piv,fn)=>{ const s=fromAscii(rows,piv); for(let y=0;y<s.h;y++){ let L=s.w,Rr=-1; for(let x=0;x<s.w;x++) if(s.mat[y*s.w+x]){ L=Math.min(L,x); Rr=Math.max(Rr,x); }
      for(let x=0;x<s.w;x++){ const i=y*s.w+x; if(s.mat[i]) fn(s,i,x,y,L,Rr); } } return s; };
  const toTank=(s,i,x,y,L,Rr)=>{ const m=s.mat[i];
    if(m===M.SKIN && y>=4 && y<=14 && !(y<=6 && (x-L<2 || Rr-x<2))) s.mat[i]=M.ARMOR;
    else if(m===M.FRAME){ s.mat[i]=M.MDARK; s.tone[i]=.5; } else if(m===M.RED) s.mat[i]=M.DARK; };
  ['f2_torso','f2_torso_1','f2_torso_2'].forEach((k,v)=>{ const [rows,piv]=F2ART[k]; const t=autoNormals(recolor(rows,piv,toTank)); t.mask=1; SPR['br_torso_'+v+'@0']=t; });
  const bakeBoth=(name,raw,rawB)=>{ bakeRot(raw,2,{outline:false}).forEach((s,a)=>{ s.mask=1; SPR[name+'@'+a]=s; }); bakeRot(rawB,2,{outline:false}).forEach((s,a)=>{ s.mask=1; SPR[name+'B@'+a]=s; }); };
  const toJeans=(s,i)=>{ s.mat[i]=M.DARK; };
  const toShin=(s,i,x,y)=>{ s.mat[i] = y<=9 ? M.DARK : y>=12 ? M.MDARK : M.FRAME; };
  const dark=(fn)=>(s,i,x,y,L,Rr)=>{ fn(s,i,x,y,L,Rr); s.tone[i]=Math.max(.05,s.tone[i]-1/7.2); };
  bakeBoth('br_thigh', recolor(...F2ART.f2_thigh,toJeans), recolor(...F2ART.f2_thigh,dark(toJeans)));
  bakeBoth('br_shin', recolor(...F2ART.f2_shin,toShin), recolor(...F2ART.f2_shin,dark(toShin)));
  bakeBoth('br_fore', fromAscii(...BRART.br_fore), fromAscii(darker(BRART.br_fore[0]),BRART.br_fore[1]));
  for(const k of ['it_bat','it_knife']) bakeRot(fromAscii(...BRART[k]),2,{outline:false}).forEach((s,a)=>{ s.mask=1; SPR[k+'@'+a]=s; });
  // 느와르 캐릭터: 머리(중절모·헌팅캡)는 원화, 몸통은 v2 실루엣만 빌려 코트를 새로 칠한다(옷깃 · 셔츠 · 넥타이 · 단추 · 벨트)
  for(const k of ['n_head_fed','n_head_cap']){ const h=autoNormals(fromAscii(...NART[k])); h.mask=1; SPR[k+'@0']=h; }
  ['f2_torso','f2_torso_1','f2_torso_2'].forEach((k,v)=>{ const [rows,piv]=F2ART[k], src=fromAscii(rows,piv), t=newSprite(src.w,src.h); t.px=src.px; t.py=src.py; t.mask=1;
    const cx=piv[0]+[1,1,0][v], T=(i,m,tone)=>{ t.mat[i]=m; t.tone[i]=tone; };
    for(let y=0;y<src.h;y++){ let L=src.w,Rr=-1; for(let x=0;x<src.w;x++) if(src.mat[y*src.w+x]){ L=Math.min(L,x); Rr=Math.max(Rr,x); }
      for(let x=L;x<=Rr;x++){ const i=y*src.w+x; if(!src.mat[i]) continue;
        let tone = x===L ? .22 : x===Rr ? .5 : x>cx+1 ? .66 : x<L+3 ? .36 : .5; if(x===Rr-1 && y>2) tone=.82;
        T(i,M.COAT,tone);
        const dv=Math.abs(x-cx), vw=y<=2?2:y<=5?1:y<=8?0:-1;                    // V자 앞섶
        if(y>=1 && dv<=vw){ T(i, dv===0&&y>=2 ? M.RED : M.FRAME, dv===0&&y>=2 ? .4 : .7); }
        else if(y>=1 && y<=9 && dv===vw+1) T(i,M.COAT,.22);                       // 옷깃 선
        if(y<=1 && (x<=L+1||x>=Rr-1)) T(i,M.COAT,.66);                             // 세운 칼라
        if(x===cx+1 && (y===11||y===14)) T(i,M.MDARK,.5);                          // 단추
        if(y===src.h-5) T(i, x===cx||x===cx+1 ? M.MDARK : M.COAT, x===cx||x===cx+1 ? .6 : .36); // 벨트
      } }
    SPR['n_torso_'+v+'@0']=autoNormals(t); SPR['n_torso_'+v+'@0'].mask=1; });
  { const mk=(rows,piv,fn)=>{ const s=fromAscii(rows,piv); for(let y=0;y<s.h;y++) for(let x=0;x<s.w;x++){ const i=y*s.w+x; if(s.mat[i]) fn(s,i,x,y); } return s; };
    const dk=fn=>(s,i,x,y)=>{ fn(s,i,x,y); s.tone[i]=Math.max(.05,s.tone[i]-1/7.2); };
    // 소매는 몸통과 같은 코트라도 톤을 달리해 팔 모양이 읽히게: 기본 한 단 어둡게, 앞(오른쪽) 가장자리 밝게, 뒤 가장자리 짙게
    const edge=(s,x,y)=>{ let L=s.w,Rr=-1; for(let q=0;q<s.w;q++) if(s.mat[y*s.w+q]){ L=Math.min(L,q); Rr=Math.max(Rr,q); } return [L,Rr]; };
    const sleeveTone=(s,i,x,y)=>{ const [L,Rr]=edge(s,x,y); s.mat[i]=M.COAT; s.tone[i]= x===Rr ? .66 : x===L ? .22 : x===L+1 ? .36 : .42; };
    const sleeve=(s,i,x,y)=>sleeveTone(s,i,x,y), fore=(s,i,x,y)=>{ if(y<=6) sleeveTone(s,i,x,y); };
    const trou=(s,i)=>{ s.mat[i]=M.SUIT; }, shin=(s,i,x,y)=>{ if(y<=9) s.mat[i]=M.SUIT; else { s.mat[i]=M.MDARK; if(y===10) s.tone[i]=.66; } };
    const both=(name,rows,piv,fn)=>{ bakeRot(mk(rows,piv,fn),2,{outline:false}).forEach((q,a)=>{ q.mask=1; SPR[name+'@'+a]=q; });
      bakeRot(mk(rows,piv,dk(fn)),2,{outline:false}).forEach((q,a)=>{ q.mask=1; SPR[name+'B@'+a]=q; }); };
    both('n_upper',...F2ART.f2_upper,sleeve); both('n_fore',...BRART.br_fore,fore);
    both('n_thigh',...F2ART.f2_thigh,trou); both('n_shin',...F2ART.f2_shin,shin);
    bakeRot(fromAscii(...NART.n_tail),2,{outline:false}).forEach((q,a)=>{ q.mask=1; SPR['n_tail@'+a]=q; }); }
  // 선수 v2: 머리·몸통은 똑바로 한 장만(얼굴 픽셀 보존), 팔·다리는 외곽선 없이 32방향
  for(const [k,[rows,piv]] of Object.entries(F2ART)){
    const upright = k==='f2_head'||k.startsWith('f2_torso');
    if(upright){ const s=autoNormals(fromAscii(rows,piv)); s.mask=1; SPR[k+'@0']=s; continue; }
    bakeRot(fromAscii(rows,piv),2,{outline:false}).forEach((s,a)=>{ s.mask=1; SPR[k+'@'+a]=s; });
    bakeRot(fromAscii(darker(rows),piv),2,{outline:false}).forEach((s,a)=>{ s.mask=1; SPR[k+'B@'+a]=s; });
  }
  const ROT_ART=new Set(['k_head','k_torso','s_skull','s_rib','mk_head','mk_torso','ms_skull','ms_rib','f_head','f_torso']);
  for(const [k,[rows,piv]] of Object.entries(ART)){
    if(ROT_ART.has(k)) bakeRot(fromAscii(rows,piv),4).forEach((s,a)=>SPR[k+'@'+a]=s);
    else SPR[k]=finish(fromAscii(rows,piv), 4);
  }
  SPR.s_shield = finish(fromAscii(roundShield(),[6,6]), 3);
  for(const [k,[rows,piv,cap]] of Object.entries(LIMB)){
    bakeRot(fromAscii(rows,piv),cap).forEach((s,a)=> SPR[k+'@'+a]=s);
    if(/(arm|thigh|shin|upper|fore)$/.test(k))
      bakeRot(fromAscii(darker(rows),piv),cap).forEach((s,a)=> SPR[k+'B@'+a]=s);
  }
  // 색이 다른 숫자: 치명타(금색) · 회복(초록) · 화상(주황)
  for(const [set,leg] of [['C','G'],['H','e'],['B','R']]) for(const [ch,rows] of Object.entries(GLYPH)){
    const s = finish(fromAscii(rows.map(r=>r.replace(/#/g, set==='H'?'h':leg)),[0,0]),1,'ink'); s.mask=.5;
    if(set==='H') for(let i=0;i<s.mat.length;i++) if(s.mat[i]===M.GOLD){ s.mat[i]=M.GRASS; s.tone[i]=.9; s.emit[i]=1; }
    if(set==='B') for(let i=0;i<s.mat.length;i++) if(s.mat[i]===M.RED){ s.mat[i]=M.GOLD; s.tone[i]=.55; s.emit[i]=1; }
    SPR['g'+set+ch]=s; }
  for(const [ch,rows] of Object.entries(GLYPH)){
    const s = finish(fromAscii(rows.map(r=>r.replace(/#/g,'e')),[0,0]),1,'ink'); s.mask=.5; SPR['g'+ch]=s; // UI 숫자는 캐릭터 테두리에서 제외
  }
  SPR.torch0 = finish(fromAscii([".f.","fGf","GRG",".R.",".w.",".v.",".w."],[1,2]),1,'ink');
  SPR.torch1 = finish(fromAscii(["f..",".fG","GRG",".R.",".w.",".v.",".w."],[1,2]),1,'ink');
  // 스미어 · 타격 스파크 · 먼지
  SPR.smearK_a = genSmear(30, 8, 105, 212, M.GOLD);  SPR.smearK_b = genSmear(30, 4, 62, 132, M.GOLD);
  SPR.smearS_a = genSmear(29, 7, 105, 212, M.STEEL); SPR.smearS_b = genSmear(29, 4, 62, 132, M.STEEL);
  SPR.it_potion = finish(fromAscii(["..ww..",".ssss.","..ss..",".srrs.","srrRrs","srRrrs","srrrrs",".ssss."],[3,4]),2);
  SPR.it_gem = finish(fromAscii([".AAAA.","A!AAaq","AAaaaq",".aaaq.","..aq.."],[3,2]),2);
  SPR.it_stone = finish(fromAscii(["..zssss..",".zsSSSsz.","zsssssszz",".zzzzzzz."],[4,2]),2);
  // 느와르 잔상: 칼 궤적 대신 발·주먹의 움직임만 남기는 가는 점선 호(a)와 짧은 속도선(b)
  { const arc=(R,th0,th1)=>{ const N=2*R+3, c=R+1, s=newSprite(N,N); s.px=c; s.py=c; s.mask=.5;
      for(let a=th0;a<=th1;a+=2){ const t=a*Math.PI/180, x=c+Math.round(R*Math.sin(t)), y=c+Math.round(R*Math.cos(t)); if((a/2)%3===2) continue; const i=y*N+x; s.mat[i]=M.FRAME; s.tone[i]=.62; s.emit[i]=.35; }
      return s; };
    SPR.smearN_a=arc(22,95,175); SPR.smearN_b=(()=>{ const s=newSprite(16,9); s.px=0; s.py=4; s.mask=.5;
      for(const [y,x0,x1] of [[1,4,13],[4,0,15],[7,6,12]]) for(let x=x0;x<=x1;x+=1) if((x+y)%4!==3){ const i=y*16+x; s.mat[i]=M.FRAME; s.tone[i]=.62; s.emit[i]=.35; } return s; })(); }
  for(const [k,R] of [[0,4],[1,7],[2,10]]){ const N=2*R+3, c=R+1, s=newSprite(N,N); s.px=c; s.py=c; s.mask=.5;
    for(let a=0;a<360;a+=4){ if(k>0 && (a/4)%(k+2)===0) continue; const t=a*Math.PI/180, x=c+Math.round(R*Math.cos(t)), y=c+Math.round(R*Math.sin(t)); const i=y*N+x; s.mat[i]=M.FRAME; s.tone[i]=.95; s.emit[i]=1; }
    if(k===0) for(const [x,y] of [[c,c],[c-1,c],[c+1,c],[c,c-1],[c,c+1]]){ const i=y*N+x; s.mat[i]=M.FRAME; s.tone[i]=1; s.emit[i]=1; }
    SPR['fx_ring'+k]=s; }
  SPR.smearKm_a = genSmear(12, 4, 105, 212, M.GOLD); SPR.smearKm_b = genSmear(12, 2, 62, 132, M.GOLD);
  SPR.smearSm_a = genSmear(11, 4, 105, 212, M.STEEL); SPR.smearSm_b = genSmear(11, 2, 62, 132, M.STEEL);
  { const sh=newSprite(11,3); for(let y=0;y<3;y++) for(let x=0;x<11;x++){ const dx=(x-5)/5.5, dy=(y-1)/1.5; if(dx*dx+dy*dy<=1) sh.mat[y*11+x]=M.INK; } SPR.shadow_s=sh; }
  SPR.spark0 = plain(fromAscii(["....e....","....e....","..e.G.e..","...GGG...","eeGG+GGee","...GGG...","..e.G.e..","....e....","....e...."],[4,4]));
  SPR.spark1 = plain(fromAscii(["......e......",".............","..e.......e..",".....G.G.....","....G...G....","...G.....G...","e...........e","...G.....G...","....G...G....",".....G.G.....","..e.......e..",".............","......e......"],[6,6]));
  SPR.dust0 = plain(fromAscii(["...ss...","..sSSs..",".sSSSSs."],[4,2]), .5);
  SPR.dust1 = plain(fromAscii([".s....s.","s.s..s.s","..s..s.."],[4,2]), .5);
  const ff = newSprite(1,1); ff.mat[0]=M.GOLD; ff.tone[0]=.9; ff.emit[0]=1; ff.mask=.5; SPR.ff=ff;
  const sh = newSprite(22,5);
  for(let y=0;y<5;y++) for(let x=0;x<22;x++){ const dx=(x-10.5)/11, dy=(y-2)/2.5; if(dx*dx+dy*dy<=1) sh.mat[y*22+x]=M.INK; }
  SPR.shadow = sh;
  SPR.bg = genBG();
  Object.assign(SPR, genCity());
  Object.assign(SPR, genOctagon());
  Object.assign(SPR, genStage());
  Object.assign(SPR, genNoir());
  Object.assign(SPR, genSubway());
  Object.assign(SPR, genNYC());
  Object.assign(SPR, genBridge());
  Object.assign(SPR, genEl());
  Object.assign(SPR, genVault());
  Object.assign(SPR, genGimmicks());
  Object.assign(SPR, genPosters());
  Object.assign(SPR, genCorridor());
  Object.assign(SPR, genCorridor2());
  Object.assign(SPR, genCine());
  Object.assign(SPR, genPuffs());
}

function mulberry(a){ return ()=>{ a|=0; a=a+0x6D2B79F5|0; let t=Math.imul(a^a>>>15,1|a); t=t+Math.imul(t^t>>>7,61|t)^t; return ((t^t>>>14)>>>0)/4294967296; }; }
function genBG(){
  const s=newSprite(W,H); s.mask=.5;
  const rnd=mulberry(11);
  const set=(x,y,m,t,e=0,nx=0,ny=0)=>{ x|=0; y|=0; if(x<0||y<0||x>=W||y>=H) return; const i=y*W+x; s.mat[i]=m; s.tone[i]=t; s.emit[i]=e; s.nx[i]=nx; s.ny[i]=ny; };
  const get=(x,y)=> (x<0||y<0||x>=W||y>=H)?0:s.mat[y*W+x];
  const blob=(cx,cy,rx,ry,m,t,k=.75,yMax=999)=>{
    for(let y=Math.floor(cy-ry);y<=Math.ceil(cy+ry);y++) for(let x=Math.floor(cx-rx);x<=Math.ceil(cx+rx);x++){
      const dx=(x+.5-cx)/rx, dy=(y+.5-cy)/ry, r=dx*dx+dy*dy; if(r>1||y>yMax) continue;
      set(x,y,m,t+(rnd()<.08?.1:0),0,dx*k,-dy*k);
    }
  };
  // 하늘
  for(let y=0;y<H;y++) for(let x=0;x<W;x++) set(x,y,M.SKY,.34+.26*Math.min(1,y/90));
  for(let k=0;k<46;k++){ const x=rnd()*W, y=rnd()*58; if(Math.hypot(x-206,y-24)>16) set(x,y,M.EYE,.5,.25+rnd()*.3); }
  // 달
  for(let y=12;y<=36;y++) for(let x=194;x<=218;x++){
    const dx=(x+.5-206)/10, dy=(y+.5-24)/10; if(dx*dx+dy*dy>1) continue;
    let t=.62; if(Math.hypot(x-202,y-21)<2.6||Math.hypot(x-209,y-28)<2||Math.hypot(x-210,y-19)<1.4) t=.36;
    set(x,y,M.MOON,t,.95,dx*.6,-dy*.6);
  }
  // 먼 숲 (둥근 덩어리 + 침엽수)
  for(let i=0;i<22;i++) blob(i*12.5+rnd()*6-4, 58+rnd()*9, 8+rnd()*5, 12+rnd()*6, M.LEAF, .30, .6);
  for(let i=0;i<9;i++){
    const cx=12+i*29+rnd()*10, top=36+rnd()*12, base=86;
    for(let y=top|0;y<base;y++){ const half=(y-top)*.32+1; for(let x=Math.floor(cx-half);x<=Math.ceil(cx+half);x++){
      const dx=(x+.5-cx)/half; const band=((y-top)%6)<2; set(x,y,M.LEAF,band?.42:.34,0,dx*.6,band?.5:.2); } }
  }
  for(let y=70;y<88;y++) for(let x=0;x<W;x++) if(get(x,y)===M.SKY) set(x,y,M.LEAF,.27,0,0,.2);
  // 가까운 나무 (양옆)
  for(const [cx,cy,rx,ry] of [[6,22,22,30],[20,58,18,20],[-4,80,16,20],[250,20,22,30],[238,56,18,22],[260,84,16,18]]) blob(cx,cy,rx,ry,M.LEAF,.52,.85);
  for(const tx of [14,240]) for(let y=60;y<92;y++) for(let x=tx-2;x<=tx+2;x++) set(x,y,M.WOOD,x===tx-2?.38:.5,0,(x-tx)*.25,0);
  // 땅
  for(let y=84;y<120;y++) for(let x=0;x<W;x++){
    const lip = y===84;
    set(x,y,M.GRASS, lip?.66:.5 - (y<88?.06:0), 0, 0, .6);
  }
  for(let k=0;k<170;k++){
    const x=(rnd()*W)|0, y=86+(rnd()*32)|0;
    if(rnd()<.55){ set(x,y,M.GRASS,.72,0,0,.6); set(x-1,y-1,M.GRASS,.68,0,-.4,.4); set(x+1,y-1,M.GRASS,.68,0,.4,.4); }
    else set(x,y,M.GRASS,.36,0,0,.6);
  }
  for(let k=0;k<10;k++){ const x=(rnd()*W)|0, y=88+(rnd()*28)|0; set(x,y,M.RED,.7,.15,0,.6); }
  // 물
  for(let y=119;y<H;y++) for(let x=0;x<W;x++) set(x,y,y===119?M.INK:M.WATER,.45,0,0,.5);
  // 석판 무대
  const plat=new Uint8Array(W*H);
  for(let y=90;y<=113;y++){
    const top = y<=104;
    const f = Math.min(1,(y-90)/14);
    const xl = Math.round(40+(28-40)*(top?f:1)), xr = Math.round(216+(228-216)*(top?f:1));
    for(let x=xl;x<=xr;x++){
      plat[y*W+x]=1;
      if(top){
        let t=.56;
        for(let k=0;k<=8;k++){ const xs=Math.round(40+k*22+((28+k*25)-(40+k*22))*f); if(x===xs) t=.34; }
        if(y===97) t=.36;
        if(y===104) t=.84;
        if(y===90) t=.42;
        set(x,y,M.STONE,t,0,0,.66);
      } else {
        let t=.42; if((x-28)%25===0) t=.26; if(y===113) t=.24; if(y===105) t=.5;
        if(y>=107&&y<=110&&((x-40)%25===3||(x-40)%25===4)) t=.62;
        set(x,y,M.STONE,t,0,0,-.08);
      }
    }
  }
  // 랜턴
  for(let y=66;y<=96;y++){ set(46,y,M.WOOD,.56,0,-.4,0); set(47,y,M.WOOD,.42,0,.4,0); plat[y*W+46]=plat[y*W+47]=1; }
  for(let x=42;x<=51;x++){ set(x,56,M.STEEL,.62,0,0,.6); set(x,57,M.STEEL,.44,0,0,-.2); plat[56*W+x]=plat[57*W+x]=1; }
  for(let x=46;x<=47;x++) for(let y=53;y<=55;y++){ set(x,y,M.STEEL,.55); plat[y*W+x]=1; }
  for(let y=58;y<=64;y++) for(let x=43;x<=50;x++){
    plat[y*W+x]=1;
    if(x===43||x===50||y===64) set(x,y,M.STEEL,.48,0,x===43?-.5:x===50?.5:0,0);
    else set(x,y,M.GOLD,.85,.95);
  }
  for(let y=65;y<=65;y++) for(let x=45;x<=48;x++){ set(x,y,M.STEEL,.4); plat[y*W+x]=1; }
  // 외곽선 (무대 · 랜턴)
  for(let y=0;y<H;y++) for(let x=0;x<W;x++){
    if(plat[y*W+x]) continue;
    const n=(X,Y)=> X>=0&&Y>=0&&X<W&&Y<H&&plat[Y*W+X];
    if(n(x-1,y)||n(x+1,y)||n(x,y-1)||n(x,y+1)) set(x,y,M.INK,.5);
  }
  for(let i=0;i<W*H;i++){ const q=quantNormal(s.nx[i],s.ny[i]); s.nx[i]=q[0]; s.ny[i]=q[1]; }
  return s;
}

