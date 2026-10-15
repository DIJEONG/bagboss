// ===== 막차의 동료들: 노 차장(정리) · 사보(허풍 · 장물아비) · 미니(신문팔이) — 받아치는 쪽은 '나' =====
const CAST={ cond:{ n:'노 차장', c:'#6ec6ff' }, saboo:{ n:'사보', c:'#ffcf5a' }, minnie:{ n:'미니', c:'#ff8a5a' }, me:{ n:'나', c:'#cfc6e6' } };
const VOX={ cond:{ f:150, type:'triangle', ms:48, span:5, vol:.05, slide:1 }, saboo:{ f:240, type:'square', ms:36, span:8, vol:.022, slide:.94 }, minnie:{ f:430, type:'triangle', ms:39, span:7, vol:.045, slide:1.06 }, me:{ f:118, type:'sine', ms:46, span:3, vol:.05, slide:.98 } };
const VOWEL=[2,3,1,2,1,2,0,1,-2,-1,-1,-1,-2,-3,-2,-2,-3,-3,-4,-3,4];
function blip(who,ch){ try{ if(!SND.ctx || SND.muted || !SND.sfx) return; const V=VOX[who]||VOX.cond, code=ch.charCodeAt(0);
  let st=(code>=0xAC00&&code<=0xD7A3)?VOWEL[Math.floor(((code-0xAC00)%588)/28)]*V.span/4:((code*7)%(V.span*2))-V.span; st+=(Math.random()-.5)*1.2;
  const c=SND.ctx, f=V.f*Math.pow(2,st/12), t=c.currentTime, d=V.ms/1000*.85, o=c.createOscillator(), g=c.createGain();
  o.type=V.type; o.frequency.setValueAtTime(f,t); o.frequency.linearRampToValueAtTime(f*V.slide,t+d); g.gain.setValueAtTime(0,t); g.gain.linearRampToValueAtTime(V.vol,t+.006); g.gain.exponentialRampToValueAtTime(.0005,t+d);
  o.connect(g); g.connect(SND.sfx); o.start(t); o.stop(t+d+.02); }catch(e){} }
function drawPortrait(cv,who){ const c=cv.getContext('2d'), W=cv.width, H=cv.height, ink='#14121c', bg=(CAST[who]||CAST.cond).c;   // 잉크 실루엣 + 소품 하나
  c.clearRect(0,0,W,H); const g=c.createRadialGradient(W*.5,H*.4,2,W*.5,H*.5,W*.8); g.addColorStop(0,bg); g.addColorStop(1,'#0e0d14'); c.fillStyle=g; c.fillRect(0,0,W,H);
  c.fillStyle=ink; c.beginPath(); c.moveTo(W*.1,H); c.quadraticCurveTo(W*.16,H*.66,W*.5,H*.64); c.quadraticCurveTo(W*.84,H*.66,W*.9,H); c.fill(); c.fillRect(W*.43,H*.5,W*.14,H*.16);
  c.beginPath(); c.ellipse(W*.5,H*.42,W*.16,H*.19,0,0,7); c.fill();
  if(who==='cond'){ c.fillRect(W*.3,H*.16,W*.4,H*.12); c.fillRect(W*.25,H*.27,W*.5,H*.04); c.fillStyle='#ffcf5a'; c.fillRect(W*.47,H*.19,W*.06,H*.05); c.fillRect(W*.6,H*.76,W*.03,H*.14); c.fillStyle='rgba(255,255,255,.55)'; c.fillRect(W*.26,H*.27,W*.2,H*.012); }   // 차장 모자 · 배지 · 회중시계 줄
  else if(who==='saboo'){ c.beginPath(); c.ellipse(W*.47,H*.27,W*.19,H*.08,-.2,0,7); c.fill(); c.fillStyle='#9fe6ff'; c.fillRect(W*.35,H*.38,W*.3,H*.05); c.fillStyle='#ffcf5a'; c.fillRect(W*.53,H*.5,W*.05,H*.04); c.strokeStyle='#cfc3a6'; c.lineWidth=W*.02; c.beginPath(); c.moveTo(W*.38,H*.68); c.lineTo(W*.5,H*.86); c.lineTo(W*.62,H*.68); c.stroke(); }   // 넘긴 머리 · 선글라스 · 금니 · 넓은 깃
  else if(who==='minnie'){ c.beginPath(); c.ellipse(W*.5,H*.26,W*.22,H*.1,0,0,7); c.fill(); c.fillRect(W*.5,H*.3,W*.26,H*.04); c.fillStyle='#f1e6cf'; c.fillRect(W*.14,H*.72,W*.34,H*.24); c.fillStyle=ink; for(let k=0;k<4;k++) c.fillRect(W*.18,H*(.76+k*.045),W*.26,H*.015); }   // 헌팅캡 · 신문 묶음
  else { c.beginPath(); c.ellipse(W*.48,H*.27,W*.17,H*.07,-.15,0,7); c.fill(); c.fillStyle='#f1e6cf'; c.beginPath(); c.moveTo(W*.42,H*.66); c.lineTo(W*.5,H*.8); c.lineTo(W*.58,H*.66); c.fill(); c.fillStyle='#d6453a'; c.fillRect(W*.48,H*.69,W*.04,H*.16); } }   // 나: 넘긴 머리 · 흰 셔츠 · 붉은 넥타이
const tkBox=(()=>{ const d=document.createElement('div'); d.className='talk'; d.hidden=true;
  d.innerHTML='<div class="tk-por"><canvas width="64" height="64"></canvas></div><div class="tk-body"><b class="tk-name"></b><p class="tk-text"></p><div class="tk-ch"></div></div><button type="button" class="tk-skip">건너뛰기</button><span class="tk-more">▼</span>';
  ['pointerdown','touchstart','mousedown'].forEach(t=>d.addEventListener(t,e=>e.stopPropagation()));
  d.addEventListener('click',e=>{ sndInit(); const T=GS.talk; if(!T) return; if(e.target.closest('.tk-skip')){ tkSkip(); return; } const bt=e.target.closest('.tk-ch button'); if(bt){ tkPick(+bt.dataset.k); return; }
    if(T.choices) return; if(T.typing) tkFinish(); else tkNext(); });
  stage.appendChild(d); return d; })();
function talk(lines,done){ if(GS.talk){ (GS.talkQ=GS.talkQ||[]).push([lines,done]); return; } GS.talk={ lines:lines.slice(), i:-1, done, picked:null };
  const host=(!gOverlay.hidden && gOverlay.parentElement)?gOverlay.parentElement:stage; if(tkBox.parentElement!==host) host.appendChild(tkBox); tkBox.classList.toggle('on-dev', host!==stage);   // 매점 등 오버레이 위에 뜨게
  sayEl.hidden=true; tkBox.hidden=false; tkNext(); }
function tkShow(who,html){ const T=GS.talk, C=CAST[who]||CAST.cond, V=VOX[who]||VOX.cond; tkBox.style.setProperty('--tc',C.c); drawPortrait(tkBox.querySelector('canvas'),who);
  tkBox.querySelector('.tk-name').textContent=tr(C.n); tkBox.querySelector('.tk-ch').innerHTML=''; tkBox.querySelector('.tk-more').hidden=true;
  const tmp=document.createElement('div'); tmp.innerHTML=html; T.txt=tmp.textContent; T.html=html; T.k=0; T.typing=true; T.who=who; T.choices=null; const el=tkBox.querySelector('.tk-text'); el.textContent='';
  const step=()=>{ if(GS.talk!==T || !T.typing) return; T.k++; const ch=T.txt[T.k-1]||''; el.textContent=T.txt.slice(0,T.k); if(ch && !/[\s.,!?…·—:()]/.test(ch)) blip(who,ch);
    if(T.k>=T.txt.length){ tkFinish(); return; } T.tm=setTimeout(step, V.ms*(/[.!?…]/.test(ch)?5:/[,·—:]/.test(ch)?2.5:1)); };
  T.tm=setTimeout(step,80); }
function tkFinish(){ const T=GS.talk; if(!T) return; clearTimeout(T.tm); T.typing=false; tkBox.querySelector('.tk-text').innerHTML=T.html; tkBox.querySelector('.tk-more').hidden=false; }
function tkNext(){ const T=GS.talk; if(!T) return; T.i++; if(T.i>=T.lines.length){ tkEnd(); return; } const L=T.lines[T.i];
  if(L[0]==='me'){ T.choices=L[1]; T.typing=false; const C=CAST.me; tkBox.style.setProperty('--tc',C.c); drawPortrait(tkBox.querySelector('canvas'),'me'); tkBox.querySelector('.tk-name').textContent=tr(C.n);
    tkBox.querySelector('.tk-text').textContent=''; tkBox.querySelector('.tk-more').hidden=true; tkBox.querySelector('.tk-ch').innerHTML=L[1].map((o,k)=>`<button type="button" data-k="${k}">${tr(o[0])}</button>`).join(''); return; }
  tkShow(L[0],L[1]); if(L[2]) try{ L[2](); }catch(e){} }
function tkPick(k){ const T=GS.talk; if(!T||!T.choices) return; const o=T.choices[k]; if(!o) return; blip('me',o[0][0]||'아'); if(o[1]) T.lines.splice(T.i+1,0,o[1]); if(o[2]) T.picked=o[2]; T.choices=null; tkNext(); }
function tkSkip(){ const T=GS.talk; if(!T) return; clearTimeout(T.tm); for(let i=T.i+1;i<T.lines.length;i++){ const L=T.lines[i]; if(L[0]!=='me' && L[2]) try{ L[2](); }catch(e){} } tkEnd(); }
function tkEnd(){ const T=GS.talk; if(!T) return; clearTimeout(T.tm); GS.talk=null; tkBox.hidden=true; try{ T.done&&T.done(T.picked); }catch(e){} if(GS.talkQ&&GS.talkQ.length){ const q=GS.talkQ.shift(); talk(q[0],q[1]); } }
// 한 번만: 바로(talkOnce) · 싸움이 멈춘 틈에(talkSoon)
function talkOnce(key,lines,done){ META.talks=META.talks||{}; if(META.talks[key] || (navigator.webdriver && !GS.talkTest)){ done&&done(); return; }   /* 자동 점검 환경에선 대화를 건너뛴다(프롤로그와 같게) */ META.talks[key]=1; metaDirty=true; talk(typeof lines==='function'?lines():lines, done); }
function talkSoon(key,fn){ META.talks=META.talks||{}; if(META.talks[key]) return; GS.talkSoon=GS.talkSoon||[]; if(GS.talkSoon.some(q=>q.key===key)) return; GS.talkSoon.push({ key, fn }); }
const talkSafe=()=>GS.on && !GS.tower && !GS.prologue && !GS.cine && !GS.kane && !GS.spc && !GS.croute && !GS.bonus && !GS.demo && !GS.tapW && !foes().length && (typeof gOverlay==='undefined' || gOverlay.hidden) && !(typeof drag!=='undefined' && drag && drag.ghost);
function talkTick(){ if(GS.talk || !GS.talkSoon || !GS.talkSoon.length || !talkSafe()) return; const q=GS.talkSoon.shift(); talkOnce(q.key, q.fn); }
const TALK={
  intro:()=>[ ['cond','막차에 오신 걸 환영해요. 이 열차는 <b>종점</b>까지 가요. 서는 역은 몇 안 되고요.'],
    ['minnie','호외요, 호외! <b>보스의 가방</b>이 막차에서 터졌대요! …손님 거죠, 그 가방?'],
    ['me',[ ['…짧게.', ['minnie','네네! 서류가 <b>칸마다</b> 흩어졌어요. 싸워서 줍거나, 매점에서 되사면 돼요!']],
            ['그래서?', ['saboo','그래서 제가 있죠. 흩어진 서류 <b>주워 오는 게 제 전문</b>이에요. 값만 맞으면.']] ]],
    ['saboo','저는 사보. 매점에서 뵙죠. 금니는 덤이고요.'],
    ['cond','정리하면 — <b>붙어 있는 서류는 순서대로 이어져요.</b> 시작기 ▶가 맞으면, 경로를 따라 콤보가 나가요.'] ],
  fork:()=>[ ['cond','갈림길이네요. 서류가 상황에 따라 <b>다른 쪽으로 갈라질</b> 수 있어요.'],
    ['me',[ ['한쪽으로만 가게 해.', ['cond','블록을 누르면 <b>갈림</b> 단추가 나와요. 누르면 그쪽으로 고정, 다시 누르면 풀려요.']],
            ['알아서 가겠지.', ['cond','그럼 열차가 알아서 갑니다. 적이 떠 있으면 위로, 쓰러져 있으면 아래로요.']] ]],
    ['cond','정리하면 — 갈림길은 <b>상황</b>이 고르고, 고정은 <b>손님</b>이 골라요.'] ],
  starter:()=>[ ['cond','<b>시작기 ▶</b>를 얻으셨네요. 이게 맞으면 <b>콤보 창</b>이 열려요.'],
    ['saboo','▶ 한 장이면 서류 석 장 값은 하죠. 파실 생각 있으시면…'],
    ['me',[ ['안 팔아.', ['saboo','네네, 농담이에요. 반쯤은.']], ['어디에 둬?', ['cond','옆에 이음기 ●나 마무리기 ■를 붙이세요. 붙은 순서대로 이어져요.']] ]],
    ['cond','정리하면 — ▶ 옆에 ●·■를 붙이면 <b>새 콤보 경로</b>가 생겨요.'] ],
  finisher:()=>[ ['minnie','<b>마무리기 ■</b>다! 마무리가 들어가면 무조건 1면이에요!'],
    ['me',[ ['1면은 관심 없어.', ['minnie','에이, 그래도 박수는 받잖아요!']], ['어디에 둬?', ['cond','경로 <b>끝</b>에요. 집어 들면 <b>금색 칸</b>이 추천 자리예요.']] ]],
    ['cond','정리하면 — ■는 경로를 <b>완성</b>해요. 집으면 금색 칸을 보세요.'] ],
  shop:()=>[ ['saboo','어서 오세요. 오늘 밤 주운 서류들이에요. <b>하나만</b> 고르실 수 있어요.'],
    ['me',[ ['비싸군.', ['saboo','토큰 2개면 <b>목록을 새로</b> 뽑아 드리죠. 제 전문이에요.']], ['뭐가 좋지?', ['saboo','카드 아래 <b>금색 줄</b>을 보세요. 손님 콤보가 어떻게 바뀌는지 적어 놨어요.']] ]],
    ['cond','정리하면 — 고른 서류는 <b>보류함</b>으로 가요. 가방에 끌어 넣으면 경로가 이어져요.'] ],
  book:B=>[ ['minnie',`호외요! <b>${B.n}</b>, 콤보 도감 첫 완성이에요!`],
    ['me',[ ['…그래서?', ['minnie','열 개를 다 채우면 — <b>1면 통째로</b> 손님 거예요!']], ['다음은?', ['minnie','도감에 아직 흐린 콤보가 아홉 개나 남았어요!']] ]],
    ['cond','정리하면 — 도감은 <b>실전에서 성공한 콤보</b>만 채워져요.'] ] };
// ===== 프롤로그 서사: 보스의 가방 · 배신 · 복수 =====
const SC_BAG={ hammer:[['hmup',0,1],['hmswing',1,1],['hmback',3,1],['hmdown',4,1]], thunder:[['upper',1,0],['cycle',2,0],['axe',4,0]], bridge:[['knee',1,1],['punch',2,1],['suplex',3,1]], signoff:[['knee',1,1],['paper',2,1],['case',3,1]] };   // 장도리 난타 · 낙뢰 · 무너뜨려 꽂기 · 서류가방 결재
const scBag=k=>SC_BAG[k].filter(([id])=>GITEMS[id]).map(([id,x,y])=>Object.assign(newItem(id,1,null),{x,y,rot:0}));
function vaultOpen(){ const P=GS.prologue, H=GS.hero; P.bag=true; GS.pBag=true; H.wpn=null;
  comicT=0; comicSFX(H.d.x+6, H.d.y-28, '클랭!'); sfx.hitK('hammer',false,0); shakeAmp=Math.max(shakeAmp||0,1.5);
  GS.bag=scBag('thunder'); renderBag(); say(tr('보스의 가방'), tr('서류 한 장 한 장이, 보스가 내게 가르친 싸움이다.'), 3.4); }
function scTick(){ const P=GS.prologue, H=GS.hero; if(!GS.croute && !foes().some(a=>!a.sc && !a.dead)) for(const b of GS.bag) b.t=0;   // 콤보 쇼: 평소 기술은 쉬고, 탭 한 번으로 콤보를 연다(쇼와 무관한 적이 있으면 평소대로 싸운다)
  const SF=foes().filter(a=>a.sc && !a.dead && a.anim!=='death');
  for(const a of SF){ a.e.cdT=Math.min(a.e.cdT,-3); a.e.hp=Math.max(a.e.hp,999); }                       // 쇼 동안 적은 덤비지 않고, 콤보가 끝날 때 쓰러진다
  if(GS.croute) P.scOpen=true;
  if(P.scFired && !GS.croute && !GS.tapW){
    if(P.scOpen && GS.time-P.scFired>.35){ for(const a of SF){ a.e.hp=1; damage(H,a,9,{knock:true}); } P.scFired=0; P.scOpen=false; }
    else if(!P.scOpen && GS.time-P.scFired>2.4) P.scFired=0;
    return; }
  if(!GS.tapW && !GS.croute && !P.scFired && SF.length && canAct(H)){ const st=GS.bag.find(b=>croleOf(b.id)==='S'); if(!st) return;
    const it=GITEMS[st.id], T=SF.slice().sort((a,c)=>Math.abs(a.d.x-H.d.x)-Math.abs(c.d.x-H.d.x))[0], d=Math.abs(T.d.x-H.d.x);
    if(d<=Math.max(it.reach+4,48) && d>=8){ GS.tapW={ t:0, i:GS.bag.indexOf(st), T }; GS.slowT=1.6; } } }               // 기회: 슬로 + 탭!(닿지 않으면 탭 순간 파고든다)
function tapFire(just){ const W=GS.tapW; if(!W) return; GS.tapW=null; GS.slowT=0; const H=GS.hero, P=GS.prologue; if(!W.T || W.T.dead || !GS.bag[W.i]) return;
  if(H.anim==='walk') setAnim(H,'idle'); face(H,W.T.d.x);
  { const it=GITEMS[GS.bag[W.i].id], sg=Math.sign(W.T.d.x-H.d.x)||1; if(Math.abs(W.T.d.x-H.d.x)>it.reach-2 && canAct(H)){ H.d.x=W.T.d.x-sg*Math.max(10,it.reach-4); fkLines(H); } }   // 파고들기: 큰 적도 시작기 거리 안으로
  if(canAct(H)){ useSkill(W.i, W.T, !!just); if(P) P.scFired=GS.time; }
  if(just){ comicT=0; comicSFX(W.T.d.x, W.T.d.y-62, 'JUST!'); shakeAmp=Math.max(shakeAmp||0,2.6); HITFX.push({ k:'tapok', x:W.T.d.x, y:W.T.d.y-34, t:0, life:.32 }); } }
function pagesBurst(x,y){ HITFX.push({ k:'pages', x, y, t:0, life:2.4, P:Array.from({length:30},(_,k)=>({ vx:(k%2?1:-1)*(70+Math.random()*200), vy:-(30+Math.random()*140), r:Math.random()*6.3, vr:(Math.random()-.5)*14, ph:Math.random()*6 })) }); }
function bagScatter(){ try{ bagEl.querySelectorAll('.inv-grid .ii').forEach(el=>{ el.style.transition='transform .8s cubic-bezier(.3,0,.8,.6), opacity .8s';
    el.style.transform=`translate(${Math.round((Math.random()-.5)*320)}px,${Math.round(-60-Math.random()*220)}px) rotate(${Math.round((Math.random()-.5)*150)}deg)`; el.style.opacity='0'; }); }catch(e){}
  setTimeout(()=>{ GS.bag=(GS.pKit||[]).map(b=>({...b})); renderBag(); }, 860); }
function kaneStart(){ const H=GS.hero; const held=foes().map(a=>a.e.t); GS.ents=GS.ents.filter(a=>!a.e); GS.kane={ t:0, ph:0, held }; GS.departT=999; H.wpn='w_case';   /* 함께 탄 적은 장면 뒤에 태운다 */                  // 막차 안: 배신자 빅터 케인(칸 반대편에서 걸어온다)
  const before=new Set(GS.ents); spawnWave(['kane'],false); const K=GS.ents.find(a=>!before.has(a)&&a.e);
  if(!K){ GS.kane=null; GS.pBag=false; GS.departT=2.4; return; }
  const side=H.d.x>SB.W/2?-1:1; K.kane=true; K.e.hp=K.e.max=9999; K.e.cdT=-99; K.d.x=side<0?110:SB.W-110; K.wpn='w_umb'; setAnim(K,'idle'); face(K,H.d.x); GS.kane.K=K; GS.kane.side=side;
  setTimeout(()=>{ if(GS.kane) sayEl.hidden=true; }, 60); }                                                     // 칸 안내는 장면 뒤로
function kaneSlash(){ const H=GS.hero; sfx.swing(); shakeAmp=Math.max(shakeAmp||0,3.6); comicT=0; comicSFX(H.d.x+12, H.d.y-58, '슥!');
  HITFX.push({ k:'slash', x:H.d.x+8, y:H.d.y-34, t:0, life:.3 }); pagesBurst(H.d.x+8, H.d.y-32); H.wpn=null; bagScatter(); }
function kaneUpdate(dt){ const S=GS.kane, H=GS.hero, K=S&&S.K; if(!S) return; S.t+=dt; if(!K){ GS.kane=null; return; }
  const sd=S.side||1, gone=()=>{ GS.ents=GS.ents.filter(a=>a!==K); S.ph=6; S.t6=S.t; };
  if(S.ph<5){ face(H,K.d.x); K.e.cdT=-99; if(H.anim==='walk') setAnim(H,'idle'); }
  if(S.ph<3){ face(K,H.d.x); const tx=H.d.x-sd*58; if(Math.abs(K.d.x-tx)>3) moveTo(K,tx,34,dt); else if(K.anim==='walk') setAnim(K,'idle'); }   // 대사하며 천천히 다가온다
  if(S.ph===0 && S.t>.7){ S.ph=1; comicSay(K,tr('가방은 두고 가라. 보스는 이미 종점에서 내렸어.'),'speech',true); }
  if(S.ph===1 && S.t>3.6){ S.ph=2; comicSay(H,tr('그럼 나도 종점까지 간다.'),'speech',true); }
  if(S.ph===2 && S.t>6.2){ S.ph=3; S.d0=S.t; }                                                              // 지팡이 칼: 남은 거리를 한 번에
  if(S.ph===3){ face(K,H.d.x); K.d.x+=(H.d.x-sd*26-K.d.x)*Math.min(1,dt*16); if(S.t-S.d0>.22){ S.ph=4; kaneSlash(); } }
  if(S.ph===4 && S.t>8.0){ S.ph=5; S.t5=S.t; comicSay(K,tr('종점에서 기다리지.'),'speech',true); }
  if(S.ph===5 && S.t>S.t5+1.2){ if(S.ex==null) S.ex=K.d.x>SB.W/2?SB.W+60:-60; face(K,S.ex); moveTo(K,S.ex,72,dt); if(K.d.x<=10 || K.d.x>=SB.W-10 || S.t-S.t5>5) gone(); }   // 가까운 연결 통로 문으로 사라진다
  if(S.ph<6 && S.t>18){ gone(); }                                                                           // 안전장치: 오래 걸리면 장면을 끝낸다
  if(S.ph===6 && S.t>S.t6+.5){ S.ph=7; say('BAG BOSS · '+tr('막차'), tr('남은 건 서류')+` ${GS.bag.length}`+tr('장. 막차는 기다려 주지 않는다.'), 3.4); }
  if(S.ph===7 && S.t>S.t6+3.8){ GS.kane=null; GS.pBag=false; H.wpn=null;
    const go=()=>{ GS.departT=1.4; say(STAGE.name, STAGE.intro||'', 3); if(S.held && S.held.length){ spawnWave(S.held,true); setTimeout(()=>say('적이 탔다!', S.held.map(t=>ETYPES[t]?ETYPES[t].n:t).join(' · '), 1.8), 3200); } };
    if(!(META.talks||{}).intro) setTimeout(()=>talkOnce('intro', TALK.intro, go), 400); else go(); } }   // 막차의 동료들 첫 소개
function routeHintMaybe(){ if(GS.demo || GS.tower || GS.prologue || GS.kane || GS.cine) return; talkSoon('intro', TALK.intro); }   // 프롤로그를 건너뛴 판: 싸움이 멈춘 틈에 첫 소개
function startPrologue(){ const H=GS.hero; GS.prologue={ x:0, wi:0 }; COMIC.length=0; setTimeout(()=>hint('move'),3200); GS.state='corridor'; GS.ents=[H]; GS.props=[]; GS.cans=[]; GS.ev=null; GS.pt=null;
  GS.pKit=GS.bag.map(b=>({...b})); GS.bag=scBag('hammer'); GS.stash=[]; renderBag();                         // 시작 가방은 맡겨 두고(케인 장면 뒤에 돌려받는다), 복도에선 장도리 네 수
  H.d.x=60; H.d.flip=false; H.wpn='w_hammer'; setAnim(H,'idle'); TR.v=0; TR.phase='stop'; TR.door=0; GS.doorWant=false; GS.departT=9999; GS.atStop=null;
  say(tr('자정. 보스가 죽었다.'),tr('지하 기계실에 묶여 있었다. 공구함엔 장도리 하나.'),3.2); }
function corridorUpdate(dt){ const P=GS.prologue, H=GS.hero; if(!P||!H) return; lampTick(dt); if(H.anim!=='hangkick' && H.airOv) H.airOv=0; if(!P.out && !P.bag && H.wpn!=='w_hammer') H.wpn='w_hammer';
  if(H.d.x>230 && P.x<CORR_LEN){ const d=Math.min(H.d.x-230, CORR_LEN-P.x); H.d.x-=d; P.x+=d; for(const a of GS.ents) if(a!==H) a.d.x-=d; }     // 카메라 트래킹(세상이 뒤로 흐른다)
  if(H.d.x<24) H.d.x=24;
  while(P.wi<CORR_WAVES.length && P.x>=CORR_WAVES[P.wi][0] && foes().length<7){ const [,list,side,sck]=CORR_WAVES[P.wi]; if(sck && (!P.bag || foes().length)) break; if(sck){ GS.bag=scBag(sck); renderBag(); P.scK=sck; const B=COMBO_BOOK.find(x=>x.id===sck); if(B) say(tr(B.n), tr(B.d), 2.6); } const before=new Set(GS.ents);
    if(side===0){ const vis=visibleDoors(); if(vis.length){ doorOpen(vis[Math.floor(Math.random()*vis.length)], list); P.wi++; continue; } }      // 문에서 등장(보이는 문이 없으면 앞쪽에서)
    spawnWave(list,false); GS.ents.filter(a=>!before.has(a)).forEach((a,k)=>{ a.d.x = side<0 ? -12-k*16 : SB.W+10+k*16; a.d.flip = side>=0; a.e.cdT=-1.2-k*.5; if(sck) a.sc=sck; }); P.wi++; }
  doorTick(dt);
  if(!P.bag && P.wi>=CORR_VAULT && !foes().length && P.x>=700) vaultOpen();                          // 금고실: 보스의 서류가방
  if(P.bag && !P.out) scTick();
  if(P.wi>=CORR_WAVES.length && !foes().length && P.x>=CORR_LEN-1 && H.d.x>392 && !P.out){ P.out=true; P.outT=0; sfx.door(true); }      // 철문이 열린다
  if(P.out){ P.outT+=dt; const ox=H.d.x; H.d.x=Math.min(H.d.x+40*dt,446); advGait(H,H.d.x-ox,false); face(H,H.d.x+10); if(H.anim!=='walk') setAnim(H,'walk');
    if(P.outT>1.3 && !GS.cine){ startCine(); } } }
function endPrologue(){ const H=GS.hero; H.wpn=null; H.hidden=false; sfx.chime(); setTimeout(()=>{ hint('move') || hint('timer'); saveRun(); },3600);
  GS.prologue=null; TR.phase='stop'; TR.door=1; TR.v=0; GS.doorWant=true; enterCar(0); GS.fade=0; GS.departT=2.4; GS.atStop=START_STOP; GS.legT=0;
  if(GS.pBag) kaneStart(); else { restoreKit(); say(STAGE.name, STAGE.intro||'', 3); } }

