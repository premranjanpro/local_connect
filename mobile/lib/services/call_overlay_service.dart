import 'dart:async';
import 'package:flutter/material.dart';
import '../screens/incoming_call_screen.dart';

/// Global foreground call overlay service.
/// Jab app foreground mein ho aur call aaye toh ek full-screen
/// animated overlay dikhata hai — bina kisi notification tap ke.
class CallOverlayService {
  static OverlayEntry? _overlayEntry;
  static Timer? _autoDeclineTimer;

  /// Show a full-screen incoming call overlay on top of any screen.
  static void showIncomingCallOverlay({
    required BuildContext context,
    required String callId,
    required String callerName,
    required String callerRole,
    String? callerUserId,
    String? liveKitUrl,
    String? calleeToken,
  }) {
    // Dismiss any existing overlay first
    dismissOverlay();

    _overlayEntry = OverlayEntry(
      builder: (_) => _IncomingCallOverlay(
        callId: callId,
        callerName: callerName,
        callerRole: callerRole,
        callerUserId: callerUserId,
        liveKitUrl: liveKitUrl,
        calleeToken: calleeToken,
        onDismiss: dismissOverlay,
      ),
    );

    Overlay.of(context, rootOverlay: true).insert(_overlayEntry!);

    // Auto-dismiss after 45 seconds if not answered
    _autoDeclineTimer = Timer(const Duration(seconds: 45), () {
      dismissOverlay();
    });
  }

  static void dismissOverlay() {
    _autoDeclineTimer?.cancel();
    _overlayEntry?.remove();
    _overlayEntry = null;
  }
}

/// Full-screen animated incoming call overlay widget.
class _IncomingCallOverlay extends StatefulWidget {
  final String callId;
  final String callerName;
  final String callerRole;
  final String? callerUserId;
  final String? liveKitUrl;
  final String? calleeToken;
  final VoidCallback onDismiss;

  const _IncomingCallOverlay({
    required this.callId,
    required this.callerName,
    required this.callerRole,
    this.callerUserId,
    this.liveKitUrl,
    this.calleeToken,
    required this.onDismiss,
  });

  @override
  State<_IncomingCallOverlay> createState() => _IncomingCallOverlayState();
}

class _IncomingCallOverlayState extends State<_IncomingCallOverlay>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _pulseController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutBack,
    ));

    _fadeAnimation = CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeIn,
    );

    _slideController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _acceptCall() async {
    widget.onDismiss();
    if (mounted) {
      Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(
          builder: (_) => IncomingCallScreen(
            callId: widget.callId,
            callerName: widget.callerName,
            callerRole: widget.callerRole,
            callerUserId: widget.callerUserId,
            liveKitUrl: widget.liveKitUrl,
            calleeToken: widget.calleeToken,
          ),
        ),
      );
    }
  }

  void _declineCall() {
    widget.onDismiss();
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

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 48, 12, 0),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A), Color(0xFF16213E), Color(0xFF0F3460)],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.greenAccent.withValues(alpha: 0.35),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.greenAccent.withValues(alpha: 0.2),
                      blurRadius: 32,
                      spreadRadius: 2,
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.6),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      // Animated Avatar
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (_, child) {
                          final glow = _pulseController.value;
                          return Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF10B981), Color(0xFF1DE9B6)],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.greenAccent.withValues(alpha: 0.3 + glow * 0.4),
                                  blurRadius: 12 + glow * 12,
                                  spreadRadius: glow * 4,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                _callerInitials,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 12),

                      // Caller Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                AnimatedBuilder(
                                  animation: _pulseController,
                                  builder: (_, __) => Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: Colors.greenAccent.withValues(
                                          alpha: 0.5 + _pulseController.value * 0.5),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  'INCOMING CALL',
                                  style: TextStyle(
                                    color: Colors.greenAccent,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.callerName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              widget.callerRole,
                              style: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 12),

                      // Decline Button
                      GestureDetector(
                        onTap: _declineCall,
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.redAccent.withValues(alpha: 0.5),
                            ),
                          ),
                          child: const Icon(Icons.call_end, color: Colors.redAccent, size: 20),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Accept Button (animated)
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (_, child) => GestureDetector(
                          onTap: _acceptCall,
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981), Color(0xFF1DE9B6)],
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.greenAccent.withValues(
                                      alpha: 0.3 + _pulseController.value * 0.3),
                                  blurRadius: 8 + _pulseController.value * 8,
                                  spreadRadius: _pulseController.value * 2,
                                ),
                              ],
                            ),
                            child: const Icon(Icons.call, color: Colors.white, size: 22),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
