import 'package:flutter/material.dart';

import 'forms.dart';
import 'pages.dart';
import 'stats.dart';
import 'store.dart';
import 'theme.dart';
import 'widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await app.load();
  runApp(const WatchApp());
}

class WatchApp extends StatelessWidget {
  const WatchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'D. Watch Gestionale',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      home: const Home(),
    );
  }
}

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int _i = 0;

  static const _titles = ['Acquisti', 'Vendite', 'Collezione', 'Spese', 'Statistiche'];
  /// Le pagine si creano a ogni aggiornamento (senza const) così si ridisegnano
  /// subito dopo ogni salvataggio.
  Widget _page() {
    switch (_i) {
      case 0:
        return AcquistiPage();
      case 1:
        return VenditePage();
      case 2:
        return CollezionePage();
      case 3:
        return SpesePage();
      default:
        return StatsPage();
    }
  }

  Widget? _fab(BuildContext context) {
    switch (_i) {
      case 0:
        return FloatingActionButton.extended(
          onPressed: () => openSheet(context, const WatchForm()),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Acquisto'),
        );
      case 1:
        return FloatingActionButton.extended(
          onPressed: () => openSheet(context, const QuickSaleForm()),
          icon: const Icon(Icons.bolt_rounded),
          label: const Text('Vendita veloce'),
        );
      case 2:
        return FloatingActionButton.extended(
          onPressed: () => openSheet(context, const WatchForm(collection: true)),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Pezzo'),
        );
      case 3:
        return FloatingActionButton.extended(
          onPressed: () => openSheet(context, const ExpenseForm()),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Spesa'),
        );
      default:
        return null;
    }
  }

  Widget _circle(BuildContext context, IconData icon) {
    final t = context.tk;
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: t.surface,
        shape: BoxShape.circle,
        border: Border.all(color: t.border),
      ),
      child: Icon(icon, color: t.ink, size: 22),
    );
  }

  Widget _header(BuildContext context) {
    final t = context.tk;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'D. WATCH',
                  style: TextStyle(color: t.red, fontSize: 11, letterSpacing: 1.6, fontWeight: FontWeight.w800),
                ),
                Text(
                  _titles[_i],
                  style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -0.6, height: 1.15),
                ),
              ],
            ),
          ),
          PopupMenuButton<int>(
            tooltip: 'Anno',
            onSelected: (v) => app.setYear(v == 0 ? null : v),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 0, child: Text('Tutti gli anni')),
              for (final y in availableYears(app.db)) PopupMenuItem(value: y, child: Text('$y')),
            ],
            child: Container(
              height: 44,
              padding: const EdgeInsets.only(left: 16, right: 8),
              decoration: BoxDecoration(
                color: t.surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: t.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    app.year == null ? 'Tutti' : '${app.year}',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  Icon(Icons.expand_more_rounded, color: t.muted, size: 20),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            tooltip: 'Menu',
            onSelected: (v) {
              if (v == 'ordini') {
                Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const OrdiniPage()));
              } else if (v == 'profili') {
                Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const ProfiliPage()));
              } else if (v == 'backup') {
                openSheet(context, const BackupSheet());
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'ordini', child: Text('Ordini in arrivo')),
              PopupMenuItem(value: 'profili', child: Text('Profili')),
              PopupMenuItem(value: 'backup', child: Text('Backup e dati')),
            ],
            child: _circle(context, Icons.more_horiz_rounded),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                _header(context),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: KeyedSubtree(key: ValueKey<int>(_i), child: _page()),
                  ),
                ),
              ],
            ),
          ),
          floatingActionButton: _fab(context),
          bottomNavigationBar: DecoratedBox(
            decoration: BoxDecoration(border: Border(top: BorderSide(color: context.tk.border))),
            child: NavigationBar(
              selectedIndex: _i,
              onDestinationSelected: (i) => setState(() => _i = i),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.shopping_bag_outlined),
                  selectedIcon: Icon(Icons.shopping_bag_rounded),
                  label: 'Acquisti',
                ),
                NavigationDestination(
                  icon: Icon(Icons.sell_outlined),
                  selectedIcon: Icon(Icons.sell_rounded),
                  label: 'Vendite',
                ),
                NavigationDestination(
                  icon: Icon(Icons.watch_outlined),
                  selectedIcon: Icon(Icons.watch_rounded),
                  label: 'Collezione',
                ),
                NavigationDestination(
                  icon: Icon(Icons.receipt_long_outlined),
                  selectedIcon: Icon(Icons.receipt_long_rounded),
                  label: 'Spese',
                ),
                NavigationDestination(
                  icon: Icon(Icons.bar_chart_outlined),
                  selectedIcon: Icon(Icons.bar_chart_rounded),
                  label: 'Stats',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
