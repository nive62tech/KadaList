import 'package:flutter/foundation.dart';
import '../models/shopping_list.dart';
import '../models/shopping_item.dart';
import '../repositories/shopping_repository.dart';

class ShoppingStore extends ChangeNotifier {
  ShoppingStore(this.repository);
  final ShoppingRepository repository;
  List<ShoppingList> _lists = [];
  List<ShoppingItem> _items = [];
  List<ShoppingList> get lists => List.unmodifiable(_lists);
  List<ShoppingItem> itemsFor(int id) =>
      _items.where((item) => item.listId == id).toList();
  bool voiceTips = true;
  bool busy = false;
  String? error;
  bool _disposed = false;
  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  Future<bool> load() => run(() async {});
  Future<bool> run(Future<void> Function() action) async {
    if (busy) {
      return false;
    }
    busy = true;
    error = null;
    _notify();
    try {
      await action();
      final lists = await repository.lists();
      voiceTips = await repository.showVoiceTips();
      final items = await repository.items();
      _lists = lists;
      _items = items;
      return true;
    } catch (_) {
      error = 'Could not access your shopping data. Please try again.';
      return false;
    } finally {
      busy = false;
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
