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
