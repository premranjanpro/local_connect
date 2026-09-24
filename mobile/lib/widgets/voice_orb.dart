import 'package:flutter/material.dart';

class VoiceOrb extends StatefulWidget {
  final double size;
  final bool isSpeaking;
  const VoiceOrb({super.key, required this.size, this.isSpeaking = false});

  @override
  State<VoiceOrb> createState() => _VoiceOrbState();
}

class _VoiceOrbState extends State<VoiceOrb> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, child) {
        final scale = 1.0 + (_controller.value * (widget.isSpeaking ? 0.18 : 0.08));
        return Transform.scale(
          scale: scale,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: widget.isSpeaking
                    ? [Colors.greenAccent, Colors.tealAccent, Colors.cyanAccent]
                    : [Colors.indigoAccent, Colors.purpleAccent, Colors.pinkAccent],
              ),
              boxShadow: [
                BoxShadow(
                  color: (widget.isSpeaking ? Colors.greenAccent : Colors.purpleAccent).withValues(alpha: 0.5),
                  blurRadius: 40,
                  spreadRadius: 6,
                )
              ],
            ),
            child: Icon(
              widget.isSpeaking ? Icons.record_voice_over_rounded : Icons.mic_rounded,
              size: widget.size * 0.4,
              color: Colors.white,
            ),
          ),
        );
      },
    );
  }
}
