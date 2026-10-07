import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nesta_core/nesta_core.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

/// ACOG (2020) kontrendikasyon taraması.
class ScreeningScreen extends StatefulWidget {
  const ScreeningScreen({super.key, this.editing = false});
  final bool editing;

  @override
  State<ScreeningScreen> createState() => _ScreeningScreenState();
}

class _ScreeningScreenState extends State<ScreeningScreen> {
  final Map<String, bool> _answers = {};

  @override
  void initState() {
    super.initState();
    final prev = context.read<AppState>().patient?.screening;
    if (prev != null) _answers.addAll(prev.answers);
  }

  bool get _complete =>
      allScreeningQuestions.every((q) => _answers.containsKey(q.id));

  Future<void> _save() async {
    final state = context.read<AppState>();
    final router = GoRouter.of(context);
    final result = ScreeningResult(
      answers: _answers,
      completedAt: state.now().toUtc(),
    );
    await state.saveScreening(result);
    if (widget.editing) router.pop();
  }

  @override
  Widget build(BuildContext context) {
    final answered = _answers.length, total = allScreeningQuestions.length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('SAĞLIK TARAMASI'),
        automaticallyImplyLeading: widget.editing,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          const Text(
            'Egzersizin sizin için güvenli olup olmadığını değerlendirmek için '
            'aşağıdaki soruları yanıtlayın. Emin olmadığınız sorular için '
            'ebenize veya hekiminize danışın.',
            style: TextStyle(color: NestaColors.inkSoft, height: 1.4),
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: answered / total,
            borderRadius: BorderRadius.circular(4),
            minHeight: 6,
          ),
          const SizedBox(height: 4),
          Text(
            '$answered / $total yanıtlandı',
            style: const TextStyle(fontSize: 12, color: NestaColors.inkSoft),
          ),
          const SizedBox(height: 16),
          const SectionTitle('Bölüm 1'),
          for (final q in absoluteContraindications) _question(q),
          const SizedBox(height: 8),
          const SectionTitle('Bölüm 2'),
          for (final q in relativeContraindications) _question(q),
        ],
      ),
      bottomNavigationBar: BottomAction(
        child: BusyButton(
          label: _complete ? 'KAYDET' : 'TÜM SORULARI YANITLAYIN',
          onPressed: _complete ? _save : null,
        ),
      ),
    );
  }

  Widget _question(ScreeningQuestion q) {
    final a = _answers[q.id];
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(q.text, style: const TextStyle(height: 1.35)),
            const SizedBox(height: 10),
            Row(
              children: [
                _choice(
                  'Hayır',
                  a == false,
                  () => setState(() => _answers[q.id] = false),
                ),
                const SizedBox(width: 10),
                _choice(
                  'Evet',
                  a == true,
                  () => setState(() => _answers[q.id] = true),
                  danger: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _choice(
    String label,
    bool selected,
    VoidCallback onTap, {
    bool danger = false,
  }) => Expanded(
    child: ChoiceChip(
      label: SizedBox(
        width: double.infinity,
        child: Text(label, textAlign: TextAlign.center),
      ),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: danger ? NestaColors.peachSoft : NestaColors.mintSoft,
      showCheckmark: false,
    ),
  );
}

/// Mutlak kontrendikasyon bulunduğunda gösterilir.
class ScreeningResultScreen extends StatelessWidget {
  const ScreeningResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final positives = state.patient?.screening?.positiveAbsolute ?? const [];
    return Scaffold(
      appBar: AppBar(
        title: const Text('TARAMA SONUCU'),
        automaticallyImplyLeading: false,
        actions: [
          TextButton(onPressed: state.signOut, child: const Text('Çıkış')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Icon(
            Icons.health_and_safety_outlined,
            size: 72,
            color: NestaColors.peach,
          ),
          const SizedBox(height: 12),
          Text(
            'Şu an egzersiz önerilmiyor',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          const Text(
            'Yanıtlarınıza göre gebeliğinizde egzersizin risk oluşturabileceği '
            'bir durum bulunuyor. Bu nedenle uygulama egzersiz programını '
            'açmıyor. Lütfen ebeniz veya hekiminizle görüşün.',
            textAlign: TextAlign.center,
            style: TextStyle(height: 1.45),
          ),
          const SizedBox(height: 20),
          for (final q in positives)
            ListTile(
              leading: const Icon(
                Icons.circle,
                size: 10,
                color: NestaColors.danger,
              ),
              title: Text(q.text),
              dense: true,
            ),
          const SizedBox(height: 20),
          const InfoBanner(
            text:
                'Durumunuz değişirse (ör. hekiminiz egzersize izin verirse) '
                'taramayı yeniden doldurabilirsiniz. İpuçları bölümündeki '
                'nefes ve gevşeme önerilerinden yararlanabilirsiniz.',
          ),
        ],
      ),
      bottomNavigationBar: BottomAction(
        child: OutlinedButton(
          onPressed: () => context.push('/screening/edit'),
          child: const Text('TARAMAYI YENİDEN DOLDUR'),
        ),
      ),
    );
  }
}
