import time, sys, json
import os as _os, pathlib as _pl
GAME_URL = _pl.Path(_os.environ.get('BAGBOSS_HTML') or _pl.Path(__file__).resolve().parents[3] / 'web' / 'index.html').resolve().as_uri()
from playwright.sync_api import sync_playwright
SP=sys.argv[1]; W=int(sys.argv[2]); H=int(sys.argv[3]); tag=sys.argv[4]
with sync_playwright() as p:
    b=p.chromium.launch(args=["--use-gl=angle","--use-angle=swiftshader","--enable-unsafe-swiftshader"]); pg=b.new_page(viewport={'width':W,'height':H}, device_scale_factor=2); logs=[]
    pg.on('pageerror', lambda e: logs.append('PAGEERROR '+str(e)[:300]))
    pg.goto(GAME_URL); time.sleep(1.2); pg.click('#modeSeg button[data-m="game"]'); time.sleep(1.5)
    # 가짜 이어하기 저장 만들기
    pg.evaluate("(()=>{ const L=window.__dotlab; L.GS.state='fight'; L.saveRun(); })()")
    save0=pg.evaluate("localStorage.getItem('dotlab-run-v1')")
    lines0=pg.evaluate("JSON.stringify(window.__dotlab.meta().lines)")
    pg.evaluate("window.__dotlab.openDev()"); time.sleep(.5)
    pg.click('#devPanel [data-dl="3"]'); time.sleep(.2)
    pg.click('#devPanel [data-dc="6"]'); time.sleep(.2)
    pg.click('#devPanel [data-dbag="t4"]'); time.sleep(.2)
    pg.click('#devPanel label.dl-sw:has([data-dgod])'); time.sleep(.2)
    pg.locator('#devPanel .dp-lines').screenshot(path=f'{SP}/devline_{tag}_sec.png')
    pg.click('#devPanel [data-dgo]'); time.sleep(2.5)
    st=pg.evaluate("(()=>{ const g=window.__dotlab.GS; return { stage:g.stageIdx, ci:g.ci, devRun:g.devRun, foes:g.ents.filter(a=>a.e&&!a.dead).map(a=>a.e.t), tiers:g.bag.map(o=>o.tier), hp:[g.hp,g.max], panel:document.getElementById('devPanel').hidden }; })()")
    print('시작', json.dumps(st,ensure_ascii=False))
    time.sleep(4); pg.screenshot(path=f'{SP}/devline_{tag}_run.png')
    # 무적 확인: 보스에게 맞기
    hp=pg.evaluate("(()=>{ const L=window.__dotlab, g=L.GS; const B=g.ents.find(a=>a.e&&a.e.boss&&!a.dead); if(!B) return 'noboss'; const h0=g.hp; L.hurt(B,40); return [h0,g.hp]; })()")
    print('무적', hp)
    # 진행 중 칸 조작: 이전 칸(6)으로 이동해 다음 칸으로
    pg.evaluate("window.__dotlab.openDev()"); time.sleep(.4)
    live=pg.evaluate("!!document.querySelector('#devPanel .dl-live')")
    print('진행 중 줄', live)
    pg.locator('#devPanel .dp-lines').screenshot(path=f'{SP}/devline_{tag}_live.png')
    pg.click('#devPanel [data-dkill]'); time.sleep(1.2)
    print('정리 후 적', pg.evaluate("window.__dotlab.GS.ents.filter(a=>a.e&&!a.dead).map(a=>a.e.t)"))
    save1=pg.evaluate("localStorage.getItem('dotlab-run-v1')")
    lines1=pg.evaluate("JSON.stringify(window.__dotlab.meta().lines)")
    print('저장 유지', save0==save1, '노선 기록 유지', lines0==lines1, lines0)
    # 2호차부터 → 다음 칸
    pg.evaluate("window.__dotlab.openDev()"); time.sleep(.3)
    pg.click('#devPanel [data-dc="1"]'); pg.click('#devPanel [data-dgo]'); time.sleep(1.5)
    pg.evaluate("window.__dotlab.openDev()"); time.sleep(.3); pg.click('#devPanel [data-dnext]'); time.sleep(1.5)
    print('다음 칸', pg.evaluate("[window.__dotlab.GS.stageIdx, window.__dotlab.GS.ci, window.__dotlab.carName()]"))
    # 모든 노선 열기 → 메뉴
    pg.evaluate("window.__dotlab.openDev()"); time.sleep(.3)
    pg.click('#devPanel label.dl-sw:has([data-dall])'); time.sleep(.2)
    pg.evaluate("document.getElementById('devPanel').hidden=true; window.__dotlab.openMenu('run')"); time.sleep(.5)
    print('메뉴 노선', pg.evaluate("[...document.querySelectorAll('#gOverlay .mm-line')].map(b=>[b.textContent.trim(), b.disabled])"))
    pg.screenshot(path=f'{SP}/devline_{tag}_menu.png')
    print(logs[:5]); b.close()
