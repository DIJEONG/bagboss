#!/usr/bin/env node
// 저장 픽스처: 게임을 실제로 띄워 '게임이 스스로 쓴' localStorage 문자열과 '불러온 뒤의 값'을 기록한다 → BBPersistence 테스트 기준값.
//
//   native/Tests/Fixtures/saves/*.json
//     meta-default.json      새 기기 META 를 metaSave() 로 쓴 문자열(파싱해서 저장)
//     meta-played.json       metaFoe · metaItem · metaLink · metaStn · tot · 타워 기록 등을 실제 함수로 바꾼 뒤 metaSave()
//     meta-merge.json        { saved: 일부 키만 있는 옛 저장, loaded: 다시 읽은 뒤 META } — 얕은 병합 · best/tot 한 단계 병합 대조
//     run.json               startRun → 장비 · 고정(pin) 추가 → 게임의 saveRun() 이 쓴 문자열
//     run-rejected.json      { saved: v:2 저장 } — loadRunSave() 가 null 을 돌려주는지
//     opt.json               { default, saved, loaded } — {...기본값, ...저장값}
//     snd.json               { default, saved, loaded } — Object.assign(vol) · muted 불리언화
//     lang.json              { default, raw } — dotlab-lang 은 JSON 이 아닌 날 문자열
//     cc.json                { default, saved, loaded } — 배열이면 앞 CC_MAX 개
//
//   node tools/js/extract/saves.mjs
import path from 'node:path';
import { openGame, ROOT, writeJson } from './page.mjs';

const OUT = path.join(ROOT, 'native', 'Tests', 'Fixtures', 'saves');
const g = await openGame({ run: true });
const page = g.page;
const reload = async () => {
  await page.reload();
  await page.waitForFunction(() => typeof window.__BB_SCOPE__ === 'function', null, { timeout: 60000 });
};

try {
  await page.evaluate(() => localStorage.clear());
  await reload();

  // 1) 기본값들(빈 저장소에서 부팅한 직후)
  const defaults = await page.evaluate(() => {
    const S = __BB_SCOPE__;
    S('metaSave')();
    return {
      meta: JSON.parse(localStorage.getItem('dotlab-subway-meta-v1')),
      opt: JSON.parse(JSON.stringify(S('OPT'))),
      snd: { vol: { ...S('SND').vol }, muted: S('SND').muted },
      lang: S('LANG'),
      cc: S('ccLoad')(),
      ccMax: S('CC_MAX'),
    };
  });
  writeJson(path.join(OUT, 'meta-default.json'), defaults.meta);

  // 2) 진행한 META: 게임 함수로 기록을 바꾼다
  const played = await page.evaluate(() => {
    const S = __BB_SCOPE__, M = S('META');
    S('metaFoe')('thug', false); S('metaFoe')('thug', true); S('metaFoe')('heavy', false);
    S('metaItem')('punch', 2); S('metaItem')('kick', 1);
    S('metaLink')(Object.keys(S('LINKS'))[0] != null ? S('LINKS')[0].id : 'l0');
    S('metaStn')(Object.keys(S('STN'))[0]);
    M.runs = 7; M.best.score = 12345; M.best.stage = 2; M.lines[1] = 1; M.lines[2] = 1;
    M.tot.kills = 321; M.tot.crits = 45; M.tot.merges = 3; M.kits.brawler = 1;
    M.daily['2026-10-08'] = 4200;
    M.hints = { move: 1, bag: 1 }; M.talks = { kane: 2 }; M.flags = { prologueDone: 1 }; M.seenCut = { intro: 1 };
    M.spc = { rush: 3 }; M.cbook = { c1: { n: 2, best: 14 } }; M.cseen = { c2: 1 };
    M.combos = { 'punch>kick': { name: '원투 킥', ids: ['punch', 'kick'], n: 5, best: 9 } };
    M.bossScenes = { boss1: 1 }; M.bonusBest = 880;
    M.tower = { best: 12, bestT: 341, runs: 4, ot: 1, lv: { 0: { f: 12, t: 341 }, 1: { f: 3, t: 99 } }, daily: { '2026-10-08': { f: 5, t: 120 } } };
    M.futureField = { nested: [1, 'two', null, true, 2.5] };   // 웹 다음 버전이 더할 필드 흉내(보존 검사)
    S('metaSave')();
    return localStorage.getItem('dotlab-subway-meta-v1');
  });
  writeJson(path.join(OUT, 'meta-played.json'), JSON.parse(played));

  // 3) 병합: 일부 키만 있는 옛 저장을 넣고 다시 부팅 → META
  const mergeSaved = { v: 1, runs: 3, best: { score: 99 }, tot: { kills: 5, legacyStat: 2 }, foes: { thug: { seen: 1, ko: 0 } }, extraTop: 'keep' };
  const optSaved = { skin: 'navy', vibe: false, shortCut: false, devFoo: 3 };
  const sndSaved = { vol: { music: 0.2, voice: 0.4 }, muted: 1 };
  const ccSaved = ['punch:0', 'kick:1', 'round', 'punch:0', 'punch:1', 'punch:2', 'punch:3', 'kick:0', 'kick:2', 'round'];
  await page.evaluate(([m, o, s, c]) => {
    localStorage.clear();
    localStorage.setItem('dotlab-subway-meta-v1', JSON.stringify(m));
    localStorage.setItem('dotlab-opt', JSON.stringify(o));
    localStorage.setItem('dotlab-snd', JSON.stringify(s));
    localStorage.setItem('dotlab-cc', JSON.stringify(c));
    localStorage.setItem('dotlab-lang', 'en');
  }, [mergeSaved, optSaved, sndSaved, ccSaved]);
  await reload();
  const loaded = await page.evaluate(() => {
    const S = __BB_SCOPE__;
    return {
      meta: JSON.parse(JSON.stringify(S('META'))),
      opt: JSON.parse(JSON.stringify(S('OPT'))),
      snd: { vol: { ...S('SND').vol }, muted: S('SND').muted },
      lang: S('LANG'),
      cc: S('ccLoad')(),
    };
  });
  writeJson(path.join(OUT, 'meta-merge.json'), { saved: mergeSaved, loaded: loaded.meta });
  writeJson(path.join(OUT, 'opt.json'), { default: defaults.opt, saved: optSaved, loaded: loaded.opt });
  writeJson(path.join(OUT, 'snd.json'), { default: defaults.snd, saved: sndSaved, loaded: loaded.snd });
  writeJson(path.join(OUT, 'lang.json'), { default: defaults.lang, raw: loaded.lang });
  writeJson(path.join(OUT, 'cc.json'), { default: defaults.cc, max: defaults.ccMax, saved: ccSaved, loaded: loaded.cc });

  // 4) 판 저장: 실제 판을 시작해 장비를 얻고 고정(pin)을 건 뒤 게임의 saveRun()
  await page.evaluate(() => localStorage.clear());
  await reload();
  const run = await page.evaluate(async () => {
    const S = __BB_SCOPE__, GS = S('GS');
    S('hideTitle')(true);
    S('startRun')({ kit: 'basic', stage: 0, daily: false });
    // 몇 프레임 돌려 영웅 · 판이 자리 잡게
    await new Promise(r => setTimeout(r, 600));
    const ids = Object.keys(S('GITEMS')).filter(id => !S('GITEMS')[id].pro);
    S('gainGear')(ids[1], 2, { k: 'crit', v: 0.15 });
    S('gainGear')(ids[2], 1, null);
    S('addToStash')(ids[3], 3, true, null);
    // 고정: 가방 첫 아이템이 가장 큰 uid 를 가진 아이템을 가리키게(웹 33-bag-ui2 의 pin = 대상 uid)
    const all = [...GS.bag, ...GS.stash];
    if (GS.bag.length) GS.bag[0].pin = Math.max(...all.map(b => b.uid));
    GS.tokens = 17; GS.score = 2345; GS.kills = 12; GS.sp = 0.5; GS.ci = 2;
    S('saveRun')();
    const raw = localStorage.getItem('dotlab-run-v1');
    return { raw, uidCounter: GS.uid, on: GS.on, hero: !!GS.hero };
  });
  if (!run.raw) throw new Error('[saves] saveRun() 이 아무것도 쓰지 않음: ' + JSON.stringify(run));
  writeJson(path.join(OUT, 'run.json'), JSON.parse(run.raw));

  // 5) v!==1 판 저장은 버린다
  const rejected = await page.evaluate((raw) => {
    const S = __BB_SCOPE__, s = JSON.parse(raw); s.v = 2;
    localStorage.setItem('dotlab-run-v1', JSON.stringify(s));
    return { saved: s, loaded: S('loadRunSave')() };
  }, run.raw);
  writeJson(path.join(OUT, 'run-rejected.json'), rejected);

  if (g.errors.length) console.warn('[saves] 페이지 오류:', g.errors.slice(0, 3));
  console.log('[saves] 완료 →', path.relative(ROOT, OUT), '· uid 카운터', run.uidCounter);
} finally {
  await g.close();
}
