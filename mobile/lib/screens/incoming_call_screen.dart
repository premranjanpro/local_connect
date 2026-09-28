import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import 'calling_screen.dart';

class IncomingCallScreen extends StatefulWidget {
  final String callId;
  final String callerName;
  final String callerRole;
  final String? callerUserId;
  final String? liveKitUrl;
  final String? calleeToken;

  const IncomingCallScreen({
    super.key,
    required this.callId,
    required this.callerName,
    required this.callerRole,
    this.callerUserId,
    this.liveKitUrl,
    this.calleeToken,
  });

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen>
    with TickerProviderStateMixin {
  Timer? _vibrationTimer;
  Timer? _dotTimer;
  bool _isResponding = false;

  // Animated ring controllers
  late AnimationController _ring1Controller;
  late AnimationController _ring2Controller;
  late AnimationController _ring3Controller;
  late AnimationController _avatarGlowController;
  late AnimationController _slideUpController;

  // Dots animation for "Ringing..."
  int _dotCount = 0;

  // Avatar bounce
  late AnimationController _avatarBounceController;
  late Animation<double> _avatarBounce;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _startVibration();
    _startDotAnimation();
  }

  void _initAnimations() {
    // 3 cascading ripple rings
    _ring1Controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();

    _ring2Controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _ring2Controller.repeat();
    });

    _ring3Controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) _ring3Controller.repeat();
    });

    // Avatar glow pulse
    _avatarGlowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    // Avatar bounce (phone shake effect)
    _avatarBounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _avatarBounce = Tween<double>(begin: -4, end: 4).animate(
      CurvedAnimation(parent: _avatarBounceController, curve: Curves.elasticIn),
    );
    _startAvatarShake();

    // Bottom buttons slide up
    _slideUpController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _slideUpController.forward();
  }

  void _startAvatarShake() {
    Timer.periodic(const Duration(milliseconds: 1500), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      _avatarBounceController
          .forward()
          .then((_) => _avatarBounceController.reverse());
    });
  }

  void _startVibration() {
    HapticFeedback.heavyImpact();
    _vibrationTimer = Timer.periodic(const Duration(milliseconds: 1600), (_) {
      if (mounted) HapticFeedback.heavyImpact();
    });
  }

  void _startDotAnimation() {
    _dotTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) {
        setState(() {
          _dotCount = (_dotCount + 1) % 4;
        });
      }
    });
  }

  @override
  void dispose() {
    _vibrationTimer?.cancel();
    _dotTimer?.cancel();
    _ring1Controller.dispose();
    _ring2Controller.dispose();
    _ring3Controller.dispose();
    _avatarGlowController.dispose();
    _avatarBounceController.dispose();
    _slideUpController.dispose();
    super.dispose();
  }

  Future<void> _acceptCall() async {
    if (_isResponding) return;
    setState(() => _isResponding = true);
    _vibrationTimer?.cancel();
    _dotTimer?.cancel();
    await NotificationService.cancelCall();
    HapticFeedback.mediumImpact();

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => CallingScreen(
            callId: widget.callId,
            partnerName: widget.callerName,
            partnerRole: widget.callerRole,
            isIncoming: true,
            liveKitUrl: widget.liveKitUrl ?? 'ws://127.0.0.1:7880',
            roomToken: widget.calleeToken ?? '',
          ),
        ),
      );
    }
  }

  Future<void> _declineCall() async {
    if (_isResponding) return;
    setState(() => _isResponding = true);
    _vibrationTimer?.cancel();
    _dotTimer?.cancel();
    await NotificationService.cancelCall();
    HapticFeedback.heavyImpact();

    if (widget.callerUserId != null) {
      try {
        await ApiService.respondCall(widget.callId, 'Decline', widget.callerUserId!);
      } catch (_) {}
    }

    if (mounted) {
      Navigator.pop(context);
    }
  }

  String get _callerInitials {
    final parts = widget.callerName.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return widget.callerName.isNotEmpty
        ? widget.callerName[0].toUpperCase()
        : '?';
  }

  String get _ringingText => 'Ringing${'.' * _dotCount}';

  Widget _buildRippleRing(AnimationController controller, Color color) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        final scale = 1.0 + controller.value * 1.4;
        final opacity = (1.0 - controller.value).clamp(0.0, 1.0);
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: color.withValues(alpha: opacity * 0.6),
                width: 2,
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        width: screenSize.width,
        height: screenSize.height,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0A0E1A),
              Color(0xFF0F1B30),
              Color(0xFF071523),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ── Top Section: Status Badge ──────────────────
              const SizedBox(height: 32),
              _buildStatusBadge(),

              // ── Caller Name & Role ─────────────────────────
              const SizedBox(height: 20),
              Text(
                widget.callerName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  widget.callerRole,
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

              // ── Center: Avatar with Ripple Rings ──────────
              const Spacer(),
              SizedBox(
                width: 300,
                height: 300,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // 3 cascading rings
                    _buildRippleRing(_ring3Controller, Colors.greenAccent),
                    _buildRippleRing(_ring2Controller, Colors.tealAccent),
                    _buildRippleRing(_ring1Controller, Colors.cyanAccent),

                    // Avatar with animated glow
                    AnimatedBuilder(
                      animation: _avatarGlowController,
                      builder: (_, __) {
                        return AnimatedBuilder(
                          animation: _avatarBounce,
                          builder: (_, __) => Transform.translate(
                            offset: Offset(_avatarBounce.value, 0),
                            child: Container(
                              width: 140,
                              height: 140,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFF00C853),
                                    Color(0xFF1DE9B6),
                                    Color(0xFF00BFA5),
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.greenAccent.withValues(
                                        alpha: 0.25 + _avatarGlowController.value * 0.35),
                                    blurRadius: 30 + _avatarGlowController.value * 20,
                                    spreadRadius: 4 + _avatarGlowController.value * 6,
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  _callerInitials,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 52,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                    // Phone icon on top right of avatar
                    Positioned(
                      top: 70,
                      right: 70,
                      child: AnimatedBuilder(
                        animation: _avatarGlowController,
                        builder: (_, __) => Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.greenAccent.withValues(alpha: 0.5),
                                blurRadius: 8 + _avatarGlowController.value * 8,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.phone_in_talk,
                            color: Color(0xFF00C853),
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Ringing Text ───────────────────────────────
              const SizedBox(height: 16),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Text(
                  _ringingText,
                  key: ValueKey(_ringingText),
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 15,
                    letterSpacing: 0.5,
                  ),
                ),
              ),

              const Spacer(),

              // ── Bottom: Action Buttons ─────────────────────
              SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 2),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: _slideUpController,
                  curve: Curves.easeOutCubic,
                )),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(40, 0, 40, 40),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // ── Decline ──
                      Column(
                        children: [
                          GestureDetector(
                            onTap: _isResponding ? null : _declineCall,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E1E2E),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.redAccent.withValues(alpha: 0.6),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.redAccent.withValues(alpha: 0.25),
                                    blurRadius: 20,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.call_end,
                                color: Colors.redAccent,
                                size: 32,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Decline',
                            style: TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                        ],
                      ),

                      // ── Accept (animated pulsing) ──
                      Column(
                        children: [
                          AnimatedBuilder(
                            animation: _avatarGlowController,
                            builder: (_, __) => GestureDetector(
                              onTap: _isResponding ? null : _acceptCall,
                              child: Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [Color(0xFF00C853), Color(0xFF1DE9B6)],
                                  ),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.greenAccent.withValues(
                                          alpha: 0.35 + _avatarGlowController.value * 0.35),
                                      blurRadius: 24 + _avatarGlowController.value * 16,
                                      spreadRadius: 2 + _avatarGlowController.value * 4,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.call,
                                  color: Colors.white,
                                  size: 36,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Accept',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge() {
    return AnimatedBuilder(
      animation: _avatarGlowController,
      builder: (_, __) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.greenAccent.withValues(alpha: 0.1 + _avatarGlowController.value * 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.greenAccent.withValues(alpha: 0.3 + _avatarGlowController.value * 0.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: Colors.greenAccent.withValues(
                    alpha: 0.6 + _avatarGlowController.value * 0.4),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'INCOMING ${widget.callerRole.toUpperCase()} CALL',
              style: const TextStyle(
                color: Colors.greenAccent,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
