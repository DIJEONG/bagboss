import time, sys, json
import os as _os, pathlib as _pl
GAME_URL = _pl.Path(_os.environ.get('BAGBOSS_HTML') or _pl.Path(__file__).resolve().parents[3] / 'web' / 'index.html').resolve().as_uri()
from playwright.sync_api import sync_playwright
SP=sys.argv[1]; W=int(sys.argv[2]); H=int(sys.argv[3]); tag=sys.argv[4]
with sync_playwright() as p:
    b=p.chromium.launch(args=["--use-gl=angle","--use-angle=swiftshader","--enable-unsafe-swiftshader"]); pg=b.new_page(viewport={'width':W,'height':H}, device_scale_factor=2); logs=[]
    pg.on('pageerror', lambda e: logs.append('PAGEERROR '+str(e)[:300]))
    pg.goto(GAME_URL); time.sleep(1.2); pg.click('#modeSeg button[data-m="game"]'); time.sleep(1.5)
    pg.evaluate("window.__dotlab.jumpTo('dojo')"); time.sleep(1.5)
    pg.screenshot(path=f'{SP}/dj2_{tag}_0.png')
    # 기술 탭 → 어퍼컷 → 멈춤 → 프레임
    pg.click('#dojoPanel [data-tab=move]'); time.sleep(.3)
    pg.click('#dojoPanel [data-zoom="2"]'); time.sleep(.2)
    pg.click('#dojoPanel [data-hero=upper]'); time.sleep(.55)
    pg.click('#dojoPanel [data-play]'); time.sleep(.3)
    for i in range(3): pg.click('#dojoPanel [data-step]'); time.sleep(.15)
    pg.screenshot(path=f'{SP}/dj2_{tag}_1.png')
    st=pg.evaluate("(()=>{ const g=window.__dotlab.GS, H=g.hero, D=g.ents.find(a=>a.e&&a.dojo); return { paused:window.__dotlab.isPaused(), h:[H.anim,H.pose,H.si], d:[D.anim,D.pose], z:+(g.camZ||1).toFixed(2), panelTop:document.getElementById('dojoPanel').getBoundingClientRect().top, stageBot:document.getElementById('stage').getBoundingClientRect().bottom, bagVis:getComputedStyle(document.querySelector('.game-panel')).display }; })()")
    print(json.dumps(st,ensure_ascii=False))
    # 재생 → 반복 켜기 → 상대 덩치
    pg.click('#dojoPanel [data-play]'); time.sleep(.2)
    pg.click('#dojoPanel [data-zoom="1"]'); pg.click('#dojoPanel [data-dummy=brute]'); time.sleep(.3)
    pg.click('#dojoPanel [data-rep]'); pg.click('#dojoPanel [data-hero=round]');
    n=0; last=None; t0=time.time()
    while time.time()-t0<7:
        a=pg.evaluate("window.__dotlab.GS.hero.anim")
        if a=='round' and last!='round': n+=1
        last=a; time.sleep(.05)
    print('반복 횟수(7초)', n)
    pg.screenshot(path=f'{SP}/dj2_{tag}_2.png')
    pg.click('#dojoPanel [data-exit]'); time.sleep(1)
    print('exit', pg.evaluate("({demo:window.__dotlab.GS.demo, djon:document.body.classList.contains('dj-on'), panel:getComputedStyle(document.querySelector('.game-panel')).display})"))
    print(logs[:5]); b.close()
