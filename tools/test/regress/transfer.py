import time, sys, json
import os as _os, pathlib as _pl
GAME_URL = _pl.Path(_os.environ.get('BAGBOSS_HTML') or _pl.Path(__file__).resolve().parents[3] / 'web' / 'index.html').resolve().as_uri()
from playwright.sync_api import sync_playwright
SP=sys.argv[1]
with sync_playwright() as p:
    b=p.chromium.launch(args=["--use-gl=angle","--use-angle=swiftshader","--enable-unsafe-swiftshader"]); pg=b.new_page(viewport={'width':390,'height':844}, device_scale_factor=2); logs=[]
    pg.on('pageerror', lambda e: logs.append('PAGEERROR '+str(e)[:400]))
    pg.goto(GAME_URL); time.sleep(1.2); pg.click('#modeSeg button[data-m="game"]'); time.sleep(1.5)
    pg.evaluate("window.__dotlab.jumpTo('subway')"); time.sleep(.8)
    for K in [2,3]:
        pg.evaluate(f"(()=>{{ const L=window.__dotlab, g=L.GS; L.loadStage({K}); g.ents=g.ents.filter(a=>!a.e); g.bonusSt={{}}; g.bonusSt[{K}]=true; g.state='end'; g.wait=0; }})()")
        t0=time.time(); shot=False; seen=[]
        while time.time()-t0<25:
            r=pg.evaluate("(()=>{ const g=window.__dotlab.GS; return [g.state, g.stageIdx, !!document.querySelector('#sbTransfer:not([hidden])'), (document.querySelector('#sbTransfer')||{}).innerText||'']; })()")
            if not seen or seen[-1][:2]!=r[:2]: seen.append(r)
            if r[2] and not shot: time.sleep(1.0); pg.screenshot(path=f'{SP}/tr_{K}.png'); shot=True
            if r[0]=='fight' and r[1]==K+1: break
            time.sleep(.2)
        print(K,'→', [(s[0],s[1]) for s in seen], '| 카드:', (seen[-1][3] or '').replace('\n',' / ')[:120])
    print('logs', logs[:5]); b.close()
