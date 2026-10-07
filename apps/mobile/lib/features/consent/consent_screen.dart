import 'package:flutter/material.dart';
import 'package:nesta_core/nesta_core.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

/// KVKK aydınlatma metni ve açık rıza. Onay verilmeden hiçbir sağlık verisi
/// toplanmaz.
class ConsentScreen extends StatefulWidget {
  const ConsentScreen({super.key, this.readOnly = false});

  /// Profil ekranından yalnızca okumak için açıldığında true.
  final bool readOnly;

  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen> {
  bool _health = false;
  bool _research = false;
  bool _disclaimer = false;

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('AYDINLATMA VE ONAY'),
        automaticallyImplyLeading: widget.readOnly,
        actions: [
          if (!widget.readOnly)
            TextButton(onPressed: state.signOut, child: const Text('Çıkış')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Text(
            privacyNoticeTitle,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          for (final p in privacyNotice)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(p, style: const TextStyle(height: 1.45)),
            ),
          const SizedBox(height: 4),
          const InfoBanner.warning(title: 'Önemli', text: medicalDisclaimer),
          if (!widget.readOnly) ...[
            const SizedBox(height: 16),
            _check(
              value: _health,
              onChanged: (v) => setState(() => _health = v),
              text: healthDataConsentText,
            ),
            _check(
              value: _research,
              onChanged: (v) => setState(() => _research = v),
              text: researchConsentText,
            ),
            _check(
              value: _disclaimer,
              onChanged: (v) => setState(() => _disclaimer = v),
              text:
                  'Uygulamanın tanı koymadığını ve egzersize ebe/hekim onayıyla '
                  'başlayacağımı anladım. (Zorunlu)',
            ),
          ] else ...[
            const SizedBox(height: 16),
            Text(
              'Onay sürümü: $consentVersion',
              style: const TextStyle(color: NestaColors.inkSoft),
            ),
          ],
        ],
      ),
      bottomNavigationBar: widget.readOnly
          ? null
          : BottomAction(
              child: BusyButton(
                label: 'ONAYLIYORUM',
                onPressed: _health && _disclaimer
                    ? () => state.acceptConsent(research: _research)
                    : null,
              ),
            ),
    );
  }

  Widget _check({
    required bool value,
    required ValueChanged<bool> onChanged,
    required String text,
  }) => CheckboxListTile(
    value: value,
    onChanged: (v) => onChanged(v ?? false),
    controlAffinity: ListTileControlAffinity.leading,
    contentPadding: EdgeInsets.zero,
    title: Text(text, style: const TextStyle(fontSize: 14, height: 1.35)),
  );
}
