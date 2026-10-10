import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'services/invoice_store.dart';
import 'views/dashboard_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await InvoiceStore.initialize();
  runApp(const FaktorsazApp());
}

class FaktorsazApp extends StatelessWidget {
  const FaktorsazApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'فاکتورساز',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFFF5F7FA),
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF087E78)),
          fontFamily: 'Vazirmatn',
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFFF5F7FA),
            foregroundColor: Color(0xFF172B4D),
            centerTitle: false,
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        locale: const Locale('fa'),
        supportedLocales: const [Locale('fa'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: const Directionality(
          textDirection: TextDirection.rtl,
          child: DashboardScreen(),
        ),
      );
}

class MyApp extends FaktorsazApp {
  const MyApp({super.key});
}
