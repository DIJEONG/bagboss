// 노선: 칸 여섯 개, 둘째·넷째 칸 뒤에 정차역. 칸마다 웨이브 목록
// D 급행 업타운: 애틀랜틱 애비뉴 → (디캘브 통과) → 맨해튼 다리(실외 · 노을 · 브루클린 다리) → 그랜드 스트리트 → 6번가선 → 59번가부터 CPW 급행
// quick = 짧게 서는 역 [역, 출발점에서의 거리, 타는 적]. 승객이 내리고 탄다
const LINE_D=[
  { car:0, waves:[['punk','punk','pick'],['punk','rusher','punk'],['rusher','pick','punk'],['punk','pick','rusher'],['rusher','punk','punk','pick']],                    stop:'grand', bridge:{b0:1400,len:10000}, passes:[], shop:true },
  { car:1, waves:[['pick','thrower','punk'],['rusher','punk','thrower'],['punk','punk','rusher']],         stop:'w4',    quick:[['bwl',3600,['pick','punk']]], fight:['punk','rusher'] },
  { car:2, waves:[['guard','punk','punk'],['guard','rusher','punk'],['thrower','guard','pick']],          stop:'s34h',  passes:[['s14f',2400],['s23f',5200]], shop:true },
  { car:13, waves:[['blade','punk','punk'],['pick','punk','punk'],['heavy','punk','pick']],                     stop:'s42b',  passes:[], fight:['blade','thrower'] },
  { car:3, waves:[['heavy','punk','punk'],['heavy','thrower','pick'],['rusher','blade','punk']],          stop:'s59',   quick:[['s47',3000,['blade','punk']],['s7a',6600,[]]], shop:true },
  { car:4, waves:[['rusher','rusher','guard'],['heavy','thrower','blade'],['rusher','punk','pick']],     stop:'s125', passes:[['s72',2200],['s81',4600],['s96',7000],['s110',9400]], fight:['guard','pick'], shop:true },
  { car:9, waves:[['boss','punk'],['blade','punk','rusher'],['thrower','pick','punk']],                          stop:'s145',  passes:[['s135',2600]], end:true },
];
const legMin=L=> Math.max(L.bridge ? L.bridge.b0+L.bridge.len+900 : 0, ...(L.quick||[]).map(q=>q[1]+900), 0);   // 이 거리 전에는 종착역에 들어가지 않는다

// 2스테이지: 4 열차 업타운(제롬 애비뉴 고가선, 밤). 실제로는 모든 역에 서는 완행 구간
const LINE_4=[
  { car:6, waves:[['weasel','punk','punk'],['brute','weasel','punk'],['gear','weasel','punk']],                  stop:'s170', quick:[['s167',3200,['weasel']]], shop:true },
  { car:7, waves:[['slasher','punk','weasel'],['brute','slasher','weasel'],['gear','gear','slasher']],          stop:'burn', quick:[['mteden',3000,['slasher']],['s176',6400,['gear']]], fight:['weasel','slasher'], shop:true },
  { car:8, waves:[['gear','gear','weasel'],['gear','brute','slasher'],['gear','gear','brute']],        stop:'ford', quick:[['s183',3400,['gear','gear']]], fight:['gear','weasel'], shop:true },
  { car:9, waves:[['boss2','gear'],['gear','weasel','slasher'],['brute','gear','gear']],                         stop:'wood', quick:[['kings',2600,[]],['bedpk',5200,['brute']],['mosh',7800,[]]], end:true },
];
// 3스테이지: 6 열차 다운타운(렉싱턴 애비뉴 완행) → 캐널 스트리트(차이나타운) → 종점 너머 옛 시티 홀 역
const LINE_6=[
  { car:10, waves:[['triad','triad','punk'],['triad','pick','triad'],['kungfu','triad','punk']],                stop:'s23l', quick:[['s33l',3000,['triad']],['s28l',6200,[]]], shop:true },
  { car:11, waves:[['triad','kungfu','triad'],['swords','triad','pick'],['kungfu','swords','triad']],           stop:'astor', quick:[['s14l',3400,['triad','triad']]], fight:['kungfu','triad'], shop:true },
  { car:12, waves:[['swords','swords','triad'],['bguard','kungfu','triad'],['kungfu','kungfu','swords']], stop:'canal', quick:[['bleecker',2800,['triad']],['spring',6000,['swords']]], fight:['bguard','swords'], shop:true },
  { car:9,  waves:[['boss3','kungfu'],['swords','triad','triad'],['bguard','kungfu','triad']],                   stop:'cityhall', quick:[['bbch',4000,['triad']]], end:true },
];
// 4스테이지: 7 열차 플러싱 고가선(퀸스, 네온). 퀸스보로 플라자 → 플러싱–메인 스트리트
const LINE_7=[
  { car:2,  waves:[['skater','punk','punk'],['batter','skater','punk'],['skater','skater','thrower']],             stop:'s46', quick:[['s33r',2600,['skater']],['s40',5400,[]]], shop:true },
  { car:6,  waves:[['batter','skater','weasel'],['neonbig','skater','punk'],['batter','batter','skater']],         stop:'woodside', quick:[['s52',3200,['batter']]], fight:['skater','batter'] },
  { car:14, waves:[['skater','skater','batter'],['neonbig','batter','skater'],['slasher','skater','batter']],      stop:'s74', quick:[['s69',3000,['skater','skater']]], shop:true },
  { car:15, waves:[['batter','thrower','skater'],['neonbig','skater','thrower'],['skater','batter','weasel']],     stop:'junction', quick:[['s82',2800,['batter']],['s90',5800,[]]], fight:['neonbig','skater'], shop:true },
  { car:1,  waves:[['neonbig','batter','skater'],['skater','skater','slasher'],['batter','neonbig','skater']],     stop:'s111', quick:[['s103',3400,['skater']]], shop:true },
  { car:14, waves:[['neonbig','neonbig','skater'],['batter','batter','slasher'],['skater','skater','neonbig']],    stop:'mets', quick:[], fight:['batter','neonbig'], shop:true },
  { car:9,  waves:[['boss4','skater'],['batter','skater','skater'],['neonbig','batter','skater']],                 stop:'flushing', quick:[], end:true },
];
// 5스테이지(최종): L 열차 캐너시선. 유니언 스퀘어 → 강 밑 터널 → 브루클린 창고 클럽 → 캐너시 종점 너머 지도에 없는 역
const LINE_L=[
  { car:17, waves:[['punkg','punk','punk'],['breaker','punkg','punk'],['punkg','breaker','pick']],                  stop:'s1av', quick:[['s3av',3000,['punkg']]], shop:true },
  { car:16, waves:[['breaker','breaker','punkg'],['bouncer','breaker','punk'],['punkg','punkg','breaker']],         stop:'bedford', passes:[], fight:['breaker','punkg'] },
  { car:4,  waves:[['bouncer','punkg','breaker'],['punkg','thrower','breaker'],['breaker','breaker','bouncer']],    stop:'montrose', quick:[['lorimer',2600,['breaker']],['graham',5000,[]],['grandl',7400,['punkg']]], shop:true },
  { car:16, waves:[['breaker','punkg','bouncer'],['bouncer','bouncer','breaker'],['punkg','breaker','slasher']],    stop:'jefferson', quick:[['morgan',3200,['breaker','punkg']]], fight:['bouncer','breaker'], shop:true },
  { car:5,  waves:[['punkg','breaker','breaker'],['bouncer','punkg','slasher'],['breaker','punkg','bouncer']],      stop:'myrtle', quick:[['dekalbl',3200,[]]], shop:true },
  { car:18, waves:[['bouncer','bouncer','breaker'],['punkg','punkg','breaker'],['slasher','breaker','bouncer']],    stop:'canarsie', passes:[['halsey',2200],['wilson',4400],['bwayjct',6600]], fight:['punkg','bouncer'], shop:true },
  { car:18, waves:[['kaneB','breaker'],['bouncer','punkg'],['breaker','punkg','bouncer']],                          stop:'ghost', quick:[], end:true },
];
const STAGES=[
  { key:'D', short:'D', color:'#ff6319', name:'D 급행 · 업타운', start:'atl', line:LINE_D, reinf:['punk','pick','punk','rusher'], intro:'D 급행 · 업타운 145 St 방면 — 곧 맨해튼 다리를 건너요' },
  { key:'4', short:'4', color:'#00933c', name:'4 열차 · 제롬 애비뉴 고가선', start:'y161', line:LINE_4, el:true, reinf:['gear','weasel','gear','slasher'], intro:'4 열차 · 우드론 방면 — 브롱크스 고가선. 밤이 됐다',
    card:['환승', '145 St에서 D를 계속 타고 161 St–Yankee Stadium으로', '4 열차 · 제롬 애비뉴 고가선 · 브롱크스', "해가 졌다. 고가선 위는 스팀펑크 갱단 '기어단'의 구역"] },
  { key:'6', short:'6', color:'#00933c', name:'6 열차 · 렉싱턴 애비뉴 완행', start:'gc42', line:LINE_6, reinf:['triad','triad','kungfu','swords'], intro:'6 열차 · 다운타운 브루클린 브리지 방면 — 캐널 스트리트(차이나타운)를 지난다',
    card:['환승', '우드론에서 4를 타고 다시 남쪽으로 — 그랜드 센트럴에서 6 완행으로', '6 열차 · 렉싱턴 애비뉴 완행 · 차이나타운', "캐널 스트리트 일대는 가상의 조직 '청룡방'의 구역. 종점 너머엔 폐쇄된 옛 시티 홀 역"] },
  { key:'7', short:'7', color:'#b933ad', name:'7 열차 · 플러싱 고가선', start:'qbp', line:LINE_7, el:'q', reinf:['skater','batter','skater','neonbig'], intro:'7 열차 · 플러싱 방면 — 퀸스 고가선. 네온이 켜졌다',
    card:['환승', '시티 홀에서 6을 거슬러 그랜드 센트럴로 — 7을 타고 강 건너 퀸스로', '7 열차 · 플러싱 고가선 · 퀸스', "네온 간판 아래 고가선은 가상의 폭주족 '네온 바이퍼스'의 구역"] },
  { key:'L', short:'L', color:'#a7a9ac', name:'L 열차 · 캐너시선', start:'s14l', line:LINE_L, reinf:['punkg','breaker','punkg','bouncer'], intro:'L 열차 · 캐너시 방면 — 강 밑 터널을 지나 브루클린으로',
    card:['환승', '플러싱에서 7을 타고 돌아와 유니언 스퀘어에서 L로', 'L 열차 · 캐너시선 · 브루클린', "강 건너 창고 클럽은 가상의 조직 '언더그라운드'의 무대. 종점 너머 어딘가에서 케인이 기다린다"] },
];
let STAGE=STAGES[0], LINE=STAGE.line, START_STOP=STAGE.start, STOPS=[START_STOP, ...LINE.map(L=>L.stop)];
function setStage(k){ GS.stageIdx=k; STAGE=STAGES[k]; LINE=STAGE.line; START_STOP=STAGE.start; STOPS=[START_STOP, ...LINE.map(L=>L.stop)]; }

const BARKS=['표 좀 보자고','자리 비켜','어딜 가','여기 내 구역이야','지갑 두고 가','그 가방 이리 내'];
const COLS=5, ROWS=3, FLOOR=SB.FLOOR;
