import '../models/shopping_item.dart';

class BudgetSummary {
  BudgetSummary(this.budget, List<ShoppingItem> items)
    : actualSpent = items
          .where((i) => i.purchased && i.total != null)
          .fold(0, (sum, i) => sum + i.total!),
      pendingPrices = items.where((i) => i.purchased && i.total == null).length,
      estimatedEssential = items
          .where((i) => !i.purchased && i.category == ItemCategory.essential)
          .fold(0, (sum, i) => sum + (i.projectedTotal ?? 0)),
      planned = items.fold(0, (sum, i) => sum + (i.projectedTotal ?? 0)),
      unknownProjections = items.where((i) => i.projectedTotal == null).length,
      hasEstimates = items.any(
        (i) => i.estimatedPrice != null || (!i.purchased && i.price != null),
      );
  final int budget,
      actualSpent,
      pendingPrices,
      estimatedEssential,
      planned,
      unknownProjections;
  final bool hasEstimates;
  int get remaining => budget - actualSpent;
  int get projectedBalance => budget - planned;
}
