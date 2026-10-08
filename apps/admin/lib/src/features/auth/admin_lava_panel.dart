import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../core/theme/theme.dart';
import '../../core/widgets/admin_wordmark.dart';

const String kPristupNapomena =
    'Pristup imaju samo vlasnik i majstori lokacije.';

/// Shared desktop backdrop and mobile header for staff authentication.
class AdminLavaPanel extends StatelessWidget {
  const AdminLavaPanel({this.hero = false, super.key});

  final bool hero;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [colors.sidebarRaised, colors.sidebarBackground],
        ),
      ),
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            const IgnorePointer(
              child: RepaintBoundary(child: _LavaAnimation()),
            ),
            // Keep the wordmark and access note readable over passing bubbles.
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.center,
                  end: Alignment.bottomCenter,
                  colors: [
                    colors.sidebarBackground.withValues(alpha: 0),
                    colors.sidebarBackground.withValues(alpha: 0.8),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(hero ? AdminSpacing.xl : 48),
              child: Align(
                alignment: Alignment.bottomLeft,
                child: hero
                    ? const AdminWordmark(
                        naTamnom: true,
                        potpis: true,
                        velicinaZnaka: 36,
                      )
                    : Text(
                        kPristupNapomena,
                        style: Theme.of(context).textTheme.bodyLarge
                            ?.copyWith(color: colors.sidebarText, height: 1.6),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LavaAnimation extends StatefulWidget {
  const _LavaAnimation();

  @override
  State<_LavaAnimation> createState() => _LavaAnimationState();
}

class _LavaAnimationState extends State<_LavaAnimation>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static final _program = ui.FragmentProgram.fromAsset(
    'shaders/admin_lava.frag',
  );
  final _motion = _LavaMotion();
  late final Ticker _ticker;
  ui.FragmentShader? _shader;
  Duration? _previous;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ticker = createTicker((elapsed) {
      final previous = _previous;
      _previous = elapsed;
      if (previous != null) {
        _motion.advance(
          math.min((elapsed - previous).inMicroseconds / 1e6, 0.05),
        );
      }
    });
    _load();
  }

  Future<void> _load() async {
    try {
      final program = await _program;
      if (!mounted) return;
      setState(() => _shader = program.fragmentShader());
      _updateTicker();
    } catch (_) {
      // Unsupported renderers retain a static, painted composition.
    }
  }

  void _updateTicker() {
    final animate =
        _shader != null &&
        _foreground &&
        !MediaQuery.disableAnimationsOf(context) &&
        TickerMode.valuesOf(context).enabled;
    if (animate && !_ticker.isActive) {
      _previous = null;
      _ticker.start();
    } else if (!animate && _ticker.isActive) {
      _ticker.stop();
      _previous = null;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateTicker();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _updateTicker();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    _shader?.dispose();
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _LavaPainter(
      motion: _motion,
      shader: _shader,
      coral: context.adminColors.action,
      blue: context.adminColors.accent,
    ),
  );
}

class _Bubble {
  _Bubble(this.random, {bool initial = false}) {
    renew();
    if (initial) progress = random.nextDouble();
  }

  final math.Random random;
  late double x, radius, duration, phase, sway, direction, blue;
  double progress = 0;

  void renew() {
    progress = 0;
    x = 0.12 + random.nextDouble() * 0.76;
    radius = 0.075 + random.nextDouble() * 0.095;
    duration = 28 + random.nextDouble() * 32;
    phase = random.nextDouble() * math.pi * 2;
    sway = 0.04 + random.nextDouble() * 0.13;
    direction = random.nextDouble() < 0.25 ? -1 : 1;
    blue = random.nextBool() ? 1 : 0;
  }

  // Zero influence at either end makes random respawning visually continuous.
  double get visibleRadius {
    final entrance = (progress / 0.12).clamp(0.0, 1.0);
    final exit = ((1 - progress) / 0.12).clamp(0.0, 1.0);
    double smooth(double t) => t * t * (3 - 2 * t);
    return radius *
        smooth(entrance) *
        smooth(exit) *
        (1 + 0.12 * math.sin(progress * math.pi * 4 + phase));
  }

  Offset position(Size size) {
    final scale = math.min(size.width, size.height);
    final y = direction > 0 ? 1 - progress : progress;
    return Offset(
      (x + math.sin(progress * math.pi * 2 + phase) * sway) *
          size.width /
          scale,
      (y * (size.height / scale + radius * 4) - radius * 2),
    );
  }
}

class _LavaMotion extends ChangeNotifier {
  _LavaMotion() {
    final random = math.Random();
    bubbles = List.generate(12, (_) => _Bubble(random, initial: true));
  }
  late final List<_Bubble> bubbles;

  void advance(double seconds) {
    for (final bubble in bubbles) {
      bubble.progress += seconds / bubble.duration;
      if (bubble.progress >= 1) bubble.renew();
    }
    notifyListeners();
  }
}

class _LavaPainter extends CustomPainter {
  _LavaPainter({
    required this.motion,
    required this.shader,
    required this.coral,
    required this.blue,
  }) : super(repaint: motion);

  final _LavaMotion motion;
  final ui.FragmentShader? shader;
  final Color coral, blue;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final effect = shader;
    if (effect == null) {
      final scale = math.min(size.width, size.height);
      for (final bubble in motion.bubbles) {
        canvas.drawCircle(
          bubble.position(size) * scale,
          bubble.visibleRadius * scale,
          Paint()
            ..color = (bubble.blue == 1 ? blue : coral).withValues(alpha: 0.65)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
        );
      }
      return;
    }
    effect.setFloat(0, size.width);
    effect.setFloat(1, size.height);
    for (final (index, value) in [
      coral.r,
      coral.g,
      coral.b,
      blue.r,
      blue.g,
      blue.b,
    ].indexed) {
      effect.setFloat(index + 2, value);
    }
    for (final (index, bubble) in motion.bubbles.indexed) {
      final position = bubble.position(size);
      final offset = 8 + index * 4;
      effect.setFloat(offset, position.dx);
      effect.setFloat(offset + 1, position.dy);
      effect.setFloat(offset + 2, bubble.visibleRadius);
      effect.setFloat(offset + 3, bubble.blue);
    }
    canvas.drawRect(Offset.zero & size, Paint()..shader = effect);
  }

  @override
  bool shouldRepaint(_LavaPainter oldDelegate) =>
      oldDelegate.shader != shader ||
      oldDelegate.coral != coral ||
      oldDelegate.blue != blue ||
      oldDelegate.motion != motion;
}
