import 'shopping_item.dart';

/// User-confirmed parser output. Prices intentionally remain unknown.
class ConfirmedGrocery {
  const ConfirmedGrocery({
    required this.name,
    required this.quantity,
    required this.unit,
    this.category = ItemCategory.essential,
  });
  final String name;
  final num quantity;
  final ItemUnit unit;
  final ItemCategory category;
}
