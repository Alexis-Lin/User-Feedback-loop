# User Feedback Loop

课中「报错反馈」功能的产品设计与可交互原型。用户在上课的动作详情页快速上报 AI 识别 / 课程内容问题，数据结构化流转到后端并同步 AI 团队与课程研发看板。

## 文件

- [`PRD 课中报错反馈.md`](<PRD 课中报错反馈.md>) — 产品需求文档（交互逻辑、状态设计、后端流转、交付物）。
- [`UX Demo 课中报错反馈.html`](<UX Demo 课中报错反馈.html>) — 单文件可交互原型，零依赖、可离线打开。支持 中/英、课中/课外 切换，底部含「状态演示」面板（错误 / 空 / 阻断 / 极限）。
- [`Dev Notes 原型实现与录音前后端建议.md`](<Dev Notes 原型实现与录音前后端建议.md>) — Part A 原型实现说明（供照着接真机）+ Part B 录音与前后端同步工程建议（接口契约、本地队列、ASR、分工与节奏）。
- [`Flutter Code 录音上传参考.dart`](<Flutter Code 录音上传参考.dart>) — 录音 + 本地离线保存 + 异步上传的 Flutter 参考代码（§6 含弹窗与微动效最佳实践）。
- [`Flutter Code 弹窗动效可运行示例.dart`](<Flutter Code 弹窗动效可运行示例.dart>) — 可直接 `flutter run` 的单文件示例，零第三方依赖：sheet 一二级切换、PopScope 防误关、键盘避让、录音三态、Toast、触感、reduce-motion。

## 快速预览

直接用浏览器打开 `UX Demo 课中报错反馈.html` 即可，无需运行环境。
