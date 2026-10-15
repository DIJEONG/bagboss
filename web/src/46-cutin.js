// =========================================================
// 컷인 원화: 클로즈업 전용 도트 초상(게임 속 얼굴의 6~8배 밀도) · 망점 음영 · 잉크 외곽선
// =========================================================
function pBuf(W,H){ const a=new Array(W*H).fill(null), fx=new Array(W*H).fill(false);
  const set=(x,y,c,keep)=>{ x=Math.round(x); y=Math.round(y); if(x>=0&&y>=0&&x<W&&y<H){ a[y*W+x]=c; fx[y*W+x]=!!keep; } };
  const get=(x,y)=>(x<0||y<0||x>=W||y>=H)?null:a[y*W+x];
  const rect=(x,y,w,h,c,k)=>{ for(let j=0;j<h;j++) for(let i=0;i<w;i++) set(x+i,y+j,c,k); };
  const ell=(cx,cy,rx,ry,c,k)=>{ for(let y=-ry;y<=ry;y++) for(let x=-rx;x<=rx;x++) if((x*x)/(rx*rx)+(y*y)/(ry*ry)<=1) set(cx+x,cy+y,c,k); };
  const line=(x0,y0,x1,y1,c,k,th=1)=>{ const n=Math.ceil(Math.max(Math.abs(x1-x0),Math.abs(y1-y0)))||1; for(let s=0;s<=n;s++){ const x=x0+(x1-x0)*s/n, y=y0+(y1-y0)*s/n; for(let i=0;i<th;i++) for(let j=0;j<th;j++) set(x+i-(th>>1),y+j-(th>>1),c,k); } };
  const poly=(pts,c,k)=>{ const ys=pts.map(p=>p[1]); for(let y=Math.floor(Math.min(...ys));y<=Math.ceil(Math.max(...ys));y++){ const xs=[]; for(let i=0;i<pts.length;i++){ const [ax,ay]=pts[i],[bx,by]=pts[(i+1)%pts.length]; if((ay<=y+.5&&by>y+.5)||(by<=y+.5&&ay>y+.5)) xs.push(ax+(y+.5-ay)*(bx-ax)/(by-ay)); } xs.sort((p,q)=>p-q); for(let i=0;i+1<xs.length;i+=2) for(let x=Math.round(xs[i]);x<Math.round(xs[i+1]);x++) set(x,y,c,k); } };
  return { W,H,a,fx,set,get,rect,ell,line,poly }; }
// 망점 음영: 왼쪽 위가 밝고 오른쪽 아래가 어둡다 + 어두운 면엔 체크 점
function pShade(b,lx=-1,ly=-1){ const src=b.a.slice(), W=b.W, H=b.H;
  for(let y=0;y<H;y++) for(let x=0;x<W;x++){ const c=src[y*W+x]; if(!c||b.fx[y*W+x]||!(c in RAMP_OF)) continue; const [ri,ci]=RAMP_OF[c], R=RAMPS[ri];
    const out=(dx,dy)=>{ const q=(x+dx<0||y+dy<0||x+dx>=W||y+dy>=H)?null:src[(y+dy)*W+x+dx]; return !q||!(q in RAMP_OF)||RAMP_OF[q][0]!==ri; };
    if(out(lx,ly)||out(0,ly)) b.a[y*W+x]=R[Math.min(R.length-1,ci+1)];
    else if(out(-lx,-ly)||out(0,-ly)||out(-lx,0)) b.a[y*W+x]=R[Math.max(0,ci-1)];
    else if(((x+y)&1)===0 && ci>0 && (x/W+y/H)>1.05) b.a[y*W+x]=R[ci-1]; } }                       // 오른쪽 아래 절반에 망점
function pOutline(b){ const o=b.a.slice(); for(let y=0;y<b.H;y++) for(let x=0;x<b.W;x++){ if(b.a[y*b.W+x]) continue; if([[1,0],[-1,0],[0,1],[0,-1]].some(([dx,dy])=>{ const c=b.get(x+dx,y+dy); return c&&c!=='K'; })) o[y*b.W+x]='K'; } b.a=o; }
function pCanvas(b){ const cv=document.createElement('canvas'); cv.width=b.W; cv.height=b.H; const cx=cv.getContext('2d'); for(let y=0;y<b.H;y++) for(let x=0;x<b.W;x++){ const c=b.a[y*b.W+x]; if(!c) continue; cx.fillStyle=ICON_PAL[c]; cx.fillRect(x,y,1,1); } return cv; }
// 얼굴 틀(64×64, 오른쪽을 본다): 옷 · 목 · 머리 · 귀 · 머리카락 · 눈썹 · 눈 · 코 · 입 · 수염 · 흉터 · 모자
function drawFace(b,P){ const cx=32, cy=30, rx=P.jaw||14, ry=18, coat=P.coat||'n';
  b.poly([[4,64],[10,50],[22,46],[42,46],[54,50],[60,64]],coat);                                              // 어깨 · 옷
  if(P.collar==='mandarin'){ b.poly([[24,44],[40,44],[41,51],[23,51]],coat); b.line(32,46,32,63,'C',true); for(const y of [52,56,60]) b.rect(31,y,2,2,'Y',true); }
  else { b.poly([[25,45],[39,45],[32,58]],'w',true); b.poly([[30,48],[34,48],[35,62],[32,64],[29,62]],P.tie||'N',true); b.poly([[22,46],[30,47],[27,60]],coat==='n'?'m':coat); b.poly([[42,46],[34,47],[37,60]],coat); }
  b.rect(27,40,10,7,'S'); b.ell(cx,cy,rx,ry,'s'); b.poly([[cx-rx+2,cy+6],[cx+rx-2,cy+6],[cx+4,cy+ry+1],[cx-6,cy+ry]],'s');   // 목 · 머리 · 턱
  b.ell(cx-rx+1,cy+2,3,5,'s'); b.line(cx-rx+1,cy,cx-rx+1,cy+4,'S',true);                                     // 귀
  if(P.hair==='slick'){ b.poly([[cx-rx-1,cy-2],[cx-rx+1,cy-15],[cx-4,cy-21],[cx+10,cy-20],[cx+rx+1,cy-12],[cx+rx-2,cy-6],[cx+2,cy-11],[cx-8,cy-9],[cx-rx+3,cy+1]],'N'); for(let k=0;k<5;k++) b.line(cx-10+k*4,cy-18,cx-2+k*5,cy-12,'n',true); }
  if(P.silver){ for(const [x0,y0] of [[cx-rx+1,cy-6],[cx-rx+2,cy-10],[cx+rx-3,cy-8]]) b.line(x0,y0,x0+3,y0-4,'W',true,2); }      // 은빛 관자놀이
  if(P.hair==='crop'){ b.poly([[cx-rx,cy-6],[cx-rx+3,cy-16],[cx+6,cy-20],[cx+rx,cy-13],[cx+rx-1,cy-9],[cx-rx+3,cy-4]],'N'); for(let x=cx-rx+3;x<cx+rx;x+=2) b.set(x,cy-15+(x%3),'n',true); }
  if(P.hat==='tophat'){ b.rect(cx-12,cy-36,24,20,'N'); b.rect(cx-17,cy-17,34,3,'N'); b.rect(cx-12,cy-21,24,3,'x'); for(const gx of [cx-7,cx+5]){ b.ell(gx,cy-21,3,3,'Y'); b.ell(gx,cy-21,1.6,1.6,'l',true); } }
  if(P.chops){ b.poly([[cx-rx+1,cy+2],[cx-rx+5,cy+2],[cx-rx+6,cy+14],[cx-rx+2,cy+12]],'x'); b.poly([[cx+rx-5,cy+2],[cx+rx-1,cy+2],[cx+rx-2,cy+12],[cx+rx-6,cy+14]],'x'); b.poly([[cx-6,cy+9],[cx+8,cy+9],[cx+6,cy+12],[cx-4,cy+12]],'x'); }
  const by=cy-3, ang=P.brow??2.5;                                                                            // 눈썹(안쪽이 내려가면 매섭다)
  b.line(cx-10,by-1,cx-3,by+ang*.6,'N',true,2); b.line(cx+3,by+ang*.6,cx+11,by-1,'N',true,2);
  for(const ex of [cx-7,cx+7]){ b.rect(ex-3,by+3,7,3,'h',true); b.rect(ex-1,by+3,3,3,P.iris||'N',true); b.set(ex,by+3,'h',true); b.line(ex-3,by+2,ex+3,by+2,'K',true); b.line(ex-2,by+6,ex+3,by+6,'S',true); }
  if(P.glare) for(const ex of [cx-7,cx+7]) b.rect(ex-1,by+4,3,1,'r',true);
  b.line(cx+1,by+4,cx+3,cy+8,'S',true); b.line(cx-1,cy+9,cx+4,cy+9,'z',true);                              // 코
  b.line(cx-5,cy+13,cx+6,cy+12+(P.smirk?-1:1),'z',true); b.set(cx-5,cy+14,'z',true);                          // 입
  if(P.stubble) for(let y=cy+9;y<cy+ry;y++) for(let x=cx-rx+3;x<cx+rx-2;x++) if(((x*7+y*3)%5)===0 && b.get(x,y)==='s') b.set(x,y,'S',true);
  if(P.scar){ b.line(cx+5,by-4,cx+10,by+10,'w',true); b.line(cx+6,by-4,cx+11,by+10,'S',true); }
  if(P.mustache) b.poly([[cx-5,cy+11],[cx+7,cy+11],[cx+5,cy+12],[cx-3,cy+12]],'N',true); }
function heroMood(b,m){ const cx=32, cy=30, by=27, L=cx-7, Rr=cx+7;
  const sweat=(x,y)=>{ b.set(x,y,'l',true); b.set(x,y+1,'l',true); b.set(x-1,y+2,'b',true); b.set(x,y+2,'l',true); };
  const brows=(a)=>{ b.line(cx-10,by-1-a*.3,cx-3,by+a*.6,'N',true,2); b.line(cx+3,by+a*.6,cx+11,by-1-a*.3,'N',true,2); };
  const teeth=()=>{ b.rect(cx-5,cy+11,11,3,'h',true); for(let x=cx-4;x<=cx+5;x+=2) b.set(x,cy+12,'W',true); b.line(cx-5,cy+10,cx+5,cy+10,'K',true); b.line(cx-5,cy+14,cx+5,cy+14,'K',true); };
  const shut=(ex,dir)=>{ b.rect(ex-3,by+2,7,5,'s',true); b.line(ex-3*dir,by+3,ex,by+4,'K',true); b.line(ex,by+4,ex-3*dir,by+5,'K',true); };
  if(m==='strain'||m==='hurt'||m==='crit'){ brows(m==='crit'?4.5:4); teeth(); sweat(cx+12,by-2); }
  if(m==='hurt'||m==='crit'){ b.rect(L-3,by+2,7,5,'s',true); b.line(L-3,by+4,L+3,by+5,'K',true); b.line(L-2,by+3,L+2,by+3,'S',true);            // 한쪽 눈 찡그림
    b.line(cx-9,by-3,cx-5,by-1,'r',true); b.set(cx-7,by,'R',true); b.set(cx-7,by+1,'R',true);                                                  // 눈썹 위 상처
    b.ell(cx+9,cy+5,2.5,2,'S',true); b.set(cx+9,cy+5,'P',true); b.set(cx+10,cy+6,'z',true); b.line(cx+2,cy+10,cx+2,cy+12,'R',true); }                                     // 뺨 멍 · 코피
  if(m==='crit'){ for(let a=0;a<Math.PI*2;a+=.2) b.set(Math.round(Rr+Math.cos(a)*5),Math.round(by+4+Math.sin(a)*3.2),(Math.round(a*5)%2)?'P':'z',true);   // 멍든 눈(어두운 보라 · 갈색) · 반쯤 감김
    b.rect(Rr-3,by+2,7,2,'S',true); b.line(Rr-3,by+4,Rr+3,by+4,'K',true); b.ell(cx,cy+12,3.5,2.2,'K',true); b.rect(cx-2,cy+10,5,1,'h',true); b.line(cx+4,cy+12,cx+5,cy+16,'R',true); // 거친 숨 · 입술 피
    b.line(cx-2,cy-14,cx-5,by-1,'N',true); b.line(cx+3,cy-14,cx+1,by,'N',true); b.line(cx+6,cy-13,cx+6,by-2,'n',true); sweat(cx-13,by); sweat(cx+13,cy+4); }   // 흘러내린 머리 · 식은땀
  if(m==='flinch'){ brows(5); shut(L,1); shut(Rr,-1); b.rect(cx-5,cy+10,11,4,'K',true); b.rect(cx-4,cy+10,9,1,'h',true); b.rect(cx-4,cy+13,9,1,'h',true); sweat(cx+12,by-3); }   // 움찔
  if(m==='shout'){ brows(5.5); for(const ex of [L,Rr]){ b.rect(ex-3,by+2,7,4,'h',true); b.rect(ex-1,by+3,2,2,'N',true); b.line(ex-3,by+1,ex+3,by+1,'K',true); }        // 외침
    b.ell(cx,cy+12,4.5,3.4,'K',true); b.rect(cx-3,cy+9,7,1,'h',true); b.ell(cx,cy+14,2.2,1.2,'R',true); } }
function portrait(kind){ const [base,mood]=kind.split('_'), b=pBuf(64,64), P={
    hero:{ hair:'slick', jaw:13, brow:2.8, coat:'n', tie:'N' },
    boss:{ hair:'crop', jaw:16, brow:3.4, coat:'C', tie:'N', stubble:true, scar:true },
    boss2:{ hat:'tophat', jaw:16, brow:3, coat:'x', chops:true, iris:'y', smirk:true },
    boss3:{ hair:'slick', jaw:12, brow:3.6, coat:'w', collar:'mandarin', mustache:true, iris:'N', silver:true },
    boss4:{ hair:'crop', jaw:14, brow:3, coat:'p', tie:'b', iris:'e', smirk:true, stubble:true },
    kaneB:{ hair:'slick', jaw:12, brow:3.2, coat:'w', tie:'r', iris:'N', silver:true, smirk:true, scar:true },
    mgr:{ hair:'crop', jaw:17, brow:3.6, coat:'C', tie:'y', stubble:true, mustache:true },
    headchef:{ hair:'crop', jaw:16, brow:3.4, coat:'w', tie:'r', stubble:true, mustache:true } }[base]||{ hair:'crop', jaw:14, brow:3, coat:'n' };
  const SK=base==='hero'?({ gala:{ coat:'w', tie:'w' }, rain:{ coat:'C', tie:'x' }, chicago:{ tie:'r' } }[OPT.skin]||{}):{};   // 스킨: 재킷 · 넥타이 색
  drawFace(b,{...P, ...SK, smirk: base==='hero' && !mood ? true : P.smirk}); if(base==='hero') skinFace(b); if(mood) heroMood(b,mood); if(base==='hero' && OPT.shades) shades64(b,mood); pShade(b); pOutline(b); return pCanvas(b); }
// 눈매 클로즈업(96×36): 주인공(매서운 눈) · 두목 분노(붉게 충혈 · 이마 핏줄 · 모자/고글은 두목마다)
function eyesClose(kind,rage){ const b=pBuf(96,36); b.rect(0,0,96,36,'s');
  if(kind==='boss2'){ b.rect(0,0,96,7,'N'); b.rect(0,7,96,3,'x'); for(const gx of [30,66]){ b.ell(gx,8,7,5,'Y'); b.ell(gx,8,4,3,'l',true); } }
  else b.poly([[0,0],[96,0],[96,6],[70,4],[48,7],[20,3],[0,8]],'N');                                         // 머리카락 끝
  const ang=rage?6:4;
  b.line(10,12,42,12+ang,'N',true,4); b.line(54,12+ang,86,12,'N',true,4);                                     // 굵은 눈썹
  for(const ex of [26,70]){ b.ell(ex,23,13,5,'h',true); b.ell(ex+(ex<48?3:-3),23,5,5,rage?'r':'N',true); b.ell(ex+(ex<48?3:-3),23,2,2,'K',true); b.set(ex+(ex<48?1:-5),21,'h',true); b.set(ex+(ex<48?2:-4),21,'h',true);
    b.line(ex-14,18,ex+14,17,'K',true,2); b.line(ex-12,29,ex+12,29,'S',true); if(rage){ b.line(ex-10,22,ex-6,24,'r',true); b.line(ex+8,24,ex+11,22,'r',true); } }
  b.line(47,20,49,35,'S',true); if(rage){ b.line(46,6,44,11,'R',true); b.line(50,6,52,11,'R',true); }                // 콧대 · 이마 핏줄
  if(kind==='hero' && !rage && OPT.shades){
    for(const ex of [26,70]){ b.ell(ex,23,15,8,'K',true); b.line(ex-15,15,ex+15,15,'N',true,2); b.line(ex-9,27,ex-2,19,'l',true,2); b.line(ex-4,29,ex+1,24,'l',true); b.set(ex-10,18,'h',true); b.set(ex-9,18,'h',true); }
    b.line(41,19,55,19,'N',true,2); b.line(10,17,2,15,'N',true,2); b.line(86,17,94,15,'N',true,2); }
  pShade(b); pOutline(b); return pCanvas(b); }
// 주먹(56×56) · 구두(64×48) 클로즈업
function fistClose(){ const b=pBuf(56,56); b.poly([[0,56],[0,36],[18,30],[22,56]],'n'); b.rect(10,30,14,8,'w');
  b.poly([[16,8],[46,6],[52,14],[52,36],[44,44],[18,44],[12,32]],'s'); for(const x of [24,32,40]) b.line(x,8,x,24,'S',true); b.line(16,24,50,24,'S',true);
  for(const x of [18,26,34,42]) b.rect(x,9,6,3,'h',true); b.poly([[12,26],[26,24],[28,36],[14,38]],'S'); for(let y=33;y<45;y+=3) b.line(18,y,46,y+1,'W',true);
  pShade(b); pOutline(b); return pCanvas(b); }
function shoeClose(){ const b=pBuf(64,48); b.poly([[0,0],[18,0],[22,20],[6,24]],'n'); b.poly([[6,18],[40,14],[58,22],[62,32],[60,38],[8,40]],'N');
  b.poly([[30,16],[44,16],[54,22],[30,24]],'n'); for(const x of [32,37,42]) b.line(x,18,x+4,21,'w',true); b.rect(6,38,56,5,'G'); b.rect(6,38,12,6,'x'); b.line(18,26,52,24,'h',true);
  pShade(b); pOutline(b); return pCanvas(b); }
const CUT_ART={}; function cutArt(k0){ const sk=(/hero/.test(k0) && OPT.skin && OPT.skin!=='jw') ? '|'+OPT.skin : '', k = ((OPT.shades && /hero/.test(k0)) ? k0+'|s' : k0)+sk; if(CUT_ART[k]) return CUT_ART[k];
  const [a,b]=k0.split(':'); const cv = a==='face' ? portrait(b) : a==='eyes' ? eyesClose(b,false) : a==='rage' ? eyesClose(b,true) : a==='fist' ? fistClose() : shoeClose();
  if(a==='eyes' && b==='hero' && (OPT.skin==='rain'||OPT.skin==='chicago')){ const x=cv.getContext('2d'); x.fillStyle=OPT.skin==='rain'?'#3a2a1c':'#16161c'; x.fillRect(0,0,cv.width,Math.round(cv.height*.16)); x.fillStyle=OPT.skin==='rain'?'#5c4630':'#2c2c36'; x.fillRect(0,Math.round(cv.height*.16),cv.width,1); }   // 중절모 챙 그림자
  return CUT_ART[k]=cv; }
function skinFace(b){ const k=OPT.skin||'jw', cx=32, cy=30; if(k==='jw') return;   // 컷인 초상화: 스킨 옷 · 모자
  if(k==='gala'){ b.poly([[22,46],[30,47],[27,60]],'N'); b.poly([[42,46],[34,47],[37,60]],'N'); b.poly([[25,45],[39,45],[32,56]],'w',true);
    b.poly([[26,47],[31,49],[26,52]],'N',true); b.poly([[38,47],[33,49],[38,52]],'N',true); b.rect(31,48,2,3,'N',true); b.poly([[45,53],[49,52],[48,56]],'r',true); }
  if(k==='rain'){ b.poly([[15,49],[24,41],[27,50],[19,57]],'C'); b.poly([[49,49],[40,41],[37,50],[45,57]],'C'); }
  if(k==='chicago') for(const x of [8,13,18,46,51,56]) b.line(x,51,x+(x<32?-1:1),63,'W',true);
  if(k==='rain'||k==='chicago'){ const hc=k==='rain'?'x':'N', bc=k==='rain'?'N':'w';
    b.poly([[cx-13,cy-14],[cx-11,cy-26],[cx-3,cy-29],[cx+3,cy-27],[cx+10,cy-28],[cx+12,cy-14]],hc); b.line(cx-1,cy-28,cx+1,cy-21,'N',true);
    b.rect(cx-12,cy-18,25,3,bc); b.poly([[cx-21,cy-15],[cx+21,cy-15],[cx+17,cy-11],[cx-17,cy-11]],hc); b.line(cx-17,cy-11,cx+17,cy-11,'N',true); } }

