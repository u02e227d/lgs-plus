import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/models.dart';

/// 日本建設現場向け注文書 PDF 生成
class PdfOrderExporter {
  static Future<Uint8List> build({
    required AppUser company,
    required SiteProject project,
    required MaterialOrder order,
  }) async {
    final font = await PdfGoogleFonts.iBMPlexSansJPRegular();
    final fontBold = await PdfGoogleFonts.iBMPlexSansJPBold();
    final doc = pw.Document();
    final dateFmt = DateFormat('yyyy年MM月dd日');

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        build: (ctx) => [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                '材料注文書',
                style: pw.TextStyle(font: fontBold, fontSize: 22),
              ),
              pw.Text('LGS+', style: pw.TextStyle(font: font, fontSize: 14)),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Divider(thickness: 1.2),
          pw.SizedBox(height: 12),
          _section(font, fontBold, '発注元（会社情報）', [
            '会社名：${company.companyName}',
            '住所：${company.address}',
            '担当：${company.contactName}',
            'TEL：${company.phone}',
            'Email：${company.email}',
          ]),
          pw.SizedBox(height: 10),
          _section(font, fontBold, '現場情報', [
            '現場名称：${project.name}',
            '住所：${project.address}',
            '現場連絡先：${project.contactName} / ${project.phone}',
          ]),
          pw.SizedBox(height: 10),
          _section(font, fontBold, '日付', [
            '発注日：${dateFmt.format(order.orderDate)}',
            '配送希望日：${dateFmt.format(order.deliveryDate)}',
          ]),
          pw.SizedBox(height: 16),
          pw.Text('明細', style: pw.TextStyle(font: fontBold, fontSize: 14)),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headers: ['No', '品名', '数量', '単位', '備考'],
            data: [
              for (var i = 0; i < order.lines.length; i++)
                [
                  '${i + 1}',
                  order.lines[i].name,
                  order.lines[i].qty.toStringAsFixed(
                    order.lines[i].qty == order.lines[i].qty.roundToDouble()
                        ? 0
                        : 2,
                  ),
                  order.lines[i].unit,
                  order.lines[i].note ?? '',
                ],
            ],
            headerStyle: pw.TextStyle(font: fontBold, fontSize: 10),
            cellStyle: pw.TextStyle(font: font, fontSize: 10),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            cellAlignments: {
              0: pw.Alignment.center,
              2: pw.Alignment.centerRight,
              3: pw.Alignment.center,
            },
            columnWidths: {
              0: const pw.FixedColumnWidth(28),
              1: const pw.FlexColumnWidth(3),
              2: const pw.FixedColumnWidth(50),
              3: const pw.FixedColumnWidth(36),
              4: const pw.FlexColumnWidth(2),
            },
          ),
          pw.SizedBox(height: 24),
          pw.Text(
            '※ 本注文書は LGS+ による自動積算結果です。現場状況に応じて数量を確認してください。',
            style: pw.TextStyle(
              font: font,
              fontSize: 9,
              color: PdfColors.grey700,
            ),
          ),
          pw.SizedBox(height: 28),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('承認印', style: pw.TextStyle(font: font, fontSize: 10)),
                  pw.SizedBox(height: 4),
                  pw.Container(
                    width: 70,
                    height: 70,
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey600),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    return doc.save();
  }

  /// 注文書画面の内容を横向きPDFにする
  static Future<Uint8List> buildOrderDocument({
    required String title,
    required String customer,
    required String siteName,
    required String siteAddress,
    required String receiver,
    required String sitePhone,
    required String companyName,
    required String companyAddress,
    required String companyPhone,
    required String orderNo,
    required String issueDateLabel,
    required String deliveryDateLabel,
    required List<EstimateLine> lines,
  }) async {
    final font = await PdfGoogleFonts.iBMPlexSansJPRegular();
    final fontBold = await PdfGoogleFonts.iBMPlexSansJPBold();
    final doc = pw.Document();

    String qtyOf(EstimateLine e) {
      final q = e.qty;
      return q == q.roundToDouble()
          ? q.toStringAsFixed(0)
          : q.toStringAsFixed(2);
    }

    String sizeOf(EstimateLine e) {
      if (e.lw.isNotEmpty) return e.lw;
      if (e.lengthMm > 0) return e.lengthMm.toStringAsFixed(0);
      return '';
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.fromLTRB(28, 22, 28, 22),
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        build: (ctx) => [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Spacer(),
              pw.Text(
                title.contains('注文書') ? '注文書' : title,
                style: pw.TextStyle(font: fontBold, fontSize: 22),
              ),
              pw.Spacer(),
              pw.Text(
                'No. $orderNo',
                style: pw.TextStyle(font: font, fontSize: 11),
              ),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                flex: 6,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      customer.isEmpty ? '取引先名　　様' : '$customer　様',
                      style: pw.TextStyle(font: fontBold, fontSize: 13),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      '下記の通り注文申し上げます。',
                      style: pw.TextStyle(font: font, fontSize: 10),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      '現場名　　$siteName',
                      style: pw.TextStyle(font: font, fontSize: 10),
                    ),
                    pw.Text(
                      '現場住所　$siteAddress',
                      style: pw.TextStyle(font: font, fontSize: 10),
                    ),
                    pw.Text(
                      '受取者　　$receiver',
                      style: pw.TextStyle(font: font, fontSize: 10),
                    ),
                    pw.Text(
                      '電話番号　$sitePhone',
                      style: pw.TextStyle(font: font, fontSize: 10),
                    ),
                    pw.Text(
                      '納期希望日　$deliveryDateLabel',
                      style: pw.TextStyle(font: font, fontSize: 10),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(width: 16),
              pw.Expanded(
                flex: 5,
                child: pw.Align(
                  alignment: pw.Alignment.topRight,
                  child: pw.SizedBox(
                    width: 220,
                    child: pw.Column(
                      children: [
                        _pdfRightMeta(font, '発行日', issueDateLabel),
                        _pdfRightMeta(font, '会社名', companyName),
                        _pdfRightMeta(
                          font,
                          '住所',
                          companyAddress.isEmpty
                              ? ''
                              : '〒 $companyAddress',
                        ),
                        _pdfRightMeta(font, '電話番号', companyPhone),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            headers: ['No', '品名', 'サイズ', '仕様', '単位', '数量', '備考'],
            data: [
              for (var i = 0; i < lines.length; i++)
                [
                  '${i + 1}',
                  lines[i].name,
                  sizeOf(lines[i]),
                  lines[i].spec,
                  lines[i].unit,
                  qtyOf(lines[i]),
                  lines[i].note,
                ],
            ],
            headerStyle: pw.TextStyle(font: fontBold, fontSize: 9),
            cellStyle: pw.TextStyle(font: font, fontSize: 9),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            cellAlignments: {
              0: pw.Alignment.center,
              2: pw.Alignment.center,
              4: pw.Alignment.center,
              5: pw.Alignment.centerRight,
            },
            columnWidths: {
              0: const pw.FixedColumnWidth(28),
              1: const pw.FlexColumnWidth(3),
              2: const pw.FixedColumnWidth(52),
              3: const pw.FlexColumnWidth(3),
              4: const pw.FixedColumnWidth(32),
              5: const pw.FixedColumnWidth(44),
              6: const pw.FlexColumnWidth(2),
            },
          ),
        ],
      ),
    );
    return doc.save();
  }

  static pw.Widget _pdfRightMeta(pw.Font font, String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.SizedBox(
            width: 48,
            child: pw.Text(
              label,
              style: pw.TextStyle(font: font, fontSize: 10),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(font: font, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _section(
    pw.Font font,
    pw.Font fontBold,
    String title,
    List<String> lines,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(title, style: pw.TextStyle(font: fontBold, fontSize: 12)),
        pw.SizedBox(height: 4),
        ...lines.map(
          (e) => pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 2),
            child: pw.Text(e, style: pw.TextStyle(font: font, fontSize: 10)),
          ),
        ),
      ],
    );
  }
}
