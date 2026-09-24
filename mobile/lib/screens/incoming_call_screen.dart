import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../widgets/voice_orb.dart';
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

class _IncomingCallScreenState extends State<IncomingCallScreen> {
  Timer? _vibrationTimer;
  bool _isResponding = false;

  @override
  void initState() {
    super.initState();
    // Simulate periodic vibration feedback
    HapticFeedback.heavyImpact();
    _vibrationTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) {
      HapticFeedback.heavyImpact();
    });
  }

  @override
  void dispose() {
    _vibrationTimer?.cancel();
    super.dispose();
  }

  Future<void> _acceptCall() async {
    if (_isResponding) return;
    setState(() => _isResponding = true);
    _vibrationTimer?.cancel();
    await NotificationService.cancelCall();

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
    await NotificationService.cancelCall();

    if (widget.callerUserId != null) {
      try {
        await ApiService.respondCall(widget.callId, 'Decline', widget.callerUserId!);
      } catch (_) {}
    }

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Header
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.greenAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.phone_in_talk, color: Colors.greenAccent, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'INCOMING ${widget.callerRole.toUpperCase()} CALL',
                          style: const TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    widget.callerName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${widget.callerRole} • Order & Delivery Connect',
                    style: const TextStyle(color: Colors.blueGrey, fontSize: 14),
                  ),
                ],
              ),

              // Center Visual Orb
              const Column(
                children: [
                  VoiceOrb(size: 140, isSpeaking: false),
                  SizedBox(height: 16),
                  Text(
                    'Ringing...',
                    style: TextStyle(color: Colors.grey, fontSize: 14, letterSpacing: 0.5),
                  ),
                ],
              ),

              // Action Buttons: Decline (Red) and Accept (Green)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Decline
                  Column(
                    children: [
                      GestureDetector(
                        onTap: _declineCall,
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: Colors.redAccent.shade700,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: Colors.redAccent.withValues(alpha: 0.4), blurRadius: 20, spreadRadius: 4),
                            ],
                          ),
                          child: const Icon(Icons.call_end, color: Colors.white, size: 32),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text('Decline', style: TextStyle(color: Colors.grey, fontSize: 13)),
                    ],
                  ),

                  // Accept
                  Column(
                    children: [
                      GestureDetector(
                        onTap: _acceptCall,
                        child: Container(
                          width: 76,
                          height: 76,
                          decoration: BoxDecoration(
                            color: Colors.greenAccent.shade700,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: Colors.greenAccent.withValues(alpha: 0.5), blurRadius: 24, spreadRadius: 6),
                            ],
                          ),
                          child: const Icon(Icons.call, color: Colors.white, size: 36),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text('Accept', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
