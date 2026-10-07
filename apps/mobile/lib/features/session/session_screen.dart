import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nesta_core/nesta_core.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../services/frame_logger.dart';
import '../../services/heart_rate_source.dart';
import '../../services/pose_camera.dart';
import '../../services/voice_coach.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/exercise_figure.dart';
import '../../widgets/pose_overlay.dart';
import 'safety_screen.dart';
import 'session_controller.dart';
import 'symptom_checklist.dart';

/// Canlı egzersiz seansı: kamera + iskelet, sesli koç, sayaç ve nabız.
class SessionScreen extends StatefulWidget {
  const SessionScreen({
    super.key,
    required this.exercise,
    required this.preCheck,
    this.speakerOverride,
    this.heartRateOverride,
  });

  final Exercise exercise;
  final SymptomCheck preCheck;

  /// Testlerde gerçek cihaz servisleri yerine kullanılır.
  final Speaker? speakerOverride;
  final HeartRateSource? heartRateOverride;

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen>
    with WidgetsBindingObserver {
  SessionController? _controller;
  PoseCamera? _camera;
  StreamSubscription<PoseFrame>? _frameSub;
  PoseFrame? _lastFrame;
  Timer? _ticker;
  HeartRateSource? _hrSource;
  HeartRateAvailability? _hrAvailability;
  bool _cameraless = false;
  bool _navigated = false;
  FrameLogger? _logger;
  final Stopwatch _logClock = Stopwatch();

  AppState get _state => context.read<AppState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WakelockPlus.enable().catchError((_) {});
    _setup();
  }

  Future<void> _setup() async {
    final state = _state;
    final e = widget.exercise;

    // Nabız kaynağı: demo modunda simülasyon, gerçek modda saat verisi.
    final zone = state.heartRateZone;
    HeartRateSource? source;
    if (zone != null) {
      source =
          widget.heartRateOverride ??
          (state.repo.isDemo
              ? SimulatedHeartRateSource()
              : HealthHeartRateSource());
      _hrAvailability = await source.prepare();
      if (_hrAvailability != HeartRateAvailability.ready) source = null;
    }
    _hrSource = source;

    if (e.usesCamera) {
      final cam = PoseCamera(preferFront: state.settings.useFrontCamera);
      _camera = cam;
      cam.addListener(_onCameraChanged);
      await cam.initialize();
      if (state.settings.researchLogging && cam.failure == null) {
        _logger = await FrameLogger.start(e);
        _logClock.start();
      }
      _frameSub = cam.frames.listen((f) {
        _lastFrame = f;
        final c = _controller;
        c?.onPose(f.pose);
        if (c != null && c.phase == SessionPhase.active) {
          _logger?.add(
            tMs: _logClock.elapsedMilliseconds,
            imageWidth: f.imageSize.width,
            imageHeight: f.imageSize.height,
            pose: f.pose,
            feedback: c.feedback,
          );
        }
      });
    }
    if (!mounted) return;
    _startController(cameraless: e.usesCamera && _camera?.failure != null);
  }

  void _startController({required bool cameraless}) {
    final state = _state;
    final speaker =
        widget.speakerOverride ??
        VoiceCoach(enabled: state.settings.voiceEnabled);
    speaker.init(rate: state.settings.speechRate);
    final old = _controller;
    _controller = SessionController(
      exercise: widget.exercise,
      patientId: state.uid!,
      sessionId: state.repo.newId(),
      gestationalWeek: state.gestationalAge?.weeks ?? 0,
      speaker: speaker,
      heartRateSource: _hrSource,
      heartRateZone: _hrSource == null ? null : state.heartRateZone,
      talkTest: state.patient?.profile.takesBetaBlocker ?? false,
      preCheck: widget.preCheck,
      cameraless: cameraless,
    )..addListener(_onControllerChanged);
    old?.dispose();
    _cameraless = cameraless;
    _controller!.start();
    _ticker?.cancel();
    _ticker = Timer.periodic(
      const Duration(milliseconds: 250),
      (_) => _controller?.tick(),
    );
    setState(() {});
  }

  void _onCameraChanged() {
    if (mounted) setState(() {});
  }

  void _onControllerChanged() {
    final c = _controller!;
    if (c.isFinished && !_navigated) {
      _navigated = true;
      _ticker?.cancel();
      _handleFinish(c);
    }
  }

  Future<void> _handleFinish(SessionController c) async {
    final state = _state;
    final router = GoRouter.of(context);
    final session = c.buildSession();
    switch (c.endReason) {
      case SessionEndReason.heartRate:
        final bpm = c.heartRate.bpm ?? session.heartRate?.max ?? 0;
        await state.saveSession(session);
        await state.reportHeartRateStop(bpm, widget.exercise.name, session.id);
        router.pushReplacement(
          '/safety',
          extra: SafetyArgs(reason: SafetyReason.heartRate, bpm: bpm),
        );
      case SessionEndReason.symptom:
        // Belirtiler [_reportSymptom] içinde kaydedilir.
        break;
      default:
        router.pushReplacement('/session/summary', extra: session);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.paused || s == AppLifecycleState.inactive) {
      _controller?.pause();
      _camera?.pause();
    } else if (s == AppLifecycleState.resumed) {
      _camera?.resume();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    WakelockPlus.disable().catchError((_) {});
    _ticker?.cancel();
    _frameSub?.cancel();
    _logger?.close();
    _camera?.removeListener(_onCameraChanged);
    _camera?.dispose();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _confirmStop() async {
    final c = _controller!;
    c.pause();
    final stop = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Egzersizi bitir'),
        content: const Text(
          'Seansı şimdi bitirmek istiyor musunuz? '
          'Yaptığınız kısım kaydedilecek.',
        ),
        actions: [
          TextButton(
            onPressed: () => ctx.pop(false),
            child: const Text('Devam et'),
          ),
          FilledButton(
            onPressed: () => ctx.pop(true),
            child: const Text('Bitir'),
          ),
        ],
      ),
    );
    if (stop == true) {
      c.stopByUser();
    } else {
      c.resume();
    }
  }

  Future<void> _reportSymptom() async {
    final c = _controller!;
    c.pause();
    final selected = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _SymptomSheet(),
    );
    if (!mounted) return;
    if (selected == null) {
      c.resume();
      return;
    }
    final state = _state;
    final router = GoRouter.of(context);
    if (selected.isEmpty) {
      // Belirti yok, yalnızca yoruldu: seansı normal bitir.
      c.stopByUser();
      return;
    }
    _navigated = true;
    c.stopForSymptom();
    final check = SymptomCheck(
      present: selected,
      checkedAt: state.now().toUtc(),
    );
    final session = c.buildSession().copyWith(postCheck: check);
    await state.saveSession(session);
    await state.reportSymptoms(
      check,
      AlertType.symptomDuringSession,
      exerciseName: widget.exercise.name,
      sessionId: session.id,
    );
    router.pushReplacement(
      '/safety',
      extra: SafetyArgs(reason: SafetyReason.symptom, check: check),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    final e = widget.exercise;
    if (c == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmStop();
      },
      child: ListenableBuilder(
        listenable: c,
        builder: (context, _) {
          final dark = c.usesPoseTracking;
          return Scaffold(
            backgroundColor: dark ? Colors.black : NestaColors.background,
            body: Stack(
              children: [
                Positioned.fill(
                  child: c.usesPoseTracking ? _cameraView(c) : _guidedView(c),
                ),
                SafeArea(child: _topBar(c, dark)),
                if (c.phase == SessionPhase.preparing) _countdown(c),
                if (c.phase == SessionPhase.resting) _rest(c),
                if (c.isPaused) _paused(c),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: SafeArea(child: _bottomPanel(c, e)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _cameraView(SessionController c) {
    final cam = _camera!;
    final ctrl = cam.controller;
    if (!cam.isReady || ctrl == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
    final preview = ctrl.value.previewSize;
    final frame = _lastFrame;
    final aspect = preview == null ? 3 / 4 : preview.height / preview.width;
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: 1000 * aspect,
          height: 1000,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CameraPreview(ctrl),
              if (frame != null && _state.settings.showSkeleton)
                CustomPaint(
                  painter: PoseOverlayPainter(
                    pose: frame.pose,
                    imageSize: frame.imageSize,
                    mirrored: frame.mirrored,
                    correct: c.feedback?.isCorrect ?? true,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _guidedView(SessionController c) {
    final e = widget.exercise;
    final colors = NestaColors.forKey(e.colorKey);
    final step = c.currentGuidedStep;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 90, 24, 220),
        child: Column(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: colors.$2,
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(28),
                child: e.demoFrames.length >= 2
                    ? ExerciseFigure(exercise: e, color: colors.$1)
                    : AnimatedScale(
                        // Nefes alma ve kasılma adımlarında daire büyür.
                        scale:
                            step != null &&
                                (step.$1.cue.contains('nefes alın') ||
                                    step.$1.cue.startsWith('Kasın'))
                            ? 1.0
                            : 0.75,
                        duration: Duration(seconds: step?.$1.seconds ?? 1),
                        curve: Curves.easeInOut,
                        child: ExerciseFigure(exercise: e, color: colors.$1),
                      ),
              ),
            ),
            const SizedBox(height: 20),
            if (step != null) ...[
              Text(
                step.$1.cue,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(
                '${step.$2}',
                style: const TextStyle(
                  fontSize: 44,
                  fontWeight: FontWeight.w800,
                  color: NestaColors.primary,
                ),
              ),
            ] else if (_cameraless)
              const Text(
                'Kamera kullanılamıyor. Adımları sesli komutlarla takip edin.',
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
    );
  }

  Widget _topBar(SessionController c, bool dark) {
    final fg = dark ? Colors.white : NestaColors.ink;
    final e = widget.exercise;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Bitir',
                onPressed: _confirmStop,
                icon: Icon(Icons.close_rounded, color: fg),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      e.name,
                      style: TextStyle(
                        color: fg,
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                      ),
                    ),
                    Text(
                      'Set ${c.setIndex + 1}/${e.sets} · ${formatDuration(c.totalActiveSeconds)}',
                      style: TextStyle(color: fg.withValues(alpha: 0.8)),
                    ),
                  ],
                ),
              ),
              if (c.usesPoseTracking && (_camera?.isReady ?? false))
                IconButton(
                  tooltip: 'Kamerayı çevir',
                  onPressed: () => _camera!.switchCamera(),
                  icon: Icon(Icons.cameraswitch_outlined, color: fg),
                )
              else
                const SizedBox(width: 48),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              _heartChip(c),
              if (c.usesPoseTracking)
                for (final r in e.rules)
                  _ruleChip(
                    r,
                    c.feedback?.activeViolations.contains(r.id) ?? false,
                    c.feedback?.bodyVisible ?? false,
                  ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heartChip(SessionController c) {
    final hr = c.heartRate;
    final zone = c.heartRateZone;
    String text;
    Color color;
    if (zone == null) {
      text = _state.patient?.profile.takesBetaBlocker ?? false
          ? 'Konuşma testi'
          : _hrAvailability?.label ?? 'Nabız yok';
      color = NestaColors.inkSoft;
    } else if (hr.bpm == null || hr.status == HeartRateStatus.noData) {
      text = 'Nabız bekleniyor';
      color = NestaColors.inkSoft;
    } else {
      text = '${hr.bpm} atım/dk';
      color = switch (hr.status) {
        HeartRateStatus.critical => NestaColors.danger,
        HeartRateStatus.above => NestaColors.warning,
        HeartRateStatus.inZone => NestaColors.success,
        _ => NestaColors.sky,
      };
    }
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.favorite_rounded, size: 16, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: text,
                    style: TextStyle(fontWeight: FontWeight.w700, color: color),
                  ),
                  if (zone != null)
                    TextSpan(
                      text: '  hedef ${zone.low}–${zone.high}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: NestaColors.inkSoft,
                      ),
                    ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
    final sim = _hrSource;
    if (sim is SimulatedHeartRateSource) {
      return GestureDetector(
        onLongPress: () {
          sim.spike();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Demo: nabız yükseltiliyor (güvenlik uyarısını '
                'göstermek için).',
              ),
            ),
          );
        },
        child: chip,
      );
    }
    return chip;
  }

  Widget _ruleChip(PostureRule r, bool violated, bool visible) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: !visible
          ? Colors.white.withValues(alpha: 0.6)
          : violated
          ? NestaColors.peach
          : NestaColors.mint,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          violated ? Icons.error_outline_rounded : Icons.check_circle_outline,
          size: 16,
          color: NestaColors.ink,
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            r.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          ),
        ),
      ],
    ),
  );

  Widget _bottomPanel(SessionController c, Exercise e) {
    final f = c.feedback;
    final showVisibilityHint =
        c.usesPoseTracking &&
        c.phase == SessionPhase.active &&
        f != null &&
        !f.bodyVisible;
    final counter = e.mode == ExerciseMode.guided
        ? '${c.totalReps}'
        : (c.usesPoseTracking && e.countsReps)
        ? '${c.repsInSet}/${e.targetReps}'
        : formatDuration(c.setElapsedSeconds);
    final counterLabel = e.mode == ExerciseMode.guided
        ? 'tekrar'
        : (c.usesPoseTracking && e.countsReps)
        ? 'tekrar'
        : 'süre';
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [BoxShadow(blurRadius: 20, color: Colors.black26)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              SizedBox(
                width: 64,
                height: 64,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: c.setProgress,
                      strokeWidth: 6,
                      backgroundColor: NestaColors.mintSoft,
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          counter,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          counterLabel,
                          style: const TextStyle(
                            fontSize: 10,
                            color: NestaColors.inkSoft,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  showVisibilityHint
                      ? visibilityCue
                      : c.lastCue ?? 'Hazırlanın',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                    color:
                        (f != null && f.activeViolations.isNotEmpty) ||
                            showVisibilityHint
                        ? NestaColors.danger
                        : NestaColors.ink,
                  ),
                ),
              ),
            ],
          ),
          if (_camera?.failure != null && !_cameraless) ...[
            const SizedBox(height: 10),
            const InfoBanner.warning(text: 'Kamera açılamadı.'),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: c.isPaused ? c.resume : c.pause,
                  icon: Icon(
                    c.isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                  ),
                  label: Text(c.isPaused ? 'Devam' : 'Duraklat'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: _confirmStop,
                  child: const Text('Bitir'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: NestaColors.danger),
            onPressed: _reportSymptom,
            icon: const Icon(Icons.healing_outlined),
            label: const Text('Kendimi iyi hissetmiyorum'),
          ),
        ],
      ),
    );
  }

  Widget _overlayCard(Widget child) => Container(
    color: Colors.black45,
    alignment: Alignment.center,
    child: Container(
      margin: const EdgeInsets.all(32),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
      ),
      child: child,
    ),
  );

  Widget _countdown(SessionController c) => _overlayCard(
    Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Hazırlanın',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          '${c.prepareRemaining}',
          style: const TextStyle(
            fontSize: 64,
            fontWeight: FontWeight.w800,
            color: NestaColors.primary,
          ),
        ),
        if (c.usesPoseTracking)
          Text(
            widget.exercise.cameraView!.setupHint,
            textAlign: TextAlign.center,
            style: const TextStyle(color: NestaColors.inkSoft),
          ),
      ],
    ),
  );

  Widget _rest(SessionController c) => _overlayCard(
    Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.local_drink_outlined,
          size: 40,
          color: NestaColors.sky,
        ),
        const SizedBox(height: 8),
        const Text(
          'Dinlenme',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        Text(
          formatDuration(c.restRemainingSeconds),
          style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w800),
        ),
        Text('Sıradaki: Set ${c.setIndex + 1}/${widget.exercise.sets}'),
        const SizedBox(height: 12),
        TextButton(onPressed: c.skipRest, child: const Text('Dinlenmeyi atla')),
      ],
    ),
  );

  Widget _paused(SessionController c) => _overlayCard(
    Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.pause_circle_filled_rounded,
          size: 56,
          color: NestaColors.primary,
        ),
        const SizedBox(height: 8),
        const Text(
          'Duraklatıldı',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        FilledButton(onPressed: c.resume, child: const Text('DEVAM ET')),
      ],
    ),
  );
}

class _SymptomSheet extends StatefulWidget {
  @override
  State<_SymptomSheet> createState() => _SymptomSheetState();
}

class _SymptomSheetState extends State<_SymptomSheet> {
  Set<String> _selected = {};

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Ne hissediyorsunuz?',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          const Text(
            'Egzersiz durduruldu. Yaşadığınız belirtileri işaretleyin.',
            style: TextStyle(color: NestaColors.inkSoft),
          ),
          SymptomChecklist(
            selected: _selected,
            onChanged: (s) => setState(() => _selected = s),
          ),
          const SizedBox(height: 8),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: NestaColors.danger),
            onPressed: _selected.isEmpty
                ? null
                : () => Navigator.of(context).pop(_selected),
            child: const Text('BİLDİR VE DURDUR'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(<String>{}),
            child: const Text('Sadece yoruldum, bitir'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Vazgeç, devam et'),
          ),
        ],
      ),
    ),
  );
}
