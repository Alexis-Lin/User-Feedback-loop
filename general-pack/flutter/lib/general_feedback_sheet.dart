// ATOM / BodyPark — General 通用反馈模块
// 一级列表（App View）→ 点分类上弹抽屉表单 → 一次提交。
// 交互对齐原型 UX-Demo：抽屉式、截图折叠、联系方式成组卡片、空值校验、默认联系许可。
// v1.1：移除独立"新增动作申请"；加空账号回退输入框、提交防重复。
//
// 依赖：仅 Flutter Material（录音 / 上传为 TODO 钩子，见 §录音）。
// 用法：
//   Navigator.push(context, MaterialPageRoute(builder: (_) => FeedbackEntryPage(
//     region: Region.intl,                       // 跟随账号地区
//     account: const FeedbackAccount(email: 'alex@example.com'),
//     onSubmit: (draft) => api.submitFeedback(draft),   // 先本地队列后异步上传
//   )));

import 'package:flutter/material.dart';
import 'feedback_strings.dart';

// ----- 设计 token（与原型一致）-----
const _ink = Color(0xFF111214);
const _ink2 = Color(0xFF6B6B70);
const _ink3 = Color(0xFF7C7C83);
const _line = Color(0xFFE5E5EA);
const _sep = Color(0xFFECECF0);
const _soft = Color(0xFFF3F4F6);
const _lime = Color(0xFFC6F24E);

enum Region { cn, intl }

class FeedbackAccount {
  final String email; // 国际版预填（可空 → 回退输入框）
  final String phone; // 大陆版预填，脱敏展示（可空 → 回退输入框）
  const FeedbackAccount({this.email = '', this.phone = ''});
}

/// 提交草稿（先本地存，异步上传）
class FeedbackDraft {
  final String category;        // ai / content / connect / otherfb / feature
  final List<int> subtypeIndex; // 勾选的子项下标
  final String text;
  final String? voicePath;      // 本地录音文件
  final List<String> shotPaths;
  final String contactType;     // email / phone
  final String contactValue;
  final String? altEmail;
  final bool contactConsent;    // 默认 true
  final String lang;
  final String region;
  const FeedbackDraft({
    required this.category,
    required this.subtypeIndex,
    required this.text,
    required this.voicePath,
    required this.shotPaths,
    required this.contactType,
    required this.contactValue,
    required this.altEmail,
    required this.contactConsent,
    required this.lang,
    required this.region,
  });

  Map<String, dynamic> toJson() => {
        'category': category,
        'subtypeIndex': subtypeIndex,
        'text': text,
        'voicePath': voicePath,
        'shots': shotPaths,
        'contact': {'type': contactType, 'value': contactValue, 'altEmail': altEmail},
        'contactConsent': contactConsent,
        'lang': lang,
        'region': region,
      };
}

// =====================================================================
// 一级 App View：分类列表
// =====================================================================
class FeedbackEntryPage extends StatelessWidget {
  final Region region;
  final FeedbackAccount account;
  final ValueChanged<FeedbackDraft> onSubmit;
  final String supportEmail;

  const FeedbackEntryPage({
    super.key,
    required this.region,
    required this.account,
    required this.onSubmit,
    this.supportEmail = 'cs@bodypark.fit',
  });

  @override
  Widget build(BuildContext context) {
    final s = FeedbackStrings.forLocale(Localizations.localeOf(context));
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        foregroundColor: _ink,
        title: Text(s.ui('title'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12, left: 2),
            child: Text(s.ui('prompt'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ),
          for (final c in kCategoryOrder)
            _CategoryRow(cat: c, s: s, onTap: () => showFeedbackSheet(
                  context: context, category: c, region: region, account: account, onSubmit: onSubmit,
                )),
          const SizedBox(height: 22),
          // 售后直达
          Center(
            child: Column(children: [
              Text(s.ui('csText'), style: const TextStyle(fontSize: 13, color: _ink3)),
              const SizedBox(height: 5),
              Text('${s.ui('csMail')}  $supportEmail',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF2A7D46), fontWeight: FontWeight.w500)),
            ]),
          ),
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  final FeedbackCategory cat;
  final FeedbackStrings s;
  final VoidCallback onTap;
  const _CategoryRow({required this.cat, required this.s, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(border: Border.all(color: _line, width: 1.5), borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            Icon(_iconFor(cat), size: 22, color: _ink2),
            const SizedBox(width: 13),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.catName(cat), style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 2),
                Text(s.catSub(cat), style: const TextStyle(fontSize: 13, color: _ink3)),
              ]),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFFC4C4C9)),
          ]),
        ),
      ),
    );
  }

  IconData _iconFor(FeedbackCategory c) => switch (c) {
        FeedbackCategory.ai => Icons.center_focus_weak,
        FeedbackCategory.content => Icons.play_circle_outline,
        FeedbackCategory.connect => Icons.bluetooth,
        FeedbackCategory.otherfb => Icons.chat_bubble_outline,
        FeedbackCategory.feature => Icons.lightbulb_outline,
      };
}

// =====================================================================
// 抽屉入口
// =====================================================================
Future<void> showFeedbackSheet({
  required BuildContext context,
  required FeedbackCategory category,
  required Region region,
  required FeedbackAccount account,
  required ValueChanged<FeedbackDraft> onSubmit,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true, // 允许高抽屉 + 键盘避让
    backgroundColor: Colors.white,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom), // 键盘避让
      child: _FeedbackSheet(category: category, region: region, account: account, onSubmit: onSubmit),
    ),
  );
}

enum _Panel { form, thanks }

class _FeedbackSheet extends StatefulWidget {
  final FeedbackCategory category;
  final Region region;
  final FeedbackAccount account;
  final ValueChanged<FeedbackDraft> onSubmit;
  const _FeedbackSheet({required this.category, required this.region, required this.account, required this.onSubmit});

  @override
  State<_FeedbackSheet> createState() => _FeedbackSheetState();
}

class _FeedbackSheetState extends State<_FeedbackSheet> {
  _Panel panel = _Panel.form;
  bool _submitting = false; // 防重复提交

  late final List<bool> _checked;
  final _text = TextEditingController();
  bool _hasVoice = false; // 录音完成后置 true（见 §录音）
  String? _voicePath;
  final List<String> _shots = [];
  bool _shotsExpanded = false;
  bool _consent = true; // 默认勾选
  bool _useAltEmail = false;
  final _altEmail = TextEditingController();
  bool _useAltPhone = false;
  final _altPhone = TextEditingController();
  final _cnMail = TextEditingController();

  FeedbackCategory get cat => widget.category;
  bool get isFreeText => kCategories[cat]!.isFreeText;
  bool get _emptyAccountIntl => widget.region == Region.intl && widget.account.email.trim().isEmpty;
  bool get _emptyAccountCn => widget.region == Region.cn && widget.account.phone.trim().isEmpty;

  @override
  void initState() {
    super.initState();
    final n = kCategories[cat]!.subs['en']!.length;
    _checked = List<bool>.filled(n, false);
    // 空账号时，联系方式改为可输入：直接展开备用输入框
    if (_emptyAccountIntl) _useAltEmail = true;
    if (_emptyAccountCn) _useAltPhone = true;
    _text.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _text.dispose();
    _altEmail.dispose();
    _altPhone.dispose();
    _cnMail.dispose();
    super.dispose();
  }

  // 提交校验：有选项类需勾选或文字/语音；纯文字类需文字/语音
  bool get _canSubmit {
    if (_submitting) return false;
    final hasSub = _checked.any((e) => e);
    final hasText = _text.text.trim().isNotEmpty;
    if (isFreeText) return hasText || _hasVoice;
    return hasSub || hasText || _hasVoice;
  }

  @override
  Widget build(BuildContext context) {
    final s = FeedbackStrings.forLocale(Localizations.localeOf(context));
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _header(s),
          Flexible(child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 2, 20, 8),
            child: panel == _Panel.form ? _formPanel(s) : _thanksPanel(s),
          )),
          _footer(s),
        ]),
      ),
    );
  }

  Widget _header(FeedbackStrings s) {
    final title = panel == _Panel.form ? s.catName(cat) : s.ui('tkTitle');
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 6),
      child: Row(children: [
        Expanded(child: Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600))),
        InkWell(
          onTap: () => Navigator.pop(context),
          customBorder: const CircleBorder(),
          child: Container(
            width: 30, height: 30,
            decoration: const BoxDecoration(color: Color(0xFFEFEFF2), shape: BoxShape.circle),
            child: const Icon(Icons.close, size: 16, color: Color(0xFF8A8A90)),
          ),
        ),
      ]),
    );
  }

  // ---------------- 表单面板 ----------------
  Widget _formPanel(FeedbackStrings s) {
    final subs = s.catSubs(cat);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (var i = 0; i < subs.length; i++)
        InkWell(
          onTap: () => setState(() => _checked[i] = !_checked[i]),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 11),
            child: Row(children: [
              _checkbox(_checked[i]),
              const SizedBox(width: 11),
              Expanded(child: Text(subs[i], style: const TextStyle(fontSize: 16))),
            ]),
          ),
        ),
      _label('${isFreeText ? s.catLabel(cat) : s.ui('addDefault')}  ', optional: s.ui('optional')),
      _field(child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(child: TextField(
          controller: _text, maxLength: 200, maxLines: null,
          decoration: InputDecoration.collapsed(hintText: isFreeText ? s.catPlaceholder(cat) : s.ui('ph_add')),
        )),
        _micButton(s),
      ])),
      const SizedBox(height: 14),
      _screenshotRow(s),
      const SizedBox(height: 20),
      _contactGroup(s),
    ]);
  }

  // 截图：折叠一行 → 点 + 展开
  Widget _screenshotRow(FeedbackStrings s) {
    if (!_shotsExpanded) {
      return Row(children: [
        Expanded(child: _labelInline(s.ui('shotSect'), optional: s.ui('optional'))),
        _plusButton(() => setState(() {
              _shotsExpanded = true;
              _shots.add('shot_${_shots.length}'); // 实际接系统相册/截图选择器
            })),
      ]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _labelInline(s.ui('shotSect'), optional: s.ui('optional')),
      const SizedBox(height: 10),
      Wrap(spacing: 10, runSpacing: 10, children: [
        for (var i = 0; i < _shots.length; i++) _shotThumb(i),
        if (_shots.length < 3) _addShotBox(),
      ]),
    ]);
  }

  Widget _shotThumb(int i) => Stack(clipBehavior: Clip.none, children: [
        Container(width: 60, height: 60, decoration: BoxDecoration(color: const Color(0xFFDCDCE0), borderRadius: BorderRadius.circular(10))),
        Positioned(top: -6, right: -6, child: InkWell(
          onTap: () => setState(() {
            _shots.removeAt(i);
            if (_shots.isEmpty) _shotsExpanded = false; // 删空收回
          }),
          child: Container(width: 19, height: 19,
            decoration: const BoxDecoration(color: Color(0xFF141414), shape: BoxShape.circle),
            child: const Icon(Icons.close, size: 12, color: Colors.white)),
        )),
      ]);

  Widget _addShotBox() => InkWell(
        onTap: () => setState(() => _shots.add('shot_${_shots.length}')),
        child: Container(
          width: 60, height: 60,
          decoration: BoxDecoration(
            color: const Color(0xFFFAFAFB),
            border: Border.all(color: const Color(0xFFCFCFD4), width: 1.5),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.add, color: _ink3),
        ),
      );

  // 联系方式：成组浅灰卡片
  Widget _contactGroup(FeedbackStrings s) {
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
      decoration: BoxDecoration(color: _soft, borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 9),
          child: _labelInline(s.ui('contactTitle'), optional: s.ui('optional'), color: _ink3, size: 13),
        ),
        if (widget.region == Region.intl) ..._intlContact(s) else ..._cnContact(s),
        // 默认联系许可
        Padding(
          padding: const EdgeInsets.only(top: 11),
          child: InkWell(
            onTap: () => setState(() => _consent = !_consent),
            child: Container(
              padding: const EdgeInsets.only(top: 11),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFE6E7EA)))),
              child: Row(children: [
                _checkbox(_consent, size: 19),
                const SizedBox(width: 9),
                Expanded(child: Text(s.ui('consent'), style: const TextStyle(fontSize: 12.5, color: _ink2))),
              ]),
            ),
          ),
        ),
      ]),
    );
  }

  List<Widget> _intlContact(FeedbackStrings s) => [
        // 空账号：直接输入邮箱；否则预填卡 + 换一个
        if (_emptyAccountIntl)
          _field(child: TextField(controller: _altEmail, keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration.collapsed(hintText: s.ui('contactIntl'))))
        else ...[
          _acctCard(value: widget.account.email, note: s.ui('acctNote'), change: s.ui('changeMail'),
              onChange: () => setState(() => _useAltEmail = true)),
          if (_useAltEmail) Padding(
            padding: const EdgeInsets.only(top: 10),
            child: _field(child: TextField(controller: _altEmail, keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration.collapsed(hintText: s.ui('ph_alt')))),
          ),
        ],
      ];

  List<Widget> _cnContact(FeedbackStrings s) => [
        if (_emptyAccountCn)
          _field(child: TextField(controller: _altPhone, keyboardType: TextInputType.phone,
              decoration: InputDecoration.collapsed(hintText: s.ui('contactTitle'))))
        else ...[
          _acctCard(value: widget.account.phone, note: s.ui('acctPhoneNote'), change: s.ui('changePhone'),
              onChange: () => setState(() => _useAltPhone = true)),
          if (_useAltPhone) Padding(
            padding: const EdgeInsets.only(top: 10),
            child: _field(child: TextField(controller: _altPhone, keyboardType: TextInputType.phone,
                decoration: InputDecoration.collapsed(hintText: s.ui('ph_altPhone')))),
          ),
        ],
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 7),
          child: _labelInline(s.ui('cnMail'), optional: s.ui('optional'), color: _ink2, size: 13),
        ),
        _field(child: TextField(controller: _cnMail, keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration.collapsed(hintText: s.ui('ph_cnMail')))),
        // 企业微信引导
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: const Color(0xFFEEF6E6), border: Border.all(color: const Color(0xFFD5E8C4)), borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              Container(width: 34, height: 34, alignment: Alignment.center,
                decoration: BoxDecoration(color: const Color(0xFF2AAE67), borderRadius: BorderRadius.circular(9)),
                child: const Text('企', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
              const SizedBox(width: 11),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.ui('wecomT'), style: const TextStyle(fontSize: 14, color: Color(0xFF1F5C38), fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(s.ui('wecomS'), style: const TextStyle(fontSize: 11.5, color: Color(0xFF3C7A52))),
              ])),
              const Icon(Icons.qr_code_2, size: 30, color: Color(0xFF2AAE67)),
            ]),
          ),
        ),
      ];

  Widget _acctCard({required String value, required String note, required String change, required VoidCallback onChange}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: const Color(0xFFECECEF)), borderRadius: BorderRadius.circular(11)),
      child: Row(children: [
        Container(width: 20, height: 20, alignment: Alignment.center,
          decoration: const BoxDecoration(color: Color(0xFFE8F3EA), shape: BoxShape.circle),
          child: const Icon(Icons.check, size: 13, color: Color(0xFF2E7D4F))),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, color: _ink)),
          const SizedBox(height: 2),
          Text(note, style: const TextStyle(fontSize: 11.5, color: _ink3)),
        ])),
        InkWell(onTap: onChange, child: Text(change, style: const TextStyle(fontSize: 12.5, color: Color(0xFF2A7D46), fontWeight: FontWeight.w500))),
      ]),
    );
  }

  // ---------------- 感谢面板 ----------------
  Widget _thanksPanel(FeedbackStrings s) {
    final sub = cat == FeedbackCategory.feature ? s.ui('tkSubFeat') : s.ui('tkSub');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Column(children: [
        Container(width: 72, height: 72, alignment: Alignment.center,
          decoration: const BoxDecoration(color: _lime, shape: BoxShape.circle),
          child: const Icon(Icons.favorite, size: 34, color: Color(0xFF1C2B06))),
        const SizedBox(height: 18),
        Text(s.ui('tkTitle'), style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text(sub, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: _ink2)),
        const SizedBox(height: 26),
        Text(s.ui('satLab'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(height: 14),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (final e in ['😍', '🙂', '😕'])
            Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: _FaceButton(emoji: e)),
        ]),
        const SizedBox(height: 8),
        Text(s.ui('satCap'), style: const TextStyle(fontSize: 12, color: _ink3)),
      ]),
    );
  }

  // ---------------- 底部按钮 ----------------
  Widget _footer(FeedbackStrings s) {
    final isForm = panel == _Panel.form;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: _sep))),
      child: Row(children: [
        if (isForm) ...[
          _pillButton(s.ui('cancel'), filled: false, onTap: () => Navigator.pop(context)),
          const SizedBox(width: 12),
        ],
        Expanded(child: _pillButton(
          isForm ? s.ui('submit') : s.ui('done'),
          filled: true,
          enabled: isForm ? _canSubmit : true,
          onTap: () => _onPrimary(s),
        )),
      ]),
    );
  }

  void _onPrimary(FeedbackStrings s) {
    if (panel == _Panel.thanks) {
      Navigator.pop(context);
      return;
    }
    if (_submitting || !_canSubmit) return;
    setState(() => _submitting = true); // 防重复
    final subIdx = <int>[for (var i = 0; i < _checked.length; i++) if (_checked[i]) i];
    final isIntl = widget.region == Region.intl;
    widget.onSubmit(FeedbackDraft(
      category: kCategories[cat]!.key,
      subtypeIndex: subIdx,
      text: _text.text.trim(),
      voicePath: _voicePath,
      shotPaths: List.of(_shots),
      contactType: isIntl ? 'email' : 'phone',
      contactValue: isIntl
          ? ((_useAltEmail || _emptyAccountIntl) ? _altEmail.text.trim() : widget.account.email)
          : ((_useAltPhone || _emptyAccountCn) ? _altPhone.text.trim() : widget.account.phone),
      altEmail: isIntl ? null : (_cnMail.text.trim().isEmpty ? null : _cnMail.text.trim()),
      contactConsent: _consent,
      lang: s.lang,
      region: isIntl ? 'intl' : 'cn',
    ));
    setState(() => panel = _Panel.thanks);
  }

  // ================= 录音（TODO 钩子） =================
  // 真机接 `record` 包，参考交付包中的《录音上传参考.dart》。
  //   停止 / 删除后调用 setState 刷新提交可用态（_canSubmit 依赖 _hasVoice）。
  Widget _micButton(FeedbackStrings s) => InkWell(
        onTap: () => setState(() { _hasVoice = !_hasVoice; _voicePath = _hasVoice ? 'voice.m4a' : null; }),
        customBorder: const CircleBorder(),
        child: Container(
          width: 36, height: 36,
          decoration: BoxDecoration(color: _hasVoice ? const Color(0xFFDFEEB0) : const Color(0xFFEEF3D6), shape: BoxShape.circle),
          child: const Icon(Icons.mic, size: 18, color: Color(0xFF556417)),
        ),
      );

  // ---- 小组件 ----
  Widget _checkbox(bool on, {double size = 22}) => Container(
        width: size, height: size, alignment: Alignment.center,
        decoration: BoxDecoration(
          color: on ? _ink : Colors.transparent,
          border: Border.all(color: on ? _ink : const Color(0xFFC9C9CE), width: 2),
          borderRadius: BorderRadius.circular(size < 20 ? 6 : 7),
        ),
        child: on ? Icon(Icons.check, size: size * 0.6, color: Colors.white) : null,
      );

  Widget _field({required Widget child}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(color: Colors.white, border: Border.all(color: const Color(0xFFECECEF)), borderRadius: BorderRadius.circular(14)),
        child: child,
      );

  Widget _label(String text, {String? optional}) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 9),
        child: _labelInline(text.trim(), optional: optional),
      );

  Widget _labelInline(String text, {String? optional, Color color = _ink, double size = 15}) => Row(children: [
        Flexible(child: Text(text, style: TextStyle(fontSize: size, fontWeight: FontWeight.w600, color: color))),
        if (optional != null) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(color: const Color(0xFFF1F6DF), border: Border.all(color: const Color(0xFFE2ECC0)), borderRadius: BorderRadius.circular(6)),
            child: Text(optional, style: const TextStyle(fontSize: 11, color: Color(0xFF5B6B16))),
          ),
        ],
      ]);

  Widget _plusButton(VoidCallback onTap) => InkWell(
        onTap: onTap, customBorder: const CircleBorder(),
        child: Container(width: 34, height: 34,
          decoration: BoxDecoration(border: Border.all(color: _line, width: 1.5), shape: BoxShape.circle),
          child: const Icon(Icons.add, size: 20, color: _ink2)),
      );

  Widget _pillButton(String text, {required bool filled, bool enabled = true, required VoidCallback onTap}) {
    return SizedBox(
      height: 50,
      child: TextButton(
        onPressed: enabled ? onTap : null,
        style: TextButton.styleFrom(
          backgroundColor: filled ? (enabled ? _ink : const Color(0xFFDCDCE0)) : const Color(0xFFEFEFF2),
          foregroundColor: filled ? Colors.white : _ink,
          padding: EdgeInsets.symmetric(horizontal: filled ? 0 : 22),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        ),
        child: Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
      ),
    );
  }
}

class _FaceButton extends StatefulWidget {
  final String emoji;
  const _FaceButton({required this.emoji});
  @override
  State<_FaceButton> createState() => _FaceButtonState();
}

class _FaceButtonState extends State<_FaceButton> {
  bool on = false;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => setState(() => on = !on),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 60, height: 60, alignment: Alignment.center,
        decoration: BoxDecoration(
          color: on ? const Color(0xFFF4F7E6) : Colors.white,
          border: Border.all(color: on ? const Color(0xFFCFE07F) : _line, width: 1.5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(widget.emoji, style: const TextStyle(fontSize: 28)),
      ),
    );
  }
}
