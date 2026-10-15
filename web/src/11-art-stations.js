/* =========================================================
   2-g. 뉴욕 지하철 IND 8번가선 (A 급행 업타운 14 St → 168 St)
   출처: nycsubway.org "IND Station Tile Colors", "IND 8th Avenue Line" 역별 설명
   IND 양식: 흰 타일 벽 + 역마다 정해진 띠·테두리 색 + 검은 바탕 흰 글자 이름판 (색만 쓰는 역은 이름판 바탕이 그 색)
   ========================================================= */
// 색 → 엔진 재질 램프 근사 [재질, 톤]
const NYC_COL={ mustard:[M.GOLD,.5], terracotta:[M.WOOD,.3], gold:[M.GOLD,.62], burgundy:[M.RED,.3], maroon:[M.RED,.26], purple:[M.STONE,.36],
  orchid:[M.STONE,.5], ultramarine:[M.ARMOR,.42], midnight:[M.DARK,.36], blue:[M.ARMOR,.5], marine:[M.GRASS,.36], dkgreen:[M.IVY,.36],
  reddishpurple:[M.NEONP,.3], black:[M.MDARK,.12], white:[M.FRAME,.84],
  royalblue:[M.ARMOR,.36], grassgreen:[M.GRASS,.42], chromegreen:[M.IVY,.3], lightgreen:[M.GRASS,.58], truegreen:[M.GRASS,.3],
  deepyellow:[M.GOLD,.58], ochre:[M.GOLD,.36], scarlet:[M.RED,.5], darkbrown:[M.WOOD,.2], royalpurple:[M.STONE,.42], teal:[M.NEONT,.42] };
// 역: band=띠(없으면 null) · border=테두리 · tablet=이름판 { field 바탕, rim 테두리 } · beam=기둥 색 · cap=숫자 표지 · big=띠 위 큰 숫자 · wall=벽(흰 타일/담황 벽돌)
const STN={
  s14:  { n:'14 St',                ko:'14번가',            tab:'14TH STREET',  dir:'14TH AND 16TH STS', band:'mustard', border:'terracotta', tablet:{field:'black',rim:'gold'}, beam:'black', cap:'14' },
  s23:  { n:'23 St',                ko:'23번가',            tab:'23RD STREET',  band:null, tablet:{field:'gold',rim:'black'}, beam:'black', cap:'23' },
  s34:  { n:'34 St–Penn Station',   ko:'34번가–펜역',        tab:'34TH STREET',  dir:'PENN STATION', band:'maroon', border:'maroon', tablet:{field:'maroon',rim:'maroon'}, beam:'dkgreen', cap:'34' },
  s42:  { n:'42 St–Port Authority', ko:'42번가–포트 오소리티', tab:null, band:'purple', border:'black', big:'42', beam:'black', cap:'42' },
  s50:  { n:'50 St',                ko:'50번가',            tab:'50TH STREET',  band:null, tablet:{field:'purple',rim:'black'}, beam:'black', cap:'50' },
  s59:  { n:'59 St–Columbus Circle', ko:'59번가–콜럼버스 서클', tab:'59TH STREET', dir:'COLUMBUS CIRCLE', band:'ultramarine', border:'black', tablet:{field:'black',rim:'ultramarine'}, beam:'black', cap:'59' },
  s72:  { n:'72 St',                ko:'72번가',            tab:'72ND STREET',  band:null, tablet:{field:'blue',rim:'black'}, beam:'blue', cap:'72' },
  s81:  { n:'81 St–Museum',         ko:'81번가–자연사박물관',   tab:'81ST STREET',  band:'midnight', border:'black', tablet:{field:'midnight',rim:'black'}, beam:'blue', cap:'81' },
  s96:  { n:'96 St',                ko:'96번가',            tab:'96TH STREET',  band:null, tablet:{field:'midnight',rim:'black'}, beam:'blue', cap:'96' },
  s110: { n:'Cathedral Pkwy–110 St', ko:'110번가',          tab:'110TH STREET', band:null, tablet:{field:'midnight',rim:'black'}, beam:'blue', cap:'110' },
  s125: { n:'125 St',               ko:'125번가',           tab:null, band:'marine', border:'black', beam:'marine', cap:'125', wall:'brick' },
  s135: { n:'135 St',               ko:'135번가',           tab:'135TH STREET', band:null, tablet:{field:'dkgreen',rim:'black'}, beam:'black', cap:'135' },
  s145: { n:'145 St',               ko:'145번가',           tab:'145TH STREET', band:'gold', border:'black', tablet:{field:'black',rim:'gold'}, beam:'black', cap:'145' },
  s155: { n:'155 St',               ko:'155번가',           tab:'155TH STREET', band:null, tablet:{field:'gold',rim:'black'}, beam:'gold', cap:'155' },
  s163: { n:'163 St–Amsterdam Av',  ko:'163번가–암스테르담가', tab:'163RD STREET', dir:'AMSTERDAM AVE', band:'gold', border:'black', tablet:{field:'gold',rim:'black'}, beam:'gold', cap:'163' },
  s168: { n:'168 St',               ko:'168번가',           tab:null, band:'reddishpurple', border:'black', beam:'black', cap:'168' },
  // D선 브루클린 · 6번가선 (출처: subwaynut.com · forgotten-ny.com · nycsubway.org IND 색표)
  atl:   { n:'Atlantic Av–Barclays Ctr', ko:'애틀랜틱 애비뉴–바클레이스 센터', h:'ATL', tab:'ATLANTIC AV', dir:'BARCLAYS CTR', band:'black', border:'teal', bandPat:'geo', bandText:'PACIFIC ST', tablet:{field:'black',rim:'black'}, beam:'black' },
  grand: { n:'Grand St',              ko:'그랜드 스트리트',     h:'GR', tab:null, band:'royalblue', border:'royalblue', bandText:'GRAND ST', beam:'black', wall:'beige' },
  bwl:   { n:'Broadway–Lafayette St', ko:'브로드웨이–라파예트', tab:'BWAY-LAFAYETTE', band:'royalblue', border:'black', tablet:{field:'black',rim:'royalblue'}, beam:'blue' },
  w4:    { n:'W 4 St–Wash Sq',        ko:'웨스트 4번가',        h:'W4', tab:'WEST 4TH ST', dir:'WASHINGTON SQ', band:'grassgreen', border:'chromegreen', tablet:{field:'black',rim:'grassgreen'}, beam:'dkgreen', cap:'4' },
  s14f:  { n:'14 St (6 Av)',          ko:'14번가',             tab:'14TH STREET', band:'lightgreen', border:'truegreen', tablet:{field:'black',rim:'lightgreen'}, beam:'black', cap:'14' },
  s23f:  { n:'23 St (6 Av)',          ko:'23번가',             tab:'23RD STREET', band:'lightgreen', border:'truegreen', tablet:{field:'black',rim:'lightgreen'}, beam:'black', cap:'23' },
  s34h:  { n:'34 St–Herald Sq',       ko:'34번가–헤럴드 스퀘어', tab:'34TH STREET', dir:'HERALD SQ', band:'deepyellow', border:'ochre', tablet:{field:'black',rim:'deepyellow'}, beam:'black', cap:'34' },
  s42b:  { n:'42 St–Bryant Pk',       ko:'42번가–브라이언트 파크', tab:'42ND STREET', dir:'BRYANT PARK', band:'scarlet', border:'darkbrown', tablet:{field:'black',rim:'scarlet'}, beam:'black', cap:'42' },
  s47:   { n:'47–50 Sts–Rockefeller Ctr', ko:'47–50번가–록펠러 센터', tab:'47-50 STS', dir:'ROCKEFELLER CTR', band:'scarlet', border:'darkbrown', tablet:{field:'black',rim:'scarlet'}, beam:'black', cap:'50' },
  // 6 열차 렉싱턴 애비뉴 완행(IRT, 1904): 크림색 타일 · 테두리 두른 모자이크 이름판
  gc42:  { n:'Grand Central–42 St', ko:'그랜드 센트럴–42번가', h:'GC', tab:'GRAND CENTRAL', band:'terracotta', border:'terracotta', tablet:{field:'white',rim:'terracotta'}, beam:'black' },
  s33l:  { n:'33 St', ko:'33번가', tab:'33RD STREET', band:null, tablet:{field:'white',rim:'blue'}, beam:'black', cap:'33' },
  s28l:  { n:'28 St', ko:'28번가', tab:'28TH STREET', band:null, tablet:{field:'white',rim:'mustard'}, beam:'black', cap:'28' },
  s23l:  { n:'23 St', ko:'23번가', h:'23', tab:'23RD STREET', band:'teal', border:'teal', tablet:{field:'white',rim:'teal'}, beam:'black', cap:'23' },
  s14l:  { n:'14 St–Union Sq', ko:'14번가–유니언 스퀘어', tab:'14TH STREET', dir:'UNION SQUARE', band:'maroon', border:'maroon', tablet:{field:'white',rim:'maroon'}, beam:'black', cap:'14' },
  astor: { n:'Astor Pl', ko:'애스터 플레이스', h:'AST', tab:'ASTOR PLACE', band:'dkgreen', border:'dkgreen', tablet:{field:'white',rim:'dkgreen'}, beam:'dkgreen' },
  bleecker:{ n:'Bleecker St', ko:'블리커 스트리트', tab:'BLEECKER ST', band:null, tablet:{field:'white',rim:'ochre'}, beam:'black' },
  spring:{ n:'Spring St', ko:'스프링 스트리트', tab:'SPRING ST', band:null, tablet:{field:'white',rim:'blue'}, beam:'black' },
  canal: { n:'Canal St', ko:'캐널 스트리트', h:'CNL', tab:'CANAL ST', dir:'CHINATOWN', band:'scarlet', border:'scarlet', tablet:{field:'white',rim:'scarlet'}, beam:'black' },
  bbch:  { n:'Brooklyn Bridge–City Hall', ko:'브루클린 브리지–시티 홀', tab:'BROOKLYN BRIDGE', dir:'CITY HALL', band:'darkbrown', border:'darkbrown', tablet:{field:'white',rim:'darkbrown'}, beam:'black' },
  cityhall:{ n:'City Hall (closed)', ko:'옛 시티 홀 역', h:'CH', tab:'CITY HALL', band:null, tablet:{field:'white',rim:'dkgreen'}, beam:'black', vault:true },
  // 4 열차 제롬 애비뉴 고가선(브롱크스): 지붕 달린 고가 승강장 · 검은 판에 흰 글자 표지
  y161:  { n:'161 St–Yankee Stadium', ko:'161번가–양키 스타디움', h:'161', el:true, sign:'161 ST-YANKEE STADIUM', yankee:true },
  s167:  { n:'167 St', ko:'167번가', el:true, sign:'167 ST' },
  s170:  { n:'170 St', ko:'170번가', h:'170', el:true, sign:'170 ST' },
  mteden:{ n:'Mt Eden Av', ko:'마운트 에덴 애비뉴', el:true, sign:'MT EDEN AV' },
  s176:  { n:'176 St', ko:'176번가', el:true, sign:'176 ST' },
  burn:  { n:'Burnside Av', ko:'번사이드 애비뉴', h:'BUR', el:true, sign:'BURNSIDE AV' },
  s183:  { n:'183 St', ko:'183번가', el:true, sign:'183 ST' },
  ford:  { n:'Fordham Rd', ko:'포덤 로드', h:'FOR', el:true, sign:'FORDHAM RD' },
  kings: { n:'Kingsbridge Rd', ko:'킹스브리지 로드', el:true, sign:'KINGSBRIDGE RD' },
  bedpk: { n:'Bedford Park Blvd–Lehman College', ko:'베드퍼드 파크 블러바드', el:true, sign:'BEDFORD PARK BLVD' },
  mosh:  { n:'Mosholu Pkwy', ko:'모숄루 파크웨이', el:true, sign:'MOSHOLU PKWY' },
  wood:  { n:'Woodlawn', ko:'우드론', h:'WDL', el:true, sign:'WOODLAWN' },
  s7a:   { n:'7 Av',                  ko:'7번가',              tab:'7TH AVENUE', band:'royalpurple', border:'black', tablet:{field:'black',rim:'royalpurple'}, beam:'black', cap:'7' },
  // 7 열차 플러싱 고가선(퀸스): 보라 7 동그라미 표지
  qbp:   { n:'Queensboro Plaza', ko:'퀸스보로 플라자', h:'QBP', el:true, line:'7', sign:'QUEENSBORO PLAZA' },
  s33r:  { n:'33 St–Rawson St', ko:'33번가–로슨 스트리트', el:true, line:'7', sign:'33 ST-RAWSON ST' },
  s40:   { n:'40 St–Lowery St', ko:'40번가–라워리 스트리트', el:true, line:'7', sign:'40 ST-LOWERY ST' },
  s46:   { n:'46 St–Bliss St', ko:'46번가–블리스 스트리트', h:'46', el:true, line:'7', sign:'46 ST-BLISS ST' },
  s52:   { n:'52 St', ko:'52번가', el:true, line:'7', sign:'52 ST' },
  woodside:{ n:'61 St–Woodside', ko:'61번가–우드사이드', h:'WDS', el:true, line:'7', sign:'61 ST-WOODSIDE' },
  s69:   { n:'69 St', ko:'69번가', el:true, line:'7', sign:'69 ST' },
  s74:   { n:'74 St–Broadway', ko:'74번가–브로드웨이', h:'74', el:true, line:'7', sign:'74 ST-BROADWAY' },
  s82:   { n:'82 St–Jackson Hts', ko:'82번가–잭슨 하이츠', el:true, line:'7', sign:'82 ST-JACKSON HTS' },
  s90:   { n:'90 St–Elmhurst Av', ko:'90번가–엘름허스트', el:true, line:'7', sign:'90 ST-ELMHURST AV' },
  junction:{ n:'Junction Blvd', ko:'정션 블러바드', h:'JCT', el:true, line:'7', sign:'JUNCTION BLVD' },
  s103:  { n:'103 St–Corona Plaza', ko:'103번가–코로나 플라자', el:true, line:'7', sign:'103 ST-CORONA PLAZA' },
  s111:  { n:'111 St', ko:'111번가', h:'111', el:true, line:'7', sign:'111 ST' },
  mets:  { n:'Mets–Willets Point', ko:'메츠–윌레츠 포인트', h:'MET', el:true, line:'7', sign:'METS-WILLETS POINT', citi:true },
  flushing:{ n:'Flushing–Main St', ko:'플러싱–메인 스트리트', h:'FLU', el:true, line:'7', sign:'FLUSHING-MAIN ST' },
  // L 열차 캐너시선(브루클린): 유니언 스퀘어에서 강 밑으로
  s3av:  { n:'3 Av', ko:'3번가', tab:'3RD AVENUE', band:null, tablet:{field:'white',rim:'blue'}, beam:'black', cap:'3' },
  s1av:  { n:'1 Av', ko:'1번가', h:'1AV', tab:'1ST AVENUE', band:'ultramarine', border:'ultramarine', tablet:{field:'white',rim:'ultramarine'}, beam:'black', cap:'1' },
  bedford:{ n:'Bedford Av', ko:'베드퍼드 애비뉴', h:'BED', tab:'BEDFORD AV', band:'teal', border:'teal', tablet:{field:'white',rim:'teal'}, beam:'black' },
  lorimer:{ n:'Lorimer St', ko:'로리머 스트리트', tab:'LORIMER ST', band:null, tablet:{field:'white',rim:'ochre'}, beam:'black' },
  graham:{ n:'Graham Av', ko:'그레이엄 애비뉴', tab:'GRAHAM AV', band:null, tablet:{field:'white',rim:'maroon'}, beam:'black' },
  grandl:{ n:'Grand St', ko:'그랜드 스트리트(L)', tab:'GRAND ST', band:null, tablet:{field:'white',rim:'blue'}, beam:'black' },
  montrose:{ n:'Montrose Av', ko:'몬트로즈 애비뉴', h:'MON', tab:'MONTROSE AV', band:'mustard', border:'mustard', tablet:{field:'white',rim:'mustard'}, beam:'black' },
  morgan:{ n:'Morgan Av', ko:'모건 애비뉴', tab:'MORGAN AV', band:null, tablet:{field:'white',rim:'dkgreen'}, beam:'black' },
  jefferson:{ n:'Jefferson St', ko:'제퍼슨 스트리트', h:'JEF', tab:'JEFFERSON ST', band:'reddishpurple', border:'reddishpurple', tablet:{field:'white',rim:'reddishpurple'}, beam:'black' },
  dekalbl:{ n:'DeKalb Av', ko:'디캘브 애비뉴(L)', tab:'DEKALB AV', band:null, tablet:{field:'white',rim:'scarlet'}, beam:'black' },
  myrtle:{ n:'Myrtle–Wyckoff Avs', ko:'머틀–와이코프', h:'MYR', tab:'MYRTLE-WYCKOFF', band:'darkbrown', border:'darkbrown', tablet:{field:'white',rim:'darkbrown'}, beam:'black' },
  halsey:{ n:'Halsey St', ko:'핼시 스트리트', tab:'HALSEY ST', band:null, tablet:{field:'white',rim:'ochre'}, beam:'black' },
  wilson:{ n:'Wilson Av', ko:'윌슨 애비뉴', tab:'WILSON AV', band:null, tablet:{field:'white',rim:'blue'}, beam:'black' },
  bwayjct:{ n:'Broadway Junction', ko:'브로드웨이 정션', tab:'BROADWAY JCT', band:'black', border:'black', tablet:{field:'white',rim:'black'}, beam:'black' },
  canarsie:{ n:'Canarsie–Rockaway Pkwy', ko:'캐너시–로커웨이 파크웨이', h:'CAN', tab:'CANARSIE', dir:'ROCKAWAY PKWY', band:'maroon', border:'maroon', tablet:{field:'white',rim:'maroon'}, beam:'black' },
  ghost: { n:'(Not on the map)', ko:'지도에 없는 역', h:'END', tab:'NO SERVICE', band:'black', border:'black', tablet:{field:'black',rim:'white'}, beam:'black', ruin:true },
};
try{ for(const id in STN){ const S=STN[id]; if(S.ko && typeof EN_DICT==='object' && !(S.ko in EN_DICT)) EN_DICT[S.ko]=S.n; } }catch(e){}   // 영문: 역 이름은 원래 표기로
// 높이(화면 y): 띠는 객차 지붕 위로 보이고, 이름판은 창 높이(창 너머로 읽힘)
const NY={ CEIL:34, BAND:112, TAB:160, DIR:182, CAP:98, FLOOR:226, LEN:960 };
function genNYC(){
  const rnd=mulberry(1932), out={};
  const C=k=>NYC_COL[k]||NYC_COL.black;
  // 흰 타일 벽 (줄눈 4px) · 담황 세로 벽돌(125 St)
  for(const [key,brick] of [['ny_wall',false],['ny_brick',true],['ny_beige','beige']]){ const p=paint(240,NY.FLOOR-NY.CEIL);
    for(let y=0;y<p.h;y++) for(let x=0;x<240;x++){ let m=M.FRAME, k=4;
      if(brick==='beige'){ m=M.CURT; k=(x%6===0||y%6===0)?3:(rnd()<.05?3:4); }
      else if(brick){ m=M.CURT; k = (x%6===0 || (y+((x/6|0)%2)*6)%12===0) ? 2 : (rnd()<.1?3:4); }
      else { k = (x%4===0||y%4===0) ? 2 : (rnd()<.06?3:4); if(y>p.h-14) k=Math.max(1,k-1); }   // 바닥 쪽은 때가 탔다
      p.set(x,y,m,k); }
    for(let k=0;k<26;k++){ const x=Math.floor(rnd()*240), y=Math.floor(rnd()*(p.h-20)), L=4+Math.floor(rnd()*14); for(let j=0;j<L;j++) if(rnd()<.8) p.set(x,y+j,brick?M.CURT:M.FRAME,2); } // 물얼룩
    out[key]=p.s; }
  // 폐역(지도에 없는 역): 때 낀 타일 · 떨어져 나간 자리 · 금 · 물 흘러내린 자국 · 낙서
  { const p=paint(240,NY.FLOOR-NY.CEIL);
    for(let y=0;y<p.h;y++) for(let x=0;x<240;x++){ const gl=(x%4===0||y%4===0); p.set(x,y,M.CURT,gl?1:(rnd()<.18?1:2),{e:.01}); }
    for(let k=0;k<34;k++){ const tx=Math.floor(rnd()*60)*4, ty=Math.floor(rnd()*(p.h/4-2))*4; for(let j=0;j<4;j++) for(let i=0;i<4;i++) p.set(tx+i,ty+j,M.CONC,rnd()<.5?0:1); }   // 떨어져 나간 타일
    for(let k=0;k<9;k++){ let x=Math.floor(rnd()*240), y=Math.floor(rnd()*60); for(let j=0;j<40;j++){ p.set(x,y,M.MDARK,0); y++; if(rnd()<.35) x+=rnd()<.5?-1:1; } }               // 금
    for(let k=0;k<30;k++){ const x=Math.floor(rnd()*240), y=Math.floor(rnd()*30), L=20+Math.floor(rnd()*60); for(let j=0;j<L;j++) if(rnd()<.85) p.set(x,y+j,M.IVY,1,{e:.02}); }   // 녹물 · 이끼
    const TAGS=['END OF LINE','NO EXIT','K','LAST STOP','X'], TC=[M.RED,M.FRAME,M.NEONT];
    for(let k=0;k<3;k++){ const t=TAGS[Math.floor(rnd()*TAGS.length)]; signText(p,10+Math.floor(rnd()*150),70+Math.floor(rnd()*60),t,TC[k%3],3,{e:.05},t.length<3?3:1); }
    out.ny_ruin=p.s; }
  // 천장: 형광등 띠 · 배관
  { const p=paint(240,NY.CEIL); p.rect(0,0,240,NY.CEIL,M.MDARK,(q,j)=>j<20?1:2);
    for(let x=10;x<240;x+=60){ p.rect(x,22,40,3,M.FRAME,5,{e:.95}); p.rect(x-2,20,44,2,M.STEEL,2); }
    for(let x=0;x<240;x++){ p.set(x,8,M.STEEL,2); p.set(x,9,M.STEEL,1); } out.ny_ceil=p.s; }
  // 띠: 테두리 한 줄 + 색 타일 두 줄 + 테두리 한 줄 (타일 4px)
  for(const id in STN){ const S=STN[id]; if(!S.band) continue; const p=paint(240,16), B=C(S.band), D=C(S.border);
    for(let y=0;y<16;y++) for(let x=0;x<240;x++){ const edge=y<4||y>=12, [m,t]=edge?D:B; p.set(x,y,m, Math.max(0,Math.min(5,Math.round(t*7.2) + ((x%4===0||y%4===0)?-1:0) + (rnd()<.08?1:0)))); }
    if(S.bandPat==='geo') for(let x=0;x<240;x+=12){ for(let j=0;j<6;j++){ p.set(x+j,5+j,M.FRAME,4); p.set(x+11-j,5+j,M.FRAME,4); } }   // 검은 띠의 흰 기하학 무늬
    if(S.bandText){ const tw=S.bandText.length*6; signText(p,120-(tw>>1),4,S.bandText,S.bandPat?M.FRAME:M.FRAME,S.bandPat?2:5,{}); } // 띠 안의 역 이름
    out['ny_band_'+id]=p.s; }
  // 기둥(I-빔): 리벳 · 역마다 색
  for(const k of ['black','dkgreen','blue','marine','gold']){ const p=paint(8,NY.FLOOR), [m,t]=C(k), k0=Math.round(t*7.2);
    for(let y=0;y<NY.FLOOR;y++){ p.set(0,y,m,Math.max(0,k0-1)); p.set(1,y,m,k0+1); for(let x=2;x<6;x++) p.set(x,y,m,k0); p.set(6,y,m,Math.max(0,k0-1)); p.set(7,y,m,Math.max(0,k0-2)); if(y%10===0){ p.set(2,y,m,k0+2); p.set(5,y,m,k0+2); } }
    p.rect(0,NY.FLOOR-14,8,14,m,Math.max(0,k0-1)); out['ny_beam_'+k]=p.s; }
  // 글자: '14TH STREET' → 큰 숫자 + 위첨자 서수(밑줄) + 큰 글자
  const drawName=(p,x,y,str,m,k,sc)=>{ const mm=str.match(/^(\d+)(ST|ND|RD|TH)\s+(.*)$/); let cx=x;
    const tile=(px,py)=>{ p.set(px,py,m,Math.max(0,Math.min(5,k+(rnd()<.18?-1:0)))); };          // 모자이크: 타일마다 살짝 다른 톤
    const glyph=(ch,gx,gy,s)=>{ const g=F57[ch]||F57[' ']; for(let j=0;j<7;j++) for(let i=0;i<5;i++) if(g[j][i]==='1') for(let a=0;a<s;a++) for(let b=0;b<s;b++) tile(gx+i*s+a,gy+j*s+b); };
    if(mm){ for(const ch of mm[1]){ glyph(ch,cx,y,sc); cx+=6*sc; } glyph(mm[2][0],cx,y,1); glyph(mm[2][1],cx+6,y,1); for(let q=cx;q<cx+11;q++) tile(q,y+9); cx+=14+sc*2;
      for(const ch of mm[3]){ glyph(ch,cx,y,sc); cx+=6*sc; } }
    else for(const ch of str){ glyph(ch,cx,y,sc); cx+=6*sc; }
    return cx-x; };
  const nameW=(str,sc)=>{ const mm=str.match(/^(\d+)(ST|ND|RD|TH)\s+(.*)$/); return mm ? mm[1].length*6*sc+14+sc*2+mm[3].length*6*sc : str.length*6*sc; };
  for(const id in STN){ const S=STN[id];
    if(S.tab){ const sc=2, w=nameW(S.tab,sc)+12, h=7*sc+10, p=paint(w,h), F=C(S.tablet.field), R=C(S.tablet.rim);
      const darkField = F[0]===M.MDARK || F[1]<.4, txt = darkField ? [M.FRAME,5] : [M.MDARK,0];
      for(let y=0;y<h;y++) for(let x=0;x<w;x++){ const rim=x<3||y<3||x>=w-3||y>=h-3, [m,t]=rim?R:F; p.set(x,y,m,Math.max(0,Math.min(5,Math.round(t*7.2)+(rnd()<.2?-1:0)+((x+y)%2&&!rim?0:0)))); }
      drawName(p,6,5,S.tab,txt[0],txt[1],sc); out['ny_tab_'+id]=p.s; }
    if(S.dir){ const w=S.dir.length*6+40, p=paint(w,11); p.rect(0,0,w,11,M.MDARK,(q,j)=>j===0||j===10?2:0);
      const arr=(x0,dirn)=>{ for(let q=0;q<12;q++) p.set(x0+q,5,M.FRAME,5); for(let j=-2;j<=2;j++) p.set(dirn<0?x0+Math.abs(j):x0+11-Math.abs(j),5+j,M.FRAME,5); };
      arr(3,-1); signText(p,20,2,S.dir,M.FRAME,5,{}); arr(w-15,1); out['ny_dir_'+id]=p.s; }
    if(S.cap){ const w=S.cap.length*6+5, p=paint(w,11); p.rect(0,0,w,11,M.MDARK,(q,j)=>j===0||j===10||q===0||q===w-1?1:0); signText(p,3,2,S.cap,M.FRAME,5,{}); out['ny_cap_'+id]=p.s; }
    if(S.big){ const p=paint(S.big.length*6*3+6,24); signText(p,3,1,S.big,M.FRAME,5,{},3); out['ny_big_'+id]=p.s; }
  }
  // 터널 사이 강철 기둥 (지나가는 속도감)
  { const p=paint(6,200); for(let y=0;y<200;y++){ p.set(0,y,M.MDARK,1); for(let x=1;x<5;x++) p.set(x,y,M.MDARK,x===1?3:2); p.set(5,y,M.MDARK,0); if(y%12===0) p.set(2,y,M.STEEL,3); } out.ny_col=p.s; }
  return out;
}

/* =========================================================
   2-h. 맨해튼 다리 실외 구간 (노을): 하늘 · 맨해튼 스카이라인 · 브루클린 다리 · 이스트강 · 다리 트러스
   ========================================================= */
const BR={ HZ:168, SUN:[352,116] };          // 수평선 · 해 위치(화면)
function genBridge(){
  const rnd=mulberry(1883), out={};
  const B4=[0,8,2,10,12,4,14,6,3,11,1,9,15,7,13,5], bay=(x,y)=>B4[(y&3)*4+(x&3)]/16;
  // 하늘: 위 짙은 보라 → 자홍 → 주황 → 금빛 수평선. 띠 사이는 순서 디더로 섞는다(스스로 빛나는 하늘)
  { const p=paint(SB.W,200), stops=[[0,M.STONE,1],[.22,M.STONE,2],[.4,M.NEONP,1],[.56,M.NEONP,2],[.7,M.NEONO,2],[.82,M.NEONO,3],[.93,M.GOLD,3],[1,M.GOLD,4]];
    for(let y=0;y<200;y++){ const g=y/(BR.HZ+2); let k=0; while(k<stops.length-2 && g>stops[k+1][0]) k++;
      const a=stops[k], b=stops[k+1], u=Math.max(0,Math.min(1,(g-a[0])/(b[0]-a[0])));
      for(let x=0;x<SB.W;x++){ const t=u>bay(x,y)?b:a; p.set(x,y,t[1],t[2],{e:.42}); } }
    for(let k=0;k<9;k++){ const cy=50+Math.floor(rnd()*80), cx=Math.floor(rnd()*SB.W), L=40+Math.floor(rnd()*110);       // 길게 늘어진 구름, 아랫면이 금빛
      for(let x=0;x<L;x++){ const xx=(cx+x)%SB.W; if(rnd()<.85){ p.set(xx,cy,M.NEONP,3,{e:.45}); p.set(xx,cy+1,M.NEONO,4,{e:.55}); } if(x>4&&x<L-4&&rnd()<.6) p.set(xx,cy-1,M.STONE,2,{e:.4}); } }
    const [sx,sy]=BR.SUN; for(let y=-16;y<=16;y++) for(let x=-16;x<=16;x++){ const r=Math.hypot(x,y); if(r<=13) p.set(sx+x,sy+y,M.GOLD,5,{e:1}); else if(r<=16 && bay(x,y)<(16-r)/3) p.set(sx+x,sy+y,M.GOLD,5,{e:.95}); }
    out.br_sky=p.s; }
  // 맨해튼 스카이라인(역광 실루엣 · 켜진 창 · 해 쪽 가장자리 금빛)
  { const p=paint(960,84);
    let x=0; while(x<960){ const w=8+Math.floor(rnd()*22), h=12+Math.floor(rnd()*44)*(rnd()<.2?1.4:1)|0, top=84-h;
      for(let yy=top;yy<84;yy++) for(let xx=x;xx<Math.min(960,x+w);xx++) p.set(xx,yy,M.SUIT,xx===x+w-1?3:1,{e:.12});
      for(let yy=top+3;yy<82;yy+=3) for(let xx=x+2;xx<x+w-2;xx+=3) if(rnd()<.18) p.set(xx,yy,M.COAT,5,{e:.7});
      x+=w+(rnd()<.3?2:0); }
    const tower=(cx,h,w)=>{ for(let yy=84-h;yy<84;yy++){ const ww=Math.max(1,Math.round(w*(.45+.55*(yy-(84-h))/h))); for(let xx=cx-ww;xx<=cx+ww;xx++) p.set(xx,yy,M.SUIT,xx===cx+ww?3:2,{e:.14}); } for(let yy=84-h-14;yy<84-h;yy++) p.set(cx,yy,M.STEEL,3,{e:.3}); };
    tower(300,80,7); tower(720,72,6);                                                       // 뾰족한 첨탑 둘(원 WTC · 엠파이어 스테이트 느낌)
    out.br_skyline=p.s; }
  // 브루클린 다리: 화강암 탑 둘(뾰족 아치 두 개씩) · 주케이블 현수선 · 행어 · 사선 케이블
  { const W2=720, p=paint(W2,140), deck=118, towers=[150,560], top=8;
    for(let x=0;x<W2;x++){ p.set(x,deck,M.SUIT,2,{e:.15}); p.set(x,deck+1,M.SUIT,1,{e:.1}); }
    const cable=(x0,y0,x1,y1,sag)=>{ for(let x=x0;x<=x1;x++){ const u=(x-x0)/Math.max(1,x1-x0), y=y0+(y1-y0)*u+sag*4*u*(1-u); p.set(x,Math.round(y),M.MDARK,2,{e:.15});
      if(x%5===0) for(let yy=Math.round(y)+1;yy<deck;yy++) if(yy%2===0||yy>deck-6) p.set(x,yy,M.MDARK,1,{e:.1}); } };
    cable(towers[0]+20,top+14,towers[1],top+14,70); cable(0,deck-10,towers[0],top+14,-20); cable(towers[1]+20,top+14,W2-1,deck-12,-20);
    for(const tx of towers) for(let k=0;k<6;k++){ const ex=tx+(k<3?-30-k*22:50+(k-3)*22); p.line(tx+(k<3?2:18),top+18,ex,deck,M.MDARK,1,{e:.12}); }
    for(const tx of towers){ for(let y=top;y<deck+18;y++) for(let x=tx;x<tx+20;x++){ const edge=x===tx||x===tx+19; p.set(x,y,M.STONEL,edge?1:(x<tx+6?3:2),{e:.22}); }      // 해 쪽 면이 밝다
      for(let y=top-4;y<top;y++) for(let x=tx+2;x<tx+18;x++) p.set(x,y,M.STONEL,2,{e:.2});
      for(const ax of [tx+3,tx+11]) for(let y=top+22;y<top+70;y++){ const half=y<top+28 ? Math.round((y-top-22)*.7) : 3; for(let x=ax+3-half;x<=ax+3+half;x++) if(x>=ax&&x<ax+7) p.s.mat[y*W2+x]=0; } }  // 뾰족 아치(하늘이 비친다)
    out.br_bk=p.s; }
  // 이스트강: 물결 줄 · 반짝임은 따로
  { const p=paint(SB.W,SB.H-BR.HZ);
    for(let y=0;y<p.h;y++) for(let x=0;x<SB.W;x++){ const k=(y<3)?3:((x+y*7)%23<2?3:(y%4===0&&rnd()<.5?2:1)); p.set(x,y,y<6?M.STONE:M.DARK,k,{e:.25,ny:.8}); }
    out.br_water=p.s; }
  { const g=paint(4,1); for(let x=0;x<4;x++) g.set(x,0,M.GOLD,5,{e:1}); out.br_glint=g.s;
    const b=paint(7,3); for(const [x,y] of [[0,0],[1,1],[2,1],[3,2],[4,1],[5,1],[6,0]]) b.set(x,y,M.MDARK,1,{e:.1}); out.br_gull=b.s; }
  // 맨해튼 다리 트러스(바로 앞을 지나간다): 위 현재 · 수직재 · 엇갈린 사재
  { const p=paint(192,140);
    for(let x=0;x<192;x++) for(let y=0;y<12;y++) p.set(x,y,M.MDARK,y===11?3:(y===0?2:1),{ny:-.3});
    for(let x=0;x<192;x+=24) p.set(x+4,5,M.STEEL,3);
    for(const px of [0,96]){ for(let y=12;y<140;y++) for(let x=px;x<px+7;x++) p.set(x,y,M.MDARK,x===px+6?3:1,{nx:x===px+6?.6:0}); }
    for(const [x0,x1] of [[7,96],[96,192]]){ p.line(x0,12,x1-1,138,M.MDARK,2); p.line(x0,13,x1-1,139,M.MDARK,1); p.line(x1-1,12,x0,138,M.MDARK,2); p.line(x1-1,13,x0,139,M.MDARK,1); }
    out.br_truss=p.s; }
  { const p=paint(24,SB.H); p.rect(0,0,24,SB.H,M.CONC,(q,j)=>q<3?1:(q>20?3:2)); out.br_portal=p.s; }
  // 타격 연출: 별 모양 터짐 · 파편
  for(const [k,R] of [[0,9],[1,14]]){ const N=2*R+3, c=R+1, s=newSprite(N,N); s.px=c; s.py=c; s.mask=.5;
    for(let a=0;a<8;a++){ const t=a*Math.PI/4+(k?.2:0); for(let r=(k?6:2);r<=R;r++){ const x=c+Math.round(r*Math.cos(t)), y=c+Math.round(r*Math.sin(t)); const i=y*N+x; s.mat[i]=M.FRAME; s.tone[i]=1; s.emit[i]=1; } }
    out['fx_burst'+k]=s; }
  { const s=newSprite(2,2); s.px=1; s.py=1; s.mask=.5; for(let i=0;i<4;i++){ s.mat[i]=M.FRAME; s.tone[i]=1; s.emit[i]=1; } out.fx_bit=s; }
  return out;
}

/* =========================================================
   2-i. 4 열차 · 제롬 애비뉴 고가선(브롱크스, 밤): 밤하늘 · 먼 맨해튼 · 벽돌 아파트(물탱크 · 비상계단) · 고가 구조 · 고가 역 · 양키 스타디움
   ========================================================= */
const EL={ HZ:150 };
function genVault(){ const rnd=mulberry(1904), out={}, p=paint(240,NY.FLOOR);
  for(let y=0;y<NY.FLOOR;y++) for(let x=0;x<240;x++) p.set(x,y,M.CURT,((x>>2)+(y>>2))%2?3:4,{e:.03});                              // 엇갈린 크림 타일(헤링본 느낌)
  for(const ax of [0,120]){ const cx=ax+60;
    for(let y=0;y<150;y++) for(let x=ax;x<ax+120;x++){ const dx=(x-cx)/56, top=150-Math.sqrt(Math.max(0,1-dx*dx))*128;               // 아치(타원)
      if(y<top){ const d=top-y; p.set(x,y, d<3?M.IVY:M.CURT, d<3?3:(((x+y)>>1)%3===0?2:3),{e:.02}); } else if(y<top+4) p.set(x,y,M.IVY,y<top+2?4:2); }
    for(let y=20;y<34;y++) for(let x=cx-10;x<cx+10;x++) p.set(x,y,M.STONE,(x+y)%5===0?5:4,{e:.55});                                 // 천창(자수정빛 유리)
    for(let x=cx-11;x<cx+11;x++){ p.set(x,19,M.IVY,2); p.set(x,34,M.IVY,2); } for(let y=19;y<35;y++){ p.set(cx-11,y,M.IVY,2); p.set(cx+10,y,M.IVY,2); } }
  for(const px of [0,119,120,239]) for(let y=60;y<NY.FLOOR;y++) p.set(px,y,M.IVY,2);
  out.ch_vault=p.s;
  const c=paint(15,14); c.rect(7,0,1,5,M.GOLD,2); for(let k=0;k<5;k++){ const x=1+k*3; c.rect(x,8,2,4,M.FRAME,5,{e:1}); c.set(x,7,M.GOLD,4); } c.rect(1,12,13,1,M.GOLD,3); c.rect(4,5,7,2,M.GOLD,4);   // 놋쇠 샹들리에
  out.ch_lamp=c.s; return out; }
function genEl(){
  const rnd=mulberry(1917), out={};
  const B4=[0,8,2,10,12,4,14,6,3,11,1,9,15,7,13,5], bay=(x,y)=>B4[(y&3)*4+(x&3)]/16;
  // 밤하늘: 짙은 남색 → 수평선 쪽 도시 불빛에 물든 보라 · 주황. 별 · 달
  { const p=paint(SB.W,200), stops=[[0,M.DARK,0],[.45,M.DARK,1],[.75,M.STONE,1],[.92,M.NEONO,1],[1,M.NEONO,2]];
    for(let y=0;y<200;y++){ const g=y/(EL.HZ+20); let k=0; while(k<stops.length-2 && g>stops[k+1][0]) k++;
      const a=stops[k], b=stops[k+1], u=Math.max(0,Math.min(1,(g-a[0])/(b[0]-a[0])));
      for(let x=0;x<SB.W;x++){ const t=u>bay(x,y)?b:a; p.set(x,y,t[1],t[2],{e:.3}); } }
    for(let k=0;k<70;k++){ const x=Math.floor(rnd()*SB.W), y=Math.floor(rnd()*110); p.set(x,y,M.FRAME,rnd()<.3?5:4,{e:.7}); }
    for(let y=-7;y<=7;y++) for(let x=-7;x<=7;x++){ const r=Math.hypot(x,y); if(r<=6.5 && Math.hypot(x+3,y-2)>5.2) p.set(84+x,38+y,M.FRAME,5,{e:.95}); }   // 초승달
    out.el_sky=p.s; }
  // 먼 맨해튼(작은 불빛)
  { const p=paint(960,50); let x=0; while(x<960){ const w=6+Math.floor(rnd()*14), h=8+Math.floor(rnd()*36); for(let yy=50-h;yy<50;yy++) for(let xx=x;xx<Math.min(960,x+w);xx++){ p.set(xx,yy,M.DARK,1,{e:.12}); if(rnd()<.05) p.set(xx,yy,M.GOLD,4,{e:.6}); } x+=w; } out.el_far=p.s; }
  // 브롱크스 벽돌 아파트 줄(5~6층): 켜진 창 · 비상계단 · 처마 장식 · 옥상 물탱크
  { const W2=480, H2=160, p=paint(W2,H2); let x=0;
    while(x<W2){ const w=58+Math.floor(rnd()*46), floors=5+Math.floor(rnd()*2), h=floors*20+12, top=H2-h, brick=[M.BRICK,M.RED,M.WOOD][Math.floor(rnd()*3)];
      for(let yy=top;yy<H2;yy++) for(let xx=x;xx<Math.min(W2,x+w);xx++){ const mortar=(yy%4===0)||((xx+(Math.floor(yy/4)%2)*3)%6===0); p.set(xx,yy,brick,mortar?1:2,{e:.05}); }
      for(let xx=x;xx<Math.min(W2,x+w);xx++){ p.set(xx,top,M.CONC,3); p.set(xx,top+1,M.CONC,2); p.set(xx,top+3,M.CONC,2); }        // 처마 장식
      for(let f=0;f<floors;f++) for(let wx=x+5;wx<x+w-8;wx+=11){ const wy=top+10+f*20, lit=rnd()<.38, warm=rnd()<.7;
        for(let j=0;j<10;j++) for(let i=0;i<6;i++) p.set(wx+i,wy+j, lit?(warm?M.GOLD:M.FRAME):M.GLASS, lit?(j<2?3:4):1, {e:lit?.55:0});
        if(lit && rnd()<.4) for(let j=0;j<10;j++) p.set(wx+2,wy+j,M.WOODD,1);                                      // 창살 · 커튼 그림자
        p.set(wx-1,wy+10,M.CONC,3); for(let i=0;i<8;i++) p.set(wx-1+i,wy+10,M.CONC,3); }
      if(rnd()<.7){ const fx=x+Math.floor(w*.3); for(let f=1;f<floors;f++){ const fy=top+f*20+8; for(let i=0;i<22;i++){ p.set(fx+i,fy,M.MDARK,1); if(i%3===0) p.set(fx+i,fy-1,M.MDARK,1); } p.line(fx+2,fy,fx+18,fy-12,M.MDARK,1); } }  // 비상계단
      if(rnd()<.6){ const tx=x+8+Math.floor(rnd()*(w-30)); for(let j=0;j<12;j++) for(let i=0;i<14;i++) p.set(tx+i,top-18+j,M.WOODD,i%4===0?1:2,{e:.04});    // 물탱크
        for(let i=0;i<14;i++){ p.set(tx+i,top-19,M.WOODD,1); } for(let k=0;k<14;k++){ p.set(tx+7-Math.floor(k/2),top-19-Math.floor(k/2)+0,M.WOODD,1); p.set(tx+7+Math.floor(k/2),top-19-Math.floor(k/2),M.WOODD,1); }
        for(const lx of [tx+2,tx+11]) for(let j=0;j<6;j++) p.set(lx,top-6+j,M.MDARK,1); }
      x+=w+1+Math.floor(rnd()*3); }
    out.el_bld=p.s; }
  // 고가 구조(옆 선로의 거더 · 난간 기둥 · 신호등)
  { const p=paint(192,60);
    for(let x=0;x<192;x++){ for(let y=36;y<50;y++) p.set(x,y,M.MDARK,y===36?3:(y===49?0:1),{ny:y===36?-.5:0}); if(x%12===0) p.set(x,42,M.STEEL,3); }
    for(let x=0;x<192;x+=48){ for(let y=10;y<36;y++){ p.set(x,y,M.MDARK,2); p.set(x+1,y,M.MDARK,1); } }
    for(let x=0;x<192;x++){ p.set(x,12,M.MDARK,2); p.set(x,22,M.MDARK,1); }
    p.rect(96,2,6,9,M.MDARK,1); p.set(98,4,M.RED,5,{e:1}); p.set(98,7,M.GRASS,3,{e:.3});                                        // 신호등
    out.el_struct=p.s; }
  // 양키 스타디움(바깥벽: 아치 창 · 석회석 · 금빛 글자 · 조명탑)
  { const p=paint(360,110);
    for(let y=30;y<110;y++) for(let x=0;x<360;x++) p.set(x,y,M.STONEL,(y%10===0)?2:3,{e:.08});
    for(let x=10;x<350;x+=22) for(let y=46;y<100;y++){ const ax=x+9, top=46+Math.round(Math.abs((y<54)?(9-Math.sqrt(Math.max(0,81-(y-54)*(y-54)))):0)); for(let i=0;i<18;i++){ const dx=i-9; if(y<54 && Math.hypot(dx,(y-54)*1.1)>9) continue; p.set(x+i,y,M.GOLD,y<60?4:3,{e:.5}); } }   // 불 켜진 아치 창
    signText(p,108,34,'YANKEE STADIUM',M.GOLD,5,{e:.9});
    for(const tx of [24,330]){ for(let y=0;y<30;y++) p.set(tx,y,M.MDARK,2); for(let i=-6;i<=6;i++) for(let j=0;j<4;j++) p.set(tx+i,j,M.FRAME,5,{e:1}); }       // 조명탑
    out.el_yankee=p.s; }
  // 고가 역 플랫폼: 초록 철제 지붕(아래 형광등) · 기둥 · 건너편 난간
  { const p=paint(240,SB.H);
    for(let x=0;x<240;x++){ for(let y=0;y<22;y++) p.set(x,y,M.IVY,y<3?3:(y>19?1:2)); }
    for(let x=10;x<240;x+=60){ p.rect(x,18,40,2,M.FRAME,5,{e:.95}); }
    for(const px of [30,150]){ for(let y=22;y<214;y++){ p.set(px,y,M.IVY,1); p.set(px+1,y,M.IVY,3); p.set(px+2,y,M.IVY,2); p.set(px+3,y,M.IVY,1); } for(let k=0;k<10;k++){ p.set(px-k,22+k,M.IVY,2); p.set(px+3+k,22+k,M.IVY,2); } }
    for(let x=0;x<240;x++){ p.set(x,186,M.IVY,3); p.set(x,187,M.IVY,1); p.set(x,200,M.IVY,2); if(x%8===0) for(let y=186;y<214;y++) p.set(x,y,M.IVY,1); }
    for(let x=0;x<240;x++) for(let y=214;y<226;y++) p.set(x,y,M.CONC,y===214?4:2);
    out.el_plat=p.s; }
  // 역 표지(지붕에 매단 검은 판 · 흰 글자 · 초록 4 동그라미)
  for(const id in STN){ const S=STN[id]; if(!S.el) continue; const w=S.sign.length*6+26, p=paint(w,13);
    p.rect(0,0,w,13,M.MDARK,(q,j)=>j===0||j===12?2:0); signText(p,4,3,S.sign,M.FRAME,5,{e:.3});
    const cx=w-8, L7=S.line==='7'; for(let y=-4;y<=4;y++) for(let x=-4;x<=4;x++) if(x*x+y*y<=18) p.set(cx+x,6+y,L7?M.STONE:M.GRASS,L7?4:3,{e:.3}); signText(p,cx-2,3,L7?'7':'4',M.FRAME,5,{e:.4});
    out['el_sign_'+id]=p.s; }
  // ===== 7 열차 퀸스 고가: 자홍빛 도시 하늘 · 높은 맨해튼 스카이라인 · 네온 간판 상가 · 야구장 =====
  { const p=paint(SB.W,200), stops=[[0,M.DARK,0],[.4,M.DARK,1],[.68,M.STONE,1],[.86,M.NEONP,1],[1,M.NEONP,2]];
    for(let y=0;y<200;y++){ const g=y/(EL.HZ+20); let k=0; while(k<stops.length-2 && g>stops[k+1][0]) k++;
      const a=stops[k], b=stops[k+1], u=Math.max(0,Math.min(1,(g-a[0])/(b[0]-a[0])));
      for(let x=0;x<SB.W;x++){ const t=u>bay(x,y)?b:a; p.set(x,y,t[1],t[2],{e:.32}); } }
    for(let k=0;k<26;k++){ const x=Math.floor(rnd()*SB.W), y=Math.floor(rnd()*80); p.set(x,y,M.FRAME,4,{e:.6}); }       // 도시 불빛에 별은 드물다
    out.q_sky=p.s; }
  { const p=paint(960,74); let x=0; while(x<960){ const tall=rnd()<.18, w=tall?14+Math.floor(rnd()*10):8+Math.floor(rnd()*16), h=tall?44+Math.floor(rnd()*24):14+Math.floor(rnd()*30);
      for(let yy=74-h;yy<74;yy++) for(let xx=x;xx<Math.min(960,x+w);xx++){ p.set(xx,yy,M.DARK,1,{e:.14}); if(rnd()<.07) p.set(xx,yy,rnd()<.7?M.GOLD:M.FRAME,4,{e:.65}); }
      if(tall && rnd()<.5){ const sx=x+(w>>1); for(let yy=74-h-10;yy<74-h;yy++) p.set(sx,yy,M.DARK,1,{e:.14}); p.set(sx,74-h-11,M.RED,5,{e:1}); }   // 첨탑 · 항공등
      x+=w; } out.q_far=p.s; }
  { const W2=480, H2=190, p=paint(W2,H2), WORDS=['KARAOKE','TACOS','PHO','BAKERY','NAILS','24H','DELI','NOODLE','HOT POT','ARCADE','MOMO','DUMPLING','PHARMACY','MOTEL','BAR','OPEN'], NEON=[M.NEONP,M.NEONT,M.NEONO,M.GOLD,M.RED]; let x=0, wi=0;
    const neonBoard=(tx,ty,word,col)=>{ const tw=textW(word); for(let yy=ty-2;yy<ty+9;yy++) for(let xx=tx-3;xx<tx+tw+3;xx++) p.set(xx,yy,M.MDARK,0); for(let xx=tx-3;xx<tx+tw+3;xx++){ p.set(xx,ty-3,col,3,{e:.6}); p.set(xx,ty+9,col,3,{e:.6}); } signText(p,tx,ty,word,col,5,{e:1}); return tw; };
    while(x<W2){ const w=54+Math.floor(rnd()*40), floors=3+Math.floor(rnd()*3), h=floors*18+30, top=H2-h, wall=[M.BRICK,M.CONC,M.STONEL,M.WOOD][Math.floor(rnd()*4)];
      for(let yy=top;yy<H2;yy++) for(let xx=x;xx<Math.min(W2,x+w);xx++) p.set(xx,yy,wall,(yy%5===0)?1:2,{e:.05});
      for(let xx=x;xx<Math.min(W2,x+w);xx++){ p.set(xx,top,M.CONC,3); p.set(xx,top+1,M.CONC,1); }
      for(let f=0;f<floors;f++) for(let wx=x+5;wx<x+w-8;wx+=12){ const wy=top+20+f*18, lit=rnd()<.42, warm=rnd()<.6;
        for(let j=0;j<9;j++) for(let i=0;i<7;i++) p.set(wx+i,wy+j, lit?(warm?M.GOLD:M.NEONT):M.GLASS, lit?(j<2?3:4):1, {e:lit?.5:0}); }
      { const word=WORDS[wi++%WORDS.length], col=NEON[Math.floor(rnd()*NEON.length)], tw=textW(word);                     // 맨 위층 앞 네온 간판(창 너머로 보이는 높이)
        if(tw<w-8) neonBoard(x+((w-tw)>>1), top+6, word, col); }
      if(rnd()<.4){ const word=WORDS[wi++%WORDS.length], col=NEON[Math.floor(rnd()*NEON.length)], tw=textW(word), bx=x+4;   // 옥상 광고판(기둥 위)
        if(tw<w){ for(let yy=top-8;yy<top;yy++){ p.set(bx+2,yy,M.MDARK,1); p.set(bx+tw,yy,M.MDARK,1); } neonBoard(bx+2,top-19,word,col); } }
      if(rnd()<.35){ const vx=x+w-7, vc=NEON[Math.floor(rnd()*NEON.length)]; for(let yy=top+20;yy<top+20+Math.min(52,h-40);yy++){ p.set(vx,yy,M.MDARK,0); p.set(vx+1,yy,vc,5,{e:1}); p.set(vx+2,yy,M.MDARK,0); } }   // 세로 네온관
      x+=w+1+Math.floor(rnd()*3); }
    out.q_bld=p.s; }
  { const p=paint(380,104);                                                                                                         // 야구장: 붉은 벽돌 원형 입구 · 아치 창 · 조명탑
    for(let y=34;y<104;y++) for(let x=0;x<380;x++) p.set(x,y,M.BRICK,(y%6===0)?1:2,{e:.06});
    for(let x=12;x<368;x+=24) for(let y=52;y<98;y++){ for(let i=0;i<16;i++){ const dx=i-8; if(y<60 && Math.hypot(dx,(y-60)*1.1)>8) continue; p.set(x+i,y,M.GOLD,y<64?4:3,{e:.5}); } }
    for(let x=0;x<380;x++){ p.set(x,34,M.CONC,4); p.set(x,35,M.CONC,2); p.set(x,48,M.CONC,3); }
    signText(p,(380-textW('BALLPARK',2))>>1,38,'BALLPARK',M.FRAME,5,{e:.9},1);
    for(const tx of [30,350]){ for(let y=0;y<34;y++) p.set(tx,y,M.MDARK,2); for(let i=-7;i<=7;i++) for(let j=0;j<5;j++) p.set(tx+i,j,M.FRAME,5,{e:1}); }
    out.q_ball=p.s; }
  // 선풍기(천장, 네 장 날개가 돈다)
  for(let k=0;k<3;k++){ const s=paint(19,7); s.rect(8,0,3,3,M.STEEL,3); const a=k*Math.PI/6;
    for(let b=0;b<2;b++){ const t=a+b*Math.PI/2; for(let r=-8;r<=8;r++){ const x=9+Math.round(r*Math.cos(t)), y=4+Math.round(r*Math.sin(t)*.35); s.set(x,y,M.STEEL,Math.abs(r)>2?2:3); } }
    out['sb_fan'+k]=s.s; }
  // 톱니바퀴 장식(갱단 칸) · 놋쇠 랜턴
  { const s=paint(15,15); for(let y=0;y<15;y++) for(let x=0;x<15;x++){ const d=Math.hypot(x-7,y-7), a=Math.atan2(y-7,x-7), tooth=Math.cos(a*8)>.3; if((d<5.5||(tooth&&d<7.2)) && d>2) s.set(x,y,M.GOLD,d<4?4:3,{r:.4}); } out.sb_gear=s.s;
    const lr=paint(9,13); lr.rect(4,0,1,2,M.MDARK,2); lr.rect(2,2,5,1,M.GOLD,3); for(let y=3;y<11;y++){ const w=y<5||y>8?5:7, x0=(9-w)>>1; for(let x=0;x<w;x++) lr.set(x0+x,y,M.RED,(x===0||x===w-1)?3:(y%3===0?4:5),{e:.85}); }
    lr.rect(2,11,5,1,M.GOLD,3); lr.rect(4,12,1,1,M.GOLD,4); out.sb_lanternR=lr.s;
    { const on=paint(3,3); on.set(1,0,M.GOLD,3); on.rect(0,1,3,1,M.GOLD,5,{e:1}); on.set(1,2,M.GOLD,4,{e:1}); out.sb_bulbOn=on.s;
      const off=paint(3,3); off.set(1,0,M.GOLD,2); off.rect(0,1,3,1,M.GOLD,2); off.set(1,2,M.GOLD,2); out.sb_bulbOff=off.s; }                                                   // 붉은 종이 등롱
    const l=paint(5,8); l.rect(1,0,3,1,M.GOLD,3); l.rect(0,1,5,6,M.GOLD,2); l.rect(1,2,3,4,M.GOLD,5,{e:1}); l.rect(1,7,3,1,M.GOLD,2); out.sb_lantern=l.s; }
  return out;
}

