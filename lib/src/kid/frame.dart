import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:studio_core/core/strings.dart';

import '../core.dart';
import '../data/misc.dart';
import '../data/titles.dart';
import '../texts.dart';
import 'store.dart';

/// Oyun ekranı ile çerçeve arasındaki bağ: bölüm bitince kutlama.
class KidHooks {
  void Function(int sticker, VoidCallback then)? _celebrate;

  void celebrate(int sticker, VoidCallback then) {
    final c = _celebrate;
    if (c == null) {
      then();
    } else {
      c(sticker, then);
    }
  }
}

/// Çocuk çerçevesi: üstte çıkartma albümü ve ebeveyn düğmesi; günlük süre
/// sınırı ve uyku saati; bölüm sonunda çıkartma kutlaması.
class KidFrame extends StatefulWidget {
  final EPlay play;
  final KidHooks hooks;
  final Widget child;
  const KidFrame({super.key, required this.play, required this.hooks, required this.child});

  @override
  State<KidFrame> createState() => _KidFrameState();
}

class _KidFrameState extends State<KidFrame> {
  Timer? _tick;
  int? _sticker;
  bool _blocked = false;
  bool _bed = false;

  String get lang => widget.play.lang;

  @override
  void initState() {
    super.initState();
    widget.hooks._celebrate = _celebrate;
    unawaited(KidStore.instance.load().then((_) {
      if (mounted) setState(_check);
    }));
    _tick = Timer.periodic(const Duration(seconds: 15), (_) {
      KidStore.instance.addPlayTime(15);
      if (mounted) setState(_check);
    });
  }

  void _check() {
    final s = KidStore.instance;
    _bed = s.isBedtime(DateTime.now());
    _blocked = _bed || s.overLimit;
  }

  @override
  void dispose() {
    _tick?.cancel();
    widget.hooks._celebrate = null;
    super.dispose();
  }

  void _celebrate(int sticker, VoidCallback then) {
    if (!mounted) return then();
    setState(() => _sticker = sticker);
    Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _sticker = null);
      then();
    });
  }

  Future<void> _openParents() async {
    if (!await parentGate(context, lang)) return;
    if (!mounted) return;
    await showDialog<void>(context: context, builder: (_) => ParentArea(lang: lang));
    if (mounted) setState(_check);
  }

  Future<void> _unblock() async {
    if (!await parentGate(context, lang)) return;
    final s = KidStore.instance;
    if (_bed) {
      s.allowTonight();
    } else {
      s.addBonus(15);
    }
    if (mounted) setState(_check);
  }

  @override
  Widget build(BuildContext context) {
    final st = _sticker;
    return Stack(children: [
      Positioned.fill(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
            child: Row(children: [
              BigButton(
                size: 46,
                color: KColors.tiles[3],
                tooltip: et(lang, 'stickers'),
                onTap: () => showDialog<void>(context: context, builder: (_) => StickerBook(lang: lang)),
                child: const Icon(Icons.auto_stories, size: 24),
              ),
              const Spacer(),
              BigButton(
                size: 46,
                color: KColors.soft,
                tooltip: et(lang, 'parents'),
                onTap: _openParents,
                child: const Icon(Icons.lock_outline, size: 22),
              ),
            ]),
          ),
          Expanded(child: widget.child),
        ]),
      ),
      if (st != null) Positioned.fill(child: _Celebration(sticker: st, lang: lang)),
      if (_blocked) Positioned.fill(child: _RestScreen(lang: lang, bed: _bed, onParent: _unblock)),
    ]);
  }
}

class _Celebration extends StatelessWidget {
  final int sticker;
  final String lang;
  const _Celebration({required this.sticker, required this.lang});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        color: Colors.white.withValues(alpha: 0.75),
        alignment: Alignment.center,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.3, end: 1.0),
          duration: const Duration(milliseconds: 600),
          curve: Curves.elasticOut,
          builder: (context, v, child) => Transform.scale(scale: v, child: child),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 150,
              height: 150,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: KColors.tiles[sticker % KColors.tiles.length],
                border: Border.all(color: KColors.sun, width: 6),
              ),
              child: Text(kStickers[sticker % kStickers.length], style: const TextStyle(fontSize: 80)),
            ),
            const SizedBox(height: 14),
            Text(et(lang, 'newSticker'), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: KColors.ink)),
          ]),
        ),
      ),
    );
  }
}

class _RestScreen extends StatelessWidget {
  final String lang;
  final bool bed;
  final VoidCallback onParent;
  const _RestScreen({required this.lang, required this.bed, required this.onParent});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF26305A),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(bed ? '🌙' : '🧸', style: const TextStyle(fontSize: 96)),
              const SizedBox(height: 12),
              Text(et(lang, 'restTitle'),
                  textAlign: TextAlign.center, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white)),
              const SizedBox(height: 8),
              Text(et(lang, bed ? 'bedBody' : 'restBody'),
                  textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, color: Color(0xFFDDE3F5))),
              const SizedBox(height: 28),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white54)),
                onPressed: onParent,
                icon: const Icon(Icons.lock_outline),
                label: Text(et(lang, 'parents')),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Yetişkin kontrolü: iki basamaklı çarpma; çocukların ayarlara ve
/// satın almalara kazara girmesini önler.
Future<bool> parentGate(BuildContext context, String lang) async {
  final r = math.Random();
  final a = 6 + r.nextInt(4), b = 6 + r.nextInt(4);
  final answer = a * b;
  final opts = <int>{answer};
  while (opts.length < 4) {
    opts.add(answer + r.nextInt(17) - 8);
  }
  final list = opts.toList()..shuffle(r);
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(et(lang, 'askGrownup')),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(et(lang, 'grownupQ')),
        const SizedBox(height: 12),
        Text('$a × $b = ?', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final o in list) OutlinedButton(onPressed: () => Navigator.of(ctx).pop(o == answer), child: Text('$o')),
        ]),
      ]),
      actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(et(lang, 'cancel')))],
    ),
  );
  return ok ?? false;
}

/// Çıkartma albümü.
class StickerBook extends StatelessWidget {
  final String lang;
  const StickerBook({super.key, required this.lang});

  @override
  Widget build(BuildContext context) {
    final have = KidStore.instance.stickers.toSet();
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            const Icon(Icons.auto_stories),
            const SizedBox(width: 8),
            Expanded(child: Text(et(lang, 'stickers'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
            Text('${have.length}/${KidStore.stickerCount}', style: const TextStyle(fontWeight: FontWeight.w700)),
            IconButton(tooltip: et(lang, 'close'), onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close)),
          ]),
          const SizedBox(height: 8),
          Flexible(
            child: GridView.count(
              shrinkWrap: true,
              crossAxisCount: 6,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              children: [
                for (var i = 0; i < KidStore.stickerCount; i++)
                  Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: have.contains(i) ? KColors.tiles[i % KColors.tiles.length] : const Color(0xFFEDEDED),
                      border: Border.all(color: have.contains(i) ? KColors.sun : Colors.black12, width: 2),
                    ),
                    child: have.contains(i)
                        ? FittedBox(child: Padding(padding: const EdgeInsets.all(4), child: Text(kStickers[i], style: const TextStyle(fontSize: 30))))
                        : const Icon(Icons.star_border, color: Colors.black26),
                  ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

/// Ebeveyn alanı: yerel rapor ve süre ayarları.
class ParentArea extends StatefulWidget {
  final String lang;
  const ParentArea({super.key, required this.lang});

  @override
  State<ParentArea> createState() => _ParentAreaState();
}

class _ParentAreaState extends State<ParentArea> {
  String get lang => widget.lang;

  String _title(String gameId) {
    final t = kGameTitles[gameId];
    if (t != null) return Strings.pick(t, lang);
    return gameId.replaceFirst('oyun-', '').replaceAll('-', ' ');
  }

  Widget _report() {
    final s = KidStore.instance;
    final rep = s.report();
    final hist = s.history;
    final now = DateTime.now();
    final days = [for (var i = 6; i >= 0; i--) KidStore.dayKey(now.subtract(Duration(days: i)))];
    final mx = math.max<int>(60, days.map((d) => hist[d] ?? 0).fold<int>(0, (a, b) => a > b ? a : b));
    final rows = rep.entries.toList()..sort((a, b) => b.value[0].compareTo(a.value[0]));
    return ListView(padding: const EdgeInsets.all(12), children: [
      Text('${et(lang, 'today')}: ${s.todaySeconds ~/ 60} ${et(lang, 'min')}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
      const SizedBox(height: 10),
      Text(et(lang, 'week')),
      const SizedBox(height: 6),
      SizedBox(
        height: 110,
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          for (final d in days)
            Expanded(
              child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                Text('${(hist[d] ?? 0) ~/ 60}', style: const TextStyle(fontSize: 11)),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  height: 4 + 70 * (hist[d] ?? 0) / mx,
                  decoration: BoxDecoration(color: KColors.accent, borderRadius: BorderRadius.circular(4)),
                ),
                const SizedBox(height: 2),
                Text(d.substring(8), style: const TextStyle(fontSize: 11)),
              ]),
            ),
        ]),
      ),
      const Divider(height: 24),
      if (rows.isEmpty) Text(et(lang, 'noData')),
      for (final e in rows)
        ListTile(
          dense: true,
          title: Text(_title(e.key)),
          subtitle: Text('${et(lang, 'played')}: ${e.value[0]} · ${et(lang, 'accuracy')}: '
              '${e.value[1] + e.value[2] == 0 ? '-' : '${(100 * e.value[1] / (e.value[1] + e.value[2])).round()}%'} · '
              '${et(lang, 'time')}: ${e.value[3] ~/ 60} ${et(lang, 'min')}'),
        ),
      const SizedBox(height: 12),
      Text(et(lang, 'localOnly'), style: const TextStyle(fontSize: 12, color: Colors.black54)),
    ]);
  }

  Widget _settings() {
    final s = KidStore.instance;
    String hh(int h) => '${h.toString().padLeft(2, '0')}:00';
    return ListView(padding: const EdgeInsets.all(12), children: [
      Text(et(lang, 'dailyLimit'), style: const TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      Wrap(spacing: 8, runSpacing: 6, children: [
        for (final m in const [0, 15, 30, 45, 60, 90])
          ChoiceChip(
            label: Text(m == 0 ? et(lang, 'off') : '$m ${et(lang, 'min')}'),
            selected: s.limitMinutes == m,
            onSelected: (_) => setState(() => s.limitMinutes = m),
          ),
      ]),
      const Divider(height: 28),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(et(lang, 'bedtime')),
        value: s.bedtimeOn,
        onChanged: (v) => setState(() => s.bedtimeOn = v),
      ),
      if (s.bedtimeOn)
        Row(children: [
          const Icon(Icons.nightlight_round),
          const SizedBox(width: 8),
          DropdownButton<int>(
            value: s.bedFrom,
            items: [for (var h = 17; h <= 23; h++) DropdownMenuItem(value: h, child: Text(hh(h)))],
            onChanged: (v) => setState(() => s.bedFrom = v ?? 20),
          ),
          const Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text('→')),
          const Icon(Icons.wb_sunny_outlined),
          const SizedBox(width: 8),
          DropdownButton<int>(
            value: s.bedTo,
            items: [for (var h = 5; h <= 10; h++) DropdownMenuItem(value: h, child: Text(hh(h)))],
            onChanged: (v) => setState(() => s.bedTo = v ?? 7),
          ),
        ]),
      const SizedBox(height: 16),
      Text(et(lang, 'localOnly'), style: const TextStyle(fontSize: 12, color: Colors.black54)),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: Text(et(lang, 'parents')),
            leading: IconButton(tooltip: et(lang, 'close'), icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
            bottom: TabBar(tabs: [
              Tab(icon: const Icon(Icons.insights), text: et(lang, 'report')),
              Tab(icon: const Icon(Icons.tune), text: et(lang, 'settings')),
            ]),
          ),
          body: TabBarView(children: [_report(), _settings()]),
        ),
      ),
    );
  }
}
