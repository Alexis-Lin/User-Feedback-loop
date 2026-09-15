// ATOM / BodyPark — General 问题反馈 · 7 语言字符串
// zh 简体中文 · en English · ja 日本語 · es Español · pt Português(BR) · de Deutsch · fr Français
// 真机跟随系统语言。本文件由 i18n.json 生成，可替换为 ARB / gen_l10n。
//
// 用法：
//   final s = FeedbackStrings.of(context);   // 跟随系统 Locale
//   Text(s.ui('submit'));
//   Text(s.catName(FeedbackCategory.ai));

import 'dart:ui' show Locale;

const List<String> kFeedbackLangs = ['zh', 'en', 'ja', 'es', 'pt', 'de', 'fr'];

/// key → (lang → text)
const Map<String, Map<String, String>> kFeedbackUI = {
  'title': {'zh': "问题反馈", 'en': "Feedback", 'ja': "フィードバック", 'es': "Comentarios", 'pt': "Feedback", 'de': "Feedback", 'fr': "Commentaires"},
  'prompt': {'zh': "想反馈点什么？", 'en': "What would you flag?", 'ja': "どうされましたか？", 'es': "¿Qué quieres reportar?", 'pt': "O que você quer relatar?", 'de': "Was möchtest du melden?", 'fr': "Que souhaitez-vous signaler ?"},
  'addDefault': {'zh': "补充说明", 'en': "Details", 'ja': "補足", 'es': "Detalles", 'pt': "Detalhes", 'de': "Details", 'fr': "Détails"},
  'ph_add': {'zh': "还想说点什么…", 'en': "Anything to add…", 'ja': "補足があればどうぞ…", 'es': "¿Algo que añadir?…", 'pt': "Algo a acrescentar?…", 'de': "Noch etwas?…", 'fr': "Autre chose à ajouter ?…"},
  'optional': {'zh': "选填", 'en': "optional", 'ja': "任意", 'es': "opcional", 'pt': "opcional", 'de': "optional", 'fr': "facultatif"},
  'shotSect': {'zh': "截图", 'en': "Screenshot", 'ja': "スクリーンショット", 'es': "Captura", 'pt': "Captura", 'de': "Screenshot", 'fr': "Capture"},
  'shotsCap': {'zh': "最多 3 张", 'en': "up to 3", 'ja': "最大3枚", 'es': "hasta 3", 'pt': "até 3", 'de': "bis zu 3", 'fr': "jusqu'à 3"},
  'contactTitle': {'zh': "联系方式", 'en': "How to reach you", 'ja': "連絡先", 'es': "Cómo contactarte", 'pt': "Como te contatar", 'de': "Kontakt", 'fr': "Comment vous joindre"},
  'contactIntl': {'zh': "回复邮箱", 'en': "Reply email", 'ja': "返信用メール", 'es': "Correo de respuesta", 'pt': "E-mail de resposta", 'de': "Antwort-E-Mail", 'fr': "E-mail de réponse"},
  'acctNote': {'zh': "回复会发到这里", 'en': "Replies go here", 'ja': "ここに返信します", 'es': "Aquí recibirás respuesta", 'pt': "As respostas vêm aqui", 'de': "Antworten kommen hierher", 'fr': "Les réponses arrivent ici"},
  'changeMail': {'zh': "换一个", 'en': "Use another", 'ja': "変更", 'es': "Cambiar", 'pt': "Trocar", 'de': "Ändern", 'fr': "Changer"},
  'ph_alt': {'zh': "换个邮箱接收回复（选填）", 'en': "A different email for replies (optional)", 'ja': "別のメールで受け取る（任意）", 'es': "Otro correo para respuestas (opcional)", 'pt': "Outro e-mail para respostas (opcional)", 'de': "Andere E-Mail für Antworten (optional)", 'fr': "Un autre e-mail pour les réponses (facultatif)"},
  'acctPhoneNote': {'zh': "方便时联系你", 'en': "Handy if we need you", 'ja': "必要な時に連絡します", 'es': "Por si necesitamos contactarte", 'pt': "Caso precisemos falar com você", 'de': "Falls wir dich erreichen müssen", 'fr': "Au cas où l'on doive vous joindre"},
  'changePhone': {'zh': "换一个", 'en': "Use another", 'ja': "変更", 'es': "Cambiar", 'pt': "Trocar", 'de': "Ändern", 'fr': "Changer"},
  'ph_altPhone': {'zh': "换个手机号（选填）", 'en': "A different phone number (optional)", 'ja': "別の電話番号（任意）", 'es': "Otro número (opcional)", 'pt': "Outro telefone (opcional)", 'de': "Andere Nummer (optional)", 'fr': "Un autre numéro (facultatif)"},
  'cnMail': {'zh': "补充邮箱", 'en': "Add email", 'ja': "メールを追加", 'es': "Añadir correo", 'pt': "Adicionar e-mail", 'de': "E-Mail hinzufügen", 'fr': "Ajouter un e-mail"},
  'ph_cnMail': {'zh': "留个邮箱，方便回复你（选填）", 'en': "Leave an email so we can reply (optional)", 'ja': "返信用にメールを（任意）", 'es': "Deja un correo para responderte (opcional)", 'pt': "Deixe um e-mail para responder (opcional)", 'de': "E-Mail für die Antwort (optional)", 'fr': "Laissez un e-mail pour la réponse (facultatif)"},
  'consent': {'zh': "有需要才找你，平时不打扰", 'en': "Only reach out if needed", 'ja': "必要な時だけ連絡します", 'es': "Solo te contactamos si hace falta", 'pt': "Só falamos se for necessário", 'de': "Wir melden uns nur bei Bedarf", 'fr': "On vous contacte seulement si nécessaire"},
  'wecomT': {'zh': "加企业微信客服", 'en': "Add WeChat support", 'ja': "WeChatサポートを追加", 'es': "Añadir soporte por WeChat", 'pt': "Adicionar suporte no WeChat", 'de': "WeChat-Support hinzufügen", 'fr': "Ajouter le support WeChat"},
  'wecomS': {'zh': "问题复杂？加一下更快", 'en': "Complex issue? Faster this way", 'ja': "複雑な問題はこちらが早い", 'es': "¿Problema complejo? Más rápido así", 'pt': "Problema complexo? Assim é mais rápido", 'de': "Komplex? So geht's schneller", 'fr': "Cas complexe ? Plus rapide ainsi"},
  'csText': {'zh': "售后、订单问题？直接联系我们", 'en': "After-sales or orders? Reach us directly", 'ja': "購入・注文のご相談は直接こちら", 'es': "¿Postventa o pedidos? Escríbenos directamente", 'pt': "Pós-venda ou pedidos? Fale direto com a gente", 'de': "Fragen zu Kauf oder Bestellung? Direkt an uns", 'fr': "Après-vente ou commandes ? Contactez-nous directement"},
  'csMail': {'zh': "客服邮箱", 'en': "Support", 'ja': "サポート", 'es': "Soporte", 'pt': "Suporte", 'de': "Support", 'fr': "Support"},
  'cancel': {'zh': "取消", 'en': "Cancel", 'ja': "キャンセル", 'es': "Cancelar", 'pt': "Cancelar", 'de': "Abbrechen", 'fr': "Annuler"},
  'back': {'zh': "返回", 'en': "Back", 'ja': "戻る", 'es': "Atrás", 'pt': "Voltar", 'de': "Zurück", 'fr': "Retour"},
  'submit': {'zh': "提交", 'en': "Submit", 'ja': "送信", 'es': "Enviar", 'pt': "Enviar", 'de': "Senden", 'fr': "Envoyer"},
  'submitReq': {'zh': "提交申请", 'en': "Submit request", 'ja': "申請する", 'es': "Enviar solicitud", 'pt': "Enviar pedido", 'de': "Anfrage senden", 'fr': "Envoyer la demande"},
  'done': {'zh': "完成", 'en': "Done", 'ja': "完了", 'es': "Listo", 'pt': "Concluir", 'de': "Fertig", 'fr': "Terminé"},
  'naEntryT': {'zh': "新增动作申请", 'en': "Request new exercise", 'ja': "種目の追加リクエスト", 'es': "Solicitar ejercicio", 'pt': "Solicitar exercício", 'de': "Übung anfragen", 'fr': "Demander un exercice"},
  'naEntryS': {'zh': "找不到想要的动作？", 'en': "Can't find an exercise?", 'ja': "お探しの種目がない？", 'es': "¿No encuentras un ejercicio?", 'pt': "Não achou um exercício?", 'de': "Übung nicht gefunden?", 'fr': "Exercice introuvable ?"},
  'naTitle': {'zh': "新增动作申请", 'en': "Request new exercise", 'ja': "種目の追加リクエスト", 'es': "Solicitar ejercicio", 'pt': "Solicitar exercício", 'de': "Übung anfragen", 'fr': "Demander un exercice"},
  'naHeroT': {'zh': "找不到想要的动作？", 'en': "Missing an exercise?", 'ja': "種目が見つからない？", 'es': "¿Falta un ejercicio?", 'pt': "Falta um exercício?", 'de': "Übung fehlt?", 'fr': "Un exercice manque ?"},
  'naHeroP': {'zh': "告诉我们，教练会逐一审核。", 'en': "Tell us — our coaches review each one.", 'ja': "お知らせください。コーチが一つずつ確認します。", 'es': "Cuéntanos; nuestros coaches revisan cada uno.", 'pt': "Conta pra gente — os coaches revisam um a um.", 'de': "Sag es uns – unsere Coaches prüfen jede Anfrage.", 'fr': "Dites-le-nous — nos coachs examinent chaque demande."},
  'naName': {'zh': "动作名称", 'en': "Exercise name", 'ja': "種目名", 'es': "Nombre del ejercicio", 'pt': "Nome do exercício", 'de': "Übungsname", 'fr': "Nom de l'exercice"},
  'naWhy': {'zh': "为什么需要？", 'en': "Why do you need it?", 'ja': "なぜ必要ですか？", 'es': "¿Por qué lo necesitas?", 'pt': "Por que você precisa?", 'de': "Warum brauchst du sie?", 'fr': "Pourquoi en avez-vous besoin ?"},
  'naWhyHelp': {'zh': "带理由的申请会被优先审核。", 'en': "Requests with a reason get reviewed first.", 'ja': "理由付きの申請は優先的に確認されます。", 'es': "Las solicitudes con motivo se revisan antes.", 'pt': "Pedidos com motivo têm prioridade.", 'de': "Anfragen mit Begründung werden bevorzugt geprüft.", 'fr': "Les demandes justifiées sont traitées en priorité."},
  'naRef': {'zh': "参考视频 / 链接", 'en': "Reference video / link", 'ja': "参考動画・リンク", 'es': "Vídeo o enlace de referencia", 'pt': "Vídeo ou link de referência", 'de': "Referenzvideo / Link", 'fr': "Vidéo ou lien de référence"},
  'ph_naName': {'zh': "例如：保加利亚分腿蹲", 'en': "e.g. Bulgarian split squat", 'ja': "例：ブルガリアンスクワット", 'es': "p. ej., sentadilla búlgara", 'pt': "ex.: agachamento búlgaro", 'de': "z. B. Bulgarian Split Squat", 'fr': "ex. : squat bulgare"},
  'ph_naWhy': {'zh': "简单说一下…", 'en': "A quick note…", 'ja': "ひとことで…", 'es': "Cuéntanos brevemente…", 'pt': "Conte rapidinho…", 'de': "Kurz erklären…", 'fr': "En quelques mots…"},
  'ph_naRef': {'zh': "粘贴参考视频链接", 'en': "Paste a reference link", 'ja': "参考リンクを貼り付け", 'es': "Pega un enlace de referencia", 'pt': "Cole um link de referência", 'de': "Referenzlink einfügen", 'fr': "Collez un lien de référence"},
  'tkTitle': {'zh': "谢谢你的反馈！", 'en': "Thanks for the feedback!", 'ja': "フィードバックありがとう！", 'es': "¡Gracias por tu comentario!", 'pt': "Valeu pelo feedback!", 'de': "Danke für dein Feedback!", 'fr': "Merci pour votre retour !"},
  'tkSub': {'zh': "已收到，会尽快跟进。", 'en': "Got it — we'll follow up.", 'ja': "受け取りました。順次対応します。", 'es': "Recibido; le daremos seguimiento.", 'pt': "Recebido — vamos dar sequência.", 'de': "Erhalten – wir kümmern uns darum.", 'fr': "Bien reçu — on s'en occupe."},
  'tkSubReq': {'zh': "申请已提交，教练会逐一审核。", 'en': "Request submitted — coaches review each one.", 'ja': "申請を送信しました。コーチが確認します。", 'es': "Solicitud enviada; los coaches la revisarán.", 'pt': "Pedido enviado — os coaches vão revisar.", 'de': "Anfrage gesendet – Coaches prüfen sie.", 'fr': "Demande envoyée — les coachs l'examineront."},
  'tkSubFeat': {'zh': "谢谢建议！产品团队会认真评估。", 'en': "Thanks! We'll consider it.", 'ja': "ご提案ありがとう！検討します。", 'es': "¡Gracias! Lo tendremos en cuenta.", 'pt': "Obrigado! Vamos avaliar.", 'de': "Danke! Wir prüfen das.", 'fr': "Merci ! Nous l'étudierons."},
  'satLab': {'zh': "顺便，你喜欢 ATOM 吗？", 'en': "By the way, do you like ATOM?", 'ja': "ところで、ATOMは気に入っていますか？", 'es': "Por cierto, ¿te gusta ATOM?", 'pt': "A propósito, você curte o ATOM?", 'de': "Übrigens: Magst du ATOM?", 'fr': "Au fait, aimez-vous ATOM ?"},
  'satCap': {'zh': "选填，一点即走", 'en': "optional, one tap", 'ja': "任意・ワンタップ", 'es': "opcional, un toque", 'pt': "opcional, um toque", 'de': "optional, ein Tipp", 'fr': "facultatif, un tap"},
  'recCap': {'zh': "60 秒内", 'en': "max 60s", 'ja': "60秒以内", 'es': "máx. 60 s", 'pt': "até 60 s", 'de': "max. 60 Sek.", 'fr': "60 s max"},
  'recStop': {'zh': "停止", 'en': "Stop", 'ja': "停止", 'es': "Detener", 'pt': "Parar", 'de': "Stopp", 'fr': "Arrêter"},
  'voice': {'zh': "语音", 'en': "Voice", 'ja': "音声", 'es': "Voz", 'pt': "Voz", 'de': "Sprache", 'fr': "Vocal"},
};

/// 5 个一级分类
enum FeedbackCategory { ai, content, connect, otherfb, feature }

const List<FeedbackCategory> kCategoryOrder = [
  FeedbackCategory.ai,
  FeedbackCategory.content,
  FeedbackCategory.connect,
  FeedbackCategory.otherfb,
  FeedbackCategory.feature,
];

class CategoryDef {
  final String key;                       // 提交用 category
  final Map<String, String> name;         // lang → 名称
  final Map<String, String> sub;          // lang → 副标题
  final Map<String, List<String>> subs;   // lang → 子项（空=纯文字类）
  final Map<String, String>? label;       // 纯文字类的输入标题
  final Map<String, String>? placeholder; // 纯文字类的占位
  const CategoryDef(this.key, this.name, this.sub, this.subs, {this.label, this.placeholder});
  bool get isFreeText => (subs['en'] ?? const []).isEmpty;
}

const Map<FeedbackCategory, CategoryDef> kCategories = {
  FeedbackCategory.ai: CategoryDef('ai',
    {'zh': "AI 识别准确性", 'en': "AI tracking", 'ja': "AI認識の精度", 'es': "Precisión del seguimiento por IA", 'pt': "Precisão do rastreamento por IA", 'de': "KI-Erkennungsgenauigkeit", 'fr': "Précision du suivi par IA"},
    {'zh': "计数 / 身体识别 / 讲解", 'en': "Count / pose / coaching", 'ja': "カウント・姿勢認識・解説", 'es': "Conteo / postura / instrucciones", 'pt': "Contagem / postura / instruções", 'de': "Zählung / Haltung / Anleitung", 'fr': "Comptage / posture / conseils"},
    {
      'zh': ["计数多了（没做也计）", "计数少了（做了没计）", "身体识别不准", "AI 讲解不清楚"],
      'en': ["Counted a rep I didn't do", "Missed a rep I did", "Body tracking is off", "Coaching was unclear"],
      'ja': ["やっていないのにカウントされた", "やったのにカウントされない", "姿勢認識がずれる", "AIの解説が分かりにくい"],
      'es': ["Contó una repetición que no hice", "No contó una repetición que hice", "El seguimiento corporal falla", "Las instrucciones no fueron claras"],
      'pt': ["Contou uma repetição que não fiz", "Não contou uma repetição que fiz", "O rastreamento corporal está errado", "As instruções não ficaram claras"],
      'de': ["Zählte eine Wdh., die ich nicht machte", "Zählte eine gemachte Wdh. nicht", "Körpererkennung ungenau", "Anleitung war unklar"],
      'fr': ["A compté une répétition non faite", "N'a pas compté une répétition faite", "Le suivi corporel est imprécis", "Les explications manquaient de clarté"],
    }),
  FeedbackCategory.content: CategoryDef('content',
    {'zh': "课程内容", 'en': "Course content", 'ja': "レッスン内容", 'es': "Contenido del curso", 'pt': "Conteúdo do curso", 'de': "Kursinhalt", 'fr': "Contenu du cours"},
    {'zh': "示范图文 / 名称 / 训练部位", 'en': "Image / name / target muscle", 'ja': "画像・名称・対象部位", 'es': "Imagen / nombre / músculo", 'pt': "Imagem / nome / músculo", 'de': "Bild / Name / Muskel", 'fr': "Image / nom / muscle"},
    {
      'zh': ["示范图 / 视频不对", "动作名称不对", "训练部位标注不对", "动作讲解不对"],
      'en': ["Demo image or video looks off", "Exercise name doesn't match", "Target muscle looks off", "Description isn't accurate"],
      'ja': ["見本の画像・動画が違う", "種目名が正しくない", "対象部位の表記が違う", "解説が正しくない"],
      'es': ["La imagen o vídeo no corresponde", "El nombre no coincide", "El músculo indicado es incorrecto", "La descripción no es precisa"],
      'pt': ["A imagem ou vídeo está errado", "O nome não confere", "O músculo indicado está errado", "A descrição não está correta"],
      'de': ["Demobild oder -video passt nicht", "Übungsname stimmt nicht", "Zielmuskel falsch angegeben", "Beschreibung ist ungenau"],
      'fr': ["L'image ou la vidéo ne correspond pas", "Le nom ne correspond pas", "Le muscle ciblé est incorrect", "La description est inexacte"],
    }),
  FeedbackCategory.connect: CategoryDef('connect',
    {'zh': "连接数据与使用体验", 'en': "Device, data & UX", 'ja': "接続・データ・使い心地", 'es': "Dispositivo, datos y experiencia", 'pt': "Dispositivo, dados e experiência", 'de': "Verbindung, Daten & Bedienung", 'fr': "Appareil, données et expérience"},
    {'zh': "连接 / 数据 / 卡顿", 'en': "Connect / data / performance", 'ja': "接続・データ・動作", 'es': "Conexión / datos / rendimiento", 'pt': "Conexão / dados / desempenho", 'de': "Verbindung / Daten / Leistung", 'fr': "Connexion / données / performance"},
    {
      'zh': ["设备连不上 / 老掉线", "数据丢失或不同步", "卡顿、闪退或不流畅"],
      'en': ["Won't connect / keeps dropping", "Data lost or out of sync", "Lag, crash or clunky"],
      'ja': ["接続できない・よく切れる", "データ紛失・同期しない", "重い・落ちる・カクつく"],
      'es': ["No conecta / se desconecta", "Datos perdidos o sin sincronizar", "Lento, se cierra o va a tirones"],
      'pt': ["Não conecta / cai sempre", "Dados perdidos ou fora de sincronia", "Travando, fechando ou lento"],
      'de': ["Keine Verbindung / bricht ab", "Daten verloren oder nicht synchron", "Ruckelt, stürzt ab oder hakt"],
      'fr': ["Ne se connecte pas / coupures", "Données perdues ou non synchronisées", "Lenteurs, plantages ou à-coups"],
    }),
  FeedbackCategory.otherfb: CategoryDef('otherfb',
    {'zh': "其他问题", 'en': "Other issue", 'ja': "その他の問題", 'es': "Otro problema", 'pt': "Outro problema", 'de': "Anderes Problem", 'fr': "Autre problème"},
    {'zh': "其他没归类的问题", 'en': "Anything else", 'ja': "分類外の問題", 'es': "Cualquier otra cosa", 'pt': "Qualquer outra coisa", 'de': "Alles Weitere", 'fr': "Autre chose"},
    {'zh': [], 'en': [], 'ja': [], 'es': [], 'pt': [], 'de': [], 'fr': []},
    label: {'zh': "说说你遇到的问题", 'en': "Tell us what happened", 'ja': "状況を教えてください", 'es': "Cuéntanos qué pasó", 'pt': "Conte o que aconteceu", 'de': "Erzähl uns, was passiert ist", 'fr': "Dites-nous ce qui s'est passé"},
    placeholder: {'zh': "说说你遇到的问题…", 'en': "Tell us what happened…", 'ja': "状況を教えてください…", 'es': "Cuéntanos qué pasó…", 'pt': "Conte o que aconteceu…", 'de': "Was ist passiert?…", 'fr': "Que s'est-il passé ?…"}),
  FeedbackCategory.feature: CategoryDef('feature',
    {'zh': "新功能建议", 'en': "Feature request", 'ja': "新機能の提案", 'es': "Sugerir función", 'pt': "Sugerir recurso", 'de': "Funktionswunsch", 'fr': "Suggestion de fonction"},
    {'zh': "希望增加或改进的功能", 'en': "What we could add or improve", 'ja': "追加・改善してほしい機能", 'es': "Qué añadir o mejorar", 'pt': "O que adicionar ou melhorar", 'de': "Was wir ergänzen oder verbessern können", 'fr': "Ce qu'on pourrait ajouter ou améliorer"},
    {'zh': [], 'en': [], 'ja': [], 'es': [], 'pt': [], 'de': [], 'fr': []},
    label: {'zh': "说说你的建议", 'en': "Your suggestion", 'ja': "ご提案", 'es': "Tu sugerencia", 'pt': "Sua sugestão", 'de': "Dein Vorschlag", 'fr': "Votre suggestion"},
    placeholder: {'zh': "说说你希望 ATOM 增加或改进什么…", 'en': "What could ATOM add or improve…", 'ja': "ATOMに追加・改善してほしいこと…", 'es': "¿Qué podría añadir o mejorar ATOM?…", 'pt': "O que o ATOM poderia adicionar ou melhorar…", 'de': "Was könnte ATOM ergänzen oder verbessern?…", 'fr': "Ce qu'ATOM pourrait ajouter ou améliorer…"}),
};

/// 简易本地化访问器（真机用系统 Locale；未覆盖语言回退英语）。
class FeedbackStrings {
  final String lang;
  const FeedbackStrings(this.lang);

  factory FeedbackStrings.forLocale(Locale locale) {
    final code = locale.languageCode;
    return FeedbackStrings(kFeedbackLangs.contains(code) ? code : 'en');
  }

  String ui(String key) => kFeedbackUI[key]?[lang] ?? kFeedbackUI[key]?['en'] ?? key;

  String catName(FeedbackCategory c) => kCategories[c]!.name[lang] ?? kCategories[c]!.name['en']!;
  String catSub(FeedbackCategory c) => kCategories[c]!.sub[lang] ?? kCategories[c]!.sub['en']!;
  List<String> catSubs(FeedbackCategory c) => kCategories[c]!.subs[lang] ?? kCategories[c]!.subs['en']!;
  String catLabel(FeedbackCategory c) => (kCategories[c]!.label ?? const {})[lang] ?? ui('addDefault');
  String catPlaceholder(FeedbackCategory c) => (kCategories[c]!.placeholder ?? const {})[lang] ?? ui('ph_add');
}
