# H5 键盘避让骨架

`keyboard-avoidance.js` —— 生产可用、零依赖。软键盘弹出时，底部抽屉自动上移到键盘上方，焦点输入框保持可见。

## 接入 3 步
1. 引入脚本：`<script src="keyboard-avoidance.js"></script>`
2. 抄文件末尾注释里的 **配套 CSS**（`.sheet` 过渡 + `.kbopen .sheet` 上移 + `.kbopen.kbfull .sheet` 升满屏降级）。
3. 打开抽屉后 attach、关闭时 reset：
```js
const ka = attachKeyboardAvoidance({
  root:       document.querySelector('.screen'), // 加/去 kbopen 的容器
  sheet:      document.querySelector('#sheet'),  // 抽屉本体
  scrollHost: document.querySelector('#sbody'),  // 抽屉内滚动区
  topGap:     44,                                // 顶部留白(状态栏/刘海)
});
// 关闭抽屉： ka.reset();      卸载： ka.destroy();
```

## 它做了什么
- **首选 `visualViewport`** 拿真实键盘高度 → 写入 CSS 变量 `--kbh` → 抽屉 CSS 上移（Strategy A）。三端（iOS WKWebView / Android WebView / 鸿蒙 ArkWeb，均 Chromium 系）都支持。
- **降级**：拿不到高度时 `.kbfull` 抽屉升满屏，交给浏览器把焦点输入框滚进可见区（Strategy B）。
- **老 Android `adjustResize`**：window 自身缩，fixed 抽屉天然在键盘上方，补一次 `scrollIntoView`。
- 键盘高度**动态**（不同机型不同），不写死。

## 真机验收清单
- iOS Safari / WKWebView：聚焦不缩放（输入框字号 ≥16px）、抽屉上移无遮挡、收起复位。
- Android WebView（高/低端各一台）：`visualViewport` 高度准确；必要时对比 `adjustResize`。
- **鸿蒙 ArkWeb**：重点回归；若某机型 `visualViewport` 抖，会自动走 `.kbfull` 升满屏兜底。
- `<meta name="viewport" content="…,viewport-fit=cover,interactive-widget=resizes-content">`。

> 交互演示见 `../UX-Demo …html`（用仿真键盘演示同一套避让逻辑）。
