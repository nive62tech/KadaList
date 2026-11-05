import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/shopping_store.dart';
import '../services/money.dart';
import '../widgets/edit_dialog.dart';
import '../widgets/data_status.dart';
import 'list_screen.dart';
import '../services/budget_summary.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final store = context.watch<ShoppingStore>();
    return Scaffold(
      appBar: AppBar(title: const Text('KadaList')),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Local First. Privacy First.'),
          ),
          const DataStatus(),
          Expanded(
            child: store.lists.isEmpty
                ? Center(
                    child: Text(
                      store.busy
                          ? 'Loading your lists…'
                          : 'No shopping lists yet. Create your first list.',
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: store.lists.length,
                    itemBuilder: (context, index) {
                      final list = store.lists[index];
                      final items = store.itemsFor(list.id);
                      final summary = BudgetSummary(list.budget, items);
                      return Card(
                        child: ListTile(
                          title: Text(list.name),
                          isThreeLine: true,
                          subtitle: Text(
                            '${list.createdAt.toLocal().toString().split(' ')[0]} · ${items.length} items\nBudget ${money(list.budget)} · Actual spent ${money(summary.actualSpent)}${summary.pendingPrices > 0 ? ' · Price pending' : ''}',
                          ),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => ListScreen(listId: list.id),
                            ),
                          ),
                          trailing: PopupMenuButton<String>(
                            enabled: !store.busy,
                            onSelected: (action) async {
                              if (action == 'edit') {
                                await editList(context, list: list);
                              } else if (await confirmDelete(
                                context,
                                list.name,
                              )) {
                                await store.run(
                                  () => store.repository.deleteList(list.id),
                                );
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'edit',
                                child: Text('Rename / edit budget'),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete'),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton.icon(
                onPressed: store.busy ? null : () => editList(context),
                icon: const Icon(Icons.add),
                label: const Text('Create Shopping List'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
