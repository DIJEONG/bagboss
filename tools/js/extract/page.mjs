// 추출 공통: web/src 조각을 이어 붙이되, 즉시 실행 함수가 닫히기 직전에 '닫힌 범위 창구' 한 줄을 넣은
// 임시 HTML을 만들어 헤드리스 Chromium에서 띄운다. 원본(web/index.html · web/src)은 건드리지 않는다.
//
//   const pg = await openGame();            // { page, close }
//   await pg.page.evaluate(() => __BB_SCOPE__('GITEMS'))   // 게임 지역 변수 그대로 읽기(직접 eval)
//
// 왜 이렇게: 게임 코드는 한 함수 몸통 안에 있어 밖에서 지역 변수를 못 읽는다. 다른 조각이 실행 중에
// 늘리는 표(ETYPES · POSES · JW_SEQ …)까지 '다 돈 뒤의 값'을 얻으려면 실제로 실행해 보는 것이 가장 정확하다.
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import crypto from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { chromium } from 'playwright';

export const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..', '..');
export const SRC = path.join(ROOT, 'web', 'src');
// 생성물 위치(BBContent 패키지 리소스) — 직접 고치지 않는다
export const GEN = path.join(ROOT, 'native', 'Sources', 'BBContent', 'Resources', 'Generated');

const IIFE_END = '\n})();\n';
// 직접 eval 이라 닫힌 범위의 let/const/function 을 모두 본다. 'use strict' 에서도 읽기는 된다.
const HOOK = '\n;window.__BB_SCOPE__ = (expr) => eval(expr);\n';

export function instrumentedHtml() {
  const order = fs.readFileSync(path.join(SRC, 'ORDER.txt'), 'utf8').split(/\s+/).filter(Boolean);
  const parts = order.map(n => fs.readFileSync(path.join(SRC, n), 'utf8'));
  const original = parts.join('');
  const last = order.findIndex(n => n === '50-mobile-dev.js');
  const body = parts[last];
  const at = body.lastIndexOf(IIFE_END);
  if (at < 0) throw new Error('[extract] 50-mobile-dev.js 끝에서 즉시 실행 함수 닫힘을 못 찾음');
  parts[last] = body.slice(0, at) + HOOK + body.slice(at);
  return { html: parts.join(''), sourceSha16: crypto.createHash('sha256').update(original).digest('hex').slice(0, 16) };
}

export async function openGame({ log = false, run = false, viewport = { width: 1280, height: 800 } } = {}) {
  const { html, sourceSha16 } = instrumentedHtml();
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'bb-extract-'));
  const file = path.join(dir, 'index.html');
  fs.writeFileSync(file, html);
  const browser = await chromium.launch({ args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
  const page = await browser.newPage({ viewport });
  await page.route(/^https?:/, r => r.abort());       // 외부 글꼴 링크 등은 막는다(완전 오프라인)
  // 부팅 직후 값을 읽기 위해 프레임 루프 · 주기 타이머를 멈춘다(부팅 코드는 그대로 돈다).
  // 게임을 실제로 돌려야 하는 픽스처는 openGame({ run: true }) 로 연다.
  if (!run) await page.addInitScript(() => { window.requestAnimationFrame = () => 0; window.setInterval = () => 0; });
  // run 모드: 루프는 돌되 window.__bbHold = true 로 붙잡을 수 있다(다음 프레임 콜백을 __bbHeld 에 맡아 둠)
  else await page.addInitScript(() => { const raf = window.requestAnimationFrame.bind(window);
    window.requestAnimationFrame = cb => window.__bbHold ? (window.__bbHeld = cb, 0) : raf(cb); });
  const errors = [];
  page.on('pageerror', e => errors.push(String(e)));
  if (log) page.on('console', m => console.log('[page]', m.text()));
  await page.goto('file://' + file);
  await page.waitForFunction(() => typeof window.__BB_SCOPE__ === 'function', null, { timeout: 60000 });
  if (errors.length) console.warn('[extract] 페이지 오류:', errors.slice(0, 3));
  return {
    page, sourceSha16, errors,
    async close() { await browser.close(); fs.rmSync(dir, { recursive: true, force: true }); },
  };
}

// 결정적 JSON(키 정렬 없이 원래 순서 유지 · 들여쓰기 1) — diff 리뷰용
export function writeJson(file, obj) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, JSON.stringify(obj, null, 1) + '\n');
}
