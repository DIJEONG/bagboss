// --- 속도 · 스타일 · 모드 · 입력 ---
let gamePaused=false;
const GAME_SPD=1.25;
function setGameSpeed(v){ gamePaused=v===0; paused=gamePaused; if(v>0) playSpeed=v; document.querySelectorAll('#gSpeed button').forEach(b=>b.setAttribute('aria-pressed', +b.dataset.s===v?'true':'false')); }
document.querySelectorAll('#gSpeed button').forEach(b=>b.addEventListener('click',()=>setGameSpeed(+b.dataset.s)));
const gStyles=document.getElementById('gStyles');
PRESETS.forEach((p,i)=>{ if(p.scene && p.scene!=='noir') return; const b=document.createElement('button'); b.type='button'; b.textContent=p.name; b.dataset.i=i;
  b.addEventListener('click',()=>{ loadPreset(i); gStyles.querySelectorAll('button').forEach(x=>x.setAttribute('aria-pressed',x===b?'true':'false')); }); gStyles.appendChild(b); });
let autoLab=true;
function stopRun(){ GS.on=false; gOverlay.hidden=true; sayEl.hidden=true; setGameSpeed(GAME_SPD); }
function setMode(m){
  const game=m==='game'; document.body.classList.toggle('game-mode',game); requestAnimationFrame(fitDevice);
  document.querySelectorAll('#modeSeg button').forEach(b=>b.setAttribute('aria-pressed', b.dataset.m===m?'true':'false'));
  if(game){ if(typeof editing!=='undefined'&&editing) setEditing(false); autoLab=autoOn; autoOn=false; animFps=20; setScene('subway'); startRun(); if(!navigator.webdriver) showTitle(); }
  else { stopRun(); autoOn=autoLab; animFps=12; setScene('forest'); }
  requestAnimationFrame(()=>{ fit(); placeUI(); });
}
document.querySelectorAll('#modeSeg button').forEach(b=>b.addEventListener('click',()=>setMode(b.dataset.m)));
stage.addEventListener('pointerdown',e=>{ if(GS.tapW && !e.target.closest('.g-ov')){ e.stopImmediatePropagation(); e.preventDefault(); tapFire(true); } }, true);   // 콤보 쇼: 탭!
stage.addEventListener('pointerdown',e=>{ if(!GS.on || scene!=='subway' || e.target.closest('.g-ov') || e.target.closest('.sb-arrange')) return; const r=canvas.getBoundingClientRect();
  if(e.clientY>r.top+r.height*.67){ heroDuck(true); return; }                                             // 화면 아래쪽 1/3 = 쭈그리기
  manual(e.clientX<r.left+r.width/2?-1:1); });
window.addEventListener('keydown',e=>{ if(!GS.on||scene!=='subway') return; if(e.key==='ArrowLeft'||e.key==='a') manual(-1); if(e.key==='ArrowRight'||e.key==='d') manual(1);
  if(e.key==='ArrowDown'||e.key==='s'){ e.preventDefault(); heroDuck(true); } });

