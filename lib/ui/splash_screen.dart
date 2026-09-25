import 'dart:math';
import 'package:flutter/material.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late AnimationController _fadeCtrl;
  late Animation<double> _pulseAnim;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600))
      ..repeat(reverse: true);

    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));

    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _fadeAnim = Tween<double>(begin: 1.0, end: 0.0).animate(
        CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn));

    _scaleAnim = Tween<double>(begin: 1.0, end: 1.15).animate(
        CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn));

    // Navigate after 2.4 seconds
    Future.delayed(const Duration(milliseconds: 2400), () {
      if (mounted) {
        _fadeCtrl.forward().then((_) {
          if (mounted) {
            Navigator.of(context).pushReplacement(
              PageRouteBuilder(
                transitionDuration: Duration.zero,
                pageBuilder: (_, __, ___) => const HomeScreen(),
              ),
            );
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_pulseAnim, _fadeAnim]),
      builder: (context, _) {
        return Opacity(
          opacity: _fadeAnim.value,
          child: Transform.scale(
            scale: _scaleAnim.value,
            child: Scaffold(
              backgroundColor: const Color(0xFF080C14),
              body: Stack(
                children: [
                  // Background glow
                  Center(
                    child: Container(
                      width: 300 * _pulseAnim.value,
                      height: 300 * _pulseAnim.value,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFFF59E0B).withOpacity(0.15 * _pulseAnim.value),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Solar ring icon
                        SizedBox(
                          width: 130,
                          height: 130,
                          child: CustomPaint(
                            painter: _SolarRingPainter(_pulseAnim.value),
                            child: const Center(
                              child: Icon(
                                Icons.bolt_rounded,
                                size: 52,
                                color: Color(0xFFF59E0B),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        const Text(
                          'SOLAR INVERTER',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 4,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Monitor',
                          style: TextStyle(
                            fontSize: 13,
                            letterSpacing: 2.5,
                            color: const Color(0xFFF59E0B).withOpacity(0.9),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 48),
                        SizedBox(
                          width: 120,
                          child: LinearProgressIndicator(
                            backgroundColor: Colors.white12,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                                Color(0xFFF59E0B)),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SolarRingPainter extends CustomPainter {
  final double pulse;
  _SolarRingPainter(this.pulse);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    // Outer arc — amber
    paint.color = const Color(0xFFF59E0B).withOpacity(0.9 * pulse);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
        -pi / 2, pi * 1.6, false, paint);

    // Inner arc — green
    paint.color = const Color(0xFF10B981).withOpacity(0.7 * pulse);
    paint.strokeWidth = 2;
    canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius * 0.75),
        pi / 4,
        pi * 1.3,
        false,
        paint);
  }

  @override
  bool shouldRepaint(_SolarRingPainter old) => old.pulse != pulse;
}
