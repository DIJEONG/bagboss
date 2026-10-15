/* =========================================================
   2-f. 지하철: 객차 단면 · 터널 · 정차역 · 선로 (480×270)
   ========================================================= */
const SB={ W:480, H:270, CAR_Y:140, FLOOR:222, WIN_Y0:160, WIN_Y1:190 }; // 객차 스프라이트는 CAR_Y부터. 바닥선 FLOOR(발 y)
const DOORS=[[112,146],[334,368]];                                       // 옆문 두 칸 (x 범위)
const CAR_CONCEPTS=[
  { key:'commute', li:1.1, name:'출근 칸', wall:M.FRAME, wallK:3, seat:M.RED, light:[.92,.96,1], ad:[M.GOLD,M.ARMOR,M.RED], floor:M.CURB, desc:'졸린 출근길. 손잡이를 잡은 사람들 사이로 시비가 붙는다' },
  { key:'night', li:.72, name:'심야 칸', wall:M.SUIT, wallK:3, seat:M.ARMOR, light:[.55,.95,.85], ad:[M.NEONP,M.GRASS,M.NEONT], floor:M.ASPH, graffiti:true, broken:true, desc:'형광등 하나가 나갔다. 벽엔 낙서, 바닥엔 굴러다니는 캔' },
  { key:'ads', li:1.15, name:'광고 칸', wall:M.NEONP, wallK:3, seat:M.STONE, light:[1,.5,.85], ad:[M.NEONP,M.NEONT,M.GOLD], floor:M.SUIT, neon:true, desc:'아이돌 광고로 통째로 감싼 칸. 분홍 조명과 LED 화면' },
  { key:'cargo', li:1.0, name:'짐칸', wall:M.WOODD, wallK:3, seat:M.WOOD, light:[1,.8,.5], ad:[M.TAXI,M.WOOD,M.RED], floor:M.WOODD, cargo:true, desc:'시장 상인들의 짐과 상자가 통로를 막는다' },
  { key:'works', li:.85, name:'공사 칸', wall:M.MDARK, wallK:3, seat:M.MDARK, light:[1,.62,.25], ad:[M.TAXI,M.MDARK,M.TAXI], floor:M.MDARK, works:true, desc:'뜯겨 나간 패널, 늘어진 전선, 주황 작업등' },
  { key:'dark', li:0, name:'정전 칸', wall:M.FRAME, wallK:3, seat:M.STEEL, light:[1,.25,.18], ad:[M.FRAME,M.CURT,M.FRAME], floor:M.CURB, oneBit:true, desc:'전기가 나갔다. 붉은 비상등 몇 개만 깜빡인다 — 어둠 속 실루엣 싸움' },
  { key:'redbird', li:1.0, name:'레드버드 칸', wall:M.CURT, wallK:3, seat:M.NEONO, light:[1,.93,.82], ad:[M.RED,M.GOLD,M.CURT], floor:M.WOODD, graffiti:true, scratch:true, desc:'80년대 레드버드 차량. 창마다 칼로 긁어 새긴 낙서(스크래치티)' },
  { key:'fan', li:.9, name:'선풍기 칸', wall:M.WOOD, wallK:3, seat:M.GRASS, light:[1,.78,.5], ad:[M.GOLD,M.WOOD,M.GRASS], floor:M.WOODD, fans:true, desc:'천장 선풍기가 도는 옛 차량. 누런 백열등 아래 후텁지근하다' },
  { key:'gang', li:.8, name:'기어단 칸', wall:M.WOODD, wallK:3, seat:M.WOOD, light:[1,.66,.36], ad:[M.GOLD,M.WOODD,M.GOLD], floor:M.WOODD, gears:true, desc:"스팀펑크 갱단 '기어단'이 차지한 칸. 놋쇠 톱니와 랜턴" },
  { key:'cab', li:.55, name:'운전실', wall:M.STEEL, wallK:2, seat:M.MDARK, light:[.9,.92,1], ad:[M.MDARK,M.MDARK,M.MDARK], floor:M.MDARK, cab:true, desc:'전조등이 어둠을 가른다. 종점까지 남은 건 두목뿐' },
  { key:'local6', li:1.1, name:'6 완행 칸', wall:M.FRAME, wallK:4, seat:M.ARMOR, light:[.95,.98,1], ad:[M.ARMOR,M.GOLD,M.RED], floor:M.CURB, desc:'최신 R142 차량. 밝은 형광등 아래 다운타운으로 가는 인파' },
  { key:'market', li:1.0, name:'장보기 칸', wall:M.CURT, wallK:3, seat:M.RED, light:[1,.84,.62], ad:[M.RED,M.GOLD,M.RED], floor:M.WOODD, cargo:true, lanterns:true, desc:'캐널 스트리트 시장에서 돌아오는 장바구니와 과일 상자, 붉은 등롱' },
  { key:'dragon', li:.75, name:'청룡방 칸', wall:M.MDARK, wallK:3, seat:M.RED, light:[1,.5,.38], ad:[M.RED,M.GOLD,M.RED], floor:M.WOODD, lanterns:true, banners:true, desc:"가상의 조직 '청룡방'이 차지한 칸. 붉은 등롱과 금실 깃발" },
  { key:'show', li:1.15, name:'브로드웨이 쇼 칸', wall:M.CURT, wallK:3, seat:M.RED, light:[1,.86,.6], ad:[M.GOLD,M.RED,M.GOLD], floor:M.WOODD, marquee:true, spot:true, desc:'극장가 42번가. 낡은 천장 조명이 불규칙하게 번쩍이고 가끔 전기 불꽃이 튄다 — 관객은 브라보를 외친다' },
  { key:'viper', li:.78, name:'바이퍼스 칸', wall:M.MDARK, wallK:3, seat:M.NEONP, light:[.95,.45,1], ad:[M.NEONP,M.NEONT,M.NEONP], floor:M.ASPH, neon:true, graffiti:true, desc:"가상의 폭주족 '네온 바이퍼스'가 차지한 칸. 분홍 · 청록 네온관과 스프레이 낙서" },
  { key:'flushing', li:1.0, name:'플러싱 야시장 칸', wall:M.CURT, wallK:3, seat:M.GOLD, light:[1,.82,.6], ad:[M.RED,M.NEONT,M.GOLD], floor:M.WOODD, cargo:true, lanterns:true, desc:'메인 스트리트 야시장 상인들의 상자와 등. 꼬치 굽는 냄새가 밴 칸' },
  { key:'club', li:.66, name:'클럽 칸', wall:M.MDARK, wallK:3, seat:M.NEONT, light:[.7,.4,1], ad:[M.NEONP,M.NEONT,M.NEONO], floor:M.ASPH, neon:true, strobe:true, desc:"창고 클럽 '언더그라운드'로 가는 칸. 사이키 조명이 번쩍이고 베이스가 바닥을 울린다" },
  { key:'gallery', li:1.05, name:'그래피티 칸', wall:M.CURT, wallK:3, seat:M.NEONO, light:[1,.9,.78], ad:[M.NEONT,M.GOLD,M.NEONP], floor:M.WOODD, graffiti:true, scratch:true, desc:'윌리엄스버그로 가는 칸. 벽마다 거리 화가들의 그림' },
  { key:'ruin', li:.5, name:'폐차 칸', wall:M.MDARK, wallK:3, seat:M.STEEL, light:[.62,.9,.7], ad:[M.MDARK,M.FRAME,M.MDARK], floor:M.ASPH, broken:true, works:true, graffiti:true, desc:'운행을 멈춘 지 오래된 차량. 깜빡이는 초록 등 아래 먼지와 녹' },
];
