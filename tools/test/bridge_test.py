#!/usr/bin/env python3
"""앱 번들(ios/BagBoss/Web)을 네이티브 셸처럼 띄워 브리지를 검사한다 (맥 · 리눅스 공통, Playwright).

- 가짜 오리진(http://app.local/)으로 Web/ 파일만 서빙하고, 그 밖의 네트워크는 전부 막는다(오프라인 확인)
- window.webkit.messageHandlers.bagboss를 흉내 내 메시지를 모은다(reply 형식 → Promise 반환)
- 네이티브가 하듯 __BAGBOSS_SAVE__ 스냅숏 → bridge.js 순서로 documentStart에 주입한다

사용: python3 tools/test/bridge_test.py [--shots 폴더]
종료 코드 0 = 통과
"""
import json, mimetypes, pathlib, sys, time
from playwright.sync_api import sync_playwright

ROOT = pathlib.Path(__file__).resolve().parents[2]
WEB = ROOT / 'ios' / 'BagBoss' / 'Web'
BRIDGE = (WEB / 'app' / 'bridge.js').read_text(encoding='utf-8')
ORIGIN = 'http://app.local'
SNAP = {'dotlab-lang': 'ko', 'dotlab-opt': json.dumps({'vibe': True, 'autoSpc': False}), 'dotlab-restore-probe': 'from-native', 'other-key': 'x'}

MOCK = """
window.__msgs = [];
window.webkit = { messageHandlers: { bagboss: { postMessage(m) {
  window.__msgs.push(JSON.parse(JSON.stringify(m)));
  return Promise.resolve(m && m.type === 'save.put' ? { ok: true } : null);
} } } };
window.__BAGBOSS_SAVE__ = %s;
""" % json.dumps(SNAP)

fails = []
def check(name, ok, info=''):
    print(('  ✔ ' if ok else '  ✘ ') + name + (f'  — {info}' if info else ''))
    if not ok: fails.append(name)

def main():
    shots = None
    if '--shots' in sys.argv:
        shots = pathlib.Path(sys.argv[sys.argv.index('--shots') + 1]); shots.mkdir(parents=True, exist_ok=True)
    with sync_playwright() as p:
        b = p.chromium.launch(args=['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'])
        ctx = b.new_context(viewport={'width': 390, 'height': 844}, device_scale_factor=3, is_mobile=True, has_touch=True)
        outside, errors = [], []
        def route(r):
            url = r.request.url
            if url.startswith(ORIGIN + '/'):
                rel = url[len(ORIGIN) + 1:].split('?')[0] or 'index.html'
                f = WEB / rel
                if f.is_file():
                    return r.fulfill(status=200, body=f.read_bytes(), content_type=mimetypes.guess_type(str(f))[0] or 'application/octet-stream')
                return r.fulfill(status=404, body=b'')
            if url.startswith('data:') or url.startswith('blob:'):
                return r.continue_()
            outside.append(url); return r.abort()
        ctx.route('**/*', route)
        ctx.add_init_script(MOCK)
        ctx.add_init_script(BRIDGE)
        pg = ctx.new_page()
        pg.on('pageerror', lambda e: errors.append(str(e)[:300]))
        pg.goto(ORIGIN + '/index.html'); time.sleep(1.5)
        pg.click('#modeSeg button[data-m="game"]'); time.sleep(2.5)    # 실기기에서는 webdriver가 아니라 자동으로 게임 모드

        msgs = lambda t=None: pg.evaluate('window.__msgs').__iter__() if t is None else [m for m in pg.evaluate('window.__msgs') if m['type'] == t]
        ready = msgs('app.ready')
        check('app.ready 수신', len(ready) == 1, json.dumps(ready[0]['payload'], ensure_ascii=False) if ready else '')
        if ready:
            check('스냅숏 복원(빈 키만, dotlab*만)', sorted(ready[0]['payload']['restored']) == ['dotlab-lang', 'dotlab-opt', 'dotlab-restore-probe'])
        check('localStorage에 복원값', pg.evaluate("localStorage.getItem('dotlab-restore-probe')") == 'from-native'
              and pg.evaluate("localStorage.getItem('other-key')") is None)

        pg.evaluate("localStorage.setItem('dotlab-probe','1'); localStorage.setItem('dotlab-probe','2'); localStorage.removeItem('dotlab-restore-probe'); localStorage.setItem('unrelated','z')")
        time.sleep(.8)
        puts = msgs('save.put'); ent = {}
        for m in puts: ent.update(m['payload']['entries'])
        check('저장 미러(디바운스 · 마지막 값 · 삭제=null · 다른 접두사 제외)',
              ent.get('dotlab-probe') == '2' and 'dotlab-restore-probe' in ent and ent['dotlab-restore-probe'] is None and 'unrelated' not in ent,
              f'{len(puts)}회 · {sorted(ent)}')

        n0 = len(msgs('haptic'))
        pg.evaluate("navigator.vibrate(25); navigator.vibrate([40,30,60]); navigator.vibrate(0)")
        time.sleep(.2)
        hp = msgs('haptic')[n0:]
        check('navigator.vibrate → haptic 패턴', [m['payload']['pattern'] for m in hp] == [[25], [40, 30, 60]], str([m['payload'] for m in hp]))

        # 판 시작 → 싸우는 중 백그라운드 → 메뉴로 멈춤 + 저장 플러시
        pg.evaluate("window.__dotlab.jumpTo('tower')"); time.sleep(.5)
        pg.evaluate("(()=>{ const L=window.__dotlab; document.getElementById('gOverlay').hidden=true; L.GS.state='fight'; L.towerGo(3); })()"); time.sleep(2.5)
        before = len(msgs('save.put'))
        r = pg.evaluate("NativeBridge._native({type:'app.pause'}).then(x=>JSON.stringify(x))")
        time.sleep(.3)
        st = pg.evaluate("({ menu: document.getElementById('gOverlay').dataset.menu, hidden: document.getElementById('gOverlay').hidden, paused: window.__dotlab.isPaused() })")
        check('app.pause → 메뉴 열고 멈춤', st['menu'] == '1' and not st['hidden'] and st['paused'], str(st))
        after = msgs('save.put')[before:]; keys = set()
        for m in after: keys |= set(m['payload']['entries'])
        check('app.pause → 메타 저장 즉시 플러시', 'dotlab-subway-meta-v1' in keys, f'{sorted(keys)} · 응답 {r}')
        check('app.resume 응답', pg.evaluate("NativeBridge._native({type:'app.resume'})") is True)
        pg.evaluate("document.querySelector('#gOverlay .mm-x, #gOverlay [data-act=close], #gOverlay .close') && document.querySelector('#gOverlay .mm-x, #gOverlay [data-act=close], #gOverlay .close').click()")

        time.sleep(2.2)
        ps = msgs('perf.sample')
        check('perf.sample 1초마다', len(ps) >= 5, f'{len(ps)}개 · 마지막 {ps[-1]["payload"] if ps else None}')
        if ps:
            last = ps[-1]['payload']
            check('perf 필드', all(k in last for k in ('fps', 'p50', 'p95', 'max', 'long', 'scene', 'px')) and last['fps'] > 0)
        pg.evaluate("document.querySelector('#stage canvas').getContext('webgl2').getExtension('WEBGL_lose_context').loseContext()")
        time.sleep(.5)
        gl = msgs('gl.lost')
        check('WebGL 문맥 잃음 → gl.lost', len(gl) == 1, str(gl[0]['payload'] if gl else None))
        check('Impact 대체 글꼴 로드', pg.evaluate("document.fonts.check('900 40px Impact')"))
        check('외부 네트워크 요청 없음', not outside, ', '.join(outside[:3]))
        logs = msgs('log')
        check('페이지 오류 없음', not errors and not [m for m in logs if m['payload'].get('level') == 'error'], '; '.join(errors[:2]))
        if shots:
            pg.screenshot(path=str(shots / 'bridge_app.png'))
        b.close()
    print('통과' if not fails else f'실패 {len(fails)}건: ' + ', '.join(fails))
    return 1 if fails else 0

if __name__ == '__main__':
    sys.exit(main())
