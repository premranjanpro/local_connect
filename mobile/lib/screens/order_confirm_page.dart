import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../screens/home_screen.dart';
import '../services/audio_tone_service.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  Order Confirm Page — Success + Live Tracking
// ══════════════════════════════════════════════════════════════════════════════

class OrderConfirmPage extends StatefulWidget {
  final Map<String, dynamic> order;
  const OrderConfirmPage({super.key, required this.order});

  @override
  State<OrderConfirmPage> createState() => _OrderConfirmPageState();
}

class _OrderConfirmPageState extends State<OrderConfirmPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _fade;

  // Mock driver location
  LatLng _driverLoc = const LatLng(26.9160, 75.7900);
  LatLng _dropLoc = const LatLng(26.9124, 75.7873);

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _ctrl.forward();
    AudioToneService.playOrderCreatedTone();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final orderId = widget.order['id']?.toString() ?? 'ORD-XXXX';
    final shopName = widget.order['businessName']?.toString() ?? 'Shop';
    final total =
        (widget.order['totalAmount'] as num?)?.toStringAsFixed(0) ?? '0';
    final payment = widget.order['paymentMode']?.toString() ?? 'Cash';
    final status = widget.order['status']?.toString() ?? 'Pending';

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF060B18) : const Color(0xFFF1F5F9),
      body: Column(
        children: [
          // ── Success header ────────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 60, 20, 28),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF059669), Color(0xFF10B981)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              children: [
                // Animated checkmark
                ScaleTransition(
                  scale: _scale,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(Icons.check_rounded,
                        color: Colors.white, size: 38),
                  ),
                ),
                const SizedBox(height: 14),
                FadeTransition(
                  opacity: _fade,
                  child: Column(
                    children: [
                      const Text('Order Placed!',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 24)),
                      const SizedBox(height: 4),
                      Text('$shopName will prepare your order soon',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Order summary card
                  _infoCard(isDark, [
                    _infoRow('Order ID', orderId, isDark),
                    _infoRow('Status', status, isDark,
                        valueColor: const Color(0xFFF59E0B)),
                    _infoRow('Shop', shopName, isDark),
                    _infoRow('Amount', '₹$total', isDark,
                        valueColor: const Color(0xFF10B981)),
                    _infoRow('Payment', payment, isDark),
                    _infoRow(
                        'Address',
                        widget.order['deliveryAddress']?.toString() ??
                            'Your location',
                        isDark),
                  ]),

                  const SizedBox(height: 16),

                  // Status tracker
                  _buildStatusTracker(isDark),

                  const SizedBox(height: 16),

                  // Mini map
                  _buildMiniMap(isDark),

                  const SizedBox(height: 16),

                  // Action buttons
                  Row(children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.call_rounded,
                            size: 16),
                        label: const Text('Call Driver'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor:
                              const Color(0xFF10B981),
                          side: const BorderSide(
                              color: Color(0xFF10B981)),
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const HomeScreen()),
                            (_) => false,
                          );
                        },
                        icon: const Icon(Icons.home_rounded,
                            size: 16),
                        label: const Text('Go Home'),
                        style: ElevatedButton.styleFrom(
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.list_alt_rounded,
                          color: Color(0xFF94A3B8), size: 16),
                      label: const Text('Track All Orders',
                          style: TextStyle(
                              color: Color(0xFF94A3B8))),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoCard(bool isDark, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
      ),
      child: Column(children: children),
    );
  }

  Widget _infoRow(String label, String value, bool isDark,
      {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  color: Color(0xFF94A3B8), fontSize: 12)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: valueColor ??
                    (isDark ? Colors.white : const Color(0xFF0F172A)),
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusTracker(bool isDark) {
    final steps = ['Order Placed', 'Confirmed', 'Out for Delivery', 'Delivered'];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Order Status',
              style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  fontWeight: FontWeight.bold,
                  fontSize: 14)),
          const SizedBox(height: 14),
          Row(
            children: steps.asMap().entries.map((e) {
              final idx = e.key;
              final step = e.value;
              final done = idx == 0; // Only first step done
              final active = idx == 1;
              return Expanded(
                child: Column(
                  children: [
                    Row(children: [
                      if (idx > 0)
                        Expanded(
                          child: Container(
                            height: 2,
                            color: done
                                ? const Color(0xFF10B981)
                                : (isDark
                                    ? Colors.white12
                                    : const Color(0xFFE2E8F0)),
                          ),
                        ),
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: done
                              ? const Color(0xFF10B981)
                              : active
                                  ? const Color(0xFFF59E0B)
                                  : (isDark
                                      ? const Color(0xFF334155)
                                      : const Color(0xFFF1F5F9)),
                          shape: BoxShape.circle,
                          border: active
                              ? Border.all(
                                  color: const Color(0xFFF59E0B),
                                  width: 2)
                              : null,
                        ),
                        child: Icon(
                          done
                              ? Icons.check_rounded
                              : active
                                  ? Icons.radio_button_checked_rounded
                                  : Icons.circle_outlined,
                          size: 14,
                          color: done || active
                              ? Colors.white
                              : const Color(0xFF64748B),
                        ),
                      ),
                      if (idx < steps.length - 1)
                        Expanded(
                          child: Container(
                            height: 2,
                            color: isDark
                                ? Colors.white12
                                : const Color(0xFFE2E8F0),
                          ),
                        ),
                    ]),
                    const SizedBox(height: 6),
                    Text(
                      step,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: done
                            ? const Color(0xFF10B981)
                            : active
                                ? const Color(0xFFF59E0B)
                                : const Color(0xFF64748B),
                        fontSize: 9,
                        fontWeight: done || active
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniMap(bool isDark) {
    return Container(
      height: 180,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: _driverLoc,
              initialZoom: 14,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.none,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: isDark
                    ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
                    : 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.shopconnector.app',
              ),
              MarkerLayer(markers: [
                Marker(
                  point: _driverLoc,
                  width: 36,
                  height: 36,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1D4ED8),
                      shape: BoxShape.circle,
                      border:
                          Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(Icons.two_wheeler_rounded,
                        color: Colors.white, size: 18),
                  ),
                ),
                Marker(
                  point: _dropLoc,
                  width: 36,
                  height: 36,
                  child: const Icon(Icons.location_pin,
                      color: Color(0xFFEF4444), size: 36),
                ),
              ]),
            ],
          ),
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1E293B)
                    : Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: Row(children: [
                const Icon(Icons.two_wheeler_rounded,
                    color: Color(0xFF1D4ED8), size: 14),
                const SizedBox(width: 5),
                Text('Driver en route',
                    style: TextStyle(
                        color: isDark
                            ? Colors.white
                            : const Color(0xFF0F172A),
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
