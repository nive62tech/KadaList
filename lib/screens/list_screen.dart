import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/shopping_item.dart';
import '../services/shopping_store.dart';
import '../services/money.dart';
import '../services/budget_summary.dart';
import '../widgets/edit_dialog.dart';
import '../widgets/data_status.dart';
import '../widgets/shopping_item_tile.dart';
import 'grocery_text_screen.dart';

class ListScreen extends StatelessWidget {
  const ListScreen({super.key, required this.listId});
  final int listId;
  @override
  Widget build(BuildContext context) {
    final store = context.watch<ShoppingStore>();
    final matches = store.lists.where((list) => list.id == listId);
    if (matches.isEmpty) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('This list no longer exists.')),
      );
    }
    final list = matches.first;
    final items = store.itemsFor(listId);
    final summary = BudgetSummary(list.budget, items);
    final error = TextStyle(color: Theme.of(context).colorScheme.error);
    return Scaffold(
      appBar: AppBar(
        title: Text(list.name),
        actions: [
          IconButton(
            tooltip: 'Add groceries by voice',
            onPressed: store.busy
                ? null
                : () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          GroceryTextScreen(listId: listId, voiceFirst: true),
                    ),
                  ),
            icon: const Icon(Icons.mic),
          ),
          IconButton(
            tooltip: 'Paste or type grocery list',
            onPressed: store.busy
                ? null
                : () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => GroceryTextScreen(listId: listId),
                    ),
                  ),
            icon: const Icon(Icons.playlist_add),
          ),
          IconButton(
            tooltip: 'Edit list and budget',
            onPressed: store.busy ? null : () => editList(context, list: list),
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          const DataStatus(),
          Expanded(
            child: ListView(
              children: [
                Card(
                  margin: const EdgeInsets.all(16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Budget ${money(list.budget)}',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const Text(
                          'One shared budget for Essential and Miscellaneous',
                        ),
                        Text('Actual spent ${money(summary.actualSpent)}'),
                        Text('Remaining ${money(summary.remaining)}'),
                        if (summary.pendingPrices > 0)
                          Text(
                            '${summary.pendingPrices} purchased item(s): Price pending. Actual spent and remaining are incomplete.',
                          ),
                        if (summary.hasEstimates) ...[
                          Text(
                            'Estimated essential costs (still to buy) ${money(summary.estimatedEssential)}',
                          ),
                          Text(
                            'Projected balance ${money(summary.projectedBalance)}',
                          ),
                          const Text(
                            'Projection uses actual purchased costs and estimates for remaining or unpriced items.',
                          ),
                        ],
                        if (summary.unknownProjections > 0)
                          Text(
                            '${summary.unknownProjections} item(s) have no price or estimate; projection is incomplete.',
                          ),
                        if (summary.remaining < 0)
                          Text(
                            'Over budget by ${money(-summary.remaining)}',
                            style: error,
                          ),
                        if (summary.planned > list.budget)
                          Text(
                            'Planned items exceed budget by ${money(summary.planned - list.budget)}',
                            style: error,
                          ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: list.budget == 0
                              ? (summary.actualSpent > 0 ? 1 : 0)
                              : (summary.actualSpent / list.budget).clamp(
                                  0.0,
                                  1.0,
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Add items to start planning your shopping.'),
                  ),
                for (final category in ItemCategory.values) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      category == ItemCategory.essential
                          ? 'Essential'
                          : 'Miscellaneous',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  if (!items.any((i) => i.category == category))
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text('No items in this section.'),
                    ),
                  ...items
                      .where((i) => i.category == category)
                      .map((item) => ShoppingItemTile(item: item)),
                ],
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton.icon(
                onPressed: store.busy ? null : () => editItem(context, listId),
                icon: const Icon(Icons.add),
                label: const Text('Add item'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
