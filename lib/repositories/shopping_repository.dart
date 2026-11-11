import '../database/app_database.dart';
import '../models/shopping_list.dart';
import '../models/shopping_item.dart';
import '../services/quantity.dart';
import '../models/confirmed_grocery.dart';

class ShoppingRepository {
  ShoppingRepository(this.database);
  final AppDatabase database;
  Future<List<ShoppingList>> lists() async =>
      (await (await database.database).query(
        'shopping_lists',
        orderBy: 'created_at DESC, id DESC',
      )).map(ShoppingList.fromMap).toList();
  Future<List<ShoppingItem>> items() async =>
      (await (await database.database).query(
        'shopping_items',
        orderBy: 'id ASC',
      )).map(ShoppingItem.fromMap).toList();
  String _name(String value) {
    if (value.trim().isEmpty || value.trim().length > 100) {
      throw ArgumentError('Name must contain 1–100 characters');
    }
    return value.trim();
  }

  Future<void> saveList(String name, int budget, {int? id}) async {
    if (budget < 0 || budget > 99999999999) {
      throw ArgumentError('Invalid budget');
    }
    final values = <String, Object?>{'name': _name(name), 'budget': budget};
    final db = await database.database;
    if (id == null) {
      values['created_at'] = DateTime.now().millisecondsSinceEpoch;
      await db.insert('shopping_lists', values);
    } else {
      await db.update(
        'shopping_lists',
        values,
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

  Future<void> deleteList(int id) async {
    await (await database.database).delete(
      'shopping_lists',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> saveItem(
    int listId,
    String name,
    num quantity,
    int? price, {
    int? id,
    int? estimatedPrice,
    int? actualTotal,
    ItemUnit unit = ItemUnit.piece,
    ItemCategory category = ItemCategory.essential,
  }) async {
    final millis = quantityMillis(quantity);
    if ((actualTotal != null &&
            (actualTotal < 0 || actualTotal > 99999999999)) ||
        (price != null && (price < 0 || price > 99999999999)) ||
        (estimatedPrice != null &&
            (estimatedPrice < 0 || estimatedPrice > 99999999999))) {
      throw ArgumentError('Invalid quantity or price');
    }
    final values = <String, Object?>{
      'list_id': listId,
      'name': _name(name),
      'quantity_millis': millis,
      'price': price,
      'actual_total': actualTotal,
      'estimated_price': estimatedPrice,
      'unit': unit.name,
      'category': category.name,
    };
    final db = await database.database;
    if (id == null) {
      await db.insert('shopping_items', values);
    } else {
      await db.update(
        'shopping_items',
        values,
        where: 'id = ? AND list_id = ?',
        whereArgs: [id, listId],
      );
    }
  }

  Future<void> setPurchased(int id, bool value) async {
    await (await database.database).update(
      'shopping_items',
      {'purchased': value ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Store the exact total paid, independently of quantity and unit price.
  Future<void> purchaseWithTotal(int id, int? total) async {
    if (total != null && (total < 0 || total > 99999999999)) {
      throw ArgumentError('Invalid actual total');
    }
    await (await database.database).update(
      'shopping_items',
      {'purchased': 1, 'actual_total': total, 'price': null},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Validate before writing, then commit the complete review atomically.
  Future<void> addConfirmedItems(
    int listId,
    List<ConfirmedGrocery> items,
  ) async {
    if (items.isEmpty) throw ArgumentError('Select at least one item');
    final values = items
        .map(
          (item) => <String, Object?>{
            'list_id': listId,
            'name': _name(item.name),
            'quantity_millis': quantityMillis(item.quantity),
            'unit': item.unit.name,
            'category': item.category.name,
            'price': null,
            'estimated_price': null,
          },
        )
        .toList();
    final db = await database.database;
    await db.transaction((txn) async {
      for (final row in values) {
        await txn.insert('shopping_items', row);
      }
    });
  }

  Future<void> deleteItem(int id) async {
    await (await database.database).delete(
      'shopping_items',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
