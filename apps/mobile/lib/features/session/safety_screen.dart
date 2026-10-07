import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nesta_core/nesta_core.dart';
import 'package:provider/provider.dart';

import '../../config.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

enum SafetyReason { symptom, heartRate }

class SafetyArgs {
  const SafetyArgs({required this.reason, this.check, this.bpm});
  final SafetyReason reason;
  final SymptomCheck? check;
  final int? bpm;
}

/// Tehlike belirtisi veya nabız sınırı aşımında gösterilen güvenlik ekranı.
class SafetyScreen extends StatelessWidget {
  const SafetyScreen({super.key, required this.args});
  final SafetyArgs args;

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final urgent = args.check?.hasUrgent ?? false;
    final m = state.midwife;
    final phone = state.patient?.profile.phone;
    return Scaffold(
      backgroundColor: urgent ? NestaColors.dangerSoft : NestaColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('GÜVENLİK'),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Icon(
            urgent
                ? Icons.emergency_rounded
                : Icons.pause_circle_outline_rounded,
            size: 80,
            color: urgent ? NestaColors.danger : NestaColors.warning,
          ),
          const SizedBox(height: 12),
          Text(
            urgent
                ? 'Lütfen hemen sağlık kuruluşuna başvurun'
                : args.reason == SafetyReason.heartRate
                ? 'Egzersiz durduruldu'
                : 'Bugün egzersiz yapmayın',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          Text(
            urgent
                ? 'Bildirdiğiniz belirtiler acil değerlendirme gerektirebilir. '
                      'Egzersiz yapmayın. ${AppConfig.emergencyNumber}\'yi arayın '
                      'veya en yakın kadın doğum acil servisine gidin.'
                : args.reason == SafetyReason.heartRate
                ? 'Nabzınız${args.bpm == null ? '' : ' (${args.bpm} atım/dk)'} '
                      'güvenli sınırın üzerine çıktı. Oturun, derin ve yavaş '
                      'nefes alın, su için. Nabzınız 15 dakika içinde '
                      'normale dönmezse veya kendinizi kötü hissederseniz '
                      'ebenize ulaşın.'
                : 'Bildirdiğiniz belirtiler nedeniyle bugün egzersiz '
                      'yapmamanız önerilir. Dinlenin ve belirtiler sürerse '
                      'ebenize danışın.',
            textAlign: TextAlign.center,
            style: const TextStyle(height: 1.45),
          ),
          if (args.check != null && args.check!.signs.isNotEmpty) ...[
            const SizedBox(height: 16),
            for (final s in args.check!.signs)
              ListTile(
                dense: true,
                leading: Icon(
                  Icons.circle,
                  size: 10,
                  color: s.urgent ? NestaColors.danger : NestaColors.warning,
                ),
                title: Text(s.text),
              ),
          ],
          const SizedBox(height: 16),
          if (m != null)
            InfoBanner(
              icon: Icons.notifications_active_outlined,
              color: NestaColors.primary,
              background: NestaColors.mintSoft,
              text: 'Bu durum ebeniz ${m.displayName} ile paylaşıldı.',
            ),
          if (phone == null && m != null) const SizedBox(height: 4),
        ],
      ),
      bottomNavigationBar: BottomAction(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (urgent)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: NestaColors.danger,
                  ),
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => const AlertDialog(
                      title: Text('Acil durum'),
                      content: Text(
                        'Telefonunuzdan ${AppConfig.emergencyNumber}\'yi arayın.',
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.call),
                  label: const Text('${AppConfig.emergencyNumber} ACİL'),
                ),
              ),
            OutlinedButton(
              onPressed: () => context.go('/home'),
              child: const Text('ANA SAYFAYA DÖN'),
            ),
          ],
        ),
      ),
    );
  }
}
