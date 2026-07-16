// 课中报错反馈 —— 录音 + 离线先存后异步上传 参考代码（伪代码，示意为主）
//
// 依赖（pubspec.yaml 参考）：
//   record            // 录音
//   just_audio        // 语音条回放
//   path_provider     // 本地目录
//   connectivity_plus // 网络状态监听
//   dio               // 上传（multipart）
//   uuid              // 幂等键
//   hive / hive_flutter // 本地队列持久化
//
// 核心原则：
//   1) 端上只“录音 + 落地本地”，不做 ASR —— 转写在后端做，用户零等待。
//   2) 提交 = 先写本地队列（用户立刻能关表单），再异步上传（失败不丢、可重试）。
//   3) 幂等键（uuid）随请求上送，后端据此去重，重试不会重复建单。

import 'dart:async';
import 'dart:io';
import 'dart:math';

// ============================================================
// 1. 录音服务
// ============================================================
class RecordedClip {
  final String path;         // 本地音频文件路径
  final Duration duration;   // 时长
  const RecordedClip(this.path, this.duration);
}

class MicPermissionDenied implements Exception {}

class AudioRecorderService {
  final _rec = AudioRecorder();        // record 包
  Timer? _capTimer;
  DateTime? _startedAt;

  Future<bool> ensurePermission() => _rec.hasPermission(); // 触发系统麦克风授权

  /// 开始录音；到 60s 硬上限自动停止并回调 onMaxReached
  Future<void> start({required void Function() onMaxReached}) async {
    if (!await ensurePermission()) throw MicPermissionDenied();

    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/fb_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _rec.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,   // 体积小、iOS/Android 通用
        bitRate: 32000,                // 低码率：60s 约 <300KB
        sampleRate: 22050,
        numChannels: 1,                // 单声道，人声足够
      ),
      path: path,
    );
    _startedAt = DateTime.now();

    _capTimer = Timer(const Duration(seconds: 60), () async {
      await stop();
      onMaxReached();                  // UI 提示“已达 60 秒上限”
    });
  }

  /// 停止录音；过短（误触）则丢弃返回 null
  Future<RecordedClip?> stop() async {
    _capTimer?.cancel();
    final path = await _rec.stop();
    if (path == null || _startedAt == null) return null;

    final dur = DateTime.now().difference(_startedAt!);
    _startedAt = null;

    if (dur.inMilliseconds < 800) {    // <0.8s 视为误触，删掉
      await File(path).delete().catchError((_) => File(path));
      return null;
    }
    return RecordedClip(path, dur);
  }

  Future<void> dispose() async {
    _capTimer?.cancel();
    await _rec.dispose();
  }
}

// 中断处理（来电 / 切后台 / 锁屏）：
// 在 State with WidgetsBindingObserver 里监听 —— 正在录音且 state != resumed，
// 就调用 recorder.stop() 保存已录部分，避免录到一半丢失。
//
//   @override
//   void didChangeAppLifecycleState(AppLifecycleState s) {
//     if (s != AppLifecycleState.resumed && isRecording) recorder.stop();
//   }

// ============================================================
// 2. 报错草稿模型
// ============================================================
enum UploadStatus { pending, uploading, done, failed }

class ReportDraft {
  final String id;                     // uuid：幂等键
  final Map<String, dynamic> payload;  // 表单 + 上下文（设备/业务/AI运行时/标注）
  final String? audioPath;             // 本地音频（可空）
  final String? videoClipPath;         // 本地视频 clip（可空，大文件）
  int retries;
  UploadStatus status;

  ReportDraft({
    required this.id,
    required this.payload,
    this.audioPath,
    this.videoClipPath,
    this.retries = 0,
    this.status = UploadStatus.pending,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'payload': payload,
        'audioPath': audioPath,
        'videoClipPath': videoClipPath,
        'retries': retries,
        'status': status.index,
      };

  factory ReportDraft.fromJson(Map j) => ReportDraft(
        id: j['id'],
        payload: Map<String, dynamic>.from(j['payload']),
        audioPath: j['audioPath'],
        videoClipPath: j['videoClipPath'],
        retries: j['retries'] ?? 0,
        status: UploadStatus.values[j['status'] ?? 0],
      );
}

// ============================================================
// 3. 本地持久化队列（离线先存）
// ============================================================
class ReportQueue {
  final Box _box;                      // Hive box：key=id, value=json
  ReportQueue(this._box);

  Future<void> save(ReportDraft d) => _box.put(d.id, d.toJson());
  Future<void> remove(String id) => _box.delete(id);

  List<ReportDraft> pending() => _box.values
      .map((e) => ReportDraft.fromJson(Map.from(e)))
      .where((d) => d.status != UploadStatus.done)
      .toList();
}

// ============================================================
// 4. 异步上传器（重试 + 退避 + 网络恢复自动续传）
// ============================================================
class ReportUploader {
  final ReportQueue queue;
  final Dio dio;
  bool _running = false;

  ReportUploader(this.queue, this.dio) {
    // 网络恢复时自动把队列里没传完的补传
    Connectivity().onConnectivityChanged.listen((r) {
      if (r != ConnectivityResult.none) processQueue();
    });
  }

  /// 提交入口：★ 先落地本地，再异步上传（不 await，UI 立刻可关表单）
  Future<void> submit(ReportDraft d) async {
    await queue.save(d);               // 断网也稳稳存住
    processQueue();                    // 触发上传，不阻塞
  }

  /// App 启动时也调一次，续传上次没传完的
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
        'idempotency_key': d.id,       // 后端据此去重，重试不重复建单
        if (d.audioPath != null)
          'audio': await MultipartFile.fromFile(d.audioPath!),
        if (d.videoClipPath != null)   // 大文件：可加“仅 WiFi / 分块续传”
          'video_clip': await MultipartFile.fromFile(d.videoClipPath!),
      });

      await dio.post('/feedback/report', data: form,
          options: Options(sendTimeout: const Duration(seconds: 30)));

      await _cleanupFiles(d);          // 传成功再删本地音视频
      await queue.remove(d.id);        // 出队
    } catch (e) {
      d.retries += 1;
      d.status = UploadStatus.failed;
      await queue.save(d);             // 失败也保留，绝不丢

      if (d.retries <= 5) {
        final delay = Duration(seconds: min(60, 1 << d.retries)); // 指数退避
        Timer(delay, () => _uploadOne(d));
      }
      // 超过重试上限：留在本地队列，等下次网络恢复 / App 启动再试
    }
  }

  Future<void> _cleanupFiles(ReportDraft d) async {
    for (final p in [d.audioPath, d.videoClipPath]) {
      if (p != null) await File(p).delete().catchError((_) => File(p));
    }
  }
}

// ============================================================
// 5. 表单“提交”接线示例
// ============================================================
Future<void> onSubmit({
  required ReportUploader uploader,
  required List<String> selectedTags,   // 二级多选
  required String text,                  // 补充说明文本
  RecordedClip? clip,                    // 语音（可空）
  String? videoClipPath,                 // 触发点前后 N 秒视频（引擎提供）
}) async {
  final draft = ReportDraft(
    id: const Uuid().v4(),
    payload: {
      // (a) 设备 / (b) 业务 / (c) AI 运行时 / (d) 用户标注 —— 见数据抓取表
      'category': 'ai',                  // 一级分类
      'tags': selectedTags,
      'text': text.trim(),
      'audio_duration_ms': clip?.duration.inMilliseconds,
      'client_ts': DateTime.now().toIso8601String(),
      // 'user_id','device_id','device_model','network',
      // 'course_id','action_id','model_version','set_index'... 由上下文注入
    },
    audioPath: clip?.path,
    videoClipPath: videoClipPath,
  );

  await uploader.submit(draft);          // 立即返回
  // HapticFeedback.mediumImpact();       // 提交成功触感（见 §6.5）
  // showThanksToast(...);  Navigator.pop(); // 「谢谢你，已收到！」并回到训练
  // 注意：ASR（自动语种识别 + 转写）在后端做，端上不转写。
}

// ============================================================
// 6. 弹窗与微动效（Flutter 官方最佳实践 · Android / iOS 一致）
// ============================================================
// 说明：以下为 UI 层参考，仅需 flutter/material + flutter/services，无额外依赖。
//
// 原则：
//  1) 能用框架自带过渡就别手写 —— showModalBottomSheet 免费给你
//     平台正确的进/出动画、下拉关闭、scrim 遮罩、焦点与无障碍。
//  2) 简单显隐用「隐式动画」(AnimatedSwitcher / AnimatedSize / AnimatedOpacity)；
//     需要循环或协调多个值才上 AnimationController，并记得 dispose。
//  3) 尊重系统「减弱动态效果」：MediaQuery.disableAnimationsOf(context)。
//  4) 关键时刻加触感 HapticFeedback（两端都有原生实现）。
//  5) 时长/曲线统一走 token，别各处随手写。

// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';   // HapticFeedback
// import 'dart:ui' show FontFeature;         // 计时数字等宽

/// 统一动效 token（Material 3 motion）
class Motion {
  static const micro    = Duration(milliseconds: 200);
  static const sheetIn  = Duration(milliseconds: 300);
  static const sheetOut = Duration(milliseconds: 250);
  static const curveIn  = Curves.easeInOutCubicEmphasized; // M3 强调曲线
  static const curveOut = Curves.easeInCubic;

  /// 开了「减弱动态效果」就瞬时完成，避免眩晕
  static Duration d(BuildContext c, Duration x) =>
      MediaQuery.disableAnimationsOf(c) ? Duration.zero : x;
}

// ------------------------------------------------------------
// 6.1 底部 sheet（一级 / 二级）—— 用官方 showModalBottomSheet
// ------------------------------------------------------------
// · 进入/退出/下拉关闭/遮罩：全部交给框架，两端物理一致。
// · 一级→二级：不要再弹一个新 sheet（会闪两次遮罩）；在同一个 sheet 内
//   用 AnimatedSwitcher 横向切换，遮罩连续。
// · 防丢输入：二级若已有输入，用 PopScope 拦截「下拉/点遮罩/系统返回」，
//   只允许「取消/返回」按钮显式关闭（对应原型：点遮罩只关一级）。

Future<void> openReportSheet(BuildContext context) {
  HapticFeedback.selectionClick();               // 打开时轻触感
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,                    // 允许超半屏 + 键盘避让
    useSafeArea: true,                           // 刘海 + 底部安全区
    showDragHandle: true,                        // 官方抓手 + 下拉关闭
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    sheetAnimationStyle: AnimationStyle(         // 覆盖进/出时长与曲线（Flutter 3.19+）
      duration: Motion.sheetIn, reverseDuration: Motion.sheetOut,
      curve: Motion.curveIn, reverseCurve: Motion.curveOut,
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
  int _step = 1;                 // 1=一级分类  2=二级细化
  String _branch = 'ai';
  bool _hasInput = false;        // 二级是否已勾选/填字/录音

  @override
  Widget build(BuildContext context) {
    // 二级有输入时，拦截下拉/遮罩/返回，防止误关丢输入
    return PopScope(
      canPop: _step == 1 && !_hasInput,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _step == 2) setState(() => _step = 1); // 二级“返回”回一级
      },
      child: AnimatedPadding(                    // 键盘避让，平滑抬起
        duration: Motion.d(context, Motion.micro),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: AnimatedSize(                     // 一/二级高度差 → 平滑变化，不跳变
          duration: Motion.d(context, Motion.micro),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: AnimatedSwitcher(               // 一 ↔ 二级 横向切换，遮罩连续
            duration: Motion.d(context, Motion.micro),
            transitionBuilder: (child, anim) {
              final slide = Tween<Offset>(
                begin: Offset(_step == 2 ? .12 : -.12, 0), end: Offset.zero,
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
                      setState(() { _branch = b; _step = 2; });
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
    );
  }
}
// 若想要更“原生”的左右滑与边缘返回手势，可把 AnimatedSwitcher 换成 sheet 内嵌
// 一个 Navigator（push/pop 拿到平台转场）；一般 AnimatedSwitcher 已足够。

// ------------------------------------------------------------
// 6.2 提交成功 Toast（居中卡片，2.2s 自动消失）
// ------------------------------------------------------------
// Flutter 无内置居中 toast；用 Overlay + 短生命周期动画组件（fade + 轻微上移）。
// 若可接受底部条，用 ScaffoldMessenger.showSnackBar(behavior: floating) 更省事、自带动画。

void showThanksToast(BuildContext context,
    {required String title, required String sub, IconData icon = Icons.favorite}) {
  final overlay = Overlay.of(context);
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _ToastCard(
      title: title, sub: sub, icon: icon,
      reduceMotion: MediaQuery.disableAnimationsOf(context),
      onGone: () => entry.remove(),
    ),
  );
  overlay.insert(entry);
}

class _ToastCard extends StatefulWidget {
  final String title, sub;
  final IconData icon;
  final bool reduceMotion;
  final VoidCallback onGone;
  const _ToastCard({required this.title, required this.sub, required this.icon,
      required this.reduceMotion, required this.onGone});
  @override
  State<_ToastCard> createState() => _ToastCardState();
}

class _ToastCardState extends State<_ToastCard> with SingleTickerProviderStateMixin {
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
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
    return Positioned.fill(
      child: IgnorePointer(              // 不挡后面训练画面的操作
        child: Center(
          child: FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween(begin: const Offset(0, .06), end: Offset.zero).animate(curved),
              child: /* 卡片 UI：icon + title + sub，深色圆角背景 */ const SizedBox(),
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------
// 6.3 录音条 / 语音条三态切换（输入框 ↔ 录音中 ↔ 语音条）
// ------------------------------------------------------------
// AnimatedSize 抹平高度跳变，AnimatedSwitcher 做淡入淡出。
//
//   AnimatedSize(
//     duration: Motion.d(context, Motion.micro), curve: Curves.easeOut,
//     child: AnimatedSwitcher(
//       duration: Motion.d(context, Motion.micro),
//       child: switch (recState) {
//         RecState.idle      => _fieldWithMic(key: const ValueKey('field')),
//         RecState.recording => _recBar(key: const ValueKey('rec')),
//         RecState.done      => _clip(key: const ValueKey('clip')),
//       },
//     ),
//   )
//
// 录音红点脉冲：AnimationController(repeat reverse) + FadeTransition，记得 dispose。
//   late final _pulse = AnimationController(
//       vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
//   FadeTransition(opacity: Tween(begin: 1.0, end: .3).animate(_pulse), child: _dot);
//
// 计时数字防抖动：等宽数字，宽度不跳。
//   Text('0:03', style: TextStyle(fontFeatures: const [FontFeature.tabularFigures()]));

// ------------------------------------------------------------
// 6.4 主按钮文案切换（直接提交 ↔ 提交问题）
// ------------------------------------------------------------
//   AnimatedSwitcher(
//     duration: Motion.d(context, Motion.micro),
//     child: Text(selected == 0 ? '直接提交' : '提交问题', key: ValueKey(selected == 0)),
//   )

// ------------------------------------------------------------
// 6.5 触感反馈（跨端；Android 走 vibration，iOS 走 Taptic）
// ------------------------------------------------------------
//   打开报错 / 选分类      → HapticFeedback.selectionClick();
//   开始 / 停止录音        → HapticFeedback.lightImpact();
//   录满 60s 上限          → HapticFeedback.heavyImpact();
//   提交成功               → HapticFeedback.mediumImpact();

// ------------------------------------------------------------
// 6.6 跨端一致性 checklist（提测必过）
// ------------------------------------------------------------
//  · 时长/曲线统一走 Motion token：micro 200ms、sheet 进 300 / 出 250、M3 强调曲线。
//  · iOS：确认下拉关闭手势不与系统「边缘滑动返回」冲突（sheet 内 Navigator 时尤其注意）。
//  · Android：返回键/手势由 PopScope 正确拦截（二级不误关）。
//  · 打开系统「减弱动态效果」跑一遍：所有过渡应瞬时、无位移。
//  · 键盘弹起时 sheet 平滑抬起、不遮挡输入框与提交按钮。
//  · 想要更“原生”的 iOS 观感可选 showCupertinoModalPopup / modal_bottom_sheet 包；
//    但 showModalBottomSheet 两端已足够好，优先一套代码。
