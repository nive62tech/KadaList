import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/shopping_store.dart';
import '../services/money.dart';
import '../services/budget_summary.dart';
import '../widgets/edit_dialog.dart';
import '../widgets/data_status.dart';
import '../widgets/grocery_art.dart';
import '../widgets/offline_speech_input.dart';
import 'list_screen.dart';

final dashboardTab = ValueNotifier<int>(0);

class KadaNavigation extends StatelessWidget {
  const KadaNavigation({super.key});
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
    valueListenable: dashboardTab,
    builder: (context, selected, _) => NavigationBar(
      selectedIndex: selected,
      onDestinationSelected: (index) {
        dashboardTab.value = index;
        Navigator.of(context).popUntil((route) => route.isFirst);
      },
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.shopping_basket_outlined),
          selectedIcon: Icon(Icons.shopping_basket),
          label: 'Lists',
        ),
        NavigationDestination(icon: Icon(Icons.task_alt), label: 'Completed'),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          label: 'Profile',
        ),
      ],
    ),
  );
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final store = context.watch<ShoppingStore>();
    return ValueListenableBuilder<int>(
      valueListenable: dashboardTab,
      builder: (context, tab, _) {
        final lists = store.lists
            .where((list) => list.completed == (tab == 1))
            .toList();
        return Scaffold(
          appBar: AppBar(
            title: const Text('KadaList'),
            actions: const [
              Padding(
                padding: EdgeInsets.all(16),
                child: Icon(Icons.shield_outlined),
              ),
            ],
          ),
          bottomNavigationBar: const KadaNavigation(),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const DataStatus(),
                  if (tab == 2) ...[
                    Text(
                      'Your little local corner',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const Text(
                      'Account venda. Ningalude data, ningalude phone.',
                    ),
                    const SizedBox(height: 24),
                    const ListTile(
                      leading: Icon(Icons.language),
                      title: Text('Voice preference: Manglish'),
                      subtitle: Text(
                        'Malayalam + English. Whisper language: ml. Review every transcript.',
                      ),
                    ),
                    const ListTile(
                      leading: Icon(Icons.lock_outline),
                      title: Text('Local First. Privacy First.'),
                      subtitle: Text(
                        'SQLite storage and recognition stay on this device. No login, backend, cloud sync, tracking or automatic model downloads. Audio stays in memory.',
                      ),
                    ),
                    SwitchListTile(
                      value: store.voiceTips,
                      title: const Text('Show Manglish voice tips'),
                      subtitle: const Text('Saved only on this device'),
                      onChanged: store.busy
                          ? null
                          : (value) => store.run(
                              () => store.repository.setVoiceTips(value),
                            ),
                    ),
                    const OfflineSpeechInput(
                      modelOnly: true,
                      onTranscript: _ignoreTranscript,
                    ),
                    ListTile(
                      leading: const Icon(Icons.folder_outlined),
                      title: const Text('Manage shopping data'),
                      subtitle: const Text(
                        'Open a list to rename, share or delete it. Deleting is permanent and asks for confirmation.',
                      ),
                      onTap: () => dashboardTab.value = 0,
                    ),
                    const ListTile(
                      leading: Icon(Icons.info_outline),
                      title: Text('Your device, your responsibility'),
                      subtitle: Text(
                        'Uninstalling or clearing app storage removes lists and imported models. Sharing a list sends only the text you choose through Android.',
                      ),
                    ),
                  ] else ...[
                    if (tab == 0) ...[
                      const GroceryArt(),
                      Text(
                        'Welcome to KadaList!',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      const Text('Entha vaanganam? Oru list undakkam!'),
                      const Text('Local First. Privacy First.'),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: store.busy ? null : () => editList(context),
                        icon: const Icon(Icons.add),
                        label: const Text('Create Shopping List'),
                      ),
                    ] else ...[
                      Text(
                        'Completed trips',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const Text(
                        'Shopping kazhinju! Your trips, safely saved.',
                      ),
                    ],
                    const SizedBox(height: 24),
                    Text(
                      tab == 0 ? 'Your shopping lists' : 'Trip history',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    if (lists.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          store.busy
                              ? 'Loading your lists...'
                              : tab == 0
                              ? 'List illa? Plan something fresh.'
                              : 'No finished trips yet. Tap Finish shopping inside a list.',
                        ),
                      ),
                    for (final list in lists)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Column(
                            children: [
                              ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: const Color(0xffffdda3),
                                  child: Icon(
                                    list.completed
                                        ? Icons.check
                                        : Icons.shopping_basket_outlined,
                                  ),
                                ),
                                title: Text(
                                  list.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(
                                  '${store.itemsFor(list.id).length} items | Budget ${money(list.budget)}\nActual spent ${money(BudgetSummary(list.budget, store.itemsFor(list.id)).actualSpent)}',
                                ),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute<void>(
                                    builder: (_) => ListScreen(listId: list.id),
                                  ),
                                ),
                              ),
                              if (list.completed)
                                TextButton.icon(
                                  onPressed: store.busy
                                      ? null
                                      : () async {
                                          int? id;
                                          final saved = await store.run(
                                            () async {
                                              id = await store.repository
                                                  .restartList(list.id);
                                            },
                                          );
                                          if (saved && context.mounted) {
                                            dashboardTab.value = 0;
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute<void>(
                                                builder: (_) =>
                                                    ListScreen(listId: id!),
                                              ),
                                            );
                                          }
                                        },
                                  icon: const Icon(Icons.restart_alt),
                                  label: const Text('Restart as new list'),
                                ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

void _ignoreTranscript(String _) {}
