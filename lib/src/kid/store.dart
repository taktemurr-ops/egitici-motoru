import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Çocuk ailesinin yerel kaydı: çıkartmalar, ebeveyn raporu, süre sınırı.
/// Hiçbir veri cihaz dışına çıkmaz. SharedPreferences açılamazsa bellekte çalışır.
class KidStore {
  KidStore._();
  static final KidStore instance = KidStore._();

  static const int stickerCount = 60;

  SharedPreferences? _prefs;
  bool _loading = false;
  final Map<String, Object> _mem = {};

  Future<void> load() async {
    if (_prefs != null || _loading) return;
    _loading = true;
    try {
      _prefs = await SharedPreferences.getInstance();
    } catch (_) {
      _prefs = null;
    }
    _loading = false;
  }

  String _s(String k, String def) {
    final p = _prefs;
    if (p != null) {
      try {
        return p.getString(k) ?? def;
      } catch (_) {}
    }
    final v = _mem[k];
    return v is String ? v : def;
  }

  int _i(String k, int def) {
    final p = _prefs;
    if (p != null) {
      try {
        return p.getInt(k) ?? def;
      } catch (_) {}
    }
    final v = _mem[k];
    return v is int ? v : def;
  }

  void _setS(String k, String v) {
    _mem[k] = v;
    final p = _prefs;
    if (p != null) unawaited(p.setString(k, v).catchError((_) => false));
  }

  void _setI(String k, int v) {
    _mem[k] = v;
    final p = _prefs;
    if (p != null) unawaited(p.setInt(k, v).catchError((_) => false));
  }

  // ------------------------------------------------------------ çıkartmalar

  List<int> get stickers {
    final raw = _s('eg.stickers', '');
    if (raw.isEmpty) return const [];
    return [for (final x in raw.split(',')) int.tryParse(x) ?? -1].where((x) => x >= 0 && x < stickerCount).toList();
  }

  /// Yeni bir çıkartma verir (hepsi toplandıysa yine de gösterilecek birini döndürür).
  int awardSticker(int seed) {
    final have = stickers.toSet();
    final start = (seed & 0x7FFFFFFF) % stickerCount;
    for (var i = 0; i < stickerCount; i++) {
      final s = (start + i * 7) % stickerCount;
      if (!have.contains(s)) {
        _setS('eg.stickers', [...have, s].join(','));
        return s;
      }
    }
    return start;
  }

  // ------------------------------------------------------------ rapor

  static String dayKey(DateTime t) => '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> _stats() {
    try {
      final m = jsonDecode(_s('eg.stats', '{}'));
      return m is Map<String, dynamic> ? m : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  void _bump(String gameId, String field, int by) {
    final m = _stats();
    final g = (m[gameId] is Map<String, dynamic>) ? m[gameId] as Map<String, dynamic> : <String, dynamic>{};
    final old = g[field];
    g[field] = (old is int ? old : 0) + by;
    m[gameId] = g;
    _setS('eg.stats', jsonEncode(m));
  }

  void answer(String gameId, bool correct) => _bump(gameId, correct ? 'ok' : 'miss', 1);

  void levelDone(String gameId, int seconds) {
    _bump(gameId, 'levels', 1);
    _bump(gameId, 'sec', seconds);
  }

  /// oyun → (bölüm, doğru, yanlış, saniye)
  Map<String, List<int>> report() {
    final out = <String, List<int>>{};
    _stats().forEach((k, v) {
      if (v is Map<String, dynamic>) {
        final mv = v;
        int g(String f) => mv[f] is int ? mv[f] as int : 0;
        out[k] = [g('levels'), g('ok'), g('miss'), g('sec')];
      }
    });
    return out;
  }

  // ------------------------------------------------------------ süre

  /// Bugün oynanan saniye.
  int get todaySeconds => _s('eg.day', '') == dayKey(DateTime.now()) ? _i('eg.today', 0) : 0;

  /// Gün → saniye (son 7 gün).
  Map<String, int> get history {
    try {
      final m = jsonDecode(_s('eg.hist', '{}'));
      if (m is Map<String, dynamic>) return {for (final e in m.entries) if (e.value is int) e.key: e.value as int};
    } catch (_) {}
    return {};
  }

  void addPlayTime(int sec) {
    final today = dayKey(DateTime.now());
    final cur = todaySeconds + sec;
    _setS('eg.day', today);
    _setI('eg.today', cur);
    final h = history..[today] = cur;
    final keys = h.keys.toList()..sort();
    while (keys.length > 7) {
      h.remove(keys.removeAt(0));
    }
    _setS('eg.hist', jsonEncode(h));
  }

  /// Günlük sınır (dakika, 0 = kapalı).
  int get limitMinutes => _i('eg.limit', 0);
  set limitMinutes(int v) => _setI('eg.limit', v);

  /// Ebeveynin verdiği ek süre (bugün için, dakika).
  int get bonusMinutes => _s('eg.bonusDay', '') == dayKey(DateTime.now()) ? _i('eg.bonus', 0) : 0;
  void addBonus(int m) {
    _setS('eg.bonusDay', dayKey(DateTime.now()));
    _setI('eg.bonus', bonusMinutes + m);
  }

  bool get bedtimeOn => _i('eg.bed', 0) == 1;
  set bedtimeOn(bool v) => _setI('eg.bed', v ? 1 : 0);
  int get bedFrom => _i('eg.bedFrom', 20);
  set bedFrom(int v) => _setI('eg.bedFrom', v);
  int get bedTo => _i('eg.bedTo', 7);
  set bedTo(int v) => _setI('eg.bedTo', v);

  /// Uyku saatinde mi (ebeveyn bugün izin verdiyse hayır).
  bool isBedtime(DateTime now) {
    if (!bedtimeOn) return false;
    if (_s('eg.bedOk', '') == dayKey(now.subtract(Duration(hours: now.hour < 12 ? 12 : 0)))) return false;
    final h = now.hour;
    return bedFrom > bedTo ? (h >= bedFrom || h < bedTo) : (h >= bedFrom && h < bedTo);
  }

  void allowTonight() => _setS('eg.bedOk', dayKey(DateTime.now().subtract(Duration(hours: DateTime.now().hour < 12 ? 12 : 0))));

  bool get overLimit {
    final l = limitMinutes;
    if (l <= 0) return false;
    return todaySeconds >= (l + bonusMinutes) * 60;
  }

  /// Uyarlanabilir zorluk: oyun başına 0 (kolay) .. 4 (zor) beceri düzeyi.
  int skill(String gameId) => _i('eg.skill.$gameId', 2);
  void setSkill(String gameId, int v) => _setI('eg.skill.$gameId', v < 0 ? 0 : (v > 4 ? 4 : v));
}
