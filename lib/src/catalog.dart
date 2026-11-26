import 'core.dart';
import 'kinds/art.dart';
import 'kinds/discover.dart';
import 'kinds/ek4.dart';
import 'kinds/life.dart';
import 'kinds/music.dart';
import 'kinds/play.dart';
import 'kinds/quizzes.dart';
import 'kinds/write.dart';

/// Eğitici ve Çocuk türleri (41).
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
  'duygular': DuyguKind(),
  'zit-kavramlar': ZitKind(),
  'geri-donusum': GeriDonusumKind(),
  'yonler': YonKind(),
  'saglikli-aliskanliklar': SaglikKind(),
  'meslekler': MeslekKind(),
  'vucudumuz': VucutKind(),
  'dinozorlar': DinoKind(),
  'meyve-sebze': MeyveSebzeKind(),
  'oyuncak-ev': OyuncakEvKind(),
  'veteriner': VeterinerKind(),
  'masal': MasalKind(),
  'araba-tamir': ArabaTamirKind(),
  'dunya-alfabeleri': DunyaAlfabeleriKind(),
};

EgiticiRules egiticiRulesFor(String gameId, String kind) => egiticiRules(gameId, kEgiticiKinds[kind]!);
