import 'models.dart';

/// Importo e numero di operazioni.
class Tot {
  int n = 0;
  double m = 0;
  void add(double v) {
    n++;
    m += v;
  }
}

/// Contatori di un anno solare (o di tutti gli anni se [year] è null).
///
/// Regole di attribuzione:
///  - un acquisto conta nell'anno della data di acquisto;
///  - una vendita nell'anno della data di vendita;
///  - una spesa nell'anno della data della spesa;
///  - i pezzi della collezione restano fuori da acquisti, vendite e netto,
///    e hanno contatori propri (anno di ingresso in collezione).
class YearStats {
  final int? year;
  int acquisti = 0;
  double costoAcquisti = 0;
  int vendite = 0;
  double ricavi = 0;
  double costoVenduti = 0;
  double spese = 0;
  int giacenzaN = 0;
  double giacenzaValore = 0;
  int collezioneN = 0;
  double collezioneCosto = 0;
  double collezioneValore = 0;

  YearStats(this.year);

  /// Cassa: quanto hai incassato meno quanto hai speso nell'anno.
  double get nettoCassa => ricavi - costoAcquisti - spese;

  /// Guadagno sui soli pezzi venduti, al netto delle spese.
  double get margineNetto => ricavi - costoVenduti - spese;

  double get margineLordo => ricavi - costoVenduti;
}

bool _inYear(String? date, int? year) => year == null || yearOf(date) == year;

YearStats computeYear(Db db, int? year) {
  final s = YearStats(year);
  final end = year == null ? '9999-12-31' : '$year-12-31';

  for (final w in db.watches) {
    if (!w.isCollection && _inYear(w.purchaseDate, year)) {
      s.acquisti++;
      s.costoAcquisti += w.purchasePrice;
    }
    if (w.isSold && _inYear(w.saleDate, year)) {
      s.vendite++;
      s.ricavi += w.salePrice ?? 0;
      s.costoVenduti += w.purchasePrice;
    }
    // Giacenza a fine anno: comprato entro l'anno e non ancora venduto.
    final soldLater = w.isSold && (w.saleDate ?? '').compareTo(end) > 0;
    if ((w.isStock || soldLater) && w.purchaseDate.compareTo(end) <= 0) {
      s.giacenzaN++;
      s.giacenzaValore += w.purchasePrice;
    }
    if (w.isCollection && _inYear(w.collectionDate ?? w.purchaseDate, year)) {
      s.collezioneN++;
      s.collezioneCosto += w.purchasePrice;
      s.collezioneValore += w.estimatedValue ?? w.purchasePrice;
    }
  }
  for (final e in db.expenses) {
    if (_inYear(e.date, year)) s.spese += e.amount;
  }
  return s;
}

/// Vendite per profilo che ha venduto (non per chi ha comprato).
Map<String, Tot> salesBySeller(Db db, int? year) {
  final out = <String, Tot>{};
  for (final w in db.watches) {
    if (w.isSold && _inYear(w.saleDate, year)) {
      out.putIfAbsent(w.sellerProfileId ?? '', Tot.new).add(w.salePrice ?? 0);
    }
  }
  return out;
}

Map<String, Tot> salesByPlatform(Db db, int? year) {
  final out = <String, Tot>{};
  for (final w in db.watches) {
    if (w.isSold && _inYear(w.saleDate, year)) {
      out.putIfAbsent(w.salePlatform ?? 'Non specificato', Tot.new).add(w.salePrice ?? 0);
    }
  }
  return out;
}

/// Vendite mese per mese (indice 0 = gennaio). Solo per un anno preciso.
List<Tot> salesByMonth(Db db, int year) {
  final out = List<Tot>.generate(12, (_) => Tot());
  for (final w in db.watches) {
    if (w.isSold && yearOf(w.saleDate) == year) {
      final m = int.tryParse((w.saleDate ?? '').substring(5, 7)) ?? 0;
      if (m >= 1 && m <= 12) out[m - 1].add(w.salePrice ?? 0);
    }
  }
  return out;
}

/// Dettaglio di un profilo in un anno.
class ProfileStats {
  int vendite = 0;
  double ricavi = 0;
  int acquisti = 0;
  double costoAcquisti = 0;
  double spese = 0;
  double get nettoCassa => ricavi - costoAcquisti - spese;
}

ProfileStats computeProfile(Db db, String profileId, int? year) {
  final p = ProfileStats();
  for (final w in db.watches) {
    if (w.isSold && w.sellerProfileId == profileId && _inYear(w.saleDate, year)) {
      p.vendite++;
      p.ricavi += w.salePrice ?? 0;
    }
    if (!w.isCollection && w.buyerProfileId == profileId && _inYear(w.purchaseDate, year)) {
      p.acquisti++;
      p.costoAcquisti += w.purchasePrice;
    }
  }
  for (final e in db.expenses) {
    if (e.profileId == profileId && _inYear(e.date, year)) p.spese += e.amount;
  }
  return p;
}

/// Anni per cui esistono dati, dal più recente (include sempre l'anno corrente).
List<int> availableYears(Db db) {
  final ys = <int>{DateTime.now().year};
  void add(String? d) {
    final y = yearOf(d);
    if (y > 0) ys.add(y);
  }

  for (final w in db.watches) {
    add(w.purchaseDate);
    add(w.saleDate);
    add(w.collectionDate);
  }
  for (final e in db.expenses) {
    add(e.date);
  }
  final l = ys.toList()..sort((a, b) => b.compareTo(a));
  return l;
}
