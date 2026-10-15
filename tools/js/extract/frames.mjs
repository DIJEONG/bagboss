#!/usr/bin/env node
// 렌더 프레임 캡처(N1 렌더러 대조용): 웹판에서 장면을 실제로 돌린 뒤 루프를 붙잡고 render() 를 한 번 직접 불러,
// 그 프레임의 WebGL 호출(정점 데이터 · 그리기 순서 · 상태 · 유니폼)을 기록하고 각 단계 결과 픽셀을 읽어 둔다.
// Swift Metal 렌더러는 같은 입력(frame.json)을 받아 단계별로 같은 픽셀을 내야 한다.
//
//   native/Tests/Fixtures/frames/<장면>/frame.json        그리기 입력(RenderFrame)
//   native/Tests/Fixtures/frames/<장면>/<단계>.rgba.deflate  웹 결과 픽셀(위→아래 행, raw DEFLATE): gInfo · gNorm · comp · bloom · post
//
// 이 픽스처는 '그 순간의 스냅숏'이다(웹 게임이 결정적이지 않아 다시 찍으면 장면이 달라진다) → --check 없음. 바꾸려면 다시 찍고 커밋한다.
//   node tools/js/extract/frames.mjs [장면 …]
import fs from 'node:fs';
import path from 'node:path';
import zlib from 'node:zlib';
import { openGame, ROOT } from './page.mjs';
import { encodePng } from './png.mjs';

const OUT = path.join(ROOT, 'native', 'Tests', 'Fixtures', 'frames');
const PREVIEW = path.join(ROOT, 'tools', 'js', 'out', 'frames');

// 장면 준비: 웹 개발 훅으로 들어가 실제 시간만큼 돌린 뒤 찍는다
const SCENES = {
  subway: { setup: `window.__dotlab.jumpTo('subway')`, wait: 3500 },
  tower: { setup: `(()=>{ const L=window.__dotlab; L.jumpTo('tower'); L.demoBag(1); L.towerGo(6); })()`, wait: 3000 },
};

const want = process.argv.slice(2).filter(a => !a.startsWith('-'));
const names = want.length ? want : Object.keys(SCENES);

for (const name of names) {
  const sc = SCENES[name];
  if (!sc) { console.error(`[frames] 모르는 장면: ${name}`); process.exit(1); }
  const g = await openGame({ run: true, viewport: { width: 390, height: 844 } });
  try {
    const p = g.page;
    await p.waitForTimeout(1200);
    await p.click('#modeSeg button[data-m="game"]');
    await p.waitForTimeout(1200);
    await p.evaluate(sc.setup);
    await p.waitForTimeout(sc.wait);
    // 루프 붙잡기: 다음 프레임부터 rAF 콜백을 맡아 둔다
    await p.evaluate(() => { window.__bbHold = true; });
    await p.waitForTimeout(200);
    const r = await p.evaluate(capture);
    write(name, r, g.sourceSha16);
  } finally { await g.close(); }
}

// ---- 페이지 안에서 도는 캡처 ----
function capture() {
  const S = __BB_SCOPE__, gl = S('gl');
  const W = S('W'), H = S('H');
  const progs = { sprite: S('sprProg'), mesh: S('prog3'), comp: S('compProg'), bright: S('brightProg'), blur: S('blurProg'), post: S('postProg'), blit: S('blitProg'), debug: S('dbgProg') };
  const fbs = { gbuf: S('gFB'), comp: S('cFB'), post: S('pFB'), bloomA: S('bFA'), bloomB: S('bFB') };
  const bufs = { sprite: S('vbo'), mesh: S('vbo3') };
  const nameOf = (tbl, v) => v == null ? 'screen' : (Object.keys(tbl).find(k => tbl[k] === v) || '?');
  // 이미 만들어 둔 유니폼 위치에 이름표
  const sprU = S('sprU'); for (const k in sprU) if (sprU[k]) sprU[k].__n = k;
  for (const u of S('nodeU')) if (u.loc) u.loc.__n = `u${u.node.id}_${u.k}`;

  const log = [], uni = new Map(), data = {};
  let prog = null, fb = null, arrayBuf = null;
  const st = { blend: false, blendF: null, mask: [true, true, true, true], depth: false, depthF: null, viewport: null };
  const orig = {};
  const hook = (n, f) => { orig[n] = gl[n]; gl[n] = function (...a) { const r = orig[n].apply(gl, a); f(a, r); return r; }; };
  hook('getUniformLocation', ([, n], r) => { if (r) r.__n = n; });
  hook('useProgram', ([p]) => { prog = p; if (!uni.has(p)) uni.set(p, {}); });
  hook('bindFramebuffer', ([t, f]) => { if (t !== gl.READ_FRAMEBUFFER) fb = f; });
  hook('bindBuffer', ([t, b]) => { if (t === gl.ARRAY_BUFFER) arrayBuf = b; });
  hook('enable', ([c]) => { if (c === gl.BLEND) st.blend = true; if (c === gl.DEPTH_TEST) st.depth = true; });
  hook('disable', ([c]) => { if (c === gl.BLEND) st.blend = false; if (c === gl.DEPTH_TEST) st.depth = false; });
  hook('blendFunc', ([s, d]) => { st.blendF = [s === gl.DST_COLOR ? 'dstColor' : s, d === gl.ZERO ? 'zero' : d]; });
  hook('colorMask', (a) => { st.mask = a.map(Boolean); });
  hook('depthFunc', ([f]) => { st.depthF = f === gl.LESS ? 'less' : f; });
  hook('viewport', (a) => { st.viewport = a; });
  hook('bufferSubData', ([, off, src, srcOff = 0, len]) => {
    const k = nameOf(bufs, arrayBuf); data[k] = Array.from(src.subarray(srcOff, srcOff + (len ?? src.length - srcOff)));
  });
  const setU = (vals) => (a) => { const loc = a[0]; if (!loc || !prog) return; uni.get(prog)[loc.__n || '?'] = vals(a); };
  for (const n of ['uniform1f', 'uniform1i']) hook(n, setU(a => [a[1]]));
  for (const n of ['uniform2f']) hook(n, setU(a => [a[1], a[2]]));
  for (const n of ['uniform3f']) hook(n, setU(a => [a[1], a[2], a[3]]));
  for (const n of ['uniform4f']) hook(n, setU(a => [a[1], a[2], a[3], a[4]]));
  for (const n of ['uniform1fv', 'uniform4fv']) hook(n, setU(a => Array.from(a[1])));
  hook('drawArrays', ([mode, first, count]) => {
    log.push({ prog: nameOf(progs, prog), fb: nameOf(fbs, fb), first, count, blend: st.blend ? st.blendF : null, mask: st.mask.slice(),
      depth: st.depth ? st.depthF : null, viewport: st.viewport, uniforms: JSON.parse(JSON.stringify(uni.get(prog) || {})) });
  });

  const time = S('gameTime');
  try { S('render')(performance.now()); }
  finally { for (const n in orig) gl[n] = orig[n]; }

  // 단계별 결과 읽기(GL 은 아래→위 행 → 위→아래로 뒤집는다)
  const read = (f, att, w, h) => {
    gl.bindFramebuffer(gl.READ_FRAMEBUFFER, f); gl.readBuffer(att);
    const px = new Uint8Array(w * h * 4); gl.readPixels(0, 0, w, h, gl.RGBA, gl.UNSIGNED_BYTE, px);
    const out = new Uint8Array(w * h * 4);
    for (let y = 0; y < h; y++) out.set(px.subarray((h - 1 - y) * w * 4, (h - y) * w * 4), y * w * 4);
    let s = ''; for (let i = 0; i < out.length; i += 0x8000) s += String.fromCharCode.apply(null, out.subarray(i, i + 0x8000));
    return { w, h, b64: btoa(s) };
  };
  const usedPost = log.some(d => d.prog === 'post');
  const pixels = {
    gInfo: read(fbs.gbuf, gl.COLOR_ATTACHMENT0, W, H),
    gNorm: read(fbs.gbuf, gl.COLOR_ATTACHMENT1, W, H),
    comp: read(fbs.comp, gl.COLOR_ATTACHMENT0, W, H),
    ...(usedPost ? { bloom: read(fbs.bloomA, gl.COLOR_ATTACHMENT0, W >> 1, H >> 1), post: read(fbs.post, gl.COLOR_ATTACHMENT0, W, H) } : {}),
  };
  gl.bindFramebuffer(gl.READ_FRAMEBUFFER, null);
  return { W, H, time, log, data, pixels, scene: S('scene'), state: S('GS').state };
}

// ---- 기록 → RenderFrame ----
function write(name, r, sourceSha16) {
  const dir = path.join(OUT, name);
  fs.rmSync(dir, { recursive: true, force: true });
  fs.mkdirSync(dir, { recursive: true });
  const L = r.log;
  const gbuf = L.filter(d => d.fb === 'gbuf');
  const spr = gbuf.find(d => d.prog === 'sprite');
  const pass = gbuf.map(d => d.prog === 'sprite'
    ? { kind: 'sprite', first: d.first, count: d.count, shadow: (d.uniforms.uShadow?.[0] ?? 0) > .5 }
    : { kind: 'mesh', first: d.first, count: d.count });
  const one = p => L.find(d => d.prog === p)?.uniforms ?? null;
  const frame = {
    _about: 'tools/js/extract/frames.mjs 로 찍은 웹 프레임 — RenderFrame(BBRender) 입력. 다시 찍으면 장면이 달라진다.',
    sourceSha16, scene: r.scene, state: r.state,
    width: r.W, height: r.H, time: r.time,
    sprite: { uniforms: spr ? spr.uniforms : null, verts: r.data.sprite ?? [] },
    mesh: { uniforms: one('mesh'), verts: r.data.mesh ?? [] },
    gbuffer: pass,
    composite: { program: L.find(d => d.fb === 'comp')?.prog, uniforms: L.find(d => d.fb === 'comp')?.uniforms ?? null },
    post: L.some(d => d.prog === 'post') ? {
      bright: one('bright'),
      blur: L.filter(d => d.prog === 'blur').map(d => ({ uniforms: d.uniforms, target: d.fb })),
      post: one('post'),
    } : null,
    blit: one('blit'),
    // 원본 호출 기록(디버그용)
    calls: L.map(({ uniforms, ...d }) => d),
  };
  fs.writeFileSync(path.join(dir, 'frame.json'), JSON.stringify(frame) + '\n');
  fs.mkdirSync(path.join(PREVIEW, name), { recursive: true });
  for (const [k, px] of Object.entries(r.pixels)) {
    const raw = Buffer.from(px.b64, 'base64');
    fs.writeFileSync(path.join(dir, `${k}.rgba.deflate`), zlib.deflateRawSync(raw, { level: 9 }));
    fs.writeFileSync(path.join(PREVIEW, name, `${k}.png`), encodePng(px.w, px.h, raw));
  }
  const nq = (r.data.sprite?.length ?? 0) / 54, n3 = (r.data.mesh?.length ?? 0) / 30;
  console.log(`[frames] ${name}: ${r.W}×${r.H} · 장면 ${r.scene}/${r.state} · 쿼드 ${nq} · 3D 삼각형 ${n3} · 광원 ${frame.composite.uniforms?.uLN?.[0]} · 후처리 ${frame.post ? '있음' : '없음'} · 합성 ${frame.composite.program}`);
}
