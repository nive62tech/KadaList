import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/shopping_store.dart';

class DataStatus extends StatelessWidget {
  const DataStatus({super.key});
  @override
  Widget build(BuildContext context) {
    final store = context.watch<ShoppingStore>();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (store.busy) const LinearProgressIndicator(),
        if (store.error != null)
          MaterialBanner(
            content: Text(store.error!),
            actions: [
              TextButton(
                onPressed: store.busy ? null : store.load,
                child: const Text('Retry'),
              ),
            ],
          ),
      ],
    );
  }
}
