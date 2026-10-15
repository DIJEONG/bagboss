// =========================================================
// 소리: WebAudio 실시간 합성(음원 파일 없음). 첫 터치 때 켜진다
//   열차(굴림 · 모터 · 레일 이음매 · 제동 · 문 신호 · 압력파) · 전투(타격 · 휘두름 · 치명 · 병 · 폭발) · 장소(역 웅성임 · 형광등) · UI · 누아르 재즈 배경음
// =========================================================
const SND={ on:false, ctx:null, vol:{ master:.8, music:.55, sfx:.8 }, muted:false, mus:{ bar:0, t:0, step:0, int:0 } };
try{ const v=JSON.parse(localStorage.getItem('dotlab-snd')||'null'); if(v){ Object.assign(SND.vol,v.vol||{}); SND.muted=!!v.muted; } }catch(e){}
function sndSave(){ try{ localStorage.setItem('dotlab-snd', JSON.stringify({vol:SND.vol, muted:SND.muted})); }catch(e){} }
function sndInit(){ if(SND.ctx){ if(SND.ctx.state==='suspended') SND.ctx.resume(); return; }
  const AC=window.AudioContext||window.webkitAudioContext; if(!AC) return; const c=new AC(); SND.ctx=c;
  SND.master=c.createGain(); SND.master.connect(c.destination);
  const comp=c.createDynamicsCompressor(); comp.threshold.value=-14; comp.ratio.value=4; comp.connect(SND.master); SND.bus=comp;
  for(const k of ['music','sfx','amb']){ const g=c.createGain(); g.connect(comp); SND[k]=g; }
  const n=c.createBuffer(1,c.sampleRate*2,c.sampleRate), d=n.getChannelData(0); for(let i=0;i<d.length;i++) d[i]=Math.random()*2-1; SND.noise=n;
  const br=c.createBuffer(1,c.sampleRate*2,c.sampleRate), e=br.getChannelData(0); let last=0; for(let i=0;i<e.length;i++){ last=(last+.02*(Math.random()*2-1))/1.02; e[i]=last*3.5; } SND.brown=br;
  // 계속 도는 소리: 열차 굴림(갈색 잡음) · 모터 울림 · 바람(다리) · 제동 끼익 · 역 웅성임 · 형광등 지직
  const loop=(buf)=>{ const s=c.createBufferSource(); s.buffer=buf; s.loop=true; s.start(); return s; };
  const lp=(f)=>{ const x=c.createBiquadFilter(); x.type='lowpass'; x.frequency.value=f; return x; }, bp=(f,q)=>{ const x=c.createBiquadFilter(); x.type='bandpass'; x.frequency.value=f; x.Q.value=q; return x; };
  const g0=()=>{ const g=c.createGain(); g.gain.value=0; return g; };
  SND.rumF=lp(120); SND.rumG=g0(); loop(SND.brown).connect(SND.rumF).connect(SND.rumG).connect(SND.amb);
  SND.motO=c.createOscillator(); SND.motO.type='sawtooth'; SND.motF=bp(400,6); SND.motG=g0(); SND.motO.connect(SND.motF).connect(SND.motG).connect(SND.amb); SND.motO.start();
  SND.windF=bp(900,.7); SND.windG=g0(); loop(SND.noise).connect(SND.windF).connect(SND.windG).connect(SND.amb);
  // 제동: ① 금속이 긁히는 좁은 대역 잡음 두 갈래 ② 거의 멈출 때 끊겼다 이어지는 쇳소리(배수가 아닌 높은 배음 셋, 불규칙하게 떨림) ③ 바퀴에 갈리는 낮은 그르르
  SND.frG=g0(); for(const [f,q] of [[2600,9],[3900,11]]){ const fl=bp(f,q); loop(SND.noise).connect(fl).connect(SND.frG); } SND.frG.connect(SND.sfx);
  SND.sqG=g0(); SND.sqO=[3150,4720,6230].map((f,k)=>{ const o=c.createOscillator(); o.type='sine'; o.frequency.value=f; const g=c.createGain(); g.gain.value=[.5,.32,.18][k]; o.connect(g).connect(SND.sqG); o.start(); return o; }); SND.sqG.connect(SND.sfx);
  SND.grF=lp(160); SND.grG=g0(); loop(SND.brown).connect(SND.grF).connect(SND.grG).connect(SND.sfx);
  SND.crowdF=bp(500,.8); SND.crowdG=g0(); loop(SND.noise).connect(SND.crowdF).connect(SND.crowdG).connect(SND.amb);
  SND.humO=c.createOscillator(); SND.humO.type='square'; SND.humO.frequency.value=120; SND.humG=g0(); SND.humO.connect(lp(900)).connect(SND.humG).connect(SND.amb); SND.humO.start();
  SND.on=true; sndApplyVol(); }
function sndApplyVol(){ if(!SND.ctx) return; const m=SND.muted?0:SND.vol.master, t=SND.ctx.currentTime;
  SND.master.gain.setTargetAtTime(m,t,.05); SND.music.gain.setTargetAtTime(SND.vol.music*.5,t,.05); SND.sfx.gain.setTargetAtTime(SND.vol.sfx,t,.05); SND.amb.gain.setTargetAtTime(SND.vol.sfx*.7,t,.05); }
// 배경음 잠깐 누르기(덕킹): 무거운 타격이 앞으로 나오게 음악 · 환경음을 k배로 낮췄다가 되돌린다
function sndDuck(k,hold,rel){ if(!SND.ctx||SND.muted) return; const t=SND.ctx.currentTime; for(const [g,b] of [[SND.music,SND.vol.music*.5],[SND.amb,SND.vol.sfx*.7]]){ if(!g) continue; g.gain.cancelScheduledValues(t); g.gain.setValueAtTime(g.gain.value,t); g.gain.linearRampToValueAtTime(b*k,t+.012); g.gain.setValueAtTime(b*k,t+.012+hold); g.gain.linearRampToValueAtTime(b,t+.012+hold+rel); } }
// 짧은 소리 도구: 잡음 터짐 · 음 하나(높이 미끄러짐)
function nz(t,dur,{f=1200,q=1,type='bandpass',g=.5,att=.002,to=null,bus='sfx'}={}){ const c=SND.ctx; const s=c.createBufferSource(); s.buffer=SND.noise; const fl=c.createBiquadFilter(); fl.type=type; fl.frequency.setValueAtTime(f,t); if(to) fl.frequency.exponentialRampToValueAtTime(to,t+dur); fl.Q.value=q;
  const e=c.createGain(); e.gain.setValueAtTime(0,t); e.gain.linearRampToValueAtTime(g,t+att); e.gain.exponentialRampToValueAtTime(.001,t+dur); s.connect(fl).connect(e).connect(SND[bus]); s.start(t,Math.random()*1.5); s.stop(t+dur+.05); }
function tone(t,dur,{f=440,to=null,type='sine',g=.3,att=.004,bus='sfx'}={}){ const c=SND.ctx; const o=c.createOscillator(); o.type=type; o.frequency.setValueAtTime(f,t); if(to) o.frequency.exponentialRampToValueAtTime(to,t+dur);
  const e=c.createGain(); e.gain.setValueAtTime(0,t); e.gain.linearRampToValueAtTime(g,t+att); e.gain.exponentialRampToValueAtTime(.001,t+dur); o.connect(e).connect(SND[bus]); o.start(t); o.stop(t+dur+.05); }
const sfx={
  clack(){ if(!SND.on) return; const t=SND.ctx.currentTime, k=Math.min(1,TR.v/600); nz(t,.05,{f:900,q:2,g:.25*k+.05}); tone(t,.08,{f:95,to:60,g:.35*k+.05}); },              // 레일 이음매
  hit(heavy,crit){ if(!SND.on) return; const t=SND.ctx.currentTime;
    if(heavy){ tone(t,.28,{f:120,to:38,g:.75}); nz(t,.18,{f:600,q:.7,g:.55,to:180}); nz(t,.06,{f:3000,q:.8,g:.25}); }
    else { tone(t,.09,{f:170,to:80,g:.45}); nz(t,.07,{f:1500+Math.random()*600,q:1.2,g:.35}); }
    if(crit){ tone(t+.01,.35,{f:1760,type:'triangle',g:.16}); tone(t+.01,.3,{f:2637,type:'sine',g:.1}); nz(t,.25,{f:6000,q:.6,g:.12,type:'highpass'}); } },
  hitK(kind,crit,combo){ if(!SND.on) return; const t=SND.ctx.currentTime, pv=(1+(Math.random()-.5)*.16)*(1+Math.min(10,combo||0)*.025);   // 음높이 흔들림 · 연타 상승
    if(kind==='jab'){ nz(t,.045,{f:2400*pv,q:1.4,g:.32}); tone(t,.06,{f:210*pv,to:120,g:.3}); }                                          // 탁
    else if(kind==='punch'){ tone(t,.12,{f:150*pv,to:62,g:.55}); nz(t,.08,{f:900*pv,q:.9,g:.4,to:500}); }                                // 퍽(살에 맞는 중음 · 고음 없이)
    else if(kind==='hammer'){ tone(t,.2,{f:130*pv,to:55,g:.65}); nz(t,.09,{f:1800,q:1.2,g:.35}); tone(t+.003,.16,{f:1250*pv,type:'triangle',g:.11}); tone(t+.003,.12,{f:1870*pv,g:.06}); }   // 쇠망치: 묵직한 타격 + 금속음
    else if(kind==='kick'){ tone(t,.16,{f:115*pv,to:48,g:.6}); nz(t,.13,{f:700*pv,q:.8,g:.42,to:300}); }                                 // 퍽(묵직)
    else { tone(t,.3,{f:120*pv,to:36,g:.8}); nz(t,.2,{f:600,q:.7,g:.55,to:170}); nz(t,.05,{f:1900,q:.7,g:.14}); }                      // 쾅(넘어뜨리기 · 메치기) — 고음은 낮고 약하게
    if(crit){ nz(t,.035,{f:2400,q:.6,g:.34,type:'highpass'}); nz(t+.01,.09,{f:1100,q:.7,g:.3,to:600}); tone(t,.18,{f:110*pv,to:45,g:.5}); } },   // 짝(치명): 채찍처럼 갈라지는 잡음 + 묵직한 저음(맑은 음은 빼서 쇳소리처럼 들리지 않게)
  // 타격음 3단: 0 가벼움 '탁' · 1 중간 '퍽' · 2 무거움 '쾅' — 첫소리(갈라짐) · 몸통(저음) · 여운(잔향) 세 겹을 무게대로 쌓는다. 공중 타격은 바닥 울림(초저음)을 줄이고 살짝 높게
  hit3(tier,{crit=false,combo=0,air=false,big=false}={}){ if(!SND.on) return; const t=SND.ctx.currentTime, pv=(1+(Math.random()-.5)*.12)*(1+Math.min(10,combo)*.022)*(air?1.07:1), sub=air?.45:1;
    if(tier<=0){ nz(t,.04,{f:2700*pv,q:1.5,g:.36}); tone(t,.055,{f:230*pv,to:130,g:.3}); nz(t+.004,.03,{f:5200,q:.7,g:.08,type:'highpass'}); }                                   // 탁: 짧고 높게, 여운 없음
    else if(tier===1){ nz(t,.03,{f:1600*pv,q:1,g:.24}); tone(t,.13,{f:150*pv,to:58,g:.55}); nz(t,.1,{f:720*pv,q:.8,g:.38,to:340}); nz(t+.02,.14,{f:320,q:.6,g:.07*sub,type:'lowpass',att:.01}); }   // 퍽: 살에 묻히는 중음 + 짧은 여운
    else { nz(t,.025,{f:3000,q:.6,g:.3,type:'highpass'}); tone(t,.32,{f:108*pv,to:34,g:.85}); nz(t,.2,{f:620*pv,q:.7,g:.55,to:160}); tone(t,.45,{f:54,to:30,g:.5*sub}); nz(t+.03,big?.6:.4,{f:420,to:110,q:.5,g:(big?.22:.14)*sub,type:'lowpass',att:.025}); if(big) sndDuck(.32,.14,.36); }   // 쾅: 갈라짐 + 묵직한 몸통 + 초저음 + 긴 여운, 배경음을 잠깐 눌러 타격을 앞으로
    if(crit){ nz(t,.035,{f:2400,q:.6,g:.34,type:'highpass'}); nz(t+.01,.09,{f:1100,q:.7,g:.3,to:600}); tone(t,.18,{f:110*pv,to:45,g:.5}); } },
  just(){ if(!SND.on) return; const t=SND.ctx.currentTime; nz(t,.06,{f:5200,q:.7,g:.16,type:'highpass'}); tone(t,.22,{f:1568,type:'triangle',g:.17}); tone(t+.035,.32,{f:2349,g:.11}); nz(t,.18,{f:900,to:3200,q:.8,g:.12}); },   // 저스트: 맑게 갈라지는 '챙'
  floor(p){ if(!SND.on) return; const t=SND.ctx.currentTime; if(t-(SND.floorT||0)<.07) return; SND.floorT=t; const k=Math.min(1.6,p);   // 몸이 바닥에 떨어지는 쿵(세게 떨어질수록 낮고 길게)
    tone(t,.16+.1*k,{f:74+8*k,to:36,g:.18+.22*k}); nz(t,.12+.08*k,{f:260,q:.6,g:.12+.14*k,type:'lowpass'}); if(k>1.1) nz(t+.02,.22,{f:1300,q:1.4,g:.05}); },
  thud(){ if(!SND.on) return; const t=SND.ctx.currentTime; tone(t,.22,{f:78,to:40,g:.55}); nz(t,.18,{f:320,q:.6,g:.35,type:'lowpass'}); },
  swing(){ if(!SND.on) return; nz(SND.ctx.currentTime,.13,{f:600,to:2400,q:.9,g:.16}); },
  hurt(heavy){ if(!SND.on) return; const t=SND.ctx.currentTime; tone(t,.16,{f:140,to:70,g:.5,type:'triangle'}); nz(t,.1,{f:800,q:1,g:.3}); if(heavy){ tone(t,.3,{f:96,to:36,g:.6}); nz(t,.18,{f:520,q:.7,g:.4,to:160}); sndDuck(.45,.1,.3); } },   // 무거운 공격에 맞으면 저음을 더한다
  glass(){ if(!SND.on) return; const t=SND.ctx.currentTime; for(let k=0;k<6;k++) nz(t+k*.012+Math.random()*.02,.12+Math.random()*.1,{f:3000+Math.random()*4000,q:8,g:.18}); tone(t,.1,{f:200,to:90,g:.2}); },
  boom(){ if(!SND.on) return; const t=SND.ctx.currentTime; tone(t,.7,{f:90,to:28,g:.9}); nz(t,.6,{f:400,to:60,q:.6,g:.6,type:'lowpass'}); },
  whoosh(){ if(!SND.on) return; nz(SND.ctx.currentTime,.35,{f:300,to:2000,q:.7,g:.3}); },
  dodge(){ if(!SND.on) return; nz(SND.ctx.currentTime,.2,{f:2400,to:500,q:1.5,g:.2}); },
  press(){ if(!SND.on) return; const t=SND.ctx.currentTime; tone(t,.6,{f:60,to:30,g:.55}); nz(t,.5,{f:200,to:60,q:.5,g:.35,type:'lowpass'}); },
  chime(){ if(!SND.on) return; const t=SND.ctx.currentTime; tone(t,.5,{f:659,type:'sine',g:.22}); tone(t+.38,.7,{f:523,type:'sine',g:.22}); tone(t,.5,{f:1318,g:.05}); tone(t+.38,.7,{f:1046,g:.05}); },   // 문 닫힘 두 음(내려가는 딩-동)
  door(open){ if(!SND.on) return; const t=SND.ctx.currentTime; nz(t,.5,{f:open?500:900,to:open?1400:350,q:.8,g:.16}); tone(t+.48,.12,{f:110,to:70,g:.25}); },
  click(){ if(!SND.on) return; const t=SND.ctx.currentTime; tone(t,.05,{f:1200,g:.12,type:'square'}); },
  coin(){ if(!SND.on) return; const t=SND.ctx.currentTime; tone(t,.12,{f:1568,g:.15,type:'triangle'}); tone(t+.07,.25,{f:2093,g:.13,type:'triangle'}); },
  merge(ok){ if(!SND.on) return; const t=SND.ctx.currentTime; if(ok) [523,659,784,1046].forEach((f,i)=>tone(t+i*.07,.3,{f,type:'triangle',g:.2})); else { tone(t,.4,{f:180,to:90,type:'sawtooth',g:.12}); tone(t+.15,.45,{f:140,to:70,type:'sawtooth',g:.1}); } },
  clear(){ if(!SND.on) return; const t=SND.ctx.currentTime; [392,523,659,784].forEach((f,i)=>tone(t+i*.09,.35,{f,type:'triangle',g:.16})); },
  slowIn(){ if(!SND.on) return; const t=SND.ctx.currentTime; tone(t,.9,{f:110,to:46,g:.35,att:.08}); nz(t,.8,{f:900,to:120,q:.6,g:.22,type:'lowpass',att:.1}); },   // 슬로우로 들어가는 '우웅'
  carHit(h){ if(!SND.on) return; const t=SND.ctx.currentTime; tone(t,.16,{f:h?95:120,to:45,g:.55}); nz(t,.12,{f:h?650:900,q:2.2,g:.42,to:300}); nz(t+.02,.18,{f:340,q:6,g:.18}); },   // 철판이 우그러지는 쿵 · 웅
  gong(){ if(!SND.on) return; const t=SND.ctx.currentTime; tone(t,1.4,{f:98,g:.5}); tone(t,1.2,{f:196*1.5,g:.16,type:'triangle'}); tone(t,1.0,{f:523,g:.08}); nz(t,.5,{f:900,q:2,g:.2}); },
  ready(){ if(!SND.on) return; const t=SND.ctx.currentTime; [659,880,1318].forEach((f,i)=>tone(t+i*.06,.3,{f,type:'triangle',g:.14})); },
  brass(){ if(!SND.on) return; const c=SND.ctx, t=c.currentTime; for(const f of [146.8,174.6,220,293.7]){ const o=c.createOscillator(); o.type='sawtooth'; o.frequency.value=f; const fl=c.createBiquadFilter(); fl.type='lowpass'; fl.frequency.setValueAtTime(300,t); fl.frequency.exponentialRampToValueAtTime(2600,t+.08); fl.frequency.exponentialRampToValueAtTime(500,t+.7);
    const g=c.createGain(); g.gain.setValueAtTime(0,t); g.gain.linearRampToValueAtTime(.11,t+.03); g.gain.exponentialRampToValueAtTime(.001,t+.9); o.connect(fl).connect(g).connect(SND.sfx); o.start(t); o.stop(t+1); } tone(t,.6,{f:73,to:60,g:.5}); },
  rage(){ if(!SND.on) return; const t=SND.ctx.currentTime; tone(t,.8,{f:62,to:48,type:'sawtooth',g:.18}); nz(t,.7,{f:300,q:.7,g:.35,type:'lowpass'}); tone(t+.05,.5,{f:93,to:70,type:'square',g:.08}); },
  hiss(){ if(!SND.on) return; const t=SND.ctx.currentTime; tone(t,.12,{f:90,to:55,g:.3}); nz(t+.05,1.1,{f:5200,q:.4,g:.16,type:'highpass',att:.03}); nz(t+.05,.6,{f:2400,q:.8,g:.07,att:.02}); },   // 에어 브레이크
  pass(){ if(!SND.on) return; const t=SND.ctx.currentTime; nz(t,1.7,{f:300,to:1200,q:.5,g:.5,type:'lowpass',att:.35}); nz(t+.2,1.2,{f:2500,q:.7,g:.12,att:.3});
    for(const [f,d] of [[311,0],[392,0]]) tone(t+.05,.55,{f,type:'square',g:.06}); tone(t+.05,.55,{f:466,type:'square',g:.04}); },                       // 교행: 굉음 · 경적
  zap(){ if(!SND.on) return; const t=SND.ctx.currentTime; for(let k=0;k<4;k++){ const d=k*.035+Math.random()*.02; nz(t+d,.03,{f:4200+Math.random()*2000,q:.6,g:.15,type:'highpass'}); } tone(t,.09,{f:120,type:'square',g:.045}); },
  unlock(){ if(!SND.on) return; const t=SND.ctx.currentTime; [523,784,1046,1318,1568].forEach((f,i)=>tone(t+i*.08,.5,{f,type:'triangle',g:.15})); },
};
// 계속 도는 소리 갱신(매 프레임): 속도 · 다리 · 제동 · 정차 · 형광등 깜빡임
function sndUpdate(){ if(!SND.on||!GS.on) return; const c=SND.ctx, t=c.currentTime, v=TR.v, k=Math.min(1,v/720);
  const BRG=bridgeSpan&&bridgeSpan(), out=!!(BRG&&BRG.full)||STAGE.el;
  SND.rumG.gain.setTargetAtTime(.05+.5*k*(out?.6:1), t,.1); SND.rumF.frequency.setTargetAtTime(70+170*k, t,.1);
  SND.motO.frequency.setTargetAtTime(90+780*k, t,.15); SND.motF.frequency.setTargetAtTime(160+900*k, t,.15); SND.motG.gain.setTargetAtTime(TR.phase==='accel'?.05:.02*k, t,.2);
  SND.windG.gain.setTargetAtTime(out?.12*k:.02*k, t,.3);
  { const br=GS.brakeGlow>.05 && v>8 ? GS.brakeGlow : 0;
    SND.frG.gain.setTargetAtTime(br*.2*Math.min(1,v/220), t,.04);                                                  // 긁히는 마찰(속도에 비례)
    SND.grG.gain.setTargetAtTime(br*.22*Math.min(1,v/400), t,.06); SND.grF.frequency.setTargetAtTime(60+v*.25, t,.1);   // 갈리는 저음
    const sq = br && v<260 ? (Math.random()<.78 ? 1 : .12) * .035 * Math.min(1,(260-v)/120) : 0;                    // 쇳소리: 멈출 무렵에만, 끊겼다 이어진다
    SND.sqG.gain.setTargetAtTime(sq, t,.015); SND.sqO.forEach((o,k)=>o.frequency.setTargetAtTime([3150,4720,6230][k]*(1+(Math.random()-.5)*.03), t,.01)); }   // 규칙적 떨림 없이 불규칙하게
  if(SND.lastPh==='brake' && TR.phase==='stop') sfx.hiss(); SND.lastPh=TR.phase;
  SND.crowdG.gain.setTargetAtTime(GS.atStop && TR.door>.5 ? .07 : 0, t,.3);
  const C=CAR_CONCEPTS[LINE[GS.ci||0].car]; SND.humG.gain.setTargetAtTime((C.works||C.broken)?.012+.03*(TR.flickS||0):(GS.oneBit?.0:.004), t,.05);
  // 문: 열림 · 닫힘 시작 소리, 닫히기 직전 신호음
  if(GS.doorWant!==SND.lastDW){ if(SND.lastDW===true && GS.doorWant===false && TR.door>.5) sfx.chime(); SND.lastDW=GS.doorWant; SND.doorT=performance.now(); }
  const dm=TR.door>(SND.lastDoor??TR.door)?1:TR.door<(SND.lastDoor??TR.door)?-1:0; if(dm!==0 && dm!==SND.doorMov){ if(performance.now()-(SND.doorT||0)<1500 || dm>0) sfx.door(dm>0); } SND.doorMov=dm; SND.lastDoor=TR.door;
  musicTick(); }
// --- 누아르 재즈 배경음: D단조 ii-V-i(Em7b5 · A7 · Dm7 · Dm7). 긴장도(평온 · 전투 · 위기 · 두목)에 따라 악기가 겹친다 ---
const CHORDS=[[52,55,58,62],[57,61,64,67],[50,53,57,60],[50,53,57,62]], BASSW=[[40,43,46,47],[45,44,43,42],[38,41,45,43],[38,40,41,42]];
const mtof=m=>440*Math.pow(2,(m-69)/12);
function musicTick(){ if(GS.prologue){ const c=SND.ctx, M=SND.mus; if(!M.t || M.t<c.currentTime-.5) M.t=c.currentTime+.05; const spb=60/96/2;
    while(M.t<c.currentTime+.15){ const st=M.step%16, t=M.t; if(st===0||st===3) tone(t,.16,{f:st?52:58,to:36,g:.45,bus:'music'}); if(st===0 && (M.step/16|0)%2===0) tone(t,spb*15,{f:mtof(38),type:'sawtooth',g:.03,att:.4,bus:'music'}); if(st===8) tone(t,spb*7,{f:mtof(45),type:'triangle',g:.025,att:.3,bus:'music'}); M.t+=spb; M.step++; } return; }
  const c=SND.ctx, M=SND.mus, nf=foes().length, Lh=LINE[GS.ci], left=legDur(Lh)-(GS.legT||0);
  const boss=foes().some(a=>a.e.boss), danger=nf && left<legDur(Lh)*.25 && GS.state==='fight';
  const lvl = boss?3 : danger?2.5 : nf?2 : 1; M.int += (lvl-M.int)*.02;
  const bpm = 92 + (M.int>1.5?18:0) + (M.int>2.4?14:0), spb=60/bpm/2;                                    // 8분음표 단위
  if(!M.t || M.t<c.currentTime-.5) M.t=c.currentTime+.05;
  while(M.t < c.currentTime+.15){ const st=M.step%16, bar=Math.floor(M.step/16)%4, t=M.t, sw = st%2 ? spb*.33 : 0;   // 스윙
    if(st%2===0){ const bn=BASSW[bar][st/4|0]; if(st%4===0 || M.int>1.6) tone(t,spb*1.8,{f:mtof(bn),type:'triangle',g:.32,att:.01,bus:'music'}); }   // 워킹 베이스
    if(st%4===2) nz(t+sw,.12,{f:4000,q:.4,g:M.int>1.4?.06:.035,type:'highpass',bus:'music'});                     // 브러시(뒷박)
    if(M.int>1.6 && st%2===0) nz(t+sw,.18,{f:8000,q:.5,g:.03,type:'highpass',bus:'music'});                        // 라이드
    if(st===0 || (M.int>2.3 && st===10)) CHORDS[bar].forEach(n=>tone(t+sw,spb*(st===0?6:2),{f:mtof(n+12),g:M.int>2.3?.05:.04,att:.02,bus:'music'}));   // 로즈 화음
    if(M.int>2.6 && st%8===6) tone(t,spb,{f:mtof(CHORDS[bar][3]+24),type:'square',g:.025,bus:'music'});            // 위기 · 두목: 날카로운 찌르기
    if(GS.ev && GS.ev.k==='busk' && GS.ev.t<GS.ev.dur) tone(t+sw,spb*1.6,{f:mtof(CHORDS[bar][st%4]+12+(st%8>3?12:0)),type:'triangle',g:.09,att:.003,bus:'music'});   // 버스커 기타 아르페지오
    M.t+=spb; M.step++; } }
['pointerdown','keydown'].forEach(ev=>window.addEventListener(ev,()=>{ if(GS.on||scene==='subway') sndInit(); },{passive:true}));

