// =========================================================
// 2순위: 타이틀 화면 · 타블로이드 신문 1면 결과 · 칸 이동 문 전환
// =========================================================
const titleEl=document.createElement('div'); titleEl.className='g-title'; titleEl.hidden=true; document.getElementById('stage').appendChild(titleEl);
function showTitle(){ setGameSpeed(0); sayEl.hidden=true; COMIC.length=0;
  titleEl.innerHTML=`<div class="gt-logo">${artURL('case',0,1)?`<img class="gt-case" src="${artURL('case',0,1)}" alt="">`:''}<span class="gt-en">BAG BOSS</span><span class="gt-ko">막차</span></div>
    <p class="gt-sub">LAST TRAIN · 서류가방 하나로 뉴욕 지하철을 접수한다</p>
    <p class="gt-start">▶ 터치해서 ${loadRunSave()?'새로 ':''}출발 <small>PRESS START</small></p>
    ${(()=>{ const S=loadRunSave(); return S?`<button type="button" class="gt-resume" data-resume>이어 하기 · ${STAGES[S.stageIdx||0].short}선 ${(S.ci||0)+1}호차 · ${(S.score||0).toLocaleString()}점</button>`:''; })()}
    <div class="gt-menu"><button type="button" data-t="run">새 판 설정</button><button type="button" data-t="daily">오늘의 노선</button><button type="button" data-t="codex">도감</button><button type="button" data-t="sound">설정</button></div>
    <p class="gt-rec">D · 4 · 6 노선 · 최고 ${META.best.score}점 · ${META.runs}판</p>`;
  titleEl.hidden=false;
  { const rb=titleEl.querySelector('[data-resume]'); if(rb) rb.addEventListener('click',e=>{ e.stopPropagation(); sndInit(); const S=loadRunSave(); if(S) resumeRun(S); }); }
  titleEl.querySelectorAll('[data-t]').forEach(b=>b.addEventListener('click',e=>{ e.stopPropagation(); sndInit(); sfx.click(); hideTitle(true); openMenu(b.dataset.t); })); }
// PC 목업: 아이폰 18 Pro Max 실제 크기(440×956 + 테두리)가 창에 안 들어가면 비율을 지킨 채 통째로 줄인다
function fitDevice(){ const d=document.querySelector('.device'); if(!d) return; const on=PC_MQ.matches && document.body.classList.contains('game-mode');
  const full=980, k=on ? Math.min(1,(innerHeight-32)/full) : 1;   // 베젤 포함 바깥 높이
  d.style.transform = on && k<1 ? `scale(${k.toFixed(4)})` : ''; d.style.marginBottom = on && k<1 ? `${Math.round(16-(1-k)*full)}px` : '';
  if(Math.abs(k-DEV_K)>.001){ DEV_K=k; try{ fit(); }catch(e){} } }   // 배율이 바뀌면 캔버스 해상도도 다시 맞춘다
addEventListener('resize', fitDevice); try{ PC_MQ.addEventListener('change', fitDevice); }catch(e){} setTimeout(fitDevice, 0);
function hideTitle(keepPause){ if(titleEl.hidden) return; titleEl.hidden=true; sndInit(); if(!keepPause){ clearRunSave(); setGameSpeed(GAME_SPD); sfx.chime(); } }   // 타이틀에서 새로 출발하면 저장을 지운다
titleEl.addEventListener('pointerdown',e=>{ e.stopPropagation(); }); titleEl.addEventListener('click',e=>{ if(e.target.closest('button')) return; hideTitle(); });
window.addEventListener('keydown',e=>{ if(!titleEl.hidden && (e.key===' '||e.key==='Enter')){ e.preventDefault(); hideTitle(); } });
// --- 결과: 타블로이드 신문 1면(판이 끝난 순간의 화면을 흑백 망점 '보도 사진'으로) ---
function newsPhoto(url){ const im=new Image(); im.onload=()=>{ const w=240, h=135, c=document.createElement('canvas'); c.width=w; c.height=h; const x=c.getContext('2d'); x.drawImage(im,0,0,w,h);
    const d=x.getImageData(0,0,w,h), B=[0,8,2,10,12,4,14,6,3,11,1,9,15,7,13,5];
    for(let y=0;y<h;y++) for(let i=0;i<w;i++){ const o=(y*w+i)*4, L=(.3*d.data[o]+.59*d.data[o+1]+.11*d.data[o+2])/255, v=Math.pow(L,.8)*1.15 > (B[(y%4)*4+i%4]+.5)/16 ? 236 : 22;   // 4×4 순서 디더(신문 망점)
      d.data[o]=v; d.data[o+1]=v-4; d.data[o+2]=v-14; } x.putImageData(d,0,0); const el=document.getElementById('gPhoto'); if(el) el.src=c.toDataURL(); }; im.src=url; }
function newsCopy(win){ const s=GS.stats, st=STN[LINE[GS.ci].stop], fr=STN[STOPS[GS.ci]];
  const head = win ? `정장 사나이, ${STAGES.length}개 노선 평정!` : (GS.kills>=30 ? `${GS.ci+1}호차의 혈투 — 정장 사나이 끝내 하차` : `${fr.ko} 구간서 쓰러진 정장 사나이`);
  const deck = win ? '애틀랜틱 애비뉴에서 지도에 없는 역까지 — 배신자 케인, 종점에서 쓰러지다' : LANG==='en' ? `${tr(STAGE.name)}, car ${GS.ci+1}, ${tr(fr.ko)} → ${tr(st.ko)} — witnesses keep coming forward` : `${STAGE.name} ${GS.ci+1}호차, ${fr.ko}→${st.ko} 구간 — 목격담 잇따라`;
  const n=v=>Math.round(v||0), dk=v=>Math.round((v||0)*DMG_K).toLocaleString(), jo=(w,a,b)=>{ const c=w.charCodeAt(w.length-1); return c>=0xAC00&&c<=0xD7A3&&(c-0xAC00)%28 ? a : b; };   // 0인 기록은 기사에서 뺀다
  let p1, p2;
  if(LANG==='en'){ const F=[n(s.maxCombo)>1&&`a ${n(s.maxCombo)}-hit chain`, n(s.crits)&&`${n(s.crits)} crits`, n(s.combos)&&`${n(s.combos)} combos`, n(s.counters)&&`${n(s.counters)} counters`, n(s.justs)&&`${n(s.justs)} just counters`].filter(Boolean);
    p1=`He took down ${GS.kills} enemies that day${n(s.outs)?`, throwing ${n(s.outs)} of them out an open door`:''}.${F.length?` Witnesses counted ${F.join(', ')}.`:''}`;
    p2=`${n(s.onTime)||n(s.late)?`The train ran on time ${n(s.onTime)} times${n(s.late)?` and late ${n(s.late)}`:''}. `:''}One rider said, "His tie never moved." Damage dealt ${dk(s.dealt)} · taken ${dk(s.taken)}.`; }
  else { const F=[n(s.maxCombo)>1&&`최대 ${n(s.maxCombo)}연타`, n(s.crits)&&`치명타 ${n(s.crits)}번`, n(s.combos)&&`콤보 ${n(s.combos)}번`, n(s.counters)&&`받아치기 ${n(s.counters)}번`, n(s.justs)&&`저스트 ${n(s.justs)}번`].filter(Boolean);
    p1=`이날 그는 적 ${GS.kills}명을 쓰러뜨렸다.${n(s.outs)?` 그중 ${n(s.outs)}명은 열린 문밖으로 내던졌다.`:''}${F.length?` ${F.join(', ')}${jo(F[F.length-1],'이','가')} 목격됐다.`:''}`;
    p2=`${n(s.onTime)||n(s.late)?`열차는 정시 도착 ${n(s.onTime)}회${n(s.late)?`, 지각 ${n(s.late)}회`:''}를 기록했다. `:''}한 승객은 "넥타이 한 번 안 흐트러지더라"고 전했다. 준 피해 ${dk(s.dealt)}, 받은 피해 ${dk(s.taken)}.`; }
  return { head, deck, p1, p2 }; }
// --- 칸 이동: 강철 통로 문이 닫혔다 열린다 ---
function drawWipe(dt){ const Wp=GS.wipe; if(!Wp) return; Wp.t+=dt; const T=.5, u=Wp.t/T, close = u<.4 ? easeO(u/.4) : u<.6 ? 1 : 1-easeO((u-.6)/.4), half=VW/2*close;
  for(const side of [0,1]){ const x0= side ? VW-half : 0; uiCx.fillStyle='#3a3f4e'; uiCx.fillRect(x0,0,half,H); uiCx.fillStyle='#22242e'; uiCx.fillRect(side?x0:x0+half-4,0,4,H);
    if(half>40){ const wx= side ? x0+18 : x0+half-58; uiCx.fillStyle='#0e0d14'; uiCx.fillRect(wx,60,40,64); uiCx.fillStyle='#6a7898'; uiCx.fillRect(wx+3,63,34,58); uiCx.fillStyle='rgba(255,255,255,.25)'; uiCx.fillRect(wx+5,65,6,40); } }
  if(close>.85 && Wp.label){ uiCx.font='bold 12px Galmuri11,monospace'; uiCx.textAlign='center'; uiCx.fillStyle='#0e0d14'; uiCx.fillText(Wp.label,VW/2+1,H/2+1); uiCx.fillStyle='#ffe27a'; uiCx.fillText(Wp.label,VW/2,H/2); uiCx.textAlign='left'; }
  if(Wp.t>=T) GS.wipe=null; }

