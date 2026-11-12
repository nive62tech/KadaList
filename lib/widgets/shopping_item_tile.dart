import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/shopping_item.dart';
import '../services/shopping_store.dart';
import '../services/money.dart';
import '../services/quantity.dart';
import 'edit_dialog.dart';
import 'purchase_price_dialog.dart';

class ShoppingItemTile extends StatelessWidget {
  const ShoppingItemTile({
    super.key,
    required this.item,
    this.readOnly = false,
  });
  final ShoppingItem item;
  final bool readOnly;
  @override
  Widget build(BuildContext context) {
    final store = context.watch<ShoppingStore>();
    final details = <String>[
      '${quantityLabel(quantityMillis(item.quantity))} ${item.unit.name}',
    ];
    if (item.total != null) {
      details.add('Actual ${money(item.total!)}');
    } else if (item.purchased) {
      details.add('Price pending');
    } else {
      details.add('Actual price not entered');
    }
    if (item.estimatedTotal != null) {
      details.add('Estimate ${money(item.estimatedTotal!)}');
    }
    return ListTile(
      leading: Checkbox(
        value: item.purchased,
        onChanged: (store.busy || readOnly)
            ? null
            : (value) => value == true
                  ? enterPurchasePrice(context, item)
                  : store.run(
                      () => store.repository.setPurchased(item.id, false),
                    ),
      ),
      title: Text(
        item.name,
        style: TextStyle(
          decoration: item.purchased ? TextDecoration.lineThrough : null,
        ),
      ),
      subtitle: Text(details.join(' | ')),
      onTap: (store.busy || readOnly)
          ? null
          : () => editItem(context, item.listId, item: item),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (item.purchased)
            IconButton(
              tooltip: 'Edit actual price for ${item.name}',
              icon: const Icon(Icons.price_change_outlined),
              onPressed: (store.busy || readOnly)
                  ? null
                  : () => enterPurchasePrice(context, item),
            ),
          IconButton(
            tooltip: 'Delete ${item.name}',
            icon: const Icon(Icons.delete_outline),
            onPressed: (store.busy || readOnly)
                ? null
                : () async {
                    if (await confirmDelete(context, item.name)) {
                      await store.run(
                        () => store.repository.deleteItem(item.id),
                      );
                    }
                  },
          ),
        ],
      ),
    );
  }
}
