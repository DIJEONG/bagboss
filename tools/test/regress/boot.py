import time, sys
import os as _os, pathlib as _pl
GAME_URL = _pl.Path(_os.environ.get('BAGBOSS_HTML') or _pl.Path(__file__).resolve().parents[3] / 'web' / 'index.html').resolve().as_uri()
from playwright.sync_api import sync_playwright
url=sys.argv[1] if len(sys.argv)>1 else GAME_URL
with sync_playwright() as p:
    b=p.chromium.launch(args=["--use-gl=angle","--use-angle=swiftshader","--enable-unsafe-swiftshader"]); pg=b.new_page(viewport={'width':760,'height':900}); pg.set_default_timeout(20000); logs=[]
    pg.on('pageerror', lambda e: logs.append('PAGEERROR '+str(e)[:300])); pg.on('console', lambda m: logs.append(m.type+' '+m.text[:300]) if m.type in ('error','warning') and '403' not in m.text else None)
    pg.goto(url); time.sleep(1.2); pg.click('#modeSeg button[data-m="game"]'); time.sleep(1.5)
    pg.evaluate("window.__dotlab.jumpTo('subway')"); time.sleep(.5)
    t0=pg.evaluate("window.__dotlab.GS.time"); time.sleep(2.5); t1=pg.evaluate("window.__dotlab.GS.time")
    print('부팅', '게임 시간', round(t0,2), '→', round(t1,2), '|', logs[:5] or '오류 없음'); b.close()
