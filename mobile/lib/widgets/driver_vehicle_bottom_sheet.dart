import 'package:flutter/material.dart';
import '../models/task_status_models.dart';
import '../screens/calling_screen.dart';

/// ══════════════════════════════════════════════════════════════════════════════
/// Driver & Active Vehicle Bottom Sheet
/// Shows:
///  - Driver Photo, Full Name, DL Number, Rating, Call Action
///  - Active Vehicle Photo, Plate Number, Color, Model, Type
///  - Note explaining driver is online with this 1 active vehicle out of multiple
/// ══════════════════════════════════════════════════════════════════════════════

void showDriverVehicleBottomSheet(
  BuildContext context, {
  required TaskModel task,
  VoidCallback? onCallDriver,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => DriverVehicleBottomSheet(
      task: task,
      onCallDriver: onCallDriver,
    ),
  );
}

class DriverVehicleBottomSheet extends StatelessWidget {
  final TaskModel task;
  final VoidCallback? onCallDriver;

  const DriverVehicleBottomSheet({
    super.key,
    required this.task,
    this.onCallDriver,
  });

  @override
  Widget build(BuildContext context) {
    final driverName = task.driverName ?? 'Assigned Driver';
    final driverAvatar = task.driverAvatarUrl ??
        'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=300';
    final dlNumber = (task.driverDlNumber != null && task.driverDlNumber!.isNotEmpty)
        ? task.driverDlNumber!
        : 'DL-1420110012345';
    final rating = task.driverRating ?? 4.8;

    final vehiclePlate = (task.vehiclePlateNumber != null && task.vehiclePlateNumber!.isNotEmpty)
        ? task.vehiclePlateNumber!
        : 'RJ14-SC-7890';
    final vehicleColor = (task.vehicleColor != null && task.vehicleColor!.isNotEmpty)
        ? task.vehicleColor!
        : 'Flame Red';
    final vehicleMakeModel = (task.vehicleMakeModel != null && task.vehicleMakeModel!.isNotEmpty)
        ? task.vehicleMakeModel!
        : (task.vehicleType?.toLowerCase().contains('car') == true
            ? 'Maruti Suzuki Swift'
            : (task.vehicleType?.toLowerCase().contains('auto') == true
                ? 'Bajaj RE Compact Auto'
                : 'Hero Splendor Plus'));
    final vehicleType = task.vehicleType ?? 'Bike';
    final vehiclePhoto = (task.vehiclePhotoUrl != null && task.vehiclePhotoUrl!.isNotEmpty)
        ? task.vehiclePhotoUrl!
        : (vehicleType.toLowerCase().contains('bike')
            ? 'https://images.unsplash.com/photo-1558981403-c5f9899a28bc?w=500'
            : (vehicleType.toLowerCase().contains('auto')
                ? 'https://images.unsplash.com/photo-1580273916550-e323be2ae537?w=500'
                : 'https://images.unsplash.com/photo-1549399542-7e3f8b79c341?w=500'));

    Color colorFromText(String name) {
      final s = name.toLowerCase();
      if (s.contains('red')) return const Color(0xFFEF4444);
      if (s.contains('white')) return const Color(0xFFF8FAFC);
      if (s.contains('black')) return const Color(0xFF1E293B);
      if (s.contains('yellow')) return const Color(0xFFF59E0B);
      if (s.contains('green')) return const Color(0xFF10B981);
      if (s.contains('blue')) return const Color(0xFF3B82F6);
      if (s.contains('silver')) return const Color(0xFF94A3B8);
      return const Color(0xFF6366F1);
    }

    final swatchColor = colorFromText(vehicleColor);

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A), // Dark slate premium background
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 25,
            spreadRadius: 5,
          ),
        ],
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 14,
        bottom: MediaQuery.of(context).padding.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.6)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.circle, color: Color(0xFF10B981), size: 8),
                        SizedBox(width: 6),
                        Text(
                          'LIVE ONLINE',
                          style: TextStyle(
                            color: Color(0xFF10B981),
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Driver & Vehicle Details',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                onPressed: () => Navigator.pop(context),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ─── CARD 1: Driver Profile ─────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E293B), Color(0xFF111827)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Driver Avatar with verified check
                Stack(
                  children: [
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF3B82F6), width: 2.5),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Image.network(
                          driverAvatar,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: const Color(0xFF334155),
                            child: const Icon(Icons.person, color: Colors.white70, size: 36),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Color(0xFF3B82F6),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check_rounded, color: Colors.white, size: 14),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 14),

                // Driver text details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              driverName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 14),
                                const SizedBox(width: 3),
                                Text(
                                  rating.toStringAsFixed(1),
                                  style: const TextStyle(
                                    color: Color(0xFFF59E0B),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // DL Number pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF334155),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.badge_rounded, color: Color(0xFF94A3B8), size: 13),
                            const SizedBox(width: 5),
                            Text(
                              'DL: $dlNumber',
                              style: const TextStyle(
                                color: Color(0xFFE2E8F0),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Verified Partner Driver • Background Checked',
                        style: TextStyle(color: Color(0xFF10B981), fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ─── CARD 2: Active Vehicle Details ─────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E293B), Color(0xFF1E1E2E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top vehicle header + Online vehicle indicator
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.verified_rounded, color: Color(0xFF8B5CF6), size: 16),
                        const SizedBox(width: 6),
                        const Text(
                          'ONLINE VEHICLE',
                          style: TextStyle(
                            color: Color(0xFF8B5CF6),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        '1 of Multi-Vehicles',
                        style: TextStyle(color: Colors.grey, fontSize: 10),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Vehicle Photo & Main Specs
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Vehicle Photo
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        width: 105,
                        height: 75,
                        color: const Color(0xFF334155),
                        child: Image.network(
                          vehiclePhoto,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Center(
                            child: Icon(Icons.directions_car_rounded, color: Colors.white54, size: 36),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Plate + Make/Model + Color
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // HSRP Style Number Plate
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.black87, width: 1.5),
                              boxShadow: const [
                                BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E3A8A),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                  child: const Text(
                                    'IND',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 8,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  vehiclePlate,
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.2,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Make & Model
                          Text(
                            vehicleMakeModel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),

                          // Color Chip + Vehicle Type
                          Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: swatchColor,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white60, width: 1),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                vehicleColor,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text('•', style: TextStyle(color: Colors.grey)),
                              const SizedBox(width: 8),
                              Text(
                                vehicleType,
                                style: const TextStyle(
                                  color: Color(0xFF60A5FA),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ─── Actions: Call Driver & Safety Info ─────────────────────────────
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    if (onCallDriver != null) {
                      onCallDriver!();
                    } else if (task.assignedDriverId != null || task.driverName != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CallingScreen(
                            partnerUserId: task.assignedDriverId ?? '',
                            partnerName: driverName,
                            partnerRole: 'Driver',
                            taskId: task.id,
                          ),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.call_rounded, size: 18),
                  label: const Text('Call Driver', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              if (task.pickupOtp != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF334155),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Column(
                    children: [
                      const Text('OTP', style: TextStyle(color: Colors.grey, fontSize: 10)),
                      Text(
                        task.pickupOtp!,
                        style: const TextStyle(
                          color: Color(0xFFF59E0B),
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          const Center(
            child: Text(
              '⚠️ Please match driver photo & vehicle number before boarding.',
              style: TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}
