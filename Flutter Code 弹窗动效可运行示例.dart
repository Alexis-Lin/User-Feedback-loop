// 课中报错反馈 · 弹窗与微动效「可直接运行」示例
// ------------------------------------------------------------
// 零第三方依赖：只用 flutter/material + flutter/services（录音用 Timer 模拟）。
// 直接把本文件当 lib/main.dart 运行：flutter run
//
// 版本要求（用到的较新 API）：
//   · Flutter 3.22+ ：PopScope.onPopInvokedWithResult（更旧版本改用 onPopInvoked）
//   · Flutter 3.19+ ：showModalBottomSheet 的 sheetAnimationStyle / AnimationStyle
//   · Dart 3        ：switch 表达式
//   建议 Flutter ≥ 3.24（stable）跑最稳。
//
// 覆盖重点（配套 Flutter Code 录音上传参考.dart §6）：
//   · showModalBottomSheet（showDragHandle + sheetAnimationStyle）替代手写 sheet 动画
//   · 一级→二级：同一个 sheet 内 AnimatedSwitcher 横向切换（遮罩连续）
//   · 二级防误关：PopScope 拦截下拉/点遮罩/系统返回，只允许显式「取消/返回」
//   · 键盘避让：AnimatedPadding + viewInsets
//   · 录音三态（输入框↔录音中↔语音条）：AnimatedSize + AnimatedSwitcher
//   · Toast：Overlay + fade/上移，2.2s 自动消失
//   · 触感 HapticFeedback；reduce-motion 兜底（Motion.d）

import 'dart:async';
import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() => runApp(const DemoApp());

class DemoApp extends StatelessWidget {
  const DemoApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true),
      home: const _Home(),
    );
  }
}

class _Home extends StatelessWidget {
  const _Home();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: Center(
        child: FilledButton.tonal(
          onPressed: () => openReportSheet(context),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text('打开报错'),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// 统一动效 token（Material 3 motion）
// ============================================================
class Motion {
  static const micro = Duration(milliseconds: 200);
  static const sheetIn = Duration(milliseconds: 300);
  static const sheetOut = Duration(milliseconds: 250);
  static const curveIn = Curves.easeInOutCubicEmphasized;
  static const curveOut = Curves.easeInCubic;

  /// 开了系统「减弱动态效果」就瞬时完成
  static Duration d(BuildContext c, Duration x) =>
      MediaQuery.disableAnimationsOf(c) ? Duration.zero : x;
}

const _ink = Color(0xFF141414);
const _ink3 = Color(0xFF7C7C83);
const _line = Color(0xFFE5E5EA);

// ============================================================
// 打开报错 sheet
// ============================================================
Future<void> openReportSheet(BuildContext context) {
  HapticFeedback.selectionClick();
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    sheetAnimationStyle: AnimationStyle(
      duration: Motion.sheetIn,
      reverseDuration: Motion.sheetOut,
      curve: Motion.curveIn,
      reverseCurve: Motion.curveOut,
    ),
    builder: (_) => const _ReportSheet(),
  );
}

class _ReportSheet extends StatefulWidget {
  const _ReportSheet();
  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  int _step = 1; // 1=一级  2=二级
  String _branch = 'ai';
  bool _hasInput = false; // 二级是否已勾选/填字/录音

  @override
  Widget build(BuildContext context) {
    // 二级有输入时，拦截下拉/点遮罩/系统返回，防误关丢输入
    return PopScope(
      canPop: _step == 1 && !_hasInput,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _step == 2) setState(() => _step = 1); // 二级返回一级
      },
      child: AnimatedPadding(
        duration: Motion.d(context, Motion.micro),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
          child: AnimatedSize(
            duration: Motion.d(context, Motion.micro),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: AnimatedSwitcher(
              duration: Motion.d(context, Motion.micro),
              transitionBuilder: (child, anim) {
                final slide = Tween<Offset>(
                  begin: Offset(_step == 2 ? .12 : -.12, 0),
                  end: Offset.zero,
                ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut));
                return FadeTransition(
                  opacity: anim,
                  child: SlideTransition(position: slide, child: child),
                );
              },
              child: _step == 1
                  ? _Level1(
                      key: const ValueKey('l1'),
                      onPick: (b) {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _branch = b;
                          _step = 2;
                        });
                      },
                    )
                  : _Level2(
                      key: const ValueKey('l2'),
                      branch: _branch,
                      onChanged: (has) => setState(() => _hasInput = has),
                      onBack: () => setState(() => _step = 1),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------
// 一级分类
// ------------------------------------------------------------
class _Level1 extends StatelessWidget {
  final void Function(String branch) onPick;
  const _Level1({super.key, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('杠铃颈后深蹲', style: TextStyle(fontSize: 14, color: _ink3)),
          const SizedBox(height: 2),
          const Text('这个动作哪里不对？',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
          const SizedBox(height: 14),
          _optTile('AI 识别问题', '计数 / 身体识别 / 讲解', () => onPick('ai')),
          const SizedBox(height: 10),
          _optTile('课程内容报错', '示范图文 / 名称 / 训练部位', () => onPick('content')),
        ],
      ),
    );
  }

  Widget _optTile(String t, String s, VoidCallback onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: _line, width: 1.5),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t, style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 2),
                  Text(s, style: const TextStyle(fontSize: 13, color: _ink3)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFFC4C4C9)),
          ]),
        ),
      );
}

// ------------------------------------------------------------
// 二级细化（多选 + 补充说明 + 录音三态 + 底部按钮）
// ------------------------------------------------------------
enum _Rec { idle, recording, done }

class _Level2 extends StatefulWidget {
  final String branch;
  final void Function(bool hasInput) onChanged;
  final VoidCallback onBack;
  const _Level2({
    super.key,
    required this.branch,
    required this.onChanged,
    required this.onBack,
  });
  @override
  State<_Level2> createState() => _Level2State();
}

class _Level2State extends State<_Level2> {
  late final List<String> _labels = widget.branch == 'ai'
      ? ['计数多了（没做也计）', '计数少了（做了没计）', '身体识别不准', 'AI 讲解不清楚']
      : ['示范图 / 视频不对', '动作名称不对', '训练部位标注不对', '动作讲解不对'];
  final _selected = <int>{};
  final _ctrl = TextEditingController();

  _Rec _rec = _Rec.idle;
  Timer? _timer;
  int _sec = 0;
  Duration? _clip;

  bool get _hasInput =>
      _selected.isNotEmpty || _ctrl.text.trim().isNotEmpty || _rec == _Rec.done;

  void _notify() => widget.onChanged(_hasInput);

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _startRec() {
    HapticFeedback.lightImpact();
    setState(() {
      _rec = _Rec.recording;
      _sec = 0;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _sec++);
      if (_sec >= 60) _stopRec(auto: true); // 60s 硬上限
    });
    _notify();
  }

  void _stopRec({bool auto = false}) {
    _timer?.cancel();
    HapticFeedback.lightImpact();
    if (auto) HapticFeedback.heavyImpact();
    setState(() {
      if (_sec > 0) {
        _rec = _Rec.done;
        _clip = Duration(seconds: _sec);
      } else {
        _rec = _Rec.idle; // 误触（<1s）丢弃
      }
    });
    _notify();
  }

  void _delClip() {
    setState(() {
      _rec = _Rec.idle;
      _clip = null;
    });
    _notify();
  }

  void _submit() {
    HapticFeedback.mediumImpact();
    final overlay = Overlay.of(context, rootOverlay: true); // 先拿根 overlay
    Navigator.of(context).pop(); // 关闭 sheet
    showThanksToast(overlay, title: '收到，谢谢你！', sub: '这个动作会更准');
  }

  static String _fmt(int s) => '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final len = _ctrl.text.characters.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 头部：返回 + 动作名 + 问句
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            InkWell(
              onTap: widget.onBack,
              borderRadius: BorderRadius.circular(20),
              child: const Padding(
                padding: EdgeInsets.only(right: 8, top: 2),
                child: Icon(Icons.chevron_left, size: 26),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('杠铃颈后深蹲',
                      style: TextStyle(fontSize: 14, color: _ink3)),
                  Text(widget.branch == 'ai' ? 'AI 哪里识别不准？' : '内容哪里有问题？',
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  const Text('可多选；不选也能直接提交',
                      style: TextStyle(fontSize: 13, color: _ink3)),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 8),

          // 多选
          for (var i = 0; i < _labels.length; i++)
            InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() =>
                    _selected.contains(i) ? _selected.remove(i) : _selected.add(i));
                _notify();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 9),
                child: Row(children: [
                  _CheckBox(on: _selected.contains(i)),
                  const SizedBox(width: 11),
                  Expanded(
                      child: Text(_labels[i], style: const TextStyle(fontSize: 16))),
                ]),
              ),
            ),

          const SizedBox(height: 10),

          // 补充说明标签 + 字数
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text('其他问题或补充说明',
                    style: TextStyle(fontSize: 13, color: _ink3)),
                Text('$len/200',
                    style: const TextStyle(fontSize: 12, color: _ink3)),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // 录音三态：输入框 ↔ 录音中 ↔ 语音条
          AnimatedSize(
            duration: Motion.d(context, Motion.micro),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: AnimatedSwitcher(
              duration: Motion.d(context, Motion.micro),
              child: switch (_rec) {
                _Rec.recording => _recBar(),
                _Rec.done => _clipChip(),
                _Rec.idle => _fieldWithMic(),
              },
            ),
          ),

          const SizedBox(height: 18),

          // 底部：取消 + 提交（文案随选择数切换）
          Row(children: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消', style: TextStyle(color: _ink3)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SizedBox(
                height: 50,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _ink,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999)),
                  ),
                  onPressed: _submit,
                  child: AnimatedSwitcher(
                    duration: Motion.d(context, Motion.micro),
                    child: Text(
                      _selected.isEmpty ? '直接提交' : '提交问题',
                      key: ValueKey(_selected.isEmpty),
                      style: const TextStyle(fontSize: 14, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _fieldWithMic() => Container(
        key: const ValueKey('field'),
        padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
        decoration: BoxDecoration(
          border: Border.all(color: _line),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: _ctrl,
              maxLength: 200,
              maxLines: null,
              onChanged: (_) {
                setState(() {});
                _notify();
              },
              buildCounter: (_, {required currentLength, required isFocused, maxLength}) =>
                  null,
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: '说说这个动作的具体问题…',
                hintStyle: TextStyle(color: _ink3),
              ),
            ),
          ),
          IconButton(
            onPressed: _startRec,
            icon: const Icon(Icons.mic, size: 20),
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFFEEF3D6),
              foregroundColor: const Color(0xFF556417),
            ),
          ),
        ]),
      );

  Widget _recBar() => Container(
        key: const ValueKey('rec'),
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFDECEB),
          border: Border.all(color: const Color(0xFFE5342F)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(children: [
          const _PulseDot(),
          const SizedBox(width: 10),
          Text(_fmt(_sec),
              style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFF9A2422),
                  fontFeatures: [FontFeature.tabularFigures()])),
          const SizedBox(width: 10),
          const Expanded(
              child: Text('60 秒以内',
                  style: TextStyle(fontSize: 13, color: Color(0xFF9A2422)))),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFE5342F),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap),
            onPressed: () => _stopRec(),
            child: const Text('停止', style: TextStyle(fontSize: 14)),
          ),
        ]),
      );

  Widget _clipChip() => Align(
        key: const ValueKey('clip'),
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 8, 12, 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF2F4E6),
            border: Border.all(color: const Color(0xFFE0E7BF)),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.play_arrow, size: 18, color: Color(0xFF54631A)),
            const SizedBox(width: 6),
            Text('语音 ${_fmt(_clip!.inSeconds)}',
                style: const TextStyle(fontSize: 14, color: Color(0xFF54631A))),
            const SizedBox(width: 8),
            InkWell(
              onTap: _delClip,
              child: const Icon(Icons.close, size: 16, color: Color(0xFF8A985A)),
            ),
          ]),
        ),
      );
}

class _CheckBox extends StatelessWidget {
  final bool on;
  const _CheckBox({required this.on});
  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: Motion.d(context, const Duration(milliseconds: 120)),
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: on ? _ink : Colors.transparent,
        border: Border.all(color: on ? _ink : const Color(0xFFC9C9CE), width: 2),
        borderRadius: BorderRadius.circular(7),
      ),
      child: on
          ? const Icon(Icons.check, size: 14, color: Colors.white)
          : null,
    );
  }
}

// 录音红点脉冲
class _PulseDot extends StatefulWidget {
  const _PulseDot();
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat(reverse: true);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 1.0, end: .3).animate(_c),
      child: Container(
        width: 11,
        height: 11,
        decoration: const BoxDecoration(
            color: Color(0xFFE5342F), shape: BoxShape.circle),
      ),
    );
  }
}

// ============================================================
// 居中 Toast（Overlay + fade/上移，2.2s 自动消失）
// ============================================================
void showThanksToast(OverlayState overlay,
    {required String title, required String sub}) {
  final reduce = MediaQuery.disableAnimationsOf(overlay.context);
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _ToastCard(
      title: title,
      sub: sub,
      reduceMotion: reduce,
      onGone: () => entry.remove(),
    ),
  );
  overlay.insert(entry);
}

class _ToastCard extends StatefulWidget {
  final String title, sub;
  final bool reduceMotion;
  final VoidCallback onGone;
  const _ToastCard({
    required this.title,
    required this.sub,
    required this.reduceMotion,
    required this.onGone,
  });
  @override
  State<_ToastCard> createState() => _ToastCardState();
}

class _ToastCardState extends State<_ToastCard>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 220));

  @override
  void initState() {
    super.initState();
    widget.reduceMotion ? _c.value = 1 : _c.forward();
    Future.delayed(const Duration(milliseconds: 2200), () async {
      if (!mounted) return;
      if (!widget.reduceMotion) await _c.reverse();
      widget.onGone();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
    return Positioned.fill(
      child: IgnorePointer(
        child: Center(
          child: FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween(begin: const Offset(0, .06), end: Offset.zero)
                  .animate(curved),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 40),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xEE121212),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.favorite, size: 18, color: Color(0xFFC6F24E)),
                    const SizedBox(width: 7),
                    Text(widget.title,
                        style: const TextStyle(
                            fontSize: 17, color: Colors.white)),
                  ]),
                  const SizedBox(height: 6),
                  Text(widget.sub,
                      style: const TextStyle(fontSize: 13, color: Colors.white70)),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
