import 'package:flutter/material.dart';

import 'models.dart';
import 'store.dart';
import 'theme.dart';

const List<String> kPlatforms = [
  'Vinted',
  'eBay',
  'Subito',
  'A mano',
  'Mercatino',
  'Altro',
  'Non specificato',
];

// ------------------------------------------------------------ dialoghi e fogli

Future<bool> confirmDialog(BuildContext context, String message, {String ok = 'Elimina'}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annulla')),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(96, 44)),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(ok),
        ),
      ],
    ),
  );
  return r == true;
}

void toast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

Future<T?> openSheet<T>(BuildContext context, Widget child) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(child: child),
    ),
  );
}

Future<String?> promptText(BuildContext context, String title, {String initial = ''}) async {
  final c = TextEditingController(text: initial);
  final r = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: c,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annulla')),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(96, 44)),
          onPressed: () => Navigator.pop(ctx, c.text.trim()),
          child: const Text('Salva'),
        ),
      ],
    ),
  );
  c.dispose();
  return r;
}

// ------------------------------------------------------------ campi dei form

Widget textInput(
  TextEditingController c,
  String label, {
  bool number = false,
  int lines = 1,
  String? hint,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: c,
      keyboardType: number ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      textCapitalization: number ? TextCapitalization.none : TextCapitalization.sentences,
      minLines: 1,
      maxLines: lines,
      decoration: InputDecoration(labelText: label, hintText: hint),
    ),
  );
}

class DateField extends StatelessWidget {
  final String label;
  final String value;
  final ValueChanged<String> onChanged;

  const DateField({super.key, required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () async {
          final initial = DateTime.tryParse(value) ?? DateTime.now();
          final d = await showDatePicker(
            context: context,
            initialDate: initial,
            firstDate: DateTime(2000),
            lastDate: DateTime(2100),
          );
          if (d != null) {
            onChanged(
              '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}',
            );
          }
        },
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            suffixIcon: Icon(Icons.calendar_today_rounded, size: 18, color: context.tk.muted),
          ),
          child: Text(
            value.length >= 10 ? '${value.substring(8, 10)}/${value.substring(5, 7)}/${value.substring(0, 4)}' : value,
          ),
        ),
      ),
    );
  }
}

class ProfileDropdown extends StatelessWidget {
  final String label;
  final String? value;
  final ValueChanged<String?> onChanged;

  const ProfileDropdown({super.key, required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final Db db = app.db;
    final ids = db.profiles.map((p) => p.id).toSet();
    final String? current = (value != null && ids.contains(value)) ? value : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String?>(
        value: current,
        isExpanded: true,
        borderRadius: BorderRadius.circular(16),
        decoration: InputDecoration(labelText: label),
        items: [
          const DropdownMenuItem<String?>(value: null, child: Text('Senza profilo')),
          ...db.profiles.map((p) => DropdownMenuItem<String?>(value: p.id, child: Text(p.name))),
        ],
        onChanged: onChanged,
      ),
    );
  }
}

class PlatformDropdown extends StatelessWidget {
  final String label;
  final String value;
  final ValueChanged<String> onChanged;

  const PlatformDropdown({super.key, required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final items = [...kPlatforms];
    if (!items.contains(value)) items.insert(0, value);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        value: value,
        isExpanded: true,
        borderRadius: BorderRadius.circular(16),
        decoration: InputDecoration(labelText: label),
        items: items.map((p) => DropdownMenuItem<String>(value: p, child: Text(p))).toList(),
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }
}

class SheetTitle extends StatelessWidget {
  final String text;
  const SheetTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Text(
          text,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.3),
        ),
      );
}

class SaveRow extends StatelessWidget {
  final VoidCallback onSave;
  final String label;
  const SaveRow({super.key, required this.onSave, this.label = 'Salva'});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Annulla')),
          ),
          const SizedBox(width: 12),
          Expanded(flex: 2, child: FilledButton(onPressed: onSave, child: Text(label))),
        ],
      );
}

// ------------------------------------------------------------ componenti grafici

/// Riquadro rosso in evidenza in cima a ogni schermata.
class HeroCard extends StatelessWidget {
  final String label;
  final String value;
  final List<(String, String)> stats;

  const HeroCard({super.key, required this.label, required this.value, this.stats = const []});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [kRed, kRedDeep],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 11, letterSpacing: 1.3, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.w800,
                letterSpacing: -1,
                fontFeatures: kTabular,
              ),
            ),
          ),
          if (stats.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Divider(height: 1, color: Color(0x33FFFFFF)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 24,
              runSpacing: 10,
              children: [
                for (final s in stats)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.$1, style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 12)),
                      const SizedBox(height: 2),
                      Text(
                        s.$2,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          fontFeatures: kTabular,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class SectionLabel extends StatelessWidget {
  final String text;
  const SectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        child: Text(
          text.toUpperCase(),
          style: TextStyle(color: context.tk.muted, fontSize: 11, letterSpacing: 1.4, fontWeight: FontWeight.w700),
        ),
      );
}

/// Pastiglia colorata (guadagno positivo / negativo).
class Pill extends StatelessWidget {
  final String text;
  final bool positive;
  const Pill(this.text, {super.key, this.positive = true});

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: positive ? t.greenSoft : t.redSoft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: positive ? t.green : t.red,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          fontFeatures: kTabular,
        ),
      ),
    );
  }
}

/// Cerchio con l'iniziale del profilo (ogni profilo ha il suo colore).
class Avatar extends StatelessWidget {
  final String? profileId;
  final double size;
  const Avatar(this.profileId, {super.key, this.size = 40});

  static const List<Color> _colors = [
    Color(0xFFE5484D),
    Color(0xFF3E7BFA),
    Color(0xFF2FA05A),
    Color(0xFFD08700),
    Color(0xFF9B5DE5),
  ];

  @override
  Widget build(BuildContext context) {
    final profiles = app.db.profiles;
    final i = profiles.indexWhere((p) => p.id == profileId);
    final Color c = i < 0 ? context.tk.muted : _colors[i % _colors.length];
    final String letter = i < 0 || profiles[i].name.isEmpty ? '–' : profiles[i].name.characters.first.toUpperCase();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: c.withValues(alpha: 0.15), shape: BoxShape.circle),
      child: Text(
        letter,
        style: TextStyle(color: c, fontWeight: FontWeight.w800, fontSize: size * 0.4),
      ),
    );
  }
}

class IconBadge extends StatelessWidget {
  final IconData icon;
  final double size;
  const IconBadge(this.icon, {super.key, this.size = 40});

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: t.redSoft, shape: BoxShape.circle),
      child: Icon(icon, color: t.red, size: size * 0.5),
    );
  }
}

/// Voce di elenco: cerchio a sinistra, titolo e dettaglio, importo a destra.
class ItemCard extends StatelessWidget {
  final Widget leading;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final Widget? menu;
  final VoidCallback? onTap;

  const ItemCard({
    super.key,
    required this.leading,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.menu,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Material(
        color: t.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: t.border),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.fromLTRB(14, 10, menu == null ? 14 : 2, 10),
            child: Row(
              children: [
                leading,
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, height: 1.25),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12.5, color: t.muted, height: 1.3),
                      ),
                    ],
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: 8), trailing!],
                if (menu != null) menu!,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Importo in grassetto, con eventuale riga sotto.
class PriceColumn extends StatelessWidget {
  final String price;
  final Widget? below;
  const PriceColumn(this.price, {super.key, this.below});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(price, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, fontFeatures: kTabular)),
        if (below != null) ...[const SizedBox(height: 4), below!],
      ],
    );
  }
}

PopupMenuButton<String> moreMenu(
  BuildContext context, {
  required List<(String, String)> items,
  required ValueChanged<String> onSelected,
}) {
  return PopupMenuButton<String>(
    tooltip: 'Azioni',
    icon: Icon(Icons.more_vert_rounded, color: context.tk.muted, size: 20),
    onSelected: onSelected,
    itemBuilder: (_) => [for (final i in items) PopupMenuItem<String>(value: i.$1, child: Text(i.$2))],
  );
}

class KpiTile extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const KpiTile({super.key, required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: t.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(color: t.muted, fontSize: 10.5, letterSpacing: 1.2, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                color: color ?? t.ink,
                fontSize: 21,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
                fontFeatures: kTabular,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Contenitore bianco con bordo sottile.
class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const Panel({super.key, required this.child, this.padding = const EdgeInsets.all(16)});

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: padding,
      width: double.infinity,
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: t.border),
      ),
      child: child,
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String text;
  const EmptyState(this.icon, this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 40, 32, 24),
      child: Column(
        children: [
          IconBadge(icon, size: 64),
          const SizedBox(height: 16),
          Text(text, textAlign: TextAlign.center, style: TextStyle(color: t.muted, height: 1.4)),
        ],
      ),
    );
  }
}

class DomSignature extends StatelessWidget {
  const DomSignature({super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 24, 0, 96),
        child: Center(
          child: Text(
            "un'app Dom Studio",
            style: TextStyle(fontSize: 11, letterSpacing: 0.8, color: context.tk.muted),
          ),
        ),
      );
}
