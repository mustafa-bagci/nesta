/// Poz tahmini modelinden bağımsız iskelet temsili ve geometri yardımcıları.
///
/// Eklem sıralaması BlazePose/ML Kit'in 33 noktalı modeliyle aynıdır;
/// mobil uygulama ML Kit çıktısını bu yapıya dönüştürür.
library;

import 'dart:math' as math;

enum Joint {
  nose,
  leftEyeInner,
  leftEye,
  leftEyeOuter,
  rightEyeInner,
  rightEye,
  rightEyeOuter,
  leftEar,
  rightEar,
  leftMouth,
  rightMouth,
  leftShoulder,
  rightShoulder,
  leftElbow,
  rightElbow,
  leftWrist,
  rightWrist,
  leftPinky,
  rightPinky,
  leftIndex,
  rightIndex,
  leftThumb,
  rightThumb,
  leftHip,
  rightHip,
  leftKnee,
  rightKnee,
  leftAnkle,
  rightAnkle,
  leftHeel,
  rightHeel,
  leftFootIndex,
  rightFootIndex,
}

enum BodySide { left, right }

/// Bir taraf için temel eklemleri döndürür.
class SideJoints {
  const SideJoints._(this.shoulder, this.elbow, this.wrist, this.hip, this.knee,
      this.ankle, this.ear);

  static const left = SideJoints._(
      Joint.leftShoulder,
      Joint.leftElbow,
      Joint.leftWrist,
      Joint.leftHip,
      Joint.leftKnee,
      Joint.leftAnkle,
      Joint.leftEar);
  static const right = SideJoints._(
      Joint.rightShoulder,
      Joint.rightElbow,
      Joint.rightWrist,
      Joint.rightHip,
      Joint.rightKnee,
      Joint.rightAnkle,
      Joint.rightEar);

  static SideJoints of(BodySide side) =>
      side == BodySide.left ? SideJoints.left : SideJoints.right;

  final Joint shoulder, elbow, wrist, hip, knee, ankle, ear;

  List<Joint> get all => [shoulder, elbow, wrist, hip, knee, ankle];
}

/// Görüntü koordinatlarında (piksel, y aşağı doğru artar) bir eklem noktası.
class Landmark {
  const Landmark(this.x, this.y, {this.likelihood = 1.0});
  final double x;
  final double y;

  /// Modelin bu noktanın görünür olduğuna dair güveni (0–1).
  final double likelihood;

  Landmark operator -(Landmark o) => Landmark(x - o.x, y - o.y);

  @override
  String toString() =>
      'Landmark(${x.toStringAsFixed(1)}, ${y.toStringAsFixed(1)}, '
      '${likelihood.toStringAsFixed(2)})';
}

/// Tek bir karedeki poz.
class Pose {
  const Pose(this.landmarks);
  final Map<Joint, Landmark> landmarks;

  static const minLikelihood = 0.5;

  /// Eklem güvenilir biçimde görünüyorsa döndürür.
  Landmark? operator [](Joint j) {
    final l = landmarks[j];
    if (l == null || l.likelihood < minLikelihood) return null;
    return l;
  }

  bool hasAll(Iterable<Joint> joints) => joints.every((j) => this[j] != null);

  double sideConfidence(BodySide side) {
    final joints = SideJoints.of(side).all;
    var sum = 0.0;
    for (final j in joints) {
      sum += landmarks[j]?.likelihood ?? 0;
    }
    return sum / joints.length;
  }

  /// Yandan çekimde kameraya dönük (daha iyi görünen) taraf.
  BodySide get visibleSide =>
      sideConfidence(BodySide.left) >= sideConfidence(BodySide.right)
          ? BodySide.left
          : BodySide.right;

  Landmark? midpoint(Joint a, Joint b) {
    final pa = this[a], pb = this[b];
    if (pa == null || pb == null) return null;
    return Landmark((pa.x + pb.x) / 2, (pa.y + pb.y) / 2,
        likelihood: math.min(pa.likelihood, pb.likelihood));
  }
}

/// Geometri yardımcıları. Tüm açılar derece cinsindendir.
abstract final class Geometry {
  static double _deg(double rad) => rad * 180 / math.pi;

  /// `b` köşesindeki a-b-c açısı (0–180).
  static double angle(Landmark a, Landmark b, Landmark c) {
    final v1x = a.x - b.x, v1y = a.y - b.y;
    final v2x = c.x - b.x, v2y = c.y - b.y;
    final n1 = math.sqrt(v1x * v1x + v1y * v1y);
    final n2 = math.sqrt(v2x * v2x + v2y * v2y);
    if (n1 == 0 || n2 == 0) return 0;
    final cos = ((v1x * v2x + v1y * v2y) / (n1 * n2)).clamp(-1.0, 1.0);
    return _deg(math.acos(cos));
  }

  /// `from`→`to` doğrusunun düşeyle yaptığı açı (0–90, yönden bağımsız).
  static double angleFromVertical(Landmark from, Landmark to) {
    final dx = (to.x - from.x).abs(), dy = (to.y - from.y).abs();
    if (dx == 0 && dy == 0) return 0;
    return _deg(math.atan2(dx, dy));
  }

  /// `from`→`to` doğrusunun yatayla yaptığı açı (0–90, yönden bağımsız).
  static double angleFromHorizontal(Landmark from, Landmark to) =>
      90 - angleFromVertical(from, to);

  /// `to` noktası `from`'un yatay hizasının ne kadar üstünde (derece);
  /// negatif değer altında olduğunu gösterir. Görüntüde y aşağı artar.
  static double elevation(Landmark from, Landmark to) {
    final dx = (to.x - from.x).abs();
    final dy = from.y - to.y;
    if (dx == 0 && dy == 0) return 0;
    return _deg(math.atan2(dy, dx));
  }

  /// İki doğru parçası arasındaki açı (0–180).
  static double between(Landmark a1, Landmark a2, Landmark b1, Landmark b2) {
    final shifted = Landmark(a1.x + (b2.x - b1.x), a1.y + (b2.y - b1.y));
    return angle(a2, a1, shifted);
  }

  static double distance(Landmark a, Landmark b) {
    final dx = a.x - b.x, dy = a.y - b.y;
    return math.sqrt(dx * dx + dy * dy);
  }
}
