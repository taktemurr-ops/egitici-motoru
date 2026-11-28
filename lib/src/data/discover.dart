/// Meslekler, Vücudumuz, Dinozorlar ve Meyve-Sebze verileri. Adlar
/// [kDiscoverNames] içinde (discover_names.dart), burada resim ve ilişkiler var.
library;

/// Ad anahtarı → resim (emoji). Meslek kişilerine ten rengi eklenebilir.
const Map<String, String> kPicEmoji = {
  // meslekler
  'j.doctor': '🧑‍⚕️', 'j.teacher': '🧑‍🏫', 'j.firefighter': '🧑‍🚒', 'j.police': '👮', 'j.cook': '🧑‍🍳',
  'j.farmer': '🧑‍🌾', 'j.pilot': '🧑‍✈️', 'j.astronaut': '🧑‍🚀', 'j.mechanic': '🧑‍🔧', 'j.artist': '🧑‍🎨',
  'j.scientist': '🧑‍🔬', 'j.builder': '👷', 'j.singer': '🧑‍🎤', 'j.coder': '🧑‍💻',
  // vücut
  'v.eye': '👁️', 'v.ear': '👂', 'v.nose': '👃', 'v.mouth': '👄', 'v.tongue': '👅', 'v.hand': '✋', 'v.foot': '🦶',
  'v.leg': '🦵', 'v.arm': '💪', 'v.teeth': '🦷', 'v.brain': '🧠', 'v.heart': '❤️', 'v.lungs': '🫁', 'v.bone': '🦴',
  // meyve ve sebzeler
  'f.apple': '🍎', 'f.banana': '🍌', 'f.grapes': '🍇', 'f.strawberry': '🍓', 'f.orange': '🍊', 'f.watermelon': '🍉',
  'f.pear': '🍐', 'f.cherry': '🍒', 'f.lemon': '🍋', 'g.peach': '🍑', 'g.pineapple': '🍍', 'g.kiwi': '🥝',
  'g.coconut': '🥥', 'g.mango': '🥭', 'f.carrot': '🥕', 'f.corn': '🌽', 'g.broccoli': '🥦',
  'g.potato': '🥔', 'g.eggplant': '🍆', 'g.cucumber': '🥒', 'g.pepper': '🌶️', 'g.onion': '🧅', 'g.garlic': '🧄',
  'g.lettuce': '🥬', 'g.fruit': '🍎🍌🍇', 'g.veg': '🥕🥦🌽',
};

/// Ten rengi değiştiricisini ilk karakterden sonra ekler ([t] 1..5; 0 = yok).
String toned(String e, int t) {
  if (t <= 0 || t > 5) return e;
  final r = e.runes.toList();
  return String.fromCharCodes([r.first, 0x1F3FA + t, ...r.skip(1)]);
}

// ---------------------------------------------------------------- meslekler

class Job {
  final String key;
  final List<String> tools;
  final List<String> places;
  const Job(this.key, this.tools, this.places);
}

/// Her aletin ve yerin tek bir mesleğe ait olduğu (çakışmasız) liste.
const List<Job> kJobs = [
  Job('j.doctor', ['🩺', '💉', '🩹'], ['🏥']),
  Job('j.teacher', ['📚', '✏️', '📓'], ['🏫']),
  Job('j.firefighter', ['🧯', '🚒'], ['🔥']),
  Job('j.police', ['🚓', '🚔'], ['🚦']), // 🚨 tepe lambası itfaiye/ambulansta da var
  Job('j.cook', ['🍳', '🥄', '🧂'], ['🍽️']),
  Job('j.farmer', ['🚜', '🧺'], ['🌾', '🐄']),
  Job('j.pilot', ['✈️'], ['☁️']),
  Job('j.astronaut', ['🚀', '🛰️'], ['🌕', '🪐']),
  Job('j.mechanic', ['🔧', '🔩'], ['🚙']),
  Job('j.artist', ['🎨', '🖌️'], ['🖼️']),
  Job('j.scientist', ['🔬', '🧲'], ['🧪']),
  Job('j.builder', ['🧱', '🦺'], ['🏗️']),
  Job('j.singer', ['🎤'], ['🎭']),
  Job('j.coder', ['💻', '⌨️', '🖱️'], ['🏢']),
];

int jobOfKey(String key) => kJobs.indexWhere((j) => j.key == key);
int jobOfTool(String e) => kJobs.indexWhere((j) => j.tools.contains(e));
int jobOfPlace(String e) => kJobs.indexWhere((j) => j.places.contains(e));

// ---------------------------------------------------------------- vücudumuz

const List<String> kBodyKeys = [
  'v.eye', 'v.ear', 'v.nose', 'v.tongue', 'v.hand', // 0..4 beş duyu
  'v.mouth', 'v.foot', 'v.leg', 'v.arm', 'v.teeth', 'v.brain', 'v.heart', 'v.lungs', 'v.bone',
];

/// Beş duyu (göz, kulak, burun, dil, el) ve onlarla algılanan şeyler.
const List<List<String>> kSenseThings = [
  ['🌈', '⭐', '🖼️', '👓'], // 🎆 ve 📺 sesle de algılanır (kulak da doğru olurdu)
  ['🎵', '🔔', '🥁', '📢'],
  ['🌸', '🌹', '💐', '🦨'],
  ['🍋', '🍭', '🍯', '🧂'],
  ['🧸', '🧊', '🌵', '🧶'],
];

/// Organ → yaptığı iş (resimle). Anahtar [kBodyKeys] sırası.
const Map<int, List<String>> kBodyJobs = {
  5: ['🗣️'], // ağız: konuşmak
  6: ['🚶', '🏃'], // ayak: yürümek, koşmak
  4: ['✍️', '👏'], // el: yazmak, alkış
  9: ['🪥'], // diş: fırçalanır
  10: ['💭', '🧩'], // beyin: düşünmek
  11: ['💓'], // kalp: atar
  12: ['🌬️'], // akciğer: nefes
  13: ['🧍'], // kemik: dik durmak (iskelet)
};

/// Anlamca birbirine çok yakın organ çiftleri (aynı soruda yan yana çıkmaz).
const List<List<int>> kBodyClash = [
  [5, 9], [5, 3], [9, 3], [6, 7], [4, 8], [12, 2], [12, 5], [13, 6], [13, 7], // dik durmak: ayak/bacak da doğru olurdu; sv/nb'de bacak ve kemik aynı sözcük (ben/bein)
];

bool bodyClash(int a, int b) => kBodyClash.any((p) => (p[0] == a && p[1] == b) || (p[0] == b && p[1] == a));

int senseOf(String e) => kSenseThings.indexWhere((l) => l.contains(e));
int bodyJobOf(String e) {
  for (final en in kBodyJobs.entries) {
    if (en.value.contains(e)) return en.key;
  }
  return -1;
}

// ---------------------------------------------------------------- dinozorlar

const List<String> kDinoKeys = ['d.trex', 'd.tric', 'd.steg', 'd.brach', 'd.ankylo', 'd.raptor', 'd.para', 'd.spino', 'd.ptera', 'd.plesio'];

/// 0 bitki, 1 et, 2 balık.
const List<int> kDinoDiet = [1, 0, 0, 0, 0, 1, 0, 2, 2, 2];

/// 0 kara, 1 gökyüzü, 2 deniz.
const List<int> kDinoHome = [0, 0, 0, 0, 0, 0, 0, 0, 1, 2];

/// Yaklaşık boy (desimetre; Pteranodon için kanat açıklığı).
const List<int> kDinoSize = [120, 90, 90, 220, 70, 20, 100, 150, 65, 35];

/// Gerçek dinozor olmayan (aynı çağın uçan ve deniz sürüngenleri).
bool notDino(int i) => i == 8 || i == 9;

const List<String> kDietEmoji = ['🌿', '🍖', '🐟'];
const List<String> kHomeIcon = ['🏞️', '☁️', '🌊'];
const List<int> kDinoColors = [0xFF7A8B5A, 0xFFC08552, 0xFF6FA36B, 0xFF8AAFC9, 0xFFA68A64, 0xFFB9835A, 0xFF5E9C8F, 0xFF9C6644, 0xFFB08BBB, 0xFF4F7CAC];

// ---------------------------------------------------------------- meyve ve sebze

class Produce {
  final String key;
  final bool fruit;

  /// [kColorKeys] sırası; -1 = rengi tartışmalı, renk sorusunda kullanılmaz.
  final int color;

  /// 0 ağaçta, 1 toprağın altında, 2 bitkide/fidede; -1 = sorulmaz.
  final int grow;
  const Produce(this.key, this.fruit, this.color, this.grow);
}

const List<Produce> kProduce = [
  Produce('f.apple', true, 0, 0),
  Produce('f.banana', true, 2, -1),
  Produce('f.grapes', true, 5, 2),
  Produce('f.strawberry', true, 0, 2),
  Produce('f.orange', true, 1, 0),
  Produce('f.watermelon', true, -1, 2), // 🍉 dilimi kırmızı görünür; "yeşil" sorusunda yanıltıcı
  Produce('f.pear', true, 3, 0),
  Produce('f.cherry', true, 0, 0),
  Produce('f.lemon', true, 2, 0),
  Produce('g.peach', true, -1, 0),
  Produce('g.pineapple', true, -1, 2),
  Produce('g.kiwi', true, -1, 2),
  Produce('g.coconut', true, 7, 0),
  Produce('g.mango', true, -1, 0),
  Produce('f.carrot', false, 1, 1),
  Produce('f.corn', false, 2, 2),
  Produce('g.broccoli', false, 3, 2),
  Produce('g.potato', false, 7, 1),
  Produce('g.eggplant', false, 5, 2),
  Produce('g.cucumber', false, 3, 2),
  Produce('g.pepper', false, 0, 2),
  Produce('g.onion', false, -1, 1),
  Produce('g.garlic', false, 9, 1),
  Produce('g.lettuce', false, 3, 2),
];

int produceOf(String key) => kProduce.indexWhere((p) => p.key == key);
