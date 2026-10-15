/* =========================================================
   4. 리그 · 동작 문법 · 전투
   ========================================================= */
// 각도: 0=아래, 4=앞, 8=위, 12=뒤 (22.5° 단위, 0.5 단위까지 = 11.25°)
// r=몸 전체 전진(대시) · b=골반 오프셋 · h=머리 추가 오프셋 · t=몸 기울기(+는 앞으로 숙임)
// fF·fB=앞발·뒷발 위치 [앞뒤, 높이]. 단위는 다리 길이(1 = 다리 한 길이), 높이 0 = 바닥. 무릎은 IK로 자동으로 굽는다
const POSES = {
  idle0:  { r:0,  b:[0,0],  h:[0,0],  t:0,   aF:0,  aB:4,  w:4,   fF:[.12,0],  fB:[-.12,0] },
  idle1:  { r:0,  b:[0,1],  h:[0,0],  t:0,   aF:0,  aB:4,  w:4,   fF:[.12,0],  fB:[-.12,0] },
  windup: { r:-3, b:[-1,2], h:[0,-1], t:-.5, aF:10, aB:2,  w:9,   fF:[.25,0],  fB:[-.3,0] },
  strike: { r:22, b:[2,2],  h:[1,0],  t:1,   aF:4,  aB:4,  w:5,   fF:[.75,0],  fB:[-.65,0], smear:'a', snap:true },
  follow: { r:20, b:[1,2],  h:[0,0],  t:1,   aF:3,  aB:3,  w:3,   fF:[.7,0],   fB:[-.55,0], smear:'b' },
  recover:{ r:8,  b:[0,1],  h:[0,0],  t:.5,  aF:2,  aB:3,  w:5,   fF:[.3,0],   fB:[-.2,0] },
  hit:    { r:-4, b:[-2,0], h:[-1,0], t:-1,  aF:15, aB:1,  w:7,   fF:[.15,-.15],fB:[-.35,0], snap:true },
  walk0:  { r:0,  b:[0,1],  h:[0,0],  t:.5,  aF:15, aB:3,  w:4,   fF:[.45,0],  fB:[-.45,0] },
  walk1:  { r:0,  b:[0,-1], h:[0,0],  t:.5,  aF:0,  aB:3.5,w:4,   fF:[.05,0],  fB:[-.1,-.3] },
  walk2:  { r:0,  b:[0,1],  h:[0,0],  t:.5,  aF:1,  aB:2.5,w:4.5, fF:[-.45,0], fB:[.45,0] },
  walk3:  { r:0,  b:[0,-1], h:[0,0],  t:.5,  aF:0,  aB:3.5,w:4,   fF:[-.1,-.3],fB:[.05,0] },
  block:  { r:-2, b:[-1,2], h:[-1,0], t:-.5, aF:13, aB:6,  w:10.5,fF:[.35,0],  fB:[-.4,0] },
  cast0:  { r:0,  b:[0,2],  h:[0,0],  t:-.5, aF:9,  aB:7,  w:8,   fF:[.2,0],   fB:[-.25,0] },
  cast1:  { r:0,  b:[0,-1], h:[0,-1], t:-1,  aF:8,  aB:6,  w:8,   fF:[.1,0],   fB:[-.1,0], charge:true },
  cast2:  { r:4,  b:[2,2],  h:[1,0],  t:1,   aF:4,  aB:3,  w:4,   fF:[.55,0],  fB:[-.45,0], snap:true },
  death0: { r:-6, b:[-2,0], h:[-1,0], t:-1.5,aF:14, aB:1,  w:9,   fF:[.1,-.1], fB:[-.3,0], snap:true },
  death1: { r:-6, b:[-1,5], h:[0,0],  t:1,   aF:2,  aB:1,  w:5,   fF:[.35,0],  fB:[-.75,0] },
  death2: { r:-6, b:[1,9],  h:[1,1],  t:3,   aF:3,  aB:2,  w:4,   fF:[-.6,0],  fB:[-.9,0] },
  // MMA: e = 팔을 뻗은 정도(가드는 0.4 안팎, 펀치는 1). impact = 이 포즈에 들어서는 순간 맞는다
  m_idle0: { r:0,  b:[0,1],  h:[0,0],  t:.5,  aF:4.9, eF:.46, aB:4.6, eB:.55, w:4, fF:[.34,0], fB:[-.34,0] },
  m_idle1: { r:0,  b:[0,2],  h:[0,0],  t:.5,  aF:4.8, eF:.46, aB:4.5, eB:.55, w:4, fF:[.34,0], fB:[-.34,0] },
  m_jabW:  { tv:1, r:1,  b:[1,1],  h:[0,0],  t:.8,  aF:5.0, eF:.5,  aB:4.6, eB:.55, w:4, fF:[.38,0], fB:[-.3,0] },
  m_jab:   { tv:1, smear:'b', r:9,  b:[3,2],  h:[1,0],  t:1.2, aF:4.4, eF:1,   aB:4.6, eB:.55, w:4, fF:[.52,0], fB:[-.3,0], impact:true, snap:true },
  m_crossW:{ r:-1, b:[-1,2], h:[0,0],  t:.2,  aF:6.5, eF:.45, aB:5.4, eB:.4,  w:4, fF:[.3,0],  fB:[-.38,0] },
  m_cross: { tv:2, smear:'b', r:11, b:[4,2],  h:[1,0],  t:.9,  aF:6.6, eF:.4,  aB:4.1, eB:1,   w:4, fF:[.52,0], fB:[-.2,-.05], impact:true, snap:true, frontB:true },
  m_kickW: { tv:1, r:-2, b:[-1,1], h:[0,0],  t:-.3, aF:5.0, eF:.46, aB:4.6, eB:.55,  w:4, fF:[.22,-.12], fB:[-.36,0] },
  m_kick:  { tv:1, r:6,  b:[-1,0], h:[-1,0], t:-.6, aF:6.8, eF:.45, aB:5.2, eB:.45, w:4, fF:[1.05,-.5], fB:[-.3,0], impact:true, snap:true },
  // --- 존 윅 리그(밀리초 동작). F=가까운 쪽(뒷손·뒷다리) B=먼 쪽(앞손·앞다리). ty=몸통 비틀기(+면 가까운 어깨가 앞으로) str=스미어 때 팔 늘림 ---
  st0:     { r:0, b:[0,3.0], h:[1,1.0], t:1.6, ty:-.45, aF:5.7, eF:.36, aB:5.2, eB:.6,  w:4, fF:[-.48,0], fB:[.55,0] },
  gx_rel:  { r:0, b:[0,2.0], h:[0,0],   t:.5,  ty:0,    aF:1.3, eF:.25, aB:1.1, eB:.25, w:4, fF:[-.3,0], fB:[.32,0] },     // 스킨 제스처: 힘 뺀 선 자세
  gx_b1:   { r:0, b:[0,2.0], h:[0,1],   t:.7,  ty:.1,   aF:2.9, eF:.95, aB:2.6, eB:.95, w:4, fF:[-.3,0], fB:[.32,0] },     // 단추 잠그기
  gx_b2:   { r:0, b:[0,2.2], h:[0,2],   t:.8,  ty:-.1,  aF:3.1, eF:1.0, aB:2.8, eB:1.0, w:4, fF:[-.3,0], fB:[.32,0] },
  gx_c1:   { r:0, b:[0,2.0], h:[1,2],   t:.8,  ty:.35,  aF:3.4, eF:1.05,aB:3.6, eB:.7,  w:4, fF:[-.3,0], fB:[.32,0] },     // 커프스 매만지기
  gx_c2:   { r:0, b:[0,2.2], h:[1,3],   t:.9,  ty:.5,   aF:3.6, eF:1.15,aB:3.9, eB:.75, w:4, fF:[-.3,0], fB:[.32,0] },
  gx_h1:   { r:0, b:[0,2.0], h:[1,1],   t:.6,  ty:-.1,  aF:6.3, eF:1.05,aB:1.2, eB:.3,  w:4, fF:[-.3,0], fB:[.32,0] },     // 중절모 챙 잡기
  gx_h2:   { r:0, b:[0,2.4], h:[1,3],   t:1.0, ty:-.1,  aF:6.6, eF:1.15,aB:1.1, eB:.3,  w:4, fF:[-.3,0], fB:[.32,0] },     // 챙 내리며 고개 숙이기
  gx_t1:   { r:0, b:[0,2.0], h:[0,2],   t:.6,  ty:.1,   aF:4.4, eF:1.25,aB:1.2, eB:.3,  w:4, fF:[-.3,0], fB:[.32,0] },     // 넥타이 매만지기
  gx_t2:   { r:0, b:[0,2.0], h:[0,1],   t:.6,  ty:.05,  aF:3.6, eF:1.2, aB:1.2, eB:.3,  w:4, fF:[-.3,0], fB:[.32,0] },
  st1:     { r:0, b:[0,3.6], h:[1,1.3], t:1.7, ty:-.47, aF:5.65,eF:.36, aB:5.15,eB:.6,  w:4, fF:[-.48,0], fB:[.55,0] },
  st2:     { r:0, b:[0,4.2], h:[1,1.6], t:1.8, ty:-.49, aF:5.6, eF:.37, aB:5.1, eB:.61, w:4, fF:[-.48,0], fB:[.55,0] },
  st3:     { r:0, b:[0,4.8], h:[1,2.0], t:1.9, ty:-.5,  aF:5.5, eF:.38, aB:5.0, eB:.62, w:4, fF:[-.48,0], fB:[.55,0] },
  c_load:  { r:0, b:[0,2.5], h:[1,0], t:1.3, ty:-.55, aF:4.6, eF:.5,  aB:4.9, eB:.55, w:4, fF:[-.5,0], fB:[.55,0] },
  c_pull:  { r:-1,b:[0,3.0], h:[0,1], t:1.2, ty:-.75, aF:4.0, eF:.42, aB:5.2, eB:.5,  w:4, fF:[-.5,0], fB:[.55,0] },
  c_smear:  { r:6, b:[2,3.5], h:[3,1], t:2.1, ty:.6,  aF:4.1, eF:1, strF:1.4, aB:5.8, eB:.36, w:4, fF:[-.78,0], fB:[.66,-.06], smear:'b' },
  c_hit:    { r:7, b:[2,3.5], h:[3,1], t:2.3, ty:.72, aF:4.0, eF:1,  strF:1.1, aB:5.8, eB:.36, w:4, fF:[-.8,0], fB:[.68,-.08], impact:true, snap:true },
  c_fol:   { r:7, b:[1,3.6], h:[3,1.2],t:2.1,ty:.5,  aF:4.2, eF:.95, aB:5.8, eB:.36, w:4, fF:[-.78,0], fB:[.62,0] },
  c_rec:   { r:3, b:[0,3.2], h:[2,1], t:1.8, ty:.1,  aF:5.0, eF:.55, aB:5.4, eB:.45, w:4, fF:[-.6,0], fB:[.58,0] },
  c_over:  { r:0, b:[0,3.4], h:[1,1.2],t:1.7, ty:-.6, aF:5.8, eF:.34, aB:5.1, eB:.6,  w:4, fF:[-.48,0], fB:[.55,0] },
  j_load:  { r:0, b:[0,3.0], h:[1,1], t:1.5, ty:-.45, aF:5.7, eF:.36, aB:4.8, eB:.5,  w:4, fF:[-.5,0], fB:[.6,0] },
  j_smear: { r:4, b:[1,3.0], h:[2,1], t:1.7, ty:-.7,  aF:5.7, eF:.36, aB:4.2, eB:1, strB:1.3, w:4, fF:[-.5,0], fB:[.7,0], smear:'b' },
  j_hit:   { r:5, b:[1,3.0], h:[2,1], t:1.7, ty:-.72, aF:5.7, eF:.36, aB:4.15,eB:1, w:4, fF:[-.5,0], fB:[.72,0], impact:true, snap:true },
  j_rec:   { r:2, b:[0,3.2], h:[1,1], t:1.6, ty:-.5,  aF:5.7, eF:.36, aB:4.8, eB:.55, w:4, fF:[-.5,0], fB:[.6,0] },
  h_load:   { r:-1,b:[0,4],  h:[1,2], t:1.4, ty:.7,   aF:5.9, eF:.34, aB:5.6, eB:.45, w:4, fF:[-.5,0], fB:[.55,0] },
  h_smear:  { r:4, b:[1,4],  h:[0,2], t:1.6, ty:-.4,  aF:5.9, eF:.34, aB:4.6, eB:.5,  upB:true, strB:1.12, w:4, fF:[-.62,0], fB:[.6,0], smear:'b' },
  h_hit:    { r:5, b:[1,4],  h:[-1,2],t:1.7, ty:-1.35, aF:5.9, eF:.34, aB:4.2, eB:.5,  upB:true, w:4, fF:[-.66,0], fB:[.6,0], impact:true, snap:true },
  u_load:  { r:0, b:[0,7.0], h:[1,2], t:2.2, ty:-.5,  aF:2.2, eF:.6,  aB:5.2, eB:.5,  w:4, fF:[-.55,0], fB:[.55,0] },
  u_smear: { r:5, b:[1,1.0], h:[2,0], t:.6,  ty:.4,   aF:7.0, eF:.85, strF:1.2, aB:5.6, eB:.4, w:4, fF:[-.5,0], fB:[.62,0], smear:'b' },
  u_hit:   { r:6, b:[1,0.0], h:[2,-1],t:.2,  ty:.5,   aF:7.6, eF:.8,  aB:5.6, eB:.4,  w:4, fF:[-.45,0], fB:[.62,0], air:2, impact:true, snap:true },
  k_load:  { r:0, b:[0,1.5], h:[0,1], t:.6,  ty:-.3,  aF:5.6, eF:.38, aB:5.2, eB:.55, w:4, fF:[-.45,0], fB:[.4,-.62] },
  k_smear: { r:3, b:[-1,1], h:[-1,1], t:-.2, ty:-.4,  aF:5.6, eF:.38, aB:5.0, eB:.55, w:4, fF:[-.45,0], fB:[.98,-.55], smear:'a', smearAt:'hip' },
  k_hit:   { r:4, b:[-1,1], h:[-1,1], t:-.3, ty:-.4,  aF:5.6, eF:.38, aB:5.0, eB:.55, w:4, fF:[-.42,0], fB:[1.08,-.6], impact:true, snap:true },
  k_rec:   { r:2, b:[0,2],  h:[0,1], t:.6,  ty:-.4,  aF:5.6, eF:.38, aB:5.2, eB:.55, w:4, fF:[-.45,0], fB:[.5,-.4] },
  r_load:   { r:2, b:[1,6], h:[2,2], t:1.6, ty:-.3, aF:5.6, eF:.42, aB:5.2, eB:.5, w:4, fF:[-.72,0], fB:[.78,0], spin:.03 },
  r_smear:  { r:4, b:[-1,2], h:[-2,0], t:-1.6, ty:.4, aF:6.3, eF:.55, aB:3.0, eB:.8, w:4, fF:[1.1,-1.05], fB:[.02,-.78], strL:1.1, air:11, spin:.92, smear:'a', smearAt:'hip' },
  r_hit:    { r:6, b:[-1,2], h:[-3,1], t:-2.3, ty:.6, aF:6.5, eF:.55, aB:2.4, eB:.85, w:4, fF:[1.38,-1.12], fB:[.05,-.8], strL:1.15, air:11, spin:1, impact:true, snap:true },
  r_rec:   { r:3, b:[0,2],  h:[0,1], t:.4,  ty:.2,   aF:5.6, eF:.4,  aB:4.6, eB:.6,  w:4, fF:[.3,-.4], fB:[.52,0] },
  // 피격 반응: 공격마다 몸이 받는 방향 · 부위가 다르다
  rc0:     { r:-6, b:[-1,2], h:[-4,-2],t:-1.8,ty:.6, aF:6.8, eF:.85, aB:7.4, eB:.9,  w:4, fF:[-.45,-.12], fB:[.5,0], snap:true },   // 크로스: 고개 꺾이고 팔 벌어짐
  rc1:     { r:-10,b:[-1,4], h:[-2,0], t:-.6, ty:.3, aF:5.0, eF:.7,  aB:5.6, eB:.7,  w:4, fF:[-.75,0], fB:[.3,-.15] },            //  뒤로 휘청
  rh0:     { r:-3, b:[0,2],  h:[-2,1], t:.9,  ty:-1.3,aF:2.2, eF:.9,  aB:6.2, eB:.75, w:4, fF:[-.5,0], fB:[.5,0], snap:true },     // 훅: 고개 · 몸통이 옆으로
  rh1:     { r:-5, b:[0,6],  h:[0,2],  t:1.4, ty:-.8, aF:2.8, eF:.7,  aB:4.4, eB:.7,  w:4, fF:[-.55,0], fB:[.42,0] },             //  무릎 꺾임
  ru0:     { r:-2, b:[0,-2], h:[-3,-4],t:-2.4,ty:.2, aF:7.6, eF:.9,  aB:7.0, eB:.9,  w:4, fF:[-.3,-.2], fB:[.3,-.25], air:4, snap:true }, // 어퍼컷: 턱 들림 · 까치발
  rk0:     { r:-1, b:[0,4],  h:[2,3],  t:3.4, ty:.1, aF:2.2, eF:.38, aB:2.4, eB:.38, w:4, fF:[-.2,-.25], fB:[.25,-.3], air:4, snap:true }, // 니킥: 배 움켜쥐고 접히며 들림
  rk1:     { r:-3, b:[0,8],  h:[2,3],  t:2.9, ty:.1, aF:2.6, eF:.4,  aB:2.8, eB:.4,  w:4, fF:[-.45,0], fB:[.4,0] },
  rk2:     { r:-5, b:[0,6],  h:[1,2],  t:2.0, ty:0,  aF:3.0, eF:.5,  aB:3.2, eB:.5,  w:4, fF:[-.6,0], fB:[.35,0] },
  rkc0:    { r:-8, b:[0,3],  h:[2,2],  t:2.6, ty:0,  aF:2.0, eF:.6,  aB:5.8, eB:.7,  w:4, fF:[.25,-.2], fB:[.5,-.1], air:3, snap:true }, // 앞차기: 배 맞고 접혀 밀림
  rs0:     { r:-6, b:[0,2],  h:[-2,0], t:.4,  ty:1.9, aF:6.5, eF:.95, aB:1.5, eB:.95, w:4, fF:[-.4,0], fB:[.55,-.1], snap:true },   // 돌려차기 · 가방: 몸이 돌아감
  rs1:     { r:-10,b:[0,6],  h:[-1,1], t:-1.8,ty:2.8, aF:7.0, eF:.9,  aB:3.0, eB:.9,  w:4, fF:[.3,-.3], fB:[.6,-.2], air:6 },
  rsw0:    { r:-2, b:[0,4],  h:[-2,-1],t:-2.6,ty:.2, aF:7.6, eF:.9,  aB:8.4, eB:.9,  w:4, fF:[1.0,-.7], fB:[.85,-.5], air:9, snap:true }, // 다리걸기: 발이 앞으로 들림
  rsw1:    { r:-4, b:[0,8],  h:[-1,0], t:-5.2,ty:.1, aF:6.4, eF:.9,  aB:7.0, eB:.9,  w:4, fF:[1.0,-.4], fB:[.9,-.3], air:5 },
  slm0:    { r:-13,b:[0,14], h:[0,-1], t:-6.2,ty:.1, aF:6.0, eF:.95, aB:6.8, eB:.95, w:4, fF:[.8,-.4], fB:[.7,-.3], air:5, snap:true },  // 메치기: 등으로 꽂혀 튀어 오름
  stp0:    { r:-13,b:[0,15], h:[1,1],  t:-5.8,ty:.1, aF:2.2, eF:.45, aB:2.6, eB:.45, w:4, fF:[.5,-.45], fB:[.4,-.4], snap:true },   // 밟힘: 누운 채 웅크림
  dz0:     { r:-1, b:[0,4],  h:[1,3],  t:1.0, ty:.5, aF:1.4, eF:.9,  aB:1.0, eB:.9,  w:4, fF:[-.5,0], fB:[.42,0] },               // 경직: 비틀비틀
  dz1:     { r:1,  b:[0,5],  h:[-1,3], t:.6,  ty:-.3, aF:1.0, eF:.9,  aB:1.6, eB:.9,  w:4, fF:[-.48,0], fB:[.46,0] },
  dfw0:    { r:0,  b:[0,13], h:[1,3],  t:2.6, ty:0,  aF:2.0, eF:.6,  aB:2.2, eB:.6,  w:4, fF:[-.2,0], fB:[-.35,0] },             // 무릎 꿇고
  dfw1:    { r:4,  b:[0,17], h:[0,1],  t:6.6, ty:.1, aF:7.6, eF:.9,  aB:7.2, eB:.9,  w:4, fF:[-.9,0], fB:[-.8,0] },              //  앞으로 엎어짐
  hl0:     { r:2,  b:[0,2],  h:[1,0],  t:1.4, ty:.3, aF:4.6, eF:.75, aB:4.9, eB:.75, w:4, fF:[.1,-.12], fB:[.55,0] },            // 잡힘: 끌려오며 팔을 붙잡음
  hl1:     { r:0,  b:[-1,2], h:[-2,0], t:-4.2,ty:.3, aF:7.4, eF:.8,  aB:5.6, eB:.7,  w:4, fF:[.7,-.8], fB:[.3,-.4], air:13 },       // 들림: 팔다리 버둥 A
  hl1b:    { r:0,  b:[-1,2], h:[-2,1], t:-4.0,ty:.3, aF:5.4, eF:.7,  aB:7.8, eB:.8,  w:4, fF:[.4,-.5], fB:[.75,-.9], air:13 },      //       버둥 B
  hl2:     { r:0,  b:[-1,4], h:[-1,0], t:-6.0,ty:.2, aF:8.4, eF:.95, aB:8.0, eB:.95, w:4, fF:[.9,-.6], fB:[.8,-.5], air:6 },        // 내던져짐: 거꾸로 꺾임
  bk_load: { r:2, b:[0,3],  h:[-2,1], t:2.4, ty:-.6, aF:4.6, eF:.7,  aB:5.0, eB:.7,  w:4, fF:[.1,0], fB:[-.2,-.55] },                 // 뒤차기: 숙이며 뒷다리 접기 · 어깨 너머로 뒤를 본다
  bk_hit:  { r:4, b:[0,4],  h:[-3,2], t:3.0, ty:-.4, aF:4.2, eF:.9,  aB:3.6, eB:.8,  w:4, fF:[.15,0], fB:[-1.28,-.52], impact:true, snap:true }, //  뒷다리를 뒤로 곧게
  bk_rec:  { r:2, b:[0,3],  h:[-1,1], t:1.8, ty:-.3, aF:4.8, eF:.7,  aB:5.0, eB:.7,  w:4, fF:[0,0], fB:[-.5,-.2] },
  bf_load: { r:0, b:[0,3],  h:[0,1],  t:.8,  ty:1.6, aF:4.8, eF:.5,  aB:6.4, eB:.45, w:4, fF:[-.3,0], fB:[.4,0] },                   // 백피스트: 몸통을 비틀어 뒤쪽 팔을 가슴 앞으로 감는다
  bf_hit:  { r:-3,b:[0,2],  h:[-2,0], t:-.6, ty:2.6, aF:4.4, eF:.6,  aB:12.2,eB:1.0, w:4, fF:[-.35,0], fB:[.45,0], impact:true, snap:true }, //  등 뒤로 휘둘러 주먹 등으로
  bf_rec:  { r:-1,b:[0,3],  h:[-1,1], t:.4,  ty:1.2, aF:4.6, eF:.6,  aB:9.0, eB:.6,  w:4, fF:[-.3,0], fB:[.42,0] },
  hm_wind: { r:2, b:[-1,1], h:[1,0], t:.9, ty:.4, aF:6.6, eF:.45, aB:3.2, eB:.5, w:7, fF:[.55,0], fB:[-.5,0] },                                // 장도리: 어깨 뒤로 들었다가
  hm_hit:  { r:-3, b:[1,2], h:[-1,1], t:-1.3, ty:.5, aF:3.6, eF:1.0, aB:2.4, eB:.6, w:4, fF:[.75,0], fB:[-.55,0], snap:true },                   //  수평으로 크게
  hm_rec:  { r:-1, b:[1,2], h:[0,1], t:-.9, aF:2.2, eF:.85, aB:2.8, eB:.5, w:2.5, fF:[.6,0], fB:[-.5,0] },
  hm_bload:{ r:-2, b:[1,1], h:[-1,0], t:-.9, ty:.3, aF:4.8, eF:.95, aB:2.6, eB:.5, w:6, fF:[.7,0], fB:[-.55,0] },                              // 되돌려 치기: 앞쪽 높이에서
  hm_bhit: { r:2, b:[0,2], h:[1,1], t:1.1, ty:.4, aF:2.8, eF:.55, aB:3.2, eB:.5, w:1, fF:[.55,0], fB:[-.6,0], snap:true },                         //  몸 쪽으로 가로질러(오른→왼)
  hm_uload:{ r:3, b:[0,4], h:[1,1], t:.6, ty:.6, aF:1.0, eF:.8, aB:3, eB:.5, w:-1, fF:[.6,0], fB:[-.6,0] },                                      // 올려치기: 낮게 웅크렸다가
  hm_uhit: { r:-4, b:[0,-1], h:[-1,-1], t:-1, aF:6.8, eF:.95, aB:3, eB:.6, w:8, fF:[.5,-.1], fB:[-.5,0], snap:true },                            //  위로
  hm_dload:{ r:3, b:[0,0], h:[0,-1], t:.3, aF:7.8, eF:.7, aB:7.2, eB:.7, w:8, fF:[.5,0], fB:[-.5,0] },                                            // 내려찍기: 두 손으로 높이 들어
  hm_dhit: { r:-6, b:[1,6], h:[-1,2], t:-1.2, ty:.8, aF:2.4, eF:1, aB:2.6, eB:.9, w:2, fF:[.8,0], fB:[-.6,0], snap:true },                       //  바닥까지
  ps0:     { r:0, b:[0,2], h:[0,0], t:.4, ty:.2, aF:7.6, eF:.9, aB:7.0, eB:.75, w:4, fF:[.2,-.15], fB:[-.25,0] },                         // 기둥을 잡는다
  ps1:     { r:-2, b:[0,0], h:[-1,0], t:-1.2, ty:.6, aF:7.8, eF:1.0, aB:7.2, eB:.85, w:4, fF:[1.25,-.6], fB:[1.0,-.42], air:10, snap:true }, //  몸을 띄워 다리를 휘두른다
  ps2:     { r:-2, b:[0,0], h:[-1,0], t:-1.2, ty:.6, aF:7.8, eF:1.0, aB:7.2, eB:.85, w:4, fF:[1.25,-.6], fB:[1.0,-.42], air:10, snap:true }, //  반 바퀴 돌아 뒤쪽도
  ps3:     { r:0, b:[0,4], h:[0,1], t:.8, aF:5, eF:.6, aB:4.6, eB:.6, w:4, fF:[-.4,0], fB:[.4,0] },
  hk0:     { r:0, b:[0,0], h:[0,-1], t:-.4, ty:0, aF:8.0, eF:.95, aB:7.8, eB:.95, w:4, fF:[.35,-.55], fB:[.2,-.5], air:8, snap:true },          // 손잡이에 매달린다
  hk1:     { r:2, b:[0,0], h:[-1,0], t:-1.6, ty:0, aF:8.2, eF:1.0, aB:7.9, eB:1.0, w:4, fF:[1.3,-.6], fB:[1.2,-.5], air:9, snap:true },         //  두 발로 찬다
  hk2:     { r:0, b:[0,3], h:[0,1], t:.6, aF:5.4, eF:.6, aB:5.0, eB:.6, w:4, fF:[-.3,0], fB:[.35,0] },
  gt0:     { r:0, b:[0,1], h:[1,1], t:.6, ty:.4, aF:3.4, eF:.55, aB:2.6, eB:.5, w:2.2, fF:[-.35,0], fB:[.3,0] },                                   // 기타 연주
  gt1:     { r:0, b:[0,1], h:[1,1], t:.6, ty:.4, aF:3.0, eF:.5, aB:2.6, eB:.5, w:2.2, fF:[-.35,0], fB:[.3,0] },
  pr0:     { r:-2, b:[0,3], h:[-1,1], t:.2, ty:.3, aF:6.4, eF:.32, aB:5.4, eB:.42, w:4, fF:[-.55,0], fB:[.45,0], snap:true },        // 막기: 앞팔을 세워 쳐낸다
  ev0:     { r:-9, b:[0,4], h:[-2,0], t:-1.2,ty:-.8, aF:5.2, eF:.6, aB:5.8, eB:.6, w:4, fF:[-.85,-.12], fB:[.15,0], snap:true },   // 뒤로 빠지며 피함
  dk0:     { r:-1,b:[0,6],  h:[1,2], t:1.6, ty:-.3, aF:6.6, eF:.5,  aB:6.9, eB:.5,  w:4, fF:[-.42,0], fB:[.5,0], snap:true },
  dk1:     { r:-2,b:[0,13], h:[2,3], t:2.5, ty:.2,  aF:7.4, eF:.42, aB:7.7, eB:.45, w:4, fF:[-.58,0], fB:[.64,0] },
  dk2:     { r:-1,b:[0,6],  h:[1,1], t:1.5, ty:0,   aF:5.6, eF:.55, aB:5.2, eB:.6,  w:4, fF:[-.45,0], fB:[.52,0] },
  e_load:  { r:0, b:[0,3],  h:[1,1], t:1.4, ty:-.7, aF:6.4, eF:.34, aB:5.2, eB:.55, w:4, fF:[-.5,0], fB:[.55,0] },
  e_hit:   { r:5, b:[1,3.5],h:[2,1], t:2.0, ty:.75, aF:4.8, eF:.3,  aB:5.8, eB:.36, w:4, fF:[-.65,0], fB:[.6,0], impact:true, snap:true },
  n_load:  { r:2, b:[0,2.5],h:[1,1], t:1.1, ty:-.2, aF:4.3, eF:.85, aB:4.1, eB:.85, w:4, fF:[-.45,0], fB:[.5,0] },
  n_hit:   { r:6, b:[1,-.5],h:[1,2], t:1.4, ty:.3,  aF:3.0, eF:.6,  aB:2.8, eB:.6,  w:4, fF:[.55,-.82], fB:[.3,0], impact:true, snap:true },
  n_rec:   { r:3, b:[0,2],  h:[1,1], t:1.2, ty:0,   aF:4.6, eF:.6,  aB:4.6, eB:.6,  w:4, fF:[.1,-.25], fB:[.4,0] },
  sw_load: { r:0, b:[0,8.5],h:[1,2], t:1.7, ty:-.5, aF:3.0, eF:.6,  aB:2.6, eB:.6,  w:4, fF:[-.35,0], fB:[.5,0] },
  sw_hit:  { r:3, b:[-2,11],h:[0,2], t:.6,  ty:.6,  aF:1.2, eF:.9,  aB:7.0, eB:.6,  w:4, fF:[1.3,-.04], fB:[.15,0], impact:true, snap:true, smear:'a', smearAt:'hip' },
  sw_rec:  { r:2, b:[0,7],  h:[1,2], t:1.4, ty:0,   aF:2.8, eF:.6,  aB:4.0, eB:.6,  w:4, fF:[.45,0], fB:[.3,0] },
  ch_load: { r:-2,b:[0,4],  h:[1,1], t:2.3, ty:.85, aF:3.6, eF:.5,  aB:4.6, eB:.4,  w:4, fF:[-.6,0], fB:[.4,0] },
  ch_run:  { r:6, b:[0,3],  h:[2,1], t:2.6, ty:1.0, aF:3.4, eF:.5,  aB:4.6, eB:.4,  w:4, fF:[-.85,-.15], fB:[.62,0], smear:'b' },
  ch_hit:  { r:9, b:[1,3],  h:[2,1], t:2.6, ty:1.05,aF:3.4, eF:.5,  aB:4.6, eB:.4,  w:4, fF:[-.8,0], fB:[.66,0], impact:true, snap:true },
  gr_reach:{ r:3, b:[0,2.5],h:[2,1], t:1.6, ty:0,   aF:4.2, eF:.95, aB:4.4, eB:.95, w:4, fF:[-.5,0], fB:[.6,0] },
  gr_hold: { r:1, b:[0,2],  h:[1,1], t:.8,  ty:0,   aF:4.6, eF:.7,  aB:4.8, eB:.7,  w:4, fF:[-.45,0], fB:[.5,0], snap:true },
  gr_lift: { r:0, b:[0,1],  h:[0,0], t:-.6, ty:0,   aF:7.6, eF:.85, aB:7.3, eB:.85, w:4, fF:[-.42,0], fB:[.45,0] },
  gr_throw:{ r:4, b:[0,4],  h:[2,1], t:2.2, ty:.3,  aF:4.8, eF:.95, aB:4.6, eB:.95, w:4, fF:[-.6,0], fB:[.6,0], impact:true, snap:true },
  st_load: { r:1, b:[0,0],  h:[1,1], t:.9,  ty:-.3, aF:5.6, eF:.4,  aB:5.0, eB:.55, w:4, fF:[.35,-.75], fB:[-.2,0] },
  st_hit:  { r:3, b:[0,4],  h:[2,2], t:1.6, ty:-.3, aF:5.4, eF:.4,  aB:4.8, eB:.55, w:4, fF:[.5,0], fB:[-.25,0], impact:true, snap:true },
  hh0:     { r:-3,b:[-1,2], h:[-3,-1],t:.3, ty:.4,   aF:5.2, eF:.5,  aB:4.4, eB:.6,  w:4, fF:[-.55,0], fB:[.45,0], snap:true },
  hh1:     { r:-4,b:[-1,3], h:[-3,-1],t:.1, ty:.45,  aF:5.0, eF:.5,  aB:4.2, eB:.6,  w:4, fF:[-.58,0], fB:[.42,0] },
  hbd0:    { r:-2,b:[0,4],  h:[1,2], t:2.6, ty:-.2,  aF:3.2, eF:.5,  aB:3.0, eB:.5,  w:4, fF:[-.5,0], fB:[.45,0], snap:true },
  kd0:     { r:-4,b:[-1,2], h:[-3,-1],t:-1.5,ty:.4,  aF:6.0, eF:.6,  aB:5.4, eB:.7,  w:4, fF:[-.5,0], fB:[.45,0], air:2, snap:true },
  kd1:     { r:-8,b:[-1,2], h:[-2,0],t:-4.0,ty:.3,   aF:7.0, eF:.85, aB:6.6, eB:.85, w:4, fF:[.6,-.7], fB:[.42,-.5], air:13 },
  kd2:     { r:-11,b:[-1,8],h:[-1,0],t:-5.8,ty:.2,   aF:6.0, eF:.85, aB:5.6, eB:.85,  w:4, fF:[.8,-.3], fB:[.7,-.2], air:5 },
  kd3:     { r:-13,b:[0,16],h:[0,0], t:-6.6,ty:.1,   aF:3.4, eF:.92, aB:3.8, eB:.92,  w:4, fF:[.92,0], fB:[.82,0], snap:true },
  kd4:     { r:-13,b:[0,15],h:[0,0], t:-6.4,ty:.1,   aF:3.8, eF:.9,  aB:4.2, eB:.9,  w:4, fF:[.9,-.08], fB:[.8,-.05], air:3 },
  kd5:     { r:-13,b:[0,16],h:[0,1], t:-6.6,ty:.1,   aF:3.3, eF:.92, aB:3.7, eB:.92,  w:4, fF:[.92,0], fB:[.82,0] },
  gu0:     { r:-12,b:[0,14],h:[1,1], t:-2.6,ty:0,    aF:3.0, eF:.8,  aB:3.4, eB:.8,  w:4, fF:[.62,0], fB:[.5,0] },
  gu1:     { r:-10,b:[0,9], h:[1,1], t:1.2, ty:-.3,  aF:3.6, eF:.6,  aB:4.0, eB:.6,  w:4, fF:[-.55,0], fB:[.45,0] },
  // --- 타격 다양화: 훅 · 어퍼컷 · 팔꿈치 · 니킥 · 돌려차기 · 다리걸기 · 박치기 ---
  hookW:   { tv:2, r:-1, b:[-1,2], h:[0,0], t:-.4, aF:3.2, eF:.5,  aB:4.6, eB:.55, w:4, fF:[.36,0],  fB:[-.34,0] },
  hook:    { tv:1, r:10, b:[3,2],  h:[1,0], t:1.4, aF:4.6, eF:.62, aB:4.8, eB:.5,  w:4, fF:[.5,0],   fB:[-.24,0], impact:true, snap:true, smear:'b' },
  upW:     { tv:2, r:0,  b:[0,6],  h:[0,1], t:.7,  aF:4.9, eF:.46, aB:2.0, eB:.6,  w:4, fF:[.4,0],   fB:[-.38,0] },
  up:      { tv:2, r:8,  b:[2,-3], h:[1,-1],t:-.7, aF:5.0, eF:.46, aB:7.4, eB:.72, w:4, fF:[.46,0],  fB:[-.18,-.12], impact:true, snap:true, frontB:true },
  elbW:    { tv:2, r:-1, b:[0,2],  h:[0,0], t:-.3, aF:7.0, eF:.32, aB:4.6, eB:.55, w:4, fF:[.34,0],  fB:[-.34,0] },
  elb:     { tv:1, r:9,  b:[3,1],  h:[1,0], t:1.3, aF:4.3, eF:.34, aB:4.8, eB:.5,  w:4, fF:[.52,0],  fB:[-.26,0], impact:true, snap:true },
  knW:     { tv:0, r:3,  b:[1,1],  h:[0,0], t:.7,  aF:4.3, eF:.78, aB:4.1, eB:.78, w:4, fF:[.36,0],  fB:[-.32,0] },
  kn:      { tv:1, r:8,  b:[2,-2], h:[1,1], t:1.0, aF:3.0, eF:.62, aB:2.8, eB:.62, w:4, fF:[.52,-.78], fB:[-.24,0], impact:true, snap:true },
  rhW:     { tv:2, r:-2, b:[-1,2], h:[0,0], t:-.5, aF:5.4, eF:.48, aB:4.6, eB:.55, w:4, fF:[.22,-.12], fB:[-.36,0] },
  rh:      { tv:1, r:7,  b:[-2,-1],h:[-1,0],t:-1.5,aF:5.8, eF:.5,  aB:2.6, eB:.75, w:4, fF:[1.05,-1.15], fB:[-.26,0], impact:true, snap:true, smear:'a', smearAt:'hip' },
  swW:     { tv:0, r:0,  b:[0,9],  h:[0,1], t:.9,  aF:3.0, eF:.62, aB:2.0, eB:.62, w:4, fF:[.42,0],  fB:[-.5,0] },
  sw:      { tv:1, r:4,  b:[-2,11],h:[0,1], t:.3,  aF:1.4, eF:.85, aB:.8,  eB:.85, w:4, fF:[1.28,-.04], fB:[-.42,0], impact:true, snap:true, smear:'b', smearAt:'hip' },
  hbW:     { tv:0, r:-3, b:[-1,1], h:[-2,0],t:-.7, aF:4.4, eF:.7,  aB:4.2, eB:.7,  w:4, fF:[.34,0],  fB:[-.36,0] },
  hb:      { tv:1, r:10, b:[3,1],  h:[4,1], t:1.7, aF:4.0, eF:.72, aB:3.8, eB:.72, w:4, fF:[.54,0],  fB:[-.24,0], impact:true, snap:true },
  batW:    { tv:2, r:-3, b:[-1,2], h:[0,0], t:-.7, aF:6.6, eF:.5,  aB:6.2, eB:.58, w:11, fF:[.34,0], fB:[-.38,0] },
  batS:    { tv:1, r:11, b:[3,2],  h:[1,0], t:1.1, aF:4.2, eF:.9,  aB:4.4, eB:.82, w:4.2, fF:[.52,0], fB:[-.22,0], impact:true, snap:true },
  batF:    { tv:1, r:9,  b:[2,2],  h:[1,0], t:.9,  aF:2.6, eF:.85, aB:2.8, eB:.8,  w:1.5, fF:[.48,0], fB:[-.24,0] },
  m_hitB:  { tv:2, r:-3, b:[-1,4], h:[2,2], t:1.7, aF:2.6, eF:.5,  aB:2.0, eB:.5,  w:4, fF:[.26,0],  fB:[-.4,0], snap:true },
  m_lift:  { tv:2, r:-6, b:[-2,0], h:[-2,0],t:-2.2,aF:6.5, eF:.8,  aB:6.0, eB:.8,  w:4, fF:[.1,-.5], fB:[-.3,-.4], air:14, snap:true },
  sb_sitc: { r:2, b:[2,5.4], h:[1,1], t:.6, aF:7.2, eF:.85, aB:6.8, eB:.85, w:4, fF:[.62,0], fB:[.52,0] },          // 앉은 채 머리를 감싼다
  sb_sit:  { r:0, b:[2,4.8], h:[0,0], t:.2, aF:1.6, eF:.55, aB:1.3, eB:.55, w:4, fF:[.62,0], fB:[.52,0] },
  sb_strap:{ r:0, b:[0,0], h:[0,0], t:0, aF:8.2, eF:.95, aB:.6, eB:.95, w:4, fF:[.18,0], fB:[-.18,0] },
  b_walk0: { r:0, b:[0,1], h:[0,0], t:.5, aF:4.9, eF:.46, aB:4.6, eB:.55, w:4, fF:[.42,0], fB:[-.32,0] },
  b_walk1: { r:0, b:[0,0], h:[0,0], t:.5, aF:4.8, eF:.46, aB:4.5, eB:.55, w:4, fF:[.5,-.18], fB:[-.22,0] },
  b_walk2: { r:0, b:[0,1], h:[0,0], t:.5, aF:4.9, eF:.46, aB:4.6, eB:.55, w:4, fF:[.46,0], fB:[-.26,0] },
  b_walk3: { r:0, b:[0,0], h:[0,0], t:.5, aF:5.0, eF:.46, aB:4.7, eB:.55, w:4, fF:[.4,0], fB:[-.16,-.2] },
  b_jkW:   { tv:1, r:-1, b:[-1,4], h:[0,1], t:.6, aF:5.6, eF:.5, aB:5.2, eB:.5, w:4, fF:[.3,0], fB:[-.3,0] },
  b_jk:    { tv:1, r:14, b:[2,0], h:[1,0], t:-.5, air:13, aF:5.2, eF:.5, aB:4.4, eB:.5, w:4, fF:[1.05,-.55], fB:[-.22,-.45], impact:true, snap:true },
  b_jkL:   { tv:0, r:16, b:[0,3], h:[0,0], t:.4, air:1, aF:5.0, eF:.46, aB:4.6, eB:.55, w:4, fF:[.42,0], fB:[-.3,0] },
  m_hit:   { tv:2, r:-5, b:[-2,1], h:[-2,0], t:-1.6,aF:7,   eF:.38, aB:6.5, eB:.34, w:4, fF:[.22,0], fB:[-.42,0], snap:true },
};
const POSE_LABEL = { idle0:'대기 1', idle1:'대기 2', windup:'예비', strike:'타격', follow:'후속', recover:'회수', hit:'피격',
  walk0:'걷기 1', walk1:'걷기 2', walk2:'걷기 3', walk3:'걷기 4', block:'막기', cast0:'시전 모으기', cast1:'시전 유지', cast2:'시전 발사',
  death0:'쓰러짐 1', death1:'쓰러짐 2', death2:'쓰러짐 3',
  m_idle0:'MMA 가드 1', m_idle1:'MMA 가드 2', m_jabW:'잽 예비', m_jab:'잽', m_crossW:'크로스 예비', m_cross:'크로스', m_kickW:'로우킥 예비', m_kick:'로우킥', m_hit:'MMA 피격' };
const POSE_DEFAULT = JSON.parse(JSON.stringify(POSES));
const LOOP = new Set(['idle','walk','busk','run','stagger']);
const GRAMMAR = [
  { k:'pre', l:'예비', v:4, min:0, max:8, c:'#7c6cd8' },
  { k:'hit', l:'타격', v:1, min:1, max:4, c:'#ff7a59' },
  { k:'stop', l:'정지', v:4, min:0, max:8, c:'#ffd166' },
  { k:'fol', l:'후속', v:2, min:0, max:6, c:'#4fb0e8' },
  { k:'rec', l:'회수', v:3, min:0, max:8, c:'#8a82a6' },
];
const G = Object.fromEntries(GRAMMAR.map(g=>[g.k,g.v]));
// 존 윅 리그 동작표 (값 = ms). SLYNYRD 구조: 장전 → 당김 → 스미어 → 타격 → 유지 → 회수 → 오버슈트
const JW_SEQ = {
  jug:[['air_up',99999]], jland:[['kd3',60],['kd4',70],['kd5',520]],   // 저글: 공중은 물리가 자세를 정하고, 착지하면 눕는다
  spcHold:[['gr_hold',99999]], spcLift:[['gr_lift',99999]], spcSlam:[['gr_throw',140],['gr_ft',420],['gr_rt',160],['c_over',60]],   // 종착역: 잡고 밀기 · 들기 · 내리꽂기
  uthrust:[['ut_load',95],['ut_smear',35],['ut_hit',110],['ut_hit_ft',90],['ut_hit_rt',100],['c_over',60]],
  swat:   [['np_load',70],['np_smear',30],['np_hit',80],['np_hit_ft',60],['np_hit_rt',70],['c_over',40]],
  fkick:  [['fk_ready',140],['fk_jump',80],['fk_tuck',90],['fk_smear',40],['fk_hit',120],['fk_fall',110],['fk_land',130],['c_over',70]],
  gx_jw:      [['gx_rel',120],['gx_b1',170],['gx_b2',240],['gx_b1',120],['gx_rel',180]],
  gx_gala:    [['gx_rel',100],['gx_c1',190],['gx_c2',240],['gx_c1',130],['gx_rel',180]],
  gx_rain:    [['gx_rel',100],['gx_h1',180],['gx_h2',300],['gx_h1',130],['gx_rel',180]],
  gx_chicago: [['gx_rel',100],['gx_t1',180],['gx_t2',160],['gx_h1',160],['gx_h2',240],['gx_rel',180]],
  idle:   [['st0',100],['st1',100],['st2',100],['st3',100],['st2',50],['st1',50],['st0',50],['st0',50]],
  cross:   [['c_load',70],['c_pull',45],['c_smear',35],['c_hit',90],['c_hit_ft',90],['c_hit_rt',110],['c_over',60]],
  jab:     [['j_load',45],['j_smear',30],['j_hit',70],['j_hit_ft',60],['j_hit_rt',80],['c_over',40]],
  hook:    [['h_load',105],['h_smear',35],['h_hit',90],['h_hit_ft',100],['h_hit_rt',110],['c_over',60]],
  upper:   [['u_load',100],['u_dip',70],['u_smear',40],['u_hit',120],['u_hit_ft',140],['u_hit_rt',150],['c_over',70]],
  kick:    [['k_load',100],['k_smear',40],['k_hit',100],['k_hit_ft',90],['k_hit_rt',110],['c_over',60]],
  round:  [['r_load',100],['r_turn',50],['r_spin1',60],['r_spin2',60],['r_smear',40],['r_hit',120],['r_hit_ft',110],['r_hit_rt',120],['c_over',70]],
  bat:    [['batW',150],['batS',100],['batF',150],['c_rec',100],['c_over',50]],
  hbutt:  [['hbW',150],['hb',150],['c_rec',100],['c_over',50]],
  hit:    [['hh0',50],['hh1',150],['c_over',100]],
  hitB:   [['hbd0',50],['hbd0',200],['c_over',100]],
  fall:   [['kd0',50],['kd1',150],['kd2',100],['kd3',50],['kd4',50],['kd5',500]],
  launch: [['ru0',80],['kd1',220],['kd2',100],['kd3',50],['kd4',50],['kd5',500]],
  rCross: [['rc0',50],['rc1',200],['c_over',100]],
  rHook:  [['rh0',50],['rh1',220],['c_over',100]],
  rKnee:  [['rk0',80],['rk1',260],['rk2',150],['c_over',100]],
  rElbow: [['hbd0',60],['dz0',220],['dz1',220],['dz0',220],['dz1',220],['c_over',100]],
  rKick:  [['rkc0',80],['kd1',150],['kd2',100],['kd3',50],['kd4',50],['kd5',500]],
  rSpin:  [['rs0',60],['rs1',150],['kd2',80],['kd3',50],['kd4',50],['kd5',500]],
  rSwept: [['rsw0',60],['rsw1',90],['kd3',40],['kd4',60],['kd5',550]],
  rCharge:[['rc0',40],['kd1',260],['kd2',100],['kd3',50],['kd4',50],['kd5',500]],
  rSlam:  [['kd3',40],['slm0',90],['kd4',60],['kd5',650]],
  rSpike: [['sp_dive',70],['sp_hit',60],['sp_bounce',90],['sp_land',70],['sp_lie',650]],   // 도끼 차기: 앞으로 꽂혀 바닥에 쿵 → 살짝 튕김 → 엎어진 채
  rStomp: [['stp0',90],['kd5',450]],
  deathFwd:[['rk0',80],['dfw0',180],['dfw1',150],['dfw1',700],['dfw1',700,'blink']],
  getup:  [['gu0',150],['gu1',200],['c_over',100]],
  elbow:   [['e_load',55],['e_hit',75],['e_hit_ft',70],['e_hit_rt',90],['c_over',50]],
  knee:    [['n_load',110],['n_hit',100],['n_hit_ft',90],['n_rec',100],['c_over',60]],
  sweep:   [['sw_load',150],['sw_hit',120],['sw_hit_ft',110],['sw_rec',140],['c_over',60]],
  charge: [['ch_load',100],['ch_run',150],['ch_hit',100],['c_rec',150],['c_over',50]],
  throw:   [['gr_reach',100],['gr_hold',150],['gr_lift',250],['gr_throw',140],['gr_ft',150],['gr_rt',130],['c_over',60]],
  stomp:   [['st_load',160],['st_hit',110],['st_hit_ft',100],['st_hit_rt',120],['c_over',60]],
  held:   [['hl0',99999]],
  rest_sit: [['sb_sit',99999]],
  rest_lean:[['lean0',99999]],
  duck:   [['dk0',50],['dk1',420],['dk2',100],['c_over',50]],
  evade:  [['ev0',60],['ev0',160],['c_over',80]],
  parry:  [['pr0',60],['pr0',140],['c_over',80]],
  hm_swing:[['hm_wind',90],['hm_hit',70],['hm_rec',110],['c_over',60]],
  hm_back: [['hm_bload',80],['hm_bhit',70],['hm_rec',100],['c_over',60]],
  hm_up:   [['hm_uload',90],['hm_uhit',80],['hm_rec',110],['c_over',60]],
  hm_down: [['hm_dload',110],['hm_dhit',80],['hm_rec',130],['c_over',70]],
  polespin:[['ps0',80],['ps1',150],['ps2',150],['ps3',120],['c_over',60]],
  hangkick:[['hk0',110],['hk1',170],['hk2',140],['c_over',60]],
  busk:   [['gt0',230],['gt1',230]],
  run:    [['st0',99999]],
  bkick:   [['bk_load',100],['bk_hit',110],['bk_hit_ft',90],['bk_rec',110],['c_over',50]],
  bfist:   [['bf_load',70],['bf_hit',90],['bf_hit_ft',80],['bf_rec',100],['c_over',50]],
  death:  [['kd0',50],['kd1',150],['kd2',100],['kd3',50],['kd4',50],['kd5',700],['kd5',700,'blink']],
};JW_SEQ.jlandD=[['kd3',60],['kd4',70],['kd5',700],['kd5',700,'blink']];
for(const k of ['fall','rKick','rSpin','rSwept','rCharge','rSlam','launch']) JW_SEQ[k+'D']=[...JW_SEQ[k].slice(0,-1), ['kd5',700], ['kd5',700,'blink']];   // 쓰러지는 반응의 죽음 버전
JW_SEQ.rTetsu=JW_SEQ.rCharge.slice();
const FALLS=new Set(['fall','launch','rKick','rSpin','rSwept','rCharge','rSlam','rStomp','jland','crumple','rSpike','rTetsu']);
JW_SEQ.rSpikeD=[...JW_SEQ.rSpike.slice(0,-1), ['sp_lie',700], ['sp_lie',700,'blink']]; JW_SEQ.rTetsuD=JW_SEQ.rChargeD.slice();
JW_SEQ.getupP=[['pp0',170],['pp1',170],['gu1',200],['c_over',100]];   // 엎드린 채 일어나기(도끼 차기 뒤)
JW_SEQ.stagger=[['stg0',150],['stg3',150],['stg1',170],['stg2',150]];   // 휘청(경직 동안 반복)
JW_SEQ.staggerX=[...JW_SEQ.stagger, ...JW_SEQ.stagger, ...JW_SEQ.stagger, ['c_over',120]];   // 무도장 시연용(세 번 흔들고 끝)
JW_SEQ.rWall=[['wl0',70],['wl1',170],['c_over',90]];   // 서서 벽에 부딪힘
JW_SEQ.rBlast=JW_SEQ.rCharge.slice(); JW_SEQ.rBlastD=JW_SEQ.rChargeD.slice();   // 콤보 마무리 일직선 날림(물리가 아닐 때 대비)
FALLS.add('rBlast');
const REACTS=new Set(['parry','evade','hit','hitB','getup','death','held',...FALLS,'rCross','rHook','rKnee','rElbow','deathFwd','rKickD','rSpinD','rSweptD','rChargeD','rSlamD','launchD','rSpikeD','rTetsuD','getupP','stagger','staggerX','rWall','rBlastD']);
// 공격 → 맞는 쪽 반응: 공격자의 지금 동작과 타격 성격으로 고른다
function reactKey(att,o){ const a=att&&att.anim&&att.anim.replace(/_air$/,'');
  if(o.splash) return 'rKick';                                                       // 메치기 주변에 휩쓸림
  if(o.react==='down') return 'rStomp';
  if(a==='hm_swing') return o.knock ? 'rSpin' : 'rHook';                              // 장도리
  if(a==='hm_back') return 'rCross';
  if(a==='hm_up') return 'launch';
  if(a==='hm_down') return o.knock ? 'fall' : 'hit';
  if(a==='throw'||a==='suplex') return 'rSlam';
  if(a==='tetsu') return 'rTetsu';
  if(a==='renkan') return o.react==='launch' ? 'launch' : 'rkPop';
  if(a==='axe') return 'crumple';
  if(a==='bkick') return o.knock ? 'rKick' : 'hitB';
  if(a==='bfist') return 'rHook';
  if(a==='sweep') return 'rSwept';
  if(a==='charge') return 'rCharge';
  if(a==='round'||a==='bat') return o.knock ? 'rSpin' : 'rHook';
  if(a==='kick') return o.knock ? 'rKick' : 'hitB';
  if(a==='knee') return 'rKnee';
  if(a==='elbow') return 'rElbow';
  if(a==='upper'||a==='scoop'||a==='skick'||o.react==='launch') return 'launch';
  if(a==='hook') return 'rHook';
  if(a==='cross'||a==='hbutt') return 'rCross';
  if(o.knock) return 'fall';
  if(o.react==='body') return 'hitB';
  return 'hit'; }
// =========================================================
// 공중 콤보(저글): 띄우기 → 공중 타격마다 살짝 뜨며 뒤로 밀림 → 맞을수록 중력이 세져 결국 떨어진다(저글 감쇠)
// 저글 점수가 한도를 넘으면 더 뜨지 않는다 · 바닥 튕김은 한 번 · 공중 타격은 맞을수록 피해가 줄어든다
// =========================================================
const JUG={ G:640, decay:.9, gUp:.16, limit:9, scaleK:.93, scaleMin:.55, bounceV:200, hitPose:.13 };
const LAUNCH={ launch:{vy:210,vx:20,up:'air_up',fall:'air_back',pts:2}, rkPop:{vy:125,vx:12,up:'air_up',fall:'air_back',pts:1},   // 연환퇴 1타: 살짝 띄움 rTetsu:{vy:95,vx:430,up:'air_back',fall:'air_fall',pts:3,drag:.78,bounce:true},   // 철산고: 낮고 길게 일직선 rCharge:{vy:190,vx:330,up:'air_arch',fall:'air_arch',roll:-.3,pts:3,drag:.62,bounce:true},   // 돌진: 멀리 · 빙글 · 꼭 한 번 튕김
  rKick:{vy:133,vx:150,up:'air_back',fall:'air_fall',pts:2}, rBlast:{vy:120,vx:360,up:'air_back',fall:'air_fall',pts:3,drag:.7,bounce:true}, rSwept:{vy:80,vx:12,up:'air_trip',fall:'air_trip',pts:1,trip:true}, rSpin:{vy:177,vx:125,up:'air_arch',fall:'air_arch',roll:-.25,pts:2}, fall:{vy:106,vx:110,up:'air_back',fall:'air_fall',pts:1} };
const AIRPOP={ L:{vy:150,vx:18,pts:1}, M:{vy:165,vx:30,pts:2}, H:{vy:185,vx:110,pts:3} };   // 가벼운 공중 타격은 조금만 밀어 다음 주먹이 닿게, 무거운 건 멀리
function strapAir(H,T,sx){ dbgT('strap', dbgSt(T)); H.d.x=sx; face(H,T.d.x); setAnim(H,'idle'); cmdPush({ name:'손잡이 공중전', env:true }); GS.hangT2=GS.time; GS.hangX=sx;
  requestAction(H,'hangkick',{ cues:{ hk0:()=>{ H.airOv=6; }, hk1:()=>{ const f=H.d.flip?-1:1; for(const a of foes()){ const dx=(a.d.x-H.d.x)*f; if(a.jug && dx>-6 && dx<46) damage(H,a,Math.round(22*(1+.08*GS.ci)),{knock:true}); } }, hk2:()=>{ H.airOv=0; } } }); }
function jugRollRate(J){ if(!J.rollT || J.roll<=J.rollT) { J.rollR=0; return; } const g=JUG.G*(1+JUG.gUp*J.n), T=Math.max(.18,(Math.max(0,J.vy)+Math.sqrt(J.vy*J.vy+2*g*Math.max(0,J.h)))/g); J.rollR=(J.rollT-J.roll)/T; }   // 땅에 닿을 때 딱 한 바퀴가 끝나게
function jugRefund(k){ const b=GS.bag.find(b=>b&&b.uid===GS.curSrc); if(!b) return; const it=GITEMS[b.id]; if(it.fam==='fist'||it.combo){ const cd=sStats(GS.bag.indexOf(b)).cd; b.t=Math.min(cd,(b.t||0)+cd*k); } }   // 띄운 기술 100% · 공중 타격 85%: 바로 이어 친다   // 주먹 계열은 공중 연타가 이어지게
function jugHit(t,rk,f,att,o,kres){
  if(!t.jug){ const L=LAUNCH[rk]||LAUNCH.fall, hv=(t.e&&t.e.heavy?.6:1)*(kres<1?.8:1);
    t.jug={ h:Math.max(.5,t.airOv||0), vy:L.vy*hv, vx:f*L.vx*hv, n:0, pts:L.pts, spin:0, spinR:0, roll:0, rollT:L.roll||0, rollR:0, jerkT:L.roll?.12:0, up:L.up, fall:L.fall, bounced:false, hitT:0, t:0, drag:L.drag||.45, forceB:!!L.bounce, trip:!!L.trip, src:att===GS.hero?GS.curSrc:null }; jugRollRate(t.jug);
    if(att && att.anim==='skick'){ t.jug.gk=.8; t.jug.vy*=Math.sqrt(.8); }   // 섬머솔트: 같은 높이로 더 오래 뜬다(뒤집힘을 끝까지 보여 주고 이어 치게)
    if(GS.tower) t.jug.vy*=1.55;   /* 타워: 좁은 칸 — 띄우면 천장까지 */ t.action=null; t.queue=[]; t.after=null; if(t.e) t.e.stun=0; setAnim(t,'jug'); t.pose=t.prev=L.up; t.k=0; t.bFrom=null; if(att===GS.hero) jugRefund(1); }   // 첫 프레임부터 그 반응의 자세로
  else { const J=t.jug, w=(ATK_FEEL[att&&att.anim]&&ATK_FEEL[att.anim].w)||(o.knock?'H':'M'), P=AIRPOP[w]; J.n++; J.pts+=P.pts; if(J.trip){ J.trip=false; J.up='air_back'; J.fall='air_fall'; }   // 걸림 중 맞으면 걸림이 끝나고 보통 중력
    J.vy = J.pts<=JUG.limit ? Math.max(J.vy, P.vy*Math.pow(JUG.decay,J.n)*Math.max(.25,Math.min(1,1-(J.h-36)/24))) : Math.min(J.vy,-80);   /* 높이 36 위로는 띄움이 점점 약해진다(부드러운 천장) */   // 올라가는 중엔 상승을 살짝만 줄이고, 내려오는 중이면 다시 띄운다 · 한도를 넘으면 떨어진다
    if(o.knock && J.n>=3 && att===GS.hero) GS.slowT=Math.max(GS.slowT||0,.18);   // 저글 마무리: 잠깐 느리게
    J.vx = f*P.vx + J.vx*.3; if(att && (att.anim==='upper' || att.anim==='scoop' || o.react==='launch')){ J.vx=f*20; J.vy=Math.max(J.vy,(att.anim==='scoop'?240:205)*Math.pow(JUG.decay,J.n)); J.trip=false; J.up='air_up'; J.fall='air_back'; }   /* 공중 어퍼컷: 거의 수직으로 다시 띄운다 */ if(o.knock){ J.vx=f*Math.max(Math.abs(J.vx),185); J.rollT=J.roll-.06; J.up='air_back'; J.fall='air_fall'; }   /* 공중 무거운 마무리: 누운 자세 그대로 조금 더 뒤로 구른다 */ J.hitT=GS.time+JUG.hitPose; J.kv=(J.kv||0)-(o.knock?.7:.45); jugRollRate(J); if(att===GS.hero) jugRefund(1);
    if(att && att.anim==='stomp' && !J.gb){ J.vy=-430; J.vx*=.3; J.gbReady=true; J.gbSrc=GS.curSrc; }
    if(o.blast){ J.vx=f*340*(t.e&&t.e.heavy?.6:1); J.vy=Math.min(Math.max(J.vy,40),90); J.drag=.7; J.forceB=true; J.bounced=false; J.up='air_back'; J.fall='air_fall'; J.rollT=J.roll; jugRollRate(J); } }   /* 콤보 마무리: 떠 있어도 낮게 일직선으로 날린다 */   // 바닥 튕기기: 내리꽂는다
  t.kb=t.jug.vx; }
function jugStep(a,dt){ const J=a.jug;
  J.kv=(J.kv||0)+(-140*(J.kick||0)-15*(J.kv||0))*dt; J.kick=(J.kick||0)+J.kv*dt;   // 맞을 때마다 뒤로 젖혀졌다 제자리로(스프링)
  if(a.hs>0){ a.d.x+=J.vx*dt*.05; return; }   // 정지 중에도 넉백 방향으로 아주 조금만(높이는 그대로 — 저글 높이가 쌓이지 않게)
  J.t+=dt;
  const v0=J.vy, h0=J.h, g0=JUG.G*(1+JUG.gUp*J.n)*(J.trip?.5:1)*(J.gk||1); J.vy-=g0*dt; J.h+=J.vy*dt;
  if(GS.tower && v0>0 && h0<TWR.CEIL_H){ const C=TWR.CEIL_H-h0, D=v0*v0-2*g0*C; if(D>=0){ const tc=(v0-Math.sqrt(D))/g0; if(tc<=dt){ J.vy=v0-g0*tc; twCeil(a,J); } } }   // 엘리베이터 천장 튕기기: 실제 궤적이 천장에 닿는 순간을 계산(프레임이 느려도 같게) J.vx*=Math.pow(J.drag||.45,dt); a.kb=J.vx; if(J.rollR) J.roll=Math.max(J.rollT, J.roll+J.rollR*dt);
  const x0=J.px??a.d.x; J.px=a.d.x;
  if(!J.wallB && J.t>.05 && J.h<46 && Math.abs(J.vx)>160 && poleOK()){ const dir=Math.sign(J.vx), px=(GS.demo&&DJ.on?DJ_POLES:POLES).find(px=>(px-x0)*(px-a.d.x)<=0 && x0!==a.d.x);   // 날아가다 기둥을 실제로 지나면 한 번 튕겨 온다(기둥 튕기기 연계)
    if(px!=null){ J.wallB=true; J.vx=-dir*Math.min(110,Math.abs(J.vx)*.33); J.vy=Math.max(J.vy,140); J.hitT=GS.time+.18; a.hs=Math.max(a.hs||0,3); J.spinR*=.4; a.d.x=px-dir*5; a.kb=J.vx;
      { const bi=GS.bag.findIndex(b=>b&&b.uid===J.src); if(bi>=0) linkFire(bi,'pole'); } if(GS.demo&&DJ.on) djJolt(1.2); sparks.push({x:px,y:a.d.y-24-J.h,age:0}); sparks.push({x:px,y:a.d.y-36-J.h,age:1});
      shakeAmp=Math.max(shakeAmp||0,2.6); comicSFX(px, a.d.y-60-J.h, 'CLANG!'); try{ sfx.clack(); }catch(e){} GS.poleT=GS.time; } }
  const ps = J.t<J.jerkT ? 'air_jerk' : (J.wallP||0)>GS.time ? 'air_wall' : GS.time<J.hitT ? 'air_hit' : J.vy>30 ? J.up : J.fall; if(a.pose!==ps){ a.prev=ps; a.pose=ps; a.k=0; if(a.lastP){ a.bFrom=a.lastP; a.bT0=gameTime; a.bDur= ps==='air_hit'?.05:.12; } }   /* 공중 자세 전환: 피격 자세로 3프레임 · 비행 자세로 0.12초 보간 */ a.hold=99999; a.phaseN=99999; a.airOv=Math.max(0,J.h);
  if(J.h<=0 && J.vy<0 && J.gbReady && !J.gb){ J.gb=true; J.gbReady=false; J.bounced=true; J.vy=210; J.h=.5; J.hitT=GS.time+.15; groundImpact(a.d.x,a.d.y,1.5);   // 높이 튕겨 다시 공중으로
    const bi=GS.bag.findIndex(b=>b&&b.uid===J.gbSrc); if(bi>=0) linkFire(bi,'gbounce'); }
  if((J.h<=0 && J.vy<0) || J.t>3.5){ const imp=Math.max(0,-J.vy);
    if((imp>JUG.bounceV || (J.forceB && imp>60)) && !J.bounced && J.t<=3.5){ J.bounced=true; J.vy=imp*.3; J.h=.5; J.vx*=.55; J.roll=J.rollT; J.rollR=0; groundImpact(a.d.x,a.d.y,Math.min(1.6,imp/300)); }   // 한 번 튕긴다
    else { const die=J.die; if(J.trip) a.tripLandT=GS.time; a.jug=null; a.airOv=0; a.kb=J.vx*.9; if(die) setAnim(a,'jlandD'); else { setAnim(a,'jland'); a.after='getup'; } groundImpact(a.d.x,a.d.y,Math.min(1.4,imp/330+.25)); } } }
// 바닥 충격: 양쪽으로 퍼지는 먼지 덩이 · 튀는 부스러기 · 큰 충격엔 바닥 금 · 화면 흔들림
function groundImpact(x,y,p){ p=Math.max(.3,p); if(p>=.6) sfx.floor(p); if(xcOn()) xcKick(x,y,1+p*.6,10+30*p);   /* 건널목: 큰 충격에 단풍이 크게 날린다 */ const n=Math.round(6+8*p), puffs=[]; for(let i=0;i<n;i++){ const side=i%2?1:-1; puffs.push({ dx:side*(2+Math.random()*6), vx:side*(14+Math.random()*26)*p, rise:3+Math.random()*7*p, r:(2.4+Math.random()*3)*(.7+p*.5), d:Math.random()*.12 }); }
  HITFX.push({ k:'gdust', x, y, t:0, life:.55+.3*p, puffs });
  const parts=[]; for(let i=0;i<Math.round(3+5*p);i++) parts.push({ vx:(Math.random()*2-1)*(40+50*p), vy:60+Math.random()*90*p, s:Math.random()<.5?1:2 }); HITFX.push({ k:'debris', x, y, t:0, life:.6, parts });
  if(p>1.05){ const pts=[]; let cx=-10-8*p; while(cx<10+8*p){ pts.push([cx,(Math.random()*2-1)*1.2]); cx+=2+Math.random()*3; } HITFX.push({ k:'crack', x, y, t:0, life:1.1, pts }); }
  dusts.push({ x, y, age:0, flip:false }); dusts.push({ x, y, age:0, flip:true }); shakeAmp=Math.max(shakeAmp||0, 1+1.6*p); if(GS.demo&&DJ.on) djJolt(p*.7); if(GS.tower) GS.tower.sagV+=p*5; }   // 타워: 큰 착지에 칸이 출렁
const REACT_KB={ crumple:6, spinout:22, pulled:-160, hit:42, hitB:28, rCross:58, rHook:38, rKnee:16, rElbow:22, rKick:120, rSpin:70, rSwept:26, rCharge:150, rSlam:0, rStomp:0, rSpike:0, rTetsu:220, launch:60, fall:110 };
const deathOf=rk=> FALLS.has(rk) && rk!=='rStomp' ? rk+'D' : (rk==='rKnee'||rk==='hitB'||rk==='rElbow') ? 'deathFwd' : rk==='rStomp' ? 'rSlamD' : 'death';

const seqOf = (name,c) => { if(c&&c.seqOv&&c.seqOv.anim===name) return c.seqOv.seq;   // 한 번만 쓰는 순서(자동 착지 다리)
  if(c&&c.d&&c.d.jw&&JW_SEQ[name]) return JW_SEQ[name];
  const g=(c&&c.grammar)||G, mma=!!(c&&c.d&&c.d.mma); return ({
  idle:   mma ? [['m_idle0',4],['m_idle1',4]] : [['idle0',6],['idle1',6]],
  jkick:  [['b_jkW',3],['b_jk',4],['b_jkL',2],['m_idle0',2]],
  hook:   [['hookW',3],['hook',2],['m_idle0',4]],
  upper:  [['upW',3],['up',3],['m_idle0',4]],
  elbow:  [['elbW',2],['elb',2],['m_idle0',3]],
  knee:   [['knW',3],['kn',3],['m_idle0',3]],
  round:  [['rhW',3],['rh',3],['m_idle0',4]],
  sweep:  [['swW',3],['sw',3],['swW',2],['m_idle0',3]],
  hbutt:  [['hbW',3],['hb',2],['m_idle0',4]],
  hitB:   [['m_hitB',4],['m_idle0',3]],
  pass:   [[(c&&c.passPose)||'sb_sit',9999]],
  bat:    [['batW',4],['batS',2],['batF',3],['m_idle0',3]],
  launch: [['m_hit',1],['m_lift',3],['death1',2],['death2',7]],
  fall:   [['m_hit',1],['death0',2],['death1',2],['death2',7]],
  getup:  [['death1',3],['m_idle1',2]],
  jab:    [['m_jabW',2],['m_jab',2],['m_idle0',3]],
  cross:  [['m_crossW',3],['m_cross',2],['m_idle0',4]],
  kick:   [['m_kickW',3],['m_kick',2],['m_idle0',4]],
  attack: [['windup',g.pre],['strike',g.hit],['follow',g.fol],['recover',g.rec]],
  guard:  [['block',4],['recover',2]],
  drink:  [['cast0',3],['cast1',5],['recover',3]],
  hit:    mma ? [['m_hit',3],['m_idle0',3]] : [['hit',3],['recover',2]],
  walk:   mma ? [['b_walk0',2],['b_walk1',2],['b_walk2',2],['b_walk3',2]] : [['walk0',3],['walk1',3],['walk2',3],['walk3',3]],
  block:  [['block',12],['recover',3]],
  cast:   [['cast0',4],['cast1',8],['cast2',3],['recover',4]],
  death:  [['death0',3],['death1',4],['death2',14],['death2',10,'blink']],
  down:   [['death2',9999]],
}[name] || [['idle0',6]]); };

// 캐릭터마다 몸 치수만 다르고, 동작표(POSES·GRAMMAR)는 공유
// 모든 좌표는 골반(엉덩이 관절) 기준. hip = 발바닥에서 골반까지 높이, a0 = 원화가 그려진 각도(0=아래로 늘어뜨림)
// thigh·shin = 허벅지(엉덩이→무릎)·정강이(무릎→발바닥) 길이
const RIG_K = { hip:-14, head:[0,-8], shF:[4,-7], shB:[-1,-7], legF:[2,0], legB:[-3,0], armLenF:9, armLenB:9, thigh:5, shin:9, scarf:[-5,-8], glowLen:13, a0:{} };
const RIG_S = { hip:-13, head:[0,-9], shF:[4,-9], shB:[-1,-9], legF:[2,0], legB:[-2,0], armLenF:9, armLenB:9, thigh:5, shin:8, glowLen:12, a0:{} };
// 소형 리그: 같은 동작표를 쓰되 픽셀 단위 값(대시·골반·머리)은 sc 배율로 줄인다. 발 위치는 원래 다리 길이 비율이라 그대로
const RIG_KM = { hip:-8, head:[0,-4], shF:[2,-4], shB:[-2,-4], legF:[1,0], legB:[-1,0], armLenF:4, armLenB:4, thigh:3, shin:5, glowLen:6, a0:{}, sc:.4, popY:-30, sparkY:-12, sparkX:3 };
const RIG_SM = { hip:-8, head:[0,-4], shF:[2,-5], shB:[-2,-5], legF:[1,0], legB:[-1,0], armLenF:3, armLenB:3, thigh:3, shin:5, glowLen:6, a0:{}, sc:.4, popY:-30, sparkY:-12, sparkX:3 };
const KNIGHT_MINI = { name:'기사', x:176, y:176, flip:false, rig:RIG_KM, smear:'smearKm_', eye:null, glow:true,
  p:{ head:'mk_head', torso:'mk_torso', armF:'mk_arm', armB:'mk_armB', thighF:'mk_thigh', shinF:'mk_shin', thighB:'mk_thighB', shinB:'mk_shinB', wpn:'mk_sword', off:'mk_shield', scarf:null } };
const SKEL_MINI = { name:'해골', x:212, y:176, flip:true, rig:RIG_SM, smear:'smearSm_', eye:[2,-2], glow:false,
  p:{ head:'ms_skull', torso:'ms_rib', armF:'ms_arm', armB:'ms_armB', thighF:'ms_thigh', shinF:'ms_shin', thighB:'ms_thighB', shinB:'ms_shinB', wpn:'ms_axe', off:'ms_shield', scarf:null } };
// MMA 선수: 팔은 위팔·아래팔 두 마디(upper·fore). 블루 코너는 팔레트 스왑 4번(반바지 파랑 · 짙은 피부)
// v2: 키 59px. upright = 머리·몸통은 돌리지 않음(관절 위치만 기울기를 따름). sc = 동작표의 픽셀 값(대시·골반·머리) 배율
const RIG_F = { hip:-24, head:[0,-17], shF:[5,-15], shB:[-4,-15], views:[{shF:[5,-15],shB:[-4,-15]},{shF:[3,-15],shB:[-1,-15]},{shF:[7,-15],shB:[-7,-15]}], legF:[2,0], legB:[-3,0], upper:8, fore:9, armLenF:17, armLenB:17, thigh:11, shin:13, glowLen:3, a0:{}, upright:true, sc:1.25, popY:-70, sparkY:-48, sparkX:7 };
const FP={ head:'f2_head', torso:'f2_torso', torsoV:['f2_torso','f2_torso_1','f2_torso_2'], armF:'f2_upper', foreF:'f2_fore', armB:'f2_upperB', foreB:'f2_foreB', thighF:'f2_thigh', shinF:'f2_shin', thighB:'f2_thighB', shinB:'f2_shinB', wpn:'none', off:'none', scarf:null };
const FIGHTER_A = { name:'레드', x:140, y:150, flip:false, rig:RIG_F, mma:true, lines:true, smear:'none', eye:null, glow:false, p:FP };
const FIGHTER_B = { name:'블루', x:182, y:150, flip:true, rig:RIG_F, mma:true, lines:true, smear:'none', eye:null, glow:false, p:FP };
// 느와르: 트렌치코트 · 중절모 주인공과 헌팅캡 패거리. 보폭 동기 걷기(gait)
const NP={ ...FP, head:'n_head_fed', torso:'n_torso_0', torsoV:['n_torso_0','n_torso_1','n_torso_2'], armF:'n_upper', foreF:'n_fore', armB:'n_upperB', foreB:'n_foreB',
  thighF:'n_thigh', shinF:'n_shin', thighB:'n_thighB', shinB:'n_shinB', tail:'n_tail' };
const RIG_N = { ...RIG_F, shF:[7,-15], shB:[-6,-15], views:[{shF:[7,-15],shB:[-6,-15]},{shF:[5,-15],shB:[-3,-15]},{shF:[8,-15],shB:[-8,-15]}] };
const RIG_3D = { ...RIG_F, leanK:.6, shF:[.5,-15], shB:[0,-15], views:null, legF:[.6,0], legB:[-.4,0], head:[.6,-17], upper:8, fore:8, thigh:11, shin:13, upright:false };
const NOIR_HERO = { name:'탐정', x:120, y:NFLOOR+22, flip:false, rig:RIG_3D, model3:noirModel(), mma:true, gait:true, lines:true, smear:'smearN_', eye:null, glow:false, p:NP };
const NOIR_THUG = { name:'패거리', x:360, y:NFLOOR+36, flip:true, rig:RIG_3D, model3:noirModel({cap:true}), mma:true, gait:true, lines:true, smear:'smearN_', eye:null, glow:false, p:{ ...NP, head:'n_head_cap' } };
const JW_HERO = { ...NOIR_HERO, name:'존', model3:noirModel({suit:true, coat:M.SUIT, trou:M.SUIT}), jw:true, msT:true, face:true };
const JW_THUG = { ...NOIR_THUG, name:'패거리', model3:noirModel({suit:true, coat:M.COAT, cap:true}), jw:true, msT:true, face:true };
const JW_BOSS = { ...JW_HERO, name:'두목', model3:noirModel({suit:true, coat:M.COAT}) };
// ===== 주인공 스킨(유료 시험): 기본 검은 양복 + 3종 — 실루엣 · 소품 · 타격 강조색까지 바뀐다 =====
const JW_BASE_MODEL=JW_HERO.model3;
const SKINS={ jw:{ n:'존 윅', sub:'검은 양복 · 기본', sw:['#1e1e25','#e2e2d8','#3c3829'], acc:null, free:true, gx:'재킷 단추 잠그기', fl:'기본 연출' },
  gala:{ n:'갈라 나이트', sub:'흰 턱시도 · 나비넥타이 · 금 커프스', sw:['#d6d4cf','#141419','#c22131'], acc:'#ffd36a', gx:'커프스 매만지기', fl:'금빛 반짝임 · 잔 부딪는 소리' },
  rain:{ n:'레인 디텍티브', sub:'트렌치코트 · 중절모 · 금 버클', sw:['#83705a','#40301f','#ffc13d'], acc:'#8fd0ff', gx:'중절모 챙 내리기', fl:'빗줄기 · 낮은 천둥' },
  chicago:{ n:'시카고 1929', sub:'핀스트라이프 · 흰 띠 중절모 · 각반', sw:['#2a2a33','#cfcfc3','#c22131'], acc:'#ff6a5a', gx:'넥타이 · 챙 매만지기', fl:'붉은 불꽃 · 따다다닥' } };
function skinModel(k){
  if(k==='gala'){ const m=suitModel({ suit:true, coat:M.CANVAS, trou:M.SUIT, noTie:true });
    m.torso=[...m.torso, prism(1,9.6, 4.2,.32,2.8, 3.88,.32,1.0, M.SUIT,.42,2),                          // 검은 새틴 숄 라펠
      prism(1.15,2.45, 4.42,.34,1.6, 4.42,.34,1.6, M.SUIT,.36,2), prism(1.45,2.15, 4.66,.3,.45, 4.66,.3,.45, M.SUIT,.24,2),   // 나비넥타이 · 매듭
      prism(4.1,5.5, 3.98,.3,.85, 3.96,.3,.85, M.RED,.62,2,-1.5) ];                                              // 가슴 행커치프
    for(const [pt,pn] of [['thighF',9],['thighB',11]]) m[pt]=[...m[pt], prism(-1,11, 0,.14,2.86, 0,.14,2.56, M.SUIT,.66,pn)];   // 턱시도 바지 새틴 줄
    for(const [pt,pn] of [['shinF',10],['shinB',12]]) m[pt]=[...m[pt], prism(0,11, 0,.14,2.46, 0,.14,2.16, M.SUIT,.64,pn)];
    for(const [pt,pn] of [['farmF',6],['farmB',8]]) m[pt]=[...m[pt], prism(6.5,7.3, 0,1.86,1.86, 0,1.86,1.86, M.FRAME,.82,pn), prism(6.6,7.2, 1.9,.22,.5, 1.9,.22,.5, M.GOLD,.86,pn)];   // 흰 소매 · 금 커프스
    return m; }
  if(k==='rain'){ const m=suitModel({ suit:true, coat:M.COAT, trou:M.SUIT, tie:'WOODD', hair:'fedora', hatMat:M.WOODD, bandMat:M.MDARK });
    m.skirtF=[ prism(-.5,14, 0,4.2,3.0, .6,5.3,4.0, M.COAT,.46,3, 2.6) ]; m.skirtB=[ prism(-.5,14, 0,4.2,3.0, .6,5.3,4.0, M.COAT,.4,4,-2.6) ];   // 무릎까지 오는 코트 자락(걸음에 흔들림)
    m.torso=[...m.torso, prism(-1.6,2.6, .2,3.05,4.1, .2,3.95,5.4, M.COAT,.6,2),                          // 세운 깃
      prism(9.6,11.2, 0,3.95,6.65, 0,3.93,6.55, M.COAT,.24,2), prism(9.8,11, 3.98,.3,.95, 3.98,.3,.95, M.GOLD,.82,2),   // 허리띠 · 금 버클
      ...[3.6,6.6].flatMap(y=>[-1.15,1.15].map(l=>prism(y,y+.75, 4.06,.25,.46, 4.04,.25,.46, M.WOODD,.4,2,l))),   // 더블 단추
      prism(1.5,4.5, -3.9,.25,6.0, -3.7,.25,5.6, M.COAT,.52,2) ];                                               // 등 덮개(스톰 플랩)
    for(const [pt,pn] of [['farmF',6],['farmB',8]]) m[pt]=[...m[pt], prism(5.4,6.2, 0,1.9,1.9, 0,1.9,1.9, M.COAT,.28,pn)];   // 소매 끈
    return m; }
  if(k==='chicago'){ const m=suitModel({ suit:true, coat:M.SUIT, trou:M.SUIT, tie:'RED', hair:'fedora', hatMat:M.SUIT, bandMat:M.FRAME });
    const st=.34, S=M.FRAME;                                                                                   // 핀스트라이프: 몸보다 살짝 넓은 얇은 판을 일정 간격으로 → 옆면에 가는 줄
    m.torso=[...m.torso, ...[-2.8,-1.4,0,1.4,2.8].map(x=>prism(2,16.6, x,.07,7.56, x*.88,.07,5.76, S,st,2)),
      prism(10.4,11.4, 3.92,.25,2.6, 3.88,.25,2.2, M.GOLD,.82,2) ];                                             // 금 시곗줄
    for(const [pt,pn] of [['thighF',9],['thighB',11]]) m[pt]=[...m[pt], ...[-1.7,-.6,.6,1.7].map(x=>prism(-1,11, x,.06,2.82, x*.86,.06,2.52, S,st,pn))];
    for(const [pt,pn] of [['shinF',10],['shinB',12]]) m[pt]=[...m[pt], ...[-1.4,-.45,.45,1.4].map(x=>prism(0,11, x,.06,2.42, x*.875,.06,2.12, S,st,pn))];
    for(const [pt,pn] of [['uarmF',5],['uarmB',7]]) m[pt]=[...m[pt], ...[-1.2,0,1.2].map(x=>prism(-1,8, x,.06,2.42, x*.83,.06,2.12, S,st,pn))];
    for(const [pt,pn] of [['footF',10],['footB',12]]) m[pt]=[...m[pt], prism(-2.5,-.3, 1.3,4.12,2.14, 1.5,4.22,2.16, M.FRAME,.72,pn)];   // 흰 각반(스패츠)
    return m; }
  return JW_BASE_MODEL; }
const SKIN_CACHE={};
function skinGesture(){ const Hh=GS.hero; if(!Hh||Hh.dead||!Hh.d||!Hh.d.jw) return; if(Hh.anim==='idle'||Hh.anim==='walk') setAnim(Hh,'gx_'+((typeof OPT!=='undefined'&&OPT.skin)||'jw')); }
function skTone(f0,f1,d,type,v){ try{ if(!SND.ctx||SND.muted||!SND.sfx) return; const c=SND.ctx, t=c.currentTime, o=c.createOscillator(), g=c.createGain(); o.type=type; o.frequency.setValueAtTime(f0,t); o.frequency.exponentialRampToValueAtTime(f1,t+d); g.gain.setValueAtTime(v,t); g.gain.exponentialRampToValueAtTime(.0005,t+d); o.connect(g); g.connect(SND.sfx); o.start(t); o.stop(t+d+.02); }catch(e){} }
function skNoise(d,f,g){ try{ if(!SND.ctx||SND.muted||!SND.sfx||!SND.noise) return; const c=SND.ctx, t=c.currentTime, s=c.createBufferSource(), bp=c.createBiquadFilter(), gn=c.createGain(); s.buffer=SND.noise; bp.type='bandpass'; bp.frequency.value=f; bp.Q.value=1.2; gn.gain.setValueAtTime(g,t); gn.gain.exponentialRampToValueAtTime(.0005,t+d); s.connect(bp); bp.connect(gn); gn.connect(SND.sfx); s.start(t); s.stop(t+d+.02); }catch(e){} }
function skinFlair(T){ const k=(typeof OPT!=='undefined'&&OPT.skin)||'jw'; if(k==='jw'||!T||!T.d) return; const x=T.d.x, y=T.d.y-34-(T.jug?T.jug.h:0), acc=SKINS[k].acc;   // 콤보 마무리: 스킨마다 손맛
  if(k==='gala'){ HITFX.push({ k:'sk_glint', x, y, t:0, life:.75, c:acc, P:Array.from({length:14},()=>({ a:Math.random()*6.283, v:22+Math.random()*40, s:1+Math.random()*1.4 })) }); skTone(1500,2200,.07,'sine',.05); setTimeout(()=>skTone(2700,2650,.14,'triangle',.035),70); }
  if(k==='rain'){ HITFX.push({ k:'sk_rain', x, y, t:0, life:.8 }); skNoise(.55,130,.14); if(!OPT.noFlash) HITFX.push({ k:'sig_flash', x, y, t:0, life:.16 }); }
  if(k==='chicago'){ HITFX.push({ k:'sk_glint', x, y, t:0, life:.5, c:acc, P:Array.from({length:10},()=>({ a:Math.random()*6.283, v:30+Math.random()*50, s:1.2 })) }); for(let i=0;i<4;i++) setTimeout(()=>skNoise(.045,1900,.1), i*70); } }
// 스킨 미리보기: 위는 스튜디오(배경 · HUD 없이 주인공만, 2.6배), 아래는 스킨 목록 — 서기 → 좌우로 걷기 → 제스처 → 360° 돌려 보기 → 돌려차기
let pvBoxEl=null; const pvBox=()=>pvBoxEl||(pvBoxEl=(()=>{ const d=document.createElement('div'); d.className='skpv'; d.hidden=true;
  d.innerHTML='<div class="skpv-head"><b class="skpv-t"></b><button type="button" class="skpv-x"></button></div><div class="skpv-row"></div><div class="skpv-feat"></div>';
  ['pointerdown','touchstart','mousedown'].forEach(t=>d.addEventListener(t,e=>e.stopPropagation()));
  d.addEventListener('click',e=>{ const b=e.target.closest('[data-pvskin]'); if(b){ sfx.click(); applySkin(b.dataset.pvskin); skinPvRender(); if(GS.skinPv){ GS.skinPv.t=0; GS.skinPv.ph=-1; } return; } if(e.target.closest('.skpv-x')){ sfx.click(); skinPvClose(); } });
  return d; })());
function skinPvPlace(){ const d=pvBox(), dev=document.getElementById('device'), port=document.body.classList.contains('portrait') && dev && dev.contains(stage);   // 세로 화면: 게임 화면 아래(가방 자리)를 통째로
  const host=port?dev:stage; if(d.parentElement!==host) host.appendChild(d);
  if(port){ const dr=dev.getBoundingClientRect(), sr=stage.getBoundingClientRect(); d.classList.add('dock'); d.style.top=Math.round(sr.bottom-dr.top)+'px'; } else { d.classList.remove('dock'); d.style.top=''; } }
function skinPvRender(){ const k=OPT.skin||'jw', S=SKINS[k], d=pvBox(); d.querySelector('.skpv-t').textContent=tr('스킨'); d.querySelector('.skpv-x').textContent=tr('닫기');
  d.querySelector('.skpv-row').innerHTML=Object.entries(SKINS).map(([kk,Q])=>`<button type="button" data-pvskin="${kk}" class="${k===kk?'on':''}"><span class="sk-sw">${Q.sw.map(c=>`<i style="background:${c}"></i>`).join('')}</span><b>${tr(Q.n)}</b><small>${tr(Q.sub)}</small><em class="${Q.free?'free':''}">${k===kk?tr('착용 중'):Q.free?tr('기본'):tr('유료')}</em></button>`).join('');
  d.querySelector('.skpv-feat').innerHTML=`<b>${tr(S.n)}</b><span>${tr(S.free?'기본 스킨':'유료 스킨 · 시험 기간 무료 착용')}</span><ul><li>${tr('전용 옷 · 컷인 초상화')}</li><li>${tr('제스처')} · ${tr(S.gx)}</li><li>${tr('마무리 연출')} · ${tr(S.fl)}</li></ul>`; }
function skinPvOpen(){ if(gOverlay.dataset.menu==='1') closeMenu(); else gOverlay.hidden=true;   // 메뉴는 제대로 닫아 일시정지를 푼다
  if(!GS.on || !GS.hero) jumpTo('dojo'); const Hh=GS.hero; if(!Hh) return; if(GS.talk) tkSkip();
  const fromTitle=!titleEl.hidden; if(fromTitle){ titleEl.hidden=true; sndInit(); setGameSpeed(GAME_SPD); }   // 타이틀에서 열면 잠시 걷어 낸다
  GS.skinPv={ t:0, ph:-1, x:Hh.d.x, y:Hh.d.y, flip:Hh.d.flip, wpn:Hh.wpn, fromTitle, fade:GS.fade||0, hid:GS.ents.filter(a=>a!==Hh && !a.hidden), cx:Math.round(W/2) }; Hh.wpn=null;
  GS.skinPv.hid.forEach(a=>a.hidden=true); Hh.d.flip=false; Hh.d.x=GS.skinPv.cx; Hh.d.y=Math.round(H*.47+34); setAnim(Hh,'idle');   // 배경이 없으니 화면 가운데로 올려 세운다
  sayEl.hidden=true; skinPvRender(); skinPvPlace(); pvBox().hidden=false; stage.classList.add('pv-on'); }
