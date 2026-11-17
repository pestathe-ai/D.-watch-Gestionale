import 'package:flutter_test/flutter_test.dart';
import 'package:d_watch_gestionale/models.dart';
import 'package:d_watch_gestionale/stats.dart';
import 'package:d_watch_gestionale/format.dart';

Db sample() => Db(
      profiles: [Profile(id: 'D', name: 'D'), Profile(id: 'E', name: 'E')],
      watches: [
        Watch(id: 'w1', name: 'Stock 2025', purchasePrice: 40, buyerProfileId: 'D', purchaseDate: '2025-12-20'),
        // comprato a dicembre dal profilo D, venduto a gennaio dal profilo E
        Watch(
            id: 'w2', name: 'A cavallo', purchasePrice: 30, buyerProfileId: 'D', purchaseDate: '2025-12-28',
            status: stSold, salePlatform: 'Vinted', salePrice: 100, sellerProfileId: 'E', saleDate: '2026-01-05'),
        Watch(
            id: 'w3', name: 'Normale', purchasePrice: 20, buyerProfileId: 'E', purchaseDate: '2026-02-01',
            status: stSold, salePlatform: 'eBay', salePrice: 50, sellerProfileId: 'E', saleDate: '2026-03-10'),
        Watch(
            id: 'w4', name: 'Collezione', purchasePrice: 200, buyerProfileId: 'D', purchaseDate: '2026-04-01',
            status: stCollection, collectionDate: '2026-04-02', estimatedValue: 350),
      ],
      expenses: [
        Expense(id: 'e1', desc: 'Cinturini', amount: 10, profileId: 'D', date: '2026-02-02'),
        Expense(id: 'e2', desc: 'Buste', amount: 5, profileId: 'D', date: '2025-12-30'),
        // collegata a un pezzo venduto: conta nell'anno della vendita (2026)
        Expense(id: 'e3', desc: 'Boost', amount: 4, watchId: 'w3', profileId: 'E', date: '2025-12-31'),
        // collegata a un pezzo ancora in giacenza: non conta finché non lo vendi
        Expense(id: 'e4', desc: 'Scatola', amount: 7, watchId: 'w1', profileId: 'D', date: '2026-01-10'),
      ],
    );

void main() {
  test('anno 2025: acquisti, spese e giacenza a fine anno', () {
    final s = computeYear(sample(), 2025);
    expect(s.acquisti, 2);
    expect(s.costoAcquisti, 70);
    expect(s.vendite, 0);
    expect(s.spese, 5);
    expect(s.speseCassa, 9);
    expect(s.giacenzaN, 2);
    expect(s.giacenzaValore, 70);
    expect(s.collezioneN, 0);
    expect(s.nettoCassa, -79);
  });

  test('anno 2026: la collezione resta fuori da acquisti e netto', () {
    final s = computeYear(sample(), 2026);
    expect(s.acquisti, 1);
    expect(s.costoAcquisti, 20);
    expect(s.vendite, 2);
    expect(s.ricavi, 150);
    expect(s.costoVenduti, 50);
    expect(s.spese, 14);
    expect(s.speseCassa, 17);
    expect(s.speseGenerali, 10);
    expect(s.speseLegate, 4);
    expect(s.speseInSospeso, 7);
    expect(s.giacenzaN, 1);
    expect(s.giacenzaValore, 40);
    expect(s.collezioneN, 1);
    expect(s.collezioneCosto, 200);
    expect(s.collezioneValore, 350);
    expect(s.nettoCassa, 113);
    expect(s.margineNetto, 86);
    expect(s.guadagno, 96);
  });

  test('tutti gli anni', () {
    final s = computeYear(sample(), null);
    expect(s.acquisti, 3);
    expect(s.costoAcquisti, 90);
    expect(s.vendite, 2);
    expect(s.spese, 19);
    expect(s.speseCassa, 26);
    expect(s.giacenzaN, 1);
    expect(s.collezioneN, 1);
  });

  test('le vendite vanno al profilo che ha venduto, non a chi ha comprato', () {
    final bySeller = salesBySeller(sample(), 2026);
    expect(bySeller.containsKey('D'), false);
    expect(bySeller['E']!.n, 2);
    expect(bySeller['E']!.m, 150);

    final d = computeProfile(sample(), 'D', 2026);
    expect(d.vendite, 0);
    expect(d.ricavi, 0);
    expect(d.spese, 17);
    final e = computeProfile(sample(), 'E', 2026);
    expect(e.vendite, 2);
    expect(e.ricavi, 150);
    expect(e.acquisti, 1);
    expect(e.costoAcquisti, 20);
    expect(e.spese, 0);
    expect(e.guadagno, 96);
    expect(e.nettoCassa, 130);
  });

  test('la spesa collegata entra nel guadagno del pezzo quando lo vendi', () {
    final db = sample();
    final w3 = db.watches.firstWhere((w) => w.id == 'w3');
    expect(linkedExpenses(db, 'w3'), 4);
    expect(watchProfit(db, w3), 26); // 50 - 20 - 4
    final w1 = db.watches.firstWhere((w) => w.id == 'w1');
    expect(linkedExpenses(db, 'w1'), 7);
    // venduto il pezzo, la spesa da 7 comincia a contare
    w1.status = stSold;
    w1.salePrice = 100;
    w1.saleDate = '2026-05-01';
    expect(watchProfit(db, w1), 53); // 100 - 40 - 7
    final s = computeYear(db, 2026);
    expect(s.speseInSospeso, 0);
    expect(s.speseLegate, 11);
  });

  test('dettaglio di un profilo per piattaforma', () {
    final db = sample();
    final p = salesByPlatformFor(db, 'E', 2026);
    expect(p.keys.toSet(), {'Vinted', 'eBay'});
    expect(p['Vinted']!.n, 1);
    expect(p['Vinted']!.m, 100);
    expect(p['Vinted']!.g, 70); // 100 - 30
    expect(p['eBay']!.g, 26);
    expect(salesByPlatformFor(db, 'D', 2026).isEmpty, true);
  });

  test('vendite per mese e per piattaforma', () {
    final m = salesByMonth(sample(), 2026);
    expect(m[0].n, 1);
    expect(m[0].m, 100);
    expect(m[2].n, 1);
    expect(m[2].m, 50);
    expect(m[5].n, 0);
    final p = salesByPlatform(sample(), 2026);
    expect(p['Vinted']!.m, 100);
    expect(p['eBay']!.m, 50);
  });

  test('anni disponibili', () {
    final y = availableYears(sample());
    expect(y.contains(2025), true);
    expect(y.contains(2026), true);
    expect(y.first >= y.last, true);
  });

  test('formato euro e date', () {
    expect(eur(1234.5), '1.234,50 €');
    expect(eur(0), '0,00 €');
    expect(eur(-5), '-5,00 €');
    expect(eur(1234567.891), '1.234.567,89 €');
    expect(parseNum('12,5'), 12.5);
    expect(parseNum(''), null);
    expect(fmtDate('2026-11-15'), '15/11/2026');
    expect(fmtDateShort('2000-03-05'), '5 mar 2000');
  });
}
