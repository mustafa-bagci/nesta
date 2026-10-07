import 'package:flutter/material.dart';
import 'package:nesta_core/nesta_core.dart';
import 'package:provider/provider.dart';

import '../../data/demo_repository.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

/// Gebenin ebesinin davet koduyla bağlandığı ekran.
class LinkMidwifeScreen extends StatefulWidget {
  const LinkMidwifeScreen({super.key});

  @override
  State<LinkMidwifeScreen> createState() => _LinkMidwifeScreenState();
}

class _LinkMidwifeScreenState extends State<LinkMidwifeScreen> {
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _link() async {
    final m = await context.read<AppState>().linkMidwife(_code.text);
    if (m == null) {
      throw Exception(
        'Bu davet koduna ait bir ebe bulunamadı. Kodu kontrol edin.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('EBENİZE BAĞLANIN'),
        automaticallyImplyLeading: false,
        actions: [
          TextButton(onPressed: state.signOut, child: const Text('Çıkış')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Icon(
            Icons.diversity_1_rounded,
            size: 72,
            color: NestaColors.mint,
          ),
          const SizedBox(height: 12),
          Text(
            'Ebe davet kodu',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 10),
          const Text(
            'Egzersiz programınız, sizi takip eden ebenin veya hekimin onayıyla '
            'açılır. Ebenizden aldığınız 6 haneli davet kodunu girin.',
            textAlign: TextAlign.center,
            style: TextStyle(height: 1.45, color: NestaColors.inkSoft),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _code,
            textAlign: TextAlign.center,
            textCapitalization: TextCapitalization.characters,
            maxLength: 8,
            style: const TextStyle(
              fontSize: 24,
              letterSpacing: 6,
              fontWeight: FontWeight.w700,
            ),
            decoration: const InputDecoration(hintText: 'KOD', counterText: ''),
          ),
          if (state.repo.isDemo) ...[
            const SizedBox(height: 12),
            const InfoBanner(
              text:
                  'Demo modu: ${DemoRepository.demoInviteCode} kodunu girin. '
                  'Onay birkaç saniye içinde otomatik verilir.',
            ),
          ],
        ],
      ),
      bottomNavigationBar: BottomAction(
        child: BusyButton(label: 'BAĞLAN', onPressed: _link),
      ),
    );
  }
}

/// Ebe onayı beklenirken veya egzersiz önerilmediğinde gösterilir.
class WaitingApprovalScreen extends StatelessWidget {
  const WaitingApprovalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final c = state.patient?.clearance ?? Clearance.none;
    final rejected = c.status == ClearanceStatus.rejected;
    final m = state.midwife;
    return Scaffold(
      appBar: AppBar(
        title: const Text('EBE ONAYI'),
        automaticallyImplyLeading: false,
        actions: [
          TextButton(onPressed: state.signOut, child: const Text('Çıkış')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Icon(
            rejected
                ? Icons.do_not_disturb_on_outlined
                : Icons.hourglass_top_rounded,
            size: 72,
            color: rejected ? NestaColors.peach : NestaColors.sand,
          ),
          const SizedBox(height: 12),
          Text(
            rejected ? 'Egzersiz önerilmedi' : 'Onay bekleniyor',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          Text(
            rejected
                ? 'Ebeniz şu an sizin için egzersiz programı önermedi. Ayrıntılar '
                      'için ebenizle görüşün.'
                : 'Bilgileriniz ve tarama yanıtlarınız ebenize iletildi. Ebeniz '
                      'onay verdiğinde programınız burada açılacak.',
            textAlign: TextAlign.center,
            style: const TextStyle(height: 1.45, color: NestaColors.inkSoft),
          ),
          const SizedBox(height: 24),
          if (m != null)
            Card(
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: NestaColors.mintSoft,
                  child: Icon(Icons.person, color: NestaColors.primary),
                ),
                title: Text(m.displayName),
                subtitle: Text(m.institution),
              ),
            ),
          if (c.note != null) ...[
            const SizedBox(height: 12),
            InfoBanner(title: 'Ebenizin notu', text: c.note!),
          ],
          if (!rejected) ...[
            const SizedBox(height: 24),
            const Center(child: CircularProgressIndicator()),
          ],
        ],
      ),
    );
  }
}

/// Ebe hesabıyla mobil uygulamaya giriş yapıldığında gösterilir.
class MidwifeOnMobileScreen extends StatelessWidget {
  const MidwifeOnMobileScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const NestaLogo(),
            const SizedBox(height: 24),
            const Text(
              'Bu hesap bir ebe/hekim hesabıdır. Gebelerinizi takip etmek '
              'için ebe panelini bilgisayarınızın tarayıcısından açın.',
              textAlign: TextAlign.center,
              style: TextStyle(height: 1.45),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: context.read<AppState>().signOut,
              child: const Text('ÇIKIŞ YAP'),
            ),
          ],
        ),
      ),
    ),
  );
}
