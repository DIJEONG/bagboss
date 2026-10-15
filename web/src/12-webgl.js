/* =========================================================
   3. WebGL2
   ========================================================= */
const canvas = document.getElementById('view');
const gl = canvas.getContext('webgl2', { antialias:false, alpha:false, preserveDrawingBuffer:false });
if(!gl){ document.getElementById('glerr').style.display='grid'; return; }

function sh(type, src){ const s=gl.createShader(type); gl.shaderSource(s,src); gl.compileShader(s);
  if(!gl.getShaderParameter(s,gl.COMPILE_STATUS)){ const e=gl.getShaderInfoLog(s); gl.deleteShader(s); throw new Error(e); } return s; }
function prog(vs, fs){ const p=gl.createProgram(); const a=sh(gl.VERTEX_SHADER,vs), b=sh(gl.FRAGMENT_SHADER,fs);
  gl.attachShader(p,a); gl.attachShader(p,b); gl.linkProgram(p); gl.deleteShader(a); gl.deleteShader(b);
  if(!gl.getProgramParameter(p,gl.LINK_STATUS)){ const e=gl.getProgramInfoLog(p); gl.deleteProgram(p); throw new Error(e); } return p; }
function tex(w,h,data){ const t=gl.createTexture(); gl.bindTexture(gl.TEXTURE_2D,t);
  gl.texImage2D(gl.TEXTURE_2D,0,gl.RGBA8,w,h,0,gl.RGBA,gl.UNSIGNED_BYTE,data||null);
  gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_MIN_FILTER,gl.NEAREST); gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_MAG_FILTER,gl.NEAREST);
  gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_WRAP_S,gl.CLAMP_TO_EDGE); gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_WRAP_T,gl.CLAMP_TO_EDGE); return t; }

const VS_SPRITE = `#version 300 es
in vec2 aPos; in vec2 aUV; in vec2 aF; in float aD; in float aR; in float aP;
uniform vec2 uRes; uniform vec2 uShake;
out vec2 vUV; flat out vec2 vF; flat out float vD; flat out float vR; flat out float vP;
void main(){ vec2 p=aPos+uShake; gl_Position=vec4(p.x/uRes.x*2.0-1.0, 1.0-p.y/uRes.y*2.0, 0.0, 1.0); vUV=aUV; vF=aF; vD=aD; vR=aR; vP=aP; }`;
const FS_SPRITE = `#version 300 es
precision highp float;
uniform sampler2D uA; uniform sampler2D uN;
uniform float uTime; uniform float uFix; uniform float uShadow; uniform vec2 uRes; uniform vec2 uShake; uniform float uWin;
uniform float uRemap[48]; // 팔레트 스왑 세트 8개 × (원래 재질, 바꿀 재질) 3쌍
in vec2 vUV; flat in vec2 vF; flat in float vD; flat in float vR; flat in float vP;
layout(location=0) out vec4 o0;
layout(location=1) out vec4 o1;
vec2 h22(vec2 p){ p=vec2(dot(p,vec2(127.1,311.7)),dot(p,vec2(269.5,183.3))); return fract(sin(p)*43758.5453); }
float cellEdge(vec2 q){ vec2 i=floor(q), f=fract(q); float d1=9.0, d2=9.0;
  for(int y=-1;y<=1;y++) for(int x=-1;x<=1;x++){ vec2 g=vec2(float(x),float(y)); vec2 o=h22(i+g);
    o=0.5+0.42*sin(uTime*0.7+6.2831*o); vec2 r=g+o-f; float d=dot(r,r);
    if(d<d1){ d2=d1; d1=d; } else if(d<d2){ d2=d; } }
  return sqrt(d2)-sqrt(d1); }
void main(){
  ivec2 t=ivec2(floor(vUV));
  vec4 a=texelFetch(uA,t,0);
  if(a.a<0.5) discard;
  if(uShadow>0.5){ o0=vec4(1.0,0.55,1.0,1.0); o1=vec4(1.0); return; }
  vec4 n=texelFetch(uN,t,0);
  vec2 nn=n.rg*2.0-1.0;
  if(vF.x>0.5 && uFix>0.5) nn.x=-nn.x;
  float mat=floor(a.r*255.0+0.5); float tone=a.g; float emit=a.b; float mask=n.b;
  if(vR>0.5){ int k=(int(vR+0.5)-1)*6; float m0=mat;
    for(int j=0;j<3;j++){ if(uRemap[k+j*2]>0.5 && abs(m0-uRemap[k+j*2])<0.5){ mat=uRemap[k+j*2+1]; break; } } }
  if(abs(mat-14.0)<0.5){
    // 물: phase = dot(world,k) + time*speed,  d.x = amplitude*sin(phase)
    vec2 wp=vec2(floor(gl_FragCoord.x), floor(uRes.y-gl_FragCoord.y))-uShake;
    float phase=wp.y*0.6+uTime*2.2;
    vec2 q=vec2(wp.x+1.5*sin(phase), wp.y);
    float e=cellEdge(q/vec2(12.0,5.0));
    // 셀 경계를 한 칸 걸러 찍어서 점선 물결로
    bool dotOn = mod(wp.x+wp.y, 2.0) < 0.5;
    if(e<0.075 && dotOn){ tone=0.9; emit=0.22; nn=vec2(0.0,0.6); }
    else { tone=0.38+0.04*step(0.5,fract(wp.y*0.5)); }
  }
  // 켜질 수 있는 창: 발광 채널에 '켜지는 순서'를 담아 두고, 시간대(uWin)에 따라 하나씩 켠다. 꺼진 창은 유리 재질로
  if(abs(mat-31.0)<0.5){ if(uWin>0.001 && emit<uWin){ emit=0.85; } else { mat=19.0; emit=0.0; } }
  if(vF.y>0.5){ mat=13.0; tone=1.0; emit=1.0; }
  if(vP>0.5 && mask>0.75) mask=0.78+vP/64.0;   // 캐릭터 선을 쓰는 캐릭터: 마스크에 파츠 번호(그리는 순서)를 싣는다
  o0=vec4(mat/255.0,tone,emit,mask);
  o1=vec4(nn*0.5+0.5,vD,n.a);   // b=깊이(0 가까움~1 하늘) a=릴리프
}`;
const VS_FULL = `#version 300 es
out vec2 vUV;
void main(){ vec2 p=vec2(float((gl_VertexID<<1)&2), float(gl_VertexID&2)); vUV=p; gl_Position=vec4(p*2.0-1.0,0.0,1.0); }`;
// 정수배가 아닌 크기에서도 픽셀 모양을 지키는 sharp-bilinear 확대
const FS_BLIT = `#version 300 es
precision highp float; uniform sampler2D uT; uniform vec2 uSrc; uniform vec2 uDst; uniform float uZoom; uniform vec2 uZC; uniform float uCamX; uniform float uVW; in vec2 vUV; out vec4 o;
void main(){
  vec2 uv=vec2((uCamX+vUV.x*uVW)/uSrc.x, vUV.y);                                     /* 세로 화면: 보이는 폭만큼 잘라 카메라 위치에서 */
  vec2 tx=clamp(((uv-uZC)/max(uZoom,1.0)+uZC)*uSrc, vec2(0.0), uSrc-vec2(0.001)); /* 줌 펀치: 맞은 자리를 향해 살짝 당긴다 */ vec2 sc=max(uDst/vec2(uVW,uSrc.y), vec2(1.0));
  vec2 fl=floor(tx); vec2 cd=fract(tx)-0.5; vec2 rr=0.5-0.5/sc;
  vec2 f=(cd-clamp(cd,-rr,rr))*sc+0.5;
  o=texture(uT,(fl+f)/uSrc);
}`;

const PRELUDE = `#version 300 es
precision highp float; precision highp int;
uniform sampler2D uInfo; uniform sampler2D uNorm; uniform sampler2D uPal;
uniform vec2 uRes; uniform float uTime; uniform int uLN;
uniform float uAmb; uniform float uEmitK; uniform vec3 uSky; uniform vec2 uSun; // 장면 환경광 배율 · 안개(하늘)색 · 화면 기준 빛이 오는 방향
uniform vec4 uLP[8]; uniform vec4 uLC[8]; uniform vec4 uLD[8];
out vec4 oC;
ivec2 PX;
vec4 gInfo(ivec2 o){ ivec2 q=clamp(PX+o, ivec2(0), ivec2(uRes)-1); return texelFetch(uInfo,q,0); }
float gMat(){ return floor(gInfo(ivec2(0)).r*255.0+0.5); }
vec3 gNormal(){ vec2 e=texelFetch(uNorm,PX,0).rg*2.0-1.0; return vec3(e, sqrt(max(0.0,1.0-dot(e,e)))); }
float gDepth(){ return texelFetch(uNorm,PX,0).b; }
vec3 pal(float p, float m, float s){ return texelFetch(uPal, ivec2(int(s), int(p)*${NMAT}+int(m)), 0).rgb; }
float luma(vec3 c){ return dot(c, vec3(0.299,0.587,0.114)); }
vec2 pxPos(){ return vec2(float(PX.x)+0.5, uRes.y-(float(PX.y)+0.5)); }
vec3 lightSum(vec3 n){
  vec2 p=pxPos(); vec3 acc=vec3(0.0);
  for(int i=0;i<8;i++){
    if(i>=uLN) break;
    vec4 lp=uLP[i], lc=uLC[i], ld=uLD[i];
    vec3 L=vec3(lp.x-p.x, -(lp.y-p.y), lp.z);
    float att; float nd;
    if(ld.w>1.5){ // 방향광(하늘·해): 감쇠 없음
      acc+=lc.rgb*lc.a*max(dot(n,normalize(ld.xyz)),0.0); continue;
    }
    if(ld.w>0.5){
      vec2 v=normalize(p-lp.xy+1e-4);
      float dd=clamp(length(p-lp.xy)/lp.w,0.0,1.0); att = smoothstep(ld.z, ld.z+(1.0-ld.z)*0.55, dot(v,ld.xy)) * (1.0-dd)*(1.0-dd*0.5); // 가장자리가 부드러운 원뿔
      nd = max(dot(n, normalize(vec3(0.0,0.45,1.0))), 0.0);
    } else {
      att=clamp(1.0-length(L)/lp.w,0.0,1.0); att*=att;
      att*=exp(-max(0.0,gDepth()-ld.z-0.02)*18.0); // 점광원은 자기 층보다 먼 곳(깊이↑)에는 약하게 닿는다
      nd=max(dot(n,normalize(L)),0.0);
    }
    acc+=lc.rgb*lc.a*att*nd;
  }
  return acc;
}
float rimSum(vec3 n){
  float t=length(n.xy); if(t<0.3) return 0.0;
  vec2 nd=n.xy/t; vec2 p=pxPos(); float r=0.0;
  for(int i=0;i<8;i++){
    if(i>=uLN) break;
    if(uLD[i].w>0.5) continue;
    vec4 lp=uLP[i], lc=uLC[i];
    vec3 L=vec3(lp.x-p.x, -(lp.y-p.y), lp.z);
    float att=clamp(1.0-length(L)/lp.w,0.0,1.0); att*=att;
    r+=smoothstep(0.3,0.9,t)*max(dot(nd,normalize(L.xy+1e-4)),0.0)*att*lc.a*luma(lc.rgb);
  }
  return r;
}
const float B4[16]=float[16](0.,8.,2.,10.,12.,4.,14.,6.,3.,11.,1.,9.,15.,7.,13.,5.);
const float B2[4]=float[4](0.,2.,3.,1.);
float thr(float mode){
  ivec2 q=PX;
  if(mode<0.5){ ivec2 r=q&3; return (B4[r.y*4+r.x]+0.5)/16.0; }
  if(mode<1.5){ ivec2 r=q&3; ivec2 s=(q>>2)&1; return (4.0*B4[r.y*4+r.x]+B2[s.y*2+s.x]+0.5)/64.0; }
  if(mode<2.5){ return abs(fract(float(q.x+q.y)/6.0)*2.0-1.0)*0.94+0.03; }
  return fract(sin(dot(vec2(q),vec2(12.9898,78.233)))*43758.5453);
}
float h12(vec2 p){ return fract(sin(dot(p,vec2(12.9898,78.233)))*43758.5453); }
vec2 gDR(ivec2 o){ ivec2 q=clamp(PX+o, ivec2(0), ivec2(uRes)-1); return texelFetch(uNorm,q,0).ba; }
// 릴리프 그림자: 빛 쪽으로 몇 칸 거슬러 가며 나보다 충분히 튀어나온 픽셀(같은 깊이 층)이 있으면 그늘
float reliefShadow(float len){
  vec2 me=gDR(ivec2(0)); vec2 d=normalize(uSun+1e-4); d.y=-d.y;
  for(int i=1;i<=8;i++){ if(float(i)>len) break;
    vec2 o=gDR(ivec2(floor(d*float(i)+0.5)));
    if(abs(o.x-me.x)<0.02 && o.y-me.y>float(i)*0.11) return 1.0; }
  return 0.0;
}
// 재질마다 다른 1비트 무늬. 반환값 T: 값이 T보다 밝으면 흰 점
float matThr(float m){
  ivec2 q=PX; ivec2 r=q&3; float b4=(B4[r.y*4+r.x]+0.5)/16.0;
  if(gInfo(ivec2(0)).a>0.75) return b4; // 캐릭터는 깨끗한 베이어로 (읽힘 우선)
  int sx=q.x, sy=int(uRes.y)-1-q.y, mi=int(m+0.5);
  if(mi==4){ float h=h12(vec2(q)); if(h<0.07) return 0.1; if(h>0.9) return 0.97; return 0.15+b4*0.7; } // 풀: 점묘
  if(mi==3) return thr(1.0)*0.9+0.05;                                                              // 잎: 베이어 8
  if(mi==5){ bool mortar=(sy%6==0)||((sx+((sy/6)%2)*7)%14==0); return mortar?0.97:b4*0.85; }        // 돌: 벽돌 줄눈
  if(mi==14) return (sy%3==0) ? b4*0.6 : 0.6+b4*0.38;                                             // 물: 가로 줄
  if(mi==11) return (sx%3==0) ? 0.93 : b4;                                                        // 나무: 세로 결
  if(mi==6||mi==8) return abs(fract(float(sx+sy)/4.0)*2.0-1.0)*0.9+0.05;                          // 금속: 사선 해칭
  if(mi==2) return thr(1.0);                                                                      // 하늘
  return b4;
}
// 캐릭터 선: 파츠 번호가 실린 캐릭터만 대상. 바깥 = 이웃 재질의 가장 어두운 단, 안쪽 = 앞 파츠가 덮는 경계
float partOf(vec4 i){ return (i.a>0.77 && i.a<0.985) ? floor((i.a-0.78)*64.0+0.5) : -1.0; }
vec4 selOut(float s){
  if(gInfo(ivec2(0)).a>0.75) return vec4(0.0);
  ivec2 O[4]=ivec2[4](ivec2(1,0),ivec2(-1,0),ivec2(0,1),ivec2(0,-1));
  for(int k=0;k<4;k++){ vec4 q=gInfo(O[k]); if(partOf(q)>=0.0) return vec4(pal(0.0,floor(q.r*255.0+0.5),s)*0.85,1.0); }
  return vec4(0.0);
}
float innerLine(){
  float p=partOf(gInfo(ivec2(0))); if(p<0.0) return 0.0; float dm=texelFetch(uNorm,PX,0).a;
  ivec2 O[4]=ivec2[4](ivec2(1,0),ivec2(-1,0),ivec2(0,1),ivec2(0,-1));
  for(int k=0;k<4;k++){ float q=partOf(gInfo(O[k])); if(q<0.0 || abs(q-p)<0.5) continue;
    float dq=texelFetch(uNorm,clamp(PX+O[k],ivec2(0),ivec2(uRes)-1),0).a;
    if(dm>0.01 || dq>0.01){ if(dq>dm+0.012) return 1.0; }       // 3D: 이웃 부위가 더 가까우면 내 쪽에 선
    else if(q>p+0.5) return 1.0; }                               // 2D 파츠: 나중에 그린 부위가 앞
  return 0.0;
}
float edgeOut(float th){
  if(gInfo(ivec2(0)).a>0.75) return 0.0;
  int t=int(th+0.5);
  for(int y=-2;y<=2;y++) for(int x=-2;x<=2;x++){
    if(abs(x)+abs(y)>t || (x==0&&y==0)) continue;
    if(gInfo(ivec2(x,y)).a>0.75) return 1.0;
  }
  return 0.0;
}
`;
const FS_DEBUG = PRELUDE + `
uniform float uMode;
void main(){
  PX=ivec2(gl_FragCoord.xy);
  vec4 i=gInfo(ivec2(0)); float m=floor(i.r*255.0+0.5); vec3 c;
  if(uMode<1.5) c=pal(0.0,m,clamp(floor(i.g*2.0*3.0),0.0,5.0));
  else if(uMode<2.5) c=gNormal()*0.5+0.5;
  else if(uMode<3.5){ vec3 L=lightSum(gNormal())+vec3(0.06); c=L/(1.0+L)*1.5; }
  else if(uMode<4.5) c=vec3(1.0,0.82,0.45)*i.b;
  else c=pal(0.0,m,clamp(floor(i.g*7.2),0.0,5.0)); // 기준 밝기에서 보이는 '원래 색'
  oC=vec4(c,1.0);
}`;

let atlasW=2048, atlasH=1024, atlasUserY=0; const USER_REG_H=1024; // 아틀라스 아래쪽 1024×1024는 불러온 원화 자리 (파츠 704줄 · 프레임 320줄)
const sprProg = prog(VS_SPRITE, FS_SPRITE);
const blitProg = prog(VS_FULL, FS_BLIT);
const dbgProg = prog(VS_FULL, FS_DEBUG);
/* =========================================================
   7-b. 후처리: 블룸 · 볼류메트릭 빛줄기 · 젖은 바닥 반사 · 비 · 비네트 · 디더 양자화
   ========================================================= */
const FS_BRIGHT = `#version 300 es
precision highp float; uniform sampler2D uC; uniform sampler2D uInfo; uniform vec2 uSrc; out vec4 o;
void main(){ ivec2 p=ivec2(gl_FragCoord.xy)*2; vec3 c=vec3(0.0);
  for(int y=0;y<2;y++) for(int x=0;x<2;x++){ ivec2 q=min(p+ivec2(x,y), ivec2(uSrc)-1); vec3 s=texelFetch(uC,q,0).rgb; float em=texelFetch(uInfo,q,0).b;
    float l=dot(s,vec3(0.3,0.59,0.11)); c+= s*(smoothstep(0.55,1.0,l)*0.7 + em*1.4); }
  o=vec4(c*0.25,1.0); }`;
const FS_BLUR = `#version 300 es
precision highp float; uniform sampler2D uT; uniform vec2 uDir; uniform vec2 uSz; out vec4 o;
void main(){ vec2 uv=gl_FragCoord.xy/uSz; vec3 c=texture(uT,uv).rgb*0.227;
  c+=(texture(uT,uv+uDir*1.385/uSz).rgb+texture(uT,uv-uDir*1.385/uSz).rgb)*0.316;
  c+=(texture(uT,uv+uDir*3.231/uSz).rgb+texture(uT,uv-uDir*3.231/uSz).rgb)*0.07; o=vec4(c,1.0); }`;
const FS_POST = `#version 300 es
precision highp float; precision highp int;
uniform sampler2D uC; uniform sampler2D uBloom; uniform sampler2D uInfo; uniform sampler2D uNorm;
uniform vec3 uGrade; uniform float uSat;
uniform float uExpo; uniform float uWinR; uniform vec2 uWinY; uniform float uPress;   // 눈 적응 노출 · 차창 반사(강도 · 창 높이) · 압력파(귀 먹먹)
uniform vec2 uRes; uniform float uTime; uniform float uBloomK; uniform float uReflY; uniform float uRain; uniform float uVig; uniform float uFog; uniform vec3 uFogC; uniform float uInv;
uniform vec4 uVP[6]; uniform vec4 uVC[6]; uniform vec4 uVD[6]; uniform int uVN;
uniform float uWetA; uniform float uWetB; uniform float uWetC; // 재질 번호: 젖은 도로 · 보도
uniform vec4 uSW[4]; uniform vec4 uSWb[4]; uniform int uSWN; uniform vec4 uSM; uniform float uSMk;   // 투명 충격파(x · y · 반지름 · 밀기) · (고리 폭 · 어둡게) · 방향 번짐(x · y · 방향×간격 · 반경)
out vec4 oC;
float bayer4(ivec2 p){ int m[16]=int[16](0,8,2,10,12,4,14,6,3,11,1,9,15,7,13,5); return float(m[(p.y&3)*4+(p.x&3)])/16.0; }
void main(){
  ivec2 px=ivec2(gl_FragCoord.xy); vec2 uv=(vec2(px)+0.5)/uRes;
  // 투명 충격파: 고리 위의 픽셀을 바깥으로 밀어 읽는다(굴절) · 정수 픽셀로 밀어 도트가 뭉개지지 않게 · 안쪽은 살짝 어둡게
  vec2 p0=vec2(float(px.x)+0.5, uRes.y-float(px.y)-0.5), swOff=vec2(0.0); float swDk=0.0;
  for(int i=0;i<4;i++){ if(i>=uSWN) break; vec2 v=p0-uSW[i].xy; float d=length(v), r=uSW[i].z, x=(d-r)/uSWb[i].x;
    if(abs(x)<1.0){ float pr=1.0-x*x; swOff+=(v/max(d,0.001))*uSW[i].w*pr; swDk+=uSWb[i].y*(x>0.0?1.1:0.6)*pr; }   /* 바깥 테두리가 가장 짙게(레퍼런스의 돔 윤곽) */
    if(d<r) swDk+=uSWb[i].y*(0.35+0.65*d/max(r,1.0)); }
  ivec2 ro=ivec2(floor(swOff+0.5)), sp=clamp(px+ivec2(-ro.x, ro.y), ivec2(0), ivec2(uRes)-1);
  vec3 c=texelFetch(uC,sp,0).rgb;
  if(uSMk>0.0){ float dm=length(p0-uSM.xy); if(dm<uSM.w){ vec3 acc=c; for(int j=1;j<4;j++) acc+=texelFetch(uC, clamp(sp+ivec2(int(uSM.z)*j,0), ivec2(0), ivec2(uRes)-1),0).rgb;   // 묵직한 타격: 1~2프레임 진행 방향 번짐
    c=mix(c, acc*0.25, uSMk*(1.0-dm/uSM.w)); } }
  c*=1.0-min(swDk,0.35);
  // 차창 반사: 유리는 빛의 4~5%를 되비춘다. 바깥이 어두우면(터널) 반사된 실내가 보이고, 밝으면(다리 위) 반사가 묻힌다
  if(uWinR>0.0){ float ysw=uRes.y-float(px.y)-0.5; float dep=texelFetch(uNorm,px,0).b;
    if(dep>0.7 && ysw>=uWinY.x && ysw<uWinY.y && px.x>8 && px.x<int(uRes.x)-8){
      float outL=dot(c,vec3(.3,.59,.11)), dark=1.0-smoothstep(0.12,0.45,outL);
      vec3 seat=texelFetch(uC,ivec2(px.x+2, int(uRes.y-(2.0*uWinY.y-ysw))),0).rgb;          // 아래(좌석 · 사람)를 위로 뒤집어 비춤
      vec3 lamp=texelFetch(uC,ivec2(px.x, int(uRes.y-(2.0*uWinY.x-ysw))),0).rgb;            // 창 윗부분엔 천장 형광등이 비침
      float tw=1.0-smoothstep(uWinY.x,uWinY.x+7.0,ysw);
      c += (seat*0.55 + lamp*0.8*tw)*uWinR*dark; } }
  vec4 info=texelFetch(uInfo,px,0); float mat=floor(info.r*255.0+0.5);
  float ys=uRes.y-float(px.y)-0.5; vec2 p=vec2(float(px.x)+0.5, ys);
  // 젖은 바닥: 건물 밑선(uReflY)을 축으로 위쪽을 뒤집어 비춘다. 웅덩이(톤이 높은 도로)는 거의 거울
  float refl = abs(mat-uWetA)<0.5 ? (info.g>0.7 ? 0.95 : 0.42) : abs(mat-uWetB)<0.5 ? 0.16 : 0.0;
  if(refl>0.0 && info.a<0.75){ float yr=2.0*uReflY-ys;
    if(yr>1.0){ float wob=sin(ys*0.9+uTime*2.3)*(info.g>0.7?0.6:1.4); vec3 r=texture(uC,vec2(p.x+wob, uRes.y-yr)/uRes).rgb;
      float fade=exp(-(ys-uReflY)/70.0); c+= r*refl*fade; } }
  // 볼류메트릭: 원뿔 안의 산란 + 광원 주변 헤일로
  for(int i=0;i<6;i++){ if(i>=uVN) break;
    vec2 v=p-uVP[i].xy; float d=length(v), along=dot(v,uVP[i].zw);
    if(along>0.0 && along<uVD[i].y){ float ca=along/max(d,0.001); float inside=smoothstep(uVD[i].x,uVD[i].x+(1.0-uVD[i].x)*0.7,ca);
      float fall=pow(1.0-along/uVD[i].y,1.5); float n=0.82+0.18*sin(p.x*0.11+p.y*0.05+uTime*0.7);
      c+= uVC[i].rgb*uVC[i].a*inside*fall*n*0.2; }
    c+= uVC[i].rgb*uVC[i].a*0.08/(1.0+d*d/(uVD[i].z*uVD[i].z)); }
  // 안개: 화면 아래(가까움)는 옅고 위는 짙게 — 밤거리의 습기
  c=mix(c,uFogC,uFog*smoothstep(uRes.y,0.0,ys)*0.6);
  // 블룸
  c*=uExpo;                                                                       // 눈 적응: 밝은 데로 나오면 과노출, 어두운 데로 들어가면 새카맣다가 서서히
  c+= texture(uBloom,uv).rgb*uBloomK*max(1.0,uExpo);
  if(uPress>0.0){ vec2 q2=uv-0.5; c*=1.0-uPress*smoothstep(0.08,0.5,dot(q2,q2)*2.2); }      // 압력파: 귀가 먹먹한 듯 가장자리가 잠깐 조인다
  // 비: 기울어진 가는 줄
  if(uRain>0.0){ float sx=p.x+ys*0.22; float col=floor(sx/3.0); float h=fract(sin(col*91.7)*437.5);
    float len=50.0+h*80.0, t=fract((ys-uTime*(260.0+h*140.0)+h*500.0)/len);                  // 위에서 아래로 떨어진다
    if(t<0.07 && fract(h*13.0)<uRain && mod(sx,3.0)<1.0) c+=vec3(0.32,0.36,0.42)*(t/0.07)*0.55; }        // 아래쪽(앞쪽) 끝이 밝게
  // 비네트 + 디더 양자화(채널당 24단) — 부드러운 빛을 넣어도 픽셀 질감이 남게
  c=mix(vec3(dot(c,vec3(.299,.587,.114))), c, uSat)*uGrade;                                  // 노선별 색 보정(곱하기 · 채도)
  vec2 q=uv-0.5; c*=1.0-uVig*dot(q,q)*1.7;
  if(uInv>0.5){ float l=dot(c,vec3(.3,.59,.11)); c=vec3(1.0)-vec3(l*1.4); }      // 임팩트 프레임: 한 프레임 흑백 반전
  c=floor(c*24.0+bayer4(px)+0.0)/24.0;
  oC=vec4(c,1.0);
}`;
const brightProg=prog(VS_FULL,FS_BRIGHT), blurProg=prog(VS_FULL,FS_BLUR), postProg=prog(VS_FULL,FS_POST);
let postTex=null, bloomA=null, bloomB=null; const pFB=gl.createFramebuffer(), bFA=gl.createFramebuffer(), bFB=gl.createFramebuffer();
function linTex(w,h){ const t=tex(w,h); gl.bindTexture(gl.TEXTURE_2D,t); gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_MIN_FILTER,gl.LINEAR); gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_MAG_FILTER,gl.LINEAR); return t; }
function allocPost(){
  for(const t of [postTex,bloomA,bloomB]) if(t) gl.deleteTexture(t);
  postTex=linTex(W,H); bloomA=linTex(W>>1,H>>1); bloomB=linTex(W>>1,H>>1);
  for(const [fb,t] of [[pFB,postTex],[bFA,bloomA],[bFB,bloomB]]){ gl.bindFramebuffer(gl.FRAMEBUFFER,fb); gl.framebufferTexture2D(gl.FRAMEBUFFER,gl.COLOR_ATTACHMENT0,gl.TEXTURE_2D,t,0); }
  gl.bindFramebuffer(gl.FRAMEBUFFER,null);
}
allocPost();
const POSTV=new Float32Array(24), POSTC=new Float32Array(24), POSTD=new Float32Array(24), SWA=new Float32Array(16), SWB=new Float32Array(16);
// fx: { bloom, reflY, rain, vig, fog, fogC, vols:[{x,y,dx,dy,c,i,cone,len,halo}] }
let IMPF=0;   // 임팩트 프레임: 남은 프레임 수(이 동안 화면 흑백 반전)
function runPost(fx, time){
  const hw=W>>1, hh=H>>1;
  gl.bindVertexArray(emptyVAO);
  gl.bindFramebuffer(gl.FRAMEBUFFER,bFA); gl.viewport(0,0,hw,hh); gl.useProgram(brightProg);
  gl.activeTexture(gl.TEXTURE0); gl.bindTexture(gl.TEXTURE_2D,compTex); gl.activeTexture(gl.TEXTURE1); gl.bindTexture(gl.TEXTURE_2D,gInfo);
  gl.uniform1i(U(brightProg,'uC'),0); gl.uniform1i(U(brightProg,'uInfo'),1); gl.uniform2f(U(brightProg,'uSrc'),W,H); gl.drawArrays(gl.TRIANGLES,0,3);
  gl.useProgram(blurProg); gl.uniform1i(U(blurProg,'uT'),0); gl.uniform2f(U(blurProg,'uSz'),hw,hh);
  for(const r of [1,2]){
    gl.bindFramebuffer(gl.FRAMEBUFFER,bFB); gl.activeTexture(gl.TEXTURE0); gl.bindTexture(gl.TEXTURE_2D,bloomA); gl.uniform2f(U(blurProg,'uDir'),r,0); gl.drawArrays(gl.TRIANGLES,0,3);
    gl.bindFramebuffer(gl.FRAMEBUFFER,bFA); gl.bindTexture(gl.TEXTURE_2D,bloomB); gl.uniform2f(U(blurProg,'uDir'),0,r); gl.drawArrays(gl.TRIANGLES,0,3); }
  gl.bindFramebuffer(gl.FRAMEBUFFER,pFB); gl.viewport(0,0,W,H); gl.useProgram(postProg);
  gl.activeTexture(gl.TEXTURE0); gl.bindTexture(gl.TEXTURE_2D,compTex); gl.activeTexture(gl.TEXTURE1); gl.bindTexture(gl.TEXTURE_2D,bloomA);
  gl.activeTexture(gl.TEXTURE2); gl.bindTexture(gl.TEXTURE_2D,gInfo); gl.activeTexture(gl.TEXTURE3); gl.bindTexture(gl.TEXTURE_2D,gNorm);
  const u=n=>U(postProg,n);
  gl.uniform1i(u('uC'),0); gl.uniform1i(u('uBloom'),1); gl.uniform1i(u('uInfo'),2); gl.uniform1i(u('uNorm'),3);
  gl.uniform1f(u('uExpo'),fx.expo??1); gl.uniform1f(u('uWinR'),fx.winR||0); gl.uniform2f(u('uWinY'),...(fx.winY||[0,0])); gl.uniform1f(u('uPress'),fx.press||0);
  gl.uniform2f(u('uRes'),W,H); gl.uniform1f(u('uTime'),time); gl.uniform1f(u('uBloomK'),fx.bloom); gl.uniform1f(u('uReflY'),fx.reflY);
  gl.uniform3f(u('uGrade'),...(fx.grade||[1,1,1])); gl.uniform1f(u('uSat'),fx.sat??1);
  gl.uniform1f(u('uRain'),fx.rain); gl.uniform1f(u('uInv'),(fx.inv||IMPF>0)?1:0); if(IMPF>0) IMPF--; gl.uniform1f(u('uVig'),fx.vig); gl.uniform1f(u('uFog'),fx.fog); gl.uniform3f(u('uFogC'),...fx.fogC);
  gl.uniform1f(u('uWetA'),M.ROADW); gl.uniform1f(u('uWetB'),M.CURB); gl.uniform1f(u('uWetC'),-1);
  const V=fx.vols.slice(0,6), vsh=SHK(); V.forEach((v,i)=>{ POSTV.set([v.x+vsh,v.y,v.dx,v.dy],i*4); POSTC.set([v.c[0],v.c[1],v.c[2],v.i],i*4); POSTD.set([v.cone,v.len,v.halo,0],i*4); });
  gl.uniform4fv(u('uVP'),POSTV); gl.uniform4fv(u('uVC'),POSTC); gl.uniform4fv(u('uVD'),POSTD); gl.uniform1i(u('uVN'),V.length);
  { const on=typeof GS!=='undefined' && GS.on, now=on?GS.time:0; let n=0; SWA.fill(0); SWB.fill(0);   // 투명 충격파 · 방향 번짐(게임 시간 기준이라 느리게 돌리면 함께 느려진다)
    if(on && GS.sw){ GS.sw=GS.sw.filter(q=>now<q.t0+q.life && now>q.t0-1);
      for(const q of GS.sw){ const uu=(now-q.t0)/q.life; if(uu<0 || n>=4) continue; const e=1-Math.pow(1-uu,2.2), dk=Math.pow(1-uu,1.4);
        SWA.set([q.x+vsh, q.y, q.r0+(q.r1-q.r0)*e, q.amp*dk], n*4); SWB.set([q.w*(.7+.3*e), q.dark*(1-uu), 0, 0], n*4); n++; } }
    gl.uniform4fv(u('uSW'),SWA); gl.uniform4fv(u('uSWb'),SWB); gl.uniform1i(u('uSWN'),n);
    const M0=on && GS.smear, mu=M0 ? (now-M0.t0)/M0.life : 1;
    if(M0 && mu>=0 && mu<1){ gl.uniform4f(u('uSM'), M0.x+vsh, M0.y, M0.f*2, M0.R); gl.uniform1f(u('uSMk'), .8*(1-mu)); }
    else { gl.uniform4f(u('uSM'),0,0,0,0); gl.uniform1f(u('uSMk'),0); if(M0 && (mu>=1 || mu<-1)) GS.smear=null; } }
  gl.drawArrays(gl.TRIANGLES,0,3);
  return postTex;
}
/* =========================================================
   6-b. 3D 리그 캐릭터 → 픽셀 G-버퍼 (데드 셀 방식)
   뼈대·동작표·IK·보폭 걷기가 계산한 관절 위치로 로우폴리 부위를 3D 공간에 놓고,
   원본 해상도로 래스터화해 재질·톤·노멀·깊이를 G-버퍼에 쓴다 → 조명·팔레트·캐릭터 선·후처리는 그대로 적용
   ========================================================= */
const VS_3D = `#version 300 es
in vec3 aP; in vec2 aN; in float aT; in float aM; in float aK; in float aD; in float aE;
uniform vec2 uRes; uniform vec2 uShake;
flat out vec2 vN; flat out float vT; flat out float vM; flat out float vK; flat out float vD; flat out float vE;
void main(){ vec2 p=aP.xy+uShake; gl_Position=vec4(p.x/uRes.x*2.0-1.0, 1.0-p.y/uRes.y*2.0, aP.z, 1.0); vN=aN; vT=aT; vM=aM; vK=aK; vD=aD; vE=aE; }`;
const FS_3D = `#version 300 es
precision highp float; flat in vec2 vN; flat in float vT; flat in float vM; flat in float vK; flat in float vD; flat in float vE;
layout(location=0) out vec4 o0; layout(location=1) out vec4 o1;
void main(){ o0=vec4(vM/255.0, vT, vE, 0.78+vK/64.0); o1=vec4(vN*0.5+0.5, 0.0, vD); }`;
const prog3=prog(VS_3D,FS_3D), vao3=gl.createVertexArray(), vbo3=gl.createBuffer(), F3=10, MAX3=12000;
const v3=new Float32Array(MAX3*3*F3); let n3=0;
gl.bindVertexArray(vao3); gl.bindBuffer(gl.ARRAY_BUFFER,vbo3); gl.bufferData(gl.ARRAY_BUFFER,v3.byteLength,gl.DYNAMIC_DRAW);
for(const [name,size,off] of [['aP',3,0],['aN',2,3],['aT',1,5],['aM',1,6],['aK',1,7],['aD',1,8],['aE',1,9]]){
  const loc=gl.getAttribLocation(prog3,name); if(loc<0) continue; gl.enableVertexAttribArray(loc); gl.vertexAttribPointer(loc,size,gl.FLOAT,false,F3*4,off*4); }
gl.bindVertexArray(null);
// 조각: y축을 따라 가늘어지는 상자. 위 단면(앞뒤 반폭 hw0, 좌우 반폭 hd0, 중심 cx0) → 아래 단면
function prism(y0,y1,cx0,hw0,hd0,cx1,hw1,hd1,mat,tone,part,cz=0){
  const A=[[cx0-hw0,y0,cz-hd0],[cx0+hw0,y0,cz-hd0],[cx0+hw0,y0,cz+hd0],[cx0-hw0,y0,cz+hd0]];
  const B=[[cx1-hw1,y1,cz-hd1],[cx1+hw1,y1,cz-hd1],[cx1+hw1,y1,cz+hd1],[cx1-hw1,y1,cz+hd1]];
  return { q:[[A[0],A[1],A[2],A[3]],[B[0],B[1],B[2],B[3]],[A[0],A[1],B[1],B[0]],[A[1],A[2],B[2],B[1]],[A[2],A[3],B[3],B[2]],[A[3],A[0],B[0],B[3]]],
    mat, tone, part, c:[(cx0+cx1)/2,(y0+y1)/2,cz] };
}
// 느와르 인물 모델 (단위 px). 뼈마다 조각 목록. 부위 번호(part)는 캐릭터 선의 경계 판정용
function noirModel(o={}){
  if(o.suit) return suitModel(o);
  const C=o.coat||M.COAT, T=o.trou||M.SUIT, S=M.SKIN, HAT=o.hatMat||M.HAIR, cap=!!o.cap;
  const head=[ prism(-3,0, .5,1.6,1.6, .5,1.8,1.8, S,.5,1),                                    // 목
    prism(-11.5,-2.6, .8,3.9,3.6, 1.1,3.2,3.0, S,.6,1),                                        // 머리 · 턱
    prism(-7.6,-5.4, 4.6,.9,.8, 5.4,1.0,.8, S,.66,1),                                           // 코
    prism(-8.4,-7.3, 4.65,.35,.5, 4.65,.35,.5, M.INK,.5,1, 1.7), prism(-8.4,-7.3, 4.65,.35,.5, 4.65,.35,.5, M.INK,.5,1,-1.7), // 눈
    prism(-7.8,-5.2, -.6,1.0,.5, -.6,1.0,.5, S,.45,1, 3.8),                                     // 귀
    prism(-11,-5.5, -2.8,1.2,3.8, -3.0,1.1,3.7, M.HAIR,.32,1) ];                                // 뒷머리
  if(cap) head.push(prism(-13.5,-10.2, .2,4.2,4.0, .4,4.4,4.2, HAT,.42,1), prism(-10.8,-10.0, 4.5,2.2,3.6, 5.2,2.4,3.6, HAT,.36,1));
  else head.push(prism(-16,-11.6, .6,3.5,3.5, .6,4.0,4.0, HAT,.45,1), prism(-12.2,-11.3, .6,4.05,4.05, .6,4.1,4.1, M.RED,.36,1),
    prism(-11.5,-10.7, 1.0,6.4,5.9, 1.0,6.7,6.2, HAT,.38,1));
  return {
    head,
    torso:[ prism(1,17, 0,4.1,7.4, 0,3.6,5.6, C,.52,2), prism(-1.5,2.6, .2,3.0,4.0, .2,3.9,5.3, C,.64,2),     // 몸통 · 세운 칼라
      prism(1,7.5, 4.0,.35,1.7, 3.7,.35,.25, M.FRAME,.72,2), prism(1.6,9.5, 4.25,.3,.55, 3.85,.3,.55, M.RED,.42,2), // 셔츠 · 넥타이
      prism(14,15.6, 0,3.75,5.75, 0,3.75,5.75, C,.3,2) ],                                                         // 벨트
    skirtF:[ prism(-.5,14, 0,4.2,3.0, .6,5.3,4.0, C,.5,3, 2.6) ], skirtB:[ prism(-.5,14, 0,4.2,3.0, .6,5.3,4.0, C,.46,4,-2.6) ],
    uarmF:[ prism(-1,8, 0,2.4,2.3, 0,2.0,2.0, C,.46,5) ], farmF:[ prism(0,7.6, 0,2.0,2.0, 0,1.7,1.7, C,.44,6), prism(7.3,10.2, .3,1.7,1.5, .4,1.6,1.4, S,.6,6) ],
    uarmB:[ prism(-1,8, 0,2.4,2.3, 0,2.0,2.0, C,.4,7) ], farmB:[ prism(0,7.6, 0,2.0,2.0, 0,1.7,1.7, C,.38,8), prism(7.3,10.2, .3,1.7,1.5, .4,1.6,1.4, S,.55,8) ],
    thighF:[ prism(-1,11, 0,2.9,2.7, 0,2.5,2.4, T,.5,9) ], shinF:[ prism(0,11, 0,2.4,2.3, 0,2.1,2.0, T,.48,10) ], footF:[ prism(-3,0, 1.6,4.0,2.0, 1.8,4.1,2.0, M.MDARK,.55,10) ],
    thighB:[ prism(-1,11, 0,2.9,2.7, 0,2.5,2.4, T,.44,11) ], shinB:[ prism(0,11, 0,2.4,2.3, 0,2.1,2.0, T,.42,12) ], footB:[ prism(-3,0, 1.6,4.0,2.0, 1.8,4.1,2.0, M.MDARK,.5,12) ],
    bat:[ prism(-1,15, 0,.8,.8, 0,1.35,1.35, M.WOOD,.55,13) ],
    paper:[ prism(-1,9, 0,1.1,1.1, 0,1.2,1.2, M.FRAME,.6,13) ], umb:[ prism(-5,-1, -1.6,1.1,.9, -1.6,1.1,.9, M.WOOD,.55,13), prism(-6,-4, -3.0,1.0,.8, -3.0,1.0,.8, M.WOOD,.5,13),   // 나무 J 손잡이
      prism(-1,1, 0,1.0,1.0, 0,1.0,1.0, M.STEEL,.8,13),                                                                            // 쇠 고리
      prism(1,17, 0,1.9,1.9, 0,1.0,1.0, M.SUIT,.72,13), prism(7,8.5, 0,2.0,2.0, 0,2.0,2.0, M.BONE,.7,13),                         // 접힌 천 · 똑딱이 끈
      prism(17,22, 0,.7,.7, 0,.55,.55, M.STEEL,.75,13), prism(22,24, 0,.6,.6, 0,.3,.3, M.STEEL,.95,13) ],                         // 살대 끝 · 뾰족한 쇠 끝
    case:[ prism(0,7, 0,4.2,1.6, 0,4.2,1.6, M.WOODD,.5,13), prism(-1.5,0, 0,1.6,.6, 0,1.6,.6, M.MDARK,.5,13) ],
    hammer:[ prism(-3,10, 0,.55,.4, 0,.6,.45, M.WOOD,.5,13), prism(10,13, 0,1.0,.6, 0,1.0,.6, M.STEEL,.7,13), prism(9.5,10.5, 0,3.6,.7, 0,3.4,.7, M.STEEL,.75,13), prism(10,11.5, -3.2,1.6,.5, -4.4,1.2,.4, M.STEEL,.6,13) ],   // 장도리(자루 · 머리 · 노루발)
    guitar:[ prism(-2,5, 0,.5,.35, 0,.5,.35, M.WOODD,.45,13), prism(5,9, 0,2.0,.8, 0,2.6,.9, M.WOOD,.55,13), prism(9,13, 0,2.6,.9, 0,2.2,.8, M.WOOD,.5,13), prism(-4,-2, 0,.7,.4, 0,.7,.4, M.MDARK,.4,13) ],
    pan:[ prism(-1,6, 0,.45,.4, 0,.45,.4, M.MDARK,.5,13), prism(6,13, 0,3.0,.45, 0,3.0,.45, M.MDARK,.4,13), prism(6.5,12.5, 0,2.4,.5, 0,2.4,.5, M.STEEL,.55,13) ],   // 프라이팬
    cleaver:[ prism(-1,3, 0,.6,.5, 0,.6,.5, M.WOODD,.5,13), prism(3,11, 0,2.0,.25, 0,2.4,.25, M.STEEL,.8,13) ],   // 정육 식칼
    wrench:[ prism(-1,14, 0,.9,.7, 0,1.0,.8, M.STEEL,.6,13), prism(14,17, 0,2.4,.9, 0,2.4,.9, M.STEEL,.65,13) ], knife:[ prism(-1,2, 0,.7,.6, 0,.7,.6, M.MDARK,.5,13), prism(2,8, 0,.35,.5, 0,.2,.3, M.STEEL,.75,13) ],
  };
}
// 양복 인물: 재킷 자락은 엉덩이까지만, 모자 대신 넘긴 머리(+수염). 패거리는 헌팅캡
function suitModel(o){
  const C=o.coat||M.SUIT, T=o.trou||M.SUIT, S=M.SKIN, H=M.HAIR;
  const base=noirModel({ ...o, suit:false, coat:C, trou:T });
  const head=[ prism(-3,0, .5,1.6,1.6, .5,1.8,1.8, S,.5,1), prism(-11.5,-2.6, .8,3.9,3.6, 1.1,3.2,3.0, S,.6,1),
    prism(-7.6,-5.4, 4.6,.9,.8, 5.4,1.0,.8, S,.66,1),
    prism(-7.8,-5.2, -.6,1.0,.5, -.6,1.0,.5, S,.45,1, 3.8) ];
  if(o.cap) head.push(prism(-11,-5.5, -2.8,1.2,3.8, -3.0,1.1,3.7, H,.32,1), prism(-13.5,-10.2, .2,4.2,4.0, .4,4.4,4.2, M.HAIR,.42,1), prism(-10.8,-10.0, 4.5,2.2,3.6, 5.2,2.4,3.6, M.HAIR,.36,1));
  else head.push(prism(-12.8,-10.2, .1,4.3,3.95, .2,4.1,3.85, H,.3,1),                      // 넘긴 윗머리
    prism(-11,-3.2, -2.7,1.4,3.85, -3.0,1.2,3.7, H,.27,1),                                      // 목덜미까지 내려온 뒷머리
    prism(-12.2,-9.6, 3.6,1.0,3.6, 3.2,.8,3.4, H,.36,1),                                        // 앞머리
    prism(-5.6,-2.5, 2.6,2.0,3.2, 2.0,1.7,2.7, H,.33,1));                                       // 수염
  // 머리 스타일(스팀펑크 포함): 톱햇+놋쇠 고글 · 모히칸 · 퐁파두르 · 고글 가죽모자 · 반다나 · 민머리
  if(o.hair){ head.length=4; const hb=(m,t)=>prism(-12.6,-9.6, .1,4.25,3.95, .2,4.15,3.9, m,t,1);
    const lens=(y0,y1,x)=>[prism(y0,y1, x,.6,1.0, x,.6,1.0, M.GOLD,.7,1, 1.35), prism(y0,y1, x,.6,1.0, x,.6,1.0, M.GOLD,.7,1,-1.35), prism(y0+.4,y1-.4, x+.35,.3,.6, x+.35,.3,.6, M.GLASS,.7,1, 1.35), prism(y0+.4,y1-.4, x+.35,.3,.6, x+.35,.3,.6, M.GLASS,.7,1,-1.35)];
    if(o.hair==='tophat') head.push(prism(-11,-5, -2.8,1.2,3.8, -3,1.1,3.7, H,.3,1), prism(-21.5,-12.4, .3,3.3,3.3, .3,3.4,3.4, M.MDARK,.3,1), prism(-12.8,-11.9, .3,5.4,5.4, .3,5.4,5.4, M.MDARK,.24,1),
        prism(-13.9,-12.8, .3,3.45,3.45, .3,3.45,3.45, M.WOODD,.5,1), ...lens(-14.6,-12.2,3.5));
    if(o.hair==='mohawk') head.push(prism(-12.4,-9.6, .1,4.15,3.9, .2,4.1,3.85, S,.48,1), prism(-17,-10.6, -.2,4.6,.9, .1,3.8,1.0, M.NEONP,.5,1));
    if(o.hair==='pomp') head.push(hb(H,.3), prism(-15.2,-11, 2.6,2.6,3.5, 1.2,3.6,3.8, H,.38,1), prism(-11,-4, -2.8,1.3,3.8, -3,1.1,3.6, H,.28,1));
    if(o.hair==='goggle') head.push(hb(M.WOODD,.42), prism(-11,-6, -2.9,1.2,3.9, -3.1,1.1,3.8, M.WOODD,.36,1), prism(-11.4,-10.2, .1,4.3,4.0, .1,4.3,4.0, M.MDARK,.4,1), ...lens(-12.4,-9.8,3.9));
    if(o.hair==='bandana') head.push(hb(M.RED,.45), prism(-10.4,-7.2, -4.3,.8,.7, -5.4,.6,.6, M.RED,.4,1), prism(-11,-5, -2.8,1.2,3.8, -3,1.1,3.7, H,.3,1));
    if(o.hair==='fedora') head.push(prism(-11,-5, -2.8,1.2,3.8, -3,1.1,3.7, H,.3,1), prism(-16.4,-11.4, .4,3.4,3.5, .5,3.95,4.05, o.hatMat||M.MDARK,.44,1),   // 중절모: 움푹한 크라운 · 띠 · 앞으로 내린 챙
        prism(-16.6,-15.6, .4,1.2,2.2, .4,1.2,2.2, o.hatMat||M.MDARK,.3,1), prism(-12.4,-11.3, .5,4.0,4.1, .5,4.05,4.15, o.bandMat||M.RED,.42,1), prism(-11.6,-10.8, 1.0,6.4,6.0, 1.3,6.8,6.3, o.hatMat||M.MDARK,.34,1));
    if(o.hair==='bald') head.push(prism(-12.2,-9.6, .1,4.1,3.85, .2,4.05,3.8, S,.52,1), prism(-5.6,-2.5, 2.6,2.0,3.2, 2.0,1.7,2.7, H,.33,1)); }
  const fat=!!o.fat, tw=fat?1.75:1;                                                            // 배불뚝이: 몸통 · 허벅지가 두툼하고 배가 튀어나온다
  return { ...base, head,
    ...(fat?{ thighF:[ prism(-1,11, 0,4.0,3.7, 0,3.2,3.1, T,.4,9) ], thighB:[ prism(-1,11, 0,4.0,3.7, 0,3.2,3.1, T,.34,11) ],
              shinF:[ prism(0,11, 0,3.0,2.8, 0,2.5,2.4, T,.38,10) ], shinB:[ prism(0,11, 0,3.0,2.8, 0,2.5,2.4, T,.32,12) ],
              uarmF:[ prism(-1,8, 0,3.6,3.5, 0,3.0,3.0, C,.42,5) ], uarmB:[ prism(-1,8, 0,3.6,3.5, 0,3.0,3.0, C,.36,7) ] }:{}),
    torso: o.mandarin ? [ prism(1,17, 0,4.1*tw,7.4*tw*.9, fat?1.2:0,3.6*tw*1.2,5.6*tw*1.05, C,.42,2), prism(-1.2,2.2, .3,2.9,3.4, .3,3.1,3.7, C,.6,2),
        ...[4,7,10,13].map(y=>prism(y,y+1, 4.05,.45,.9, 4.0,.45,.9, M.GOLD,.82,2)), prism(2,16, 4.0,.22,.25, 3.7,.22,.25, C,.2,2) ] : [ prism(1,17, 0,4.1*tw,7.4*tw*.9, fat?1.2:0,3.6*tw*1.2,5.6*tw*1.05, C,.4,2),
      ...(fat?[prism(5,18, 5.0,5.2,8.2, 7.4,5.6,8.8, C,.48,2), prism(10.5,15.5, 12.4,1.0,5.0, 12.8,1.0,4.6, M.FRAME,.64,2)]:[]),   // 배불뚝이: 앞으로 불룩한 배 · 셔츠가 터질 듯 prism(-1,2.4, .4,2.6,3.2, .4,3.2,4.6, M.FRAME,.74,2),     // 재킷 · 셔츠 깃
      prism(1,9, 4.0,.35,2.2, 3.75,.35,.3, M.FRAME,.76,2), ...(o.noTie?[]:[prism(1.4,10.5, 4.25,.3,.6, 3.9,.3,.6, o.tie?M[o.tie]:M.MDARK,o.tie?.5:.3,2)]), // 흰 셔츠 V · 넥타이(기본 검정)
      prism(1,9.5, 4.1,.3,2.6, 3.8,.3,.9, C,.26,2, 0),                                                           // 깃 접힌 선(라펠)
      prism(9.5,17, 3.75,.25,.3, 3.65,.25,.3, C,.18,2, 1.0), prism(13,13.6, 3.0,.8,.3, 3.0,.8,.3, C,.2,2, 4.4) ],   // 앞여밈선 · 주머니 덮개
    skirtF:[ prism(-.5,6, 0,4.2,3.0, .3,4.5,3.4, C,.36,3, 2.6) ], skirtB:[ prism(-.5,6, 0,4.2,3.0, .3,4.5,3.4, C,.32,4,-2.6) ],
    uarmF:[ prism(-1,8, 0,2.4,2.3, 0,2.0,2.0, C,.42,5) ], uarmB:[ prism(-1,8, 0,2.4,2.3, 0,2.0,2.0, C,.36,7) ],
    thighF:[ prism(-1,11, 0,2.9,2.7, 0,2.5,2.4, T,.4,9), prism(0,10.5, 2.75,.22,.22, 2.4,.22,.22, T,.62,9) ],          // 다린 바지 주름(밝은 선)
    thighB:[ prism(-1,11, 0,2.9,2.7, 0,2.5,2.4, T,.34,11), prism(0,10.5, 2.75,.22,.22, 2.4,.22,.22, T,.55,11) ],
    shinF:[ prism(0,11, 0,2.4,2.3, 0,2.1,2.0, T,.38,10), prism(0,2.2, 2.35,.25,1.6, 2.3,.25,1.4, T,.18,10) ],          // 무릎 접힘(짙은 선)
    shinB:[ prism(0,11, 0,2.4,2.3, 0,2.1,2.0, T,.32,12), prism(0,2.2, 2.35,.25,1.6, 2.3,.25,1.4, T,.16,12) ],
    footF:[ prism(-3,0, 1.6,4.0,2.0, 1.8,4.1,2.0, M.MDARK,.5,10), prism(-3.1,-2.7, 4.2,.9,.9, 4.2,.9,.9, M.FRAME,.95,10, .6) ], // 구두 광택
    footB:[ prism(-3,0, 1.6,4.0,2.0, 1.8,4.1,2.0, M.MDARK,.45,12), prism(-3.1,-2.7, 4.2,.9,.9, 4.2,.9,.9, M.FRAME,.85,12,-.6) ],
    farmF:[ prism(0,7.0, 0,2.0,2.0, 0,1.7,1.7, C,.4,6), prism(0,1.4, -1.9,.25,1.5, -1.8,.25,1.3, C,.16,6), prism(7.0,7.8, 0,1.75,1.75, 0,1.75,1.75, M.FRAME,.74,6), prism(7.6,10.2, .3,1.7,1.5, .4,1.6,1.4, S,.6,6) ],
    farmB:[ prism(0,7.0, 0,2.0,2.0, 0,1.7,1.7, C,.34,8), prism(0,1.4, -1.9,.25,1.5, -1.8,.25,1.3, C,.14,8), prism(7.0,7.8, 0,1.75,1.75, 0,1.75,1.75, M.FRAME,.7,8), prism(7.6,10.2, .3,1.7,1.5, .4,1.6,1.4, S,.55,8) ] };
}
// 얼굴 원화: 3/4 오른쪽 보기. 1행이 눈 줄. b 눈썹 · w 흰자 · e 눈동자 · x 감은 눈 · n 코 그늘 · m 입 · o 벌린 입 · t 이
const FACES={
  neutral:["bb.bb","we.e.","....n",".mmm."],
  blink:  ["bb.bb","xx.x.","....n",".mmm."],
  atk:    ["b..b.",".bbbb","we.e.","....n","mtttm"],
  hurt:   [".b.b.","xx.x.","....n",".oo.."],
  ko:     ["b...b","xx.x.","....n","..o.."],
};
const FACE_EYE={ neutral:1, blink:1, atk:2, hurt:1, ko:1 };
const FACE_LEG={ b:[M.HAIR,.16], w:[M.FRAME,.86], e:[M.INK,.5], x:[M.SKIN,.2], n:[M.SKIN,.34], m:[M.SKIN,.22], o:[M.INK,.5], t:[M.FRAME,.92], s:[M.INK,.06], g:[M.FRAME,.97] };
function faceOf(c){
  const a=c.anim; if(FALLS.has(a)||/D$/.test(a)||a==='death'||a==='down'||a==='deathFwd'||a==='held') return 'ko';
  if(c.flash>0||REACTS.has(a)) return 'hurt';
  if(['jab','cross','hook','upper','kick','round','bat','hbutt'].includes(a)) return 'atk';
  return ((gameTime*1000+(c.d.x|0)*37)%3400<130) ? 'blink' : 'neutral';
}
function pushFace(c, headBone, ox, oy){
  const key=faceOf(c), ey=FACE_EYE[key], f=c.d.flip?-1:1, footY=c.d.y, T=boneT(headBone);
  let rows=FACES[key]; if(OPT.shades && c===GS.hero){ rows=rows.slice(); rows[ey]= key==='hurt' ? 'sgsss' : 'gssss'; }
  const A=T([4.3,-8.6,3.2]), N0=T([0,0,0]), NF=T([1,0,0]), NU=T([0,-1,0]);
  const fz=NF[2]-N0[2]; if(fz<.04) return;                                        // 얼굴이 돌아가 안 보이면 그리지 않음
  const ang=Math.atan2(NU[0]-N0[0], -(NU[1]-N0[1])), qt=((Math.round(ang/(Math.PI/2))%4)+4)%4;   // 머리 기울기를 90° 단위로
  const ax=Math.round(ox+f*A[0]), ay=Math.round(oy+A[1]), nx=f*(NF[0]-N0[0]), ny=-(NF[1]-N0[1]);
  rows.forEach((r,j)=>{ for(let i=0;i<r.length;i++){ const L=FACE_LEG[r[i]]; if(!L) continue;
    let dx=i, dy=j-ey; for(let k=0;k<qt;k++){ const t=dx; dx=-dy; dy=t; }
    const X=ax+f*dx, Y=ay+dy, z=.9-footY/300-(A[2]+1.2)/600;
    for(const [u,v] of [[0,0],[1,0],[1,1],[0,0],[1,1],[0,1]]){ if(n3>=MAX3*3) return; const o=n3*F3;
      v3[o]=X+u; v3[o+1]=Y+v; v3[o+2]=z; v3[o+3]=nx; v3[o+4]=ny; v3[o+5]=L[1]; v3[o+6]=L[0]; v3[o+7]=1; v3[o+8]=.5+A[2]/60; v3[o+9]=0; n3++; } } });
}
const M3_CACHE=new Map();
const YAW=30*Math.PI/180, CY=Math.cos(YAW), SY=Math.sin(YAW), PIT=14*Math.PI/180, CP=Math.cos(PIT), SP=Math.sin(PIT); // 3/4 시점 + 살짝 내려다봄(모자 윗면이 보이게)
// 뼈 변환: 조각 좌표 → (뼈 비틀기 · 길이 늘림 · 화면 평면 회전 · 위치) → 카메라(3/4 + 내려다봄)
function boneT(bone, sp, rl){ const cs=Math.cos(bone.th), sn=Math.sin(bone.th), yw=bone.yaw||0, cyw=Math.cos(yw), syw=Math.sin(yw), sy=bone.sy||1;
  return p=>{ const px=p[0]*cyw-p[2]*syw, pz=p[0]*syw+p[2]*cyw, py=p[1]*sy;
    let x=px*cs-py*sn+bone.x, z=pz+bone.z, y=px*sn+py*cs+bone.y;
    if(bone.ab){ const A=bone.ab, dy=y-A.py, dz=z-A.pz; y=A.py+dy*A.c-dz*A.s; z=A.pz+dy*A.s+dz*A.c; }   // 다리 벌리기: 엉덩이를 지나는 앞뒤 축으로 바깥으로 기울인다
    if(rl){ const dx=x-rl.px, dy=y-rl.py; x=rl.px+dx*rl.c-dy*rl.s; y=rl.py+dx*rl.s+dy*rl.c; }   // 화면 안 회전(날아가며 뒤로 구르기)
    if(sp){ const dx=x-sp.px, z0=z; x=sp.px+dx*sp.c-z0*sp.s; z=dx*sp.s+z0*sp.c; }   // 몸 전체 회전(돌려차기 360°)
    const xr=x*CY-z*SY, zr=x*SY+z*CY; return [xr, y*CP+zr*SP, -y*SP+zr*CP]; }; }
// 관절 → 3D 뼈: 원점 o(x,y,z), 회전 th(라디안, 화면 평면 안). 조각의 +y가 뼈 방향
function pushModel(c, B, ox, oy, remapFn, flash){
  const f=c.d.flip?-1:1, footY=c.d.y;
  for(const key in B){ const bone=B[key], pieces=c.d.model3[key]; if(!pieces||!bone) continue;
    const cs=Math.cos(bone.th), sn=Math.sin(bone.th);
    const T=boneT(bone, B._spin, B._roll);
    for(const pc of pieces){
      const cc=T(pc.c), mat=flash?M.EYE:remapFn(pc.mat), tone=flash?1:pc.tone, emit=flash?1:0;
      for(const qd of pc.q){ const P=qd.map(T);
        let ux=P[1][0]-P[0][0], uy=P[1][1]-P[0][1], uz=P[1][2]-P[0][2], vx=P[2][0]-P[0][0], vy=P[2][1]-P[0][1], vz=P[2][2]-P[0][2];
        let nx=uy*vz-uz*vy, ny=uz*vx-ux*vz, nz=ux*vy-uy*vx; const L=Math.hypot(nx,ny,nz)||1; nx/=L; ny/=L; nz/=L;
        const mx=(P[0][0]+P[2][0])/2-cc[0], my=(P[0][1]+P[2][1])/2-cc[1], mz=(P[0][2]+P[2][2])/2-cc[2];
        if(nx*mx+ny*my+nz*mz<0){ nx=-nx; ny=-ny; nz=-nz; }          // 바깥쪽을 보게
        if(nz<=0.02) continue;                                         // 뒷면은 버린다
        for(const tri of [[0,1,2],[0,2,3]]){ if(n3+3>MAX3*3) return;
          for(const k of tri){ const p=P[k], o=n3*F3;
            v3[o]=ox+f*p[0]; v3[o+1]=oy+p[1]; v3[o+2]=.9-footY/300-p[2]/600; v3[o+3]=f*nx; v3[o+4]=-ny; v3[o+5]=tone; v3[o+6]=mat; v3[o+7]=pc.part; v3[o+8]=.5+p[2]/60; v3[o+9]=emit; n3++; } } } } }
}
// 2D 리그가 계산한 관절(지역 좌표: x 앞, y 아래) → 뼈
function charBones(j, P, R, tq){
  const seg=(A,Bp,z)=>({ x:A[0], y:A[1], z, th:-Math.atan2(Bp[0]-A[0], Bp[1]-A[1]) });
  const tor=seg(j.neck, j.hips, 0), thF=seg(j.legF,j.kneeF,2.8), thB=seg(j.legB,j.kneeB,-2.8), shnF=seg(j.kneeF,j.footF,2.8), shnB=seg(j.kneeB,j.footB,-2.8);
  const ty=P.ty||0; tor.yaw=ty;                                                  // 몸통 비틀기: 펀치 때 어깨가 앞으로 돈다
  const B={ torso:tor, head:{ x:j.head[0], y:j.head[1], z:0, th:tor.th, yaw:ty*.5 },
    skirtF:{ x:j.hips[0], y:j.hips[1], z:0, th:thF.th*.55+tor.th*.45 }, skirtB:{ x:j.hips[0], y:j.hips[1], z:0, th:thB.th*.55+tor.th*.45 },
    thighF:{...thF, sy:P.strL||1}, shinF:{...shnF, sy:P.strL||1}, thighB:thB, shinB:shnB,
    footF:{ x:j.footF[0], y:j.footF[1], z:2.8, th:shnF.th*.25 }, footB:{ x:j.footB[0], y:j.footB[1], z:-2.8, th:shnB.th*.25 },
    uarmF:seg(j.shF,j.elbF,j.zF), farmF:{...seg(j.elbF,j.handF,j.zF), sy:P.strF||1}, uarmB:seg(j.shB,j.elbB,j.zB), farmB:{...seg(j.elbB,j.handB,j.zB), sy:P.strB||1} };
  B.skirtF.yaw=ty*.5; B.skirtB.yaw=ty*.5;
  if(j.wpn){ const th=-(P.w||4)*Math.PI/8; B[j.wpn]={ x:j.handF[0], y:j.handF[1], z:j.zF, th }; }
  { const sF=P.sprF??P.spr??0, sB=P.sprB??P.spr??0;   // 다리 좌우 벌리기(도) — 다리마다 따로(sprF · sprB), 없으면 spr 공통
    if(sF){ const a=sF*Math.PI/180, aF={ py:j.legF[1], pz:2.8, c:Math.cos(a), s:Math.sin(a) }; for(const k of ['thighF','shinF','footF']) B[k].ab=aF; }
    if(sB){ const a=sB*Math.PI/180, aB={ py:j.legB[1], pz:-2.8, c:Math.cos(a), s:-Math.sin(a) }; for(const k of ['thighB','shinB','footB']) B[k].ab=aB; } }
  if(P.spin){ const a=P.spin*2*Math.PI; B._spin={ px:j.hips[0], c:Math.cos(a), s:Math.sin(a) }; }
  if(P.roll){ const a=P.roll*2*Math.PI; B._roll={ px:(j.hips[0]+j.neck[0])/2, py:(j.hips[1]+j.neck[1])/2, c:Math.cos(a), s:Math.sin(a) }; }   // 몸통 중심
  return B;
}



buildSprites();
// --- 아틀라스 ---
const ATL = {};
(function pack(){
  const items = Object.entries(SPR).sort((a,b)=>b[1].h-a[1].h);
  let x=0,y=0,rowH=0; const pad=1;
  for(const [k,s] of items){
    if(x+s.w>atlasW){ x=0; y+=rowH+pad; rowH=0; }
    ATL[k]={x,y}; x+=s.w+pad; rowH=Math.max(rowH,s.h);
  }
  atlasUserY=y+rowH+2; atlasH=atlasUserY+USER_REG_H;
  const A=new Uint8Array(atlasW*atlasH*4), N=new Uint8Array(atlasW*atlasH*4);
  for(const [k,s] of items){ const o=ATL[k];
    for(let yy=0;yy<s.h;yy++) for(let xx=0;xx<s.w;xx++){
      const i=yy*s.w+xx, j=((o.y+yy)*atlasW+(o.x+xx))*4; if(!s.mat[i]) continue;
      A[j]=s.mat[i]; A[j+1]=Math.round(Math.min(1,s.tone[i])*255); A[j+2]=Math.round(s.emit[i]*255); A[j+3]=255;
      N[j]=Math.round((s.nx[i]*.5+.5)*255); N[j+1]=Math.round((s.ny[i]*.5+.5)*255); N[j+2]=Math.round(s.mask*255); N[j+3]=Math.round((s.rel?s.rel[i]:0)*255);
    }
  }
  ATL._a=tex(atlasW,atlasH,A); ATL._n=tex(atlasW,atlasH,N);
})();
const palData=new Uint8Array(STEPS*NMAT*NPAL*4);
PALS.forEach((P,pi)=>P.forEach((row,m)=>row.forEach((c,s)=>{ const j=((pi*NMAT+m)*STEPS+s)*4; palData[j]=c[0]; palData[j+1]=c[1]; palData[j+2]=c[2]; palData[j+3]=255; })));
const palTex=tex(STEPS,NMAT*NPAL,palData);

// G-버퍼 (MRT 2장) + 합성 버퍼
let gInfo=tex(W,H), gNorm=tex(W,H), compTex=tex(W,H);
gl.bindTexture(gl.TEXTURE_2D,compTex); gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_MIN_FILTER,gl.LINEAR); gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_MAG_FILTER,gl.LINEAR);
const gFB=gl.createFramebuffer(); gl.bindFramebuffer(gl.FRAMEBUFFER,gFB);
gl.framebufferTexture2D(gl.FRAMEBUFFER,gl.COLOR_ATTACHMENT0,gl.TEXTURE_2D,gInfo,0);
gl.framebufferTexture2D(gl.FRAMEBUFFER,gl.COLOR_ATTACHMENT1,gl.TEXTURE_2D,gNorm,0);
gl.drawBuffers([gl.COLOR_ATTACHMENT0,gl.COLOR_ATTACHMENT1]);
const gDepthRB=gl.createRenderbuffer(); gl.bindRenderbuffer(gl.RENDERBUFFER,gDepthRB); gl.renderbufferStorage(gl.RENDERBUFFER,gl.DEPTH_COMPONENT16,W,H);
gl.framebufferRenderbuffer(gl.FRAMEBUFFER,gl.DEPTH_ATTACHMENT,gl.RENDERBUFFER,gDepthRB); // 3D 캐릭터끼리의 가림용
const cFB=gl.createFramebuffer(); gl.bindFramebuffer(gl.FRAMEBUFFER,cFB);
gl.framebufferTexture2D(gl.FRAMEBUFFER,gl.COLOR_ATTACHMENT0,gl.TEXTURE_2D,compTex,0);
gl.bindFramebuffer(gl.FRAMEBUFFER,null);
function allocTargets(){ // 장면 해상도가 바뀌면 G-버퍼 · 합성 버퍼 · 후처리 버퍼를 새 크기로
  allocPost();
  for(const t of [gInfo,gNorm,compTex]) gl.deleteTexture(t);
  gInfo=tex(W,H); gNorm=tex(W,H); compTex=tex(W,H);
  gl.bindTexture(gl.TEXTURE_2D,compTex); gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_MIN_FILTER,gl.LINEAR); gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_MAG_FILTER,gl.LINEAR);
  gl.bindFramebuffer(gl.FRAMEBUFFER,gFB);
  gl.framebufferTexture2D(gl.FRAMEBUFFER,gl.COLOR_ATTACHMENT0,gl.TEXTURE_2D,gInfo,0);
  gl.framebufferTexture2D(gl.FRAMEBUFFER,gl.COLOR_ATTACHMENT1,gl.TEXTURE_2D,gNorm,0);
  gl.bindRenderbuffer(gl.RENDERBUFFER,gDepthRB); gl.renderbufferStorage(gl.RENDERBUFFER,gl.DEPTH_COMPONENT16,W,H);
  gl.framebufferRenderbuffer(gl.FRAMEBUFFER,gl.DEPTH_ATTACHMENT,gl.RENDERBUFFER,gDepthRB);
  gl.bindFramebuffer(gl.FRAMEBUFFER,cFB);
  gl.framebufferTexture2D(gl.FRAMEBUFFER,gl.COLOR_ATTACHMENT0,gl.TEXTURE_2D,compTex,0);
  gl.bindFramebuffer(gl.FRAMEBUFFER,null);
}

const vao=gl.createVertexArray(); gl.bindVertexArray(vao);
const vbo=gl.createBuffer(); gl.bindBuffer(gl.ARRAY_BUFFER,vbo);
const FPV=9, MAXQ=900; const vdata=new Float32Array(MAXQ*6*FPV);
gl.bufferData(gl.ARRAY_BUFFER,vdata.byteLength,gl.DYNAMIC_DRAW);
for(const [name,size,off] of [['aPos',2,0],['aUV',2,2],['aF',2,4],['aD',1,6],['aR',1,7],['aP',1,8]]){
  const loc=gl.getAttribLocation(sprProg,name); gl.enableVertexAttribArray(loc);
  gl.vertexAttribPointer(loc,size,gl.FLOAT,false,FPV*4,off*4);
}
const emptyVAO=gl.createVertexArray();
const U = (p,n)=>gl.getUniformLocation(p,n);
const sprU = { uA:U(sprProg,'uA'), uN:U(sprProg,'uN'), uTime:U(sprProg,'uTime'), uFix:U(sprProg,'uFix'), uShadow:U(sprProg,'uShadow'), uRes:U(sprProg,'uRes'), uShake:U(sprProg,'uShake'), uWin:U(sprProg,'uWin'), uRemap:U(sprProg,'uRemap') };
// 팔레트 스왑 세트: 1 붉은 해골 · 2 철갑 해골 · 3 해골 기사
// 1 붉은 해골 · 2 철갑 해골 · 3 해골 기사 · 4 MMA 블루 코너 · 5~8 거리 패거리(민소매 · 바지 · 머리/피부)
const REMAP=new Float32Array([ 10,12, 11,7, 0,0,    10,8, 11,22, 0,0,    10,7, 11,12, 0,0,    12,6, 32,33, 0,0,
  43,47, 6,12, 7,22,    43,29, 32,33, 6,4,    43,44, 44,7, 6,20,    43,20, 44,20, 32,33 ]);

