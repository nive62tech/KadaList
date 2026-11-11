import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/shopping_item.dart';
import '../services/money.dart';
import '../services/shopping_store.dart';

Future<void> enterPurchasePrice(BuildContext context, ShoppingItem item) =>
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PurchasePriceDialog(item: item),
    );

class PurchasePriceDialog extends StatefulWidget {
  const PurchasePriceDialog({super.key, required this.item});
  final ShoppingItem item;

  @override
  State<PurchasePriceDialog> createState() => _PurchasePriceDialogState();
}

class _PurchasePriceDialogState extends State<PurchasePriceDialog> {
  final _form = GlobalKey<FormState>();
  late final _amount = TextEditingController(
    text: widget.item.total == null ? '' : moneyInput(widget.item.total!),
  );
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save({bool pending = false}) async {
    if (!pending && !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final store = context.read<ShoppingStore>();
    final ok = await store.run(
      () => store.repository.purchaseWithTotal(
        widget.item.id,
        pending ? null : parseMoney(_amount.text),
      ),
    );
    if (!mounted) return;
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
      title: Text('Actual price for ${widget.item.name}'),
      content: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _amount,
                autofocus: true,
                enabled: !_saving,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Actual total paid (₹)',
                ),
                validator: (value) => parseMoney(value ?? '') == null
                    ? 'Enter a non-negative amount, up to 2 decimals'
                    : null,
              ),
              if (_error != null) Text(_error!),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _saving ? null : () => _save(pending: true),
          child: const Text('Price pending'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: const Text('Save price'),
        ),
      ],
    ),
  );
}
