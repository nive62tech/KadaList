import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/shopping_list.dart';
import '../models/shopping_item.dart';
import '../services/money.dart';
import '../services/shopping_store.dart';
import '../services/quantity.dart';

Future<void> editList(BuildContext context, {ShoppingList? list}) =>
    showDialog<void>(
      context: context,
      builder: (_) => EditDialog(list: list),
    );
Future<void> editItem(BuildContext context, int listId, {ShoppingItem? item}) =>
    showDialog<void>(
      context: context,
      builder: (_) => EditDialog(listId: listId, item: item),
    );

class EditDialog extends StatefulWidget {
  const EditDialog({super.key, this.list, this.listId, this.item});
  final ShoppingList? list;
  final int? listId;
  final ShoppingItem? item;
  @override
  State<EditDialog> createState() => _EditDialogState();
}

class _EditDialogState extends State<EditDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name, _amount, _quantity;
  late final TextEditingController _estimate;
  late ItemUnit _unit;
  late ItemCategory _category;
  bool _saving = false;
  String? _error;
  bool get isItem => widget.listId != null;
  @override
  void initState() {
    super.initState();
    _name = TextEditingController(
      text: widget.item?.name ?? widget.list?.name ?? '',
    );
    final amount = isItem
        ? (widget.item?.actualTotal ?? widget.item?.price)
        : widget.list?.budget ?? 0;
    _amount = TextEditingController(
      text: amount == null ? '' : moneyInput(amount),
    );
    _estimate = TextEditingController(
      text: widget.item?.estimatedPrice == null
          ? ''
          : moneyInput(widget.item!.estimatedPrice!),
    );
    _unit = widget.item?.unit ?? ItemUnit.piece;
    _category = widget.item?.category ?? ItemCategory.essential;
    _quantity = TextEditingController(text: '${widget.item?.quantity ?? 1}');
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _quantity.dispose();
    _estimate.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) {
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final store = context.read<ShoppingStore>();
    final ok = await store.run(
      () => isItem
          ? store.repository.saveItem(
              widget.listId!,
              _name.text,
              parseQuantity(_quantity.text)! / 1000,
              widget.item?.actualTotal != null
                  ? null
                  : parseMoney(_amount.text),
              actualTotal: widget.item?.actualTotal != null
                  ? parseMoney(_amount.text)
                  : null,
              id: widget.item?.id,
              estimatedPrice: parseMoney(_estimate.text),
              unit: _unit,
              category: _category,
            )
          : store.repository.saveList(
              _name.text,
              parseMoney(_amount.text)!,
              id: widget.list?.id,
            ),
    );
    if (!mounted) {
      return;
    }
    if (ok) {
      Navigator.pop(context);
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
    child: AlertDialog(
      title: Text(
        isItem
            ? (widget.item == null ? 'Add item' : 'Edit item')
            : (widget.list == null
                  ? 'Create Shopping List'
                  : 'Edit shopping list'),
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                autofocus: true,
                enabled: !_saving,
                maxLength: 100,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Enter a name' : null,
              ),
              if (isItem)
                TextFormField(
                  controller: _quantity,
                  enabled: !_saving,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Quantity'),
                  validator: (v) {
                    return parseQuantity(v ?? '') == null
                        ? 'Enter 0.001–9999, up to 3 decimals'
                        : null;
                  },
                ),
              TextFormField(
                controller: _amount,
                enabled: !_saving,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: isItem
                      ? (widget.item?.actualTotal != null
                            ? 'Actual total paid (₹, optional)'
                            : 'Actual unit price (₹, optional)')
                      : 'Budget (₹)',
                ),
                validator: (v) => isItem && (v ?? '').trim().isEmpty
                    ? null
                    : parseMoney(v ?? '') == null
                    ? 'Enter a non-negative amount, up to 2 decimals'
                    : null,
              ),
              if (isItem) ...[
                TextFormField(
                  controller: _estimate,
                  enabled: !_saving,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Estimated unit price (₹, optional)',
                  ),
                  validator: (v) =>
                      (v ?? '').trim().isEmpty || parseMoney(v!) != null
                      ? null
                      : 'Enter a non-negative amount, up to 2 decimals',
                ),
                DropdownButtonFormField<ItemUnit>(
                  initialValue: _unit,
                  decoration: const InputDecoration(labelText: 'Unit'),
                  items: ItemUnit.values
                      .map(
                        (u) => DropdownMenuItem(value: u, child: Text(u.name)),
                      )
                      .toList(),
                  onChanged: _saving ? null : (u) => setState(() => _unit = u!),
                ),
                DropdownButtonFormField<ItemCategory>(
                  initialValue: _category,
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
                  onChanged: _saving
                      ? null
                      : (c) => setState(() => _category = c!),
                ),
              ],
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving…' : 'Save'),
        ),
      ],
    ),
  );
}

Future<bool> confirmDelete(BuildContext context, String name) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete "$name"?'),
        content: const Text(
          'This permanently removes the data from this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    ) ??
    false;
