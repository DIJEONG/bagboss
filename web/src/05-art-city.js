/* =========================================================
   2-b. 도시 · 흐린 날 — 절차 생성 배경 (384×216, 패럴랙스 층)
   ========================================================= */
/* =========================================================
   2-b. 도시 · 흐린 날 — 설정값으로 돌아가는 절차 생성 배경 (가로 384×216 · 세로 216×384)
   ========================================================= */
const T6=[.08,.22,.36,.5,.64,.79]; // 흐린 낮 기준 밝기에서 0~5단에 정확히 떨어지는 톤
function paint(w,h){
  const s=newSprite(w,h); s.mask=.5;
  const set=(x,y,m,k,o={})=>{ x=Math.round(x); y=Math.round(y); if(x<0||y<0||x>=w||y>=h) return; const i=y*w+x;
    s.mat[i]=m; s.tone[i]=T6[Math.max(0,Math.min(5,k|0))]; s.emit[i]=o.e||0; s.nx[i]=o.nx||0; s.ny[i]=o.ny||0; s.rel[i]=o.r||0; };
  const rect=(x,y,ww,hh,m,k,o)=>{ for(let j=0;j<hh;j++) for(let q=0;q<ww;q++) set(x+q,y+j,m,typeof k==='function'?k(q,j):k,o); };
  const get=(x,y)=>(x<0||y<0||x>=w||y>=h)?0:s.mat[Math.round(y)*w+Math.round(x)];
  const relAt=(x,y)=>(x<0||y<0||x>=w||y>=h)?-1:s.rel[Math.round(y)*w+Math.round(x)];
  const line=(x0,y0,x1,y1,m,k,o)=>{ x0=Math.round(x0); y0=Math.round(y0); x1=Math.round(x1); y1=Math.round(y1);
    const dx=Math.abs(x1-x0), dy=-Math.abs(y1-y0), sx=x0<x1?1:-1, sy=y0<y1?1:-1; let e=dx+dy;
    for(let g=0;g<2000;g++){ set(x0,y0,m,k,o); if(x0===x1&&y0===y1) break; const e2=2*e; if(e2>=dy){ e+=dy; x0+=sx; } if(e2<=dx){ e+=dx; y0+=sy; } } };
  return { s, w, h, set, rect, get, relAt, line, marks:{ sill:[], slab:[], rail:[] } };
}
function cropRows(s){
  let y0=s.h, y1=-1; for(let y=0;y<s.h;y++) for(let x=0;x<s.w;x++) if(s.mat[y*s.w+x]){ y0=Math.min(y0,y); y1=Math.max(y1,y); break; }
  if(y1<0) return { s, oy:0 };
  const o=newSprite(s.w,y1-y0+1); o.mask=s.mask;
  for(let y=y0;y<=y1;y++) for(let x=0;x<s.w;x++){ const i=y*s.w+x, j=(y-y0)*s.w+x;
    o.mat[j]=s.mat[i]; o.tone[j]=s.tone[i]; o.emit[j]=s.emit[i]; o.nx[j]=s.nx[i]; o.ny[j]=s.ny[i]; o.rel[j]=s.rel[i]; }
  return { s:o, oy:y0 };
}
function fromLegend(rows, legend, piv){
  const h=rows.length, w=Math.max(...rows.map(r=>r.length)), s=newSprite(w,h);
  for(let y=0;y<h;y++) for(let x=0;x<w;x++){ const L=legend[rows[y][x]]; if(!L) continue; const i=y*w+x;
    s.mat[i]=L[0]; s.tone[i]=T6[L[1]]; s.emit[i]=L[2]||0; s.rel[i]=L[3]||0; s.nx[i]=L[4]||0; s.ny[i]=L[5]||0; }
  s.px=piv?piv[0]:0; s.py=piv?piv[1]:0; s.mask=.5; return s;
}

// --- 창 · 발코니 · 판넬 건물 ---
function cWindow(p,x,y,w,h,rnd,rank){
  const wood=rnd()<.14, FM=wood?M.PANEL:M.FRAME, fk=wood?2:3, open=rnd()<.05;
  p.rect(x,y,w,h,FM,fk,{r:.2});
  p.rect(x+1,y+1,w-2,h-2,open?M.GLASS:M.WINLIT,open?1:3,{e:open?0:rank});        // 유리 (밤이 되면 켜질 수 있음)
  if(!open) for(let q=x+1;q<x+w-1;q++) p.set(q,y+1,M.WINLIT,4,{e:rank});          // 윗줄 반사
  const panes=w>=13?3:2, mx=[]; for(let k=1;k<panes;k++) mx.push(x+Math.round(w*k/panes));
  for(const m of mx) for(let j=1;j<h-1;j++) p.set(m,y+j,FM,fk,{r:.2});
  if(rnd()<.45) for(let q=x+1;q<x+w-1;q++) p.set(q,y+Math.max(3,Math.round(h*.3)),FM,fk,{r:.2}); // 위쪽 작은 창
  const c=rnd();
  if(!open && c<.5){ const left=rnd()<.5, a=left?x+1:mx[mx.length-1]+1, b=left?mx[0]-1:x+w-2;
    for(let q=a;q<=b;q++) for(let j=y+2;j<y+h-1;j++) p.set(q,j,M.CURT,((q-a)&1)?3:4);
  } else if(!open && c<.62){ for(let j=y+2;j<y+h-1;j+=2) for(let q=x+1;q<x+w-1;q++) if(p.get(q,j)===M.WINLIT) p.set(q,j,FM,2);
  } else if(!open && c<.7){ const q=x+2+Math.floor(rnd()*(w-5)); p.set(q,y+h-2,M.HEDGE,3); p.set(q+1,y+h-2,M.HEDGE,2); p.set(q,y+h-3,M.HEDGE,4); }
  for(let q=x-1;q<=x+w;q++) p.set(q,y+h,M.CONC,1,{r:.45});                       // 창턱
  p.marks.sill.push([x-1,x+w,y+h]);
  // 에어컨 실외기 · 위성 접시 (벽 위에만)
  const wallBox=(ax,ay,aw,ah)=>{ for(let j=0;j<ah;j++) for(let q=0;q<aw;q++){ if(p.get(ax+q,ay+j)!==M.CONC||p.relAt(ax+q,ay+j)!==.25) return false; } return true; };
  if(rnd()<.11){ const L=rnd()<.5, ax=L?x-8:x+w+2, ay=y+h-6;
    if(wallBox(ax,ay,6,5)){ p.rect(ax,ay,6,5,M.FRAME,(q,j)=>j===0?4:(q===0||q===5)?2:((q+j)&1?3:2),{r:.65}); p.marks.sill.push([ax,ax+5,ay+4]); } }
  if(rnd()<.06){ const dx=x+w+2, dy=y+2; if(wallBox(dx,dy,3,3)){ p.set(dx,dy,M.FRAME,3,{r:.6}); p.set(dx+1,dy,M.FRAME,4,{r:.6}); p.set(dx,dy+1,M.FRAME,2,{r:.6}); p.set(dx+1,dy+1,M.FRAME,3,{r:.6}); p.set(dx+2,dy+2,M.MDARK,2,{r:.6}); } }
}
function cBalcony(p,x,y,w,rnd,rank){ // y = 슬래브 윗줄
  const k=rnd();
  for(let q=0;q<w;q++){ p.set(x+q,y,M.CONC,5,{r:.9,ny:.7}); p.set(x+q,y+1,M.CONC,1,{r:.9}); }
  p.marks.slab.push([x,x+w-1,y+1]);
  if(k<.28){
    p.rect(x,y-7,w,7,M.FRAME,3,{r:.75}); p.rect(x+1,y-6,w-2,5,M.WINLIT,3,{r:.72,e:rank});
    for(let q=x+1;q<x+w-1;q++) p.set(q,y-6,M.WINLIT,4,{r:.72,e:rank});
    for(let q=x+5;q<x+w-1;q+=5) for(let j=y-6;j<y-1;j++) p.set(q,j,M.FRAME,3,{r:.75});
  } else {
    for(let q=0;q<w;q++) p.set(x+q,y-6,M.MDARK,4,{r:.75,ny:.6});
    for(let q=0;q<w;q+=2) for(let j=y-5;j<y;j++) p.set(x+q,j,M.MDARK,2,{r:.72});
    p.marks.rail.push([x,x+w-1,y+1]);
    if(k<.55){ const bx=x+2+Math.floor(rnd()*(w-8)); p.rect(bx,y-4,4,4,M.CURT,2,{r:.5}); p.set(bx,y-4,M.CURT,4,{r:.5}); }
    else if(k<.7){ for(let q=x+3;q<x+w-3;q+=3) p.set(q,y-5,M.FRAME,4,{r:.5}); }
  }
}
// 세월감: 물 얼룩 · 녹물 · 보수 판넬 · 그을음 · 모서리 때 (벽 픽셀만 건드림)
function cWeather(p,o,rnd){
  const isWall=(X,Y)=>{ const m=p.get(X,Y), r=p.relAt(X,Y); return (m===M.CONC||m===M.PANEL) && (r===.25||Math.abs(r-.26)<.001); };
  const step=(X,Y,n)=>{ X=Math.round(X); Y=Math.round(Y); if(!isWall(X,Y)) return; const i=Y*p.w+X; let k=0,b=9;
    T6.forEach((t,j)=>{ const d=Math.abs(t-p.s.tone[i]); if(d<b){ b=d; k=j; } }); p.s.tone[i]=T6[Math.max(0,Math.min(5,k+n))]; };
  for(const [x0,x1,y] of p.marks.sill.concat(p.marks.slab)){ if(rnd()>.42) continue;
    const sx=x0+Math.floor(rnd()*(x1-x0+1)), len=3+Math.floor(rnd()*o.fh*.7), wid=rnd()<.6?1:2;
    for(let j=1;j<=len;j++) for(let q=0;q<wid;q++) if(rnd()<1-j/(len+2)) step(sx+q,y+j,-1); }
  for(const [x0,x1,y] of p.marks.rail){ if(rnd()>.4) continue; const sx=x0+1+Math.floor(rnd()*(x1-x0-1)), len=4+Math.floor(rnd()*o.fh*.6);
    for(let j=1;j<=len;j++) if(rnd()<1-j/(len+2) && isWall(sx,y+j)){ const i=Math.round(y+j)*p.w+sx; const t=p.s.tone[i]; p.set(sx,y+j,M.PANEL,t>.45?2:1,{r:.25}); } }
  for(let n=0;n<(o.patches||0);n++){ const f=Math.floor(rnd()*o.floors), j=Math.floor(rnd()*(o.joints.length-1)), lighter=rnd()<.5;
    const x0=o.x+o.joints[j]+1, x1=o.x+o.joints[j+1]-1, y0=o.y0+f*o.fh+1, y1=y0+o.fh-2;
    for(let Y=y0;Y<=y1;Y++) for(let X=x0;X<=x1;X++) if(p.get(X,Y)===M.CONC) step(X,Y,lighter?1:-1); }
  for(let Y=o.y0;Y<o.y0+7;Y++) for(let X=o.x;X<o.x+o.w;X++) if(rnd()<.55-(Y-o.y0)*.08) step(X,Y,-1);
  for(let Y=o.y0;Y<o.base;Y++) for(const X of [o.x,o.x+1,o.x+o.w-1,o.x+o.w-2]) if(rnd()<.35) step(X,Y,-1);
  for(let n=0;n<10;n++){ const X=o.x+Math.floor(rnd()*o.w), Y=o.base-4-Math.floor(rnd()*o.ground*.6); step(X,Y,-1); step(X+1,Y,-1); }
}
function cBuilding(p,o,rnd){
  const {x,top,w,floors,fh,ground}=o, roofH=6, y0=top+roofH, base=y0+floors*fh+ground;
  const rank=()=>.02+rnd()*.96;
  if(o.side) p.rect(x-o.side,top+3,o.side,base-top-3,M.CONC,(q,j)=>((j>>1)&1)?1:2,{r:.25,nx:-.7});
  p.rect(x,y0,w,base-y0,M.CONC,(q,j)=>(j%3===0)?3:4,{r:.25});
  for(const jx of o.joints) for(let y=y0;y<base-ground;y++) p.set(x+jx,y,M.CONC,2,{r:.25});
  for(let f=0;f<=floors;f++){ const y=y0+f*fh; for(let q=0;q<w;q++) p.set(x+q,y,M.CONC,2,{r:.25}); }
  p.rect(x-1,top,w+2,roofH,M.CONC,(q,j)=>j===0?5:j===1?4:j===roofH-1?1:3,{r:.3,ny:.5});
  for(const v of (o.roof||[])){
    if(v.t==='mast'){ for(let y=top-v.h;y<top;y++) p.set(x+v.x,y,M.MDARK,3);
      for(const cy of [top-v.h+2,top-v.h+5]) for(let q=-2;q<=2;q++) p.set(x+v.x+q,cy,M.MDARK,3);
      p.line(x+v.x,top-v.h+1,x+v.x+4,top-v.h+6,M.MDARK,3); }
    if(v.t==='stack'){ p.rect(x+v.x,top-v.h,v.w,v.h,M.CONC,(q,j)=>j===0?4:q===0?2:3,{r:.3}); p.rect(x+v.x,top-v.h-1,v.w,1,M.MDARK,3); }
  }
  for(let f=0;f<floors;f++){ const fy=y0+f*fh;
    for(const c of o.cols){ const cx=x+c.x;
      if(c.t==='acc') p.rect(cx,fy+2,c.w,fh-3,M.PANEL,(q,j)=>(j%3===0)?3:4,{r:.26});
      else if(c.t==='win') cWindow(p,cx,fy+3,c.w,fh-7,rnd,rank());
      else if(c.t==='bal'){ cWindow(p,cx+c.pad,fy+3,c.w-2*c.pad,fh-6,rnd,rank()); cBalcony(p,cx-1,fy+fh-1,c.w+2,rnd,rank()); }
    }
    if(f===0) for(const vx of (o.vents||[])) p.rect(x+vx,fy+5,2,2,M.GLASS,1);
  }
  const gy=base-ground, gwh=Math.min(ground-6,9);
  p.rect(x,base-3,w,3,M.CONC,(q,j)=>j===0?2:1,{r:.25});
  for(const c of o.cols) if(c.t==='win' && Math.abs(c.x-o.door)>16) cWindow(p,x+c.x+1,gy+2,c.w-2,gwh,rnd,rank());
  const ex=x+o.door;
  p.rect(ex-4,gy-1,19,2,M.CONC,(q,j)=>j?1:5,{r:.95,ny:.7});
  p.rect(ex-1,gy+1,13,ground-4,M.CONC,5,{r:.3});
  p.rect(ex,gy+2,11,ground-5,M.MDARK,(q,j)=>q===5?1:3,{r:.15});
  p.rect(ex+1,gy+3,4,3,M.WINLIT,2,{e:.01}); p.rect(ex+6,gy+3,4,3,M.WINLIT,2,{e:.01});
  p.rect(ex-13,gy+2,9,6,M.FRAME,4,{r:.35}); for(let j=gy+3;j<gy+7;j+=2) for(let q=ex-12;q<ex-6;q++) if((q+j)%3) p.set(q,j,M.GLASS,2,{r:.35});
  p.rect(ex+15,gy+3,5,2,M.ARMOR,3,{r:.35}); p.set(ex+15,gy+3,M.ARMOR,4,{r:.35});
  p.rect(ex-17,gy+4,2,3,M.RED,2,{r:.4});
  p.rect(ex+13,gy+5,1,Math.max(4,ground-8),M.MDARK,2,{r:.4});
  if(o.weather!==false) cWeather(p,{...o,y0,base},rnd);
}

// --- 나무 · 덤불 · 전선 · 펜스 ---
function cPine(p,cx,base,h,w,rnd,far){
  // 가문비나무: 줄기 쪽 촘촘한 심 + 끝이 처지는 가지 층. 나무마다 기울기 · 좌우 비대칭 · 빠진 가지가 다르다
  const m=far?M.PFAR:M.PINE, top=base-h, sh=far?1:0, lowest=base-Math.max(3,Math.round(h*.1));
  const lean=(rnd()-.5)*.1*h, sL=.78+rnd()*.44, sR=.78+rnd()*.44, X=u=>cx+Math.round(lean*(1-u));
  for(let y=lowest-6;y<base;y++){ p.set(cx,y,m,1+sh,{r:.2}); if(!far&&h>60) p.set(cx+1,y,m,sh,{r:.2}); }
  for(let y=top-3;y<top+3;y++) p.set(X(0),y,m,2+sh,{r:.3});
  for(let y=top+2;y<lowest;y++){ const u=(y-top)/(lowest-top), cw=Math.round(w*.5*u*.3), c0=X(u);
    for(let d=-cw;d<=cw;d++) p.set(c0+d,y,m,sh+(Math.abs(d)>=cw?1:0),{r:.35}); }
  let ty=top+2;
  while(ty<lowest){
    const u=(ty-top)/(lowest-top), L=Math.max(2,Math.round(w*.5*(.14+.86*Math.pow(u,.85)))), c0=X(u), broken=rnd()<.05;
    for(const side of [-1,1]){
      if(broken || rnd()<.06) continue;
      const Ls=Math.max(2,Math.round(L*(side<0?sL:sR)*(.75+rnd()*.38))), dy0=rnd()<.5?0:1;
      for(let d=0;d<=Ls;d++){
        const a=d/Ls, cy=ty+dy0+Math.round(a*a*Ls*.34+a), th=Math.max(1,Math.round((1-a)*2.3+1));
        for(let j=0;j<th;j++){ const k = j===0 ? (a>.55?3:2) : (j===th-1?0:1);
          p.set(c0+side*d,cy+j,m,Math.min(5,k+sh),{r:.35,ny:j===0?.6:-.3,nx:side*.4}); }
        if(d>Ls*.4 && rnd()<.22){ const hl=1+Math.floor(rnd()*2); for(let j=0;j<hl;j++) p.set(c0+side*d,cy+th+j,m,sh,{r:.35}); }
      }
    }
    ty+=Math.round(2.4+u*3.6+rnd()*1.4);
  }
}
function cBare(p,x,base,h,rnd){
  for(let y=base-h;y<base;y++) p.set(x,y,M.PFAR,1,{r:.3});
  for(let y=base-h+2;y<base-h*.35;y+=2+Math.floor(rnd()*3)){ const dir=rnd()<.5?-1:1, L=2+Math.floor(rnd()*4);
    for(let k=1;k<=L;k++) p.set(x+dir*k,y-Math.floor(k*.7),M.PFAR,2,{r:.3}); }
}
function cHedge(p,x0,x1,base,h,rnd){
  for(let x=x0;x<=x1;x++){
    const spike=(rnd()<.35)?Math.floor(rnd()*3):0, bump=Math.round(Math.sin(x*.5)*1.2+Math.sin(x*.19+1)*1.6)+spike, top=base-h-bump;
    for(let y=top;y<base;y++){ const j=y-top; p.set(x,y,M.HEDGE, j===0?4:j===1?3:(rnd()<.16?3:(y>base-3?1:2)), {r:.45,ny:j<2?.6:0}); }
  }
}
function cWire(p,xa,ya,xb,yb,sag){ let px=null,py=null;
  for(let x=xa;x<=xb;x++){ const t=(x-xa)/(xb-xa), y=ya+(yb-ya)*t+sag*4*t*(1-t); if(px!==null) p.line(px,py,x,y,M.WIRE,2); px=x; py=Math.round(y); } }
function cFence(w,h){
  const p=paint(w,h);
  for(let x=0;x<w;x++){ p.set(x,0,M.MDARK,4,{r:.5,ny:.6}); p.set(x,1,M.MDARK,2,{r:.5}); p.set(x,h-1,M.MDARK,2,{r:.5});
    for(let y=2;y<h-1;y++) if(((x+y)%8===0)||((x-y+800)%8===0)) p.set(x,y,M.MDARK,2,{r:.5}); }
  for(let x=4;x<w;x+=28) for(let y=0;y<h;y++){ p.set(x,y,M.MDARK,3,{r:.55}); p.set(x+1,y,M.MDARK,1,{r:.55}); }
  return p.s;
}
function cLamp(h){
  const p=paint(22,h); for(let y=12;y<h;y++){ p.set(10,y,M.MDARK,3,{r:.6}); p.set(11,y,M.MDARK,1,{r:.6}); }
  p.line(10,12,12,7,M.MDARK,3); p.line(12,7,17,5,M.MDARK,3); p.rect(15,6,5,2,M.WINLIT,3,{e:.005});
  p.rect(9,h-6,4,6,M.MDARK,2,{r:.6}); const s=p.s; s.px=10; s.py=h-1; return s;
}

// --- 장면 설정: 가로(레퍼런스 색감) · 세로(레퍼런스 구도) ---
const CITY_CFG={
  city:{ W:384, H:216, world:560, farW:448, midW:480, ground:176, userX:116, chars:[176,212],
    far:{ base:150, n:90, hMin:20, hMax:50, bare:10, fillY:148 },
    mid:{ building:{ x:318, top:70, w:104, floors:6, fh:14, ground:10, side:0, joints:[0,34,70,103], patches:3,
            cols:[{t:'win',x:4,w:11},{t:'acc',x:17,w:6},{t:'win',x:25,w:10},{t:'win',x:40,w:10},{t:'bal',x:55,w:18,pad:3},{t:'win',x:79,w:11},{t:'win',x:93,w:9}],
            door:36, roof:[{t:'stack',x:20,w:5,h:6},{t:'stack',x:62,w:4,h:5},{t:'mast',x:84,h:12}] },
          pines:[[8,88],[30,104],[52,96],[78,110],[100,86],[250,98],[274,112],[298,94],[438,108],[460,96],[476,112]], pinesBase:170,
          bare:[[110,60],[240,70],[434,64]], bareBase:166, wires:[[0,58,402,64,10],[0,66,402,70,12],[0,74,402,76,9],[0,40,402,60,14]] },
    main:{ pines:[[12,128],[40,146],[70,120],[96,154],[124,132],[154,112],[374,118],[452,150],[480,128],[512,156],[546,130]], pinesBase:166,
          building:{ x:186, top:20, w:170, floors:8, fh:16, ground:12, side:6, joints:[0,43,86,128,169], patches:5,
            cols:[{t:'win',x:5,w:13},{t:'acc',x:20,w:7},{t:'win',x:29,w:11},{t:'win',x:47,w:11},{t:'bal',x:62,w:20,pad:4},
                  {t:'win',x:90,w:13},{t:'acc',x:105,w:7},{t:'win',x:114,w:11},{t:'win',x:131,w:11},{t:'bal',x:146,w:20,pad:4}],
            door:96, vents:[22,108], roof:[{t:'mast',x:120,h:24},{t:'stack',x:30,w:6,h:7},{t:'stack',x:142,w:5,h:6},{t:'mast',x:60,h:14}] },
          hedges:[[150,182,6],[200,270,7],[300,372,6],[372,440,5]], hedgeBase:168 },
    plaza:{ lawnY:166, y:169, h:15 }, road:{ y:186, h:30 }, fence1:{ y:177, h:10 }, fence2:{ y:204, h:12 },
    lamps:{ xs:[110,300,470], base:184, h:104 }, dogY:181, vanY:207, birdY:[12,56], dogs:[150,322,340] },
  cityV:{ W:216, H:384, world:300, farW:246, midW:271, ground:313, userX:80, chars:[150,186],
    far:{ base:300, n:60, hMin:24, hMax:64, bare:10, fillY:298 },
    mid:{ building:{ x:166, top:150, w:112, floors:7, fh:18, ground:12, side:0, joints:[0,38,76,111], patches:3,
            cols:[{t:'win',x:5,w:13},{t:'acc',x:20,w:7},{t:'win',x:29,w:12},{t:'win',x:46,w:12},{t:'bal',x:62,w:22,pad:4},{t:'win',x:90,w:13}],
            door:44, roof:[{t:'stack',x:16,w:6,h:7},{t:'stack',x:70,w:5,h:6},{t:'mast',x:96,h:16}] },
          pines:[[30,140],[48,118],[120,150],[136,170],[150,124],[180,142],[205,112],[214,162],[232,134],[256,128],[270,156],
                 [10,46],[40,52],[64,44],[96,58],[120,48],[146,60],[176,50],[204,56],[226,46],[252,54]], pinesBase:306,
          bare:[[144,96],[160,80],[250,90]], bareBase:300,
          wires:[[0,62,101,38,6],[0,84,101,40,8],[0,106,101,42,10],[101,38,271,60,12],[101,42,271,80,14],[101,40,271,98,16],[0,26,271,64,22]] },
    main:{ pines:[[38,172],[58,138],[196,152],[248,186],[272,226],[298,200]], pinesBase:298,
          building:{ x:66, top:64, w:112, floors:9, fh:22, ground:18, side:7, joints:[0,46,92,111], patches:5,
            cols:[{t:'win',x:4,w:14},{t:'acc',x:20,w:8},{t:'win',x:30,w:13},{t:'win',x:48,w:13},{t:'bal',x:66,w:24,pad:5},{t:'win',x:95,w:13}],
            door:46, vents:[22,96], roof:[{t:'mast',x:50,h:30},{t:'stack',x:14,w:6,h:8},{t:'stack',x:90,w:5,h:7},{t:'mast',x:80,h:16}] },
          hedges:[[40,66,8],[72,110,9],[124,152,8],[152,200,9],[200,262,8]], hedgeBase:304 },
    plaza:{ lawnY:286, lawnH:20, y:306, h:12 }, road:{ y:320, h:64, walkY:368 }, fence1:{ y:315, h:12 }, fence2:{ y:356, h:14 },
    lamps:{ xs:[220], base:320, h:196 }, dogY:316, vanY:352, birdY:[10,70], dogs:[90,170,206] },
};
function genCityScene(key,c,rnd){
  const out={}, layers=[], N=n=>key+'_'+n;
  const add=(name,p,depth,w)=>{ const r=cropRows(p.s); out[N(name)]=r.s; layers.push({name:N(name),depth,oy:r.oy,w}); };
  { const p=paint(c.W,c.H); p.rect(0,0,c.W,c.H,M.SKYD,(q,j)=>j<20&&((q+j)&1)&&j<10?3:4); add('sky',p,1,c.W); }
  { const p=paint(c.farW,c.H), f=c.far;
    for(let i=0;i<f.n;i++){ const x=Math.floor(rnd()*c.farW), h=f.hMin+Math.floor(rnd()*(f.hMax-f.hMin)); cPine(p,x,f.base,h,Math.round(h*.38),rnd,true); }
    for(let i=0;i<f.bare;i++) cBare(p,Math.floor(rnd()*c.farW),f.base,30+Math.floor(rnd()*30),rnd);
    p.rect(0,f.fillY,c.farW,30,M.PFAR,(q,j)=>j<2?3:2,{r:.3});
    add('far',p,.88,c.farW); }
  { const p=paint(c.midW,c.H), m=c.mid;
    cBuilding(p,m.building,rnd);
    for(const [x,h] of m.pines) cPine(p,x,m.pinesBase,h,Math.round(h*.4)+Math.floor(rnd()*6),rnd,false);
    for(const [x,h] of m.bare) cBare(p,x,m.bareBase,h,rnd);
    for(const w of m.wires) cWire(p,...w);
    add('mid',p,.6,c.midW); }
  { const p=paint(c.world,c.H), m=c.main;
    for(const [x,h] of m.pines) cPine(p,x,m.pinesBase,h,Math.round(h*.42)+Math.floor(rnd()*8),rnd,false);
    cBuilding(p,m.building,rnd);
    const z=c.plaza; // 화단(잔디)은 건물 발치에 깔고 그 위에 덤불을 심는다
    p.rect(0,z.lawnY,c.world,z.lawnH||3,M.LAWN,(q,j)=>j===0?3:(rnd()<.12?3:(rnd()<.1?1:2)),{r:.1,ny:.5});
    if((z.lawnH||3)>4) for(let x=0;x<c.world;x++) p.set(x,z.lawnY,M.CURB,4,{r:.12,ny:.6});
    for(const [a,b,h] of m.hedges) cHedge(p,a,b,m.hedgeBase,h,rnd);
    add('main',p,.32,c.world); }
  { const p=paint(c.world,c.H), z=c.plaza;
    for(let x=0;x<c.world;x++) p.set(x,z.y-1,M.CURB,4,{r:.12,ny:.6}); // 화단 경계석
    p.rect(0,z.y,c.world,z.h,M.CURB,(q,j)=> (j%5===0 || (q+Math.floor(j/5)*6)%14===0) ? 2 : (rnd()<.04?2:3),{ny:.5});
    p.rect(0,z.y+z.h,c.world,2,M.CURB,(q,j)=>j?1:5,{ny:.6});
    add('plaza',p,.27,c.world); }
  { const p=paint(c.world,c.H), r=c.road;
    p.rect(0,r.y,c.world,r.h,M.ASPH,(q,j)=> j<2?1 : (rnd()<.06?4:(rnd()<.04?2:3)),{ny:.5});
    if(r.walkY) p.rect(0,r.walkY,c.world,r.y+r.h-r.walkY,M.CURB,(q,j)=> j===0?5 : (j%6===0||q%16===0)?2:3,{ny:.5}); // 맨 아래 보도
    const cr=cropRows(p.s); out[N('road')]=cr.s; c.roadOY=cr.oy; }
  out[N('fence1')]=cFence(c.world,c.fence1.h); out[N('fence2')]=cFence(c.world,c.fence2.h); out[N('lamp')]=cLamp(c.lamps.h);
  c.layers=layers;
  return out;
}
function genCity(){
  const rnd=mulberry(29), out={};
  for(const [k,c] of Object.entries(CITY_CFG)) Object.assign(out, genCityScene(k,c,rnd));
  const V={ 'V':[M.VAN,1],'W':[M.VAN,5],'w':[M.VAN,4],'u':[M.VAN,3],'c':[M.VAN,2],'C':[M.VAN,5],'g':[M.WINLIT,2,.004],'G':[M.WINLIT,4,.004],
            'k':[M.MDARK,1],'K':[M.MDARK,4],'r':[M.RED,3],'L':[M.WINLIT,5,.003],'d':[M.MDARK,3] };
  out.c_van=fromLegend([
    "VVVVVVVVVVVVVVVVVVVVVVVVVVVV.............",
    "VWWWWWWWWWWWWWWWWWWWWWWWWWWV.............",
    "VWwwwwwwwwwwwwwwwwwwwwwwwwuV.ccccccc.....",
    "VWwwwwwwwwwwwwwwwwwwwwwwwwuVcCCCCCCCc....",
    "VWwwwwwwwwwwwwwwwwwwwwwwwwuVcCGggggCCc...",
    "VWwwwwwwwwwwwwwwwwwwwwwwwwuVcCGgggggCCc..",
    "VWwwwwwwwwwwwwwwwwwwwwwwwwuVcCggggggCCCc.",
    "VWwwwwwwwwwwwwwwwwwwwwwwwwuVcCCCCCCCCCCLc",
    "VWwwwwwwwwwwwwwwwwwwwwwwwwuVcCCCCCCCCCCCc",
    "VuuuuuuuuuuuuuuuuuuuuuuuuuuVcCCCCCCCCCCCc",
    "VVVVVVVVVVVVVVVVVVVVVVVVVVVVccccccccccccc",
    "rkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkk",
    "...kkkk..................kkkk.....kkkk...",
    "..kKddKk................kKddKk...kKddKk..",
    "...kkkk..................kkkk.....kkkk...",
  ], V, [20,14]);
  const D={ 'd':[M.MDARK,2],'b':[M.WOOD,2],'B':[M.WOOD,3] };
  out.c_dogA0=fromLegend([".....dd.","ddddddd.",".ddddd..",".d...d.."],D,[4,3]);
  out.c_dogA1=fromLegend([".....dd.","ddddddd.",".ddddd..","d.....d."],D,[4,3]);
  out.c_dogB0=fromLegend([".....bB.","bbbbbbb.",".bbbbb..",".b...b.."],D,[4,3]);
  out.c_dogB1=fromLegend([".....bB.","bbbbbbb.",".bbbbb..","b.....b."],D,[4,3]);
  const B={ 'x':[M.MDARK,3] };
  out.c_bird0=fromLegend(["x...x",".x.x."],B,[2,1]); out.c_bird1=fromLegend([".....","xx.xx"],B,[2,1]);
  return out;
}

