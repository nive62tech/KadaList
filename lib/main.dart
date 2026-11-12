import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'database/app_database.dart';
import 'repositories/shopping_repository.dart';
import 'services/shopping_store.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(const [
      'whisper.cpp',
      'ggml',
    ], await rootBundle.loadString('third_party/whisper-LICENSE.txt'));
  });
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
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xff286343),
          surface: const Color(0xfffffbf2),
        ),
        scaffoldBackgroundColor: const Color(0xfffffbf2),
        appBarTheme: const AppBarTheme(backgroundColor: Color(0xfffffbf2)),
        cardTheme: CardThemeData(
          elevation: 0,
          color: const Color(0xffedf2df),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      ),
      home: const HomeScreen(),
    ),
  );
}
