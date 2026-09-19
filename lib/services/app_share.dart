import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/locale_controller.dart';
import 'app_platform.dart';

/// デスクトップ / iPad でも確実に共有・保存できるヘルパー
class AppShare {
  AppShare._();

  /// サンドボックス内でも必ず書ける一時ファイル
  static Future<File> tempFile(String fileName) async {
    final safe = fileName.replaceAll(RegExp(r'[/\\:\0]'), '_');
    for (final probe in await _candidateDirs()) {
      try {
        await probe.create(recursive: true);
        final f = File('${probe.path}/$safe');
        // 書き込み可否を確認
        await f.writeAsBytes(const [], flush: true);
        return f;
      } catch (_) {
        continue;
      }
    }
    final fallback = File('${Directory.systemTemp.path}/$safe');
    await Directory.systemTemp.create(recursive: true);
    return fallback;
  }

  static Future<List<Directory>> _candidateDirs() async {
    final out = <Directory>[];
    try {
      out.add(await getTemporaryDirectory());
    } catch (_) {}
    try {
      out.add(await getApplicationSupportDirectory());
    } catch (_) {}
    try {
      out.add(await getApplicationDocumentsDirectory());
    } catch (_) {}
    out.add(Directory.systemTemp);
    return out;
  }

  /// NSSharingServicePicker は FlutterView 座標系（左上原点）の矩形が必要
  static Rect originFrom(BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize && box.attached) {
      // 画面全体ではなく、ビュー内ローカルに近い座標へ
      final topLeft = box.localToGlobal(Offset.zero);
      final size = box.size;
      if (size.width >= 8 && size.height >= 8) {
        return Rect.fromLTWH(
          topLeft.dx.clamp(0, 4000),
          topLeft.dy.clamp(0, 4000),
          size.width.clamp(8, 200),
          size.height.clamp(8, 80),
        );
      }
    }
    final mq = MediaQuery.maybeOf(context);
    final w = mq?.size.width ?? 800;
    return Rect.fromLTWH(w - 120, 8, 56, 40);
  }

  static Future<ShareResult> share({
    required BuildContext context,
    String? text,
    String? subject,
    List<XFile>? files,
    Rect? sharePositionOrigin,
  }) async {
    // macOS / Windows：ファイル共有は保存ダイアログを主経路
    if (AppPlatform.isDesktop && files != null && files.isNotEmpty) {
      final ok = await _saveFilesAs(files);
      if (!ok) {
        throw StateError('share_cancelled_or_failed');
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ファイルを保存しました')),
        );
      }
      return const ShareResult('', ShareResultStatus.success);
    }

    final origin = sharePositionOrigin ?? originFrom(context);
    try {
      return await SharePlus.instance.share(
        ShareParams(
          text: text,
          subject: subject,
          files: files,
          sharePositionOrigin: origin,
        ),
      );
    } catch (_) {
      if (files != null && files.isNotEmpty) {
        final saved = await _saveFilesAs(files);
        if (saved) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('ファイルを保存しました')),
            );
          }
          return const ShareResult('', ShareResultStatus.success);
        }
      }
      rethrow;
    }
  }

  /// iPhone / iPad：保存か共有を選択。Mac：従来どおり保存ダイアログ。
  static Future<bool> exportBytes({
    required BuildContext context,
    required Uint8List bytes,
    required String fileName,
    String mimeType = 'application/pdf',
    String? subject,
  }) async {
    if (Platform.isIOS) {
      final action = await _pickIosExportAction(context);
      if (action == null) return false;
      if (action == 'save') {
        return saveBytes(
          context: context,
          bytes: bytes,
          fileName: fileName,
          mimeType: mimeType,
        );
      }
      return shareBytes(
        context: context,
        bytes: bytes,
        fileName: fileName,
        mimeType: mimeType,
        subject: subject,
      );
    }
    return saveBytes(
      context: context,
      bytes: bytes,
      fileName: fileName,
      mimeType: mimeType,
    );
  }

  static Future<String?> _pickIosExportAction(BuildContext context) {
    final s = LocaleController.instance.strings;
    return showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: Text(s.exportChooseTitle)),
            ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: Text(s.saveLocally),
              onTap: () => Navigator.pop(ctx, 'save'),
            ),
            ListTile(
              leading: const Icon(Icons.ios_share),
              title: Text(s.shareSend),
              subtitle: Text(s.shareLineEmail),
              onTap: () => Navigator.pop(ctx, 'share'),
            ),
          ],
        ),
      ),
    );
  }

  /// システム共有シート（LINE / メール等）へ送る
  static Future<bool> shareBytes({
    required BuildContext context,
    required Uint8List bytes,
    required String fileName,
    String mimeType = 'application/pdf',
    String? subject,
  }) async {
    final safe = fileName.replaceAll(RegExp(r'[/\\:\0]'), '_');
    final file = await tempFile(safe);
    await file.writeAsBytes(bytes, flush: true);
    if (!context.mounted) return false;
    final origin = originFrom(context);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: mimeType, name: safe)],
        subject: subject ?? safe,
        sharePositionOrigin: origin,
      ),
    );
    return true;
  }

  /// PDF バイトを直接保存（一時ファイル不要）
  static Future<bool> saveBytes({
    required BuildContext context,
    required Uint8List bytes,
    required String fileName,
    String mimeType = 'application/pdf',
  }) async {
    final safe = fileName.replaceAll(RegExp(r'[/\\:\0]'), '_');
    try {
      final uri = await FilePicker.saveFile(
        dialogTitle: '保存先を選択',
        fileName: safe,
        bytes: bytes,
        mimeType: mimeType,
        type: FileType.custom,
        allowedExtensions: _extOf(safe) ?? ['pdf'],
      );
      if (uri == null) return false;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ファイルを保存しました')),
        );
      }
      // 可能なら Finder で表示
      if (AppPlatform.isDesktop && uri.isScheme('file')) {
        try {
          await Process.run('open', ['-R', uri.toFilePath()]);
        } catch (_) {}
      }
      return true;
    } catch (_) {
      // FilePicker 失敗時は一時ファイル経由で共有シートへ
      if (!context.mounted) return false;
      return shareBytes(
        context: context,
        bytes: bytes,
        fileName: safe,
        mimeType: mimeType,
        subject: safe,
      );
    }
  }

  static Future<bool> _saveFilesAs(List<XFile> files) async {
    final src = files.first;
    final suggested = src.name.isNotEmpty
        ? src.name
        : src.path.split(Platform.pathSeparator).last;
    final bytes = await File(src.path).readAsBytes();
    final uri = await FilePicker.saveFile(
      dialogTitle: '保存先を選択',
      fileName: suggested,
      bytes: Uint8List.fromList(bytes),
      mimeType: src.mimeType ?? 'application/octet-stream',
      type: FileType.custom,
      allowedExtensions: _extOf(suggested) ?? ['pdf'],
    );
    if (uri == null) return false;
    if (AppPlatform.isDesktop && uri.isScheme('file')) {
      try {
        await Process.run('open', ['-R', uri.toFilePath()]);
      } catch (_) {}
    }
    return true;
  }

  static List<String>? _extOf(String name) {
    final i = name.lastIndexOf('.');
    if (i < 0 || i == name.length - 1) return null;
    return [name.substring(i + 1).toLowerCase()];
  }
}
