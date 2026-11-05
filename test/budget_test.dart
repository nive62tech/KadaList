import 'package:flutter_test/flutter_test.dart';
import 'package:kadalist/models/shopping_item.dart';
import 'package:kadalist/services/budget_summary.dart';
import 'package:kadalist/services/money.dart';
import 'package:kadalist/services/quantity.dart';

ShoppingItem item({
  num quantity = 1,
  int? price,
  int? estimate,
  bool purchased = false,
  ItemCategory category = ItemCategory.essential,
}) => ShoppingItem(
  id: 1,
  listId: 1,
  name: 'Item',
  quantity: quantity,
  price: price,
  estimatedPrice: estimate,
  purchased: purchased,
  category: category,
);

void main() {
  test('fractional costs round half up once per item using integer paise', () {
    expect(item(quantity: 0.5, price: 12345).total, 6173);
    expect(item(quantity: 0.25, price: 10001).total, 2500);
    expect(item(quantity: 0.001, price: 500).total, 1);
    expect(parseQuantity('0.25'), 250);
    expect(quantityLabel(10000), '10');
    expect(quantityLabel(250), '0.25');
    for (final invalid in ['0', '-1', 'NaN', 'Infinity', '0.0001', '10000']) {
      expect(parseQuantity(invalid), isNull);
    }
    expect(money(999999999999999), '₹9999999999999.99');
    expect(money(-1), '-₹0.01');
  });
  test('missing actual prices remain null; zero is a known free price', () {
    final pending = item(quantity: 0.5, estimate: 10000, purchased: true);
    expect(pending.total, isNull);
    final summary = BudgetSummary(10000, [
      pending,
      item(price: 0, purchased: true),
    ]);
    expect(summary.actualSpent, 0);
    expect(summary.pendingPrices, 1);
    expect(summary.remaining, 10000);
    expect(summary.projectedBalance, 5000);
  });
  test('miscellaneous purchases and essential estimates share one budget', () {
    final summary = BudgetSummary(10000, [
      item(quantity: 0.5, price: 8000, purchased: true),
      item(price: 3000, purchased: true, category: ItemCategory.miscellaneous),
      item(quantity: 0.25, estimate: 8000),
      item(estimate: 1500, category: ItemCategory.miscellaneous),
    ]);
    expect(summary.actualSpent, 7000);
    expect(summary.remaining, 3000);
    expect(summary.estimatedEssential, 2000);
    expect(summary.planned, 10500);
    expect(summary.projectedBalance, -500);
    expect(summary.unknownProjections, 0);
  });
  test(
    'actual replaces estimate on purchase, unknown costs stay incomplete',
    () {
      final summary = BudgetSummary(0, [
        item(price: 100, estimate: 900, purchased: true),
        item(purchased: true),
        item(),
      ]);
      expect(summary.actualSpent, 100);
      expect(summary.remaining, -100);
      expect(summary.planned, 100);
      expect(summary.pendingPrices, 1);
      expect(summary.unknownProjections, 2);
      expect(summary.projectedBalance, -100);
      expect(BudgetSummary(0, []).hasEstimates, isFalse);
    },
  );
}
