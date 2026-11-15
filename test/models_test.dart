import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:d_watch_gestionale/models.dart';

const oldBackup = '''
{
  "watches": [
    {"id":"a1","name":"Seiko","purchasePlatform":"Vinted","purchasePrice":30,"buyerProfileId":"D",
     "purchaseDate":"2026-09-21","status":"sold","salePlatform":"Vinted","salePrice":50,
     "sellerProfileId":"E","saleDate":"2026-10-02"},
    {"id":"a2","name":"Citizen","purchasePrice":25,"buyerProfileId":"D","purchaseDate":"2026-09-23","status":"stock"}
  ],
  "profiles": [{"id":"E","name":"E"},{"id":"D","name":"D"}],
  "expenses": [{"id":"x1","desc":"Boost","amount":4.6,"watchId":null,"profileId":"E","date":"2026-07-19"}],
  "orders": [{"id":"o1","desc":"Ordine","tracking":"","link":"","status":"In transito","date":"2026-09-27"}]
}
''';

void main() {
  test('legge il backup della versione web', () {
    final db = Db.fromJson(jsonDecode(oldBackup) as Map<String, dynamic>);
    expect(db.watches.length, 2);
    expect(db.profiles.length, 2);
    expect(db.expenses.single.amount, 4.6);
    expect(db.orders.single.status, 'In transito');
    expect(db.watches.first.sellerProfileId, 'E');
    expect(db.watches.first.margin, 20);
    expect(db.profileName('E'), 'E');
    expect(db.profileName('zz'), 'Senza profilo');
  });

  test('esporta e rilegge senza perdere dati', () {
    final db = Db.fromJson(jsonDecode(oldBackup) as Map<String, dynamic>);
    db.watches.add(Watch(
        id: 'c1', name: 'Pezzo di famiglia', purchaseDate: '2026-01-01',
        status: stCollection, collectionDate: '2026-01-02', estimatedValue: 300, notes: 'Eredità'));
    final again = Db.fromJson(jsonDecode(jsonEncode(db.toJson())) as Map<String, dynamic>);
    expect(again.watches.length, 3);
    final c = again.watches.last;
    expect(c.isCollection, true);
    expect(c.collectionYear, 2026);
    expect(c.estimatedValue, 300);
    expect(c.notes, 'Eredità');
    // i campi della collezione non compaiono nei pezzi normali
    expect(again.watches.first.toJson().containsKey('collectionDate'), false);
  });

  test('importare due volte lo stesso file non duplica nulla', () {
    final db = Db();
    final inc = Db.fromJson(jsonDecode(oldBackup) as Map<String, dynamic>);
    final r1 = db.merge(inc);
    expect(r1.total, 6);
    final r2 = db.merge(Db.fromJson(jsonDecode(oldBackup) as Map<String, dynamic>));
    expect(r2.total, 0);
    expect(db.watches.length, 2);
  });

  test('id nuovi sono diversi tra loro', () {
    final ids = List.generate(200, (_) => newId()).toSet();
    expect(ids.length, 200);
  });
}
