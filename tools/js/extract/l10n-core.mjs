// 번역 공통: Localizable.xcstrings 읽기 + 웹 tr() 와 같은 번역 순서(정확한 문장 → 자리표시 문장 → 용어 치환).
// 네이티브 BBContent/Localization.swift(Loc) 가 같은 알고리즘이다 — 고치면 둘 다 고친다.
import fs from 'node:fs';

const HANGUL = /[가-힣]/;
const POS = /%(\d+)\$@/g;

/** 카탈로그 키/값(%1$@ 형식) → 웹 사전 형식({0}) */
export function fromCatalogForm(s) {
  POS.lastIndex = 0;
  if (!POS.test(s)) return s;
  POS.lastIndex = 0;
  return s.replace(POS, (_, n) => `{${+n - 1}}`).replace(/%%/g, '%');
}

/** xcstrings → { 한국어({0} 형식): 영어 } */
export function loadCatalog(file) {
  const obj = JSON.parse(fs.readFileSync(file, 'utf8'));
  const out = {};
  for (const [k, v] of Object.entries(obj.strings || {})) {
    const val = v?.localizations?.en?.stringUnit?.value;
    if (typeof val === 'string' && val.length) out[fromCatalogForm(k)] = fromCatalogForm(val);
  }
  return out;
}

/** 웹 00-i18n.js tr() 이식 — dict 는 {0} 형식 사전 */
export function makeTr(dict) {
  const TPL = [], GLOSS = [];
  for (const [k, v] of Object.entries(dict)) {
    if (/\{\d+\}/.test(k)) {
      const parts = k.split(/(\{\d+\})/); let re = '^'; const order = []; let lit = 0;
      for (const p of parts) {
        const m = p.match(/^\{(\d+)\}$/);
        if (m) { re += '([\\s\\S]*?)'; order.push(+m[1]); } else { re += p.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'); lit += p.length; }
      }
      TPL.push([new RegExp(re + '$'), v, order, lit, k]);
    } else if (k.length >= 2) GLOSS.push([k, v]);
  }
  // 정렬은 안정 정렬 + 같은 길이면 키 순서(결정적 — Swift 쪽과 같게)
  TPL.sort((a, b) => b[3] - a[3] || (a[4] < b[4] ? -1 : a[4] > b[4] ? 1 : 0));
  GLOSS.sort((a, b) => b[0].length - a[0].length || (a[0] < b[0] ? -1 : a[0] > b[0] ? 1 : 0));
  const cache = new Map();
  function tr(s, how) {
    if (typeof s !== 'string' || !HANGUL.test(s)) return s;
    const lead = s.match(/^\s*/)[0], trail = s.match(/\s*$/)[0], core = s.trim();
    let out = dict[core], kind = out != null ? 'exact' : null;
    if (out == null && core.length <= 800) {
      for (const [re, v, order] of TPL) {
        const m = core.match(re);
        if (m) { out = v.replace(/\{(\d+)\}/g, (_, n) => { const i = order.indexOf(+n); return i >= 0 ? tr(m[i + 1]) : ''; }); kind = 'template'; break; }
      }
    }
    if (out == null) { let t = core; for (const [k, v] of GLOSS) if (t.includes(k)) t = t.split(k).join(v); out = t; kind = 'gloss'; }
    out = out.replace(/\b1 (cell|hit|token|run|node|item|line|trigger|time|second|enemie)s\b/g, (m, w) => '1 ' + (w === 'enemie' ? 'enemy' : w));
    if (how) how.kind = kind;
    return lead + out + trail;
  }
  return tr;
}

export { HANGUL };
