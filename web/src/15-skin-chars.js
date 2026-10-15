function skinPvClose(){ const P=GS.skinPv; if(!P) return; if(peBoxEl) peBoxEl.hidden=true; P.hid.forEach(a=>a.hidden=false); const Hh=GS.hero; if(Hh){ Hh.d.x=P.x; Hh.d.y=P.y; Hh.d.flip=P.flip; Hh.wpn=P.wpn||null; setAnim(Hh,'idle'); }
  GS.skinPv=null; GS.camZ=1; GS.fade=P.fade; pvBox().hidden=true; stage.classList.remove('pv-on');
  if(P.fromTitle) showTitle(); }   // 타이틀에서 열었으면 타이틀로 돌아간다
function skinPvTick(dt){ const P=GS.skinPv, Hh=GS.hero; if(!Hh){ skinPvClose(); return; } P.t+=dt; const t=P.t%9.2; sayEl.hidden=true; GS.fade=0;
  if(P.play){ if(!P.playing){ P.playing=true; Hh.d.x=P.cx; Hh.d.flip=false; setAnim(Hh,P.play); } else if(Hh.anim==='idle'){ P.play=null; P.playing=false; } GS.camZ=P.z1?1:3.0; GS.camC=[P.cx/W,(Hh.d.y-34)/H]; return; }   /* 자세 편집기: 동작 전체 재생 */
  if(P.fixed){ if(Hh.anim!=='__hold'||Hh.pose!==P.fixed){ JW_SEQ.__hold=[[P.fixed,999999]]; setAnim(Hh,'__hold'); Hh.prev=P.fixed; } Hh.d.x=P.cx; Hh.d.flip=false; GS.camZ=P.z1?1:3.0; GS.camC=[Hh.d.x/W,(Hh.d.y-34-((POSES[P.fixed]&&POSES[P.fixed].air)||0))/H]; return; }   /* 자세 실험실: 한 자세로 고정해 크게 본다(공중 자세는 카메라도 함께 올라간다) */
  const ph = t<1.2?0 : t<3.6?1 : t<5.6?2 : t<7.8?3 : 4;
  if(ph!==P.ph){ P.ph=ph; P.wq=ph===1?[P.cx+16, P.cx-16, P.cx]:null; if(ph!==1){ Hh.d.x=P.cx; Hh.d.flip=false; } setAnim(Hh, ph===2?'gx_'+(OPT.skin||'jw') : ph===4?'round' : 'idle'); }
  if(ph===1 && P.wq && P.wq.length){ const tx=P.wq[0]; if(Math.abs(Hh.d.x-tx)<1.5){ P.wq.shift(); if(!P.wq.length){ Hh.d.flip=false; setAnim(Hh,'idle'); } } else { Hh.d.flip=tx<Hh.d.x; moveTo(Hh, tx, 34, dt); } }   // 실제로 걸어서 보폭이 맞는다(제자리 덜덜 없음)
  P.spin = ph===3 ? (t-5.6)/2.2 : 0;
  GS.camZ=3.0; GS.camC=[Hh.d.x/W, (Hh.d.y-34)/H]; }
const skinAcc=()=>{ const S=SKINS[(typeof OPT!=='undefined'&&OPT.skin)||'jw']; return S&&S.acc; };
function applySkin(k,quiet){ if(!SKINS[k]) k='jw'; const m=SKIN_CACHE[k]||(SKIN_CACHE[k]=skinModel(k)); JW_HERO.model3=m; if(GS.hero && GS.hero.d && GS.hero.d.jw) GS.hero.d.model3=m;
  if(!quiet){ OPT.skin=k; optSave(); } }
const KNIGHT = { name:'기사', x:88, y:101, flip:false, rig:RIG_K, smear:'smearK_', p:{ head:'k_head', torso:'k_torso', armF:'k_arm', armB:'k_armB', thighF:'k_thigh', shinF:'k_shin', thighB:'k_thighB', shinB:'k_shinB', wpn:'k_sword', off:'k_shield', scarf:'k_scarf' }, eye:null, glow:true };
const CHARS = [
  KNIGHT,
  { name:'해골', x:168, y:101, flip:true, rig:RIG_S, smear:'smearS_', p:{ head:'s_skull', torso:'s_rib', armF:'s_arm', armB:'s_armB', thighF:'s_thigh', shinF:'s_shin', thighB:'s_thighB', shinB:'s_shinB', wpn:'s_axe', off:'s_shield' }, eye:[4,-7], glow:false },
].map(d=>({ d, anim:'idle', si:0, hold:6, pose:'idle0', prev:'idle0', k:0, phaseN:6, flash:0, lastR:0, scarfHold:0, scarfF:0, blink:false, jw:null,
  hidden:false, dead:false, remap:0, wpn:null, grammar:null, action:null, queue:[] }));
const SKEL = CHARS[1].d;
const builtinK = d => d===KNIGHT || d===KNIGHT_MINI || d===FIGHTER_A || d===NOIR_HERO;
const baseKnight = () => scene==='forest' ? KNIGHT : scene==='octagon' ? FIGHTER_A : scene==='noir' ? NOIR_HERO : KNIGHT_MINI;
const m32 = a => ((a%32)+32)%32;
let freeze=0, shakeX=0, shakeAmp=1, tick=0, autoOn=true, autoT=0, turn=0, paused=false;
