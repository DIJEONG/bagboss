// =========================================================
// 개발자 도구 · 자세 편집기: 동작의 키 자세를 스튜디오에서 크게 보며 각도로 고친다(목업과 같은 조절값)
// 옛 방식(발 목표 · 팔 자동 계산) 자세는 처음 고칠 때 같은 모양의 각도 값으로 바꾼다 · 이 기기에 자동 저장
// =========================================================
const PE_LS='dotlab-poseEdits', PE_ORIG={}; let peBoxEl=null, PE={ anim:'tetsu', pose:'ts_hit' };
const PE_FIELDS=['spin','t','ty','air','legH','legFK','lFT','lFK','lBT','lBK','sprF','sprB','spr','armFK','uF','lF','uB','lB'];
const peClone=o=>JSON.parse(JSON.stringify(o));
function peLoad(){ try{ return JSON.parse(localStorage.getItem(PE_LS)||'{}')||{}; }catch(e){ return {}; } }
function peDiff(k){ const P=POSES[k], O=PE_ORIG[k], d={}; if(!P||!O) return d; for(const f of PE_FIELDS) if(JSON.stringify(P[f])!==JSON.stringify(O[f])) d[f]=P[f]===undefined?null:P[f]; return d; }
function peSaveAll(){ try{ const o={}; for(const k in PE_ORIG){ const d=peDiff(k); if(Object.keys(d).length) o[k]=d; } localStorage.setItem(PE_LS, JSON.stringify(o)); }catch(e){} }
function peApplySaved(){ const S=peLoad(); for(const k in S){ if(!POSES[k]) continue; PE_ORIG[k]=PE_ORIG[k]||peClone(POSES[k]); const v={ ...S[k] }; for(const f in v) if(v[f]===null) delete v[f]; POSES[k]=Object.assign({},POSES[k],v); } }
function peToFK(P){ const R=GS.hero.d.rig, o={ ...P };   // 옛 방식 자세 → 같은 모양의 각도 값
  if(!o.armFK){ const A=toFK(P,R); Object.assign(o,{ armFK:true, uF:+A.uF.toFixed(2), lF:+A.lF.toFixed(2), uB:+A.uB.toFixed(2), lB:+A.lB.toFixed(2) }); }
  if(!o.legFK){ const sc=R.sc||1, L1=R.thigh||6, L2=R.shin||7, LL=L1+L2, hips=[Math.round(P.b[0]*sc), R.hip+Math.round(P.b[1]*sc)], kL=P.strL||1;
    const leg=(fp,base,k)=>{ const Hj=[hips[0]+base[0], hips[1]+base[1]], T=[base[0]+(fp?fp[0]:0)*LL, Math.min(0,(fp?fp[1]:0)*LL)], q=solveLeg(Hj,T,L1*k,L2*k), th=q.aT*22.5, ps=q.aS*22.5; return [+(th-90).toFixed(1), +(ps-th).toFixed(1)]; };
    const [a,b]=leg(P.fF,R.legF,kL), [c2,d2]=leg(P.fB,R.legB,1); Object.assign(o,{ legFK:true, lFT:a, lFK:b, lBT:c2, lBK:d2, legH:-hips[1] }); }
  return o; }
const peNrm=a=>((a%360)+540)%360-180;
function peMoves(){ const L=[['서기','idle'],['걷기','walk']]; for(const [n,id,ci] of DOJO.hero){ const it=GITEMS[id]; const an=id==='punch'?['jab','cross','hook','upper'][ci||0]:(it&&it.anim); if(an&&JW_SEQ[an]&&!L.some(x=>x[1]===an)) L.push([n,an]); } return L; }
function pePoses(an){ return [...new Set((JW_SEQ[an]||[]).map(s=>s[0]))].filter(k=>POSES[k]); }
function peUses(k){ let n=0; for(const an in JW_SEQ){ if(an==='__hold') continue; if((JW_SEQ[an]||[]).some(s=>s[0]===k)) n++; } return n; }
const PE_CTL=[ ['몸',[['몸 회전',-180,180,P=>peNrm((P.spin||0)*360),(P,v)=>P.spin=v/360],['상체 기울기',-90,90,P=>(P.t||0)*13.5,(P,v)=>P.t=v/13.5],['몸통 비틀기',-180,180,P=>(P.ty||0)*180/Math.PI,(P,v)=>P.ty=v*Math.PI/180],['공중 높이',0,40,P=>P.air||0,(P,v)=>P.air=v],['골반 높이',0,30,P=>P.legH??0,(P,v)=>P.legH=v]]],
  ['다리',[['앞 허벅지',-180,180,P=>P.lFT,(P,v)=>P.lFT=v],['앞 무릎',-170,170,P=>P.lFK,(P,v)=>P.lFK=v],['앞 벌리기',-30,80,P=>P.sprF??P.spr??0,(P,v)=>P.sprF=v],['뒤 허벅지',-180,180,P=>P.lBT,(P,v)=>P.lBT=v],['뒤 무릎',-170,170,P=>P.lBK,(P,v)=>P.lBK=v],['뒤 벌리기',-30,80,P=>P.sprB??P.spr??0,(P,v)=>P.sprB=v]]],
  ['팔',[['앞 위팔',-180,180,P=>peNrm(P.uF*22.5-90),(P,v)=>{ const bd=P.lF-P.uF; P.uF=(v+90)/22.5; P.lF=P.uF+bd; }],['앞 굽힘',-180,180,P=>peNrm((P.lF-P.uF)*22.5),(P,v)=>P.lF=P.uF+v/22.5],['뒤 위팔',-180,180,P=>peNrm(P.uB*22.5-90),(P,v)=>{ const bd=P.lB-P.uB; P.uB=(v+90)/22.5; P.lB=P.uB+bd; }],['뒤 굽힘',-180,180,P=>peNrm((P.lB-P.uB)*22.5),(P,v)=>P.lB=P.uB+v/22.5]]] ];
const peBox=()=>peBoxEl||(peBoxEl=(()=>{ const d=document.createElement('div'); d.className='skpv pe'; d.hidden=true; ['pointerdown','touchstart','mousedown'].forEach(t=>d.addEventListener(t,e=>e.stopPropagation())); return d; })());
function peRender(){ const d=peBox(), P=POSES[PE.pose], moves=peMoves(), uses=peUses(PE.pose), V=GS.skinPv||{}, edited=!!PE_ORIG[PE.pose] && Object.keys(peDiff(PE.pose)).length>0;
  d.innerHTML=`<div class="skpv-head"><b class="skpv-t">${tr('자세 편집기')}</b><button type="button" class="skpv-x" data-pe="close">${tr('닫기')}</button></div>
  <div class="pe-top"><select data-pe="anim">${moves.map(([n,a])=>`<option value="${a}"${a===PE.anim?' selected':''}>${tr(n)} · ${a}</option>`).join('')}</select>
  <button type="button" data-pe="play">▶ ${tr('동작 재생')}</button><label class="pe-ck"><input type="checkbox" data-pe="z1"${V.z1?' checked':''}> ${tr('실제 크기')}</label></div>
  <div class="pe-chips">${pePoses(PE.anim).map(k=>`<button type="button" data-pk="${k}" class="${k===PE.pose?'on':''}">${k}${PE_ORIG[k]&&Object.keys(peDiff(k)).length?' *':''}</button>`).join('')}</div>
  <p class="pe-note">${PE.pose}${uses>1?` · <em>${tr('공용 자세')} ${uses}${tr('개 동작')}</em>`:''}${edited?` · <b>${tr('수정됨 · 이 기기에 저장')}</b>`:''}</p>
  <div class="pe-row"><span>${tr('보기 회전(확인용)')}</span><input type="range" min="-180" max="180" step="1" value="${Math.round(V.view||0)}" data-pe="view"><i>${Math.round(V.view||0)}°</i></div>
  ${PE_CTL.map(([g,list])=>`<p class="pe-g">${tr(g)}</p>`+list.map(([n,mi,ma,get],i)=>{ const v=P&&(P.legFK||g!=='다리')&&(P.armFK||g!=='팔')?get(P):null, show=v==null||isNaN(v)?0:Math.round(v), auto=n==='골반 높이'&&(!P||P.legH==null); return `<div class="pe-row"><span>${tr(n)}</span><input type="range" min="${mi}" max="${ma}" step="1" value="${show}" data-ctl="${g}:${i}"><i>${auto?tr('자동'):show+(n==='공중 높이'||n==='골반 높이'?'':'°')}</i></div>`; }).join('')).join('')}
  <div class="pe-act"><button type="button" data-pe="floor">${tr('골반을 바닥에 맞추기')}</button><button type="button" data-pe="copy">${tr('값 복사')}</button><button type="button" data-pe="revert">${tr('이 자세 되돌리기')}</button><button type="button" data-pe="clear">${tr('모든 수정 지우기')}</button></div>
  <textarea class="pe-out" readonly hidden></textarea>`;
  d.querySelector('[data-pe="anim"]').onchange=e=>{ PE.anim=e.target.value; const ps=pePoses(PE.anim); PE.pose=ps.includes('ts_hit')?'ts_hit':(ps.find(k=>POSES[k].impact)||ps[0]); peShow(); };
  d.querySelectorAll('[data-pk]').forEach(b=>b.onclick=()=>{ PE.pose=b.dataset.pk; peShow(); });
  d.querySelector('[data-pe="close"]').onclick=()=>{ sfx.click(); poseEdClose(); };
  d.querySelector('[data-pe="play"]').onclick=()=>{ if(GS.skinPv){ GS.skinPv.play=PE.anim; GS.skinPv.playing=false; } };
  d.querySelector('[data-pe="z1"]').onchange=e=>{ if(GS.skinPv) GS.skinPv.z1=e.target.checked; };
  d.querySelector('[data-pe="view"]').oninput=e=>{ if(GS.skinPv) GS.skinPv.view=+e.target.value; e.target.nextElementSibling.textContent=e.target.value+'°'; };
  d.querySelectorAll('[data-ctl]').forEach(inp=>inp.oninput=()=>{ const [g,i]=inp.dataset.ctl.split(':'), C=PE_CTL.find(x=>x[0]===g)[1][+i];
    if(!PE_ORIG[PE.pose]) PE_ORIG[PE.pose]=peClone(POSES[PE.pose]); const Pn=peToFK({ ...POSES[PE.pose] }); C[4](Pn,+inp.value); POSES[PE.pose]=Pn;
    inp.nextElementSibling.textContent=inp.value+(C[0]==='공중 높이'||C[0]==='골반 높이'?'':'°'); clearTimeout(peRender._t); peRender._t=setTimeout(()=>{ peSaveAll(); peRender(); },500); });
  d.querySelector('[data-pe="floor"]').onclick=()=>{ if(!PE_ORIG[PE.pose]) PE_ORIG[PE.pose]=peClone(POSES[PE.pose]); const Pn=peToFK({ ...POSES[PE.pose] }); delete Pn.legH; POSES[PE.pose]=Pn; peSaveAll(); peRender(); };
  d.querySelector('[data-pe="revert"]').onclick=()=>{ if(PE_ORIG[PE.pose]){ POSES[PE.pose]=peClone(PE_ORIG[PE.pose]); delete PE_ORIG[PE.pose]; peSaveAll(); } peRender(); };
  d.querySelector('[data-pe="clear"]').onclick=()=>{ for(const k in PE_ORIG){ POSES[k]=peClone(PE_ORIG[k]); delete PE_ORIG[k]; } try{ localStorage.removeItem(PE_LS); }catch(e){} peRender(); };
  d.querySelector('[data-pe="copy"]').onclick=()=>{ const txt=`${PE.pose}: ${JSON.stringify(POSES[PE.pose])},`, ta=d.querySelector('.pe-out'); ta.hidden=false; ta.value=txt; ta.select();
    try{ navigator.clipboard.writeText(txt).then(()=>say(tr('자세 편집기'),tr('값을 복사했어요'),1.4)).catch(()=>{}); }catch(e){} };
}
function peShow(){ const V=GS.skinPv; if(V){ V.fixed=PE.pose; V.play=null; V.playing=false; } peRender(); }
function poseEdOpen(){ if(!GS.on || !GS.hero) jumpTo('dojo'); skinPvOpen(); pvBox().hidden=true; const d=peBox(), dev=document.getElementById('device'), port=document.body.classList.contains('portrait') && dev && dev.contains(stage), host=port?dev:stage;
  if(d.parentElement!==host) host.appendChild(d); if(port){ const dr=dev.getBoundingClientRect(), sr=stage.getBoundingClientRect(); d.classList.add('dock'); d.style.top=Math.round(sr.bottom-dr.top)+'px'; } else { d.classList.remove('dock'); d.style.top=''; }
  d.hidden=false; peShow(); }
function poseEdClose(){ skinPvClose(); }
