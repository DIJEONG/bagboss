import time, sys, json
import os as _os, pathlib as _pl
GAME_URL = _pl.Path(_os.environ.get('BAGBOSS_HTML') or _pl.Path(__file__).resolve().parents[3] / 'web' / 'index.html').resolve().as_uri()
from playwright.sync_api import sync_playwright
names=json.loads(sys.argv[1])
with sync_playwright() as p:
    b=p.chromium.launch(args=["--use-gl=angle","--use-angle=swiftshader","--enable-unsafe-swiftshader"]); pg=b.new_page(viewport={'width':760,'height':900}); pg.set_default_timeout(20000); logs=[]
    pg.on('pageerror', lambda e: logs.append('PAGEERROR '+str(e)[:300]))
    pg.goto(GAME_URL); time.sleep(1.2); pg.click('#modeSeg button[data-m="game"]'); time.sleep(1.5)
    pg.evaluate("window.__dotlab.jumpTo('dojo')"); time.sleep(1.2)
    for n in names:
        pg.evaluate(f"(()=>{{ const b=[...document.querySelectorAll('button')].find(x=>x.textContent.startsWith('{n}')); if(b) b.click(); }})()")
        ha=[]; da=[]; t0=time.time(); sw0=pg.evaluate("window.__dotlab.GS.swLast?window.__dotlab.GS.swLast.t:-1"); swn=0; lt=sw0
        while time.time()-t0<9:
            h,d,lt2=pg.evaluate("(()=>{ const g=window.__dotlab.GS, D=g.ents.find(a=>a!==g.hero&&(a.dojo||a.e)); return [g.hero.anim, D?D.anim:'-', g.swLast?g.swLast.t:-1]; })()")
            if h not in ('idle','walk') and (not ha or ha[-1]!=h): ha.append(h)
            if not da or da[-1]!=d: da.append(d)
            if lt2!=lt: swn+=1; lt=lt2
            time.sleep(.04)
        print(n, '| 주인공', ha, '| 허수아비', da[:6], '| 충격파', swn)
        time.sleep(1.5)
    print(logs[:3] or '오류 없음'); b.close()
