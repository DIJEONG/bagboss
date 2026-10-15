#!/usr/bin/env node
// 콘텐츠 추출: 게임 최상위 const 중 '데이터'인 것을 부팅이 끝난 뒤의 값으로 JSON에 굽는다.
// 다른 조각이 실행 중에 늘리는 표(ETYPES · POSES · JW_SEQ …)도 늘어난 뒤의 값이 나온다.
//
//   Generated/content/<조각>.json   조각별 { 이름: 값 }   (정의 조각은 docs/deps/deps.json 기준)
//   Generated/content/index.json    이름 → 조각 · 모양 · 크기 · 함수 수
//   Generated/content/lambdas.json  값 안의 함수 원문({"$fn":"이름.경로"} 자리) — Swift로 손으로 옮길 목록
//
// 직렬화 규칙: 함수 → {"$fn": 경로} · Set → {"$set": […]} · Map → {"$map": [[k,v]…]}
//             Infinity/NaN → {"$num": "Infinity"} · 순환 참조(조상 경로에 다시 나올 때만) → {"$ref": 경로}
// 제외: 두 번 띄워 값이 다른 것(부팅 때 무작위) · 함수 자체 · DOM/캔버스/WebGL/오디오 객체 · 형식화 배열 · 빈 배열/객체(실행 중 채우는 상태) · 아래 STATE 목록
//
//   node tools/js/extract/content.mjs [--check]
import fs from 'node:fs';
import path from 'node:path';
import { openGame, ROOT, GEN } from './page.mjs';

const OUT = path.join(GEN, 'content');
// 실행 중 상태(데이터가 아님) — 네이티브에서는 BBSim State 로 설계한다
const STATE = new Set(['GS', 'META', 'OPT', 'TR', 'DJ', 'SND', 'NOIR', 'TWR', 'BN', 'CUT_ART', 'TR_CACHE', 'LOOK_CACHE', 'DSTACK',
  'CHARS', 'lights', 'SPR', 'ATL', 'EN_DICT', 'EN_TPL', 'EN_GLOSS', 'PALS', 'PAL0', 'M', 'LEG']);   // 아트 · 번역은 별도 추출기
const MAX_BYTES = 1.5e6;

const deps = JSON.parse(fs.readFileSync(path.join(ROOT, 'docs', 'deps', 'deps.json'), 'utf8'));
const candidates = [];
for (const f of deps.fragments) for (const d of f.defines)
  if (d.kind === 'const' && d.scope === 'iife' && !STATE.has(d.name)) candidates.push({ name: d.name, file: f.file });

async function extractOnce() {
const g = await openGame();
try {
  const r = await g.page.evaluate(({ candidates, MAX_BYTES }) => {
    const S = __BB_SCOPE__;
    const isHost = v => (typeof Node !== 'undefined' && v instanceof Node) || ArrayBuffer.isView(v) || v instanceof ArrayBuffer
      || (typeof WebGLObject !== 'undefined' && v instanceof WebGLObject) || (typeof WebGL2RenderingContext !== 'undefined' && v instanceof WebGL2RenderingContext)
      || (typeof AudioNode !== 'undefined' && v instanceof AudioNode) || (typeof BaseAudioContext !== 'undefined' && v instanceof BaseAudioContext)
      || (typeof CanvasRenderingContext2D !== 'undefined' && v instanceof CanvasRenderingContext2D) || (typeof ImageData !== 'undefined' && v instanceof ImageData)
      || (typeof Image !== 'undefined' && v instanceof Image) || (typeof ResizeObserver !== 'undefined' && v instanceof ResizeObserver)
      || (typeof MutationObserver !== 'undefined' && v instanceof MutationObserver) || v instanceof RegExp || v instanceof Promise || v === window || v === document;
    const out = {}, lambdas = {}, skipped = {};
    for (const { name } of candidates) {
      let v;
      try { v = S(name); } catch (e) { skipped[name] = 'TDZ/오류'; continue; }
      if (v === undefined || typeof v === 'function') { skipped[name] = typeof v; continue; }
      if (isHost(v)) { skipped[name] = '호스트 객체'; continue; }
      if (v && typeof v === 'object' && !(v instanceof Set) && !(v instanceof Map) && Object.keys(v).length === 0) { skipped[name] = '빈 값(실행 상태)'; continue; }
      if (v && typeof v === 'object' && !Array.isArray(v) && !(v instanceof Set) && !(v instanceof Map) && Object.keys(v).length && Object.values(v).every(x => typeof x === 'function')) { skipped[name] = '함수 묶음(코드)'; continue; }
      const seen = new Map(); let fnN = 0, hostHit = false;
      const ser = (x, p) => {
        if (typeof x === 'function') { lambdas[p] = x.toString(); fnN++; return { $fn: p }; }
        if (typeof x === 'number' && !Number.isFinite(x)) return { $num: String(x) };
        if (typeof x === 'bigint') return { $num: String(x) };
        if (x === null || typeof x !== 'object') return x;
        if (isHost(x)) { hostHit = true; return { $host: Object.prototype.toString.call(x) }; }
        if (seen.has(x)) return { $ref: seen.get(x) };   // 진짜 순환(조상 경로에 다시 나옴)만 — 공유 객체는 그대로 펼친다
        seen.set(x, p);
        try {
        if (x instanceof Set) return { $set: [...x].map((e, i) => ser(e, p + '[' + i + ']')) };
        if (x instanceof Map) return { $map: [...x].map(([k, e], i) => [ser(k, p + '<k' + i + '>'), ser(e, p + '<' + i + '>')]) };
        if (Array.isArray(x)) return x.map((e, i) => ser(e, p + '[' + i + ']'));
        const o = {}; for (const k of Object.keys(x)) o[k] = ser(x[k], p + '.' + k); return o;
        } finally { seen.delete(x); }
      };
      const val = ser(v, name);
      if (hostHit) { skipped[name] = '호스트 객체 포함'; for (const k of Object.keys(lambdas)) if (k === name || k.startsWith(name + '.') || k.startsWith(name + '[')) delete lambdas[k]; continue; }
      const json = JSON.stringify(val);
      if (json.length > MAX_BYTES) { skipped[name] = '너무 큼 ' + json.length; continue; }
      out[name] = { val, fns: fnN, bytes: json.length,
        shape: Array.isArray(v) ? 'array[' + v.length + ']' : v instanceof Set ? 'set[' + v.size + ']' : v instanceof Map ? 'map[' + v.size + ']' : v && typeof v === 'object' ? 'object{' + Object.keys(v).length + '}' : typeof v };
    }
    return { out, lambdas, skipped };
  }, { candidates, MAX_BYTES });
  return { ...r, sourceSha16: g.sourceSha16 };
} finally { await g.close(); }
}

// 두 번 띄워 값이 다른 이름 = 부팅 때 무작위로 정해지는 실행 상태 → 데이터에서 뺀다
const res = await extractOnce(), res2 = await extractOnce();
for (const name of Object.keys(res.out)) {
  if (JSON.stringify(res.out[name].val) !== JSON.stringify(res2.out[name]?.val)) {
    delete res.out[name]; res.skipped[name] = '비결정(부팅마다 다름)';
    for (const k of Object.keys(res.lambdas)) if (k === name || k.startsWith(name + '.') || k.startsWith(name + '[')) delete res.lambdas[k];
  }
}

// 조각별로 묶기
const byFile = {}, index = {};
for (const { name, file } of candidates) {
  const r = res.out[name]; if (!r) continue;
  const key = file.replace(/\.js$/, '');
  (byFile[key] ??= {})[name] = r.val;
  // 객체형 표는 키 순서를 따로 적는다 — Swift JSONDecoder 는 순서를 잃는데, 게임은 Object.keys 순서에 기댄다(매점 뽑기 등)
  const plain = r.val && typeof r.val === 'object' && !Array.isArray(r.val) && !('$set' in r.val) && !('$map' in r.val);
  index[name] = { file: key, shape: r.shape, bytes: r.bytes, ...(r.fns ? { fns: r.fns } : {}), ...(plain ? { keyOrder: Object.keys(r.val) } : {}) };
}
const files = {};
for (const [k, v] of Object.entries(byFile)) files[k + '.json'] = JSON.stringify(v, null, 1) + '\n';
files['index.json'] = JSON.stringify({ _about: 'tools/js/extract/content.mjs 로 생성 — 직접 고치지 않는다.', sourceSha16: res.sourceSha16, names: index, skipped: res.skipped }, null, 1) + '\n';
files['lambdas.json'] = JSON.stringify(res.lambdas, null, 1) + '\n';

if (process.argv.includes('--check')) {
  const have = fs.existsSync(OUT) ? fs.readdirSync(OUT).sort() : [];
  const fresh = JSON.stringify(have) === JSON.stringify(Object.keys(files).sort())
    && Object.entries(files).every(([k, v]) => fs.readFileSync(path.join(OUT, k), 'utf8') === v);
  console.log(`[content] ${fresh ? '최신' : '다시 생성 필요'}`); process.exit(fresh ? 0 : 1);
}
fs.rmSync(OUT, { recursive: true, force: true });
fs.mkdirSync(OUT, { recursive: true });
for (const [k, v] of Object.entries(files)) fs.writeFileSync(path.join(OUT, k), v);
const total = Object.values(index).reduce((s, x) => s + x.bytes, 0);
console.log(`[content] 이름 ${Object.keys(index).length}개 · ${(total / 1024).toFixed(0)}KB · 조각 ${Object.keys(byFile).length}개 · 함수 ${Object.keys(res.lambdas).length}개 · 제외 ${Object.keys(res.skipped).length}개 → ${path.relative(ROOT, OUT)}`);
