import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/shopping_item.dart';
import '../services/list_share.dart';
import '../services/shopping_store.dart';
import '../services/money.dart';
import '../services/budget_summary.dart';
import '../widgets/edit_dialog.dart';
import '../widgets/data_status.dart';
import '../widgets/shopping_item_tile.dart';
import 'home_screen.dart';
import 'grocery_text_screen.dart';
import '../widgets/offline_speech_input.dart';
import '../services/grocery_parser.dart';
import 'grocery_review_screen.dart';

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
      bottomNavigationBar: const KadaNavigation(),
      appBar: AppBar(
        title: Text(list.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Import from image (coming soon)',
            icon: const Icon(Icons.camera_alt_outlined),
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Photo import varunnu! Coming soon.'),
              ),
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'List actions',
            enabled: !store.busy,
            onSelected: (action) async {
              if (action == 'rename') {
                await editList(context, list: list);
              } else if (action == 'share') {
                try {
                  await ListShare.share(list, items);
                } on PlatformException {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Unable to open the share sheet. Try again.',
                        ),
                      ),
                    );
                  }
                } on MissingPluginException {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Text sharing is available in the Android app.',
                        ),
                      ),
                    );
                  }
                }
              } else if (await confirmDelete(context, list.name)) {
                final deleted = await store.run(
                  () => store.repository.deleteList(listId),
                );
                if (deleted && context.mounted) Navigator.pop(context);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'rename',
                child: Text('Rename / edit budget'),
              ),
              PopupMenuItem(value: 'share', child: Text('Share')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          const DataStatus(),
          Expanded(
            child: ListView(
              children: [
                if (!list.completed)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.task_alt),
                      label: const Text('Finish shopping'),
                      onPressed: store.busy
                          ? null
                          : () async {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Finish shopping?'),
                                  content: const Text(
                                    'Ellam ready? Move this trip to Completed. All items and prices will be kept.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('Cancel'),
                                    ),
                                    FilledButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text('Finish'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirmed == true) {
                                final saved = await store.run(
                                  () => store.repository.finishList(listId),
                                );
                                if (saved && context.mounted) {
                                  dashboardTab.value = 1;
                                  Navigator.pop(context);
                                }
                              }
                            },
                    ),
                  ),
                if (list.completed)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Shopping kazhinju | Completed trip'),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: _SpendingCard(
                          label: 'Actual spent',
                          amount: summary.actualSpent,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _SpendingCard(
                          label: 'Remaining budget',
                          amount: summary.remaining,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Budget ${money(list.budget)}',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const Text('Essentials + Miscellaneous | Oru budget.'),
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
                            'Projection includes estimates for remaining or unpriced items.',
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
                          ? 'Essentials'
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
                      .map(
                        (item) => ShoppingItemTile(
                          item: item,
                          readOnly: list.completed,
                        ),
                      ),
                ],
              ],
            ),
          ),
          if (!list.completed)
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextButton.icon(
                      onPressed: store.busy
                          ? null
                          : () => Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    GroceryTextScreen(listId: listId),
                              ),
                            ),
                      icon: const Icon(Icons.edit_note),
                      label: const Text('Paste or type grocery list'),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: store.busy
                            ? null
                            : () => editItem(context, listId),
                        icon: const Icon(Icons.add),
                        label: const Text('Add item'),
                      ),
                    ),
                    if (store.voiceTips)
                      const Text(
                        'Paranjolu! Speak Malayalam + English. Check names and quantities.',
                      ),
                    OfflineSpeechInput(
                      key: ValueKey(listId),
                      inline: true,
                      onTranscript: (text) {
                        final candidates = GroceryParser().parse(text);
                        if (candidates.isNotEmpty) {
                          Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => GroceryReviewScreen(
                                listId: listId,
                                candidates: candidates,
                              ),
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SpendingCard extends StatelessWidget {
  const _SpendingCard({required this.label, required this.amount});
  final String label;
  final int amount;
  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Semantics(
        label: '$label ${money(amount)}',
        excludeSemantics: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                money(amount),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: amount < 0
                      ? Theme.of(context).colorScheme.error
                      : null,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
