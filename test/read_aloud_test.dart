import 'package:egitici_motoru/src/kid/read_aloud.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('çevrimdışı ses seçimi: ağ gerektiren ve indirilmemiş sesler elenir', () {
    final voices = [
      {'name': 'tr-tr-x-net', 'locale': 'tr-TR', 'network_required': '1', 'features': 'networkTts'},
      {'name': 'tr-tr-x-missing', 'locale': 'tr-TR', 'network_required': '0', 'features': 'embeddedTts\tnotInstalled'},
      {'name': 'tr-tr-x-local', 'locale': 'tr-TR', 'network_required': '0', 'features': 'embeddedTts'},
      {'name': 'en-us-x-local', 'locale': 'en-US', 'network_required': '0', 'features': ''},
    ];
    expect(pickOfflineVoice(voices, 'tr'), {'name': 'tr-tr-x-local', 'locale': 'tr-TR'});
    expect(pickOfflineVoice(voices.take(2).toList(), 'tr'), isNull);
    expect(pickOfflineVoice(voices, 'de'), isNull);
  });

  test('ses seçimi: tercih edilen bölge, eski Android kodları, iOS biçimi', () {
    final voices = [
      {'name': 'Joana', 'locale': 'pt-PT'},
      {'name': 'Luciana', 'locale': 'pt-BR'},
      {'name': 'Carmit', 'locale': 'iw_IL'},
      {'name': 'Damayanti', 'locale': 'in-ID'},
      {'name': 'Tingting', 'locale': 'zh-CN', 'quality': 'enhanced'},
    ];
    expect(pickOfflineVoice(voices, 'pt')?['name'], 'Luciana');
    expect(pickOfflineVoice(voices, 'he')?['name'], 'Carmit');
    expect(pickOfflineVoice(voices, 'id')?['name'], 'Damayanti');
    expect(pickOfflineVoice(voices, 'zh')?['name'], 'Tingting');
    expect(pickOfflineVoice([null, 'x', <String, String>{}], 'en'), isNull);
  });

  test('33 dilin hepsine ses yereli tanımlı', () {
    expect(kTtsLocales.length, 33);
  });

  test('karakter konumu -> sözcük sırası', () {
    const s = 'Kaplumbağa ile tavşan yarıştı';
    expect(wordIndexAt(s, 0), 0);
    expect(wordIndexAt(s, 11), 1);
    expect(wordIndexAt(s, 15), 2);
    expect(wordIndexAt(s, 23), 3);
    expect(wordIndexAt('一起读书', 2), 0);
  });

  test('desteklenmeyen ortamda (test) ses yok -> vurgulamaya geçilir', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final ok = await ReadAloud.instance.speak('bir iki', 'tr', onWord: (_) {}, onDone: () {});
    expect(ok, isFalse);
  });
}
