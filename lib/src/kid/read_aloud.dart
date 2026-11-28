import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Sesli okuma (Masal Kitaplığı): cihazın kendi sistem sesleri, ÇEVRİMDIŞI.
///
/// Çocuk güvenliği: ağ gerektiren sesler hiç seçilmez (Android'de
/// `network_required` = 1 ya da indirilmemiş sesler elenir; iOS sesleri
/// zaten cihazda). Web'de tarayıcı seslerinin çevrimdışı olup olmadığı
/// bilinemediği için sesli okuma kapalıdır. Uygun ses yoksa ya da eklenti
/// yoksa (test, masaüstü) `false` döner ve ekran sözcük vurgulamaya geçer.

/// Uygulama dil kodu -> tercih edilen bölge (ses yereli), ardından aynı
/// dilin her bölgesi kabul edilir. Eski Android kodları da eşleşir.
const Map<String, List<String>> kTtsLocales = {
  'tr': ['tr-TR'], 'en': ['en-US', 'en-GB'], 'de': ['de-DE'], 'es': ['es-ES', 'es-MX', 'es-US'],
  'fr': ['fr-FR', 'fr-CA'], 'ar': ['ar-SA', 'ar-001', 'ar-EG'], 'fa': ['fa-IR'], 'he': ['he-IL', 'iw-IL'],
  'ur': ['ur-PK', 'ur-IN'], 'ru': ['ru-RU'], 'uk': ['uk-UA'], 'pl': ['pl-PL'], 'cs': ['cs-CZ'],
  'ro': ['ro-RO'], 'hu': ['hu-HU'], 'el': ['el-GR'], 'it': ['it-IT'], 'pt': ['pt-BR', 'pt-PT'],
  'nl': ['nl-NL', 'nl-BE'], 'sv': ['sv-SE'], 'da': ['da-DK'], 'nb': ['nb-NO', 'no-NO'], 'fi': ['fi-FI'],
  'ja': ['ja-JP'], 'ko': ['ko-KR'], 'zh': ['zh-CN', 'cmn-CN', 'zh-TW'], 'hi': ['hi-IN'], 'bn': ['bn-BD', 'bn-IN'],
  'id': ['id-ID', 'in-ID'], 'ms': ['ms-MY'], 'th': ['th-TH'], 'vi': ['vi-VN'], 'fil': ['fil-PH', 'tl-PH'],
};

const Map<String, List<String>> _kAltCodes = {
  'he': ['iw'], 'id': ['in'], 'fil': ['tl'], 'nb': ['no', 'nn'], 'zh': ['cmn', 'yue'],
};

String _norm(String s) => s.replaceAll('_', '-').toLowerCase();

/// Sesler arasından [lang] için çevrimdışı bir ses seçer; yoksa `null`.
/// [voices]: flutter_tts `getVoices` çıktısı (name, locale, network_required, features).
Map<String, String>? pickOfflineVoice(List<Object?> voices, String lang) {
  final codes = {lang, ...?_kAltCodes[lang]};
  final pref = [for (final l in kTtsLocales[lang] ?? const <String>[]) _norm(l)];
  Map<String, String>? best;
  var bestScore = -1;
  for (final v in voices) {
    if (v is! Map) continue;
    final name = '${v['name'] ?? ''}';
    final loc = _norm('${v['locale'] ?? ''}');
    if (name.isEmpty || loc.isEmpty) continue;
    if ('${v['network_required'] ?? '0'}' == '1') continue;
    final feats = '${v['features'] ?? ''}'.split('\t');
    if (feats.contains('notInstalled')) continue;
    if (!codes.contains(loc.split('-').first)) continue;
    final pi = pref.indexOf(loc);
    var score = pi >= 0 ? 100 - pi * 10 : 10;
    final q = '${v['quality'] ?? ''}';
    if (q == 'very high' || q == 'enhanced' || q == 'premium') score += 3;
    if (q == 'high') score += 2;
    if (score > bestScore) {
      bestScore = score;
      best = {'name': name, 'locale': '${v['locale']}'};
    }
  }
  return best;
}

/// Metindeki karakter konumunu boşlukla ayrılmış sözcük sırasına çevirir.
int wordIndexAt(String text, int offset) {
  var i = 0;
  var pos = 0;
  for (final w in text.split(' ')) {
    final end = pos + w.length;
    if (offset < end || (offset == end && w.isNotEmpty)) return i;
    pos = end + 1;
    i++;
  }
  return i - 1;
}

/// Tek bir sistem sesli okuyucusu (uygulama başına bir tane).
class ReadAloud {
  ReadAloud._();
  static final ReadAloud instance = ReadAloud._();

  /// Testlerde ya da desteklenmeyen platformda kapatmak için.
  static bool enabled = true;

  FlutterTts? _tts;
  final Map<String, Map<String, String>?> _voiceFor = {};
  void Function(int word)? _onWord;
  VoidCallback? _onDone;
  int _token = 0;

  /// Yeni okumanın başladığı bildirilmeden gelen bitiş/iptal olayları bir
  /// önceki okumaya aittir (durdurma sırası) ve yok sayılır.
  bool _started = false;

  bool get _supported =>
      enabled && !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  Future<FlutterTts?> _engine() async {
    if (_tts != null) return _tts;
    final t = FlutterTts();
    try {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await t.setSharedInstance(true).timeout(const Duration(seconds: 3));
        await t.setIosAudioCategory(IosTextToSpeechAudioCategory.playback, [
          IosTextToSpeechAudioCategoryOptions.mixWithOthers,
        ]).timeout(const Duration(seconds: 3));
      }
      await t.awaitSpeakCompletion(false).timeout(const Duration(seconds: 3));
    } catch (_) {
      return null;
    }
    t.setProgressHandler((text, start, end, word) => _onWord?.call(wordIndexAt(text, start)));
    t.setStartHandler(() => _started = true);
    t.setCompletionHandler(() {
      if (_started) _finished();
    });
    t.setCancelHandler(() {
      if (_started) _finished();
    });
    t.setErrorHandler((_) => _finished());
    return _tts = t;
  }

  void _finished() {
    final d = _onDone;
    _onWord = null;
    _onDone = null;
    d?.call();
  }

  /// Bu dilde çevrimdışı ses var mı (sonuç önbelleğe alınır).
  Future<Map<String, String>?> voiceFor(String lang) async {
    if (!_supported) return null;
    if (_voiceFor.containsKey(lang)) return _voiceFor[lang];
    Map<String, String>? v;
    try {
      final t = await _engine();
      if (t != null) {
        final list = await t.getVoices.timeout(const Duration(seconds: 4));
        if (list is List) v = pickOfflineVoice(list, lang);
      }
    } catch (_) {
      v = null;
    }
    return _voiceFor[lang] = v;
  }

  /// [text] metnini [lang] dilinin çevrimdışı sesiyle okur. Ses yoksa
  /// `false` döner (çağıran sözcük vurgulamaya geçer). [onWord] okunan
  /// sözcüğün sırasıyla, [onDone] okuma bitince/durunca çağrılır.
  Future<bool> speak(String text, String lang, {required void Function(int word) onWord, required VoidCallback onDone}) async {
    final my = ++_token;
    final voice = await voiceFor(lang);
    final t = _tts;
    if (voice == null || t == null || my != _token) return false;
    try {
      const wait = Duration(seconds: 4);
      if (_onDone != null) await t.stop().timeout(wait);
      if (my != _token) return false;
      _onWord = null;
      _onDone = null;
      _started = false;
      await t.setVoice(voice).timeout(wait);
      await t.setSpeechRate(0.42).timeout(wait);
      await t.setPitch(1.05).timeout(wait);
      await t.setVolume(1.0).timeout(wait);
      _onWord = onWord;
      _onDone = onDone;
      final r = await t.speak(text).timeout(wait);
      if (r != 1 && r != null) {
        _onWord = null;
        _onDone = null;
        return false;
      }
      return true;
    } catch (_) {
      _onWord = null;
      _onDone = null;
      return false;
    }
  }

  /// Kısa bir sözü (soru, ad, övgü) okur; bitişini beklemez. Ses yoksa `false`.
  Future<bool> say(String text, String lang) => speak(text, lang, onWord: (_) {}, onDone: () {});

  Future<void> stop() async {
    _token++;
    _onWord = null;
    _onDone = null;
    try {
      await _tts?.stop();
    } catch (_) {}
  }
}
