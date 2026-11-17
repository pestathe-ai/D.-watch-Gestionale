import 'dart:convert';
import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'forms.dart';
import 'format.dart';
import 'models.dart';
import 'stats.dart';
import 'store.dart';
import 'theme.dart';
import 'widgets.dart';

String yearLabel() => app.year == null ? 'Tutti gli anni' : '${app.year}';

String _expNote(Watch w) {
  final le = linkedExpenses(app.db, w.id);
  return le > 0 ? ' · +${eur(le)} spese' : '';
}

/// Guadagno di un pezzo venduto, in euro e in percentuale sul costo totale.
String _profitText(Db db, Watch w) {
  final profit = watchProfit(db, w);
  final cost = w.purchasePrice + linkedExpenses(db, w.id);
  final pc = cost > 0 ? ' · ${(profit / cost * 100).toStringAsFixed(0)}%' : '';
  return '${_signed(profit, money: true)}$pc';
}

String _signed(num v, {bool money = false}) {
  final s = money ? eur(v.toDouble()) : '${v.toInt()}';
  return v >= 0 ? '+$s' : s;
}

// ---------------------------------------------------------------- ACQUISTI

class AcquistiPage extends StatefulWidget {
  const AcquistiPage({super.key});

  @override
  State<AcquistiPage> createState() => _AcquistiPageState();
}

class _AcquistiPageState extends State<AcquistiPage> {
  String _q = '';

  Future<void> _onMenu(String v, Watch w) async {
    switch (v) {
      case 'sell':
        openSheet(context, SellForm(watch: w));
        break;
      case 'edit':
        openSheet(context, WatchForm(edit: w));
        break;
      case 'exp':
        openSheet(context, ExpenseForm(presetWatchId: w.id));
        break;
      case 'coll':
        app.mutate(() {
          w.status = stCollection;
          w.collectionDate = todayIso();
        });
        toast(context, 'Spostato in "Mia collezione".');
        break;
      case 'del':
        if (await confirmDialog(context, 'Eliminare "${w.name}"?')) {
          app.mutate(() => app.db.watches.removeWhere((x) => x.id == w.id));
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = app.db;
    final all = db.watches.where((w) => w.isStock).toList();
    final q = _q.toLowerCase();
    final shown = all.where((w) => w.name.toLowerCase().contains(q)).toList()
      ..sort((a, b) => b.purchaseDate.compareTo(a.purchaseDate));
    final capital = all.fold<double>(0, (s, w) => s + w.purchasePrice);
    final ys = computeYear(db, app.year);
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        HeroCard(
          label: 'In giacenza',
          value: '${all.length} ${all.length == 1 ? 'pezzo' : 'pezzi'}',
          stats: [
            ('Capitale fermo', eur(capital)),
            (app.year == null ? 'Acquisti di sempre' : 'Acquisti ${app.year}', '${ys.acquisti} · ${eur(ys.costoAcquisti)}'),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: TextField(
            onChanged: (v) => setState(() => _q = v),
            decoration: InputDecoration(
              prefixIcon: Icon(Icons.search_rounded, color: context.tk.muted),
              hintText: 'Cerca tra gli acquisti',
            ),
          ),
        ),
        const SectionLabel('Da vendere'),
        if (shown.isEmpty) const EmptyState(Icons.shopping_bag_outlined, 'Nessun acquisto in giacenza.\nTocca "Acquisto" per aggiungerne uno.'),
        for (final w in shown)
          ItemCard(
            leading: Avatar(w.buyerProfileId),
            title: w.name,
            subtitle: '${w.purchasePlatform} · ${fmtDateShort(w.purchaseDate)}${_expNote(w)}',
            trailing: PriceColumn(eur(w.purchasePrice)),
            onTap: () => openSheet(context, SellForm(watch: w)),
            menu: moreMenu(
              context,
              onSelected: (v) => _onMenu(v, w),
              items: const [
                ('sell', 'Segna venduto'),
                ('exp', 'Aggiungi spesa'),
                ('edit', 'Modifica'),
                ('coll', 'Sposta in collezione'),
                ('del', 'Elimina'),
              ],
            ),
          ),
        const DomSignature(),
      ],
    );
  }
}

// ---------------------------------------------------------------- VENDITE

class VenditePage extends StatelessWidget {
  const VenditePage({super.key});

  Future<void> _onMenu(BuildContext context, String v, Watch w) async {
    switch (v) {
      case 'edit':
        openSheet(context, SellForm(watch: w));
        break;
      case 'exp':
        openSheet(context, ExpenseForm(presetWatchId: w.id));
        break;
      case 'undo':
        app.mutate(() {
          w.status = stStock;
          w.salePrice = null;
          w.salePlatform = null;
          w.sellerProfileId = null;
          w.saleDate = null;
        });
        toast(context, 'Vendita annullata: il pezzo è tornato negli acquisti.');
        break;
      case 'del':
        if (await confirmDialog(context, 'Eliminare "${w.name}" e la sua vendita?')) {
          app.mutate(() => app.db.watches.removeWhere((x) => x.id == w.id));
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = app.db;
    final y = app.year;
    final sold = db.watches.where((w) => w.isSold && (y == null || yearOf(w.saleDate) == y)).toList()
      ..sort((a, b) => (b.saleDate ?? '').compareTo(a.saleDate ?? ''));
    final s = computeYear(db, y);
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        HeroCard(
          label: 'Ricavi · ${yearLabel()}',
          value: eur(s.ricavi),
          stats: [
            ('Vendite', '${s.vendite}'),
            ('Guadagno', eur(s.guadagno)),
            if (s.costoVenduti + s.speseLegate > 0)
              ('Ricarico', '${(s.guadagno / (s.costoVenduti + s.speseLegate) * 100).toStringAsFixed(0)}%'),
          ],
        ),
        const SectionLabel('Vendite'),
        if (sold.isEmpty) const EmptyState(Icons.sell_outlined, 'Nessuna vendita in questo periodo.'),
        for (final w in sold)
          ItemCard(
            leading: Avatar(w.sellerProfileId),
            title: w.name,
            subtitle:
                '${w.salePlatform ?? 'Non specificato'} · ${fmtDateShort(w.saleDate)} · costo ${eur(w.purchasePrice)}${linkedExpenses(db, w.id) > 0 ? ' + ${eur(linkedExpenses(db, w.id))} spese' : ''}',
            trailing: PriceColumn(
              eur(w.salePrice ?? 0),
              below: Pill(_profitText(db, w), positive: watchProfit(db, w) >= 0),
            ),
            onTap: () => openSheet(context, SellForm(watch: w)),
            menu: moreMenu(
              context,
              onSelected: (v) => _onMenu(context, v, w),
              items: const [
                ('edit', 'Modifica vendita'),
                ('exp', 'Aggiungi spesa'),
                ('undo', 'Annulla vendita'),
                ('del', 'Elimina'),
              ],
            ),
          ),
        const DomSignature(),
      ],
    );
  }
}

// ---------------------------------------------------------------- COLLEZIONE

class CollezionePage extends StatelessWidget {
  const CollezionePage({super.key});

  Future<void> _onMenu(BuildContext context, String v, Watch w) async {
    switch (v) {
      case 'edit':
        openSheet(context, WatchForm(edit: w, collection: true));
        break;
      case 'sale':
        app.mutate(() {
          w.status = stStock;
          w.collectionDate = null;
        });
        toast(context, 'Il pezzo è tornato negli acquisti, pronto da vendere.');
        break;
      case 'del':
        if (await confirmDialog(context, 'Eliminare "${w.name}" dalla collezione?')) {
          app.mutate(() => app.db.watches.removeWhere((x) => x.id == w.id));
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = app.db.watches.where((w) => w.isCollection).toList();
    final byYear = <int, List<Watch>>{};
    for (final w in items) {
      byYear.putIfAbsent(w.collectionYear, () => []).add(w);
    }
    final years = byYear.keys.toList()..sort((a, b) => b.compareTo(a));
    final cost = items.fold<double>(0, (s, w) => s + w.purchasePrice);
    final value = items.fold<double>(0, (s, w) => s + (w.estimatedValue ?? w.purchasePrice));
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        HeroCard(
          label: 'Valore stimato',
          value: eur(value),
          stats: [
            ('Pezzi', '${items.length}'),
            ('Speso', eur(cost)),
          ],
        ),
        if (items.isEmpty)
          const EmptyState(
            Icons.watch_outlined,
            'La collezione è vuota.\nAggiungi un pezzo con il tasto "Pezzo", oppure sposta un acquisto dal suo menu.',
          ),
        for (var n = 0; n < years.length; n++)
          _YearGroup(
            year: years[n],
            initiallyOpen: n == 0,
            items: (byYear[years[n]]!
              ..sort((a, b) => (b.collectionDate ?? b.purchaseDate).compareTo(a.collectionDate ?? a.purchaseDate))),
            onMenu: (v, w) => _onMenu(context, v, w),
          ),
        const DomSignature(),
      ],
    );
  }
}

class _YearGroup extends StatefulWidget {
  final int year;
  final bool initiallyOpen;
  final List<Watch> items;
  final void Function(String, Watch) onMenu;

  const _YearGroup({required this.year, required this.initiallyOpen, required this.items, required this.onMenu});

  @override
  State<_YearGroup> createState() => _YearGroupState();
}

class _YearGroupState extends State<_YearGroup> {
  late bool _open = widget.initiallyOpen;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final list = widget.items;
    final c = list.fold<double>(0, (s, w) => s + w.purchasePrice);
    final v = list.fold<double>(0, (s, w) => s + (w.estimatedValue ?? w.purchasePrice));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _open = !_open),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
            child: Row(
              children: [
                Text(
                  widget.year == 0 ? 'Senza data' : '${widget.year}',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.4),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${list.length} ${list.length == 1 ? 'pezzo' : 'pezzi'} · speso ${eur(c)} · stima ${eur(v)}',
                    maxLines: 2,
                    style: TextStyle(color: t.muted, fontSize: 12.5),
                  ),
                ),
                AnimatedRotation(
                  turns: _open ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(Icons.expand_more_rounded, color: t.muted),
                ),
              ],
            ),
          ),
        ),
        if (_open)
          for (final w in list)
            ItemCard(
              leading: const IconBadge(Icons.watch_rounded),
              title: w.name,
              subtitle:
                  'Costo ${eur(w.purchasePrice)} · dal ${fmtDateShort(w.collectionDate ?? w.purchaseDate)}${w.notes != null ? '\n${w.notes}' : ''}',
              trailing: w.estimatedValue == null
                  ? null
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(eur(w.estimatedValue!),
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, fontFeatures: kTabular)),
                        Text('stima', style: TextStyle(fontSize: 11, color: t.muted)),
                      ],
                    ),
              onTap: () => openSheet(context, WatchForm(edit: w, collection: true)),
              menu: moreMenu(
                context,
                onSelected: (s) => widget.onMenu(s, w),
                items: const [
                  ('edit', 'Modifica'),
                  ('sale', 'Metti in vendita'),
                  ('del', 'Elimina'),
                ],
              ),
            ),
      ],
    );
  }
}

// ---------------------------------------------------------------- SPESE

class SpesePage extends StatelessWidget {
  const SpesePage({super.key});

  /// Elenco delle spese collegate a un orologio (non compaiono tra le spese generali).
  void _linkedSheet(BuildContext context) {
    final db = app.db;
    final t = context.tk;
    final byId = {for (final w in db.watches) w.id: w};
    final list = db.expenses.where((e) => isLinkedExpense(e, byId)).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    openSheet(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetTitle('Spese collegate a un orologio'),
          Text(
            "Non sono spese generali: contano quando vendi l'orologio, nel suo guadagno.",
            style: TextStyle(color: t.muted, fontSize: 13, height: 1.35),
          ),
          const SizedBox(height: 12),
          for (final e in list)
            Builder(builder: (ctx) {
              final w = byId[e.watchId]!;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                isThreeLine: true,
                title: Text(e.desc),
                subtitle: Text(
                  '${w.name}\n${w.isSold ? 'Contata nella vendita del ${fmtDateShort(w.saleDate)}' : 'In attesa della vendita'}',
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  openSheet(context, ExpenseForm(edit: e));
                },
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(eur(e.amount), style: const TextStyle(fontWeight: FontWeight.w700, fontFeatures: kTabular)),
                    IconButton(
                      tooltip: 'Elimina',
                      icon: Icon(Icons.delete_outline_rounded, color: t.muted),
                      onPressed: () async {
                        if (await confirmDialog(ctx, 'Eliminare la spesa "${e.desc}"?')) {
                          app.mutate(() => db.expenses.removeWhere((x) => x.id == e.id));
                          if (ctx.mounted) Navigator.pop(ctx);
                        }
                      },
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = app.db;
    final y = app.year;
    final byId = {for (final w in db.watches) w.id: w};
    final s = computeYear(db, y);
    final general = db.expenses.where((e) => !isLinkedExpense(e, byId) && (y == null || yearOf(e.date) == y)).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final linked = db.expenses.where((e) => isLinkedExpense(e, byId)).toList();
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        HeroCard(
          label: 'Spese · ${yearLabel()}',
          value: eur(s.spese),
          stats: [
            ('Generali', eur(s.speseGenerali)),
            ('Collegate a vendite', eur(s.speseLegate)),
          ],
        ),
        const SectionLabel('Spese generali'),
        if (general.isEmpty) const EmptyState(Icons.receipt_long_outlined, 'Nessuna spesa generale in questo periodo.'),
        for (final e in general)
          ItemCard(
            leading: Avatar(e.profileId),
            title: e.desc,
            subtitle: '${db.profileName(e.profileId)} · ${fmtDateShort(e.date)}',
            trailing: PriceColumn(eur(e.amount)),
            onTap: () => openSheet(context, ExpenseForm(edit: e)),
            menu: moreMenu(
              context,
              onSelected: (v) async {
                if (v == 'edit') {
                  openSheet(context, ExpenseForm(edit: e));
                } else if (v == 'del') {
                  if (await confirmDialog(context, 'Eliminare la spesa "${e.desc}"?')) {
                    app.mutate(() => db.expenses.removeWhere((x) => x.id == e.id));
                  }
                }
              },
              items: const [('edit', 'Modifica'), ('del', 'Elimina')],
            ),
          ),
        if (linked.isNotEmpty) ...[
          const SectionLabel('Collegate agli orologi'),
          ItemCard(
            leading: const IconBadge(Icons.link_rounded),
            title: '${linked.length} ${linked.length == 1 ? 'spesa collegata' : 'spese collegate'}',
            subtitle: s.speseInSospeso > 0
                ? '${eur(s.speseInSospeso)} in attesa della vendita del pezzo'
                : 'Tutte già contate nelle vendite',
            trailing: Icon(Icons.chevron_right_rounded, color: context.tk.muted),
            onTap: () => _linkedSheet(context),
          ),
        ],
        const DomSignature(),
      ],
    );
  }
}

// ---------------------------------------------------------------- STATISTICHE

class StatsPage extends StatelessWidget {
  const StatsPage({super.key});

  void _profileDetail(BuildContext context, String profileId) {
    final db = app.db;
    final t = context.tk;
    final p = computeProfile(db, profileId, app.year);
    final plats = salesByPlatformFor(db, profileId, app.year).entries.toList()
      ..sort((a, b) => b.value.m.compareTo(a.value.m));
    openSheet(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Avatar(profileId, size: 44),
              const SizedBox(width: 12),
              Expanded(child: SheetTitle('${db.profileName(profileId)} · ${yearLabel()}')),
            ],
          ),
          Row(
            children: [
              Expanded(child: KpiTile(label: 'Vendite', value: '${p.vendite}')),
              const SizedBox(width: 10),
              Expanded(child: KpiTile(label: 'Ricavi', value: eur(p.ricavi))),
              const SizedBox(width: 10),
              Expanded(
                child: KpiTile(label: 'Guadagno', value: eur(p.guadagno), color: p.guadagno >= 0 ? t.green : t.red),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'VENDITE PER PIATTAFORMA',
            style: TextStyle(color: t.muted, fontSize: 11, letterSpacing: 1.4, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          if (plats.isEmpty) Text('Nessuna vendita in questo periodo.', style: TextStyle(color: t.muted)),
          for (final e in plats)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: t.field, borderRadius: BorderRadius.circular(14)),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.key, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(
                          '${e.value.n} ${e.value.n == 1 ? 'vendita' : 'vendite'}',
                          style: TextStyle(color: t.muted, fontSize: 12.5),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(eur(e.value.m), style: const TextStyle(fontWeight: FontWeight.w700, fontFeatures: kTabular)),
                      const SizedBox(height: 4),
                      Pill(_signed(e.value.g, money: true), positive: e.value.g >= 0),
                    ],
                  ),
                ],
              ),
            ),
          const Divider(height: 24),
          _row('Acquisti fatti', '${p.acquisti} · ${eur(p.costoAcquisti)}'),
          _row('Spese', eur(p.spese)),
          _row('Netto di cassa', eur(p.nettoCassa), bold: true),
          const SizedBox(height: 6),
          Text(
            'Il guadagno è il ricavo meno il costo di acquisto e le spese collegate al pezzo.',
            style: TextStyle(fontSize: 12, color: t.muted, height: 1.35),
          ),
        ],
      ),
    );
  }

  static Widget _row(String a, String b, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Expanded(child: Text(a)),
            Text(b, style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w600, fontFeatures: kTabular)),
          ],
        ),
      );

  Widget _bars(
    BuildContext context,
    Map<String, Tot> data, {
    required String Function(String) label,
    Widget Function(String)? avatar,
    void Function(String)? onTap,
  }) {
    final t = context.tk;
    final entries = data.entries.toList()..sort((a, b) => b.value.m.compareTo(a.value.m));
    final maxV = entries.isEmpty ? 1.0 : (entries.first.value.m <= 0 ? 1.0 : entries.first.value.m);
    return Panel(
      child: entries.isEmpty
          ? Text('Nessuna vendita.', style: TextStyle(color: t.muted))
          : Column(
              children: [
                for (var i = 0; i < entries.length; i++)
                  InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: onTap == null ? null : () => onTap(entries[i].key),
                    child: Padding(
                      padding: EdgeInsets.only(top: i == 0 ? 0 : 14),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              if (avatar != null) ...[avatar(entries[i].key), const SizedBox(width: 10)],
                              Expanded(
                                child: Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(text: label(entries[i].key), style: const TextStyle(fontWeight: FontWeight.w700)),
                                      TextSpan(
                                        text: '   ${entries[i].value.n} ${entries[i].value.n == 1 ? 'vendita' : 'vendite'}',
                                        style: TextStyle(color: t.muted, fontSize: 12.5),
                                      ),
                                    ],
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(eur(entries[i].value.m),
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontFeatures: kTabular)),
                              if (onTap != null) Icon(Icons.chevron_right_rounded, size: 18, color: t.muted),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: (entries[i].value.m / maxV).clamp(0.0, 1.0),
                              minHeight: 7,
                              backgroundColor: t.field,
                              color: t.red,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _monthChart(BuildContext context, List<Tot> months) {
    final t = context.tk;
    final maxM = months.fold<double>(0, (a, m) => m.m > a ? m.m : a);
    var maxI = -1;
    for (var i = 0; i < 12; i++) {
      if (months[i].m > 0 && (maxI < 0 || months[i].m > months[maxI].m)) maxI = i;
    }
    return Panel(
      child: SizedBox(
        height: 150,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < 12; i++)
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (months[i].n > 0)
                      Text('${months[i].n}', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: t.muted)),
                    const SizedBox(height: 3),
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0, end: maxM == 0 ? 0 : 96 * months[i].m / maxM),
                      duration: const Duration(milliseconds: 450),
                      curve: Curves.easeOutCubic,
                      builder: (context, h, _) => Container(
                        height: h,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: i == maxI ? t.red : t.red.withValues(alpha: 0.30),
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(monthNames[i].substring(0, 1), style: TextStyle(fontSize: 10.5, color: t.muted)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _delta(BuildContext context, String label, num v, {bool money = false, bool goodWhenUp = true}) {
    final t = context.tk;
    final up = v > 0;
    final neutral = v == 0;
    final good = goodWhenUp ? up : !up;
    final c = neutral ? t.muted : (good ? t.green : t.red);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: t.muted, fontSize: 12)),
        const SizedBox(height: 2),
        Text(
          _signed(v, money: money),
          style: TextStyle(color: c, fontWeight: FontWeight.w800, fontSize: 15, fontFeatures: kTabular),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final db = app.db;
    final y = app.year;
    final s = computeYear(db, y);
    final prev = y == null ? null : computeYear(db, y - 1);
    final hasPrev = prev != null && (prev.vendite > 0 || prev.acquisti > 0 || prev.spese > 0);
    final years = availableYears(db);
    final months = y == null ? null : salesByMonth(db, y);

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            children: [
              _YearChip('Tutti', y == null, () => app.setYear(null)),
              for (final yr in years) _YearChip('$yr', y == yr, () => app.setYear(yr)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.0,
            children: [
              KpiTile(label: 'Ricavi', value: eur(s.ricavi)),
              KpiTile(label: 'Netto di cassa', value: eur(s.nettoCassa), color: s.nettoCassa >= 0 ? t.green : t.red),
              KpiTile(label: 'Acquisti', value: eur(s.costoAcquisti)),
              KpiTile(label: 'Spese', value: eur(s.spese)),
            ],
          ),
        ),
        const SectionLabel('Vendite per profilo'),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Text(
            'Tocca un profilo per vedere le sue vendite per piattaforma.',
            style: TextStyle(color: t.muted, fontSize: 12.5),
          ),
        ),
        _bars(
          context,
          salesBySeller(db, y),
          label: (id) => db.profileName(id),
          avatar: (id) => Avatar(id, size: 32),
          onTap: (id) => _profileDetail(context, id),
        ),
        const SectionLabel('Vendite per piattaforma'),
        _bars(context, salesByPlatform(db, y), label: (k) => k),
        if (months != null) ...[
          SectionLabel('Mese per mese · $y'),
          _monthChart(context, months),
        ],
        _Collapsible(
          title: 'Altri dettagli',
          child: Column(
            children: [
              Panel(
                child: Column(
                  children: [
                    _row('Vendite', '${s.vendite}'),
                    _row('Pezzi acquistati', '${s.acquisti}'),
                    _row('Guadagno sui venduti', eur(s.guadagno)),
                    _row('Guadagno dopo tutte le spese', eur(s.margineNetto)),
                    _row('Spese generali', eur(s.speseGenerali)),
                    _row('Spese collegate a vendite', eur(s.speseLegate)),
                    if (s.speseInSospeso > 0) _row('Spese in attesa della vendita', eur(s.speseInSospeso)),
                    _row('Giacenza a fine periodo (${s.giacenzaN})', eur(s.giacenzaValore)),
                    _row('Collezione (${s.collezioneN})', eur(s.collezioneValore)),
                  ],
                ),
              ),
              if (prev != null && hasPrev) ...[
                SectionLabel('Rispetto al ${y! - 1}'),
                Panel(
                  child: Wrap(
                    spacing: 28,
                    runSpacing: 12,
                    children: [
                      _delta(context, 'Vendite', s.vendite - prev.vendite),
                      _delta(context, 'Ricavi', s.ricavi - prev.ricavi, money: true),
                      _delta(context, 'Spese', s.spese - prev.spese, money: true, goodWhenUp: false),
                      _delta(context, 'Netto di cassa', s.nettoCassa - prev.nettoCassa, money: true),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const DomSignature(),
      ],
    );
  }
}

/// Sezione che si apre e si chiude toccando il titolo.
class _Collapsible extends StatefulWidget {
  final String title;
  final Widget child;
  const _Collapsible({required this.title, required this.child});

  @override
  State<_Collapsible> createState() => _CollapsibleState();
}

class _CollapsibleState extends State<_Collapsible> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _open = !_open),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title.toUpperCase(),
                    style: TextStyle(color: t.muted, fontSize: 11, letterSpacing: 1.4, fontWeight: FontWeight.w700),
                  ),
                ),
                AnimatedRotation(
                  turns: _open ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(Icons.expand_more_rounded, color: t.muted),
                ),
              ],
            ),
          ),
        ),
        if (_open) widget.child,
      ],
    );
  }
}

class _YearChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _YearChip(this.label, this.selected, this.onTap);

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: selected ? t.ink : t.surface,
        shape: StadiumBorder(side: BorderSide(color: selected ? t.ink : t.border)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Center(
              child: Text(
                label,
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: selected ? t.bg : t.ink),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- ORDINI

Future<void> openLink(BuildContext context, String link) async {
  final u = Uri.tryParse(link.trim());
  if (u == null || !u.hasScheme) {
    toast(context, 'Link non valido.');
    return;
  }
  try {
    final ok = await launchUrl(u, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) toast(context, 'Impossibile aprire il link.');
  } catch (_) {
    if (context.mounted) toast(context, 'Impossibile aprire il link.');
  }
}

class OrdiniPage extends StatelessWidget {
  const OrdiniPage({super.key});

  Widget _leading(BuildContext context, Order o) {
    final t = context.tk;
    final done = o.status == 'Consegnato';
    final problem = o.status == 'Problema';
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(color: done ? t.greenSoft : t.redSoft, shape: BoxShape.circle),
      child: Icon(
        done ? Icons.check_rounded : (problem ? Icons.priority_high_rounded : Icons.local_shipping_outlined),
        size: 20,
        color: done ? t.green : t.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final list = [...app.db.orders]..sort((a, b) => b.date.compareTo(a.date));
        return Scaffold(
          appBar: AppBar(title: const Text('Ordini in arrivo')),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => openSheet(context, const OrderForm()),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Ordine'),
          ),
          body: list.isEmpty
              ? const EmptyState(Icons.local_shipping_outlined, 'Nessun ordine registrato.')
              : ListView(
                  padding: const EdgeInsets.only(top: 8),
                  children: [
                    for (final o in list)
                      ItemCard(
                        leading: _leading(context, o),
                        title: o.desc,
                        subtitle: '${o.status} · ${fmtDateShort(o.date)}${o.tracking.isEmpty ? '' : ' · ${o.tracking}'}',
                        onTap: () => o.link.isNotEmpty ? openLink(context, o.link) : openSheet(context, OrderForm(edit: o)),
                        menu: moreMenu(
                          context,
                          onSelected: (v) async {
                            switch (v) {
                              case 'open':
                                openLink(context, o.link);
                                break;
                              case 'done':
                                app.mutate(() => o.status = 'Consegnato');
                                break;
                              case 'edit':
                                openSheet(context, OrderForm(edit: o));
                                break;
                              case 'del':
                                if (await confirmDialog(context, 'Eliminare l\'ordine "${o.desc}"?')) {
                                  app.mutate(() => app.db.orders.removeWhere((x) => x.id == o.id));
                                }
                                break;
                            }
                          },
                          items: [
                            if (o.link.isNotEmpty) ('open', 'Apri tracking'),
                            if (o.status != 'Consegnato') ('done', 'Segna consegnato'),
                            ('edit', 'Modifica'),
                            ('del', 'Elimina'),
                          ],
                        ),
                      ),
                    const SizedBox(height: 96),
                  ],
                ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------- PROFILI

class ProfiliPage extends StatelessWidget {
  const ProfiliPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final db = app.db;
        return Scaffold(
          appBar: AppBar(title: Text('Profili · ${yearLabel()}')),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () async {
              final n = await promptText(context, 'Nome del nuovo profilo');
              if (n != null && n.isNotEmpty) {
                app.mutate(() => db.profiles.add(Profile(id: newId(), name: n)));
              }
            },
            icon: const Icon(Icons.add_rounded),
            label: const Text('Profilo'),
          ),
          body: db.profiles.isEmpty
              ? const EmptyState(Icons.person_outline_rounded, 'Nessun profilo.\nAggiungine uno per attribuire acquisti e vendite.')
              : ListView(
                  padding: const EdgeInsets.only(top: 8),
                  children: [
                    for (final p in db.profiles)
                      Builder(builder: (context) {
                        final st = computeProfile(db, p.id, app.year);
                        return ItemCard(
                          leading: Avatar(p.id),
                          title: p.name,
                          subtitle: '${st.vendite} vendite · ${st.acquisti} acquisti',
                          trailing: PriceColumn(eur(st.ricavi)),
                          menu: moreMenu(
                            context,
                            onSelected: (v) async {
                              if (v == 'rename') {
                                final n = await promptText(context, 'Rinomina profilo', initial: p.name);
                                if (n != null && n.isNotEmpty) app.mutate(() => p.name = n);
                              } else if (v == 'del') {
                                if (await confirmDialog(
                                    context, 'Eliminare il profilo "${p.name}"? Acquisti e vendite collegati restano, ma senza profilo.')) {
                                  app.mutate(() => db.profiles.removeWhere((x) => x.id == p.id));
                                }
                              }
                            },
                            items: const [('rename', 'Rinomina'), ('del', 'Elimina')],
                          ),
                        );
                      }),
                    const SizedBox(height: 96),
                  ],
                ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------- BACKUP

class BackupSheet extends StatelessWidget {
  const BackupSheet({super.key});

  Future<void> _export(BuildContext context) async {
    try {
      final dir = await getTemporaryDirectory();
      final name = 'backup_orologi_${todayIso()}.json';
      final f = File('${dir.path}/$name');
      await f.writeAsString(app.exportJson());
      await SharePlus.instance.share(
        ShareParams(files: [XFile(f.path, mimeType: 'application/json')], subject: name, text: name),
      );
    } catch (e) {
      if (context.mounted) toast(context, 'Esportazione non riuscita: $e');
    }
  }

  Future<void> _import(BuildContext context) async {
    try {
      final file = await FilePicker.pickFile();
      if (file == null) return;
      final bytes = await file.readAsBytes();
      final r = app.importJson(utf8.decode(bytes));
      if (!context.mounted) return;
      if (r.total == 0) {
        toast(context, 'Nessun dato nuovo: erano già tutti presenti.');
      } else {
        Navigator.pop(context);
        toast(context, 'Importati: ${r.watches} orologi, ${r.expenses} spese, ${r.profiles} profili, ${r.orders} ordini.');
      }
    } on FormatException catch (e) {
      if (context.mounted) toast(context, 'File non valido: ${e.message}');
    } catch (e) {
      if (context.mounted) toast(context, 'Importazione non riuscita: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = app.db;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SheetTitle('Backup e dati'),
        Text(
          'Nel telefono ci sono ${db.watches.length} orologi, ${db.expenses.length} spese, '
          '${db.orders.length} ordini e ${db.profiles.length} profili. '
          'I dati restano solo su questo dispositivo: esporta un backup ogni tanto.',
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () => _export(context),
          icon: const Icon(Icons.ios_share),
          label: const Text('Esporta backup (JSON)'),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => _import(context),
          icon: const Icon(Icons.file_open_outlined),
          label: const Text('Importa backup (JSON)'),
        ),
        const SizedBox(height: 10),
        Text(
          "L'importazione aggiunge i dati del file senza cancellare quelli già presenti. "
          'Funziona anche con i backup della versione web.',
          style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
        ),
      ],
    );
  }
}
