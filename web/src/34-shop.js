// --- 정차역 매점 · 결과 ---
function shopPick(){ const pool=REAL_ITEMS(), pick=[], Rr = GS.daily ? mulberry(hashStr(`${todayKey()}:${GS.stageIdx||0}:${GS.ci}:${GS.rerolls||0}`)) : Math.random; if(GS.ci===0 && (GS.stageIdx||0)===0 && duckSlot()<0 && !GS.stash.some(b=>b.id==='duck')) pick.push('duck');   // 첫 매점엔 쭈그리기
  while(pick.length<3){ const k=pool[Math.floor(Rr()*pool.length)]; if(!pick.includes(k)) pick.push(k); }
  return pick.map(k=>({ id:k, tier: (GS.stageIdx||0)>=1 && Rr()<.3 ? 2 : 1, opt: rollOpt(k,(GS.stageIdx||0)>=1?.65:.45,Rr) })); }
function shapeMini(id){ const c=shapeOf(id,0), w=Math.max(...c.map(p=>p[0]))+1, h=Math.max(...c.map(p=>p[1]))+1;
  return `<span class="mini" style="--w:${w};--h:${h}">${c.map(([x,y])=>`<i style="left:${x/w*100}%;top:${y/h*100}%;width:${100/w}%;height:${100/h}%"></i>`).join('')}</span>`; }
function openShop(reroll){ sayEl.hidden=true; sayT=0; if(!reroll) setTimeout(()=>{ if(!gOverlay.hidden) talkOnce('shop', TALK.shop); }, 420);   // 첫 매점: 사보
  if(!reroll){ GS.hp=Math.min(GS.max,GS.hp+Math.round(GS.max*.4*(GS.tower?(GS.tower.restK||1):1))); GS.shopList=shopPick(); }
  const st=GS.tower ? { ko:twFloorName(GS.tower.floor), n:(TW_FLOORS[GS.tower.floor]||{}).en||'Room Service' } : STN[GS.nextStop];
  gOverlay.innerHTML=`<div class="g-card shop"><h3><span>${st.ko} 매점 · <small>${st.n}</small></span><span class="sh-tok"><i class="px-token"></i>${GS.tokens}</span></h3><p class="sh-sub">하나를 골라 보류함에 넣어요 · 체력 40% 회복</p>${contribHTML(GS.contrib,4)}<div class="loot">${GS.shopList.map((o,k)=>shopCard(o,k)).join('')}</div>
    <p class="shop-foot sf2"><button type="button" class="reroll" ${GS.tokens<REROLL_COST?'disabled':''}>새로고침 <i class="tk"><i class="px-token"></i>${REROLL_COST}</i></button><button type="button" class="carve" ${GS.tokens<4?'disabled':''}>각인 새기기 <i class="tk"><i class="px-token"></i>4</i></button><button type="button" class="skip">지나가기</button></p></div>`;
  gOverlay.hidden=false;
  gOverlay.querySelector('.skip').onclick=()=>{ gOverlay.hidden=true; GS.state='arrange'; GS.arrT=20+5*GS.stash.length; GS.arrTouched=false; renderBag(); showArrange(); };
  gOverlay.querySelector('.carve').onclick=()=>{ if(GS.tokens<4) return; GS.tokens-=4; carveImprint(); openShop(true); };
  gOverlay.querySelector('.reroll').onclick=()=>{ if(GS.tokens<REROLL_COST) return; GS.tokens-=REROLL_COST; GS.rerolls=(GS.rerolls||0)+1; GS.shopList=shopPick(); openShop(true); };
  gOverlay.querySelectorAll('.lc').forEach(btn=>btn.addEventListener('click',()=>{ const o=GS.shopList[+btn.dataset.k], n=addToStash(o.id,o.tier,true,o.opt); if(n) GS.selUid=n.uid;
    gOverlay.hidden=true; GS.state='arrange'; GS.arrT=20+5*GS.stash.length; GS.arrTouched=false; renderBag(); showArrange(); }));
}
// 매점 카드: 가방 타일과 같은 말 — 모양 · 역할 배지 · 이름 · 피해 · 쿨다운 · 칸 수 · 콤보 변화 (그림 없음)
const ROLE_N={ S:'시작기', L:'이음기', F:'마무리기', X:'회피' };
function roleBadge(id){ const r=croleOf(id), k=GITEMS[id].kind; return (k==='skill'||k==='dodge') ? `<b class="bdg">${ROLE_G[r]||'◇'} ${ROLE_N[r]||''}</b>` : `<b class="bdg gold">◆ 보조</b>`; }
function stashFits(id){ const tmp={ id, tier:1, uid:-77, rot:0 }, save=GS.stash.map(o=>[o,o.sx,o.sy,o.rot]), arr=GS.stash.slice(); let ok=false;
  try{ ok=stashPut(tmp); } finally{ GS.stash=arr; for(const [o,x,y,r] of save){ o.sx=x; o.sy=y; o.rot=r; } } return ok; }
function shopCard(o,k){ const it=GITEMS[o.id], fake={ id:o.id, tier:o.tier, opt:o.opt, uid:-50-k, rot:0 }, S=tileStats(fake), {w,h}=itemBox(fake,0), cs=13, cd=comboDelta(o.id), fit=stashFits(o.id);
  const st=`${S.dmg!=null?`<em class="dm">${SV_SW}${S.dmg}</em>`:''}${S.val?`<em style="color:${S.vc}">${S.val}</em>`:''}${S.cd?`<em class="ct">${SV_CK}${S.cd}${LANG==='en'?'s':'초'}</em>`:''}<em class="sz">${sizeOf(o.id)}칸</em>${o.opt?`<em class="op" style="--oc:${OPTS[o.opt.k].c}">${OPTS[o.opt.k].f(o.opt.v)}</em>`:''}`;
  return `<button type="button" class="lc sc" data-k="${k}"><span class="sc-shape"><span class="sc-tile" style="width:${w*cs}px;height:${h*cs}px">${itemHTML(fake,'ii mini')}</span></span><span class="sc-body"><span class="sc-top">${roleBadge(o.id)}<b class="sc-n" style="color:${TIER_COL[o.tier]}">${it.n}</b><i class="sc-star" style="color:${TIER_COL[o.tier]}">${starsOf(o.tier)}</i></span><span class="sc-st">${st}</span><span class="sc-d">${it.desc}</span>${cd?`<span class="sc-cb">${cd}</span>`:''}${fit?'':`<span class="sc-warn">보류함이 가득 — 고르면 토큰 ${tokenValue(fake)}개로 바뀌어요</span>`}</span></button>`; }
// 정리 시간: 문이 열린 채 15초. 직접 넣거나, 시간이 다 되면 자동 정리하고 출발
function showArrange(){ hint('bag'); let el=document.getElementById('sbArrange'); if(!el){ el=document.createElement('div'); el.id='sbArrange'; el.className='sb-arrange'; stage.appendChild(el); }
  el.innerHTML=`<span>자동 출발 <b id="arrT">${Math.ceil(GS.arrT||20)}</b>초 · 서류가방을 만지면 기다려요</span><button type="button">출발 ▶</button>`; el.hidden=false;
  if(!el.dataset.wired){ el.dataset.wired=1; ['pointerdown','mousedown','touchstart'].forEach(t=>el.addEventListener(t,e=>e.stopPropagation()));   // 바깥(화면 터치 · 핸들 끌기)이 가로채지 않게
    el.addEventListener('pointerup',e=>{ if(e.target.closest('button')){ e.stopPropagation(); finishArrange(); } }); } }
function finishArrange(){ const el=document.getElementById('sbArrange'); if(el) el.hidden=true; if(GS.stash.length) autoPack(); if(GS.tower){ renderBag(); GS.state='fight'; const T=GS.tower; if(T.phase==='zone'){ T.phase='move'; T.t=0; T.vel=0; say(KE('다음 구간으로','On to the next zone'),'',1.2); return; } T.phase='close'; T.t=0; say('문이 닫힙니다','',1.2); return; } startBoard(); say('문이 닫힙니다','',1.6); }

function showResult(win){
  hideArrange(); if(!GS.devRun) clearRunSave(); GS.state='over'; const s=GS.stats; sayEl.hidden=true; sayT=0; metaTick(); const newBest=!GS.devRun && GS.score>META.best.score; if(!GS.devRun){ META.runs++; META.best.score=Math.max(META.best.score,GS.score); }   // 테스트 판은 기록 · 저장에 남기지 않는다
  if(RUNCFG.daily){ const dk=todayKey(); META.daily[dk]=Math.max(META.daily[dk]||0,GS.score); } metaSave();
  const unl=(GS.newUnlocks||[]), N=newsCopy(win), d=new Date(), date=`${d.getFullYear()}년 ${d.getMonth()+1}월 ${d.getDate()}일`;
  GS.capReq=true;                                                                                              // 다음 프레임에 화면을 찍어 보도 사진으로
  gOverlay.innerHTML=`<div class="g-card paper"><div class="np-mast"><b>THE DAILY TRANSIT</b><div class="np-date"><span>${LANG==='en'?'New York Subway Edition':'데일리 트랜짓 · 뉴욕 지하철판'}</span><span>${LANG==='en'?d.toLocaleDateString('en-US',{month:'short',day:'numeric',year:'numeric'}):date} · ${RUNCFG.daily?(LANG==='en'?'Daily Route Special':'오늘의 노선 특별판'):(LANG==='en'?'Final':'최종판')} · 25¢</span></div></div>
    <h3 class="np-head">${N.head}</h3><p class="np-deck">${N.deck}</p>
    <div class="np-body"><figure><img id="gPhoto" alt="보도 사진"><figcaption>${LANG==='en'?`Photo: courtesy of a passenger · Score ${GS.score.toLocaleString()}${newBest?' · New best!':''}`:`사진: 승객 제공 · 점수 ${GS.score.toLocaleString()}점${newBest?' · 최고 기록 경신':''}`}</figcaption></figure>
      <div class="np-cols"><p>${N.p1}</p><p>${N.p2}</p></div></div>
    <div class="np-box"><b>기록실</b><span>최고 ${META.best.score.toLocaleString()}점</span><span>${META.runs}판째</span>${RUNCFG.daily?`<span>오늘의 노선 최고 ${META.daily[todayKey()]}점</span>`:''}<span>도감 적 ${Object.keys(META.foes).length}/${Object.keys(ETYPES).length}</span><span>역 ${Object.keys(META.stns).length}</span><span>아이템 ${Object.keys(META.items).length}/${REAL_ITEMS().length}</span>${unl.length?`<em>새로 열림: ${unl.join(' · ')}</em>`:''}</div>
    <div class="mm-act"><button type="button" class="btn primary" id="gAgain">다시 하기</button><button type="button" class="btn" id="gMenu">메뉴</button></div></div>`;
  gOverlay.hidden=false; document.getElementById('gAgain').addEventListener('click',()=>startRun()); document.getElementById('gMenu').addEventListener('click',()=>openMenu('run'));
}
