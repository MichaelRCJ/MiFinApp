import 'dart:math';
import 'package:flutter/material.dart';

class ParticleBackground extends StatefulWidget {
  final int particleCount;
  final Color? color;
  const ParticleBackground({super.key, this.particleCount = 36, this.color});

  @override
  State<ParticleBackground> createState() => _ParticleBackgroundState();
}

class _ParticleBackgroundState extends State<ParticleBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_Particle> _particles;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 12))
      ..repeat();
    _particles = List.generate(widget.particleCount, (_) => _randomParticle());
  }

  _Particle _randomParticle() {
    final speed = 5 + _random.nextDouble() * 20;
    final size = 1.5 + _random.nextDouble() * 2.5;
    return _Particle(
      offset: Offset(_random.nextDouble(), _random.nextDouble()),
      direction: _random.nextDouble() * 2 * pi,
      speed: speed,
      size: size,
      opacity: .25 + _random.nextDouble() * .35,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _ParticlePainter(
              particles: _particles,
              time: _controller.value,
              color: widget.color ?? Theme.of(context).colorScheme.primary,
              onRecycle: (p) {
                // softly respawn near the top when out of bounds
                p
                  ..offset = Offset(_random.nextDouble(), -0.1)
                  ..direction = pi / 2 + (_random.nextDouble() * .6 - .3)
                  ..speed = 10 + _random.nextDouble() * 20
                  ..size = 1.5 + _random.nextDouble() * 2.5
                  ..opacity = .25 + _random.nextDouble() * .35;
              },
            ),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double time; // 0..1 loop
  final Color color;
  final void Function(_Particle) onRecycle;

  _ParticlePainter({required this.particles, required this.time, required this.color, required this.onRecycle});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    for (final p in particles) {
      // update
      final velocity = Offset(cos(p.direction), sin(p.direction)) * (p.speed / 6000.0);
      p.offset += velocity;
      if (p.offset.dx < -0.1 || p.offset.dx > 1.1 || p.offset.dy < -0.1 || p.offset.dy > 1.1) {
        onRecycle(p);
      }

      final center = Offset(p.offset.dx * size.width, p.offset.dy * size.height);
      paint.color = color.withValues(alpha: p.opacity);
      canvas.drawCircle(center, p.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) => true;
}

class _Particle {
  Offset offset;
  double direction;
  double speed;
  double size;
  double opacity;

  _Particle({required this.offset, required this.direction, required this.speed, required this.size, required this.opacity});
}
