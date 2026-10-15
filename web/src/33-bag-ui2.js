// 가방 UI 도트 스킨: 가죽 틀(바느질 · 놋쇠 리벳) · 안감 칸 · 지퍼 옆주머니 · 지하철 쓰레기통 · 토큰 · 자물쇠 · 놋쇠 버튼 · 짙은 판. 전부 픽셀로 그려 9-슬라이스로 입힌다
function pxCanvas(w,h,draw){ const cv=document.createElement('canvas'); cv.width=w; cv.height=h; const cx=cv.getContext('2d');
  const P=(x,y,c)=>{ if(!c) return; cx.fillStyle=c; cx.fillRect(x,y,1,1); }, R=(x,y,ww,hh,c)=>{ cx.fillStyle=c; cx.fillRect(x,y,ww,hh); };
  draw(P,R,cx); return cv.toDataURL(); }
function buildInvSkin(){
  const rnd=mulberry(7), set=(k,v)=>document.documentElement.style.setProperty(k,`url(${v})`);
  // 가죽 틀 24×24(모서리 8): 바깥 검은 선 · 가죽 결 · 바느질(점선) · 모서리 놋쇠 리벳 · 안쪽 그림자
  set('--px-frame', pxCanvas(24,24,(P,R)=>{ for(let y=0;y<24;y++) for(let x=0;x<24;x++){ const n=rnd(); P(x,y, n<.12?'#5a3820':n<.3?'#7a4c2a':'#6a4226'); }
    for(let i=0;i<24;i++){ P(i,0,'#0e0d14'); P(i,23,'#0e0d14'); P(0,i,'#0e0d14'); P(23,i,'#0e0d14'); P(i,1,'#9a6a3e'); P(1,i,'#9a6a3e'); P(i,22,'#3a2414'); P(22,i,'#3a2414'); }
    for(let i=3;i<21;i++) if(i%3!==2){ P(i,3,'#e8d6a8'); P(i,20,'#c9b282'); P(3,i,'#e8d6a8'); P(20,i,'#c9b282'); }
    for(const [x,y] of [[5,5],[17,5],[5,17],[17,17]]){ R(x,y,2,2,'#c08a24'); P(x,y,'#ffe7a8'); P(x+1,y+1,'#8a5a14'); }
    for(let i=7;i<17;i++){ P(i,7,'#2a1a10'); P(7,i,'#2a1a10'); } R(8,8,8,8,'#3b2618'); }));
  // 안감 칸 16×16: 짙은 천 · 사선 결 · 박음질 경계
  set('--px-cell', pxCanvas(16,16,(P,R)=>{ R(0,0,16,16,'#1f1a38'); for(let y=0;y<16;y++) for(let x=0;x<16;x++){ if((x+y)%4===0) P(x,y,'#262044'); if((x-y+16)%6===0) P(x,y,'#191430'); }
    for(let i=0;i<16;i++){ P(i,0,'#120f22'); P(0,i,'#120f22'); P(i,15,'#2c2650'); P(15,i,'#2c2650'); } for(let i=2;i<14;i+=3){ P(i,1,'#3a3360'); P(1,i,'#3a3360'); } }));
  // 지퍼 달린 옆주머니 18×18(모서리 6): 캔버스 천 · 바느질 · 위쪽 지퍼 이빨
  set('--px-pocket', pxCanvas(18,18,(P,R)=>{ for(let y=0;y<18;y++) for(let x=0;x<18;x++){ const n=rnd(); P(x,y, n<.14?'#4a2e1a':n<.32?'#6a4226':'#5a3820'); }
    for(let i=0;i<18;i++){ P(i,0,'#0e0d14'); P(i,17,'#0e0d14'); P(0,i,'#0e0d14'); P(17,i,'#0e0d14'); P(i,1,'#8a5e38'); P(1,i,'#8a5e38'); P(i,16,'#2a1a10'); P(16,i,'#2a1a10'); }
    for(let i=2;i<16;i++){ P(i,2,i%2?'#c9a24a':'#8a6a24'); P(i,3,i%2?'#8a6a24':'#c9a24a'); }
    for(let i=5;i<14;i++) if(i%3!==2){ P(3,i,'#e8d6a8'); P(14,i,'#c9b282'); } for(let i=4;i<14;i++) if(i%3!==2) P(i,14,'#c9b282'); }));
  set('--px-slot', pxCanvas(12,12,(P,R)=>{ R(0,0,12,12,'#24160d'); R(1,1,10,10,'#1a110a'); for(let i=0;i<12;i++){ P(i,0,'#0b0705'); P(0,i,'#0b0705'); P(i,11,'#7a5232'); P(11,i,'#7a5232'); P(i,1,'#120b06'); P(1,i,'#120b06'); }
    for(const [x,y] of [[2,2],[9,2],[2,9],[9,9]]) P(x,y,'#5a3c24'); }));
  set('--px-trash', pxCanvas(28,34,(P,R)=>{
    R(9,0,6,3,'#d9d2bf'); R(10,1,2,1,'#9a937e'); R(15,1,4,2,'#bfb7a0'); P(16,1,'#7d7766'); R(7,2,14,2,'#0e0d14');
    for(let y=6;y<31;y++){ const sh=Math.floor((y-6)/12), x0=3+sh, x1=24-sh;
      for(let x=x0;x<=x1;x++){ const m=((x+y)%5===0)||((x-y+40)%5===0); P(x,y, m ? (x<x0+4?'#6fc07a':x>x1-3?'#245a30':'#3f8a4e') : '#101a12'); } P(x0,y,'#0e0d14'); P(x1,y,'#0e0d14'); }
    R(2,3,24,3,'#3f8a4e'); R(2,3,24,1,'#7fd08a'); R(2,5,24,1,'#1c3a22'); P(2,4,'#0e0d14'); P(25,4,'#0e0d14');
    R(4,17,20,2,'#2f6b3c'); R(4,17,20,1,'#5aa868');
    R(5,29,18,3,'#2f6b3c'); R(5,29,18,1,'#5aa868'); R(5,31,18,1,'#1c3a22'); R(6,32,16,1,'#0e0d14'); R(8,33,12,1,'#07060c'); }));
  // 놋쇠 버튼 12×12(모서리 4)
  set('--px-btn', pxCanvas(12,12,(P,R)=>{ R(0,0,12,12,'#c08a24'); for(let i=0;i<12;i++){ P(i,0,'#0e0d14'); P(i,11,'#0e0d14'); P(0,i,'#0e0d14'); P(11,i,'#0e0d14'); P(i,1,'#f6cb4c'); P(1,i,'#f6cb4c'); P(i,10,'#8a5a14'); P(10,i,'#8a5a14'); } P(1,1,'#ffe7a8'); }));
  // 짙은 판 12×12(모서리 4): 정보 줄 · 합성 창 · 매점 카드
  set('--px-plate', pxCanvas(12,12,(P,R)=>{ R(0,0,12,12,'#1a1530'); for(let i=0;i<12;i++){ P(i,0,'#0e0d14'); P(i,11,'#0e0d14'); P(0,i,'#0e0d14'); P(11,i,'#0e0d14'); P(i,1,'#3a3360'); P(1,i,'#3a3360'); P(i,10,'#110d20'); P(10,i,'#110d20'); } P(2,2,'#5a4b9a'); P(9,2,'#5a4b9a'); P(2,9,'#5a4b9a'); P(9,9,'#5a4b9a'); }));
  // 지하철 토큰 12×12: 놋쇠 동전 · 가운데 Y자 구멍
  set('--px-token', pxCanvas(12,12,(P,R)=>{ for(let y=0;y<12;y++) for(let x=0;x<12;x++){ const d=Math.hypot(x-5.5,y-5.5); if(d<5.6) P(x,y, d>4.6?'#8a5a14':d>3.6?'#f6cb4c':'#c08a24'); }
    for(const [x,y] of [[4,3],[5,4],[7,3],[6,4],[5,5],[6,5],[5,6],[6,6],[5,7],[6,7]]) P(x,y,'#3a2414'); P(3,2,'#ffe7a8'); }));
  // 자물쇠 10×12
  set('--px-lock', pxCanvas(10,12,(P,R)=>{ for(let i=2;i<8;i++) P(i,0,'#8d877b'); for(let i=1;i<5;i++){ P(1,i,'#8d877b'); P(8,i,'#4d4943'); } R(0,5,10,7,'#c08a24'); R(0,5,10,1,'#f6cb4c'); R(4,7,2,3,'#3a2414'); R(0,11,10,1,'#8a5a14'); }));
}

buildInvSkin();
// --- 가방 UI: 6×4 격자에 모양대로 놓인 아이템 · 보류함 · 휴지통 · 자동 정리 ---
const TIER_COL=['','#8a90a8','#5fd08a','#5aa8ff','#c77dff','#ffcf4a'];
const starsOf=t=>'★'.repeat(t||1);
function itemBox(b, rot=b.rot){ const c=shapeOf(b.id,rot), w=Math.max(...c.map(p=>p[0]))+1, h=Math.max(...c.map(p=>p[1]))+1; return { c, w, h }; }
// 타일 표기: 역할 배지(콤보 순번) · 이름 · 피해 · 쿨다운 · 쿨다운 막대 — 그림 대신 글자로
const SHORT_N={ hmback:'되치기', charm:'부적', pin:'타이핀', ring:'반지', metro:'메트로', cuff:'커프스', paper:'신문', earph:'이어폰', bandage:'반창고', duck:'쭈그리기' };
const ROLE_G={ S:'▶', L:'●', F:'■', X:'◇' };
const SV_SW='<svg viewBox="0 0 8 8" shape-rendering="crispEdges" aria-hidden="true"><path fill="currentColor" d="M6 0h1v1h-1zM7 0h1v1h-1zM5 1h1v1h-1zM6 1h1v1h-1zM7 1h1v1h-1zM4 2h1v1h-1zM5 2h1v1h-1zM6 2h1v1h-1zM1 3h1v1h-1zM3 3h1v1h-1zM4 3h1v1h-1zM5 3h1v1h-1zM2 4h1v1h-1zM3 4h1v1h-1zM4 4h1v1h-1zM2 5h1v1h-1zM3 5h1v1h-1zM1 6h1v1h-1zM4 6h1v1h-1zM0 7h1v1h-1z"/></svg>';
const SV_CK='<svg viewBox="0 0 8 8" shape-rendering="crispEdges" aria-hidden="true"><path fill="currentColor" d="M2 0h1v1h-1zM3 0h1v1h-1zM4 0h1v1h-1zM5 0h1v1h-1zM1 1h1v1h-1zM6 1h1v1h-1zM0 2h1v1h-1zM3 2h1v1h-1zM7 2h1v1h-1zM0 3h1v1h-1zM3 3h1v1h-1zM7 3h1v1h-1zM0 4h1v1h-1zM3 4h1v1h-1zM4 4h1v1h-1zM7 4h1v1h-1zM0 5h1v1h-1zM7 5h1v1h-1zM1 6h1v1h-1zM6 6h1v1h-1zM2 7h1v1h-1zM3 7h1v1h-1zM4 7h1v1h-1zM5 7h1v1h-1z"/></svg>';
const LB_CACHE={};
function labelRect(id,rot){ const k=id+'@'+(((rot||0)%4+4)%4); if(LB_CACHE[k]) return LB_CACHE[k];
  const c=shapeOf(id,rot), S=new Set(c.map(p=>p[0]+','+p[1])), W=Math.max(...c.map(p=>p[0]))+1, H=Math.max(...c.map(p=>p[1]))+1; let best=null;
  for(let y=0;y<H;y++) for(let x=0;x<W;x++) for(let h=1;h<=3;h++) for(let w=1;w<=3;w++){ let ok=true;
    for(let yy=y;yy<y+h&&ok;yy++) for(let xx=x;xx<x+w;xx++) if(!S.has(xx+','+yy)){ ok=false; break; }
    if(!ok) continue; const sc=w*h*10+(h>=2?3:0)-y*.5-x*.1; if(!best||sc>best.sc) best={ lx:x, ly:y, lw:w, lh:h, sc }; }
  return LB_CACHE[k]=best; }
let RBADGE=new Map();
function routeBadgeMap(list){ const M=new Map(); try{ routesOf(list||GS.bag).forEach((r,k)=>r.items.forEach((o,n)=>{ if(!M.has(o.uid)) M.set(o.uid,{ n:n+1, col:r.col }); })); }catch(e){} return M; }
const fmtD=v=>{ const n=Math.round(v*DMG_K); return n>=10000 ? (n/1000).toFixed(n>=100000?0:1)+'k' : String(n); };
function tileStats(b){ const it=GITEMS[b.id], t=b.tier||1, i=GS.bag.indexOf(b), k=it.kind, P=v=>Math.round(v*100)+'%';
  if(k==='skill'||k==='dodge'){ let dmg, cd;
    if(i>=0){ const st=sStats(i); dmg=st.dmg; cd=st.cd; } else { const op=b.opt||{}; dmg=(it.dmg||0)*tDmg(t)*(1+(op.k==='dmg'?op.v:0)); cd=it.cd*tCd(t)*(1-(op.k==='cd'?op.v:0)); }
    return { dmg: it.dmg ? fmtD(dmg)+(it.combo?'+':'') : null, cd: cd.toFixed(1), hasCd:true }; }
  const V={ crit:['+'+P(.12+.04*(t-1)),'#ff8a7a'], critd:['+'+P(.40+.15*(t-1)),'#ffb067'], gem:['+'+P(.25+.08*(t-1)),'#ffe27a'], stone:['−'+P(.18+.05*(t-1)),'#8cc4ff'],
    metro:['↕−'+P(.12+.03*(t-1)),'#8cc4ff'], cuff:['⤡+'+P(.10+.03*(t-1)),'#ff8a7a'], knuckle:['+'+P(.25+.08*(t-1)),'#ffe27a'], shoes:['−'+P(.10+.02*(t-1)),'#8cc4ff'],
    armor:['+'+(30+15*(t-1)),'#8dff9a'], heal:['+'+(it.heal+6*(t-1)),'#8dff9a'], gum:['+'+(1.5+.3*(t-1)).toFixed(1)+(LANG==='en'?'s':'초'),'#e8d6a8'], ear:['+'+P(.6+.15*(t-1)),'#e8d6a8'], watch:['+'+P(.30+.05*(t-1)),'#d4b4ff'] }[k];
  return { val:V?V[0]:null, vc:V?V[1]:null, cd: k==='heal' ? String(it.cd-(t-1)) : null, hasCd: k==='heal' }; }
function badgeOf(b){ const R=RBADGE.get(b.uid), r=croleOf(b.id), k=GITEMS[b.id].kind;
  return R ? `<b class="bdg" style="--rc:${R.col}">${R.n}${ROLE_G[r]||''}</b>` : (k==='skill'||k==='dodge') ? `<b class="bdg">${ROLE_G[r]||'◇'}</b>` : `<b class="bdg gold">◆</b>`; }
function tileLabel(b,rot,w,h){ const it=GITEMS[b.id], L=labelRect(b.id,rot), t=b.tier||1, role=croleOf(b.id), R=RBADGE.get(b.uid), sk=it.kind==='skill'||it.kind==='dodge';
  const lay = L.lw>=2&&L.lh===1 ? 'row' : L.lw===1&&L.lh===1 ? 's1' : 'col', S=tileStats(b);
  const badge = R ? `<b class="bdg" style="--rc:${R.col}">${R.n}${ROLE_G[role]||''}</b>` : sk ? `<b class="bdg">${ROLE_G[role]||'◇'}</b>` : `<b class="bdg gold">◆</b>`;
  const nm = (L.lw===1 && SHORT_N[b.id]) || it.sn || it.n, tt = L.lw===1 && Math.max(...nm.split(/\s+/).map(q=>q.length))>=4;   // 한 칸 폭에 네 글자 낱말이면 촘촘하게
  const sv = S.dmg!=null || S.val ? `<span class="sv">${S.dmg!=null?`<em class="dm">${SV_SW}${S.dmg}</em>`:''}${S.val?`<em class="vl" style="color:${S.vc}">${S.val}</em>`:''}${S.cd&&sk?`<em class="ct">${SV_CK}${S.cd}</em>`:''}</span>` : (S.cd&&sk?`<span class="sv"><em class="ct">${SV_CK}${S.cd}</em></span>`:'');
  return `<span class="lb ${lay}${S.hasCd?' hc':''}" style="left:${L.lx/w*100}%;top:${L.ly/h*100}%;width:${L.lw/w*100}%;height:${L.lh/h*100}%"><span class="hd"><span class="bdr">${badge}${t>1?`<i class="tr">★${t}</i>`:''}${b.opt?`<i class="od" style="--oc:${OPTS[b.opt.k].c}"></i>`:''}</span><span class="nm${tt?' tt':''}">${nm}</span></span>${sv}${S.hasCd?'<i class="cb"><i class="cd"></i></i>':''}</span>`; }
function itemHTML(b, cls, rot){ const it=GITEMS[b.id], {c,w,h}=itemBox(b,rot), r=rot??b.rot;
  const has=(x,y)=>c.some(p=>p[0]===x&&p[1]===y);                                  // 한 덩어리처럼: 바깥쪽 변에만 테두리
  const pcs=c.map(([x,y])=>{ const t=!has(x,y-1), rr=!has(x+1,y), bt=!has(x,y+1), l=!has(x-1,y);
    return `<i class="pc" style="left:${x/w*100}%;top:${y/h*100}%;width:${100/w}%;height:${100/h}%;border-width:${t?2:0}px ${rr?2:0}px ${bt?2:0}px ${l?2:0}px"></i>`; }).join('');
  const fcol=it.fcol||((it.fam&&FAMS[it.fam])?FAMS[it.fam].c:(it.kind==='skill'||it.kind==='dodge')?'#d8cfae':'#c9a24a');
  return `<div class="${cls} t${b.tier||1}" data-uid="${b.uid}" style="--w:${w};--h:${h};--tc:${TIER_COL[b.tier||1]};--fcol:${fcol}">${pcs}${pcs.replace(/class="pc"/g,'class="po"')}${c.map(([x,y])=>`<i class="cdo" data-cy="${y}" data-h="${h}" style="left:${x/w*100}%;top:${y/h*100}%;width:${100/w}%;height:${100/h}%"></i>`).join('')}${tileLabel(b,r,w,h)}</div>`; }
// =========================================================
// 가방 블럭 연출 · 케미(FC 레퍼런스) · 기여 통계
// =========================================================
// =========================================================
// 격투 게임식 커맨드 표시: 발동한 가방 기술이 무대 오른쪽에 순서대로 쌓인다
// =========================================================
const CMD_MAX=5, CMD_LIFE=4;
function cmdPush(o){ GS.cmdLog=GS.cmdLog||[]; GS.cmdLog.unshift({ ...o, t:performance.now()/1000 }); if(GS.cmdLog.length>CMD_MAX) GS.cmdLog.length=CMD_MAX; }
function cmdSkill(b,crit,step){ const it=GITEMS[b.id]; const nm = it.combo ? ['잽','크로스','훅','어퍼'][step||0] : it.n;
  cmdPush({ id:b.id, name:nm, fam:it.fam, crit, link:!!b.linkMark }); b.linkMark=false; }
function drawCmdLog(){ const L=GS.cmdLog; if(!L||!L.length || GS.cine || GS.cut) return; const now=performance.now()/1000, x0=8, y0=GS.bonus?50:GS.demo?48:36, rh=15;   // 왼쪽 위: 노선 표시 · 남은 시간 막대 바로 아래
  uiCx.save(); uiCx.font='10px Galmuri9,monospace'; uiCx.textBaseline='middle';                                  // 타격명만: 그림 · 꼬리표 없이, 상태는 글자 색으로(치명 빨강 · 연계 초록 · 필살기 금색)
  L.forEach((e,k)=>{ const age=now-e.t; if(age>CMD_LIFE+.5) return; const a=age>CMD_LIFE ? 1-(age-CMD_LIFE)/.5 : 1, slide=Math.max(0,1-age/.12)*24, y=y0+k*rh, x=x0-slide;   // 왼쪽에서 밀려 들어온다
    const w=Math.ceil(uiCx.measureText(e.name).width)+10;
    uiCx.globalAlpha=a*(k===0?1:.88-k*.08);
    uiCx.fillStyle = e.sp ? 'rgba(60,40,6,.85)' : 'rgba(10,8,18,.72)'; uiCx.fillRect(x,y,w,rh-2);
    uiCx.fillStyle = e.sp ? '#ffd34a' : (e.fam&&FAMS[e.fam]?FAMS[e.fam].c:'#9a94b4'); uiCx.fillRect(x,y,2,rh-2);
    uiCx.fillStyle = e.sp ? '#ffe27a' : e.crit ? '#ff7a5c' : e.link ? '#7dffa0' : '#f1ece0'; uiCx.fillText(e.name,x+6,y+6.5);
    if(age<.15){ uiCx.globalAlpha=(1-age/.15)*.6; uiCx.fillStyle='#ffffff'; uiCx.fillRect(x,y,w,rh-2); } });
  uiCx.restore(); }

// =========================================================
// 방향 시너지(메트로카드 · 커프스 단추 · 손목시계) · 각인 칸 · 주인공 선글라스
// =========================================================
// 두 아이템 칸 집합 사이의 닿음: 위아래(v) · 좌우(h) · 대각(d) · 상하좌우 어느 쪽(o)
function dirRel(A,B){ let v=false,h=false,d=false; for(const [ax,ay] of A) for(const [bx,by] of B){ const dx=Math.abs(ax-bx), dy=Math.abs(ay-by); if(dx===0&&dy===1) v=true; else if(dx===1&&dy===0) h=true; else if(dx===1&&dy===1) d=true; } return { v, h, d, o:v||h }; }
const touches=(item,c)=>cellsOf(item).some(([x,y])=>Math.abs(x-c[0])+Math.abs(y-c[1])===1);
// 손목시계: 첫 칸 = 들어오는 끝, 둘째 칸 = 나가는 끝
function watchEnds(w){ const c=cellsOf(w); return { inC:c[0], outC:c[1] }; }
function watchFlow(src){ for(const w of GS.bag){ if(GITEMS[w.id].kind!=='watch' || w===src) continue; const E=watchEnds(w); if(!touches(src,E.inC) || touches(src,E.outC)) continue;
    const k=.30+.05*((w.tier||1)-1);
    for(const o of GS.bag){ if(o===src||o===w||GITEMS[o.id].kind!=='skill'||!touches(o,E.outC)) continue; const j=GS.bag.indexOf(o), cd=sStats(j).cd; o.t=Math.min(cd,o.t+cd*k); pulseItem(o,true); } } }
// 각인 칸: 권총집(빨리) · 비밀 주머니(치명) · 해진 안감(피해 −20%)
const IMP_NAME={ holster:'권총집', pocket:'비밀 주머니', worn:'해진 안감' }, IMP_DESC={ holster:'이 칸에 걸친 기술 10% 빨리 발동', pocket:'이 칸에 걸친 기술 치명 +8%p', worn:'이 칸에 걸친 기술 피해 −20%' };
function genImprints(){ const rnd = RUNCFG.daily ? mulberry(hashStr(todayKey()+':imp')) : Math.random, I={}, cells=[];
  for(let y=0;y<INV.H;y++) for(let x=0;x<INV.W;x++) cells.push(x+','+y);
  for(const t of ['holster','pocket','worn']){ const k=cells.splice(Math.floor(rnd()*cells.length),1)[0]; I[k]=t; } return I; }
function impOf(b){ const I=GS.imprints||{}, r={}; for(const [x,y] of cellsOf(b)){ const t=I[x+','+y]; if(t) r[t]=true; } return r; }
function impAt(b,tx,ty,rot){ const I=GS.imprints||{}, r={}; for(const [x,y] of cellsOf(b,tx,ty,rot)){ const t=I[x+','+y]; if(t) r[t]=true; } return r; }
function impBadges(){ const I=GS.imprints||{}; return Object.entries(I).map(([k,t])=>{ const [x,y]=k.split(',').map(Number); return `<i class="impb imp-${t}" style="left:${(x+1)/INV.W*100}%;top:${y/INV.H*100}%" title="${IMP_NAME[t]} · ${IMP_DESC[t]}"></i>`; }).join(''); }
function carveImprint(){ const I=GS.imprints||(GS.imprints={}), worn=Object.keys(I).find(k=>I[k]==='worn');
  if(worn){ delete I[worn]; say('각인 새기기','해진 안감을 수선했어요',1.6); }
  else { const free=[]; for(let y=0;y<INV.H;y++) for(let x=0;x<INV.W;x++) if(!I[x+','+y]) free.push(x+','+y); if(!free.length) return; const k=free[Math.floor(Math.random()*free.length)], t=Math.random()<.5?'holster':'pocket'; I[k]=t; say('각인 새기기',`${IMP_NAME[t]}을(를) 새겼어요 — ${IMP_DESC[t]}`,2); }
  sfx.coin(); renderBag(); }
// 선글라스(초상 64px): 두 렌즈 · 브리지 · 다리 · 반사
function shades64(b,m){ const by=27, L=25, Rr=39;
  for(const [x0,x1] of [[L-5,L+4],[Rr-4,Rr+5]]){ b.rect(x0,by+1,x1-x0+1,6,'K',true); b.rect(x0+1,by+7,x1-x0-1,1,'K',true); b.line(x0,by,x1,by,'N',true); b.set(x0+1,by+2,'h',true); b.set(x0+2,by+2,'h',true); b.line(x0+4,by+5,x0+7,by+2,'l',true); }
  b.line(L+5,by+2,Rr-5,by+2,'N',true); b.line(L-6,by+2,L-8,by+1,'N',true); b.line(Rr+6,by+2,Rr+8,by+1,'N',true);
  if(m==='crit'){ b.line(L-3,by+2,L,by+4,'h',true); b.line(L,by+4,L-1,by+6,'h',true); } }

function bagElOf(uid){ return bagEl.querySelector(`.inv-grid .ii[data-uid="${uid}"]`); }
// 무대 위 주인공의 화면 좌표(세로 크롭 · 거리 장면 카메라 반영)
function heroScreen(){ const Hh=GS.hero, r=canvas.getBoundingClientRect(), cx=(GS.on&&(scene==='subway'||GS.cine||GS.bonus))?CAMX:0, wx=Hh.d.x-(scene==='brawl'?(GS.cam||0):0);
  return { x:r.left+(wx-cx)/VW*r.width, y:r.top+(Hh.d.y-40)/SB.H*r.height, vis:r.bottom>0&&r.top<innerHeight }; }
function beam(x0,y0,x1,y1,col,w,dur){ const d=document.createElement('i'); d.className='bag-beam'; const len=Math.hypot(x1-x0,y1-y0), ang=Math.atan2(y1-y0,x1-x0);
  d.style.cssText=`left:${x0}px;top:${y0-(w||3)/2}px;width:${len}px;height:${w||3}px;transform:rotate(${ang}rad);--bc:${col};animation-duration:${dur||280}ms`; document.body.appendChild(d); setTimeout(()=>d.remove(),(dur||280)+60); }
function bagFire(b,hit,crit){ const el=bagElOf(b.uid); if(!el) return; el.classList.remove('fire','fcrit'); void el.offsetWidth; el.classList.add(hit&&crit?'fcrit':'fire'); }
function bagLinkBeam(a,b){ const ea=bagElOf(a.uid), eb=bagElOf(b.uid); if(!ea||!eb) return; const ra=ea.getBoundingClientRect(), rb=eb.getBoundingClientRect();
  beam(ra.left+ra.width/2, ra.top+ra.height/2, rb.left+rb.width/2, rb.top+rb.height/2, '#7dffa0', 4, 360); }
// 케미: 닿은 쌍의 종류(연계 nm · 연쇄 ch · 버프 bf)
function chemPairs(){ const out=[], BUFF=k=>['gem','stone','crit','critd'].includes(k), SK=k=>k==='skill'||k==='dodge';
  for(let i=0;i<GS.bag.length;i++) for(const B of adjItems(i)){ const A=GS.bag[i], j=GS.bag.indexOf(B); if(j<=i) continue;
    const ka=GITEMS[A.id].kind, kb=GITEMS[B.id].kind, L=linkBetween(A,B);
    let type = L ? 'nm' : (ka==='skill'&&kb==='skill') ? 'ch' : (BUFF(ka)&&SK(kb))||(BUFF(kb)&&SK(ka)) ? 'bf' : null;
    if(!type && ((ka==='metro'&&SK(kb))||(kb==='metro'&&SK(ka))) && dirRel(cellsOf(A),cellsOf(B)).v) type='bf';
    if(!type && (ka==='watch'||kb==='watch')){ const w=ka==='watch'?A:B, o=w===A?B:A; if(SK(GITEMS[o.id].kind)){ const E=watchEnds(w); if(touches(o,E.inC)||touches(o,E.outC)) type='fl'; } }
    if(type) out.push({A,B,type,L}); }
  for(const c of GS.bag){ if(GITEMS[c.id].kind!=='cuff') continue; for(const o of GS.bag){ if(o===c||!SK(GITEMS[o.id].kind)) continue; const D=dirRel(cellsOf(c),cellsOf(o)); if(D.d&&!D.o) out.push({A:c,B:o,type:'bf'}); } }
  return out; }
const cellCenter=b=>{ const c=cellsOf(b); return [c.reduce((s,p)=>s+p[0],0)/c.length+.5, c.reduce((s,p)=>s+p[1],0)/c.length+.5]; };
function chemSVG(){ const P=chemPairs(), sty={ nm:'stroke="#5dff7a" stroke-width="2.6"', ch:'stroke="#ffb347" stroke-width="1.8" stroke-dasharray="4 3"', bf:'stroke="#6ec6ff" stroke-width="1.8" stroke-dasharray="1.5 3"', fl:'stroke="#c59bff" stroke-width="2" stroke-dasharray="5 2"' };
  const sel=GS.selUid; const lines=P.map(p=>{ const [x0,y0]=cellCenter(p.A), [x1,y1]=cellCenter(p.B), on=sel!=null&&(p.A.uid===sel||p.B.uid===sel); return `<line class="${on?'on':''} t-${p.type}" x1="${x0}" y1="${y0}" x2="${x1}" y2="${y1}" ${sty[p.type]} vector-effect="non-scaling-stroke" stroke-linecap="round"/>`; }).join('');
  return `<svg class="chem" viewBox="0 0 ${INV.W} ${INV.H}" preserveAspectRatio="none" aria-hidden="true">${lines}</svg>`; }
function chemOf(b,P){ const k=GITEMS[b.id].kind; if(k!=='skill'&&k!=='dodge') return -1; const my=P.filter(p=>p.A===b||p.B===b);
  return Math.min(3, Math.min(2,new Set(my.filter(p=>p.type==='nm').map(p=>p.L.n)).size) + (my.some(p=>p.type!=='nm')?1:0)); }
function chemDiamonds(){ const P=chemPairs(); return GS.bag.map(b=>{ const n=chemOf(b,P); if(n<0) return ''; const c=cellsOf(b), x=Math.min(...c.map(p=>p[0])), y=Math.max(...c.filter(p=>p[0]===x).map(p=>p[1]));
    return `<i class="chemd" style="left:${x/INV.W*100}%;top:${(y+1)/INV.H*100}%">${'◆'.repeat(n)}${'◇'.repeat(3-n)}</i>`; }).join(''); }
// 별: 고른 블럭 옆 빈칸 중 연계 짝이 올 수 있는 자리
function linkPartners(id){ const out=[]; for(const L of LINKS){ for(const pid in GITEMS){ if(pid===id || GITEMS[pid].pro) continue; if((L.a(id)&&L.b(pid))||(L.b(id)&&L.a(pid))) out.push([pid,L.n]); } }
  const seen=new Set(); return out.filter(([p,n])=>{ const k=p+n; if(seen.has(k)) return false; seen.add(k); return GITEMS[p].kind==='skill'||GITEMS[p].kind==='dodge'; }); }
function chemStars(){ if(!GS.selUid || !canEdit()) return ''; const b=GS.bag.find(o=>o.uid===GS.selUid); if(!b) return ''; const k=GITEMS[b.id].kind, occ=occMap(-1), seen=new Set(), out=[], mine=new Set(cellsOf(b).map(([x,y])=>x+','+y));
  const mark=(x,y,cls,ch)=>{ const kk=x+','+y; if(x<0||y<0||x>=INV.W||y>=INV.H||occ.has(kk)||mine.has(kk)||seen.has(kk)) return; seen.add(kk); out.push(`<i class="cstar ${cls||''}" style="left:${(x+.5)/INV.W*100}%;top:${(y+.5)/INV.H*100}%">${ch||'✦'}</i>`); };
  if(k==='metro'||k==='cuff'){ const D=k==='metro'?[[0,1],[0,-1]]:[[1,1],[1,-1],[-1,1],[-1,-1]]; for(const [x,y] of cellsOf(b)) for(const [dx,dy] of D) mark(x+dx,y+dy); }
  else if(k==='watch'){ const E=watchEnds(b); for(const [dx,dy] of [[1,0],[-1,0],[0,1],[0,-1]]){ mark(E.inC[0]+dx,E.inC[1]+dy,'win','▸'); mark(E.outC[0]+dx,E.outC[1]+dy,'',''); } }
  else { if(!linkPartners(b.id).length) return ''; for(const [x,y] of cellsOf(b)) for(const [dx,dy] of [[1,0],[-1,0],[0,1],[0,-1]]) mark(x+dx,y+dy); }
  return out.join(''); }
// 기여 통계: 구간별 · 판 전체
function contribAdd(uid,d){ for(const k of ['contrib','contribRun']){ const C=GS[k]||(GS[k]={}); (C[uid]||(C[uid]={dmg:0,n:0})).dmg+=d; } }
function contribTrig(uid){ for(const k of ['contrib','contribRun']){ const C=GS[k]||(GS[k]={}); (C[uid]||(C[uid]={dmg:0,n:0})).n++; } }
function contribHTML(C,limit,title){ const arr=Object.entries(C||{}).map(([u,v])=>({ b:findAny(+u), ...v })).filter(o=>o.b&&o.dmg>0).sort((a,c)=>c.dmg-a.dmg).slice(0,limit||5); if(!arr.length) return '';
  const tot=Object.values(C).reduce((s,v)=>s+v.dmg,0), mx=arr[0].dmg;
  return `<div class="contrib"><b>${title||'이번 구간 기여'}</b>${arr.map(o=>`<p>${badgeOf(o.b)}<span class="cn">${GITEMS[o.b.id].n}</span><i class="cbar"><i style="width:${Math.round(o.dmg/mx*100)}%"></i></i><span class="cv">${Math.round(o.dmg*DMG_K).toLocaleString()} · ${Math.round(o.dmg/tot*100)}%</span><span class="cx">${o.n}회</span></p>`).join('')}</div>`; }

// 닿은 경계마다 연결 표시: 금색 = 이름 붙은 연계 · 은색 = 연쇄(기술끼리) · 파랑 = 부적 · 캔커피
function linkMarks(){ const out=[];
  for(let i=0;i<GS.bag.length;i++) for(const B of adjItems(i)){ const A=GS.bag[i], j=GS.bag.indexOf(B); if(j<=i) continue;
    const ka=GITEMS[A.id].kind, kb=GITEMS[B.id].kind, L=linkBetween(A,B);
    const BUFF=k=>['gem','stone','crit','critd'].includes(k);
    const type = L ? 'nm' : (ka==='skill'&&kb==='skill') ? 'ch' : (BUFF(ka)&&(kb==='skill'||kb==='dodge'))||(BUFF(kb)&&(ka==='skill'||ka==='dodge')) ? 'bf' : null;
    if(!type) continue;
    const cb=cellsOf(B); let e=null;
    for(const [ax,ay] of cellsOf(A)){ for(const [bx,by] of cb){ if(Math.abs(ax-bx)+Math.abs(ay-by)===1){ e = ax!==bx ? {x:Math.max(ax,bx), y:ay+.5, v:1} : {x:ax+.5, y:Math.max(ay,by), v:0}; break; } } if(e) break; }
    if(e) out.push(`<i class="lk ${type} ${e.v?'v':'h'}" style="left:${e.x/INV.W*100}%;top:${e.y/INV.H*100}%" title="${L?L.n:''}"></i>`); }
  return out.join(''); }
// 오른쪽 칸: 전투 중엔 '준비 순서', 끌거나 전투 밖이면 '보류함'. 직접 고른 탭은 전투 상태가 바뀔 때까지 유지
let drag=null;
function bagTab(){ const c=inCombat(); if(GS.bagTabU && GS.bagTabU.c===c) return GS.bagTabU.t; GS.bagTabU=null; return c?'q':'p'; }
function bagCS(){ const w=bagEl.clientWidth-8; if(w<=0) return; const cs=Math.max(30,Math.min(52,Math.floor((w-14)/8))); if(bagEl._cs!==cs){ bagEl._cs=cs; bagEl.style.setProperty('--cs',cs+'px'); } }
try{ new ResizeObserver(()=>bagCS()).observe(bagEl); }catch(e){}
function qRows(){ const H=GS.hero, F=H?foes().filter(a=>a.anim!=='death'&&!a.held):[], T=H?F.filter(a=>!isDown(a)).sort((a,b)=>Math.abs(a.d.x-H.d.x)-Math.abs(b.d.x-H.d.x))[0]:null;
  return GS.bag.map((b,i)=>{ const it=GITEMS[b.id]; if(!(it.kind==='skill'||it.kind==='dodge'||it.kind==='heal')) return null;
    const full=it.kind==='heal' ? it.cd-((b.tier||1)-1) : sStats(i).cd, p=full?Math.min(1,(b.t||0)/full):1, wait=p>=1 && it.cond && H && !condOK(it.cond,H,T,F);
    return { b, i, rem:Math.max(0,full-(b.t||0)), p, wait }; }).filter(Boolean).sort((a,c)=>a.rem-c.rem || rdKey(a.b)-rdKey(c.b)); }
function queueHTML(rows){ rows=rows||qRows(); if(!rows.length) return `<span class="iq-empty">${tr('기술을 넣으면 준비 순서가 보여요')}</span>`;
  return rows.map(({b,p,wait})=>{ const it=GITEMS[b.id], R=RBADGE.get(b.uid), role=croleOf(b.id), S=tileStats(b);
    const bd = R ? `<b class="bdg" style="--rc:${R.col}">${R.n}${ROLE_G[role]||''}</b>` : `<b class="bdg">${it.kind==='heal'?'◆':ROLE_G[role]||'◇'}</b>`;
    return `<div class="iq${p>=1&&!wait?' r':''}${wait?' w':''}${b.uid===GS.selUid?' sel':''}" data-uid="${b.uid}"><span class="qh">${bd}<span class="qn">${it.sn||it.n}</span></span><span class="qf"><i class="qb"><i style="width:${Math.round(p*100)}%"></i></i><span class="qd">${S.dmg!=null?S.dmg:S.val||''}</span></span></div>`; }).join(''); }
function renderBag(){
  GS.max=heroMax(); GS.hp=Math.min(GS.hp,GS.max); if(GS.hero) GS.hero.pick=null; computeSets(); normStash(); RBADGE=routeBadgeMap();
  const lock=!canEdit(), tab=bagTab(), isNew=GS.stash.some(o=>o.isNew);
  const IMP=GS.imprints||{}; let grid=''; for(let y=0;y<INV.H;y++) for(let x=0;x<INV.W;x++){ const t=IMP[x+','+y]; grid+=`<i class="gc${t?' imp-'+t:''}" style="left:${x/INV.W*100}%;top:${y/INV.H*100}%"></i>`; }
  const items=GS.bag.map(b=>{ const {w,h}=itemBox(b), f=GITEMS[b.id].fam, set=inSet(b); return `<div class="slot${set?' inset':''}" style="left:${b.x/INV.W*100}%;top:${b.y/INV.H*100}%;width:${w/INV.W*100}%;height:${h/INV.H*100}%;${set?`--fc:${FAMS[f].c}`:''}">${itemHTML(b,'ii'+(b.uid===GS.selUid?' sel':'')+(b.emp?' emp':''))}</div>`; }).join('');
  let pk=''; for(let y=0;y<INV.SH;y++) for(let x=0;x<INV.SW;x++) pk+=`<i class="pk" style="left:${x/INV.SW*100}%;top:${y/INV.SH*100}%;width:${100/INV.SW}%;height:${100/INV.SH}%"></i>`;
  const pitems=GS.stash.map(b=>{ const f=stFoot(b,b.rot||0); return `<div class="slot pslot${b.isNew?' isnew':''}${f.fold?' fold':''}" style="left:${b.sx/INV.SW*100}%;top:${b.sy/INV.SH*100}%;width:${f.w/INV.SW*100}%;height:${f.h/INV.SH*100}%">${itemHTML(b,'ii si'+(b.uid===GS.selUid?' sel':'')+(b.isNew?' new':''))}</div>`; }).join('');
  bagEl.className='inv'+(lock?' locked':'')+(drag&&drag.ghost?' dragging':''); bagCS();
  bagEl.innerHTML=`<div class="inv-head"><b class="inv-title">${artURL('case',0,1)?`<img src="${artURL('case',0,1)}" alt="">`:''}서류가방</b><span class="inv-lock">${lock?'<i class="px-lock"></i>장면이 끝나면 정리할 수 있어요':inCombat()?'전투 중 정리 · 시간이 느려지고 옮긴 기술은 쿨다운이 처음부터':'끌어 놓으면 화력 변화가 미리 보여요'}</span><button type="button" class="inv-btn inv-rot" ${lock||!GS.selUid?'disabled':''} aria-label="선택한 아이템 돌리기">↻ 돌리기</button><button type="button" class="inv-btn inv-undo" ${lock||!(GS.undo&&GS.undo.length)?'disabled':''} aria-label="되돌리기">↶ 되돌리기</button><span class="inv-tok"><i class="px-token"></i>${GS.tokens}</span></div>
    ${Object.keys(GS.sets||{}).length?`<div class="inv-sets">${Object.keys(GS.sets).map(f=>`<span style="--fc:${FAMS[f].c}">${FAMS[f].n} 세트 · 피해 +20% · 쿨다운 −10%${FAMS[f].guard?' · 받는 피해 −15%':''}</span>`).join('')}</div>`:''}
    <div class="inv-main"><div class="inv-grid" style="--W:${INV.W};--H:${INV.H}">${grid}${items}${chemSVG()}${routeLayer()}${linkMarks()}${impBadges()}${chemStars()}</div>
      <div class="inv-right${tab==='q'?' show-q':''}"><div class="ir-tabs"><button type="button" class="ir-tab${tab==='q'?' on':''}" data-t="q">준비</button><button type="button" class="ir-tab${tab==='p'?' on':''}${isNew&&tab!=='p'?' ping':''}" data-t="p">보류<b>${GS.stash.length}</b></button></div>
        <div class="inv-pocket" aria-label="보류함">${pk}${pitems}<span class="ip-drop">여기 두기</span></div><div class="inv-queue">${queueHTML()}</div></div></div>
    <div class="inv-foot">${comboListHTML()}<div class="inv-trash" aria-label="버리기"><i class="px-trash"></i><small>버리기</small></div><button type="button" class="inv-auto">빈자리에 넣기</button></div>`;
  bagEl.dataset.tab=tab; bagEl._qsig='';
  if(GS.equipHint){ const hb=GS.stash.find(o=>o.uid===GS.equipHint.uid), sp=hb&&findSpot(hb); if(sp){ const cells=bagEl.querySelectorAll('.gc'); for(const [x,y] of cellsOf(hb,sp.x,sp.y,sp.rot)){ const n=cells[y*INV.W+x]; if(n) n.classList.add('hint'); } } else GS.equipHint=null; }   // 들어갈 자리
  bagEl.querySelector('.inv-undo').onclick=()=>doUndo(); bagEl.querySelector('.inv-rot').onclick=()=>{ const b=findAny(GS.selUid); if(b) rotateItem(b); };
  bagEl.querySelector('.inv-auto').onclick=()=>{ if(canEdit()){ pushUndo(); const n=autoPack(); say('', n?`보류함의 ${n}개를 빈자리에 넣었어요`:'빈자리를 만들면 넣을 수 있어요', 1.4); } };
  bagEl.querySelectorAll('.ir-tab').forEach(bt=>bt.onclick=()=>{ GS.bagTabU={ c:inCombat(), t:bt.dataset.t }; sfx.click(); renderBag(); });
  showInfo(GS.selUid);
}
const findAny=uid=>GS.bag.find(b=>b.uid===uid)||GS.stash.find(b=>b.uid===uid);
// 가방 아래 정보 칸: 타일과 같은 말(모양 · 배지 · 피해 · 쿨다운)로 머리줄을 만들고, 나머지는 '이름표 | 내용' 줄로 짧게
const SEC_U=()=>LANG==='en'?'s':'초', KE=(ko,en)=>LANG==='en'?en:ko;
function infoHead(b,st,nx){ const it=GITEMS[b.id], t=b.tier||1, inBag=GS.bag.includes(b), fake={ ...b, uid:b.uid }, {w,h}=itemBox(b,0), cs=12, S=tileStats(b), sk=it.kind==='skill'||it.kind==='dodge';
  const role = sk ? `<b class="bdg"${RBADGE.get(b.uid)?` style="--rc:${RBADGE.get(b.uid).col}"`:''}>${RBADGE.get(b.uid)?RBADGE.get(b.uid).n:''}${ROLE_G[croleOf(b.id)]||'◇'} ${ROLE_N[croleOf(b.id)]||''}</b>` : `<b class="bdg gold">◆ 보조</b>`;
  const meta = [`${sizeOf(b.id)}칸`, it.fam?`<span style="color:${FAMS[it.fam].c}">${FAMS[it.fam].n}</span>`:'', !inBag?'<span class="ih-hold">보류 중</span>':''].filter(Boolean).join(' · ');
  let stat='';
  if(sk){ const dmg=st?st.dmg:(it.dmg||0)*tDmg(t), cd=st?st.cd:it.cd*tCd(t);
    stat=`${it.dmg?`<em class="dm">${SV_SW}${fmtD(dmg)}${it.combo?'+':''}</em>`:''}<em class="ct">${SV_CK}${cd.toFixed(1)}${SEC_U()}</em>${st&&it.dmg?`<em class="cr">치명 ${Math.round(st.crit*100)}% ×${st.critD.toFixed(1)}</em>`:''}${nx?`<em class="nx">★${t+1} ${it.dmg?fmtD(nx.dmg)+' · ':''}${nx.cd.toFixed(1)}${SEC_U()}</em>`:''}`; }
  else stat=`${S.val?`<em style="color:${S.vc}">${S.val}</em>`:''}${S.cd?`<em class="ct">${SV_CK}${S.cd}${SEC_U()}</em>`:''}`;
  return `<div class="ih"><span class="ih-tile" style="width:${w*cs}px;height:${h*cs}px">${itemHTML({ ...b, rot:0 },'ii mini')}</span><div class="ih-main"><div class="ih-top">${role}<b class="ih-n" style="color:${TIER_COL[t]}">${it.n}</b><i class="ih-star" style="color:${TIER_COL[t]}">${starsOf(t)}</i></div><div class="ih-meta">${meta}</div><div class="ih-st">${stat}</div></div>
    <span class="ih-btns"><button type="button" data-a="rot" aria-label="돌리기">↻</button><button type="button" data-a="trash" aria-label="버리기">버리기 <i class="px-token"></i>${tokenValue(b)}</button></span></div>`; }
function infoRows(b,st){ const it=GITEMS[b.id], i=GS.bag.indexOf(b), t=b.tier||1, R=[], sk=it.kind==='skill'||it.kind==='dodge';
  if(it.cond) R.push(['조건', COND[it.cond].ko]);
  if(i<0 && sk) R.push(['보류', '서류가방에 넣어야 써요']);
  if(st){ const up=[st.gem&&`부적 ${st.gem}`, st.stone&&`커피 ${st.stone}`, st.pins&&`넥타이핀 ${st.pins}`, st.rings&&`반지 ${st.rings}`, st.metros&&`메트로카드 ${st.metros}`, st.cuffs&&`커프스 ${st.cuffs}`, it.fist&&pv('knuckle',1,0)?'너클':'', st.set?'세트':'', b.emp?'<b class="ok">반격 준비 +50%</b>':''].filter(Boolean);
    for(const tt in (st.imp||{})) up.push(`<span class="${tt==='worn'?'bad':''}">${IMP_NAME[tt]}</span>`);
    if(up.length) R.push(['강화', up.join(' · ')]); }
  if(i>=0){ const nb=adjItems(i), nm=new Map(); for(const o of nb){ const L=linkBetween(b,o); if(L){ if(!nm.has(L.n)) nm.set(L.n,{L,who:[]}); nm.get(L.n).who.push(GITEMS[o.id].n); } }
    if(nm.size) R.push(['연계', [...nm.values()].map(({L,who})=>`<b class="ok">${L.n}</b>(${who.join(' · ')}) ${L.desc}`).join(' / ')]);
    const ch=nb.filter(o=>GITEMS[o.id].kind==='skill'&&it.kind==='skill'&&!linkBetween(b,o)); if(ch.length) R.push(['연쇄', `${ch.map(o=>tr(GITEMS[o.id].n)).join(' · ')} — ${KE(`적중마다 서로 쿨다운 ${Math.round(CHAIN_K(t)*100)}% 충전`,`each hit refills the other's cooldown by ${Math.round(CHAIN_K(t)*100)}%`)}`]);
    if(!sk){ const k=it.kind, sks=GS.bag.filter(o=>o!==b&&(GITEMS[o.id].kind==='skill'||GITEMS[o.id].kind==='dodge'));
      const hit = ['gem','stone','crit','critd'].includes(k) ? nb.filter(o=>sks.includes(o)) : k==='metro' ? sks.filter(o=>dirRel(cellsOf(b),cellsOf(o)).v) : k==='cuff' ? sks.filter(o=>{ const D=dirRel(cellsOf(b),cellsOf(o)); return D.d&&!D.o; }) : null;
      if(hit) R.push(['적용', hit.length ? hit.map(o=>GITEMS[o.id].n).join(' · ') : '<span class="dim">아직 닿은 기술이 없어요</span>']); } }
  if(it.fam && sk) R.push(['계열', inSet(b) ? `<span style="color:${FAMS[it.fam].c}">${FAMS[it.fam].n} 세트 완성</span> · 피해 +20% · 쿨다운 −10%` : `<span style="color:${FAMS[it.fam].c}">${FAMS[it.fam].n}</span> — 같은 계열 3종을 이어 붙이면 세트`]);
  if(b.opt) R.push(['옵션', `<span style="color:${OPTS[b.opt.k].c}">${OPTS[b.opt.k].f(b.opt.v)}</span>`]);
  { const ps=linkPartners(b.id); if(ps.length && !(i>=0 && adjItems(i).some(o=>linkBetween(b,o)))){ const by={}; for(const [pid,n] of ps) (by[n]=by[n]||[]).push(GITEMS[pid].n); R.push(['연계 짝', Object.entries(by).slice(0,2).map(([n,arr])=>`${arr.slice(0,3).join('·')}${arr.length>3?' 외':''}(${n})`).join(' / ')]); } }
  { const C=(GS.contrib||{})[b.uid], R2=(GS.contribRun||{})[b.uid]; if(C||R2){ const a=Math.round((C?C.dmg:0)*DMG_K).toLocaleString(), n=C?C.n:0, r=Math.round((R2?R2.dmg:0)*DMG_K).toLocaleString(); R.push(['기여', KE(`이번 구간 ${a} · ${n}회 · 판 전체 ${r}`,`This leg ${a} · ${n} uses · Run ${r}`)]); } }
  return R; }
function showInfo(uid){ const b=uid!=null&&findAny(uid);
  if(!b){ infoEl.className='iteminfo'; infoEl.innerHTML=`<p class="ii-help">타일을 누르면 자세한 정보가 여기 떠요 · 두 번 누르면 돌리기 · 같은 아이템 · 같은 ★끼리 겹치면 합성</p>`; return; }
  const it=GITEMS[b.id], i=GS.bag.indexOf(b), t=b.tier||1, sk=it.kind==='skill'||it.kind==='dodge';
  const st=i>=0&&sk?sStats(i):null; let nx=null;
  if(sk && t<TIER_MAX){ if(i>=0){ b.tier=t+1; nx=sStats(i); b.tier=t; } else nx={ dmg:(it.dmg||0)*tDmg(t+1), cd:it.cd*tCd(t+1) }; }   // 다음 ★도 지금 배치 그대로 계산
  infoEl.className='iteminfo sel';
  infoEl.innerHTML=`${infoHead(b,st,nx)}<p class="ii-desc">${it.desc}</p><dl class="ii-rows">${infoRows(b,st).map(([k,v])=>`<dt>${k}</dt><dd>${v}</dd>`).join('')}</dl>`;
  infoEl.querySelector('[data-a=rot]').onclick=()=>rotateItem(b);
  infoEl.querySelector('[data-a=trash]').onclick=()=>discardItem(b);
}
function rotateItem(b){ if(!canEdit()) return lockNote(); pushUndo(); sfx.click(); cdReset(b);
  const nr=((b.rot||0)+1)%4;
  if(GS.stash.includes(b)){ for(const [dx,dy] of [[0,0],[-1,0],[0,-1],[-1,-1],[1,0],[0,1],[0,-2],[-1,-2]]) if(canStash(b,b.sx+dx,b.sy+dy,nr,b.uid)){ b.sx+=dx; b.sy+=dy; b.rot=nr; renderBag(); return; }
    say('','보류함에서 돌릴 자리가 모자라요',1.2); return; }
  for(const [dx,dy] of [[0,0],[-1,0],[0,-1],[-1,-1],[1,0],[0,1]]) if(canPlace(b,b.x+dx,b.y+dy,nr,b.uid)){ b.x+=dx; b.y+=dy; b.rot=nr; renderBag(); return; }
  say('','옆 칸을 비우면 돌릴 수 있어요',1.2); }
function discardItem(b){ if(!canEdit()) return lockNote(); pushUndo();
  const v=tokenValue(b); GS.bag=GS.bag.filter(o=>o!==b); GS.stash=GS.stash.filter(o=>o!==b); GS.tokens+=v; GS.selUid=null; renderBag(); say('',`${GITEMS[b.id].n}을(를) 버리고 토큰 ${v}개를 받았어요`,1.4); }
const lockNote=()=>say('','장면이 끝나면 정리할 수 있어요',1.2);
// 합성: 같은 아이템 · 같은 등급. 성공하면 ★+1, 실패하면 재료 하나만 잃는다(단계 유지)
function askMerge(src,dst){ const t=dst.tier||1, p=MERGE_P[t], it=GITEMS[dst.id], i=GS.bag.indexOf(dst), sk=it.kind==='skill'||it.kind==='dodge';
  const box=document.createElement('div'); box.className='inv-merge mg2';
  let chg='';                                                                                                     // ★가 오르면 바뀌는 값(지금 배치 그대로)
  if(sk){ let a0, a1; if(i>=0){ a0=sStats(i); dst.tier=t+1; a1=sStats(i); dst.tier=t; } else { a0={ dmg:(it.dmg||0)*tDmg(t), cd:it.cd*tCd(t) }; a1={ dmg:(it.dmg||0)*tDmg(t+1), cd:it.cd*tCd(t+1) }; }
    const dg=a0.cd.toFixed(1)===a1.cd.toFixed(1)?2:1;                                                            // 소수 첫째 자리가 같으면 둘째 자리까지
    chg=`${it.dmg?`<em class="dm">${SV_SW}${fmtD(a0.dmg)} → <b>${fmtD(a1.dmg)}</b></em>`:''}<em class="ct">${SV_CK}${a0.cd.toFixed(dg)} → <b>${a1.cd.toFixed(dg)}</b>${SEC_U()}</em>`; }
  else { const S0=tileStats(dst), S1=tileStats({ ...dst, tier:t+1 }); chg=S0.val?`<em style="color:${S0.vc}">${S0.val} → <b>${S1.val}</b></em>`:'<em>등급마다 효과가 커져요</em>'; }
  const OF=o=>tr(OPTS[o.k].f(o.v)), optLine = src.opt ? (dst.opt ? (dst.opt.k===src.opt.k ? `${KE('같은 옵션이라 절반이 더해져요','Same option — half of it adds on')} · <span style="color:${OPTS[src.opt.k].c}">${OF(dst.opt)} → ${OF({ k:dst.opt.k, v:Math.min(OPTS[dst.opt.k].cap, Math.round((dst.opt.v+src.opt.v*.5)*100)/100) })}</span>` : KE(`재료 옵션(${OF(src.opt)})은 사라져요 — 지금 옵션 유지`,`The other copy's ${OF(src.opt)} is lost — current option stays`)) : `<span style="color:${OPTS[src.opt.k].c}">${OF(src.opt)}</span> ${KE('옵션이 넘어와요','carries over')}`) : '';
  const fake={ ...dst, rot:0 }, {w,h}=itemBox(fake,0), cs=12, canBoost=GS.tokens>=BOOST_COST;
  box.innerHTML=`<div class="mg-h"><span class="mg-tile" style="width:${w*cs}px;height:${h*cs}px">${itemHTML(fake,'ii mini')}</span><div><b class="mg-n">${it.n}</b><div class="mg-t"><span style="color:${TIER_COL[t]}">★${t}</span> → <span style="color:${TIER_COL[t+1]}">★${t+1}</span> 합성</div></div></div>
    <div class="mg-chg">${chg}</div>${optLine?`<p class="mg-opt">${optLine}</p>`:''}
    <div class="mg-p"><span>성공</span><i class="mg-bar"><i style="width:${Math.round(p*100)}%"></i></i><b class="pp">${Math.round(p*100)}%</b></div>
    <p class="mg-fail">실패하면 재료 하나를 잃고 토큰 1개를 돌려받아요 · ★는 그대로</p>
    <label class="mg-boost${canBoost?'':' off'}"><span>${KE(`토큰 ${BOOST_COST}개로 성공 +${Math.round(MERGE_BOOST*100)}%`,`+${Math.round(MERGE_BOOST*100)}% success for ${BOOST_COST} tokens`)} <small>${KE('보유','have')} ${GS.tokens}</small></span><input type="checkbox" class="sw" ${canBoost?'':'disabled'}></label>
    <div class="mg-act"><button type="button" data-a="no">그만두기</button><button type="button" data-a="go">합성하기 <b class="pp2">${Math.round(p*100)}%</b></button></div>`;
  const br=bagEl.getBoundingClientRect(), bw=Math.min(br.width*.88, 340); box.style.width=bw+'px'; box.style.left=(br.left+(br.width-bw)/2)+'px'; box.style.top=Math.max(8, br.top+br.height*.1)+'px';
  document.querySelectorAll('.inv-merge').forEach(n=>n.remove()); document.body.appendChild(box);          // 가방을 다시 그려도 사라지지 않게 화면 위에
  const cb=box.querySelector('input'), upd=()=>{ const q=Math.round(Math.min(.95,p+(cb.checked?MERGE_BOOST:0))*100)+'%'; box.querySelector('.pp').textContent=q; box.querySelector('.pp2').textContent=q; box.querySelector('.mg-bar i').style.width=q; }; cb.onchange=upd;
  box.querySelector('[data-a=no]').onclick=()=>box.remove();
  box.querySelector('[data-a=go]').onclick=()=>{ pushUndo(); const boost=cb.checked&&GS.tokens>=BOOST_COST; if(boost) GS.tokens-=BOOST_COST; box.remove();
    const ok=Math.random()<Math.min(.95,p+(boost?MERGE_BOOST:0)); GS.bag=GS.bag.filter(o=>o!==src); GS.stash=GS.stash.filter(o=>o!==src);
    sfx.merge(ok); if(ok) metaItem(dst.id,t+1); else GS.tokens+=1;                                                   // 실패해도 토큰 1개
    if(ok){ dst.tier=t+1; GS.stats.merges=(GS.stats.merges||0)+1; cdReset(dst);
      if(src.opt){ if(!dst.opt) dst.opt={...src.opt}; else if(dst.opt.k===src.opt.k) dst.opt.v=Math.min(OPTS[dst.opt.k].cap, Math.round((dst.opt.v+src.opt.v*.5)*100)/100); } } else GS.stats.mergeFails=(GS.stats.mergeFails||0)+1;
    GS.selUid=dst.uid; renderBag(); const el=bagEl.querySelector(`.ii[data-uid="${dst.uid}"]`); if(el){ el.classList.add(ok?'fx-ok':'fx-bad'); }
    say(ok?'합성 성공!':'합성 실패', ok?`${GITEMS[dst.id].n} ★${t+1}`:`재료를 잃었지만 토큰 1개를 돌려받았어요. ${GITEMS[dst.id].n}은(는) ★${t} 그대로`, 1.8); };
}
// 끌어 놓기: 격자 위 칸 맞춤 미리보기(초록/빨강) · 휴지통 · 보류함 · 같은 아이템 위면 합성. R 키로 회전
function gridCellAt(px,py){ const g=bagEl.querySelector('.inv-grid'); if(!g) return null; const r=g.getBoundingClientRect(); return { x:(px-r.left)/(r.width/INV.W), y:(py-r.top)/(r.height/INV.H), r }; }
// =========================================================
// 가방 1단계 UX: 놓기 전 미리보기 · 회전 버튼 · 되돌리기 · 손가락 위로 띄운 고스트
// =========================================================
const UNDO_MAX=20;
function pushUndo(){ if(!canEdit()) return; GS.undo=GS.undo||[]; GS.undo.push(JSON.stringify({ bag:GS.bag, stash:GS.stash, tokens:GS.tokens, sel:GS.selUid })); if(GS.undo.length>UNDO_MAX) GS.undo.shift(); }
function doUndo(){ if(!canEdit()||!GS.undo||!GS.undo.length) return; const S=JSON.parse(GS.undo.pop()); GS.bag=S.bag; GS.stash=S.stash; GS.tokens=S.tokens; GS.selUid=S.sel; sfx.click(); renderBag(); say('','되돌렸어요',1); }
function bagPower(){ let s=0; GS.bag.forEach((b,i)=>{ if(GITEMS[b.id].kind!=='skill') return; const st=sStats(i); s+=st.dmg/Math.max(.3,st.cd)*(1+st.crit*Math.max(0,(st.critD||1.5)-1)); }); return s; }
function linkNamesOf(b){ const out=new Set(), i=GS.bag.indexOf(b); if(i<0) return out; for(const o of adjItems(i)){ const L=linkBetween(b,o); if(L) out.add(L.n); } return out; }
function previewPlace(b,tx,ty,rot){ const inBag=GS.bag.includes(b), o={x:b.x,y:b.y,rot:b.rot}, sk=GITEMS[b.id].kind==='skill';
  computeSets(); const p0=bagPower(), s0={...GS.sets}, l0=inBag?linkNamesOf(b):new Set(), st0=inBag&&sk?sStats(GS.bag.indexOf(b)):null;
  b.x=tx; b.y=ty; b.rot=rot; if(!inBag) GS.bag.push(b);
  const s1=computeSets(), p1=bagPower(), l1=linkNamesOf(b), st1=sk?sStats(GS.bag.indexOf(b)):null;
  Object.assign(b,o); if(!inBag) GS.bag.pop(); computeSets();
  return { dp:p0>0?p1/p0-1:(p1>0?1:0), st0, st1, newL:[...l1].filter(n=>!l0.has(n)), newS:Object.keys(s1).filter(f=>!s0[f]), imp:impAt(b,tx,ty,rot) }; }
const prevEl=(()=>{ const d=document.createElement('div'); d.className='inv-prev'; d.hidden=true; document.body.appendChild(d); return d; })();
const rotFab=(()=>{ const d=document.createElement('button'); d.type='button'; d.className='inv-rotfab'; d.textContent='↻'; d.hidden=true; d.setAttribute('aria-label','회전'); document.body.appendChild(d);
  d.addEventListener('pointerdown',e=>{ e.stopPropagation(); e.preventDefault(); if(drag&&drag.ghost) rotDrag(); }); return d; })();
function rotDrag(){ if(!drag||!drag.ghost) return; drag.rot=(drag.rot+1)%4; const {w,h}=itemBox(drag.b,drag.rot); drag.gx=Math.min(drag.gx,w-1); drag.gy=Math.min(drag.gy,h-1); drag.pk=null; sizeGhost(); moveGhost(drag.px,drag.py); sfx.click(); }
function showPreview(){ const d=drag; if(!d||!d.ghost){ prevEl.hidden=true; return; }
  const gr=d.ghost.getBoundingClientRect(); prevEl.style.left=Math.max(4,gr.left)+'px'; prevEl.style.top=Math.max(4,gr.top-6)+'px';
  const key=d.tx+','+d.ty+','+d.rot+','+(d.mergeT?d.mergeT.uid:'');
  if(key===d.pk){ prevEl.hidden=false; return; } d.pk=key;
  const fmt=v=>Math.round(v*DMG_K).toLocaleString();
  if(d.mergeT){ const t=d.mergeT.tier||1; prevEl.innerHTML=`<b class="pv-m">합성 ★${t} → ★${t+1}</b><span>성공 ${Math.round(MERGE_P[t]*100)}% · 실패해도 토큰 1개</span>`; prevEl.className='inv-prev merge'; prevEl.hidden=false; return; }
  if(d.inPocket){ const key2='P'+d.ptx+','+d.pty+','+d.rot; if(key2===d.pk2){ prevEl.hidden=false; return; } d.pk2=key2; d.pk=null;
    const ok0=canStash(d.b,d.ptx,d.pty,d.rot,d.b.uid), alt=!ok0&&GS.bag.includes(d.b)&&stashSpot(d.b,d.rot), ok=ok0||!!alt, lines=[ok0?`<b class="pv-eq">${tr('보류함에 잠시 두기')}</b>`:alt?`<b class="pv-eq">${tr('보류함 빈 곳에 두기')}</b>`:`<b class="pv-bad">${tr('보류함에 자리가 모자라요')}</b>`];
    if(ok && GS.bag.includes(d.b)){ const hyp=GS.bag.filter(o=>o!==d.b); try{ const L=bagEl.querySelector('.rt-layer'); if(L) L.outerHTML=routeLayer(hyp); for(const o of routesOf(GS.bag)) if(!routesOf(hyp).find(q=>q.key===o.key)) lines.push(`<span class="pv-dn">${tr(o.name)} ${tr('끊김')}</span>`); }catch(e){} if(GITEMS[d.b.id].kind==='skill') lines.push(`<span class="pv-dn">${tr('가방에서 빠지면 쓰지 않아요')}</span>`); }
    prevEl.innerHTML=lines.join(''); prevEl.className='inv-prev'+(ok?'':' bad'); prevEl.hidden=false; prevClamp(); return; }
  d.pk2=null;
  if(d.tx==null || !d.inGrid){ prevEl.hidden=true; const L0=bagEl.querySelector('.rt-layer'); if(L0) L0.outerHTML=routeLayer(GS.bag); return; }
  if(!canPlace(d.b,d.tx,d.ty,d.rot,d.b.uid)){ prevEl.innerHTML='<b class="pv-bad">여기엔 자리가 모자라요</b>'; prevEl.className='inv-prev bad'; prevEl.hidden=false; return; }
  const P=previewPlace(d.b,d.tx,d.ty,d.rot), pct=Math.round(P.dp*100), lines=[];
  lines.push(`<b class="${pct>0?'pv-up':pct<0?'pv-dn':'pv-eq'}">가방 화력 ${pct>0?'+':''}${pct}%</b>`);
  if(P.st1) lines.push(P.st0 ? `<span>피해 ${fmt(P.st0.dmg)}→${fmt(P.st1.dmg)} · 쿨 ${P.st0.cd.toFixed(1)}→${P.st1.cd.toFixed(1)}초</span>` : `<span>피해 ${fmt(P.st1.dmg)} · 쿨 ${P.st1.cd.toFixed(1)}초</span>`);
  for(const n of P.newL) lines.push(`<span class="pv-l">새 연계: ${n}</span>`); for(const f of P.newS) lines.push(`<span class="pv-l">${FAMS[f].n} 세트 완성!</span>`);
  for(const t in P.imp) lines.push(`<span class="${t==='worn'?'pv-dn':'pv-i'}">각인 · ${IMP_NAME[t]}: ${IMP_DESC[t].replace('이 칸에 걸친 기술 ','')}</span>`);
  try{ const hyp=GS.bag.filter(o=>o!==d.b).concat([{ ...d.b, x:d.tx, y:d.ty, rot:d.rot }]), R0=routesOf(GS.bag), R1=routesOf(hyp);   // 콤보 경로 미리보기
    const L=bagEl.querySelector('.rt-layer'); if(L) L.outerHTML=routeLayer(hyp);
    for(const r of R1){ const o=R0.find(q=>q.items[0].uid===r.items[0].uid); if(!o) lines.push(`<span class="pv-c" style="--rc:${r.col}">${tr('새 콤보')}: ${tr(r.name)}</span>`); else if(o.key!==r.key) lines.push(`<span class="pv-c" style="--rc:${r.col}">${tr(o.name)} → ${tr(r.name)}</span>`); }
    for(const o of R0) if(!R1.find(q=>q.items[0].uid===o.items[0].uid)) lines.push(`<span class="pv-dn">${tr(o.name)} ${tr('끊김')}</span>`); }catch(e){}
  prevEl.innerHTML=lines.join(''); prevEl.className='inv-prev'; prevEl.hidden=false; prevClamp(); }
function prevClamp(){ const w=prevEl.offsetWidth, x=parseFloat(prevEl.style.left)||0; if(x+w>innerWidth-4) prevEl.style.left=Math.max(4,innerWidth-4-w)+'px'; }
window.addEventListener('wheel',e=>{ if(drag&&drag.ghost){ e.preventDefault(); rotDrag(); } },{passive:false});

bagEl.addEventListener('pointerdown',e=>{ bagTouch(); { const fk=e.target.closest('.rt-fork'); if(fk){ e.preventDefault(); e.stopPropagation(); const a=findAny(+fk.dataset.pf), t=+fk.dataset.pt; if(a){ a.pin = a.pin===t ? null : t; sfx.click(); renderBag(); } return; } }   /* 갈림길 고정 핀 */
  { const q=e.target.closest('.iq'); if(q){ const qb=findAny(+q.dataset.uid); if(qb){ GS.selUid=qb.uid; sfx.click(); renderBag(); } return; } }   /* 준비 순서 줄: 눌러서 정보 보기 */
  const el=e.target.closest('.ii'); if(!el) return; const b=findAny(+el.dataset.uid); if(!b) return;
  GS.selUid=b.uid; const r=el.getBoundingClientRect(), {w,h}=itemBox(b);
  drag={ b, sx:e.clientX, sy:e.clientY, gx:Math.max(0,Math.min(w-1,Math.floor((e.clientX-r.left)/(r.width/w)))), gy:Math.max(0,Math.min(h-1,Math.floor((e.clientY-r.top)/(r.height/h)))), rot:b.rot||0, moved:false, ghost:null, pid:e.pointerId, lift:e.pointerType==='touch'?1:0 };
  bagEl.setPointerCapture(e.pointerId); });
bagEl.addEventListener('pointermove',e=>{ if(!drag || e.pointerId!==drag.pid) return;
  if(!drag.moved && Math.hypot(e.clientX-drag.sx,e.clientY-drag.sy)>6){ if(!canEdit()){ drag=null; lockNote(); return; } drag.moved=true; makeGhost(); }
  if(drag.ghost) moveGhost(e.clientX,e.clientY); });
const tr_=t=>(typeof tr==='function'?tr(t):t);
function pocketCellAt(px,py){ const g=bagEl.querySelector('.inv-pocket'); if(!g) return null; const r=g.getBoundingClientRect(); if(!r.width) return null; return { x:(px-r.left)/(r.width/INV.SW), y:(py-r.top)/(r.height/INV.SH) }; }
function pocketAim(px,py){ const d=drag; d.inPocket=false; const c=pocketCellAt(px,py); if(!c || c.x<-.25 || c.y<-.25 || c.x>INV.SW+.25 || c.y>INV.SH+.25) return;
  const f=stFoot(d.b,d.rot), gx=Math.min(d.gx,f.w-1), gy=Math.min(d.gy,f.h-1); d.inPocket=true; d.ptx=Math.max(0,Math.min(INV.SW-f.w,Math.round(c.x-gx-.5))); d.pty=Math.max(0,Math.min(INV.SH-f.h,Math.round(c.y-gy-.5))); }
function makeGhost(){ const g=document.createElement('div'); g.className='inv-ghost'; g.innerHTML=itemHTML(drag.b,'ii',drag.rot); document.body.appendChild(g); drag.ghost=g; sizeGhost();
  { const tr=bagEl.querySelector('.inv-trash'); if(tr) tr.classList.add('armed'); } bagEl.classList.add('dragging');                // 끄는 동안 오른쪽 칸은 보류함
  const br=bagEl.getBoundingClientRect(), ft=bagEl.querySelector('.inv-foot'), fr=ft?ft.getBoundingClientRect():br; rotFab.style.left=(br.left+10)+'px'; rotFab.style.top=(Math.min(innerHeight-70,fr.top-6))+'px'; rotFab.hidden=false; }   // 두 번째 손가락으로 누르는 회전 버튼(휴지통을 가리지 않게 왼쪽 아래)
function sizeGhost(){ const gr=bagEl.querySelector('.inv-grid').getBoundingClientRect(), cs=gr.width/INV.W, {w,h}=itemBox(drag.b,drag.rot); drag.ghost.style.width=w*cs+'px'; drag.ghost.style.height=h*cs+'px'; drag.cs=cs;
  drag.ghost.innerHTML=itemHTML(drag.b,'ii',drag.rot); rtSuggest(); }
function moveGhost(px,py){ drag.px=px; drag.py=py; const cs=drag.cs, ly=(drag.lift||0)*cs; drag.ghost.style.left=(px-(drag.gx+.5)*cs)+'px'; drag.ghost.style.top=(py-ly-(drag.gy+.5)*cs)+'px';   // 터치: 손가락 위로 한 칸
  const c=gridCellAt(px,py-ly), tx=Math.round(c.x-drag.gx-.5), ty=Math.round(c.y-drag.gy-.5); drag.tx=tx; drag.ty=ty;
  { const under=document.elementFromPoint(px,py-ly), tEl=under&&under.closest&&under.closest('.ii'), tg=tEl&&findAny(+tEl.dataset.uid);
    drag.mergeT = (tg && tg!==drag.b && tg.id===drag.b.id && (tg.tier||1)===(drag.b.tier||1) && (tg.tier||1)<TIER_MAX && (GS.bag.includes(tg)||GS.stash.includes(tg))) ? tg : null; }
  drag.inGrid=c.x>=0&&c.y>=0&&c.x<INV.W&&c.y<INV.H; pocketAim(px,py-ly); showPreview();
  { const tr=bagEl.querySelector('.inv-trash'), u2=document.elementFromPoint(px,py-ly), on=!!(u2&&u2.closest&&u2.closest('.inv-trash'));
    if(tr && tr.classList.contains('hot')!==on){ tr.classList.toggle('hot',on); const sm=tr.querySelector('small'); if(sm) sm.textContent = on ? tr_(`+${tokenValue(drag.b)} 토큰`) : tr_('버리기'); if(drag.ghost) drag.ghost.classList.toggle('to-trash',on); }
    if(on) prevEl.hidden=true; }
  bagEl.querySelectorAll('.gc.ok,.gc.bad,.pk.ok,.pk.bad').forEach(n=>n.classList.remove('ok','bad'));
  if(drag.inPocket && !drag.mergeT){ const ok=canStash(drag.b,drag.ptx,drag.pty,drag.rot,drag.b.uid), P=bagEl.querySelectorAll('.pk'); for(const [x,y] of stCells(drag.b,drag.ptx,drag.pty,drag.rot)){ if(x<0||y<0||x>=INV.SW||y>=INV.SH) continue; const n=P[y*INV.SW+x]; if(n) n.classList.add(ok?'ok':'bad'); } return; }
  const inGrid=c.x>=0&&c.y>=0&&c.x<INV.W&&c.y<INV.H; if(!inGrid) return; const ok=canPlace(drag.b,tx,ty,drag.rot,drag.b.uid);
  for(const [x,y] of cellsOf(drag.b,tx,ty,drag.rot)){ const n=bagEl.querySelectorAll('.gc')[y*INV.W+x]; if(n && x>=0&&x<INV.W) n.classList.add(ok?'ok':'bad'); } }
window.addEventListener('keydown',e=>{ if(drag&&drag.ghost&&(e.key==='r'||e.key==='R')) rotDrag(); });
let lastTap={uid:null,t:0};
bagEl.addEventListener('pointerup',e=>{ if(!drag || e.pointerId!==drag.pid) return; const d=drag; drag=null; if(d.ghost) d.ghost.remove(); prevEl.hidden=true; rotFab.hidden=true;
  const ly=(d.lift||0)*(d.cs||0);
  if(!d.moved && GS.stash.includes(d.b) && d.b.isNew && canEdit()){ quickEquip(d.b.uid); return; }                  // 새 장비: 한 번 탭으로 빈자리에
  if(!d.moved){ const now=performance.now(); if(lastTap.uid===d.b.uid && now-lastTap.t<350){ rotateItem(d.b); lastTap.uid=null; } else { lastTap={uid:d.b.uid,t:now}; renderBag(); } return; }
  const under=document.elementFromPoint(e.clientX,e.clientY-(d.moved?ly:0));
  if(under && under.closest('.inv-trash')){ discardItem(d.b); return; }
  const tgtEl=under && under.closest('.ii'); const tgt=tgtEl && findAny(+tgtEl.dataset.uid);
  if(tgt && tgt!==d.b && tgt.id===d.b.id && (tgt.tier||1)===(d.b.tier||1) && (tgt.tier||1)<TIER_MAX && (GS.bag.includes(tgt)||GS.stash.includes(tgt))){ askMerge(d.b,tgt); renderBag(); return; }
  drag=d; pocketAim(e.clientX,e.clientY-ly); drag=null;
  if(d.inPocket){ const fromBag=GS.bag.includes(d.b);                                                           // 보류함: 모양 · 자리 · 방향 그대로
    let sp = canStash(d.b,d.ptx,d.pty,d.rot,d.b.uid) ? { sx:d.ptx, sy:d.pty, rot:d.rot } : fromBag ? stashSpot(d.b,d.rot) : null;
    if(sp){ pushUndo(); sfx.click(); if(fromBag){ GS.bag=GS.bag.filter(o=>o!==d.b); GS.stash.push(d.b); } Object.assign(d.b,sp); }
    else if(fromBag) say('','보류함에 자리가 모자라요',1.2);
    renderBag(); return; }
  if(d.tx!=null && canPlace(d.b,d.tx,d.ty,d.rot,d.b.uid)){ pushUndo(); sfx.click(); cdReset(d.b); d.b.isNew=false; d.b.x=d.tx; d.b.y=d.ty; d.b.rot=d.rot; if(GS.stash.includes(d.b)){ GS.stash=GS.stash.filter(o=>o!==d.b); GS.bag.push(d.b); } }
  renderBag(); });
bagEl.addEventListener('pointercancel',e=>{ if(drag && e.pointerId!==drag.pid) return; if(drag&&drag.ghost) drag.ghost.remove(); drag=null; prevEl.hidden=true; rotFab.hidden=true; bagEl.classList.remove('dragging'); renderBag(); });
function updateBagCD(){
  const H=GS.hero, F=foes().filter(a=>a.anim!=='death'&&!a.held), T=H?F.filter(a=>!isDown(a)).sort((a,b)=>Math.abs(a.d.x-H.d.x)-Math.abs(b.d.x-H.d.x))[0]:null;
  const lock=!canEdit(); if(bagEl.classList.contains('locked')!==lock) renderBag();
  bagEl.querySelectorAll('.inv-grid .ii').forEach(el=>{ const i=GS.bag.findIndex(b=>b.uid===+el.dataset.uid); if(i<0) return; const b=GS.bag[i], it=GITEMS[b.id], cd=el.querySelector('.cd');
    const full=(it.kind==='skill'||it.kind==='dodge') ? sStats(i).cd : it.kind==='heal' ? it.cd-((b.tier||1)-1) : 0, filled=!!full && b.t>=full;
    const wait = filled && it.cond && H && !condOK(it.cond,H,T,F);
    if(cd) cd.style.width = full ? Math.round(Math.min(1,b.t/full)*100)+'%' : '0%';
    { const k = full ? 1-Math.min(1,b.t/full) : 0; el.querySelectorAll('.cdo').forEach(o=>{ const hh=+o.dataset.h, y=+o.dataset.cy; o.style.setProperty('--d', Math.max(0,Math.min(1,k*hh-y)).toFixed(3)); }); }
    el.classList.toggle('ready', filled && !wait); el.classList.toggle('waiting', !!wait); el.classList.toggle('syn', !!(it.kind==='skill' && (sStats(i).gem||sStats(i).stone||sStats(i).pins||sStats(i).rings))); });
  const tk=bagEl.querySelector('.inv-tok'); if(tk) tk.innerHTML=`<i class="px-token"></i>${GS.tokens}`;
  { const tab=bagTab(), R=bagEl.querySelector('.inv-right'); if(R && bagEl.dataset.tab!==tab){ bagEl.dataset.tab=tab; R.classList.toggle('show-q',tab==='q'); bagEl.querySelectorAll('.ir-tab').forEach(t=>t.classList.toggle('on',t.dataset.t===tab)); }   // 전투가 시작 · 끝나면 오른쪽 칸 전환
    const Q=bagEl.querySelector('.inv-queue'); if(Q && tab==='q' && !bagEl.classList.contains('dragging')){ const rows=qRows(), sig=rows.map(r=>r.b.uid+(r.p>=1?'r':'')+(r.wait?'w':'')).join(',');
      if(sig!==bagEl._qsig){ bagEl._qsig=sig; Q.innerHTML=queueHTML(rows); }
      else { const els=Q.querySelectorAll('.iq'); rows.forEach((r,k)=>{ const f=els[k]&&els[k].querySelector('.qb > i'); if(f) f.style.width=Math.round(r.p*100)+'%'; }); } } }
}

