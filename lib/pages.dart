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
import 'widgets.dart';

String yearLabel() => app.year == null ? 'Tutti gli anni' : '${app.year}';

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
      children: [
        SummaryCard(title: 'In giacenza', rows: [
          ('Pezzi da vendere', '${all.length}'),
          ('Capitale fermo', eur(capital)),
        ]),
        SummaryCard(
          title: app.year == null ? 'Acquisti di sempre' : 'Acquisti ${app.year}',
          rows: [
            ('Pezzi acquistati', '${ys.acquisti}'),
            ('Speso', eur(ys.costoAcquisti)),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: TextField(
            onChanged: (v) => setState(() => _q = v),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Cerca tra gli acquisti',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
        if (shown.isEmpty) const EmptyNote('Nessun acquisto in giacenza.\nTocca "Acquisto" per aggiungerne uno.'),
        for (final w in shown)
          ListTile(
            title: Text(w.name),
            subtitle: Text(
              '${eur(w.purchasePrice)} · ${db.profileName(w.buyerProfileId)} · ${w.purchasePlatform} · ${fmtDate(w.purchaseDate)}',
            ),
            onTap: () => openSheet(context, SellForm(watch: w)),
            trailing: PopupMenuButton<String>(
              onSelected: (v) => _onMenu(v, w),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'sell', child: Text('Segna venduto')),
                PopupMenuItem(value: 'edit', child: Text('Modifica')),
                PopupMenuItem(value: 'coll', child: Text('Sposta in collezione')),
                PopupMenuItem(value: 'del', child: Text('Elimina')),
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
      children: [
        SummaryCard(title: 'Vendite · ${yearLabel()}', rows: [
          ('Pezzi venduti', '${s.vendite}'),
          ('Ricavi (lordo)', eur(s.ricavi)),
          ('Guadagno sui pezzi venduti', eur(s.margineLordo)),
        ]),
        if (sold.isEmpty) const EmptyNote('Nessuna vendita in questo periodo.'),
        for (final w in sold)
          ListTile(
            title: Text(w.name),
            subtitle: Text(
              '${eur(w.purchasePrice)} → ${eur(w.salePrice ?? 0)} · ${db.profileName(w.sellerProfileId)} · ${w.salePlatform ?? ''} · ${fmtDate(w.saleDate)}',
            ),
            onTap: () => openSheet(context, SellForm(watch: w)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _signed(w.margin, money: true),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: w.margin >= 0 ? const Color(0xFF2E7D32) : kRed,
                      ),
                    ),
                    if (w.purchasePrice > 0)
                      Text(
                        '${(w.margin / w.purchasePrice * 100).toStringAsFixed(0)}%',
                        style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor),
                      ),
                  ],
                ),
                PopupMenuButton<String>(
                  onSelected: (v) => _onMenu(context, v, w),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Modifica vendita')),
                    PopupMenuItem(value: 'undo', child: Text('Annulla vendita')),
                    PopupMenuItem(value: 'del', child: Text('Elimina')),
                  ],
                ),
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
    final thisYear = DateTime.now().year;
    return ListView(
      children: [
        SummaryCard(title: 'La mia collezione', rows: [
          ('Pezzi', '${items.length}'),
          ('Speso', eur(cost)),
          ('Valore stimato', eur(value)),
        ]),
        if (items.isEmpty)
          const EmptyNote('La collezione è vuota.\nAggiungi un pezzo con il tasto "Pezzo", oppure sposta un acquisto dal suo menu.'),
        for (final y in years)
          Builder(builder: (context) {
            final list = byYear[y]!..sort((a, b) => (b.collectionDate ?? b.purchaseDate).compareTo(a.collectionDate ?? a.purchaseDate));
            final c = list.fold<double>(0, (s, w) => s + w.purchasePrice);
            final v = list.fold<double>(0, (s, w) => s + (w.estimatedValue ?? w.purchasePrice));
            return Card(
              margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              clipBehavior: Clip.antiAlias,
              child: ExpansionTile(
                initiallyExpanded: y == thisYear,
                shape: const Border(),
                collapsedShape: const Border(),
                title: Text(
                  '${y == 0 ? 'Senza data' : y} · ${list.length} ${list.length == 1 ? 'pezzo' : 'pezzi'}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text('Speso ${eur(c)} · Valore ${eur(v)}'),
                children: [
                  for (final w in list)
                    ListTile(
                      title: Text(w.name),
                      subtitle: Text(
                        'Costo ${eur(w.purchasePrice)}${w.estimatedValue != null ? ' · Stima ${eur(w.estimatedValue!)}' : ''} · dal ${fmtDate(w.collectionDate ?? w.purchaseDate)}'
                        '${w.notes != null ? '\n${w.notes}' : ''}',
                      ),
                      onTap: () => openSheet(context, WatchForm(edit: w, collection: true)),
                      trailing: PopupMenuButton<String>(
                        onSelected: (s) => _onMenu(context, s, w),
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'edit', child: Text('Modifica')),
                          PopupMenuItem(value: 'sale', child: Text('Metti in vendita')),
                          PopupMenuItem(value: 'del', child: Text('Elimina')),
                        ],
                      ),
                    ),
                ],
              ),
            );
          }),
        const DomSignature(),
      ],
    );
  }
}

// ---------------------------------------------------------------- SPESE

class SpesePage extends StatelessWidget {
  const SpesePage({super.key});

  @override
  Widget build(BuildContext context) {
    final db = app.db;
    final y = app.year;
    final list = db.expenses.where((e) => y == null || yearOf(e.date) == y).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final total = list.fold<double>(0, (s, e) => s + e.amount);
    return ListView(
      children: [
        SummaryCard(title: 'Spese · ${yearLabel()}', rows: [
          ('Numero di spese', '${list.length}'),
          ('Totale', eur(total)),
        ]),
        if (list.isEmpty) const EmptyNote('Nessuna spesa in questo periodo.'),
        for (final e in list)
          ListTile(
            title: Text(e.desc),
            subtitle: Text('${db.profileName(e.profileId)} · ${fmtDate(e.date)}'),
            onTap: () => openSheet(context, ExpenseForm(edit: e)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(eur(e.amount), style: const TextStyle(fontWeight: FontWeight.w700)),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    if (await confirmDialog(context, 'Eliminare la spesa "${e.desc}"?')) {
                      app.mutate(() => db.expenses.removeWhere((x) => x.id == e.id));
                    }
                  },
                ),
              ],
            ),
          ),
        const DomSignature(),
      ],
    );
  }
}

// ---------------------------------------------------------------- STATISTICHE

class StatsPage extends StatelessWidget {
  const StatsPage({super.key});

  void _profileDetail(BuildContext context, String profileId) {
    final p = computeProfile(app.db, profileId, app.year);
    openSheet(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SheetTitle('${app.db.profileName(profileId)} · ${yearLabel()}'),
          _row('Vendite fatte', '${p.vendite}'),
          _row('Ricavi', eur(p.ricavi)),
          _row('Acquisti fatti', '${p.acquisti}'),
          _row('Costo acquisti', eur(p.costoAcquisti)),
          _row('Spese', eur(p.spese)),
          const Divider(),
          _row('Netto di cassa', eur(p.nettoCassa), bold: true),
          const SizedBox(height: 8),
          Text(
            'Le vendite contano per il profilo che ha venduto, gli acquisti e il loro costo per quello che ha comprato.',
            style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
          ),
        ],
      ),
    );
  }

  static Widget _row(String a, String b, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(child: Text(a)),
            Text(b, style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w600)),
          ],
        ),
      );

  Widget _tableCard(BuildContext context, String title, Map<String, Tot> data, String Function(String) label,
      {void Function(String)? onTap}) {
    final entries = data.entries.toList()..sort((a, b) => b.value.m.compareTo(a.value.m));
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            if (entries.isEmpty) const Text('Nessuna vendita.'),
            for (final e in entries)
              InkWell(
                onTap: onTap == null ? null : () => onTap(e.key),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(
                    children: [
                      Expanded(child: Text('${label(e.key)}${onTap != null ? '  ›' : ''}')),
                      Text('${e.value.n} · ', style: TextStyle(color: Theme.of(context).hintColor)),
                      Text(eur(e.value.m), style: const TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = app.db;
    final y = app.year;
    final s = computeYear(db, y);
    final prev = y == null ? null : computeYear(db, y - 1);
    final hasPrev = prev != null && (prev.vendite > 0 || prev.acquisti > 0 || prev.spese > 0);
    final years = availableYears(db);
    final months = y == null ? null : salesByMonth(db, y);
    final maxM = months == null ? 0.0 : months.fold<double>(0, (a, t) => t.m > a ? t.m : a);

    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
          child: Wrap(
            spacing: 8,
            children: [
              ChoiceChip(label: const Text('Tutti'), selected: y == null, onSelected: (_) => app.setYear(null)),
              for (final yr in years)
                ChoiceChip(label: Text('$yr'), selected: y == yr, onSelected: (_) => app.setYear(yr)),
            ],
          ),
        ),
        SummaryCard(title: 'Riepilogo · ${yearLabel()}', rows: [
          ('Vendite', '${s.vendite}'),
          ('Ricavi', eur(s.ricavi)),
          ('Acquisti (${s.acquisti} pezzi)', '-${eur(s.costoAcquisti)}'),
          ('Spese', '-${eur(s.spese)}'),
          ('Netto di cassa', eur(s.nettoCassa)),
          ('Guadagno sui pezzi venduti, dopo le spese', eur(s.margineNetto)),
          ('Giacenza a fine periodo (${s.giacenzaN} pezzi)', eur(s.giacenzaValore)),
          ('Collezione (${s.collezioneN} pezzi)', eur(s.collezioneValore)),
        ]),
        if (prev != null && hasPrev)
          SummaryCard(title: 'Rispetto al ${y! - 1}', rows: [
            ('Vendite', _signed(s.vendite - prev.vendite)),
            ('Ricavi', _signed(s.ricavi - prev.ricavi, money: true)),
            ('Spese', _signed(s.spese - prev.spese, money: true)),
            ('Netto di cassa', _signed(s.nettoCassa - prev.nettoCassa, money: true)),
          ]),
        _tableCard(
          context,
          'Vendite per profilo (chi ha venduto)',
          salesBySeller(db, y),
          (id) => db.profileName(id),
          onTap: (id) => _profileDetail(context, id),
        ),
        _tableCard(context, 'Vendite per piattaforma', salesByPlatform(db, y), (k) => k),
        if (months != null)
          Card(
            margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Vendite mese per mese · $y',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 140,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (var i = 0; i < 12; i++)
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (months[i].n > 0)
                                  Text('${months[i].n}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
                                Container(
                                  height: maxM == 0 ? 0 : 90 * months[i].m / maxM,
                                  margin: const EdgeInsets.symmetric(horizontal: 3),
                                  decoration: BoxDecoration(color: kRed, borderRadius: BorderRadius.circular(3)),
                                ),
                                const SizedBox(height: 4),
                                Text(monthNames[i], style: const TextStyle(fontSize: 9)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        const DomSignature(),
      ],
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
            icon: const Icon(Icons.add),
            label: const Text('Ordine'),
          ),
          body: list.isEmpty
              ? const EmptyNote('Nessun ordine registrato.')
              : ListView(
                  children: [
                    for (final o in list)
                      ListTile(
                        leading: Icon(
                          o.status == 'Consegnato'
                              ? Icons.check_circle
                              : o.status == 'Problema'
                                  ? Icons.error_outline
                                  : Icons.local_shipping_outlined,
                          color: o.status == 'Consegnato' ? const Color(0xFF2E7D32) : null,
                        ),
                        title: Text(o.desc),
                        subtitle: Text(
                          '${o.status} · ${fmtDate(o.date)}${o.tracking.isEmpty ? '' : ' · ${o.tracking}'}',
                        ),
                        onTap: () => o.link.isNotEmpty
                            ? openLink(context, o.link)
                            : openSheet(context, OrderForm(edit: o)),
                        trailing: PopupMenuButton<String>(
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
                          itemBuilder: (_) => [
                            if (o.link.isNotEmpty) const PopupMenuItem(value: 'open', child: Text('Apri tracking')),
                            if (o.status != 'Consegnato') const PopupMenuItem(value: 'done', child: Text('Segna consegnato')),
                            const PopupMenuItem(value: 'edit', child: Text('Modifica')),
                            const PopupMenuItem(value: 'del', child: Text('Elimina')),
                          ],
                        ),
                      ),
                    const SizedBox(height: 90),
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
            icon: const Icon(Icons.add),
            label: const Text('Profilo'),
          ),
          body: db.profiles.isEmpty
              ? const EmptyNote('Nessun profilo. Aggiungine uno per attribuire acquisti e vendite.')
              : ListView(
                  children: [
                    for (final p in db.profiles)
                      Builder(builder: (context) {
                        final st = computeProfile(db, p.id, app.year);
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: kRed,
                            foregroundColor: Colors.white,
                            child: Text(p.name.isEmpty ? '?' : p.name.characters.first.toUpperCase()),
                          ),
                          title: Text(p.name),
                          subtitle: Text('${st.vendite} vendite · ${eur(st.ricavi)} · acquisti ${st.acquisti}'),
                          trailing: PopupMenuButton<String>(
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
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'rename', child: Text('Rinomina')),
                              PopupMenuItem(value: 'del', child: Text('Elimina')),
                            ],
                          ),
                        );
                      }),
                    const SizedBox(height: 90),
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
