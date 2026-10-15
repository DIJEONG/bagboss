// =========================================================
// 메타 진행: 판이 끝나도 남는 기록(브라우저 저장) — 시작 가방 해금 · 시작 노선 · 도감(적 · 역 · 아이템 · 연계 · 기록) · 오늘의 노선
// =========================================================
const META_KEY='dotlab-subway-meta-v1';
const META=(()=>{ const d={ v:1, runs:0, best:{score:0,stage:0}, tot:{kills:0,crits:0,dodges:0,links:0,throws:0,outs:0,onTime:0,merges:0,footSet:0}, foes:{}, stns:{}, items:{}, links:{}, kits:{basic:1}, lines:{0:1}, daily:{} };
  try{ const s=JSON.parse(localStorage.getItem(META_KEY)||'null'); if(s&&s.v===1) return { ...d, ...s, best:{...d.best,...s.best}, tot:{...d.tot,...s.tot} }; }catch(e){} return d; })();
let metaDirty=false; const metaSave=()=>{ try{ localStorage.setItem(META_KEY, JSON.stringify(META)); metaDirty=false; }catch(e){} };
const KITS=[
  { id:'basic', n:'기본 가방', desc:'서류 세 장 — 어퍼컷 ▶ → 주먹 ● → 앞차기 ■ 일자 콤보 경로', bag:[['upper',0,0,0],['punch',1,0,0],['kick',2,0,0]] },
  { id:'crit', n:'치명 가방', desc:'치명 옵션 신문을 넥타이핀 · 인장 반지가 감싼다', bag:[['paper',1,0,0,{k:'crit',v:.12}],['pin',0,0,0],['ring',2,0,0],['punch',2,1,0]], cond:{k:'crits',n:60,t:'치명타 누적 60번'} },
  { id:'foot', n:'발 계열 가방', desc:'앞차기 · 밟기 · 돌려차기 세트 완성 + 다리걸기', bag:[['kick',0,0,0],['stomp',2,0,0],['round',3,0,0],['sweep',0,3,0]], cond:{k:'footSet',n:1,t:'발 계열 세트 완성 1번'} },
  { id:'grap', n:'몸싸움 가방', desc:'니킥 · 메치기 · 어깨 돌진 세트(받는 피해 −15%)', bag:[['knee',0,0,0],['throw',1,0,0],['charge',3,1,0]], cond:{k:'throws',n:15,t:'메치기 누적 15번'} },
  { id:'guard', n:'수비 가방', desc:'쭈그리기 · 장우산 · 두꺼운 코트 · 주먹 — 버티며 가는 출발', bag:[['duck',0,0,0],['umb',1,0,0],['coat',4,0,0],['punch',0,1,0]], cond:{k:'dodges',n:20,t:'병 피하기 누적 20번'} },
  { id:'link', n:'연계 가방', desc:'접고 메치기 · 눕히고 밟기가 처음부터 이어진 배치', bag:[['knee',0,0,0],['throw',1,0,0],['kick',3,1,0],['stomp',4,0,0]], cond:{k:'links',n:40,t:'연계 발동 누적 40번'} },
];
const kitOpen=k=>!k.cond || !!META.kits[k.id];
let RUNCFG={ kit:'basic', stage:0, daily:false };
const lineOpen=k=>!!(META.lines[k] || OPT.devLines);   // 개발자 도구 '모든 노선 열기'는 기록을 바꾸지 않고 고르게만 해 준다
const ORIG_RAND=Math.random;
const todayKey=()=>{ const d=new Date(); return `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`; };
const hashStr=s=>{ let h=2166136261; for(const ch of s){ h^=ch.charCodeAt(0); h=Math.imul(h,16777619); } return h>>>0; };
const dailyKit=()=>KITS[hashStr(todayKey())%KITS.length];
// 기록 훅
function metaFoe(t,ko){ const r=META.foes[t]||(META.foes[t]={seen:0,ko:0}); if(ko) r.ko++; else r.seen++; metaDirty=true; }
function metaItem(id,tier){ if((META.items[id]||0)<tier){ META.items[id]=tier; metaDirty=true; } }
function metaLink(id){ if(!META.links[id]){ META.links[id]=1; metaDirty=true; } }
function metaStn(id){ if(id && !META.stns[id]){ META.stns[id]=1; metaDirty=true; } }
// 판 진행 중 수치를 누적하고 해금을 확인(2초마다)
function metaTick(){ if(!GS.on) return; const s=GS.stats, snap=GS.metaSnap||(GS.metaSnap={}), cur={ kills:GS.kills, crits:s.crits||0, dodges:s.dodges||0, links:s.links||0, throws:s.throws||0, outs:s.outs||0, onTime:s.onTime||0, merges:s.merges||0, footSet:s.footSet||0 };
  for(const k in cur){ const d=cur[k]-(snap[k]||0); if(d>0){ META.tot[k]=(META.tot[k]||0)+d; metaDirty=true; } snap[k]=cur[k]; }
  if(GS.atStop && TR.door>.9) metaStn(GS.atStop);
  for(const k of KITS) if(k.cond && !META.kits[k.id] && (META.tot[k.cond.k]||0)>=k.cond.n){ META.kits[k.id]=1; metaDirty=true; (GS.newUnlocks=GS.newUnlocks||[]).push(k.n); say('새 시작 가방 해금!', `${k.n} — ${k.desc}`, 3); sfx.unlock(); }
  if(metaDirty) metaSave(); }
setInterval(metaTick,2000);
// --- 메뉴: 새 판(시작 가방 · 시작 노선) · 오늘의 노선 · 도감 · 소리 ---
let menuPrevSpeed=1;
function openMenu(tab='run'){ if(gOverlay.dataset.menu!=='1'){ menuPrevSpeed=playSpeed; setGameSpeed(0); } gOverlay.dataset.menu='1'; sayEl.hidden=true;
  const tabs=[['run','새 판'],['daily',KE('오늘의 노선','Daily')],['tower','타워'],['codex','도감'],['sound','설정']];
  let body='';
  if(tab==='run'){ body=`<p class="mm-sub">시작 가방</p><div class="mm-kits">${KITS.map(k=>{ const open=kitOpen(k), p=k.cond?Math.min(1,(META.tot[k.cond.k]||0)/k.cond.n):1;
      return `<button type="button" class="mm-kit${open?'':' locked'}${RUNCFG.kit===k.id&&!RUNCFG.daily?' sel':''}" data-kit="${k.id}" ${open?'':'disabled'}><b>${k.n}</b>${miniBag(k.bag)}<small>${open?k.desc:`🔒 ${k.cond.t} (${Math.min(META.tot[k.cond.k]||0,k.cond.n)}/${k.cond.n})`}</small>${open?'':`<i class="mm-prog"><i style="width:${Math.round(p*100)}%"></i></i>`}</button>`; }).join('')}</div>
    <p class="mm-sub">시작 노선</p><div class="mm-lines">${STAGES.map((S,k)=>`<button type="button" class="mm-line${RUNCFG.stage===k?' sel':''}" data-line="${k}" ${lineOpen(k)?'':'disabled'} style="--lc:${S.color}"><i>${S.short}</i>${lineOpen(k)?(META.lines[k]?S.name:tr(S.name)+' · '+KE('개발','dev')):'🔒 이 노선까지 가 보면 열려요'}</button>`).join('')}</div>
    <p class="mm-note">${RUNCFG.stage>0?'중간 노선에서 시작하면 아이템 하나와 토큰 6개를 더 받아요.':''}</p>
    <div class="mm-act"><button type="button" class="btn primary" data-act="start">출발 ▶</button>${GS.on&&GS.state!=='over'?'<button type="button" class="btn" data-act="resume">계속하기</button>':''}</div>`; }
  if(tab==='daily'){ const k=dailyKit(), best=META.daily[todayKey()]||0;
    body=`<p class="mm-sub">${todayKey()} 오늘의 노선</p><p>오늘은 매점 · 적 · 확률이 누구에게나 같아요. 시작 가방도 하루 하나로 정해져요(잠긴 가방이어도 오늘은 써 볼 수 있어요).</p>
      <div class="mm-kit sel"><b>${k.n}</b>${miniBag(k.bag)}<small>${k.desc}</small></div>
      <p>오늘 최고 기록 <b class="mm-num">${best}</b></p><div class="mm-act"><button type="button" class="btn primary" data-act="daily">도전 ▶</button></div>`; }
  if(tab==='tower'){ const M2=META.tower||{best:0,bestT:0,runs:0}, mm=s=>`${Math.floor(s/60)}:${String(s%60).padStart(2,'0')}`;
    const otU=M2.ot||0, otS=Math.max(0,Math.min(otU,OPT.twOT||0)), LV=(M2.lv||{})[otS];
    body=`<p class="mm-sub">${KE('엘리베이터 타워 · 1~20층','Elevator Tower · 1–20F')}</p>
      <p>${KE('화물 엘리베이터를 타고 1층 주차장에서 20층 총주방장실까지 올라가요. 층마다 적이 타고, 정원을 넘기면 문이 안 닫혀요. 문이 열린 동안 밖으로 날려 보내고, 띄우기 기술은 천장에 튕겨요.','Ride a freight elevator from the 1F garage to the 20F head chef. Enemies board on every floor; over capacity, the doors stay open. Throw them out while the doors are open — launchers bounce off the ceiling.')}</p>
      <div class="tw-ot">${Array.from({length:otU+1},(_,l)=>`<button type="button" data-ot="${l}" class="${l===otS?'on':''}">${l?KE(`야근 ${l}`,`OT ${l}`):KE('정시','Regular')}</button>`).join('')}${otU<TW_OT_MAX?`<span class="tw-lock">🔒 ${KE(`${TW_TOP}층을 돌파하면 야근 ${otU+1}단계`,`Clear ${TW_TOP}F for OT ${otU+1}`)}</span>`:''}</div>
      ${otS?`<div class="tw-mods">${TW_OT.slice(1,otS+1).map(o=>`<b>${KE(o.n,o.en)}</b>`).join('')}</div>`:''}
      <div class="tw-rec"><div><b>${LV?LV.f+'F':'—'}</b><small>${twOtName(otS)} ${KE('최고 층','best floor')}</small></div><div><b>${LV&&LV.f>=TW_TOP?mm(LV.t):'—'}</b><small>${KE(`${TW_TOP}층 최단 시간`,`Best ${TW_TOP}F time`)}</small></div><div><b>${M2.runs||0}</b><small>${KE('도전','Runs')}</small></div></div>
      <p class="mm-note">${KE("시작 가방은 '새 판'에서 고른 가방이에요 · 본편 이어 하기 저장은 그대로 남아요","Uses the starting case picked in New run · your main-run save stays untouched")}</p>
      <div class="mm-act"><button type="button" class="btn primary" data-act="tower">${KE('오르기 ▶','Climb ▶')}</button></div>
      ${(()=>{ const dk=todayKey(), D=twDaily(dk), db=(M2.daily||{})[dk], dkit=dailyKit(); return `<p class="mm-sub" style="margin-top:16px">${KE('오늘의 타워','Daily Tower')} · ${dk}</p>
      <p>${KE('오늘은 누구에게나 같은 조건 · 같은 탑승 순서 · 같은 시작 가방이에요.','Same conditions, boarding order and starting case for everyone today.')}</p>
      <div class="tw-mods">${D.mods.map(m=>`<b>${KE(m.n,m.en)}</b>`).join('')}<b class="kit">${KE('가방','Case')} · ${dkit.n}</b></div>
      <p>${KE('오늘 최고','Today best')} <b class="mm-num">${db?`${db.f}F · ${mm(db.t)}`:'—'}</b></p>
      <div class="mm-act"><button type="button" class="btn" data-act="towerDaily">${KE('오늘의 타워 ▶','Daily Tower ▶')}</button></div>`; })()}`; }
  if(tab==='codex') body=codexHTML(gOverlay.dataset.ctab||'foe');
  if(tab==='sound'){ const T=(k,t,d)=>`<label class="st-row"><span class="st-t">${t}${d?`<small>${d}</small>`:''}</span><input type="checkbox" class="sw" ${k==='vibe'?(OPT.vibe!==false?'checked':''):(OPT[k]?'checked':'')} data-opt="${k}"></label>`;
    body=`<div class="mm-snd st">
      <section class="st-sec"><h4>소리 <small class="st-h">브라우저에서 바로 합성</small></h4>${[['master','전체'],['music','음악'],['sfx','효과음']].map(([k,n])=>`<label class="st-vol"><span>${n}</span><input type="range" min="0" max="100" value="${Math.round(SND.vol[k]*100)}" data-vol="${k}"><b>${Math.round(SND.vol[k]*100)}</b></label>`).join('')}
        <label class="st-row"><span class="st-t">음소거</span><input type="checkbox" class="sw" ${SND.muted?'checked':''} data-mute></label></section>
      <section class="st-sec"><h4>게임</h4>${T('autoSpc','필살기 자동 발동','적 3명 이상이거나 두목일 때')}${T('shortCut','컷인 짧게','두 번째부터 짧게 보여요')}${T('noFlash','번쩍임 줄이기','흑백 반전 · 하얀 섬광 끔 · 충격파 약하게')}${T('vibe','진동','큰 타격 · 필살기 · 두목 등장 (모바일)')}</section>
      <section class="st-sec"><h4>주인공 <i class="sk-tag">${tr('스킨 유료 · 시험')}</i><button type="button" class="st-mini" data-skinpv="1">${tr('미리보기 ▶')}</button></h4>${T('shades','선글라스','')}
        <div class="sk-row st-sk">${Object.entries(SKINS).map(([k,S])=>`<button type="button" data-skin="${k}" class="sk${(OPT.skin||'jw')===k?' on':''}"><span class="sk-sw">${S.sw.map(c=>`<i style="background:${c}"></i>`).join('')}</span><b>${tr(S.n)}</b><small>${tr(S.sub)}</small>${S.free?'':`<em>${tr('유료')}</em>`}</button>`).join('')}</div></section>
      <section class="st-sec st-inline"><h4>언어 · Language</h4><div class="st-seg"><button type="button" data-lang="ko" aria-pressed="${LANG==='ko'}">한국어</button><button type="button" data-lang="en" aria-pressed="${LANG==='en'}">English</button></div></section>
      <section class="st-sec st-inline"><h4>기타</h4><div class="st-btns"><button type="button" class="st-mini" data-hints>도움말 다시 보기</button><button type="button" class="st-mini" data-dev>개발자 도구</button></div></section></div>`; }
  gOverlay.innerHTML=`<div class="g-card mm"><div class="mm-head"><h3>메뉴</h3><span>최고 ${META.best.score}점 · ${STAGES[Math.min(META.best.stage,STAGES.length-1)].short}선까지 · ${META.runs}판</span><button type="button" class="mm-x" data-act="close" aria-label="닫기">✕</button></div>
    <div class="mm-tabs">${tabs.map(([k,n])=>`<button type="button" data-tab="${k}" class="${k===tab?'on':''}">${n}</button>`).join('')}</div><div class="mm-body">${body}</div></div>`;
  gOverlay.hidden=false;
  gOverlay.querySelectorAll('[data-tab]').forEach(b=>b.onclick=()=>{ sfx.click(); openMenu(b.dataset.tab); });
  gOverlay.querySelectorAll('[data-kit]').forEach(b=>b.onclick=()=>{ sfx.click(); RUNCFG.kit=b.dataset.kit; RUNCFG.daily=false; openMenu('run'); });
  gOverlay.querySelectorAll('[data-line]').forEach(b=>b.onclick=()=>{ sfx.click(); RUNCFG.stage=+b.dataset.line; openMenu('run'); });
  gOverlay.querySelectorAll('[data-ot]').forEach(b=>b.onclick=()=>{ sfx.click(); OPT.twOT=+b.dataset.ot; optSave(); openMenu('tower'); });   // 야근 단계 고르기
  gOverlay.querySelectorAll('[data-ctab]').forEach(b=>b.onclick=()=>{ sfx.click(); gOverlay.dataset.ctab=b.dataset.ctab; openMenu('codex'); });
  gOverlay.querySelectorAll('[data-cblab]').forEach(b=>b.onclick=()=>{ sfx.click(); jumpTo('dojo'); });                                        // 콤보 연구실: 무도장 커스텀 콤보
  gOverlay.querySelectorAll('[data-cbdemo]').forEach(b=>b.onclick=()=>{ sfx.click(); const B=COMBO_BOOK.find(x=>x.id===b.dataset.cbdemo); jumpTo('dojo'); if(B) setTimeout(()=>{ let pc=0; dojoRun(B.r.map(id=>id==='punch'?['punch',(pc++)%4]:[id]), tr(B.n)); }, 450); });
  gOverlay.querySelectorAll('[data-vol]').forEach(r=>r.oninput=()=>{ SND.vol[r.dataset.vol]=r.value/100; sndApplyVol(); sndSave(); const v=r.parentNode.querySelector('b'); if(v) v.textContent=r.value; });
  const mu=gOverlay.querySelector('[data-mute]'); if(mu) mu.onchange=()=>{ SND.muted=mu.checked; sndApplyVol(); sndSave(); };
  gOverlay.querySelectorAll('[data-opt]').forEach(c=>c.onchange=()=>{ OPT[c.dataset.opt]=c.checked; optSave(); });
  gOverlay.querySelectorAll('[data-skinpv]').forEach(b=>b.onclick=()=>{ sfx.click(); skinPvOpen(); });
  gOverlay.querySelectorAll('[data-skin]').forEach(b=>b.onclick=()=>{ sfx.click(); applySkin(b.dataset.skin); gOverlay.querySelectorAll('[data-skin]').forEach(x=>x.classList.toggle('on',x===b)); });   // 스킨 바로 바꾸기
  gOverlay.querySelectorAll('[data-jump]').forEach(b=>b.onclick=()=>{ sndInit(); sfx.click(); jumpTo(b.dataset.jump); });
  { const db=gOverlay.querySelector('[data-dev]'); if(db) db.onclick=()=>{ sndInit(); sfx.click(); openDev(); }; }
  gOverlay.querySelectorAll('[data-lang]').forEach(b=>b.onclick=()=>{ const l=b.dataset.lang; if(l===LANG) return; try{ saveRun(); localStorage.setItem('dotlab-lang',l); }catch(e){} location.reload(); });
  { const hb=gOverlay.querySelector('[data-hints]'); if(hb) hb.onclick=()=>{ META.hints={}; metaSave(); sfx.click(); hb.textContent='도움말을 다시 보여 드려요'; }; }
  gOverlay.querySelectorAll('[data-act]').forEach(b=>b.onclick=()=>{ const a=b.dataset.act; sndInit();
    if(a==='close'||a==='resume'){ closeMenu(); if(!GS.on) startRun(); }
    if(a==='start'){ closeMenu(); RUNCFG.daily=false; startRun(); }
    if(a==='daily'){ closeMenu(); RUNCFG.daily=true; startRun(); }
    if(a==='tower'){ closeMenu(); startTower(); }
    if(a==='towerDaily'){ closeMenu(); startTower({ daily:true }); } });
}
// 시작 가방 미리보기: 그림 대신 실제 6×4 배치를 작은 타일로
function miniBag(list,cs=9){ return `<span class="mm-minibag" style="width:${INV.W*cs}px;height:${INV.H*cs}px">${list.map(([id,x,y,rot],k)=>{ if(!GITEMS[id]) return ''; const f={ id, tier:1, uid:-200-k, rot:rot||0 }, {w,h}=itemBox(f); return `<span class="mb-s" style="left:${x*cs}px;top:${y*cs}px;width:${w*cs}px;height:${h*cs}px">${itemHTML(f,'ii mini')}</span>`; }).join('')}</span>`; }
function closeMenu(){ gOverlay.dataset.menu=''; gOverlay.hidden=true; setGameSpeed(menuPrevSpeed||1); }
function codexHTML(ct){ const tabs=[['foe','적'],['stn','역'],['item','아이템'],['link','연계'],['cmb','콤보'],['spc','필살기'],['rec','기록']];
  let list='';
  if(ct==='foe') list=Object.keys(ETYPES).map(t=>{ const r=META.foes[t]; return `<li class="${r?'':'unk'}"><b>${r?ETYPES[t].n:'???'}</b><small>${r?`만남 ${r.seen} · 쓰러뜨림 ${r.ko}`:'아직 못 만났어요'}</small></li>`; }).join('');
  if(ct==='stn'){ const ids=[...new Set(STAGES.flatMap(S=>[S.start,...S.line.flatMap(L=>[L.stop,...(L.quick||[]).map(q=>q[0]),...(L.passes||[]).map(q=>q[0])])]))];
    list=ids.map(id=>{ const S=STN[id], v=META.stns[id], col=S.band?NYC_COL[S.band]:null; return `<li class="stamp ${v?'':'unk'}"><b>${v?S.ko:'???'}</b><small>${v?S.n:'아직 안 들렀어요'}</small></li>`; }).join(''); }
  if(ct==='item') list=REAL_ITEMS().map(id=>{ const t=META.items[id]; return `<li class="${t?'':'unk'}"><img src="${artURL(id,0)||iconOf(GITEMS[id].icon)}" alt="" class="${t?'':'sil'}"><b>${t?GITEMS[id].n:'???'}</b><small>${t?`최고 ${'★'.repeat(t)}`:'아직 못 얻었어요'}</small></li>`; }).join('');
  if(ct==='link'){ const seen=new Set(); list=LINKS.filter(L=>{ if(seen.has(L.n)) return false; seen.add(L.n); return true; }).map(L=>{ const v=LINKS.some(x=>x.n===L.n&&META.links[x.id]); return `<li class="${v?'':'unk'}"><b>${v?L.n:'???'}</b><small>${v?L.desc:'어떤 조합일까요?'}</small></li>`; }).join(''); }
  if(ct==='cmb'){ const G={S:'▶',L:'●',F:'■'}, CB=META.cbook||{}, nm=id=>`${G[croleOf(id)]||''} ${tr(GITEMS[id]?GITEMS[id].n:id)}`;
    const book=COMBO_BOOK.map(B=>{ const e=CB[B.id], seen=(META.cseen||{})[B.id]; return `<li class="cb${e?' ok':' unk'}${!e&&seen?' seen':''}"><b>${e?'✓ ':''}${tr(B.n)}${!e&&seen?` <i class="cb-seen">${tr('목격함')}</i>`:''}</b><small>${B.r.map(nm).join(' → ')}</small><small>${tr(B.d)}${e?` · ${e.n}${tr('번')} · ${tr('최고')} ${e.best} HIT`:` · ${tr('실전에서 성공하면 채워져요')}`}</small>${SIG[B.id]?`<small class="cb-sig">${tr('고유 마무리')} · <b>${SIG[B.id].w}</b> ${tr(SIG[B.id].d)}</small>`:''}<button type="button" class="cb-demo" data-cbdemo="${B.id}">${tr('무도장 시연')}</button></li>`; }).join('');
    const free=Object.values(META.combos||{}).filter(e=>!bookOf(e.ids)).sort((a,b)=>b.n-a.n).map(e=>`<li><b>${tr(e.name)}</b><small>${e.ids.map(nm).join(' → ')} · ${e.n}${tr('번')} · ${tr('최고')} ${e.best} HIT</small></li>`).join('');
    list = `<li class="cb-head"><b>${tr('콤보 도감')} ${Object.keys(CB).filter(k=>COMBO_BOOK.some(B=>B.id===k)).length} / ${COMBO_BOOK.length}</b><small>${tr('실전에서 그 순서로 성공해야 채워져요')}</small><button type="button" class="cb-lab" data-cblab="1">${tr('콤보 연구실 열기')}</button></li>${book}`
      + `<li class="cb-head"><b>${tr('두목 명장면')}</b><small>${tr('무너진 두목을 콤보로 쓰러뜨리면 기록돼요')}</small></li>${Object.keys(BOSS_INFO).map(k=>{ const n=(META.bossScenes||{})[k]; return `<li class="cb${n?' ok':' unk'}"><b>${n?'✓ ':''}${tr(BOSS_INFO[k].n)}</b><small>${n?`${n}${tr('번')}`:tr('아직 없어요')}</small></li>`; }).join('')}`
      + `<li class="cb-head"><b>${tr('자유 콤보')}</b><small>${free?tr('도감 밖에서 찾은 콤보'):tr('도감에 없는 순서로 콤보를 완성하면 여기에 기록돼요')}</small></li>${free}`; }
  if(ct==='spc') list=Object.keys(SPC).map(k=>{ const n=(META.spc||{})[k]; return `<li class="${n?'':'unk'}"><b>${n?SPC[k].n:'???'}</b><small>${n?`${SPC[k].en} · ${n}번 사용`:`${FAMS[k].n} 위주로 가방을 짜면 나와요`}</small></li>`; }).join('');
  if(ct==='rec'){ const T=META.tot; list=[['판 수',META.runs],['최고 점수',META.best.score],['가장 멀리 간 노선',STAGES[Math.min(META.best.stage,STAGES.length-1)].name],['쓰러뜨린 적',T.kills],['치명타',T.crits],['병 피하기',T.dodges],['연계 발동',T.links],['메치기',T.throws],['문밖으로 날린 적',T.outs],['정시 클리어',T.onTime],['합성 성공',T.merges]].map(([a,b])=>`<li><b>${a}</b><small>${b}</small></li>`).join(''); }
  const total = ct==='foe'?Object.keys(ETYPES).length : ct==='item'?REAL_ITEMS().length : 0, got = ct==='foe'?Object.keys(META.foes).length : ct==='item'?Object.keys(META.items).length : 0;
  return `<div class="mm-ctabs">${tabs.map(([k,n])=>`<button type="button" data-ctab="${k}" class="${k===ct?'on':''}">${n}</button>`).join('')}</div>${total?`<p class="mm-note">${got} / ${total}</p>`:''}<ul class="mm-list ${ct}">${list}</ul>`; }

