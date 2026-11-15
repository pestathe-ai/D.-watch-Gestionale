import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

/// Stato dell'app: dati + anno selezionato. Salva da solo a ogni modifica.
class AppState extends ChangeNotifier {
  static const _key = 'd_watch_db_v1';

  Db db = Db();

  /// Anno mostrato nelle schermate. Null = tutti gli anni.
  int? year = DateTime.now().year;

  SharedPreferences? _prefs;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final s = _prefs!.getString(_key);
    if (s != null && s.isNotEmpty) {
      try {
        db = Db.fromJson(jsonDecode(s) as Map<String, dynamic>);
      } catch (_) {
        db = Db();
      }
    }
    notifyListeners();
  }

  /// Applica una modifica ai dati, la salva e aggiorna le schermate.
  void mutate(void Function() change) {
    change();
    _prefs?.setString(_key, jsonEncode(db.toJson()));
    notifyListeners();
  }

  void setYear(int? y) {
    year = y;
    notifyListeners();
  }

  /// Unisce i dati di un backup JSON. Lancia FormatException se il file non è valido.
  ImportResult importJson(String text) {
    final data = jsonDecode(text);
    if (data is! Map<String, dynamic> ||
        !(data.containsKey('watches') ||
            data.containsKey('profiles') ||
            data.containsKey('expenses') ||
            data.containsKey('orders'))) {
      throw const FormatException('Il file non sembra un backup di Orologi Gestionale.');
    }
    final incoming = Db.fromJson(data);
    late ImportResult r;
    mutate(() => r = db.merge(incoming));
    return r;
  }

  String exportJson() => const JsonEncoder.withIndent('  ').convert(db.toJson());
}

final AppState app = AppState();
