#!/usr/bin/env node
// 번역 추출: 게임 사전(EN_DICT, 부팅 후 — 역 이름 주입 포함) + KE(ko, en) 인라인 쌍
//           + 웹 영어 삼항(en ? `영어` : `한국어` · LANG==='en' ? … : …) + 콘텐츠 표의 영어 필드({n: 한국어, en: 영어} · {ko: 한국어, n: 영어})
//           + 손으로 다듬은 보충(strings-extra.json — 웹이 번역하지 않은 문구 · 네이티브에만 있는 문구) → Localizable.xcstrings
// 우선순위: 사전 > KE > 삼항 > 콘텐츠 en > 보충. 보충은 웹 번역을 덮지 않는다("override": true 로 표시한 것만 덮는다).
// 원문 언어 ko, 키 = 한국어 원문. 자리표시 {0} {1} … 이 있는 키는 위치 지정 서식 %1$@ %2$@ … 으로 바꾼다
// (그 문자열 안의 '%' 글자는 '%%'). 자리표시가 없는 키는 원문 그대로다.
//
// 함께 내는 보고서(Generated/strings-report.json):
//   keConflicts  — 같은 한국어에 KE 영어와 사전 영어가 다른 것
//   untranslated — 소스의 한글 문자열 리터럴 중 위 어디에도 없는 것(부분 치환 GLOSS 에 기대거나 번역 누락 · 개발 화면 문구)
//   extra        — 보충 파일 통계 · 웹 번역에 가려진 보충 키(shadowed) · 자리표시가 어긋난 키(placeholderMismatch)
//   네이티브 Swift 소스 쪽 범위는 l10n-audit.mjs 가 본다.
//
//   node tools/js/extract/strings.mjs [--check]
import fs from 'node:fs';
import path from 'node:path';
import * as acorn from 'acorn';
import { openGame, ROOT, SRC, GEN } from './page.mjs';

const OUT_CAT = path.join(GEN, 'Localizable.xcstrings');
const OUT_REP = path.join(GEN, 'strings-report.json');
const EXTRA = path.join(path.dirname(new URL(import.meta.url).pathname), 'strings-extra.json');

// 1) 부팅 후 사전
const g = await openGame();
let dict;
try { dict = await g.page.evaluate(() => ({ ...__BB_SCOPE__('EN_DICT') })); } finally { await g.close(); }

// 2) 소스 훑기: KE(ko, en) 쌍 · 한글 리터럴
const order = fs.readFileSync(path.join(SRC, 'ORDER.txt'), 'utf8').split(/\s+/).filter(n => n.endsWith('.js'));
const code = order.map(n => fs.readFileSync(path.join(SRC, n), 'utf8')).join('');
const ast = acorn.parse(code, { ecmaVersion: 'latest', sourceType: 'script' });
const HANGUL = /[가-힣]/;
const ke = {}, keConflicts = [], literals = new Set(), tern = {};
const isEnTest = t => (t.type === 'Identifier' && t.name === 'en') ||
  (t.type === 'BinaryExpression' && /^={2,3}$/.test(t.operator) && t.left.type === 'Identifier' && t.left.name === 'LANG' && t.right.type === 'Literal' && t.right.value === 'en');
// 템플릿 → '{0}' 문장. 식은 소스 글자로 맞춘다(ko 쪽 순서가 번호)
const tplOf = (n, holes) => {
  if (n.type === 'Literal' && typeof n.value === 'string') return n.value;
  if (n.type !== 'TemplateLiteral') return null;
  let out = '';
  for (let i = 0; i < n.quasis.length; i++) {
    out += n.quasis[i].value.cooked;
    if (i < n.expressions.length) {
      const src = code.slice(n.expressions[i].start, n.expressions[i].end);
      let k = holes.indexOf(src);
      if (k < 0) { if (holes.frozen) return null; holes.push(src); k = holes.length - 1; }
      out += `{${k}}`;
    }
  }
  return out;
};
const strOf = n => n && n.type === 'Literal' && typeof n.value === 'string' ? n.value
  : n && n.type === 'TemplateLiteral' && n.expressions.length === 0 ? n.quasis[0].value.cooked : null;
(function walk(n) {
  if (!n || typeof n.type !== 'string') return;
  if (n.type === 'CallExpression' && n.callee.type === 'Identifier' && n.callee.name === 'KE') {
    const k = strOf(n.arguments[0]), e = strOf(n.arguments[1]);
    if (k != null && e != null) {
      if (ke[k] != null && ke[k] !== e) keConflicts.push({ ko: k, en: [ke[k], e] });
      ke[k] = e;
    }
  }
  if (n.type === 'ConditionalExpression' && isEnTest(n.test)) {
    const holes = []; const k = tplOf(n.alternate, holes); holes.frozen = true; const e = tplOf(n.consequent, holes);
    if (k != null && e != null && HANGUL.test(k) && !HANGUL.test(e) && k.trim().length) tern[k] = e;
  }
  const s = strOf(n);
  if (s != null && HANGUL.test(s)) literals.add(s);
  if (n.type === 'TemplateLiteral') for (const q of n.quasis) if (HANGUL.test(q.value.cooked)) literals.add(q.value.cooked);
  for (const k in n) {
    const v = n[k];
    if (Array.isArray(v)) v.forEach(walk); else if (v && typeof v.type === 'string') walk(v);
  }
})(ast);

// 3) 콘텐츠 표의 영어 필드(content.mjs 생성물) — {n: 한국어, en: 영어}(TW_FLOORS · TW_OT · TW_MODS …) · {ko: 한국어, n: 영어}(STN)
const contentEn = {};
const CONTENT = path.join(GEN, 'content');
if (fs.existsSync(CONTENT)) {
  for (const f of fs.readdirSync(CONTENT).filter(f => f.endsWith('.json') && f !== 'index.json' && f !== 'lambdas.json').sort()) {
    (function walk(v) {
      if (Array.isArray(v)) return v.forEach(walk);
      if (!v || typeof v !== 'object') return;
      const pair = (k, e) => { if (typeof k === 'string' && typeof e === 'string' && HANGUL.test(k) && !HANGUL.test(e) && e.trim()) contentEn[k] ??= e; };
      pair(v.n, v.en); pair(v.ko, v.n);
      for (const x of Object.values(v)) walk(x);
    })(JSON.parse(fs.readFileSync(path.join(CONTENT, f), 'utf8')));
  }
}

// 4) 보충 파일 — { sections: { 묶음: { 한국어({0}): 영어 | { en, override?, note? } } } }
const extraRaw = fs.existsSync(EXTRA) ? JSON.parse(fs.readFileSync(EXTRA, 'utf8')) : { sections: {} };
const extra = {}, extraOverride = new Set(), extraDup = [];
for (const [sec, entries] of Object.entries(extraRaw.sections || {})) {
  for (const [k, v] of Object.entries(entries)) {
    const e = typeof v === 'string' ? v : v.en;
    if (typeof e !== 'string' || !e.length) throw new Error(`[strings] 보충 '${sec}' 의 '${k}' 에 영어가 없음`);
    if (extra[k] != null && extra[k] !== e) extraDup.push({ ko: k, en: [extra[k], e], section: sec });
    extra[k] = e;
    if (typeof v === 'object' && v.override) extraOverride.add(k);
  }
}

// 5) 합치기 — 사전 우선, KE 는 사전에 없을 때만, 그다음 삼항 · 콘텐츠 · 보충
const all = { ...dict };
const source = {};
for (const k of Object.keys(all)) source[k] = 'dict';
for (const [k, e] of Object.entries(ke)) {
  if (all[k] == null) { all[k] = e; source[k] = 'ke'; }
  else if (all[k] !== e) keConflicts.push({ ko: k, en: [all[k], e], note: '사전과 KE가 다름(사전 사용)' });
}
for (const [k, e] of Object.entries(tern)) if (all[k] == null) { all[k] = e; source[k] = 'ternary'; }
for (const [k, e] of Object.entries(contentEn)) if (all[k] == null) { all[k] = e; source[k] = 'content'; }
const shadowed = [];
for (const [k, e] of Object.entries(extra)) {
  if (all[k] == null || extraOverride.has(k)) { all[k] = e; source[k] = 'extra'; }
  else if (all[k] !== e) shadowed.push({ ko: k, web: all[k], extra: e });
}
// 자리표시 검사: 한국어 · 영어의 {n} 집합이 같아야 한다(웹 사전은 보고만, 보충은 실패)
const holesOf = s => [...new Set((s.match(/\{\d+\}/g) || []))].sort().join(',');
const placeholderMismatch = Object.keys(all).filter(k => holesOf(k) !== holesOf(all[k])).sort().map(k => ({ ko: k, en: all[k], source: source[k] }));
const badExtra = placeholderMismatch.filter(m => m.source === 'extra');
if (badExtra.length) throw new Error(`[strings] 보충 자리표시 불일치: ${badExtra.map(m => m.ko).join(' | ')}`);
const PH = /\{(\d+)\}/g;
const fmt = s => PH.test(s) ? s.replace(/%/g, '%%').replace(PH, (_, i) => `%${+i + 1}$@`) : s;
const strings = {};
for (const k of Object.keys(all).sort()) {
  PH.lastIndex = 0;
  const key = fmt(k); PH.lastIndex = 0;
  const val = PH.test(k) ? (PH.lastIndex = 0, fmt(all[k])) : all[k];
  strings[key] = { extractionState: 'manual', localizations: { en: { stringUnit: { state: 'translated', value: val } } } };
}
const catalog = JSON.stringify({ sourceLanguage: 'ko', strings, version: '1.0' }, null, 2) + '\n';

const covered = new Set(Object.keys(all));
const untranslated = [...literals].filter(s => !covered.has(s) && !covered.has(s.trim())).sort();
const report = JSON.stringify({
  _about: 'tools/js/extract/strings.mjs 로 생성 — 네이티브 문구 이식 때 참고',
  counts: {
    dict: Object.keys(dict).length, ke: Object.keys(ke).length, catalog: Object.keys(strings).length, templates: Object.keys(all).filter(k => /\{\d+\}/.test(k)).length, untranslated: untranslated.length,
    bySource: Object.fromEntries(['dict', 'ke', 'ternary', 'content', 'extra'].map(x => [x, Object.values(source).filter(v => v === x).length])),
  },
  keConflicts,
  extra: { entries: Object.keys(extra).length, used: Object.values(source).filter(v => v === 'extra').length, overrides: [...extraOverride].sort(), shadowed: shadowed.sort((a, b) => (a.ko < b.ko ? -1 : 1)), duplicates: extraDup },
  placeholderMismatch,
  untranslated,
}, null, 1) + '\n';

if (process.argv.includes('--check')) {
  const fresh = fs.existsSync(OUT_CAT) && fs.readFileSync(OUT_CAT, 'utf8') === catalog && fs.existsSync(OUT_REP) && fs.readFileSync(OUT_REP, 'utf8') === report;
  console.log(`[strings] ${fresh ? '최신' : '다시 생성 필요'}`); process.exit(fresh ? 0 : 1);
}
fs.mkdirSync(GEN, { recursive: true });
fs.writeFileSync(OUT_CAT, catalog);
fs.writeFileSync(OUT_REP, report);
console.log(`[strings] 사전 ${Object.keys(dict).length} + KE ${Object.keys(ke).length} + 삼항 ${Object.keys(tern).length} + 콘텐츠 ${Object.keys(contentEn).length} + 보충 ${Object.keys(extra).length}(가려짐 ${shadowed.length}) → 카탈로그 ${Object.keys(strings).length}개 · 충돌 ${keConflicts.length} · 사전 밖 한글 리터럴 ${untranslated.length}개 → ${path.relative(ROOT, OUT_CAT)}`);
