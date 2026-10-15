// =========================================================
// 공격 손맛 v2: 무게 등급(가벼움 L · 중간 M · 무거움 H)마다 박자 · 팔로우스루 · 고유 회복 · 전진 · 타격감이 다르다
// =========================================================
const ATK_FEEL={
  renkan:{ w:'M', load:'rk_crouch', hit:'rk_k1', hs:1.0, shake:1.6, zoom:.03, step:0 },
  tetsu: { w:'H', load:'ts_set', hit:'ts_hit', hs:2.3, shake:3.6, zoom:.1,   step:0, dust:1 },
  cycle: { w:'L', load:'cy_jump', hit:'cy_k1', hs:.7,  shake:1.0, zoom:.02,  step:0 },
  axe:   { w:'H', load:'ax_top',  hit:'ax_hit', hs:1.75,shake:3.0, zoom:.08,  step:2, dust:1 },
  axe_air:{ w:'H', load:'axa_top', hit:'axa_hit',hs:1.75,shake:3.0, zoom:.08,  step:0, dust:1 },
  suplex:{ w:'H', load:'sx_lift', hit:'sx_arch',hs:1.6, shake:3.2, zoom:.08,  step:0, dust:1 },
  jab:   { w:'L', load:'j_load',  hit:'j_hit',  hs:.75, shake:1.0, zoom:0,    step:3 },
  bfist: { w:'L', load:'bf_load', hit:'bf_hit', hs:.85, shake:1.2, zoom:0,    step:0 },
  elbow: { w:'L', load:'e_load',  hit:'e_hit',  hs:.95, shake:1.3, zoom:.02,  step:3 },
  cross: { w:'M', load:'c_pull',  hit:'c_hit',  hs:1.05,shake:1.6, zoom:.03,  step:6 },
  hook:  { w:'M', load:'h_load',  hit:'h_hit',  hs:1.15,shake:1.8, zoom:.04,  step:4 },
  kick:  { w:'M', load:'k_load',  hit:'k_hit',  hs:1.1, shake:1.7, zoom:.035, step:5 },
  knee:  { w:'M', load:'n_load',  hit:'n_hit',  hs:1.25,shake:1.9, zoom:.045, step:6 },
  bkick: { w:'M', load:'bk_load', hit:'bk_hit', hs:1.15,shake:1.8, zoom:.04,  step:0 },
  upper: { w:'H', load:'u_load',  hit:'u_hit',  hs:1.55,shake:2.6, zoom:.075, step:3, dust:1 },
  round: { w:'H', load:'r_load',  hit:'r_hit',  hs:1.5, shake:2.6, zoom:.07,  step:7, dust:1 },
  sweep: { w:'H', load:'sw_load', hit:'sw_hit', hs:1.35,shake:2.2, zoom:.05,  step:4, dust:1 },
  stomp: { w:'H', load:'st_load', hit:'st_hit', hs:1.5, shake:3.0, zoom:.06,  step:2, dust:1 },
  charge:{ w:'H', hs:1.4, shake:2.8, zoom:.06, step:0, dust:1 },
  fkick: { w:'H', hs:1.5, shake:2.7, zoom:.07, step:0, dust:1 },
  swat:   { w:'L', load:'np_load', hit:'np_hit', hs:.8,  shake:1.0, zoom:0,   step:2 },
  uthrust:{ w:'M', load:'ut_load', hit:'ut_hit', hs:1.05,shake:1.4, zoom:.03, step:6 },
  throw: { w:'H', hs:1.7, shake:3.2, zoom:.08, step:0, dust:1 },
};
// 팔로우스루 = 타격 자세를 (준비 → 타격) 방향으로 더 밀어낸 자세 · 회복 = 팔로우스루와 가드 사이
function deriveFollow(only){ const OK={L:.18,M:.24,H:.32}, NUM=['r','t','ty','aF','eF','aB','eB','air','w'], ARR=['b','h','fF','fB'];
  const g=(o,k)=>o[k]??0, ga=(o,k)=>o[k]||[0,0];
  for(const a in ATK_FEEL){ const F=ATK_FEEL[a]; if(!F.load||!F.hit) continue; if(only && !only.includes(a)) continue; if(!only && POSES[F.hit+'_ft']) continue; const L=POSES[F.load], Hh=POSES[F.hit], G=POSES.c_over; if(!L||!Hh||!G) continue; const k=OK[F.w];
    const ft={ w:Hh.w }, rt={ w:Hh.w };
    for(const n of NUM){ if(Hh[n]==null && L[n]==null) continue; ft[n]=g(Hh,n)+(g(Hh,n)-g(L,n))*k; }
    for(const n of ARR){ const hv=ga(Hh,n), lv=ga(L,n); ft[n]=[hv[0]+(hv[0]-lv[0])*k, hv[1]+(hv[1]-lv[1])*k]; }
    if(ft.eF!=null) ft.eF=Math.max(0,Math.min(1,ft.eF)); if(ft.eB!=null) ft.eB=Math.max(0,Math.min(1,ft.eB)); if(ft.air!=null) ft.air=Math.max(0,ft.air);
    for(const n of NUM){ if(ft[n]==null && G[n]==null) continue; rt[n]=(ft[n]??g(Hh,n))*.5+g(G,n)*.5; }
    for(const n of ARR){ const fv=ft[n], gv=ga(G,n); rt[n]=[fv[0]*.5+gv[0]*.5, fv[1]*.5+gv[1]*.5]; }
    if(rt.air!=null) rt.air=Math.max(0,rt.air*.4);
    if(Hh.upF) ft.upF=true; if(Hh.upB) ft.upB=true; if(Hh.strF) ft.strF=1+(Hh.strF-1)*.5; if(Hh.strB) ft.strB=1+(Hh.strB-1)*.5;
    POSES[F.hit+'_ft']=ft; POSES[F.hit+'_rt']=rt; } }
deriveFollow();
// 무기 전용 동작: 무기는 F(뒷손)에 붙으므로 F 팔로 친다
Object.assign(POSES, {
  ut_load:  { r:-2, b:[-1,3], h:[-1,1], t:.2,  ty:.35, aF:4.9, eF:.42, aB:5.8, eB:.36, w:4.3, fF:[-.75,0], fB:[.72,0] },
  ut_smear: { r:5,  b:[3,5],  h:[3,2],  t:2.1, ty:.65, aF:4.35, eF:.95, strF:1.25, aB:5.6, eB:.4, w:4.4, fF:[-.88,0], fB:[.92,0], smear:'b' },
  ut_hit:   { r:7,  b:[3,6],  h:[3,2],  t:2.4, ty:.75, aF:4.4, eF:1,   strF:1.15, aB:5.4, eB:.45, w:4.45, fF:[-.9,0], fB:[1.0,0], impact:true, snap:true },
  np_load:  { r:-2, b:[-1,1], h:[-1,0], t:-.5, ty:.45, aF:7.4, eF:.7,  aB:5.8, eB:.36, w:8.5, fF:[-.7,0], fB:[.62,0] },
  np_smear: { r:3,  b:[1,3],  h:[1,1],  t:1.0, ty:.55, aF:5.6, eF:.95, strF:1.15, aB:5.8, eB:.36, w:6, fF:[-.75,0], fB:[.66,0], smear:'b' },
  np_hit:   { r:6,  b:[2,4],  h:[2,1],  t:1.9, ty:.65, aF:3.4, eF:1,   aB:5.8, eB:.36, w:3, fF:[-.78,0], fB:[.7,0], impact:true, snap:true },
});
deriveFollow(['swat','uthrust']);
// 공중 피격 자세(저글): 떠오름 · 공중 피격 · 뒤로 넘어가며 낙하 · 수평으로 날아감 · 얼굴 위로 낙하
Object.assign(POSES, {
  air_up:   { r:-4,  b:[0,-1], h:[-3,-3], t:-3.0, ty:.3, aF:7.6, eF:.9,  aB:7.2, eB:.9,  w:4, fF:[.35,-.45], fB:[.15,-.2] },
  air_hit:  { r:-8,  b:[0,1],  h:[-4,-2], t:-4.6, ty:.6, aF:6.4, eF:.95, aB:7.6, eB:.95, w:4, fF:[.7,-.6],  fB:[.4,-.3], snap:true },
  air_back: { r:-9,  b:[-1,2], h:[-2,0],  t:-4.6, ty:.3, aF:6.8, eF:.85, aB:6.2, eB:.85, w:4, fF:[.7,-.6],  fB:[.5,-.4] },
  air_blow: { r:-10, b:[0,4],  h:[-3,-1], t:-5.6, ty:.4, aF:3.0, eF:.95, aB:3.6, eB:.95, w:4, fF:[.85,-.25], fB:[.7,-.05] },
  air_fall: { r:-12, b:[0,8],  h:[-1,0],  t:-6.0, ty:.2, aF:6.6, eF:.85, aB:6.0, eB:.85, w:4, fF:[.85,-.5], fB:[.7,-.35] },
  air_jerk: { r:-6,  b:[-2,3], h:[3,2],   t:-1.0, ty:.2, aF:3.4, eF:.9,  aB:3.0, eB:.9,  w:4, fF:[.7,-.3],  fB:[.6,-.2], snap:true },   // 맞는 순간: 몸통이 먼저 뒤로 · 머리 팔다리는 앞에 남아 C자
  air_arch: { r:-6,  b:[0,2],  h:[-4,-3], t:-1.8, ty:.3, aF:7.4, eF:.9,  aB:7.0, eB:.9,  w:4, fF:[.55,-.25], fB:[.4,-.15] },              // 비행: 선 채로 등을 젖히고(머리 뒤로 · 팔은 머리 위) 다리는 앞에 남음 — 회전이 몸을 뒤로 넘긴다
  air_trip: { r:-12, b:[0,14], h:[-1,0],  t:-6.2, ty:.2, aF:6.8, eF:.85, aB:6.2, eB:.85, w:4, fF:[.85,-.8], fB:[.75,-.6] },    // 다리걸기: 다리만 들린 채 무릎 높이로 뒤로 넘어감

  dig:      { r:4,   b:[2,10], h:[2,3],   t:3.0,  ty:.4, aF:2.6, eF:.8,  aB:5.6, eB:.5,  w:4, fF:[-.9,0],   fB:[.95,0] },        // 브릿지: 몸을 낮춰 파고들기(손을 등 밑으로)
  cr0:      { r:3,   b:[1,4],  h:[2,3],   t:3.6,  ty:.2, aF:2.6, eF:.35, aB:2.4, eB:.35, w:4, fF:[-.35,0],  fB:[.3,0], snap:true },   // 무너짐: 배를 움켜쥐고 꺾임
  cr1:      { r:4,   b:[1,9],  h:[2,4],   t:3.2,  ty:.2, aF:2.8, eF:.35, aB:2.6, eB:.35, w:4, fF:[-.4,0],   fB:[.35,0] },
  cr2:      { r:5,   b:[1,15], h:[3,4],   t:2.6,  ty:.2, aF:3.0, eF:.4,  aB:2.8, eB:.4,  w:4, fF:[-.45,0],  fB:[.3,0] },
  cr3:      { r:-4,  b:[0,15], h:[0,2],   t:-2.0, ty:.2, aF:5.0, eF:.6,  aB:4.4, eB:.6,  w:4, fF:[.5,0],    fB:[.6,0] },
});
Object.assign(POSES, {
  so0: { r:-2, b:[0,3], h:[-2,1], t:.6,  ty:1.2, aF:6.4, eF:.8, aB:2.4, eB:.8, w:4, fF:[-.4,0], fB:[.5,0], spin:.22, snap:true },   // 돌려 세움: 빙글 돌아
  so1: { r:2,  b:[0,4], h:[1,2],  t:1.2, ty:.6,  aF:5.0, eF:.6, aB:3.6, eB:.6, w:4, fF:[-.45,0], fB:[.5,0], spin:.42 },
  so2: { r:3,  b:[1,5], h:[2,3],  t:1.8, ty:.3,  aF:4.0, eF:.5, aB:3.6, eB:.5, w:4, fF:[-.5,0], fB:[.45,0], spin:.5 },              //  등을 보이고 비틀
  pl0: { r:6,  b:[2,3], h:[3,2],  t:3.2, ty:.3,  aF:3.2, eF:.95,aB:3.6, eB:.95,w:4, fF:[.55,0], fB:[-.6,0], snap:true },            // 끌려옴: 앞으로 고꾸라짐
  pl1: { r:4,  b:[1,4], h:[2,2],  t:2.4, ty:.2,  aF:4.2, eF:.7, aB:4.6, eB:.7, w:4, fF:[.3,0], fB:[-.45,0] },
});
JW_SEQ.spinout=[['so0',80],['so1',120],['so2',650],['c_over',140]]; JW_SEQ.pulled=[['pl0',90],['pl1',260],['c_over',140]];
// 섬머솔트 킥: 웅크림 → 도약 → 무릎 당김 → 뒤로 젖히며 차올림(초승달) → 거꾸로 → 다시 웅크림 → 내려옴 → 착지
Object.assign(POSES, {
  // 연환퇴: 웅크림 → 앞다리로 엉덩이 높이 1타 → 공중에서 다리 바꿈 → 꼭대기에서 뒷다리 수직 2타 → 내려와 착지
  rk_crouch:{ r:0, b:[0,6], h:[0,1], t:.8,  ty:0, aF:3, eF:.5, aB:3, eB:.5, w:4, fF:[.3,0], fB:[-.3,0], legFK:true, lFT:-65, lFK:-55, lBT:-115, lBK:-35, armFK:true, uF:3.2, lF:6.4, uB:2.4, lB:5.6 },
  rk_k1:    { r:0, b:[0,0], h:[0,-1],t:-.4, ty:.2,aF:3, eF:.5, aB:3, eB:.5, w:4, fF:[.8,-.5], fB:[-.1,0], legFK:true, lFT:-95, lFK:-15, lBT:25, lBK:-45, air:10, armFK:true, uF:5.5, lF:6.5, uB:.8, lB:.4, impact:true, snap:true },   // 1타: 뒷다리(먼 쪽)를 엉덩이 높이로
  rk_sw:    { r:0, b:[0,0], h:[0,-1],t:-.3, ty:0, aF:3, eF:.5, aB:3, eB:.5, w:4, fF:[.3,-.6], fB:[.1,-.6], legFK:true, lFT:10, lFK:-60, lBT:-30, lBK:-60, air:18, armFK:true, uF:4.2, lF:5.4, uB:2.0, lB:3.0 },   // 공중에서 다리 바꿈(가위)
  rk_k2:    { r:0, b:[0,0], h:[-1,-1],t:-1.5,ty:-.2,aF:3, eF:.5, aB:3, eB:.5, w:4, fF:[.8,-1.9], fB:[-.1,-.5], legFK:true, lFT:55, lFK:-4, lBT:-75, lBK:-55, air:24, armFK:true, uF:1.0, lF:.5, uB:.6, lB:.3, impact:true, snap:true },   // 2타: 앞다리(카메라 쪽)를 머리 위로 수직에 가깝게 · 팔은 다리를 가리지 않게
  rk_fall:  { r:0, b:[0,2], h:[0,0], t:.2,  ty:0, aF:3, eF:.5, aB:3, eB:.5, w:4, fF:[.2,0], fB:[-.2,0], legFK:true, lFT:-80, lFK:-20, lBT:-100, lBK:-30, air:8, armFK:true, uF:3.0, lF:5.0, uB:2.6, lB:5.0 },
  rk_land:  { r:0, b:[0,6], h:[0,1], t:.7,  ty:0, aF:3, eF:.5, aB:3, eB:.5, w:4, fF:[.3,0], fB:[-.3,0], legFK:true, lFT:-60, lFK:-70, lBT:-112, lBK:-40, armFK:true, uF:3.2, lF:6.2, uB:2.4, lB:5.4, snap:true },
  // 철산고: 반 보 물러서 낮춤 → 앞발 들며 파고듦 → 진각 · 몸을 돌려 등과 어깨로(넓은 보폭 · 상체를 뒤로 기댐) → 버팀 → 회복
  ts_set:   { r:0, b:[0,4],  h:[0,0],  t:.1,   ty:0, aF:3, eF:.5, aB:3, eB:.5, w:4, fF:[.3,0], fB:[-.3,0], legFK:true, lFT:-70, lFK:-22, lBT:-108, lBK:-12, spr:8,  spin:.06,   armFK:true, uF:3.0, lF:5.6, uB:1.2, lB:3.6 },   // 반 보 물러섬: 주먹을 거두며 돌기 시작
  ts_step:  { r:0, b:[0,6],  h:[0,0],  t:-.2,  ty:0, aF:3, eF:.5, aB:3, eB:.5, w:4, fF:[.5,0], fB:[-.2,0], legFK:true, lFT:-28, lFK:-62, lBT:-62, lBK:-70, spr:15, spin:.2,    armFK:true, uF:4.4, lF:6.2, uB:1.0, lB:3.3, snap:true },   // 앞무릎을 들며 파고듦 · 반쯤 돎
  ts_hit:   { r:0, b:[0,9],  h:[0,0],  t:-.44, ty:0, aF:3, eF:.5, aB:3, eB:.5, w:4, fF:[.665,0], fB:[-.039,0], legFK:true, lFT:-13, lFK:-53, lBT:-41, lBK:-109, spr:23, spin:.3333, armFK:true, uF:4.98, lF:6.49, uB:.89, lB:3.11, impact:true, snap:true },   // 진각: 목업 확정값 · 몸 전체를 돌려 등을 적에게(게임 카메라 30° 보정) · 다리 23° 벌림
  ts_ft:    { r:0, b:[0,9],  h:[0,0],  t:-.44, ty:0, aF:3, eF:.5, aB:3, eB:.5, w:4, fF:[.665,0], fB:[-.039,0], legFK:true, lFT:-13, lFK:-53, lBT:-41, lBK:-109, spr:23, spin:.3333, armFK:true, uF:4.98, lF:6.49, uB:.89, lB:3.11 },
  ts_rt:    { r:0, b:[0,3.4], h:[0,0], t:.2,   ty:0, aF:3, eF:.5, aB:3, eB:.5, w:4, fF:[-.48,0], fB:[.55,0], legFK:true, lFT:-102.6, lFK:-31.9, lBT:-53.1, lBK:-6.4, spr:0, spin:.08, armFK:true, uF:2.4, lF:5.4, uB:1.8, lB:5.0 },   // 회복: 다리는 마무리 자세(c_over)와 똑같이 → 끝에서 튀지 않게
  // 도끼 차기에 맞음: 앞으로 고꾸라지며 꽂힘 → 얼굴부터 바닥 → 살짝 튕김 → 엎어진 채
  sp_dive:  { r:-7,b:[0,8],  h:[1,2],  t:4.6,  ty:0,   aF:6.8, eF:.5,  aB:6.4, eB:.5,  w:4, fF:[-.5,-.2], fB:[-.4,-.15], snap:true },
  sp_hit:   { r:-9,b:[0,18], h:[0,2],  t:6.8,  ty:.1,  aF:7.8, eF:.9,  aB:7.4, eB:.9,  w:4, fF:[-.92,0],  fB:[-.82,0], impact:true, snap:true },   // 얼굴부터 바닥(엎어짐 dfw1 기준)
  sp_bounce:{ r:-9,b:[0,16], h:[0,0],  t:6.4,  ty:.1,  aF:7.4, eF:.85, aB:7.0, eB:.85, w:4, fF:[-.9,-.1], fB:[-.8,-.08], air:5 },
  sp_land:  { r:-9,b:[0,17], h:[0,1],  t:6.6,  ty:.1,  aF:7.6, eF:.9,  aB:7.2, eB:.9,  w:4, fF:[-.9,0],   fB:[-.8,0], snap:true },
  sp_lie:   { r:-9,b:[0,17], h:[0,1],  t:6.6,  ty:.1,  aF:7.6, eF:.9,  aB:7.2, eB:.9,  w:4, fF:[-.9,0],   fB:[-.8,0] },
  // 엎드린 채 일어나기: 손 짚고 가슴 들기 → 무릎 당겨 네 발 → 한 무릎 세워 일어남(뒤집히지 않는다)
  pp0:      { r:-9,b:[0,16], h:[1,-1], t:4.4,  ty:.1,  aF:1.5, eF:.9,  aB:1.2, eB:.9,  w:4, fF:[-.9,0],   fB:[-.8,0] },
  pp1:      { r:-6,b:[0,13], h:[1,1],  t:4.4,  ty:.1,  aF:2.5, eF:.9,  aB:2.2, eB:.9,  w:4, fF:[-.45,0],  fB:[-.35,0] },
  // 휘청: 경직된 동안 뒤로 젖혔다 · 옆으로 흔들 · 무릎 꺾였다 · 헛발 — 팔은 힘없이 늘어지고 고개가 돈다
  stg0:     { r:-4,b:[-1,5], h:[-3,1], t:-1.0, ty:.5,  aF:.8,  eF:.95, aB:1.4, eB:.95, w:4, fF:[-.6,0],   fB:[.5,0] },
  stg1:     { r:2, b:[1,8],  h:[2,4],  t:1.8,  ty:-.4, aF:1.6, eF:.95, aB:1.0, eB:.95, w:4, fF:[-.42,0],  fB:[.4,0] },
  stg2:     { r:-1,b:[0,5],  h:[1,3],  t:.8,   ty:.3,  aF:2.0, eF:.95, aB:.6,  eB:.95, w:4, fF:[-.25,-.22],fB:[.5,0] },
  stg3:     { r:3, b:[1,6],  h:[-1,3], t:.4,   ty:-.5, aF:1.0, eF:.95, aB:1.8, eB:.95, w:4, fF:[-.5,0],   fB:[.25,-.18] },
  // 벽꽝: 등이 벽에 붙어 팔이 벌어진다(공중 · 서서)
  air_wall: { r:-2,b:[-2,1], h:[-4,-1],t:-1.6, ty:.4,  aF:6.8, eF:.95, aB:7.8, eB:.95, w:4, fF:[.15,-.15], fB:[-.1,-.05], snap:true },
  wl0:      { r:-2,b:[-2,2], h:[-4,-1],t:-1.6, ty:.4,  aF:6.8, eF:.95, aB:7.8, eB:.95, w:4, fF:[-.2,0],   fB:[.3,0], snap:true },
  wl1:      { r:1, b:[0,6],  h:[2,3],  t:1.6,  ty:0,   aF:2.0, eF:.8,  aB:1.6, eB:.8,  w:4, fF:[-.45,0],  fB:[.4,0] },   // 머리가 맞은 자리 아래로 떨어지고 몸은 뒤로 눕게(r 음수)
  // 공중 자전거 차기: 웅크림 → 도약 → 다리를 번갈아 굴리며 3연타 → 착지
  cy_crouch:{ r:0, b:[0,7],  h:[1,2],  t:1.4,  ty:0,   aF:4.4, eF:.55, aB:4.0, eB:.6,  w:4, fF:[-.35,0],  fB:[.45,0], snap:true },
  cy_jump:  { r:-2,b:[0,0],  h:[0,-1], t:-.6,  ty:0,   aF:6.4, eF:.45, aB:6.0, eB:.45, w:4, fF:[.25,-.55], fB:[-.2,-.35], air:14 },
  cy_k1:    { r:-4,b:[0,0],  h:[-1,-1],t:-1.6, ty:.25, aF:6.9, eF:.3,  aB:2.4, eB:.5,  w:4, fF:[1.25,-1.0], fB:[-.1,-.6], strL:1.1, air:20, impact:true, snap:true },
  cy_k2:    { r:-4,b:[0,0],  h:[-1,-1],t:-1.8, ty:-.25,aF:2.4, eF:.5,  aB:6.8, eB:.3,  w:4, fF:[.0,-.75], fB:[1.28,-1.05], air:22, impact:true, snap:true },
  cy_k3:    { r:-5,b:[0,0],  h:[-1,-2],t:-2.0, ty:.3,  aF:7.0, eF:.3,  aB:2.2, eB:.5,  w:4, fF:[1.32,-1.2], fB:[-.15,-.5], strL:1.12, air:23, impact:true, snap:true },
  cy_fall:  { r:-1,b:[0,2],  h:[0,0],  t:-.4,  ty:0,   aF:5.6, eF:.5,  aB:5.0, eB:.5,  w:4, fF:[.3,-.3],  fB:[-.2,-.25], air:9 },
  cy_land:  { r:0, b:[0,8],  h:[1,3],  t:1.6,  ty:0,   aF:4.4, eF:.55, aB:4.0, eB:.6,  w:4, fF:[-.4,0],   fB:[.5,0], snap:true },
  // 도끼 차기: 무릎 → 다리를 수직으로 → 꼭대기에서 버팀 → 내리찍기
  ax_load:  { r:-1,b:[0,1],  h:[0,0],  t:-.5,  ty:0,   aF:3.0, eF:.4,  aB:2.6, eB:.4,  w:4, fF:[.5,-.65], fB:[-.2,0] },
  ax_up:    { r:-3,b:[0,0],  h:[-1,0], t:-1.5, ty:0,   aF:4.6, eF:.3,  aB:1.8, eB:.4,  w:4, fF:[.55,-2.25], fB:[-.15,0], strL:1.22 },
  ax_top:   { r:-3,b:[0,0],  h:[-1,0], t:-1.9, ty:0,   aF:4.9, eF:.25, aB:1.6, eB:.4,  w:4, fF:[.75,-2.45], fB:[-.15,0], strL:1.25 },
  ax_smear: { r:2, b:[0,2],  h:[1,0],  t:.6,   ty:0,   aF:3.8, eF:.4,  aB:3.4, eB:.5,  w:4, fF:[1.2,-1.15], fB:[-.3,0], strL:1.15, smear:'f' },
  ax_hit:   { r:4, b:[0,5],  h:[2,1],  t:2.0,  ty:0,   aF:3.4, eF:.6,  aB:5.0, eB:.5,  w:4, fF:[1.05,-.15], fB:[-.5,0], impact:true, snap:true },
  ax_ft:    { r:3, b:[0,6],  h:[2,2],  t:2.2,  ty:0,   aF:3.2, eF:.6,  aB:4.8, eB:.5,  w:4, fF:[1.0,0],   fB:[-.55,0] },
  ax_rt:    { r:1, b:[0,3],  h:[1,1],  t:1.2,  ty:0,   aF:4.2, eF:.5,  aB:4.0, eB:.55, w:4, fF:[.4,0],    fB:[-.3,0] },
  axa_up:   { r:-3,b:[0,0],  h:[-1,0], t:-1.4, ty:0,   aF:5.0, eF:.3,  aB:2.0, eB:.4,  w:4, fF:[.6,-2.2],  fB:[-.2,-.3], strL:1.22, air:16 },   // 공중 도끼 차기
  axa_top:  { r:-4,b:[0,0],  h:[-1,-1],t:-1.9, ty:0,   aF:5.2, eF:.25, aB:1.8, eB:.4,  w:4, fF:[.8,-2.45], fB:[-.2,-.4], strL:1.25, air:24 },
  axa_smear:{ r:2, b:[0,1],  h:[1,0],  t:.6,   ty:0,   aF:3.8, eF:.4,  aB:3.4, eB:.5,  w:4, fF:[1.25,-1.2], fB:[-.3,-.3], strL:1.15, air:22, smear:'f' },
  axa_hit:  { r:4, b:[0,2],  h:[2,1],  t:1.8,  ty:0,   aF:3.4, eF:.6,  aB:5.0, eB:.5,  w:4, fF:[1.1,-.4],  fB:[-.4,-.3], air:16, impact:true, snap:true },
  axa_fall: { r:2, b:[0,3],  h:[1,1],  t:1.2,  ty:0,   aF:4.0, eF:.5,  aB:4.2, eB:.5,  w:4, fF:[.6,0],    fB:[-.3,0], air:6 },
  // 저먼 수플렉스: 다가가 허리 잡기 → 무릎 굽혀 들기 → 활처럼 뒤로 → 뒤쪽 바닥에 꽂고 버팀 → 일어남
  sx_reach: { r:3, b:[0,3],  h:[2,1],  t:1.8,  ty:0,   aF:4.4, eF:.9,  aB:4.6, eB:.9,  w:4, fF:[-.2,0],   fB:[.55,0] },
  sx_grab:  { r:2, b:[0,4],  h:[1,2],  t:2.2,  ty:0,   aF:4.2, eF:1.0, aB:4.4, eB:1.0, w:4, fF:[-.35,0],  fB:[.5,0], snap:true },
  sx_lift:  { r:0, b:[0,6],  h:[-1,0], t:-.9,  ty:0,   aF:6.0, eF:.9,  aB:6.2, eB:.9,  w:4, fF:[-.4,0],   fB:[.45,0] },
  sx_arch:  { r:-6,b:[-1,9], h:[-3,-1],t:-4.6, ty:0,   aF:7.6, eF:.8,  aB:7.8, eB:.8,  w:4, fF:[-.5,0],   fB:[.4,0], impact:true, snap:true },
  sx_slam:  { r:-8,b:[-2,12],h:[-4,1], t:-6.0, ty:0,   aF:8.2, eF:.7,  aB:8.0, eB:.7,  w:4, fF:[-.55,0],  fB:[.35,0] },
  sx_rise:  { r:-2,b:[0,6],  h:[-1,1], t:-1.0, ty:0,   aF:4.0, eF:.6,  aB:3.6, eB:.6,  w:4, fF:[-.3,0],   fB:[.4,0] },
  sk_crouch:{ r:0, b:[0,10], h:[1,3],  t:2.2,  ty:-.4, aF:5.2, eF:.4,  aB:4.8, eB:.5,  w:4, fF:[-.6,0],   fB:[.6,0], snap:true },
  sk_jump:  { r:0, b:[0,0],  h:[0,-1], t:.4,   ty:0,   aF:7.4, eF:.6,  aB:7.0, eB:.6,  w:4, fF:[-.2,.05], fB:[.25,0], air:10 },
  sk_tuck:  { r:0, b:[0,2],  h:[1,1],  t:1.0,  ty:0,   aF:5.2, eF:.35, aB:4.8, eB:.4,  w:4, fF:[.35,-.55], fB:[.5,-.45], air:20 },
  sk_lean:  { r:-2,b:[0,1],  h:[-2,-1],t:-1.4, ty:.2,  aF:6.0, eF:.6,  aB:5.6, eB:.6,  w:4, fF:[.3,-.3],  fB:[1.0,-.7], air:26, roll:-.08 },
  sk_kick:  { r:-4,b:[0,0],  h:[-3,-2],t:-2.4, ty:.3,  aF:6.8, eF:.8,  aB:6.4, eB:.8,  w:4, fF:[.2,-.2],  fB:[.7,-1.15], air:30, roll:-.2, impact:true, snap:true },
  sk_over:  { r:-6,b:[0,0],  h:[-3,-2],t:-2.4, ty:.3,  aF:7.2, eF:.85, aB:6.8, eB:.85, w:4, fF:[.1,-.4],  fB:[.3,-1.2], air:30, roll:-.45 },
  sk_tuck2: { r:0, b:[0,2],  h:[1,1],  t:1.0,  ty:0,   aF:5.2, eF:.35, aB:4.8, eB:.4,  w:4, fF:[.35,-.55], fB:[.5,-.45], air:24, roll:-.75 },
  sk_fall:  { r:0, b:[0,1],  h:[0,0],  t:.6,   ty:-.2, aF:6.6, eF:.5,  aB:6.2, eB:.55, w:4, fF:[-.3,-.1], fB:[.35,-.15], air:12, roll:-1 },
  sk_land:  { r:0, b:[0,8],  h:[1,2],  t:2.0,  ty:-.4, aF:5.4, eF:.45, aB:5.0, eB:.5,  w:4, fF:[-.6,0],   fB:[.6,0], snap:true },
});
POSES.land_q={ r:0, b:[0,7], h:[1,2], t:1.8, ty:-.4, aF:5.4, eF:.45, aB:5.0, eB:.5, w:4, fF:[-.55,0], fB:[.55,0] };   // 짧은 착지 웅크림
JW_SEQ.cycle=[['cy_crouch',100],['cy_jump',70],['cy_k1',75],['cy_k2',75],['cy_k3',95],['cy_fall',60],['cy_land',50],['c_over',30]];   // 공중 자전거 차기: 오른발 · 왼발 · 오른발
JW_SEQ.axe=[['ax_load',110],['ax_up',90],['ax_top',120],['ax_smear',35],['ax_hit',130],['ax_ft',140],['ax_rt',120],['c_over',70]];   // 도끼 차기: 수직으로 들었다 내리찍기
JW_SEQ.axe_air=[['axa_up',60],['axa_top',60],['axa_smear',30],['axa_hit',120],['axa_fall',110],['cy_land',90],['c_over',60]];   // 떠 있는 적: 뛰어올라 위에서 발뒤꿈치로 내리꽂기(준비 0.15초)
JW_SEQ.suplex=[['sx_reach',100],['sx_grab',150],['sx_lift',170],['sx_arch',110],['sx_slam',280],['sx_rise',160],['c_over',80]];   // 저먼 수플렉스: 잡기 → 젖히기 → 꽂기
JW_SEQ.renkan=[['rk_crouch',100],['rk_k1',90],['rk_sw',55],['rk_k2',110],['rk_fall',80],['rk_land',70],['c_over',40]];   // 연환퇴: 웅크림 → 앞다리 1타(살짝 띄움) → 공중에서 다리 바꿈 → 뒷다리 2타(높이 띄움) → 착지
JW_SEQ.tetsu=[['ts_set',150],['ts_step',60],['ts_hit',160],['ts_ft',230],['ts_rt',150],['c_over',80]];   // 철산고: 반 보 물러섬 → 폭발적 한 걸음 → 진각 · 등으로 들이받기 → 버팀 → 회복
JW_SEQ.skick=[['sk_crouch',130],['sk_jump',50],['sk_tuck',60],['sk_lean',50],['sk_kick',70],['sk_over',50],['sk_tuck2',55],['sk_fall',110],['sk_land',110],['c_over',80]];
JW_SEQ.scoop=[['dig',110], ...JW_SEQ.upper.slice(1)];
JW_SEQ.round_air=JW_SEQ.round.filter(([p])=>!['r_load','r_turn','r_spin1'].includes(p)); JW_SEQ.charge_air=JW_SEQ.charge.filter(([p])=>p!=='ch_load');   // 저글 마무리: 준비를 줄인 공중 버전   // 퍼올리기 어퍼 = 파고들기 + 어퍼컷
JW_SEQ.crumple=[['cr0',140],['cr1',280],['cr2',320],['cr3',220],['kd3',50],['kd4',50],['kd5',420]];
JW_SEQ.crumpleD=[...JW_SEQ.crumple.slice(0,-1),['kd5',700],['kd5',700,'blink']];   // 무기 전용 동작도 팔로우스루 · 회복 자세를 만든다
// 날아차기(레퍼런스 8프레임): 웅크림 → 도약(앞무릎) → 공중 웅크림 → 뻗어 차기 → 하강 → 착지. 객차 천장 손잡이 아래로 낮게 깔린다
Object.assign(POSES, {
  fk_ready: { r:2, b:[1,6],  h:[2,2],  t:1.6, ty:-.3,  aF:5.4, eF:.4,  aB:5.0, eB:.55, w:4, fF:[-.72,0], fB:[.78,0] },
  fk_jump:  { r:1, b:[1,2],  h:[1,0],  t:.8,  ty:-.2,  aF:5.8, eF:.38, aB:5.2, eB:.55, w:4, fF:[.45,-.85], fB:[-.3,-.05], air:7 },
  fk_tuck:  { r:0, b:[0,5],  h:[1,1],  t:1.2,  ty:-.2,  aF:5.8, eF:.42, aB:5.2, eB:.55, w:4, fF:[.45,-.95], fB:[.05,-.85], air:12 },
  fk_smear: { r:3, b:[-1,4], h:[-2,1], t:-2.0, ty:-.4,  aF:6.2, eF:.5,  aB:3.4, eB:.75, w:4, fF:[1.2,-1.0], fB:[0,-.7], air:11, strL:1.1, smear:'a', smearAt:'hip' },
  fk_hit:   { r:3, b:[-1,4], h:[-3,2], t:-3.4, ty:-.5,  aF:6.6, eF:.55, aB:2.6, eB:.85, w:4, fF:[1.5,-1.15], fB:[-.05,-.62], air:11, strL:1.2, impact:true, snap:true },
  fk_fall:  { r:2, b:[0,2],  h:[-1,0], t:-.8,  ty:.1,   aF:6.8, eF:.7,  aB:5.6, eB:.7,  w:4, fF:[.35,-.3], fB:[-.18,-.35], air:5 },
  fk_land:  { r:2, b:[0,8],  h:[1,2],  t:1.6, ty:0,    aF:5.2, eF:.55, aB:5.0, eB:.6,  w:4, fF:[-.58,0], fB:[.62,0] },
});
// 간판 기술 손 튜닝: 어퍼컷 깊은 웅크림 · 돌려차기 무릎 접기와 휘감는 팔로우스루 · 메치기 뒤 깊게 숙인 마무리
Object.assign(POSES, {
  lean0:    { r:-6, b:[0,1],    h:[-1,1], t:-.4,  ty:.4,   aF:2.5, eF:.95, aB:2.7, eB:.95, w:4, fF:[.32,0], fB:[-.06,0] },
  u_dip:    { r:-1, b:[-1,8.6], h:[1,3],  t:2.7,  ty:-.95, aF:1.6, eF:.55, aB:5.4, eB:.5,  w:4, fF:[-.62,0], fB:[.62,0] },
  r_chm:    { r:2,  b:[0,1],    h:[0,1],  t:.3,   ty:.25,  aF:5.6, eF:.45, aB:4.2, eB:.65, w:4, fF:[.35,-.78], fB:[.55,0] },
  r_turn:    { r:1,  b:[0,3],   h:[0,1],  t:.8,   ty:.2,  aF:6.0, eF:.42, aB:5.6, eB:.45, w:4, fF:[-.5,0], fB:[.55,0], spin:.38 },
  r_spin1:   { r:0,  b:[0,2],   h:[0,0],  t:.4,   ty:0,   aF:6.2, eF:.42, aB:5.8, eB:.45, w:4, fF:[-.45,0], fB:[.5,0], spin:.72 },
  r_spin2:   { r:2,  b:[0,3],   h:[-1,1], t:-.6,  ty:.2,  aF:6.6, eF:.6,  aB:4.2, eB:.7,  w:4, fF:[.3,-.82], fB:[-.75,-.55], air:9, spin:.86 },
  r_hit_ft:  { r:2,  b:[0,2],   h:[0,0],  t:.3,   ty:.3,  aF:6.8, eF:.7,  aB:6.0, eB:.7,  w:4, fF:[.4,-.38], fB:[.15,-.6], air:6, spin:1.04 },
  r_hit_rt:  { r:2,  b:[0,6],   h:[1,2],  t:1.3,  ty:.2,  aF:5.4, eF:.55, aB:5.2, eB:.6,  w:4, fF:[.28,0], fB:[-.25,-.35], spin:1 },
  gr_ft:    { r:7,  b:[1,7],    h:[3,2],  t:2.8,  ty:.3,   aF:4.0, eF:.95, aB:3.8, eB:.95, w:4, fF:[-.72,0], fB:[.76,0] },
  gr_rt:    { r:3,  b:[0,4],    h:[2,1],  t:1.8,  ty:.1,   aF:5.0, eF:.6,  aB:5.0, eB:.55, w:4, fF:[-.55,0], fB:[.58,0] },
});
if(POSES.u_hit_ft){ POSES.u_hit_ft.fF=[POSES.u_hit_ft.fF[0],-.12]; POSES.u_hit_ft.fB=[POSES.u_hit_ft.fB[0],-.1]; POSES.u_hit_ft.air=Math.max(3,POSES.u_hit_ft.air||0); }
// 잔상 길이도 무게대로: 무거울수록 길게, 가벼울수록 짧게
if(POSES.u_smear) POSES.u_smear.strF=1.6; if(POSES.h_smear) POSES.h_smear.strF=1.32; if(POSES.j_smear) POSES.j_smear.strB=1.15; if(POSES.c_smear) POSES.c_smear.strF=1.4;
// 적 공격 무게: 무거울수록 준비 동작을 길게 보여 줘서 읽고 대응할 시간을 준다(잔상은 그대로 빠르게)
const FOE_W={ jab:'L', throw:'L', hook:'M', kick:'M', hbutt:'M', bat:'H', charge:'H', round:'H', upper:'H', fkick:'H' };
const FOE_TELL={ L:1, M:1.35, H:1.8 };
// 저스트 탭: 적 공격의 타격 순간(큐 자세)까지 남은 게임 시간 — 지금 자세의 남은 프레임 + 큐 앞까지 남은 자세들(예고 배율 포함)
function timeToCue(c){ const A=c&&c.action; if(!A || A.fired || !A.cue) return null; const seq=seqOf(c.anim,c), i=c.si; if(!seq || !seq[i]) return null; if(seq[i][0]===A.cue) return 0;
  let t=Math.max(0,c.hold||0)/animFps; for(let k=i+1;k<seq.length;k++){ const [pose,n]=seq[k]; if(pose===A.cue) return t; let nn=n; if(c.e && FOE_W[c.anim] && !(POSES[pose]&&POSES[pose].smear)) nn=n*FOE_TELL[FOE_W[c.anim]]; t+=Math.max(1,Math.round(nn*animFps/1000))/animFps; } return null; }   /* 실제 진행처럼 자세마다 프레임 단위로 반올림 */
const JUST_W=()=>.16*(1+pv('ear',.4,.1));
const FOE_TELLX={ L:.26, M:.3, H:.34 };   // 첫 준비 자세에 더하는 시간(초) — 사람이 보고 누를 수 있게(공격 빈도는 쿨다운에서 그만큼 빼서 그대로) · 직접 조작 중일 때만   // 타격 직전 0.16초(보청기 아이템이 있으면 조금 넓게)
// 시작부터 적중 자세까지 걸리는 시간(초)
const atkStartup=a=>{ const S=JW_SEQ[a], c=JW_CUE[a]; if(!S||!c) return 0; let t=0; for(const [p,ms] of S){ if(p===c) break; t+=ms; } return t/1000; };
const JW_CUE={ renkan:'rk_k1', tetsu:'ts_hit', cycle:'cy_k1', axe:'ax_hit', axe_air:'axa_hit', suplex:'sx_grab', fkick:'fk_hit', uthrust:'ut_hit', swat:'np_hit', hm_swing:'hm_hit', hm_back:'hm_bhit', hm_up:'hm_uhit', hm_down:'hm_dhit', bkick:'bk_hit', bfist:'bf_hit', jab:'j_hit', cross:'c_hit', hook:'h_hit', upper:'u_hit', kick:'k_hit', round:'r_hit', bat:'batS', hbutt:'hb', elbow:'e_hit', knee:'n_hit', sweep:'sw_hit', charge:'ch_hit', throw:'gr_hold', stomp:'st_hit' };
const cueFor=(c,anim,fb)=> (c.d.jw && JW_CUE[anim]) || fb;
JW_CUE.scoop=JW_CUE.upper; ATK_FEEL.scoop={...ATK_FEEL.upper};
JW_CUE.skick='sk_kick'; ATK_FEEL.skick={ w:'H', load:'sk_crouch', hit:'sk_kick', hs:1.5, shake:2.4, zoom:.08, step:0, dust:1 };
JW_CUE.round_air=JW_CUE.round; JW_CUE.charge_air=JW_CUE.charge; ATK_FEEL.round_air={...ATK_FEEL.round}; ATK_FEEL.charge_air={...ATK_FEEL.charge};
