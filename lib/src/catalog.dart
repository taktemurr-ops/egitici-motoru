import 'core.dart';
import 'kinds/art.dart';
import 'kinds/music.dart';
import 'kinds/play.dart';
import 'kinds/quizzes.dart';
import 'kinds/write.dart';

/// Eğitici ve Çocuk türleri (27).
const Map<String, EgiticiKind> kEgiticiKinds = {
  'boyama': BoyamaKind(),
  'sayiyla-boyama': SayiylaBoyamaKind(),
  'carpim': CarpimKind(),
  'alfabe': AlfabeKind(),
  'sayi': SayiKind(),
  'saat': SaatKind(),
  'sekil-renk': SekilRenkKind(),
  'bayraklar': BayrakKind(),
  'baskentler': BaskentKind(),
  'matematik-yarisi': MatematikYarisiKind(),
  'piyano': PiyanoKind(),
  'harf-izleme': HarfIzlemeKind(),
  'hece': HeceKind(),
  'turkiye-haritasi': TurkiyeKind(),
  'toplama-cikarma': ToplamaCikarmaKind(),
  'kesirler': KesirKind(),
  'geometri': GeometriKind(),
  'para-sayma': ParaKind(),
  'kodlama': KodlamaKind(),
  'nota': NotaKind(),
  'gunes-sistemi': GunesKind(),
  'trafik': TrafikKind(),
  'mevsimler': MevsimKind(),
  'dikkat': DikkatKind(),
  'hayvanlar': HayvanKind(),
  'ingilizce': IngilizceKind(),
  'labirent-yapboz': LabirentKind(),
};

EgiticiRules egiticiRulesFor(String gameId, String kind) => egiticiRules(gameId, kEgiticiKinds[kind]!);
