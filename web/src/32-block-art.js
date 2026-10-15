// =========================================================
// 기술 아이템 = 만화 칸: 칸 하나에 한 컷(32×32, 같은 축척의 손 · 발 · 얼굴 클로즈업). 회전해도 그림은 똑바로, 칸 자리만 바뀐다
// =========================================================
const slv=(b,x0,y0,x1,y1,r0,r1)=>b.cap(x0,y0,x1,y1,r0,r1??r0,'n');
const fistAt=(b,cx,cy,r,dir=1)=>{ b.disc(cx,cy,r,'s'); for(let k=-1;k<=1;k++) b.set(cx+dir*(r-2),cy+k*2,'S'); b.line(cx-dir*1,cy+r-1,cx+dir*(r-1),cy+r-2,'S'); };
const starAt=(b,cx,cy,r)=>{ for(let k=0;k<8;k++){ const a=k*Math.PI/4, rr=k%2?r*.45:r; b.line(cx,cy,cx+Math.cos(a)*rr,cy+Math.sin(a)*rr,'y'); } b.disc(cx,cy,r*.3,'t'); };
const enemyHead=(b,cx,cy,r)=>{ b.disc(cx,cy,r,'s'); b.poly([[cx-r-1,cy-2],[cx-r+2,cy-r-2],[cx+r-1,cy-r-3],[cx+r+1,cy-r+1],[cx+r,cy-2]],'x'); b.line(cx-r-4,cy-2,cx-r+3,cy-2,'C'); };
const PANELS={
  guard(b){ b.poly([[1,31],[4,22],[12,19],[22,20],[28,24],[30,31]],'n'); b.poly([[13,20],[19,20],[16,27]],'w'); b.poly([[15,21],[17,21],[17.5,28],[16,29],[14.5,28]],'N');
    b.rect(13,15,6,5,'S'); b.disc(16,10,6,'s'); b.poly([[9,10],[10,4],[15,2],[21,3],[23,7],[22,8],[16,6],[11,9]],'N'); b.set(19,10,'K'); b.set(20,10,'K'); b.line(18,8,21,8,'N'); b.set(22,12,'S'); b.line(18,14,20,14,'z');
    slv(b,24,30,26,20,3,2.5); fistAt(b,26,17,3.5); slv(b,9,31,12,24,3,2.5); fistAt(b,13,22,3); },
  jab(b){ slv(b,-3,19,17,16,4.5,3.6); b.cap(17,16,19,16,3.6,3.6,'w'); fistAt(b,23,15,5); b.line(20,19,25,20,'S'); starAt(b,29,14,3); },
  hook(b){ slv(b,0,3,14,13,4,3.4); b.cap(14,13,16,15,3.3,3.3,'w'); fistAt(b,20,18,5); starAt(b,28,24,3); },
  hitface(b){ enemyHead(b,21,17,8); b.line(16,14,19,17,'K'); b.line(19,14,16,17,'K'); b.line(23,14,26,17,'K'); b.line(26,14,23,17,'K'); b.disc(23,22,2.2,'R'); b.set(30,15,'l'); b.set(30,19,'l'); b.set(29,22,'l');
    slv(b,-3,26,4,21,3.4,3); fistAt(b,8,18,5); starAt(b,13,15,4); },
  chamber(b){ b.cap(3,31,15,15,5.2,4.6,'n'); b.cap(15,15,23,24,4.3,3.6,'n'); b.poly([[21,21],[29,20],[31,24],[30,27],[21,27]],'N'); b.set(27,21,'h'); b.set(28,21,'h'); },
  flyKick(b){ for(const y of [5,10,24,29]) b.line(0,y,8,y,'S'); b.cap(-2,20,12,17,5.4,4.8,'n'); b.cap(12,17,24,15,4.4,3.8,'n');
    b.poly([[22,11],[30,12],[31,17],[29,19],[22,19]],'N'); b.set(28,12,'h'); b.set(29,12,'h'); b.cap(4,24,12,28,4,3.4,'n'); b.poly([[10,26],[16,26],[16,30],[10,30]],'N'); starAt(b,30,8,3.4); },
  sole(b){ b.cap(0,0,8,8,5,4.5,'n'); b.poly([[6,6],[24,3],[29,11],[27,27],[17,31],[8,27],[4,15]],'G'); for(let y=10;y<=24;y+=4) b.line(8,y,25,y-1,'K'); b.rect(10,23,12,6,'g'); b.set(13,6,'g'); b.set(14,6,'g'); },
  kneeup(b){ b.poly([[19,4],[31,6],[31,31],[22,31],[20,18]],'C'); b.poly([[24,6],[28,6],[27,14]],'w'); b.cap(3,31,15,17,5.4,4.6,'n'); b.disc(16,15,4.4,'n'); starAt(b,20,12,4); },
  elbow(b){ slv(b,0,27,14,20,4.2,3.6); slv(b,14,20,7,9,3.6,3); fistAt(b,6,7,3.2,-1); b.disc(15,19,2.6,'n'); starAt(b,21,17,4.2); },
  upperRise(b){ slv(b,16,33,16,15,4.6,3.8); b.cap(16,15,16,13,3.8,3.8,'w'); fistAt(b,16,8,5); b.line(12,4,20,4,'S'); },
  jawUp(b){ enemyHead(b,16,15,8); b.poly([[22,1],[30,0],[31,5],[24,7]],'x'); b.line(12,12,15,15,'K'); b.line(15,12,12,15,'K'); b.line(18,12,21,15,'K'); b.line(21,12,18,15,'K'); b.rect(13,19,6,2,'w'); b.set(8,9,'l'); b.set(26,12,'l');
    fistAt(b,16,29,4); starAt(b,16,24,3.6); },
  sweepLow(b){ b.rect(0,28,32,4,'G'); b.cap(-2,21,19,24,4.2,3.6,'n'); b.poly([[18,21],[28,22],[30,26],[19,27]],'N'); b.set(25,22,'h'); b.disc(27,28,2.4,'W'); b.disc(31,27,2,'W'); b.disc(23,29,1.6,'W'); },
  feetUp(b){ b.cap(11,33,9,12,3.6,3.2,'C'); b.cap(21,33,23,10,3.6,3.2,'C'); b.poly([[5,6],[12,7],[13,12],[6,12]],'N'); b.poly([[19,4],[27,5],[28,10],[20,10]],'N'); starAt(b,15,6,3); starAt(b,29,16,2.6); starAt(b,4,18,2.4); },
  shoulder(b){ b.poly([[1,32],[5,15],[19,10],[31,16],[27,32]],'n'); b.poly([[18,12],[24,13],[20,20]],'w'); b.disc(13,8,5,'s'); b.poly([[7,8],[9,3],[15,2],[19,5],[17,6],[11,6],[8,9]],'N'); b.set(16,8,'K'); b.line(15,6,18,6,'N'); starAt(b,30,13,3.4); },
  grab(b){ b.poly([[2,0],[30,0],[31,32],[1,32]],'C'); b.poly([[9,2],[16,17],[23,2]],'w'); b.poly([[14,4],[18,4],[18,12],[16,14],[14,12]],'R');
    b.cap(5,33,10,16,3.8,3.2,'n'); b.cap(27,33,22,16,3.8,3.2,'n'); b.disc(11,12,4.2,'s'); b.disc(21,12,4.2,'s'); for(const x of [9,11,13]) b.set(x,9,'S'); for(const x of [19,21,23]) b.set(x,9,'S'); },
  overhead(b){ b.cap(9,21,21,10,4.6,4,'C'); b.disc(6,23,3.6,'s'); b.poly([[3,22],[5,19],[9,20],[8,23]],'x'); b.cap(21,10,27,3,3,2.6,'C'); b.poly([[25,0],[31,1],[30,5],[26,5]],'N'); },
  floorhit(b){ b.rect(0,25,32,7,'G'); b.cap(3,22,21,22,4,3.6,'C'); b.disc(25,21,3.6,'s'); b.poly([[22,19],[25,16],[29,18],[27,21]],'x'); for(const [x,y,r] of [[4,24,3],[10,26,2.4],[29,25,2.6],[16,27,2]]) b.disc(x,y,r,'W');
    b.line(13,26,10,31,'K'); b.line(17,26,19,31,'K'); b.line(15,26,15,31,'K'); },
  stompDown(b){ b.cap(17,-2,16,13,4.6,4.2,'n'); b.poly([[9,13],[24,13],[26,20],[8,20]],'N'); b.set(20,14,'h'); b.rect(0,25,32,7,'G'); b.line(16,25,11,31,'K'); b.line(17,25,23,31,'K'); b.line(16,25,17,31,'K'); b.disc(6,25,2.4,'W'); b.disc(27,25,2.6,'W'); },
  lookback(b){ b.poly([[0,32],[3,21],[14,18],[26,20],[31,24],[31,32]],'n'); b.poly([[10,18],[16,18],[13,23]],'w'); b.rect(12,14,7,5,'S'); b.disc(17,10,7.5,'N'); for(let k=0;k<4;k++) b.line(12+k*3,4,16+k*3,8,'m');
    b.poly([[8,8],[13,6],[13,16],[9,17],[7,13]],'s'); b.set(9,11,'K'); b.set(10,11,'K'); b.line(8,9,12,8,'N'); },
  backfistP(b){ slv(b,34,19,14,16,4.4,3.6); b.cap(14,16,12,16,3.6,3.6,'w'); fistAt(b,8,15,5,-1); b.line(5,12,5,18,'S'); starAt(b,3,22,3); },
  heel(b){ b.cap(33,8,15,17,4.8,4.2,'n'); b.poly([[3,15],[16,13],[18,21],[4,23]],'N'); b.rect(3,15,3,8,'g'); b.set(10,14,'h'); starAt(b,3,10,3); },
  duckP(b){ b.poly([[2,32],[6,20],[24,18],[30,32]],'n'); b.poly([[13,20],[19,20],[16,26]],'w'); b.disc(16,17,5.5,'N'); for(let k=0;k<3;k++) b.line(12+k*3,13,14+k*3,16,'m');   // 웅크려 머리를 감싼다
    slv(b,6,24,13,13,3,2.6); slv(b,26,24,19,13,3,2.6); b.disc(13,12,2.6,'s'); b.disc(19,12,2.6,'s'); b.cap(8,5,22,3,1.6,2.2,'e'); b.rect(22,2,3,3,'E'); b.set(12,4,'h'); },   // 머리 위로 휙 지나가는 병
  stare(b){ b.rect(0,6,32,24,'s'); b.rect(0,0,32,7,'N'); for(let k=0;k<6;k++) b.line(k*6,1,k*6+4,5,'m'); b.line(2,10,13,13,'N'); b.line(2,11,13,14,'N'); b.line(19,13,30,10,'N'); b.line(19,14,30,11,'N');   // 매서운 눈
    for(const ex of [8,24]){ b.rect(ex-5,16,10,4,'h',true); b.rect(ex-1,16,3,4,'N',true); b.set(ex,16,'h',true); b.line(ex-5,15,ex+4,15,'K',true); b.line(ex-4,20,ex+4,20,'S',true); } b.line(16,17,17,27,'S'); b.rect(0,29,32,3,'S'); },
  fistup(b){ slv(b,4,33,9,20,4.4,3.8); slv(b,28,33,23,20,4.4,3.8); b.cap(9,20,9,18,3.8,3.8,'w'); b.cap(23,20,23,18,3.8,3.8,'w'); fistAt(b,10,12,5.6,1); fistAt(b,22,12,5.6,-1); },   // 두 주먹 가드
  hitbald(b){ b.disc(21,17,8.5,'s'); b.disc(13,17,2,'s'); for(let y=19;y<26;y++) for(let x=15;x<29;x++) if(((x*5+y*3)%4)===0 && b.get(x,y)==='s') b.set(x,y,'S'); b.line(16,13,19,16,'K'); b.line(19,13,16,16,'K'); b.line(23,13,26,16,'K'); b.line(26,13,23,16,'K');   // 민머리 수염 적
    b.rect(19,21,6,2,'w'); b.set(29,10,'l'); b.set(30,13,'l'); slv(b,-3,26,4,21,3.4,3); fistAt(b,8,18,5); starAt(b,13,15,4); },
  spin(b){ b.disc(6,25,4,'s'); b.poly([[1,24],[3,20],[8,19],[11,22],[9,23]],'N'); b.cap(8,31,14,22,4,3.8,'n'); b.cap(14,22,24,12,4,3.4,'n'); b.poly([[22,9],[30,8],[31,12],[23,14]],'N'); b.set(27,9,'h'); starAt(b,29,4,2.8); },
};
// 칸 배정(원래 모양 기준 'x,y' → 컷). sfx:글자 = 효과음 칸 · fx = 칸 안의 속도선
const PANEL_SET={
  punch:{ '0,0':'jab', '0,1':'hitface' },
  kick:{ '0,0':'guard', '0,1':'chamber', '1,1':'sole' },
  knee:{ '0,0':'grab', '0,1':'kneeup' },
  elbow:{ '0,0':'stare', '1,0':'elbow', '1,1':'hitbald' },
  round:{ '0,0':'fistup', '1,0':'spin', '2,0':'hitbald', '1,1':'sfx:WHAM!' },
  upper:{ '0,0':'sfx:POW!', '0,1':'jawUp', '0,2':'upperRise' },
  sweep:{ '0,0':'sweepLow', '1,0':'feetUp', '2,0':'sfx:BAM!' },
  charge:{ '0,1':'stare', '1,1':'shoulder', '1,0':'hitface', '2,0':'sfx:WHAM!' },
  throw:{ '0,0':'grab', '1,0':'overhead', '0,1':'floorhit', '1,1':'sfx:SLAM!', '0,2':'feetUp' },
  stomp:{ '0,0':'stompDown', '1,0':'sfx:STOMP!' },
  bkick:{ '0,0':'lookback', '1,0':'heel', '2,0':'hitbald<', '2,1':'sfx:THWAK!' },
  bfist:{ '0,0':'lookback', '1,0':'backfistP', '0,1':'hitface<', '1,1':'sfx:THWAK!' },
  duck:{ '0,0':'duckP' },
  fkick:{ '0,0':'chamber', '1,0':'flyKick', '2,0':'sfx:WHAM!' },
};
const PANEL_FX={ flyKick:'h', stare:null, fistup:'radial', hitbald:'radial', jab:'h', hook:'arc', hitface:'radial', chamber:'arc', sole:'radial', kneeup:'diag', elbow:'h', upperRise:'v', jawUp:'radial', sweepLow:'h', feetUp:'radial', shoulder:'h', grab:'radial', overhead:'arc', floorhit:'radial', stompDown:'v', backfistP:'h', heel:'h', duckP:'h', spin:'arc' };
const FAM_BG={ fist:['#a8443a','#c85c4a'], foot:['#3a6ab0','#5486cc'], grap:['#2e8656','#46a46c'], none:['#7a6a9a','#9484b4'] };   // 밝고 채도 있는 바탕 — 검은 윤곽의 양복이 또렷하게
const PANEL_CV={};
function panelCanvas(pid){ if(PANEL_CV[pid]) return PANEL_CV[pid];
  if(pid.endsWith('<')){ const src=panelCanvas(pid.slice(0,-1)), cv=document.createElement('canvas'); cv.width=32; cv.height=32; const c=cv.getContext('2d'); c.translate(32,0); c.scale(-1,1); c.drawImage(src,0,0); return PANEL_CV[pid]=cv; }   // 거울상
  const b=artBuf(1,1); PANELS[pid](b); shadeArt(b);
  const out=b.a.slice(); for(let y=0;y<b.H;y++) for(let x=0;x<b.W;x++){ if(b.a[y*b.W+x]) continue; if([[1,0],[-1,0],[0,1],[0,-1]].some(([dx,dy])=>{ const c=b.get(x+dx,y+dy); return c&&c!=='K'; })) out[y*b.W+x]='K'; }
  const cv=document.createElement('canvas'); cv.width=32; cv.height=32; const cx=cv.getContext('2d');
  for(let y=0;y<32;y++) for(let x=0;x<32;x++){ const c=out[y*32+x]; if(!c) continue; cx.fillStyle=ICON_PAL[c]; cx.fillRect(x,y,1,1); } return PANEL_CV[pid]=cv; }
function drawPanel(cx,px,py,pid,fam){ const bg=pid.startsWith('sfx:')?['#a8241c','#d8422a']:FAM_BG[fam||'none'];
  cx.save(); cx.beginPath(); cx.rect(px+1,py+1,30,30); cx.clip();
  cx.fillStyle=bg[0]; cx.fillRect(px+1,py+1,30,30); cx.fillStyle=bg[1]; for(let y=1;y<31;y+=3) for(let x=1+((y/3|0)%2)*1.5;x<31;x+=3) cx.fillRect(px+Math.round(x),py+y,1,1);   // 망점
  const fx=PANEL_FX[pid.replace('<','')]; cx.strokeStyle='rgba(255,236,210,.32)'; cx.lineWidth=1;
  if(fx==='h') for(const y of [5,9,23,27]){ cx.beginPath(); cx.moveTo(px+1,py+y+.5); cx.lineTo(px+12,py+y+.5); cx.stroke(); }
  if(fx==='v') for(const x of [5,9,23,27]){ cx.beginPath(); cx.moveTo(px+x+.5,py+31); cx.lineTo(px+x+.5,py+16); cx.stroke(); }
  if(fx==='diag') for(const k of [0,6,12]){ cx.beginPath(); cx.moveTo(px+1+k,py+31); cx.lineTo(px+10+k,py+20); cx.stroke(); }
  if(fx==='arc') for(const r of [12,16]){ cx.beginPath(); cx.arc(px+16,py+20,r,Math.PI*1.05,Math.PI*1.75); cx.stroke(); }
  if(fx==='radial') for(let k=0;k<12;k++){ const a=k/12*Math.PI*2; cx.beginPath(); cx.moveTo(px+16+Math.cos(a)*9,py+16+Math.sin(a)*9); cx.lineTo(px+16+Math.cos(a)*22,py+16+Math.sin(a)*22); cx.stroke(); }
  if(pid.startsWith('sfx:')){ const w=pid.slice(4); cx.beginPath(); for(let k=0;k<20;k++){ const a=k/20*Math.PI*2, r=(k%2?9:15)*(k%4===0?1.1:1); const X=px+16+Math.cos(a)*r, Y=py+16+Math.sin(a)*r*.86; k?cx.lineTo(X,Y):cx.moveTo(X,Y); } cx.closePath();
    cx.fillStyle='#ffe24a'; cx.fill(); cx.strokeStyle='#0e0d14'; cx.lineWidth=1; cx.stroke();
    let fs=11; cx.font=`italic 900 ${fs}px Impact,"Arial Black",sans-serif`; while(cx.measureText(w).width>27 && fs>6){ fs-=.5; cx.font=`italic 900 ${fs}px Impact,"Arial Black",sans-serif`; }
    cx.textAlign='center'; cx.textBaseline='middle'; cx.lineJoin='round'; cx.lineWidth=2.4; cx.strokeStyle='#0e0d14'; cx.strokeText(w,px+16,py+16.5); cx.fillStyle='#e8322a'; cx.fillText(w,px+16,py+16.5); }
  else cx.drawImage(panelCanvas(pid),px,py);
  cx.restore(); cx.fillStyle='#0e0d14'; cx.fillRect(px+1,py+1,30,1); cx.fillRect(px+1,py+30,30,1); cx.fillRect(px+1,py+1,1,30); cx.fillRect(px+30,py+1,1,30);   // 잉크 테두리(칸 사이 여백 1px)
  cx.fillStyle='rgba(255,246,230,.55)'; cx.fillRect(px+2,py+2,28,1); }
function panelURL(id,rot){ const base=GITEMS[id].shape||[[0,0]], rc=shapeOf(id,rot), w=Math.max(...rc.map(p=>p[0]))+1, h=Math.max(...rc.map(p=>p[1]))+1;
  const cv=document.createElement('canvas'); cv.width=w*32; cv.height=h*32; const cx=cv.getContext('2d'); cx.imageSmoothingEnabled=false;
  const inS=(x,y)=>rc.some(p=>p[0]===x&&p[1]===y);
  cx.fillStyle='#efe4c6'; for(const [x,y] of rc) cx.fillRect(x*32,y*32,32,32);                                  // 원고지(칸 사이 여백)
  for(const [x,y] of rc){ if(inS(x+1,y)) cx.fillRect(x*32+31,y*32,2,32); if(inS(x,y+1)) cx.fillRect(x*32,y*32+31,32,2); }
  base.forEach(([x,y],i)=>{ const pid=PANEL_SET[id][x+','+y]; if(pid) drawPanel(cx, rc[i][0]*32, rc[i][1]*32, pid, GITEMS[id].fam); });
  cx.fillStyle='#0e0d14'; for(const [x,y] of rc){ const X=x*32, Y=y*32;                                          // 아이템 바깥 테두리
    if(!inS(x,y-1)) cx.fillRect(X,Y,32,1); if(!inS(x,y+1)) cx.fillRect(X,Y+31,32,1); if(!inS(x-1,y)) cx.fillRect(X,Y,1,32); if(!inS(x+1,y)) cx.fillRect(X+31,Y,1,32); }
  return cv.toDataURL(); }

// =========================================================
// 느와르 블록 그림: 8등신 실루엣 · 테두리 빛 · 계열 색 강조 · 만화책 바탕 · 캡션(기술명 · 조건)
// 블록 모양(회전 0) 기준으로 그린 뒤, 회전은 그림만 돌리고 캡션은 똑바로 다시 얹는다
// =========================================================
// 콤보 경로 역할(시안): S 시작기 · L 이음기 · F 마무리기 · X 보조 / 상태 G 지상 · A 공중 · T 걸림 · C 무너짐 · D 다운 · B 등 돌림 · K 날림 · P 끌림 · Z 경직 · * 아무 상태 · = 그대로
const COMBO_ROLE={ upper:{r:'S',i:'*',o:'A'}, skick:{r:'S',i:'*',o:'A'}, sweep:{r:'S',i:'G',o:'T'}, knee:{r:'S',i:'G',o:'C'}, elbow:{r:'S',i:'G',o:'Z'}, umb:{r:'S',i:'G',o:'P'},
  punch:{r:'L',i:'*',o:'='}, paper:{r:'L',i:'*',o:'='}, stomp:{r:'L',i:'D',o:'A'}, bfist:{r:'L',i:'B',o:'='},
  round:{r:'F',i:'*',o:'K'}, charge:{r:'F',i:'*',o:'K'}, throw:{r:'F',i:'*',o:'D'}, kick:{r:'F',i:'*',o:'K'}, fkick:{r:'F',i:'G',o:'K'}, bkick:{r:'F',i:'B',o:'K'}, case:{r:'F',i:'G',o:'D'}, cycle:{r:'L',i:'A',o:'A'}, axe:{r:'F',i:'A',o:'D'}, hmup:{r:'S',i:'*',o:'A'}, hmswing:{r:'L',i:'*',o:'='}, hmback:{r:'L',i:'*',o:'='}, hmdown:{r:'F',i:'*',o:'D'}, suplex:{r:'F',i:'G',o:'D'}, tetsu:{r:'F',i:'*',o:'K'}, renkan:{r:'S',i:'G',o:'A'}, duck:{r:'X'} };
// ===== 콤보 경로: 시작기 ▶에서 붙은 블록을 따라 이어지는 순서(상태가 맞는 블록만 · 같으면 읽는 순서) =====
const RT_COL=['#ff9a3c','#5fc8ff','#8dff7a'];
const croleOf=id=>{ const R=COMBO_ROLE[id]; if(R) return R.r; const it=GITEMS[id]; return it&&it.kind==='skill'?'L':'X'; };
const stIn=id=>(COMBO_ROLE[id]&&COMBO_ROLE[id].i)||'*', stOut=id=>(COMBO_ROLE[id]&&COMBO_ROLE[id].o)||'=';
const ST_OK={ T:['T','D','A'], C:['C','G'], Z:['Z','G'], P:['P','G'], B:['B','G'], K:['K','A'], A:['A','D'], D:['D'], G:['G'] };   // 걸림은 곧 다운 · 경직 · 끌림 · 등 돌림은 서 있는 적
const stFits=(inp,st)=>inp==='*'||inp===st||(ST_OK[st]||[]).includes(inp);
const stNext=(id,st)=>{ const o=stOut(id); return o==='='?st:o; };
const isSkillB=o=>!!(o&&GITEMS[o.id]&&GITEMS[o.id].kind==='skill');
const rdKey=b=>{ const c=cellsOf(b), y=Math.min(...c.map(p=>p[1])); return y*100+Math.min(...c.filter(p=>p[1]===y).map(p=>p[0])); };
function adjIn(list,b){ const mine=new Set(cellsOf(b).map(([x,y])=>x+','+y)), out=[];
  for(const o of list){ if(!o||o===b||o.uid===b.uid) continue; if(cellsOf(o).some(([x,y])=>mine.has((x+1)+','+y)||mine.has((x-1)+','+y)||mine.has(x+','+(y+1))||mine.has(x+','+(y-1)))) out.push(o); }
  return out; }
const linkable=(o,st,used)=>isSkillB(o)&&!used.has(o.uid)&&croleOf(o.id)!=='X'&&stFits(stIn(o.id),st);   // 시작기도 입력이 맞으면 중간에(재띄우기)
function routeFrom(list,b0,st0,used0){ const R=[b0], used=new Set(used0||[]); used.add(b0.uid); let cur=b0, st=stNext(b0.id,st0||'G');
  while(R.length<6 && !(croleOf(cur.id)==='F' && R.length>1)){
    const cand=adjIn(list,cur).filter(o=>linkable(o,st,used)); if(!cand.length) break;
    cand.sort((a,b)=>((a.uid===cur.pin?0:1)-(b.uid===cur.pin?0:1)) || ((croleOf(a.id)==='S'?1:0)-(croleOf(b.id)==='S'?1:0)) || ((stIn(a.id)===st?0:1)-(stIn(b.id)===st?0:1)) || rdKey(a)-rdKey(b));   // 고정 핀 → 보통 이음기 → 딱 맞는 상태 → 읽는 순서
    cur=cand[0]; R.push(cur); used.add(cur.uid); st=stNext(cur.id,st); }
  return R; }
const CN={ A:'공중', T:'걸어 넘기기', C:'무너뜨리기', Z:'반격', P:'끌어치기', D:'다운', B:'등 돌리기', K:'날리기', G:'연속' };
const COMBO_BOOK=[   // 콤보 도감: 실전에서 이 순서로 성공하면 채워진다(앞부분이 같으면 더 길어도 인정)
  { id:'airrush',  n:'하늘 난타',        r:['upper','punch','round'],          d:'어퍼로 띄우고 주먹으로 두들긴 뒤 돌려차기로 날려 보내요' },
  { id:'moonlit',  n:'월광 질풍',        r:['skick','punch','paper','round'],  d:'섬머솔트로 띄워 주먹 · 신문을 몰아치고 돌려차기로 끝내요' },
  { id:'airgrab',  n:'공중 잡아 꽂기',   r:['upper','punch','throw'],          d:'띄운 적을 두들기다 뛰어올라 잡아 바닥에 꽂아요' },
  { id:'scoop',    n:'걸고 퍼올리기',    r:['sweep','upper','punch'],          d:'다리를 걸어 낮게 띄우고 바닥에서 퍼 올려 이어 쳐요' },
  { id:'trample',  n:'짓밟기 3단',       r:['sweep','stomp','kick'],           d:'걸어 넘기고 밟아 튕긴 뒤 앞차기로 날려요' },
  { id:'fbounce',  n:'바닥 튕겨 올리기', r:['upper','punch','stomp','skick'],  d:'떨어지는 적을 밟아 튕기고 섬머솔트로 다시 띄워요' },
  { id:'crumple',  n:'무너뜨려 띄우기',  r:['knee','punch','upper'],           d:'니킥으로 무너뜨리고 두들긴 뒤 어퍼로 띄워요' },
  { id:'counter',  n:'받아치기 연격',    r:['elbow','knee','punch'],           d:'팔꿈치로 끊고 니킥 · 주먹으로 몰아쳐요' },
  { id:'hookrush', n:'끌어치기 돌진',    r:['umb','punch','charge'],           d:'우산으로 끌어당겨 두들기고 어깨로 들이받아요' },
  { id:'kickdrop', n:'올려 꽂기',        r:['renkan','axe'],                  d:'땅에서 두 번 차올려 높이 띄운 뒤 발뒤꿈치로 바닥에 내리꽂아요' },
  { id:'thunder',  n:'낙뢰',             r:['upper','cycle','axe'],            d:'띄우고 공중에서 두 다리로 몰아친 뒤 발뒤꿈치로 내리꽂아요' },
  { id:'bridge',   n:'무너뜨려 꽂기',    r:['knee','punch','suplex'],          d:'니킥으로 무너뜨리고 두들긴 뒤 저먼 수플렉스로 꽂아요' },
  { id:'signoff',  n:'서류가방 결재',    r:['knee','paper','case'],            d:'무너뜨리고 신문으로 찰싹, 서류가방으로 마무리 결재' } ];
const bookOf=ids=>{ let best=null; for(const B of COMBO_BOOK) if(ids.length>=B.r.length && B.r.every((id,k)=>ids[k]===id) && (!best||B.r.length>best.r.length)) best=B; return best; };
const comboName=R=>{ if(R[0]&&GITEMS[R[0].id]&&GITEMS[R[0].id].pro) return R.length>=4?'장도리 난타':`장도리 ${R.length}연격`; const B=bookOf(R.map(o=>o.id)); return B?B.n:`${CN[stOut(R[0].id)]||'연속'} ${R.length}${croleOf(R[R.length-1].id)==='F'?'연격':'연타'}`; };
function routesOf(list){ return (list||[]).filter(b=>isSkillB(b)&&croleOf(b.id)==='S').sort((a,b)=>rdKey(a)-rdKey(b)).map(b=>routeFrom(list,b,'G')).filter(R=>R.length>=2)
  .map((R,k)=>({ items:R, key:R.map(o=>o.uid).join('>'), name:comboName(R), col:RT_COL[k%RT_COL.length] })); }
// 실전: 시작기가 맞으면 콤보 창이 열리고, 경로의 다음 블록은 쿨다운과 상관없이 한 번씩 나간다
function liveSt(T){ if(!T) return 'G'; if(T.jug) return T.jug.trip?'T':'A'; if(T.anim==='crumple'||T.anim==='crumpleD') return 'C'; if(T.anim==='spinout') return 'B';
  if(T.anim==='pulled') return 'P'; if(FALLS.has(T.anim)||isDown(T)) return 'D'; if(T.e&&T.e.stun>0) return 'Z'; return 'G'; }
// 콤보 리듬: 경로가 있는 시작기는 원래 발동 조건 없이 쓰고(조건은 경로의 상태 규칙이 대신), 숨 고르기 동안엔 기다렸다 끝나면 맨 먼저 — 이음기 · 마무리기는 사이사이 견제로 단독 사용 가능
function routeSets(){ if(GS._rsT===GS.time && GS._rs) return GS._rs; const S=new Set(), M=new Set(); for(const r of routesOf(GS.bag)){ S.add(r.items[0].uid); for(const o of r.items.slice(1)) M.add(o.uid); } GS._rsT=GS.time; return GS._rs={ S, M }; }
function soloSkip(b){ if(!b || GS.croute || GS.prologue) return false; return routeSets().S.has(b.uid) && (GS.comboCD||0)>0; }   // 시작기는 숨 고르기 동안 아껴 둔다(헛쓰지 않게)
const comboMul=b=>GS.croute&&b&&GS.croute.uids.includes(b.uid)?GS.croute.mul:1;
function comboGlow(uid){ try{ const el=bagEl.querySelector(`.ii[data-uid="${uid}"]`); if(el){ el.classList.remove('rt-fire'); void el.offsetWidth; el.classList.add('rt-fire'); } }catch(e){} }
function comboOpen(i,T,chain){ if(GS.demo || GS.croute || !T || T.dead) return; if(!chain && (GS.comboCD||0)>0) return;
  const b=GS.bag[i]; if(!b||croleOf(b.id)!=='S') return; const R=routeFrom(GS.bag,b,'G'); if(R.length<2) return;
  const key=R.map(o=>o.uid).join('>'); GS.comboUse=GS.comboUse||{}; const n=GS.comboUse[key]||0;
  const mul=Math.max(.7,1-.08*n)*(GS.lastCombo&&GS.lastCombo!==key?1.06:1);                       // 같은 경로 반복은 약하게 감쇠 · 다른 콤보로 바꾸면 보너스
  GS.croute={ uids:R.map(o=>o.uid), k:chain?0:1, key, name:comboName(R), mul, t:2.4, T, hits:0, chain:chain||0, fin:false }; dbgT('open', R.map(o=>o.id).join('>'), dbgSt(T));
  if(!chain) comboGlow(b.uid); }
function comboOnUse(b){ const C=GS.croute; if(C && C.uids[C.k]===b.uid){ C.k++; C.t=2.4; if(croleOf(b.id)==='F') C.fin=true; comboGlow(b.uid); } }
function comboPick(H,T){ const C=GS.croute; if(!C) return -1; const tg=C.T&&!C.T.dead&&C.T.anim!=='death'?C.T:null; if(!tg){ comboEnd(false); return -1; }
  if(C.k>=C.uids.length) return -1;
  const st=liveSt(tg); let b=GS.bag.find(o=>o&&o.uid===C.uids[C.k]);
  if(!b || (C.k>0 && !stFits(stIn(b.id),st))){                                                            // 상황 분기: 직전 블록의 다른 이웃 중 지금 상태에 맞는 쪽으로
    const used=C.uids.slice(0,C.k), prev=GS.bag.find(o=>o&&o.uid===used[used.length-1]);
    const alt=prev?adjIn(GS.bag,prev).filter(o=>linkable(o,st,new Set(used))).sort((a,c)=>((a.uid===prev.pin?0:1)-(c.uid===prev.pin?0:1))||((stIn(a.id)===st?0:1)-(stIn(c.id)===st?0:1))||rdKey(a)-rdKey(c))[0]:null;
    if(!alt){ comboEnd(false); return -1; }
    C.uids=[...used, ...routeFrom(GS.bag,alt,st,used).map(o=>o.uid)]; C.branch=true; b=alt; }
  return GS.bag.indexOf(b); }
function comboTick(dt){ if((GS.comboCD||0)>0) GS.comboCD-=dt; const C=GS.croute, H=GS.hero;
  GS.comboIdle = (C || !foes().some(a=>!a.dead)) ? 0 : (GS.comboIdle||0)+dt;
  if(GS.bossBreak){ const B=GS.bossBreak; B.t-=dt; if(B.t<=0 || B.a.dead || !GS.ents.includes(B.a)) GS.bossBreak=null; }   // 콤보 없이 싸운 시간(8초 넘으면 묶인 블록도 단독 허용)
  if(!C){ if(GS.on && !foes().some(a=>!a.dead)) GS.comboUse={}; return; }                               // 싸움이 끝나면 반복 기록을 비운다
  C.t-=dt; if(C.t<=0){ comboEnd(false); return; }
  if(C.k>=C.uids.length && H && (canAct(H) || (H.action&&H.action.fired&&!heroAirborne(H)))) comboEnd(true); }
function comboEnd(done){ const C=GS.croute; if(!C) return; dbgT('end', done, C.k+'/'+C.uids.length, C.uids.map(u=>{ const o=GS.bag.find(x=>x&&x.uid===u); return o&&o.id; }).join('>'), dbgSt(C.T), 't='+C.t.toFixed(2)); GS.croute=null;
  if(C.hits>=2){ GS.comboUse=GS.comboUse||{}; GS.comboUse[C.key]=(GS.comboUse[C.key]||0)+1; GS.lastCombo=C.key; GS.stats.combos=(GS.stats.combos||0)+1; const fresh=metaCombo(C); if(C.book){ const B=C.book; talkSoon('book1', ()=>TALK.book(B)); } if(done && C.fin && C.T) skinFlair(C.T);
    say(tr(C.name)+(done&&C.fin?'!':''), `${C.book?tr('도감 콤보 완성')+' · ':fresh?tr('콤보 노트에 기록')+' · ':''}${C.hits} HIT${C.mul<.99?` · ${tr('반복')} ×${C.mul.toFixed(2)}`:C.mul>1.01?` · ${tr('새 콤보')} ×${C.mul.toFixed(2)}`:''}`, 1.3); }
  if(done && C.fin && !C.chain && C.T && !C.T.dead && C.T.jug){                                         // 콤보 잇기: 마무리 뒤에도 떠 있으면 다른 경로의 시작기로
    const st=liveSt(C.T), nx=routesOf(GS.bag).find(r=>!r.items.some(o=>C.uids.includes(o.uid)) && stFits(stIn(r.items[0].id),st));
    if(nx){ comboOpen(GS.bag.indexOf(nx.items[0]),C.T,1); if(GS.croute){ GS.croute.name='콤보 잇기 · '+GS.croute.name; GS.croute.hits=C.hits; return; } } }
  GS.comboCD=3.5; }                                                                                     // 숨 고르기
// 가방 화면: 경로 선 · 번호 · 콤보 목록
function routeLayer(list){ const R=routesOf(list||GS.bag);
  const anch=b=>{ const L=labelRect(b.id,b.rot); return [b.x+L.lx+.3, b.y+L.ly+.26]; };   // 타일의 역할 배지(1▶ · 2● · 3■)끼리 잇는다
  let svg='', tags='';
  R.forEach((r,k)=>{ const off=(k-(R.length-1)/2)*.1, P=r.items.map(anch).map(([x,y])=>[x+off,y+off]), pts=P.map(([x,y])=>`${x.toFixed(2)},${y.toFixed(2)}`).join(' ');
    svg+=`<polyline points="${pts}" fill="none" stroke="#0e0d14" stroke-width="4.5" stroke-linecap="round" stroke-linejoin="round" vector-effect="non-scaling-stroke" opacity=".5"/><polyline points="${pts}" fill="none" stroke="${r.col}" stroke-width="2" stroke-dasharray="5 4" stroke-linecap="round" stroke-linejoin="round" vector-effect="non-scaling-stroke"/>`; });
  let forks='', nf=0;                                                                                  // 갈림길: 경로 중간 블록에서 다른 방향으로도 이어질 수 있는 이웃
  R.forEach(r=>{ const inR=new Set(r.items.map(o=>o.uid)); let st=stNext(r.items[0].id,'G');
    r.items.forEach((cur,k)=>{ if(k>0) st=stNext(cur.id,st); if(k===r.items.length-1 && croleOf(cur.id)==='F') return; if(k>=5) return;
      for(const o of adjIn(list||GS.bag,cur)){ if(inR.has(o.uid)||!isSkillB(o)||croleOf(o.id)==='X'||(croleOf(o.id)==='S'&&stIn(o.id)!=='*')) continue; if(nf>=4) break; nf++;
        const [x0,y0]=anch(cur), [x1,y1]=anch(o), mx=(x0+x1)/2, my=(y0+y1)/2, pin=cur.pin===o.uid, need=stIn(o.id), same=stFits(need,st);
        svg+=`<line x1="${x0.toFixed(2)}" y1="${y0.toFixed(2)}" x2="${x1.toFixed(2)}" y2="${y1.toFixed(2)}" stroke="${r.col}" stroke-width="2" stroke-dasharray="2 4" opacity=".55" vector-effect="non-scaling-stroke"/>`;
        const near=GS.selUid!=null&&(GS.selUid===cur.uid||GS.selUid===o.uid);                                   // 갈림 단추는 관련 블록을 골랐을 때만 · 평소엔 작은 점
        if(!near && !pin){ forks+=`<i class="rt-fk" style="left:${(mx/INV.W*100).toFixed(2)}%;top:${(my/INV.H*100).toFixed(2)}%;--rc:${r.col}"></i>`; continue; }
        forks+=`<button type="button" class="rt-fork${pin?' pin':''}${same?'':' cond'}" data-pf="${cur.uid}" data-pt="${o.uid}" title="${pin?tr('고정'):tr('갈림')}${same?'':` · ${tr(ST_NAME[need]||'')}${tr('이면')}`}" style="left:${(mx/INV.W*100).toFixed(2)}%;top:${(my/INV.H*100).toFixed(2)}%;--rc:${r.col}">${pin?tr('고정'):tr('갈림')}</button>`; } }); });
  R.forEach(r=>r.items.forEach((cur,k)=>{ const nx=r.items[k+1]; if(!nx||cur.pin!==nx.uid) return; const [x0,y0]=anch(cur), [x1,y1]=anch(nx);   // 고정한 연결: 눌러서 풀기
    forks+=`<button type="button" class="rt-fork pin" data-pf="${cur.uid}" data-pt="${nx.uid}" style="left:${((x0+x1)/2/INV.W*100).toFixed(2)}%;top:${((y0+y1)/2/INV.H*100).toFixed(2)}%;--rc:${r.col}">${tr('고정')}</button>`; }));
  if(nf && !list && !GS.pBag) talkSoon('fork', TALK.fork);
  return `<div class="rt-layer"><svg class="rt-svg" viewBox="0 0 ${INV.W} ${INV.H}" preserveAspectRatio="none" aria-hidden="true">${svg}</svg>${tags}${forks}</div>`; }
function comboListHTML(list){ const R=routesOf(list||GS.bag), G={S:'▶',L:'●',F:'■'};
  if(!R.length) return `<div class="inv-combos"><span class="ic-empty">${tr('시작기 ▶ 옆에 ●·■를 붙이면 콤보')}</span></div>`;
  return `<div class="inv-combos">${R.map((r,k)=>`<span class="cc" style="--rc:${r.col}" title="${r.items.map(o=>`${G[croleOf(o.id)]||''} ${tr(GITEMS[o.id].n)}`).join(' → ')}"><b>${k+1}</b><span class="cn">${tr(r.name)}</span><small>${r.items.length}단</small></span>`).join('')}</div>`; }
// 콤보 점수: 경로 길이 합(마무리로 끝나면 +1) — 추천 칸 · 카드 변화 줄에 쓴다
const rtScore=list=>routesOf(list).reduce((s,r)=>s+r.items.length+(croleOf(r.items[r.items.length-1].id)==='F'?1:0),0);
const ST_NAME={ G:'지상', A:'공중', T:'걸림', C:'무너짐', D:'다운', B:'등 돌림', K:'날림', P:'끌림', Z:'경직' };
function rtSuggest(){ try{ const d=drag; const cells=bagEl.querySelectorAll('.inv-grid .gc'); cells.forEach(c=>c.classList.remove('rt-sug','rt-best')); if(!d||!d.b||!isSkillB(d.b)) return;
  const base=GS.bag.filter(o=>o!==d.b), s0=rtScore(base), hits=[]; let best=0;
  for(let y=0;y<INV.H;y++) for(let x=0;x<INV.W;x++){ if(!canPlace(d.b,x,y,d.rot,d.b.uid)) continue; const v=rtScore(base.concat([{ ...d.b, x, y, rot:d.rot }]))-s0; if(v>0){ hits.push([x,y,v]); best=Math.max(best,v); } }
  for(const [x,y,v] of hits) for(const [cx,cy] of cellsOf(d.b,x,y,d.rot)){ const el=cells[cy*INV.W+cx]; if(el && !el.classList.contains('rt-best')) el.classList.add(v===best?'rt-best':'rt-sug'); } }catch(e){} }
function comboDelta(id){ try{ if(!isSkillB({id})) return null; const G={S:'▶',L:'●',F:'■'}[croleOf(id)]||'', R0=routesOf(GS.bag), s0=rtScore(GS.bag), tmp={ id, uid:-99, tier:1, x:0, y:0, rot:0 }; let best=null;
  for(const rot of [0,1,2,3]) for(let y=0;y<INV.H;y++) for(let x=0;x<INV.W;x++){ if(!canPlace(tmp,x,y,rot,-99)) continue; const L=GS.bag.concat([{ ...tmp, x, y, rot }]), v=rtScore(L)-s0; if(!best||v>best.v) best={ v, L }; }
  if(best && best.v>0) for(const q of routesOf(best.L)){ if(!q.items.some(o=>o.uid===-99)) continue; const o=R0.find(z=>z.items[0].uid===q.items[0].uid); return o?`${G} ${tr(o.name)} → ${tr(q.name)}`:`${G} ${tr('새 콤보')}: ${tr(q.name)}`; }
  if(croleOf(id)==='S') return `${G} ${tr('시작기 · 옆에 ●·■를 붙이면 새 콤보')}`;
  return stIn(id)==='*' ? `${G} ${tr('시작기 ▶ 옆에 붙이면 이어져요')}` : `${G} ${tr(ST_NAME[stIn(id)]||'')} ${tr('상태를 만드는 블록 뒤에 이어져요')}`; }catch(e){ return null; } }
// 고유 콤보 = 고유 마무리: 도감 레시피의 마지막 타가 들어가면 의성어 · 짧은 슬로 · 전용 이펙트 · 주변 적에게 보너스 한 방
const SIG={ airrush:{ w:'회오리!', k:'ring',   r:72, dmg:6, react:'launch', d:'이중 고리 충격파 · 주변 적 띄움' }, moonlit:{ w:'월광!', k:'moon', r:84, dmg:8, d:'거대 초승달 · 주변 베기' }, airgrab:{ w:'쾅!', k:'quake', r:64, dmg:8, d:'바닥 균열 · 충격파' },
  scoop:{ w:'퍼억!', k:'burst', r:54, dmg:6, d:'폭발 선 · 주변 타격' }, trample:{ w:'쿵쿵쿵!', k:'quake', r:92, dmg:6, react:'sweep', d:'바닥 충격파 · 주변 적 넘어뜨림' }, fbounce:{ w:'튕!', k:'moon2', r:66, dmg:6, d:'이중 초승달' },
  crumple:{ w:'솟구쳐!', k:'pillar', r:52, dmg:6, react:'launch', d:'빛기둥 · 주변 띄움' }, counter:{ w:'딱!', k:'flash', r:84, dmg:4, stun:1.2, d:'섬광 · 주변 적 경직' }, hookrush:{ w:'돌진!', k:'trail', r:96, dmg:7, d:'잔상 돌진 · 밀쳐내기' }, signoff:{ w:'결재!', k:'stamp', r:72, dmg:8, d:'결재 도장 · 서류 흩날림' },
  kickdrop:{ w:'올려 꽂기!', k:'quake', r:76, dmg:7, react:'sweep', d:'바닥 충격파 · 주변 넘어뜨림' },
  thunder:{ w:'낙뢰!', k:'pillar', r:70, dmg:8, react:'launch', d:'번개 기둥 · 주변 띄움' }, bridge:{ w:'쿠웅!', k:'quake', r:86, dmg:7, react:'sweep', d:'바닥 충격파 · 주변 넘어뜨림' } };
function bossBreak(a){ a.e.brk=(a.e.brk||0)+1; swPush(a.d.x, a.d.y-40, 4, GS.hero&&GS.hero.d.flip?-1:1); GS.bossBreak={ a, t:3.2, T0:3.2 }; a.e.stun=3.2; a.action=null; a.queue=[];
  comicT=0; comicSFX(a.d.x, a.d.y-78, tr('무너졌다!')); shakeAmp=Math.max(shakeAmp||0,3); GS.slowT=Math.max(GS.slowT||0,.35); if(sfx.brass) sfx.brass();
  GS.comboCD=0; const {S}=routeSets(); GS.bag.forEach((b,k)=>{ if(b && S.has(b.uid)) b.t=Math.max(b.t,sStats(k).cd); });            // 숨 고르기 끝 · 시작기 바로
  HITFX.push({ k:'sig_ring', x:a.d.x, y:a.d.y-30, t:0, life:.6, r:74 }); GS.stats.breaks=(GS.stats.breaks||0)+1; }
function bossScene(a){ GS.items.push({ kind:'gear', id:pickGear(), x:a.d.x+10, z:a.z, t:0 }); pops.push({ x:a.d.x-20, y:a.d.y-92, t:tr('명장면!'), age:0, c:'#ffd36a' });
  comicT=0; comicSFX(a.d.x, a.d.y-84, tr('명장면!')); META.bossScenes=META.bossScenes||{}; META.bossScenes[a.e.t]=(META.bossScenes[a.e.t]||0)+1; metaDirty=true; GS.stats.bossScenes=(GS.stats.bossScenes||0)+1; }
// 볼링: 크게 날아가는 적이 서 있는 적과 겹치면 넘어뜨린다(콤보 중이면 콤보 처치)
// 몸 간격: 서 있는 몸끼리 너무 붙지 않게 매 프레임 밀어낸다(주인공 ↔ 적 18px · 적끼리 14px)
// 예외: 떠 있음 · 누움 · 잡힘 · 꽂히는 중, 주인공이 공중이거나 잡기 기술 중
const SEP_HF=20, SEP_FF=14;
const solidFoe=a=> a.e && !a.dead && !a.hidden && !a.held && !a.jug && !a.spike && !a.pass && !a.kane && !a.carDummy && !a.carOwner && !isDown(a);
function bodySep(){ const H=GS.hero; if(!H || GS.skinPv) return; const F=GS.ents.filter(solidFoe), W0=AW0(), W1=AW1();
  const heroSolid = !H.hidden && !H.dead && !heroAirborne(H) && !['throw','suplex','spcHold','spcLift','spcSlam'].includes(H.anim);
  if(heroSolid) for(const a of F){ const dx=a.d.x-H.d.x, ad=Math.abs(dx); if(ad>=SEP_HF) continue;
    const sd = ad>.5 ? Math.sign(dx) : (H.d.flip?-1:1), ov=SEP_HF-ad; let fa=ov*.7, fh=ov*.3;
    const nx=a.d.x+sd*fa; if(nx<W0 || nx>W1){ const room=sd>0?W1-a.d.x:a.d.x-W0; fa=Math.max(0,room); fh=ov-fa; }   // 벽에 붙은 적이면 주인공을 민다
    a.d.x+=sd*fa; H.d.x=Math.max(W0,Math.min(W1,H.d.x-sd*fh)); }
  for(let i=0;i<F.length;i++) for(let j=i+1;j<F.length;j++){ const A=F[i], B=F[j], dx=B.d.x-A.d.x, ad=Math.abs(dx); if(ad>=SEP_FF) continue;   // 적끼리는 가볍게(무리가 한 점에 쌓이지 않게)
    const sd = ad>.5 ? Math.sign(dx) : (i%2?1:-1), ov=(SEP_FF-ad)*.5; A.d.x=Math.max(W0,Math.min(W1,A.d.x-sd*ov)); B.d.x=Math.max(W0,Math.min(W1,B.d.x+sd*ov)); } }
// 벽꽝: 끝 벽까지 날아간 적은 벽에 부딪혀 튕겨 나온다(주인공 쪽으로 돌아와 다시 붙는다) · 작은 피해 · 흔들림 · 먼지 · 작은 충격파
function wallCheck(a){ if(GS.demo || a.dojo || GS.state!=='fight' || a.held || a.kane || a.carDummy || a.carOwner) return;
  const J=a.jug, vx=J?J.vx:(a.kb||0), dir=Math.sign(vx), W0=AW0(), W1=AW1(); if(!dir || Math.abs(vx)<(J?85:90)) return;
  if(!(dir<0 ? a.d.x<=W0 : a.d.x>=W1) || GS.time-(a.wallT||-9)<.5) return; a.wallT=GS.time;
  const sp=Math.abs(vx), h=J?Math.max(0,J.h):(a.airOv||0), wx=dir<0?W0-4:W1+4; a.d.x=dir<0?W0:W1;
  if(J){ J.vx=-dir*Math.min(130,sp*.42); J.vy=Math.max(J.vy,J.h<30?120:40); J.hitT=GS.time+.18; J.wallP=GS.time+.13; J.spinR=(J.spinR||0)*.4; J.wallB=true; GS.poleT=GS.time; a.kb=J.vx; if(a.lastP){ a.bFrom=a.lastP; a.bT0=gameTime; a.bDur=.04; } }   /* 등이 벽에 붙는 자세 0.13초 */
  else { a.kb=-dir*Math.min(110,sp*.45); if(!a.dead && a.d.jw && !FALLS.has(a.anim)){ setAnim(a,'rWall'); if(a.e && !a.e.boss) a.e.stun=Math.max(a.e.stun||0,.5); } }   /* 서서 부딪히면 벽에 붙었다 휘청 */
  a.hs=Math.max(a.hs||0,3); a.shkA=2; shakeAmp=Math.max(shakeAmp||0, sp>200?2.8:2); GS.shoveX=(GS.shoveX||0)+dir*3;
  const y=a.d.y-26-h; sparks.push({x:wx,y,age:0}); dusts.push({ x:wx-dir*4, y:a.d.y, age:0, flip:dir>0 }); swPush(wx, y, 2, -dir);
  comicT=0; comicSFX(wx-dir*20, a.d.y-96-h, tr('쾅!')); try{ sfx.thud(); }catch(e){}
  if(a.e && !a.dead){ const dm=Math.max(1,Math.round(4*(1+.12*(GS.ci||0)))); if(a.e.hp>dm){ a.e.hp-=dm; GS.stats.dealt+=dm; GS.score+=60; dmgPop(a, Math.round(dm*DMG_K), 'hit', null, '#ffb070'); } }
  GS.stats.walls=(GS.stats.walls||0)+1; }
function bowlCheck(a){ const H=GS.hero, sx=Math.sign(a.kb||(a.jug&&a.jug.vx)||0); if(!sx||!H) return;
  const x0=(a._bwt!=null && GS.time-a._bwt<.15) ? a._bwx : a.d.x; a._bwx=a.d.x; a._bwt=GS.time;   /* 지난 프레임부터 지나온 길 전체를 본다(빠르게 날아가도 건너뛰지 않게) */
  const lo=Math.min(x0,a.d.x)-9, hi=Math.max(x0,a.d.x)+9;
  for(const o of foes()){ if(o===a||o.dead||o.held||o.jug||isDown(o)||(o.bowlT||0)>GS.time) continue; if(o.d.x<lo || o.d.x>hi || (o.d.x-x0)*sx<-3) continue;
    o.bowlT=GS.time+1.2; o.finKill=!!GS.croute; comicT=0; comicSFX(o.d.x, o.d.y-58, tr('볼링!')); damage(H,o,Math.round(6*(1+.15*(GS.ci||0))),{ react:'sweep' }); if(!o.dead) o.finKill=false;
    if(a.kb) a.kb*=.55; if(a.jug&&a.jug.vx) a.jug.vx*=.55; GS.stats.bowls=(GS.stats.bowls||0)+1; break; } }
function sigCheck(b){ const C=GS.croute; if(!C || C.sig) return null; const k=C.uids.indexOf(b.uid); if(k<0) return null;
  const ids=C.uids.slice(0,k+1).map(u=>{ const o=GS.bag.find(x=>x&&x.uid===u); return o&&o.id; }); if(ids.some(x=>!x)) return null; const B=bookOf(ids); return B && B.r.length===ids.length ? B : null; }
function sigFire(B,T){ const S=SIG[B.id], H=GS.hero; if(!S||!T) return; const f=H.d.flip?-1:1, x=T.d.x, y=T.d.y-30-(T.jug?T.jug.h:0); swPush(x, y, 4, f);
  comicT=0; comicSFX(x, y-34, S.w); shakeAmp=Math.max(shakeAmp||0,3.4); GS.slowT=Math.max(GS.slowT||0,.24); sfx.hitK('big',true,0);
  if(S.k==='moon'||S.k==='moon2'){ HITFX.push({ k:'crescent', x:H.d.x+f*6, y:H.d.y-44, r:56, w:18, f, a0:84*Math.PI/180, a1:-104*Math.PI/180, t:0, life:.34 }); if(S.k==='moon2') HITFX.push({ k:'crescent', x:H.d.x+f*6, y:H.d.y-44, r:40, w:12, f, a0:84*Math.PI/180, a1:-104*Math.PI/180, t:-.08, life:.3 }); }
  else HITFX.push({ k:'sig_'+S.k, x, y, f, t:0, life:S.k==='stamp'?1.1:.6, r:S.r });
  if(S.k==='quake') groundImpact(x, T.d.y, 1.6); if(S.k==='stamp') pagesBurst(x, y);
  const sc=1+.15*(GS.ci||0)+.25*(GS.stageIdx||0);
  for(const a of foes()){ if(a===T||a.dead||a.held||!a.e||Math.abs(a.d.x-x)>S.r) continue; a.sigKill=true; a.finKill=true;
    if(S.stun){ a.e.stun=S.stun; a.action=null; a.queue=[]; damage(H,a,Math.round(S.dmg*sc),{}); }
    else damage(H,a,Math.round(S.dmg*sc),{ knock:!S.react, react:S.react });
    if(!a.dead){ a.sigKill=false; a.finKill=false; } }
  GS.stats.sigs=(GS.stats.sigs||0)+1; }
function metaBook(ids,hits){ const B=bookOf(ids); if(!B) return null; if(GS.prologue||GS.pBag){ META.cseen=META.cseen||{}; if(!META.cseen[B.id]){ META.cseen[B.id]=1; metaDirty=true; } return null; } META.cbook=META.cbook||{}; const fresh=!META.cbook[B.id], e=META.cbook[B.id]||(META.cbook[B.id]={ n:0, best:0 }); e.n++; e.best=Math.max(e.best,hits); metaDirty=true; return fresh?B:null; }
function metaCombo(C){ try{ const ids=C.uids.map(u=>{ const o=GS.bag.find(b=>b&&b.uid===u); return o&&o.id; }).filter(Boolean); if(ids.length<2) return false; const key=ids.join('>');
  C.book=metaBook(ids.slice(0,C.k||ids.length),C.hits);   // 콤보 도감: 실제로 나간 순서 기준
  if(GS.prologue||GS.pBag) return false;   // 프롤로그 콤보는 노트에 기록하지 않는다(도감엔 목격만)
  META.combos=META.combos||{}; const fresh=!META.combos[key], e=META.combos[key]||(META.combos[key]={ name:C.name.replace('콤보 잇기 · ',''), ids, n:0, best:0 }); e.n++; e.best=Math.max(e.best,C.hits); metaDirty=true; return fresh; }catch(e){ return false; } }
const NOIR=(()=>{
  const SS=2, CELL=64;
  const FAMC={ fist:'#ff9a6b', foot:'#7ad7ff', grap:'#c59bff', aid:'#e2cf8e' };
  const BG={ fist:['#eab08a','#c27858','#3a1c18'], foot:['#a9d4ec','#5f93b6','#14263a'], grap:['#cdb6ef','#8a6cbf','#24193a'], aid:['#ead59a','#b49650','#2e2614'] };   // 역광: 밝은 중심 → 중간 → 어두운 가장자리
  const INK='#07060b', RIM='#f1e6cf', CREAM='#efe6d2';
  let seed=7; const rnd=()=>{ seed=(seed*16807)%2147483647; return seed/2147483647; };
  const L={ torso:29, neck:3, head:6, ua:17, fa:14, th:26, sh:25, ft:8 };   // 8등신
  const dir=a=>[Math.cos(a*Math.PI/180), Math.sin(a*Math.PI/180)], add=(p,a,l)=>{ const d=dir(a); return [p[0]+d[0]*l, p[1]+d[1]*l]; };
  function fk(P){ const hips=[0,0], neck=add(hips,P.torso,L.torso), head=add(neck,P.torso,L.neck+L.head), u=dir(P.torso), fr=[-u[1],u[0]];
    const shF=[neck[0]+fr[0]*6-u[0]*2.5, neck[1]+fr[1]*6-u[1]*2.5], shB=[neck[0]-fr[0]*5-u[0]*2.5, neck[1]-fr[1]*5-u[1]*2.5];
    const eF=add(shF,P.uaF,L.ua), hF=add(eF,P.faF,L.fa), eB=add(shB,P.uaB,L.ua), hB=add(eB,P.faB,L.fa);
    const kF=add(hips,P.thF,L.th), fF=add(kF,P.shF,L.sh), kB=add(hips,P.thB,L.th), fB=add(kB,P.shB,L.sh);
    const toeF=add(fF,(P.shF??90)-90+(P.toeF||0),L.ft), toeB=add(fB,(P.shB??90)-90+(P.toeB||0),L.ft);
    const J={hips,neck,head,shF,shB,eF,hF,eB,hB,kF,fF,kB,fB,toeF,toeB, ta:P.torso};
    if(!P.air){ const gy=Math.max(fF[1],fB[1],toeF[1],toeB[1]); for(const k in J) if(Array.isArray(J[k])) J[k]=[J[k][0],J[k][1]-gy]; } return J; }
  function bbox(J){ let x0=1e9,y0=1e9,x1=-1e9,y1=-1e9; for(const k in J){ if(!Array.isArray(J[k])) continue; const [x,y]=J[k], r=k==='head'?L.head+1:3; x0=Math.min(x0,x-r); y0=Math.min(y0,y-r); x1=Math.max(x1,x+r); y1=Math.max(y1,y+r); } return {x0,y0,x1,y1,w:x1-x0,h:y1-y0}; }
  function capsule(c,a,b,r0,r1){ const dx=b[0]-a[0], dy=b[1]-a[1], l=Math.hypot(dx,dy)||1, an=Math.atan2(dy,dx), d=Math.asin(Math.max(-1,Math.min(1,(r0-r1)/l)));
    c.beginPath(); c.arc(a[0],a[1],r0,an+Math.PI/2+d,an+Math.PI*1.5-d); c.arc(b[0],b[1],r1,an-Math.PI/2-d,an+Math.PI/2+d); c.closePath(); c.fill(); }
  function silhouette(c,J,T,s,parts){ const g=k=>T(J[k]), S=r=>r*s*1.2, want=p=>!parts||parts.includes(p);
    if(want('legB')){ capsule(c,g('hips'),g('kB'),S(3.6),S(2.6)); capsule(c,g('kB'),g('fB'),S(2.6),S(1.6)); capsule(c,g('fB'),g('toeB'),S(1.8),S(1.3)); }
    if(want('armB')){ capsule(c,g('shB'),g('eB'),S(2.5),S(2)); capsule(c,g('eB'),g('hB'),S(2),S(1.5)); c.beginPath(); c.arc(...g('hB'),S(2.2),0,7); c.fill(); }
    if(want('torso')){ const h=g('hips'), n=g('neck'), dx=n[0]-h[0], dy=n[1]-h[1], l=Math.hypot(dx,dy)||1, px=-dy/l*s, py=dx/l*s, w=(p,k)=>[[p[0]+px*k,p[1]+py*k],[p[0]-px*k,p[1]-py*k]];
      const sho=[n[0]-dx*.06,n[1]-dy*.06], [nL,nR]=w(sho,9.2), [hL,hR]=w(h,5.6), mid=[h[0]+dx*.38,h[1]+dy*.38], [mL,mR]=w(mid,5.2);
      c.beginPath(); c.moveTo(...nL); c.quadraticCurveTo(mL[0],mL[1],hL[0],hL[1]); c.lineTo(...hR); c.quadraticCurveTo(mR[0],mR[1],nR[0],nR[1]); c.closePath(); c.fill();
      const [cL,cR]=w([h[0]-dx*.08,h[1]-dy*.08],6.2); c.beginPath(); c.moveTo(...hL); c.lineTo(...cL); c.lineTo(...cR); c.lineTo(...hR); c.closePath(); c.fill();
      capsule(c,g('neck'),g('head'),S(2.2)/1.2,S(2)/1.2); }
    if(want('head')){ const hd=g('head'), r=L.head*s; c.beginPath(); c.arc(hd[0],hd[1],r,0,7); c.fill(); const ta=(J.ta||-90)*Math.PI/180, ux=Math.cos(ta), uy=Math.sin(ta); c.beginPath(); c.ellipse(hd[0]+ux*r*.25-uy*r*.2, hd[1]+uy*r*.25+ux*r*.2, r*1.08, r*.82, ta+Math.PI/2, 0, 7); c.fill(); }
    if(want('legF')){ capsule(c,g('hips'),g('kF'),S(3.7),S(2.7)); capsule(c,g('kF'),g('fF'),S(2.7),S(1.7)); capsule(c,g('fF'),g('toeF'),S(1.9),S(1.4)); }
    if(want('armF')){ capsule(c,g('shF'),g('eF'),S(2.6),S(2.1)); capsule(c,g('eF'),g('hF'),S(2.1),S(1.6)); c.beginPath(); c.arc(...g('hF'),S(2.3),0,7); c.fill(); } }
  function rimLayer(w,h,draw,lx,ly,col,thick){ const a=document.createElement('canvas'); a.width=w; a.height=h; const x=a.getContext('2d'); x.fillStyle=col; draw(x);
    x.globalCompositeOperation='destination-out'; x.save(); x.translate(-lx*thick,-ly*thick); x.fillStyle='#000'; draw(x); x.restore(); return a; }
  function face(c,J,T,s,m,kind,col,wid){ const hd=T(J.head), r=L.head*s, ta=(J.ta??-90)*Math.PI/180, u=[Math.cos(ta),Math.sin(ta)], f=[-u[1]*m,u[0]*m], P=(a,b)=>[hd[0]+f[0]*a*r+u[0]*b*r, hd[1]+f[1]*a*r+u[1]*b*r];
    c.save(); c.strokeStyle=col; c.lineCap='round'; c.lineWidth=wid; c.beginPath();
    if(kind==='glare'){ c.moveTo(...P(.12,.2)); c.lineTo(...P(.92,.06)); } else if(kind==='hurt'){ c.moveTo(...P(.2,.22)); c.lineTo(...P(.55,.08)); c.lineTo(...P(.9,.2)); } else if(kind==='panic'){ c.arc(...P(.62,-.38), r*.16, 0, 7); }
    c.stroke(); c.restore(); }
  function figure(c,J,ox,oy,s,o={}){ const m=o.mirror?-1:1, T=p=>[ox+p[0]*s*m, oy+p[1]*s], W=c.canvas.width, H=c.canvas.height;
    if(o.ghost){ c.save(); c.globalAlpha=o.ghost*.7; c.fillStyle='#232032'; silhouette(c,J,T,s); face(c,J,T,s,m,'hurt','rgba(241,230,207,.7)',Math.max(.9*SS,.45*s)); c.restore(); return; }
    c.fillStyle=o.tone||INK; silhouette(c,J,T,s);
    c.drawImage(rimLayer(W,H,x=>silhouette(x,J,T,s),-.7,-.7,RIM,1.6*SS),0,0);
    if(o.accent){ c.save(); c.globalAlpha=.55; c.fillStyle=o.accentCol; silhouette(c,J,T,s,[o.accent]); c.restore();
      c.globalCompositeOperation='multiply'; c.fillStyle='#2a2838'; silhouette(c,J,T,s,[o.accent]); c.globalCompositeOperation='source-over';
      c.drawImage(rimLayer(W,H,x=>silhouette(x,J,T,s,[o.accent]),-.7,-.7,o.accentCol,2.2*SS),0,0); }
    face(c,J,T,s,m,o.face||'glare',RIM,Math.max(1.1*SS,.55*s));
    if(!o.noTie){ const n=T(J.neck), h=T(J.hips); c.strokeStyle='rgba(241,230,207,.55)'; c.lineWidth=.9*SS; c.beginPath(); c.moveTo(n[0]+(h[0]-n[0])*.08, n[1]+(h[1]-n[1])*.08); c.lineTo(n[0]+(h[0]-n[0])*.42, n[1]+(h[1]-n[1])*.42); c.stroke(); }
    if(o.prop) o.prop(c,T,J,s,m); }
  const POSES={
    cross: { torso:-80, uaF:-4, faF:-3, uaB:72, faB:-118, thB:62, shB:96, thF:118, shF:100 },
    swat:  { torso:-84, uaF:-112, faF:-62, uaB:70, faB:-120, thB:64, shB:96, thF:116, shF:100 },
    thrust:{ torso:-74, uaF:-6, faF:-4, uaB:150, faB:170, thB:50, shB:100, thF:150, shF:95 },
    caseSw:{ torso:-76, uaF:-30, faF:-12, uaB:80, faB:-110, thB:62, shB:96, thF:118, shF:100 },
    kick:  { torso:-102, uaF:105, faF:-70, uaB:62, faB:-115, thF:-6, shF:-4, thB:93, shB:88, toeF:-60 },
    round: { torso:-122, uaF:-35, faF:-70, uaB:155, faB:175, thF:-24, shF:-16, thB:97, shB:84, toeF:-40 },
    elbow: { torso:-78, uaF:-6, faF:172, uaB:74, faB:-122, thB:64, shB:95, thF:118, shF:100 },
    knee:  { torso:-96, uaF:35, faF:115, uaB:45, faB:125, thF:-28, shF:78, thB:92, shB:88 },
    upper: { torso:-74, uaF:-75, faF:-100, uaB:80, faB:-125, thB:76, shB:100, thF:112, shF:96 },
    sweep: { torso:-40, uaF:100, faF:92, uaB:170, faB:205, thB:22, shB:122, thF:2, shF:0, toeF:-80 },
    charge:{ torso:-32, uaF:62, faF:-48, uaB:100, faB:-60, thB:42, shB:108, thF:140, shF:72 },
    stomp: { torso:-96, uaF:40, faF:120, uaB:60, faB:130, thF:58, shF:92, thB:95, shB:88, toeF:0 },
    duck:  { torso:-48, uaF:70, faF:-110, uaB:85, faB:-120, thF:30, shF:120, thB:60, shB:150 },
    bkick: { torso:-48, uaF:120, faF:-80, uaB:150, faB:-60, thF:182, shF:180, thB:94, shB:90, toeF:80 },
    bfist: { torso:-96, uaF:186, faF:176, uaB:62, faB:-115, thB:70, shB:96, thF:112, shF:98 },
    fkick: { torso:-150, uaF:-62, faF:-30, uaB:165, faB:125, thF:-2, shF:-3, thB:42, shB:140, air:true, toeF:-70 },
    renkan:{ torso:-104, uaF:150, faF:118, uaB:-118, faB:-78, thF:-78, shF:-84, thB:112, shB:150, air:true, toeF:-86 },
    tetsu: { torso:-58, uaF:72, faF:96, uaB:-168, faB:-140, thF:26, shF:82, thB:150, shB:98, toeF:0 },
    cycle: { torso:-122, uaF:-168, faF:-132, uaB:150, faB:118, thF:-22, shF:-34, thB:42, shB:122, air:true, toeF:-40 },
    axe:   { torso:-99, uaF:142, faF:166, uaB:44, faB:104, thF:-84, shF:-94, thB:93, shB:90, toeF:-96 },
    sx:    { torso:-158, uaF:-168, faF:-196, uaB:-176, faB:-204, thF:66, shF:100, thB:80, shB:100 },
    skick: { torso:150, uaF:100, faF:150, uaB:200, faB:250, thF:-60, shF:-75, thB:30, shB:110, air:true, toeF:-40 },
    throwH:{ torso:-90, uaF:-102, faF:-84, uaB:-78, faB:-98, thF:104, shF:94, thB:76, shB:86 },
    carried:{ torso:192, uaF:-115, faF:-150, uaB:105, faB:70, thF:-38, shF:52, thB:-12, shB:78, air:true },
    fallen: { torso:178, uaF:100, faF:80, uaB:60, faB:20, thF:-4, shF:6, thB:6, shB:-4, air:true },
    launched:{ torso:-150, uaF:-140, faF:-170, uaB:160, faB:120, thF:60, shF:90, thB:80, shB:120, air:true },
    hitBack:{ torso:-118, uaF:200, faF:150, uaB:-30, faB:10, thF:70, shF:110, thB:110, shB:80 },
  };
  // 소품
  const propLine=(len,w0,w1,col,tipCol)=>(c,T,J,s,m)=>{ const h=T(J.hF), e=T(J.eF), dx=h[0]-e[0], dy=h[1]-e[1], l=Math.hypot(dx,dy)||1, ux=dx/l, uy=dy/l;
    c.save(); c.fillStyle=col; capsule(c,[h[0]-ux*2*s,h[1]-uy*2*s],[h[0]+ux*len*s,h[1]+uy*len*s],w0*s,w1*s); if(tipCol){ c.fillStyle=tipCol; c.beginPath(); c.arc(h[0]+ux*len*s,h[1]+uy*len*s,w1*s*1.3,0,7); c.fill(); } c.restore(); };
  const PROPS={ paper:propLine(13,2.4,2.2,'#e9e1cc'), umb:(c,T,J,s,m)=>{ propLine(40,1.9,1.1,'#2b3550','#d8dce6')(c,T,J,s,m); },
    case:(c,T,J,s,m)=>{ const h=T(J.hF); c.save(); c.fillStyle='#5a3a24'; c.fillRect(h[0]-1*s*m-(m<0?12*s:0), h[1]-2*s, 12*s, 9*s); c.fillStyle='#c9a24a'; c.fillRect(h[0]+4*s*m-(m<0?2*s:0), h[1]-1*s, 2*s, 2*s); c.restore(); } };
  function bgFill(c,fam,W,H,lx,ly){ const [c0,cm,c1]=BG[fam]; const R=Math.max(W,H)*.78, g=c.createRadialGradient(lx,ly,0,lx,ly,R); g.addColorStop(0,c0); g.addColorStop(.38,cm); g.addColorStop(1,c1); c.fillStyle=g; c.fillRect(0,0,W,H);
    c.save(); c.globalAlpha=.07; c.fillStyle=INK; for(let k=-H;k<W;k+=22*SS){ c.beginPath(); c.moveTo(k,0); c.lineTo(k+5*SS,0); c.lineTo(k+5*SS+H*.55,H); c.lineTo(k+H*.55,H); c.closePath(); c.fill(); } c.restore();
    c.save(); c.globalAlpha=.06; for(let i=0;i<W*H/60;i++){ c.fillStyle=rnd()<.5?'#000':'#fff'; c.fillRect(rnd()*W,rnd()*H,SS,SS); } c.restore(); }
  function halftone(c,W,H,lx,ly,col){ const st=5.5*SS, R=Math.hypot(W,H)*.62; c.save(); c.fillStyle=col;
    for(let y=0,row=0;y<H+st;y+=st,row++) for(let x=(row%2)*st/2;x<W+st;x+=st){ const d=Math.min(1,Math.hypot(x-lx,y-ly)/R), k=Math.max(0,(d-.28)/.72); if(k<=0) continue; c.globalAlpha=.16+.22*k; c.beginPath(); c.arc(x,y,k*1.7*SS,0,7); c.fill(); } c.restore(); }
  function focusLines(c,cx,cy,W,H){ const n=34, R=Math.hypot(W,H); c.save(); c.fillStyle=INK;
    for(let i=0;i<n;i++){ const a=i/n*Math.PI*2+rnd()*.12, r0=(22+rnd()*20)*SS, w=(.9+rnd()*1.6)*SS, ux=Math.cos(a), uy=Math.sin(a), px=-uy, py=ux;
      c.globalAlpha=.08+rnd()*.1; c.beginPath(); c.moveTo(cx+ux*r0, cy+uy*r0); c.lineTo(cx+ux*R+px*w, cy+uy*R+py*w); c.lineTo(cx+ux*R-px*w, cy+uy*R-py*w); c.closePath(); c.fill(); } c.restore(); }
  function straps(c,cells,C){ c.save(); c.strokeStyle='#05040a'; c.globalAlpha=.45; c.lineWidth=1.4*SS;
    cells.forEach(([x,y])=>{ if(y!==0) return; for(const fx of [.28,.74]){ const sx=(x+fx)*C, Lh=(10+rnd()*5)*SS; c.beginPath(); c.moveTo(sx,0); c.lineTo(sx,Lh); c.stroke(); c.beginPath(); c.ellipse(sx,Lh+3.6*SS,2.8*SS,3.6*SS,0,0,7); c.stroke(); } }); c.restore(); }
  function taper(c,pts,w0,w1,col,alpha=1){ c.save(); c.globalAlpha=alpha; c.fillStyle=col; for(let i=0;i<pts.length-1;i++){ const t0=i/(pts.length-1), t1=(i+1)/(pts.length-1); capsule(c,pts[i],pts[i+1],(w0+(w1-w0)*t0)*SS/2,(w0+(w1-w0)*t1)*SS/2); } c.restore(); }
  const speed=(x0,y0,n=4,len=16,gap=6,dirn=-1)=>(c,C)=>{ for(let i=0;i<n;i++){ const y=y0*C+i*gap*SS, l=(len-(i%2)*6)*SS; taper(c,[[x0*C,y],[x0*C+dirn*l,y]],1.6,.2,INK,.5); } };
  const cres=(cx,cy,r,a0,a1,w)=>(c,C)=>{ const N=28; for(const [k,col,al] of [[1,INK,.55],[.8,FAMC.foot,.95],[.42,'#f6fffa',1]]){ c.save(); c.globalAlpha=al; c.fillStyle=col; c.beginPath();
      for(let i=0;i<=N;i++){ const a=(a0+(a1-a0)*i/N)*Math.PI/180; c.lineTo(cx*C+Math.cos(a)*r*C, cy*C+Math.sin(a)*r*C); }
      for(let i=N;i>=0;i--){ const sN=i/N, a=(a0+(a1-a0)*sN)*Math.PI/180, rr=r*C-w*SS*k*Math.pow(Math.sin(Math.PI*sN),.7); c.lineTo(cx*C+Math.cos(a)*rr, cy*C+Math.sin(a)*rr); }
      c.closePath(); c.fill(); c.restore(); } };
  const arc=(cx,cy,rx,ry,a0,a1)=>(c,C)=>{ const pts=[]; for(let a=a0;a<=a1;a+=4) pts.push([cx*C+Math.cos(a*Math.PI/180)*rx*C, cy*C+Math.sin(a*Math.PI/180)*ry*C]); taper(c,pts,.3,3.2,INK,.55); };
  const flash=(x,y,r=7)=>(c,C)=>{ const cx=x*C, cy=y*C; c.save(); c.fillStyle=RIM; c.globalAlpha=.9; c.beginPath(); for(let i=0;i<=16;i++){ const a=i/16*Math.PI*2, rr=(i%2?r*.35:r)*SS; c.lineTo(cx+Math.cos(a)*rr, cy+Math.sin(a)*rr); } c.closePath(); c.fill(); c.restore(); };
  const sfx=(t,x,y,size=12,rot=-.12)=>(c,C)=>{ c.save(); c.translate(x*C,y*C); c.rotate(rot); c.font=`700 ${size*SS}px Galmuri11`; c.textAlign='center'; c.textBaseline='middle'; c.lineJoin='round'; c.lineWidth=3.2*SS; c.strokeStyle=INK; c.strokeText(t,0,0); c.fillStyle=CREAM; c.fillText(t,0,0); c.restore(); };
  const target=(pose,x,y,k=1,mirror=true)=>(c,C)=>{ const J=fk(POSES[pose]), B=bbox(J), s=k*SS*1.4; figure(c,J,x*C-(B.x0+B.w/2)*s*(mirror?-1:1),y*C-B.y1*s,s,{ghost:.85,mirror}); };
  const bottle=(x,y)=>(c,C)=>{ c.save(); c.translate(x*C,y*C); c.rotate(-.6); c.fillStyle=RIM; c.globalAlpha=.85; c.fillRect(-2*SS,-6*SS,4*SS,10*SS); c.fillRect(-1*SS,-9*SS,2*SS,3*SS); c.restore(); speed(x+.12,y-.05,3,9,4,1)(c,C); };
  // 블록 구성(회전 0 기준): 인물이 설 영역 · 소품 · 대상 · 효과
  const DEF={
    punch: { pose:'cross', area:[0,.34,1,2], accent:'armF', impact:[.93,.82], back:[speed(.99,.9,3,9,4.5,-1)], front:[flash(.93,.82,5), sfx('퍽!',.72,.58,10,-.1)] },
    paper: { pose:'swat', area:[0,.34,1,2], accent:'armF', prop:'paper', impact:[.78,.5], front:[sfx('찰싹!',.6,1.2,9,-.12)] },
    umb:   { pose:'thrust', area:[0,.34,1,2], accent:'armF', prop:'umb', impact:[1.6,.62], back:[target('hitBack',1.8,.98,.5)], front:[flash(1.58,.62,6), sfx('푹!',1.55,.28,10,-.1)] },
    case:  { pose:'caseSw', area:[0,.34,1.3,2], accent:'armF', prop:'case', impact:[1.42,1.0], back:[target('hitBack',1.8,1.98,.55)], front:[flash(1.42,1.0,7), sfx('쾅!',1.5,.42,12,-.1)] },
    kick:  { pose:'kick', area:[0,.34,1.62,2], accent:'legF', impact:[1.62,1.36], back:[speed(1.96,1.28,4,13,5.5,-1), target('hitBack',1.82,1.98,.62)], front:[flash(1.62,1.36,6), sfx('퍽!',1.55,1.12,11,-.15)] },
    knee:  { pose:'knee', area:[0,.34,1,2], accent:'legF', impact:[.72,.98], front:[flash(.72,.98,5), sfx('쿵!',.74,.6,10,-.18)] },
    elbow: { pose:'elbow', area:[.5,.34,2,2], mirror:true, accent:'armF', impact:[.72,.62], back:[target('hitBack',.32,.98,.5,false)], front:[flash(.72,.62,6), sfx('콱!',.36,.26,11,.14)] },
    round: { pose:'round', area:[.6,0,2.2,2], accent:'legF', impact:[2.28,.42], back:[arc(1.45,.85,.95,.42,190,350), target('hitBack',2.72,.98,.52)], front:[flash(2.28,.42,7), sfx('쾅!',2.45,.24,12,-.12)] },
    upper: { pose:'upper', area:[0,1.1,1,3], accent:'armF', impact:[.66,1.08], back:[target('launched',.6,.98,.5,true)], front:[flash(.66,1.08,6), sfx('빡!',.42,.36,10,-.12)] },
    sweep: { pose:'sweep', area:[.95,0,2.1,1], accent:'legF', maxS:2.1, impact:[2.3,.86], back:[arc(1.6,.93,.55,.08,195,345), target('fallen',2.58,.98,.48,true)], front:[sfx('휙!',.5,.72,11,-.1)] },
    charge:{ pose:'charge', area:[0,.34,1.25,2], accent:'armF', impact:[1.3,1.4], back:[speed(.9,1.3,4,16,6,-1), target('hitBack',2.62,1.98,.55)], front:[flash(1.32,1.38,7), sfx('쿵!',2.1,1.24,11,-.1)] },
    throw: { pose:'throwH', area:[.55,.74,2.45,3], accent:'armF', partner:'carried', impact:[1.5,.42], back:[speed(2.95,.32,3,12,6,-1)], front:[sfx('번쩍!',1.5,2.86,9,.05)] },
    stomp: { pose:'stomp', area:[0,.34,1,2], accent:'legF', impact:[.74,1.86], back:[target('fallen',.62,1.99,.4,true)], front:[flash(.72,1.84,5), sfx('쿵!',.7,.66,10,-.15)] },
    duck:  { pose:'duck', area:[0,.36,1,1], accent:null, front:[bottle(.72,.24)] },
    bkick: { pose:'bkick', area:[.9,.12,3,2], accent:'legF', impact:[.72,.5], back:[target('hitBack',.4,.98,.5,false), speed(.9,.42,3,12,6,1)], front:[flash(.72,.5,6)] },
    bfist: { pose:'bfist', area:[.5,.34,2,2], accent:'armF', impact:[.66,.6], back:[target('hitBack',.32,.98,.5,false)], front:[flash(.66,.6,6), sfx('빡!',.4,.26,11,.12)] },
    skick: { pose:'skick', area:[0,.1,1,2.2], accent:'legF', impact:[.82,.55], back:[cres(.42,1.15,.78,80,-100,9)], front:[flash(.82,.55,6), sfx('슈욱!',.5,2.55,10,-.08)] },
    renkan:{ pose:'renkan', area:[0,.25,2,3], accent:'legF', impact:[.95,.45], back:[speed(.35,2.6,3,10,5,-1), target('launched',1.55,1.2,.48,true)], front:[flash(.95,.45,6), sfx('팍!',1.5,2.5,11,-.1)] },
    tetsu: { pose:'tetsu', area:[.25,.05,1.95,2], accent:'armF', impact:[1.55,.85], back:[arc(1.0,1.96,.75,.12,180,360), speed(.25,1.1,3,10,5,-1), target('hitBack',2.55,1.98,.5)], front:[flash(1.5,.85,8), sfx('쾅!',2.45,1.25,12,-.1)] },
    cycle: { pose:'cycle', area:[0,.08,1.95,2], accent:'legF', impact:[1.62,.4], back:[speed(.3,1.2,4,10,5,-1), arc(1.15,.5,.5,.32,200,330)], front:[flash(1.62,.4,6), sfx('팍팍팍!',1.45,.82,9,-.1)] },
    axe:   { pose:'axe', area:[0,.15,1,3], accent:'legF', impact:[.9,.42], back:[arc(.62,1.0,.42,.7,240,350), target('fallen',1.55,2.99,.5,true)], front:[flash(.9,.42,6), sfx('콰직!',1.45,2.25,11,-.14)] },
    suplex:{ pose:'sx', area:[.4,.55,2,2], accent:'armF', partner:'carried', impact:[.35,1.8], back:[arc(1.0,1.15,.75,.75,180,360)], front:[flash(.35,1.8,6), sfx('쿠웅!',1.45,.3,11,-.1)] },
    fkick: { pose:'fkick', area:[.45,.08,2.4,1], accent:'legF', impact:[2.42,.48], back:[speed(.62,.4,5,20,6,-1), target('hitBack',2.76,.98,.5)], front:[flash(2.42,.48,6)] },
  };
  function baseCanvas(id){ const it=GITEMS[id], sh=it.shape||[[0,0]], W=Math.max(...sh.map(p=>p[0]))+1, H=Math.max(...sh.map(p=>p[1]))+1, C=CELL*SS;
    const cv=document.createElement('canvas'); cv.width=W*C; cv.height=H*C; const c=cv.getContext('2d'); seed=11+id.length*7;
    const fam=it.fam&&FAMC[it.fam]?it.fam:'aid', def=DEF[id];
    c.save(); c.beginPath(); sh.forEach(([x,y])=>c.rect(x*C,y*C,C,C)); c.clip();
    if(def){ const J=fk(POSES[def.pose]), B=bbox(J), [rx0,ry0,rx1,ry1]=def.area.map(v=>v*C), pad=.06*C, aw=rx1-rx0-2*pad, ah=ry1-ry0-2*pad, m=def.mirror?-1:1;
      const s=Math.min(aw/B.w, ah/B.h, (def.maxS||1.45)*SS), ox=rx0+pad+aw/2-(B.x0+B.w/2)*s*m, oy=ry1-pad-B.y1*s, lx=ox+J.neck[0]*s*m-30*SS, ly=oy+J.neck[1]*s-20*SS;
      bgFill(c,fam,cv.width,cv.height,lx,ly); halftone(c,cv.width,cv.height,lx+30*SS,ly+20*SS,INK); if(def.impact) focusLines(c,def.impact[0]*C,def.impact[1]*C,cv.width,cv.height); straps(c,sh,C);
      if(!POSES[def.pose].air){ c.save(); c.globalAlpha=.55; c.fillStyle='#000'; c.beginPath(); c.ellipse(ox+J.hips[0]*s*m, oy+1.5*SS, 22*SS, 3*SS, 0, 0, 7); c.fill(); c.restore(); }
      (def.back||[]).forEach(e=>e(c,C));
      if(def.partner){ const J2=fk(POSES[def.partner]), b=[(J.hF[0]+J.hB[0])/2,(J.hF[1]+J.hB[1])/2], ax=ox+b[0]*s*m, ay=oy+b[1]*s; figure(c,J2,ax-(J2.hips[0]-1)*s*m,ay-(J2.hips[1]-2)*s,s,{mirror:def.mirror,noTie:true,tone:'#3a3650',face:'panic'}); }
      figure(c,J,ox,oy,s,{accent:def.accent,accentCol:FAMC[fam],mirror:def.mirror,prop:def.prop&&PROPS[def.prop]});
      (def.front||[]).forEach(e=>e(c,C)); }
    else { const cx=cv.width/2, cy=cv.height/2+6*SS; bgFill(c,fam,cv.width,cv.height,cx,cy); halftone(c,cv.width,cv.height,cx,cy,INK);
      const A=typeof itemArt==='function'?itemArt(id):null;   // 보조 아이템: 기존 도트 물건을 크게(도트 그대로)
      if(A){ const t=document.createElement('canvas'); t.width=A.W; t.height=A.H; const tx=t.getContext('2d'); for(let y=0;y<A.H;y++) for(let x=0;x<A.W;x++){ const q=A.a[y*A.W+x]; if(!q) continue; tx.fillStyle=ICON_PAL[q]; tx.fillRect(x,y,1,1); }
        const k=Math.min(cv.width*.78/A.W, (cv.height-20*SS)*.8/A.H), dw=A.W*k, dh=A.H*k; c.save(); c.imageSmoothingEnabled=false; c.globalAlpha=.55; c.filter='blur(6px)'; c.drawImage(t,cx-dw/2,cy-dh/2+3*SS,dw,dh); c.restore();
        c.save(); c.imageSmoothingEnabled=false; c.drawImage(t,cx-dw/2,cy-dh/2,dw,dh); c.restore(); } }
    const vg=c.createRadialGradient(cv.width/2,cv.height/2,Math.min(cv.width,cv.height)*.3,cv.width/2,cv.height/2,Math.max(cv.width,cv.height)*.75); vg.addColorStop(0,'rgba(0,0,0,0)'); vg.addColorStop(1,'rgba(0,0,0,.3)'); c.fillStyle=vg; c.fillRect(0,0,cv.width,cv.height);
    c.restore(); return cv; }
  const BASE={};
  const SHORT={ skick:'섬머솔트', paper:'신문', elbow:'팔꿈치', cuff:'커프스', throw:'메치기', charge:'어깨 돌진', bandage:'반창고', metro:'메트로카드' };
  const ROLEC={ S:'#e8b23a', L:'#2a2732', F:'#d6453a', X:'#8a7a52' };
  function roleGlyph(c,r,x,y,s){ c.save(); c.fillStyle=ROLEC[r]||INK; c.beginPath();
    if(r==='S'){ c.moveTo(x,y); c.lineTo(x+s,y+s/2); c.lineTo(x,y+s); }
    else if(r==='F'){ c.rect(x+.5*SS,y+.5*SS,s-SS,s-SS); }
    else if(r==='X'){ c.moveTo(x+s/2,y); c.lineTo(x+s,y+s/2); c.lineTo(x+s/2,y+s); c.lineTo(x,y+s/2); }
    else { c.arc(x+s/2,y+s/2,s/2-.5*SS,0,7); }
    c.closePath(); c.fill(); c.restore(); }
  function stateIcon(c,k,x,y,s){ const L=(pts)=>{ c.beginPath(); pts.forEach(([a,b],i)=>i?c.lineTo(x+a*s,y+b*s):c.moveTo(x+a*s,y+b*s)); c.stroke(); };
    c.save(); c.strokeStyle=INK; c.fillStyle=INK; c.lineWidth=Math.max(1,2.2*SS); c.lineCap='square'; c.lineJoin='miter';
    if(k==='G'){ L([[.05,.85],[.95,.85]]); c.fillRect(x+.4*s,y+.35*s,.2*s,.3*s); }
    else if(k==='A'){ L([[.15,.6],[.5,.2],[.85,.6]]); L([[.25,.92],[.75,.92]]); }
    else if(k==='T'){ L([[.1,.25],[.55,.75]]); L([[.05,.92],[.95,.92]]); c.fillRect(x+.62*s,y+.6*s,.22*s,.22*s); }
    else if(k==='C'){ L([[.2,.15],[.2,.6],[.75,.6]]); L([[.6,.45],[.78,.6],[.6,.75]]); }
    else if(k==='D'){ c.fillRect(x+.1*s,y+.62*s,.8*s,.2*s); L([[.05,.92],[.95,.92]]); }
    else if(k==='B'){ c.beginPath(); c.arc(x+.5*s,y+.52*s,.32*s,.4,5.6); c.stroke(); L([[.72,.12],[.86,.32],[.62,.36]]); }
    else if(k==='K'){ L([[.1,.2],[.45,.5],[.1,.8]]); L([[.5,.2],[.85,.5],[.5,.8]]); }
    else if(k==='P'){ L([[.45,.2],[.1,.5],[.45,.8]]); L([[.85,.2],[.5,.5],[.85,.8]]); }
    else if(k==='Z'){ L([[.5,.08],[.5,.92]]); L([[.1,.5],[.9,.5]]); L([[.2,.2],[.8,.8]]); L([[.8,.2],[.2,.8]]); }
    else if(k==='*'){ for(const [a,b] of [[.25,.3],[.7,.3],[.47,.72]]) c.fillRect(x+a*s,y+b*s,.2*s,.2*s); }
    else if(k==='='){ L([[.15,.38],[.85,.38]]); L([[.15,.66],[.85,.66]]); }
    c.restore(); }
  function url(id,rot,opt){ const it=GITEMS[id]; if(!it) return null; const B=BASE[id]||(BASE[id]=baseCanvas(id)), r=((rot||0)%4+4)%4, C=CELL*SS;
    const cv=document.createElement('canvas'); cv.width=r%2?B.height:B.width; cv.height=r%2?B.width:B.height; const c=cv.getContext('2d');
    c.save(); c.translate(cv.width/2,cv.height/2); c.rotate(r*Math.PI/2); c.drawImage(B,-B.width/2,-B.height/2); c.restore();
    // 캡션: 회전한 모양의 윗줄 가장 왼쪽 칸에 똑바로
    const cells=shapeOf(id,r), mx=Math.min(...cells.map(p=>p[0])), my=Math.min(...cells.map(p=>p[1])), top=cells.map(([x,y])=>[x-mx,y-my]).filter(p=>p[1]===0).sort((a,b)=>a[0]-b[0])[0];
    const T_=t=>typeof tr==='function'?tr(t):t, fam=it.fam&&FAMC[it.fam]?it.fam:'aid', nm=T_(SHORT[id]||it.n), cd=it.cond&&COND[it.cond]?T_(COND[it.cond].tag):'';
    const wide=cells.filter(p=>p[1]-my===0).length>=2, tx=top[0]*C, maxW=(wide?2:1)*C-14*SS;
    const box=(text,fs,y,bg,fg,bar)=>{ c.font=`700 ${fs}px Galmuri11`; let t=text; while(c.measureText(t).width>maxW && t.length>1) t=t.slice(0,-1); const bw=c.measureText(t).width+(bar?9:7)*SS, bh=fs+4.5*SS;
      c.fillStyle='rgba(0,0,0,.45)'; c.fillRect(tx+5*SS+1.5*SS, y+1.5*SS, bw, bh); c.fillStyle=bg; c.fillRect(tx+5*SS, y, bw, bh); if(bar){ c.fillStyle=FAMC[fam]; c.fillRect(tx+5*SS, y, 2.5*SS, bh); }
      c.fillStyle=fg; c.textBaseline='middle'; c.fillText(t, tx+(bar?9.5:8.5)*SS, y+bh/2+.5*SS); return bh; };
    const RO=opt&&opt.role&&(COMBO_ROLE[id]||(it.kind!=='skill'?{r:'X'}:null));
    if(RO){   // 시안: 첫 줄 이름(전체 폭) / 둘째 줄 역할 표시 + 상태 입력 → 출력
      const fs=(wide?11:10)*SS; box(nm, fs, 5*SS, CREAM, INK, true); const bh=fs+4.5*SS, y1=5*SS+bh+2*SS;
      const s2=11*SS, g=9*SS, has=!!RO.i, cw=g+(has?s2*2+15*SS:0)+8*SS, ch=s2+5*SS;
      c.fillStyle='rgba(0,0,0,.45)'; c.fillRect(tx+6.5*SS,y1+1.5*SS,cw,ch); c.fillStyle=RO.r==='S'?'#f3d27a':RO.r==='F'?'#f2a49a':CREAM; c.fillRect(tx+5*SS,y1,cw,ch);
      roleGlyph(c,RO.r,tx+8*SS,y1+(ch-g)/2,g);
      if(has){ const x0=tx+8*SS+g+4*SS; stateIcon(c,RO.i,x0,y1+2.5*SS,s2); c.fillStyle=INK; c.beginPath(); const ax=x0+s2+1.5*SS, ay=y1+ch/2; c.moveTo(ax,ay-3*SS); c.lineTo(ax+4.5*SS,ay); c.lineTo(ax,ay+3*SS); c.fill(); stateIcon(c,RO.o,x0+s2+7.5*SS,y1+2.5*SS,s2); }
      return cv.toDataURL(); }
    if(wide || !cd){ box(cd?`${nm} · ${cd}`:nm, (wide?11:10)*SS, 5*SS, CREAM, INK, true); }
    else { const h1=box(nm, 10*SS, 5*SS, CREAM, INK, true); box(cd, 8*SS, 5*SS+h1+1.5*SS, FAMC[fam], INK, false); }   // 좁은 블록: 조건은 둘째 줄
    return cv.toDataURL(); }
  return { url, has:id=>!!GITEMS[id], reset:()=>{ for(const k in BASE) delete BASE[k]; } };
})();

function artURL(id,rot,plain){ const k=id+'@'+(rot||0)+(plain?'p':''); if(k in ART_CACHE) return ART_CACHE[k];
  if(!plain && NOIR.has(id)){ try{ return ART_CACHE[k]=NOIR.url(id,rot||0,{role:true}); }catch(e){ console.warn('noir art',id,e); } }   // 느와르 블록 그림(모든 아이템)
  if(PANEL_SET[id]) return ART_CACHE[k]=panelURL(id,rot);                                                       // 기술은 만화 칸(칸마다 한 컷)
  const A=itemArt(id); if(!A){ ART_CACHE[k]=null; return null; }
  const r=((rot||0)%4+4)%4, cv=document.createElement('canvas'); cv.width=r%2?A.H:A.W; cv.height=r%2?A.W:A.H; const cx=cv.getContext('2d');
  cx.translate(cv.width/2,cv.height/2); cx.rotate(r*Math.PI/2); cx.translate(-A.W/2,-A.H/2);
  for(let y=0;y<A.H;y++) for(let x=0;x<A.W;x++){ const c=A.a[y*A.W+x]; if(!c) continue; cx.fillStyle=ICON_PAL[c]; cx.fillRect(x,y,1,1); }
  return ART_CACHE[k]=cv.toDataURL(); }

const ICON={};
function iconOf(name){
  if(ICON[name]) return ICON[name];
  if(ICON_ART[name]){ const rows=ICON_ART[name], cv=document.createElement('canvas'); cv.width=16; cv.height=16; const cx=cv.getContext('2d');
    rows.forEach((r,y)=>{ for(let x=0;x<16;x++){ const ch=r[x]; if(ch==='.') continue; cx.fillStyle=ICON_PAL[ch]; cx.fillRect(x,y,1,1); } });
    ICON[name]=cv.toDataURL(); return ICON[name]; } const s=SPR[name]; if(!s) return ''; const cv=document.createElement('canvas'); cv.width=s.w+2; cv.height=s.h+2;
  const cx=cv.getContext('2d'), im=cx.createImageData(s.w+2,s.h+2), at=(x,y)=>(x<0||y<0||x>=s.w||y>=s.h)?0:s.mat[y*s.w+x];
  for(let y=-1;y<=s.h;y++) for(let x=-1;x<=s.w;x++){ const o=((y+1)*(s.w+2)+(x+1))*4, m=at(x,y);
    if(m){ const i=y*s.w+x; const st=s.emit[i]>.5?5:Math.max(0,Math.min(5,Math.floor(s.tone[i]*7.2)+(s.ny[i]>.3?1:s.ny[i]<-.3?-1:0))); const c=(PALS[0][m]||PALS[0][1])[st]; im.data.set([c[0],c[1],c[2],255],o); }
    else if(at(x+1,y)||at(x-1,y)||at(x,y+1)||at(x,y-1)){ const n=at(x+1,y)||at(x-1,y)||at(x,y+1)||at(x,y-1), c=(PALS[0][n]||PALS[0][1])[0]; im.data.set([c[0]*.8|0,c[1]*.8|0,c[2]*.8|0,255],o); } }
  cx.putImageData(im,0,0); ICON[name]=cv.toDataURL(); return ICON[name]; }
