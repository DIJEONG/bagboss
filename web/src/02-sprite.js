/* =========================================================
   1. 스프라이트 · 외곽선 · 노멀 · RotSprite
   ========================================================= */
const LEG = {
  o:[M.INK,.5,0],
  '1':[M.ARMOR,.2,0], q:[M.ARMOR,.36,0], a:[M.ARMOR,.5,0], A:[M.ARMOR,.64,0], '!':[M.ARMOR,.8,0],
  x:[M.DARK,.3,0], d:[M.DARK,.5,0], D:[M.DARK,.68,0],
  z:[M.STEEL,.32,0], s:[M.STEEL,.5,0], S:[M.STEEL,.68,0], '*':[M.STEEL,.86,0],
  h:[M.GOLD,.34,.06], g:[M.GOLD,.5,.18], G:[M.GOLD,.68,.55], '+':[M.GOLD,.88,1],
  p:[M.BONE,.34,0], b:[M.BONE,.5,0], B:[M.BONE,.66,0], '^':[M.BONE,.82,0],
  v:[M.WOOD,.34,0], w:[M.WOOD,.5,0], W:[M.WOOD,.66,0],
  r:[M.RED,.5,0], R:[M.RED,.85,1], m:[M.RED,.34,0], u:[M.RED,.66,0],
  e:[M.EYE,.8,1], f:[M.GOLD,.9,1],
  k:[M.SKIN,.36,0], c:[M.SKIN,.5,0], C:[M.SKIN,.66,0], K:[M.SKIN,.82,0], n:[M.HAIR,.4,0], N:[M.HAIR,.6,0],
  l:[M.MDARK,.36,0], L:[M.MDARK,.64,0], F:[M.FRAME,.64,0],
  j:[M.SKIN,.22,0], y:[M.HAIR,.82,0], i:[M.FRAME,.82,0], U:[M.RED,.82,0],
  T:[M.HAIR,.22,0], V:[M.HAIR,.36,0], X:[M.HAIR,.5,0], E:[M.COAT,.22,0], I:[M.COAT,.36,0], J:[M.COAT,.5,0], O:[M.COAT,.66,0],
};
function newSprite(w,h){
  return { w, h, mat:new Uint8Array(w*h), tone:new Float32Array(w*h).fill(.5), emit:new Float32Array(w*h), rel:new Float32Array(w*h),
           nx:new Float32Array(w*h), ny:new Float32Array(w*h), px:0, py:0, mask:1 };
}
function fromAscii(rows, pivot){
  const h = rows.length, w = Math.max(...rows.map(r=>r.length));
  const s = newSprite(w,h);
  for(let y=0;y<h;y++) for(let x=0;x<w;x++){
    const ch = rows[y][x] || '.'; const L = LEG[ch];
    if(L){ const i=y*w+x; s.mat[i]=L[0]; s.tone[i]=L[1]; s.emit[i]=L[2]; }
  }
  s.px = pivot[0]; s.py = pivot[1];
  return s;
}
// 외곽선: 기본은 '자기 재질의 가장 어두운 단'으로 칠하는 컬러 외곽선. 발광 부위·눈은 잉크색.
function addOutline(s, mode='self'){
  const o = newSprite(s.w+2, s.h+2);
  for(let y=0;y<s.h;y++) for(let x=0;x<s.w;x++){
    const i=y*s.w+x, j=(y+1)*o.w+(x+1);
    o.mat[j]=s.mat[i]; o.tone[j]=s.tone[i]; o.emit[j]=s.emit[i];
  }
  const src = (x,y)=> (x>=1 && y>=1 && x<=s.w && y<=s.h && s.mat[(y-1)*s.w+(x-1)]>0) ? (y-1)*s.w+(x-1) : -1;
  for(let y=0;y<o.h;y++) for(let x=0;x<o.w;x++){
    const j=y*o.w+x; if(o.mat[j]) continue;
    let k=-1; for(const [dx,dy] of [[-1,0],[1,0],[0,-1],[0,1]]){ k=src(x+dx,y+dy); if(k>=0) break; }
    if(k<0) continue;
    const m=s.mat[k];
    if(mode==='ink' || m===M.INK || m===M.EYE || s.emit[k]>.5){ o.mat[j]=M.INK; o.tone[j]=.5; }
    else { o.mat[j]=m; o.tone[j]=.06; }
  }
  o.px = s.px+1; o.py = s.py+1; o.mask = s.mask;
  return o;
}
// 노멀을 8방향 × 3단계로 끊어 "도트 같은" 빛 경계를 만든다
function quantNormal(nx, ny){
  const t = Math.hypot(nx, ny);
  if(t < .2) return [0,0];
  const qt = t < .6 ? .5 : .85;
  const a = Math.round(Math.atan2(ny,nx)/(Math.PI/4))*(Math.PI/4);
  return [Math.cos(a)*qt, Math.sin(a)*qt];
}
// 외곽까지의 거리로 '쿠션' 높이를 만들고, 그 기울기로 노멀을 뽑는다 (모양만 있으면 노멀이 생김)
function pillowNormals(s, cap=4){
  const {w,h} = s, d = new Int16Array(w*h), q = [];
  const solid = (x,y)=> x>=0&&y>=0&&x<w&&y<h && s.mat[y*w+x]>0;
  for(let y=0;y<h;y++) for(let x=0;x<w;x++){
    if(!solid(x,y)) continue;
    if(!solid(x-1,y)||!solid(x+1,y)||!solid(x,y-1)||!solid(x,y+1)){ d[y*w+x]=1; q.push(x,y); }
  }
  let maxd = 1;
  for(let k=0;k<q.length;k+=2){
    const x=q[k], y=q[k+1], v=d[y*w+x];
    for(const [dx,dy] of [[1,0],[-1,0],[0,1],[0,-1]]){
      const X=x+dx, Y=y+dy;
      if(solid(X,Y) && !d[Y*w+X]){ d[Y*w+X]=v+1; maxd=Math.max(maxd,v+1); q.push(X,Y); }
    }
  }
  const R = Math.max(1, Math.min(cap, maxd-1));
  const hh = (x,y)=>{
    if(!solid(x,y)) return -0.45;
    const t = Math.min(d[y*w+x]-1, R)/R; return Math.sqrt(1-(1-t)*(1-t));
  };
  for(let y=0;y<h;y++) for(let x=0;x<w;x++){
    if(!solid(x,y)) continue;
    const gx = hh(x+1,y)-hh(x-1,y), gy = hh(x,y+1)-hh(x,y-1);
    let nx=-gx*1.1, ny=gy*1.1; const L=Math.hypot(nx,ny,1); nx/=L; ny/=L;
    const qn = quantNormal(nx,ny); s.nx[y*w+x]=qn[0]; s.ny[y*w+x]=qn[1];
  }
  return s;
}
const finish = (s, cap, mode) => pillowNormals(addOutline(s, mode), cap);
// 실루엣 쿠션 + 재질 영역 쿠션을 섞은 자동 노멀 (불러온 원화용)
function autoNormals(s){
  const a=pillowField(s.w,s.h,Uint8Array.from(s.mat,m=>m?1:0),3), b=pillowField(s.w,s.h,s.mat,3);
  for(let i=0;i<s.w*s.h;i++){ if(!s.mat[i]) continue; const q=quantNormal((a.nx[i]+b.nx[i])*.5,(a.ny[i]+b.ny[i])*.5); s.nx[i]=q[0]; s.ny[i]=q[1]; }
  return s;
}
const plain = (s, mask=1) => { s.mask=mask; return pillowNormals(s, 2); };
// 휘두름 잔상(스미어): 어깨를 중심으로 한 초승달. 앞쪽이 두껍고 꼬리로 갈수록 가늘어짐
function genSmear(R, thick, th0, th1, mat){
  const N=2*R+3, c=R+1, s=newSprite(N,N); s.px=c; s.py=c;
  for(let y=0;y<N;y++) for(let x=0;x<N;x++){
    const dx=x-c, dy=y-c, r=Math.hypot(dx,dy); let th=Math.atan2(dx,dy)*180/Math.PI; if(th<0) th+=360;
    if(th<th0||th>th1) continue;
    const u=(th-th0)/(th1-th0), inner=R-thick*Math.pow(1-u,1.3);
    if(r<inner||r>R) continue;
    const edge=r>R-1.6, i=y*N+x;
    if(u>.55 && ((x+y)&1)) continue; // 꼬리는 한 칸 걸러 찍어 흩어지게
    s.mat[i]=mat; s.tone[i]=edge?.95:.78; s.emit[i]=edge?1:.25+.6*(1-u);
  }
  return plain(crop(s));
}

// --- RotSprite: Scale2x×3 → 회전(최근접) → 1/8 샘플 ---
function scale2x(g){
  const W2=g.w*2, H2=g.h*2, o=new Int32Array(W2*H2);
  const at=(x,y)=> (x<0||y<0||x>=g.w||y>=g.h) ? 0 : g.c[y*g.w+x];
  for(let y=0;y<g.h;y++) for(let x=0;x<g.w;x++){
    const P=at(x,y), A=at(x,y-1), B=at(x+1,y), C=at(x-1,y), D=at(x,y+1);
    let e0=P,e1=P,e2=P,e3=P;
    if(C===A && C!==D && A!==B) e0=A;
    if(A===B && A!==C && B!==D) e1=B;
    if(D===C && D!==B && C!==A) e2=C;
    if(B===D && B!==A && D!==C) e3=D;
    o[(2*y)*W2+2*x]=e0; o[(2*y)*W2+2*x+1]=e1; o[(2*y+1)*W2+2*x]=e2; o[(2*y+1)*W2+2*x+1]=e3;
  }
  return {w:W2,h:H2,c:o};
}
// o.outline=false: 외곽선을 더하지 않음(불러온 원화) · o.keepN=true: 원본 노멀을 회전시켜 유지
function bakeRot(raw, cap, o={}){
  const outline=o.outline!==false, keepN=!!o.keepN;
  const table=[null], key=new Map();
  const g0={w:raw.w+2,h:raw.h+2,c:new Int32Array((raw.w+2)*(raw.h+2))};
  for(let y=0;y<raw.h;y++) for(let x=0;x<raw.w;x++){
    const i=y*raw.w+x; if(!raw.mat[i]) continue;
    const k=raw.mat[i]+'|'+raw.tone[i]+'|'+raw.emit[i]+(keepN?'|'+raw.nx[i].toFixed(2)+'|'+raw.ny[i].toFixed(2):'');
    if(!key.has(k)){ key.set(k, table.length); table.push([raw.mat[i],raw.tone[i],raw.emit[i],raw.nx[i],raw.ny[i]]); }
    g0.c[(y+1)*g0.w+(x+1)] = key.get(k);
  }
  let g=g0; for(let k=0;k<3;k++) g=scale2x(g);
  const S=8, cx=(raw.px+1+.5)*S, cy=(raw.py+1+.5)*S;
  let R=0; for(const [x,y] of [[0,0],[raw.w,0],[0,raw.h],[raw.w,raw.h]]) R=Math.max(R, Math.hypot(x-raw.px-.5, y-raw.py-.5));
  R=Math.ceil(R)+1;
  const out=[];
  for(let a=0;a<32;a++){
    const th=a*Math.PI/16, c=Math.cos(th), sn=Math.sin(th), N=2*R+1;
    const s=newSprite(N,N); s.px=R; s.py=R;
    for(let oy=0;oy<N;oy++) for(let ox=0;ox<N;ox++){
      const dx=ox-R, dy=oy-R;
      const lx=dx*c-dy*sn, ly=dx*sn+dy*c;
      let code=0;
      if(a%8===0){ // 90° 배수는 원본 그대로 (손실 없음)
        const sx=raw.px+Math.round(lx), sy=raw.py+Math.round(ly);
        if(sx>=0&&sy>=0&&sx<raw.w&&sy<raw.h) code=g0.c[(sy+1)*g0.w+(sx+1)];
      } else {
        const sx=Math.floor(cx+lx*S-.5), sy=Math.floor(cy+ly*S-.5);
        if(sx>=0&&sy>=0&&sx<g.w&&sy<g.h) code=g.c[sy*g.w+sx];
      }
      if(code){ const t=table[code], i=oy*N+ox; s.mat[i]=t[0]; s.tone[i]=t[1]; s.emit[i]=t[2];
        if(keepN){ const vx=t[3], vy=-t[4]; s.nx[i]=vx*c+vy*sn; s.ny[i]=-(-vx*sn+vy*c); } }
    }
    out.push(outline ? finish(crop(s), cap) : keepN ? crop(s) : autoNormals(crop(s)));
  }
  return out;
}
function crop(s){
  let x0=s.w,y0=s.h,x1=-1,y1=-1;
  for(let y=0;y<s.h;y++) for(let x=0;x<s.w;x++) if(s.mat[y*s.w+x]){ x0=Math.min(x0,x); y0=Math.min(y0,y); x1=Math.max(x1,x); y1=Math.max(y1,y); }
  if(x1<0) return s;
  const o=newSprite(x1-x0+1,y1-y0+1);
  for(let y=y0;y<=y1;y++) for(let x=x0;x<=x1;x++){
    const i=y*s.w+x, j=(y-y0)*o.w+(x-x0); o.mat[j]=s.mat[i]; o.tone[j]=s.tone[i]; o.emit[j]=s.emit[i]; o.nx[j]=s.nx[i]; o.ny[j]=s.ny[i]; o.rel[j]=s.rel[i];
  }
  o.px=s.px-x0; o.py=s.py-y0; o.mask=s.mask;
  return o;
}

