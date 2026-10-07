import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:nesta_core/nesta_core.dart';
import 'package:provider/provider.dart';

import 'features/auth/auth_screen.dart';
import 'features/consent/consent_screen.dart';
import 'features/exercises/exercise_detail_screen.dart';
import 'features/exercises/library_screen.dart';
import 'features/home/home_screen.dart';
import 'features/home/home_shell.dart';
import 'features/midwife_link/link_screens.dart';
import 'features/onboarding/welcome_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/profile_setup/profile_form_screen.dart';
import 'features/screening/screening_screen.dart';
import 'features/session/pre_check_screen.dart';
import 'features/session/safety_screen.dart';
import 'features/session/session_screen.dart';
import 'features/session/session_summary_screen.dart';
import 'features/tips/tips_screen.dart';
import 'features/tracking/tracking_screen.dart';
import 'state/app_state.dart';
import 'theme.dart';
import 'widgets/common.dart';

class NestaApp extends StatefulWidget {
  const NestaApp({super.key, required this.state});
  final AppState state;

  @override
  State<NestaApp> createState() => _NestaAppState();
}

class _NestaAppState extends State<NestaApp> {
  late final GoRouter _router = buildRouter(widget.state);

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider.value(
    value: widget.state,
    child: MaterialApp.router(
      title: 'Nesta',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      routerConfig: _router,
      locale: const Locale('tr', 'TR'),
      supportedLocales: const [Locale('tr', 'TR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
    ),
  );
}

/// Kurulum adımları: hoş geldin → giriş → aydınlatma/onay → profil →
/// tarama → ebe bağlantısı → ebe onayı → ana sayfa.
String? gateFor(AppState s) {
  if (!s.welcomeSeen) return '/welcome';
  if (!s.authResolved) return '/splash';
  if (s.uid == null) return '/auth';
  if (s.role == null) return '/splash';
  if (s.role == UserRole.midwife) return '/midwife';
  if (!s.patientLoaded) return '/splash';
  if (s.needsConsent) return '/consent';
  final p = s.patient;
  if (p == null) return '/profile-setup';
  if (p.screening == null) return '/screening';
  if (p.screening!.outcome == ScreeningOutcome.ineligible)
    return '/screening-result';
  if (p.midwifeId == null) return '/link';
  if (!p.clearance.isApproved) return '/waiting';
  return null;
}

const _gateRoutes = {
  '/welcome',
  '/splash',
  '/auth',
  '/midwife',
  '/consent',
  '/profile-setup',
  '/screening',
  '/screening-result',
  '/link',
  '/waiting',
};

/// Gate dışında da açılabilen yollar (ör. ineligible iken taramayı düzenleme).
const _alwaysAllowed = {'/screening/edit', '/consent/view'};

GoRouter buildRouter(AppState state) {
  Exercise exerciseOf(GoRouterState s) =>
      exerciseById(s.pathParameters['id']!) ?? exerciseLibrary.first;

  return GoRouter(
    initialLocation: '/home',
    refreshListenable: state,
    redirect: (context, rs) {
      final loc = rs.matchedLocation;
      final gate = gateFor(state);
      if (gate != null) {
        if (_alwaysAllowed.contains(loc) &&
            gate != '/auth' &&
            gate != '/splash') {
          return null;
        }
        return loc == gate ? null : gate;
      }
      return _gateRoutes.contains(loc) ? '/home' : null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const _Splash()),
      GoRoute(path: '/welcome', builder: (_, _) => const WelcomeScreen()),
      GoRoute(path: '/auth', builder: (_, _) => const AuthScreen()),
      GoRoute(
        path: '/midwife',
        builder: (_, _) => const MidwifeOnMobileScreen(),
      ),
      GoRoute(path: '/consent', builder: (_, _) => const ConsentScreen()),
      GoRoute(
        path: '/consent/view',
        builder: (_, _) => const ConsentScreen(readOnly: true),
      ),
      GoRoute(
        path: '/profile-setup',
        builder: (_, _) => const ProfileFormScreen(),
      ),
      GoRoute(path: '/screening', builder: (_, _) => const ScreeningScreen()),
      GoRoute(
        path: '/screening/edit',
        builder: (_, _) => const ScreeningScreen(editing: true),
      ),
      GoRoute(
        path: '/screening-result',
        builder: (_, _) => const ScreeningResultScreen(),
      ),
      GoRoute(path: '/link', builder: (_, _) => const LinkMidwifeScreen()),
      GoRoute(
        path: '/waiting',
        builder: (_, _) => const WaitingApprovalScreen(),
      ),
      GoRoute(
        path: '/profile/edit',
        builder: (_, _) => const ProfileFormScreen(editing: true),
      ),
      GoRoute(
        path: '/exercise/:id',
        builder: (_, s) => ExerciseDetailScreen(exercise: exerciseOf(s)),
      ),
      GoRoute(
        path: '/exercise/:id/check',
        builder: (_, s) => PreCheckScreen(exercise: exerciseOf(s)),
      ),
      GoRoute(
        path: '/exercise/:id/session',
        redirect: (_, s) => s.extra is SymptomCheck
            ? null
            : '/exercise/${s.pathParameters['id']}/check',
        builder: (_, s) => SessionScreen(
          exercise: exerciseOf(s),
          preCheck: s.extra! as SymptomCheck,
        ),
      ),
      GoRoute(
        path: '/session/summary',
        redirect: (_, s) => s.extra is ExerciseSession ? null : '/home',
        builder: (_, s) =>
            SessionSummaryScreen(session: s.extra! as ExerciseSession),
      ),
      GoRoute(
        path: '/safety',
        redirect: (_, s) => s.extra is SafetyArgs ? null : '/home',
        builder: (_, s) => SafetyScreen(args: s.extra! as SafetyArgs),
      ),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => HomeShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/tracking',
                builder: (_, _) => const TrackingScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/exercises',
                builder: (_, _) => const LibraryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/tips', builder: (_, _) => const TipsScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (_, _) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          NestaLogo(size: 72),
          SizedBox(height: 24),
          CircularProgressIndicator(),
        ],
      ),
    ),
  );
}
