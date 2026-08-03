// 报错按钮 · 从点击开始的完整流程 + 状态机（Flutter 伪代码 / 可跑骨架）
// ============================================================
// 只依赖 flutter/material + services。报错表单用 showModalBottomSheet；
// 上传通过注入的 onSubmit 回调（内部接「先存后传」uploader，见 Flutter Code 完整可跑Demo.dart）。
//
// 按钮状态机：
//   idle(默认) → [点击] → 打开表单 → [提交] → submitting → reported(已反馈)
//   reported → [再次点击] → 重开表单（允许再报）
//   刚提交后 <冷却窗口 内点击 → 只提示"刚刚已提交"，不重开
//   enabled=false → disabled(置灰不可点)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ---------- 数据 ----------
class ReportDraft {
  final String targetId;      // 计划ID / 动作ID / 结果ID —— 后端按 (targetId+user) 归并
  final String source;        // 'ai_plan' | 'in_class' | 'general' ...
  final List<String> tags;    // 勾选的问题分类 key
  final bool isFeature;       // true=「建议新功能」(与问题类互斥，走产品需求池)
  final String text;          // 补充说明
  final String? audioPath;    // 语音（本地路径）
  const ReportDraft({
    required this.targetId, required this.source, this.tags = const [],
    this.isFeature = false, this.text = '', this.audioPath,
  });
}

// ---------- 按钮状态 ----------
enum ReportBtnState { idle, submitting, reported, disabled }

class ReportEntryButton extends StatefulWidget {
  final String targetId;
  final String source;
  /// 提交回调：内部「先写本地队列(必成功) → 异步上传」，返回是否最终上传成功。
  final Future<bool> Function(ReportDraft draft) onSubmit;
  final bool enabled;         // 生成未完成 / 离线队列满 等 → false
  const ReportEntryButton({
    super.key,
    required this.targetId,
    required this.source,
    required this.onSubmit,
    this.enabled = true,
  });
  @override
  State<ReportEntryButton> createState() => _ReportEntryButtonState();
}

class _ReportEntryButtonState extends State<ReportEntryButton> {
  ReportBtnState _state = ReportBtnState.idle;
  bool _pressed = false;
  DateTime? _lastSubmit;
  static const _cooldown = Duration(seconds: 3);

  bool get _reported => _state == ReportBtnState.reported;

  // ===== 从点击开始 =====
  Future<void> _onTap() async {
    if (!widget.enabled || _state == ReportBtnState.submitting) return;

    // 冷却：刚提交完的极短窗口内再点 → 只提示，不重开（防手滑连点刷单）
    if (_lastSubmit != null && DateTime.now().difference(_lastSubmit!) < _cooldown) {
      _toast('刚刚已提交，请稍后再报');
      return;
    }

    HapticFeedback.selectionClick();

    // 1) 打开报错表单（bottom sheet）→ 拿回用户填写；null = 取消
    final draft = await showReportSheet(
      context,
      targetId: widget.targetId,
      source: widget.source,
      alreadyReported: _reported, // 已反馈过 → 表单里可提示"再补充一条"
    );
    if (draft == null) return; // 取消，状态不变

    // 2) 先本地入队（一定成功）→ 立即切「已反馈」，上传走异步
    setState(() => _state = ReportBtnState.submitting);
    HapticFeedback.mediumImpact();

    bool ok;
    try {
      ok = await widget.onSubmit(draft); // 内部：写队列 + 触发上传
    } catch (_) {
      ok = false; // 队列写失败极少；即便失败也保留本地
    }
    if (!mounted) return;

    _lastSubmit = DateTime.now();
    setState(() => _state = ReportBtnState.reported); // 入队成功即视为「已反馈」
    _toast(ok ? '收到，谢谢反馈！' : '已存本地，联网后自动提交');
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(milliseconds: 1800)),
    );
  }

  // ===== 状态 → 外观 =====
  @override
  Widget build(BuildContext context) {
    final s = widget.enabled ? _state : ReportBtnState.disabled;
    final tappable = widget.enabled && _state != ReportBtnState.submitting;

    return GestureDetector(
      onTapDown: tappable ? (_) => setState(() => _pressed = true) : null,
      onTapUp: tappable ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: tappable ? () => setState(() => _pressed = false) : null,
      onTap: tappable ? _onTap : null,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1,
        duration: const Duration(milliseconds: 90),
        child: _chip(s),
      ),
    );
  }

  Widget _chip(ReportBtnState s) {
    late final IconData icon;
    late final String label;
    late final Color bg, fg;
    switch (s) {
      case ReportBtnState.reported: // 已反馈（确认态，仍可点再报）
        icon = Icons.check_rounded; label = '已反馈';
        bg = const Color(0xFFE8F3EA); fg = const Color(0xFF2E7D4F);
        break;
      case ReportBtnState.disabled: // 置灰不可点
        icon = Icons.chat_bubble_outline_rounded; label = '报错';
        bg = const Color(0xFFF2F2F4); fg = const Color(0xFFB8B8BE);
        break;
      case ReportBtnState.idle:
      case ReportBtnState.submitting: // 默认（更醒目：实心浅底 + 深色）
        icon = Icons.chat_bubble_outline_rounded; label = '报错';
        bg = const Color(0xFFE9E9EC); fg = const Color(0xFF33333A);
        break;
    }
    final busy = s == ReportBtnState.submitting;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        busy
          ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: fg))
          : Icon(icon, size: 18, color: fg),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: fg)),
      ]),
    );
  }
}

// ============================================================
// 报错表单（bottom sheet）：4 类问题 + 「建议新功能」(互斥) + 补充说明
// 返回 ReportDraft（提交）或 null（取消）
// ============================================================
Future<ReportDraft?> showReportSheet(
  BuildContext context, {
  required String targetId,
  required String source,
  bool alreadyReported = false,
}) {
  return showModalBottomSheet<ReportDraft>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _ReportSheet(targetId: targetId, source: source),
  );
}

// 选项定义：key + 文案 + 是否「建议新功能」
class _Opt { final String key, title, sub; final bool feature;
  const _Opt(this.key, this.title, [this.sub = '', this.feature = false]); }
const _kOpts = <_Opt>[
  _Opt('incomplete', '生成没完成'),
  _Opt('slow', '生成速度太慢'),
  _Opt('wrong_exercises', '动作选得不对', '目标/部位/器械'),
  _Opt('wrong_programming', '编排不合适', '顺序/组数/次数/负重'),
  _Opt('feature', '建议新功能', '希望增加的功能', true),
];

class _ReportSheet extends StatefulWidget {
  final String targetId, source;
  const _ReportSheet({required this.targetId, required this.source});
  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  final _sel = <String>{};
  final _ctrl = TextEditingController();
  String? _audioPath; // 录音结果（接 record 包，此处略）

  bool get _isFeature => _sel.contains('feature');

  void _toggle(_Opt o) {
    setState(() {
      if (_sel.contains(o.key)) { _sel.remove(o.key); return; }
      // 「建议新功能」与问题类互斥：二选一
      if (o.feature) { _sel..clear()..add(o.key); }
      else { _sel.remove('feature'); _sel.add(o.key); }
    });
  }

  void _submit() {
    Navigator.of(context).pop(ReportDraft(
      targetId: widget.targetId,
      source: widget.source,
      tags: _sel.where((k) => k != 'feature').toList(),
      isFeature: _isFeature,
      text: _ctrl.text.trim(),
      audioPath: _audioPath,
    ));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 18, right: 18, top: 4,
        bottom: 16 + MediaQuery.viewInsetsOf(context).bottom, // 键盘避让
      ),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('结果哪里有问题？', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600)),
          const SizedBox(height: 3),
          const Text('可多选；不选也能直接提交', style: TextStyle(fontSize: 13, color: Color(0xFF7C7C83))),
          const SizedBox(height: 8),
          for (final o in _kOpts) ...[
            if (o.feature) const Divider(height: 22),
            InkWell(
              onTap: () => _toggle(o),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(children: [
                  _CheckBox(on: _sel.contains(o.key)),
                  const SizedBox(width: 11),
                  Flexible(child: RichText(overflow: TextOverflow.ellipsis, text: TextSpan(
                    style: const TextStyle(fontSize: 16, color: Color(0xFF111214)),
                    children: [
                      TextSpan(text: o.title),
                      if (o.sub.isNotEmpty)
                        TextSpan(text: '（${o.sub}）', style: const TextStyle(fontSize: 13, color: Color(0xFF7C7C83))),
                    ],
                  ))),
                ]),
              ),
            ),
          ],
          const SizedBox(height: 8),
          // 补充说明 + 语音（录音按钮略；接 record 包见另一份参考）
          TextField(
            controller: _ctrl, maxLength: 200, maxLines: null,
            decoration: const InputDecoration(hintText: '说说这个结果的具体问题…', border: OutlineInputBorder()),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Row(children: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
            const SizedBox(width: 8),
            Expanded(child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF141414),
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
              ),
              onPressed: _submit,
              child: Text(_sel.isEmpty ? '直接提交' : '提交'),
            )),
          ]),
        ]),
      ),
    );
  }
}

class _CheckBox extends StatelessWidget {
  final bool on;
  const _CheckBox({required this.on});
  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 120), width: 22, height: 22,
    decoration: BoxDecoration(
      color: on ? const Color(0xFF141414) : Colors.transparent,
      border: Border.all(color: on ? const Color(0xFF141414) : const Color(0xFFC9C9CE), width: 2),
      borderRadius: BorderRadius.circular(7),
    ),
    child: on ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
  );
}

// ============================================================
// 用法：
//   ReportEntryButton(
//     targetId: plan.id, source: 'ai_plan', enabled: plan.isReady,
//     onSubmit: (draft) => reportUploader.submit(draft), // 先存后传，返回是否上传成功
//   )
//
// 后端配套（写进 PRD）：
//   · 归并：同 (targetId + user) 的多次报错 → 合并为一条工单的「多次补充」，不新开卡。
//   · 路由：isFeature=true → 产品需求池；否则 → Bug/反馈工单。
// ============================================================
