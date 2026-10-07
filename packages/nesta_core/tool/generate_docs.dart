// Egzersiz kütüphanesinden uzman paneli değerlendirme belgesini üretir:
//   dart run tool/generate_docs.dart > ../../docs/EGZERSIZ_KATALOGU.md
import 'package:nesta_core/nesta_core.dart';

String _n(double v) => v == v.roundToDouble() ? v.toInt().toString() : '$v';

String _limits(PostureRule r) {
  if (r.min != null && r.max != null) return '${_n(r.min!)}–${_n(r.max!)}';
  if (r.min != null) return '≥ ${_n(r.min!)}';
  return '≤ ${_n(r.max!)}';
}

void main() {
  final b = StringBuffer()
    ..writeln('# Nesta Egzersiz Kataloğu ve Postür Kuralları')
    ..writeln()
    ..writeln(
        '> Bu belge `packages/nesta_core` içindeki egzersiz kütüphanesinden '
        'otomatik üretilmiştir (`dart run tool/generate_docs.dart`). Uygulamanın '
        'kullandığı değerlerin birebir aynısıdır. Uzman paneli (ebe, kadın '
        'hastalıkları ve doğum uzmanı, fizyoterapist) değerlendirmesi için '
        'hazırlanmıştır; her madde için "uygun / değiştirilmeli / çıkarılmalı" '
        'görüşü ve gerekçesi istenir.')
    ..writeln()
    ..writeln('## Özet')
    ..writeln()
    ..writeln('| Egzersiz | Kategori | Takip | Trimester | Doz |')
    ..writeln('|---|---|---|---|---|');
  for (final e in exerciseLibrary) {
    final dose = e.mode == ExerciseMode.guided
        ? '${e.sets} set × ${e.guidedRepeats} tekrar'
        : e.targetReps != null
            ? '${e.sets} set × ${e.targetReps} tekrar'
            : '${e.sets} set × ${e.targetSeconds} sn';
    b.writeln('| ${e.name} | ${e.category.label} | '
        '${e.usesCamera ? 'Kamera (${e.cameraView == CameraView.side ? 'yandan' : 'önden'})' : 'Sesli rehber'} | '
        '${(e.trimesters.map((t) => t.number).toList()..sort()).join(', ')} | $dose |');
  }
  for (final e in exerciseLibrary) {
    b
      ..writeln()
      ..writeln('## ${e.name}')
      ..writeln()
      ..writeln('- **Kimlik:** `${e.id}`')
      ..writeln('- **Amaç:** ${e.summary}')
      ..writeln('- **Faydası:** ${e.benefits}')
      ..writeln(
          '- **Trimester:** ${(e.trimesters.map((t) => t.label).toList()..sort()).join(', ')}')
      ..writeln('- **Set arası dinlenme:** ${e.restSeconds} sn')
      ..writeln()
      ..writeln('**Uygulama adımları**')
      ..writeln();
    for (var i = 0; i < e.steps.length; i++) {
      b.writeln('${i + 1}. ${e.steps[i]}');
    }
    if (e.safetyNotes.isNotEmpty) {
      b
        ..writeln()
        ..writeln('**Güvenlik notları**')
        ..writeln();
      for (final n in e.safetyNotes) {
        b.writeln('- $n');
      }
    }
    if (e.usesCamera) {
      b
        ..writeln()
        ..writeln('**Postür kuralları** (açılar derece; oranlar yüzde)')
        ..writeln()
        ..writeln('| Kural | Güvenli aralık | Sesli uyarı |')
        ..writeln('|---|---|---|');
      for (final r in e.rules) {
        b.writeln('| ${r.label} (`${r.id}`) | ${_limits(r)} | "${r.cue}" |');
      }
      final rep = e.repSpec;
      if (rep != null) {
        b
          ..writeln()
          ..writeln(
              'Tekrar sayımı: ölçüm ${rep.startsHigh ? '${_n(rep.low)} altına inip ${_n(rep.high)} üstüne çıktığında' : '${_n(rep.high)} üstüne çıkıp ${_n(rep.low)} altına indiğinde'} bir tekrar sayılır.');
      }
    } else {
      b
        ..writeln()
        ..writeln('**Sesli komut döngüsü** (${e.guidedRepeats} kez): '
            '${e.guidedSteps.map((s) => '"${s.cue}" ${s.seconds} sn').join(' → ')}');
    }
  }
  b
    ..writeln()
    ..writeln('## Güvenlik eşikleri')
    ..writeln()
    ..writeln(
        '**Nabız hedef aralıkları** (Kanada 2019 gebelikte fiziksel aktivite kılavuzu; Mottola ve ark., 2018)')
    ..writeln()
    ..writeln('| Grup | Hedef aralık (atım/dk) | Durdurma eşiği |')
    ..writeln('|---|---|---|');
  for (final (age, bmi) in [(25, 22.0), (33, 22.0), (25, 28.0), (33, 28.0)]) {
    final z = HeartRateZone.forProfile(age: age, bmi: bmi);
    b.writeln('| ${z.source} | ${z.low}–${z.high} | ≥ ${z.stopThreshold} |');
  }
  b
    ..writeln()
    ..writeln('- Hedefin üzerinde 15 sn: sesli "tempoyu düşürün" uyarısı.')
    ..writeln(
        '- Durdurma eşiğinde 10 sn veya hedefin üzerinde 90 sn: seans durdurulur, ebeye acil uyarı gider.')
    ..writeln(
        '- Nabzı etkileyen ilaç (ör. beta bloker) kullananlarda nabız eşiği uygulanmaz; 3 dakikada bir konuşma testi hatırlatılır ve seans sonunda Borg (6–20) zorlanma puanı alınır.')
    ..writeln()
    ..writeln(
        '**Seans öncesi/sırası/sonrası sorgulanan tehlike belirtileri** (ACOG, 2020)')
    ..writeln();
  for (final w in warningSigns) {
    b.writeln('- ${w.text}${w.urgent ? ' — **acil**' : ''}');
  }
  b
    ..writeln()
    ..writeln(
        '**Kontrendikasyon taraması** (ACOG, 2020): ${absoluteContraindications.length} mutlak '
        '(biri bile varsa program açılmaz), ${relativeContraindications.length} göreceli '
        '(ebe/hekim değerlendirmesine sunulur) soru.');
  print(b.toString().trimRight());
}
