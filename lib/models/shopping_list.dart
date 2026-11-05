class ShoppingList {
  const ShoppingList({
    required this.id,
    required this.name,
    required this.budget,
    required this.createdAt,
  });
  final int id, budget;
  final String name;
  final DateTime createdAt;
  factory ShoppingList.fromMap(Map<String, Object?> r) => ShoppingList(
    id: r['id'] as int,
    name: r['name'] as String,
    budget: r['budget'] as int,
    createdAt: DateTime.fromMillisecondsSinceEpoch(r['created_at'] as int),
  );
}
