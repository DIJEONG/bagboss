#!/usr/bin/env node
// 효과음 기준 파형: 웹 sfx.* · blip · skTone · 덕킹을 OfflineAudioContext 로 그려 '비교용 특징'만 남긴다 → BBAudio 대조 테스트.
//
//   native/Tests/Fixtures/audio/sfx.json
//     { sourceSha16, sr, envHopMs, specWin, specHop, seeds,
//       items: [{ id, code, dur, dry: {env, peakDb, dur, centroid}, wet?: {...}, samples? }] }
//
// - dry: 버스(sfx · music · amb, 웹 볼륨 기본값)를 컴프레서 없이 바로 출력에 이은 소리. 네이티브 DSP 의 엄격한 대조 기준.
// - wet: window.__dotlab.sndRender(49-boot.js)와 같은 그래프(버스 → 컴프레서 -14 dB · 4:1 → master) — 단, 0.5초 무음을 먼저 흘린 뒤 소리를 낸다.
//   (Chromium 컴프레서는 검출기가 0(최대 감쇠)에서 출발해 sndRender 처럼 0초에 바로 그리면 앞 0.1초가 크게 눌린다 — 게임에선 생기지 않는 시동 잡음)
// - Math.random 은 시드 고정(mulberry)으로 바꿔 그린다 → 다시 돌려도 같은 파일. 무작위가 섞인 소리는 시드 여러 개의
//   평균 특징(전력 평균 RMS 포락 · 에너지 가중 무게중심)을 남긴다. 샘플 그대로는 잡음 없는 소리 몇 개만.
//   node tools/js/extract/sfx.mjs [--check]
import fs from 'node:fs';
import path from 'node:path';
import { openGame, ROOT, writeJson } from './page.mjs';

const OUT = path.join(ROOT, 'native', 'Tests', 'Fixtures', 'audio', 'sfx.json');
const CHECK = process.argv.includes('--check');
const SR = 22050, SEEDS = 16, ENV_HOP_MS = 5, SPEC_WIN = 512, SPEC_HOP = 256;

// id · 웹 호출(게임 닫힌 범위에서 실행) · 그릴 길이(초) · 옵션
const ITEMS = [
  ['clack', 'TR.v=600; sfx.clack()', .4],
  ['hit_light', 'sfx.hit(false,false)', .5], ['hit_heavy', 'sfx.hit(true,false)', .6], ['hit_heavy_crit', 'sfx.hit(true,true)', .6],
  ['hitK_jab', "sfx.hitK('jab',false,0)", .4], ['hitK_punch', "sfx.hitK('punch',false,0)", .4], ['hitK_hammer', "sfx.hitK('hammer',false,0)", .5],
  ['hitK_kick', "sfx.hitK('kick',false,0)", .5], ['hitK_throw', "sfx.hitK('throw',false,0)", .6], ['hitK_punch_crit_c5', "sfx.hitK('punch',true,5)", .5],
  ['hit3_0', 'sfx.hit3(0)', .3], ['hit3_1', 'sfx.hit3(1)', .4], ['hit3_2', 'sfx.hit3(2)', .8], ['hit3_2_big', 'sfx.hit3(2,{big:true})', 1.0],
  ['hit3_1_air_c4', 'sfx.hit3(1,{air:true,combo:4})', .4], ['hit3_0_crit', 'sfx.hit3(0,{crit:true})', .4],
  ['just', 'sfx.just()', .6], ['floor_05', 'sfx.floor(.5)', .5], ['floor_15', 'sfx.floor(1.5)', .6], ['thud', 'sfx.thud()', .5],
  ['swing', 'sfx.swing()', .4], ['hurt', 'sfx.hurt(false)', .4], ['hurt_heavy', 'sfx.hurt(true)', .6], ['glass', 'sfx.glass()', .5],
  ['boom', 'sfx.boom()', 1.0], ['whoosh', 'sfx.whoosh()', .6], ['dodge', 'sfx.dodge()', .4], ['press', 'sfx.press()', .9],
  ['chime', 'sfx.chime()', 1.3, { samples: true }], ['door_open', 'sfx.door(true)', .8], ['door_close', 'sfx.door(false)', .8],
  ['click', 'sfx.click()', .2, { samples: true }], ['coin', 'sfx.coin()', .5, { samples: true }], ['merge_ok', 'sfx.merge(true)', .7, { samples: true }], ['merge_fail', 'sfx.merge(false)', .8, { samples: true }],
  ['clear', 'sfx.clear()', .8, { samples: true }], ['slowIn', 'sfx.slowIn()', 1.1], ['carHit', 'sfx.carHit(false)', .4], ['carHit_heavy', 'sfx.carHit(true)', .4],
  ['gong', 'sfx.gong()', 1.6], ['ready', 'sfx.ready()', .6, { samples: true }], ['brass', 'sfx.brass()', 1.2, { samples: true }], ['rage', 'sfx.rage()', 1.0],
  ['hiss', 'sfx.hiss()', 1.4], ['pass', 'sfx.pass()', 2.1], ['zap', 'sfx.zap()', .3], ['unlock', 'sfx.unlock()', 1.0, { samples: true }],
  ['blip_cond', "blip('cond','가')", .15], ['blip_saboo', "blip('saboo','하')", .15], ['blip_minnie', "blip('minnie','A')", .15], ['blip_me', "blip('me','오')", .15],
  ['skTone_glint', "skTone(1500,2200,.07,'sine',.05)", .2, { samples: true }], ['skNoise_rain', 'skNoise(.55,130,.14)', .7],
  ['beep_final', "tone(SND.ctx.currentTime,.09,{f:1320,type:'square',g:.08})", .25, { samples: true }], ['door_creak', 'nz(SND.ctx.currentTime,.4,{f:700,to:300,q:6,g:.12})', .6],
  ['duck_big', 'sndDuck(.32,.14,.36)', 1.0, { bg: true, samples: false }],
];
// 컴프레서를 거친 소리(wet)도 남길 것
const WET = ['hit3_2', 'hit3_0', 'boom', 'chime', 'click', 'gong', 'hurt_heavy', 'brass'];

// --- 특징 ---
function envOf(x) { const hop = Math.round(SR * ENV_HOP_MS / 1000), out = [];
  for (let i = 0; i < x.length; i += hop) { let s = 0, n = 0; for (let j = i; j < Math.min(x.length, i + hop); j++) { s += x[j] * x[j]; n++; } out.push(s / n); }
  return out; }   // 전력(제곱 평균) — 시드 평균 뒤 제곱근
function fftMag2(re) {   // 실수 입력 → |X|² (0..N/2), 단순 radix-2
  const N = re.length, im = new Float64Array(N), r = Float64Array.from(re);
  for (let i = 1, j = 0; i < N; i++) { let b = N >> 1; for (; j & b; b >>= 1) j ^= b; j ^= b; if (i < j) { [r[i], r[j]] = [r[j], r[i]]; } }
  for (let len = 2; len <= N; len <<= 1) { const a = -2 * Math.PI / len; for (let i = 0; i < N; i += len) for (let k = 0; k < len / 2; k++) {
    const wr = Math.cos(a * k), wi = Math.sin(a * k), xr = r[i + k + len / 2] * wr - im[i + k + len / 2] * wi, xi = r[i + k + len / 2] * wi + im[i + k + len / 2] * wr;
    r[i + k + len / 2] = r[i + k] - xr; im[i + k + len / 2] = im[i + k] - xi; r[i + k] += xr; im[i + k] += xi; } }
  const m = []; for (let k = 0; k <= N / 2; k++) m.push(r[k] * r[k] + im[k] * im[k]); return m; }
function specOf(x) {   // 창마다 (에너지, Σf·P, ΣP)
  const out = [];
  for (let i = 0; i + SPEC_WIN <= x.length; i += SPEC_HOP) { const w = []; for (let j = 0; j < SPEC_WIN; j++) w.push(x[i + j] * (.5 - .5 * Math.cos(2 * Math.PI * j / SPEC_WIN)));
    const m = fftMag2(w); let fp = 0, p = 0; for (let k = 1; k < m.length; k++) { fp += k * SR / SPEC_WIN * m[k]; p += m[k]; } out.push([p, fp]); }
  return out; }
const r5 = v => +v.toPrecision(5);
function features(renders) {
  const envs = renders.map(envOf), n = envs[0].length;
  const env = Array.from({ length: n }, (_, i) => Math.sqrt(envs.reduce((s, e) => s + e[i], 0) / envs.length));
  const peak = renders.reduce((s, x) => s + x.reduce((m, v) => Math.max(m, Math.abs(v)), 0), 0) / renders.length;
  const specs = renders.map(specOf); let fp = 0, p = 0;
  for (const S of specs) for (const [pp, ff] of S) { p += pp; fp += ff; }
  const emax = Math.max(...env); let last = 0; env.forEach((e, i) => { if (e > emax * 10 ** (-40 / 20)) last = i; });
  return { env: env.map(r5), peakDb: r5(20 * Math.log10(peak + 1e-12)), dur: r5((last + 1) * ENV_HOP_MS / 1000), centroid: r5(p > 0 ? fp / p : 0) };
}
const b64i16 = x => Buffer.from(Int16Array.from(x, v => Math.max(-32768, Math.min(32767, Math.round(v * 32767)))).buffer).toString('base64');

// --- 페이지 안에서 그리기(게임 닫힌 범위) ---
const PRE = 11008;   // wet 앞 무음(프레임) — 렌더 양자(128)의 배수라 suspend 시각이 정확히 맞는다
const RENDER_FN = `(async (code, dur, sr, seed, bg, wet, pre) => {
  const keep = { ...SND }, rnd0 = Math.random, R = mulberry(seed); Math.random = R;
  try {
    const off = wet ? pre : 0, c = new OfflineAudioContext(1, Math.round(sr * dur) + off, sr); SND.ctx = c;
    SND.master = c.createGain(); SND.master.connect(c.destination);
    let to = c.destination;
    if (wet) { const comp = c.createDynamicsCompressor(); comp.threshold.value = -14; comp.ratio.value = 4; comp.connect(SND.master); to = comp; }
    for (const k of ['music', 'sfx', 'amb']) { const g = c.createGain(); g.connect(to); SND[k] = g; }   // dry 는 컴프레서 없이
    SND.music.gain.value = SND.vol.music * .5; SND.amb.gain.value = SND.vol.sfx * .7; SND.sfx.gain.value = SND.vol.sfx;
    const n = c.createBuffer(1, c.sampleRate * 2, c.sampleRate), d = n.getChannelData(0); for (let i = 0; i < d.length; i++) d[i] = Math.random() * 2 - 1;
    SND.noise = n; SND.on = true; SND.muted = false; SND.floorT = -9;
    if (bg) { const o = c.createOscillator(); o.frequency.value = 110; const g = c.createGain(); g.gain.value = .25; o.connect(g).connect(SND.music); o.start(0); }
    if (wet) c.suspend(pre / sr).then(() => { eval(code); c.resume(); }); else eval(code);
    const buf = await c.startRendering(); return Array.from(buf.getChannelData(0)).slice(off);
  } finally { Object.assign(SND, keep); Math.random = rnd0; } })`;

const g = await openGame();
const items = [];
try {
  // 웹 기본 볼륨(저장값 무시)
  await g.page.evaluate(() => { const SND = __BB_SCOPE__('SND'); SND.vol = { master: .8, music: .55, sfx: .8 }; SND.muted = false; });
  for (const [id, code, dur, opt = {}] of ITEMS) {
    const renders = [];
    const rend = (seed, wet) => g.page.evaluate(([fn, code, dur, sr, seed, bg, wet, pre]) => __BB_SCOPE__(fn)(code, dur, sr, seed, bg, wet, pre),
      [RENDER_FN, code, dur, SR, seed, !!opt.bg, wet, PRE]);
    for (let s = 0; s < SEEDS; s++) renders.push(await rend(1000 + s, false));
    const it = { id, code, dur, dry: features(renders) };
    if (opt.samples || opt.bg) it.samples = b64i16(renders[0]);
    if (WET.includes(id)) {
      const wets = []; for (let s = 0; s < SEEDS; s++) wets.push(await rend(1000 + s, true));
      it.wet = features(wets);
    }
    items.push(it);
    process.stdout.write(id + ' ');
  }
} finally { await g.close(); }
console.log();

const data = { sourceSha16: g.sourceSha16, sr: SR, wetPreroll: PRE, envHopMs: ENV_HOP_MS, specWin: SPEC_WIN, specHop: SPEC_HOP, seeds: SEEDS, items };
if (CHECK) {
  const old = fs.existsSync(OUT) ? fs.readFileSync(OUT, 'utf8') : '';
  if (old !== JSON.stringify(data, null, 1) + '\n') { console.error('[sfx] 픽스처가 최신이 아니다 — node tools/js/extract/sfx.mjs'); process.exit(1); }
  console.log('[sfx] 최신'); process.exit(0);
}
writeJson(OUT, data);
console.log('[sfx] ' + path.relative(ROOT, OUT) + ' · ' + items.length + '개 · ' + (fs.statSync(OUT).size / 1024).toFixed(0) + 'KB');
