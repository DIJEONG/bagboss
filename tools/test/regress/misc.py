import time
import os as _os, pathlib as _pl
GAME_URL = _pl.Path(_os.environ.get('BAGBOSS_HTML') or _pl.Path(__file__).resolve().parents[3] / 'web' / 'index.html').resolve().as_uri()
from playwright.sync_api import sync_playwright
with sync_playwright() as p:
    b=p.chromium.launch(args=["--use-gl=angle","--use-angle=swiftshader","--enable-unsafe-swiftshader"]); pg=b.new_page(viewport={'width':430,'height':932}, device_scale_factor=1); pg.set_default_timeout(20000); logs=[]
    pg.on('pageerror', lambda e: logs.append('PAGEERROR '+str(e)[:300]))
    pg.goto(GAME_URL); time.sleep(1.2); pg.click('#modeSeg button[data-m="game"]'); time.sleep(1.5)
    # 건널목 연속: 콤보 반복 + 전차
    pg.evaluate("window.__dotlab.jumpTo('dojo')"); time.sleep(1); pg.evaluate("window.__dotlab.djbg('cross')"); time.sleep(.5)
    names=['올려 꽂기','철산 마무리','낙뢰','무너뜨려 꽂기']; t0=time.time(); last=None; stall=0; froze=False; k=-1; g0=pg.evaluate("window.__dotlab.GS.time")
    while time.time()-t0<45:
        g=pg.evaluate("window.__dotlab.GS.time")
        stall = stall+1 if g==last else 0; last=g
        if stall>=12: froze=True; break
        if int((time.time()-t0)//8)>k:
            k+=1; n=names[k%4]; pg.evaluate(f"(()=>{{ const b=[...document.querySelectorAll('button')].find(x=>x.textContent.startsWith('{n}')); if(b) b.click(); }})()")
            if k%2==0: pg.evaluate("window.__dotlab.xcTrain()")
        time.sleep(.1)
    print('건널목 연속', round(g0,1),'→',round(pg.evaluate("window.__dotlab.GS.time"),1), '멈춤' if froze else '멈춤 없음', pg.evaluate("window.__dotlab.xc()"))
    pg.evaluate("window.__dotlab.djbg('dojo')")
    # 자세 편집기 · 스킨 미리보기
    pg.evaluate("window.__dotlab.poseEd()"); time.sleep(1); pg.evaluate("window.__dotlab.peSel('renkan','rk_k2')"); time.sleep(.6)
    print('자세 편집기', pg.evaluate("(()=>{ const d=document.querySelector('.pe'); return d&&!d.hidden ? [d.querySelector('[data-pe=anim]').value, d.querySelectorAll('[data-ctl]').length] : null; })()"))
    pg.evaluate("document.querySelector('[data-pe=close]').click()"); time.sleep(.5)
    pg.evaluate("window.__dotlab.menu('sound')"); time.sleep(.4); pg.evaluate("document.querySelector('[data-skinpv]').click()"); time.sleep(1.2)
    print('스킨 미리보기', pg.evaluate("(()=>{ const g=window.__dotlab.GS; return [!!g.skinPv, g.camZ]; })()"))
    pg.evaluate("document.querySelector('.skpv-x').click()"); time.sleep(.4)
    print('닫은 뒤', pg.evaluate("(()=>{ const g=window.__dotlab.GS; return [!!g.skinPv, g.camZ]; })()"), logs[:3] or '오류 없음'); b.close()
