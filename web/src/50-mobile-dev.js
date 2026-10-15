// 모바일 세로 한 화면: 기기 프레임 안에 무대 + 서류가방 · 개발자 도구 시트
// =========================================================
(function buildDevice(){ const col=document.querySelector('.stage-col'), stg=document.getElementById('stage'), panel=document.querySelector('.game-panel'); if(!col||!stg||!panel) return;
  const dev=document.createElement('div'); dev.id='device'; dev.className='device';
  const sc=document.createElement('div'); sc.className='dev-scroll'; dev.appendChild(sc);
  col.insertBefore(dev, stg); sc.appendChild(stg); sc.appendChild(panel);
  // 메뉴 · 매점 · 결과 · 타이틀은 기기 화면 전체를 덮는다
  dev.appendChild(gOverlay); { const tt=document.querySelector('.g-title'); if(tt) dev.appendChild(tt); }
  const dp=document.createElement('div'); dp.id='devPanel'; dp.className='dev-panel'; dp.hidden=true;
  dp.innerHTML=`<div class="dp-head"><b>개발자 도구</b><button type="button" class="btn dp-close">닫기</button></div>
    <div class="dp-sec"><p class="dp-sub">진행 상태</p><div class="dp-status"></div></div>
    <div class="dp-sec"><p class="dp-sub">게임 속도</p><div class="dp-speed"></div></div>
    <div class="dp-sec dp-lines"></div>
    <div class="dp-sec"><p class="dp-sub">바로 가기</p><div class="mm-jump"><button type="button" class="btn" data-jump="bonus">차 부수기 보너스</button><button type="button" class="btn" data-jump="corridor">복도 오프닝</button><button type="button" class="btn" data-jump="cine">거리 연출</button><button type="button" class="btn" data-jump="dojo">동작 데모 무도장</button><button type="button" class="btn" data-jump="tower">엘리베이터 타워</button></div>
      <p class="mm-hint">차 부수기는 지금 서류가방 그대로 4선 끝에서 시작하고, 끝나면 6선 환승으로 이어져요.</p></div>
    <div class="dp-sec"><p class="dp-sub">화면 스타일</p><div class="dp-style"></div></div>
    <div class="dp-sec"><button type="button" class="btn dp-pose">자세 편집기</button> <button type="button" class="btn dp-lab">엔진 실험실 열기</button></div>
    <div class="dp-sec dp-help"><p class="dp-sub">게임 설명</p></div>`;
  dev.appendChild(dp);
  const hud=panel.querySelector('.hud'), st=dp.querySelector('.dp-status');
  if(hud) [...hud.children].filter(c=>c.id!=='gMenuBtn' && c.id!=='gSpeed' && !c.classList.contains('ab-only')).forEach(c=>st.appendChild(c));   // 행동 줄(진행 · 필살기 · 속도)은 남긴다
  const sp=document.getElementById('gSpeed'); if(sp) dp.querySelector('.dp-speed').appendChild(sp);
  const sty=document.getElementById('gStyles'); if(sty) dp.querySelector('.dp-style').appendChild(sty.closest('.bar')||sty);
  const cap=panel.querySelector('.cap'); if(cap) dp.querySelector('.dp-help').appendChild(cap);
  dp.querySelector('.dp-close').onclick=()=>{ dp.hidden=true; };
  dp.querySelector('.dp-lab').onclick=()=>{ dp.hidden=true; setMode('lab'); };
  dp.querySelector('.dp-pose').onclick=()=>{ dp.hidden=true; sndInit(); sfx.click(); poseEdOpen(); };
  dp.querySelectorAll('[data-jump]').forEach(b=>b.onclick=()=>{ dp.hidden=true; sndInit(); sfx.click(); jumpTo(b.dataset.jump); });
})();
function openDev(){ const dp=document.getElementById('devPanel'); if(!dp) return; gOverlay.hidden=true; if(!GS.demo) setGameSpeed(GAME_SPD); devLinesRender(); dp.hidden=false; dp.scrollTop=0; }
// 개발자 도구 · 노선 테스트: 노선 · 칸 · 가방을 골라 그 칸부터 바로 시작(저장 · 기록에 남지 않는 테스트 판)
const DL_BAGS=[['start','시작 가방'],['cur','지금 가방'],['t2','강화 ★2'],['t4','강화 ★4']];
const carHasBoss=c=>[...(c.waves||[]).flat(), ...(c.fight||[])].some(t=>ETYPES[t]&&ETYPES[t].boss);
function devLinesRender(){ const box=document.querySelector('#devPanel .dp-lines'); if(!box) return;
  const k=Math.max(0,Math.min(STAGES.length-1, OPT.devLine|0)), S=STAGES[k], L=S.line, j=Math.max(0,Math.min(L.length-1, OPT.devCar|0)), bm=DL_BAGS.some(x=>x[0]===OPT.devBag)?OPT.devBag:'start';
  const live=GS.on && GS.devRun && !GS.demo && !GS.bonus && !GS.prologue && ['fight','shop','arrange'].includes(GS.state);
  box.innerHTML=`<p class="dp-sub">${tr('노선 테스트')}</p>
    ${live?`<div class="dl-live"><span>${KE(`테스트 중 · ${STAGE.short} 노선 ${GS.ci+1}호차`, `Testing · ${STAGE.short} line, car ${GS.ci+1}`)}</span><button type="button" class="btn" data-dkill="1">${tr('적 모두 쓰러뜨리기')}</button><button type="button" class="btn" data-dnext="1" ${GS.ci+1<LINE.length?'':'disabled'}>${tr('다음 칸으로')}</button></div>`:''}
    <div class="dl-lines" role="group" aria-label="${tr('노선')}">${STAGES.map((T,i)=>`<button type="button" class="dl-line${i===k?' on':''}" data-dl="${i}" aria-pressed="${i===k}" title="${tr(T.name)}" style="--lc:${T.color}"><i>${T.short}</i></button>`).join('')}</div>
    <p class="dl-name">${tr(S.name)}<small>${KE(L.length+'칸', L.length+' cars')}${META.lines[k]?'':' · '+tr('아직 안 가 본 노선')}</small></p>
    <div class="dl-cars" role="group" aria-label="${tr('칸')}">${L.map((c,i)=>`<button type="button" class="dl-car${i===j?' on':''}" data-dc="${i}" aria-pressed="${i===j}"><b>${i+1}</b><span>${tr(CAR_CONCEPTS[c.car].name)}</span>${carHasBoss(c)?`<em>${tr('두목')}</em>`:''}</button>`).join('')}</div>
    <div class="dl-row"><span>${tr('가방')}</span><div class="dl-seg">${DL_BAGS.map(([v,l])=>`<button type="button" data-dbag="${v}" class="${v===bm?'on':''}" aria-pressed="${v===bm}">${tr(l)}</button>`).join('')}</div></div>
    <label class="dl-sw"><input type="checkbox" class="sw" data-dgod ${OPT.devGod?'checked':''}><span>${tr('무적')}<small>${tr('테스트 판에서만 — 맞아도 체력이 줄지 않아요')}</small></span></label>
    <label class="dl-sw"><input type="checkbox" class="sw" data-dall ${OPT.devLines?'checked':''}><span>${tr('모든 노선 열기')}<small>${tr("새 판의 '시작 노선'에서 안 가 본 노선도 고를 수 있어요")}</small></span></label>
    <button type="button" class="btn dl-go" data-dgo="1">▶ ${KE(`${S.short} 노선 ${j+1}호차부터 시작`, `Start ${S.short} line at car ${j+1}`)}</button>
    <p class="mm-hint">${tr('테스트 판은 이어 하기 저장과 노선 기록을 건드리지 않아요.')}</p>
`;
  if(box._b) return; box._b=true;
  box.addEventListener('click',e=>{ const b=e.target.closest('button'); if(!b||b.disabled) return; const a=b.dataset, dp=document.getElementById('devPanel'); sndInit(); sfx.click();
    if(a.dl!=null){ OPT.devLine=+a.dl; OPT.devCar=0; optSave(); devLinesRender(); }
    else if(a.dc!=null){ OPT.devCar=+a.dc; optSave(); devLinesRender(); }
    else if(a.dbag){ OPT.devBag=a.dbag; optSave(); devLinesRender(); }
    else if(a.dgo){ dp.hidden=true; jumpTo({ line:OPT.devLine|0, car:OPT.devCar|0, bag:OPT.devBag||'start' }); }
    else if(a.dkill){ dp.hidden=true; devClearFoes(); }
    else if(a.dnext){ dp.hidden=true; devJumpCar(GS.ci+1); } });
  box.addEventListener('change',e=>{ const t=e.target; if(t.matches('[data-dgod]')){ OPT.devGod=t.checked; optSave(); if(t.checked && GS.devRun) GS.hp=GS.max; } else if(t.matches('[data-dall]')){ OPT.devLines=t.checked; optSave(); devLinesRender(); } }); }
function devStageRun(k,j,bm){ k=Math.max(0,Math.min(STAGES.length-1,k|0));
  const keep={...RUNCFG}, snap = bm==='cur' ? { bag:(hasPro()&&GS.pKit?GS.pKit:GS.bag).map(o=>({...o})), stash:(GS.stash||[]).map(o=>({...o})), tokens:GS.tokens||0 } : null;
  GS.devStart=true; try{ startRun({stage:0,daily:false}); } finally{ GS.devStart=false; } RUNCFG=keep;
  if(snap && snap.bag.length){ GS.bag=snap.bag; GS.stash=snap.stash; GS.tokens=snap.tokens; }
  else if(bm==='t2' || bm==='t4'){ const D=DEMO_BAGS[1], t=bm==='t4'?4:2; GS.bag=D.L.filter(([id])=>GITEMS[id]).map(([id,x,y,rot])=>Object.assign(newItem(id,t,null),{x,y,rot:rot||0})); GS.stash=[]; GS.tokens=12; }
  fitBag(); GS.undo=[]; GS.max=heroMax(); GS.hp=GS.max; GS.lagH=GS.hp;
  if(k>0) loadStage(k); j=Math.max(0,Math.min(LINE.length-1,j|0)); if(j>0) devJumpCar(j);
  GS.hp=GS.max; GS.lagH=GS.hp; renderBag(); setGameSpeed(GAME_SPD); sfx.chime();
  setTimeout(()=>say(tr('노선 테스트'), KE(`${STAGE.short} · ${GS.ci+1}호차 · 저장되지 않는 테스트 판이에요`, `${STAGE.short} · car ${GS.ci+1} · test run, not saved`)+(OPT.devGod?' · '+tr('무적'):''), 2.6), 3300); }
function devJumpCar(j){ if(!GS.on || j<0 || j>=LINE.length) return; hideArrange(); gOverlay.hidden=true; GS.cut=null; GS.spc=null; GS.ents=GS.ents.filter(a=>!a.e);
  GS.leg=j; GS.legStart=TR.ex; GS.qi=0; GS.quickStop=null; GS.qDwell=null; GS.atStop=STOPS[j]; GS.nextStop=LINE[j].stop; GS.stationDone=j-1; GS.arriving=false; TR.phase='stop'; TR.v=0; TR.door=1; GS.departT=2.4; GS.doorWant=true; enterCar(j); }
function devClearFoes(){ const H=GS.hero; if(!H) return; for(const a of foes()){ if(a.dead || a.kane || !a.e) continue; a.e.shield=false; a.e.evade=0; damage(H, a, a.e.hp+999, {knock:true, crit:true}); } }
// 평소엔 바로 게임으로(자동 테스트는 실험실에서 시작)
if(!navigator.webdriver && !/lab/.test(location.hash)) setMode('game');
requestAnimationFrame(t=>{ last=t; loop(t); });
})();


