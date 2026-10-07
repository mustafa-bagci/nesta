import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:nesta_core/nesta_core.dart';
import 'package:provider/provider.dart';

import 'data/demo_panel_repository.dart';
import 'data/firebase_panel_repository.dart';
import 'data/panel_repository.dart';
import 'firebase_options.dart';
import 'panel_state.dart';
import 'screens/dashboard.dart';
import 'screens/login_screen.dart';
import 'theme.dart';

const _forceDemo = bool.fromEnvironment('NESTA_DEMO');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('tr');
  runApp(PanelApp(state: PanelState(await _createRepository())));
}

Future<PanelRepository> _createRepository() async {
  if (!_forceDemo) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      return FirebasePanelRepository();
    } catch (e) {
      debugPrint('Firebase başlatılamadı, demo moduna geçiliyor: $e');
    }
  }
  return DemoPanelRepository();
}

class PanelApp extends StatelessWidget {
  const PanelApp({super.key, required this.state});
  final PanelState state;

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider.value(
    value: state,
    child: MaterialApp(
      title: 'Nesta Ebe Paneli',
      debugShowCheckedModeBanner: false,
      theme: buildPanelTheme(),
      locale: const Locale('tr', 'TR'),
      supportedLocales: const [Locale('tr', 'TR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: const _Root(),
    ),
  );
}

class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<PanelState>();
    if (!state.authResolved) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (state.uid == null) return const LoginScreen();
    if (state.role != UserRole.midwife) return const _NotMidwife();
    return const Dashboard();
  }
}

class _NotMidwife extends StatelessWidget {
  const _NotMidwife();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Bu hesap bir gebe hesabıdır. Ebe paneline yalnızca ebe/hekim '
              'hesaplarıyla giriş yapılabilir. Gebeler Nesta mobil uygulamasını '
              'kullanır.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: context.read<PanelState>().repo.signOut,
              child: const Text('Çıkış yap'),
            ),
          ],
        ),
      ),
    ),
  );
}
