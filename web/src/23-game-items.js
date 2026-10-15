/* =========================================================
   11-e. 게임 한 판: 지하철 방치형 액션 × 가방 문법
   기본은 혼자 싸우고, 화면 왼쪽/오른쪽을 누르면 그 순간만 직접 조작(즉시 공격 · 카운터 · 대시 · 병 쳐내기)
   ========================================================= */
// 아이템: 기술은 쿨다운 + 발동 조건(cond). 조건이 있는 기술은 쿨다운이 차도 상황이 맞을 때까지 기다린다
// 밸런스 기준: 조건 없는 기본기 초당 5~7, 조건 기술은 그 순간 한 방이 크다(조건이 걸리는 빈도로 상쇄)
const GITEMS={
  punch:{ n:'주먹 콤보', icon:'punch', fam:'fist', shape:[[0,0],[0,1]], kind:'skill', fist:true, dmg:6, cd:.9, anim:'jab', cue:'m_jab', reach:24, combo:true, desc:'잽 → 원투 → 훅 → 어퍼컷으로 이어지는 기본 연타' },
  paper:{ n:'말아 쥔 신문', icon:'paper', fam:'fist', shape:[[0,0],[0,1]], kind:'skill', fist:true, dmg:5, cd:.65, anim:'swat', cue:'np_hit', reach:28, wpn:'w_paper', react:'head', desc:'가볍고 빠른 찰싹. 연타를 쌓기 좋아요' },
  umb:{ n:'장우산', icon:'umb', shape:[[0,0],[1,0],[0,1]], kind:'skill', dmg:12, cd:1.6, anim:'uthrust', cue:'ut_hit', reach:40, wpn:'w_umb', react:'head', block:true, desc:'멀리서 찔러요. 날아오는 병을 60% 확률로 막아요' },
  case:{ n:'서류가방', icon:'case', shape:[[0,0],[1,0],[0,1],[1,1]], kind:'skill', dmg:16, cd:3.0, anim:'bat', cue:'batS', reach:32, area:true, knock:true, wpn:'w_case', desc:'앞쪽 모두를 후려쳐 넘어뜨려요' },
  kick:{ n:'앞차기', icon:'kick', fam:'foot', shape:[[0,0],[0,1],[1,1]], kind:'skill', dmg:12, cd:2.6, anim:'kick', cue:'m_kick', reach:30, knock:true, desc:'밀어 넘어뜨려요. 열린 문 쪽이면 밖으로 날려요' },
  knee:{ n:'니킥', icon:'knee', fam:'grap', shape:[[0,0],[0,1]], kind:'skill', dmg:11, cd:2.0, anim:'knee', cue:'n_hit', reach:17, react:'body', desc:'바짝 붙어 무릎을 꽂아요. 몸을 꺾어 잠깐 묶어 둬요' },
  elbow:{ n:'팔꿈치 받아치기', icon:'elbow', fam:'fist', shape:[[0,0],[1,0],[1,1]], kind:'skill', fist:true, cond:'counter', dmg:14, cd:1.6, anim:'elbow', cue:'e_hit', reach:26, react:'body', crit:true, stun:1.0, desc:'적이 치려는 순간 먼저 꽂아요. 반드시 치명타 + 1초 경직' },
  round:{ n:'돌려차기', icon:'round', fam:'foot', shape:[[0,0],[1,0],[2,0],[1,1]], kind:'skill', cond:'combo', dmg:22, cd:3.0, anim:'round', cue:'rh', reach:32, area:true, knock:true, desc:'연타 끝의 마무리 발차기. 앞쪽 모두 넘어뜨려요' },
  upper:{ n:'어퍼컷', icon:'upper', fam:'fist', shape:[[0,0],[0,1],[0,2]], kind:'skill', fist:true, cond:'finish', dmg:26, cd:2.6, anim:'upper', cue:'up', reach:20, react:'launch', desc:'빈사의 적을 공중으로 띄워요' },
  sweep:{ n:'다리걸기', icon:'sweep', fam:'foot', shape:[[0,0],[1,0],[2,0]], kind:'skill', cond:'multi', dmg:8, cd:3.2, anim:'sweep', cue:'sw_hit', reach:34, area:true, react:'sweep', low:true, desc:'둘 이상 붙으면 낮게 쓸어 모두 넘어뜨려요' },
  charge:{ n:'어깨 돌진', icon:'charge', fam:'grap', shape:[[0,0],[0,1],[1,1],[2,1]], kind:'skill', dmg:16, cd:3.2, anim:'charge', cue:'ch_hit', reach:22, knock:true, desc:'몸을 던져 어깨로 들이받아요. 붙어 있는 적을 밀어 넘어뜨려요' },
  throw:{ n:'잡아 메치기', icon:'throw', fam:'grap', shape:[[0,0],[1,0],[2,0],[1,1],[1,2]], kind:'skill', cond:'grab', dmg:24, cd:4.5, anim:'throw', cue:'gr_hold', reach:20, desc:'붙잡아 머리 위로 들었다가 앞으로 내리꽂아요. 떨어진 자리 주변도 피해를 입어요' },
  stomp:{ n:'밟기', icon:'stomp', fam:'foot', shape:[[0,0],[0,1]], kind:'skill', cond:'down', dmg:12, cd:1.0, anim:'stomp', cue:'st_hit', reach:32, desc:'쓰러진 적을 밟아 더 오래 눕혀 둬요' },
  duck:{ n:'쭈그리기', icon:'duck', shape:[[0,0]], kind:'dodge', cond:'proj', cd:2.4, desc:'머리 높이로 날아오는 물건을 쭈그려 피해요. 직접 조작: ↓ 또는 화면 아래쪽' },
  bkick:{ n:'뒤차기', icon:'kick', fam:'foot', shape:[[0,0],[1,0],[2,0],[2,1]], kind:'skill', cond:'back', back:true, dmg:18, cd:2.6, anim:'bkick', cue:'bk_hit', reach:30, knock:true, desc:'앞을 본 채 뒤의 적을 걷어차 넘어뜨려요' },
  bfist:{ n:'백피스트', icon:'punch', fam:'fist', shape:[[0,0],[1,0],[1,1]], kind:'skill', cond:'back', back:true, dmg:12, cd:1.6, anim:'bfist', cue:'bf_hit', reach:24, react:'head', desc:'몸을 비틀어 등 뒤의 적을 주먹 등으로 쳐요' },
  pin:{ n:'넥타이핀', icon:'charm', shape:[[0,0]], kind:'crit', desc:'닿은 기술의 치명타 확률 +12% (등급마다 +4%p)' },
  ring:{ n:'인장 반지', icon:'charm', shape:[[0,0]], kind:'critd', desc:'닿은 기술의 치명타 피해 +40% (등급마다 +15%p)' },
  charm:{ n:'행운 부적', icon:'charm', shape:[[0,0]], kind:'gem', desc:'상하좌우로 붙은 기술 피해 +25% (등급마다 +8%p)' },
  coffee:{ n:'캔커피', icon:'coffee', shape:[[0,0]], kind:'stone', desc:'상하좌우로 붙은 기술 쿨다운 −18% (등급마다 −5%p)' },
  knuckle:{ n:'너클', icon:'knuckle', shape:[[0,0],[1,0]], kind:'knuckle', desc:'주먹 기술(주먹 콤보 · 신문 · 팔꿈치 · 어퍼컷) 피해 +25%' },
  gum:{ n:'풍선껌', icon:'gum', shape:[[0,0]], kind:'gum', desc:'연타가 1.5초 더 이어지고, 콤보 조건이 2연타로 줄어요' },
  coat:{ n:'두꺼운 코트', icon:'coat', shape:[[0,0],[1,0],[0,1],[1,1],[0,2],[1,2]], kind:'armor', desc:'최대 체력 +30, 받는 피해 -10%' },
  shoes:{ n:'운동화', icon:'shoes', shape:[[0,0],[1,0]], kind:'shoes', desc:'이동 속도 +30%, 모든 쿨다운 -10%' },
  earph:{ n:'이어폰', icon:'earph', shape:[[0,0]], kind:'ear', desc:'직접 조작 카운터 판정 시간 +60%, 받아치기 사거리 +6px' },
  bandage:{ n:'반창고', icon:'bandage', shape:[[0,0]], kind:'heal', heal:18, cd:10, desc:'체력이 50% 아래면 10초마다 18 회복' },
  fkick:{ n:'날아차기', icon:'kick', fam:'foot', shape:[[0,0],[1,0],[2,0]], kind:'skill', cond:'gap', dmg:22, cd:4.2, anim:'fkick', cue:'fk_hit', reach:28, knock:true, desc:'40~110px 떨어진 적에게 낮게 날아들어 차요. 천장 손잡이 아래로 깔리는 궤적 · 맞으면 넘어뜨려요' },
  cycle:{ n:'공중 자전거 차기', icon:'kick', fam:'foot', shape:[[0,0],[1,0],[0,1]], kind:'skill', cond:'air', dmg:8, cd:2.6, anim:'cycle', cue:'cy_k1', reach:24, desc:'떠 있는 적을 따라 뛰어올라 두 다리를 번갈아 굴리며 3번 차요. 맞은 적은 계속 떠 있어요' },
  axe:{ n:'도끼 차기', icon:'kick', fam:'foot', shape:[[0,0],[0,1],[0,2],[1,2]], kind:'skill', dmg:24, cd:3.6, anim:'axe', cue:'ax_hit', reach:22, desc:'다리를 수직으로 들어 올렸다가 발뒤꿈치로 내리찍어요. 떠 있든 서 있든 얼굴부터 바닥에 꽂혀 살짝 튕긴 뒤 엎어져요' },
  suplex:{ n:'저먼 수플렉스', icon:'throw', fam:'grap', shape:[[0,0],[1,0],[0,1],[1,1]], kind:'skill', cond:'grab', dmg:30, cd:5.0, anim:'suplex', cue:'sx_grab', reach:18, desc:'허리를 붙잡아 몸을 활처럼 뒤로 젖히며 머리부터 뒤쪽 바닥에 꽂아요. 떨어진 자리 주변 적도 휘말려요' },
  renkan:{ n:'연환퇴', icon:'kick', fam:'foot', shape:[[1,0],[0,1],[1,1],[0,2]], kind:'skill', dmg:10, cd:3.0, anim:'renkan', cue:'rk_k1', reach:22, react:'pop', desc:'뛰어오르며 앞다리로 한 번 차 살짝 띄우고, 공중에서 다리를 바꿔 뒷다리로 차올려 높이 띄워요' },
  tetsu:{ n:'철산고', icon:'charge', fam:'grap', shape:[[1,0],[0,1],[1,1],[2,1]], kind:'skill', dmg:30, cd:5.0, anim:'tetsu', cue:'ts_hit', reach:22, knock:true, desc:'반 보 물러섰다가 앞발로 바닥을 쾅 내리밟으며(진각) 등과 어깨로 들이받아요. 맞은 적은 일직선으로 멀리 날아가 뒤쪽 적까지 쓰러뜨려요' },
  skick:{ n:'섬머솔트 킥', icon:'kick', fam:'foot', shape:[[0,0],[0,1],[0,2]], kind:'skill', dmg:20, cd:3.4, anim:'skick', cue:'sk_kick', reach:26, area:true, react:'launch', desc:'몸을 뒤로 뒤집으며 초승달 궤적으로 차올려요. 앞의 적을 모두 띄우고, 떠 있는 적은 다시 띄워요' },
  metro:{ n:'메트로카드', icon:'charm', shape:[[0,0]], kind:'metro', desc:'위·아래로 닿은 기술 쿨다운 −12% (등급마다 −3%p)' },
  cuff:{ n:'커프스 단추', icon:'charm', shape:[[0,0]], kind:'cuff', desc:'대각선으로 닿은 기술 치명 확률 +10%p (등급마다 +3%p)' },
  watch:{ n:'손목시계', icon:'charm', shape:[[0,0],[1,0]], kind:'watch', desc:'왼쪽 끝에 닿은 기술이 적중하면 오른쪽 끝에 닿은 기술의 쿨다운 30% 충전 (등급마다 +5%p)' },
  // 지하 복도 전용: 장도리 네 수(올려 → 옆 → 되돌려 → 내려찍기). 손에 든 장도리와 가방 칸이 같은 동작을 보여 준다
  hmup:  { n:'장도리 올려치기', sn:'올려치기', icon:'punch', shape:[[0,0],[0,1]], kind:'skill', pro:true, fcol:'#b8c4d0', dmg:12, cd:2.4, anim:'hm_up', cue:'hm_uhit', reach:22, react:'launch', wpn:'w_hammer', desc:'장도리를 아래에서 위로 걷어 올려 적을 띄워요' },
  hmswing:{ n:'장도리 옆치기', sn:'옆치기', icon:'punch', shape:[[0,0],[1,0]], kind:'skill', pro:true, fcol:'#b8c4d0', dmg:7, cd:1.0, anim:'hm_swing', cue:'hm_hit', reach:30, wpn:'w_hammer', desc:'옆으로 크게 휘둘러요. 떠 있는 적은 계속 떠 있어요' },
  hmback:{ n:'장도리 되치기', sn:'되치기', icon:'punch', shape:[[0,0]], kind:'skill', pro:true, fcol:'#b8c4d0', dmg:7, cd:1.2, anim:'hm_back', cue:'hm_bhit', reach:28, wpn:'w_hammer', desc:'휘두른 장도리를 되돌려 한 번 더 쳐요' },
  hmdown:{ n:'장도리 내려찍기', sn:'내려찍기', icon:'punch', shape:[[0,0],[0,1],[1,1]], kind:'skill', pro:true, fcol:'#b8c4d0', dmg:16, cd:3.0, anim:'hm_down', cue:'hm_dhit', reach:26, knock:true, wpn:'w_hammer', desc:'머리 위에서 내려찍어요. 떠 있든 서 있든 바닥에 처박혀요' },
};
const REAL_ITEMS=()=>Object.keys(GITEMS).filter(k=>!GITEMS[k].pro);
const COND={
  gap:    { tag:'거리', ko:'적과 30~120px 벌어졌을 때 (달려들며 친다)' },
  down:   { tag:'다운', ko:'넘어지는 중이거나 쓰러진 적이 가까이 있을 때' },
  multi:  { tag:'다수', ko:'적이 둘 이상 붙었을 때' },
  combo:  { tag:'콤보', ko:'3연타 이상 이어지는 중일 때 (풍선껌이 있으면 2연타)' },
  finish: { tag:'마무리', ko:'목표 체력이 35% 이하일 때' },
  counter:{ tag:'반격', ko:'적이 공격을 준비하는 순간 · 맞은 직후' },
  grab:   { tag:'잡기', ko:'바로 붙어 있고, 덩치 · 두목이 아닐 때' },
  proj:   { tag:'투척', ko:'머리 높이로 물건이 날아올 때' },
  back:   { tag:'뒤', ko:'앞을 보는 채로 등 뒤에 적이 붙었을 때' },
  air:    { tag:'공중', ko:'떠 있는 적이 가까이 있을 때 (따라 뛰어올라 찬다)' },
};
const behindOf=(H,a)=>(a.d.x-H.d.x)*(H.d.flip?-1:1)<-4;                                       // 등 뒤(지금 보는 방향의 반대쪽)
const isDown=a=> FALLS.has(a.anim) && ['kd3','kd4','kd5','stp0','slm0','sp_hit','sp_bounce','sp_land','sp_lie'].includes(a.pose);
const isFalling=a=> FALLS.has(a.anim) && !a.held;   // 밟기: 넘어지는 동작 전체(눕기 전부터)
const comboWin=()=>2.2+pv('gum',1.5,.3);
function condOK(cond,H,T,F){ if(!cond) return true; const d=T?Math.abs(T.d.x-H.d.x):999;
  switch(cond){
    case 'gap': return !!T && d>=30 && d<=120;
    case 'down': return F.some(a=>isFalling(a)&&Math.abs(a.d.x-H.d.x)<=70) || (bagHasLink('gbounce') && F.some(a=>a.jug && !a.jug.gb && a.jug.h<34 && a.jug.vy<0 && Math.abs(a.d.x-H.d.x)<=60));   // 넘어지는 중 · 누운 적 · (바닥 튕기기) 떨어지는 공중의 적
    case 'multi': return F.filter(a=>!isDown(a)&&Math.abs(a.d.x-H.d.x)<=48).length>=2;
    case 'combo': return GS.combo>=(has('gum')?2:3) && GS.time-GS.lastHit<comboWin();
    case 'finish': return !!T && T.e.hp<=T.e.max*.35;
    case 'counter': return !!T && d<=30+pv('ear',6,2) && ((!!T.action && !T.action.fired) || GS.time-(GS.hurtAt??-9)<.5);   // 공격 준비 순간 또는 맞은 직후 0.5초
    case 'air': return !!T && !!T.jug && T.jug.h>4 && d<=44;   // 공중 자전거 차기: 떠 있는 적
    case 'grab': return !!T && d<=28 && !T.e.heavy && !T.held && !isDown(T);
    case 'back': return F.some(a=>!isDown(a)&&!a.held&&behindOf(H,a)&&Math.abs(a.d.x-H.d.x)<=40);
    case 'proj': return GS.shots.some(s=>!s.dead&&!s.dodged&&Math.sign(H.d.x-s.x)===Math.sign(s.vx)&&Math.abs(s.x-H.d.x)<130);
  } return true; }
const ETYPES={
  punk:{ n:'불량배', hp:26, dmg:6, cd:2.0, spd:34, remap:5, moves:['jab','hook','kick'], reach:24 },
  rusher:{ n:'돌진꾼', hp:30, dmg:9, cd:2.4, spd:34, dash:88, remap:6, moves:['hbutt','hbutt','hook','charge'], reach:20 },
  thrower:{ n:'병 던지는 놈', hp:22, dmg:7, cd:3.0, spd:30, remap:7, range:120, moves:['throw'], reach:24 },
  guard:{ n:'우산 든 놈', hp:34, dmg:7, cd:2.4, spd:28, remap:5, moves:['jab','hook'], wpn:'w_umb', reach:30, shield:true },
  heavy:{ n:'덩치', hp:70, dmg:12, cd:3.0, spd:22, remap:8, moves:['bat','kick'], wpn:'w_case', reach:30, heavy:true, grammar:{pre:7,hit:1,stop:5,fol:3,rec:4} },
  brute:{ n:'배불뚝이', hp:95, dmg:13, cd:3.0, spd:20, remap:8, moves:['charge','hook'], reach:26, heavy:true, look:{fat:true, hair:'bald', coat:'COAT'} },
  slasher:{ n:'칼잡이', hp:34, dmg:12, cd:2.6, spd:34, remap:7, moves:['jab','hook'], wpn:'w_knife', reach:26, look:{hair:'bandana', coat:'SUIT'} },
  weasel:{ n:'얍삽한 놈', hp:26, dmg:7, cd:1.8, spd:46, remap:6, moves:['jab','kick'], reach:24, evade:.4, hitrun:true, look:{hair:'pomp', coat:'COAT'} },
  gear:{ n:'기어단', hp:34, dmg:8, cd:2.2, spd:32, remap:5, moves:['jab','hook','kick'], reach:24, look:{hair:['goggle','mohawk','tophat'], coat:'WOODD'} },
  boss2:{ n:'기어단 두목', hp:260, dmg:16, cd:2.6, spd:26, remap:8, moves:['bat','round','upper','charge'], wpn:'w_wrench', reach:32, boss:true, heavy:true, look:{hair:'tophat', coat:'WOODD', fat:true} },
  kane:{ n:'빅터 케인', hp:9999, dmg:0, cd:99, spd:30, remap:3, moves:['jab'], reach:26, wpn:'w_umb', look:{hair:'pomp', coat:'BONE', tie:'RED'} },   // 배신자 · 흰 양복 · 지팡이
  stick:{ n:'막대기 패거리', hp:22, dmg:6, cd:2.2, spd:40, remap:3, moves:['jab','hook','bat'], reach:26, wpn:'it_bat', look:{coat:'COAT'} },
  pipe:{ n:'쇠파이프', hp:28, dmg:8, cd:2.5, spd:34, remap:4, moves:['hook','jab','bat'], reach:28, wpn:'w_wrench', look:{coat:'STEEL'} },
  triad:{ n:'청룡방 조직원', hp:34, dmg:8, cd:2.0, spd:34, remap:5, moves:['jab','hook','kick','round'], reach:24, look:{coat:'SUIT', tie:'RED'} },
  kungfu:{ n:'권법가', hp:38, dmg:9, cd:1.6, spd:42, remap:6, moves:['kick','round','jab','fkick'], reach:28, shield:true, parry:true, look:{coat:'MDARK', mandarin:true, hair:'bald'} },
  swords:{ n:'쌍도객', hp:36, dmg:14, cd:2.4, spd:38, remap:7, moves:['jab','hook'], wpn:'w_knife', reach:26, look:{coat:'RED', mandarin:true} },
  bguard:{ n:'경호원', hp:110, dmg:14, cd:3.0, spd:20, remap:8, moves:['charge','hook'], reach:26, heavy:true, look:{fat:true, hair:'bald', coat:'SUIT', tie:'RED'} },
  boss3:{ n:'청룡방 두목', hp:300, dmg:17, cd:2.2, spd:32, remap:8, moves:['round','kick','upper','charge'], reach:32, boss:true, heavy:true, shield:true, parry:true, look:{coat:'FRAME', mandarin:true} },
  pick:{ n:'소매치기', hp:20, dmg:5, cd:1.6, spd:46, remap:6, moves:['jab','kick'], reach:24, hitrun:true },
  blade:{ n:'칼잡이', hp:32, dmg:10, cd:3.4, spd:32, remap:7, moves:['jab','hook'], wpn:'w_knife', reach:26 },
  boss:{ n:'기관실 두목', hp:220, dmg:15, cd:2.7, spd:28, remap:8, moves:['bat','round','upper'], wpn:'w_wrench', reach:32, boss:true, heavy:true, grammar:{pre:8,hit:1,stop:6,fol:3,rec:4} },
  // 4스테이지 · 7 열차: 가상의 폭주족 '네온 바이퍼스'
  skater:{ n:'롤러 폭주족', hp:24, dmg:7, cd:1.8, spd:52, dash:96, remap:6, moves:['jab','kick','hbutt'], reach:24, hitrun:true, look:{hair:'goggle', coat:'NEONP'} },
  batter:{ n:'방망이패', hp:32, dmg:10, cd:2.6, spd:32, remap:6, moves:['bat','jab','hook'], wpn:'it_bat', reach:28, look:{hair:'crop', coat:'NEONT'} },
  neonbig:{ n:'네온 덩치', hp:90, dmg:13, cd:3.0, spd:22, remap:8, moves:['charge','hook'], reach:26, heavy:true, look:{fat:true, hair:'mohawk', coat:'NEONP'} },
  boss4:{ n:'바이퍼 두목', hp:230, dmg:16, cd:2.3, spd:34, dash:110, remap:8, moves:['fkick','round','upper','charge'], reach:32, boss:true, heavy:true, look:{hair:'pomp', coat:'NEONP', tie:'NEONT'} },
  // 5스테이지 · L 열차: 클럽 조직 '언더그라운드' · 최종 두목 빅터 케인
  bouncer:{ n:'클럽 문지기', hp:105, dmg:14, cd:3.0, spd:20, remap:8, moves:['charge','hook'], reach:26, heavy:true, look:{fat:true, hair:'bald', coat:'MDARK'} },
  punkg:{ n:'기타 펑크', hp:32, dmg:11, cd:2.6, spd:32, remap:7, moves:['bat','jab'], wpn:'w_guitar', reach:28, look:{hair:'mohawk', coat:'STEEL'} },
  breaker:{ n:'브레이커', hp:28, dmg:8, cd:1.7, spd:46, remap:6, moves:['round','kick','fkick'], reach:26, evade:.45, look:{hair:'bandana', coat:'NEONT'} },
  kaneB:{ n:'빅터 케인', hp:240, dmg:17, cd:2.0, spd:34, remap:8, moves:['jab','hook','round','upper','charge'], wpn:'w_umb', reach:30, boss:true, parry:true, look:{hair:'pomp', coat:'BONE', tie:'RED'} },
};
