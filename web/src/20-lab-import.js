/* =========================================================
   11-b. 원화 파이프라인
   .aseprite / PNG → 레이어 역할(색·노멀·발광·재질·높이) → 재질 램프 + 톤 + 노멀
   ========================================================= */
const fileIn=document.getElementById('fileIn'), bClear=document.getElementById('bClear'), impMsg=document.getElementById('impMsg');
const UMAT0=56, UREG_P={x:0,y:atlasUserY,w:atlasW,h:704}, UREG_F={x:0,y:atlasUserY+704,w:atlasW,h:USER_REG_H-704};
const TINTS=[null,['#2c0e3e',.38,'#ffc58a',.30],['#03223c',.36,'#d4f3ff',.26]];
const CAND=[]; for(const m of [1,3,4,5,6,7,8,9,10,11,12,13,14]) PALS[0][m].forEach((c,st)=>CAND.push([m,st,c]));
function nearestMat(r,g,b){ let best=null, bd=1e12;
  for(const [m,st,c] of CAND){ const dr=r-c[0], dg=g-c[1], db=b-c[2], d=2*dr*dr+4*dg*dg+3*db*db; if(d<bd){ bd=d; best=[m,st]; } }
  return best; }
function detectScale(d,w,h){
  for(const sc of [8,6,5,4,3,2]){
    if(w%sc||h%sc) continue; let ok=true;
    for(let y=0;y<h&&ok;y++) for(let x=0;x<w;x++){
      const i=(y*w+x)*4, j=((y-y%sc)*w+(x-x%sc))*4;
      if(Math.abs(d[i]-d[j])>10||Math.abs(d[i+1]-d[j+1])>10||Math.abs(d[i+2]-d[j+2])>10||Math.abs(d[i+3]-d[j+3])>10){ ok=false; break; }
    }
    if(ok) return sc;
  }
  return 1;
}
// --- OKLab (색을 사람 눈 기준으로 비교·보간) ---
const s2l=c=>{ c/=255; return c<=.04045?c/12.92:Math.pow((c+.055)/1.055,2.4); };
const l2s=c=>{ c=c<=.0031308?12.92*c:1.055*Math.pow(c,1/2.4)-.055; return Math.round(Math.max(0,Math.min(1,c))*255); };
function toLab(rgb){ const r=s2l(rgb[0]), g=s2l(rgb[1]), b=s2l(rgb[2]);
  const l=Math.cbrt(.4122214708*r+.5363325363*g+.0514459929*b), m=Math.cbrt(.2119034982*r+.6806995451*g+.1073969566*b), s=Math.cbrt(.0883024619*r+.2817188376*g+.6299787005*b);
  return [.2104542553*l+.793617785*m-.0040720468*s, 1.9779984951*l-2.428592205*m+.4505937099*s, .0259040371*l+.7827717662*m-.808675766*s]; }
function fromLab(c){ const L=c[0], a=c[1], b=c[2];
  const l=(L+.3963377774*a+.2158037573*b)**3, m=(L-.1055613458*a-.0638541728*b)**3, s=(L-.0894841775*a-1.291485548*b)**3;
  return [l2s(4.0767416621*l-3.3077115913*m+.2309699292*s), l2s(-1.2684380046*l+2.6097574011*m-.3413193965*s), l2s(-.0041960863*l-.7034186147*m+1.707614701*s)]; }
const hueOf=c=>Math.atan2(c[2],c[1])*180/Math.PI, chromaOf=c=>Math.hypot(c[1],c[2]);
const hueDiff=(a,b)=>{ const d=Math.abs(a-b)%360; return d>180?360-d:d; };
function tintRow(row,sh,ks,hi,kh){ const S=hexRGB(sh), Hh=hexRGB(hi);
  return row.map((rgb,s)=>{ const t=s/(STEPS-1), a=ks*Math.pow(1-t,1.4), b=kh*Math.pow(t,1.6);
    return rgb.map((v,i)=>Math.round(Math.max(0,Math.min(255,(v*(1-a)+S[i]*a)*(1-b)+Hh[i]*b)))); }); }
function setUserPalette(ramps){
  for(let m=UMAT0;m<NMAT;m++){ const r=ramps[m-UMAT0];
    for(let pi=0;pi<NPAL;pi++){
      const row = !r ? Array(STEPS).fill([0,0,0]) : (pi===0||r.flat) ? r.rgb : tintRow(r.rgb,...TINTS[pi]);
      row.forEach((c,s)=>{ const j=((pi*NMAT+m)*STEPS+s)*4; palData[j]=c[0]; palData[j+1]=c[1]; palData[j+2]=c[2]; palData[j+3]=255; });
    }
  }
  gl.bindTexture(gl.TEXTURE_2D,palTex); gl.texSubImage2D(gl.TEXTURE_2D,0,0,0,STEPS,NMAT*NPAL,gl.RGBA,gl.UNSIGNED_BYTE,palData);
}

// --- 읽기: .aseprite ---
async function inflate(u8){ const st=new Blob([u8]).stream().pipeThrough(new DecompressionStream('deflate')); return new Uint8Array(await new Response(st).arrayBuffer()); }
const ROLE_RE=[['pivot',/pivot|joint|관절|피벗/],['normal',/normal|노멀|nrm/],['height',/height|높이|bump/],['emit',/emi|glow|발광/],['mat',/(^|[ _-])mat|material|재질/]];
function roleOf(name){ const n=(name||'').toLowerCase(); for(const [r,re] of ROLE_RE) if(re.test(n)) return r; return 'color'; }
// 파츠 이름 (그룹 또는 레이어). 자식 레이어는 그룹의 파츠를 물려받음
const PART_RE=[['armF',/arm[ _-]?(f|front)\b|front[ _-]?arm|앞팔/],['armB',/arm[ _-]?(b|back)\b|back[ _-]?arm|뒷팔/],
  ['legF',/leg[ _-]?(f|front)\b|front[ _-]?leg|앞다리/],['legB',/leg[ _-]?(b|back)\b|back[ _-]?leg|뒷다리/],
  ['arm',/(^|[ _-])arm|팔/],['leg',/(^|[ _-])leg|다리/],['head',/head|머리/],['torso',/torso|body|몸통|몸/],
  ['wpn',/weapon|wpn|sword|무기/],['off',/off[ _-]?hand|shield|방패|보조/],['cape',/cape|scarf|망토|목도리/]];
function partOf(name){ const n=(name||'').toLowerCase(); for(const [p,re] of PART_RE) if(re.test(n)) return p; return null; }
async function parseAse(buf, name){
  const dv=new DataView(buf), u8=new Uint8Array(buf); let p=0;
  const r8=()=>dv.getUint8(p++), r16=()=>{ const v=dv.getUint16(p,true); p+=2; return v; }, s16=()=>{ const v=dv.getInt16(p,true); p+=2; return v; }, r32=()=>{ const v=dv.getUint32(p,true); p+=4; return v; };
  const str=()=>{ const n=r16(); const s=new TextDecoder().decode(u8.subarray(p,p+n)); p+=n; return s; };
  r32(); if(r16()!==0xA5E0) throw new Error('Aseprite 파일이 아니에요');
  const nF=r16(), w=r16(), h=r16(), depth=r16(); p=28; const transIdx=dv.getUint8(28); p=128;
  if(w>512||h>512) throw new Error(`캔버스가 ${w}×${h}이에요. 512×512 이하로 올려 주세요`);
  const layers=[], frames=[], tags=[], palette=[];
  for(let f=0;f<nF;f++){
    const fs=p, fb=r32(); if(r16()!==0xF1FA) throw new Error('프레임 머리를 읽지 못했어요');
    const oldN=r16(), dur=r16(); p+=2; const newN=r32(); const n=newN||oldN, cels=[];
    for(let c=0;c<n;c++){
      const cs=p, size=r32(), type=r16();
      if(type===0x2004){ const fl=r16(), lt=r16(), lvl=r16(); p+=4; r16(); const op=r8(); p+=3; layers.push({flags:fl,type:lt,level:lvl,opacity:op,name:str()}); }
      else if(type===0x2005){ const li=r16(), x=s16(), y=s16(), op=r8(), ct=r16(); p+=7;
        if(ct===0||ct===2){ const cw=r16(), ch=r16(), raw=u8.subarray(p,cs+size); cels.push({li,x,y,op,w:cw,h:ch,data: ct===2 ? await inflate(raw) : raw.slice()}); }
        else if(ct===1) cels.push({li,link:r16()}); }
      else if(type===0x2018){ const nt=r16(); p+=8; for(let t=0;t<nt;t++){ const from=r16(), to=r16(), dir=r8(); r16(); p+=10; tags.push({from,to,dir,name:str()}); } }
      else if(type===0x2019){ r32(); const first=r32(), lastI=r32(); p+=8; for(let i=first;i<=lastI;i++){ const ef=r16(); palette[i]=[r8(),r8(),r8(),r8()]; if(ef&1) str(); } }
      else if(type===0x0004 && !palette.length){ const np=r16(); let idx=0; for(let k=0;k<np;k++){ idx+=r8(); const cnt=r8()||256; for(let i=0;i<cnt;i++) palette[idx++]=[r8(),r8(),r8(),255]; } }
      p=cs+size;
    }
    frames.push({dur:dur||100,cels}); p=fs+fb;
  }
  frames.forEach(fr=>fr.cels.forEach((c,ci)=>{ if(c.link!==undefined){ const src=frames[c.link]&&frames[c.link].cels.find(x=>x.li===c.li&&x.data); if(src) fr.cels[ci]=src; } }));
  // 그룹 레이어 이름이 역할을 정하면 자식이 물려받음. 색 레이어만 '보임' 여부를 따름
  const stack=[];
  layers.forEach(L=>{ stack.length=L.level; const par=stack[L.level-1]; const own=roleOf(L.name);
    L.role = own!=='color' ? own : (par ? par.role : 'color'); L.vis = !!(L.flags&1) && (!par || par.vis);
    L.part = partOf(L.name) || (par ? par.part : null); stack[L.level]=L; });
  const bpp=depth===32?4:depth===16?2:1;
  const celPx=(cel,L)=>{ const out=new Uint8ClampedArray(cel.w*cel.h*4), d=cel.data;
    for(let i=0;i<cel.w*cel.h;i++){ const o=i*4;
      if(bpp===4){ out[o]=d[i*4]; out[o+1]=d[i*4+1]; out[o+2]=d[i*4+2]; out[o+3]=d[i*4+3]; }
      else if(bpp===2){ out[o]=out[o+1]=out[o+2]=d[i*2]; out[o+3]=d[i*2+1]; }
      else { const k=d[i]; if(k===transIdx && !(L.flags&8)) continue; const c=palette[k]||[0,0,0,255]; out[o]=c[0]; out[o+1]=c[1]; out[o+2]=c[2]; out[o+3]=c[3]; } }
    return out; };
  const compose=(fr,role,part)=>{ let out=null;
    for(const cel of [...fr.cels].filter(c=>c.data).sort((a,b)=>a.li-b.li)){
      const L=layers[cel.li]; if(!L||L.type!==0||L.role!==role||(role==='color'&&!L.vis)) continue;
      if(part!==undefined && L.part!==part) continue;
      if(!out) out=new Uint8ClampedArray(w*h*4);
      const px=celPx(cel,L), op=role==='color' ? (L.opacity/255)*(cel.op/255) : 1;
      for(let y=0;y<cel.h;y++) for(let x=0;x<cel.w;x++){
        const X=cel.x+x, Y=cel.y+y; if(X<0||Y<0||X>=w||Y>=h) continue;
        const s=(y*cel.w+x)*4, o=(Y*w+X)*4, sa=px[s+3]/255*op; if(sa<=0) continue;
        const da=out[o+3]/255, oa=sa+da*(1-sa);
        for(let k=0;k<3;k++) out[o+k]=(px[s+k]*sa+out[o+k]*da*(1-sa))/oa;
        out[o+3]=oa*255;
      } }
    return out; };
  const roles={}; layers.forEach(L=>{ if(L.type===0) roles[L.role]=true; });
  const partNames=[...new Set(layers.filter(L=>L.type===0&&L.part).map(L=>L.part))];
  if(partNames.length){ // 파츠 리그 모드: 첫 프레임의 조립된 기본 자세를 읽음
    // 파츠 그룹 안에서 역할 레이어 없이 이름만 파츠인 레이어는 색으로 취급
    const parts={}; const fr=frames[0];
    for(const pn of partNames) parts[pn]={ color:compose(fr,'color',pn), normal:compose(fr,'normal',pn), emit:compose(fr,'emit',pn), height:compose(fr,'height',pn), mat:compose(fr,'mat',pn), pivot:compose(fr,'pivot',pn) };
    return { mode:'parts', name, w, h, scale:1, roles, parts, tags:[], frames:[] };
  }
  return { mode:'frames', name, w, h, scale:1, roles, layerNames:layers.filter(L=>L.type===0).map(L=>L.name+':'+L.role),
    tags, frames: frames.map(fr=>({ dur:fr.dur, color:compose(fr,'color'), normal:compose(fr,'normal'), emit:compose(fr,'emit'), height:compose(fr,'height'), mat:compose(fr,'mat') })) };
}
// --- 읽기: PNG (파일 이름 끝으로 역할 구분: _normal · _emit · _height · _mat) ---
const SUFFIX=[['normal',/[_-](normal|nrm|n|노멀)$/i],['emit',/[_-](emit|emissive|glow|e|발광)$/i],['height',/[_-](height|bump|h|높이)$/i],['mat',/[_-](mat|material|m|재질)$/i]];
async function readImage(f){ const bmp=await createImageBitmap(f); const cv=document.createElement('canvas'); cv.width=bmp.width; cv.height=bmp.height;
  const cx=cv.getContext('2d',{willReadFrequently:true}); cx.drawImage(bmp,0,0); return { w:cv.width, h:cv.height, data:cx.getImageData(0,0,cv.width,cv.height).data }; }
async function parsePNGs(files){
  const parts={}; let base='';
  for(const f of files){ const stem=f.name.replace(/\.[^.]+$/,''); let role='color', b=stem;
    for(const [r,re] of SUFFIX) if(re.test(stem)){ role=r; b=stem.replace(re,''); break; }
    parts[role]=await readImage(f); if(role==='color') base=b; }
  if(!parts.color) throw new Error('색 PNG가 필요해요. 이름 끝에 _normal 같은 꼬리가 없는 파일이 색으로 읽혀요');
  const C=parts.color, sc=detectScale(C.data,C.w,C.h), w=Math.floor(C.w/sc), h=Math.floor(C.h/sc);
  const down=img=>{ if(!img) return null; const k=img.w/w, o=new Uint8ClampedArray(w*h*4);
    for(let y=0;y<h;y++) for(let x=0;x<w;x++){ const i=(Math.floor(y*k)*img.w+Math.floor(x*k))*4, j=(y*w+x)*4; for(let c=0;c<4;c++) o[j+c]=img.data[i+c]; } return o; };
  const roles={}; for(const r in parts) roles[r]=true;
  return { mode:'frames', name:base, w, h, scale:sc, roles, layerNames:Object.keys(parts), tags:[],
    frames:[{ dur:150, color:down(parts.color), normal:down(parts.normal), emit:down(parts.emit), height:down(parts.height), mat:down(parts.mat) }] };
}

// --- 색 → 램프 ---
function splitGroup(g, info){ // (a,b) 평면에서 2-평균으로 나눔. 시작점은 색상이 가장 먼 두 색
  let A=g.slice(0,1), B=g.slice(-1), far=-1;
  for(const x of g) for(const y of g){ const p=info.get(x).lab, q=info.get(y).lab, d=Math.hypot(p[1]-q[1],p[2]-q[2]); if(d>far){ far=d; A=[x]; B=[y]; } } let ca=info.get(A[0]).lab, cb=info.get(B[0]).lab;
  for(let it=0;it<8;it++){ A=[]; B=[];
    for(const k of g){ const l=info.get(k).lab; (Math.hypot(l[1]-ca[1],l[2]-ca[2],(l[0]-ca[0])*.3) <= Math.hypot(l[1]-cb[1],l[2]-cb[2],(l[0]-cb[0])*.3) ? A : B).push(k); }
    if(!A.length||!B.length) break;
    const mean=s=>[0,1,2].map(i=>s.reduce((t,k)=>t+info.get(k).lab[i],0)/s.length); ca=mean(A); cb=mean(B); }
  if(A.length&&B.length) return [A,B];
  const h=Math.ceil(g.length/2); return [g.slice(0,h), g.slice(h)];
}
function buildRamp(labs){ // L 오름차순 원본 색(≤6) → 6단 램프. 원본은 가운데에 그대로, 양 끝은 작가의 램프 방향으로 연장
  const n=labs.length, s0=Math.max(0,Math.min(STEPS-n,Math.round((STEPS-n)*.4))), out=new Array(STEPS);
  labs.forEach((l,i)=>out[s0+i]=l);
  const stepOf=(a,b,def)=>{ if(!a||!b) return def; let d=[a[0]-b[0],a[1]-b[1],a[2]-b[2]]; const m=Math.abs(d[0]);
    const t=Math.max(.045,Math.min(.12,m)); const sgn=Math.sign(def[0]); return [sgn*t, d[1]*.6, d[2]*.6]; };
  const dn=stepOf(labs[0],labs[1],[-.09,-.004,-.022]), up=stepOf(labs[n-1],labs[n-2],[.085,.004,.018]);
  for(let s=s0-1;s>=0;s--){ const b=out[s+1]; out[s]=[Math.max(.03,b[0]+dn[0]),(b[1]+dn[1])*.86,(b[2]+dn[2])*.86]; }
  for(let s=s0+n;s<STEPS;s++){ const b=out[s-1]; out[s]=[Math.min(.98,b[0]+up[0]),(b[1]+up[1])*.84,(b[2]+up[2])*.84]; }
  return { rgb:out.map(fromLab), s0, n };
}
// 쿠션 노멀: grp가 같은 이웃만 '안쪽'으로 보고 외곽 거리로 높이를 만든 뒤 기울기를 노멀로
function pillowField(w,h,grp,cap){
  const d=new Int16Array(w*h), q=[], nx=new Float32Array(w*h), ny=new Float32Array(w*h);
  const inside=(x,y,g)=> g!==0 && x>=0&&y>=0&&x<w&&y<h && grp[y*w+x]===g;
  for(let y=0;y<h;y++) for(let x=0;x<w;x++){ const g=grp[y*w+x]; if(!g) continue;
    if(!inside(x-1,y,g)||!inside(x+1,y,g)||!inside(x,y-1,g)||!inside(x,y+1,g)){ d[y*w+x]=1; q.push(x,y); } }
  for(let k=0;k<q.length;k+=2){ const x=q[k], y=q[k+1], g=grp[y*w+x], v=d[y*w+x];
    for(const [dx,dy] of [[1,0],[-1,0],[0,1],[0,-1]]){ const X=x+dx, Y=y+dy; if(inside(X,Y,g)&&!d[Y*w+X]){ d[Y*w+X]=v+1; q.push(X,Y); } } }
  const hh=(x,y,g)=>{ if(!inside(x,y,g)) return -.45; const t=Math.min(d[y*w+x]-1,cap)/cap; return Math.sqrt(1-(1-t)*(1-t)); };
  for(let y=0;y<h;y++) for(let x=0;x<w;x++){ const g=grp[y*w+x]; if(!g) continue;
    let a=-(hh(x+1,y,g)-hh(x-1,y,g))*1.1, b=(hh(x,y+1,g)-hh(x,y-1,g))*1.1; const L=Math.hypot(a,b,1); nx[y*w+x]=a/L; ny[y*w+x]=b/L; }
  return {nx,ny};
}

// items: [{src:{color,emit,mat,normal,height}, x0,y0,bw,bh}] — 프레임이든 파츠든 같은 방식으로 색을 분석
function analyze(doc, items, opt){
  const w=doc.w, info=new Map(), adj=new Map(), E=1<<24;
  const pix=items.map(it=>{ const fr=it.src, {x0,y0,bw,bh}=it, P=new Array(bw*bh);
    for(let y=0;y<bh;y++) for(let x=0;x<bw;x++){ const i=((y+y0)*w+(x+x0))*4;
      const ca=fr.color?fr.color[i+3]:0, ea=fr.emit?fr.emit[i+3]:0; if(ca<128&&ea<128) continue;
      const src=ca>=128?fr.color:fr.emit, rgb=[src[i],src[i+1],src[i+2]], em=ea>=128;
      const key=((rgb[0]<<16)|(rgb[1]<<8)|rgb[2])+(em?E:0);
      let o=info.get(key); if(!o){ o={key,rgb,lab:toLab(rgb),n:0,em,mats:new Map()}; info.set(key,o); }
      o.n++;
      if(fr.mat&&fr.mat[i+3]>=128){ const mk=(fr.mat[i]<<16)|(fr.mat[i+1]<<8)|fr.mat[i+2]; o.mats.set(mk,(o.mats.get(mk)||0)+1); }
      P[y*bw+x]={key, ea:ea/255}; }
    for(let y=0;y<bh;y++) for(let x=0;x<bw;x++){ const a=P[y*bw+x]; if(!a||info.get(a.key).em) continue;
      for(const b of [x+1<bw?P[y*bw+x+1]:null, y+1<bh?P[(y+1)*bw+x]:null]){ if(!b||b.key===a.key||info.get(b.key).em) continue;
        const k=a.key<b.key?a.key+'|'+b.key:b.key+'|'+a.key; adj.set(k,(adj.get(k)||0)+1); } }
    return P; });
  // 2) 재질 그룹
  const keys=[...info.keys()].filter(k=>!info.get(k).em), ekeys=[...info.keys()].filter(k=>info.get(k).em);
  let groups=[];
  if(opt.colorMode==='keep'){
    if(doc.roles.mat){ const by=new Map();
      for(const k of keys){ const o=info.get(k); let best=-1,bn=-1; for(const [mk,c] of o.mats) if(c>bn){ bn=c; best=mk; } if(!by.has(best)) by.set(best,[]); by.get(best).push(k); }
      groups=[...by.values()];
    } else {
      const par=new Map(keys.map(k=>[k,k])); const find=k=>{ while(par.get(k)!==k){ par.set(k,par.get(par.get(k))); k=par.get(k); } return k; };
      const uni=(a,b)=>{ a=find(a); b=find(b); if(a!==b) par.set(a,b); };
      const cls=k=>{ const l=info.get(k).lab; return l[0]<.2?'ink':chromaOf(l)<.03?'grey':'chroma'; };
      const ink=keys.filter(k=>cls(k)==='ink'), grey=keys.filter(k=>cls(k)==='grey'), chr=keys.filter(k=>cls(k)==='chroma');
      ink.forEach(k=>uni(k,ink[0])); // 외곽선 계열은 한 램프
      // 같은 재질의 명암 단은 서로 길게 맞닿고(면적 대비 경계가 큼) 밝기 차가 한두 단 정도다
      for(const [pk,cn] of adj){ const [a,b]=pk.split('|').map(Number); if(cls(a)==='ink'||cls(b)==='ink') continue;
        const A=info.get(a).lab, B=info.get(b).lab, st=cn/Math.min(info.get(a).n,info.get(b).n);
        if(st<.3 || Math.abs(A[0]-B[0])>=.25) continue;
        const ok = (cls(a)==='chroma'&&cls(b)==='chroma') ? (hueDiff(hueOf(A),hueOf(B))<30 && Math.abs(chromaOf(A)-chromaOf(B))<.09) : Math.abs(chromaOf(A)-chromaOf(B))<.06;
        if(ok) uni(a,b); }
      const by=new Map(); for(const k of keys){ const r=find(k); if(!by.has(r)) by.set(r,[]); by.get(r).push(k); }
      groups=[...by.values()];
    }
    // 6색 초과이거나 색상 폭이 40°를 넘는 그룹은 둘로 나눔 (서로 다른 재질이 이어 붙는 것 방지)
    const hueSpan=g=>{ const hs=g.map(k=>info.get(k).lab).filter(l=>chromaOf(l)>=.03&&l[0]>=.2).map(l=>(hueOf(l)+360)%360).sort((x,y)=>x-y);
      if(hs.length<2) return 0; let gap=hs[0]+360-hs[hs.length-1]; for(let i=1;i<hs.length;i++) gap=Math.max(gap,hs[i]-hs[i-1]); return 360-gap; };
    const bad=g=>g.length>STEPS || (g.length>1 && hueSpan(g)>40);
    for(let guard=0; guard<64 && groups.some(bad); guard++){
      const i=groups.findIndex(bad); groups.splice(i,1,...splitGroup(groups[i],info)); }
    groups.sort((a,b)=>cnt(b)-cnt(a));
    const room=NMAT-UMAT0-Math.min(ekeys.length,8);
    while(groups.length>room){ const g=groups.pop(); const m=g.map(k=>info.get(k).lab)[0];
      let bi=0,bd=1e9; groups.forEach((G,i)=>{ const l=info.get(G[0]).lab, d=Math.hypot(l[0]-m[0],l[1]-m[1],l[2]-m[2]); if(G.length<STEPS&&d<bd){ bd=d; bi=i; } });
      groups[bi].push(...g.slice(0,STEPS-groups[bi].length)); }
  }
  // 3) 재질 ID · 램프
  const ramps=[], assign=new Map(); let mid=UMAT0;
  for(const g of groups){ const sorted=g.slice().sort((a,b)=>info.get(a).lab[0]-info.get(b).lab[0]);
    const R=buildRamp(sorted.map(k=>info.get(k).lab)); ramps.push({rgb:R.rgb, flat:false, orig:sorted.map((k,i)=>R.s0+i), size:cnt(g)});
    sorted.forEach((k,i)=>assign.set(k,{m:mid, s:R.s0+i})); mid++; }
  function cnt(g){ return g.reduce((t,k)=>t+info.get(k).n,0); }
  const eSorted=ekeys.slice().sort((a,b)=>info.get(b).n-info.get(a).n);
  eSorted.forEach((k,i)=>{ if(i<8 && mid<NMAT){ const c=info.get(k).rgb; ramps.push({rgb:Array(STEPS).fill(c), flat:true, orig:[0,1,2,3,4,5], size:info.get(k).n}); assign.set(k,{m:mid,s:4}); mid++; }
    else { const c=info.get(k).lab; let best=null,bd=1e9; for(const k2 of eSorted.slice(0,8)){ const l=info.get(k2).lab, d=Math.hypot(l[0]-c[0],l[1]-c[1],l[2]-c[2]); if(d<bd){ bd=d; best=k2; } } if(best!==null && assign.has(best)) assign.set(k,assign.get(best)); } });
  return { info, pix, ramps, assign, groups:groups.length, emissive:Math.min(ekeys.length,8) };
}
function itemSprite(doc, it, P, an, opt){
  const w=doc.w, fr=it.src, {x0,y0,bw,bh}=it, {info,assign}=an;
  const s=newSprite(bw,bh); s.mask=1;
  for(let i=0;i<bw*bh;i++){ const a=P[i]; if(!a) continue; const o=info.get(a.key);
    if(opt.colorMode==='keep' || o.em){ const as=assign.get(a.key)||{m:M.INK,s:2}; s.mat[i]=as.m; s.tone[i]=Math.min(1,(as.s+.5)/7.2); }
    else { const mm=Math.max(...o.rgb)<28 ? [M.INK,2] : nearestMat(...o.rgb); s.mat[i]=mm[0]; s.tone[i]=Math.min(1,(mm[1]+.5)/7.2); }
    s.emit[i]=o.em ? Math.max(.6,a.ea) : 0; }
  // 노멀: 노멀 레이어 > 높이 레이어 > 자동(실루엣 + 재질 영역 쿠션)
  const sil=pillowField(bw,bh,Uint8Array.from(s.mat,m=>m?1:0),3), grp=pillowField(bw,bh,s.mat,3);
  let hasN=false;
  for(let y=0;y<bh;y++) for(let x=0;x<bw;x++){ const i=y*bw+x; if(!s.mat[i]) continue; const k=((y+y0)*w+(x+x0))*4;
    if(fr.normal && fr.normal[k+3]>=128){ let a=fr.normal[k]/127.5-1, b=(fr.normal[k+1]/127.5-1)*(opt.flipG?-1:1)*(it.mirX?1:1); if(it.mirX) a=-a; const L=Math.hypot(a,b); if(L>.95){ a*=.95/L; b*=.95/L; } s.nx[i]=a; s.ny[i]=b; hasN=true; continue; }
    if(fr.height){ const H_=(X,Y)=>{ if(X<0||Y<0||X>=bw||Y>=bh) return 0; const j=((Y+y0)*w+(X+x0))*4; return fr.height[j+3]<128?0:(fr.height[j]+fr.height[j+1]+fr.height[j+2])/765; };
      let a=-(H_(x+1,y)-H_(x-1,y))*2, b=(H_(x,y+1)-H_(x,y-1))*2; const L=Math.hypot(a,b,1); const qn=quantNormal(a/L,b/L); s.nx[i]=qn[0]; s.ny[i]=qn[1]; hasN=true; continue; }
    const qn=quantNormal((sil.nx[i]+grp.nx[i])*.5,(sil.ny[i]+grp.ny[i])*.5); s.nx[i]=qn[0]; s.ny[i]=qn[1]; }
  // 발광 픽셀의 무게중심 · 평균색 (자동 광원용)
  let ex=0,ey=0,en=0,ec=[0,0,0];
  for(let i=0;i<bw*bh;i++) if(s.emit[i]>0){ const o=info.get(P[i].key); ex+=i%bw; ey+=Math.floor(i/bw); en++; ec=ec.map((v,c)=>v+o.rgb[c]); }
  const glow = en ? { x:ex/en, y:ey/en, n:en, c:(()=>{ const m=ec.map(v=>v/en); const mx=Math.max(...m,1); return m.map(v=>v/mx); })() } : null;
  return { s, glow, hasN };
}
const visBox=(w,h,arrs)=>{ let x0=w,y0=h,x1=-1,y1=-1;
  for(const fr of arrs) for(let y=0;y<h;y++) for(let x=0;x<w;x++){ const i=(y*w+x)*4;
    if((fr.color&&fr.color[i+3]>=128)||(fr.emit&&fr.emit[i+3]>=128)){ x0=Math.min(x0,x); y0=Math.min(y0,y); x1=Math.max(x1,x); y1=Math.max(y1,y); } }
  return x1<0 ? null : {x0,y0,bw:x1-x0+1,bh:y1-y0+1}; };
function buildActor(doc, opt){
  const box=visBox(doc.w,doc.h,doc.frames);
  if(!box) throw new Error('보이는 픽셀이 없어요. 배경이 투명한지 확인해 주세요');
  if(box.bw>128||box.bh>128) throw new Error(`그림 크기가 ${box.bw}×${box.bh}이에요. 128×128 이하로 올려 주세요`);
  const items=doc.frames.map(fr=>({src:fr,...box})), an=analyze(doc,items,opt);
  const sprites=items.map((it,i)=>{ const r=itemSprite(doc,it,an.pix[i],an,opt); r.s.px=Math.floor(box.bw/2); r.s.py=box.bh-1;
    const light=r.glow?{dx:r.glow.x-r.s.px, dy:r.glow.y-r.s.py, n:r.glow.n, c:r.glow.c}:null; return { s:r.s, dur:it.src.dur, light }; });
  return { sprites, ramps:an.ramps, bw:box.bw, bh:box.bh, groups:an.groups, emissive:an.emissive };
}
// --- 아틀라스 원화 영역에 싣기 ---
function packRegion(region, entries){
  const A=new Uint8Array(region.w*region.h*4), N=new Uint8Array(region.w*region.h*4);
  let x=0,y=0,rowH=0,loaded=0;
  for(const [name,s] of entries.slice().sort((p,q)=>q[1].h-p[1].h)){
    if(x+s.w>region.w){ x=0; y+=rowH+1; rowH=0; }
    if(y+s.h>region.h) continue;
    SPR[name]=s; ATL[name]={x:region.x+x, y:region.y+y};
    for(let yy=0;yy<s.h;yy++) for(let xx=0;xx<s.w;xx++){ const i=yy*s.w+xx, j=((y+yy)*region.w+(x+xx))*4; if(!s.mat[i]) continue;
      A[j]=s.mat[i]; A[j+1]=Math.round(Math.min(1,s.tone[i])*255); A[j+2]=Math.round(s.emit[i]*255); A[j+3]=255;
      N[j]=Math.round((s.nx[i]*.5+.5)*255); N[j+1]=Math.round((s.ny[i]*.5+.5)*255); N[j+2]=Math.round((s.mask||1)*255); N[j+3]=Math.round((s.rel?s.rel[i]:0)*255); }
    x+=s.w+1; rowH=Math.max(rowH,s.h); loaded++;
  }
  for(const [t,data] of [[ATL._a,A],[ATL._n,N]]){ gl.bindTexture(gl.TEXTURE_2D,t); gl.texSubImage2D(gl.TEXTURE_2D,0,region.x,region.y,region.w,region.h,gl.RGBA,gl.UNSIGNED_BYTE,data); }
  return { loaded, total:entries.length };
}

// --- 파츠 리그: Aseprite 그룹(파츠) + 관절 점 → 리그 치수 자동 계산 ---
const PART_ORDER=['torso','head','armF','armB','legF','legB','wpn','off','cape'];
const PART_LABEL={torso:'몸통',head:'머리',armF:'앞팔',armB:'뒷팔',legF:'앞다리',legB:'뒷다리',wpn:'무기',off:'보조손',cape:'망토'};
function mirrorDoc(doc){
  const w=doc.w, h=doc.h, mir=(arr,isN)=>{ if(!arr) return arr; const o=new Uint8ClampedArray(arr.length);
    for(let y=0;y<h;y++) for(let x=0;x<w;x++){ const i=(y*w+x)*4, j=(y*w+(w-1-x))*4; o[j]=isN?255-arr[i]:arr[i]; o[j+1]=arr[i+1]; o[j+2]=arr[i+2]; o[j+3]=arr[i+3]; } return o; };
  const parts={}; for(const [k,p] of Object.entries(doc.parts)) parts[k]={color:mir(p.color),normal:mir(p.normal,true),emit:mir(p.emit),height:mir(p.height),mat:mir(p.mat),pivot:mir(p.pivot)};
  return {...doc, parts};
}
// 관절 레이어: 빨간 점 = 관절(회전 중심), 초록 점 = 무릎(다리만), 그 밖의 색 점 = 끝점(손·발바닥·칼끝)
function markers(pv,w,h){ if(!pv) return {}; const j=[0,0,0], e=[0,0,0], k=[0,0,0];
  for(let y=0;y<h;y++) for(let x=0;x<w;x++){ const i=(y*w+x)*4; if(pv[i+3]<128) continue;
    const r=pv[i], g=pv[i+1], b=pv[i+2];
    const t=(r>g+40 && r>b+40) ? j : (g>r+40 && g>b+40) ? k : e; t[0]+=x; t[1]+=y; t[2]++; }
  const avg=a=>a[2]?[a[0]/a[2],a[1]/a[2]]:null;
  return { joint:avg(j), end:avg(e), knee:avg(k) }; }
// 다리 한 장을 무릎 기준으로 허벅지 · 정강이 둘로 자른다 (엉덩이→발바닥 축에 투영, 무릎 줄은 양쪽에 겹쳐 둠)
function splitLeg(o){
  const J=o.joint, E=o.end, K=o.knee || [(J[0]+E[0])/2,(J[1]+E[1])/2], it=o.it;
  const ax=[E[0]-J[0],E[1]-J[1]], AL=Math.hypot(ax[0],ax[1])||1, u=[ax[0]/AL,ax[1]/AL], tk=(K[0]-J[0])*u[0]+(K[1]-J[1])*u[1];
  const mk=()=>{ const s=newSprite(it.bw,it.bh); s.mask=1; return s; }, th=mk(), sh=mk();
  for(let y=0;y<it.bh;y++) for(let x=0;x<it.bw;x++){ const i=y*it.bw+x; if(!o.s.mat[i]) continue;
    const t=(x+it.x0-J[0])*u[0]+(y+it.y0-J[1])*u[1];
    for(const [dst,ok] of [[th,t<=tk+.5],[sh,t>=tk-.5]]) if(ok){ dst.mat[i]=o.s.mat[i]; dst.tone[i]=o.s.tone[i]; dst.emit[i]=o.s.emit[i]; dst.nx[i]=o.s.nx[i]; dst.ny[i]=o.s.ny[i]; } }
  return { thigh:{ s:th, joint:J, end:K }, shin:{ s:sh, joint:K, end:E }, guessed:!o.knee };
}
const ang16=(a,b)=>Math.atan2(b[0]-a[0], b[1]-a[1])*8/Math.PI;
function buildParts(doc, opt){
  const D=opt.faceLeft ? mirrorDoc(doc) : doc, P={...D.parts}, auto={};
  if(!P.armF && P.arm) P.armF=P.arm; if(!P.armB && P.armF){ P.armB=P.armF; auto.armB=true; }
  if(!P.legF && P.leg) P.legF=P.leg; if(!P.legB && P.legF){ P.legB=P.legF; auto.legB=true; }
  for(const need of ['torso','head']) if(!P[need]) throw new Error(`${PART_LABEL[need]}(${need}) 파츠가 없어요. 그룹이나 레이어 이름을 확인해 주세요`);
  const items=[];
  for(const k of PART_ORDER){ if(!P[k]) continue; const box=visBox(D.w,D.h,[P[k]]); if(!box) continue;
    if(box.bw>64||box.bh>64) throw new Error(`${PART_LABEL[k]} 파츠가 ${box.bw}×${box.bh}이에요. 파츠 하나는 64×64 이하로 그려 주세요`);
    items.push({key:k, src:P[k], ...box}); }
  const an=analyze(D,items,opt), out={}, guessed=[];
  items.forEach((it,i)=>{ const r=itemSprite(D,it,an.pix[i],an,opt), mk=markers(it.src.pivot,D.w,D.h);
    out[it.key]={ it, s:r.s, glow:r.glow, hasN:r.hasN, joint:mk.joint, end:mk.end, knee:mk.knee }; if(!mk.joint) guessed.push(it.key); });
  const pts=o=>{ const a=[], it=o.it; for(let y=0;y<it.bh;y++) for(let x=0;x<it.bw;x++) if(o.s.mat[y*it.bw+x]) a.push([x+it.x0,y+it.y0]); return a; };
  const near=(o,pt,far)=>{ let best=null, bd=far?-1:1e9; for(const q of pts(o)){ const d=Math.hypot(q[0]-pt[0],q[1]-pt[1]); if(far?d>bd:d<bd){ bd=d; best=q; } } return best; };
  const topC=o=>[o.it.x0+(o.it.bw-1)/2, o.it.y0], botC=o=>[o.it.x0+(o.it.bw-1)/2, o.it.y0+o.it.bh-1];
  // 관절을 표시하지 않은 파츠는 모양으로 추정
  for(const k of ['torso','head']) if(!out[k].joint) out[k].joint=botC(out[k]);
  for(const k of ['armF','armB','legF','legB']) if(out[k]){ if(!out[k].joint) out[k].joint=topC(out[k]); if(!out[k].end) out[k].end=[out[k].joint[0], out[k].it.y0+out[k].it.bh-1]; }
  const hF=out.armF&&out.armF.end, hB=out.armB&&out.armB.end;
  if(out.wpn){ if(!out.wpn.joint) out.wpn.joint=hF?near(out.wpn,hF):topC(out.wpn); if(!out.wpn.end) out.wpn.end=near(out.wpn,out.wpn.joint,true); }
  if(out.off && !out.off.joint) out.off.joint=hB?near(out.off,hB):topC(out.off);
  if(out.cape && !out.cape.joint) out.cape.joint=near(out.cape,out.head.joint);
  // 리그 치수: 골반(몸통 관절) 기준 상대 좌표. 발바닥 = 다리(없으면 몸통) 맨 아래 픽셀
  const T=out.torso.joint, RN=Math.round, rel=p=>[RN(p[0]-T[0]),RN(p[1]-T[1])], len=(a,b)=>Math.max(2,RN(Math.hypot(b[0]-a[0],b[1]-a[1])));
  const bottom=Math.max(...['legF','legB','torso'].filter(k=>out[k]).map(k=>out[k].it.y0+out[k].it.bh-1));
  const R={ hip:RN(T[1]-bottom), head:rel(out.head.joint),
    shF:out.armF?rel(out.armF.joint):[3,-8], shB:out.armB?rel(out.armB.joint):[-2,-8],
    legF:out.legF?rel(out.legF.joint):[2,0], legB:out.legB?rel(out.legB.joint):[-2,0],
    armLenF:out.armF?len(out.armF.joint,out.armF.end):8, armLenB:out.armB?len(out.armB.joint,out.armB.end):8,
    thigh:5, shin:7, scarf:out.cape?rel(out.cape.joint):[0,0],
    glowLen:out.wpn?RN(len(out.wpn.joint,out.wpn.end)*.85):10, a0:{} };
  if(auto.armB) R.shB=[R.shF[0]-5, R.shF[1]];
  if(auto.legB) R.legB=[R.legF[0]-5, R.legF[1]];
  for(const k of ['armF','armB','wpn']) if(out[k]) R.a0[k]=Math.round(ang16(out[k].joint,out[k].end)*2)/2;
  // 다리는 무릎에서 둘로 나눠 허벅지 · 정강이로 굽는다
  let kneeGuess=false;
  for(const side of ['F','B']){ const o=out['leg'+side]; if(!o) continue; const sp=splitLeg(o); kneeGuess=kneeGuess||sp.guessed;
    out['thigh'+side]={ it:o.it, s:sp.thigh.s, joint:sp.thigh.joint, end:sp.thigh.end, hasN:o.hasN };
    out['shin'+side]={ it:o.it, s:sp.shin.s, joint:sp.shin.joint, end:sp.shin.end, hasN:o.hasN };
    if(auto['leg'+side]){ auto['thigh'+side]=true; auto['shin'+side]=true; }
    R.a0['thigh'+side]=Math.round(ang16(sp.thigh.joint,sp.thigh.end)*2)/2; R.a0['shin'+side]=Math.round(ang16(sp.shin.joint,sp.shin.end)*2)/2;
    if(side==='F'){ R.thigh=len(sp.thigh.joint,sp.thigh.end); R.shin=len(sp.shin.joint,sp.shin.end); }
    delete out['leg'+side]; }
  // 굽기: 팔·다리·무기·머리·몸통·망토는 32방향, 보조손은 그대로
  const spr={}, partLights=[];
  for(const [k,o] of Object.entries(out)){
    let s=o.s;
    if(auto[k]){ s={...s, tone:Float32Array.from(s.tone,(t,i)=>s.emit[i]>0?t:Math.max(.05,t-1/7.2))}; } // 자동 뒷팔·뒷다리는 한 단 어둡게
    s.px=RN(o.joint[0]-o.it.x0); s.py=RN(o.joint[1]-o.it.y0);
    if(k==='off') spr.U_off=s; else bakeRot(s,3,{outline:false,keepN:o.hasN}).forEach((r,a)=>spr['U_'+k+'@'+a]=r);
    if(o.glow && k!=='cape' && !auto[k]) partLights.push({ part:k, off:[o.glow.x+o.it.x0-o.joint[0], o.glow.y+o.it.y0-o.joint[1]], n:o.glow.n, c:o.glow.c });
  }
  const reach=Math.min(40, R.armLenF+(out.wpn?len(out.wpn.joint,out.wpn.end):6));
  let wm=M.EYE; if(out.wpn){ const cnt=new Map(); out.wpn.s.mat.forEach((m,i)=>{ if(m&&!out.wpn.s.emit[i]) cnt.set(m,(cnt.get(m)||0)+1); }); let bn=0; for(const [m,c] of cnt) if(c>bn){ bn=c; wm=m; } }
  spr.smearU_a=genSmear(reach,7,105,212,wm); spr.smearU_b=genSmear(reach,4,62,132,wm);
  const def={ name:doc.name||'원화', x:KNIGHT.x, y:KNIGHT.y, flip:false, rig:R, smear:'smearU_', scarfRot:true, eye:null, glow:false, partLights,
    p:{ head:'U_head', torso:'U_torso', armF:'U_armF', armB:'U_armB', thighF:'U_thighF', shinF:'U_shinF', thighB:'U_thighB', shinB:'U_shinB', wpn:'U_wpn', off:out.off?'U_off':'none', scarf:out.cape?'U_cape':null } };
  const found=Object.keys(out).map(k=>k.replace(/^(thigh|shin)/,'leg')); 
  return { def, spr, ramps:an.ramps, groups:an.groups, emissive:an.emissive, found, auto, guessed, R, kneeGuess };
}

// --- 무대에 세우기 · 재생 ---
let doc=null, actor=null;
const opt={ colorMode:'keep', flipG:false, flip:false, faceLeft:false };
function resetChar(c){ const p0=c.d&&c.d.mma?'m_idle0':'idle0'; c.anim='idle'; c.si=0; c.pose=p0; c.prev=p0; c.hold=6; c.k=0; c.blink=false; c.flash=0; }
function applyDoc(){
  if(doc.mode==='parts'){
    const r=buildParts(doc,opt);
    setUserPalette(r.ramps);
    const res=packRegion(UREG_P, Object.entries(r.spr));
    if(res.loaded<res.total) throw new Error('파츠가 커서 아틀라스에 다 싣지 못했어요. 파츠 크기를 줄여 주세요');
    actor=null; packRegion(UREG_F, []);
    CHARS[0].d=r.def; resetChar(CHARS[0]);
    document.getElementById('whoK').textContent='원화';
    renderPanel(r, 0);
    return;
  }
  if(!builtinK(CHARS[0].d)){ CHARS[0].d=baseKnight(); resetChar(CHARS[0]); document.getElementById('whoK').textContent='기사'; }
  const r=buildActor(doc,opt);
  setUserPalette(r.ramps);
  const res=packRegion(UREG_F, r.sprites.map((f,i)=>['u'+i, f.s])), loaded=Math.min(res.loaded, r.sprites.length);
  const old=actor;
  actor={ frames:r.sprites.slice(0,loaded).map((f,i)=>({ name:'u'+i, dur:f.dur, light:f.light })), tags:doc.tags, tag: old ? old.tag : (doc.tags.length?0:-1),
          i:0, clock:0, dirStep:1 };
  setTag(actor.tag);
  renderPanel(r, loaded);
}
function safeApply(){ try{ applyDoc(); }catch(e){ impMsg.textContent=e.message||'다시 읽지 못했어요'; console.warn(e); } }
function tagRange(){ const t=actor.tags[actor.tag]; return t ? [Math.min(t.from,actor.frames.length-1), Math.min(t.to,actor.frames.length-1), t.dir] : [0, actor.frames.length-1, 0]; }
function setTag(ti){ actor.tag = ti>=0 && ti<actor.tags.length ? ti : -1; const [a,b,dir]=tagRange(); actor.i = (dir===1||dir===3) ? b : a; actor.dirStep = (dir===1||dir===3) ? -1 : 1; actor.clock=0; }
function advanceActor(ms){
  if(!actor||!actor.frames.length) return; actor.clock+=ms; const [a,b,dir]=tagRange(); let g=0;
  while(actor.clock>=actor.frames[actor.i].dur && g++<64){
    actor.clock-=actor.frames[actor.i].dur;
    if(a===b) continue;
    if(dir===2||dir===3){ if(actor.i+actor.dirStep>b||actor.i+actor.dirStep<a) actor.dirStep*=-1; actor.i+=actor.dirStep; }
    else if(dir===1){ actor.i = actor.i-1<a ? b : actor.i-1; }
    else actor.i = actor.i+1>b ? a : actor.i+1;
  }
}
function actorDraw(dyn){
  if(!actor||!actor.frames.length) return;
  const f=actor.frames[actor.i], fl=opt.flip?-1:1;
  const UX=sceneUserX(), GY=sceneGround();
  placeAt(f.name, UX, GY, opt.flip, 0);
  if(f.light){ const L=f.light; dyn.push({ x:UX+fl*Math.round(L.dx)+.5, y:GY+Math.round(L.dy)+.5, z:8, r:Math.min(70,18+4*Math.sqrt(L.n)), c:L.c, i:.95 }); }
}

// --- 패널 ---
const impPanel=document.getElementById('impPanel');
const ROLE_LABEL={color:'색',normal:'노멀',emit:'발광',mat:'재질',height:'높이'};
function renderPanel(r, loaded){
  impPanel.hidden=false; bClear.hidden=false;
  const parts=doc.mode==='parts';
  document.getElementById('impName').textContent=doc.name||'불러온 원화';
  document.getElementById('impMeta').textContent = parts
    ? `파츠 리그 · 골반 높이 ${-r.R.hip} · 팔 ${r.R.armLenF} · 허벅지 ${r.R.thigh} · 정강이 ${r.R.shin} · 무기 ${r.R.glowLen}px${r.kneeGuess?' (무릎은 다리 가운데로 추정)':''} → 기사 자리에 섰어요`
    : `${r.bw}×${r.bh}px · 프레임 ${loaded}${loaded<doc.frames.length?`/${doc.frames.length}`:''}${doc.scale>1?` · ${doc.scale}배 확대본을 1배로 읽음`:''}`;
  document.getElementById('impRoles').innerHTML = (parts
    ? PART_ORDER.map(k=>{ const has=r.found.includes(k), au=r.auto[k], gs=r.guessed.includes(k);
        return `<span class="role${has?' on':''}">${PART_LABEL[k]}${!has?' 없음':au?' (자동 복사)':gs?' · 관절 추정':''}</span>`; }).join('')
    : Object.entries(ROLE_LABEL).map(([k,l])=>`<span class="role${doc.roles[k]?' on':''}">${l}${doc.roles[k]?'':' 없음'}</span>`).join(''))
    + `<span class="role-note">노멀: ${doc.roles.normal?'노멀 레이어':doc.roles.height?'높이 레이어에서 계산':'모양에서 자동 생성'}</span>`;
  document.querySelectorAll('.frames-only').forEach(el=>el.hidden=parts);
  document.querySelectorAll('.parts-only').forEach(el=>el.hidden=!parts);
  const rb=document.getElementById('impRamps');
  if(opt.colorMode==='keep'){
    rb.innerHTML=`<div class="ramp-head">${doc.roles.mat?'재질 레이어로':'색을 자동으로'} 나눈 램프 ${r.groups}개${r.emissive?` + 발광 ${r.emissive}개`:''} (점이 원본 색)</div>`
      + r.ramps.map(R=>`<div class="ramp">${R.rgb.map((c,s)=>`<i class="sw${!R.flat&&R.orig.includes(s)?' o':''}" style="background:rgb(${c})"></i>`).join('')}${R.flat?'<em>발광</em>':''}</div>`).join('');
  } else rb.innerHTML='<div class="ramp-head">엔진 재질로 맞추는 중이에요. 색은 엔진 팔레트에서 가장 가까운 단으로 바뀌어요.</div>';
  const sel=document.getElementById('impTag');
  sel.innerHTML='<option value="-1">전체 프레임</option>'+doc.tags.map((t,i)=>`<option value="${i}"${i===actor.tag?' selected':''}>${t.name} (${t.from}–${t.to})</option>`).join('');
  document.getElementById('bFlipG').disabled=!doc.roles.normal;
  impMsg.textContent='';
}
async function loadFiles(files){
  impMsg.textContent='읽는 중이에요…';
  try{
    const ase=files.find(f=>/\.(aseprite|ase)$/i.test(f.name));
    doc = ase ? await parseAse(await ase.arrayBuffer(), ase.name.replace(/\.[^.]+$/,'')) : await parsePNGs(files);
    actor=null; applyDoc();
  }catch(e){ impMsg.textContent=e.message||'이 파일은 읽을 수 없어요'; console.warn(e); }
}
fileIn.addEventListener('change',()=>{ const fs=[...fileIn.files]; fileIn.value=''; if(fs.length) loadFiles(fs); });
async function loadSample(b64, name){
  try{ const bin=Uint8Array.from(atob(b64),c=>c.charCodeAt(0)); doc=await parseAse(bin.buffer,name); actor=null; applyDoc(); }
  catch(e){ impMsg.textContent=e.message||'샘플을 읽지 못했어요'; console.warn(e); } }
document.getElementById('bSample').addEventListener('click',()=>loadSample(SAMPLE_ASE,'샘플: 랜턴 든 여행자'));
document.getElementById('bSampleP').addEventListener('click',()=>loadSample(SAMPLE_PARTS,'샘플 파츠: 랜턴 검사'));
bClear.addEventListener('click',()=>{ actor=null; doc=null; setUserPalette([]); packRegion(UREG_F,[]); if(!builtinK(CHARS[0].d)){ CHARS[0].d=baseKnight(); resetChar(CHARS[0]); document.getElementById('whoK').textContent='기사'; }
  impPanel.hidden=true; bClear.hidden=true; impMsg.textContent='.aseprite 또는 PNG'; });
document.getElementById('impTag').addEventListener('change',e=>{ if(actor) setTag(+e.target.value); });
document.querySelectorAll('#impColor button').forEach(b=>b.addEventListener('click',()=>{
  opt.colorMode=b.dataset.m; document.querySelectorAll('#impColor button').forEach(x=>x.setAttribute('aria-pressed',x===b?'true':'false')); if(doc) safeApply(); }));
const bFlipG=document.getElementById('bFlipG'), bFlipX=document.getElementById('bFlipX');
bFlipG.addEventListener('click',()=>{ opt.flipG=!opt.flipG; bFlipG.setAttribute('aria-pressed',opt.flipG); if(doc) safeApply(); });
const bFaceL=document.getElementById('bFaceL');
bFaceL.addEventListener('click',()=>{ opt.faceLeft=!opt.faceLeft; bFaceL.setAttribute('aria-pressed',opt.faceLeft); if(doc) safeApply(); });
bFlipX.addEventListener('click',()=>{ opt.flip=!opt.flip; bFlipX.setAttribute('aria-pressed',opt.flip); });

