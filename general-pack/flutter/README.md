# General 问题反馈 · Flutter 参考代码

一级列表（App View）→ 点分类上弹抽屉表单 → 一次提交。与原型 `UX-Demo` 交互一致。

## 文件
| 文件 | 说明 |
|---|---|
| `lib/general_feedback_sheet.dart` | 主体：`FeedbackEntryPage`（分类列表）+ `showFeedbackSheet`（抽屉表单）+ 校验 / 截图折叠 / 联系方式卡片 / 联系许可 / 感谢页 |
| `lib/feedback_strings.dart` | 7 语言字符串（`kFeedbackUI` + `kCategories`）与访问器 `FeedbackStrings`；由 `i18n.json` 生成 |

## 接入
```dart
import 'lib/general_feedback_sheet.dart';

Navigator.push(context, MaterialPageRoute(builder: (_) => FeedbackEntryPage(
  region: Region.intl,                                   // 跟随账号地区：Region.cn / Region.intl
  account: const FeedbackAccount(email: 'alex@example.com', phone: '138****8862'),
  onSubmit: (draft) => api.submitFeedback(draft.toJson()),          // 先本地队列后异步上传
  onSubmitNewExercise: (na) => api.submitNewExercise(na.toJson()),  // 新增动作申请
)));
```

## 语言
- 跟随系统 `Localizations.localeOf(context)`；未覆盖语言回退英语。
- 支持 7 种：`zh en ja es pt de fr`。要接 gen_l10n / ARB，用 `feedback_strings.dart` 的表转换即可。

## 校验（防空提交）
- 有选项分类（ai / content / connect）：勾选任一子项 **或** 有文字 / 语音才可提交。
- 纯文字分类（otherfb / feature）：需文字 / 语音。
- 新增动作申请：动作名称必填。

## 待接入（TODO 钩子）
1. **录音**：`_micButton` 目前为演示开关。接 `record` 包（见交付包《Flutter Code 录音上传参考.dart》/《完整可跑Demo.dart》），停止 / 删除后调用 `setState` 刷新 `_hasVoice` 以更新提交可用态。60 秒上限、本地存音频、异步上传。
2. **截图**：`_addShotBox` / 展开逻辑接系统相册 / 截图选择器，最多 3 张。
3. **企业微信二维码**：`Icons.qr_code_2` 占位，替换为实际客服二维码图。
4. **提交**：`onSubmit` 内做「先本地队列（Hive）→ 异步上传（Dio）」，带 `idempotencyKey`。

## 设计 token
颜色 / 圆角与原型一致（`_ink / _line / _soft / _lime` 等）。抽屉用 `showModalBottomSheet(isScrollControlled: true, showDragHandle: true)` + `MediaQuery.viewInsetsOf` 键盘避让。
