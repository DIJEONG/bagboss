#!/usr/bin/env node
// 네이티브 번역 범위 점검: native/Sources/** · native/App/** 의 Swift 소스에서 사람에게 보이는 한글 문자열 리터럴을 모아
// Localizable.xcstrings(웹 tr 과 같은 순서: 정확한 문장 → 자리표시 문장 → 용어 치환)로 영어가 '다' 되는지 본다.
//
//   node tools/js/extract/l10n-audit.mjs            # 요약 + 빠진 목록
//   node tools/js/extract/l10n-audit.mjs --all      # 덮인 것까지 종류별로
//   node tools/js/extract/l10n-audit.mjs --check    # 허용 목록 밖에 빠진 것이 있으면 실패(종료 코드 1)
//   node tools/js/extract/l10n-audit.mjs --json out.json
//   node tools/js/extract/l10n-audit.mjs --catalog 다른.xcstrings   # 예전 카탈로그와 비교할 때
//
// 빼는 것: 주석 · #if DEBUG 블록 · 로그(print · NSLog · fatalError · assert …) · KE("ko", "en") 의 한국어(영어가 바로 옆) ·
//          l10n-allow.json 의 files(개발 점검 화면) · literals(화면에 안 나가는 키 · 내부 식별자).
// 보간 "\(x)호차" 는 자리마다 표본 값 '7' 을 넣어 번역해 본다(숫자 자리 기준 — 이름 자리는 실행 때 사전이 덮는다).
// 판정: exact(키 그대로) · template({0} 문장) · gloss(용어 치환만으로 한글이 남지 않음) · missing(한글이 남음).
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { loadCatalog, makeTr, HANGUL } from './l10n-core.mjs';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..', '..');
const NATIVE = path.join(ROOT, 'native');
const CAT = path.join(NATIVE, 'Sources', 'BBContent', 'Resources', 'Generated', 'Localizable.xcstrings');
const ALLOW = path.join(path.dirname(fileURLToPath(import.meta.url)), 'l10n-allow.json');

// 로그 · 개발 계측(BootTrace.mark · markOnce · measure · reset) — 화면에 안 나간다
const LOG_CALLS = new Set(['mark', 'markOnce', 'measure', 'reset', 'print', 'debugPrint', 'NSLog', 'fatalError', 'assert', 'assertionFailure', 'precondition', 'preconditionFailure', 'os_log', 'dump', 'XCTFail', 'Issue']);

function swiftFiles(dir) {
  const out = [];
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) { if (!e.name.startsWith('.') && e.name !== 'Generated' && !e.name.endsWith('.xcodeproj')) out.push(...swiftFiles(p)); }
    else if (e.name.endsWith('.swift')) out.push(p);
  }
  return out.sort();
}

/** #if DEBUG … #else … #endif 중 DEBUG 쪽 줄을 빈 줄로(줄 번호 유지) */
function stripDebug(src) {
  const lines = src.split('\n'), stack = [];
  const skipping = () => stack.some(f => f.skip);
  return lines.map(line => {
    const t = line.trim();
    let m;
    if ((m = t.match(/^#if\s+(.*)$/))) { const c = m[1].replace(/\/\/.*$/, '').trim(); stack.push({ dbg: c === 'DEBUG' ? 1 : c === '!DEBUG' ? -1 : 0 }); stack.at(-1).skip = stack.at(-1).dbg === 1; return ''; }
    if (/^#elseif\b/.test(t)) { const f = stack.at(-1); if (f) f.skip = f.dbg === 1 ? false : f.skip; return ''; }
    if (/^#else\b/.test(t)) { const f = stack.at(-1); if (f) f.skip = f.dbg === 1 ? false : f.dbg === -1; return ''; }
    if (/^#endif\b/.test(t)) { stack.pop(); return ''; }
    return skipping() ? '' : line;
  }).join('\n');
}

/**
 * Swift 렉서(문자열 · 주석만): 문자열 리터럴마다 { text: 보간을 {0}{1}… 로 바꾼 글, line, call: 감싼 호출 이름, argIndex }
 * 보간 안의 문자열도 따로 모은다.
 */
export function lexSwift(src) {
  const out = [];
  let i = 0, line = 1;
  const n = src.length;
  // 열린 괄호 스택: { name, arg } — 쉼표로 인자 번호를 센다
  const parens = [];
  let lastIdent = '', lastIdentEnd = -1;
  function readString(start, ctx = { call: '', arg: 0 }) {
    // start: 따옴표 앞 '#' 개수 포함 위치
    let hashes = 0; let j = start;
    while (src[j] === '#') { hashes++; j++; }
    const multi = src.startsWith('"""', j);
    const q = multi ? '"""' : '"';
    j += q.length;
    const close = q + '#'.repeat(hashes);
    const esc = '\\' + '#'.repeat(hashes);
    let text = '', idx = 0; const startLine = line; const nested = [];
    while (j < n) {
      if (src.startsWith(close, j)) { j += close.length; break; }
      if (src.startsWith(esc, j)) {
        const k = j + esc.length;
        if (src[k] === '(') {   // 보간: 끝 괄호를 찾고, 안쪽 식을 다시 렉싱한다(안쪽 호출 문맥 — KE · tr — 을 그대로 본다)
          let depth = 1, p = k + 1;
          const line0 = line;
          while (p < n && depth > 0) {
            if (src[p] === '"' || (src[p] === '#' && /^#+"/.test(src.slice(p, p + 6)))) { p = readString(p).end; continue; }
            if (src[p] === '(') depth++; else if (src[p] === ')') depth--;
            if (src[p] === '\n') line++;
            p++;
          }
          // 안쪽 식의 최상위 문자열은 바깥 문자열의 호출 문맥(KE 첫 인자 등)을 물려받는다
          for (const it of lexSwift(src.slice(k + 1, p - 1)))
            nested.push({ ...it, line: it.line + line0 - 1, call: it.call || ctx.call, arg: it.call ? it.arg : ctx.arg, nested: true });
          text += `{${idx++}}`; j = p; continue;
        }
        const c = src[k];
        if (c === 'u') {
          const m = src.slice(k).match(/^u\{([0-9a-fA-F]+)\}/);
          if (m) { text += String.fromCodePoint(parseInt(m[1], 16)); j = k + m[0].length; continue; }
        }
        if (c === '\n') { line++; j = k + 1; continue; }   // 여러 줄 문자열의 줄 이음
        text += c === 'n' ? '\n' : c === 't' ? '\t' : c === '0' ? '\0' : c;
        j = k + 1;
        continue;
      }
      if (src[j] === '\n') { line++; if (!multi) break; }
      text += src[j]; j++;
    }
    if (multi) text = dedentMulti(text);
    return { text, end: j, startLine, nested, holes: idx };
  }
  while (i < n) {
    const c = src[i];
    if (c === '\n') { line++; i++; continue; }
    if (c === '/' && src[i + 1] === '/') { while (i < n && src[i] !== '\n') i++; continue; }
    if (c === '/' && src[i + 1] === '*') {
      let depth = 1; i += 2;
      while (i < n && depth > 0) { if (src.startsWith('/*', i)) { depth++; i += 2; } else if (src.startsWith('*/', i)) { depth--; i += 2; } else { if (src[i] === '\n') line++; i++; } }
      continue;
    }
    if (c === '"' || (c === '#' && /^#+"/.test(src.slice(i, i + 6)))) {
      const top = parens.at(-1);
      const r = readString(i, { call: top ? top.name : '', arg: top ? top.arg : 0 });
      out.push({ text: r.text, line: r.startLine, call: top ? top.name : '', arg: top ? top.arg : 0, holes: r.holes });
      for (const s of r.nested) out.push(s);
      i = r.end; continue;
    }
    if (/[A-Za-z_]/.test(c)) {
      let j = i; while (j < n && /[A-Za-z0-9_]/.test(src[j])) j++;
      lastIdent = src.slice(i, j); lastIdentEnd = j; i = j; continue;
    }
    if (c === '(' || c === '[') {
      const name = c === '(' && lastIdentEnd >= 0 && /^\s*$/.test(src.slice(lastIdentEnd, i)) ? lastIdent : '';
      parens.push({ name, arg: 0, br: c }); i++; lastIdentEnd = -1; continue;
    }
    if (c === ')' || c === ']') { parens.pop(); i++; lastIdentEnd = -1; continue; }
    if (c === ',') { const top = parens.at(-1); if (top) top.arg++; }
    if (!/\s/.test(c)) lastIdentEnd = -1;
    i++;
  }
  return out;
}

function dedentMulti(t) {
  // """ 다음 줄바꿈 ~ 마지막 줄 들여쓰기 제거(대략)
  const lines = t.split('\n');
  if (lines[0].trim() === '') lines.shift();
  const last = lines.at(-1);
  const ind = /^\s*$/.test(last) ? last.length : 0;
  if (/^\s*$/.test(last)) lines.pop();
  return lines.map(l => l.slice(Math.min(ind, l.match(/^\s*/)[0].length))).join('\n');
}

const sample = (t) => t.replace(/\{\d+\}/g, '7');

export function audit({ catalogFile = CAT, allowFile = ALLOW } = {}) {
  const dict = loadCatalog(catalogFile);
  const tr = makeTr(dict);
  const allow = fs.existsSync(allowFile) ? JSON.parse(fs.readFileSync(allowFile, 'utf8')) : { files: [], literals: {} };
  const allowFiles = (allow.files || []).map(f => f.path ?? f);
  const allowLits = new Set(Object.keys(allow.literals || {}));
  const files = [...swiftFiles(path.join(NATIVE, 'Sources')), ...swiftFiles(path.join(NATIVE, 'App'))];
  const items = new Map();   // text → { text, kind, en, sites[] }
  const skipped = { debugOrFile: 0, log: 0, ke: 0, allow: 0 };
  for (const f of files) {
    const rel = path.relative(NATIVE, f);
    if (allowFiles.some(a => rel === a || rel.startsWith(a.replace(/\*$/, '')) && a.endsWith('*'))) { skipped.debugOrFile++; continue; }
    const src = stripDebug(fs.readFileSync(f, 'utf8'));
    for (const lit of lexSwift(src)) {
      if (!HANGUL.test(lit.text)) continue;
      if (LOG_CALLS.has(lit.call)) { skipped.log++; continue; }
      if (lit.call === 'KE' && lit.arg === 0) { skipped.ke++; continue; }
      if (allowLits.has(lit.text)) { skipped.allow++; continue; }
      let it = items.get(lit.text);
      if (!it) {
        const how = {}; const s = lit.holes ? sample(lit.text) : lit.text;
        const en = tr(s, how);
        const kind = HANGUL.test(en) ? 'missing' : how.kind;
        it = { text: lit.text, kind, en, sites: [] }; items.set(lit.text, it);
      }
      it.sites.push(`${rel}:${lit.line}`);
    }
  }
  const all = [...items.values()].sort((a, b) => (a.text < b.text ? -1 : 1));
  const by = k => all.filter(x => x.kind === k);
  return { total: all.length, exact: by('exact').length, template: by('template').length, gloss: by('gloss').length, missing: by('missing'), all, skipped };
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const ci = process.argv.indexOf('--catalog');
  const r = audit(ci > 0 ? { catalogFile: path.resolve(process.argv[ci + 1]) } : {});
  const covered = r.total - r.missing.length;
  console.log(`[l10n-audit] 한글 리터럴 ${r.total}개 · 덮임 ${covered} (정확 ${r.exact} · 자리표시 ${r.template} · 용어 치환 ${r.gloss}) · 빠짐 ${r.missing.length} · 커버리지 ${(covered / Math.max(1, r.total) * 100).toFixed(1)}%`);
  console.log(`  제외: 개발 화면 파일 ${r.skipped.debugOrFile} · 로그 ${r.skipped.log} · KE ${r.skipped.ke} · 허용 목록 ${r.skipped.allow}`);
  const show = process.argv.includes('--all') ? r.all : r.missing;
  for (const m of show) console.log(`  [${m.kind}] ${JSON.stringify(m.text)}  → ${JSON.stringify(m.en)}   (${m.sites[0]}${m.sites.length > 1 ? ` 외 ${m.sites.length - 1}` : ''})`);
  const ji = process.argv.indexOf('--json');
  if (ji > 0) fs.writeFileSync(process.argv[ji + 1], JSON.stringify(r, null, 1));
  if (process.argv.includes('--check')) process.exit(r.missing.length ? 1 : 0);
}
