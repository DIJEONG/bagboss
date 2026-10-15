import time, sys, json
import os as _os, pathlib as _pl
GAME_URL = _pl.Path(_os.environ.get('BAGBOSS_HTML') or _pl.Path(__file__).resolve().parents[3] / 'web' / 'index.html').resolve().as_uri()
from playwright.sync_api import sync_playwright
SP=sys.argv[1]
def rect(pg,sel): return pg.evaluate(f"(()=>{{ const e=document.querySelector('{sel}'); if(!e) return null; const r=e.getBoundingClientRect(); return [r.x,r.y,r.width,r.height]; }})()")
def gcell(pg,x,y):
    r=rect(pg,'.inv-grid'); cs=r[2]/6; return (r[0]+(x+.5)*cs, r[1]+(y+.5)*cs)
def pcell(pg,x,y):
    r=rect(pg,'.inv-right'); cs=r[2]/2; return (r[0]+(x+.5)*cs, r[1]+(y+.5)*cs)
def drag(pg,a,b,steps=8,mid=None):
    pg.mouse.move(*a); pg.mouse.down(); 
    for k in range(1,steps+1): pg.mouse.move(a[0]+(b[0]-a[0])*k/steps, a[1]+(b[1]-a[1])*k/steps); time.sleep(.03)
    if mid: mid()
    pg.mouse.up(); time.sleep(.25)
def st(pg): return pg.evaluate("window.__dotlab.bagSt()")
with sync_playwright() as p:
    b=p.chromium.launch(args=["--use-gl=angle","--use-angle=swiftshader","--enable-unsafe-swiftshader"])
    pg=b.new_page(viewport={'width':440,'height':956}); logs=[]
    pg.on('pageerror', lambda e: logs.append('PAGEERROR '+str(e)[:300]))
    pg.goto(GAME_URL); time.sleep(1.2); pg.click('#modeSeg button[data-m="game"]'); time.sleep(1.5)
    pg.evaluate("window.__dotlab.jumpTo('subway')"); time.sleep(1)
    pg.evaluate("(()=>{ const L=window.__dotlab; L.demoBag(1); L.renderBag(); L.stashAdd('pin'); L.stashAdd('paper'); L.stashAdd('charm'); })()"); time.sleep(.4)
    s0=st(pg); print('시작', s0['stash'], 'tab', s0['tab'])
    pg.evaluate("window.__dotlab.GS.state='fight'"); 
    # 탭이 준비 순서면 보류함으로
    if s0['tab']=='q': pg.click('.ir-tab[data-t="p"]'); time.sleep(.3)
    # a. 보류함 pin(0,0) → 격자 빈칸 (1,2)
    drag(pg, pcell(pg,0,0), gcell(pg,1,2)); s=st(pg); print('a 보류→가방', [x for x in s['bag'] if x[0]=='pin'], s['stash'])
    # b. 가방 charm(0,3) → 보류함 (0,0)
    if s['tab']=='q': pg.click('.ir-tab[data-t="p"]'); time.sleep(.3)
    drag(pg, gcell(pg,0,3), pcell(pg,0,0)); s=st(pg); print('b 가방→보류', s['stash'], 'bag charm', [x for x in s['bag'] if x[0]=='charm'])
    # c. 보류함 안 이동: charm(0,0) → (0,3)
    if s['tab']=='q': pg.click('.ir-tab[data-t="p"]'); time.sleep(.3)
    drag(pg, pcell(pg,0,0), pcell(pg,0,3)); s=st(pg); print('c 보류 안 이동', s['stash'])
    # d. 보류함 안 회전: paper 더블클릭
    pap=[x for x in s['stash'] if x[0]=='paper'][0]; c=pcell(pg,pap[1],pap[2]); pg.mouse.click(*c); time.sleep(.12); pg.mouse.click(*c); time.sleep(.3); s=st(pg); print('d 회전', [x for x in s['stash'] if x[0]=='paper'])
    # e. 버리기
    tok0=s['tokens']; ch=[x for x in s['stash'] if x[0]=='charm'][0]; tr=rect(pg,'.inv-trash'); drag(pg, pcell(pg,ch[1],ch[2]), (tr[0]+tr[2]/2, tr[1]+tr[3]/2)); s=st(pg); print('e 버리기 토큰', tok0,'→',s['tokens'], s['stash'])
    # f. 합성: 새 charm을 보류함에 넣고 가방 charm 위로(가방엔 charm 없음 → 가방 pin 쪽으로 pin 하나 더)
    pg.evaluate("window.__dotlab.stashAdd('pin')"); time.sleep(.3); s=st(pg)
    if s['tab']=='q': pg.click('.ir-tab[data-t="p"]'); time.sleep(.3)
    pn=[x for x in s['stash'] if x[0]=='pin'][0]; bp=[x for x in s['bag'] if x[0]=='pin'][0]
    drag(pg, pcell(pg,pn[1],pn[2]), gcell(pg,bp[1],bp[2])); print('f 합성 창', pg.evaluate("!!document.querySelector('.inv-merge')")); pg.evaluate("document.querySelectorAll('.inv-merge').forEach(n=>n.remove())")
    # g. 준비 순서 탭에서 가방 기술을 끌면 보류함이 보이고 놓을 수 있다
    pg.click('.ir-tab[data-t="q"]'); time.sleep(.3); s=st(pg); print('g 탭', s['tab'], 'queue rows', pg.evaluate("document.querySelectorAll('.iq').length"))
    kn=[x for x in s['bag'] if x[0]=='knee'][0]
    def mid():
        print('  끄는 중 dragging', pg.evaluate("document.querySelector('#bag').classList.contains('dragging')"), '보류함 보임', pg.evaluate("getComputedStyle(document.querySelector('.inv-pocket')).display"))
        pg.screenshot(path=f'{SP}/drag_mid.png')
    free=None
    occ=set()
    for it in s['stash']:
        pass
    drag(pg, gcell(pg,kn[1],kn[2]), pcell(pg,1,3) if True else None, mid=mid); s=st(pg); print('g 결과', [x for x in s['stash'] if x[0]=='knee'], 'bag knee', [x for x in s['bag'] if x[0]=='knee'])
    pg.screenshot(path=f'{SP}/drag_after.png')
    print('logs', logs[:5])
    b.close()
