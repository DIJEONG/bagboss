// =========================================================
// 처음 하는 사람 안내(상황이 처음 생길 때 한 번) · 이어 하기(칸마다 자동 저장)
// =========================================================
const HINTS={
  tower:['엘리베이터 타워','적이 너무 많이 타면 정원 초과로 문이 안 닫혀요 — 문이 열린 동안 밖으로 날려 보내면 빨라요. 띄우기 기술은 천장에 튕겨 떨어져요'],
  move:['직접 조작','화면 왼쪽·오른쪽을 누르면 그쪽으로 공격, 아래쪽은 피하기 — 가만히 두면 알아서 싸워요'],
  bag:['서류가방 정리','끌어 놓으면 화력 변화가 미리 보여요 · ↻ 돌리기 · ↶ 되돌리기 · 같은 ★끼리 겹치면 합성'],
  link:['연계 발동','닿아 있는 기술의 조합이 맞으면 바로 이어서 나가요 — 서류가방에서 서로 붙여 두세요'],
  sp:['필살기 준비','급행 게이지가 찼어요 — 오른쪽 아래 필살 버튼(스페이스)'],
  timer:['시간제 운행','다음 역에 닿기 전에 칸을 정리하면 정시 보너스와 매점이 열려요'],
  boss:['두목','체력이 절반 아래로 떨어지면 분노해서 공격이 빨라져요'],
  heavy:['무거운 공격','머리 위 빨간 !!는 무거운 공격이에요 — 쭈그리면 피하고 빈틈을 만들어요(다음 한 방 +50%)'],
  just:['저스트 받아치기','적 머리 위 고리가 작아져 하얗게 빛나는 순간 그쪽 화면을 누르면 저스트 받아치기 — 빨간 고리는 아래쪽을 눌러 숙여요'] };
function hint(k){ META.hints=META.hints||{}; if(META.hints[k] || !HINTS[k] || GS.cine || GS.bonus || GS.pBag || GS.kane) return false;   /* 콤보 쇼 · 케인 장면 동안엔 도움말을 미룬다 */ META.hints[k]=1; metaDirty=true; metaSave();
  const [t,b]=HINTS[k]; setTimeout(()=>{ say('도움말 · '+t, b, 4.2); },400); return true; }
const RUN_KEY='dotlab-run-v1';
const hasPro=()=>GS.bag.some(b=>GITEMS[b.id]&&GITEMS[b.id].pro), restoreKit=()=>{ if(hasPro() && GS.pKit){ GS.bag=GS.pKit.map(b=>({...b})); renderBag(); } };
function saveRun(){ try{ if(!GS.on || GS.state==='over' || !GS.hero || GS.devRun || GS.demo || GS.tower) return; localStorage.setItem(RUN_KEY, JSON.stringify({ v:1, at:Date.now(), cfg:RUNCFG, stageIdx:GS.stageIdx||0, ci:GS.ci||0,
    bag:hasPro()&&GS.pKit?GS.pKit:GS.bag, stash:GS.stash, tokens:GS.tokens, score:GS.score, hp:GS.hp, sp:GS.sp||0, kills:GS.kills||0, stats:GS.stats, bonusDone:!!GS.bonusDone, bonusSt:GS.bonusSt||{}, imprints:GS.imprints||{} })); }catch(e){} }
const loadRunSave=()=>{ try{ const s=JSON.parse(localStorage.getItem(RUN_KEY)||'null'); return s&&s.v===1?s:null; }catch(e){ return null; } };
const clearRunSave=()=>{ try{ localStorage.removeItem(RUN_KEY); }catch(e){} };
function resumeRun(S){ hideTitle(true); GS.resuming=true; startRun({...(S.cfg||{})}); GS.resuming=false;
  if((S.stageIdx||0)>0) loadStage(S.stageIdx);
  GS.bag=S.bag||[]; GS.stash=S.stash||[]; GS.tokens=S.tokens||0; if(S.imprints) GS.imprints=S.imprints; GS.score=S.score||0; GS.kills=S.kills||0; GS.stats={...GS.stats,...(S.stats||{})}; GS.bonusDone=!!S.bonusDone; GS.bonusSt=S.bonusSt||(S.bonusDone?{1:true}:{}); GS.sp=S.sp||0;
  fitBag(); GS.undo=[]; GS.max=heroMax(); GS.hp=Math.max(1,Math.min(GS.max,S.hp||GS.max));
  if((S.ci||0)>0){ GS.ci=S.ci-1; GS.ents=GS.ents.filter(a=>!a.e); GS.atStop=(LINE[S.ci-1]||{}).stop||START_STOP; GS.stationDone=S.ci-1; GS.adA=null; GS.outS=null; startBoard(); }   // 이어 하기: 직전 호차가 도착한 역에서 다음 호차를 탄다(첫 역 배경으로 돌아가지 않게)
  renderBag(); setGameSpeed(GAME_SPD); say('이어 하기', `${STAGES[S.stageIdx||0].name} · ${(S.ci||0)+1}호차부터`, 2.6); sfx.chime(); }

