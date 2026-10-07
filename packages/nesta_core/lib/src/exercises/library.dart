/// Nesta egzersiz kütüphanesi.
///
/// Egzersiz seçimi ve açı sınırları ACOG (2020) ve Kanada (2019) gebelikte
/// fiziksel aktivite kılavuzları ile klinik pilates ilkelerine dayanır.
/// Sırtüstü yatış gerektiren egzersizler bilinçli olarak dahil edilmemiştir.
/// Açı eşikleri başlangıç değerleridir; teknik doğrulama ve uzman paneli
/// değerlendirmesiyle güncellenmelidir.
library;

import '../models/pregnancy.dart';
import '../pose/form_checker.dart';
import '../pose/pose.dart';
import 'exercise.dart';

// ---------------------------------------------------------------------------
// Ölçüm yardımcıları
// ---------------------------------------------------------------------------

const _allTrimesters = {Trimester.first, Trimester.second, Trimester.third};

/// Yandan çekimde kameraya dönük taraf üzerinden ölçüm.
double? _onVisibleSide(Pose p, double? Function(SideJoints s) f) =>
    f(SideJoints.of(p.visibleSide));

double? _jointAngle(Pose p, Joint a, Joint b, Joint c) {
  final pa = p[a], pb = p[b], pc = p[c];
  if (pa == null || pb == null || pc == null) return null;
  return Geometry.angle(pa, pb, pc);
}

double? _fromVertical(Pose p, Joint from, Joint to) {
  final a = p[from], b = p[to];
  if (a == null || b == null) return null;
  return Geometry.angleFromVertical(a, b);
}

/// Kalça ortası → omuz ortası doğrusunun düşeyden sapması.
double? _trunkLean(Pose p) {
  final hip = p.midpoint(Joint.leftHip, Joint.rightHip);
  final sh = p.midpoint(Joint.leftShoulder, Joint.rightShoulder);
  if (hip == null || sh == null) return null;
  return Geometry.angleFromVertical(hip, sh);
}

double? _minOf(double? a, double? b) =>
    a == null ? b : (b == null ? a : (a < b ? a : b));

double? _maxOf(double? a, double? b) =>
    a == null ? b : (b == null ? a : (a > b ? a : b));

double? _avgOf(double? a, double? b) =>
    a == null ? b : (b == null ? a : (a + b) / 2);

double? _kneeAngle(Pose p, SideJoints s) =>
    _jointAngle(p, s.hip, s.knee, s.ankle);

/// İki eklem çifti arasındaki yatay mesafe oranı (yüzde).
double? _widthRatio(Pose p, Joint a1, Joint a2, Joint b1, Joint b2) {
  final pa1 = p[a1], pa2 = p[a2], pb1 = p[b1], pb2 = p[b2];
  if (pa1 == null || pa2 == null || pb1 == null || pb2 == null) return null;
  final b = (pb1.x - pb2.x).abs();
  if (b < 1e-6) return null;
  return 100 * (pa1.x - pa2.x).abs() / b;
}

/// Kalça–omuz–bilek açısı: kolun gövdeye göre ne kadar kaldırıldığı.
double? _armRaise(Pose p, SideJoints s) =>
    _jointAngle(p, s.hip, s.shoulder, s.wrist);

/// Yandan çekimde, bileği daha yüksekte olan bacağın kalçaya göre yüksekliği.
double? _raisedLegElevation(Pose p) {
  double? e(SideJoints s) {
    final hip = p[s.hip], ankle = p[s.ankle];
    if (hip == null || ankle == null) return null;
    return Geometry.elevation(hip, ankle);
  }

  return _maxOf(e(SideJoints.left), e(SideJoints.right));
}

/// Yandan çekimde, bileği daha aşağıda olan (yere basan) kolun dikliği.
double? _supportArmTilt(Pose p) {
  final l = p[Joint.leftWrist], r = p[Joint.rightWrist];
  final SideJoints s;
  if (l != null && r != null) {
    s = l.y >= r.y ? SideJoints.left : SideJoints.right;
  } else if (l != null) {
    s = SideJoints.left;
  } else {
    s = SideJoints.right;
  }
  return _fromVertical(p, s.shoulder, s.wrist);
}

/// Yan yatışta üstteki bacağın alttaki bacakla yaptığı açı.
double? _sideLyingLegSpread(Pose p) {
  final hip = p.midpoint(Joint.leftHip, Joint.rightHip);
  final la = p[Joint.leftAnkle], ra = p[Joint.rightAnkle];
  if (hip == null || la == null || ra == null) return null;
  final top = la.y < ra.y ? la : ra;
  final bottom = identical(top, la) ? ra : la;
  return Geometry.angle(top, hip, bottom);
}

bool Function(Pose) _sideVisible(List<Joint> Function(SideJoints s) joints) =>
    (p) => p.hasAll(joints(SideJoints.of(p.visibleSide)));

bool Function(Pose) _allVisible(Set<Joint> joints) => (p) => p.hasAll(joints);

// ---------------------------------------------------------------------------
// Demo kareleri için yardımcılar
// ---------------------------------------------------------------------------

/// Yandan görünüm: uzak taraf hafif kaydırılarak yakın tarafın kopyası olur.
DemoFrame _side(Map<String, (double, double)> near,
    {Map<String, (double, double)> far = const {}, (double, double)? nose}) {
  const names = {
    'shoulder': (Joint.leftShoulder, Joint.rightShoulder),
    'elbow': (Joint.leftElbow, Joint.rightElbow),
    'wrist': (Joint.leftWrist, Joint.rightWrist),
    'hip': (Joint.leftHip, Joint.rightHip),
    'knee': (Joint.leftKnee, Joint.rightKnee),
    'ankle': (Joint.leftAnkle, Joint.rightAnkle),
  };
  final f = <Joint, (double, double)>{};
  near.forEach((k, v) {
    final (l, r) = names[k]!;
    f[l] = v;
    f[r] = far[k] ?? (v.$1 - 0.015, v.$2 - 0.01);
  });
  if (nose != null) f[Joint.nose] = nose;
  return f;
}

DemoFrame _front(Map<String, ((double, double), (double, double))> pairs,
    {required (double, double) nose}) {
  const names = {
    'shoulder': (Joint.rightShoulder, Joint.leftShoulder),
    'elbow': (Joint.rightElbow, Joint.leftElbow),
    'wrist': (Joint.rightWrist, Joint.leftWrist),
    'hip': (Joint.rightHip, Joint.leftHip),
    'knee': (Joint.rightKnee, Joint.leftKnee),
    'ankle': (Joint.rightAnkle, Joint.leftAnkle),
  };
  final f = <Joint, (double, double)>{Joint.nose: nose};
  pairs.forEach((k, v) {
    final (r, l) = names[k]!;
    f[r] = v.$1;
    f[l] = v.$2;
  });
  return f;
}

// ---------------------------------------------------------------------------
// Egzersizler
// ---------------------------------------------------------------------------

final diaphragmaticBreathing = Exercise(
  id: 'diyafram_nefesi',
  name: 'Diyafram Nefesi',
  summary: 'Isınma ve gevşeme için derin karın nefesi.',
  category: ExerciseCategory.breathing,
  mode: ExerciseMode.guided,
  trimesters: _allTrimesters,
  colorKey: 'sky',
  steps: const [
    'Sırtınız dik olacak şekilde sandalyeye ya da bağdaş kurarak oturun.',
    'Bir elinizi göğsünüze, diğerini karnınızın üst kısmına koyun.',
    'Burnunuzdan 4 saniye boyunca nefes alırken karnınızın şiştiğini hissedin.',
    'Dudaklarınızı hafifçe büzerek 6 saniye boyunca yavaşça nefes verin.',
  ],
  benefits:
      'Kalp hızını düşürür, stresi azaltır ve pelvik taban ile diyafram arasındaki uyumu destekler.',
  safetyNotes: const ['Başınız dönerse normal nefesinize dönün ve dinlenin.'],
  guidedSteps: const [
    GuidedStep('Burnunuzdan nefes alın', 4),
    GuidedStep('Yavaşça nefes verin', 6),
  ],
  guidedRepeats: 8,
  restSeconds: 0,
);

final catCow = Exercise(
  id: 'kedi_inek',
  name: 'Kedi-İnek Gevşeme',
  summary: 'Sırt ve bel bölgesindeki gerginliği azaltan omurga esnetmesi.',
  category: ExerciseCategory.mobility,
  mode: ExerciseMode.camera,
  cameraView: CameraView.side,
  trimesters: _allTrimesters,
  colorKey: 'mint',
  steps: const [
    'Mat üzerinde dört ayak üzerine gelin; elleriniz omuzlarınızın, dizleriniz kalçalarınızın altında olsun.',
    'Nefes alırken göğsünüzü öne doğru açın ve başınızı hafifçe kaldırın (inek).',
    'Nefes verirken sırtınızı yukarı doğru yuvarlayın ve çenenizi göğsünüze yaklaştırın (kedi).',
    'Hareketi nefesinizle uyumlu şekilde, zorlamadan tekrarlayın.',
  ],
  benefits:
      'Bel ağrısını hafifletir, omurga esnekliğini korur ve bebeğin rahim içindeki yükünü sırttan alır.',
  safetyNotes: const [
    'Belinizi aşırı çukurlaştırmayın; inek pozisyonunda hareket küçük olmalıdır.',
    'Bilekleriniz ağrırsa ellerinizin altına katlanmış havlu koyun.',
  ],
  targetSeconds: 60,
  sets: 2,
  buildRules: () => [
    PostureRule(
      id: 'eller_omuz_altinda',
      label: 'Eller omuz altında',
      cue: 'Ellerinizi omuzlarınızın tam altına yerleştirin.',
      metric: _supportArmTilt,
      max: 20,
    ),
    PostureRule(
      id: 'dizler_kalca_altinda',
      label: 'Dizler kalça altında',
      cue: 'Dizlerinizi kalçalarınızın altına getirin.',
      metric: (p) => _onVisibleSide(p, (s) => _fromVertical(p, s.hip, s.knee)),
      max: 20,
    ),
  ],
  isBodyVisible: _sideVisible((s) => [s.shoulder, s.wrist, s.hip, s.knee]),
  demoFrames: [
    _side({
      'shoulder': (0.70, 0.50),
      'elbow': (0.70, 0.67),
      'wrist': (0.70, 0.85),
      'hip': (0.35, 0.49),
      'knee': (0.35, 0.85),
      'ankle': (0.10, 0.86),
    }, nose: (
      0.83,
      0.44
    )),
    _side({
      'shoulder': (0.70, 0.48),
      'elbow': (0.70, 0.66),
      'wrist': (0.70, 0.85),
      'hip': (0.35, 0.47),
      'knee': (0.35, 0.85),
      'ankle': (0.10, 0.86),
    }, nose: (
      0.78,
      0.60
    )),
  ],
);

final supportedPlieSquat = Exercise(
  id: 'destekli_plie_squat',
  name: 'Destekli Plié Squat',
  summary: 'Kalça ve bacak kaslarını güçlendirir, doğuma hazırlık sağlar.',
  category: ExerciseCategory.strength,
  mode: ExerciseMode.camera,
  cameraView: CameraView.front,
  trimesters: _allTrimesters,
  colorKey: 'peach',
  steps: const [
    'Bir sandalyenin arkasına tutunarak ayaklarınızı omuz genişliğinden biraz daha geniş açın.',
    'Ayak uçlarınızı hafifçe dışa çevirin, gövdenizi dik tutun.',
    'Nefes alırken dizlerinizi ayak uçları yönünde bükerek kontrollü şekilde çömelin.',
    'Nefes verirken topuklarınızdan güç alarak başlangıç pozisyonuna dönün.',
  ],
  benefits:
      'Kalça, uyluk ve pelvik çevre kaslarını güçlendirir; gündelik hareketlerde ve doğumda kullanılan kasları destekler.',
  safetyNotes: const [
    'Mutlaka sabit bir desteğe tutunun; denge merkezi gebelikte değişir.',
    'Dizleriniz 90 derecenin altına inmesin.',
  ],
  targetReps: 10,
  sets: 2,
  buildRules: () => [
    PostureRule(
      id: 'cok_derin',
      label: 'Derinlik güvenli',
      cue: 'Çok derine inmeyin; dizleriniz doksan derecenin altına inmesin.',
      metric: (p) => _minOf(
          _kneeAngle(p, SideJoints.left), _kneeAngle(p, SideJoints.right)),
      min: 85,
    ),
    PostureRule(
      id: 'dizler_ice',
      label: 'Dizler dışa dönük',
      cue: 'Dizlerinizi içe kaçırmayın; ayak uçlarınızla aynı yönde tutun.',
      metric: (p) => _widthRatio(p, Joint.leftKnee, Joint.rightKnee,
          Joint.leftAnkle, Joint.rightAnkle),
      min: 75,
      hysteresis: 5,
    ),
    PostureRule(
      id: 'govde_dik',
      label: 'Gövde dik',
      cue: 'Gövdenizi dik tutun, öne eğilmeyin.',
      metric: _trunkLean,
      max: 15,
    ),
  ],
  isBodyVisible: _allVisible({
    Joint.leftShoulder,
    Joint.rightShoulder,
    Joint.leftHip,
    Joint.rightHip,
    Joint.leftKnee,
    Joint.rightKnee,
    Joint.leftAnkle,
    Joint.rightAnkle,
  }),
  repSpec: RepSpec(
    metric: (p) =>
        _avgOf(_kneeAngle(p, SideJoints.left), _kneeAngle(p, SideJoints.right)),
    low: 140,
    high: 160,
  ),
  demoFrames: [
    _front({
      'shoulder': ((0.40, 0.25), (0.60, 0.25)),
      'elbow': ((0.33, 0.38), (0.67, 0.38)),
      'wrist': ((0.42, 0.47), (0.58, 0.47)),
      'hip': ((0.43, 0.50), (0.57, 0.50)),
      'knee': ((0.37, 0.70), (0.63, 0.70)),
      'ankle': ((0.36, 0.90), (0.64, 0.90)),
    }, nose: (
      0.50,
      0.14
    )),
    _front({
      'shoulder': ((0.40, 0.41), (0.60, 0.41)),
      'elbow': ((0.33, 0.54), (0.67, 0.54)),
      'wrist': ((0.42, 0.63), (0.58, 0.63)),
      'hip': ((0.43, 0.66), (0.57, 0.66)),
      'knee': ((0.30, 0.72), (0.70, 0.72)),
      'ankle': ((0.36, 0.90), (0.64, 0.90)),
    }, nose: (
      0.50,
      0.30
    )),
  ],
);

final standingSideBend = Exercise(
  id: 'ayakta_yana_esneme',
  name: 'Ayakta Yana Esneme',
  summary: 'Gövde yanlarını açar, nefes kapasitesini destekler.',
  category: ExerciseCategory.mobility,
  mode: ExerciseMode.camera,
  cameraView: CameraView.front,
  trimesters: _allTrimesters,
  colorKey: 'lilac',
  steps: const [
    'Ayaklarınızı omuz genişliğinde açarak dik durun.',
    'Bir kolunuzu nefes alırken başınızın üzerine kaldırın.',
    'Nefes verirken gövdenizi karşı tarafa doğru hafifçe esnetin.',
    'Ortaya dönün ve diğer tarafa tekrarlayın.',
  ],
  benefits:
      'Kaburgalar arasındaki kasları esneterek nefes almayı kolaylaştırır ve sırt gerginliğini azaltır.',
  safetyNotes: const ['Esnemeyi ağrı hissetmeden, rahat bir aralıkta yapın.'],
  targetReps: 8,
  sets: 2,
  buildRules: () => [
    PostureRule(
      id: 'asiri_egilme',
      label: 'Esneme kontrollü',
      cue: 'Yana çok fazla eğilmeyin, hareketi rahat bir aralıkta yapın.',
      metric: _trunkLean,
      max: 30,
    ),
    PostureRule(
      id: 'ayak_acikligi',
      label: 'Ayaklar omuz genişliğinde',
      cue: 'Ayaklarınızı omuz genişliğinde açarak dengenizi koruyun.',
      metric: (p) => _widthRatio(p, Joint.leftAnkle, Joint.rightAnkle,
          Joint.leftShoulder, Joint.rightShoulder),
      min: 80,
      hysteresis: 5,
    ),
  ],
  isBodyVisible: _allVisible({
    Joint.leftShoulder,
    Joint.rightShoulder,
    Joint.leftHip,
    Joint.rightHip,
    Joint.leftAnkle,
    Joint.rightAnkle,
  }),
  repSpec: RepSpec(metric: _trunkLean, low: 6, high: 15, startsHigh: false),
  demoFrames: [
    _front({
      'shoulder': ((0.40, 0.25), (0.60, 0.25)),
      'elbow': ((0.37, 0.38), (0.63, 0.38)),
      'wrist': ((0.36, 0.50), (0.64, 0.50)),
      'hip': ((0.43, 0.50), (0.57, 0.50)),
      'knee': ((0.42, 0.70), (0.58, 0.70)),
      'ankle': ((0.38, 0.90), (0.62, 0.90)),
    }, nose: (
      0.50,
      0.14
    )),
    _front({
      'shoulder': ((0.50, 0.23), (0.69, 0.31)),
      'elbow': ((0.52, 0.10), (0.74, 0.45)),
      'wrist': ((0.66, 0.05), (0.76, 0.58)),
      'hip': ((0.43, 0.50), (0.57, 0.50)),
      'knee': ((0.42, 0.70), (0.58, 0.70)),
      'ankle': ((0.38, 0.90), (0.62, 0.90)),
    }, nose: (
      0.64,
      0.14
    )),
  ],
);

final seatedArmRaise = Exercise(
  id: 'oturarak_kol_kaldirma',
  name: 'Oturarak Kol Kaldırma',
  summary: 'Postürü düzeltir, omuz ve üst sırt kaslarını çalıştırır.',
  category: ExerciseCategory.strength,
  mode: ExerciseMode.camera,
  cameraView: CameraView.front,
  trimesters: _allTrimesters,
  colorKey: 'sand',
  steps: const [
    'Sandalyenin ön kısmına, ayaklarınız yere tam basacak şekilde dik oturun.',
    'Kollarınız yanlarda, avuç içleriniz içe bakarken omuzlarınızı gevşetin.',
    'Nefes alırken iki kolunuzu aynı anda başınızın üzerine kaldırın.',
    'Nefes verirken kollarınızı yavaşça indirin.',
  ],
  benefits:
      'Göğüs büyümesiyle öne kayan omuzları dengeler, üst sırt kaslarını güçlendirir.',
  targetReps: 10,
  sets: 2,
  buildRules: () => [
    PostureRule(
      id: 'dik_otur',
      label: 'Dik oturuş',
      cue: 'Dik oturun, omurganızı uzatın.',
      metric: _trunkLean,
      max: 10,
    ),
    PostureRule(
      id: 'kol_simetrisi',
      label: 'Kollar eşit',
      cue: 'Kollarınızı aynı anda ve eşit yükseklikte kaldırın.',
      metric: (p) {
        final l = _armRaise(p, SideJoints.left),
            r = _armRaise(p, SideJoints.right);
        if (l == null || r == null) return null;
        return (l - r).abs();
      },
      max: 25,
    ),
  ],
  isBodyVisible: _allVisible({
    Joint.leftShoulder,
    Joint.rightShoulder,
    Joint.leftHip,
    Joint.rightHip,
    Joint.leftWrist,
    Joint.rightWrist,
  }),
  repSpec: RepSpec(
    metric: (p) =>
        _avgOf(_armRaise(p, SideJoints.left), _armRaise(p, SideJoints.right)),
    low: 40,
    high: 140,
    startsHigh: false,
  ),
  demoFrames: [
    _front({
      'shoulder': ((0.40, 0.30), (0.60, 0.30)),
      'elbow': ((0.36, 0.44), (0.64, 0.44)),
      'wrist': ((0.35, 0.56), (0.65, 0.56)),
      'hip': ((0.42, 0.58), (0.58, 0.58)),
      'knee': ((0.40, 0.66), (0.60, 0.66)),
      'ankle': ((0.40, 0.88), (0.60, 0.88)),
    }, nose: (
      0.50,
      0.19
    )),
    _front({
      'shoulder': ((0.40, 0.30), (0.60, 0.30)),
      'elbow': ((0.34, 0.16), (0.66, 0.16)),
      'wrist': ((0.32, 0.03), (0.68, 0.03)),
      'hip': ((0.42, 0.58), (0.58, 0.58)),
      'knee': ((0.40, 0.66), (0.60, 0.66)),
      'ankle': ((0.40, 0.88), (0.60, 0.88)),
    }, nose: (
      0.50,
      0.19
    )),
  ],
);

final sideLyingLegLift = Exercise(
  id: 'yan_yatarak_bacak_kaldirma',
  name: 'Yan Yatarak Bacak Kaldırma',
  summary: 'Kalça yan kaslarını güçlendirir, pelvis dengesini destekler.',
  category: ExerciseCategory.strength,
  mode: ExerciseMode.camera,
  cameraView: CameraView.front,
  trimesters: _allTrimesters,
  colorKey: 'mint',
  steps: const [
    'Mat üzerinde yan yatın; başınızı alttaki kolunuza yaslayın, alt dizinizi hafifçe bükün.',
    'Üstteki bacağınızı düz tutarak kalça hizasında uzatın.',
    'Nefes verirken üst bacağınızı yavaşça yukarı kaldırın.',
    'Nefes alırken kontrollü şekilde indirin. Seti tamamlayınca diğer tarafa dönün.',
  ],
  benefits:
      'Pelvik kuşak ağrısını azaltmaya yardımcı olur, yürürken ve ayakta dururken kalçayı dengeler.',
  safetyNotes: const [
    'Karnınızın altına küçük bir yastık koyabilirsiniz.',
    'Kasıkta ya da kasık kemiğinde ağrı olursa hareketi durdurun.',
  ],
  targetReps: 10,
  sets: 2,
  buildRules: () => [
    PostureRule(
      id: 'bacak_cok_yuksek',
      label: 'Bacak yüksekliği güvenli',
      cue: 'Bacağınızı çok yükseğe kaldırmayın, kalçanızı zorlamayın.',
      metric: _sideLyingLegSpread,
      max: 40,
    ),
  ],
  isBodyVisible: _allVisible({
    Joint.leftHip,
    Joint.rightHip,
    Joint.leftKnee,
    Joint.rightKnee,
    Joint.leftAnkle,
    Joint.rightAnkle,
  }),
  repSpec: RepSpec(
      metric: _sideLyingLegSpread, low: 12, high: 25, startsHigh: false),
  demoFrames: [
    {
      Joint.nose: (0.11, 0.63),
      Joint.leftShoulder: (0.22, 0.70),
      Joint.rightShoulder: (0.22, 0.64),
      Joint.leftElbow: (0.15, 0.74),
      Joint.leftWrist: (0.12, 0.67),
      Joint.rightElbow: (0.30, 0.70),
      Joint.rightWrist: (0.34, 0.78),
      Joint.leftHip: (0.50, 0.72),
      Joint.rightHip: (0.50, 0.66),
      Joint.leftKnee: (0.68, 0.78),
      Joint.leftAnkle: (0.88, 0.80),
      Joint.rightKnee: (0.68, 0.72),
      Joint.rightAnkle: (0.88, 0.74),
    },
    {
      Joint.nose: (0.11, 0.63),
      Joint.leftShoulder: (0.22, 0.70),
      Joint.rightShoulder: (0.22, 0.64),
      Joint.leftElbow: (0.15, 0.74),
      Joint.leftWrist: (0.12, 0.67),
      Joint.rightElbow: (0.30, 0.70),
      Joint.rightWrist: (0.34, 0.78),
      Joint.leftHip: (0.50, 0.72),
      Joint.rightHip: (0.50, 0.66),
      Joint.leftKnee: (0.68, 0.78),
      Joint.leftAnkle: (0.88, 0.80),
      Joint.rightKnee: (0.68, 0.61),
      Joint.rightAnkle: (0.86, 0.56),
    },
  ],
);

final birdDog = Exercise(
  id: 'kus_kopek',
  name: 'Kuş-Köpek',
  summary: 'Derin karın ve sırt kaslarını çalıştıran denge egzersizi.',
  category: ExerciseCategory.balance,
  mode: ExerciseMode.camera,
  cameraView: CameraView.side,
  // 3. trimesterde denge ve karın kası ayrışması riski nedeniyle önerilmez.
  trimesters: const {Trimester.first, Trimester.second},
  colorKey: 'peach',
  steps: const [
    'Dört ayak üzerine gelin; elleriniz omuz, dizleriniz kalça hizasında olsun.',
    'Karnınızı hafifçe içe çekerek sırtınızı düz tutun.',
    'Nefes verirken sağ kolunuzu öne, sol bacağınızı geriye uzatın.',
    'Kalça hizasını bozmadan başlangıca dönün ve karşı tarafla tekrarlayın.',
  ],
  benefits:
      'Gövde stabilitesini ve dengeyi geliştirir, bel ağrısının önlenmesine katkı sağlar.',
  safetyNotes: const [
    'Bacağınızı kalça hizasından yukarı kaldırmayın.',
    'Dengeniz zorlanıyorsa yalnızca bacağı uzatarak yapın.',
  ],
  targetReps: 8,
  sets: 2,
  buildRules: () => [
    PostureRule(
      id: 'bacak_kalca_ustu',
      label: 'Bacak kalça hizasında',
      cue:
          'Bacağınızı kalça hizasından yukarı kaldırmayın, belinizi çukurlaştırmayın.',
      metric: _raisedLegElevation,
      max: 10,
    ),
    PostureRule(
      id: 'destek_kolu',
      label: 'Destek eli omuz altında',
      cue: 'Destek elinizi omzunuzun altında tutun.',
      metric: _supportArmTilt,
      max: 20,
    ),
  ],
  isBodyVisible: _sideVisible((s) => [s.shoulder, s.hip, s.knee, s.ankle]),
  repSpec: RepSpec(
      metric: _raisedLegElevation, low: -35, high: -12, startsHigh: false),
  demoFrames: [
    _side({
      'shoulder': (0.70, 0.50),
      'elbow': (0.70, 0.67),
      'wrist': (0.70, 0.85),
      'hip': (0.35, 0.50),
      'knee': (0.35, 0.85),
      'ankle': (0.10, 0.86),
    }, nose: (
      0.83,
      0.47
    )),
    _side({
      'shoulder': (0.70, 0.50),
      'elbow': (0.70, 0.67),
      'wrist': (0.70, 0.85),
      'hip': (0.35, 0.50),
      'knee': (0.18, 0.50),
      'ankle': (0.02, 0.50),
    }, far: {
      'shoulder': (0.685, 0.49),
      'elbow': (0.84, 0.48),
      'wrist': (0.96, 0.47),
      'hip': (0.335, 0.49),
      'knee': (0.335, 0.84),
      'ankle': (0.085, 0.85),
    }, nose: (
      0.83,
      0.47
    )),
  ],
);

final wallPelvicTilt = Exercise(
  id: 'duvarda_pelvik_tilt',
  name: 'Duvarda Pelvik Tilt',
  summary: 'Bel çukurluğunu azaltır, bel ağrısını hafifletir.',
  category: ExerciseCategory.mobility,
  mode: ExerciseMode.camera,
  cameraView: CameraView.side,
  trimesters: _allTrimesters,
  colorKey: 'sky',
  steps: const [
    'Sırtınızı duvara yaslayın; topuklarınız duvardan bir ayak boyu uzakta olsun.',
    'Dizlerinizi hafifçe bükün, omuzlarınızı gevşetin.',
    'Nefes verirken karnınızı içe çekip belinizi duvara doğru bastırın.',
    'Nefes alırken gevşeyin. Hareketi yavaş ve kontrollü tekrarlayın.',
  ],
  benefits:
      'Karın ve bel kaslarını dengeler, gebelikte artan bel çukurluğunun yarattığı ağrıyı azaltır.',
  targetSeconds: 60,
  sets: 2,
  buildRules: () => [
    PostureRule(
      id: 'dizler_hafif_bukulu',
      label: 'Dizler hafif bükülü',
      cue: 'Dizlerinizi yalnızca hafifçe bükün, çömelmeyin.',
      metric: (p) => _onVisibleSide(p, (s) => _kneeAngle(p, s)),
      min: 150,
    ),
    PostureRule(
      id: 'sirt_duvarda',
      label: 'Sırt duvarda',
      cue: 'Sırtınızı duvara yaslı ve dik tutun.',
      metric: (p) =>
          _onVisibleSide(p, (s) => _fromVertical(p, s.hip, s.shoulder)),
      max: 12,
    ),
  ],
  isBodyVisible: _sideVisible((s) => [s.shoulder, s.hip, s.knee, s.ankle]),
  demoFrames: [
    _side({
      'shoulder': (0.31, 0.25),
      'elbow': (0.32, 0.38),
      'wrist': (0.35, 0.48),
      'hip': (0.33, 0.50),
      'knee': (0.38, 0.70),
      'ankle': (0.40, 0.90),
    }, nose: (
      0.36,
      0.16
    )),
    _side({
      'shoulder': (0.31, 0.25),
      'elbow': (0.32, 0.38),
      'wrist': (0.35, 0.48),
      'hip': (0.345, 0.51),
      'knee': (0.385, 0.70),
      'ankle': (0.40, 0.90),
    }, nose: (
      0.36,
      0.16
    )),
  ],
);

final pelvicFloor = Exercise(
  id: 'pelvik_taban',
  name: 'Pelvik Taban Güçlendirme',
  summary: 'Kegel egzersizi: idrar kaçırmayı önler, doğuma hazırlar.',
  category: ExerciseCategory.pelvicFloor,
  mode: ExerciseMode.guided,
  trimesters: _allTrimesters,
  colorKey: 'sand',
  steps: const [
    'Rahat bir pozisyonda oturun veya yan yatın.',
    'İdrarınızı tutmaya çalışıyormuş gibi pelvik taban kaslarınızı içe ve yukarı doğru kasın.',
    'Kasılmayı 5 saniye koruyun; bu sırada nefesinizi tutmayın, karın ve kalça kaslarınızı gevşek bırakın.',
    '5 saniye boyunca tamamen gevşeyin.',
  ],
  benefits:
      'Gebelik ve doğum sonrasında idrar kaçırma riskini azaltır, pelvik organları destekler.',
  safetyNotes: const [
    'Egzersizi idrar yaparken yapmayın.',
    'Kasıkta ağrı hissederseniz ebenize danışın.',
  ],
  guidedSteps: const [
    GuidedStep('Kasın ve tutun', 5),
    GuidedStep('Gevşeyin', 5),
  ],
  guidedRepeats: 10,
  sets: 2,
  restSeconds: 30,
);

/// Kütüphanedeki tüm egzersizler (önerilen sırayla).
final exerciseLibrary = <Exercise>[
  diaphragmaticBreathing,
  catCow,
  supportedPlieSquat,
  standingSideBend,
  seatedArmRaise,
  sideLyingLegLift,
  birdDog,
  wallPelvicTilt,
  pelvicFloor,
];

Exercise? exerciseById(String id) {
  for (final e in exerciseLibrary) {
    if (e.id == id) return e;
  }
  return null;
}

/// Gebe için kullanılabilir egzersizler: trimestere uygun ve ebe tarafından
/// kapatılmamış olanlar.
List<Exercise> availableExercises(Trimester t,
        {Set<String> disabled = const {}}) =>
    exerciseLibrary
        .where((e) => e.allowedIn(t) && !disabled.contains(e.id))
        .toList();

/// Günün programı: ısınma (nefes) + dönüşümlü üç ana egzersiz + pelvik taban.
///
/// Ana egzersizler günden güne değişir; böylece hafta içinde tüm kas grupları
/// çalıştırılır.
List<Exercise> dailyProgram(DateTime day, Trimester t,
    {Set<String> disabled = const {}}) {
  final available = availableExercises(t, disabled: disabled);
  final warmUp =
      available.where((e) => e.category == ExerciseCategory.breathing);
  final coolDown =
      available.where((e) => e.category == ExerciseCategory.pelvicFloor);
  final main = available
      .where((e) =>
          e.category != ExerciseCategory.breathing &&
          e.category != ExerciseCategory.pelvicFloor)
      .toList();
  final picked = <Exercise>[];
  if (main.isNotEmpty) {
    final dayIndex =
        DateTime.utc(day.year, day.month, day.day).millisecondsSinceEpoch ~/
            Duration.millisecondsPerDay;
    final start = dayIndex % main.length;
    for (var i = 0; i < 3 && i < main.length; i++) {
      picked.add(main[(start + i) % main.length]);
    }
  }
  return [...warmUp.take(1), ...picked, ...coolDown.take(1)];
}
