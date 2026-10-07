import 'package:flutter/material.dart';
import 'package:nesta_core/nesta_core.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/exercise_figure.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final _page = PageController();
  int _index = 0;

  static final _slides = [
    (
      'HOŞ GELDİNİZ',
      'Sağlıklı ve kontrollü bir hamilelik yolculuğu için yanınızdayız.',
      standingSideBend,
    ),
    (
      'ANLIK GERİ BİLDİRİM',
      'Kameranız hareketinizi izler; yanlış bir pozisyonda sizi sesli olarak '
          'uyarır. Görüntünüz telefonunuzdan hiçbir yere gönderilmez.',
      supportedPlieSquat,
    ),
    (
      'EBENİZLE BİRLİKTE',
      'Programınız ebenizin onayıyla açılır. Nabzınız ve tehlike belirtileri '
          'izlenir, gerektiğinde ebenize haber verilir.',
      catCow,
    ),
  ];

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  void _next() {
    if (_index < _slides.length - 1) {
      _page.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      );
    } else {
      context.read<AppState>().markWelcomeSeen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            const NestaLogo(size: 52),
            Expanded(
              child: PageView.builder(
                controller: _page,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) {
                  final (title, body, exercise) = _slides[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      children: [
                        Expanded(
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 20),
                            decoration: BoxDecoration(
                              color: NestaColors.forKey(exercise.colorKey).$2,
                              shape: BoxShape.circle,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: ExerciseFigure(exercise: exercise),
                            ),
                          ),
                        ),
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(color: NestaColors.primary),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          body,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 15,
                            height: 1.4,
                            color: NestaColors.inkSoft,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _slides.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _index ? 22 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _index
                          ? NestaColors.primary
                          : NestaColors.line,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            ),
            BottomAction(
              child: FilledButton(
                onPressed: _next,
                child: Text(_index == _slides.length - 1 ? 'BAŞLA' : 'DEVAM'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
