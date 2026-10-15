/* BAG BOSS 네이티브 브리지 · 웹 쪽 (v1)
 *
 * 네이티브 셸이 WKUserScript로 documentStart(게임 스크립트보다 먼저)에 주입한다.
 * 게임 HTML(web/index.html)은 한 글자도 고치지 않는 것이 1단계 원칙이다.
 * 이 파일이 하는 일:
 *   1) 저장 미러   — localStorage 'dotlab*' 키를 네이티브 파일에 백업하고, 웹 저장소가 비면 복원
 *   2) 햅틱       — navigator.vibrate(게임의 buzz())를 네이티브 햅틱으로 연결 (iOS WebKit엔 vibrate가 없다)
 *   3) 프레임 측정 — 1초마다 FPS · 프레임 시간 p50/p95 · 긴 프레임 수를 네이티브로 보낸다
 *   4) 수명주기    — 앱이 백그라운드로 가면 일시정지 · 저장 · 플러시, 돌아오면 오디오 재개
 *   5) 오류 보고   — window error / unhandledrejection을 네이티브 로그로
 *   6) WebGL 문맥 잃음 — 알리면 네이티브가 저장을 밀어 넣고 페이지를 다시 연다(게임은 이어 하기로 복귀)
 * 명세: docs/03-브리지-명세.md
 */
(function () {
  'use strict';
  if (window.NativeBridge) return;

  var MH = window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.bagboss;
  var CFG = Object.assign(
    { debug: false, perf: true, haptics: true, saveMirror: true, keyPrefix: 'dotlab', flushMs: 400 },
    window.__BAGBOSS_CFG__ || {}
  );

  // ---------------------------------------------------------------- 전송
  // 핸들러가 reply 형식(WKScriptMessageHandlerWithReply)이면 postMessage가 Promise를 돌려준다.
  function send(type, payload) {
    if (!MH) return Promise.resolve(null);
    try {
      var r = MH.postMessage({ v: 1, type: type, payload: payload == null ? null : payload });
      return r && typeof r.then === 'function' ? r.catch(function () { return null; }) : Promise.resolve(null);
    } catch (e) {
      return Promise.resolve(null);
    }
  }

  // 게임 코드는 거의 전부 즉시 실행 함수 안에 있어 전역(GS · SND …)을 밖에서 읽을 수 없다.
  // 바깥으로 열린 창구는 개발 훅 window.__dotlab 하나 → 1단계는 이것만 쓴다(1.5단계에서 정식 호스트 API로 교체: docs/02).
  function peek(fn, fallback) { try { return fn(); } catch (e) { return fallback; } }
  function L() { return window.__dotlab || null; }

  // ---------------------------------------------------------------- 1) 저장 미러
  var LS = peek(function () { return window.localStorage; }, null);
  var restored = [];
  var snap = window.__BAGBOSS_SAVE__ || null;           // 네이티브가 앞서 주입한 { key: string }
  if (LS && snap && CFG.saveMirror) {
    for (var k in snap) {
      if (!Object.prototype.hasOwnProperty.call(snap, k) || k.indexOf(CFG.keyPrefix) !== 0) continue;
      try {
        if (LS.getItem(k) == null) { LS.setItem(k, String(snap[k])); restored.push(k); }
      } catch (e) { /* 용량 초과 등: 무시 */ }
    }
  }

  var pending = {}, pendingN = 0, flushT = 0;
  function queue(key, value) {                          // value === null → 삭제
    if (!(key in pending)) pendingN++;
    pending[key] = value;
    if (!flushT) flushT = setTimeout(flush, CFG.flushMs);
  }
  function flush() {
    if (flushT) { clearTimeout(flushT); flushT = 0; }
    if (!pendingN) return Promise.resolve(null);
    var entries = pending; pending = {}; pendingN = 0;
    return send('save.put', { entries: entries });
  }
  if (LS && CFG.saveMirror && MH) {
    var SP = Storage.prototype, oSet = SP.setItem, oRem = SP.removeItem;
    SP.setItem = function (key, value) {
      var r = oSet.apply(this, arguments);              // 실패(용량 초과)하면 여기서 예외 → 미러도 안 함
      if (this === LS && typeof key === 'string' && key.indexOf(CFG.keyPrefix) === 0) queue(key, String(value));
      return r;
    };
    SP.removeItem = function (key) {
      var r = oRem.apply(this, arguments);
      if (this === LS && typeof key === 'string' && key.indexOf(CFG.keyPrefix) === 0) queue(key, null);
      return r;
    };
  }

  // ---------------------------------------------------------------- 2) 햅틱
  // 게임: const buzz=p=>{ if(OPT.vibe!==false && navigator.vibrate && matchMedia('(pointer:coarse)').matches) navigator.vibrate(p) }
  // 패턴(ms) 그대로 넘기고, 세기 매핑은 네이티브(Haptics.swift)가 한다.
  function vibrate(p) {
    var seq = Array.isArray(p) ? p.slice(0, 16) : [p];
    seq = seq.map(function (n) { n = Number(n); return isFinite(n) && n > 0 ? Math.min(1000, Math.round(n)) : 0; });
    if (!seq.length || (seq.length === 1 && seq[0] === 0)) return true;
    send('haptic', { pattern: seq });
    return true;
  }
  if (CFG.haptics && MH) {
    try { Object.defineProperty(Navigator.prototype, 'vibrate', { value: vibrate, configurable: true, writable: true }); }
    catch (e) { try { navigator.vibrate = vibrate; } catch (e2) {} }
  }

  // ---------------------------------------------------------------- 3) 프레임 측정
  var perf = { frames: [], last: 0, t0: 0, long: 0, worst: 0 };
  function sceneLabel() {
    return peek(function () {
      var G = L() && L().GS;
      if (!G) return 'boot';
      if (G.tower) return 'tower:' + (G.tower.floor || 0);
      if (G.demo) return 'dojo';
      if (!G.on) return 'title';
      return (G.state || 'run') + ':' + (G.stageIdx || 0) + '.' + (G.ci || 0);
    }, '');
  }
  function stageCanvas() { return document.querySelector('#stage canvas') || document.querySelector('canvas'); }
  function report(now) {
    var f = perf.frames, n = f.length, el = now - perf.t0;
    if (n > 2 && el > 0) {
      var s = f.slice().sort(function (a, b) { return a - b; });
      var cv = stageCanvas();
      send('perf.sample', {
        fps: Math.round((n * 1000 / el) * 10) / 10,
        p50: Math.round(s[Math.floor(n * 0.5)] * 10) / 10,
        p95: Math.round(s[Math.min(n - 1, Math.floor(n * 0.95))] * 10) / 10,
        max: Math.round(perf.worst * 10) / 10,
        long: perf.long,                                 // 50ms 넘은 프레임 수
        scene: sceneLabel(),
        px: cv ? cv.width + 'x' + cv.height : ''
      });
    }
    perf.frames = []; perf.t0 = now; perf.long = 0; perf.worst = 0;
  }
  function rafTick(now) {
    if (perf.last) {
      var d = now - perf.last;
      if (d > 1000) { perf.frames = []; perf.t0 = now; perf.long = 0; perf.worst = 0; }   // 백그라운드 복귀: 버린다
      else { perf.frames.push(d); if (d > 50) perf.long++; if (d > perf.worst) perf.worst = d; }
    }
    perf.last = now;
    if (!perf.t0) perf.t0 = now;
    if (now - perf.t0 >= 1000) report(now);
    requestAnimationFrame(rafTick);
  }
  if (CFG.perf && MH) requestAnimationFrame(rafTick);

  // ---------------------------------------------------------------- 4) 수명주기 (네이티브 → 웹)
  function onPause() {
    // 싸우는 중이면 메뉴를 열어 멈춘다(메뉴가 곧 일시정지 화면). 매점 · 정리 · 결과 화면은 건드리지 않는다.
    var D = L();
    if (D) {
      peek(function () {
        var G = D.GS, ov = document.getElementById('gOverlay');
        if (G.on && G.state === 'fight' && !G.demo && !D.isPaused() && ov && ov.hidden) D.openMenu('run');
      });
      peek(function () { D.saveRun(); });                // 칸 이어 하기 저장(가드는 게임 쪽에 있다)
      peek(function () { LS.setItem('dotlab-subway-meta-v1', JSON.stringify(D.meta())); });   // = 게임의 metaSave()
    }
    return flush();
  }
  function onResume() {
    peek(function () { var S = L().snd(); if (S.ctx && S.ctx.state !== 'running') S.ctx.resume(); });
    perf.last = 0;
    return Promise.resolve(true);
  }
  function fromNative(msg) {
    var t = msg && msg.type;
    if (t === 'app.pause') return onPause();
    if (t === 'app.resume') return onResume();
    if (t === 'save.flush') return flush();
    if (t === 'perf.reset') { perf.frames = []; perf.t0 = 0; perf.last = 0; return Promise.resolve(true); }
    if (t === 'memory.warning') { send('log', { level: 'warn', msg: 'memory warning', scene: sceneLabel() }); return Promise.resolve(true); }
    return Promise.resolve(null);
  }

  // ---------------------------------------------------------------- 5) 오류 보고
  if (MH) {
    window.addEventListener('error', function (e) {
      send('log', { level: 'error', msg: String(e.message || e), src: (e.filename || '') + ':' + (e.lineno || 0) + ':' + (e.colno || 0),
                    stack: e.error && e.error.stack ? String(e.error.stack).slice(0, 2000) : '' });
    });
    window.addEventListener('unhandledrejection', function (e) {
      var r = e.reason;
      send('log', { level: 'error', msg: 'unhandledrejection: ' + String(r && r.message || r), stack: r && r.stack ? String(r.stack).slice(0, 2000) : '' });
    });
    if (CFG.debug) {
      ['warn', 'error'].forEach(function (lv) {
        var o = console[lv];
        console[lv] = function () {
          try { send('log', { level: lv, msg: Array.prototype.map.call(arguments, String).join(' ').slice(0, 2000) }); } catch (e) {}
          return o.apply(console, arguments);
        };
      });
    }
  }

  // ---------------------------------------------------------------- 시작 알림 · 글꼴 예열
  function ready() {
    // 만화 효과음 글꼴: iOS엔 Impact가 없어 app/fonts.css가 Anton을 'Impact' 이름으로 묶는다. 캔버스용으로 미리 불러 둔다.
    peek(function () { document.fonts.load('900 40px Impact'); });
    var cv = stageCanvas();
    // WebGL 문맥 잃음(백그라운드 메모리 회수 · GPU 리셋): 게임은 자원을 다시 만들지 못한다 → 네이티브가 저장 후 다시 연다.
    if (cv && MH) cv.addEventListener('webglcontextlost', function () {
      flush();
      send('gl.lost', { scene: sceneLabel(), px: cv.width + 'x' + cv.height });
    });
    send('app.ready', {
      restored: restored, dpr: window.devicePixelRatio || 1, w: innerWidth, h: innerHeight,
      lang: peek(function () { return L().lang(); }, '') || peek(function () { return localStorage.getItem('dotlab-lang'); }, ''), canvas: cv ? cv.width + 'x' + cv.height : '',
      webgl2: typeof WebGL2RenderingContext !== 'undefined'
    });
  }
  if (document.readyState === 'complete') setTimeout(ready, 0);
  else window.addEventListener('load', function () { setTimeout(ready, 0); });

  window.NativeBridge = {
    version: 1,
    native: !!MH,
    send: send,
    flush: flush,
    haptic: function (p) { return vibrate(p == null ? 20 : p); },
    _native: fromNative,
    _restored: restored
  };
})();
