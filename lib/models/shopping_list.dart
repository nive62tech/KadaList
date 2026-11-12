class ShoppingList {
  const ShoppingList({
    required this.id,
    required this.name,
    required this.budget,
    required this.createdAt,
    this.completed = false,
  });
  final bool completed;
  final int id, budget;
  final String name;
  final DateTime createdAt;
  factory ShoppingList.fromMap(Map<String, Object?> r) => ShoppingList(
    completed: r['completed'] == 1,
    id: r['id'] as int,
    name: r['name'] as String,
    budget: r['budget'] as int,
    createdAt: DateTime.fromMillisecondsSinceEpoch(r['created_at'] as int),
  );
}
