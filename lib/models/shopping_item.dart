import '../services/quantity.dart';

enum ItemCategory { essential, miscellaneous }

enum ItemUnit { kg, g, litre, ml, packet, piece }

class ShoppingItem {
  const ShoppingItem({
    required this.id,
    required this.listId,
    required this.name,
    required this.quantity,
    required this.price,
    required this.purchased,
    this.unit = ItemUnit.piece,
    this.category = ItemCategory.essential,
    this.estimatedPrice,
  });
  final int id, listId;
  final num quantity;
  final int? price, estimatedPrice;
  final ItemUnit unit;
  final ItemCategory category;
  final String name;
  final bool purchased;
  int? get total =>
      price == null ? null : extendedPrice(price!, quantityMillis(quantity));
  int? get estimatedTotal => estimatedPrice == null
      ? null
      : extendedPrice(estimatedPrice!, quantityMillis(quantity));
  int? get projectedTotal =>
      purchased ? (total ?? estimatedTotal) : (estimatedTotal ?? total);
  factory ShoppingItem.fromMap(Map<String, Object?> r) => ShoppingItem(
    id: r['id'] as int,
    listId: r['list_id'] as int,
    name: r['name'] as String,
    quantity: (r['quantity_millis'] as int) / 1000,
    price: r['price'] as int?,
    estimatedPrice: r['estimated_price'] as int?,
    unit: ItemUnit.values.byName(r['unit'] as String),
    category: ItemCategory.values.byName(r['category'] as String),
    purchased: r['purchased'] == 1,
  );
}
