#!/usr/bin/env python3
"""회귀 테스트 묶음 (헤드리스 Chromium · Playwright). 게임 코드나 브리지를 고친 뒤 반드시 돌린다.

  pip3 install playwright && python3 -m playwright install chromium   # 처음 한 번
  python3 tools/test/run_all.py            # 전체 (약 6~10분)
  python3 tools/test/run_all.py quick      # 빠른 묶음 (boot · misc · bridge, 약 1분)
  python3 tools/test/run_all.py tower bridge

대상 HTML: 기본 web/index.html · 다른 파일은 BAGBOSS_HTML=/경로/파일.html
스크린숏: tools/test/out/
각 스크립트는 원래 클라우드 작업 세션에서 쓰던 검증 도구다. 통과 기준은 아래 CASES의 expect.
"""
import os, pathlib, subprocess, sys, time

HERE = pathlib.Path(__file__).resolve().parent
OUT = HERE / 'out'
R = HERE / 'regress'

# (이름, 명령, 출력에 있어야 할 문자열들, 시간 제한 초)
CASES = [
    ('boot',     [R / 'boot.py'],                                   ['부팅'], 120),
    ('misc',     [R / 'misc.py'],                                   ['오류 없음'], 200),
    ('combo',    [R / 'combo.py', '["낙뢰"]'],                       ['오류 없음'], 250),
    ('live',     [R / 'live.py', '1', '40', 'rg'],                  ['멈춤 없음', '오류 없음'], 250),
    ('transfer', [R / 'transfer.py', str(OUT)],                     ['logs []'], 250),
    ('bag',      [R / 'bagdrag.py', str(OUT)],                      ['logs []'], 250),
    ('dojo',     [R / 'dojo.py', str(OUT), '390', '844', 'rg'],     ['exit '], 250),
    ('devline',  [R / 'devline.py', str(OUT), '390', '844', 'rg'],  ['저장 유지 True'], 250),
    ('tower',    [R / 'tower.py', '18', '500', '3', 'god'],         ['총주방장실 돌파!', '야근 1단계가 열렸어요'], 600),
    ('bridge',   [HERE / 'bridge_test.py', '--shots', str(OUT)],    ['통과'], 200),
]
QUICK = {'boot', 'misc', 'bridge'}


def main(argv):
    pick = set(argv) - {'quick'}
    cases = [c for c in CASES if (not pick and ('quick' not in argv or c[0] in QUICK)) or c[0] in pick]
    OUT.mkdir(exist_ok=True)
    env = dict(os.environ, BAGBOSS_OUT=str(OUT))
    results = []
    for name, cmd, expect, limit in cases:
        t0 = time.time()
        try:
            p = subprocess.run([sys.executable, *map(str, cmd)], capture_output=True, text=True, timeout=limit, env=env, cwd=str(OUT))
            out = (p.stdout or '') + (p.stderr or '')
            ok = p.returncode == 0 and all(e in out for e in expect) and 'PAGEERROR' not in out
        except subprocess.TimeoutExpired:
            out, ok = f'시간 초과({limit}s)', False
        dt = time.time() - t0
        tail = out.strip().splitlines()[-1][:140] if out.strip() else ''
        print(f'{"✔" if ok else "✘"} {name:9} {dt:6.1f}s  {tail}', flush=True)
        if not ok:
            (OUT / f'{name}.log').write_text(out, encoding='utf-8')
        results.append(ok)
    bad = results.count(False)
    print(f'\n{len(results) - bad}/{len(results)} 통과' + (f' · 실패 로그: {OUT}/<이름>.log' if bad else ''))
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
