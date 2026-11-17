/// Importo in euro con formato italiano: 1.234,50 €
String eur(double v) {
  final neg = v < -0.004;
  final s = v.abs().toStringAsFixed(2);
  final parts = s.split('.');
  final ip = parts[0];
  final b = StringBuffer();
  for (var i = 0; i < ip.length; i++) {
    if (i > 0 && (ip.length - i) % 3 == 0) b.write('.');
    b.write(ip[i]);
  }
  return '${neg ? '-' : ''}$b,${parts[1]} €';
}

/// Da aaaa-mm-gg a gg/mm/aaaa.
String fmtDate(String? iso) {
  if (iso == null || iso.length < 10) return iso ?? '';
  return '${iso.substring(8, 10)}/${iso.substring(5, 7)}/${iso.substring(0, 4)}';
}

/// Legge un numero scritto con la virgola o con il punto. Null se non valido.
double? parseNum(String s) {
  final t = s.trim().replaceAll(',', '.');
  if (t.isEmpty) return null;
  return double.tryParse(t);
}

const List<String> monthNames = [
  'Gen', 'Feb', 'Mar', 'Apr', 'Mag', 'Giu', 'Lug', 'Ago', 'Set', 'Ott', 'Nov', 'Dic'
];

/// Data breve: "21 set" (anno corrente) oppure "21 set 2025".
String fmtDateShort(String? iso) {
  if (iso == null || iso.length < 10) return iso ?? '';
  final d = int.tryParse(iso.substring(8, 10)) ?? 0;
  final m = int.tryParse(iso.substring(5, 7)) ?? 1;
  final y = int.tryParse(iso.substring(0, 4)) ?? 0;
  final base = '$d ${monthNames[(m - 1).clamp(0, 11)].toLowerCase()}';
  return y == DateTime.now().year ? base : '$base $y';
}
