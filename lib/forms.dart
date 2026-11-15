import 'package:flutter/material.dart';

import 'format.dart';
import 'models.dart';
import 'store.dart';
import 'widgets.dart';

/// Acquisto in giacenza oppure pezzo della collezione (nuovo o da modificare).
class WatchForm extends StatefulWidget {
  final Watch? edit;
  final bool collection;
  const WatchForm({super.key, this.edit, this.collection = false});

  @override
  State<WatchForm> createState() => _WatchFormState();
}

class _WatchFormState extends State<WatchForm> {
  late final TextEditingController _name;
  late final TextEditingController _price;
  late final TextEditingController _estimated;
  late final TextEditingController _notes;
  late String _date;
  late String _collDate;
  late String _platform;
  String? _buyer;

  @override
  void initState() {
    super.initState();
    final w = widget.edit;
    _name = TextEditingController(text: w?.name ?? '');
    _price = TextEditingController(text: w == null ? '' : '${w.purchasePrice}');
    _estimated = TextEditingController(text: w?.estimatedValue == null ? '' : '${w!.estimatedValue}');
    _notes = TextEditingController(text: w?.notes ?? '');
    _date = w?.purchaseDate ?? todayIso();
    _collDate = w?.collectionDate ?? _date;
    _platform = w?.purchasePlatform ?? 'Vinted';
    _buyer = w?.buyerProfileId ?? (app.db.profiles.isNotEmpty ? app.db.profiles.first.id : null);
  }

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _estimated.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    final price = parseNum(_price.text);
    if (name.isEmpty) {
      toast(context, 'Inserisci il nome.');
      return;
    }
    if (price == null || price < 0) {
      toast(context, 'Inserisci un prezzo valido (anche 0).');
      return;
    }
    final est = parseNum(_estimated.text);
    final notes = _notes.text.trim();
    app.mutate(() {
      final w = widget.edit;
      if (w != null) {
        w.name = name;
        w.purchasePrice = price;
        w.purchaseDate = _date;
        w.purchasePlatform = _platform;
        w.buyerProfileId = _buyer;
        if (widget.collection) {
          w.collectionDate = _collDate;
          w.estimatedValue = est;
          w.notes = notes.isEmpty ? null : notes;
        }
      } else {
        app.db.watches.add(Watch(
          id: newId(),
          name: name,
          purchasePlatform: _platform,
          purchasePrice: price,
          buyerProfileId: _buyer,
          purchaseDate: _date,
          status: widget.collection ? stCollection : stStock,
          collectionDate: widget.collection ? _collDate : null,
          estimatedValue: widget.collection ? est : null,
          notes: widget.collection && notes.isNotEmpty ? notes : null,
        ));
      }
    });
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.edit == null;
    final title = widget.collection
        ? (isNew ? 'Nuovo pezzo in collezione' : 'Modifica pezzo')
        : (isNew ? 'Nuovo acquisto' : 'Modifica acquisto');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SheetTitle(title),
        textInput(_name, 'Orologio / descrizione'),
        textInput(_price, 'Costo di acquisto (€)', number: true),
        PlatformDropdown(label: 'Acquistato su', value: _platform, onChanged: (v) => setState(() => _platform = v)),
        ProfileDropdown(label: 'Profilo che ha acquistato', value: _buyer, onChanged: (v) => setState(() => _buyer = v)),
        DateField(label: 'Data di acquisto', value: _date, onChanged: (v) => setState(() => _date = v)),
        if (widget.collection) ...[
          DateField(label: 'In collezione dal', value: _collDate, onChanged: (v) => setState(() => _collDate = v)),
          textInput(_estimated, 'Valore stimato (€)', number: true),
          textInput(_notes, 'Note', lines: 4),
        ],
        const SizedBox(height: 4),
        SaveRow(onSave: _save),
      ],
    );
  }
}

/// Segna come venduto un acquisto (oppure modifica una vendita già registrata).
class SellForm extends StatefulWidget {
  final Watch watch;
  const SellForm({super.key, required this.watch});

  @override
  State<SellForm> createState() => _SellFormState();
}

class _SellFormState extends State<SellForm> {
  late final TextEditingController _price;
  late String _date;
  late String _platform;
  String? _seller;

  @override
  void initState() {
    super.initState();
    final w = widget.watch;
    _price = TextEditingController(text: w.salePrice == null ? '' : '${w.salePrice}');
    _date = w.saleDate ?? todayIso();
    _platform = w.salePlatform ?? 'Vinted';
    _seller = w.sellerProfileId ?? w.buyerProfileId;
  }

  @override
  void dispose() {
    _price.dispose();
    super.dispose();
  }

  void _save() {
    final price = parseNum(_price.text);
    if (price == null || price < 0) {
      toast(context, 'Inserisci il prezzo di vendita.');
      return;
    }
    app.mutate(() {
      final w = widget.watch;
      w.status = stSold;
      w.salePrice = price;
      w.salePlatform = _platform;
      w.sellerProfileId = _seller;
      w.saleDate = _date;
    });
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.watch;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SheetTitle(w.isSold ? 'Modifica vendita' : 'Segna come venduto'),
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Text('${w.name}\nAcquistato a ${eur(w.purchasePrice)}'),
        ),
        textInput(_price, 'Prezzo di vendita (€)', number: true),
        PlatformDropdown(label: 'Venduto su', value: _platform, onChanged: (v) => setState(() => _platform = v)),
        ProfileDropdown(label: 'Venduto dal profilo', value: _seller, onChanged: (v) => setState(() => _seller = v)),
        DateField(label: 'Data di vendita', value: _date, onChanged: (v) => setState(() => _date = v)),
        const SizedBox(height: 4),
        SaveRow(onSave: _save, label: w.isSold ? 'Salva' : 'Venduto'),
      ],
    );
  }
}

/// Vendita veloce: pezzo comprato e venduto senza passare dagli acquisti.
class QuickSaleForm extends StatefulWidget {
  const QuickSaleForm({super.key});

  @override
  State<QuickSaleForm> createState() => _QuickSaleFormState();
}

class _QuickSaleFormState extends State<QuickSaleForm> {
  final _name = TextEditingController();
  final _price = TextEditingController();
  final _cost = TextEditingController(text: '0');
  String _date = todayIso();
  String _platform = 'Vinted';
  String? _seller = app.db.profiles.isNotEmpty ? app.db.profiles.first.id : null;

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _cost.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    final price = parseNum(_price.text);
    final cost = parseNum(_cost.text) ?? 0;
    if (name.isEmpty) {
      toast(context, 'Inserisci la descrizione.');
      return;
    }
    if (price == null || price < 0) {
      toast(context, 'Inserisci il prezzo di vendita.');
      return;
    }
    app.mutate(() {
      app.db.watches.add(Watch(
        id: newId(),
        name: name,
        purchasePlatform: 'Non specificato',
        purchasePrice: cost,
        buyerProfileId: _seller,
        purchaseDate: _date,
        status: stSold,
        salePlatform: _platform,
        salePrice: price,
        sellerProfileId: _seller,
        saleDate: _date,
      ));
    });
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SheetTitle('Vendita veloce'),
        textInput(_name, 'Descrizione'),
        textInput(_price, 'Prezzo di vendita (€)', number: true),
        textInput(_cost, 'Costo di acquisto (€, 0 se non lo ricordi)', number: true),
        PlatformDropdown(label: 'Venduto su', value: _platform, onChanged: (v) => setState(() => _platform = v)),
        ProfileDropdown(label: 'Profilo', value: _seller, onChanged: (v) => setState(() => _seller = v)),
        DateField(label: 'Data', value: _date, onChanged: (v) => setState(() => _date = v)),
        const SizedBox(height: 4),
        SaveRow(onSave: _save),
      ],
    );
  }
}

class ExpenseForm extends StatefulWidget {
  final Expense? edit;
  const ExpenseForm({super.key, this.edit});

  @override
  State<ExpenseForm> createState() => _ExpenseFormState();
}

class _ExpenseFormState extends State<ExpenseForm> {
  late final TextEditingController _desc;
  late final TextEditingController _amount;
  late String _date;
  String? _profile;

  @override
  void initState() {
    super.initState();
    final e = widget.edit;
    _desc = TextEditingController(text: e?.desc ?? '');
    _amount = TextEditingController(text: e == null ? '' : '${e.amount}');
    _date = e?.date ?? todayIso();
    _profile = e?.profileId ?? (app.db.profiles.isNotEmpty ? app.db.profiles.first.id : null);
  }

  @override
  void dispose() {
    _desc.dispose();
    _amount.dispose();
    super.dispose();
  }

  void _save() {
    final desc = _desc.text.trim();
    final amount = parseNum(_amount.text);
    if (desc.isEmpty) {
      toast(context, 'Inserisci la descrizione.');
      return;
    }
    if (amount == null || amount < 0) {
      toast(context, 'Inserisci un importo valido.');
      return;
    }
    app.mutate(() {
      final e = widget.edit;
      if (e != null) {
        e.desc = desc;
        e.amount = amount;
        e.date = _date;
        e.profileId = _profile;
      } else {
        app.db.expenses.add(Expense(id: newId(), desc: desc, amount: amount, profileId: _profile, date: _date));
      }
    });
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SheetTitle(widget.edit == null ? 'Nuova spesa' : 'Modifica spesa'),
        textInput(_desc, 'Descrizione (cinturini, buste, boost...)'),
        textInput(_amount, 'Importo (€)', number: true),
        ProfileDropdown(label: 'Profilo', value: _profile, onChanged: (v) => setState(() => _profile = v)),
        DateField(label: 'Data', value: _date, onChanged: (v) => setState(() => _date = v)),
        const SizedBox(height: 4),
        SaveRow(onSave: _save),
      ],
    );
  }
}

const List<String> kOrderStatuses = ['In transito', 'Consegnato', 'Problema'];

class OrderForm extends StatefulWidget {
  final Order? edit;
  const OrderForm({super.key, this.edit});

  @override
  State<OrderForm> createState() => _OrderFormState();
}

class _OrderFormState extends State<OrderForm> {
  late final TextEditingController _desc;
  late final TextEditingController _tracking;
  late final TextEditingController _link;
  late String _date;
  late String _status;

  @override
  void initState() {
    super.initState();
    final o = widget.edit;
    _desc = TextEditingController(text: o?.desc ?? '');
    _tracking = TextEditingController(text: o?.tracking ?? '');
    _link = TextEditingController(text: o?.link ?? '');
    _date = o?.date ?? todayIso();
    _status = o?.status ?? kOrderStatuses.first;
  }

  @override
  void dispose() {
    _desc.dispose();
    _tracking.dispose();
    _link.dispose();
    super.dispose();
  }

  void _save() {
    final desc = _desc.text.trim();
    if (desc.isEmpty) {
      toast(context, 'Inserisci la descrizione.');
      return;
    }
    app.mutate(() {
      final o = widget.edit;
      if (o != null) {
        o.desc = desc;
        o.tracking = _tracking.text.trim();
        o.link = _link.text.trim();
        o.status = _status;
        o.date = _date;
      } else {
        app.db.orders.add(Order(
          id: newId(),
          desc: desc,
          tracking: _tracking.text.trim(),
          link: _link.text.trim(),
          status: _status,
          date: _date,
        ));
      }
    });
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final statuses = [...kOrderStatuses];
    if (!statuses.contains(_status)) statuses.add(_status);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SheetTitle(widget.edit == null ? 'Nuovo ordine' : 'Modifica ordine'),
        textInput(_desc, 'Descrizione'),
        textInput(_tracking, 'Codice di tracking (facoltativo)'),
        textInput(_link, 'Link di tracciamento (facoltativo)', hint: 'https://...'),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: DropdownButtonFormField<String>(
            value: _status,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Stato', border: OutlineInputBorder()),
            items: statuses.map((s) => DropdownMenuItem<String>(value: s, child: Text(s))).toList(),
            onChanged: (v) {
              if (v != null) setState(() => _status = v);
            },
          ),
        ),
        DateField(label: 'Data ordine', value: _date, onChanged: (v) => setState(() => _date = v)),
        const SizedBox(height: 4),
        SaveRow(onSave: _save),
      ],
    );
  }
}
