import 'dart:math';

double _d(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse('${v ?? ''}'.replaceAll(',', '.')) ?? 0;
}

double? _dn(dynamic v) {
  if (v == null) return null;
  if (v is String && v.trim().isEmpty) return null;
  return _d(v);
}

String? _sn(dynamic v) {
  if (v == null) return null;
  final s = v.toString();
  return s.isEmpty ? null : s;
}

/// Anno di una data in formato aaaa-mm-gg (0 se mancante o non valida).
int yearOf(String? date) {
  if (date == null || date.length < 4) return 0;
  return int.tryParse(date.substring(0, 4)) ?? 0;
}

String todayIso() {
  final n = DateTime.now();
  return '${n.year.toString().padLeft(4, '0')}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
}

String newId() {
  final t = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  final r = Random().nextInt(1 << 20).toRadixString(36);
  return '$t$r';
}

class Profile {
  final String id;
  String name;
  Profile({required this.id, required this.name});

  factory Profile.fromJson(Map<String, dynamic> j) =>
      Profile(id: j['id'].toString(), name: (j['name'] ?? '').toString());

  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}

/// Stati possibili di un orologio.
const String stStock = 'stock';
const String stSold = 'sold';
const String stCollection = 'collection';

class Watch {
  final String id;
  String name;
  String purchasePlatform;
  double purchasePrice;
  String? buyerProfileId;
  String purchaseDate;
  String status;
  String? salePlatform;
  double? salePrice;
  String? sellerProfileId;
  String? saleDate;
  // Mia collezione
  String? collectionDate;
  double? estimatedValue;
  String? notes;

  Watch({
    required this.id,
    required this.name,
    this.purchasePlatform = 'Non specificato',
    this.purchasePrice = 0,
    this.buyerProfileId,
    required this.purchaseDate,
    this.status = stStock,
    this.salePlatform,
    this.salePrice,
    this.sellerProfileId,
    this.saleDate,
    this.collectionDate,
    this.estimatedValue,
    this.notes,
  });

  factory Watch.fromJson(Map<String, dynamic> j) => Watch(
        id: j['id'].toString(),
        name: (j['name'] ?? '').toString(),
        purchasePlatform: (j['purchasePlatform'] ?? 'Non specificato').toString(),
        purchasePrice: _d(j['purchasePrice']),
        buyerProfileId: _sn(j['buyerProfileId']),
        purchaseDate: (j['purchaseDate'] ?? '').toString(),
        status: (j['status'] ?? stStock).toString(),
        salePlatform: _sn(j['salePlatform']),
        salePrice: _dn(j['salePrice']),
        sellerProfileId: _sn(j['sellerProfileId']),
        saleDate: _sn(j['saleDate']),
        collectionDate: _sn(j['collectionDate']),
        estimatedValue: _dn(j['estimatedValue']),
        notes: _sn(j['notes']),
      );

  Map<String, dynamic> toJson() {
    final m = <String, dynamic>{
      'id': id,
      'name': name,
      'purchasePlatform': purchasePlatform,
      'purchasePrice': purchasePrice,
      'buyerProfileId': buyerProfileId,
      'purchaseDate': purchaseDate,
      'status': status,
    };
    void put(String k, dynamic v) {
      if (v != null) m[k] = v;
    }

    put('salePlatform', salePlatform);
    put('salePrice', salePrice);
    put('sellerProfileId', sellerProfileId);
    put('saleDate', saleDate);
    put('collectionDate', collectionDate);
    put('estimatedValue', estimatedValue);
    put('notes', notes);
    return m;
  }

  bool get isSold => status == stSold;
  bool get isStock => status == stStock;
  bool get isCollection => status == stCollection;

  /// Anno in cui il pezzo è entrato in collezione.
  int get collectionYear => yearOf(collectionDate ?? purchaseDate);

  /// Guadagno lordo sul singolo pezzo venduto.
  double get margin => (salePrice ?? 0) - purchasePrice;
}

class Expense {
  final String id;
  String desc;
  double amount;
  String? watchId;
  String? profileId;
  String date;

  Expense({
    required this.id,
    required this.desc,
    required this.amount,
    this.watchId,
    this.profileId,
    required this.date,
  });

  factory Expense.fromJson(Map<String, dynamic> j) => Expense(
        id: j['id'].toString(),
        desc: (j['desc'] ?? '').toString(),
        amount: _d(j['amount']),
        watchId: _sn(j['watchId']),
        profileId: _sn(j['profileId']),
        date: (j['date'] ?? '').toString(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'desc': desc,
        'amount': amount,
        'watchId': watchId,
        'profileId': profileId,
        'date': date,
      };
}

class Order {
  final String id;
  String desc;
  String tracking;
  String link;
  String status;
  String date;

  Order({
    required this.id,
    required this.desc,
    this.tracking = '',
    this.link = '',
    this.status = 'In transito',
    required this.date,
  });

  factory Order.fromJson(Map<String, dynamic> j) => Order(
        id: j['id'].toString(),
        desc: (j['desc'] ?? '').toString(),
        tracking: (j['tracking'] ?? '').toString(),
        link: (j['link'] ?? '').toString(),
        status: (j['status'] ?? 'In transito').toString(),
        date: (j['date'] ?? '').toString(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'desc': desc,
        'tracking': tracking,
        'link': link,
        'status': status,
        'date': date,
      };
}

class ImportResult {
  int watches = 0, expenses = 0, profiles = 0, orders = 0;
  int get total => watches + expenses + profiles + orders;
}

/// Tutti i dati dell'app. Il formato JSON è identico al backup della
/// versione web (watches, profiles, expenses, orders).
class Db {
  final List<Watch> watches;
  final List<Profile> profiles;
  final List<Expense> expenses;
  final List<Order> orders;

  Db({
    List<Watch>? watches,
    List<Profile>? profiles,
    List<Expense>? expenses,
    List<Order>? orders,
  })  : watches = watches ?? [],
        profiles = profiles ?? [],
        expenses = expenses ?? [],
        orders = orders ?? [];

  factory Db.fromJson(Map<String, dynamic> j) {
    List<T> list<T>(String k, T Function(Map<String, dynamic>) f) {
      final raw = j[k];
      if (raw is! List) return <T>[];
      return raw.whereType<Map>().map((e) => f(Map<String, dynamic>.from(e))).toList();
    }

    return Db(
      watches: list('watches', Watch.fromJson),
      profiles: list('profiles', Profile.fromJson),
      expenses: list('expenses', Expense.fromJson),
      orders: list('orders', Order.fromJson),
    );
  }

  Map<String, dynamic> toJson() => {
        'watches': watches.map((e) => e.toJson()).toList(),
        'profiles': profiles.map((e) => e.toJson()).toList(),
        'expenses': expenses.map((e) => e.toJson()).toList(),
        'orders': orders.map((e) => e.toJson()).toList(),
      };

  String profileName(String? id) {
    if (id == null || id.isEmpty) return 'Senza profilo';
    for (final p in profiles) {
      if (p.id == id) return p.name;
    }
    return 'Senza profilo';
  }

  /// Aggiunge gli elementi di [other] che non sono già presenti (stesso id).
  ImportResult merge(Db other) {
    final r = ImportResult();
    int add<T>(List<T> mine, List<T> inc, String Function(T) idOf) {
      final ids = mine.map(idOf).toSet();
      var n = 0;
      for (final x in inc) {
        if (ids.add(idOf(x))) {
          mine.add(x);
          n++;
        }
      }
      return n;
    }

    r.profiles = add<Profile>(profiles, other.profiles, (e) => e.id);
    r.watches = add<Watch>(watches, other.watches, (e) => e.id);
    r.expenses = add<Expense>(expenses, other.expenses, (e) => e.id);
    r.orders = add<Order>(orders, other.orders, (e) => e.id);
    return r;
  }
}
