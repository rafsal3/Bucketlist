import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:lottie/lottie.dart';

class ProgressRing extends StatefulWidget {
  final double progress;
  final double size;

  const ProgressRing({
    super.key,
    required this.progress,
    required this.size,
  });

  @override
  State<ProgressRing> createState() => _ProgressRingState();
}

class _ProgressRingState extends State<ProgressRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  bool _showWink = false;
  bool _hasShownWink = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: widget.progress).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    _animationController.forward();
  }

  @override
  void didUpdateWidget(ProgressRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress != widget.progress) {
      _animation = Tween<double>(
        begin: _animation.value,
        end: widget.progress,
      ).animate(
        CurvedAnimation(
          parent: _animationController,
          curve: Curves.easeInOut,
        ),
      );
      _animationController.forward(from: 0);

      // Check if we just hit 100% and haven't shown the wink yet
      if (widget.progress >= 1.0 &&
          oldWidget.progress < 1.0 &&
          !_hasShownWink) {
        _showWinkAnimation();
      }

      // Reset the wink flag if progress goes below 100%
      if (widget.progress < 1.0) {
        _hasShownWink = false;
      }
    }
  }

  void _showWinkAnimation() {
    setState(() {
      _showWink = true;
      _hasShownWink = true;
    });

    // Hide the wink after 2 seconds
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted) {
        setState(() {
          _showWink = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            children: [
              // Background circle
              CustomPaint(
                size: Size(widget.size, widget.size),
                painter: _RingPainter(
                  progress: 1.0,
                  color: Theme.of(context)
                      .colorScheme
                      .primaryContainer
                      .withOpacity(0.3),
                  strokeWidth: 8,
                ),
              ),
              // Progress circle
              CustomPaint(
                size: Size(widget.size, widget.size),
                painter: _RingPainter(
                  progress: _animation.value,
                  color: Theme.of(context).colorScheme.primary,
                  strokeWidth: 8,
                ),
              ),
              // Center content - either wink animation or percentage text
              Center(
                child: _showWink
                    ? SizedBox(
                        width: widget.size * 0.6,
                        height: widget.size * 0.6,
                        child: Lottie.asset(
                          'assets/images/Wink.json',
                          fit: BoxFit.contain,
                          repeat: false,
                        ),
                      )
                    : Text(
                        '${(_animation.value * 100).toInt()}%',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  _RingPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
