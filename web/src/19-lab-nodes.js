/* =========================================================
   8. 노드 타입 · 컴파일러
   ========================================================= */
const F='float', V3='vec3';
const TYPES = {
  gbuf:{ t:'G-버퍼', cat:'in', inputs:[], outputs:[
      {k:'base',l:'기본색',t:V3},{k:'mat',l:'재질 ID',t:F},{k:'tone',l:'톤',t:F},{k:'normal',l:'노멀',t:V3},
      {k:'emit',l:'발광',t:F},{k:'lum',l:'재질 밝기',t:F},{k:'mask',l:'캐릭터 마스크',t:F}],
    glsl:c=>`vec4 ${c.o('raw')}=gInfo(ivec2(0));
float ${c.o('mat')}=floor(${c.o('raw')}.r*255.0+0.5);
float ${c.o('tone')}=${c.o('raw')}.g*2.0;
float ${c.o('emit')}=${c.o('raw')}.b*uEmitK;
float ${c.o('mask')}=step(0.75,${c.o('raw')}.a);
vec3 ${c.o('normal')}=gNormal();
vec3 ${c.o('base')}=pal(0.0,${c.o('mat')},3.0);
float ${c.o('lum')}=luma(${c.o('base')});` },
  lights:{ t:'광원 합산', cat:'light', inputs:[{k:'normal',l:'노멀',t:V3,d:'gNormal()'}],
    outputs:[{k:'light',l:'빛 색',t:V3},{k:'lum',l:'빛 세기',t:F},{k:'tint',l:'빛 색조',t:V3}],
    params:[{k:'amb',l:'환경광',kind:'range',min:0,max:1,step:.01,v:.16},{k:'gain',l:'광원 배율',kind:'range',min:0,max:3,step:.05,v:1}],
    glsl:c=>`vec3 ${c.o('light')}=lightSum(${c.i('normal')})*${c.p('gain')}+vec3(${c.p('amb')})*uAmb;
float ${c.o('lum')}=dot(${c.o('light')},vec3(0.3333));
vec3 ${c.o('tint')}=${c.o('light')}/max(max(${c.o('light')}.r,max(${c.o('light')}.g,${c.o('light')}.b)),1e-3);` },
  relief:{ t:'릴리프 그림자', cat:'light', inputs:[], outputs:[{k:'sh',l:'그늘',t:F}],
    params:[{k:'len',l:'길이',kind:'range',min:1,max:8,step:1,v:5},{k:'str',l:'세기',kind:'range',min:0,max:1,step:.05,v:.6}],
    glsl:c=>`float ${c.o('sh')}=reliefShadow(${c.p('len')})*${c.p('str')};` },
  rim:{ t:'림라이트', cat:'light', inputs:[{k:'normal',l:'노멀',t:V3,d:'gNormal()'}], outputs:[{k:'rim',l:'림',t:F}],
    params:[{k:'str',l:'세기',kind:'range',min:0,max:2,step:.05,v:.8}],
    glsl:c=>`float ${c.o('rim')}=rimSum(${c.i('normal')})*${c.p('str')};` },
  value:{ t:'숫자', cat:'math', inputs:[], outputs:[{k:'v',l:'값',t:F}],
    params:[{k:'v',l:'값',kind:'range',min:0,max:4,step:.05,v:1}], glsl:c=>`float ${c.o('v')}=${c.p('v')};` },
  color:{ t:'색', cat:'math', inputs:[], outputs:[{k:'c',l:'색',t:V3}],
    params:[{k:'c',l:'색',kind:'color',v:'#ffffff'}], glsl:c=>`vec3 ${c.o('c')}=${c.p('c')};` },
  add:{ t:'더하기', cat:'math', inputs:[{k:'a',l:'A',t:F,d:'0.0'},{k:'b',l:'B',t:F,d:'0.0'}], outputs:[{k:'o',l:'A+B',t:F}],
    glsl:c=>`float ${c.o('o')}=${c.i('a')}+${c.i('b')};` },
  mul:{ t:'곱하기', cat:'math', inputs:[{k:'a',l:'A',t:F,d:'1.0'},{k:'b',l:'B',t:F,d:'1.0'}], outputs:[{k:'o',l:'A×B',t:F}],
    glsl:c=>`float ${c.o('o')}=${c.i('a')}*${c.i('b')};` },
  invert:{ t:'반전', cat:'math', inputs:[{k:'a',l:'값',t:F,d:'0.0'}], outputs:[{k:'o',l:'1−값',t:F}],
    glsl:c=>`float ${c.o('o')}=1.0-${c.i('a')};` },
  lumOf:{ t:'색 → 밝기', cat:'math', inputs:[{k:'c',l:'색',t:V3,d:'vec3(0.0)'}], outputs:[{k:'o',l:'밝기',t:F}],
    glsl:c=>`float ${c.o('o')}=luma(${c.i('c')});` },
  mulc:{ t:'색 × 값', cat:'math', inputs:[{k:'c',l:'색',t:V3,d:'vec3(1.0)'},{k:'v',l:'값',t:F,d:'1.0'}], outputs:[{k:'o',l:'색',t:V3}],
    glsl:c=>`vec3 ${c.o('o')}=${c.i('c')}*${c.i('v')};` },
  mulcc:{ t:'색 × 색', cat:'math', inputs:[{k:'a',l:'A',t:V3,d:'vec3(1.0)'},{k:'b',l:'B',t:V3,d:'vec3(1.0)'}], outputs:[{k:'o',l:'색',t:V3}],
    glsl:c=>`vec3 ${c.o('o')}=${c.i('a')}*${c.i('b')};` },
  addc:{ t:'색 + 색', cat:'math', inputs:[{k:'a',l:'A',t:V3,d:'vec3(0.0)'},{k:'b',l:'B',t:V3,d:'vec3(0.0)'}], outputs:[{k:'o',l:'색',t:V3}],
    glsl:c=>`vec3 ${c.o('o')}=${c.i('a')}+${c.i('b')};` },
  mixc:{ t:'색 섞기', cat:'math', inputs:[{k:'a',l:'A',t:V3,d:'vec3(0.0)'},{k:'b',l:'B',t:V3,d:'vec3(1.0)'},{k:'t',l:'비율',t:F,d:'0.5'}], outputs:[{k:'o',l:'색',t:V3}],
    glsl:c=>`vec3 ${c.o('o')}=mix(${c.i('a')},${c.i('b')},clamp(${c.i('t')},0.0,1.0));` },
  levels:{ t:'레벨 (대비)', cat:'math', inputs:[{k:'a',l:'값',t:F,d:'0.0'}], outputs:[{k:'o',l:'값',t:F}],
    params:[{k:'lo',l:'검정점',kind:'range',min:0,max:1,step:.01,v:.1},{k:'hi',l:'흰색점',kind:'range',min:0,max:1.5,step:.01,v:.9},
            {k:'g',l:'감마',kind:'range',min:.3,max:3,step:.05,v:1}],
    glsl:c=>`float ${c.o('o')}=pow(clamp((${c.i('a')}-${c.p('lo')})/max(${c.p('hi')}-${c.p('lo')},1e-3),0.0,1.0),${c.p('g')});` },
  posterize:{ t:'단계화', cat:'style', inputs:[{k:'a',l:'값',t:F,d:'0.0'}], outputs:[{k:'o',l:'단계값',t:F}],
    params:[{k:'n',l:'단계 수',kind:'range',min:2,max:8,step:1,v:4}],
    glsl:c=>`float ${c.o('o')}=min(floor(clamp(${c.i('a')},0.0,1.0)*${c.p('n')}),${c.p('n')}-1.0)/max(${c.p('n')}-1.0,1.0);` },
  ramp:{ t:'팔레트 램프', cat:'style',
    inputs:[{k:'mat',l:'재질 ID',t:F,d:'gMat()'},{k:'level',l:'밝기 단계',t:F,d:'0.5'},{k:'tint',l:'빛 색조',t:V3,d:'vec3(1.0)'}],
    outputs:[{k:'color',l:'색',t:V3}],
    params:[{k:'pal',l:'팔레트',kind:'select',opts:['밤 숲','황혼','새벽'],v:0},
            {k:'tintAmt',l:'빛 색 반영',kind:'range',min:0,max:1,step:.05,v:.4},
            {k:'dith',l:'경계 디더',kind:'range',min:0,max:1.5,step:.05,v:0}],
    glsl:c=>`float ${c.o('lv')}=clamp(${c.i('level')},0.0,1.0)*${STEPS}.0+(thr(0.0)-0.5)*${c.p('dith')};
vec3 ${c.o('color')}=pal(${c.p('pal')},${c.i('mat')},clamp(floor(${c.o('lv')}),0.0,${STEPS-1}.0))*mix(vec3(1.0),${c.i('tint')},${c.p('tintAmt')});` },
  dither:{ t:'디더', cat:'style', inputs:[{k:'a',l:'값',t:F,d:'0.5'}], outputs:[{k:'o',l:'디더 값',t:F}],
    params:[{k:'pat',l:'패턴',kind:'select',opts:['베이어 4×4','베이어 8×8','사선 해칭','노이즈'],v:0},
            {k:'lv',l:'단계 수',kind:'range',min:2,max:6,step:1,v:2},
            {k:'str',l:'세기',kind:'range',min:0,max:1.5,step:.05,v:1}],
    glsl:c=>`float ${c.o('o')}=clamp(floor(clamp(${c.i('a')},0.0,1.0)*(${c.p('lv')}-1.0)+(thr(${c.p('pat')})-0.5)*${c.p('str')}+0.5),0.0,${c.p('lv')}-1.0)/(${c.p('lv')}-1.0);` },
  matdither:{ t:'재질 패턴 디더', cat:'style',
    inputs:[{k:'a',l:'값',t:F,d:'0.5'},{k:'mat',l:'재질 ID',t:F,d:'gMat()'}], outputs:[{k:'o',l:'디더 값',t:F}],
    params:[{k:'mode',l:'무늬',kind:'select',opts:['재질마다 다르게','모두 베이어'],v:0},
            {k:'lv',l:'단계 수',kind:'range',min:2,max:6,step:1,v:2},
            {k:'str',l:'세기',kind:'range',min:0,max:1.5,step:.05,v:1}],
    glsl:c=>`float ${c.o('t')}=${c.p('mode')}<0.5 ? 1.0-matThr(${c.i('mat')}) : thr(0.0);
float ${c.o('o')}=clamp(floor(clamp(${c.i('a')},0.0,1.0)*(${c.p('lv')}-1.0)+(${c.o('t')}-0.5)*${c.p('str')}+0.5),0.0,${c.p('lv')}-1.0)/(${c.p('lv')}-1.0);` },
  edgeval:{ t:'캐릭터 테두리 (값)', cat:'style', inputs:[{k:'a',l:'값',t:F,d:'0.0'}], outputs:[{k:'o',l:'값',t:F}],
    params:[{k:'v',l:'테두리 값',kind:'range',min:0,max:1,step:.05,v:1},{k:'th',l:'두께',kind:'select',opts:['1px','2px'],v:0}],
    glsl:c=>`float ${c.o('o')}=mix(${c.i('a')},${c.p('v')},edgeOut(${c.p('th')}+1.0));` },
  fog:{ t:'안개 · 공기 원근', cat:'style', inputs:[{k:'c',l:'색',t:V3,d:'vec3(0.0)'}], outputs:[{k:'o',l:'색',t:V3}],
    params:[{k:'amt',l:'세기',kind:'range',min:0,max:1,step:.05,v:.55},{k:'start',l:'시작 깊이',kind:'range',min:0,max:1,step:.05,v:.3},
            {k:'mode',l:'안개 색',kind:'select',opts:['하늘색 따라가기','직접 지정'],v:0},{k:'col',l:'직접 지정 색',kind:'color',v:'#c9c7c0'}],
    glsl:c=>`vec3 ${c.o('o')}=mix(${c.i('c')}, ${c.p('mode')}<0.5?uSky:${c.p('col')}, smoothstep(${c.p('start')},1.0,gDepth())*${c.p('amt')});` },
  twotone:{ t:'2색 매핑', cat:'style', inputs:[{k:'a',l:'값',t:F,d:'0.0'}], outputs:[{k:'color',l:'색',t:V3}],
    params:[{k:'ink',l:'잉크',kind:'color',v:'#141217'},{k:'paper',l:'종이',kind:'color',v:'#efe9da'}],
    glsl:c=>`vec3 ${c.o('color')}=mix(${c.p('ink')},${c.p('paper')},clamp(${c.i('a')},0.0,1.0));` },
  grad4:{ t:'4색 매핑', cat:'style', inputs:[{k:'a',l:'값',t:F,d:'0.0'}], outputs:[{k:'color',l:'색',t:V3}],
    params:[{k:'c0',l:'가장 어두운 색',kind:'color',v:'#0f380f'},{k:'c1',l:'어두운 색',kind:'color',v:'#306230'},
            {k:'c2',l:'밝은 색',kind:'color',v:'#8bac0f'},{k:'c3',l:'가장 밝은 색',kind:'color',v:'#c8d89a'}],
    glsl:c=>`float ${c.o('i')}=floor(clamp(${c.i('a')},0.0,1.0)*3.0+0.5);
vec3 ${c.o('color')}=${c.o('i')}<0.5?${c.p('c0')}:(${c.o('i')}<1.5?${c.p('c1')}:(${c.o('i')}<2.5?${c.p('c2')}:${c.p('c3')}));` },
  charline:{ t:'캐릭터 선 (실루엣·겹침)', cat:'style', inputs:[{k:'color',l:'색',t:V3,d:'vec3(0.0)'}], outputs:[{k:'o',l:'색',t:V3}],
    params:[{k:'pal',l:'팔레트',kind:'select',opts:['세트 1','세트 2','세트 3'],v:0},{k:'outer',l:'바깥 외곽선',kind:'select',opts:['끔','켬'],v:1},{k:'inner',l:'겹침 선',kind:'select',opts:['끔','켬'],v:1},
            {k:'sel',l:'선 방식',kind:'select',opts:['재질의 가장 어두운 단','셀렉티브(색 섞인 선)'],v:0},{k:'tint',l:'선 색조',kind:'color',v:'#1d2b6b'}],
    glsl:c=>`vec3 ${c.o('o')}=${c.i('color')}; { vec4 so=selOut(${c.p('pal')}); vec4 me=gInfo(ivec2(0)); bool sel=${c.p('sel')}>0.5;
      if(${c.p('outer')}>0.5 && so.a>0.5) ${c.o('o')}= sel ? mix(so.rgb, ${c.p('tint')}, 0.45) : so.rgb;
      else if(${c.p('inner')}>0.5 && innerLine()>0.5){ vec3 d0=pal(0.0,floor(me.r*255.0+0.5),${c.p('pal')})*0.9;
        ${c.o('o')}= sel ? mix(${c.i('color')}*0.5+${c.p('tint')}*0.3, d0, 0.35) : d0; } }` },
  outline:{ t:'캐릭터 외곽선', cat:'style', inputs:[{k:'color',l:'색',t:V3,d:'vec3(0.0)'}], outputs:[{k:'o',l:'색',t:V3}],
    params:[{k:'col',l:'선 색',kind:'color',v:'#f6f0ff'},{k:'th',l:'두께',kind:'select',opts:['1px','2px'],v:0}],
    glsl:c=>`vec3 ${c.o('o')}=mix(${c.i('color')},${c.p('col')},edgeOut(${c.p('th')}+1.0));` },
  output:{ t:'화면 출력', cat:'out', inputs:[{k:'color',l:'색',t:V3,d:'vec3(0.0)'}], outputs:[],
    glsl:c=>`oC=vec4(clamp(${c.i('color')},0.0,1.0),1.0);` },
};
const CAT_LABEL={ in:'입력', light:'빛', math:'수학', style:'스타일', out:'출력' };
const conv=(v,from,to)=> from===to ? v : (to===V3 ? `vec3(${v})` : `luma(${v})`);

function compileGraph(g){
  const out=g.nodes.find(n=>n.type==='output'); if(!out) throw new Error('화면 출력 노드가 없어요');
  const byId=new Map(g.nodes.map(n=>[n.id,n])); const into=new Map();
  for(const l of g.links) into.set(l.t+':'+l.ti, l);
  const order=[], st=new Map();
  const visit=id=>{ const s=st.get(id); if(s===2) return; if(s===1) throw new Error('연결이 순환하고 있어요');
    st.set(id,1); const n=byId.get(id); for(const inp of TYPES[n.type].inputs){ const l=into.get(id+':'+inp.k); if(l&&byId.has(l.f)) visit(l.f); }
    st.set(id,2); order.push(id); };
  visit(out.id);
  let decl='', body=''; const uni=[];
  for(const id of order){
    const n=byId.get(id), T=TYPES[n.type];
    const ctx={
      i:k=>{ const inp=T.inputs.find(x=>x.k===k), l=into.get(id+':'+k);
        if(!l||!byId.has(l.f)) return inp.d;
        const so=TYPES[byId.get(l.f).type].outputs.find(o=>o.k===l.fo); if(!so) return inp.d;
        return conv(`n${l.f}_${l.fo}`, so.t, inp.t); },
      o:k=>`n${id}_${k}`, p:k=>`u${id}_${k}`,
    };
    for(const p of T.params||[]){ decl+=`uniform ${p.kind==='color'?'vec3':'float'} u${id}_${p.k};\n`; uni.push({node:n,k:p.k,kind:p.kind}); }
    body+=T.glsl(ctx)+'\n';
  }
  return { src: PRELUDE+decl+`void main(){\nPX=ivec2(gl_FragCoord.xy);\n${body}}\n`, uni };
}
const statusEl=document.getElementById('status');
function recompile(){
  try{
    const {src,uni}=compileGraph(graph);
    const p=prog(VS_FULL,src);
    if(compProg) gl.deleteProgram(compProg);
    compProg=p; nodeU=uni.map(u=>({...u, loc:gl.getUniformLocation(p,`u${u.node.id}_${u.k}`)}));
    statusEl.textContent=`그래프 적용됨 · 노드 ${graph.nodes.length}개`; statusEl.classList.remove('bad');
  }catch(e){
    statusEl.textContent='적용 안 됨: '+String(e.message||e).split('\n')[0].slice(0,80); statusEl.classList.add('bad');
  }
}

/* =========================================================
   9. 프리셋
   ========================================================= */
const L_=(f,fo,t,ti)=>({f,fo,t,ti});
const PRESETS = [
  { name:'컬러 도트', g:{ nodes:[
      {id:1,type:'gbuf',x:24,y:24},
      {id:2,type:'lights',x:250,y:24,p:{amb:.16,gain:1}},
      {id:3,type:'rim',x:250,y:262,p:{str:.8}},
      {id:4,type:'add',x:470,y:24},{id:5,type:'mul',x:470,y:150},{id:6,type:'add',x:470,y:276},
      {id:7,type:'ramp',x:690,y:40,p:{pal:0,tintAmt:.4,dith:0}},
      {id:8,type:'output',x:910,y:110}],
    links:[L_(1,'normal',2,'normal'),L_(1,'normal',3,'normal'),L_(2,'lum',4,'a'),L_(3,'rim',4,'b'),L_(4,'o',5,'a'),L_(1,'tone',5,'b'),
           L_(5,'o',6,'a'),L_(1,'emit',6,'b'),L_(1,'mat',7,'mat'),L_(6,'o',7,'level'),L_(2,'tint',7,'tint'),L_(7,'color',8,'color')] } },
  { name:'1비트 야간', beam:true, g:{ nodes:[
      {id:1,type:'gbuf',x:24,y:24},
      {id:2,type:'lights',x:250,y:24,p:{amb:.03,gain:1.15}},
      {id:3,type:'rim',x:250,y:262,p:{str:.5}},
      {id:4,type:'add',x:470,y:24},{id:5,type:'mul',x:470,y:150},{id:6,type:'add',x:470,y:276},
      {id:7,type:'mul',x:690,y:24},{id:8,type:'value',x:690,y:150,p:{v:2.2}},{id:9,type:'mul',x:690,y:250},
      {id:13,type:'levels',x:910,y:24,p:{lo:.12,hi:.85,g:1}},
      {id:10,type:'matdither',x:1130,y:24,p:{mode:0,lv:2,str:1}},
      {id:14,type:'edgeval',x:1130,y:290,p:{v:1,th:0}},
      {id:11,type:'twotone',x:1350,y:24,p:{ink:'#141217',paper:'#efe9da'}},
      {id:12,type:'output',x:1350,y:230}],
    links:[L_(1,'normal',2,'normal'),L_(1,'normal',3,'normal'),L_(2,'lum',4,'a'),L_(3,'rim',4,'b'),L_(4,'o',5,'a'),L_(1,'tone',5,'b'),
           L_(5,'o',6,'a'),L_(1,'emit',6,'b'),L_(6,'o',7,'a'),L_(1,'lum',7,'b'),L_(7,'o',9,'a'),L_(8,'v',9,'b'),
           L_(9,'o',13,'a'),L_(13,'o',10,'a'),L_(1,'mat',10,'mat'),L_(10,'o',14,'a'),L_(14,'o',11,'a'),L_(11,'color',12,'color')] } },
  { name:'4색 휴대기', g:{ nodes:[
      {id:1,type:'gbuf',x:24,y:24},
      {id:2,type:'lights',x:250,y:24,p:{amb:.1,gain:1}},
      {id:4,type:'mul',x:470,y:24},{id:5,type:'add',x:470,y:150},
      {id:7,type:'mul',x:690,y:24},{id:8,type:'value',x:690,y:150,p:{v:2.1}},{id:9,type:'mul',x:690,y:250},
      {id:10,type:'matdither',x:910,y:24,p:{mode:0,lv:4,str:.85}},
      {id:11,type:'grad4',x:910,y:260},
      {id:12,type:'output',x:1130,y:150}],
    links:[L_(1,'normal',2,'normal'),L_(2,'lum',4,'a'),L_(1,'tone',4,'b'),L_(4,'o',5,'a'),L_(1,'emit',5,'b'),
           L_(5,'o',7,'a'),L_(1,'lum',7,'b'),L_(7,'o',9,'a'),L_(8,'v',9,'b'),L_(9,'o',10,'a'),L_(1,'mat',10,'mat'),L_(10,'o',11,'a'),L_(11,'color',12,'color')] } },
  { name:'도시 · 흐린 날', scene:'city', g:{ nodes:[
      {id:1,type:'gbuf',x:24,y:24},
      {id:2,type:'lights',x:250,y:24,p:{amb:.2,gain:1}},
      {id:3,type:'relief',x:250,y:262,p:{len:5,str:.6}},
      {id:4,type:'invert',x:470,y:262},{id:5,type:'mul',x:470,y:24},{id:6,type:'mul',x:470,y:140},
      {id:7,type:'add',x:690,y:24},
      {id:8,type:'ramp',x:690,y:150,p:{pal:0,tintAmt:.45,dith:0}},
      {id:9,type:'fog',x:910,y:24,p:{amt:.55,start:.3,mode:0,col:'#c9c7c0'}},
      {id:10,type:'output',x:1130,y:110}],
    links:[L_(1,'normal',2,'normal'),L_(3,'sh',4,'a'),L_(2,'lum',5,'a'),L_(4,'o',5,'b'),L_(5,'o',6,'a'),L_(1,'tone',6,'b'),
           L_(6,'o',7,'a'),L_(1,'emit',7,'b'),L_(1,'mat',8,'mat'),L_(7,'o',8,'level'),L_(2,'tint',8,'tint'),L_(8,'color',9,'c'),L_(9,'o',10,'color')] } },
  { name:'비교: 양자화 없음', g:{ nodes:[
      {id:1,type:'gbuf',x:24,y:24},
      {id:2,type:'lights',x:250,y:24,p:{amb:.16,gain:1}},
      {id:3,type:'mulcc',x:470,y:24},{id:4,type:'mulc',x:470,y:150},{id:5,type:'mulc',x:470,y:276},
      {id:6,type:'addc',x:690,y:100},{id:7,type:'output',x:910,y:110}],
    links:[L_(1,'normal',2,'normal'),L_(1,'base',3,'a'),L_(2,'light',3,'b'),L_(3,'o',4,'c'),L_(1,'tone',4,'v'),
           L_(1,'base',5,'c'),L_(1,'emit',5,'v'),L_(4,'o',6,'a'),L_(5,'o',6,'b'),L_(6,'o',7,'color')] } },
];
// 옥타곤 기본 스타일: 컬러 도트 + 캐릭터 선(실루엣 외곽선 · 겹침 선)
{ const g=JSON.parse(JSON.stringify(PRESETS[0].g)), out=g.nodes.find(n=>n.type==='output'), id=Math.max(...g.nodes.map(n=>n.id))+1, L=g.links.find(l=>l.t===out.id);
  g.nodes.push({id,type:'charline',x:out.x,y:out.y,p:{pal:0,outer:1,inner:1}}); out.x+=220;
  g.links.push({f:L.f,fo:L.fo,t:id,ti:'color'}); L.f=id; L.fo='o';
  PRESETS.push({ name:'컬러 도트 · 캐릭터 선', scene:'octagon', g }); }
{ const g=JSON.parse(JSON.stringify(PRESETS[PRESETS.length-1].g)); const r=g.nodes.find(n=>n.type==='ramp'); r.p.dith=.85; r.p.tintAmt=.6;
  const cl=g.nodes.find(n=>n.type==='charline'); if(cl){ cl.p.sel=1; cl.p.tint='#1d2b6b'; }
  const l=g.nodes.find(n=>n.type==='lights'); l.p.amb=.12; PRESETS.push({ name:'느와르 · 부드러운 빛', scene:'noir', g }); }
function fillParams(g){
  for(const n of g.nodes){ n.p=n.p||{}; for(const p of TYPES[n.type].params||[]) if(n.p[p.k]===undefined) n.p[p.k]=p.v; }
  return g;
}
const clone=o=>JSON.parse(JSON.stringify(o));

/* =========================================================
   10. 노드 에디터 UI
   ========================================================= */
const ws=document.getElementById('ws'), svg=document.getElementById('wires'), sizer=document.getElementById('sizer'), edScroll=document.getElementById('edScroll');
const WS_W=1600, WS_H=860;
let graph, presetIdx=0, zoom = window.innerWidth<700 ? .75 : 1;
function setZoom(z){ zoom=Math.max(.5,Math.min(1.4,Math.round(z*20)/20)); ws.style.transform=`scale(${zoom})`;
  sizer.style.width=WS_W*zoom+'px'; sizer.style.height=WS_H*zoom+'px'; document.getElementById('zVal').textContent=Math.round(zoom*100)+'%'; }
const SAVE_KEY='dotlab.graph.v4';
let saveT=0;
function save(){ clearTimeout(saveT); saveT=setTimeout(()=>{ try{ localStorage.setItem(SAVE_KEY, JSON.stringify({graph,presetIdx})); }catch(e){} },300);
  document.getElementById('json').value=JSON.stringify(graph); }

function nodeEl(n){
  const T=TYPES[n.type], el=document.createElement('div');
  el.className='node'; el.dataset.id=n.id; el.style.left=n.x+'px'; el.style.top=n.y+'px';
  const hd=document.createElement('div'); hd.className='hd';
  hd.innerHTML=`<i style="background:var(--c-${T.cat})"></i><span>${T.t}</span>`;
  if(n.type!=='output'){ const b=document.createElement('button'); b.className='del'; b.type='button'; b.textContent='×'; b.setAttribute('aria-label',T.t+' 노드 삭제'); hd.appendChild(b); }
  el.appendChild(hd);
  for(const i of T.inputs){ const r=document.createElement('div'); r.className='row in';
    r.innerHTML=`<span class="port in" data-n="${n.id}" data-k="${i.k}" data-t="${i.t}" title="${i.l}"></span><span>${i.l}</span>`; el.appendChild(r); }
  for(const o of T.outputs){ const r=document.createElement('div'); r.className='row out';
    r.innerHTML=`<span>${o.l}</span><span class="port out" data-n="${n.id}" data-k="${o.k}" data-t="${o.t}" title="${o.l}"></span>`; el.appendChild(r); }
  if(T.params&&T.params.length){
    const box=document.createElement('div'); box.className='params';
    for(const p of T.params){
      const lab=document.createElement('label'); lab.className='param';
      const v=n.p[p.k];
      if(p.kind==='range'){
        lab.innerHTML=`<span>${p.l}</span><output>${(+v).toFixed(p.step>=1?0:2)}</output><input type="range" min="${p.min}" max="${p.max}" step="${p.step}" value="${v}">`;
        const inp=lab.querySelector('input'), out=lab.querySelector('output');
        inp.addEventListener('input',()=>{ n.p[p.k]=+inp.value; out.textContent=(+inp.value).toFixed(p.step>=1?0:2); markEdited(); });
      } else if(p.kind==='color'){
        lab.innerHTML=`<span>${p.l}</span><input type="color" value="${v}">`;
        const inp=lab.querySelector('input'); inp.addEventListener('input',()=>{ n.p[p.k]=inp.value; markEdited(); });
      } else {
        lab.innerHTML=`<span>${p.l}</span><span></span><select>${p.opts.map((o,i)=>`<option value="${i}"${+v===i?' selected':''}>${o}</option>`).join('')}</select>`;
        const sel=lab.querySelector('select'); sel.addEventListener('change',()=>{ n.p[p.k]=+sel.value; markEdited(); });
      }
      box.appendChild(lab);
    }
    el.appendChild(box);
  }
  return el;
}
function renderEditor(){
  ws.querySelectorAll('.node').forEach(e=>e.remove());
  for(const n of graph.nodes) ws.appendChild(nodeEl(n));
  drawWires();
}
function portCenter(el){ const r=el.getBoundingClientRect(), w=ws.getBoundingClientRect();
  return [ (r.left+r.width/2-w.left)/zoom, (r.top+r.height/2-w.top)/zoom ]; }
const pathD=(a,b)=>{ const dx=Math.max(40,Math.abs(b[0]-a[0])*.5); return `M${a[0]},${a[1]} C${a[0]+dx},${a[1]} ${b[0]-dx},${b[1]} ${b[0]},${b[1]}`; };
const portOf=(id,k,dir)=>ws.querySelector(`.node[data-id="${id}"] .port.${dir}[data-k="${k}"]`);
let tempPath=null;
function drawWires(){
  svg.innerHTML=''; ws.querySelectorAll('.port.on').forEach(p=>p.classList.remove('on'));
  for(const l of graph.links){
    const a=portOf(l.f,l.fo,'out'), b=portOf(l.t,l.ti,'in'); if(!a||!b) continue;
    a.classList.add('on'); b.classList.add('on');
    const p=document.createElementNS('http://www.w3.org/2000/svg','path');
    p.setAttribute('d',pathD(portCenter(a),portCenter(b)));
    p.setAttribute('stroke', a.dataset.t===V3?'var(--wc)':'var(--wf)'); svg.appendChild(p);
  }
  if(tempPath) svg.appendChild(tempPath);
}
function reaches(from, target){ // from 노드에서 아래로 내려가 target에 닿는가
  const seen=new Set(), st=[from];
  while(st.length){ const id=st.pop(); if(id===target) return true; if(seen.has(id)) continue; seen.add(id);
    for(const l of graph.links) if(l.f===id) st.push(l.t); }
  return false;
}
function connect(f,fo,t,ti){
  if(f===t) return false;
  if(reaches(t,f)) { flashStatus('순환 연결은 만들 수 없어요'); return false; }
  graph.links=graph.links.filter(l=>!(l.t===t&&l.ti===ti));
  graph.links.push({f,fo,t,ti}); return true;
}
function flashStatus(msg){ statusEl.textContent=msg; statusEl.classList.add('bad'); setTimeout(()=>recompile(),1600); }
function markEdited(){ save(); updatePresetChips(true); }
function structChanged(){ drawWires(); recompile(); save(); updatePresetChips(true); }

const wsPoint=e=>{ const w=ws.getBoundingClientRect(); return [(e.clientX-w.left)/zoom,(e.clientY-w.top)/zoom]; };
ws.addEventListener('pointerdown',e=>{
  const del=e.target.closest('.del');
  if(del){ const id=+del.closest('.node').dataset.id; graph.nodes=graph.nodes.filter(n=>n.id!==id);
    graph.links=graph.links.filter(l=>l.f!==id&&l.t!==id); renderEditor(); structChanged(); return; }
  const port=e.target.closest('.port');
  if(port){
    e.preventDefault();
    let src=null;
    if(port.classList.contains('out')) src={id:+port.dataset.n,k:port.dataset.k,t:port.dataset.t,el:port};
    else { const id=+port.dataset.n, k=port.dataset.k, l=graph.links.find(x=>x.t===id&&x.ti===k);
      if(!l) return; graph.links=graph.links.filter(x=>x!==l);
      const el=portOf(l.f,l.fo,'out'); src={id:l.f,k:l.fo,t:el.dataset.t,el}; drawWires(); }
    const a=portCenter(src.el);
    tempPath=document.createElementNS('http://www.w3.org/2000/svg','path');
    tempPath.setAttribute('stroke',src.t===V3?'var(--wc)':'var(--wf)'); tempPath.setAttribute('stroke-dasharray','5 4');
    svg.appendChild(tempPath); tempPath.setAttribute('d',pathD(a,wsPoint(e)));
    port.setPointerCapture(e.pointerId);
    let hot=null;
    const mv=ev=>{ tempPath.setAttribute('d',pathD(a,wsPoint(ev)));
      const tg=document.elementFromPoint(ev.clientX,ev.clientY); const pi=tg&&tg.closest&&tg.closest('.port.in');
      if(hot&&hot!==pi) hot.classList.remove('hot'); hot=pi; if(hot) hot.classList.add('hot'); };
    const up=ev=>{ port.removeEventListener('pointermove',mv); port.removeEventListener('pointerup',up); port.removeEventListener('pointercancel',up);
      if(hot) hot.classList.remove('hot');
      tempPath.remove(); tempPath=null;
      const tg=document.elementFromPoint(ev.clientX,ev.clientY); const pi=tg&&tg.closest&&tg.closest('.port.in');
      const ok = pi ? connect(src.id,src.k,+pi.dataset.n,pi.dataset.k) : null;
      if(ok===false){ drawWires(); save(); return; }
      structChanged(); };
    port.addEventListener('pointermove',mv); port.addEventListener('pointerup',up); port.addEventListener('pointercancel',up);
    return;
  }
  const hd=e.target.closest('.hd');
  if(hd){
    const el=hd.closest('.node'), n=graph.nodes.find(x=>x.id===+el.dataset.id);
    ws.querySelectorAll('.node.sel').forEach(x=>x.classList.remove('sel')); el.classList.add('sel');
    const s=wsPoint(e), ox=n.x, oy=n.y; hd.setPointerCapture(e.pointerId);
    const mv=ev=>{ const p=wsPoint(ev); n.x=Math.max(0,Math.min(WS_W-180,Math.round(ox+p[0]-s[0]))); n.y=Math.max(0,Math.min(WS_H-40,Math.round(oy+p[1]-s[1])));
      el.style.left=n.x+'px'; el.style.top=n.y+'px'; drawWires(); };
    const up=()=>{ hd.removeEventListener('pointermove',mv); hd.removeEventListener('pointerup',up); hd.removeEventListener('pointercancel',up); save(); };
    hd.addEventListener('pointermove',mv); hd.addEventListener('pointerup',up); hd.addEventListener('pointercancel',up);
  }
});

// 노드 추가 메뉴
const addSel=document.getElementById('addNode');
addSel.innerHTML='<option value="">+ 노드 추가</option>'+Object.entries(CAT_LABEL).filter(([c])=>c!=='out').map(([c,l])=>
  `<optgroup label="${l}">${Object.entries(TYPES).filter(([,T])=>T.cat===c).map(([k,T])=>`<option value="${k}">${T.t}</option>`).join('')}</optgroup>`).join('');
addSel.addEventListener('change',()=>{
  const type=addSel.value; addSel.value=''; if(!type) return;
  const id=Math.max(0,...graph.nodes.map(n=>n.id))+1;
  const x=Math.round((edScroll.scrollLeft+edScroll.clientWidth/2)/zoom-90), y=Math.round((edScroll.scrollTop+edScroll.clientHeight/2)/zoom-60);
  const n=fillParams({nodes:[{id,type,x:Math.max(0,x),y:Math.max(0,y)}]}).nodes[0];
  graph.nodes.push(n); ws.appendChild(nodeEl(n)); structChanged();
});

// 프리셋 칩
const presetBox=document.getElementById('presets');
PRESETS.forEach((p,i)=>{ const b=document.createElement('button'); b.className='btn'; b.type='button'; b.textContent=p.name; b.dataset.i=i;
  b.addEventListener('click',()=>loadPreset(i)); presetBox.appendChild(b); });
function updatePresetChips(edited){
  presetBox.querySelectorAll('button').forEach(b=>{ const on=+b.dataset.i===presetIdx; b.setAttribute('aria-pressed',on?'true':'false');
    b.textContent=PRESETS[+b.dataset.i].name+(on&&edited?' (편집됨)':''); });
}
function loadPreset(i){
  presetIdx=i; graph=fillParams(clone(PRESETS[i].g));
  setBeam(!!PRESETS[i].beam && scene!=='subway');   // 숲의 달빛 줄기는 지하철에선 끈다
  renderEditor(); recompile(); save(); updatePresetChips(false);
}
document.getElementById('bReset').addEventListener('click',()=>loadPreset(presetIdx));
document.getElementById('zIn').addEventListener('click',()=>{ setZoom(zoom+.1); drawWires(); });
document.getElementById('zOut').addEventListener('click',()=>{ setZoom(zoom-.1); drawWires(); });
document.getElementById('bJson').addEventListener('click',()=>{
  const js=document.getElementById('jsonStatus');
  try{ const g=JSON.parse(document.getElementById('json').value);
    if(!g||!Array.isArray(g.nodes)||!Array.isArray(g.links)) throw new Error('nodes와 links 배열이 필요해요');
    for(const n of g.nodes) if(!TYPES[n.type]) throw new Error('모르는 노드 종류: '+n.type);
    graph=fillParams(g); renderEditor(); structChanged(); js.textContent='적용했어요';
  }catch(e){ js.textContent='적용 안 됨: '+e.message; }
});

/* =========================================================
   11. 스테이지 컨트롤
   ========================================================= */
const bAuto=document.getElementById('bAuto'), bBeam=document.getElementById('bBeam'), bFix=document.getElementById('bFix');
document.getElementById('bAttack').addEventListener('click',()=>{ attack(0); turn=1; });
bAuto.addEventListener('click',()=>{ autoOn=!autoOn; bAuto.setAttribute('aria-pressed',autoOn); });
function setBeam(on){ beamOn=on; bBeam.setAttribute('aria-pressed',on); }
bBeam.addEventListener('click',()=>setBeam(!beamOn));
bFix.addEventListener('click',()=>{ fixFlip=!fixFlip; bFix.setAttribute('aria-pressed',fixFlip); });
document.querySelectorAll('#views button').forEach(b=>b.addEventListener('click',()=>{
  view=+b.dataset.v; document.querySelectorAll('#views button').forEach(x=>x.setAttribute('aria-pressed',x===b?'true':'false')); }));
// 동작 문법
const gBox=document.getElementById('grammar'), tl=document.getElementById('timeline');
gBox.innerHTML='<span class="lbl" style="font-size:12px;color:var(--ink2);min-width:58px">동작 문법</span>';
const gramInfo=document.getElementById('gramInfo');
function drawTimeline(){
  tl.innerHTML=GRAMMAR.map(g=>`<i style="flex:${BF(G[g.k])};background:${g.c}"></i>`).join('');
  const total=GRAMMAR.reduce((a,g)=>a+BF(G[g.k]),0);
  gramInfo.textContent=`${animFps}fps에서 실제 ${GRAMMAR.map(g=>g.l+' '+BF(G[g.k])).join(' · ')}프레임, 한 번 휘두르는 데 ${(total/animFps).toFixed(2)}초`;
}
for(const g of GRAMMAR){
  const s=document.createElement('span'); s.className='step';
  s.innerHTML=`<i style="width:8px;height:8px;border-radius:2px;background:${g.c};display:inline-block"></i>${g.l}<button type="button" aria-label="${g.l} 프레임 줄이기">−</button><b>${G[g.k]}</b><button type="button" aria-label="${g.l} 프레임 늘리기">+</button>`;
  const [minus,plus]=s.querySelectorAll('button'), val=s.querySelector('b');
  const upd=d=>{ G[g.k]=Math.max(g.min,Math.min(g.max,G[g.k]+d)); val.textContent=G[g.k]; drawTimeline(); };
  minus.addEventListener('click',()=>upd(-1)); plus.addEventListener('click',()=>upd(1));
  gBox.appendChild(s);
}
const unit=document.createElement('span'); unit.style.cssText='font-size:12px;color:var(--ink2)'; unit.textContent='키 프레임 (12fps 기준)'; gBox.appendChild(unit);
drawTimeline();
// 재생: fps · 인비트윈 · 속도
const FPS_LIST=[4,6,8,12,15,24,30,60];
function setFps(v){ animFps=v; document.getElementById('fpsVal').textContent=v; acc=0; drawTimeline(); }
document.getElementById('fpsDn').addEventListener('click',()=>{ const i=FPS_LIST.indexOf(animFps); setFps(FPS_LIST[Math.max(0,i-1)]); });
document.getElementById('fpsUp').addEventListener('click',()=>{ const i=FPS_LIST.indexOf(animFps); setFps(FPS_LIST[Math.min(FPS_LIST.length-1,i+1)]); });
const bTween=document.getElementById('bTween');
bTween.addEventListener('click',()=>{ inbetween=!inbetween; bTween.setAttribute('aria-pressed',inbetween); });
document.querySelectorAll('#speeds button').forEach(b=>b.addEventListener('click',()=>{
  playSpeed=+b.dataset.s; document.querySelectorAll('#speeds button').forEach(x=>x.setAttribute('aria-pressed',x===b?'true':'false')); }));
if(window.matchMedia('(prefers-reduced-motion: reduce)').matches){ autoOn=false; bAuto.setAttribute('aria-pressed','false'); }

const SAMPLE_PARTS='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';
const SAMPLE_ASE='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';
