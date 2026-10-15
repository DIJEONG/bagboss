// 개발용 추적: GS.traceOn일 때만 기술 사용 · 콤보 열림/닫힘 · 환경 기술을 기록한다
const dbgSt=a=>a?(a.anim+(a.jug?'@'+Math.round(a.jug.h):'')+(a.e?':'+Math.round(a.e.hp)+'/'+a.e.max:'')):'-';
function dbgT(...a){ if(GS.traceOn){ const L=GS.trace||(GS.trace=[]); L.push([+GS.time.toFixed(2),...a]); if(L.length>600) L.shift(); } }
function useSkill(i,T,manual){ dbgT('use', GS.bag[i]&&GS.bag[i].id, dbgSt(T), GS.croute?GS.croute.k+'/'+GS.croute.uids.length:'', +(GS.comboCD||0).toFixed(1)); const H=GS.hero, b=GS.bag[i], it=GITEMS[b.id]; b.opener = !manual && !GS.demo && !GS.croute && !!it.cond && croleOf(b.id)==='S' && !condOK(it.cond,H,T,foes());   /* 시작기: 원래 조건(어퍼컷=빈사) 없이 콤보를 열 때는 띄우기 위주로 — 한 방에 끝나 콤보가 안 열리는 것을 막는다 */ b.t=0; comboOnUse(b); sfx.swing(); H.pick=null; if(!it.back) face(H,T.d.x); let anim=it.anim, cue=it.cue; const f=H.d.flip?-1:1;
  if(it.combo){ b.combo=(GS.time-(b.last||-9)<2.4)?((b.combo||0)+1)%4:0; b.last=GS.time; anim=['jab','cross','hook','upper'][b.combo]; cue=['m_jab','m_cross','hook','up'][b.combo]; }
  if(H.scoopNext && anim==='upper'){ anim='scoop'; cue=JW_CUE.scoop; } H.scoopNext=false;
  if(T && T.jug && T.jug.h>6 && (anim==='round'||anim==='charge'||anim==='axe')){ anim+='_air'; cue=JW_CUE[anim]; }   // 떠 있는 적: 준비를 줄인 공중 마무리   // 걸고 퍼올리기: 파고든 뒤 퍼 올린다
  const HM={ jab:'hm_swing', cross:'hm_back', hook:'hm_swing', upper:'hm_up', elbow:'hm_back', bfist:'hm_back', stomp:'hm_down' };            // 복도: 장도리 동작으로
  if(GS.prologue && !GS.prologue.bag && it.combo){ b.combo=b.combo%3; anim=['hm_down','hm_swing','hm_back'][b.combo]; cue=JW_CUE[anim]; }                       // 장도리 3콤보: 위→아래 · 왼→오른 · 오른→왼
  else if(GS.prologue && !GS.prologue.bag && HM[anim]){ anim=HM[anim]; cue=JW_CUE[anim]; }
  if(GS.bonus && anim==='throw'){ anim='hook'; cue=JW_CUE.hook; }                                                    // 차는 들 수 없다
  const opts={ cue:cueFor(H,anim,cue), wpn:GS.prologue&&!GS.prologue.bag?'w_hammer':it.wpn, onCue:()=>heroSkill(i,manual) };
  { const F=ATK_FEEL[anim], su=F&&F.step&&!it.back&&!holding(H) ? atkStartup(anim) : 0; if(su>0){ H.dash=f*F.step/su; H.dashT=su; } }
  if(anim.startsWith('hm_')) opts.cues={ hm_dhit:()=>hmTrail(H,'d'), hm_hit:()=>hmTrail(H,'h'), hm_bhit:()=>hmTrail(H,'b') };                   // 장도리 궤적선                                          // 복도: 무엇을 쓰든 손엔 장도리
  if(anim==='hook' && !opts.cues) opts.cues={ h_smear:()=>hmTrail(H,'h') };
  if(anim==='uthrust' && !opts.cues && bagHasLink('pull')) opts.cues={ ut_hit_ft:()=>hmTrail(H,'h') };   // 우산 손잡이로 걸어 당기는 호
  if(anim==='skick'){ const dust=()=>{ dusts.push({x:H.d.x,y:H.d.y,age:0,flip:false}); dusts.push({x:H.d.x,y:H.d.y,age:0,flip:true}); };
    const cres=()=>{ const J=H.jw, air=POSES.sk_kick.air||0, px=J&&J.hips&&J.neck?(J.hips[0]+J.neck[0])/2:-4, py=J&&J.hips&&J.neck?(J.hips[1]+J.neck[1])/2:-31;   /* 회전 중심(몸통 가운데)에 맞춰 발 궤적과 겹치게 */
      const W=(J&&J.W2)?J.W2([px,py]):[H.d.x+f*px, H.d.y+py-air]; HITFX.push({ k:'crescent', x:W[0], y:W[1], r:34, w:13, f, a0:84*Math.PI/180, a1:-104*Math.PI/180, t:0, life:.22 }); };
    const hit=opts.onCue; opts.onCue=()=>{ cres(); hit(); };   // 초승달은 타격 신호와 같은 순간에
    opts.cues={ sk_jump:dust, sk_land:dust }; }   // 초승달: 발이 지나간 앞쪽 궤적
  if((anim==='round'||anim==='round_air') && !opts.cues) opts.cues={ r_spin2:()=>hmTrail(H,'h'), r_smear:()=>hmTrail(H,'h'), r_hit_rt:()=>dusts.push({ x:H.d.x, y:H.d.y, age:0, flip:H.d.flip }) };
  if(anim==='fkick') opts.cues={ fk_smear:()=>fkLines(H), fk_jump:()=>{ const dd=Math.max(0,Math.abs(T.d.x-H.d.x)-20); H.dash=f*dd/.2; H.dashT=.2; }, fk_land:()=>{ H.dash=0; H.dashT=0; dusts.push({ x:H.d.x, y:H.d.y, age:0, flip:H.d.flip }); } };
  if((anim==='charge'||anim==='charge_air')) opts.cues={ ch_run:()=>{ const d=Math.max(0,Math.abs(T.d.x-H.d.x)-16); H.dash=f*Math.max(300,d/.14); H.dashT=Math.max(.05,Math.min(.14,d/300)); } };   // 출발 순간 튀어 나가 적중 자세 전에 도착  // 출발 순간 몸이 튀어 나간다
  if(anim==='cycle'){ const st=sStats(i);                                                            // 공중 자전거 차기: 뛰어올라 두 다리를 번갈아 3연타
    const kickFx=k=>{ const air=(POSES[H.pose]&&POSES[H.pose].air)||0; HITFX.push({ k:'cyw', x:H.d.x+f*13, y:H.d.y-28-air, f, r:9, t:0, life:.2 }); if(T && T.jug && !T.dead) HITFX.push({ k:'cystar', x:T.d.x-f*3, y:T.d.y-34-T.jug.h, t:0, life:.14, s:k?1.25:1 }); };   // 페달 바퀴 · 연타 별
    const extra=(k,last,pop)=>{ kickFx(k); if(!T || T.dead || !T.jug) return; const dx=(T.d.x-H.d.x)*f; if(dx<-10 || dx>36) return; GS.curSrc=b.uid; damage(H,T,Math.max(1,Math.round(st.dmg*k*comboMul(b))),{react:pop?'launch':'head'}); GS.curSrc=null; if(pop && T.jug && !T.dead) T.jug.vy=Math.max(T.jug.vy,200);   /* 마지막 발: 줄어들지 않는 높이로 띄워 다음 기술(도끼 차기)이 닿게 */
      if(GS.croute && GS.croute.uids.includes(b.uid)) GS.croute.hits++; if(last){ comicT=0; comicSFX(T.d.x, T.d.y-62-(T.jug?T.jug.h:0), '팍팍팍!'); } };
    const hit=opts.onCue; opts.onCue=()=>{ kickFx(0); hit(); };
    opts.cues={ cy_jump:()=>{ dusts.push({x:H.d.x,y:H.d.y,age:0,flip:H.d.flip}); const dd=Math.max(0,Math.abs(T.d.x-H.d.x)-16); if(dd>0){ H.dash=f*dd/.14; H.dashT=.14; } },
      cy_k2:()=>extra(.9,false), cy_k3:()=>extra(1.15,true,true), cy_land:()=>{ H.dash=0; H.dashT=0; dusts.push({x:H.d.x,y:H.d.y,age:0,flip:!H.d.flip}); } }; }
  if(anim==='axe'||anim==='axe_air'){ const hit=opts.onCue, air=anim==='axe_air';                     // 도끼 차기: 수직 궤적 → 콰직(떠 있으면 바닥에 꽂혀 튀어 오른다)
    const arcFx=()=>{ const ay=(POSES[H.pose]&&POSES[H.pose].air)||0, tx=T?T.d.x-f*4:H.d.x+f*16; HITFX.push({ k:'axv', x:tx, y0:H.d.y-96-ay, y1:T?T.d.y-26-(T.jug?T.jug.h:0):H.d.y-20, t:0, life:.22 }); };   // 단두대처럼 수직으로 떨어지는 칼날
    opts.cues=air ? { axa_up:()=>{ dusts.push({x:H.d.x,y:H.d.y,age:0,flip:H.d.flip}); const dd=Math.max(0,Math.abs(T.d.x-H.d.x)-14); if(dd>0){ H.dash=f*dd/.12; H.dashT=.12; } }, axa_smear:arcFx, cy_land:()=>{ H.dash=0; H.dashT=0; dusts.push({x:H.d.x,y:H.d.y,age:0,flip:!H.d.flip}); } }
                  : { ax_up:()=>dusts.push({x:H.d.x,y:H.d.y,age:0,flip:H.d.flip}), ax_smear:arcFx };
    opts.onCue=()=>{ hit(); const tx=T?T.d.x:H.d.x+f*18; if(!air) groundImpact(tx, H.d.y, 1.8); HITFX.push({ k:'axring', x:tx, y:H.d.y, t:0, life:.6, cr:Array.from({length:6},(_,k)=>({ sd:k%2?1:-1, a:(Math.random()-.5)*.5, n:3+(k%3) })) }); shakeAmp=Math.max(shakeAmp||0,3); comicT=0; comicSFX(tx, H.d.y-74-(T&&T.jug?T.jug.h:0), '콰직!'); GS.slowT=Math.max(GS.slowT||0,.1); }; }
  if(anim==='suplex'){ const st=sStats(i);                                                            // 저먼 수플렉스: 허리 잡기 → 활처럼 젖혀 → 머리부터 뒤쪽 바닥에
    opts.onCue=()=>{ if(!T.dead && !isDown(T) && Math.abs(T.d.x-H.d.x)<=26){ if(T.jug) T.jug=null; T.held={by:H, t0:GS.time}; T.action=null; T.queue=[]; setAnim(T,'held'); H.kb=0; H.dash=0; H.dashT=0; comicT=0; comicSFX(T.d.x, T.d.y-72, '꽉!'); } };
    opts.cues={ sx_lift:()=>{ if(T.held) HITFX.push({ k:'sxpath', x:H.d.x-f*4, y:H.d.y-26, r:36, f, t:0, life:.55 }); },   // 앞 → 머리 위 → 뒤로 그려지는 점선 궤적
      sx_slam:()=>{ if(!T.held) return; T.held=null; T.airOv=0; T.d.x=Math.max(14,Math.min(SB.W-14,H.d.x-f*24)); T.d.flip=H.d.flip;
        GS.stats.throws=(GS.stats.throws||0)+1; GS.curSrc=b.uid; contribTrig(b.uid); damage(H,T,Math.round(st.dmg*comboMul(b)),{knock:true,crit:true});
        groundImpact(T.d.x,T.d.y,2.0); shakeAmp=Math.max(shakeAmp||0,3.6); GS.slowT=Math.max(GS.slowT||0,.18); if(!OPT.noFlash) HITFX.push({ k:'sig_flash', x:T.d.x, y:T.d.y-30, t:0, life:.12 });
        HITFX.push({ k:'sxboom', x:T.d.x, y:T.d.y-8, t:0, life:.34 }); comicT=0; comicSFX(T.d.x, T.d.y-66, '쿠웅!'); dusts.push({x:T.d.x,y:T.d.y,age:0,flip:T.d.flip}); dusts.push({x:T.d.x,y:T.d.y,age:0,flip:!T.d.flip});
        { const bi=GS.bag.indexOf(b); linkFire(bi,'hit'); linkFire(bi,'knock'); if(GS.croute && GS.croute.uids.includes(b.uid)) GS.croute.hits++; }
        foes().forEach(o=>{ if(o!==T && !isDown(o) && !o.dead && Math.abs(o.d.x-T.d.x)<26) damage(H,o,Math.round(st.dmg*.35),{knock:true,splash:true}); }); GS.curSrc=null; } }; }
  if(anim==='renkan'){ const st=sStats(i);                                                            /* 연환퇴: 1타는 기본 타격(살짝 띄움) · 2타는 꼭대기에서 높이 띄움 */
    opts.cues={ rk_crouch:()=>{ const dd=Math.max(0,Math.abs(T.d.x-H.d.x)-17); if(dd>0){ H.dash=f*dd/.09; H.dashT=.09; } },
      rk_k1:()=>dusts.push({x:H.d.x,y:H.d.y,age:0,flip:!H.d.flip}),
      rk_k2:()=>{ if(!T || T.dead) return; const dx=(T.d.x-H.d.x)*f; if(dx<-10 || dx>36 || (T.jug && T.jug.h>70)) return; GS.curSrc=b.uid; damage(H,T,Math.max(1,Math.round(st.dmg*1.3*comboMul(b))),{react:'launch'}); GS.curSrc=null; if(T.jug && !T.dead){ T.jug.vy=Math.max(T.jug.vy,230); T.jug.vx=f*18; T.jug.pts=Math.min(T.jug.pts,2); T.jug.n=Math.min(T.jug.n,1); }   /* 2타가 진짜 띄우기: 어퍼컷만큼 높이 · 저글 점수와 타수도 어퍼컷 수준으로(1타 살짝 띄움은 준비 동작) */
        if(GS.croute && GS.croute.uids.includes(b.uid)) GS.croute.hits++; GS.slowT=Math.max(GS.slowT||0,.06); },
      rk_land:()=>{ H.dash=0; H.dashT=0; dusts.push({x:H.d.x,y:H.d.y,age:0,flip:H.d.flip}); dusts.push({x:H.d.x,y:H.d.y,age:0,flip:!H.d.flip}); } }; }
  if(anim==='tetsu'){ const hit=opts.onCue;                                                            /* 철산고: 반 보 물러섬 → 파고듦 → 진각 · 등과 어깨 */
    opts.cues={ ts_set:()=>{ H.dash=-f*4/.1; H.dashT=.1; }, ts_step:()=>{ dusts.push({x:H.d.x,y:H.d.y,age:0,flip:!H.d.flip}); const dd=Math.max(0,Math.abs(T.d.x-H.d.x)-17); if(dd>0){ H.dash=f*dd/.06; H.dashT=.06; } } };
    opts.onCue=()=>{ H.dash=0; H.dashT=0; hit(); const fx=H.d.x+f*12, cx=T?T.d.x-f*6:H.d.x+f*20, cy=H.d.y-34;
      groundImpact(fx,H.d.y,1.6); HITFX.push({ k:'tsring', x:fx, y:H.d.y, t:0, life:.7, cr:Array.from({length:8},(_,k)=>({ sd:k%2?1:-1, a:(Math.random()-.5)*.6, n:3+(k%3) })) });   /* 진각: 바닥 균열 · 납작한 이중 충격파 */
      /* 타격 효과는 기본 타격 효과만(번개 섬광 제거) */
      if(!(typeof OPT!=='undefined' && OPT.noFlash)) IMPF=2;                                                 /* 흑백 반전 임팩트 프레임 */
      skTone(72,38,.38,'sine',.28); skNoise(.22,110,.14);                                                    /* 쿵 — 낮은 울림 */
      shakeAmp=Math.max(shakeAmp||0,3.8); GS.slowT=Math.max(GS.slowT||0,.16); comicT=0; comicSFX(cx, cy-40, '쾅!');
      if(xcOn()) xcKick(fx,H.d.y,2.6,70); }; }                                                              /* 건널목: 진각 자리에서 단풍이 한꺼번에 */
  if(anim==='throw'){ const st=sStats(i), airT=!!T.jug;                                // 짝 동작: 잡기 → 들기 → 내리꽂기(떠 있으면 뛰어 잡는다)
    opts.onCue=()=>{ if(!T.dead && !isDown(T) && Math.abs(T.d.x-H.d.x)<=28){ if(T.jug){ T.jug=null; H.airOv=9; } T.held={by:H, t0:GS.time}; T.action=null; T.queue=[]; setAnim(T,'held'); H.kb=0; H.dash=0; H.dashT=0; } };
    opts.cues={ gr_throw:()=>{ if(!T.held) return; T.held=null; T.airOv=0; T.d.x=Math.max(14,Math.min(SB.W-14,H.d.x+f*30));
      H.airOv=0; GS.stats.throws=(GS.stats.throws||0)+1; GS.curSrc=b.uid; contribTrig(b.uid); damage(H,T,Math.round(st.dmg*(airT?1.2:1)),{knock:true,crit:true}); groundImpact(T.d.x,T.d.y,airT?1.8:1.4); shakeAmp=3; dusts.push({x:T.d.x,y:T.d.y,age:0,flip:T.d.flip}); { const bi=GS.bag.indexOf(b); linkFire(bi,'hit'); linkFire(bi,'knock'); }
      foes().forEach(o=>{ if(o!==T && !isDown(o) && !o.dead && Math.abs(o.d.x-T.d.x)<24) damage(H,o,Math.round(st.dmg*.35),{knock:true,splash:true}); }); GS.curSrc=null; } }; }
  requestAction(H, anim, opts); }
// 쉬는 동작: 다 잡고 도착까지 6초 넘게 남으면 빈 의자에 앉거나 문 옆에 기대어 혼잣말
function restWanted(){ const L=LINE[GS.ci]; if(!L || GS.state!=='fight' || GS.clearT==null || GS.arriving || GS.prologue || GS.bonus || GS.cine) return false; const left=legDur(L)-(GS.legT||0); return left>6 && GS.legT-GS.clearT>1.2; }
function restTick(H,dt){
  if(!H.rest){ const pass=GS.ents.filter(a=>a.pass&&!a.hidden), free=[70,190,290,410].filter(x=>!inDoor(x) && !pass.some(a=>Math.abs(a.d.x-x)<18)).sort((a,b)=>Math.abs(a-H.d.x)-Math.abs(b-H.d.x));
    if(free.length) H.rest={ mode:'sit', x:free[0], t:0 };
    else { const d=DOORS.reduce((b,[d0,d1])=>Math.abs((d0+d1)/2-H.d.x)<Math.abs(b-H.d.x)?(d0+d1)/2:b, 9999), dd=DOORS.find(([d0,d1])=>(d0+d1)/2===d); H.rest={ mode:'lean', x:H.d.x<d?dd[0]-6:dd[1]+6, t:0, door:d }; } }
  const RS=H.rest; RS.t+=dt;
  if(!RS.on){ if(Math.abs(H.d.x-RS.x)>2){ face(H,RS.x); moveTo(H,RS.x,heroSpd()*.5,dt); return; }
    RS.on=true; RS.t=0; if(RS.mode==='sit'){ H.z=-2; face(H,SB.W/2); setAnim(H,'rest_sit'); } else { face(H, RS.door<H.d.x ? H.d.x+10 : H.d.x-10); setAnim(H,'rest_lean'); } }
  if(RS.on && !RS.said && RS.t>1.4){ RS.said=true; comicSay(H, pickQ('rest'), 'think'); } }
function restEnd(H){ if(H.anim==='rest_sit'||H.anim==='rest_lean') setAnim(H,'idle'); H.z=3; H.rest=null; }
function heroAI(dt){ if(GS.demo || GS.kane || /^gx_/.test((GS.hero&&GS.hero.anim)||'')) return;
  const H=GS.hero; if(H.dead) return; if(GS.bonus && GS.bonus.phase!=='go') return; if(holding(H)) return; const F=foes().filter(a=>a.anim!=='death');
  if(!F.length && GS.state==='corridor'){ if(canAct(H)||H.anim==='walk'){ face(H,H.d.x+10); moveTo(H, H.d.x+30, heroSpd()*.85, dt); } return; }   // 복도: 앞으로 밀고 나간다
  if(F.length && H.rest) restEnd(H);
  if(!F.length && restWanted()){ restTick(H,dt); return; }
  if(!F.length && H.rest) restEnd(H);
  if(!F.length){ if(canAct(H) && (GS.arriving||GS.clearT!=null||GS.state==='arrive')){ const dx=(DOORS[1][0]+DOORS[1][1])/2-14; if(Math.abs(H.d.x-dx)>2){ face(H,dx); moveTo(H, dx, heroSpd()*.6, dt); } else if(H.anim==='walk') setAnim(H,'idle'); }  // 내릴 문 앞으로
    return; }
  const dist=a=>Math.abs(a.d.x-H.d.x), Fa=F.filter(a=>!a.held), live=Fa.filter(a=>!isDown(a));
  let T=(live.length?live:Fa).slice().sort((a,b)=>dist(a)-dist(b))[0];
  if(GS.bossBreak && GS.bossBreak.a && !GS.bossBreak.a.dead && dist(GS.bossBreak.a)<170) T=GS.bossBreak.a;   // 무너진 두목을 노린다
  const front=live.filter(a=>!behindOf(H,a)).sort((a,b)=>dist(a)-dist(b))[0], rear=live.filter(a=>behindOf(H,a)).sort((a,b)=>dist(a)-dist(b))[0];
  if(front && rear && dist(front)<52 && dist(rear)<44 && GS.bag.some(b=>GITEMS[b.id].back)) T=front;               /* 앞을 본 채로 버틴다(뒤는 뒤 공격으로) */
  if(!GS.bonus && !live.some(a=>a.jug) && envMove(H,live)){ spcGain(5); return; }   /* 저글 중엔 환경 기술보다 공중 콤보 */                                                                                       /* 기둥 · 손잡이 · 짐 상자: 자리가 곧 기술 */
  if(T && !canAct(H) && H.action && H.action.fired && !H.dead && !FALLS.has(H.anim) && !heroAirborne(H) && (live.some(a=>a.jug && a.jug.h<66 && dist(a)<44) || (GS.croute && GS.croute.k<GS.croute.uids.length && GS.croute.T && !GS.croute.T.dead && dist(GS.croute.T)<56))){   /* 착지 캔슬: 공중 동작은 내려앉은 뒤에 끊는다 */   /* 공중 콤보 캔슬: 띄운 뒤 회복 동작을 끊고 바로 이어 친다 */
    const C=GS.croute, nx=C&&C.k<C.uids.length ? GS.bag.findIndex(b=>b&&b.uid===C.uids[C.k]) : -1;               // 콤보 창이면 경로의 다음 블록으로 끊는다(쿨다운 무시)
    const ji= nx>=0 ? nx : GS.bag.findIndex((b,k)=>b && GITEMS[b.id].kind==='skill' && !GITEMS[b.id].cond && (GITEMS[b.id].fam==='fist'||GITEMS[b.id].combo) && b.t>=sStats(k).cd && !soloSkip(b));
    if(ji>=0){ H.action=null; H.queue=[]; setAnim(H,'idle'); } }
  if(T && !canAct(H) && !H.dead && !FALLS.has(H.anim) && H.anim!=='getup' && H.anim!=='duck' && !H.spcLock && !heroAirborne(H)){   /* 반격 끊어 쓰기: 내 공격 회복 중 · 가벼운 피격 중이면 받아친다 */
    const recov = H.action ? H.action.fired : (GS.time-(GS.hurtAt??-9)>.15);
    const ci = recov ? GS.bag.findIndex((b,k)=>b && GITEMS[b.id].cond==='counter' && b.t>=sStats(k).cd && !soloSkip(b)) : -1;
    if(ci>=0 && condOK('counter',H,T,Fa) && dist(T)<=GITEMS[GS.bag[ci].id].reach+4){ H.action=null; H.queue=[]; setAnim(H,'idle'); face(H,T.d.x); useSkill(ci,T,false); return; } }
  if(!T || !canAct(H)) return;
  // 고른 기술은 쓸 때까지 유지하되, 쿨다운이나 조건이 깨지면 다시 고른다
  // 조건 기술이 성립하면 바로 끼어든다(상황 우선). 아니면 고른 기본기를 쓸 때까지 유지
  const situ=[]; GS.bag.forEach((b,k)=>{ if(!b) return; const q=GITEMS[b.id]; if(q.kind==='skill' && q.cond && b.t>=sStats(k).cd && condOK(q.cond,H,T,Fa) && !soloSkip(b)) situ.push(k); });
  let i=H.pick;
  if(situ.length && !(i>=0 && GS.bag[i] && GITEMS[GS.bag[i].id].cond && situ.includes(i))) i=H.pick=situ[Math.floor(Math.random()*situ.length)];
  else if(i==null || i<0 || !GS.bag[i] || GS.bag[i].t<sStats(i).cd || (!routeSets().S.has(GS.bag[i].uid) && !condOK(GITEMS[GS.bag[i].id].cond,H,T,Fa)) || soloSkip(GS.bag[i])) i=H.pick=pickSkill(H,T,Fa);
  if(!GS.croute && (GS.comboCD||0)<=0){ const {S}=routeSets(), si=GS.bag.findIndex((b,k)=>b && S.has(b.uid) && b.t>=sStats(k).cd); if(si>=0) i=H.pick=si; }   // 콤보 우선: 숨 고르기가 끝나면 시작기부터(경로 시작기는 원래 조건 없이)
  if(GS.croute){ const ci=comboPick(H,T); if(ci>=0){ i=H.pick=ci; if(GS.croute&&GS.croute.T&&!GS.croute.T.dead) T=GS.croute.T; } }   // 콤보 창: 경로의 다음 블록(쿨다운 무시)
  if(i<0){ face(H,T.d.x); approach(H, T.d.x+(T.d.x>=H.d.x?-1:1)*24, heroSpd(), dt, heroSpd()*3.4); return; }
  const LA=GS.linkAt||{};
  if(!GS.croute && !GS.tower && T.jug && T.jug.h>=22 && T.jug.h<64 && dist(T)<38 && GS.time-(GS.hangT2||-9)>2 && GS.time-(LA.air??-9)<2.5 && canAct(H)){ const sx=STRAP_X.find(x=>Math.abs(x-H.d.x)<26); if(sx!=null){ strapAir(H,T,sx); return; } }   /* 손잡이 공중전(띄우고 차기 연계) */
  const tc = !GS.croute && GS.time-(LA.scoop??-9)<1.6 ? Fa.find(a=>((a.jug&&a.jug.trip&&a.jug.h<26) || (FALLS.has(a.anim)&&GS.time-(a.tripLandT||-9)<.45)) && dist(a)<40) : null;
  if(tc){ const si=GS.bag.findIndex((b,k)=>b && (b.id==='upper'||b.id==='punch') && b.t>=sStats(k).cd && !soloSkip(b)); if(si>=0){ const b=GS.bag[si]; if(b.id==='punch'){ b.combo=2; b.last=GS.time; } H.scoopNext=true; i=H.pick=si; T=tc; } }   /* 걸고 퍼올리기(걸린 채 · 막 떨어진 적도 바닥에서 퍼 올린다) */
  else if(!GS.croute && T.jug && !T.jug.trip && T.jug.n>=2 && T.jug.h>=4 && T.jug.h<42 && GS.time-(LA.airgrab??-9)<3){ const ti=GS.bag.findIndex((b,k)=>b && b.id==='throw' && b.t>=sStats(k).cd && !soloSkip(b)); if(ti>=0) i=H.pick=ti; }   /* 공중 잡아 꽂기 */
  else if(!GS.croute && T.jug && T.jug.h<66){ const ji=GS.bag.findIndex((b,k)=>b && GITEMS[b.id].kind==='skill' && !GITEMS[b.id].cond && (GITEMS[b.id].fam==='fist'||GITEMS[b.id].combo) && b.t>=sStats(k).cd && !soloSkip(b)); if(ji>=0) i=H.pick=ji; }   /* 공중 콤보: 떠 있는 적엔 빠른 주먹으로 이어 친다 */
  const it=GITEMS[GS.bag[i].id], tgt = it.cond==='down' ? Fa.filter(a=>isFalling(a)||(a.jug&&!a.jug.gb&&a.jug.h<36&&bagHasLink('gbounce'))).sort((a,b)=>dist(a)-dist(b))[0]||T : it.back ? (rear||T) : T, d=dist(tgt), reach=(it.combo?24:it.cond==='grab'?28:it.reach)+(tgt.jug?8:0);
  if(it.back){ if(rear && d<=reach+4){ if(H.anim==='walk') setAnim(H,'idle'); useSkill(i,tgt,false); }
    else if(rear && d<=60){ H.d.x+=Math.sign(rear.d.x-H.d.x)*heroSpd()*.7*dt; if(H.anim!=='walk') setAnim(H,'walk'); }   /* 돌아서지 않고 뒷걸음으로 붙는다 */
    else H.pick=null; return; }   /* 뒤 공격: 돌아서지 않고 그 자리에서 */
  face(H,tgt.d.x);
  if(it.cond==='gap' || (d<=reach+2 && d>=8)){ if(H.anim==='walk') setAnim(H,'idle'); useSkill(i,tgt,false); return; }
  { const sj=heroSpd()*(tgt.jug?(tgt.jug.wallB&&GS.time-(GS.poleT||-9)<1.4?2.2:1.6):1); approach(H, tgt.d.x+(tgt.d.x>=H.d.x?-1:1)*Math.max(SEP_HF,reach-4), sj, dt, Math.max(sj*1.2, heroSpd()*3.4), !!(tgt.e && (tgt.e.retreatT>0 || Math.abs(tgt.kb||0)>30 || tgt.jug))); }   /* 떠 있는 적은 빠르게 쫓는다 · 기둥에서 튕겨 오면 마중 나간다 */
}
// 브로드웨이 쇼 칸 천장 조명: 제자리에 붙어 불규칙하게 깜빡 · 번쩍 · 잠깐 정전, 그때 가끔 전기 불꽃이 튄다
const SHOW_LAMPS=[80,200,320,440].map(x=>({ x, k:1, t:0, q:[[1,.5+Math.random()*2]], sparkT:0 }));
function fkLines(c){ const f=c.d.flip?-1:1; for(let k=0;k<6;k++) HITFX.push({ k:'streak', x:c.d.x-f*(4+Math.random()*6), y:c.d.y-34+Math.random()*18, vx:-f*(300+Math.random()*160), vy:(Math.random()-.5)*20, t:0, life:.16+Math.random()*.06, col:'#fffbe8' }); }
function lampSeq(){ const r=Math.random(), idle=[1,1.5+Math.random()*3.5], q=[];
  if(r<.55){ const n=3+Math.floor(Math.random()*5); for(let i=0;i<n;i++){ const u=Math.random(); q.push([u<.5?0:u<.75?.35+Math.random()*.6:1.7, .03+Math.random()*.06]); } }
  else if(r<.8) q.push([1.9,.06],[0,.12+Math.random()*.15]);
  else q.push([.2,.05],[0,.25+Math.random()*.5],[1.3,.05]);
  q.push(idle); return q; }
function showSpark(L){ L.sparkT=.1; const y=SB.CAR_Y+12, n=6+Math.floor(Math.random()*6);
  for(let i=0;i<n;i++) HITFX.push({ k:'drop', x:L.x+(Math.random()-.5)*6, y, vx:(Math.random()-.5)*150, vy:-30-Math.random()*70, t:0, life:.45+Math.random()*.35, col:Math.random()<.5?'#fff6c0':'#ffcf5a' });
  HITFX.push({ k:'flash', x:L.x, y, t:0, life:.08, big:false }); sfx.zap(); }
function showLampUpdate(dt){ const Lc=GS.on && scene==='subway' && LINE[GS.ci] && CAR_CONCEPTS[LINE[GS.ci].car]; if(!Lc || !Lc.marquee) return;
  for(const L of SHOW_LAMPS){ L.sparkT=Math.max(0,L.sparkT-dt);
    if(L.t>0){ L.t-=dt; if(!L.q.length && Math.abs(L.k-1)<.06) L.k=1+(Math.random()-.5)*.04; continue; }
    if(!L.q.length) L.q=lampSeq();
    const [k,d]=L.q.shift(), was=L.k; L.k=k; L.t=d; L.n=(L.n||0)+1; if(k<.15 && was>.6) L.off=(L.off||0)+1; if(k>1.4) L.fl=(L.fl||0)+1;
    if(((k<.15 && was>.6) || k>1.4) && Math.random()<.25){ L.sp=(L.sp||0)+1; showSpark(L); } } }
function drawShowLamps(){ const Lc=GS.on && scene==='subway' && LINE[GS.ci] && CAR_CONCEPTS[LINE[GS.ci].car]; if(!Lc || !Lc.marquee) return; const y=SB.CAR_Y+6;
  for(const L of SHOW_LAMPS){ const k=L.k;
    if(k>.25){ const g=uiCx.createRadialGradient(L.x,y+3,0,L.x,y+3,k>1.4?22:12*k); g.addColorStop(0,k>1.4?'rgba(255,255,240,.9)':'rgba(255,224,160,.55)'); g.addColorStop(1,'rgba(255,200,120,0)'); uiCx.fillStyle=g; uiCx.fillRect(L.x-24,y-20,48,48); }
    uiCx.fillStyle='#1a1610'; uiCx.fillRect(L.x-6,y-2,12,3); uiCx.fillStyle='#4a4232'; uiCx.fillRect(L.x-6,y-2,12,1);
    uiCx.fillStyle = k>1.4 ? '#ffffff' : k>.6 ? '#ffe9b0' : k>.25 ? '#b08a50' : '#3a3024'; uiCx.fillRect(L.x-3,y+1,6,3); } }
const showBulbK=x=>{ let b=null, dd=1e9; for(const L of SHOW_LAMPS){ const q=Math.abs(L.x-x); if(q<dd){ dd=q; b=L; } } return (b && dd<=60) ? b.k : 1; };
// 천장 손잡이: 공중으로 빠르게 지나가는 몸이 스치면 그 방향으로 튕겼다가 스프링처럼 잦아든다
const STRAPS={};
function strapUpdate(dt){ if(scene!=='subway' || !GS.on) return;
  for(const c of GS.ents){ if(c.hidden||c.dead) continue; const P=POSES[c.pose], air=((P&&P.air)||0)+(c.airOv||0); if(air<5) continue;
    const vx=(c.dash||0)+(c.kb||0); if(Math.abs(vx)<20) continue; const dir=Math.sign(vx);
    for(let x=18;x<SB.W-18;x+=26){ if(Math.abs(x-c.d.x)>9) continue; const S=STRAPS[x]||(STRAPS[x]={a:0,v:0,cd:0}); if(S.cd>0) continue; S.v+=dir*(5+Math.min(4,air*.25)); S.cd=.35; } }
  for(const k in STRAPS){ const S=STRAPS[k]; S.cd=Math.max(0,S.cd-dt); S.v+=(-34*S.a-3.2*S.v)*dt; S.a=Math.max(-1,Math.min(1,S.a+S.v*dt)); } }
function foeAI(a,dt){ if(a.carDummy||a.carOwner||GS.demo||a.kane||(a.e&&a.e.towerBusy)) return;
  const H=GS.hero, e=a.e; if(a.held) return; e.cdT+=dt; if(a.anim==='stagger' && !(e.stun>0)) setAnim(a,'idle');
  if(e.stun>0){ e.stun-=dt; if(e.stun>.2 && canAct(a) && !a.jug){ setAnim(a,'stagger'); if(GS.stats) GS.stats.stag=(GS.stats.stag||0)+1; } return; } if(!canAct(a)||H.dead) return;   // 경직 동안은 휘청거린다
  if(e.retreatT>0){ e.retreatT-=dt; const away=a.d.x>=H.d.x?1:-1; face(a,H.d.x); moveTo(a, Math.max(AW0()+2,Math.min(AW1()-2,H.d.x+away*80)), e.spd*1.2, dt); return; }  // 치고 빠지기
  const side=a.d.x>=H.d.x?1:-1, dist=Math.abs(a.d.x-H.d.x); face(a,H.d.x);
  if(e.range){ // 병 던지는 놈: 거리를 두고 던진다
    const atWall = a.d.x<=20 || a.d.x>=SB.W-20;                                  // 벽에 몰리면 더 물러날 수 없다
    if(dist<e.range-20 && !atWall) moveTo(a, Math.max(14,Math.min(SB.W-14,H.d.x+side*e.range)), e.spd, dt);
    else if(e.cdT>=e.cd){ e.cdT=0;
      if(dist<=MOVE_REACH.jab){ a.lastMove='jab'; requestAction(a,'jab',{cue:cueFor(a,'jab','m_jab'), onCue:()=>foeHit(a) }); }   // 붙으면 주먹
      else { a.lastMove='throw'; requestAction(a,'jab',{cue:cueFor(a,'jab','m_jab'), onCue:()=>{ GS.shots.push({ x:a.d.x-side*8, y:a.d.y-52, vx:-side*150, t:0 }); }}); } }
    else if(a.anim==='walk') setAnim(a,'idle'); return; }
  const close=foes().filter(o=>Math.abs(o.d.x-H.d.x)<36 && o!==a).length;
  const wait=close>=2 && dist>34;
  const spd = e.dash && dist>60 ? e.dash : e.spd, rs = e.boss ? e.spd*2 : Math.max(e.dash||0, Math.min(120, Math.max(90, e.spd*2.6)));   // 멀어지면(날아갔다 일어나면) 달려서 다시 붙는다
  if(!e.next){ const ms=e.moves; let m=ms[Math.floor(Math.random()*ms.length)]; if(ms.length>1 && m===a.lastMove && Math.random()<.75){ const alt=ms.filter(x=>x!==a.lastMove); m=alt[Math.floor(Math.random()*alt.length)]; } e.next=m; }   // 같은 공격을 연달아 잘 안 쓴다
  if(e.next==='fkick' && dist<50){ const alt=e.moves.filter(m=>m!=='fkick'); e.next=alt[Math.floor(Math.random()*alt.length)]||'jab'; }
  const gapMv=e.next==='fkick', inGap=dist>=50&&dist<=110;
  const rch=wpnReach(e.next,e.wpn);
  if(e.flankAt && GS.time>=e.flankAt){ e.flankAt=0; if(!gapMv && dist<=rch+4){ e.cdT=0; const mv=e.next; e.next=null; e._fl=true; foeStrike(a, mv); return; } }   // 협공: 반대편 동료와 거의 동시에
  const inR=!gapMv && !wait && dist<=rch && dist>=SEP_HF-1; if(inR && a.anim==='walk') setAnim(a,'idle');   // 이미 닿는 거리면 제자리(주인공이 다가올 때 뒷걸음으로 거리를 맞추지 않는다)
  const there=gapMv ? (dist<=110 || approach(a, H.d.x+side*90, spd, dt, rs)) : inR ? true : approach(a, H.d.x+side*(wait?64:Math.max(SEP_HF,rch-3)), spd, dt, rs);
  if(gapMv && inGap && a.anim==='walk') setAnim(a,'idle');
  if(!wait && (gapMv ? inGap : ((there || dist<=rch) && dist<=rch+4)) && e.cdT>=e.cd){ e.cdT=0; const mv=e.next; e.next=null; foeStrike(a, mv); }
}
function foeStrike(a, mv){ const H=GS.hero, e=a.e, dist=Math.abs(a.d.x-H.d.x), rch=wpnReach(mv,e.wpn); a.lastMove=mv; a.windup=GS.time; e.flankHit=!!e._fl; e._fl=false; if(!e.flankHit) flankCall(a);
    if(FOE_W[mv]==='H'){ hint('heavy'); if(GS.manualT<=0 && duckReady() && dist<=rch+8) heroDuck(); }
    const an = mv==='jab' && e.wpn==='w_umb' ? 'uthrust' : mv==='jab' && e.wpn==='w_paper' ? 'swat' : mv;   // 무기를 든 손(F)으로 치는 전용 동작
    const tx=(GS.demo || GS.time<(GS.engageT||-9)) ? (FOE_TELLX[FOE_W[mv]]||0) : 0; e.cdT+=tx;   /* 직접 누르기 시작하면(8초) · 무도장에선 예고를 길게 — 자동 전투 템포는 그대로 */ face(a,H.d.x); const fo={ tell:tx, cue:cueFor(a,an,{jab:'m_jab',hook:'hook',hbutt:'hb',kick:'m_kick',bat:'batS',round:'rh',upper:'up'}[an]), wpn:e.wpn, onCue:()=>foeHit(a) };
    if(mv==='fkick') fo.cues={ fk_smear:()=>fkLines(a), fk_jump:()=>{ const dd=Math.max(0,Math.abs(H.d.x-a.d.x)-18); a.dash=(H.d.x>a.d.x?1:-1)*dd/.3; a.dashT=.3; }, fk_tuck:()=>{ if(GS.manualT<=0 && duckReady()) heroDuck(); }, fk_land:()=>{ a.dash=0; a.dashT=0; dusts.push({ x:a.d.x, y:a.d.y, age:0, flip:a.d.flip }); } };
    if(mv==='charge') fo.cues={ ch_run:()=>{ const dd=Math.abs(H.d.x-a.d.x)-16; a.dash=(H.d.x>a.d.x?1:-1)*260; a.dashT=Math.max(.05,Math.min(.3,dd/260)); } };   // 배치기 돌진
    requestAction(a, an, fo);
}
// 협공: 가끔(3.5초에 한 번 이하 · 60% 확률) 주인공 반대편에 붙어 있는 적이 0.14초 늦게 같이 친다 — 머리 위 '!'로 미리 알린다 · 협공 타격은 피해 ×0.8
function flankCall(a){ const H=GS.hero; if(GS.demo || GS.state!=='fight' || !H || GS.time-(GS.flankT||-9)<3.5 || Math.random()>.6) return;
  const sd=Math.sign(a.d.x-H.d.x)||1, b=foes().find(o=>o!==a && !o.held && !o.jug && !o.e.range && canAct(o) && !(o.e.stun>0) && !(o.e.retreatT>0) && Math.sign(o.d.x-H.d.x)===-sd && Math.abs(o.d.x-H.d.x)<=40);
  if(!b) return; GS.flankT=GS.time; b.e.flankAt=GS.time+.14; b.e.cdT=Math.min(b.e.cdT,b.e.cd-.5); GS.stats.flanks=(GS.stats.flanks||0)+1;
  pops.push({ x:b.d.x-3, y:b.d.y-74, t:'!', age:0, c:'#ff7a5a' }); }
// --- 직접 조작: 누른 쪽으로 즉시 공격 / 공격 준비 중인 적은 카운터 / 날아오는 병은 쳐냄 / 없으면 대시 ---
// 쭈그리기: 거의 모든 동작을 끊고 바로 낮춘다(맞는 중 · 넘어진 중엔 불가). 잡고 있던 적은 놓친다
const isDucking=H=> H.anim==='duck' && H.pose!=='c_over';
const duckSlot=()=>GS.bag.findIndex(b=>b&&b.id==='duck');
const duckReady=()=>{ const i=duckSlot(); return i>=0 && GS.bag[i].t>=sStats(i).cd; };
function heroDuck(manualIn){
  const H=GS.hero; if(manualIn) GS.engageT=GS.time+8; if(!H||H.dead||H.anim==='duck'||REACTS.has(H.anim)||holding(H)) return false;
  const i=duckSlot();
  if(i<0){ if(manualIn) say('','서류가방에 쭈그리기가 있어야 숙일 수 있어요',1.4); return false; }   // 아이템이 있어야 한다
  if(GS.bag[i].t<sStats(i).cd){ if(manualIn){ GS.flash='WAIT'; GS.flashT=.4; } return false; }     // 쿨다운 중
  GS.bag[i].t=0; if(manualIn) GS.manualT=2.5; H.queue=[]; H.action=null; setAnim(H,'idle'); requestAction(H,'duck',{ cue:'dk1', onCue:()=>{} }); bagFire(GS.bag[i],false,false); cmdPush({ id:GS.bag[i].id, name:'피하기', fam:null }); return true;
}
function manual(side){
  if(!GS.on || GS.state==='over' || GS.state==='shop') return; const H=GS.hero; if(H.dead) return; GS.manualT=2.5; GS.engageT=GS.time+8;
  if(holding(H)) return;
  const win=.42*(1+pv('ear',.6,.15));
  const shot=GS.shots.find(s=>Math.sign(s.x-H.d.x)===side && Math.abs(s.x-H.d.x)<40);
  if(shot){ shot.dead=true; sparks.push({x:shot.x,y:shot.y,age:0}); GS.score+=50; face(H,H.d.x+side); if(canAct(H)) setAnim(H,'jab'); return; }
  const near=foes().filter(a=>Math.sign(a.d.x-H.d.x)===side && Math.abs(a.d.x-H.d.x)<46 && a.anim!=='death').sort((a,b)=>Math.abs(a.d.x-H.d.x)-Math.abs(b.d.x-H.d.x));
  { const A=near.find(a=>a.action && !a.action.fired && FOE_W[a.anim]); if(A){ const i=near.indexOf(A); near.splice(i,1); near.unshift(A); } }   // 치려고 준비하는 적을 먼저
  { const A=near[0], tt=A?timeToCue(A):null; if(A && tt!=null && tt<=JUST_W() && FOE_W[A.anim]!=='H' && !FALLS.has(H.anim) && !REACTS.has(H.anim) && !A.e.boss){ justCounter(A); return; }   // 저스트: 타격 직전에 누르면
    if(A && tt!=null && tt>JUST_W()) GS.justEarly=GS.time; }
  if(near[0] && behindOf(H,near[0]) && Math.abs(near[0].d.x-H.d.x)<=34){ const bi=GS.bag.findIndex((b,k)=>GITEMS[b.id].back && b.t>=sStats(k).cd);       /* 등 뒤를 누르면 뒤 공격 */
    if(bi>=0){ H.queue=[]; H.action=null; setAnim(H,'idle'); useSkill(bi,near[0],true); return; } }
  const T=near[0];
  if(T && T.action && !T.action.fired && FOE_W[T.anim]==='H'){ GS.flash='DUCK!'; GS.flashT=.6; if(duckReady() && heroDuck(true)) return; }
  if(T && T.action && !T.action.fired && FOE_W[T.anim]!=='H' && GS.time-(T.windup||0)<win+.35){ // 카운터
    T.action=null; T.queue=[]; T.e.stun=1.2; T.e.cdT=-.6; GS.stats.counters++; face(H,T.d.x); H.queue=[]; H.action=null; setAnim(H,'idle');
    requestAction(H,'cross',{cue:cueFor(H,'cross','m_cross'),onCue:()=>{ if(T.dead||!inFront(H,T,MOVE_REACH.cross)) return; damage(H,T,Math.round(14*(1+.12*GS.ci)),{crit:true,counter:true,react:'body'}); }}); GS.flash='COUNTER'; GS.flashT=.8; return; }
  if(T && Math.abs(T.d.x-H.d.x)<=32){ if(!canAct(H) && H.anim!=='walk'){ H.queue=[]; } const i=pickSkill(H,T,foes().filter(a=>!a.held));
    if(i>=0 && Math.abs(T.d.x-H.d.x)<=GITEMS[GS.bag[i].id].reach+4){ H.action=null; setAnim(H,'idle'); useSkill(i,T,true); return; }
    if(GS.mcd<=0){ GS.mcd=.32; face(H,T.d.x); H.action=null; setAnim(H,'idle'); requestAction(H,'jab',{cue:cueFor(H,'jab','m_jab'),onCue:()=>{ if(inFront(H,T,MOVE_REACH.jab)) damage(H,T,4,{react:'head'}); }}); }
    return; }
  face(H,H.d.x+side); H.dash=side*260; H.dashT=.14; if(canAct(H)) setAnim(H,'walk');
}
// 저스트 받아치기: 타격 직전 탭 — 공격을 끊고 순간 파고들어 크로스(피해 ×2 · 무너뜨림) · 슬로 · 충격파 · 반짝
function justCounter(T){ const H=GS.hero, f=T.d.x>=H.d.x?1:-1, d=Math.abs(T.d.x-H.d.x);
  H.airOv=0; T.action=null; T.queue=[]; T.e.cdT=-1.4; T.hs=Math.max(T.hs||0,6); T.hs0=T.hs; T.shkA=1;   /* 적은 휘두르던 자세 그대로 굳는다(받아치기가 꽂힐 때까지) */ GS.stats.counters++; GS.stats.justs=(GS.stats.justs||0)+1; face(H,T.d.x); H.queue=[]; H.action=null; setAnim(H,'idle');
  if(d>24){ H.dash=f*(d-22)/.07; H.dashT=.07; }   // 순간 파고들기
  GS.slowT=Math.max(GS.slowT||0,.3); GS.flash='JUST!'; GS.flashT=.9; spcGain(8); sfx.just();
  HITFX.push({ k:'tapok', x:T.d.x, y:T.d.y-34, t:0, life:.32 }); if(!OPT.noFlash) HITFX.push({ k:'chstar', x:T.d.x-f*3, y:T.d.y-36, t:0, life:.26 });
  comicT=0; comicSFX(T.d.x, T.d.y-96, tr('저스트!')); cmdPush({ name:'저스트 받아치기', sp:false, fam:null });
  requestAction(H,'cross',{cue:cueFor(H,'cross','m_cross'),onCue:()=>{ if(T.dead) return; if(!inFront(H,T,MOVE_REACH.cross+10)) return;
    damage(H,T,Math.round(22*(1+.12*GS.ci)*(1+.15*(GS.stageIdx||0))),{crit:true,counter:true,just:true,react:'body'}); swPush(T.d.x, T.d.y-32, 3, f); if(T.e && !T.dead) T.e.stun=Math.max(T.e.stun||0,1.2); }}); }
