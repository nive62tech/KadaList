import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'database/app_database.dart';
import 'repositories/shopping_repository.dart';
import 'services/shopping_store.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const KadaListApp());
}

class KadaListApp extends StatelessWidget {
  const KadaListApp({super.key, this.repository});
  final ShoppingRepository? repository;
  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (_) =>
        ShoppingStore(repository ?? ShoppingRepository(AppDatabase()))..load(),
    child: MaterialApp(
      title: 'KadaList',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
      ),
      home: const HomeScreen(),
    ),
  );
}
