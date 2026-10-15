import time, sys, json
import os as _os, pathlib as _pl
GAME_URL = _pl.Path(_os.environ.get('BAGBOSS_HTML') or _pl.Path(__file__).resolve().parents[3] / 'web' / 'index.html').resolve().as_uri()
from playwright.sync_api import sync_playwright
START=int(sys.argv[1]); LIM=float(sys.argv[2]); TIER=sys.argv[3] if len(sys.argv)>3 else '2'; GOD=len(sys.argv)>4
with sync_playwright() as p:
    b=p.chromium.launch(args=["--use-gl=angle","--use-angle=swiftshader","--enable-unsafe-swiftshader"]); pg=b.new_page(viewport={'width':390,'height':844}); logs=[]
    pg.on('pageerror', lambda e: logs.append('PAGEERROR '+str(e)[:300]+' || '+str(getattr(e,'stack',''))[:600]))
    pg.goto(GAME_URL); time.sleep(1.2); pg.click('#modeSeg button[data-m="game"]'); time.sleep(1.5)
    pg.evaluate("window.__dotlab.jumpTo('tower')"); time.sleep(.3)
    pg.evaluate(f"(()=>{{ const L=window.__dotlab; L.demoBag(1); L.GS.bag.forEach(o=>o.tier={TIER}); L.renderBag(); L.GS.max=L.GS.max; L.towerGo({START}); }})()")
    pg.evaluate("window.__dotlab.setPlaySpeed(2)")
    if GOD: pg.evaluate("window.__god=1")
    t0=time.time(); last=None; ev=[]; seen={}; minhp=999
    while time.time()-t0<LIM:
        r=pg.evaluate("(()=>{ const L=window.__dotlab; const s=L.towerSt(); if(!s) return null; s.gt=+L.GS.time.toFixed(1); if(window.__god && L.GS.state==='fight') L.GS.hp=Math.max(L.GS.hp, L.GS.max*.6); s.pr=L.twProbe(); return s; })()")
        if not r: break
        minhp=min(minhp,r['hp']); pr=r['pr']
        for k in ['fires','extra','gust','ice','shots','press']:
            if pr[k] and k not in seen: seen[k]=(r['floor'], r['gt'])
        if pr.get('flash') in ('CLANG','BLIND') and pr['flash'] not in seen: seen[pr['flash']]=(r['floor'],r['gt'])
        k=(r['floor'],r['phase'])
        if k!=last: ev.append((r['floor'],r['phase'],r['gt'],r['hp'],r['w'],len(r['foes']))); last=k
        if r['state']=='shop': pg.evaluate("(()=>{ const s=document.querySelector('#gOverlay .lc')||document.querySelector('#gOverlay .skip'); if(s) s.click(); })()")
        if r['state']=='arrange': pg.evaluate("(()=>{ const b=document.querySelector('#sbArrange button'); if(b){ b.dispatchEvent(new PointerEvent('pointerup',{bubbles:true})); } })()")
        if r['state']=='over': ev.append(('끝', r['floor'], r['gt'], r['hp'])); break
        pg.evaluate("window.__dotlab.setPlaySpeed(2)"); time.sleep(.25)
    for e in [x for x in ev if x[1] in ('arrive','끝') or x[0]=='끝']: print(' ', e)
    print('본 것', seen); print('최저 체력', minhp)
    print('결과', pg.evaluate("(()=>{ const c=document.querySelector('#gOverlay .tw-res'); return c?c.innerText.replace(/\\n+/g,' | '):null; })()"))
    print('META', pg.evaluate("JSON.stringify(window.__dotlab.meta().tower)"))
    pg.evaluate("window.__dotlab.openMenu('tower')"); time.sleep(.8)
    print('칩', pg.evaluate("[...document.querySelectorAll('[data-ot]')].map(b=>[b.dataset.ot, b.innerText.trim(), b.disabled, b.className])"))
    print('잠금', pg.evaluate("[...document.querySelectorAll('.tw-lock')].map(b=>b.innerText)"))
    pg.screenshot(path=_os.path.join(_os.environ.get('BAGBOSS_OUT','.'),'tower_menu_'+str(START)+'.png'))
    print(logs[:5]); b.close()
