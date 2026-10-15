#!/usr/bin/env node
// web/src 조각 의존성 지도.
// 조각들을 ORDER.txt 순서로 이어 붙여 한 스크립트로 파싱(acorn)하고, 스코프 분석(eslint-scope)으로
// '최상위 이름(전역 + 즉시 실행 함수 몸통)'의 정의 조각과 참조 조각을 정확히 묶는다(정규식 근사 아님).
//
//   node tools/js/deps_web.mjs            # docs/deps/deps.json + docs/05-의존성-지도.md 생성
//   node tools/js/deps_web.mjs --check    # 생성물이 최신인지(다르면 종료 코드 1)
//
// 구분:
//   읽기(read)      — 다른 조각의 이름을 읽거나 부른다
//   다시 대입(write) — 다른 조각이 선언한 let/var 를 통째로 바꾼다(x = …, x++)  → 공유 가변 상태
//   속성 변경(mutate) — 다른 조각 객체의 속성을 바꾼다(GS.hp = …, PAL[i] = …)    → 공유 가변 상태
//   typeof 가드      — `typeof x` 로만 확인하는 참조(없어도 안 깨짐) → 따로 센다
//   개발 훅          — 49-boot.js 의 window.__dotlab = {…} 안 참조 → 따로 센다(출시 빌드에서 축소 대상)
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import * as acorn from 'acorn';
import * as eslintScope from 'eslint-scope';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const SRC = path.join(ROOT, 'web', 'src');
const TABLE = JSON.parse(fs.readFileSync(path.join(ROOT, 'tools', 'modules.json'), 'utf8'));
const OUT_JSON = path.join(ROOT, 'docs', 'deps', 'deps.json');
const OUT_MD = path.join(ROOT, 'docs', '05-의존성-지도.md');
const HOOK_FILE = '49-boot.js';

const meta = Object.fromEntries(TABLE.modules.map(m => [m.file, m]));
const order = fs.readFileSync(path.join(SRC, 'ORDER.txt'), 'utf8').split(/\s+/).filter(n => n.endsWith('.js'));

// 1) 이어 붙이고 조각별 범위 기록
let code = '';
const spans = [];
for (const f of order) {
  const body = fs.readFileSync(path.join(SRC, f), 'utf8');
  spans.push({ file: f, a: code.length, b: code.length + body.length });
  code += body;
}
const fragOf = pos => {
  let lo = 0, hi = spans.length - 1;
  while (lo < hi) { const mid = (lo + hi + 1) >> 1; if (spans[mid].a <= pos) lo = mid; else hi = mid - 1; }
  return spans[lo].file;
};

// 2) 파싱 · 스코프
const ast = acorn.parse(code, { ecmaVersion: 'latest', sourceType: 'script', ranges: true });
const sm = eslintScope.analyze(ast, { ecmaVersion: 2022, sourceType: 'script' });
const globalScope = sm.globalScope;
const iifeNode = ast.body.find(s => s.type === 'ExpressionStatement' && s.expression.type === 'CallExpression'
  && /Function/.test(s.expression.callee.type))?.expression.callee;
if (!iifeNode) { console.error('[deps] 즉시 실행 함수를 못 찾음'); process.exit(1); }
const iifeScope = sm.acquire(iifeNode);

// 3) 보조 정보: 부모 링크 · typeof · 속성 변경 대상 · 개발 훅 범위
const parent = new Map();
(function walk(n, p) {
  if (!n || typeof n.type !== 'string') return;
  if (p) parent.set(n, p);
  for (const k in n) {
    if (k === 'range') continue;
    const v = n[k];
    if (Array.isArray(v)) v.forEach(c => c && typeof c.type === 'string' && walk(c, n));
    else if (v && typeof v.type === 'string') walk(v, n);
  }
})(ast, null);

let hookRange = null;
for (const [n] of parent) {
  if (n.type === 'AssignmentExpression' && n.left.type === 'MemberExpression'
    && n.left.object.name === 'window' && n.left.property.name === '__dotlab' && fragOf(n.range[0]) === HOOK_FILE) {
    hookRange = n.right.range; break;
  }
}
const inHook = pos => hookRange && pos >= hookRange[0] && pos < hookRange[1];

const isTypeofOnly = id => { const p = parent.get(id); return p && p.type === 'UnaryExpression' && p.operator === 'typeof'; };
// id 가 `id.a.b = …` / `id[i]++` / `delete id.x` 의 뿌리 객체인가
const isMutationRoot = id => {
  let n = id, p = parent.get(n);
  if (!p || p.type !== 'MemberExpression' || p.object !== n) return false;
  while (p && p.type === 'MemberExpression' && p.object === n) { n = p; p = parent.get(n); }
  if (!p) return false;
  if (p.type === 'AssignmentExpression' && p.left === n) return true;
  if (p.type === 'UpdateExpression' && p.argument === n) return true;
  if (p.type === 'UnaryExpression' && p.operator === 'delete') return true;
  return false;
};

// 4) 최상위 이름 수집
const vars = [];   // { name, file, kind, scope }
const collect = (scope, tag) => {
  for (const v of scope.variables) {
    if (!v.defs.length) continue;           // 내장 · arguments
    const d = v.defs[0];
    const file = fragOf(d.name.range[0]);
    const kind = d.type === 'FunctionName' ? 'function' : d.type === 'ClassName' ? 'class'
      : d.type === 'Variable' ? d.parent.kind : d.type.toLowerCase();
    const dupFiles = [...new Set(v.defs.map(x => fragOf(x.name.range[0])))];
    vars.push({ v, name: v.name, file, kind, scope: tag, dupFiles });
  }
};
collect(globalScope, 'global');
collect(iifeScope, 'iife');

// 5) 참조 집계
const frag = {};
for (const s of spans) frag[s.file] = {
  file: s.file, group: meta[s.file]?.group ?? '?', title: meta[s.file]?.title ?? '',
  lines: fs.readFileSync(path.join(SRC, s.file), 'utf8').split('\n').length - 1,
  kb: +((s.b - s.a) / 1024).toFixed(1),
  defines: [], imports: {}, writes: {}, mutates: {}, guarded: {}, hook: {},
};
const add = (obj, from, name) => { (obj[from] ??= new Set()).add(name); };
const sharedState = [];  // 여러 조각이 바꾸는 이름

for (const x of vars) {
  frag[x.file].defines.push({ name: x.name, kind: x.kind, scope: x.scope, ...(x.dupFiles.length > 1 ? { alsoIn: x.dupFiles.filter(f => f !== x.file) } : {}) });
  const writers = new Set(), mutators = new Set(), readers = new Set();
  for (const r of x.v.references) {
    const pos = r.identifier.range[0];
    const at = fragOf(pos);
    if (r.init) continue;                    // 선언 초기값
    if (r.isWrite()) writers.add(at);
    else if (isMutationRoot(r.identifier)) mutators.add(at);
    else readers.add(at);
    if (at === x.file) continue;
    const F = frag[at];
    if (inHook(pos)) add(F.hook, x.file, x.name);
    else if (r.isWrite()) add(F.writes, x.file, x.name);
    else if (isTypeofOnly(r.identifier)) add(F.guarded, x.file, x.name);
    else {
      add(F.imports, x.file, x.name);
      if (isMutationRoot(r.identifier)) add(F.mutates, x.file, x.name);
    }
  }
  const changers = new Set([...writers, ...mutators]);
  if (changers.size > 1 || [...changers].some(f => f !== x.file))
    sharedState.push({ name: x.name, owner: x.file, kind: x.kind, reassignedIn: [...writers].sort(), mutatedIn: [...mutators].sort(), readIn: readers.size });
}

// '선언 없이 쓰는 이름'(전역 암묵 · 브라우저 API)은 무시. 단, 조각이 만든 window.* 은 셀 수 없다(동적).

// 6) 조각 그래프 · 강결합 묶음(SCC) · 위상 순서
const files = spans.map(s => s.file);
const edges = Object.fromEntries(files.map(f => [f, new Set(Object.keys(frag[f].imports))]));
// Tarjan
let idx = 0; const st = [], on = new Set(), I = {}, L = {}, sccs = [];
const strong = v => {
  I[v] = L[v] = idx++; st.push(v); on.add(v);
  for (const w of edges[v]) {
    if (I[w] === undefined) { strong(w); L[v] = Math.min(L[v], L[w]); }
    else if (on.has(w)) L[v] = Math.min(L[v], I[w]);
  }
  if (L[v] === I[v]) { const c = []; let w; do { w = st.pop(); on.delete(w); c.push(w); } while (w !== v); sccs.push(c.sort()); }
};
files.forEach(f => I[f] === undefined && strong(f));
// Tarjan 의 출력 순서 = 의존 대상이 먼저(잎 → 뿌리)
const sccOf = {}; sccs.forEach((c, i) => c.forEach(f => sccOf[f] = i));

// 7) 개발 조각 누수(개발 아닌 조각 → 개발 조각 정의)
const isDev = f => frag[f].group === 'dev';
const devLeaks = [];
for (const f of files) {
  if (isDev(f)) continue;
  for (const [from, names] of Object.entries(frag[f].imports)) if (isDev(from)) devLeaks.push({ user: f, devFile: from, names: [...names].sort() });
}

// 8) 묶음(group) 행렬
const groups = [...new Set(files.map(f => frag[f].group))];
const gm = Object.fromEntries(groups.map(g => [g, Object.fromEntries(groups.map(h => [h, 0]))]));
for (const f of files) for (const [from, names] of Object.entries(frag[f].imports)) {
  if (frag[from].group !== frag[f].group) gm[frag[f].group][frag[from].group] += names.size;
}

// 9) 직렬화
const ser = o => Object.fromEntries(Object.entries(o).sort().map(([k, s]) => [k, [...s].sort()]));
const sha = (await import('node:crypto')).createHash('sha256').update(code).digest('hex').slice(0, 16);
const json = {
  _about: 'node tools/js/deps_web.mjs 로 생성. 직접 고치지 않는다.',
  scripts_sha16: sha,
  fragments: files.map(f => {
    const F = frag[f];
    const usedBy = files.filter(g => g !== f && frag[g].imports[f]).sort();
    return { file: f, group: F.group, title: F.title, lines: F.lines, kb: F.kb, scc: sccOf[f],
      defines: F.defines, usedBy, imports: ser(F.imports), writes: ser(F.writes), mutates: ser(F.mutates),
      guarded: ser(F.guarded), hook: ser(F.hook) };
  }),
  sharedState: sharedState.sort((a, b) => (b.reassignedIn.length + b.mutatedIn.length) - (a.reassignedIn.length + a.mutatedIn.length) || a.name.localeCompare(b.name)),
  sccs: sccs.filter(c => c.length > 1),
  devLeaks,
  groupMatrix: gm,
};

// 10) 마크다운
const md = [];
const cnt = o => Object.values(o).reduce((s, v) => s + v.size, 0);
md.push('# 05 · 의존성 지도 (자동 생성)', '',
  `> \`node tools/js/deps_web.mjs\` 로 생성 — 직접 고치지 않는다. 원본 데이터: \`docs/deps/deps.json\`. 스크립트 sha \`${sha}\`.`,
  '> 파서(acorn) + 스코프 분석(eslint-scope) 기준이라 지역 변수 가림(shadowing)까지 반영한 정확한 참조다.',
  '> 단, `window[...]` · 문자열 이름 호출 · HTML 속성 같은 동적 참조는 잡지 못한다.', '');

md.push('## 1. 조각별 요약', '',
  '- 정의: 이 조각이 선언한 최상위 이름 수 · 씀: 다른 조각에서 가져다 쓰는 이름 수 · 쓰임: 이 조각을 쓰는 조각 수',
  '- 바꿈: 다른 조각 소유의 이름을 다시 대입하거나 속성을 바꾸는 수(공유 가변 상태) · 묶음#: 순환으로 묶인 강결합 묶음 번호(—는 단독)', '',
  '| 조각 | 묶음 | 줄 | KB | 정의 | 씀(조각) | 쓰임(조각) | 바꿈 | 묶음# |', '|---|---|---:|---:|---:|---:|---:|---:|---:|');
const bigScc = new Map(json.sccs.map((c, i) => [c.join(), i + 1]));
for (const F of json.fragments) {
  const sc = sccs[F.scc].length > 1 ? bigScc.get(sccs[F.scc].join()) : '—';
  const changes = Object.values(F.writes).flat().length + Object.values(F.mutates).flat().length;
  md.push(`| \`${F.file}\` | ${F.group} | ${F.lines} | ${F.kb} | ${F.defines.length} | ${Object.values(F.imports).flat().length} (${Object.keys(F.imports).length}) | ${F.usedBy.length} | ${changes} | ${sc} |`);
}

md.push('', '## 2. 묶음(group) 사이 참조 수', '', '행 = 쓰는 쪽, 열 = 정의한 쪽. 같은 묶음 안은 0으로 뒀다.', '',
  `| 쓰는 쪽 \\ 정의 | ${groups.join(' | ')} |`, `|---|${groups.map(() => '---:').join('|')}|`);
for (const g of groups) md.push(`| **${g}** | ${groups.map(h => gm[g][h] || '·').join(' | ')} |`);

md.push('', '## 3. 순환(강결합 묶음)', '',
  '서로가 서로를 쓰는 조각 무리. 진짜 모듈(ES 모듈 · Swift 타입)로 나눌 때 한 번에 옮겨야 하거나, 인터페이스로 끊어야 하는 곳이다.', '');
if (!json.sccs.length) md.push('없음.');
json.sccs.forEach((c, i) => md.push(`- **묶음 ${i + 1}** (${c.length}개): ${c.map(f => `\`${f}\``).join(' · ')}`));

md.push('', '## 4. 공유 가변 상태 (여러 조각이 바꾸는 이름)', '',
  '네이티브 이식 · 모듈화에서 가장 먼저 "누가 주인인가"를 정해야 하는 대상. 상위 40개.', '',
  '| 이름 | 종류 | 선언 조각 | 다시 대입하는 조각 | 속성을 바꾸는 조각 | 읽는 조각 수 |', '|---|---|---|---|---|---:|');
const short = l => l.length ? l.map(f => f.slice(0, 2)).join(' ') : '—';
for (const s of json.sharedState.slice(0, 40))
  md.push(`| \`${s.name}\` | ${s.kind} | \`${s.owner}\` | ${short(s.reassignedIn)} | ${short(s.mutatedIn)} | ${s.readIn} |`);
md.push('', `(전체 ${json.sharedState.length}개는 deps.json \`sharedState\`. 조각은 앞 두 자리 번호로 줄였다.)`);

md.push('', '## 5. 개발 조각 누수 (출시 빌드에서 dev 를 빼면 깨지는 곳)', '',
  '개발 도구가 아닌 조각이 `dev` 조각의 정의를 직접 쓰는 경우. typeof 가드 참조와 49번 개발 훅 안 참조는 제외했다.', '',
  '| 쓰는 조각 | dev 조각 | 이름 |', '|---|---|---|');
for (const d of devLeaks) md.push(`| \`${d.user}\` | \`${d.devFile}\` | ${d.names.map(n => `\`${n}\``).join(' ')} |`);
const devFree = files.filter(f => isDev(f) && !devLeaks.some(d => d.devFile === f));
md.push('', `바로 뺄 수 있는 dev 조각(게임 쪽 직접 참조 없음): ${devFree.length ? devFree.map(f => `\`${f}\``).join(' · ') : '없음'}`);

md.push('', '## 6. 잎부터의 순서 (이식 · 모듈화 후보 순서)', '',
  '의존 대상이 먼저 오도록 정렬했다. 위쪽일수록 다른 조각을 덜 쓰므로 먼저 꺼내기 쉽다. 같은 줄은 순환 묶음.', '');
sccs.forEach((c, i) => md.push(`${i + 1}. ${c.map(f => `\`${f}\` (${frag[f].group})`).join(' · ')}`));
md.push('');

const mdText = md.join('\n');
const jsonText = JSON.stringify(json, null, 1) + '\n';

if (process.argv.includes('--check')) {
  const same = fs.existsSync(OUT_JSON) && fs.readFileSync(OUT_JSON, 'utf8') === jsonText
    && fs.existsSync(OUT_MD) && fs.readFileSync(OUT_MD, 'utf8') === mdText;
  console.log(same ? '[deps] 최신' : '[deps] 다시 생성 필요'); process.exit(same ? 0 : 1);
}
fs.mkdirSync(path.dirname(OUT_JSON), { recursive: true });
fs.writeFileSync(OUT_JSON, jsonText);
fs.writeFileSync(OUT_MD, mdText);
console.log(`[deps] 이름 ${vars.length}개 · 공유 가변 ${json.sharedState.length}개 · 순환 묶음 ${json.sccs.length}개 · dev 누수 ${devLeaks.length}건 → docs/05-의존성-지도.md`);
