// =========================================================
// 보너스 스테이지: 차 부수기 (스트리트 파이터 II · 파이널 파이트 오마주) — 3D 각기둥 차 · 파손 6단계 · 3D 파편 · 시간 제한 · 빌드 화력 중간 점검
// =========================================================
const CAR_PAINT=M.ARMOR;
function carModel(){ const P=CAR_PAINT, G=M.GLASS, S=M.STEEL, K=M.MDARK, F=M.FRAME, Y=M.GOLD, A=M.NEONO||M.GOLD, Z=15.25;
  const dents=[]; const r=mulberry(1991); for(let k=0;k<18;k++){ const x=-36+r()*70, y=-12+r()*7, w=1.4+r()*2.6, h=1.6+r()*2.4; dents.push(prism(y,y+h, x,w,.6, x,w*.8,.6, k%3?K:S,k%3?1:2,31,15.4)); }
  const thin=(y0,y1,x,hw,z,m,t,part=20)=>prism(y0,y1, x,hw,.25, x,hw,.25, m,t,part,z);
  return {
    body:[ prism(-13,-4, 0,40,15, 0,40,15, P,3,20), prism(-13.2,-12.4, 0,39.6,14.8, 0,39.6,14.8, P,4,20),                                  // 차체 · 어깨선 하이라이트
      prism(-4,-2.6, 0,37,13.6, 0,37,13.6, K,1,20) ],
    detail:[ thin(-10.5,-4, 26,7.4,Z,K,0), thin(-10.5,-4, -26,7.4,Z,K,0),                                                             // 휠 아치
      thin(-5.6,-4.4, 0,30,Z+.05,S,2), thin(-9.3,-8.7, 0,39,Z+.05,S,4),                                                                 // 로커 패널 · 크롬 사이드 몰딩
      thin(-12,-5, -20,.2,Z+.1,K,1), thin(-12,-5, -2,.2,Z+.1,K,1), thin(-12,-5, 16,.2,Z+.1,K,1),                                       // 문 이음매
      thin(-10.6,-10, 10,1.4,Z+.15,S,4), thin(-10.6,-10, -9,1.4,Z+.15,S,4), thin(-10.5,-8.5, -33,1,Z+.1,P,2),                         // 손잡이 · 주유구
      prism(-11.5,-6, 40.3,.4,9.5, 40.3,.4,9.5, S,4,20), prism(-11,-6.5, 40.5,.4,8, 40.5,.4,8, K,0,20),                                // 그릴 테 · 그릴
      ...[-6,-3,0,3,6].map(z=>prism(-11,-6.5, 40.7,.2,.3, 40.7,.2,.3, S,3,20,z)), prism(-9.6,-8.2, 40.9,.3,1, 40.9,.3,1, Y,4,20),   // 그릴 살 · 엠블럼(가상)
      prism(-11.5,-8, 40.4,.6,3.6, 40.4,.6,3.6, S,4,20,11), prism(-11.5,-8, 40.4,.6,3.6, 40.4,.6,3.6, S,4,20,-11),                   // 전조등 크롬 테
      prism(-7.8,-6.8, 40.4,.5,2.6, 40.4,.5,2.6, A,4,20,12), prism(-7.8,-6.8, 40.4,.5,2.6, 40.4,.5,2.6, A,4,20,-12),                  // 방향지시등
      prism(-6,-4, 40.8,.4,4, 40.8,.4,4, F,4,20), ...[-2,0,2].map(z=>prism(-5.4,-4.6, 41.1,.2,.5, 41.1,.2,.5, K,1,20,z)),           // 앞 번호판
      prism(-6,-4, -40.8,.4,4, -40.8,.4,4, F,4,20), prism(-4,-3, -40.6,1.2,1.2, -40.6,1.2,1.2, K,1,20,-8),                            // 뒤 번호판 · 배기구
      prism(-11,-8, -40.4,.5,13.5, -40.4,.5,13.5, M.RED,3,20), prism(-10.5,-8.5, -40.6,.4,2, -40.6,.4,2, F,4,20,5), prism(-10.5,-8.5, -40.6,.4,2, -40.6,.4,2, F,4,20,-5) ],   // 긴 후미등 · 후진등
    cabin:[ prism(-23.5,-13, -3,15.5,11.6, -2,23,12.8, K,0,21), prism(-25,-23.6, -3,16.5,12.3, -3,15.5,11.9, P,4,21), prism(-13.6,-13, -2,23.6,13.4, -2,23.6,13.4, S,4,21),   // 실내(어둠) · 지붕 · 창틀 크롬
      prism(-30,-23.5, -30,.3,.3, -30,.3,.3, K,1,21,-6) ],                                                                                 // 안테나
    interior:[ prism(-21,-14, -9,1.6,5, -10,1.8,5, K,1,21,5), prism(-21,-14, 6,1.6,5, 5,1.8,5, K,1,21,5), prism(-17,-15.6, 12,.4,2.2, 12,.4,2.2, K,1,21,5) ],   // 좌석 · 핸들 실루엣
    glassS:[ prism(-22.6,-13.8, -10.5,8.2,.3, -10.5,8.6,.3, G,3,21,13.5), prism(-22.6,-13.8, 7.5,7.2,.3, 8.5,8.5,.3, G,3,21,13.5),
      prism(-22,-21.2, -10.5,7.6,.35, -10.5,7.6,.35, M.FRAME,4,21,13.6) ],                                                                // 옆유리 2장(B필러) · 반사 줄
    glassF:[ prism(-23.6,-13.2, 14.6,.5,11.8, 22,.5,12.8, G,3,21) ], glassB:[ prism(-23.6,-13.2, -19.6,.5,11.8, -25.6,.5,12.8, G,2,21) ],
    glassX:[ prism(-23.6,-13.2, 14.6,.5,11.8, 22,.5,12.8, S,4,21), ...[[-21,15,-16,20],[-19,17,-14,21],[-22,16,-15,19]].map(([y0,x0,y1,x1])=>prism(y0,y1, x0,.2,6, x1,.2,6, F,5,21)) ],   // 금 간 앞유리 · 금
    pillar:[ prism(-24,-13, -19,1.3,12.6, -25.5,1.5,13.4, P,2,21), prism(-24,-13, 13.5,1.1,12.6, 21.5,1.3,13.4, P,2,21), prism(-24,-13, -2.4,1,12.8, -2,1.2,13.6, P,3,21) ],
    wiper:[ prism(-14.4,-13.8, 19,3.5,.3, 19,3.5,.3, K,1,21,5), prism(-14.4,-13.8, 19,3.5,.3, 19,3.5,.3, K,1,21,-5) ],
    hood:[ prism(-1,0, 13.5,13.5,14.6, 13.5,13.5,14.6, P,4,22), prism(-1.2,-.9, 13.5,12.5,.6, 13.5,12.5,.6, P,5,22) ], trunk:[ prism(-1,0, -9,9,14.6, -9,9,14.6, P,4,23), prism(-1.6,-1, -17.5,.6,14.6, -17.5,.6,14.6, P,3,23) ],
    bumperF:[ prism(-3,2, 0,1.6,15.4, 0,1.6,15.4, S,4,24), prism(-1,.2, .4,1.4,15.6, .4,1.4,15.6, K,1,24) ], bumperR:[ prism(-3,2, 0,1.6,15.4, 0,1.6,15.4, S,4,25), prism(-1,.2, -.4,1.4,15.6, -.4,1.4,15.6, K,1,25) ],
    doorF:[ prism(-12,-5, 9,9,.7, 9,9,.7, P,3,26), prism(-10,-9.4, 12,1.6,.9, 12,1.6,.9, S,4,26), prism(-9.3,-8.7, 9,9,.8, 9,9,.8, S,4,26) ],
    doorR:[ prism(-12,-5, 9,9,.7, 9,9,.7, P,3,27), prism(-10,-9.4, 11,1.6,.9, 11,1.6,.9, S,4,27), prism(-9.3,-8.7, 9,9,.8, 9,9,.8, S,4,27) ],
    mirror:[ prism(-3,0, 0,1.8,1.4, 0,1.6,1.4, P,3,28), prism(-2.4,-.6, .6,1.2,1.5, .6,1.2,1.5, G,3,28) ],
    wheelF:[ prism(-5,5, 0,5,3, 0,5,3, K,1,29), prism(-3.4,3.4, 0,3.4,3.2, 0,3.4,3.2, S,2,29) ], hubF:[ prism(-2.2,2.2, 0,2.2,3.5, 0,2.2,3.5, S,4,29), prism(-.6,.6, 0,.6,3.7, 0,.6,3.7, K,1,29) ], wheelF2:[ prism(-5,5, 0,5,2.9, 0,5,2.9, K,1,29) ],
    wheelR:[ prism(-5,5, 0,5,3, 0,5,3, K,1,29), prism(-3.4,3.4, 0,3.4,3.2, 0,3.4,3.2, S,2,29), prism(-2.2,2.2, 0,2.2,3.5, 0,2.2,3.5, S,4,29) ], wheelR2:[ prism(-5,5, 0,5,2.9, 0,5,2.9, K,1,29) ],
    farW:[ prism(-5,5, 26,5,2.6, 26,5,2.6, K,0,29,-12.5), prism(-5,5, -26,5,2.6, -26,5,2.6, K,0,29,-12.5) ],                             // 반대편 바퀴
    lightF:[ prism(-11,-8.4, 0,.5,3, 0,.5,3, M.FRAME,5,30,11), prism(-11,-8.4, 0,.5,3, 0,.5,3, M.FRAME,5,30,-11) ], lightR:[ prism(-10.8,-8.2, 0,.4,3.6, 0,.4,3.6, M.RED,4,30,10), prism(-10.8,-8.2, 0,.4,3.6, 0,.4,3.6, M.RED,4,30,-10) ],
    dents };
}
const CAR_K=1.3;                                                                                                 // 차 크기(레퍼런스처럼 화면 중심을 차지하게)
const CAR_MODEL=(()=>{ const m=carModel(); for(const k in m) for(const pc of m[k]){ pc.q=pc.q.map(qd=>qd.map(v=>[v[0]*CAR_K,v[1]*CAR_K,v[2]*CAR_K])); pc.c=pc.c.map(v=>v*CAR_K); } return m; })(), CAR_STAGES=[.88,.76,.64,.52,.40,.28,.16,0];
function carBones(C){ const s=C.stage, f=C.dmgF||0, sh=C.shake>0?(Math.random()-.5)*2.4*C.shake:0, B={}, g=C.gone;
  const put=(k,x,y,z,th,o)=>{ if(!g[k]) B[k]={x:x+sh,y,z,th:th||0,...(o||{})}; };
  const sink=f*2.2, crush=Math.max(0,f-.45)*1.6, cy=crush*7;                                                       // 차체가 내려앉고 · 절반부터 지붕이 점점 주저앉는다
  const cs={sy:Math.max(.42,1-crush)}; put('farW',0,0,0,0); put('body',0,sink,0,0); put('detail',0,sink,0,0); put('cabin',0,sink+cy,0,0,cs); put('interior',0,sink+cy,0,0,cs); put('pillar',0,sink+cy,0,0,cs);
  if(s<5) put('glassS',0,sink+cy,0,0,cs); if(s<8) put(s>=3?'glassX':'glassF',0,sink+cy,0,0,cs); if(s<7) put('glassB',0,sink+cy,0,0,cs); if(s<6) put('wiper',0,sink+cy*.3,0,0);
  put('hood',13,-13+sink,0, s>=6?0:-(.04+f*.18)); put('trunk',-22,-13+sink,0, s>=7?.5:f*.1);
  put('bumperF',40,-6+sink,0, -f*.25); put('bumperR',-40,-6+sink,0, s>=8?.3:0);
  put('doorF',-2,sink,15.6,0); put('doorR',-20,sink,15.6,0); put('mirror',15,-14.5+sink,15.4,0);
  put('wheelF',26,-5,12,0); put('hubF',26,-5,12,0); put('wheelF2',26,-5,12,Math.PI/4); put('wheelR',-26,-5,12,0); put('wheelR2',-26,-5,12,Math.PI/4);
  if(s<5) put('lightF',40.6,sink,0,0); put('lightR',-40.6,sink,0,0);                                            // 등 조각은 높이를 이미 갖고 있다(뼈 높이를 또 더하면 떠오른다)
  C.dentN=Math.min(18,Math.round(f*24)); if(C.dentN) B.dents={x:sh,y:sink,z:0,th:0};
  if(C.tilt){ const px=-26, py=0, cs=Math.cos(C.tilt), sn=Math.sin(C.tilt); for(const k in B){ const b=B[k], dx=b.x-px, dy=b.y-py; b.x=px+dx*cs-dy*sn; b.y=py+dx*sn+dy*cs; b.th+=C.tilt; } }
  for(const k in B){ const b=B[k]; b.x*=CAR_K; b.y*=CAR_K; b.z*=CAR_K; }
  return B; }
function drawBonusCar(dyn){ const BN=GS.bonus; if(!BN||!BN.car) return; const C=BN.car, ox=C.x-Math.round(GS.cam||0);
  const model={...CAR_MODEL, dents:CAR_MODEL.dents.slice(0,C.dentN||0)}, act={ d:{ flip:false, y:C.y, model3:model } };
  pushModel(act, carBones(C), ox, C.y, m=>m, C.flash>0); drawPfx(BN);
  for(const d of C.debris){ const a2={ d:{ flip:false, y:C.y, model3:{ [d.key]:CAR_MODEL[d.key] } } }; pushModel(a2, { [d.key]:{ x:d.x-C.x, y:d.y-C.y, z:d.z, th:d.th } }, ox, C.y, m=>m, false); }
  if(BN.alarm && !BN.alarmOff && Math.floor(performance.now()/260)%2) for(const [hx,hy] of [[57,-10],[-57,-12]]) dyn.push({ x:ox+hx, y:C.y+hy, z:8, r:46, c:[1,.62,.12], i:1.5 });   // 비상등
  if(BN.fire) dyn.push({ x:ox+30, y:C.y-24, z:12, r:110, c:[1,.55,.2], i:1.6+Math.random()*.6 });                                               // 불길의 일렁이는 빛
  if(C.stage<3){ dyn.push({ x:ox+57, y:C.y-13, z:6, r:80, c:[1,.95,.8], i:1.2, spot:[1,0], cone:.7 }); } dyn.push({ x:ox-57, y:C.y-13, z:6, r:28, c:[1,.2,.15], i:.7 }); }

// --- 보너스 스테이지 진행: 소개 → 30초 → 단계별 파손 연출 → 차 주인 → 결과 · 보상 → 6선 환승 ---
const CAR_HP=460, CAR_TIME=30;
