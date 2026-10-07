import 'dart:async';
import 'dart:io' show Platform;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart'
    as mlkit;
import 'package:nesta_core/nesta_core.dart';

/// Kameradan alınan ve poz tahmini yapılan tek bir kare.
class PoseFrame {
  const PoseFrame({
    required this.pose,
    required this.imageSize,
    required this.mirrored,
    required this.tMs,
  });

  /// Karede kişi bulunamadıysa null.
  final Pose? pose;

  /// Eklem koordinatlarının ait olduğu (döndürülmüş) görüntü boyutu.
  final Size imageSize;

  /// Ön kamerada görüntü ayna gibi gösterildiği için çizimde x ekseni çevrilir.
  final bool mirrored;
  final int tMs;
}

enum CameraFailure { noCamera, permissionDenied, other }

/// Kamera görüntüsünü cihaz üzerinde ML Kit poz modeliyle işler.
///
/// Görüntüler hiçbir yere kaydedilmez veya gönderilmez; yalnızca eklem
/// koordinatları uygulamaya aktarılır.
class PoseCamera extends ChangeNotifier {
  PoseCamera({this.preferFront = true});

  final bool preferFront;
  CameraController? controller;
  CameraDescription? _camera;
  CameraFailure? failure;
  bool _busy = false;
  bool _disposed = false;
  final Stopwatch _clock = Stopwatch();
  final mlkit.PoseDetector _detector = mlkit.PoseDetector(
    options: mlkit.PoseDetectorOptions(
      model: mlkit.PoseDetectionModel.base,
      mode: mlkit.PoseDetectionMode.stream,
    ),
  );

  final _frames = StreamController<PoseFrame>.broadcast();
  Stream<PoseFrame> get frames => _frames.stream;

  bool get isReady => controller?.value.isInitialized ?? false;
  bool get isFront => _camera?.lensDirection == CameraLensDirection.front;

  static const _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  Future<void> initialize({bool? front}) async {
    failure = null;
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        failure = CameraFailure.noCamera;
        notifyListeners();
        return;
      }
      final wantFront = front ?? preferFront;
      _camera = cameras.firstWhere(
        (c) =>
            c.lensDirection ==
            (wantFront ? CameraLensDirection.front : CameraLensDirection.back),
        orElse: () => cameras.first,
      );
      final old = controller;
      controller = null;
      await old?.dispose();
      final c = CameraController(
        _camera!,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );
      await c.initialize();
      if (_disposed) {
        await c.dispose();
        return;
      }
      controller = c;
      _clock
        ..reset()
        ..start();
      await c.startImageStream(_onImage);
    } on CameraException catch (e) {
      failure = e.code.contains('Access') || e.code.contains('ermission')
          ? CameraFailure.permissionDenied
          : CameraFailure.other;
    } catch (_) {
      failure = CameraFailure.other;
    }
    if (!_disposed) notifyListeners();
  }

  Future<void> switchCamera() => initialize(front: !isFront);

  Future<void> _onImage(CameraImage image) async {
    if (_busy || _disposed) return;
    _busy = true;
    try {
      final input = _toInputImage(image);
      if (input == null) return;
      final poses = await _detector.processImage(input);
      if (_disposed) return;
      final rotation = input.metadata!.rotation;
      final rotated =
          rotation == mlkit.InputImageRotation.rotation90deg ||
          rotation == mlkit.InputImageRotation.rotation270deg;
      _frames.add(
        PoseFrame(
          pose: poses.isEmpty ? null : _convert(poses.first),
          imageSize: rotated
              ? Size(image.height.toDouble(), image.width.toDouble())
              : Size(image.width.toDouble(), image.height.toDouble()),
          mirrored: isFront,
          tMs: _clock.elapsedMilliseconds,
        ),
      );
    } catch (_) {
      // Tek bir karenin işlenememesi seansı etkilemez.
    } finally {
      _busy = false;
    }
  }

  static Pose _convert(mlkit.Pose p) => Pose({
    for (final e in p.landmarks.entries)
      Joint.values.byName(e.key.name): Landmark(
        e.value.x,
        e.value.y,
        likelihood: e.value.likelihood,
      ),
  });

  mlkit.InputImage? _toInputImage(CameraImage image) {
    final camera = _camera, c = controller;
    if (camera == null || c == null) return null;
    final sensor = camera.sensorOrientation;
    mlkit.InputImageRotation? rotation;
    if (Platform.isIOS) {
      rotation = mlkit.InputImageRotationValue.fromRawValue(sensor);
    } else {
      final device = _orientations[c.value.deviceOrientation] ?? 0;
      final comp = camera.lensDirection == CameraLensDirection.front
          ? (sensor + device) % 360
          : (sensor - device + 360) % 360;
      rotation = mlkit.InputImageRotationValue.fromRawValue(comp);
    }
    if (rotation == null) return null;
    final format = mlkit.InputImageFormatValue.fromRawValue(
      image.format.raw as int,
    );
    if (format == null ||
        (Platform.isAndroid && format != mlkit.InputImageFormat.nv21) ||
        (Platform.isIOS && format != mlkit.InputImageFormat.bgra8888)) {
      return null;
    }
    if (image.planes.length != 1) return null;
    final plane = image.planes.first;
    return mlkit.InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: mlkit.InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  Future<void> pause() async {
    final c = controller;
    if (c != null && c.value.isStreamingImages) await c.stopImageStream();
  }

  Future<void> resume() async {
    final c = controller;
    if (c != null && c.value.isInitialized && !c.value.isStreamingImages) {
      await c.startImageStream(_onImage);
    }
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    final c = controller;
    controller = null;
    try {
      if (c != null && c.value.isStreamingImages) await c.stopImageStream();
    } catch (_) {}
    await c?.dispose();
    await _detector.close();
    await _frames.close();
    super.dispose();
  }
}
