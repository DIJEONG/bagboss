// 테트리스형 가방: 6×4. 아이템은 모양(shape)만큼 칸을 차지하고 90°씩 돌릴 수 있다. 같은 아이템 · 같은 등급끼리 합성(확률)으로 ★5까지
const INV={ W:6, H:4, SW:2, SH:4 }, TIER_MAX=5, MERGE_P=[0,.85,.65,.45,.30], MERGE_BOOST=.15, BOOST_COST=3, REROLL_COST=2;
const tDmg=t=>1+.3*((t||1)-1), tCd=t=>1-.06*((t||1)-1);
function shapeOf(id,rot){ let c=GITEMS[id].shape||[[0,0]]; for(let r=0;r<((rot||0)%4+4)%4;r++) c=c.map(([x,y])=>[-y,x]);
  const mx=Math.min(...c.map(p=>p[0])), my=Math.min(...c.map(p=>p[1])); return c.map(([x,y])=>[x-mx,y-my]); }
const cellsOf=(b,x=b.x,y=b.y,rot=b.rot)=>shapeOf(b.id,rot).map(([dx,dy])=>[x+dx,y+dy]);
function occMap(exUid){ const m=new Map(); for(const b of GS.bag){ if(b.uid===exUid) continue; for(const [x,y] of cellsOf(b)) m.set(x+','+y,b); } return m; }
function canPlace(b,x,y,rot,exUid){ const m=occMap(exUid??b.uid); return cellsOf(b,x,y,rot).every(([cx,cy])=>cx>=0&&cy>=0&&cx<INV.W&&cy<INV.H&&!m.has(cx+','+cy)); }
function adjItems(i){ const b=GS.bag[i]; if(!b) return []; const mine=new Set(cellsOf(b).map(([x,y])=>x+','+y)), out=[];
  for(const o of GS.bag){ if(o===b) continue; if(cellsOf(o).some(([x,y])=>mine.has((x+1)+','+y)||mine.has((x-1)+','+y)||mine.has(x+','+(y+1))||mine.has(x+','+(y-1)))) out.push(o); } return out; }
function fitBag(){ const all=GS.bag.slice(); GS.bag=[]; for(const b of all){ if(canPlace(b,b.x,b.y,b.rot||0,b.uid)){ GS.bag.push(b); continue; } const sp=findSpot(b); if(sp){ Object.assign(b,sp); GS.bag.push(b); } else if(!stashPut(b)) GS.tokens+=tokenValue(b); } }
function findSpot(b){ for(const rot of [b.rot||0,((b.rot||0)+1)%4,((b.rot||0)+2)%4,((b.rot||0)+3)%4]) for(let y=0;y<INV.H;y++) for(let x=0;x<INV.W;x++) if(canPlace(b,x,y,rot,b.uid)) return {x,y,rot}; return null; }
const sizeOf=id=>(GITEMS[id].shape||[[0,0]]).length, tokenValue=b=>sizeOf(b.id)*(b.tier||1);
// 보류함(2×4): 아이템은 모양 · 자리(sx, sy) · 방향을 그대로 지닌다. 폭이 2를 넘는 방향은 2×2로 접어서 둔다
function stFoot(b,rot){ const {w,h}=itemBox(b,rot); return w<=INV.SW&&h<=INV.SH ? { w, h, fold:false } : { w:2, h:2, fold:true }; }
function stCells(b,x,y,rot){ const f=stFoot(b,rot); if(!f.fold) return cellsOf(b,x,y,rot); return [[x,y],[x+1,y],[x,y+1],[x+1,y+1]]; }
function stOcc(exUid){ const m=new Map(); for(const o of GS.stash){ if(o.uid===exUid||o.sx==null) continue; for(const [x,y] of stCells(o,o.sx,o.sy,o.rot||0)) m.set(x+','+y,o); } return m; }
function canStash(b,x,y,rot,exUid){ const m=stOcc(exUid??b.uid); return stCells(b,x,y,rot).every(([cx,cy])=>cx>=0&&cy>=0&&cx<INV.SW&&cy<INV.SH&&!m.has(cx+','+cy)); }
function stashSpot(b,rot0){ const r0=rot0??(b.rot||0), R=[r0,(r0+1)%4,(r0+2)%4,(r0+3)%4];
  for(const pass of [0,1]) for(const rot of R){ if(stFoot(b,rot).fold!==!!pass) continue; for(let y=0;y<INV.SH;y++) for(let x=0;x<INV.SW;x++) if(canStash(b,x,y,rot,b.uid)) return { sx:x, sy:y, rot }; }
  return null; }
// 빈 곳이 없으면 큰 것부터 다시 채워 본다(실패하면 그대로 두고 false)
function stashPut(it){ const sp=stashSpot(it); if(sp){ Object.assign(it,sp); if(!GS.stash.includes(it)) GS.stash.push(it); return true; }
  const prev=GS.stash.filter(o=>o!==it), save=prev.map(o=>[o,o.sx,o.sy,o.rot]); GS.stash=[];
  for(const o of prev.concat([it]).sort((a,b)=>sizeOf(b.id)-sizeOf(a.id))){ const q=stashSpot(o); if(!q){ GS.stash=prev; for(const [o2,x,y,r] of save){ o2.sx=x; o2.sy=y; o2.rot=r; } return false; } Object.assign(o,q); GS.stash.push(o); }
  return true; }
function normStash(){ const all=GS.stash, bad=[]; GS.stash=[];
  for(const b of all){ if(b.sx!=null && canStash(b,b.sx,b.sy,b.rot||0,b.uid)) GS.stash.push(b); else bad.push(b); }
  for(const b of bad){ if(stashPut(b)) continue; const sp=findSpot(b); if(sp){ Object.assign(b,sp); GS.bag.push(b); continue; } GS.tokens+=tokenValue(b); say('', `보류함에 자리가 없어 ${GITEMS[b.id].n}을(를) 토큰 ${tokenValue(b)}개로 바꿨어요`, 1.8); } }
const OPTS={ crit:{ n:'치명', c:'#ff6a6a', lo:.08, hi:.14, cap:.35, f:v=>`치명 +${Math.round(v*100)}%` }, critd:{ n:'치피', c:'#ffa04a', lo:.25, hi:.45, cap:1.0, f:v=>`치명 피해 +${Math.round(v*100)}%` },
  dmg:{ n:'피해', c:'#ffd34a', lo:.10, hi:.18, cap:.45, f:v=>`피해 +${Math.round(v*100)}%` }, cd:{ n:'쿨', c:'#62a8ee', lo:.06, hi:.12, cap:.3, f:v=>`쿨다운 −${Math.round(v*100)}%` } };
function rollOpt(id,p,Rr=Math.random){ if(GITEMS[id].kind!=='skill' || Rr()>=p) return null; const ks=Object.keys(OPTS), k=ks[Math.floor(Rr()*ks.length)], O=OPTS[k];
  return { k, v:Math.round((O.lo+Rr()*(O.hi-O.lo))*100)/100 }; }
const optTag=o=>o?`${OPTS[o.k].n}${o.k==='cd'?'−':'+'}${Math.round(o.v*100)}`:'';
const CRIT_BASE=.08, CRITD_BASE=1.6;
const newItem=(id,tier=1,opt=null)=>({ id, tier, uid:++GS.uid, t:0, rot:0, opt });
// 보조 아이템 효과: 같은 종류를 모두 더하되 등급마다 커진다
const pv=(kind,base,per)=>GS.bag.filter(b=>GITEMS[b.id].kind===kind).reduce((a,b)=>a+base+per*((b.tier||1)-1),0);
function addToStash(id,tier=1,note,opt=null){ const it=newItem(id,tier,opt); metaItem(id,tier);
  if(!stashPut(it)){ GS.tokens+=tokenValue(it); if(note) say('', `보류함이 가득 차 ${GITEMS[id].n}을(를) 토큰 ${tokenValue(it)}개로 바꿨어요`, 1.8); return null; }
  onboardItem(id); return it; }
function onboardItem(id){ try{ META.flags=META.flags||{}; const r=croleOf(id), F=META.flags;   // 첫 시작기 · 첫 마무리기 안내(한 번씩)
  if(GS.pBag) return; if(r==='F') talkSoon('fin', TALK.finisher); else if(r==='S') talkSoon('st', TALK.starter); }catch(e){} }
function autoPack(){ let n=0; for(const it of GS.stash.slice().sort((a,b)=>sizeOf(b.id)-sizeOf(a.id))){ const sp=findSpot(it); if(sp){ Object.assign(it,sp); GS.bag.push(it); GS.stash.splice(GS.stash.indexOf(it),1); n++; } } GS.hero&&(GS.hero.pick=null); renderBag(); return n; }
// 연계: ① 연쇄(닿은 기술끼리 적중 시 쿨다운 충전) ② 이름 붙은 연계(특정 조합) ③ 계열 세트(같은 계열 3종이 한 덩어리)
const CHAIN_K=t=>.15+.04*((t||1)-1);
const KNOCKERS=['kick','round','case','sweep','charge','throw'];
const LINKS=[
  { id:'down',  n:'눕히고 밟기',      a:id=>KNOCKERS.includes(id), b:id=>id==='stomp', on:'knock', desc:'넘어뜨리면 닿은 밟기가 바로 준비' },
  { id:'air',   n:'띄우고 차기',      a:id=>id==='upper'||id==='skick', b:id=>id==='round'||id==='kick'||id==='fkick', on:'launch', desc:'띄우면 닿은 발차기가 바로 준비' },
  { id:'grab',  n:'접고 메치기',      a:id=>id==='knee', b:id=>id==='throw', on:'hit', desc:'니킥이 맞으면 닿은 메치기가 바로 준비' },
  { id:'rush',  n:'받아치고 몰아치기', a:id=>id==='elbow', b:id=>id==='punch', on:'hit', desc:'받아치기 뒤 닿은 주먹 콤보가 훅부터 바로' },
  { id:'flank', n:'앞뒤 협공', a:id=>GITEMS[id].kind==='skill'&&!GITEMS[id].back, b:id=>!!GITEMS[id].back, on:'hit', desc:'앞을 치면 닿은 뒤 공격이 바로 준비(뒤에 적이 있으면 이어서 친다)' },
  { id:'flank2', n:'앞뒤 협공', a:id=>!!GITEMS[id].back, b:id=>GITEMS[id].kind==='skill'&&!GITEMS[id].back, on:'hit', desc:'뒤를 치면 닿은 앞 기술이 바로 준비' },
  { id:'dodge', n:'피하고 반격',      a:id=>id==='duck', b:id=>GITEMS[id].kind==='skill', on:'dodge', desc:'피하면 닿은 기술이 바로 준비되고 다음 한 방 +50%' },
  { id:'scoop', n:'걸고 퍼올리기',    a:id=>id==='sweep', b:id=>id==='upper'||id==='punch', on:'trip', desc:'다리걸기로 걸면 닿은 어퍼가 준비 — 넘어지는 적을 몸을 낮춰 퍼 올린다' },
  { id:'crumple', n:'무너뜨리기',     a:id=>id==='knee', b:id=>id==='upper'||id==='punch', on:'hit', desc:'니킥이 배를 꺾어 1초 무방비로 무너뜨리고, 닿은 주먹이 바로 준비' },
  { id:'airgrab', n:'공중 잡아 꽂기', a:id=>id==='upper'||id==='punch'||id==='skick', b:id=>id==='throw', on:'launch', desc:'띄우면 닿은 메치기가 준비 — 공중 콤보 끝에 뛰어 잡아 바닥에 꽂는다' },
  { id:'spinout', n:'돌려 세우기',    a:id=>id==='punch', b:id=>GITEMS[id].kind==='skill'&&id!=='punch'&&!GITEMS[id].back, on:'spin', desc:'훅이 상대를 빙글 돌려 등을 보이게 하고 닿은 기술이 준비 — 등을 치면 반드시 치명타' },
  { id:'gbounce', n:'바닥 튕기기',    a:id=>id==='stomp', b:id=>id==='upper'||id==='punch', on:'gbounce', desc:'떨어지는 적을 밟아 바닥에 한 번 튕기고 닿은 주먹이 준비 — 공중 콤보를 다시 잇는다' },
  { id:'pull',    n:'우산 걸어 당기기', a:id=>id==='umb', b:id=>id==='punch'||id==='upper', on:'pull', desc:'장우산 손잡이로 멀리 있는 적을 걸어 끌어당기고 닿은 주먹이 준비' },
  { id:'pole',    n:'기둥 튕기기',    a:id=>id==='charge'||id==='kick'||id==='round', b:id=>id==='punch'||id==='upper', on:'pole', desc:'날려 보낸 적이 기둥에 부딪혀 튕겨 오고 닿은 주먹이 준비 — 마중 나가 이어 친다' },
];
const poleOK=()=> GS.tower ? false : GS.demo ? !!GS.dojoPole : bagHasLink('pole');   // 타워엔 기둥이 없다   // 기본은 멀리 날아가고, 연계가 있을 때만 기둥에 튕긴다
const bagHasLink=id=>{ if(GS.demo) return true; const L=LINKS.find(L=>L.id===id); return !!L && GS.bag.some((b,i)=>b && L.a(b.id) && adjItems(i).some(o=>L.b(o.id))); };
const srcLinked=id=>{ if(GS.demo) return true; const b=GS.bag.find(x=>x&&x.uid===GS.curSrc), L=LINKS.find(L=>L.id===id); if(!b||!L) return false; const i=GS.bag.indexOf(b); return L.a(b.id) && adjItems(i).some(o=>L.b(o.id)); };
const FAMS={ fist:{ n:'주먹 계열', c:'#ff9a6b' }, foot:{ n:'발 계열', c:'#7ad7ff' }, grap:{ n:'몸싸움 계열', c:'#c59bff', guard:.15 } };
const linkBetween=(A,B)=>LINKS.find(L=>(L.a(A.id)&&L.b(B.id))||(L.a(B.id)&&L.b(A.id)));
// 세트: 같은 계열 아이템끼리 닿아 이어진 덩어리 안에 서로 다른 3종 이상
function computeSets(){ const on={}; for(const f in FAMS){ const its=GS.bag.filter(b=>GITEMS[b.id].fam===f), seen=new Set();
    for(const s0 of its){ if(seen.has(s0)) continue; const comp=[s0], q=[s0]; seen.add(s0);
      while(q.length){ const c=q.pop(); for(const o of adjItems(GS.bag.indexOf(c))) if(GITEMS[o.id].fam===f && !seen.has(o)){ seen.add(o); comp.push(o); q.push(o); } }
      if(new Set(comp.map(b=>b.id)).size>=3) on[f]=comp.map(b=>b.uid); } }
  GS.sets=on; if(on.foot && GS.on) GS.stats.footSet=1; return on; }
const inSet=b=>{ const f=GITEMS[b.id].fam; return !!(f && GS.sets && GS.sets[f] && GS.sets[f].includes(b.uid)); };
// 발동: src 아이템(i)이 적중 · 넘어뜨림 · 띄움 · 피함을 일으켰을 때
function linkFire(i, ev){ const src=GS.bag[i]; if(!src) return; const fired=[];
  for(const o of adjItems(i)){ const j=GS.bag.indexOf(o), oi=GITEMS[o.id]; if(j<0) continue;
    const L=LINKS.find(L=>L.a(src.id)&&L.b(o.id)&&L.on===ev);
    if(L){ metaLink(L.id); o.t=sStats(j).cd; (GS.linkAt||(GS.linkAt={}))[L.id]=GS.time; if(L.id==='rush'){ o.combo=1; o.last=GS.time; } if(L.id==='scoop' && o.id==='punch'){ o.combo=2; o.last=GS.time; } if(L.id==='dodge') o.emp=true; fired.push(o); GS.stats.links=(GS.stats.links||0)+1; continue; }
    if(ev==='hit' && oi.kind==='skill' && GITEMS[src.id].kind==='skill' && !linkBetween(src,o)){ /* 연쇄는 적중 한 번에 한 번 */ const cd=sStats(j).cd; o.t=Math.min(cd, o.t+cd*CHAIN_K(src.tier)); pulseItem(o,false); } }
  if(fired.length){ hint('link'); fired.forEach(o=>{ o.linkMark=true; }); GS.flash='LINK'; GS.flashT=.6; fired.forEach(o=>pulseItem(o,true)); pulseItem(src,true); } }
function pulseItem(b,gold){ const el=bagEl.querySelector(`.inv-grid .ii[data-uid="${b.uid}"]`); if(!el) return; const c=gold?'pulse-g':'pulse'; el.classList.remove(c); void el.offsetWidth; el.classList.add(c); }
const canEdit=()=> GS.on && GS.state!=='over' && !GS.cine && !(GS.cut&&GS.cut.pause);                         // 전투 중에도 정리할 수 있다(가방을 만지는 동안 시간이 느려진다)
const inCombat=()=> foes().length>0 && !['shop','arrange','transfer','over'].includes(GS.state);
const bagTouch=()=>{ if(inCombat()) GS.bagSlowT=.6; if(GS.state==='arrange') GS.arrTouched=true; };
const cdReset=b=>{ if(b && inCombat() && GITEMS[b.id].kind==='skill') b.t=0; };
const GS={ on:false, state:'idle', ci:0, wave:0, waveT:0, time:0, cam:0, stage:0, ents:[], items:[], bag:[], stash:[], tokens:0, selUid:null, uid:0,
  hp:100, max:100, score:0, kills:0, log:[], sel:-1, lagH:100, wait:0, fade:0, manualT:0, mcd:0, shots:[], cans:[], stats:{dealt:0,taken:0,crits:0,counters:0,outs:0} };
