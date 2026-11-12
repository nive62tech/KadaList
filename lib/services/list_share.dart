import 'package:flutter/services.dart';
import '../models/shopping_item.dart';
import '../models/shopping_list.dart';
import 'money.dart';
import 'quantity.dart';

/// Sends text to the local OS chooser. KadaList does not upload list data.
class ListShare {
  static const channel = MethodChannel('kadalist/share');

  static Future<void> share(
    ShoppingList list,
    List<ShoppingItem> items,
  ) => channel.invokeMethod<void>('shareText', {
    'text': [
      list.name,
      'Budget ${money(list.budget)}',
      for (final category in ItemCategory.values) ...[
        category == ItemCategory.essential ? 'Essentials' : 'Miscellaneous',
        for (final item in items.where((i) => i.category == category))
          '${item.purchased ? "[x]" : "[ ]"} ${item.name} - ${quantityLabel(quantityMillis(item.quantity))} ${item.unit.name}${item.total == null ? "" : " - ${money(item.total!)}"}',
      ],
    ].join('\n'),
  });
}
