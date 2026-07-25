import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/dashboard_screen.dart';
import 'services/ledger.dart';
import 'services/storage.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FocusLedgerApp());
}

class FocusLedgerApp extends StatelessWidget {
  const FocusLedgerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => Ledger(Storage())..init(),
      child: MaterialApp(
        title: 'Non Finito',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.build(),
        home: const DashboardScreen(),
      ),
    );
  }
}
