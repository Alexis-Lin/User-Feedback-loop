// 课中报错反馈 · 「完整可跑」Demo（真实录音 + 先存后传上传）
// ============================================================
// 这版把弹窗动效示例里的「模拟录音」换成 record 真录音，并接上
// Hive 本地队列 + Dio 异步上传（先存后传）。当 lib/main.dart 跑。
//
// —— pubspec.yaml 依赖 ——
//   record: ^5.1.0            # 录音
//   path_provider: ^2.1.0     # 本地目录
//   uuid: ^4.4.0              # 幂等键
//   hive: ^2.2.3              # 本地队列
//   hive_flutter: ^1.1.0
//   dio: ^5.5.0               # 上传
//   connectivity_plus: ^6.0.0 # 网络恢复自动续传（注意 v6 是 List 事件）
//
// —— 平台配置 ——
//   iOS  Info.plist:  <key>NSMicrophoneUsageDescription</key><string>用于语音反馈</string>
//   Android: record 插件自动加 RECORD_AUDIO 权限；minSdkVersion ≥ 23。
//
// —— 说明 ——
//   · 没有后端也能跑：提交=先写本地队列（一定成功），上传失败会退避重试，
//     这正是「先存后传」——本地不丢、联网/重启自动补传。把 baseUrl 换成你的即可。
//   · Flutter 建议 ≥ 3.24 stable（用到 PopScope.onPopInvokedWithResult / sheetAnimationStyle）。

import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:dio/dio.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

// ============================================================
// main：初始化 Hive、构建服务，注入 UI
// ============================================================
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  final box = await Hive.openBox('report_queue');

  final dio = Dio(BaseOptions(
    baseUrl: 'https://your-api.example.com', // TODO 换成真实后端
    connectTimeout: const Duration(seconds: 15),
  ));
  final uploader = ReportUploader(ReportQueue(box), dio);
  uploader.processQueue(); // 启动时续传上次没传完的

  runApp(DemoApp(uploader: uploader));
}

class DemoApp extends StatelessWidget {
  final ReportUploader uploader;
  const DemoApp({super.key, required this.uploader});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true),
      home: _Home(uploader: uploader),
    );
  }
}

class _Home extends StatelessWidget {
  final ReportUploader uploader;
  const _Home({required this.uploader});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: Center(
        child: FilledButton.tonal(
          onPressed: () => openReportSheet(context, uploader),
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
// A. 录音服务（record 真实录音）
// ============================================================
class RecordedClip {
  final String path;
  final Duration duration;
  const RecordedClip(this.path, this.duration);
}

class MicPermissionDenied implements Exception {}

class AudioRecorderService {
  final _rec = AudioRecorder();
  DateTime? _startedAt;

  Future<bool> hasPermission() => _rec.hasPermission();

  Future<void> start() async {
    if (!await _rec.hasPermission()) throw MicPermissionDenied();
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/fb_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _rec.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc, // iOS/Android 通用、体积小
        bitRate: 32000,
        sampleRate: 22050,
        numChannels: 1,
      ),
      path: path,
    );
    _startedAt = DateTime.now();
  }

  /// 停止；<0.8s 视为误触，删掉返回 null
  Future<RecordedClip?> stop() async {
    final path = await _rec.stop();
    final started = _startedAt;
    _startedAt = null;
    if (path == null || started == null) return null;
    final dur = DateTime.now().difference(started);
    if (dur.inMilliseconds < 800) {
      try { await File(path).delete(); } catch (_) {}
      return null;
    }
    return RecordedClip(path, dur);
  }

  Future<void> dispose() => _rec.dispose();
}

// ============================================================
// B. 报错草稿 + 本地队列 + 上传器（先存后传）
// ============================================================
enum UploadStatus { pending, uploading, done, failed }

class ReportDraft {
  final String id; // uuid：幂等键
  final Map<String, dynamic> payload;
  final String? audioPath;
  int retries;
  UploadStatus status;

  ReportDraft({
    required this.id,
    required this.payload,
    this.audioPath,
    this.retries = 0,
    this.status = UploadStatus.pending,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'payload': payload,
        'audioPath': audioPath,
        'retries': retries,
        'status': status.index,
      };

  factory ReportDraft.fromJson(Map j) => ReportDraft(
        id: j['id'] as String,
        payload: Map<String, dynamic>.from(j['payload'] as Map),
        audioPath: j['audioPath'] as String?,
        retries: (j['retries'] ?? 0) as int,
        status: UploadStatus.values[(j['status'] ?? 0) as int],
      );
}

class ReportQueue {
  final Box _box;
  ReportQueue(this._box);

  Future<void> save(ReportDraft d) => _box.put(d.id, d.toJson());
  Future<void> remove(String id) => _box.delete(id);

  List<ReportDraft> pending() => _box.values
      .map((e) => ReportDraft.fromJson(Map.from(e as Map)))
      .where((d) => d.status != UploadStatus.done)
      .toList();
}

class ReportUploader {
  final ReportQueue queue;
  final Dio dio;
  bool _running = false;

  ReportUploader(this.queue, this.dio) {
    // connectivity_plus v6：事件是 List<ConnectivityResult>
    Connectivity().onConnectivityChanged.listen((results) {
      if (results.any((r) => r != ConnectivityResult.none)) processQueue();
    });
  }

  /// 提交入口：★ 先落地本地，再异步上传（不 await，UI 立刻可关表单）
  Future<void> submit(ReportDraft d) async {
    await queue.save(d); // 断网也稳稳存住
    processQueue();      // 触发上传，不阻塞
  }

  Future<void> processQueue() async {
    if (_running) return;
    _running = true;
    try {
      for (final d in queue.pending()) {
        await _uploadOne(d);
      }
    } finally {
      _running = false;
    }
  }

  Future<void> _uploadOne(ReportDraft d) async {
    try {
      d.status = UploadStatus.uploading;
      await queue.save(d);

      final form = FormData.fromMap({
        ...d.payload,
        'idempotency_key': d.id, // 后端据此去重，重试不重复建单
        if (d.audioPath != null)
          'audio': await MultipartFile.fromFile(d.audioPath!),
      });

      await dio.post('/feedback/report', data: form);

      if (d.audioPath != null) {
        try { await File(d.audioPath!).delete(); } catch (_) {} // 传成功再删本地
      }
      await queue.remove(d.id);
    } catch (_) {
      d.retries += 1;
      d.status = UploadStatus.failed;
      await queue.save(d); // 失败也保留，绝不丢

      if (d.retries <= 5) {
        final delay = Duration(seconds: min(60, 1 << d.retries)); // 指数退避
        Timer(delay, () => _uploadOne(d));
      }
      // 超上限：留在本地，等网络恢复 / App 启动再试
    }
  }
}

// ============================================================
// C. 动效 token
// ============================================================
class Motion {
  static const micro = Duration(milliseconds: 200);
  static const sheetIn = Duration(milliseconds: 300);
  static const sheetOut = Duration(milliseconds: 250);
  static const curveIn = Curves.easeInOutCubicEmphasized;
  static const curveOut = Curves.easeInCubic;
  static Duration d(BuildContext c, Duration x) =>
      MediaQuery.disableAnimationsOf(c) ? Duration.zero : x;
}

const _ink = Color(0xFF141414);
const _ink3 = Color(0xFF7C7C83);
const _line = Color(0xFFE5E5EA);

// ============================================================
// D. 报错 sheet
// ============================================================
Future<void> openReportSheet(BuildContext context, ReportUploader uploader) {
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
    builder: (_) => _ReportSheet(uploader: uploader),
  );
}

class _ReportSheet extends StatefulWidget {
  final ReportUploader uploader;
  const _ReportSheet({required this.uploader});
  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  int _step = 1;
  String _branch = 'ai';
  bool _hasInput = false;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _step == 1 && !_hasInput,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _step == 2) setState(() => _step = 1);
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
                      uploader: widget.uploader,
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

class _Level1 extends StatelessWidget {
  final void Function(String) onPick;
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
          _tile('AI 识别问题', '计数 / 身体识别 / 讲解', () => onPick('ai')),
          const SizedBox(height: 10),
          _tile('课程内容报错', '示范图文 / 名称 / 训练部位', () => onPick('content')),
        ],
      ),
    );
  }

  Widget _tile(String t, String s, VoidCallback onTap) => InkWell(
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
// 二级：多选 + 补充说明 + 真实录音三态 + 提交入队
// ------------------------------------------------------------
enum _Rec { idle, recording, done }

class _Level2 extends StatefulWidget {
  final String branch;
  final ReportUploader uploader;
  final void Function(bool) onChanged;
  final VoidCallback onBack;
  const _Level2({
    super.key,
    required this.branch,
    required this.uploader,
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

  final _recorder = AudioRecorderService();
  _Rec _rec = _Rec.idle;
  Timer? _uiTimer; // 仅驱动秒数显示
  int _sec = 0;
  RecordedClip? _clip;

  bool get _hasInput =>
      _selected.isNotEmpty || _ctrl.text.trim().isNotEmpty || _rec == _Rec.done;
  void _notify() => widget.onChanged(_hasInput);

  @override
  void dispose() {
    _uiTimer?.cancel();
    _recorder.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _startRec() async {
    try {
      await _recorder.start(); // 触发系统麦克风授权
    } on MicPermissionDenied {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('麦克风权限已关闭，可去系统设置开启')),
        );
      }
      return;
    }
    HapticFeedback.lightImpact();
    setState(() {
      _rec = _Rec.recording;
      _sec = 0;
    });
    _uiTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _sec++);
      if (_sec >= 60) _stopRec(auto: true); // 60s 硬上限
    });
    _notify();
  }

  Future<void> _stopRec({bool auto = false}) async {
    _uiTimer?.cancel();
    HapticFeedback.lightImpact();
    if (auto) HapticFeedback.heavyImpact();
    final clip = await _recorder.stop();
    if (!mounted) return;
    setState(() {
      if (clip != null) {
        _rec = _Rec.done;
        _clip = clip;
      } else {
        _rec = _Rec.idle; // 误触丢弃
      }
    });
    _notify();
  }

  void _delClip() {
    final p = _clip?.path;
    if (p != null) { try { File(p).delete(); } catch (_) {} }
    setState(() {
      _rec = _Rec.idle;
      _clip = null;
    });
    _notify();
  }

  void _submit() {
    HapticFeedback.mediumImpact();

    final draft = ReportDraft(
      id: const Uuid().v4(),
      payload: {
        'category': widget.branch,
        'tags': _selected.map((i) => _labels[i]).toList(),
        'text': _ctrl.text.trim(),
        'audio_duration_ms': _clip?.duration.inMilliseconds,
        'client_ts': DateTime.now().toIso8601String(),
        // user_id / device_* / course_id / action_id / model_version… 由上下文注入
      },
      audioPath: _clip?.path,
    );
    widget.uploader.submit(draft); // 先存后传，立即返回

    final overlay = Overlay.of(context, rootOverlay: true);
    Navigator.of(context).pop();
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
          for (var i = 0; i < _labels.length; i++)
            InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selected.contains(i)
                    ? _selected.remove(i)
                    : _selected.add(i));
                _notify();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 9),
                child: Row(children: [
                  _CheckBox(on: _selected.contains(i)),
                  const SizedBox(width: 11),
                  Expanded(
                      child:
                          Text(_labels[i], style: const TextStyle(fontSize: 16))),
                ]),
              ),
            ),
          const SizedBox(height: 10),
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
              buildCounter: (_,
                      {required currentLength,
                      required isFocused,
                      maxLength}) =>
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
            Text('语音 ${_fmt(_clip!.duration.inSeconds)}',
                style: const TextStyle(fontSize: 14, color: Color(0xFF54631A))),
            const SizedBox(width: 8),
            InkWell(
                onTap: _delClip,
                child: const Icon(Icons.close,
                    size: 16, color: Color(0xFF8A985A))),
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
      child: on ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
    );
  }
}

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
        decoration:
            const BoxDecoration(color: Color(0xFFE5342F), shape: BoxShape.circle),
      ),
    );
  }
}

// ============================================================
// E. 居中 Toast
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xEE121212),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.favorite,
                        size: 18, color: Color(0xFFC6F24E)),
                    const SizedBox(width: 7),
                    Text(widget.title,
                        style:
                            const TextStyle(fontSize: 17, color: Colors.white)),
                  ]),
                  const SizedBox(height: 6),
                  Text(widget.sub,
                      style:
                          const TextStyle(fontSize: 13, color: Colors.white70)),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
