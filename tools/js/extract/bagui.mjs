#!/usr/bin/env node
// 가방 편집 · 미리보기 비교 픽스처: 웹 가방 UI(33-bag-ui2 · 32-block-art · 27-actors)의 동작을 시드 고정 입력으로 기록한다
// → Swift BagEditor · BagPreview(native/Sources/BBSim/Bag/)가 맞춰야 할 기준값.
//
//   native/Tests/Fixtures/bagui/bagui.json
//     labels   : labelRect(id, rot) 전부
//     links    : linkBetween(A, B) — 모든 아이템 쌍(연계 이름 · id)
//     cases[]  : { input: 판 상태, previews: previewPlace + 콤보 경로 변화, stashPrev: 보류함 미리보기,
//                  suggest: rtSuggest 칸 점수, tiles: tileStats, ops: 편집 행동 순서와 행동마다의 상태 }
//
// 행동: rotateItem · quickEquip · discardItem · askMerge(→ 합성하기 단추 · Math.random 고정) · doUndo · autoPack · 끌어 놓기(pointerup 의 가방/보류함 분기)
// 끌어 놓기는 이벤트 처리기 안의 코드라 직접 부를 수 없다 → 같은 줄을 여기 옮겨 웹 함수(canPlace · canStash · stashSpot …)로 실행한다.
//
//   node tools/js/extract/bagui.mjs [--check] [--n 150]
import fs from 'node:fs';
import path from 'node:path';
import { openGame, ROOT } from './page.mjs';

const OUT = path.join(ROOT, 'native', 'Tests', 'Fixtures', 'bagui', 'bagui.json');
const N = +(process.argv[process.argv.indexOf('--n') + 1] || 0) || 150;

const g = await openGame();
let data;
try {
  data = await g.page.evaluate((N) => {
    const S = __BB_SCOPE__;
    const GS = S('GS'), GITEMS = S('GITEMS'), INV = S('INV'), TIER_MAX = S('TIER_MAX');
    const F = Object.fromEntries(['shapeOf', 'canPlace', 'findSpot', 'computeSets', 'sStats', 'stashSpot', 'canStash', 'stFoot', 'routesOf', 'newItem', 'mulberry',
      'previewPlace', 'rotateItem', 'quickEquip', 'discardItem', 'askMerge', 'doUndo', 'pushUndo', 'autoPack', 'labelRect', 'linkBetween', 'tileStats',
      'rtScore', 'cdReset', 'renderBag', 'isSkillB', 'cellsOf'].map(n => [n, S(n)]));
    const ids = Object.keys(GITEMS).filter(id => !GITEMS[id].pro);
    const r6 = x => Math.round(x * 1e6) / 1e6;
    const clean = o => JSON.parse(JSON.stringify(o, (k, v) => typeof v === 'number' ? r6(v) : v));
    const strip = b => ({ id: b.id, uid: b.uid, tier: b.tier || 1, x: b.x, y: b.y, rot: b.rot || 0, opt: b.opt ? { ...b.opt } : null, t: b.t || 0,   // opt 는 복사(뒤 합성이 같은 객체를 고친다)
      ...(b.sx != null ? { sx: b.sx, sy: b.sy } : {}), ...(b.pin != null ? { pin: b.pin } : {}) });
    const snap = () => ({ bag: GS.bag.map(strip), stash: GS.stash.map(strip), tokens: GS.tokens, sel: GS.selUid ?? null,
      undo: (GS.undo || []).length, isNew: GS.stash.concat(GS.bag).filter(o => o.isNew).map(o => o.uid) });
    const findAny = uid => GS.bag.find(b => b.uid === uid) || GS.stash.find(b => b.uid === uid);

    GS.on = true; GS.state = 'arrange'; GS.demo = false; GS.tower = null; GS.cine = null; GS.cut = null;

    // 1) 이름표 자리: 모든 아이템 × 회전
    const labels = {};
    for (const id of Object.keys(GITEMS)) labels[id] = [0, 1, 2, 3].map(r => { const L = F.labelRect(id, r); return [L.lx, L.ly, L.lw, L.lh]; });
    // 2) 연계: 모든 쌍
    const links = [];
    for (const a of Object.keys(GITEMS)) for (const b of Object.keys(GITEMS)) { const L = F.linkBetween({ id: a }, { id: b }); if (L) links.push([a, b, L.id]); }

    const OPTK = ['crit', 'critd', 'dmg', 'cd'];
    const cases = [];
    for (let c = 0; c < N; c++) {
      const R = F.mulberry(7000 + c);
      GS.bag = []; GS.stash = []; GS.uid = 0; GS.sets = {}; GS.undo = []; GS.selUid = null; GS.equipHint = null;
      GS.tokens = Math.floor(R() * 9); GS.imprints = {};
      const nImp = Math.floor(R() * 4);
      for (let k = 0; k < nImp; k++) GS.imprints[Math.floor(R() * INV.W) + ',' + Math.floor(R() * INV.H)] = ['holster', 'pocket', 'worn'][Math.floor(R() * 3)];
      const want = 3 + Math.floor(R() * 8);
      const mk = (id, tier, opt) => { const it = F.newItem(id, tier, opt); it.rot = Math.floor(R() * 4); it.t = r6(R() * 2); return it; };
      for (let k = 0; k < want; k++) {
        const id = ids[Math.floor(R() * ids.length)];
        const opt = R() < .25 ? { k: OPTK[Math.floor(R() * 4)], v: Math.round((.05 + R() * .3) * 100) / 100 } : null;
        const it = mk(id, 1 + Math.floor(R() * 4), opt);
        const sp = F.findSpot(it);
        if (sp && R() < .8) { Object.assign(it, sp); GS.bag.push(it); }
        else { const st = F.stashSpot(it); if (st) { Object.assign(it, st); GS.stash.push(it); if (R() < .4) it.isNew = true; } }
      }
      // 합성 재료: 가방 · 보류함의 아무 아이템과 같은 것 1~2개를 보류함에
      for (let k = 0; k < 2; k++) { const all = GS.bag.concat(GS.stash); if (!all.length) break; const o = all[Math.floor(R() * all.length)]; if ((o.tier || 1) >= TIER_MAX) continue;
        const it = mk(o.id, o.tier || 1, R() < .5 ? { k: OPTK[Math.floor(R() * 4)], v: Math.round((.05 + R() * .3) * 100) / 100 } : null);
        const st = F.stashSpot(it); if (st) { Object.assign(it, st); GS.stash.push(it); } }
      F.computeSets();
      const input = { bag: GS.bag.map(strip), stash: GS.stash.map(strip), tokens: GS.tokens, imprints: { ...GS.imprints }, uid: GS.uid,
        isNew: GS.stash.filter(o => o.isNew).map(o => o.uid) };

      // 3) 놓기 미리보기(previewPlace + showPreview 의 콤보 경로 줄)
      const previews = [];
      const pool = GS.bag.concat(GS.stash);
      for (let k = 0; k < 14 && pool.length; k++) {
        const b = pool[Math.floor(R() * pool.length)], rot = Math.floor(R() * 4), x = Math.floor(R() * INV.W), y = Math.floor(R() * INV.H);
        const ok = F.canPlace(b, x, y, rot, b.uid);
        if (!ok) { previews.push({ uid: b.uid, x, y, rot, ok }); continue; }
        const P = F.previewPlace(b, x, y, rot);
        const hyp = GS.bag.filter(o => o !== b).concat([{ ...b, x, y, rot }]), R0 = F.routesOf(GS.bag), R1 = F.routesOf(hyp), rl = [];
        for (const r of R1) { const o = R0.find(q => q.items[0].uid === r.items[0].uid); if (!o) rl.push(['new', r.name, r.col]); else if (o.key !== r.key) rl.push(['chg', o.name, r.name, r.col]); }
        for (const o of R0) if (!R1.find(q => q.items[0].uid === o.items[0].uid)) rl.push(['cut', o.name]);
        const st = s => s ? { dmg: s.dmg, cd: s.cd } : null;
        previews.push({ uid: b.uid, x, y, rot, ok, dp: P.dp, st0: st(P.st0), st1: st(P.st1), newL: P.newL, newS: P.newS, imp: Object.keys(P.imp), routes: rl });
      }
      // 4) 보류함 미리보기(showPreview 의 inPocket 분기)
      const stashPrev = [];
      for (let k = 0; k < 4 && pool.length; k++) {
        const b = pool[Math.floor(R() * pool.length)], rot = Math.floor(R() * 4), f = F.stFoot(b, rot);
        const px = Math.floor(R() * (INV.SW - f.w + 1)), py = Math.floor(R() * (INV.SH - f.h + 1));
        const ok0 = F.canStash(b, px, py, rot, b.uid), alt = !ok0 && GS.bag.includes(b) && F.stashSpot(b, rot), ok = ok0 || !!alt, cut = [];
        if (ok && GS.bag.includes(b)) { const hyp = GS.bag.filter(o => o !== b); for (const o of F.routesOf(GS.bag)) if (!F.routesOf(hyp).find(q => q.key === o.key)) cut.push(o.name); }
        stashPrev.push({ uid: b.uid, x: px, y: py, rot, ok0, alt: alt || null, cut, dropSkill: ok && GS.bag.includes(b) && GITEMS[b.id].kind === 'skill' });
      }
      // 5) 추천 칸(rtSuggest 와 같은 계산): 칸마다 콤보 점수 증가
      const suggest = [];
      for (const b of pool.filter(F.isSkillB).slice(0, 2)) { const rot = Math.floor(R() * 4), base = GS.bag.filter(o => o !== b), s0 = F.rtScore(base), hits = [];
        for (let y = 0; y < INV.H; y++) for (let x = 0; x < INV.W; x++) { if (!F.canPlace(b, x, y, rot, b.uid)) continue; const v = F.rtScore(base.concat([{ ...b, x, y, rot }])) - s0; if (v > 0) hits.push([x, y, v]); }
        suggest.push({ uid: b.uid, rot, hits }); }
      // 6) 타일 표기 값
      const tiles = pool.map(b => { const T = F.tileStats(b); return { uid: b.uid, dmg: T.dmg ?? null, cd: T.cd ?? null, val: T.val ?? null, hasCd: !!T.hasCd }; });

      // 7) 편집 행동
      const ops = [];
      for (let k = 0; k < 10; k++) {
        const all = GS.bag.concat(GS.stash), kind = Math.floor(R() * 8);
        let op = null;
        if (kind === 0 && all.length) { const b = all[Math.floor(R() * all.length)]; op = { op: 'rotate', uid: b.uid }; F.rotateItem(b); }
        else if (kind === 1 && GS.stash.length) { const b = GS.stash[Math.floor(R() * GS.stash.length)]; op = { op: 'quickEquip', uid: b.uid }; F.quickEquip(b.uid); }
        else if (kind === 2 && all.length && R() < .5) { const b = all[Math.floor(R() * all.length)]; op = { op: 'discard', uid: b.uid }; F.discardItem(b); }
        else if (kind === 3) {
          const pairs = []; for (const a of all) for (const b of all) if (a !== b && a.id === b.id && (a.tier || 1) === (b.tier || 1) && (a.tier || 1) < TIER_MAX) pairs.push([a, b]);
          if (pairs.length) { const [src, dst] = pairs[Math.floor(R() * pairs.length)], boost = R() < .5, roll = r6(R());
            op = { op: 'merge', src: src.uid, dst: dst.uid, boost, roll };
            const mr = Math.random; Math.random = () => roll;
            try { F.askMerge(src, dst); const box = document.querySelector('.inv-merge'); const cb = box.querySelector('input'); cb.checked = boost && !cb.disabled; box.querySelector('[data-a=go]').onclick(); }
            finally { Math.random = mr; } } }
        else if (kind === 4) { op = { op: 'undo' }; F.doUndo(); }
        else if (kind === 5 && R() < .4) { op = { op: 'autoPack' }; F.pushUndo(); F.autoPack(); }
        else if (kind === 6 && all.length) {   // 가방 칸에 놓기(pointerup 의 마지막 분기)
          const b = all[Math.floor(R() * all.length)], rot = Math.floor(R() * 4); let tx = Math.floor(R() * INV.W), ty = Math.floor(R() * INV.H);
          for (let t = 0; t < 30 && !F.canPlace(b, tx, ty, rot, b.uid); t++) { tx = Math.floor(R() * INV.W); ty = Math.floor(R() * INV.H); }
          op = { op: 'toBag', uid: b.uid, x: tx, y: ty, rot };
          if (F.canPlace(b, tx, ty, rot, b.uid)) { F.pushUndo(); F.cdReset(b); b.isNew = false; b.x = tx; b.y = ty; b.rot = rot; if (GS.stash.includes(b)) { GS.stash = GS.stash.filter(o => o !== b); GS.bag.push(b); } }
          F.renderBag(); }
        else if (kind === 7 && all.length) {   // 보류함 칸에 놓기(pointerup 의 inPocket 분기)
          const b = all[Math.floor(R() * all.length)], rot = Math.floor(R() * 4), f = F.stFoot(b, rot);
          const px = Math.floor(R() * (INV.SW - f.w + 1)), py = Math.floor(R() * (INV.SH - f.h + 1));
          op = { op: 'toStash', uid: b.uid, x: px, y: py, rot };
          const fromBag = GS.bag.includes(b);
          const sp = F.canStash(b, px, py, rot, b.uid) ? { sx: px, sy: py, rot } : fromBag ? F.stashSpot(b, rot) : null;
          if (sp) { F.pushUndo(); if (fromBag) { GS.bag = GS.bag.filter(o => o !== b); GS.stash.push(b); } Object.assign(b, sp); }
          F.renderBag(); }
        if (op) ops.push({ ...op, after: snap() });
      }
      cases.push(clean({ input, previews, stashPrev, suggest, tiles, ops }));
    }
    return { labels, links, cases };
  }, N);
} finally { await g.close(); }

const json = JSON.stringify({ _about: 'tools/js/extract/bagui.mjs 로 생성 — 직접 고치지 않는다. 수치는 소수 6자리 반올림.', sourceSha16: g.sourceSha16, ...data }, null, 1) + '\n';
if (process.argv.includes('--check')) {
  const fresh = fs.existsSync(OUT) && fs.readFileSync(OUT, 'utf8') === json;
  console.log(`[bagui] ${fresh ? '최신' : '다시 생성 필요'}`); process.exit(fresh ? 0 : 1);
}
fs.mkdirSync(path.dirname(OUT), { recursive: true });
fs.writeFileSync(OUT, json);
const c = data.cases, cnt = k => c.reduce((s, x) => s + x.ops.filter(o => o.op === k).length, 0);
console.log(`[bagui] ${c.length}판 · 미리보기 ${c.reduce((s, x) => s + x.previews.filter(p => p.ok).length, 0)} · 행동 회전 ${cnt('rotate')} · 장착 ${cnt('quickEquip')} · 버리기 ${cnt('discard')} · 합성 ${cnt('merge')} · 되돌리기 ${cnt('undo')} · 정리 ${cnt('autoPack')} · 가방 ${cnt('toBag')} · 보류 ${cnt('toStash')} → ${path.relative(ROOT, OUT)}`);
