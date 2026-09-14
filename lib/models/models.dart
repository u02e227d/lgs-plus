import 'dart:convert';
import 'dart:math' as math;

bool _jsonBool(dynamic v, {bool fallback = false}) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) {
    final t = v.toLowerCase().trim();
    if (t == 'true' || t == '1') return true;
    if (t == 'false' || t == '0') return false;
  }
  return fallback;
}

enum SubscriptionPlan { free, paid }

/// 会社・ユーザー（ローカル登録。本番はメール活性化）
class AppUser {
  final String id;
  final String companyName;
  final String address;
  final String contactName;
  final String phone;
  final String email;
  final String? passwordHash;
  final bool activated;
  final DateTime createdAt;
  final String inviteCode;
  final String? referredByCode;
  final SubscriptionPlan plan;
  final DateTime accessUntil;
  final String? pendingNotice;

  AppUser({
    required this.id,
    required this.companyName,
    required this.address,
    required this.contactName,
    required this.phone,
    required this.email,
    this.passwordHash,
    this.activated = false,
    DateTime? createdAt,
    this.inviteCode = '',
    this.referredByCode,
    this.plan = SubscriptionPlan.free,
    DateTime? accessUntil,
    this.pendingNotice,
  })  : createdAt = createdAt ?? DateTime.now(),
        accessUntil = accessUntil ?? (createdAt ?? DateTime.now());

  bool get isPaid => plan == SubscriptionPlan.paid;

  /// 有料、または招待特典などの利用期限内は全機能
  bool hasFullAccess([DateTime? now]) =>
      isPaid || remainingDays(now) > 0;

  int remainingDays([DateTime? now]) {
    final n = now ?? DateTime.now();
    final end = DateTime(accessUntil.year, accessUntil.month, accessUntil.day);
    final today = DateTime(n.year, n.month, n.day);
    final days = end.difference(today).inDays;
    return days < 0 ? 0 : days;
  }

  AppUser copyWith({
    String? passwordHash,
    bool? activated,
    String? inviteCode,
    String? referredByCode,
    SubscriptionPlan? plan,
    DateTime? accessUntil,
    String? pendingNotice,
    bool clearNotice = false,
  }) =>
      AppUser(
        id: id,
        companyName: companyName,
        address: address,
        contactName: contactName,
        phone: phone,
        email: email,
        passwordHash: passwordHash ?? this.passwordHash,
        activated: activated ?? this.activated,
        createdAt: createdAt,
        inviteCode: inviteCode ?? this.inviteCode,
        referredByCode: referredByCode ?? this.referredByCode,
        plan: plan ?? this.plan,
        accessUntil: accessUntil ?? this.accessUntil,
        pendingNotice: clearNotice ? null : (pendingNotice ?? this.pendingNotice),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'company_name': companyName,
        'address': address,
        'contact_name': contactName,
        'phone': phone,
        'email': email,
        'password_hash': passwordHash,
        'activated': activated ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
        'invite_code': inviteCode,
        'referred_by_code': referredByCode,
        'plan': plan == SubscriptionPlan.paid ? 'paid' : 'free',
        'access_until': accessUntil.toIso8601String(),
        'pending_notice': pendingNotice,
      };

  factory AppUser.fromMap(Map<String, dynamic> m) {
    final created = DateTime.parse(m['created_at'] as String);
    final accessRaw = m['access_until'] as String?;
    return AppUser(
      id: m['id'] as String,
      companyName: m['company_name'] as String,
      address: m['address'] as String,
      contactName: m['contact_name'] as String,
      phone: m['phone'] as String,
      email: m['email'] as String,
      passwordHash: m['password_hash'] as String?,
      activated: (m['activated'] as int? ?? 0) == 1,
      createdAt: created,
      inviteCode: (m['invite_code'] as String?) ?? '',
      referredByCode: m['referred_by_code'] as String?,
      plan: (m['plan'] as String?) == 'paid'
          ? SubscriptionPlan.paid
          : SubscriptionPlan.free,
      accessUntil: accessRaw == null || accessRaw.isEmpty
          ? created
          : DateTime.parse(accessRaw),
      pendingNotice: m['pending_notice'] as String?,
    );
  }
}

/// 現場プロジェクト
class SiteProject {
  final String id;
  final String name;
  final String address;
  final String contactName;
  final String phone;
  final DateTime createdAt;

  SiteProject({
    required this.id,
    required this.name,
    required this.address,
    required this.contactName,
    required this.phone,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'address': address,
        'contact_name': contactName,
        'phone': phone,
        'created_at': createdAt.toIso8601String(),
      };

  factory SiteProject.fromMap(Map<String, dynamic> m) => SiteProject(
        id: m['id'] as String,
        name: m['name'] as String,
        address: m['address'] as String,
        contactName: m['contact_name'] as String,
        phone: m['phone'] as String,
        createdAt: DateTime.parse(m['created_at'] as String),
      );
}

/// 図面（PDF / 画像）
class DrawingFile {
  final String id;
  final String projectId;
  final String localPath;
  final String fileName;
  final String kind; // pdf | image
  /// ピクセル / mm の係数 K
  final double? scalePxPerMm;
  final DateTime createdAt;

  DrawingFile({
    required this.id,
    required this.projectId,
    required this.localPath,
    required this.fileName,
    required this.kind,
    this.scalePxPerMm,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  DrawingFile copyWith({double? scalePxPerMm}) => DrawingFile(
        id: id,
        projectId: projectId,
        localPath: localPath,
        fileName: fileName,
        kind: kind,
        scalePxPerMm: scalePxPerMm ?? this.scalePxPerMm,
        createdAt: createdAt,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'project_id': projectId,
        'local_path': localPath,
        'file_name': fileName,
        'kind': kind,
        'scale_px_per_mm': scalePxPerMm,
        'created_at': createdAt.toIso8601String(),
      };

  factory DrawingFile.fromMap(Map<String, dynamic> m) => DrawingFile(
        id: m['id'] as String,
        projectId: m['project_id'] as String,
        localPath: m['local_path'] as String,
        fileName: m['file_name'] as String,
        kind: m['kind'] as String,
        scalePxPerMm: (m['scale_px_per_mm'] as num?)?.toDouble(),
        createdAt: DateTime.parse(m['created_at'] as String),
      );
}

enum MeasureMode { wall, ceiling }

enum LgsType { type65, type100 }

enum LgsPitch { p227, p300, p303, p450, p455 }

enum BoardSize {
  size153, // 1.5×3
  size33, // 3×3
  size26, // 2×6
  size36, // 3×6
  size37, // 3×7
  size38, // 3×8
  size39, // 3×9
}

extension BoardSizeX on BoardSize {
  String get label {
    switch (this) {
      case BoardSize.size153:
        return '1.5×3';
      case BoardSize.size33:
        return '3×3';
      case BoardSize.size26:
        return '2×6';
      case BoardSize.size36:
        return '3×6';
      case BoardSize.size37:
        return '3×7';
      case BoardSize.size38:
        return '3×8';
      case BoardSize.size39:
        return '3×9';
    }
  }

  /// 短辺×長辺 (mm)
  (double wMm, double hMm) get mmSize {
    switch (this) {
      case BoardSize.size153:
        return (455, 910);
      case BoardSize.size33:
        return (910, 910);
      case BoardSize.size26:
        return (606, 1820);
      case BoardSize.size36:
        return (910, 1820);
      case BoardSize.size37:
        return (910, 2130);
      case BoardSize.size38:
        return (910, 2420);
      case BoardSize.size39:
        return (910, 2730);
    }
  }
}

/// 天井工法系統
enum CeilingSystemKind { sq, zairai }

extension CeilingSystemKindX on CeilingSystemKind {
  String get label => this == CeilingSystemKind.sq ? 'SQ工法' : '在来工法';
}

/// 天井施工仕様（野縁レイアウト基準）
enum CeilingPanelSpec { panel15x3, panel3x3, panel3x6 }

extension CeilingPanelSpecX on CeilingPanelSpec {
  String get label {
    switch (this) {
      case CeilingPanelSpec.panel15x3:
        return '1.5×3版';
      case CeilingPanelSpec.panel3x3:
        return '3×3版';
      case CeilingPanelSpec.panel3x6:
        return '3×6版';
    }
  }

  /// Wバー芯〜Wバー芯 (mm)
  double get wBarSpanMm {
    switch (this) {
      case CeilingPanelSpec.panel15x3:
        return 455;
      case CeilingPanelSpec.panel3x3:
        return 910;
      case CeilingPanelSpec.panel3x6:
        return 1820;
    }
  }

  /// ボード寸法への対応
  BoardSize get boardSize {
    switch (this) {
      case CeilingPanelSpec.panel15x3:
        return BoardSize.size153;
      case CeilingPanelSpec.panel3x3:
        return BoardSize.size33;
      case CeilingPanelSpec.panel3x6:
        return BoardSize.size36;
    }
  }

  bool get needsPitchSelect => this == CeilingPanelSpec.panel3x6;
}

/// 角スタッド型番
enum SquareStudSize {
  s2040,
  s2540,
  s3040,
  s4045,
  s4050,
  s4065,
  s4075,
}

extension SquareStudSizeX on SquareStudSize {
  String get code {
    switch (this) {
      case SquareStudSize.s2040:
        return '2040';
      case SquareStudSize.s2540:
        return '2540';
      case SquareStudSize.s3040:
        return '3040';
      case SquareStudSize.s4045:
        return '4045';
      case SquareStudSize.s4050:
        return '4050';
      case SquareStudSize.s4065:
        return '4065';
      case SquareStudSize.s4075:
        return '4075';
    }
  }

  String get label => code;

  /// 断面 短辺×長辺 (mm)
  (double a, double b) get sectionMm {
    final c = code;
    return (
      double.parse(c.substring(0, 2)),
      double.parse(c.substring(2, 4)),
    );
  }

  /// 壁厚方向に使う寸法（大きい方）
  double get studWidthMm {
    final (a, b) = sectionMm;
    return a > b ? a : b;
  }

  static SquareStudSize fromCode(String raw) {
    final t = raw.replaceAll(RegExp(r'[^0-9]'), '');
    for (final e in SquareStudSize.values) {
      if (e.code == t) return e;
    }
    return SquareStudSize.s4065;
  }
}

enum BoardLayers { single, double, triple, quad }

extension BoardLayersX on BoardLayers {
  int get count {
    switch (this) {
      case BoardLayers.single:
        return 1;
      case BoardLayers.double:
        return 2;
      case BoardLayers.triple:
        return 3;
      case BoardLayers.quad:
        return 4;
    }
  }

  String get label => '$count層';

  static BoardLayers fromCount(int n) {
    if (n <= 1) return BoardLayers.single;
    if (n == 2) return BoardLayers.double;
    if (n == 3) return BoardLayers.triple;
    return BoardLayers.quad;
  }
}

/// クロス専用設定（壁・天井）
class CrossDedicatedConfig {
  final bool enabled;
  final String crossName;
  final String crossUnit;
  final String pasteName;
  final String pateName;
  /// クロス幅 (m)。0以下は 0.9
  final double crossWidthM;
  /// 両面壁（面積×2・図面は破線）
  final bool bothSides;
  /// ファイバーテープ品名
  final String fiberTapeName;
  /// ファイバーテープ定尺長さ (m)。0＝未設定
  final double fiberTapeLengthM;

  const CrossDedicatedConfig({
    this.enabled = false,
    this.crossName = '',
    this.crossUnit = 'm',
    this.pasteName = '',
    this.pateName = '',
    this.crossWidthM = 0.9,
    this.bothSides = false,
    this.fiberTapeName = '',
    this.fiberTapeLengthM = 45,
  });

  bool get hasContent =>
      enabled &&
      (crossName.trim().isNotEmpty ||
          pasteName.trim().isNotEmpty ||
          pateName.trim().isNotEmpty ||
          fiberTapeName.trim().isNotEmpty);

  /// 測定面積に面数を乗じたクロス面積
  double effectiveAreaM2(double measuredM2) =>
      measuredM2 <= 0 ? 0 : measuredM2 * (bothSides ? 2.0 : 1.0);

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'crossName': crossName,
        'crossUnit': crossUnit,
        'pasteName': pasteName,
        'pateName': pateName,
        'crossWidthM': crossWidthM,
        'bothSides': bothSides,
        'fiberTapeName': fiberTapeName,
        'fiberTapeLengthM': fiberTapeLengthM,
      };

  factory CrossDedicatedConfig.fromJson(Map<String, dynamic>? j) {
    if (j == null) return const CrossDedicatedConfig();
    return CrossDedicatedConfig(
      enabled: _jsonBool(j['enabled']),
      crossName: j['crossName'] as String? ?? '',
      crossUnit: j['crossUnit'] as String? ?? 'm',
      pasteName: j['pasteName'] as String? ?? '',
      pateName: j['pateName'] as String? ?? '',
      crossWidthM: (j['crossWidthM'] as num?)?.toDouble() ?? 0.9,
      bothSides: _jsonBool(j['bothSides']),
      fiberTapeName: j['fiberTapeName'] as String? ?? '',
      fiberTapeLengthM: (j['fiberTapeLengthM'] as num?)?.toDouble() ?? 45,
    );
  }

  CrossDedicatedConfig copyWith({
    bool? enabled,
    String? crossName,
    String? crossUnit,
    String? pasteName,
    String? pateName,
    double? crossWidthM,
    bool? bothSides,
    String? fiberTapeName,
    double? fiberTapeLengthM,
  }) =>
      CrossDedicatedConfig(
        enabled: enabled ?? this.enabled,
        crossName: crossName ?? this.crossName,
        crossUnit: crossUnit ?? this.crossUnit,
        pasteName: pasteName ?? this.pasteName,
        pateName: pateName ?? this.pateName,
        crossWidthM: crossWidthM ?? this.crossWidthM,
        bothSides: bothSides ?? this.bothSides,
        fiberTapeName: fiberTapeName ?? this.fiberTapeName,
        fiberTapeLengthM: fiberTapeLengthM ?? this.fiberTapeLengthM,
      );
}

/// 壁工法パラメータ（JIS A 6517 準拠）
class WallMethod {
  final bool useLgs;
  final LgsType lgsType;
  final LgsPitch pitch;
  final bool useBoard;
  final BoardSize boardSize;
  /// B面ボードサイズ（未設定時は boardSize）
  final BoardSize boardSizeB;
  /// 面Aの層ごとの板サイズ（空なら boardSize を全層に適用）
  final List<BoardSize> boardLayerSizesA;
  /// 面Bの層ごとの板サイズ（空なら boardSizeB を全層に適用）
  final List<BoardSize> boardLayerSizesB;
  final BoardLayers layers;
  final bool useCross;
  final double crossWidthM;
  final double crossWasteRate;

  /// 拡張：形・ボード厚・片面両面・付属金物
  final String lgsFormCode; // '20'|'25'|'45'|'50'|'65'|...
  final String studProfile; // 'channel'|'square'
  /// 角スタッド型番（2040/2540/...）。コの字時は空
  final String squareStudCode;
  /// ランナー幅 (mm)
  final double runnerWidthMm;
  /// ランナー定尺長さ (mm)：3000 / 4000 / 5000
  final double runnerLengthMm;
  /// スタッド定尺長さ (mm)。0 のときは壁高から自動
  final double studLengthMm;
  /// 芯材枠の入力全文（例: "45" / "45+グラスウール"）
  final String lgsCoreSpec;
  final double boardThicknessMm;
  /// 面A / 面B のボード厚（大頭棒の左右点）。未設定時は boardThicknessMm
  final double? boardThicknessAMm;
  final double? boardThicknessBMm;
  /// 石膏ボード品種ラベル
  final String boardKindA;
  final String boardKindB;
  /// 面A/B のボード構成（"12.5" / "12.5+9.5"）。空なら単一 boardThickness
  final String boardStackA;
  final String boardStackB;
  final bool bothSides;
  /// A面ボードを積算に含める
  final bool useBoardFaceA;
  /// B面ボードを積算に含める
  final bool useBoardFaceB;
  final bool useSpacer;
  final bool useFureDome;
  /// 振れ止め幅 (mm)：19 / 25 / 38
  final double fureDomeWidthMm;
  /// 振れ止め定尺長さ (mm)：3000 / 4000 / 5000
  final double fureDomeLengthMm;
  /// ランナースペーサー厚 (mm)：10 / 15 / 25
  final double runnerSpacerMm;
  /// ロックフェルト
  final bool useRockFelt;
  /// ロックフェルト幅 (mm)
  final double rockFeltWidthMm;
  /// タイガーUタイト
  final bool useTigerUtight;
  /// '320' | '720'
  final String tigerUtightType;
  /// グラスウール（充填）
  final bool useGlassWool;
  /// 16 / 24 / 32
  final int glassWoolK;
  /// 鉄板（見切り・補強）
  final bool useIronPlate;
  /// 鉄板幅 (mm)
  final double ironPlateWidthMm;
  /// 鉄板定尺長さ (mm)
  final double ironPlateLengthMm;
  /// 鉄板段数（1〜20。数量＝総長×段÷定尺）
  final int ironPlateSegments;
  /// 開口補強材（スタッド同寸）
  final bool useReinforceMaterial;
  /// 補強材幅 (mm)＝スタッド幅相当
  final double reinforceWidthMm;
  /// 補強材定尺長さ (mm)＝スタッド長さ相当
  final double reinforceLengthMm;
  /// アングルピース（開口補強付属）
  final bool useAnglePiece;
  /// アングルピース辺長 (mm)
  final double anglePieceMm;
  /// ケイカルボード
  final bool useKeikal;
  final double keikalThicknessMm;
  final BoardSize keikalBoardSize;
  /// グラスウール上のその他
  final List<CeilingOtherItem> otherItemsBeforeGlassWool;
  /// タイガーUタイト下のその他
  final List<CeilingOtherItem> otherItemsAfterUtight;
  /// 材料設定「＋」で追加した別寸法
  final List<ExtraSizedItem> extraSizedItems;
  /// クロス専用
  final CrossDedicatedConfig crossDedicated;
  final String? presetId;
  final double? detectedWallThicknessMm;

  const WallMethod({
    this.useLgs = true,
    this.lgsType = LgsType.type65,
    this.pitch = LgsPitch.p303,
    this.useBoard = true,
    this.boardSize = BoardSize.size36,
    this.boardSizeB = BoardSize.size36,
    this.boardLayerSizesA = const [],
    this.boardLayerSizesB = const [],
    this.layers = BoardLayers.single,
    this.useCross = false,
    this.crossWidthM = 0.9,
    this.crossWasteRate = 0.1,
    this.lgsFormCode = '45',
    this.studProfile = 'channel',
    this.squareStudCode = '',
    this.runnerWidthMm = 45,
    this.runnerLengthMm = 4000,
    this.studLengthMm = 0,
    this.lgsCoreSpec = '45+',
    this.boardThicknessMm = 12.5,
    this.boardThicknessAMm,
    this.boardThicknessBMm,
    this.boardKindA = '普通PB',
    this.boardKindB = '普通PB',
    this.boardStackA = '12.5+',
    this.boardStackB = '12.5+',
    this.bothSides = true,
    this.useBoardFaceA = false,
    this.useBoardFaceB = false,
    this.useSpacer = false,
    this.useFureDome = true,
    this.fureDomeWidthMm = 19,
    this.fureDomeLengthMm = 4000,
    this.runnerSpacerMm = 10,
    this.useRockFelt = false,
    this.rockFeltWidthMm = 12.5,
    this.useTigerUtight = false,
    this.tigerUtightType = '320',
    this.useGlassWool = false,
    this.glassWoolK = 24,
    this.useIronPlate = false,
    this.ironPlateWidthMm = 300,
    this.ironPlateLengthMm = 1820,
    this.ironPlateSegments = 1,
    this.useReinforceMaterial = false,
    this.reinforceWidthMm = 45,
    this.reinforceLengthMm = 3000,
    this.useAnglePiece = false,
    this.anglePieceMm = 50,
    this.useKeikal = false,
    this.keikalThicknessMm = 6,
    this.keikalBoardSize = BoardSize.size36,
    this.otherItemsBeforeGlassWool = const [],
    this.otherItemsAfterUtight = const [],
    this.extraSizedItems = const [],
    this.crossDedicated = const CrossDedicatedConfig(),
    this.presetId,
    this.detectedWallThicknessMm,
  });

  /// 層数に合わせて板サイズ列を解決
  List<BoardSize> resolvedLayerSizesA(int layerCount) {
    if (layerCount <= 0) return const [];
    if (boardLayerSizesA.isEmpty) {
      return List<BoardSize>.filled(layerCount, boardSize);
    }
    return List<BoardSize>.generate(
      layerCount,
      (i) => i < boardLayerSizesA.length ? boardLayerSizesA[i] : boardSize,
    );
  }

  List<BoardSize> resolvedLayerSizesB(int layerCount) {
    if (layerCount <= 0) return const [];
    if (boardLayerSizesB.isEmpty) {
      return List<BoardSize>.filled(layerCount, boardSizeB);
    }
    return List<BoardSize>.generate(
      layerCount,
      (i) => i < boardLayerSizesB.length ? boardLayerSizesB[i] : boardSizeB,
    );
  }

  double get pitchMm {
    switch (pitch) {
      case LgsPitch.p227:
        return 227;
      case LgsPitch.p300:
        return 300;
      case LgsPitch.p303:
        return 303;
      case LgsPitch.p450:
        return 450;
      case LgsPitch.p455:
        return 455;
    }
  }

  /// 鉄板段数（未設定・旧0は1段）
  int get ironPlateSegmentCount {
    if (ironPlateSegments < 1) return 1;
    if (ironPlateSegments > 20) return 20;
    return ironPlateSegments;
  }

  double get studWidthMm {
    if (studProfile == 'square') {
      final code = squareStudCode.isNotEmpty ? squareStudCode : lgsFormCode;
      if (code.length >= 4 && RegExp(r'^\d{4}').hasMatch(code)) {
        return SquareStudSizeX.fromCode(code).studWidthMm;
      }
    }
    final fromCore = _firstNumber(lgsCoreSpec);
    if (fromCore != null) return fromCore;
    return double.tryParse(lgsFormCode) ?? 45;
  }

  static double? _firstNumber(String raw) {
    final t = raw
        .replaceAll('＋', '+')
        .replaceAll(' ', '')
        .trim();
    for (final p in t.split('+')) {
      if (p.isEmpty) continue;
      final v = double.tryParse(p);
      if (v != null && v > 0) return v;
    }
    final m = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(t);
    if (m != null) {
      final v = double.tryParse(m.group(1)!);
      if (v != null && v > 0) return v;
    }
    return null;
  }

  double get effectiveBoardAMm {
    final stack = _stackTotalMm(boardStackA);
    if (stack > 0) return stack;
    return boardThicknessAMm ?? boardThicknessMm;
  }

  double get effectiveBoardBMm {
    if (!bothSides) return 0;
    final stack = _stackTotalMm(boardStackB);
    if (stack > 0) return stack;
    return boardThicknessBMm ?? boardThicknessMm;
  }

  static double _stackTotalMm(String raw) {
    final t = raw
        .replaceAll('ｍｍ', '')
        .replaceAll('mm', '')
        .replaceAll('MM', '')
        .replaceAll('＋', '+')
        .replaceAll(' ', '')
        .trim();
    if (t.isEmpty) return 0;
    var sum = 0.0;
    for (final p in t.split('+')) {
      final v = double.tryParse(p);
      if (v != null && v > 0) sum += v;
    }
    return sum;
  }

  WallMethod copyWith({
    bool? useLgs,
    LgsType? lgsType,
    LgsPitch? pitch,
    bool? useBoard,
    BoardSize? boardSize,
    BoardSize? boardSizeB,
    List<BoardSize>? boardLayerSizesA,
    List<BoardSize>? boardLayerSizesB,
    BoardLayers? layers,
    bool? useCross,
    double? crossWidthM,
    double? crossWasteRate,
    String? lgsFormCode,
    String? studProfile,
    String? squareStudCode,
    double? runnerWidthMm,
    double? runnerLengthMm,
    double? studLengthMm,
    String? lgsCoreSpec,
    double? boardThicknessMm,
    double? boardThicknessAMm,
    double? boardThicknessBMm,
    String? boardKindA,
    String? boardKindB,
    String? boardStackA,
    String? boardStackB,
    bool? bothSides,
    bool? useBoardFaceA,
    bool? useBoardFaceB,
    bool? useSpacer,
    bool? useFureDome,
    double? fureDomeWidthMm,
    double? fureDomeLengthMm,
    double? runnerSpacerMm,
    bool? useRockFelt,
    double? rockFeltWidthMm,
    bool? useTigerUtight,
    String? tigerUtightType,
    bool? useGlassWool,
    int? glassWoolK,
    bool? useIronPlate,
    double? ironPlateWidthMm,
    double? ironPlateLengthMm,
    int? ironPlateSegments,
    bool? useReinforceMaterial,
    double? reinforceWidthMm,
    double? reinforceLengthMm,
    bool? useAnglePiece,
    double? anglePieceMm,
    bool? useKeikal,
    double? keikalThicknessMm,
    BoardSize? keikalBoardSize,
    List<CeilingOtherItem>? otherItemsBeforeGlassWool,
    List<CeilingOtherItem>? otherItemsAfterUtight,
    List<ExtraSizedItem>? extraSizedItems,
    CrossDedicatedConfig? crossDedicated,
    String? presetId,
    double? detectedWallThicknessMm,
    bool clearDetected = false,
  }) {
    return WallMethod(
      useLgs: useLgs ?? this.useLgs,
      lgsType: lgsType ?? this.lgsType,
      pitch: pitch ?? this.pitch,
      useBoard: useBoard ?? this.useBoard,
      boardSize: boardSize ?? this.boardSize,
      boardSizeB: boardSizeB ?? this.boardSizeB,
      boardLayerSizesA: boardLayerSizesA ?? this.boardLayerSizesA,
      boardLayerSizesB: boardLayerSizesB ?? this.boardLayerSizesB,
      layers: layers ?? this.layers,
      useCross: useCross ?? this.useCross,
      crossWidthM: crossWidthM ?? this.crossWidthM,
      crossWasteRate: crossWasteRate ?? this.crossWasteRate,
      lgsFormCode: lgsFormCode ?? this.lgsFormCode,
      studProfile: studProfile ?? this.studProfile,
      squareStudCode: squareStudCode ?? this.squareStudCode,
      runnerWidthMm: runnerWidthMm ?? this.runnerWidthMm,
      runnerLengthMm: runnerLengthMm ?? this.runnerLengthMm,
      studLengthMm: studLengthMm ?? this.studLengthMm,
      lgsCoreSpec: lgsCoreSpec ?? this.lgsCoreSpec,
      boardThicknessMm: boardThicknessMm ?? this.boardThicknessMm,
      boardThicknessAMm: boardThicknessAMm ?? this.boardThicknessAMm,
      boardThicknessBMm: boardThicknessBMm ?? this.boardThicknessBMm,
      boardKindA: boardKindA ?? this.boardKindA,
      boardKindB: boardKindB ?? this.boardKindB,
      boardStackA: boardStackA ?? this.boardStackA,
      boardStackB: boardStackB ?? this.boardStackB,
      bothSides: bothSides ?? this.bothSides,
      useBoardFaceA: useBoardFaceA ?? this.useBoardFaceA,
      useBoardFaceB: useBoardFaceB ?? this.useBoardFaceB,
      useSpacer: useSpacer ?? this.useSpacer,
      useFureDome: useFureDome ?? this.useFureDome,
      fureDomeWidthMm: fureDomeWidthMm ?? this.fureDomeWidthMm,
      fureDomeLengthMm: fureDomeLengthMm ?? this.fureDomeLengthMm,
      runnerSpacerMm: runnerSpacerMm ?? this.runnerSpacerMm,
      useRockFelt: useRockFelt ?? this.useRockFelt,
      rockFeltWidthMm: rockFeltWidthMm ?? this.rockFeltWidthMm,
      useTigerUtight: useTigerUtight ?? this.useTigerUtight,
      tigerUtightType: tigerUtightType ?? this.tigerUtightType,
      useGlassWool: useGlassWool ?? this.useGlassWool,
      glassWoolK: glassWoolK ?? this.glassWoolK,
      useIronPlate: useIronPlate ?? this.useIronPlate,
      ironPlateWidthMm: ironPlateWidthMm ?? this.ironPlateWidthMm,
      ironPlateLengthMm: ironPlateLengthMm ?? this.ironPlateLengthMm,
      ironPlateSegments: ironPlateSegments ?? this.ironPlateSegments,
      useReinforceMaterial:
          useReinforceMaterial ?? this.useReinforceMaterial,
      reinforceWidthMm: reinforceWidthMm ?? this.reinforceWidthMm,
      reinforceLengthMm: reinforceLengthMm ?? this.reinforceLengthMm,
      useAnglePiece: useAnglePiece ?? this.useAnglePiece,
      anglePieceMm: anglePieceMm ?? this.anglePieceMm,
      useKeikal: useKeikal ?? this.useKeikal,
      keikalThicknessMm: keikalThicknessMm ?? this.keikalThicknessMm,
      keikalBoardSize: keikalBoardSize ?? this.keikalBoardSize,
      otherItemsBeforeGlassWool:
          otherItemsBeforeGlassWool ?? this.otherItemsBeforeGlassWool,
      otherItemsAfterUtight:
          otherItemsAfterUtight ?? this.otherItemsAfterUtight,
      extraSizedItems: extraSizedItems ?? this.extraSizedItems,
      crossDedicated: crossDedicated ?? this.crossDedicated,
      presetId: presetId ?? this.presetId,
      detectedWallThicknessMm: clearDetected
          ? detectedWallThicknessMm
          : (detectedWallThicknessMm ?? this.detectedWallThicknessMm),
    );
  }

  Map<String, dynamic> toJson() => {
        'useLgs': useLgs,
        'lgsType': lgsType.name,
        'pitch': pitch.name,
        'useBoard': useBoard,
        'boardSize': boardSize.name,
        'boardSizeB': boardSizeB.name,
        'boardLayerSizesA': boardLayerSizesA.map((e) => e.name).toList(),
        'boardLayerSizesB': boardLayerSizesB.map((e) => e.name).toList(),
        'layers': layers.name,
        'useCross': useCross,
        'crossWidthM': crossWidthM,
        'crossWasteRate': crossWasteRate,
        'lgsFormCode': lgsFormCode,
        'studProfile': studProfile,
        'squareStudCode': squareStudCode,
        'runnerWidthMm': runnerWidthMm,
        'runnerLengthMm': runnerLengthMm,
        'studLengthMm': studLengthMm,
        'lgsCoreSpec': lgsCoreSpec,
        'boardThicknessMm': boardThicknessMm,
        'boardThicknessAMm': boardThicknessAMm,
        'boardThicknessBMm': boardThicknessBMm,
        'boardKindA': boardKindA,
        'boardKindB': boardKindB,
        'boardStackA': boardStackA,
        'boardStackB': boardStackB,
        'bothSides': bothSides,
        'useBoardFaceA': useBoardFaceA,
        'useBoardFaceB': useBoardFaceB,
        'useSpacer': useSpacer,
        'useFureDome': useFureDome,
        'fureDomeWidthMm': fureDomeWidthMm,
        'fureDomeLengthMm': fureDomeLengthMm,
        'runnerSpacerMm': runnerSpacerMm,
        'useRockFelt': useRockFelt,
        'rockFeltWidthMm': rockFeltWidthMm,
        'useTigerUtight': useTigerUtight,
        'tigerUtightType': tigerUtightType,
        'useGlassWool': useGlassWool,
        'glassWoolK': glassWoolK,
        'useIronPlate': useIronPlate,
        'ironPlateWidthMm': ironPlateWidthMm,
        'ironPlateLengthMm': ironPlateLengthMm,
        'ironPlateSegments': ironPlateSegments,
        'useReinforceMaterial': useReinforceMaterial,
        'reinforceWidthMm': reinforceWidthMm,
        'reinforceLengthMm': reinforceLengthMm,
        'useAnglePiece': useAnglePiece,
        'anglePieceMm': anglePieceMm,
        'useKeikal': useKeikal,
        'keikalThicknessMm': keikalThicknessMm,
        'keikalBoardSize': keikalBoardSize.name,
        'otherItemsBeforeGlassWool': [
          for (final e in otherItemsBeforeGlassWool) e.toJson(),
        ],
        'otherItemsAfterUtight': [
          for (final e in otherItemsAfterUtight) e.toJson(),
        ],
        'extraSizedItems': [for (final e in extraSizedItems) e.toJson()],
        'crossDedicated': crossDedicated.toJson(),
        'presetId': presetId,
        'detectedWallThicknessMm': detectedWallThicknessMm,
      };

  factory WallMethod.fromJson(Map<String, dynamic> j) {
    final pitchName = j['pitch'] as String? ?? 'p303';
    final pitch = LgsPitch.values.any((e) => e.name == pitchName)
        ? LgsPitch.values.byName(pitchName)
        : LgsPitch.p303;
    final layersName = j['layers'] as String? ?? 'single';
    final layers = BoardLayers.values.any((e) => e.name == layersName)
        ? BoardLayers.values.byName(layersName)
        : BoardLayers.single;
    return WallMethod(
      useLgs: j['useLgs'] as bool? ?? true,
      lgsType: LgsType.values.byName(j['lgsType'] as String? ?? 'type65'),
      pitch: pitch,
      useBoard: j['useBoard'] as bool? ?? true,
      boardSize: () {
        final name = j['boardSize'] as String? ?? 'size36';
        return BoardSize.values.any((e) => e.name == name)
            ? BoardSize.values.byName(name)
            : BoardSize.size36;
      }(),
      boardSizeB: () {
        final name = j['boardSizeB'] as String? ??
            j['boardSize'] as String? ??
            'size36';
        return BoardSize.values.any((e) => e.name == name)
            ? BoardSize.values.byName(name)
            : BoardSize.size36;
      }(),
      boardLayerSizesA: () {
        final raw = j['boardLayerSizesA'];
        if (raw is! List || raw.isEmpty) return const <BoardSize>[];
        return raw
            .map((e) {
              final name = e.toString();
              return BoardSize.values.any((x) => x.name == name)
                  ? BoardSize.values.byName(name)
                  : BoardSize.size36;
            })
            .toList();
      }(),
      boardLayerSizesB: () {
        final raw = j['boardLayerSizesB'];
        if (raw is! List || raw.isEmpty) return const <BoardSize>[];
        return raw
            .map((e) {
              final name = e.toString();
              return BoardSize.values.any((x) => x.name == name)
                  ? BoardSize.values.byName(name)
                  : BoardSize.size36;
            })
            .toList();
      }(),
      layers: layers,
      useCross: j['useCross'] as bool? ?? false,
      crossWidthM: (j['crossWidthM'] as num?)?.toDouble() ?? 0.9,
      crossWasteRate: (j['crossWasteRate'] as num?)?.toDouble() ?? 0.1,
      lgsFormCode: j['lgsFormCode'] as String? ?? '45',
      studProfile: j['studProfile'] as String? ?? 'channel',
      squareStudCode: j['squareStudCode'] as String? ?? '',
      runnerWidthMm: (j['runnerWidthMm'] as num?)?.toDouble() ??
          (double.tryParse(j['lgsFormCode'] as String? ?? '') ?? 45),
      runnerLengthMm: (j['runnerLengthMm'] as num?)?.toDouble() ?? 4000,
      studLengthMm: (j['studLengthMm'] as num?)?.toDouble() ?? 0,
      lgsCoreSpec: j['lgsCoreSpec'] as String? ??
          ((j['lgsFormCode'] as String?) != null
              ? '${j['lgsFormCode']}+'
              : '45+'),
      boardThicknessMm: (j['boardThicknessMm'] as num?)?.toDouble() ?? 12.5,
      boardThicknessAMm: (j['boardThicknessAMm'] as num?)?.toDouble(),
      boardThicknessBMm: (j['boardThicknessBMm'] as num?)?.toDouble(),
      boardKindA: j['boardKindA'] as String? ?? '普通PB',
      boardKindB: j['boardKindB'] as String? ?? '普通PB',
      boardStackA: j['boardStackA'] as String? ?? '12.5+',
      boardStackB: j['boardStackB'] as String? ?? '12.5+',
      bothSides: j['bothSides'] as bool? ?? true,
      useBoardFaceA: j['useBoardFaceA'] as bool? ??
          (j['useBoard'] as bool? ?? true),
      useBoardFaceB: j['useBoardFaceB'] as bool? ??
          ((j['useBoard'] as bool? ?? true) &&
              (j['bothSides'] as bool? ?? true)),
      useSpacer: j['useSpacer'] as bool? ?? false,
      useFureDome: j['useFureDome'] as bool? ?? true,
      fureDomeWidthMm: (j['fureDomeWidthMm'] as num?)?.toDouble() ?? 19,
      fureDomeLengthMm: (j['fureDomeLengthMm'] as num?)?.toDouble() ?? 4000,
      runnerSpacerMm: (j['runnerSpacerMm'] as num?)?.toDouble() ?? 10,
      useRockFelt: j['useRockFelt'] as bool? ?? false,
      rockFeltWidthMm: (j['rockFeltWidthMm'] as num?)?.toDouble() ?? 12.5,
      useTigerUtight: j['useTigerUtight'] as bool? ?? false,
      tigerUtightType: j['tigerUtightType'] as String? ?? '320',
      useGlassWool: j['useGlassWool'] as bool? ?? false,
      glassWoolK: () {
        final k = (j['glassWoolK'] as num?)?.toInt() ?? 24;
        if (k == 36) return 32;
        return k;
      }(),
      useIronPlate: _jsonBool(j['useIronPlate']),
      ironPlateWidthMm: (j['ironPlateWidthMm'] as num?)?.toDouble() ?? 300,
      ironPlateLengthMm: (j['ironPlateLengthMm'] as num?)?.toDouble() ?? 1820,
      ironPlateSegments: () {
        final n = (j['ironPlateSegments'] as num?)?.toInt() ?? 1;
        if (n < 1) return 1;
        if (n > 20) return 20;
        return n;
      }(),
      useReinforceMaterial: j['useReinforceMaterial'] as bool? ?? false,
      reinforceWidthMm: (j['reinforceWidthMm'] as num?)?.toDouble() ?? 45,
      reinforceLengthMm: (j['reinforceLengthMm'] as num?)?.toDouble() ?? 3000,
      useAnglePiece: j['useAnglePiece'] as bool? ?? false,
      anglePieceMm: (j['anglePieceMm'] as num?)?.toDouble() ?? 50,
      useKeikal: j['useKeikal'] as bool? ?? false,
      keikalThicknessMm: (j['keikalThicknessMm'] as num?)?.toDouble() ?? 6,
      keikalBoardSize: () {
        final name = j['keikalBoardSize'] as String? ?? 'size36';
        return BoardSize.values.any((e) => e.name == name)
            ? BoardSize.values.byName(name)
            : BoardSize.size36;
      }(),
      otherItemsBeforeGlassWool: [
        for (final e in (j['otherItemsBeforeGlassWool'] as List? ?? const []))
          if (e is Map)
            CeilingOtherItem.fromJson(Map<String, dynamic>.from(e)),
      ],
      otherItemsAfterUtight: [
        for (final e in (j['otherItemsAfterUtight'] as List? ?? const []))
          if (e is Map)
            CeilingOtherItem.fromJson(Map<String, dynamic>.from(e)),
      ],
      extraSizedItems: [
        for (final e in (j['extraSizedItems'] as List? ?? const []))
          if (e is Map)
            ExtraSizedItem.fromJson(Map<String, dynamic>.from(e)),
      ],
      crossDedicated: CrossDedicatedConfig.fromJson(
        j['crossDedicated'] is Map
            ? Map<String, dynamic>.from(j['crossDedicated'] as Map)
            : null,
      ),
      presetId: j['presetId'] as String?,
      detectedWallThicknessMm:
          (j['detectedWallThicknessMm'] as num?)?.toDouble(),
    );
  }
}

/// 天井仕上げボード1層分
class CeilingFinishBoardLayer {
  final String name;
  final double widthMm;
  final double heightMm;
  final double thicknessMm;

  const CeilingFinishBoardLayer({
    this.name = 'タイガーボード',
    this.widthMm = 910,
    this.heightMm = 1820,
    this.thicknessMm = 9.5,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'widthMm': widthMm,
        'heightMm': heightMm,
        'thicknessMm': thicknessMm,
      };

  factory CeilingFinishBoardLayer.fromJson(Map<String, dynamic> j) =>
      CeilingFinishBoardLayer(
        name: j['name'] as String? ?? 'タイガーボード',
        widthMm: (j['widthMm'] as num?)?.toDouble() ?? 910,
        heightMm: (j['heightMm'] as num?)?.toDouble() ?? 1820,
        thicknessMm: (j['thicknessMm'] as num?)?.toDouble() ?? 9.5,
      );

  CeilingFinishBoardLayer copyWith({
    String? name,
    double? widthMm,
    double? heightMm,
    double? thicknessMm,
  }) =>
      CeilingFinishBoardLayer(
        name: name ?? this.name,
        widthMm: widthMm ?? this.widthMm,
        heightMm: heightMm ?? this.heightMm,
        thicknessMm: thicknessMm ?? this.thicknessMm,
      );
}

/// 材料設定の「＋」で追加した別寸法
class ExtraSizedItem {
  /// w_bar / single_bar / channel / runner / reinforce / stud / fure_dome /
  /// iron / sq_stud / bolt / mikiri
  final String kind;
  final double widthMm;
  final double lengthMm;
  final double qty;
  final String unit;
  /// SQ種類・ボルト幅・見切り品名など
  final String code;

  const ExtraSizedItem({
    required this.kind,
    this.widthMm = 0,
    this.lengthMm = 0,
    this.qty = 1,
    this.unit = '本',
    this.code = '',
  });

  Map<String, dynamic> toJson() => {
        'kind': kind,
        'widthMm': widthMm,
        'lengthMm': lengthMm,
        'qty': qty,
        'unit': unit,
        'code': code,
      };

  factory ExtraSizedItem.fromJson(Map<String, dynamic> j) => ExtraSizedItem(
        kind: j['kind'] as String? ?? '',
        widthMm: (j['widthMm'] as num?)?.toDouble() ?? 0,
        lengthMm: (j['lengthMm'] as num?)?.toDouble() ?? 0,
        qty: (j['qty'] as num?)?.toDouble() ?? 0,
        unit: j['unit'] as String? ?? '本',
        code: j['code'] as String? ?? '',
      );

  ExtraSizedItem copyWith({
    String? kind,
    double? widthMm,
    double? lengthMm,
    double? qty,
    String? unit,
    String? code,
  }) =>
      ExtraSizedItem(
        kind: kind ?? this.kind,
        widthMm: widthMm ?? this.widthMm,
        lengthMm: lengthMm ?? this.lengthMm,
        qty: qty ?? this.qty,
        unit: unit ?? this.unit,
        code: code ?? this.code,
      );

  String estimateName({required bool ceiling}) {
    switch (kind) {
      case 'w_bar':
        return 'Wバー';
      case 'single_bar':
        return 'シングルバー';
      case 'channel':
        return '野縁受け（チャンネル）';
      case 'runner':
        return 'ランナー';
      case 'reinforce':
        return '補強材';
      case 'stud':
        return 'コの字スタッド';
      case 'fure_dome':
        return '振れ止め';
      case 'iron':
        return '鉄板';
      case 'sq_stud':
        return 'SQ角スタッド';
      case 'bolt':
        return '全ネジボルト';
      case 'mikiri':
        return code.trim().isEmpty ? '見切り' : code.trim();
      default:
        return kind;
    }
  }

  String estimateSpec({bool ceiling = false}) {
    switch (kind) {
      case 'w_bar':
      case 'single_bar':
        return '高${widthMm.round()}mm';
      case 'channel':
        return '幅${widthMm.round()}mm × ${lengthMm.round()}mm';
      case 'iron':
        return '幅${widthMm.round()}×長${lengthMm.round()}';
      case 'stud':
      case 'reinforce':
        return '${widthMm.round()}形';
      case 'runner':
        return ceiling
            ? '幅${widthMm.round()}mm'
            : '${widthMm.round()}形 天地';
      case 'fure_dome':
        return 'WB-${widthMm.round()} ${widthMm.round()}mm';
      case 'sq_stud':
        return code.trim().isEmpty ? '${widthMm.round()}' : code.trim();
      case 'bolt':
        return '${code.trim().isEmpty ? 'W3/8' : code.trim()}'
            ' × ${lengthMm.round()}mm';
      case 'mikiri':
        return '見切り・定尺${lengthMm.round()}mm';
      default:
        return '幅${widthMm.round()}mm';
    }
  }

  String estimateLw() =>
      lengthMm > 0 ? '${lengthMm.round()}' : '${widthMm.round()}';
}

/// 天井材料「その他」行
class CeilingOtherItem {
  final String name;
  final String unit;
  final double quantity;

  const CeilingOtherItem({
    this.name = '',
    this.unit = '',
    this.quantity = 0,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'unit': unit,
        'quantity': quantity,
      };

  factory CeilingOtherItem.fromJson(Map<String, dynamic> j) => CeilingOtherItem(
        name: j['name'] as String? ?? '',
        unit: j['unit'] as String? ?? '',
        quantity: (j['quantity'] as num?)?.toDouble() ?? 0,
      );

  CeilingOtherItem copyWith({
    String? name,
    String? unit,
    double? quantity,
  }) =>
      CeilingOtherItem(
        name: name ?? this.name,
        unit: unit ?? this.unit,
        quantity: quantity ?? this.quantity,
      );
}

/// 天井工法パラメータ
class CeilingMethod {
  final CeilingSystemKind systemKind;
  final CeilingPanelSpec panelSpec;
  /// 3×6版の野縁ピッチ（227/303/364）。他仕様ではレイアウトから自動。
  final double noenSpacingMm;
  final double noenuKeSpacingMm;
  final BoardSize boardSize;
  final BoardLayers layers;
  final bool rotated90;
  /// 図面上に野縁・全ネジの効果図を表示
  final bool showLayout;

  /// 全ネジボルト幅ラベル（W3/8 / W1/2）
  final String boltWidthLabel;
  /// 全ネジボルト長さ (mm)
  final double boltLengthMm;
  /// 野縁受け（チャンネル）幅 (mm) 19 / 25 / 38 / 40
  final double ukeChannelWidthMm;
  /// 野縁受け（チャンネル）定尺 (mm)
  final double ukeChannelLengthMm;
  /// チャンネルジョイント幅 (mm) 38 / 40
  final double channelJointWidthMm;
  /// Wバー高さ (mm) 19 / 25
  final double wBarHeightMm;
  /// Wバー定尺 (mm)
  final double wBarLengthMm;
  /// シングルバー高さ (mm) 19 / 25
  final double singleBarHeightMm;
  /// シングルバー定尺 (mm)
  final double singleBarLengthMm;
  /// Wクリップ用 野縁受け幅 (mm) 19 / 25 / 38 / 40
  final double wClipUkeWidthMm;
  /// シングルクリップ用 野縁受け幅 (mm) 19 / 25 / 38 / 40
  final double singleClipUkeWidthMm;
  /// Wバージョイント高さ (mm) 19 / 25
  final double wBarJointHeightMm;
  /// シングルバージョイント高さ (mm) 19 / 25
  final double singleBarJointHeightMm;
  /// ナット本数上書き（null＝自動＝全ネジ×2）
  final double? nutCountOverride;
  /// ハンガー本数上書き（null＝自動＝全ネジ本数）
  final double? hangerCountOverride;
  /// SQ角スタッド種類（例 4045）
  final String sqStudType;
  /// SQ角スタッド芯々間隔 (mm) 227 / 303 / 455
  final double sqStudPitchMm;
  /// SQ角スタッド定尺 (mm)
  final double sqStudLengthMm;
  /// 角スタクリップ用 野縁受けラベル（C19 / C25 / C38）
  final String clipUkeLabel;
  /// 角スタクリップ タイプ（横x縦、例 4045）
  final String clipType;
  /// ランナー幅 (mm)
  final double runnerWidthMm;
  /// ランナー定尺 (mm)
  final double runnerLengthMm;
  /// ハンガー：ボルト種類（W3/8 / W1/2）
  final String hangerBoltWidthLabel;
  /// ハンガー：野縁受け幅 (mm) 19 / 25 / 38 / 40
  final double hangerUkeWidthMm;
  /// ハンガー：金具高さ (mm) 50 / 99 / 150
  final double hangerFixtureHeightMm;
  /// その他材料行
  final List<CeilingOtherItem> otherItems;
  /// 材料設定「＋」で追加した別寸法
  final List<ExtraSizedItem> extraSizedItems;
  /// 仕上げボード層（1層目〜）
  final List<CeilingFinishBoardLayer> finishBoardLayers;
  /// 見切り使用
  final bool mikiriEnabled;
  /// 見切り 品名・品番
  final String mikiriName;
  /// 見切り定尺長さ (mm)
  final double mikiriLengthMm;
  /// ボード欄下のその他
  final List<CeilingOtherItem> boardOtherItems;
  /// クロス専用
  final CrossDedicatedConfig crossDedicated;

  /// 互換：第1層
  String get finishBoardName => finishBoardLayers.isNotEmpty
      ? finishBoardLayers.first.name
      : 'タイガーボード';
  double get finishBoardWidthMm =>
      finishBoardLayers.isNotEmpty ? finishBoardLayers.first.widthMm : 910;
  double get finishBoardHeightMm =>
      finishBoardLayers.isNotEmpty ? finishBoardLayers.first.heightMm : 1820;
  double get finishBoardThicknessMm =>
      finishBoardLayers.isNotEmpty ? finishBoardLayers.first.thicknessMm : 9.5;

  const CeilingMethod({
    this.systemKind = CeilingSystemKind.sq,
    this.panelSpec = CeilingPanelSpec.panel3x6,
    this.noenSpacingMm = 303,
    this.noenuKeSpacingMm = 910,
    this.boardSize = BoardSize.size36,
    this.layers = BoardLayers.single,
    this.rotated90 = false,
    this.showLayout = true,
    this.boltWidthLabel = 'W3/8',
    this.boltLengthMm = 1000,
    this.ukeChannelWidthMm = 38,
    this.ukeChannelLengthMm = 4000,
    this.channelJointWidthMm = 38,
    this.wBarHeightMm = 19,
    this.wBarLengthMm = 4000,
    this.singleBarHeightMm = 19,
    this.singleBarLengthMm = 4000,
    this.wClipUkeWidthMm = 38,
    this.singleClipUkeWidthMm = 38,
    this.wBarJointHeightMm = 19,
    this.singleBarJointHeightMm = 19,
    this.nutCountOverride,
    this.hangerCountOverride,
    this.sqStudType = '4045',
    this.sqStudPitchMm = 303,
    this.sqStudLengthMm = 4000,
    this.clipUkeLabel = 'C38',
    this.clipType = '4045',
    this.runnerWidthMm = 45,
    this.runnerLengthMm = 4000,
    this.hangerBoltWidthLabel = 'W3/8',
    this.hangerUkeWidthMm = 38,
    this.hangerFixtureHeightMm = 99,
    this.otherItems = const [],
    this.extraSizedItems = const [],
    this.finishBoardLayers = const [
      CeilingFinishBoardLayer(),
    ],
    this.mikiriEnabled = false,
    this.mikiriName = '',
    this.mikiriLengthMm = 2000,
    this.boardOtherItems = const [],
    this.crossDedicated = const CrossDedicatedConfig(),
  });

  /// 連続バー間隔（W〜シングル／シングル〜シングル）
  double get barPitchMm {
    switch (panelSpec) {
      case CeilingPanelSpec.panel15x3:
        return 227.5;
      case CeilingPanelSpec.panel3x3:
        return 303;
      case CeilingPanelSpec.panel3x6:
        return noenSpacingMm;
    }
  }

  double get wBarSpanMm => panelSpec.wBarSpanMm;

  Map<String, dynamic> toJson() => {
        'systemKind': systemKind.name,
        'panelSpec': panelSpec.name,
        'noenSpacingMm': noenSpacingMm,
        'noenuKeSpacingMm': noenuKeSpacingMm,
        'boardSize': boardSize.name,
        'layers': layers.name,
        'rotated90': rotated90,
        'showLayout': showLayout,
        'boltWidthLabel': boltWidthLabel,
        'boltLengthMm': boltLengthMm,
        'ukeChannelWidthMm': ukeChannelWidthMm,
        'ukeChannelLengthMm': ukeChannelLengthMm,
        'channelJointWidthMm': channelJointWidthMm,
        'wBarHeightMm': wBarHeightMm,
        'wBarLengthMm': wBarLengthMm,
        'singleBarHeightMm': singleBarHeightMm,
        'singleBarLengthMm': singleBarLengthMm,
        'wClipUkeWidthMm': wClipUkeWidthMm,
        'singleClipUkeWidthMm': singleClipUkeWidthMm,
        'wBarJointHeightMm': wBarJointHeightMm,
        'singleBarJointHeightMm': singleBarJointHeightMm,
        'nutCountOverride': nutCountOverride,
        'hangerCountOverride': hangerCountOverride,
        'sqStudType': sqStudType,
        'sqStudPitchMm': sqStudPitchMm,
        'sqStudLengthMm': sqStudLengthMm,
        'clipUkeLabel': clipUkeLabel,
        'clipType': clipType,
        'runnerWidthMm': runnerWidthMm,
        'runnerLengthMm': runnerLengthMm,
        'hangerBoltWidthLabel': hangerBoltWidthLabel,
        'hangerUkeWidthMm': hangerUkeWidthMm,
        'hangerFixtureHeightMm': hangerFixtureHeightMm,
        'otherItems': [for (final e in otherItems) e.toJson()],
        'extraSizedItems': [for (final e in extraSizedItems) e.toJson()],
        'finishBoardLayers': [for (final e in finishBoardLayers) e.toJson()],
        // 旧キー互換
        'finishBoardName': finishBoardName,
        'finishBoardWidthMm': finishBoardWidthMm,
        'finishBoardHeightMm': finishBoardHeightMm,
        'finishBoardThicknessMm': finishBoardThicknessMm,
        'mikiriEnabled': mikiriEnabled,
        'mikiriName': mikiriName,
        'mikiriLengthMm': mikiriLengthMm,
        'boardOtherItems': [for (final e in boardOtherItems) e.toJson()],
        'crossDedicated': crossDedicated.toJson(),
      };

  factory CeilingMethod.fromJson(Map<String, dynamic> j) {
    final layersName = j['layers'] as String? ?? 'single';
    final layers = BoardLayers.values.any((e) => e.name == layersName)
        ? BoardLayers.values.byName(layersName)
        : BoardLayers.single;
    final sysName = j['systemKind'] as String? ?? 'sq';
    final systemKind = CeilingSystemKind.values.any((e) => e.name == sysName)
        ? CeilingSystemKind.values.byName(sysName)
        : CeilingSystemKind.sq;
    CeilingPanelSpec panelSpec = CeilingPanelSpec.panel3x6;
    final psName = j['panelSpec'] as String?;
    if (psName != null &&
        CeilingPanelSpec.values.any((e) => e.name == psName)) {
      panelSpec = CeilingPanelSpec.values.byName(psName);
    } else {
      // 旧データ：boardSize から推定
      final bs = j['boardSize'] as String? ?? 'size36';
      if (bs == 'size153' || bs == 'size15') {
        panelSpec = CeilingPanelSpec.panel15x3;
      } else if (bs == 'size33') {
        panelSpec = CeilingPanelSpec.panel3x3;
      } else {
        panelSpec = CeilingPanelSpec.panel3x6;
      }
    }
    final boardName = j['boardSize'] as String? ?? panelSpec.boardSize.name;
    final boardSize = BoardSize.values.any((e) => e.name == boardName)
        ? BoardSize.values.byName(boardName)
        : panelSpec.boardSize;
    return CeilingMethod(
      systemKind: systemKind,
      panelSpec: panelSpec,
      noenSpacingMm: (j['noenSpacingMm'] as num?)?.toDouble() ?? 303,
      noenuKeSpacingMm: (j['noenuKeSpacingMm'] as num?)?.toDouble() ?? 910,
      boardSize: boardSize,
      layers: layers,
      rotated90: j['rotated90'] as bool? ?? false,
      showLayout: j['showLayout'] as bool? ?? true,
      boltWidthLabel: j['boltWidthLabel'] as String? ?? 'W3/8',
      boltLengthMm: (j['boltLengthMm'] as num?)?.toDouble() ?? 1000,
      ukeChannelWidthMm: (j['ukeChannelWidthMm'] as num?)?.toDouble() ?? 38,
      ukeChannelLengthMm:
          (j['ukeChannelLengthMm'] as num?)?.toDouble() ?? 4000,
      channelJointWidthMm:
          (j['channelJointWidthMm'] as num?)?.toDouble() ?? 38,
      wBarHeightMm: (j['wBarHeightMm'] as num?)?.toDouble() ?? 19,
      wBarLengthMm: (j['wBarLengthMm'] as num?)?.toDouble() ?? 4000,
      singleBarHeightMm: (j['singleBarHeightMm'] as num?)?.toDouble() ?? 19,
      singleBarLengthMm: (j['singleBarLengthMm'] as num?)?.toDouble() ?? 4000,
      wClipUkeWidthMm: (j['wClipUkeWidthMm'] as num?)?.toDouble() ?? 38,
      singleClipUkeWidthMm:
          (j['singleClipUkeWidthMm'] as num?)?.toDouble() ?? 38,
      wBarJointHeightMm: (j['wBarJointHeightMm'] as num?)?.toDouble() ??
          (j['wBarHeightMm'] as num?)?.toDouble() ??
          19,
      singleBarJointHeightMm:
          (j['singleBarJointHeightMm'] as num?)?.toDouble() ??
              (j['singleBarHeightMm'] as num?)?.toDouble() ??
              19,
      nutCountOverride: (j['nutCountOverride'] as num?)?.toDouble(),
      hangerCountOverride: (j['hangerCountOverride'] as num?)?.toDouble(),
      sqStudType: j['sqStudType'] as String? ?? '4045',
      sqStudPitchMm: (j['sqStudPitchMm'] as num?)?.toDouble() ?? 303,
      sqStudLengthMm: (j['sqStudLengthMm'] as num?)?.toDouble() ?? 4000,
      clipUkeLabel: j['clipUkeLabel'] as String? ?? 'C38',
      clipType: j['clipType'] as String? ?? '4045',
      runnerWidthMm: (j['runnerWidthMm'] as num?)?.toDouble() ?? 45,
      runnerLengthMm: (j['runnerLengthMm'] as num?)?.toDouble() ?? 4000,
      hangerBoltWidthLabel: j['hangerBoltWidthLabel'] as String? ??
          (j['boltWidthLabel'] as String? ?? 'W3/8'),
      hangerUkeWidthMm: (j['hangerUkeWidthMm'] as num?)?.toDouble() ??
          (j['ukeChannelWidthMm'] as num?)?.toDouble() ??
          38,
      hangerFixtureHeightMm:
          (j['hangerFixtureHeightMm'] as num?)?.toDouble() ?? 99,
      otherItems: [
        for (final e in (j['otherItems'] as List? ?? const []))
          if (e is Map)
            CeilingOtherItem.fromJson(Map<String, dynamic>.from(e)),
      ],
      extraSizedItems: [
        for (final e in (j['extraSizedItems'] as List? ?? const []))
          if (e is Map)
            ExtraSizedItem.fromJson(Map<String, dynamic>.from(e)),
      ],
      finishBoardLayers: () {
        final raw = j['finishBoardLayers'] as List?;
        if (raw != null && raw.isNotEmpty) {
          return [
            for (final e in raw)
              if (e is Map)
                CeilingFinishBoardLayer.fromJson(Map<String, dynamic>.from(e)),
          ];
        }
        // 旧単層キーから復元
        final n = j['finishBoardName'] as String? ?? 'タイガーボード';
        return [
          CeilingFinishBoardLayer(
            name: n == 'チャンネルホルタ' ? 'チャンネルホルダー' : n,
            widthMm: (j['finishBoardWidthMm'] as num?)?.toDouble() ?? 910,
            heightMm: (j['finishBoardHeightMm'] as num?)?.toDouble() ?? 1820,
            thicknessMm:
                (j['finishBoardThicknessMm'] as num?)?.toDouble() ?? 9.5,
          ),
        ];
      }(),
      mikiriEnabled: j['mikiriEnabled'] as bool? ?? false,
      mikiriName: j['mikiriName'] as String? ?? '',
      mikiriLengthMm: (j['mikiriLengthMm'] as num?)?.toDouble() ?? 2000,
      boardOtherItems: [
        for (final e in (j['boardOtherItems'] as List? ?? const []))
          if (e is Map)
            CeilingOtherItem.fromJson(Map<String, dynamic>.from(e)),
      ],
      crossDedicated: CrossDedicatedConfig.fromJson(
        j['crossDedicated'] is Map
            ? Map<String, dynamic>.from(j['crossDedicated'] as Map)
            : null,
      ),
    );
  }

  CeilingMethod copyWith({
    CeilingSystemKind? systemKind,
    CeilingPanelSpec? panelSpec,
    double? noenSpacingMm,
    double? noenuKeSpacingMm,
    BoardSize? boardSize,
    BoardLayers? layers,
    bool? rotated90,
    bool? showLayout,
    String? boltWidthLabel,
    double? boltLengthMm,
    double? ukeChannelWidthMm,
    double? ukeChannelLengthMm,
    double? channelJointWidthMm,
    double? wBarHeightMm,
    double? wBarLengthMm,
    double? singleBarHeightMm,
    double? singleBarLengthMm,
    double? wClipUkeWidthMm,
    double? singleClipUkeWidthMm,
    double? wBarJointHeightMm,
    double? singleBarJointHeightMm,
    double? nutCountOverride,
    double? hangerCountOverride,
    String? sqStudType,
    double? sqStudPitchMm,
    double? sqStudLengthMm,
    String? clipUkeLabel,
    String? clipType,
    double? runnerWidthMm,
    double? runnerLengthMm,
    String? hangerBoltWidthLabel,
    double? hangerUkeWidthMm,
    double? hangerFixtureHeightMm,
    List<CeilingOtherItem>? otherItems,
    List<ExtraSizedItem>? extraSizedItems,
    List<CeilingFinishBoardLayer>? finishBoardLayers,
    bool? mikiriEnabled,
    String? mikiriName,
    double? mikiriLengthMm,
    List<CeilingOtherItem>? boardOtherItems,
    CrossDedicatedConfig? crossDedicated,
    bool clearNutOverride = false,
    bool clearHangerOverride = false,
  }) =>
      CeilingMethod(
        systemKind: systemKind ?? this.systemKind,
        panelSpec: panelSpec ?? this.panelSpec,
        noenSpacingMm: noenSpacingMm ?? this.noenSpacingMm,
        noenuKeSpacingMm: noenuKeSpacingMm ?? this.noenuKeSpacingMm,
        boardSize: boardSize ?? this.boardSize,
        layers: layers ?? this.layers,
        rotated90: rotated90 ?? this.rotated90,
        showLayout: showLayout ?? this.showLayout,
        boltWidthLabel: boltWidthLabel ?? this.boltWidthLabel,
        boltLengthMm: boltLengthMm ?? this.boltLengthMm,
        ukeChannelWidthMm: ukeChannelWidthMm ?? this.ukeChannelWidthMm,
        ukeChannelLengthMm: ukeChannelLengthMm ?? this.ukeChannelLengthMm,
        channelJointWidthMm: channelJointWidthMm ?? this.channelJointWidthMm,
        wBarHeightMm: wBarHeightMm ?? this.wBarHeightMm,
        wBarLengthMm: wBarLengthMm ?? this.wBarLengthMm,
        singleBarHeightMm: singleBarHeightMm ?? this.singleBarHeightMm,
        singleBarLengthMm: singleBarLengthMm ?? this.singleBarLengthMm,
        wClipUkeWidthMm: wClipUkeWidthMm ?? this.wClipUkeWidthMm,
        singleClipUkeWidthMm:
            singleClipUkeWidthMm ?? this.singleClipUkeWidthMm,
        wBarJointHeightMm: wBarJointHeightMm ?? this.wBarJointHeightMm,
        singleBarJointHeightMm:
            singleBarJointHeightMm ?? this.singleBarJointHeightMm,
        nutCountOverride: clearNutOverride
            ? null
            : (nutCountOverride ?? this.nutCountOverride),
        hangerCountOverride: clearHangerOverride
            ? null
            : (hangerCountOverride ?? this.hangerCountOverride),
        sqStudType: sqStudType ?? this.sqStudType,
        sqStudPitchMm: sqStudPitchMm ?? this.sqStudPitchMm,
        sqStudLengthMm: sqStudLengthMm ?? this.sqStudLengthMm,
        clipUkeLabel: clipUkeLabel ?? this.clipUkeLabel,
        clipType: clipType ?? this.clipType,
        runnerWidthMm: runnerWidthMm ?? this.runnerWidthMm,
        runnerLengthMm: runnerLengthMm ?? this.runnerLengthMm,
        hangerBoltWidthLabel:
            hangerBoltWidthLabel ?? this.hangerBoltWidthLabel,
        hangerUkeWidthMm: hangerUkeWidthMm ?? this.hangerUkeWidthMm,
        hangerFixtureHeightMm:
            hangerFixtureHeightMm ?? this.hangerFixtureHeightMm,
        otherItems: otherItems ?? this.otherItems,
        extraSizedItems: extraSizedItems ?? this.extraSizedItems,
        finishBoardLayers: finishBoardLayers ?? this.finishBoardLayers,
        mikiriEnabled: mikiriEnabled ?? this.mikiriEnabled,
        mikiriName: mikiriName ?? this.mikiriName,
        mikiriLengthMm: mikiriLengthMm ?? this.mikiriLengthMm,
        boardOtherItems: boardOtherItems ?? this.boardOtherItems,
        crossDedicated: crossDedicated ?? this.crossDedicated,
      );
}

class Point2 {
  final double x;
  final double y;
  const Point2(this.x, this.y);

  Map<String, dynamic> toJson() => {'x': x, 'y': y};
  factory Point2.fromJson(Map<String, dynamic> j) =>
      Point2((j['x'] as num).toDouble(), (j['y'] as num).toDouble());
}

class WallSegment {
  final String id;
  /// 折れ線頂点（2点以上）。単純壁は2点。
  final List<Point2> points;
  /// 独立した画線チェーンの開始インデックス（長さ合算・非接続可）
  final List<int> chainStarts;
  final double heightMm;
  final WallMethod method;
  final Map<String, double> quantities;
  /// 線色（ARGB）
  final int? highlightArgb;
  /// 線の太さ（画像座標系のストローク幅）
  final double strokeWidth;
  /// 十字入力の向き（互換・未使用可）
  final int triadQuarterTurns;
  /// 工法選択・積算確定済み（試算表に含める）
  final bool estimateReady;
  /// 鉄板専用で測定した線（材料選択で鉄板を自動ON）
  final bool ironPlateMeasured;

  WallSegment({
    required this.id,
    required this.points,
    required this.heightMm,
    required this.method,
    required this.quantities,
    this.chainStarts = const [0],
    this.highlightArgb,
    this.strokeWidth = 8,
    this.triadQuarterTurns = 0,
    this.estimateReady = false,
    this.ironPlateMeasured = false,
  }) : assert(points.length >= 2);

  Point2 get a => points.first;
  Point2 get b => points.last;

  /// 鉄板専用モードで画いた線（T）。材料選択で鉄板をONにしただけの壁は含まない
  bool get isIronDrawLine {
    if (ironPlateMeasured || (quantities['iron_plate_draw'] ?? 0) > 0) {
      return true;
    }
    // 旧データ：LGS/ボード無し＋鉄板ON＝鉄板専用画線
    return method.useIronPlate && !method.useLgs && !method.useBoard;
  }

  /// 表示・点線用。鉄板専用画線のみ T
  bool get isIronPlate => isIronDrawLine;

  int get cornerCount => math.max(0, points.length - 2);

  /// チェーンごとに分割した頂点列
  List<List<Point2>> get chains {
    final starts = [...chainStarts]..sort();
    if (starts.isEmpty || starts.first != 0) {
      starts.insert(0, 0);
    }
    final out = <List<Point2>>[];
    for (var i = 0; i < starts.length; i++) {
      final from = starts[i].clamp(0, points.length);
      final to = i + 1 < starts.length
          ? starts[i + 1].clamp(0, points.length)
          : points.length;
      if (to - from >= 2) {
        out.add(points.sublist(from, to));
      }
    }
    if (out.isEmpty && points.length >= 2) {
      out.add(points);
    }
    return out;
  }

  WallSegment copyWith({
    List<Point2>? points,
    List<int>? chainStarts,
    double? heightMm,
    WallMethod? method,
    Map<String, double>? quantities,
    int? highlightArgb,
    double? strokeWidth,
    int? triadQuarterTurns,
    bool? estimateReady,
    bool? ironPlateMeasured,
    bool clearHighlight = false,
  }) {
    return WallSegment(
      id: id,
      points: points ?? this.points,
      chainStarts: chainStarts ?? this.chainStarts,
      heightMm: heightMm ?? this.heightMm,
      method: method ?? this.method,
      quantities: quantities ?? this.quantities,
      highlightArgb:
          clearHighlight ? highlightArgb : (highlightArgb ?? this.highlightArgb),
      strokeWidth: strokeWidth ?? this.strokeWidth,
      triadQuarterTurns: triadQuarterTurns ?? this.triadQuarterTurns,
      estimateReady: estimateReady ?? this.estimateReady,
      ironPlateMeasured: ironPlateMeasured ?? this.ironPlateMeasured,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'points': points.map((p) => p.toJson()).toList(),
        'chainStarts': chainStarts,
        'a': a.toJson(),
        'b': b.toJson(),
        'heightMm': heightMm,
        'method': method.toJson(),
        'quantities': quantities,
        'highlightArgb': highlightArgb,
        'strokeWidth': strokeWidth,
        'triadQuarterTurns': triadQuarterTurns,
        'estimateReady': estimateReady,
        'ironPlateMeasured': ironPlateMeasured,
      };

  factory WallSegment.fromJson(Map<String, dynamic> j) {
    List<Point2> pts;
    if (j['points'] is List && (j['points'] as List).isNotEmpty) {
      pts = (j['points'] as List)
          .map((e) => Point2.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      pts = [
        Point2.fromJson(j['a'] as Map<String, dynamic>),
        Point2.fromJson(j['b'] as Map<String, dynamic>),
      ];
    }
    var turns = j['triadQuarterTurns'] as int?;
    if (turns == null && (j['triadFlip'] as bool? ?? false)) {
      turns = 2;
    }
    final rawStarts = j['chainStarts'];
    final starts = rawStarts is List && rawStarts.isNotEmpty
        ? rawStarts.map((e) => (e as num).toInt()).toList()
        : <int>[0];
    return WallSegment(
      id: j['id'] as String,
      points: pts,
      chainStarts: starts,
      heightMm: (j['heightMm'] as num).toDouble(),
      method: WallMethod.fromJson(j['method'] as Map<String, dynamic>),
      quantities: (j['quantities'] as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, (v as num).toDouble())),
      highlightArgb: j['highlightArgb'] as int?,
      strokeWidth: (j['strokeWidth'] as num?)?.toDouble() ?? 8,
      triadQuarterTurns: (turns ?? 0) % 4,
      // 旧データ（キーなし）は試算対象とみなす
      estimateReady: j.containsKey('estimateReady')
          ? (j['estimateReady'] as bool? ?? false)
          : true,
      ironPlateMeasured: _jsonBool(j['ironPlateMeasured']),
    );
  }
}

/// 試算表の保存区分
enum EstimateSheetKind { board, lgs, cross, drop }

extension EstimateSheetKindX on EstimateSheetKind {
  String get label => switch (this) {
        EstimateSheetKind.board => 'ボード試算表',
        EstimateSheetKind.lgs => 'LGS試算表',
        EstimateSheetKind.cross => 'クロス試算表',
        EstimateSheetKind.drop => '下り試算表',
      };
  String get shortLabel => switch (this) {
        EstimateSheetKind.board => 'ボード',
        EstimateSheetKind.lgs => 'LGS',
        EstimateSheetKind.cross => 'クロス',
        EstimateSheetKind.drop => '下り',
      };
}

/// 試算表保存結果
class EstimateSaveResult {
  EstimateSaveResult({required this.kind, required this.lines});
  final EstimateSheetKind kind;
  final List<EstimateLine> lines;
}

/// 試算表の1行
class EstimateLine {
  String id;
  String name;
  String spec;
  /// 注文書 L/W：スタッド長さ / ボード寸法（2×6 等）
  String lw;
  double lengthMm; // L 1000〜15000（板などは 0）
  double qty;
  String unit;
  double subtotal; // 小計
  double wastePercent; // 折損率 %
  String note;
  /// 壁高さ (mm)。異なる高さは試算合算時に分けて表示
  double wallHeightMm;
  /// 図面線番号（1始まり。0＝なし）
  int wallLineNumber;
  /// 線色 ARGB（番号表示用）
  int? wallLineColorArgb;
  /// 保存時の発生源：wall / ceiling / drop / cross
  String areaKind;

  EstimateLine({
    required this.id,
    required this.name,
    required this.spec,
    this.lw = '',
    this.lengthMm = 0,
    required this.qty,
    required this.unit,
    required this.subtotal,
    this.wastePercent = 0,
    this.note = '',
    this.wallHeightMm = 0,
    this.wallLineNumber = 0,
    this.wallLineColorArgb,
    this.areaKind = '',
  });

  /// ①②③…（21以上は (n)）
  static String circledLineNumber(int n) {
    if (n >= 1 && n <= 20) {
      return String.fromCharCode(0x245F + n);
    }
    if (n > 0) return '($n)';
    return '';
  }

  /// 合計 = 小計 × (1 + 折損率%)
  double get total => subtotal * (1 + wastePercent / 100.0);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'spec': spec,
        'lw': lw,
        'lengthMm': lengthMm,
        'qty': qty,
        'unit': unit,
        'subtotal': subtotal,
        'wastePercent': wastePercent,
        'note': note,
        'wallHeightMm': wallHeightMm,
        'wallLineNumber': wallLineNumber,
        'wallLineColorArgb': wallLineColorArgb,
        'areaKind': areaKind,
      };

  factory EstimateLine.fromJson(Map<String, dynamic> j) => EstimateLine(
        id: j['id'] as String,
        name: j['name'] as String? ?? '',
        spec: j['spec'] as String? ?? '',
        lw: j['lw'] as String? ?? '',
        lengthMm: (j['lengthMm'] as num?)?.toDouble() ?? 0,
        qty: (j['qty'] as num?)?.toDouble() ?? 0,
        unit: j['unit'] as String? ?? '',
        subtotal: (j['subtotal'] as num?)?.toDouble() ?? 0,
        wastePercent: (j['wastePercent'] as num?)?.toDouble() ?? 0,
        note: j['note'] as String? ?? '',
        wallHeightMm: (j['wallHeightMm'] as num?)?.toDouble() ?? 0,
        wallLineNumber: (j['wallLineNumber'] as num?)?.toInt() ?? 0,
        wallLineColorArgb: (j['wallLineColorArgb'] as num?)?.toInt(),
        areaKind: j['areaKind'] as String? ?? '',
      );
}

/// 簡易 Offset（models 層で flutter 依存を避ける）
class OffsetLike {
  final double dx;
  final double dy;
  const OffsetLike(this.dx, this.dy);
  double get length => (dx * dx + dy * dy) <= 0 ? 0 : _sqrt(dx * dx + dy * dy);
  static double _sqrt(double v) {
    var x = v;
    if (x <= 0) return 0;
    var guess = x / 2;
    for (var i = 0; i < 12; i++) {
      guess = 0.5 * (guess + x / guess);
    }
    return guess;
  }
}

class CeilingRegion {
  final String id;
  final List<Point2> points;
  final CeilingMethod method;
  final Map<String, double> quantities;
  /// 塗りつぶし色（ARGB）
  final int? highlightArgb;
  /// 表示・積算用の番号（統合同じ番号／非統合は連番）
  final int groupNumber;

  CeilingRegion({
    required this.id,
    required this.points,
    required this.method,
    required this.quantities,
    this.highlightArgb,
    this.groupNumber = 1,
  });

  CeilingRegion copyWith({
    List<Point2>? points,
    CeilingMethod? method,
    Map<String, double>? quantities,
    int? highlightArgb,
    int? groupNumber,
  }) =>
      CeilingRegion(
        id: id,
        points: points ?? this.points,
        method: method ?? this.method,
        quantities: quantities ?? this.quantities,
        highlightArgb: highlightArgb ?? this.highlightArgb,
        groupNumber: groupNumber ?? this.groupNumber,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'points': points.map((p) => p.toJson()).toList(),
        'method': method.toJson(),
        'quantities': quantities,
        'highlightArgb': highlightArgb,
        'groupNumber': groupNumber,
      };

  factory CeilingRegion.fromJson(Map<String, dynamic> j) => CeilingRegion(
        id: j['id'] as String,
        points: (j['points'] as List)
            .map((e) => Point2.fromJson(e as Map<String, dynamic>))
            .toList(),
        method: CeilingMethod.fromJson(j['method'] as Map<String, dynamic>),
        quantities: (j['quantities'] as Map<String, dynamic>)
            .map((k, v) => MapEntry(k, (v as num).toDouble())),
        highlightArgb: (j['highlightArgb'] as num?)?.toInt(),
        groupNumber: (j['groupNumber'] as num?)?.toInt() ?? 1,
      );
}

/// 開口補強の材料
enum OpeningMaterialKind { runner, reinforce }

extension OpeningMaterialKindX on OpeningMaterialKind {
  String get label =>
      this == OpeningMaterialKind.runner ? 'ランナー' : '補強材';
}

/// 図面上の壁開口補強マーカー
class WallOpening {
  final String id;
  final Point2 a;
  final Point2 b;
  final int highlightArgb;
  final double markerSize;
  /// OpeningReinforcePattern.name
  final String patternName;
  final OpeningMaterialKind material;
  final double heightMm;
  final double widthMm;
  final int magusaSegments;
  final String? wallId;

  const WallOpening({
    required this.id,
    required this.a,
    required this.b,
    required this.highlightArgb,
    this.markerSize = 16,
    this.patternName = 'redHOrange',
    this.material = OpeningMaterialKind.reinforce,
    this.heightMm = 2100,
    this.widthMm = 900,
    this.magusaSegments = 1,
    this.wallId,
  });

  WallOpening copyWith({
    Point2? a,
    Point2? b,
    int? highlightArgb,
    double? markerSize,
    String? patternName,
    OpeningMaterialKind? material,
    double? heightMm,
    double? widthMm,
    int? magusaSegments,
    String? wallId,
    bool clearWallId = false,
  }) =>
      WallOpening(
        id: id,
        a: a ?? this.a,
        b: b ?? this.b,
        highlightArgb: highlightArgb ?? this.highlightArgb,
        markerSize: markerSize ?? this.markerSize,
        patternName: patternName ?? this.patternName,
        material: material ?? this.material,
        heightMm: heightMm ?? this.heightMm,
        widthMm: widthMm ?? this.widthMm,
        magusaSegments: magusaSegments ?? this.magusaSegments,
        wallId: clearWallId ? null : (wallId ?? this.wallId),
      );

  double get areaM2 => (widthMm / 1000.0) * (heightMm / 1000.0);

  Map<String, dynamic> toJson() => {
        'id': id,
        'a': a.toJson(),
        'b': b.toJson(),
        'highlightArgb': highlightArgb,
        'markerSize': markerSize,
        'patternName': patternName,
        'material': material.name,
        'heightMm': heightMm,
        'widthMm': widthMm,
        'magusaSegments': magusaSegments,
        'wallId': wallId,
      };

  factory WallOpening.fromJson(Map<String, dynamic> j) {
    final matName = j['material'] as String? ?? 'reinforce';
    final material = OpeningMaterialKind.values.any((e) => e.name == matName)
        ? OpeningMaterialKind.values.byName(matName)
        : OpeningMaterialKind.reinforce;
    final seg = (j['magusaSegments'] as num?)?.toInt() ?? 1;
    return WallOpening(
      id: j['id'] as String,
      a: Point2.fromJson(j['a'] as Map<String, dynamic>),
      b: Point2.fromJson(j['b'] as Map<String, dynamic>),
      highlightArgb: (j['highlightArgb'] as num?)?.toInt() ?? 0xFFFFEB3B,
      markerSize: (j['markerSize'] as num?)?.toDouble() ?? 16,
      patternName: j['patternName'] as String? ?? 'redHOrange',
      material: material,
      heightMm: (j['heightMm'] as num?)?.toDouble() ?? 2100,
      widthMm: (j['widthMm'] as num?)?.toDouble() ?? 900,
      magusaSegments: seg.clamp(1, 4),
      wallId: j['wallId'] as String?,
    );
  }
}

/// 下り形状
enum DropShape { lType, beam }

extension DropShapeX on DropShape {
  String get label => switch (this) {
        DropShape.lType => 'L型下り',
        DropShape.beam => '梁型下り',
      };
  static DropShape parse(String? name) {
    switch (name) {
      case 'beam':
        return DropShape.beam;
      default:
        return DropShape.lType;
    }
  }
}

/// 下り工法設定
class DropMethod {
  final DropShape shape;
  final CeilingSystemKind system;
  // SQ
  final double runnerWidthMm;
  final double runnerLengthMm;
  final String studType;
  final double pitchMm;
  final double studWidthMm;
  final double studLengthMm;
  // 在来
  final double runnerHeightMm;
  final double wBarHeightMm;
  final double wBarLengthMm;
  final double singleBarHeightMm;
  final double singleBarLengthMm;
  final double channelWidthMm;
  final double channelLengthMm;
  /// Wクリップ用 野縁受け幅 (mm) 19 / 25 / 38 / 40
  final double wClipUkeWidthMm;
  /// シングルクリップ用 野縁受け幅 (mm) 19 / 25 / 38 / 40
  final double singleClipUkeWidthMm;
  /// 下り仕上げボード（品名は日文のまま）
  final List<CeilingFinishBoardLayer> boards;

  /// ランナー幅20mm は Wバー／シングルバー 19mm と対標
  static double barHeightForRunner(double runnerMm) =>
      runnerMm == 20 ? 19 : runnerMm;

  static double runnerWidthForBar(double barMm) =>
      barMm == 19 ? 20 : barMm;

  static bool runnerMatchesBar(double runnerMm, double barMm) =>
      runnerMm == barMm || (barMm == 19 && runnerMm == 20);

  static double normalizeBarHeight(double mm) => mm == 20 ? 19 : mm;

  static double normalizeRunnerHeight(double mm) => mm == 19 ? 20 : mm;

  const DropMethod({
    this.shape = DropShape.lType,
    this.system = CeilingSystemKind.sq,
    this.runnerWidthMm = 45,
    this.runnerLengthMm = 4000,
    this.studType = '4045',
    this.pitchMm = 303,
    this.studWidthMm = 45,
    this.studLengthMm = 2800,
    this.runnerHeightMm = 20,
    this.wBarHeightMm = 19,
    this.wBarLengthMm = 4000,
    this.singleBarHeightMm = 19,
    this.singleBarLengthMm = 4000,
    this.channelWidthMm = 38,
    this.channelLengthMm = 4000,
    this.wClipUkeWidthMm = 38,
    this.singleClipUkeWidthMm = 38,
    this.boards = const [CeilingFinishBoardLayer()],
  });

  DropMethod copyWith({
    DropShape? shape,
    CeilingSystemKind? system,
    double? runnerWidthMm,
    double? runnerLengthMm,
    String? studType,
    double? pitchMm,
    double? studWidthMm,
    double? studLengthMm,
    double? runnerHeightMm,
    double? wBarHeightMm,
    double? wBarLengthMm,
    double? singleBarHeightMm,
    double? singleBarLengthMm,
    double? channelWidthMm,
    double? channelLengthMm,
    double? wClipUkeWidthMm,
    double? singleClipUkeWidthMm,
    List<CeilingFinishBoardLayer>? boards,
  }) =>
      DropMethod(
        shape: shape ?? this.shape,
        system: system ?? this.system,
        runnerWidthMm: runnerWidthMm ?? this.runnerWidthMm,
        runnerLengthMm: runnerLengthMm ?? this.runnerLengthMm,
        studType: studType ?? this.studType,
        pitchMm: pitchMm ?? this.pitchMm,
        studWidthMm: studWidthMm ?? this.studWidthMm,
        studLengthMm: studLengthMm ?? this.studLengthMm,
        runnerHeightMm: runnerHeightMm ?? this.runnerHeightMm,
        wBarHeightMm: wBarHeightMm ?? this.wBarHeightMm,
        wBarLengthMm: wBarLengthMm ?? this.wBarLengthMm,
        singleBarHeightMm: singleBarHeightMm ?? this.singleBarHeightMm,
        singleBarLengthMm: singleBarLengthMm ?? this.singleBarLengthMm,
        channelWidthMm: channelWidthMm ?? this.channelWidthMm,
        channelLengthMm: channelLengthMm ?? this.channelLengthMm,
        wClipUkeWidthMm: wClipUkeWidthMm ?? this.wClipUkeWidthMm,
        singleClipUkeWidthMm: singleClipUkeWidthMm ?? this.singleClipUkeWidthMm,
        boards: boards ?? this.boards,
      );

  Map<String, dynamic> toJson() => {
        'shape': shape.name,
        'system': system.name,
        'runnerWidthMm': runnerWidthMm,
        'runnerLengthMm': runnerLengthMm,
        'studType': studType,
        'pitchMm': pitchMm,
        'studWidthMm': studWidthMm,
        'studLengthMm': studLengthMm,
        'runnerHeightMm': runnerHeightMm,
        'wBarHeightMm': wBarHeightMm,
        'wBarLengthMm': wBarLengthMm,
        'singleBarHeightMm': singleBarHeightMm,
        'singleBarLengthMm': singleBarLengthMm,
        'channelWidthMm': channelWidthMm,
        'channelLengthMm': channelLengthMm,
        'wClipUkeWidthMm': wClipUkeWidthMm,
        'singleClipUkeWidthMm': singleClipUkeWidthMm,
        'boards': boards.map((e) => e.toJson()).toList(),
      };

  factory DropMethod.fromJson(Map<String, dynamic> j) {
    final rawBoards = j['boards'];
    final boards = rawBoards is List
        ? [
            for (final e in rawBoards)
              if (e is Map)
                CeilingFinishBoardLayer.fromJson(
                  Map<String, dynamic>.from(e),
                ),
          ]
        : const [CeilingFinishBoardLayer()];
    return DropMethod(
        shape: DropShapeX.parse(j['shape'] as String?),
        system: (j['system'] as String?) == 'zairai'
            ? CeilingSystemKind.zairai
            : CeilingSystemKind.sq,
        runnerWidthMm: (j['runnerWidthMm'] as num?)?.toDouble() ?? 45,
        runnerLengthMm: (j['runnerLengthMm'] as num?)?.toDouble() ?? 4000,
        studType: j['studType'] as String? ?? '4045',
        pitchMm: (j['pitchMm'] as num?)?.toDouble() ?? 303,
        studWidthMm: (j['studWidthMm'] as num?)?.toDouble() ?? 45,
        studLengthMm: (j['studLengthMm'] as num?)?.toDouble() ?? 2800,
        runnerHeightMm: DropMethod.normalizeRunnerHeight(
          (j['runnerHeightMm'] as num?)?.toDouble() ?? 20,
        ),
        wBarHeightMm: DropMethod.normalizeBarHeight(
          (j['wBarHeightMm'] as num?)?.toDouble() ?? 19,
        ),
        wBarLengthMm: (j['wBarLengthMm'] as num?)?.toDouble() ?? 4000,
        singleBarHeightMm: DropMethod.normalizeBarHeight(
          (j['singleBarHeightMm'] as num?)?.toDouble() ?? 19,
        ),
        singleBarLengthMm: (j['singleBarLengthMm'] as num?)?.toDouble() ?? 4000,
        channelWidthMm: (j['channelWidthMm'] as num?)?.toDouble() ?? 38,
        channelLengthMm: (j['channelLengthMm'] as num?)?.toDouble() ?? 4000,
        wClipUkeWidthMm: (j['wClipUkeWidthMm'] as num?)?.toDouble() ?? 38,
        singleClipUkeWidthMm:
            (j['singleClipUkeWidthMm'] as num?)?.toDouble() ?? 38,
        boards: boards,
      );
  }
}

/// 下り幅の表示ラベル（①幅・②幅…）
String dropWidthCircleLabel(int n) {
  const circled = ['①', '②', '③', '④', '⑤', '⑥', '⑦', '⑧', '⑨', '⑩'];
  if (n >= 1 && n <= circled.length) return '${circled[n - 1]}幅';
  return '$n幅';
}

/// turnIndex（2,3,4…）→ 表示番号（②③④…）。第1幅は別途 1。
int dropWidthDisplayNumber(int turnIndex) => turnIndex;

/// 第 n 折点（vertex index≥2）以降に測る追加幅
class DropTurnWidth {
  final int turnIndex;
  final double widthMm;
  final Point2? from;
  final Point2? to;

  const DropTurnWidth({
    required this.turnIndex,
    required this.widthMm,
    this.from,
    this.to,
  });

  DropTurnWidth copyWith({
    double? widthMm,
    Point2? from,
    Point2? to,
  }) =>
      DropTurnWidth(
        turnIndex: turnIndex,
        widthMm: widthMm ?? this.widthMm,
        from: from ?? this.from,
        to: to ?? this.to,
      );

  Map<String, dynamic> toJson() => {
        'turnIndex': turnIndex,
        'widthMm': widthMm,
        if (from != null) 'from': from!.toJson(),
        if (to != null) 'to': to!.toJson(),
      };

  factory DropTurnWidth.fromJson(Map<String, dynamic> j) => DropTurnWidth(
        turnIndex: (j['turnIndex'] as num?)?.toInt() ?? 2,
        widthMm: (j['widthMm'] as num?)?.toDouble() ?? 0,
        from: j['from'] is Map
            ? Point2.fromJson(Map<String, dynamic>.from(j['from'] as Map))
            : null,
        to: j['to'] is Map
            ? Point2.fromJson(Map<String, dynamic>.from(j['to'] as Map))
            : null,
      );
}

/// 図面上の下り（折れ線：始点→第1折＝幅、以降＝長さ。第2折以降は＋で追加幅）
class DropRegion {
  final String id;
  final List<Point2> points;
  final double lengthMm;
  final double widthMm;
  final double heightMm;
  /// 第2折・第3折・第4折…ごとの追加幅
  final List<DropTurnWidth> turnWidths;
  final DropMethod method;
  final Map<String, double> quantities;
  final int? highlightArgb;
  final int groupNumber;

  DropRegion({
    required this.id,
    required this.points,
    required this.lengthMm,
    required this.widthMm,
    required this.heightMm,
    this.turnWidths = const [],
    this.method = const DropMethod(),
    this.quantities = const {},
    this.highlightArgb,
    this.groupNumber = 1,
  });

  double get secondWidthMm {
    for (final t in turnWidths) {
      if (t.turnIndex == 2) return t.widthMm;
    }
    return 0;
  }

  DropRegion copyWith({
    List<Point2>? points,
    double? lengthMm,
    double? widthMm,
    double? heightMm,
    List<DropTurnWidth>? turnWidths,
    DropMethod? method,
    Map<String, double>? quantities,
    int? highlightArgb,
    int? groupNumber,
  }) =>
      DropRegion(
        id: id,
        points: points ?? this.points,
        lengthMm: lengthMm ?? this.lengthMm,
        widthMm: widthMm ?? this.widthMm,
        heightMm: heightMm ?? this.heightMm,
        turnWidths: turnWidths ?? this.turnWidths,
        method: method ?? this.method,
        quantities: quantities ?? this.quantities,
        highlightArgb: highlightArgb ?? this.highlightArgb,
        groupNumber: groupNumber ?? this.groupNumber,
      );

  /// 同一 turnIndex を上書き／追加
  DropRegion withTurnWidth(DropTurnWidth tw) {
    final next = <DropTurnWidth>[
      for (final t in turnWidths)
        if (t.turnIndex != tw.turnIndex) t,
      tw,
    ]..sort((a, b) => a.turnIndex.compareTo(b.turnIndex));
    return copyWith(turnWidths: next);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'points': points.map((e) => e.toJson()).toList(),
        'lengthMm': lengthMm,
        'widthMm': widthMm,
        'heightMm': heightMm,
        'turnWidths': turnWidths.map((e) => e.toJson()).toList(),
        'method': method.toJson(),
        'quantities': quantities,
        'highlightArgb': highlightArgb,
        'groupNumber': groupNumber,
      };

  factory DropRegion.fromJson(Map<String, dynamic> j) {
    var turns = <DropTurnWidth>[
      for (final e in (j['turnWidths'] as List? ?? const []))
        DropTurnWidth.fromJson(e as Map<String, dynamic>),
    ];
    // 旧フィールド互換
    if (turns.isEmpty) {
      final w2 = (j['secondWidthMm'] as num?)?.toDouble() ?? 0;
      if (w2 > 0) {
        turns = [
          DropTurnWidth(
            turnIndex: 2,
            widthMm: w2,
            from: j['secondWidthFrom'] is Map
                ? Point2.fromJson(
                    Map<String, dynamic>.from(j['secondWidthFrom'] as Map),
                  )
                : null,
            to: j['secondWidthTo'] is Map
                ? Point2.fromJson(
                    Map<String, dynamic>.from(j['secondWidthTo'] as Map),
                  )
                : null,
          ),
        ];
      }
    }
    return DropRegion(
      id: j['id'] as String,
      points: [
        for (final e in (j['points'] as List? ?? const []))
          Point2.fromJson(e as Map<String, dynamic>),
      ],
      lengthMm: (j['lengthMm'] as num?)?.toDouble() ?? 0,
      widthMm: (j['widthMm'] as num?)?.toDouble() ?? 0,
      heightMm: (j['heightMm'] as num?)?.toDouble() ?? 0,
      turnWidths: turns,
      method: DropMethod.fromJson(
        j['method'] is Map
            ? Map<String, dynamic>.from(j['method'] as Map)
            : const {},
      ),
      quantities: (j['quantities'] as Map?)
              ?.map((k, v) => MapEntry(k.toString(), (v as num).toDouble())) ??
          const {},
      highlightArgb: j['highlightArgb'] as int?,
      groupNumber: (j['groupNumber'] as num?)?.toInt() ?? 1,
    );
  }
}

/// 測定セッション
class Measurement {
  final String id;
  final String projectId;
  final String drawingId;
  final String name;
  final List<WallSegment> walls;
  final List<CeilingRegion> ceilings;
  /// 開口補強（壁画線より先に配置）
  final List<WallOpening> openings;
  /// 下り天井
  final List<DropRegion> drops;
  /// 保存済みボード試算表
  final List<EstimateLine> boardEstimate;
  /// 保存済み LGS 試算表
  final List<EstimateLine> lgsEstimate;
  /// 保存済みクロス試算表
  final List<EstimateLine> crossEstimate;
  /// 保存済み下り試算表
  final List<EstimateLine> dropEstimate;
  /// 保存済み天井ボード試算表
  final List<EstimateLine> ceilingBoardEstimate;
  /// 保存済み天井 LGS 試算表
  final List<EstimateLine> ceilingLgsEstimate;
  final DateTime createdAt;
  final DateTime updatedAt;

  Measurement({
    required this.id,
    required this.projectId,
    required this.drawingId,
    required this.name,
    this.walls = const [],
    this.ceilings = const [],
    this.openings = const [],
    this.drops = const [],
    this.boardEstimate = const [],
    this.lgsEstimate = const [],
    this.crossEstimate = const [],
    this.dropEstimate = const [],
    this.ceilingBoardEstimate = const [],
    this.ceilingLgsEstimate = const [],
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Measurement copyWith({
    List<WallSegment>? walls,
    List<CeilingRegion>? ceilings,
    List<WallOpening>? openings,
    List<DropRegion>? drops,
    List<EstimateLine>? boardEstimate,
    List<EstimateLine>? lgsEstimate,
    List<EstimateLine>? crossEstimate,
    List<EstimateLine>? dropEstimate,
    List<EstimateLine>? ceilingBoardEstimate,
    List<EstimateLine>? ceilingLgsEstimate,
    DateTime? updatedAt,
  }) =>
      Measurement(
        id: id,
        projectId: projectId,
        drawingId: drawingId,
        name: name,
        walls: walls ?? this.walls,
        ceilings: ceilings ?? this.ceilings,
        openings: openings ?? this.openings,
        drops: drops ?? this.drops,
        boardEstimate: boardEstimate ?? this.boardEstimate,
        lgsEstimate: lgsEstimate ?? this.lgsEstimate,
        crossEstimate: crossEstimate ?? this.crossEstimate,
        dropEstimate: dropEstimate ?? this.dropEstimate,
        ceilingBoardEstimate:
            ceilingBoardEstimate ?? this.ceilingBoardEstimate,
        ceilingLgsEstimate: ceilingLgsEstimate ?? this.ceilingLgsEstimate,
        createdAt: createdAt,
        updatedAt: updatedAt ?? DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'project_id': projectId,
        'drawing_id': drawingId,
        'name': name,
        'walls_json': jsonEncode(walls.map((e) => e.toJson()).toList()),
        'ceilings_json': jsonEncode(ceilings.map((e) => e.toJson()).toList()),
        'openings_json': jsonEncode(openings.map((e) => e.toJson()).toList()),
        'drops_json': jsonEncode(drops.map((e) => e.toJson()).toList()),
        'board_estimate_json':
            jsonEncode(boardEstimate.map((e) => e.toJson()).toList()),
        'lgs_estimate_json':
            jsonEncode(lgsEstimate.map((e) => e.toJson()).toList()),
        'cross_estimate_json':
            jsonEncode(crossEstimate.map((e) => e.toJson()).toList()),
        'drop_estimate_json':
            jsonEncode(dropEstimate.map((e) => e.toJson()).toList()),
        'ceiling_board_estimate_json':
            jsonEncode(ceilingBoardEstimate.map((e) => e.toJson()).toList()),
        'ceiling_lgs_estimate_json':
            jsonEncode(ceilingLgsEstimate.map((e) => e.toJson()).toList()),
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory Measurement.fromMap(Map<String, dynamic> m) {
    final wallsRaw = jsonDecode(m['walls_json'] as String? ?? '[]') as List;
    final ceilingsRaw =
        jsonDecode(m['ceilings_json'] as String? ?? '[]') as List;
    final openingsRaw =
        jsonDecode(m['openings_json'] as String? ?? '[]') as List;
    final dropsRaw = jsonDecode(m['drops_json'] as String? ?? '[]') as List;
    final boardRaw =
        jsonDecode(m['board_estimate_json'] as String? ?? '[]') as List;
    final lgsRaw =
        jsonDecode(m['lgs_estimate_json'] as String? ?? '[]') as List;
    final crossRaw =
        jsonDecode(m['cross_estimate_json'] as String? ?? '[]') as List;
    final dropEstRaw =
        jsonDecode(m['drop_estimate_json'] as String? ?? '[]') as List;
    final ceilBoardRaw = jsonDecode(
          m['ceiling_board_estimate_json'] as String? ?? '[]',
        ) as List;
    final ceilLgsRaw = jsonDecode(
          m['ceiling_lgs_estimate_json'] as String? ?? '[]',
        ) as List;
    return Measurement(
      id: m['id'] as String,
      projectId: m['project_id'] as String,
      drawingId: m['drawing_id'] as String,
      name: m['name'] as String,
      walls: wallsRaw
          .map((e) => WallSegment.fromJson(e as Map<String, dynamic>))
          .toList(),
      ceilings: ceilingsRaw
          .map((e) => CeilingRegion.fromJson(e as Map<String, dynamic>))
          .toList(),
      openings: openingsRaw
          .map((e) => WallOpening.fromJson(e as Map<String, dynamic>))
          .toList(),
      drops: dropsRaw
          .map((e) => DropRegion.fromJson(e as Map<String, dynamic>))
          .toList(),
      boardEstimate: boardRaw
          .map((e) => EstimateLine.fromJson(e as Map<String, dynamic>))
          .toList(),
      lgsEstimate: lgsRaw
          .map((e) => EstimateLine.fromJson(e as Map<String, dynamic>))
          .toList(),
      crossEstimate: crossRaw
          .map((e) => EstimateLine.fromJson(e as Map<String, dynamic>))
          .toList(),
      dropEstimate: dropEstRaw
          .map((e) => EstimateLine.fromJson(e as Map<String, dynamic>))
          .toList(),
      ceilingBoardEstimate: ceilBoardRaw
          .map((e) => EstimateLine.fromJson(e as Map<String, dynamic>))
          .toList(),
      ceilingLgsEstimate: ceilLgsRaw
          .map((e) => EstimateLine.fromJson(e as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.parse(m['created_at'] as String),
      updatedAt: DateTime.parse(m['updated_at'] as String),
    );
  }
}

/// 注文明細行
class OrderLine {
  final String id;
  final String name;
  final String unit;
  final double qty;
  final String? note;
  final bool isManual;

  OrderLine({
    required this.id,
    required this.name,
    required this.unit,
    required this.qty,
    this.note,
    this.isManual = false,
  });

  OrderLine copyWith({double? qty, String? name, String? note}) => OrderLine(
        id: id,
        name: name ?? this.name,
        unit: unit,
        qty: qty ?? this.qty,
        note: note ?? this.note,
        isManual: isManual,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'unit': unit,
        'qty': qty,
        'note': note,
        'isManual': isManual,
      };

  factory OrderLine.fromJson(Map<String, dynamic> j) => OrderLine(
        id: j['id'] as String,
        name: j['name'] as String,
        unit: j['unit'] as String,
        qty: (j['qty'] as num).toDouble(),
        note: j['note'] as String?,
        isManual: j['isManual'] as bool? ?? false,
      );
}

class MaterialOrder {
  final String id;
  final String projectId;
  final List<String> measurementIds;
  final DateTime orderDate;
  final DateTime deliveryDate;
  final List<OrderLine> lines;
  final DateTime createdAt;

  MaterialOrder({
    required this.id,
    required this.projectId,
    required this.measurementIds,
    required this.orderDate,
    required this.deliveryDate,
    required this.lines,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'project_id': projectId,
        'measurement_ids': jsonEncode(measurementIds),
        'order_date': orderDate.toIso8601String(),
        'delivery_date': deliveryDate.toIso8601String(),
        'lines_json': jsonEncode(lines.map((e) => e.toJson()).toList()),
        'created_at': createdAt.toIso8601String(),
      };

  factory MaterialOrder.fromMap(Map<String, dynamic> m) => MaterialOrder(
        id: m['id'] as String,
        projectId: m['project_id'] as String,
        measurementIds: (jsonDecode(m['measurement_ids'] as String) as List)
            .map((e) => e as String)
            .toList(),
        orderDate: DateTime.parse(m['order_date'] as String),
        deliveryDate: DateTime.parse(m['delivery_date'] as String),
        lines: (jsonDecode(m['lines_json'] as String) as List)
            .map((e) => OrderLine.fromJson(e as Map<String, dynamic>))
            .toList(),
        createdAt: DateTime.parse(m['created_at'] as String),
      );
}
