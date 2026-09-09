import 'dart:convert';
import 'dart:math' as math;

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
  }) : createdAt = createdAt ?? DateTime.now();

  AppUser copyWith({
    String? passwordHash,
    bool? activated,
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
      };

  factory AppUser.fromMap(Map<String, dynamic> m) => AppUser(
        id: m['id'] as String,
        companyName: m['company_name'] as String,
        address: m['address'] as String,
        contactName: m['contact_name'] as String,
        phone: m['phone'] as String,
        email: m['email'] as String,
        passwordHash: m['password_hash'] as String?,
        activated: (m['activated'] as int? ?? 0) == 1,
        createdAt: DateTime.parse(m['created_at'] as String),
      );
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
  /// 鉄板段数（0＝なし／測定延長のみ。2〜7＝延長×段数）
  final int ironPlateSegments;
  /// 開口補強材（スタッド同寸）
  final bool useReinforceMaterial;
  /// 補強材幅 (mm)＝スタッド幅相当
  final double reinforceWidthMm;
  /// 補強材定尺長さ (mm)＝スタッド長さ相当
  final double reinforceLengthMm;
  /// ケイカルボード
  final bool useKeikal;
  final double keikalThicknessMm;
  final BoardSize keikalBoardSize;
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
    this.ironPlateSegments = 0,
    this.useReinforceMaterial = false,
    this.reinforceWidthMm = 45,
    this.reinforceLengthMm = 3000,
    this.useKeikal = false,
    this.keikalThicknessMm = 6,
    this.keikalBoardSize = BoardSize.size36,
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
    bool? useKeikal,
    double? keikalThicknessMm,
    BoardSize? keikalBoardSize,
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
      useKeikal: useKeikal ?? this.useKeikal,
      keikalThicknessMm: keikalThicknessMm ?? this.keikalThicknessMm,
      keikalBoardSize: keikalBoardSize ?? this.keikalBoardSize,
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
        'useKeikal': useKeikal,
        'keikalThicknessMm': keikalThicknessMm,
        'keikalBoardSize': keikalBoardSize.name,
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
      useIronPlate: j['useIronPlate'] as bool? ?? false,
      ironPlateWidthMm: (j['ironPlateWidthMm'] as num?)?.toDouble() ?? 300,
      ironPlateLengthMm: (j['ironPlateLengthMm'] as num?)?.toDouble() ?? 1820,
      ironPlateSegments: () {
        final n = (j['ironPlateSegments'] as num?)?.toInt() ?? 0;
        if (n >= 2 && n <= 7) return n;
        return 0;
      }(),
      useReinforceMaterial: j['useReinforceMaterial'] as bool? ?? false,
      reinforceWidthMm: (j['reinforceWidthMm'] as num?)?.toDouble() ?? 45,
      reinforceLengthMm: (j['reinforceLengthMm'] as num?)?.toDouble() ?? 3000,
      useKeikal: j['useKeikal'] as bool? ?? false,
      keikalThicknessMm: (j['keikalThicknessMm'] as num?)?.toDouble() ?? 6,
      keikalBoardSize: () {
        final name = j['keikalBoardSize'] as String? ?? 'size36';
        return BoardSize.values.any((e) => e.name == name)
            ? BoardSize.values.byName(name)
            : BoardSize.size36;
      }(),
      presetId: j['presetId'] as String?,
      detectedWallThicknessMm:
          (j['detectedWallThicknessMm'] as num?)?.toDouble(),
    );
  }
}

/// 天井工法パラメータ
class CeilingMethod {
  final double noenSpacingMm;
  final double noenuKeSpacingMm;
  final BoardSize boardSize;
  final BoardLayers layers;
  final bool rotated90;

  const CeilingMethod({
    this.noenSpacingMm = 303,
    this.noenuKeSpacingMm = 910,
    this.boardSize = BoardSize.size36,
    this.layers = BoardLayers.single,
    this.rotated90 = false,
  });

  Map<String, dynamic> toJson() => {
        'noenSpacingMm': noenSpacingMm,
        'noenuKeSpacingMm': noenuKeSpacingMm,
        'boardSize': boardSize.name,
        'layers': layers.name,
        'rotated90': rotated90,
      };

  factory CeilingMethod.fromJson(Map<String, dynamic> j) {
    final layersName = j['layers'] as String? ?? 'single';
    final layers = BoardLayers.values.any((e) => e.name == layersName)
        ? BoardLayers.values.byName(layersName)
        : BoardLayers.single;
    return CeilingMethod(
        noenSpacingMm: (j['noenSpacingMm'] as num?)?.toDouble() ?? 303,
        noenuKeSpacingMm: (j['noenuKeSpacingMm'] as num?)?.toDouble() ?? 910,
        boardSize: () {
          final name = j['boardSize'] as String? ?? 'size36';
          return BoardSize.values.any((e) => e.name == name)
              ? BoardSize.values.byName(name)
              : BoardSize.size36;
        }(),
        layers: layers,
        rotated90: j['rotated90'] as bool? ?? false,
      );
  }

  CeilingMethod copyWith({bool? rotated90}) => CeilingMethod(
        noenSpacingMm: noenSpacingMm,
        noenuKeSpacingMm: noenuKeSpacingMm,
        boardSize: boardSize,
        layers: layers,
        rotated90: rotated90 ?? this.rotated90,
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
  }) : assert(points.length >= 2);

  Point2 get a => points.first;
  Point2 get b => points.last;

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
    );
  }
}

/// 試算表の保存区分（ボード／LGS）
enum EstimateSheetKind { board, lgs }

extension EstimateSheetKindX on EstimateSheetKind {
  String get label => this == EstimateSheetKind.board ? 'ボード試算表' : 'LGS試算表';
  String get shortLabel => this == EstimateSheetKind.board ? 'ボード' : 'LGS';
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

  CeilingRegion({
    required this.id,
    required this.points,
    required this.method,
    required this.quantities,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'points': points.map((p) => p.toJson()).toList(),
        'method': method.toJson(),
        'quantities': quantities,
      };

  factory CeilingRegion.fromJson(Map<String, dynamic> j) => CeilingRegion(
        id: j['id'] as String,
        points: (j['points'] as List)
            .map((e) => Point2.fromJson(e as Map<String, dynamic>))
            .toList(),
        method: CeilingMethod.fromJson(j['method'] as Map<String, dynamic>),
        quantities: (j['quantities'] as Map<String, dynamic>)
            .map((k, v) => MapEntry(k, (v as num).toDouble())),
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
    this.patternName = 'redOrange',
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
      patternName: j['patternName'] as String? ?? 'redOrange',
      material: material,
      heightMm: (j['heightMm'] as num?)?.toDouble() ?? 2100,
      widthMm: (j['widthMm'] as num?)?.toDouble() ?? 900,
      magusaSegments: seg.clamp(1, 4),
      wallId: j['wallId'] as String?,
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
  /// 保存済みボード試算表
  final List<EstimateLine> boardEstimate;
  /// 保存済み LGS 試算表
  final List<EstimateLine> lgsEstimate;
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
    this.boardEstimate = const [],
    this.lgsEstimate = const [],
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Measurement copyWith({
    List<WallSegment>? walls,
    List<CeilingRegion>? ceilings,
    List<WallOpening>? openings,
    List<EstimateLine>? boardEstimate,
    List<EstimateLine>? lgsEstimate,
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
        boardEstimate: boardEstimate ?? this.boardEstimate,
        lgsEstimate: lgsEstimate ?? this.lgsEstimate,
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
        'board_estimate_json':
            jsonEncode(boardEstimate.map((e) => e.toJson()).toList()),
        'lgs_estimate_json':
            jsonEncode(lgsEstimate.map((e) => e.toJson()).toList()),
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory Measurement.fromMap(Map<String, dynamic> m) {
    final wallsRaw = jsonDecode(m['walls_json'] as String? ?? '[]') as List;
    final ceilingsRaw =
        jsonDecode(m['ceilings_json'] as String? ?? '[]') as List;
    final openingsRaw =
        jsonDecode(m['openings_json'] as String? ?? '[]') as List;
    final boardRaw =
        jsonDecode(m['board_estimate_json'] as String? ?? '[]') as List;
    final lgsRaw =
        jsonDecode(m['lgs_estimate_json'] as String? ?? '[]') as List;
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
      boardEstimate: boardRaw
          .map((e) => EstimateLine.fromJson(e as Map<String, dynamic>))
          .toList(),
      lgsEstimate: lgsRaw
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
