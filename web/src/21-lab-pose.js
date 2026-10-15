/* =========================================================
   11-c. 동작 보기 · 포즈 편집기
   ========================================================= */
let who=0, editing=false, editPose='strike', autoBefore=true, dragK=null;
const POSE_KEY='dotlab.poses.v2';
const poseJson=document.getElementById('poseJson'), poseGrid=document.getElementById('poseGrid'), poseSel=document.getElementById('poseSel');
function savePoses(){ try{ localStorage.setItem(POSE_KEY, JSON.stringify(POSES)); }catch(e){} poseJson.value=JSON.stringify(POSES,null,1); }
function loadPoses(){ try{ const o=JSON.parse(localStorage.getItem(POSE_KEY)||'null'); if(o) for(const k in POSES) if(o[k]) Object.assign(POSES[k], o[k]); }catch(e){} poseJson.value=JSON.stringify(POSES,null,1); }
const wrapA=a=>{ a=((a%16)+16)%16; return a>=8?a-16:a; };
const PF=[ {k:'r',l:'대시',st:1,min:-30,max:40}, {k:'b0',l:'골반 앞뒤',st:1,min:-10,max:10}, {k:'b1',l:'골반 위아래',st:1,min:-10,max:12},
  {k:'h0',l:'머리 앞뒤',st:1,min:-6,max:6}, {k:'h1',l:'머리 위아래',st:1,min:-6,max:6}, {k:'t',l:'몸 기울기',st:.5,ang:true,min:-6,max:6},
  {k:'aF',l:'앞팔',st:.5,ang:true}, {k:'aB',l:'뒷팔',st:.5,ang:true}, {k:'w',l:'무기',st:.5,ang:true},
  {k:'fF0',l:'앞발 앞뒤',st:.05,pct:true,min:-1.2,max:1.2}, {k:'fF1',l:'앞발 높이',st:.05,pct:true,min:-.8,max:0},
  {k:'fB0',l:'뒷발 앞뒤',st:.05,pct:true,min:-1.2,max:1.2}, {k:'fB1',l:'뒷발 높이',st:.05,pct:true,min:-.8,max:0} ];
const VEC={b0:['b',0],b1:['b',1],h0:['h',0],h1:['h',1],fF0:['fF',0],fF1:['fF',1],fB0:['fB',0],fB1:['fB',1]};
const getF=(P,k)=> VEC[k] ? P[VEC[k][0]][VEC[k][1]] : (P[k]||0);
function setF(P,k,v){ if(VEC[k]) P[VEC[k][0]][VEC[k][1]]=v; else P[k]=v; }
const fmtF=(f,v)=> f.ang ? `${Math.round((f.k==='t'?v:wrapA(v))*22.5)}°` : f.pct ? `${Math.round(-(f.k.endsWith('1')?v:-v)*100)}%` : `${v}px`;
poseSel.innerHTML=Object.keys(POSES).map(k=>`<option value="${k}"${k===editPose?' selected':''}>${POSE_LABEL[k]||k}</option>`).join('');
function drawPoseGrid(){
  const P=POSES[editPose];
  poseGrid.innerHTML=PF.map(f=>`<span class="step" data-k="${f.k}"><span>${f.l}</span><button type="button" aria-label="${f.l} 줄이기">−</button><b>${fmtF(f,getF(P,f.k))}</b><button type="button" aria-label="${f.l} 늘리기">+</button></span>`).join('');
  poseGrid.querySelectorAll('.step').forEach(el=>{ const f=PF.find(x=>x.k===el.dataset.k), [mn,pl]=el.querySelectorAll('button');
    const upd=d=>{ const P=POSES[editPose]; let v=getF(P,f.k)+d*f.st; if(f.ang && f.k!=='t') v=((v%16)+16)%16; if(f.min!==undefined) v=Math.max(f.min,Math.min(f.max,v));
      setF(P,f.k, f.pct ? Math.round(v*20)/20 : Math.round(v*2)/2); el.querySelector('b').textContent=fmtF(f,getF(P,f.k)); savePoses(); };
    mn.addEventListener('click',()=>upd(-1)); pl.addEventListener('click',()=>upd(1)); });
}
function holdEditPose(){ CHARS.forEach(c=>resetChar(c)); const c=CHARS[who]; c.pose=editPose; c.prev=editPose; c.hold=1e9; c.anim='idle'; c.si=0; }
const handles=document.getElementById('handles'), hpLabel=document.getElementById('hpLabel');
const HP=[ ['kneeF','knee','앞무릎'], ['kneeB','knee','뒷무릎'], ['root','pos','대시'], ['hips','pos','골반'], ['head','pos','머리'], ['neck','ang','몸 기울기'], ['handF','ang','앞팔'], ['handB','ang','뒷팔'], ['tip','ang','무기'], ['footF','pos','앞발'], ['footB','pos','뒷발'] ];
const hpEl={};
for(const [k,cls,l] of HP){ const el=document.createElement('span'); el.className='hp '+cls; el.title=l; el.dataset.k=k; handles.appendChild(el); hpEl[k]=el;
  el.addEventListener('pointerdown',e=>{ e.stopPropagation(); e.preventDefault(); el.setPointerCapture(e.pointerId); dragK=k; el.classList.add('on'); hpLabel.textContent=`${POSE_LABEL[editPose]} · ${l}`; });
  el.addEventListener('pointermove',e=>{ if(dragK===k) dragHandle(k,e); });
  const end=()=>{ if(dragK===k){ dragK=null; el.classList.remove('on'); hpLabel.textContent=`${POSE_LABEL[editPose]} 편집 중`; drawPoseGrid(); savePoses(); } };
  el.addEventListener('pointerup',end); el.addEventListener('pointercancel',end); }
const headUp=7, hipBack=5; // 머리 점은 목보다 위, 골반 점은 등 쪽으로 비켜 둬서 손 점과 겹치지 않게
function n2s(p){ const sc=canvas.clientWidth/W; return [canvas.offsetLeft+(p[0]+.5)*sc, canvas.offsetTop+(p[1]+.5)*sc]; }
function s2n(e){ const r=canvas.getBoundingClientRect(); return [(e.clientX-r.left)/r.width*W-.5, (e.clientY-r.top)/r.height*H-.5]; }
function updateHandles(){
  if(!editing) return; const c=CHARS[who], j=c.jw; if(!j) return;
  const pos={ root:[0-j.rr,0], hips:[j.hips[0]-hipBack,j.hips[1]], head:[j.head[0],j.head[1]-headUp], neck:j.neck, handF:j.handF, handB:j.handB, tip:j.tip, footF:j.footF, footB:j.footB, kneeF:j.kneeF, kneeB:j.kneeB };
  for(const k in pos){ const w = k==='root' ? [c.d.x+(c.d.flip?-1:1)*j.rr, c.d.y+7] : j.W2(pos[k]); // 대시 점은 발밑 아래에 둬서 다리 점과 겹치지 않게
    const sp=n2s([w[0]+(c.ox||0), w[1]]); hpEl[k].style.transform=`translate(${sp[0]}px,${sp[1]}px)`; }
}
function dragHandle(k,e){
  const c=CHARS[who], j=c.jw, d=c.d, f=d.flip?-1:1, P=POSES[editPose], R=d.rig, pt0=s2n(e), pt=[pt0[0]-(c.ox||0), pt0[1]];
  const sc=R.sc||1, L=[(pt[0]-d.x)*f-Math.round(P.r*sc), pt[1]-d.y], q2=a=>{ const v=Math.round(a*2)/2; return ((v%16)+16)%16; }, cl=(v,a,b)=>Math.max(a,Math.min(b,v));
  if(k==='root') P.r=cl(Math.round((pt[0]-d.x)*f/sc),-30,40);
  else if(k==='hips') P.b=[cl(Math.round((L[0]+hipBack)/sc),-10,10), cl(Math.round((L[1]-R.hip)/sc),-10,12)];
  else if(k==='head') P.h=[cl(Math.round((L[0]-j.headBase[0])/sc),-6,6), cl(Math.round((L[1]+headUp-j.headBase[1])/sc),-6,6)];
  else if(k==='neck'){ const a=((ang16(j.hips,L)%16)+16)%16; P.t=cl(Math.round(wrapA(8-a)*2)/2,-6,6); }
  else if(k==='handF') P.aF=q2(ang16(j.shF,L));
  else if(k==='handB') P.aB=q2(ang16(j.shB,L));
  else if(k==='tip') P.w=q2(ang16(j.handF,L));
  else if(k==='footF'||k==='footB'){ const base=k==='footF'?R.legF:R.legB, v=[cl(Math.round((L[0]-base[0])/j.LL*20)/20,-1.2,1.2), cl(Math.round(Math.min(0,L[1])/j.LL*20)/20,-.8,0)];
    if(k==='footF') P.fF=v; else P.fB=v; }
}
function setEditing(on){
  editing=on; document.getElementById('bPose').setAttribute('aria-pressed',on); document.getElementById('bPose').textContent=on?'편집 끄기':'편집 켜기';
  handles.hidden=!on; poseGrid.hidden=!on; document.getElementById('poseHelp').hidden=!on;
  if(on){ autoBefore=autoOn; autoOn=false; paused=true; holdEditPose(); drawPoseGrid(); hpLabel.textContent=`${POSE_LABEL[editPose]} 편집 중`; }
  else { paused=false; autoOn=autoBefore; CHARS.forEach(c=>resetChar(c)); }
  bAuto.setAttribute('aria-pressed',autoOn);
}
document.getElementById('bPose').addEventListener('click',()=>setEditing(!editing));
poseSel.addEventListener('change',()=>{ editPose=poseSel.value; if(editing){ holdEditPose(); drawPoseGrid(); hpLabel.textContent=`${POSE_LABEL[editPose]} 편집 중`; } });
document.getElementById('bPoseReset').addEventListener('click',()=>{ POSES[editPose]=JSON.parse(JSON.stringify(POSE_DEFAULT[editPose])); if(editing) holdEditPose(); drawPoseGrid(); savePoses(); });
document.getElementById('bPoseAll').addEventListener('click',()=>{ for(const k in POSE_DEFAULT) POSES[k]=JSON.parse(JSON.stringify(POSE_DEFAULT[k])); if(editing) holdEditPose(); drawPoseGrid(); savePoses(); document.getElementById('poseMsg').textContent='모든 포즈를 처음으로 돌렸어요'; });
document.getElementById('bPoseJson').addEventListener('click',()=>{ const m=document.getElementById('poseMsg');
  try{ const o=JSON.parse(poseJson.value); let n=0; for(const k in POSES) if(o[k]){ Object.assign(POSES[k],o[k]); n++; } if(!n) throw new Error('아는 포즈 이름이 없어요'); if(editing) holdEditPose(); drawPoseGrid(); savePoses(); m.textContent=`포즈 ${n}개를 적용했어요`; }
  catch(e){ m.textContent='적용 안 됨: '+e.message; } });
document.querySelectorAll('#who button').forEach(b=>b.addEventListener('click',()=>{ who=+b.dataset.c;
  document.querySelectorAll('#who button').forEach(x=>x.setAttribute('aria-pressed',x===b?'true':'false')); if(editing) holdEditPose(); syncWalk(); }));
function syncWalk(){ document.querySelector('#animBar [data-anim="walk"]').setAttribute('aria-pressed', CHARS[who].anim==='walk'); }
document.querySelectorAll('#animBar [data-anim]').forEach(b=>b.addEventListener('click',()=>{
  if(editing) setEditing(false);
  const c=CHARS[who], a=b.dataset.anim;
  if(a==='walk') setAnim(c, c.anim==='walk'?'idle':'walk'); else setAnim(c,a);
  syncWalk(); }));

