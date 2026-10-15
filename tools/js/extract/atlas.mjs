#!/usr/bin/env node
// 아트 굽기: 게임이 부팅 때 만드는 스프라이트 전부(SPR)를 웹과 같은 배치(ATL)로 아틀라스 PNG 두 장에 굽는다.
//   atlas_a.rgba.deflate  = (재질 번호, 톤·255, 발광·255, 255)        ← 웹 ATL._a 와 같은 바이트
//   atlas_n.rgba.deflate  = (nx·.5+.5, ny·.5+.5, mask, rel) ·255     ← 웹 ATL._n 과 같은 바이트
//   palettes.rgba.deflate = 폭 STEPS(6) × 높이 NMAT·NPAL(80·3)      ← 웹 palTex 와 같은 배치
//   atlas.json            = 이름 → {x,y,w,h,px,py,mask} + 상수
// 형식: RGBA8 원본 바이트(행 우선, 위→아래)를 raw DEFLATE(RFC 1951)로 압축 — Foundation `.zlib` 해제와 짝.
// PNG 를 쓰지 않는 이유: 이 픽셀은 색이 아니라 데이터다. iOS 이미지 디코더는 알파가 0인 픽셀의 RGB 를
// 지워 버린다(알파 미리 곱하기) — 노멀 아틀라스의 알파(rel)는 대부분 0이라 조명이 전부 깨진다(N0 기기 점검에서 확인).
// 사람이 볼 미리보기 PNG 는 번들 밖 tools/js/out/atlas/ 에 따로 쓴다.
// 아래 '불러온 원화' 영역(USER_REG_H)은 실험실 전용이라 굽지 않는다(높이 = atlasUserY).
//
//   node tools/js/extract/atlas.mjs            # 생성
//   node tools/js/extract/atlas.mjs --check    # 두 번 구워 같은지(결정성) + 생성물이 최신인지
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { openGame, ROOT, GEN as OUT } from './page.mjs';
import zlib from 'node:zlib';
import { encodePng } from './png.mjs';

const PREVIEW = path.join(ROOT, 'tools', 'js', 'out', 'atlas');

async function bake() {
  const g = await openGame();
  try {
    return await g.page.evaluate(() => {
      const S = __BB_SCOPE__;
      const SPR = S('SPR'), ATL = S('ATL'), W = S('atlasW'), H = S('atlasUserY');
      const STEPS = S('STEPS'), NMAT = S('NMAT'), NPAL = S('NPAL'), PALS = S('PALS');
      const A = new Uint8Array(W * H * 4), N = new Uint8Array(W * H * 4);
      const sprites = {};
      const std = new Set(['w', 'h', 'mat', 'tone', 'emit', 'rel', 'nx', 'ny', 'px', 'py', 'mask']);
      const extraKeys = {};
      // 웹 pack() 과 같은 순서(높이 내림차순, 안정 정렬)로 기록해 두면 diff 가 읽기 쉽다
      for (const [k, s] of Object.entries(SPR).sort((a, b) => b[1].h - a[1].h)) {
        const o = ATL[k];
        if (!o) throw new Error('ATL 에 없는 스프라이트: ' + k);
        for (let yy = 0; yy < s.h; yy++) for (let xx = 0; xx < s.w; xx++) {
          const i = yy * s.w + xx, j = ((o.y + yy) * W + (o.x + xx)) * 4; if (!s.mat[i]) continue;
          A[j] = s.mat[i]; A[j + 1] = Math.round(Math.min(1, s.tone[i]) * 255); A[j + 2] = Math.round(s.emit[i] * 255); A[j + 3] = 255;
          N[j] = Math.round((s.nx[i] * .5 + .5) * 255); N[j + 1] = Math.round((s.ny[i] * .5 + .5) * 255); N[j + 2] = Math.round(s.mask * 255); N[j + 3] = Math.round((s.rel ? s.rel[i] : 0) * 255);
        }
        sprites[k] = { x: o.x, y: o.y, w: s.w, h: s.h, px: s.px, py: s.py, mask: s.mask };
        for (const key of Object.keys(s)) if (!std.has(key)) (extraKeys[key] ??= []).push(k);
      }
      const P = new Uint8Array(STEPS * NMAT * NPAL * 4);
      PALS.forEach((pal, pi) => pal.forEach((row, m) => row.forEach((c, st) => {
        const j = ((pi * NMAT + m) * STEPS + st) * 4; P[j] = c[0]; P[j + 1] = c[1]; P[j + 2] = c[2]; P[j + 3] = 255;
      })));
      const b64 = u8 => { let s = ''; for (let i = 0; i < u8.length; i += 0x8000) s += String.fromCharCode.apply(null, u8.subarray(i, i + 0x8000)); return btoa(s); };
      const M = S('M');
      return {
        W, H, STEPS, NMAT, NPAL, A: b64(A), N: b64(N), P: b64(P), sprites,
        extraKeys: Object.fromEntries(Object.entries(extraKeys).map(([k, v]) => [k, v.length])),
        materials: M,
      };
    }).then(r => ({ ...r, sourceSha16: g.sourceSha16 }));
  } finally { await g.close(); }
}

function files(r) {
  const buf = s => Buffer.from(s, 'base64');
  const pack = b => zlib.deflateRawSync(b, { level: 9 });
  const meta = {
    _about: 'tools/js/extract/atlas.mjs 로 생성 — 직접 고치지 않는다.',
    sourceSha16: r.sourceSha16,
    format: 'rgba8 · 행 우선(위→아래) · raw DEFLATE(RFC 1951)',
    atlas: { width: r.W, height: r.H, a: 'atlas_a.rgba.deflate', n: 'atlas_n.rgba.deflate' },
    palette: { file: 'palettes.rgba.deflate', steps: r.STEPS, materials: r.NMAT, palettes: r.NPAL, layout: 'x=단(0..STEPS-1), y=팔레트·NMAT+재질' },
    materials: r.materials,
    sprites: r.sprites,
  };
  return {
    'atlas_a.rgba.deflate': pack(buf(r.A)), 'atlas_n.rgba.deflate': pack(buf(r.N)), 'palettes.rgba.deflate': pack(buf(r.P)),
    'atlas.json': Buffer.from(JSON.stringify(meta, null, 1) + '\n'),
  };
}
function previews(r) {
  const buf = s => Buffer.from(s, 'base64');
  fs.mkdirSync(PREVIEW, { recursive: true });
  fs.writeFileSync(path.join(PREVIEW, 'atlas_a.png'), encodePng(r.W, r.H, buf(r.A)));
  fs.writeFileSync(path.join(PREVIEW, 'atlas_n.png'), encodePng(r.W, r.H, buf(r.N)));
  fs.writeFileSync(path.join(PREVIEW, 'palettes.png'), encodePng(r.STEPS, r.NMAT * r.NPAL, buf(r.P)));
}
const digest = fs_ => crypto.createHash('sha256').update(Object.entries(fs_).map(([k, v]) => k + crypto.createHash('sha256').update(v).digest('hex')).join()).digest('hex').slice(0, 16);

const t0 = Date.now();
const r1 = await bake();
const f1 = files(r1);
if (Object.keys(r1.extraKeys).length) console.log('[atlas] 표준 밖 스프라이트 속성(네이티브에서 확인 필요):', r1.extraKeys);
if (process.argv.includes('--check')) {
  const f2 = files(await bake());
  const same = digest(f1) === digest(f2);
  const fresh = Object.entries(f1).every(([k, v]) => fs.existsSync(path.join(OUT, k)) && fs.readFileSync(path.join(OUT, k)).equals(v));
  console.log(`[atlas] 결정성 ${same ? '같음' : '다름!'} · 생성물 ${fresh ? '최신' : '다시 생성 필요'}`);
  process.exit(same && fresh ? 0 : 1);
}
fs.mkdirSync(OUT, { recursive: true });
for (const old of ['atlas_a.png', 'atlas_n.png', 'palettes.png']) fs.rmSync(path.join(OUT, old), { force: true });
for (const [k, v] of Object.entries(f1)) fs.writeFileSync(path.join(OUT, k), v);
previews(r1);
console.log(`[atlas] 스프라이트 ${Object.keys(r1.sprites).length}장 · ${r1.W}×${r1.H} · digest ${digest(f1)} · ${((Date.now() - t0) / 1000).toFixed(1)}s → ${path.relative(ROOT, OUT)}`);
