import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nesta_core/nesta_core.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../services/heart_rate_source.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _exportData(BuildContext context) async {
    final state = context.read<AppState>();
    final box = context.findRenderObject() as RenderBox?;
    final dir = await getTemporaryDirectory();
    final stamp = DateTime.now().toIso8601String().substring(0, 10);
    final csv = File('${dir.path}/nesta_seanslar_$stamp.csv')
      ..writeAsStringSync('﻿${sessionsToCsv(state.sessions)}');
    final json = File('${dir.path}/nesta_verilerim_$stamp.json')
      ..writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert({
          'hesap': {'eposta': state.repo.currentEmail, 'uid': state.uid},
          'kayit': state.patient?.toMap(),
          'seanslar': state.sessions.map((s) => s.toMap()).toList(),
        }),
      );
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(csv.path), XFile(json.path)],
        subject: 'Nesta verilerim',
        sharePositionOrigin: box == null
            ? null
            : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final password = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hesabı sil'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Hesabınız ve tüm verileriniz (profil, tarama ve seans '
              'kayıtları) kalıcı olarak silinecek. Bu işlem geri alınamaz.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: password,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Şifreniz'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => ctx.pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: NestaColors.danger),
            onPressed: () => ctx.pop(true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await runWithFeedback(
      context,
      () => context.read<AppState>().deleteAccount(password.text),
      success: 'Hesabınız silindi.',
    );
  }

  Future<void> _checkWatch(BuildContext context) async {
    final state = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    if (state.patient?.profile.takesBetaBlocker ?? false) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Nabzı etkileyen ilaç kullandığınız için seanslarda '
            'nabız yerine konuşma testi kullanılıyor.',
          ),
        ),
      );
      return;
    }
    if (state.repo.isDemo) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Demo modunda nabız simülasyonla gösterilir. Seans '
            'sırasında nabız göstergesine uzun basarak güvenlik uyarısını '
            'deneyebilirsiniz.',
          ),
        ),
      );
      return;
    }
    final source = HealthHeartRateSource();
    final result = await source.prepare();
    if (result == HeartRateAvailability.healthConnectMissing) {
      await source.installHealthConnect();
      return;
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          result == HeartRateAvailability.ready
              ? '${source.name} bağlantısı hazır. Akıllı saatinizin uygulamasında '
                    'nabız verisinin ${source.name} ile paylaşıldığından emin olun.'
              : result.label,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final p = state.patient!;
    final ga = state.gestationalAge!;
    final zone = state.heartRateZone;
    final s = state.settings;
    return Scaffold(
      appBar: AppBar(title: const Text('PROFİL')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: NestaColors.peachSoft,
                    child: Text(
                      p.profile.fullName.characters.first.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: NestaColors.peach,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.profile.fullName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text('${ga.label} · ${ga.trimester.label}'),
                        Text(
                          state.repo.currentEmail ?? '',
                          style: const TextStyle(color: NestaColors.inkSoft),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (p.profile.riskFactors.isNotEmpty)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final r in p.profile.riskFactors)
                  Chip(
                    label: Text(r.label),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          const SizedBox(height: 12),
          if (state.midwife != null)
            Card(
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: NestaColors.mintSoft,
                  child: Icon(
                    Icons.medical_services_outlined,
                    color: NestaColors.primary,
                  ),
                ),
                title: Text(state.midwife!.displayName),
                subtitle: Text(
                  '${state.midwife!.institution}\n${p.clearance.status.label}',
                ),
                isThreeLine: true,
              ),
            ),
          const SizedBox(height: 8),
          if (zone != null)
            InfoBanner(
              icon: Icons.favorite_border_rounded,
              color: NestaColors.peach,
              background: NestaColors.peachSoft,
              text:
                  'Egzersiz sırasında hedef nabız aralığınız: $zone '
                  '(Kanada 2019 gebelik kılavuzu, ${zone.source}).',
            ),
          const SizedBox(height: 16),
          const SectionTitle('Bilgilerim'),
          _tile(
            context,
            Icons.edit_outlined,
            'Gebelik bilgilerini düzenle',
            () => context.push('/profile/edit'),
          ),
          _tile(
            context,
            Icons.fact_check_outlined,
            'Sağlık taramasını güncelle',
            () => context.push('/screening/edit'),
          ),
          _tile(
            context,
            Icons.watch_outlined,
            'Akıllı saat bağlantısı',
            () => _checkWatch(context),
          ),
          const SizedBox(height: 16),
          const SectionTitle('Sesli koç ve kamera'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Sesli uyarılar'),
            value: s.voiceEnabled,
            onChanged: (v) => state.updateSettings(s.copyWith(voiceEnabled: v)),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Konuşma hızı'),
            subtitle: Slider(
              value: s.speechRate,
              min: 0.3,
              max: 0.7,
              divisions: 4,
              label: s.speechRate.toStringAsFixed(1),
              onChanged: s.voiceEnabled
                  ? (v) => state.updateSettings(s.copyWith(speechRate: v))
                  : null,
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Ön kamerayla başla'),
            value: s.useFrontCamera,
            onChanged: (v) =>
                state.updateSettings(s.copyWith(useFrontCamera: v)),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Kamerada iskeleti göster'),
            value: s.showSkeleton,
            onChanged: (v) => state.updateSettings(s.copyWith(showSkeleton: v)),
          ),
          const SizedBox(height: 16),
          const SectionTitle('Gizlilik'),
          _tile(
            context,
            Icons.privacy_tip_outlined,
            'Aydınlatma metni',
            () => context.push('/consent/view'),
          ),
          _tile(
            context,
            Icons.download_outlined,
            'Verilerimi indir',
            () => runWithFeedback(context, () => _exportData(context)),
          ),
          _tile(
            context,
            Icons.delete_outline_rounded,
            'Hesabımı sil',
            () => _deleteAccount(context),
            color: NestaColors.danger,
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: state.signOut,
            child: const Text('ÇIKIŞ YAP'),
          ),
          const SizedBox(height: 16),
          const Text(
            medicalDisclaimer,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: NestaColors.inkSoft),
          ),
          const SizedBox(height: 4),
          Text(
            'Nesta 1.0.0${state.repo.isDemo ? ' · Demo modu' : ''}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: NestaColors.inkSoft),
          ),
        ],
      ),
    );
  }

  Widget _tile(
    BuildContext context,
    IconData icon,
    String title,
    VoidCallback onTap, {
    Color? color,
  }) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon, color: color ?? NestaColors.primary),
    title: Text(title, style: TextStyle(color: color)),
    trailing: const Icon(Icons.chevron_right_rounded),
    onTap: onTap,
  );
}
