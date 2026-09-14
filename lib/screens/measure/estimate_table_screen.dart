import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../widgets/order_estimate_form.dart';

/// 積算確定後の試算表（横画面）
class EstimateTableScreen extends StatelessWidget {
  const EstimateTableScreen({
    super.key,
    required this.title,
    required this.initialLines,
    this.measuredSummary,
    this.projectName,
    this.siteAddress,
    this.sitePhone,
    this.siteContact,
    this.areaLabel = '壁',
    this.areaM2,
    this.lgsAreaM2,
    this.lgsMethodLabel,
    this.boardAreaM2,
    this.boardAreaParts = const [],
    this.rockFeltM,
    this.glassWoolM2,
    this.dropLengthMm,
    this.dropWidthMm,
    this.dropHeightMm,
    this.dropShapeLabel,
    this.dropTurnWidths = const [],
    this.initialFilter,
    this.lockFilter = false,
    this.editable = true,
    this.onSavePersist,
  });

  final String title;
  final List<EstimateLine> initialLines;
  final String? measuredSummary;
  final String? projectName;
  final String? siteAddress;
  final String? sitePhone;
  final String? siteContact;
  final String areaLabel;
  final double? areaM2;
  final double? lgsAreaM2;
  final String? lgsMethodLabel;
  final double? boardAreaM2;
  final List<({String name, double m2})> boardAreaParts;
  final double? rockFeltM;
  final double? glassWoolM2;
  final double? dropLengthMm;
  final double? dropWidthMm;
  final double? dropHeightMm;
  final String? dropShapeLabel;
  final List<DropTurnWidth> dropTurnWidths;
  final EstimateSheetKind? initialFilter;
  final bool lockFilter;
  final bool editable;
  final Future<void> Function(EstimateSaveResult result)? onSavePersist;

  @override
  Widget build(BuildContext context) {
    return OrderEstimateForm(
      lines: initialLines,
      editable: editable,
      appBarTitle: title,
      projectName: projectName,
      siteAddress: siteAddress,
      sitePhone: sitePhone,
      siteContact: siteContact,
      areaLabel: areaLabel,
      areaM2: areaM2,
      lgsAreaM2: lgsAreaM2,
      lgsMethodLabel: lgsMethodLabel,
      boardAreaM2: boardAreaM2,
      boardAreaParts: boardAreaParts,
      rockFeltM: rockFeltM,
      glassWoolM2: glassWoolM2,
      dropLengthMm: dropLengthMm,
      dropWidthMm: dropWidthMm,
      dropHeightMm: dropHeightMm,
      dropShapeLabel: dropShapeLabel,
      dropTurnWidths: dropTurnWidths,
      initialFilter: initialFilter,
      lockFilter: lockFilter,
      onSavePersist: onSavePersist,
    );
  }
}
