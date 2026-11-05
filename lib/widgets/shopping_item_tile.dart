import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/shopping_item.dart';
import '../services/shopping_store.dart';
import '../services/money.dart';
import '../services/quantity.dart';
import 'edit_dialog.dart';

class ShoppingItemTile extends StatelessWidget {
  const ShoppingItemTile({super.key, required this.item});
  final ShoppingItem item;
  @override
  Widget build(BuildContext context) {
    final store = context.watch<ShoppingStore>();
    final details = <String>[
      '${quantityLabel(quantityMillis(item.quantity))} ${item.unit.name}',
    ];
    if (item.price != null) {
      details.add(
        'Actual ${money(item.total!)} (${money(item.price!)}/${item.unit.name})',
      );
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
        onChanged: store.busy
            ? null
            : (value) => store.run(
                () => store.repository.setPurchased(item.id, value!),
              ),
      ),
      title: Text(
        item.name,
        style: TextStyle(
          decoration: item.purchased ? TextDecoration.lineThrough : null,
        ),
      ),
      subtitle: Text(details.join('\n')),
      onTap: store.busy
          ? null
          : () => editItem(context, item.listId, item: item),
      trailing: IconButton(
        tooltip: 'Delete ${item.name}',
        icon: const Icon(Icons.delete_outline),
        onPressed: store.busy
            ? null
            : () async {
                if (await confirmDelete(context, item.name)) {
                  await store.run(() => store.repository.deleteItem(item.id));
                }
              },
      ),
    );
  }
}
