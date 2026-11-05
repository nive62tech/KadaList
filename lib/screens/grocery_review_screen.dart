import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/grocery_candidate.dart';
import '../models/confirmed_grocery.dart';
import '../models/shopping_item.dart';
import '../services/quantity.dart';
import '../services/shopping_store.dart';

class GroceryReviewScreen extends StatefulWidget {
  const GroceryReviewScreen({
    super.key,
    required this.listId,
    required this.candidates,
  });
  final int listId;
  final List<GroceryCandidate> candidates;
  @override
  State<GroceryReviewScreen> createState() => _GroceryReviewScreenState();
}

class _GroceryReviewScreenState extends State<GroceryReviewScreen> {
  final _form = GlobalKey<FormState>();
  late final List<_Draft> _drafts;
  bool _saving = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _drafts = widget.candidates.map(_Draft.new).toList();
  }

  @override
  void dispose() {
    for (final draft in _drafts) {
      draft.name.dispose();
      draft.quantity.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final chosen = _drafts.where((d) => d.selected).toList();
    if (chosen.isEmpty) {
      setState(() => _error = 'Select at least one item to save.');
      return;
    }
    // Fields outside the viewport may not be mounted: validate all drafts.
    final invalid = _drafts.indexWhere(
      (d) =>
          d.selected &&
          (d.name.text.trim().isEmpty ||
              d.name.text.trim().length > 100 ||
              parseQuantity(d.quantity.text) == null ||
              d.unit == null),
    );
    if (invalid >= 0) {
      setState(
        () => _error =
            'Item ${invalid + 1}: confirm a name, quantity and unit before saving.',
      );
      _form.currentState!.validate();
      return;
    }
    final store = context.read<ShoppingStore>();
    setState(() {
      _saving = true;
      _error = null;
    });
    var committed = false;
    final saved = await store.run(() async {
      await store.repository.addConfirmedItems(
        widget.listId,
        chosen
            .map(
              (d) => ConfirmedGrocery(
                name: d.name.text,
                quantity: parseQuantity(d.quantity.text)! / 1000,
                unit: d.unit!,
                category: d.category,
              ),
            )
            .toList(),
      );
      committed = true;
    });
    if (!mounted) return;
    if (saved || committed) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _saving = false;
        _error = store.error ?? 'Please wait and try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Scaffold(
      appBar: AppBar(title: const Text('Review grocery items')),
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Confirm names, quantities and units. Uncheck unwanted items. Prices stay blank and items are added as not purchased.',
              ),
            ),
            Expanded(
              child: Form(
                key: _form,
                child: ListView(
                  children: [
                    for (var i = 0; i < _drafts.length; i++)
                      _card(_drafts[i], i),
                  ],
                ),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Saving…' : 'Confirm and save'),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _card(_Draft d, int index) => Card(
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: d.selected,
            onChanged: _saving ? null : (v) => setState(() => d.selected = v!),
            title: Text('Item ${index + 1}'),
            subtitle: Text(
              d.candidate.ambiguous
                  ? 'Needs review'
                  : 'Recognized — confirm before saving',
            ),
          ),
          Text('Original: ${d.candidate.originalText}'),
          if (d.candidate.issues.isNotEmpty)
            Text('Parser notes: ${d.candidate.issues.join('; ')}'),
          TextFormField(
            controller: d.name,
            enabled: !_saving && d.selected,
            maxLength: 100,
            decoration: const InputDecoration(labelText: 'Name'),
            validator: (v) => !d.selected || (v ?? '').trim().isNotEmpty
                ? null
                : 'Enter a grocery name',
          ),
          TextFormField(
            controller: d.quantity,
            enabled: !_saving && d.selected,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Quantity'),
            validator: (v) => !d.selected || parseQuantity(v ?? '') != null
                ? null
                : 'Confirm quantity (0.001–9999, up to 3 decimals)',
          ),
          DropdownButtonFormField<ItemUnit>(
            initialValue: d.unit,
            decoration: const InputDecoration(labelText: 'Unit'),
            items: ItemUnit.values
                .map(
                  (unit) =>
                      DropdownMenuItem(value: unit, child: Text(unit.name)),
                )
                .toList(),
            onChanged: _saving || !d.selected
                ? null
                : (v) => setState(() => d.unit = v),
            validator: (v) => !d.selected || v != null ? null : 'Select a unit',
          ),
          DropdownButtonFormField<ItemCategory>(
            initialValue: d.category,
            decoration: const InputDecoration(labelText: 'Category'),
            items: const [
              DropdownMenuItem(
                value: ItemCategory.essential,
                child: Text('Essential'),
              ),
              DropdownMenuItem(
                value: ItemCategory.miscellaneous,
                child: Text('Miscellaneous'),
              ),
            ],
            onChanged: _saving || !d.selected
                ? null
                : (v) => setState(() => d.category = v!),
          ),
        ],
      ),
    ),
  );
}

class _Draft {
  _Draft(this.candidate)
    : name = TextEditingController(text: candidate.name),
      quantity = TextEditingController(
        text: candidate.quantity == null
            ? ''
            : quantityLabel(quantityMillis(candidate.quantity!)),
      ),
      unit = candidate.unit;
  final GroceryCandidate candidate;
  final TextEditingController name, quantity;
  ItemUnit? unit;
  ItemCategory category = ItemCategory.essential;
  bool selected = true;
}
