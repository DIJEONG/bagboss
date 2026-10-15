#!/usr/bin/env node
// 비교 픽스처: 웹 순수(에 가까운) 함수에 시드 고정 무작위 입력을 넣고 출력을 기록한다 → Swift 이식이 맞춰야 할 기준값.
// 1차 대상(가방 · 콤보 경로): shapeOf · canPlace · findSpot · adjItems · computeSets · sStats · stashSpot · routesOf(경로 · 이름)
//
//   native/Tests/Fixtures/bag.json   { cases: [{ input: {bag, stash, imprints}, out: {...} }] }
//
// 입력은 '판 상태 일부(GS.bag · GS.stash · GS.imprints)'로 고정하고, 나머지 GS 는 새 판 기본값이다.
//   node tools/js/extract/fixtures.mjs [--check] [--n 200]
import fs from 'node:fs';
import path from 'node:path';
import { openGame, ROOT } from './page.mjs';

const OUT = path.join(ROOT, 'native', 'Tests', 'Fixtures', 'bag.json');
const N = +(process.argv[process.argv.indexOf('--n') + 1] || 0) || 200;

const g = await openGame();
let data;
try {
  data = await g.page.evaluate((N) => {
    const S = __BB_SCOPE__;
    const GS = S('GS'), GITEMS = S('GITEMS'), INV = S('INV');
    const { shapeOf, canPlace, findSpot, adjItems, computeSets, sStats, stashSpot, routesOf, newItem, mulberry } =
      Object.fromEntries(['shapeOf', 'canPlace', 'findSpot', 'adjItems', 'computeSets', 'sStats', 'stashSpot', 'routesOf', 'newItem', 'mulberry'].map(n => [n, S(n)]));
    const ids = Object.keys(GITEMS).filter(id => !GITEMS[id].pro);
    const r6 = x => Math.round(x * 1e6) / 1e6;       // 부동소수 비교 여유(Swift 쪽도 1e-6 허용)
    const clean = o => JSON.parse(JSON.stringify(o, (k, v) => typeof v === 'number' ? r6(v) : v));
    const strip = b => ({ id: b.id, uid: b.uid, tier: b.tier, x: b.x, y: b.y, rot: b.rot || 0, opt: b.opt || null, ...(b.sx != null ? { sx: b.sx, sy: b.sy } : {}) });

    // 1) 모양: 모든 아이템 × 회전 4
    const shapes = {};
    for (const id of Object.keys(GITEMS)) shapes[id] = [0, 1, 2, 3].map(r => shapeOf(id, r));

    // 2) 무작위 가방
    const OPTK = ['crit', 'critd', 'dmg', 'cd'];
    const cases = [];
    for (let c = 0; c < N; c++) {
      const R = mulberry(9000 + c);
      GS.bag = []; GS.stash = []; GS.uid = 0; GS.sets = {}; GS.demo = false; GS.tower = null;
      GS.imprints = {};
      const nImp = Math.floor(R() * 3);
      for (let k = 0; k < nImp; k++) GS.imprints[Math.floor(R() * INV.W) + ',' + Math.floor(R() * INV.H)] = ['holster', 'pocket', 'worn'][Math.floor(R() * 3)];
      const want = 3 + Math.floor(R() * 9);
      for (let k = 0; k < want; k++) {
        const id = ids[Math.floor(R() * ids.length)];
        const opt = R() < .25 ? { k: OPTK[Math.floor(R() * 4)], v: r6(.05 + R() * .3) } : null;
        const it = newItem(id, 1 + Math.floor(R() * 4), opt);
        it.rot = Math.floor(R() * 4);
        const sp = findSpot(it);
        if (sp) { Object.assign(it, sp); GS.bag.push(it); }
        else { const st = stashSpot(it); if (st) { Object.assign(it, st); GS.stash.push(it); } }
      }
      const input = { bag: GS.bag.map(strip), stash: GS.stash.map(strip), imprints: { ...GS.imprints } };
      // 탐침: 첫 아이템을 무작위 위치 · 회전에 놓을 수 있나
      const probes = [];
      if (GS.bag.length) for (let k = 0; k < 12; k++) {
        const b = GS.bag[Math.floor(R() * GS.bag.length)], x = Math.floor(R() * (INV.W + 2)) - 1, y = Math.floor(R() * (INV.H + 2)) - 1, rot = Math.floor(R() * 4);
        probes.push({ uid: b.uid, x, y, rot, ok: canPlace(b, x, y, rot, b.uid) });
      }
      const extra = newItem(ids[Math.floor(R() * ids.length)], 1); extra.rot = Math.floor(R() * 4);
      const sets = computeSets();
      const out = {
        adj: GS.bag.map((_, i) => adjItems(i).map(o => o.uid)),
        sets,
        stats: GS.bag.map((_, i) => { const s = sStats(i); return { dmg: s.dmg, cd: s.cd, crit: s.crit, critD: s.critD, set: s.set, gem: s.gem, stone: s.stone, pins: s.pins, rings: s.rings, metros: s.metros, cuffs: s.cuffs, imp: s.imp }; }),
        probes,
        spotFor: { id: extra.id, rot: extra.rot, bag: findSpot(extra), stash: stashSpot(extra) },
        routes: routesOf(GS.bag).map(Rt => ({ uids: Rt.items.map(o => o.uid), key: Rt.key, name: Rt.name })),
      };
      cases.push(clean({ input, out }));
    }
    return { shapes, cases, inv: INV };
  }, N);
} finally { await g.close(); }

const json = JSON.stringify({ _about: 'tools/js/extract/fixtures.mjs 로 생성 — 직접 고치지 않는다. 수치는 소수 6자리 반올림.', sourceSha16: g.sourceSha16, ...data }, null, 1) + '\n';
if (process.argv.includes('--check')) {
  const fresh = fs.existsSync(OUT) && fs.readFileSync(OUT, 'utf8') === json;
  console.log(`[fixtures] ${fresh ? '최신' : '다시 생성 필요'}`); process.exit(fresh ? 0 : 1);
}
fs.mkdirSync(path.dirname(OUT), { recursive: true });
fs.writeFileSync(OUT, json);
const c = data.cases;
console.log(`[fixtures] 가방 ${c.length}건 · 평균 아이템 ${(c.reduce((s, x) => s + x.input.bag.length, 0) / c.length).toFixed(1)} · 경로 있는 판 ${c.filter(x => x.out.routes.length).length} · 세트 있는 판 ${c.filter(x => Object.keys(x.out.sets).length).length} → ${path.relative(ROOT, OUT)}`);
