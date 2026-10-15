#!/usr/bin/env node
// 글꼴 추출: 웹 _head.html 에 base64 WOFF2 로 박힌 갈무리 글꼴(UI) + web/app/fonts 의 Anton(만화 효과음)을 TTF 로 풀어 번들에 넣는다.
// iOS CoreText 는 WOFF2 를 바로 읽지 못한다 → wawoff2 로 풀어 sfnt(TTF)로.
//
//   Generated/fonts/Galmuri11.ttf · Galmuri11-Bold.ttf · Galmuri9.ttf · Anton-Regular.ttf + LICENSE-*.txt
//   node tools/js/extract/fonts.mjs [--check]
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import wawoff2 from 'wawoff2';
import { ROOT, SRC, GEN } from './page.mjs';

const OUT = path.join(GEN, 'fonts');
const head = fs.readFileSync(path.join(SRC, '_head.html'), 'utf8');
const faces = [...head.matchAll(/@font-face\{\s*font-family:'([^']+)';\s*font-weight:(\d+);[^}]*?base64,([A-Za-z0-9+/=]+)\)/g)]
  .map(([, family, weight, b64]) => ({ family, weight: +weight, woff2: Buffer.from(b64, 'base64') }));
if (faces.length !== 3) { console.error(`[fonts] 갈무리 글꼴 3개를 기대했는데 ${faces.length}개`); process.exit(1); }

const files = {};
for (const f of faces) {
  const name = `${f.family}${f.weight >= 700 ? '-Bold' : ''}.ttf`;
  files[name] = Buffer.from(await wawoff2.decompress(f.woff2));
}
files['Anton-Regular.ttf'] = Buffer.from(await wawoff2.decompress(fs.readFileSync(path.join(ROOT, 'web', 'app', 'fonts', 'anton-latin-400-normal.woff2'))));
files['LICENSE-Anton.txt'] = fs.readFileSync(path.join(ROOT, 'web', 'app', 'fonts', 'OFL-Anton.txt'));
files['LICENSE-Galmuri.txt'] = Buffer.from(
  'Galmuri — Copyright (c) Minseo Lee (quiple). https://github.com/quiple/galmuri\n' +
  'Licensed under the SIL Open Font License, Version 1.1 (https://openfontlicense.org).\n' +
  '웹판 _head.html 에 서브셋(2,350자) WOFF2 로 들어 있던 것을 TTF 로 풀었다 — 글꼴 이름 · 내용은 바꾸지 않았다.\n');

const digest = crypto.createHash('sha256').update(Object.entries(files).map(([k, v]) => k + crypto.createHash('sha256').update(v).digest('hex')).join()).digest('hex').slice(0, 16);
if (process.argv.includes('--check')) {
  const fresh = Object.entries(files).every(([k, v]) => fs.existsSync(path.join(OUT, k)) && fs.readFileSync(path.join(OUT, k)).equals(v));
  console.log(`[fonts] ${fresh ? '최신' : '다시 생성 필요'}`); process.exit(fresh ? 0 : 1);
}
fs.mkdirSync(OUT, { recursive: true });
for (const [k, v] of Object.entries(files)) fs.writeFileSync(path.join(OUT, k), v);
console.log(`[fonts] ${Object.keys(files).filter(k => k.endsWith('.ttf')).map(k => `${k} ${(files[k].length / 1024) | 0}KB`).join(' · ')} · digest ${digest} → ${path.relative(ROOT, OUT)}`);
