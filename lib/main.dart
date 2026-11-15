import 'package:flutter/material.dart';

import 'forms.dart';
import 'pages.dart';
import 'stats.dart';
import 'store.dart';
import 'widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await app.load();
  runApp(const WatchApp());
}

ThemeData _theme(Brightness b) {
  final cs = ColorScheme.fromSeed(seedColor: kRed, brightness: b);
  final light = b == Brightness.light;
  return ThemeData(
    useMaterial3: true,
    colorScheme: cs,
    scaffoldBackgroundColor: light ? const Color(0xFFFFFBFA) : null,
    appBarTheme: AppBarTheme(
      backgroundColor: light ? kRed : cs.surface,
      foregroundColor: light ? Colors.white : cs.onSurface,
    ),
  );
}

class WatchApp extends StatelessWidget {
  const WatchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'D. Watch Gestionale',
      debugShowCheckedModeBanner: false,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
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

  static const _titles = ['Acquisti', 'Vendite', 'Mia collezione', 'Spese', 'Statistiche'];
  static const _pages = <Widget>[
    AcquistiPage(),
    VenditePage(),
    CollezionePage(),
    SpesePage(),
    StatsPage(),
  ];

  Widget? _fab(BuildContext context) {
    switch (_i) {
      case 0:
        return FloatingActionButton.extended(
          onPressed: () => openSheet(context, const WatchForm()),
          icon: const Icon(Icons.add),
          label: const Text('Acquisto'),
        );
      case 1:
        return FloatingActionButton.extended(
          onPressed: () => openSheet(context, const QuickSaleForm()),
          icon: const Icon(Icons.bolt),
          label: const Text('Vendita veloce'),
        );
      case 2:
        return FloatingActionButton.extended(
          onPressed: () => openSheet(context, const WatchForm(collection: true)),
          icon: const Icon(Icons.add),
          label: const Text('Pezzo'),
        );
      case 3:
        return FloatingActionButton.extended(
          onPressed: () => openSheet(context, const ExpenseForm()),
          icon: const Icon(Icons.add),
          label: const Text('Spesa'),
        );
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: Text(_titles[_i]),
            actions: [
              PopupMenuButton<int>(
                tooltip: 'Anno',
                onSelected: (v) => app.setYear(v == 0 ? null : v),
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 0, child: Text('Tutti gli anni')),
                  for (final y in availableYears(app.db)) PopupMenuItem(value: y, child: Text('$y')),
                ],
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(yearLabel(), style: const TextStyle(fontWeight: FontWeight.w700)),
                      const Icon(Icons.arrow_drop_down),
                    ],
                  ),
                ),
              ),
              PopupMenuButton<String>(
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
              ),
            ],
          ),
          body: _pages[_i],
          floatingActionButton: _fab(context),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _i,
            onDestinationSelected: (i) => setState(() => _i = i),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.shopping_bag_outlined), label: 'Acquisti'),
              NavigationDestination(icon: Icon(Icons.sell_outlined), label: 'Vendite'),
              NavigationDestination(icon: Icon(Icons.watch_outlined), label: 'Collezione'),
              NavigationDestination(icon: Icon(Icons.receipt_long_outlined), label: 'Spese'),
              NavigationDestination(icon: Icon(Icons.bar_chart_outlined), label: 'Stats'),
            ],
          ),
        );
      },
    );
  }
}
