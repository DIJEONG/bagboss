#!/usr/bin/env python3
"""1.5단계용: web/index.html ⇄ web/src/ 조각 파일.

게임 스크립트는 즉시 실행 함수 하나(약 1만 줄) 안에 들어 있어서, 조각 파일은 단독으로 유효한 JS가 아니다.
대신 '이어 붙이면 원본과 바이트 단위로 같다'를 보장한다 — 동작이 바뀔 위험이 0인 첫 분리 단계.

  python3 tools/split_web.py split     # web/index.html → web/src/{_head.html, NN-*.js, _tail.html}
  python3 tools/split_web.py join      # web/src/ → web/index.html (이어 붙이기)
  python3 tools/split_web.py verify    # split → join 결과가 원본과 같은지(파일은 안 씀)
  python3 tools/split_web.py stats     # 조각별 크기 표
  python3 tools/split_web.py --suggest # 원본이 바뀌어 경계가 어긋났을 때, 각 경계 근처의 섹션 머리줄 후보를 보여 준다

경계 표: tools/modules.json (start = 조각 첫 줄 번호)
"""
import hashlib, json, pathlib, sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
HTML = ROOT / 'web' / 'index.html'
SRC = ROOT / 'web' / 'src'
TABLE = json.loads((ROOT / 'tools' / 'modules.json').read_text(encoding='utf-8'))


def pieces(text: str):
    lines = text.split('\n')
    so, sc = TABLE['script_open_line'], TABLE['script_close_line']
    if lines[so - 1].strip() != '<script>' or lines[sc - 1].strip() != '</script>':
        sys.exit('[split] <script> 위치가 표와 다르다 — 원본이 바뀌었으면 modules.json 줄 번호를 다시 맞추세요 (--suggest)')
    mods = TABLE['modules']
    if mods[0]['start'] != so + 1:
        sys.exit('[split] 첫 조각은 <script> 다음 줄에서 시작해야 한다')
    out = [('_head.html', '\n'.join(lines[:so]) + '\n')]
    for i, m in enumerate(mods):
        a = m['start'] - 1
        b = (mods[i + 1]['start'] - 1) if i + 1 < len(mods) else sc - 1
        first = lines[a].lstrip()
        if i > 0 and not first.startswith(('//', '/*', '(() =>', 'function ', 'const ', 'let ')):
            sys.exit(f'[split] {m["file"]} 첫 줄({m["start"]})이 최상위 선언 · 섹션 머리 주석이 아니다: {lines[a][:60]!r}')
        out.append((m['file'], '\n'.join(lines[a:b]) + '\n'))
    out.append(('_tail.html', '\n'.join(lines[sc - 1:])))
    return out


def join_parts(parts) -> str:
    return ''.join(body for _, body in parts)


def cmd_split():
    text = HTML.read_text(encoding='utf-8')
    parts = pieces(text)
    if join_parts(parts) != text:
        sys.exit('[split] 내부 오류: 이어 붙인 결과가 원본과 다르다')
    SRC.mkdir(parents=True, exist_ok=True)
    for old in SRC.glob('*'):
        old.unlink()
    order = []
    for name, body in parts:
        (SRC / name).write_text(body, encoding='utf-8'); order.append(name)
    (SRC / 'ORDER.txt').write_text('\n'.join(order) + '\n', encoding='utf-8')
    print(f'[split] web/src/ · {len(parts)}개 조각 · 원본 sha {hashlib.sha256(text.encode()).hexdigest()[:16]}')


def cmd_join():
    order = (SRC / 'ORDER.txt').read_text(encoding='utf-8').split()
    text = ''.join((SRC / n).read_text(encoding='utf-8') for n in order)
    HTML.write_text(text, encoding='utf-8')
    print(f'[join] web/index.html · {len(text.encode()):,} bytes · sha {hashlib.sha256(text.encode()).hexdigest()[:16]}')


def cmd_verify():
    text = HTML.read_text(encoding='utf-8')
    ok = join_parts(pieces(text)) == text
    print('[verify] 원본과 동일' if ok else '[verify] 다름!')
    return 0 if ok else 1


def cmd_stats():
    text = HTML.read_text(encoding='utf-8')
    parts = pieces(text)
    groups = {}
    print(f'{"조각":24} {"줄":>6} {"KB":>7}  설명')
    titles = {m['file']: (m['group'], m['title']) for m in TABLE['modules']}
    for name, body in parts:
        g, t = titles.get(name, ('html', ''))
        kb = len(body.encode()) / 1024
        groups[g] = groups.get(g, 0) + kb
        print(f'{name:24} {body.count(chr(10)):>6} {kb:>7.1f}  [{g}] {t}')
    print('그룹 합계(KB):', ', '.join(f'{g} {v:.0f}' for g, v in sorted(groups.items(), key=lambda x: -x[1])))


def cmd_suggest():
    lines = HTML.read_text(encoding='utf-8').split('\n')
    for m in TABLE['modules'][1:]:
        a = m['start'] - 1
        cands = [i + 1 for i in range(max(0, a - 60), min(len(lines), a + 60))
                 if lines[i].startswith('// ====') or lines[i].startswith('/* ====') or lines[i].startswith('// ---')]
        print(f'{m["file"]:24} 표 {m["start"]:>6} · 근처 머리줄 {cands[:6]}')


if __name__ == '__main__':
    arg = sys.argv[1] if len(sys.argv) > 1 else 'verify'
    sys.exit({'split': cmd_split, 'join': cmd_join, 'verify': cmd_verify, 'stats': cmd_stats,
              '--suggest': cmd_suggest}.get(arg, cmd_verify)() or 0)
