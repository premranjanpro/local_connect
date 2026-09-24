import 'dart:math' as math;
import 'package:flutter/material.dart';

class DynamicVoiceWaveform extends StatefulWidget {
  final double audioLevel;
  final bool isSpeaking;
  final Color primaryColor;
  final double height;
  final int barCount;

  const DynamicVoiceWaveform({
    super.key,
    required this.audioLevel,
    required this.isSpeaking,
    this.primaryColor = const Color(0xFF10B981),
    this.height = 42.0,
    this.barCount = 11,
  });

  @override
  State<DynamicVoiceWaveform> createState() => _DynamicVoiceWaveformState();
}

class _DynamicVoiceWaveformState extends State<DynamicVoiceWaveform> with SingleTickerProviderStateMixin {
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _animController,
        builder: (context, _) {
          return CustomPaint(
            size: Size(widget.barCount * 12.0, widget.height),
            painter: _WaveformPainter(
              phase: _animController.value * 2 * math.pi,
              audioLevel: widget.audioLevel,
              isSpeaking: widget.isSpeaking,
              primaryColor: widget.primaryColor,
              barCount: widget.barCount,
            ),
          );
        },
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final double phase;
  final double audioLevel;
  final bool isSpeaking;
  final Color primaryColor;
  final int barCount;

  _WaveformPainter({
    required this.phase,
    required this.audioLevel,
    required this.isSpeaking,
    required this.primaryColor,
    required this.barCount,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const barWidth = 4.0;
    final totalSpacing = size.width - (barCount * barWidth);
    final gap = totalSpacing / (barCount - 1);
    final centerY = size.height / 2;

    const minBarHeight = 6.0;
    final maxBarHeight = size.height * 0.95;

    final baseAmp = isSpeaking ? math.max(0.3, audioLevel) : math.max(0.1, audioLevel * 0.5);

    for (int i = 0; i < barCount; i++) {
      final x = i * (barWidth + gap);
      final centerFactor = 1.0 - math.pow((i - (barCount - 1) / 2) / ((barCount - 1) / 2), 2).abs() * 0.5;
      final waveFactor = math.sin(phase + (i * 0.75)).abs();
      final targetHeight = minBarHeight + (maxBarHeight - minBarHeight) * baseAmp * centerFactor * (0.5 + 0.5 * waveFactor);

      final barRect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(x + barWidth / 2, centerY),
          width: barWidth,
          height: targetHeight.clamp(minBarHeight, maxBarHeight),
        ),
        const Radius.circular(2.0),
      );

      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            primaryColor.withValues(alpha: isSpeaking ? 0.95 : 0.45),
            Colors.white.withValues(alpha: isSpeaking ? 0.9 : 0.3),
            primaryColor.withValues(alpha: isSpeaking ? 0.85 : 0.35),
          ],
        ).createShader(barRect.outerRect);

      canvas.drawRRect(barRect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) {
    return oldDelegate.phase != phase ||
        oldDelegate.audioLevel != audioLevel ||
        oldDelegate.isSpeaking != isSpeaking;
  }
}
