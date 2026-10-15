import time, sys, json
import os as _os, pathlib as _pl
GAME_URL = _pl.Path(_os.environ.get('BAGBOSS_HTML') or _pl.Path(__file__).resolve().parents[3] / 'web' / 'index.html').resolve().as_uri()
from playwright.sync_api import sync_playwright
bag=sys.argv[1]; dur=float(sys.argv[2]); tag=sys.argv[3]
with sync_playwright() as p:
    b=p.chromium.launch(args=["--use-gl=angle","--use-angle=swiftshader","--enable-unsafe-swiftshader"]); pg=b.new_page(viewport={'width':760,'height':900}); pg.set_default_timeout(20000); logs=[]
    pg.on('pageerror', lambda e: logs.append('PAGEERROR '+str(e)[:300]))
    pg.goto(GAME_URL); time.sleep(1.2); pg.click('#modeSeg button[data-m="game"]'); time.sleep(1.5)
    setup = "L.demoBag(%s)"%bag if bag.isdigit() else "L.setBag(%s)"%bag
    pg.evaluate("""(()=>{ const L=window.__dotlab,g=L.GS,H=g.hero; g.hp=9999; g.max=9999; g.state='fight'; g.ents=g.ents.filter(a=>!a.e&&!a.pass); g.wave=99; g.nextWaveAt=1e9; g.envCD=1e9;
      %s; g.bag.forEach(o=>o.t=99); g.stash=[]; L.renderBag(); L.spawnLineup(['punk','stick','punk']); g.ents.filter(a=>a.e).forEach((T,k)=>{ T.e.hp=400; T.e.max=400; T.d.x=228+k*24; }); H.d.x=200;
      window.__R={ anims:{}, sw:0, maxN:0, dmg:0 }; const orig=g.sw; })()"""%setup)
    t0=time.time(); last=None; stall=0; froze=False; g0=pg.evaluate("window.__dotlab.GS.time")
    while time.time()-t0<dur:
        r=pg.evaluate("""(()=>{ const g=window.__dotlab.GS, R=window.__R; g.hp=9999; g.envCD=1e9; R.anims[g.hero.anim]=(R.anims[g.hero.anim]||0)+1; const n=(g.sw||[]).length; R.maxN=Math.max(R.maxN,n);
          if(g.swLast && g.swLast.t!==R.lt){ R.lt=g.swLast.t; R.sw++; } g.ents.filter(a=>a.e&&!a.dead&&a.e.hp<80).forEach(a=>{ R.dmg+=400-a.e.hp; a.e.hp=400; }); return g.time; })()""")
        if last is not None and r==last: stall+=1
        else: stall=0
        if stall>=30: froze=True; break   # 소프트웨어 렌더(헤드리스)에선 1초 넘는 프레임이 가끔 있어 3초로
        last=r; time.sleep(.1)
    R=pg.evaluate("window.__R"); g1=pg.evaluate("window.__dotlab.GS.time")
    acts=sorted(k for k in R['anims'] if k not in ('idle','walk'))
    print(tag, '| 시간', round(g0,1),'→',round(g1,1), '| 멈춤' if froze else '| 멈춤 없음', '| 동작', acts, '| 충격파', R['sw'], '| 동시 최대', R['maxN'], '|', logs[:3] or '오류 없음'); b.close()
