import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:nesta_core/nesta_core.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

/// Gebelik bilgileri formu. İlk kurulumda ve profil düzenlemede kullanılır.
class ProfileFormScreen extends StatefulWidget {
  const ProfileFormScreen({super.key, this.editing = false});
  final bool editing;

  @override
  State<ProfileFormScreen> createState() => _ProfileFormScreenState();
}

class _ProfileFormScreenState extends State<ProfileFormScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _height = TextEditingController();
  final _weight = TextEditingController();
  final _otherRisk = TextEditingController();
  DateTime? _birthDate;
  DateTime? _pregnancyDate;
  bool _useDueDate = false;
  bool _betaBlocker = false;
  final Set<RiskFactor> _risks = {};
  final _fmt = DateFormat('d MMMM y', 'tr');

  @override
  void initState() {
    super.initState();
    final p = context.read<AppState>().patient?.profile;
    if (p != null) {
      _name.text = p.fullName;
      _phone.text = p.phone ?? '';
      _height.text = p.heightCm?.toStringAsFixed(0) ?? '';
      _weight.text = p.prePregnancyWeightKg?.toStringAsFixed(0) ?? '';
      _otherRisk.text = p.otherRiskNote ?? '';
      _birthDate = p.birthDate;
      _useDueDate = p.lastMenstrualPeriod == null;
      _pregnancyDate = p.lastMenstrualPeriod ?? p.dueDate;
      _betaBlocker = p.takesBetaBlocker;
      _risks.addAll(p.riskFactors);
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _phone, _height, _weight, _otherRisk]) {
      c.dispose();
    }
    super.dispose();
  }

  double? _num(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '.'));

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 28),
      firstDate: DateTime(now.year - 60),
      lastDate: DateTime(now.year - 14),
      helpText: 'Doğum tarihiniz',
    );
    if (d != null) setState(() => _birthDate = d);
  }

  Future<void> _pickPregnancyDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate:
          _pregnancyDate ??
          (_useDueDate
              ? now.add(const Duration(days: 140))
              : now.subtract(const Duration(days: 140))),
      firstDate: _useDueDate ? now : now.subtract(const Duration(days: 300)),
      lastDate: _useDueDate ? now.add(const Duration(days: 300)) : now,
      helpText: _useDueDate ? 'Tahmini doğum tarihi' : 'Son adet tarihi',
    );
    if (d != null) setState(() => _pregnancyDate = d);
  }

  PregnancyProfile? _build() {
    if (_birthDate == null || _pregnancyDate == null) return null;
    DateTime utc(DateTime d) => DateTime.utc(d.year, d.month, d.day);
    return PregnancyProfile(
      fullName: _name.text.trim(),
      birthDate: utc(_birthDate!),
      lastMenstrualPeriod: _useDueDate ? null : utc(_pregnancyDate!),
      dueDate: _useDueDate ? utc(_pregnancyDate!) : null,
      heightCm: _num(_height),
      prePregnancyWeightKg: _num(_weight),
      riskFactors: {..._risks},
      otherRiskNote: _otherRisk.text.trim().isEmpty
          ? null
          : _otherRisk.text.trim(),
      takesBetaBlocker: _betaBlocker,
      phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
    );
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final profile = _build();
    if (profile == null) {
      throw Exception('Doğum tarihinizi ve gebelik tarihinizi seçin.');
    }
    final ga = profile.gestationalAgeAt(DateTime.now());
    if (!ga.isPlausible || ga.weeks < 4) {
      throw Exception(
        'Girdiğiniz tarihe göre gebelik haftası hesaplanamadı. '
        'Lütfen tarihi kontrol edin.',
      );
    }
    final state = context.read<AppState>();
    final router = GoRouter.of(context);
    await state.saveProfile(profile);
    if (widget.editing) router.pop();
  }

  @override
  Widget build(BuildContext context) {
    final preview = _build()?.gestationalAgeAt(DateTime.now());
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.editing ? 'GEBELİK BİLGİLERİ' : 'PROFİL'),
        automaticallyImplyLeading: widget.editing,
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            if (!widget.editing)
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text(
                  'Programınızı gebelik haftanıza ve sağlık durumunuza göre '
                  'hazırlayabilmemiz için birkaç bilgiye ihtiyacımız var.',
                  style: TextStyle(color: NestaColors.inkSoft, height: 1.4),
                ),
              ),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Ad Soyad'),
              validator: (v) =>
                  v == null || v.trim().length < 3 ? 'Adınızı girin.' : null,
            ),
            const SizedBox(height: 14),
            _DateField(
              label: 'Doğum tarihi',
              value: _birthDate == null ? null : _fmt.format(_birthDate!),
              onTap: _pickBirthDate,
            ),
            const SizedBox(height: 20),
            const SectionTitle('Gebelik tarihi'),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Son adet tarihi')),
                ButtonSegment(value: true, label: Text('Tahmini doğum')),
              ],
              selected: {_useDueDate},
              onSelectionChanged: (s) => setState(() {
                _useDueDate = s.first;
                _pregnancyDate = null;
              }),
            ),
            const SizedBox(height: 12),
            _DateField(
              label: _useDueDate ? 'Tahmini doğum tarihi' : 'Son adet tarihi',
              value: _pregnancyDate == null
                  ? null
                  : _fmt.format(_pregnancyDate!),
              onTap: _pickPregnancyDate,
            ),
            if (preview != null && preview.isPlausible)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Gebelik haftanız: ${preview.label} (${preview.trimester.label})',
                  style: const TextStyle(
                    color: NestaColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            const SizedBox(height: 20),
            const SectionTitle('Gebelik öncesi boy ve kilo'),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _height,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Boy',
                      suffixText: 'cm',
                    ),
                    validator: (v) {
                      final n = _num(_height);
                      if (v == null || v.isEmpty) return null;
                      return n == null || n < 130 || n > 210
                          ? 'Geçersiz'
                          : null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _weight,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Kilo',
                      suffixText: 'kg',
                    ),
                    validator: (v) {
                      final n = _num(_weight);
                      if (v == null || v.isEmpty) return null;
                      return n == null || n < 35 || n > 200 ? 'Geçersiz' : null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const SectionTitle('Risk faktörleri'),
            const Text(
              'Hekiminizin size söylediği durumları işaretleyin.',
              style: TextStyle(color: NestaColors.inkSoft),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final r in RiskFactor.values)
                  FilterChip(
                    label: Text(r.label),
                    selected: _risks.contains(r),
                    onSelected: (v) =>
                        setState(() => v ? _risks.add(r) : _risks.remove(r)),
                  ),
              ],
            ),
            if (_risks.contains(RiskFactor.other)) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _otherRisk,
                decoration: const InputDecoration(
                  labelText: 'Diğer risk faktörü',
                ),
              ),
            ],
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _betaBlocker,
              onChanged: (v) => setState(() => _betaBlocker = v),
              title: const Text('Nabzı etkileyen ilaç kullanıyorum'),
              subtitle: const Text(
                'Ör. beta bloker (tansiyon/ritim ilacı). Bu durumda nabız '
                'yerine zorlanma hissiniz takip edilir.',
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Telefon (isteğe bağlı)',
                helperText: 'Ebenizin size ulaşabilmesi için',
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomAction(
        child: BusyButton(label: 'KAYDET', onPressed: _save),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
  });
  final String label;
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(14),
    child: InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: const Icon(Icons.calendar_month_outlined),
      ),
      child: Text(
        value ?? 'Seçin',
        style: TextStyle(
          color: value == null ? NestaColors.inkSoft : NestaColors.ink,
        ),
      ),
    ),
  );
}
