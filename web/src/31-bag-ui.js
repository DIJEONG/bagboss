// --- 말풍선 · 안내 (픽셀 상자, 한국어) ---
const sayEl=document.createElement('div'); sayEl.className='sb-say'; sayEl.hidden=true; document.getElementById('stage').appendChild(sayEl);
let sayT=0; function say(title,body,t){ sayEl.innerHTML=`<b>${title}</b>${body?`<span>${body}</span>`:''}`; sayEl.style.top = GS.bonus ? '19%' : ''; sayEl.hidden=false; sayT=t; }   // 보너스 중엔 위쪽 타이머 · 차 체력을 가리지 않게 아래로
function bark(a,txt){ GS.barks=(GS.barks||[]).filter(b=>b.t>0); GS.barks.push({a,txt,t:2.2}); comicSay(a,txt,'shout',true); }
// --- 가방 UI ---
const bagEl=document.getElementById('bag'), infoEl=document.getElementById('itemInfo'), gOverlay=document.getElementById('gOverlay');
// 아이템 아이콘: UI 전용 팔레트로 그린 16×16 (외곽선 · 하이라이트 · 3단 음영)
const ICON_PAL={"K": "#0e0d14", "w": "#f4eee2", "W": "#c9c2b3", "g": "#8d877b", "G": "#4d4943", "h": "#ffffff", "s": "#f0c09a", "S": "#c48458", "z": "#83502f", "r": "#e8524a", "R": "#9a2430", "y": "#f6cb4c", "Y": "#c08a24", "o": "#f08a3a", "b": "#62a8ee", "B": "#2c5aa0", "n": "#3c3f4e", "N": "#22242e", "m": "#5b5f72", "e": "#6ad08a", "E": "#2f8a52", "p": "#d77ad8", "P": "#8e3c9a", "c": "#d0a46c", "C": "#8a5a32", "x": "#5a3820", "t": "#ffe7a8", "l": "#9fd6ff"};
const ICON_ART={
  duck:["................", ".W.W....KKKKK...", "W.W.W..KyyyyyKK.", ".W.W...KyttyyoK.", "........KKKKKK..", "................", ".....KK.KK......", "....KssKssK.....", "....KsNNNsK.....", "...KnKNNNKnK....", "...KnnKKKnnnK...", "..KnmnnnnnnnNK..", "..KnmnnnnnnnNK..", "..KGGKnnnnKGGK..", "..KKKK.KK.KKKK..", "................"],
  punch:["................", "....KKKKKKKK....", "...KswswswssK...", "..KswsswsswsSK..", "..KsSssSssSsSK..", "..KssssssssSSK..", "..KSsssssssSSK..", "..KSKKKKKKKSSK..", "..KSssssssSSSK..", "...KSSSSSSSSK...", "...KzSSSSSSzK...", "....KwwWwwWK....", "....KWwwWwwK....", "....KwWwwWwK....", "....KKKKKKKK....", "................"],
  paper:["................", "...........KKK..", "..........KwwwK.", ".........KwgwgK.", "........KwwgwK..", ".......KwgwgK...", "......KwwgwK....", ".....KwgwgK.....", "....KwwgwK......", "...KwgwgK.......", "..KWwgwK........", ".KWWwwK.........", ".KWWWK..........", "..KKK...........", "................", "................"],
  umb:[".......KK.......", "......KnnK......", "......KnmK......", ".....KnnmNK.....", ".....KnnmNK.....", "....KnnnmNNK....", "....KnnnmNNK....", "....KnnnmNNK....", ".....KnnmNK.....", "......KYyK......", "......KgWK......", "......KgWK......", "......KgWK.KK...", "......KgWKKgK...", ".......KggggK...", "........KKKK...."],
  case:["................", "................", "......KKKKK.....", ".....KK...KK....", ".....K.....K....", "..KKKKKKKKKKKK..", "..KcccccccccCK..", "..KcCcccccccCK..", "..KccccKyKccCK..", "..KKKKKKYKKKKK..", "..KcccccccccCK..", "..KccccccccCCK..", "..KCCCCCCCCCCK..", "..KxxxxxxxxxxK..", "...KKKKKKKKKK...", "................"],
  kick:["................", "................", "................", "................", "W.....KKKK......", ".W...KnnnnK.....", "W.W..KnmnnK.....", ".W...KnmnnKKKK..", "W.W.KnnnnwnwnnKK", "....Knnnnnnnnnnn", "....Knhnnnnnnnnn", "....KGGGKKGGGGGG", ".....KKK.yKKKKKK", "..........y.....", "................", "................"],
  round:["......WWWWW.....", "....WW.....W....", "...W.........W..", "..W...........W.", "..W............W", "..W.............", ".....KKKK.......", "....KnnnnK......", "....KnmnnK......", "....KnmnnKKKK...", "...KnnnnwnwnnKK.", "...KnnnnnnnnnnnK", "...KnhnnnnnnnnnN", "...KGGGKKGGGGGGG", "....KKK..KKKKKKK", "................"],
  upper:["................", "......KKKKK.....", ".....KsssssK....", "....KswswswsK...", "....KsSsSsSsK...", "....KsssssSSK...", "....KSsKKKKSK...", "....KSssssSSK...", ".....KSSSSSK....", ".....KwwWwwK....", "..W..KnmnnnK..W.", "..W..KnmnnnK..W.", ".W...KnmnnnK...W", ".W...KnnnnnK...W", "W....KnnnnnK....", ".....KKKKKKK...."],
  elbow:["................", "...y............", "..yty...........", "...y..KKKKKK....", ".....KnnnnnmK...", "....KnnnnnnmK...", "...KnnnnnnnmK...", "...KnmmmnKKKK...", "...KnnnnK.......", "....KnnnK.......", "....KnnnK.......", "....KwwwK.......", "....KsssK.......", "....KsSSK.......", ".....KKK........", "................"],
  knee:["................", "..y.............", ".yty.....KKKK...", "..y.....KnnnnK..", ".......KnnnnmK..", "......KnnnnmK...", ".....KnnnnmK....", "....KnnnnnK.....", "....KnmnnnK.....", "....KnnmmnnK....", ".....KnnnnnnK...", "......KnnnnnK...", ".......KnnnnnK..", "........KGGGGK..", ".........KKKK...", "................"],
  sweep:["................", "................", "................", "................", ".....KKKK.......", "....KnnnnK......", "....KnmnnK......", "....KnmnnKKKK...", "...KnnnnwnwnnKK.", "...KnnnnnnnnnnnK", "...KnhnnnnnnnnnN", "...KGGGKKGGGGGGG", "....KKK..KKKKKKK", "WW.WWW.WWWWWW...", ".WWWWWWWWWWWWWW.", "................"],
  charge:["................", "................", "........KK......", "........KrK.....", "........KrrK....", "WWWW.KKKKrrrK...", ".....KrrrrrrrK..", "WWWWWKrrhrrrrrK.", ".....KrrrrrrrRK.", "WWWW.KKKKrrrRK..", "........KrRK....", "........KRK.....", "........KK......", "................", "................", "................"],
  throw:["................", "......WWWWW.....", "....WW.....W....", "...W........W...", "..W.....KK...W..", "..W....KssK..W..", "..W....KssK.WWW.", ".......KnnK..W..", "......KnmnnK....", ".....KnnmnnnK...", ".....KsKnnKsK...", "......KnnnnK....", "......KnKKnK....", "......KnK.KnK...", ".....KGGK.KGGK..", ".....KKKK.KKKK.."],
  stomp:["................", ".......KKKK.....", "......KnnnnK....", "......KnmnnK....", "......KnmnnKKKK.", ".....KnnnnwnwnnK", ".....Knnnnnnnnnn", ".....Knhnnnnnnnn", ".....KGGGKKGGGGG", "......KKK..KKKKK", ".W..W.....W...W.", "..W..W...W..W...", "KKKKKKKKKKKKKKKK", "GGgGGGGgGGGGGgGG", "GgGGGgGGGGgGGGGG", "................"],
  charm:["......KKKK......", ".....KyYYyK.....", "......KyyK......", ".....KKKKKK.....", "....KrrrrrrK....", "...KrrrrrrrRK...", "...KrryyyyrRK...", "...KrrytYyrRK...", "...KrryYYyrRK...", "...KrrrrrrrRK...", "...KrrrrrrrRK...", "...KrrrrrrrRK...", "...KRrrrrrRRK...", "....KKKKKKKK....", "................", "................"],
  coffee:["................", "....KKKKKKKK....", "...KWwWWWWWgK...", "...KgGGGGGGGK...", "...KrrrrrrrRK...", "...KrhrrrrrRK...", "...KwwwwwwwRK...", "...KwCxCwwwRK...", "...KwCCxwwwRK...", "...KwwwwwwwRK...", "...KrhrrrrrRK...", "...KrrrrrrrRK...", "...KgGGGGGGGK...", "...KWwWWWWWgK...", "....KKKKKKKK....", "................"],
  coat:["................", "....KKK..KKK....", "...KnnnKKnnnK...", "..KnnwnnnnwnnK..", "..KnnnwwwwnnnK..", "..KnnnnwrwnnnK..", ".KnnnnnwrwnnnnK.", ".KnmnnnwrwnnnNK.", ".KnmnnnnrnnnnNK.", ".KnmnnnnhnnnnNK.", ".KnmnnnnnnnnnNK.", ".KnmnnnnhnnnnNK.", ".KnnnnnnnnnnnNK.", ".KNNNNNNNNNNNNK.", "..KKKKKKKKKKKK..", "................"],
  shoes:["................", "................", "................", ".......KKKK.....", "......KwwwwK....", ".....KwbwbwK....", "....KwwbwbwWK...", "...KwwwwwwwwWK..", "..KwbbbwwwwwwWK.", "..KwwwwwwwwwwWK.", "..KhwwwwwwwwwWK.", "..KgggggggggggK.", "..KbbbbbbbbbbbK.", "...KKKKKKKKKKK..", "................", "................"],
  earph:["................", "...KKK....KKK...", "..KwwWK..KwwWK..", "..KwhWK..KwhWK..", "..KWWgK..KWWgK..", "...KWK....KWK...", "...KWK....KWK...", "....KW....WK....", ".....W....W.....", "......W..W......", ".......WW.......", ".......KK.......", "......KgGK......", ".......WW.......", "........W.......", "........W......."],
  bandage:["................", "......KKKK......", ".....KcccCK.....", ".....KcwcCK.....", ".....KccccK.....", ".KKKKKcccCKKKKK.", "KcccccWwWcccccCK", "KcwccWwWwWccwcCK", "KcccccWwWcccccCK", ".KKKKKcccCKKKKK.", ".....KccccK.....", ".....KcwcCK.....", ".....KcccCK.....", "......KKKK......", "................", "................"],
  knuckle:["................", "................", "..KKKKKKKKKKKK..", ".KyYKyYKyYKyYK..", ".KytKytKytKytYK.", ".KyYKyYKyYKyYYK.", ".KyyyyyyyyyyyYK.", "..KyyyyyyyyyYK..", "...KYyyyyyyYK...", "....KYYYYYYK....", ".....KKKKKK.....", "................", "................", "................", "................", "................"],
  gum:["................", "......KKKK......", "....KKppppKK....", "...KpphppppPK...", "..KpphpppppPPK..", "..KpppppppppPK..", "..KpppppppppPK..", "..KPpppppppPPK..", "...KPPpppPPPK...", "....KKPPPPKK....", "......KKKK......", "................", ".....KwwwwwK....", ".....KwpppwK....", ".....KwwwwwK....", ".....KKKKKKK...."],
};
// 모양에 맞춘 아이템 그림 v2: 칸당 32px. 동작 기술은 그 동작을 하는 작은 정장 인물, 물건은 세부까지
const ART_PX=32;
const RAMPS=[['N','n','m'],['z','S','s'],['W','w','h'],['G','g','W'],['Y','y','t'],['x','C','c'],['R','r','o'],['B','b','l'],['P','p','p'],['E','e','e']];
const RAMP_OF={}; RAMPS.forEach((r,ri)=>r.forEach((c,ci)=>{ if(!(c in RAMP_OF)) RAMP_OF[c]=[ri,ci]; }));
function artBuf(w,h){ const W=w*ART_PX, H=h*ART_PX, a=new Array(W*H).fill(null), fx=new Array(W*H).fill(false);
  const set=(x,y,c,keep)=>{ x=Math.round(x); y=Math.round(y); if(x>=0&&y>=0&&x<W&&y<H){ a[y*W+x]=c; fx[y*W+x]=!!keep; } };
  const get=(x,y)=>(x<0||y<0||x>=W||y>=H)?null:a[y*W+x];
  const rect=(x,y,ww,hh,c,keep)=>{ for(let j=0;j<hh;j++) for(let i=0;i<ww;i++) set(x+i,y+j,c,keep); };
  const disc=(cx,cy,r,c,keep)=>{ for(let y=Math.floor(-r);y<=r;y++) for(let x=Math.floor(-r);x<=r;x++) if(x*x+y*y<=r*r+.5) set(cx+x,cy+y,c,keep); };
  const line=(x0,y0,x1,y1,c,keep)=>{ const n=Math.ceil(Math.max(Math.abs(x1-x0),Math.abs(y1-y0)))||1; for(let k=0;k<=n;k++) set(x0+(x1-x0)*k/n,y0+(y1-y0)*k/n,c,keep); };
  const cap=(x0,y0,x1,y1,r0,r1,c)=>{ const n=Math.ceil(Math.hypot(x1-x0,y1-y0)*1.5)||1; for(let k=0;k<=n;k++){ const u=k/n; disc(x0+(x1-x0)*u,y0+(y1-y0)*u,r0+(r1-r0)*u,c); } };
  const poly=(pts,c,keep)=>{ const ys=pts.map(p=>p[1]), y0=Math.floor(Math.min(...ys)), y1=Math.ceil(Math.max(...ys));
    for(let y=y0;y<=y1;y++){ const xs=[]; for(let i=0;i<pts.length;i++){ const [ax,ay]=pts[i], [bx,by]=pts[(i+1)%pts.length]; if((ay<=y+.5&&by>y+.5)||(by<=y+.5&&ay>y+.5)) xs.push(ax+(y+.5-ay)*(bx-ax)/(by-ay)); }
      xs.sort((p,q)=>p-q); for(let i=0;i+1<xs.length;i+=2) for(let x=Math.round(xs[i]);x<Math.round(xs[i+1]);x++) set(x,y,c,keep); } };
  return { W,H,a,fx,set,get,rect,disc,line,cap,poly }; }
// 효과: 충격 별 · 속도선 · 휘두른 자국(점선 호) · 먼지
function star(b,cx,cy,r){ for(let k=0;k<8;k++){ const t=k*Math.PI/4, L=k%2?r*.55:r; for(let s=1;s<=L;s++) b.set(cx+Math.cos(t)*s,cy+Math.sin(t)*s,s<L*.5?'t':'y',true); } b.disc(cx,cy,1.5,'t',true); }
function speed(b,x0,y0,x1,y1,n,gap){ for(let k=0;k<n;k++) b.line(x0,y0+k*gap,x1-(k%2)*4,y1+k*gap,'W',true); }
function swoosh(b,cx,cy,r,a0,a1){ for(let a=a0;a<=a1;a+=.09){ if(Math.floor(a*11)%3===2) continue; b.set(cx+Math.cos(a)*r,cy+Math.sin(a)*r,'W',true); b.set(cx+Math.cos(a)*(r-1),cy+Math.sin(a)*(r-1),'W',true); } }
// 정장 인물: 관절(머리 · 목 · 어깨 둘 · 엉덩이 · 팔꿈치/손 · 무릎/발)을 굵은 팔다리로 잇는다. 뒤쪽 팔다리는 어둡게
function figure(b,P){
  const shoe=(kx,ky,fx,fy,dir)=>{ b.cap(kx,ky,fx,fy-1,2.6,2.4,'n'); const d=dir||Math.sign(fx-kx)||1; b.poly([[fx-3*d,fy-3],[fx+6*d,fy-2],[fx+7*d,fy+1],[fx-3*d,fy+2]],'N'); b.line(fx-3*d,fy+2,fx+7*d,fy+2,'G'); b.set(fx+2*d,fy-2,'W',true); };
  const back=(c)=>c==='n'?'N':c;
  // 뒤쪽 다리 · 팔
  b.cap(P.hip[0],P.hip[1],P.knee2[0],P.knee2[1],3.6,3.2,'N'); b.cap(P.knee2[0],P.knee2[1],P.foot2[0],P.foot2[1]-1,3.2,2.6,'N'); shoe(P.knee2[0],P.knee2[1],P.foot2[0],P.foot2[1],P.fd2);
  b.cap(P.sh2[0],P.sh2[1],P.el2[0],P.el2[1],2.8,2.5,'N'); b.cap(P.el2[0],P.el2[1],P.ha2[0],P.ha2[1],2.5,2.2,'N'); b.disc(P.ha2[0],P.ha2[1],2.6,'S');
  // 몸통(어깨 → 엉덩이) · 셔츠 V · 넥타이
  const [s1,s2,h]=[P.sh,P.sh2,P.hip];
  b.poly([[s2[0],s2[1]-1],[s1[0],s1[1]-1],[h[0]+(s1[0]-s2[0])*.35,h[1]+2],[h[0]-(s1[0]-s2[0])*.35,h[1]+2]],'n');
  const nx=P.neck[0], ny=P.neck[1], tx=(h[0]-nx)*.4, ty=(h[1]-ny)*.4; b.poly([[nx-3,ny],[nx+3,ny],[nx+tx,ny+ty]],'w',true); b.line(nx,ny+1,nx+tx*.8,ny+ty*.8,'N',true);
  // 머리: 피부 · 넘긴 머리 · 눈 · 귀
  b.cap(P.neck[0],P.neck[1],P.head[0],P.head[1],2.4,2.4,'S'); b.disc(P.head[0],P.head[1],5.4,'s');
  const fd=P.face||1; b.poly([[P.head[0]-5.6,P.head[1]-1],[P.head[0]-5,P.head[1]-5],[P.head[0]+1,P.head[1]-6.4],[P.head[0]+5.6*fd,P.head[1]-4],[P.head[0]+4*fd,P.head[1]-2.4],[P.head[0]-2*fd,P.head[1]-2]],'N',true);
  b.set(P.head[0]+3*fd,P.head[1]-.5,'K',true); b.set(P.head[0]-1*fd,P.head[1],'S',true); b.line(P.head[0]+2*fd,P.head[1]+3,P.head[0]+3.5*fd,P.head[1]+3,'z',true);
  // 앞쪽 다리 · 팔(밝은 정장) · 손
  b.cap(P.hip[0],P.hip[1],P.knee[0],P.knee[1],3.8,3.3,'n'); b.cap(P.knee[0],P.knee[1],P.foot[0],P.foot[1]-1,3.3,2.7,'n'); shoe(P.knee[0],P.knee[1],P.foot[0],P.foot[1],P.fd);
  b.cap(P.sh[0],P.sh[1],P.el[0],P.el[1],3.0,2.7,'n'); b.cap(P.el[0],P.el[1],P.ha[0],P.ha[1],2.7,2.3,'n');
  const cx=P.el[0]+(P.ha[0]-P.el[0])*.8, cy=P.el[1]+(P.ha[1]-P.el[1])*.8; b.disc(cx,cy,2.2,'w',true); b.disc(P.ha[0],P.ha[1],3.0,'s'); b.set(P.ha[0]-1,P.ha[1]-1,'h',true);
}
// 음영: 왼쪽 위가 비어 있으면 밝게, 오른쪽 아래가 비어 있으면 어둡게(같은 색 계열 안에서)
function shadeArt(b){ const W=b.W, H=b.H, src=b.a.slice();
  for(let y=0;y<H;y++) for(let x=0;x<W;x++){ const c=src[y*W+x]; if(!c||b.fx[y*W+x]||!(c in RAMP_OF)) continue; const [ri,ci]=RAMP_OF[c], R=RAMPS[ri];
    const e=(dx,dy)=>{ const q=(x+dx<0||y+dy<0||x+dx>=W||y+dy>=H)?null:src[(y+dy)*W+x+dx]; return !q || !(q in RAMP_OF) || RAMP_OF[q][0]!==ri; };
    if(e(-1,-1)||e(0,-1)) b.a[y*W+x]=R[Math.min(R.length-1,ci+1)]; else if(e(1,1)||e(0,1)) b.a[y*W+x]=R[Math.max(0,ci-1)]; } }
const ARTS={
  punch(b){ // 세로 2칸: 테이프 감은 주먹(앞모습) · 손목 · 소맷부리 · 충격
    b.poly([[6,10],[26,8],[28,24],[6,26]],'s'); for(const x of [11,16,21]) b.line(x,9,x,17,'S',true); b.line(7,17,27,17,'S',true);
    for(const x of [8,13,18,23]) b.rect(x,9,3,2,'h',true); b.poly([[4,18],[12,17],[13,24],[5,26]],'S'); b.line(5,21,11,20,'z',true);
    for(let y=27;y<41;y++) b.rect(7,y,18,1,(y%3===0)?'W':'w',true); b.line(8,28,24,30,'g',true);
    b.rect(6,41,20,4,'w'); for(let y=45;y<64;y++) b.rect(6,y,20,1,'n'); b.line(10,47,10,63,'m',true);
    star(b,27,5,4); },
  kick(b){ // L: 왼쪽 세로 칸에 선 인물의 앞차기 — 뻗은 다리가 아래 오른쪽 칸으로
    figure(b,{ head:[15,9], neck:[15,15], sh:[19,18], sh2:[10,18], hip:[14,36], el:[22,24], ha:[21,15], el2:[8,26], ha2:[13,19], knee:[30,40], foot:[52,46], fd:1, knee2:[11,49], foot2:[8,61], fd2:-1 });
    speed(b,34,52,44,52,3,4); star(b,59,44,4); },
  knee(b){ // 세로 2칸: 무릎을 차올리는 인물(두 손으로 잡아끌며)
    figure(b,{ head:[13,8], neck:[13,14], sh:[17,17], sh2:[9,17], hip:[13,34], el:[24,22], ha:[25,30], el2:[19,24], ha2:[22,30], knee:[25,34], foot:[19,48], fd:1, knee2:[12,48], foot2:[11,61], fd2:-1 });
    star(b,28,30,4); },
  elbow(b){ // J: 오른쪽 세로 칸의 인물이 왼쪽 위로 팔꿈치를 꽂는다
    figure(b,{ head:[48,9], neck:[48,15], sh:[44,18], sh2:[53,18], hip:[48,38], el:[24,18], ha:[38,25], el2:[57,28], ha2:[52,22], knee:[44,50], foot:[42,61], fd:-1, knee2:[53,50], foot2:[56,61], fd2:1, face:-1 });
    speed(b,30,10,40,10,3,3); star(b,14,16,6); },
  round(b){ // T: 가운데 인물 · 왼쪽으로 가로로 뻗은 돌려차기 다리 · 오른쪽으로 휘두른 팔 · 아래로 디딘 다리
    figure(b,{ head:[52,8], neck:[51,14], sh:[56,17], sh2:[46,17], hip:[49,32], el:[66,14], ha:[76,10], el2:[60,24], ha2:[70,22], knee:[30,26], foot:[9,22], fd:-1, knee2:[50,46], foot2:[50,60], fd2:1 });
    swoosh(b,48,26,22,-2.9,-1.7); for(let k=0;k<3;k++) b.line(80+k*4,4+k*3,88+k*4,20-k*2,'W',true); },
  upper(b){ // 세로 3칸: 아래에서 위로 솟구치는 어퍼컷(주먹이 맨 위 칸)
    figure(b,{ head:[12,34], neck:[13,40], sh:[18,43], sh2:[9,43], hip:[14,66], el:[24,28], ha:[19,10], el2:[6,52], ha2:[11,46], knee:[19,79], foot:[22,93], fd:1, knee2:[10,80], foot2:[7,93], fd2:-1 });
    star(b,19,5,5); for(const [x,y] of [[6,14],[26,18],[4,24]]) b.line(x,y,x,y+8,'W',true); },
  sweep(b){ // 가로 3칸: 낮게 웅크린 인물이 바닥을 쓸며 다리를 뻗는다
    figure(b,{ head:[79,8], neck:[77,13], sh:[80,15], sh2:[71,14], hip:[70,22], el:[86,20], ha:[88,28], el2:[66,20], ha2:[62,27], knee:[50,26], foot:[24,27], fd:-1, knee2:[82,24], foot2:[88,29], fd2:1, face:-1 });
    swoosh(b,40,10,22,1.2,2.4); for(const x of [10,16,22]) b.disc(x,29,1.5,'g',true); },
  charge(b){ // S: 어깨를 앞세워 돌진하는 인물 — 뒤로 끌리는 다리 · 속도선(왼쪽 아래)
    figure(b,{ head:[70,12], neck:[66,17], sh:[76,18], sh2:[62,22], hip:[48,38], el:[84,26], ha:[80,34], el2:[56,30], ha2:[62,36], knee:[58,48], foot:[62,60], fd:1, knee2:[34,48], foot2:[22,58], fd2:-1 });
    speed(b,2,40,20,40,4,5); star(b,88,14,6); },
  throw(b){ // P: 위 두 칸에 가로로 들린 적(갈색 코트) · 아래로 들어 올리는 주인공 · 다리는 맨 아래 칸
    b.cap(6,14,46,14,6,6,'C'); b.disc(54,12,5.4,'s'); b.poly([[50,7],[58,6],[60,10],[52,11]],'x',true); b.cap(4,12,-2,8,3,3,'G'); b.cap(4,17,-2,22,3,3,'G');
    b.cap(30,8,36,2,2.5,2.5,'C'); b.disc(37,2,2.5,'s'); b.cap(22,19,18,26,2.5,2.5,'C');
    figure(b,{ head:[22,40], neck:[22,46], sh:[28,49], sh2:[16,49], hip:[22,70], el:[34,36], ha:[38,22], el2:[12,36], ha2:[12,22], knee:[26,82], foot:[28,94], fd:1, knee2:[16,82], foot2:[10,94], fd2:-1 });
    star(b,58,24,4); },
  stomp(b){ // 가로 2칸: 내려찍는 구두(끈 · 뒤축) · 바지 자락 · 금 간 바닥
    b.rect(10,0,16,9,'n'); b.rect(9,8,18,3,'N'); b.poly([[6,10],[44,9],[56,13],[58,20],[6,21]],'N'); b.poly([[30,10],[46,10],[54,14],[30,15]],'n');
    for(const x of [32,36,40]) b.line(x,11,x+3,13,'w',true); b.rect(6,20,52,4,'G'); b.rect(6,20,12,5,'x'); b.set(44,12,'W',true); b.set(45,12,'W',true);
    b.line(0,30,63,30,'G',true); for(const [x0,x1] of [[14,8],[28,24],[38,46],[52,58]]) b.line(x0,26,x1,31,'K',true);
    for(const [x,y] of [[2,14],[60,8],[61,22]]) b.line(x,y,x+2,y,'W',true); },
  paper(b){ // 가로 2칸: 말아 쥔 신문(헤드라인 · 사진 · 단락 · 고무줄 · 말린 끝)
    b.poly([[4,8],[56,8],[60,12],[60,26],[56,28],[4,28]],'w'); b.rect(4,8,52,3,'h',true);
    b.rect(8,12,22,3,'G',true); b.rect(34,12,12,7,'g',true); b.rect(35,13,4,3,'W',true);
    for(const y of [17,20,23]) for(let x=8;x<32;x+=7) b.rect(x,y,5,1,'g',true); for(const y of [21,24]) for(let x=34;x<52;x+=6) b.rect(x,y,4,1,'g',true);
    b.disc(58,19,7,'W'); b.disc(58,19,4.5,'w'); b.disc(58,19,2,'g',true); b.rect(16,8,2,20,'r',true); b.rect(44,8,2,20,'r',true); },
  umb(b){ // 가로 3칸: 나무 J 손잡이 · 쇠 고리 · 접힌 천(주름 · 살대) · 똑딱이 끈 · 뾰족한 끝
    for(let a=0;a<=Math.PI*1.05;a+=.04){ const x=11-Math.cos(a)*7, y=16+Math.sin(a)*8; b.disc(x,y,2.4,'C'); } b.cap(4,16,4,12,2.4,2.4,'C'); b.cap(11,16,22,16,2.4,2.4,'C'); b.rect(21,13,4,7,'G');
    for(let x=24;x<86;x++){ const u=(x-24)/62, hh=Math.max(1.5,10*(u<.15?u/.15:1-(u-.15)/.85)); b.rect(x,16-hh,1,hh*2,'n'); }
    for(let k=0;k<6;k++){ const x0=30+k*9; b.line(x0,8,x0+12,22,'N',true); } b.rect(44,7,4,18,'Y'); b.disc(46,16,2,'y',true); b.line(86,16,95,16,'G',true); b.set(95,16,'W',true); },
  case(b){ // 2×2: 가죽 서류가방(손잡이 · 덮개 · 바느질 · 놋쇠 걸쇠)
    b.cap(24,14,24,6,2.6,2.6,'x'); b.cap(24,6,40,6,2.6,2.6,'x'); b.cap(40,6,40,14,2.6,2.6,'x');
    b.rect(4,15,56,44,'C'); b.rect(4,15,56,14,'c'); b.line(4,29,59,29,'x',true);
    for(let x=7;x<58;x+=3){ b.set(x,18,'t',true); b.set(x,55,'x',true); } for(let y=18;y<56;y+=3){ b.set(7,y,'t',true); b.set(56,y,'x',true); }
    for(const x of [14,44]){ b.rect(x,26,7,7,'Y',true); b.rect(x+1,27,5,5,'y',true); b.set(x+2,28,'t',true); } b.rect(29,24,6,8,'Y',true); b.rect(30,25,4,6,'y',true); },
  knuckle(b){ // 가로 2칸: 놋쇠 너클(고리 넷 · 손잡이 · 광)
    for(let k=0;k<4;k++){ const cx=10+k*14; b.disc(cx,12,7.5,'y'); b.disc(cx,12,4.2,null); }
    b.poly([[3,18],[61,18],[56,28],[8,28]],'Y'); b.rect(8,20,48,2,'y',true); for(let k=0;k<4;k++) b.line(5+k*14,8,8+k*14,6,'t',true); },
  shoes(b){ // 가로 2칸: 운동화 한 켤레(끈 · 줄무늬 · 밑창 홈)
    for(const ox of [0,32]){ b.poly([[ox+2,10],[ox+12,6],[ox+16,10],[ox+28,14],[ox+30,22],[ox+2,22]],'w'); b.rect(ox+2,22,29,4,'g'); for(let x=ox+3;x<ox+30;x+=3) b.set(x,25,'G',true);
      for(const x of [ox+9,ox+12,ox+15]) b.line(x,9,x+3,12,'B',true); b.line(ox+8,17,ox+26,15,'b',true); b.line(ox+9,19,ox+27,17,'b',true); b.rect(ox+24,16,5,6,'W',true); } },
  bkick(b){ // 앞을 보며(오른쪽) 뒷다리를 왼쪽으로 곧게 찬다 — 어깨 너머로 뒤를 본다
    figure(b,{ head:[80,11], neck:[79,17], sh:[84,20], sh2:[73,20], hip:[73,35], el:[89,27], ha:[93,21], el2:[69,28], ha2:[76,24], knee:[76,49], foot:[80,61], fd:1, knee2:[52,30], foot2:[24,27], fd2:-1, face:-1 });
    speed(b,38,6,52,6,3,4); star(b,10,24,6); },
  bfist(b){ // 오른쪽 인물이 몸을 비틀어 등 뒤(왼쪽)로 주먹 등을 휘두른다
    figure(b,{ head:[46,13], neck:[45,19], sh:[50,22], sh2:[40,21], hip:[44,42], el:[54,30], ha:[58,23], el2:[28,21], ha2:[12,19], knee:[50,53], foot:[54,62], fd:1, knee2:[38,53], foot2:[34,62], fd2:-1, face:-1 });
    b.disc(12,19,3.6,'s'); b.line(10,17,14,16,'S',true); swoosh(b,30,26,20,3.3,4.6); star(b,6,10,5); },
  pin(b){ // 1칸: 금 넥타이핀(붉은 보석 · 집게) — 검은 넥타이 위에
    b.poly([[12,2],[20,2],[22,26],[16,31],[10,26]],'N'); b.line(16,4,16,28,'n',true);
    b.rect(3,13,26,4,'Y'); b.rect(3,13,26,1,'t',true); b.rect(3,17,26,1,'x',true); b.disc(16,15,3.6,'R'); b.disc(15,14,1.4,'o',true); b.set(14,13,'h',true); b.rect(26,11,3,8,'Y'); },
  ring(b){ // 1칸: 인장 반지(금 고리 · 붉은 인장석 · 새긴 무늬)
    for(let a=0;a<Math.PI*2;a+=.05){ b.disc(16+Math.cos(a)*9,20+Math.sin(a)*7,2.4,'y'); } for(let a=0;a<Math.PI*2;a+=.05) b.set(16+Math.cos(a)*9,20+Math.sin(a)*7-1,'t',true);
    b.poly([[8,4],[24,4],[26,14],[6,14]],'Y'); b.poly([[10,6],[22,6],[23,12],[9,12]],'R'); b.line(12,8,20,8,'r',true); b.line(14,10,18,10,'r',true); b.set(11,7,'o',true); },
  duck(b){ // 1칸: 머리를 감싸고 웅크린 인물 · 머리 위로 날아가는 병
    figure(b,{ head:[17,19], neck:[15,23], sh:[19,22], sh2:[10,22], hip:[11,28], el:[23,16], ha:[19,14], el2:[8,15], ha2:[13,13], knee:[20,26], foot:[23,30], fd:1, knee2:[6,26], foot2:[4,30], fd2:-1 });
    b.poly([[8,4],[20,3],[22,6],[20,9],[8,8]],'o'); b.rect(20,4,4,4,'Y'); b.rect(10,4,6,2,'t',true); speed(b,0,4,6,4,2,4); },
  charm(b){ // 1칸: 붉은 부적 주머니(금실 자수 · 매듭 끈)
    b.cap(16,2,16,6,1.6,1.6,'Y'); b.disc(16,7,2.6,'y'); b.cap(11,9,21,9,2,2,'Y');
    b.poly([[8,10],[24,10],[26,14],[26,29],[6,29],[6,14]],'r'); b.rect(9,13,14,13,'R',true); b.rect(10,14,12,11,'r',true);
    for(let y=15;y<24;y+=3) b.line(12,y,20,y,'y',true); b.disc(16,19,3,'y',true); b.disc(16,19,1.5,'t',true); },
  coffee(b){ // 1칸: 캔커피(따개 · 상표 띠 · 원두 그림 · 반사)
    b.poly([[9,4],[23,4],[25,6],[25,28],[23,30],[9,30],[7,28],[7,6]],'r'); b.rect(8,4,16,3,'g'); b.rect(8,27,16,3,'g'); b.rect(14,3,4,2,'W'); b.rect(15,2,2,1,'G');
    b.rect(8,12,16,10,'w',true); b.disc(16,17,3.5,'x',true); b.line(14,16,18,18,'C',true); b.rect(10,9,12,2,'R',true); b.rect(9,6,2,20,'o',true); },
  gum(b){ // 1칸: 부풀린 풍선껌 · 포장지
    b.disc(15,13,11,'p'); b.disc(11,9,3,'h',true); b.disc(9,8,1.4,'h',true); b.cap(5,25,27,25,3,3,'w'); b.rect(6,24,20,2,'p',true); b.rect(12,23,8,4,'P',true); },
  earph(b){ // 1칸: 유선 이어폰(이어팁 · 줄 · 분기점 · 플러그)
    b.disc(9,8,5,'w'); b.disc(9,8,2.5,'W',true); b.disc(23,8,5,'w'); b.disc(23,8,2.5,'W',true); b.cap(11,13,15,20,1,1,'W'); b.cap(21,13,17,20,1,1,'W');
    b.disc(16,21,1.8,'g'); b.cap(16,22,16,28,1,1,'W'); b.rect(15,28,3,4,'g'); },
  metro(b){
    b.rect(3,8,26,16,'Y'); b.rect(3,8,26,1,'t',true); b.rect(3,23,26,1,'y',true); b.rect(3,11,26,3,'N'); b.rect(5,16,13,2,'b'); b.rect(5,19,9,1,'b'); b.disc(24,19,2.5,'b'); b.set(4,9,'h',true); },
  cuff(b){
    for(const [x,y] of [[10,11],[22,21]]){ b.disc(x,y,6,'Y'); b.disc(x,y,3.6,'b'); b.disc(x-1,y-1,1.2,'l',true); b.set(x-3,y-3,'h',true); b.line(x,y+6,x,y+9,'y',true); } },
  watch(b){
    b.rect(2,12,60,8,'C'); b.rect(2,12,60,1,'x',true); b.rect(2,19,60,1,'z',true); for(let x=6;x<60;x+=6) b.set(x,16,'z',true);
    b.disc(32,16,11,'Y'); b.disc(32,16,9,'W'); b.disc(32,16,8,'w',true); b.line(32,16,32,10,'N',true); b.line(32,16,37,17,'N',true);
    for(const [x,y] of [[32,8],[40,16],[24,16],[32,24]]) b.set(x,y,'N',true); b.set(28,11,'h',true); b.rect(43,14,3,4,'Y'); },
  bandage(b){ // 1칸: 십자로 겹친 반창고(패드 · 숨구멍)
    b.poly([[3,12],[29,12],[29,20],[3,20]],'c'); b.poly([[12,3],[20,3],[20,29],[12,29]],'c');
    b.rect(12,12,8,8,'w',true); for(let y=13;y<20;y+=2) for(let x=13;x<20;x+=2) b.set(x,y,'W',true);
    for(const [x,y] of [[6,15],[9,17],[24,15],[26,17],[15,6],[17,9],[15,24],[17,26]]) b.set(x,y,'C',true); },
  coat(b){ // 2×3: 긴 더블 외투(세운 깃 · 라펠 · 단추 두 줄 · 벨트와 버클 · 덮개 주머니 · 소맷부리 · 주름)
    b.poly([[14,6],[50,6],[58,16],[56,92],[8,92],[6,16]],'n');
    b.cap(4,18,2,70,5,4.5,'N'); b.cap(60,18,62,70,5,4.5,'n'); b.rect(0,68,7,5,'W'); b.rect(57,68,7,5,'W'); b.disc(3,76,3,'s'); b.disc(61,76,3,'s');
    b.poly([[20,6],[32,22],[44,6],[40,4],[32,14],[24,4]],'w',true); b.poly([[18,6],[30,30],[26,34],[12,12]],'N'); b.poly([[46,6],[34,30],[38,34],[52,12]],'m');
    b.rect(30,8,4,14,'R',true); for(const y of [36,46,56]) for(const x of [24,40]){ b.disc(x,y,1.8,'Y',true); b.set(x-.5,y-.5,'t',true); }
    b.rect(8,62,48,5,'x'); b.rect(29,61,7,7,'Y',true); b.rect(31,63,3,3,'x',true);
    b.rect(12,72,12,2,'N',true); b.rect(40,72,12,2,'N',true); for(const x of [20,32,44]) b.line(x,68,x-1,91,'N',true); b.line(32,22,32,92,'N',true); },
};
function itemArt(id){ const sh=GITEMS[id].shape||[[0,0]], w=Math.max(...sh.map(p=>p[0]))+1, h=Math.max(...sh.map(p=>p[1]))+1;
  if(!ARTS[id]) return null; const b=artBuf(w,h); ARTS[id](b); shadeArt(b);
  const inShape=(x,y)=>sh.some(([cx,cy])=>Math.floor(x/ART_PX)===cx&&Math.floor(y/ART_PX)===cy);
  for(let y=0;y<b.H;y++) for(let x=0;x<b.W;x++) if(!inShape(x,y)) b.a[y*b.W+x]=null;
  const out=b.a.slice(); for(let y=0;y<b.H;y++) for(let x=0;x<b.W;x++){ if(b.a[y*b.W+x]) continue;
    if([[1,0],[-1,0],[0,1],[0,-1]].some(([dx,dy])=>{ const c=b.get(x+dx,y+dy); return c && c!=='K' && c!=='W'; }) && inShape(x,y)) out[y*b.W+x]='K'; }
  return { W:b.W, H:b.H, a:out }; }
const ART_CACHE={};
