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
  // showThanksToast();  closeSheet();    // 「谢谢你，已收到！」并回到训练
  // 注意：ASR（自动语种识别 + 转写）在后端做，端上不转写。
}
