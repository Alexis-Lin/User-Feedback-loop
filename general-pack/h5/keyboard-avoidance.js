/*!
 * ATOM / BodyPark — 反馈抽屉 · 键盘避让（生产骨架，零依赖）
 * ------------------------------------------------------------------
 * 目标：软键盘弹出时，底部抽屉自动上移到键盘上方，焦点输入框保持可见。
 *
 * 原理：
 *   1) 首选 window.visualViewport 拿"真实键盘高度"（iOS WKWebView / 现代
 *      Android WebView / 鸿蒙 ArkWeb 均为 Chromium 系，支持）。把高度写进
 *      CSS 变量 --kbh，抽屉靠 CSS 上移到键盘上方（Strategy A：lift）。
 *   2) visualViewport 不可用 / 拿不到高度时，退化为"抽屉升满屏"
 *      （Strategy B：full），交给浏览器把焦点输入框滚进可见区。
 *   3) 老 Android（windowSoftInputMode=adjustResize）会直接缩 window，
 *      fixed 抽屉天然就在键盘上方，这里只补一次 scrollIntoView。
 *
 * 用法：
 *   const ka = attachKeyboardAvoidance({
 *     root:      document.querySelector('.screen'), // 加/去 kbopen 的容器
 *     sheet:     document.querySelector('#sheet'),  // 抽屉本体
 *     scrollHost:document.querySelector('#sbody'),  // 抽屉内滚动区
 *     topGap:    44,                                // 抽屉顶部留白(状态栏/刘海)
 *     onChange:  (open, kb) => {}                   // 可选：状态回调
 *   });
 *   // 关闭抽屉时： ka.reset();     不再需要时： ka.destroy();
 *
 * 配套 CSS 见本文件末尾注释（或 keyboard-avoidance.css）。
 */
(function (global) {
  'use strict';

  var KB_THRESHOLD = 120; // 大于此高度才算"键盘弹出"，滤掉地址栏收合等抖动

  function attachKeyboardAvoidance(opts) {
    var root = opts.root;
    var sheet = opts.sheet;
    var scrollHost = opts.scrollHost || sheet;
    var topGap = opts.topGap != null ? opts.topGap : 44;
    var onChange = opts.onChange || function () {};
    var vv = global.visualViewport || null;

    var isOpen = false;
    var lastKb = 0;
    var baseInnerH = global.innerHeight; // 用于 adjustResize 检测

    // ---- 读取键盘高度（visualViewport） ----
    function kbHeight() {
      if (!vv) return 0;
      // 键盘遮住的高度 = 布局视口高 - 可视视口高 - 可视视口顶偏移
      var h = global.innerHeight - vv.height - vv.offsetTop;
      return h > 0 ? Math.round(h) : 0;
    }

    // ---- 应用/清除避让 ----
    function setState(kb) {
      var open = kb > KB_THRESHOLD;
      if (open) {
        root.style.setProperty('--kbh', kb + 'px');
        root.classList.add('kbopen');
        root.classList.remove('kbfull');   // 有精确高度：走 lift
      } else {
        root.classList.remove('kbopen');
        root.classList.remove('kbfull');
        root.style.removeProperty('--kbh');
      }
      if (open !== isOpen || kb !== lastKb) {
        isOpen = open; lastKb = kb;
        if (open) scrollActiveIntoView();
        onChange(open, kb);
      }
    }

    // ---- 焦点输入框滚进键盘上方（在滚动区内居中） ----
    function scrollActiveIntoView() {
      var el = document.activeElement;
      if (!el || !sheet.contains(el)) return;
      // 等布局稳定后再滚
      requestAnimationFrame(function () {
        setTimeout(function () {
          if (el.scrollIntoView) el.scrollIntoView({ block: 'center', behavior: 'smooth' });
        }, 60);
      });
    }

    // ---- 降级：拿不到精确高度时，抽屉升满屏 ----
    function fullMode(on) {
      if (on) { root.classList.add('kbopen', 'kbfull'); isOpen = true; scrollActiveIntoView(); }
      else { root.classList.remove('kbopen', 'kbfull'); isOpen = false; }
      onChange(on, 0);
    }

    // ---- 事件 ----
    function onVV() { setState(kbHeight()); }

    function onFocusIn(e) {
      if (!sheet.contains(e.target)) return;
      if (!isFormEl(e.target)) return;
      if (vv) {
        // visualViewport 会随后触发 resize；先滚一次减少空窗
        scrollActiveIntoView();
      } else {
        // 无 visualViewport：直接升满屏
        fullMode(true);
      }
    }
    function onFocusOut(e) {
      if (!sheet.contains(e.target)) return;
      setTimeout(function () {
        var a = document.activeElement;
        if (!(a && sheet.contains(a) && isFormEl(a))) {
          if (vv) setState(kbHeight()); else fullMode(false);
        }
      }, 80);
    }
    // 老 Android adjustResize：window 自身缩 → fixed 抽屉已在键盘上方，补滚一次
    function onWinResize() {
      if (vv) return; // 有 vv 就不靠这个
      if (global.innerHeight < baseInnerH - KB_THRESHOLD) scrollActiveIntoView();
      else baseInnerH = Math.max(baseInnerH, global.innerHeight);
    }

    if (vv) {
      vv.addEventListener('resize', onVV);
      vv.addEventListener('scroll', onVV);
    }
    document.addEventListener('focusin', onFocusIn);
    document.addEventListener('focusout', onFocusOut);
    global.addEventListener('resize', onWinResize);

    return {
      // 抽屉关闭时调用，强制复位
      reset: function () {
        root.classList.remove('kbopen', 'kbfull');
        root.style.removeProperty('--kbh');
        isOpen = false; lastKb = 0;
        var a = document.activeElement;
        if (a && a.blur && sheet.contains(a)) a.blur();
      },
      // 卸载
      destroy: function () {
        if (vv) { vv.removeEventListener('resize', onVV); vv.removeEventListener('scroll', onVV); }
        document.removeEventListener('focusin', onFocusIn);
        document.removeEventListener('focusout', onFocusOut);
        global.removeEventListener('resize', onWinResize);
      }
    };
  }

  function isFormEl(el) {
    var t = el && el.tagName;
    return t === 'INPUT' || t === 'TEXTAREA' || (el && el.isContentEditable);
  }

  global.attachKeyboardAvoidance = attachKeyboardAvoidance;
})(window);

/* ================================================================
 * 配套 CSS（放进你的样式表；--kbh 由本脚本写入）
 * ----------------------------------------------------------------
 * // 抽屉平时贴底
 * .sheet{ position:absolute; left:0; right:0; bottom:0; max-height:90%;
 *   display:flex; flex-direction:column;
 *   transition: bottom .26s cubic-bezier(.32,.72,0,1),
 *               max-height .26s cubic-bezier(.32,.72,0,1),
 *               border-radius .2s; }
 * .sbody{ flex:1; overflow-y:auto; -webkit-overflow-scrolling:touch; }
 *
 * // Strategy A（有精确键盘高度）：抽屉上移到键盘上方
 * .kbopen .sheet{
 *   bottom: var(--kbh, 0px);
 *   max-height: calc(100% - var(--kbh, 0px) - 44px);  // 44 = topGap
 * }
 *
 * // Strategy B（降级）：抽屉升满屏，交给浏览器滚动焦点
 * .kbopen.kbfull .sheet{
 *   bottom:0; top:0; max-height:100%; border-radius:0;
 * }
 *
 * 提示：
 *  · <meta name="viewport" content="width=device-width, initial-scale=1,
 *    viewport-fit=cover, interactive-widget=resizes-content"> 让键盘更可控。
 *  · 输入框字号 ≥16px，避免 iOS 聚焦缩放。
 *  · 抽屉打开时 body{overflow:hidden} 锁背景滚动；关闭时恢复。
 * ================================================================ */
