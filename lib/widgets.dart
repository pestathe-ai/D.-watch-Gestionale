import 'package:flutter/material.dart';

import 'models.dart';
import 'store.dart';

const Color kRed = Color(0xFFD62828);
const Color kInk = Color(0xFF2B1B1B);

const List<String> kPlatforms = [
  'Vinted',
  'eBay',
  'Subito',
  'A mano',
  'Mercatino',
  'Altro',
  'Non specificato',
];

Future<bool> confirmDialog(BuildContext context, String message, {String ok = 'Elimina'}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annulla')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(ok)),
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
        left: 16,
        right: 16,
        bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
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
        decoration: const InputDecoration(border: OutlineInputBorder()),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annulla')),
        FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Salva')),
      ],
    ),
  );
  c.dispose();
  return r;
}

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
      decoration: InputDecoration(labelText: label, hintText: hint, border: const OutlineInputBorder()),
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
            border: const OutlineInputBorder(),
            suffixIcon: const Icon(Icons.calendar_today, size: 18),
          ),
          child: Text(value.length >= 10 ? '${value.substring(8, 10)}/${value.substring(5, 7)}/${value.substring(0, 4)}' : value),
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
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
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
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
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
        padding: const EdgeInsets.only(bottom: 14),
        child: Text(text, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
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
          Expanded(child: FilledButton(onPressed: onSave, child: Text(label))),
        ],
      );
}

class EmptyNote extends StatelessWidget {
  final String text;
  const EmptyNote(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Text(text, textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).hintColor)),
        ),
      );
}

class SummaryCard extends StatelessWidget {
  final String title;
  final List<(String, String)> rows;
  const SummaryCard({super.key, required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            for (final r in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Expanded(child: Text(r.$1)),
                    Text(r.$2, style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
          ],
        ),
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
            style: TextStyle(fontSize: 11, letterSpacing: 0.6, color: Theme.of(context).hintColor),
          ),
        ),
      );
}
