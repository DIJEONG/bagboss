#!/usr/bin/env python3
"""web/ → ios/BagBoss/Web/ 앱 번들용 웹 코어를 만든다.

원본 web/index.html은 건드리지 않는다. 앱에 넣을 사본에만 아래 패치를 적용한다.
  1) 구글 폰트 <link> 3줄 제거 (앱은 오프라인 · 해당 글꼴은 실험실 UI 전용)
  2) viewport에 user-scalable=no 추가 (핀치 확대 방지)
  3) app/fonts.css · app/app.css 링크 삽입 (Impact 대체 글꼴 · 터치 보정)
bridge.js는 HTML에 넣지 않는다 — 네이티브가 WKUserScript로 documentStart에 주입한다.

사용:  python3 tools/build_web.py            # 빌드
       python3 tools/build_web.py --check    # 빌드 결과가 최신인지 확인만 (CI · 커밋 전)
"""
import hashlib, json, pathlib, shutil, sys, datetime

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC_HTML = ROOT / 'web' / 'index.html'
SRC_APP = ROOT / 'web' / 'app'
OUT = ROOT / 'ios' / 'BagBoss' / 'Web'

VIEWPORT_OLD = '<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">'
VIEWPORT_NEW = ('<meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, '
                'user-scalable=no, viewport-fit=cover">\n'
                '<meta name="format-detection" content="telephone=no">\n'
                '<link rel="stylesheet" href="app/fonts.css">\n'
                '<link rel="stylesheet" href="app/app.css">')
DROP_IF_CONTAINS = ('fonts.googleapis.com', 'fonts.gstatic.com')


def sha(b: bytes) -> str:
    return hashlib.sha256(b).hexdigest()


def patched_html() -> tuple[str, dict]:
    src = SRC_HTML.read_text(encoding='utf-8')
    lines = src.split('\n')
    head_end = next(i for i, l in enumerate(lines) if '<style' in l)        # <head>의 링크 줄만 본다
    dropped = [i for i in range(head_end) if any(k in lines[i] for k in DROP_IF_CONTAINS)]
    if len(dropped) != 3:
        sys.exit(f'[build_web] 구글 폰트 링크가 3줄이 아니다({len(dropped)}줄) — index.html 머리가 바뀌었는지 확인하세요')
    lines = [l for i, l in enumerate(lines) if i not in dropped]
    html = '\n'.join(lines)
    if html.count(VIEWPORT_OLD) != 1:
        sys.exit('[build_web] viewport 메타가 예상과 다르다 — VIEWPORT_OLD를 맞춰 주세요')
    html = html.replace(VIEWPORT_OLD, VIEWPORT_NEW, 1)
    if 'googleapis' in html[:5000] or 'gstatic' in html[:5000]:
        sys.exit('[build_web] 외부 글꼴 참조가 남았다')
    meta = {'source': 'web/index.html', 'source_sha256': sha(src.encode('utf-8')),
            'patches': ['drop google fonts links (3)', 'viewport user-scalable=no', 'link app/fonts.css + app/app.css']}
    return html, meta


def build(check=False) -> int:
    html, meta = patched_html()
    want = {pathlib.Path('index.html'): html.encode('utf-8')}
    for p in sorted(SRC_APP.rglob('*')):
        if p.is_file():
            want[pathlib.Path('app') / p.relative_to(SRC_APP)] = p.read_bytes()
    if check:
        stale = [str(rel) for rel, b in want.items() if not (OUT / rel).exists() or (OUT / rel).read_bytes() != b]
        if stale:
            print('[build_web] 최신이 아님:', ', '.join(stale)); return 1
        print('[build_web] 최신'); return 0
    if OUT.exists():
        shutil.rmtree(OUT)
    for rel, b in want.items():
        (OUT / rel).parent.mkdir(parents=True, exist_ok=True)
        (OUT / rel).write_bytes(b)
    meta['built_at'] = datetime.datetime.now().isoformat(timespec='seconds')
    meta['files'] = {str(rel): sha(b)[:16] for rel, b in want.items()}
    (OUT / 'build.json').write_text(json.dumps(meta, ensure_ascii=False, indent=1), encoding='utf-8')
    print(f'[build_web] {OUT.relative_to(ROOT)} · {len(want)}개 파일 · index.html {len(want[pathlib.Path("index.html")]):,} bytes')
    return 0


if __name__ == '__main__':
    sys.exit(build(check='--check' in sys.argv))
