import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'config.dart';
import 'data/demo_repository.dart';
import 'data/firebase_repository.dart';
import 'data/repository.dart';
import 'firebase_options.dart';
import 'state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await initializeDateFormatting('tr');
  final prefs = await SharedPreferences.getInstance();
  final repo = await _createRepository(prefs);
  runApp(NestaApp(state: AppState(repo, prefs)));
}

/// Firebase yapılandırılmışsa gerçek altyapıyı, değilse demo modunu kullanır.
Future<NestaRepository> _createRepository(SharedPreferences prefs) async {
  if (!AppConfig.forceDemo) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      return FirebaseRepository();
    } catch (e) {
      debugPrint('Firebase başlatılamadı, demo moduna geçiliyor: $e');
    }
  }
  return DemoRepository(prefs);
}
