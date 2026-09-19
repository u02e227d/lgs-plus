import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_platform.dart';
import 'lgsplus_cloud.dart';

/// ログイン中のお知らせ未読件数。
/// Mac はネイティブ Timer + Dock / ウィンドウタイトルも併用。
class NoticeUnreadController extends ChangeNotifier {
  NoticeUnreadController._();
  static final NoticeUnreadController instance = NoticeUnreadController._();

  static const lastSeenIdKey = 'lgsplus_notice_last_seen_id';
  static const _channelName = 'jp.lgsplus.lgsPlus/window';
  static const _channel = MethodChannel(_channelName);

  int unread = 0;
  Timer? _poll;
  bool _active = false;
  bool _refreshing = false;
  bool _channelReady = false;

  Duration get _interval => AppPlatform.isDesktop
      ? const Duration(seconds: 6)
      : const Duration(seconds: 20);

  static Future<int> loadLastSeenId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(lastSeenIdKey) ?? 0;
  }

  static Future<void> saveLastSeenId(int id) async {
    if (id <= 0) return;
    final prefs = await SharedPreferences.getInstance();
    final prev = prefs.getInt(lastSeenIdKey) ?? 0;
    if (id > prev) {
      await prefs.setInt(lastSeenIdKey, id);
    }
  }

  static Future<void> markAllRead(List<OpsNotice> list) async {
    if (list.isEmpty) return;
    final maxId = list.map((e) => e.id).fold<int>(0, (a, b) => a > b ? a : b);
    await saveLastSeenId(maxId);
    if (!kIsWeb && Platform.isMacOS) {
      try {
        await _channel.invokeMethod('setLastSeenId', {'lastSeenId': maxId});
      } catch (_) {}
    }
  }

  static Future<int> unreadCount({int limit = 50}) async {
    final lastSeen = await loadLastSeenId();
    final list = await LgsplusCloud.listNotices(limit: limit);
    return list.where((e) => e.id > lastSeen).length;
  }

  void start() {
    _active = true;
    _ensureChannelHandler();
    _refresh();
    _poll?.cancel();
    _poll = Timer.periodic(_interval, (_) {
      if (_active) _refresh();
    });
    if (!kIsWeb && Platform.isMacOS) {
      () async {
        final lastSeen = await loadLastSeenId();
        try {
          await _channel.invokeMethod('startNoticePoll', {
            'lastSeenId': lastSeen,
          });
        } catch (_) {}
      }();
    }
  }

  void stop() {
    _active = false;
    _poll?.cancel();
    _poll = null;
    // Mac はネイティブ監視をログアウトでも止めない（再ログイン前の件数取りこぼし防止）。
    // Dock / タイトルは unread=0 で消す。
    if (!kIsWeb && Platform.isMacOS) {
      // keep native timer; only clear Flutter badge state
    } else if (!kIsWeb) {
      // iOS: no native poller
    }
    if (unread != 0) {
      unread = 0;
      notifyListeners();
    }
  }

  void _ensureChannelHandler() {
    if (_channelReady || kIsWeb || !Platform.isMacOS) return;
    _channelReady = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'windowBecameKey' || call.method == 'appActivated') {
        await _refresh();
        return null;
      }
      if (call.method == 'unreadUpdated') {
        final args = call.arguments;
        int count = 0;
        if (args is Map) {
          final raw = args['count'];
          if (raw is int) {
            count = raw;
          } else if (raw is num) {
            count = raw.toInt();
          }
        }
        unread = count;
        notifyListeners();
        return null;
      }
      return null;
    });
  }

  Future<void> refreshNow() async {
    if (!kIsWeb && Platform.isMacOS) {
      try {
        await _channel.invokeMethod('refreshNotices');
      } catch (_) {}
    }
    await _refresh();
  }

  Future<void> _refresh() async {
    if (!_active || _refreshing) return;
    _refreshing = true;
    try {
      final n = await unreadCount();
      unread = n;
      notifyListeners();
    } catch (_) {
      // keep last count
    } finally {
      _refreshing = false;
    }
  }
}
