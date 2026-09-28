import 'package:flutter/material.dart';
import '../models/task_status_models.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  15 Unique Task / Booking Detail Card Designs
// ══════════════════════════════════════════════════════════════════════════════

// ─── Shared Helpers ──────────────────────────────────────────────────────────

Widget _statusBadge(TaskStatus s) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: s.bgColor,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: s.color.withValues(alpha: 0.6)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(s.icon, size: 11, color: s.color),
        const SizedBox(width: 4),
        Text(s.label,
            style: TextStyle(
                color: s.color,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8)),
      ],
    ),
  );
}

Widget _routeRow(String from, String to) {
  return Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(width: 8, height: 8,
                  decoration: const BoxDecoration(
                      color: Color(0xFF10B981), shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Expanded(child: Text(from,
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 12),
                  overflow: TextOverflow.ellipsis)),
            ]),
            Container(
                margin: const EdgeInsets.only(left: 3),
                width: 2,
                height: 14,
                color: Colors.white12),
            Row(children: [
              Container(width: 8, height: 8,
                  decoration: const BoxDecoration(
                      color: Color(0xFFEF4444), shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Expanded(child: Text(to,
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 12),
                  overflow: TextOverflow.ellipsis)),
            ]),
          ],
        ),
      ),
    ],
  );
}

Widget _fareChip(double? fare, {String prefix = '₹'}) {
  if (fare == null) return const SizedBox.shrink();
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: const Color(0xFF10B981),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text('$prefix${fare.toStringAsFixed(0)}',
        style: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
  );
}

String _timeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}

// ─── CARD DESIGN 1: Gradient Hero (Cab Ride — Customer) ─────────────────────
class TaskCard1CabRide extends StatelessWidget {
  final TaskModel task;
  final VoidCallback? onTap;
  const TaskCard1CabRide({super.key, required this.task, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: task.status.color.withValues(alpha: 0.35), width: 1.2),
          boxShadow: [
            BoxShadow(
                color: task.status.color.withValues(alpha: 0.18),
                blurRadius: 16,
                offset: const Offset(0, 6)),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: task.status.color.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(task.taskIcon, color: task.status.color, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(task.taskTypeLabel,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15)),
                        Text(task.shortId,
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 11)),
                      ],
                    ),
                  ]),
                  _statusBadge(task.status),
                ],
              ),
              const SizedBox(height: 14),
              _routeRow(task.pickupAddress, task.dropoffAddress),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (task.driverName != null)
                    Row(children: [
                      const Icon(Icons.person_rounded, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(task.driverName!,
                          style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    ])
                  else
                    Text(_timeAgo(task.createdAt),
                        style: const TextStyle(color: Colors.grey, fontSize: 11)),
                  _fareChip(task.estimatedFare),
                ],
              ),
              if (task.pickupOtp != null && task.status == TaskStatus.assign) ...[
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.5)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.lock_outlined,
                        color: Color(0xFFF59E0B), size: 14),
                    const SizedBox(width: 6),
                    Text('Pickup OTP: ${task.pickupOtp}',
                        style: const TextStyle(
                            color: Color(0xFFF59E0B),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            letterSpacing: 2)),
                  ]),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── CARD DESIGN 2: Glassmorphism (Grocery — Customer) ───────────────────────
class TaskCard2Grocery extends StatelessWidget {
  final TaskModel task;
  final VoidCallback? onTap;
  const TaskCard2Grocery({super.key, required this.task, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white12),
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 4)),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF059669).withValues(alpha: 0.15),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(18)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: [
                    const Icon(Icons.shopping_basket_rounded,
                        color: Color(0xFF34D399), size: 18),
                    const SizedBox(width: 8),
                    Text(task.shopName ?? 'Kirana Store',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14)),
                  ]),
                  _statusBadge(task.status),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.pin_drop_rounded,
                        size: 14, color: Color(0xFFEF4444)),
                    const SizedBox(width: 6),
                    Expanded(
                        child: Text(task.dropoffAddress,
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12),
                            overflow: TextOverflow.ellipsis)),
                  ]),
                  const SizedBox(height: 10),
                  if (task.items.isNotEmpty)
                    Wrap(
                      spacing: 6,
                      children: task.items
                          .take(4)
                          .map<Widget>((it) => Chip(
                                label: Text(it['item']?.toString() ?? '',
                                    style: const TextStyle(
                                        fontSize: 10, color: Colors.white70)),
                                backgroundColor: const Color(0xFF334155),
                                visualDensity: VisualDensity.compact,
                              ))
                          .toList(),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_timeAgo(task.createdAt),
                          style:
                              const TextStyle(color: Colors.grey, fontSize: 11)),
                      _fareChip(task.estimatedFare),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── CARD DESIGN 3: Timeline Strip (Delivery — Merchant) ─────────────────────
class TaskCard3Timeline extends StatelessWidget {
  final TaskModel task;
  final VoidCallback? onTap;
  const TaskCard3Timeline({super.key, required this.task, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            // Left color bar
            Container(
              width: 4,
              height: 90,
              decoration: BoxDecoration(
                color: task.status.color,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(task.taskTypeLabel,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15)),
                      _statusBadge(task.status),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(task.customerName ?? 'Customer',
                      style: const TextStyle(
                          color: Color(0xFF94A3B8), fontSize: 12)),
                  const SizedBox(height: 8),
                  _routeRow(task.pickupAddress, task.dropoffAddress),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (task.driverName != null)
                        Row(children: [
                          const Icon(Icons.two_wheeler_rounded,
                              size: 13, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(task.driverName!,
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 11)),
                        ]),
                      _fareChip(task.estimatedFare),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── CARD DESIGN 4: Neon Glow (Ongoing/Active Task — Driver) ─────────────────
class TaskCard4NeonGlow extends StatelessWidget {
  final TaskModel task;
  final VoidCallback? onTap;
  const TaskCard4NeonGlow({super.key, required this.task, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.7)),
          boxShadow: [
            BoxShadow(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
                blurRadius: 20,
                spreadRadius: 1),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.local_shipping_rounded,
                          color: Color(0xFFA78BFA), size: 22),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('ACTIVE DELIVERY',
                            style: TextStyle(
                                color: Color(0xFFA78BFA),
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                                letterSpacing: 1)),
                        Text(task.shortId,
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 11)),
                      ],
                    ),
                  ]),
                  _statusBadge(task.status),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _routeRow(task.pickupAddress, task.dropoffAddress),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _infoTile(
                        Icons.straighten_rounded,
                        '${task.distanceKm?.toStringAsFixed(1) ?? '--'} km',
                        'Distance'),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _infoTile(Icons.payment_rounded,
                        task.paymentMode ?? 'Cash', 'Payment'),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _infoTile(Icons.currency_rupee_rounded,
                        task.estimatedFare?.toStringAsFixed(0) ?? '--',
                        'Earnings'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoTile(IconData icon, String val, String lbl) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Icon(icon, size: 16, color: const Color(0xFFA78BFA)),
          const SizedBox(height: 4),
          Text(val,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12)),
          Text(lbl,
              style: const TextStyle(color: Colors.grey, fontSize: 9)),
        ],
      ),
    );
  }
}

// ─── CARD DESIGN 5: Completed Celebration (Driver/Customer) ──────────────────
class TaskCard5Completed extends StatelessWidget {
  final TaskModel task;
  final VoidCallback? onTap;
  const TaskCard5Completed({super.key, required this.task, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded,
                    color: Color(0xFF34D399), size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(task.taskTypeLabel,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15)),
                        _fareChip(task.estimatedFare),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('${task.pickupAddress} → ${task.dropoffAddress}',
                        style: const TextStyle(
                            color: Color(0xFF94A3B8), fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text(
                        task.completedAt != null
                            ? 'Completed ${_timeAgo(task.completedAt!)}'
                            : 'Completed',
                        style: const TextStyle(
                            color: Color(0xFF34D399), fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── CARD DESIGN 6: Cancelled / Rejected (Red accent) ────────────────────────
class TaskCard6Cancelled extends StatelessWidget {
  final TaskModel task;
  final VoidCallback? onTap;
  const TaskCard6Cancelled({super.key, required this.task, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.cancel_rounded,
                  color: Color(0xFFEF4444), size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(task.taskTypeLabel,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14)),
                      _statusBadge(task.status),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(task.shortId,
                      style:
                          const TextStyle(color: Colors.grey, fontSize: 11)),
                  const SizedBox(height: 4),
                  Text('${task.pickupAddress} → ${task.dropoffAddress}',
                      style:
                          const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── CARD DESIGN 7: Pending Pulse (Awaiting Assignment) ──────────────────────
class TaskCard7Pending extends StatefulWidget {
  final TaskModel task;
  final VoidCallback? onTap;
  const TaskCard7Pending({super.key, required this.task, this.onTap});

  @override
  State<TaskCard7Pending> createState() => _TaskCard7PendingState();
}

class _TaskCard7PendingState extends State<TaskCard7Pending>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 1))
      ..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.6, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, _) => Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                color: const Color(0xFFF59E0B)
                    .withValues(alpha: _pulse.value * 0.7)),
            boxShadow: [
              BoxShadow(
                  color: const Color(0xFFF59E0B)
                      .withValues(alpha: _pulse.value * 0.2),
                  blurRadius: 14),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: [
                    Icon(widget.task.taskIcon,
                        color: const Color(0xFFFCD34D), size: 22),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.task.taskTypeLabel,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15)),
                        Text(widget.task.shortId,
                            style:
                                const TextStyle(color: Colors.grey, fontSize: 11)),
                      ],
                    ),
                  ]),
                  _statusBadge(widget.task.status),
                ],
              ),
              const SizedBox(height: 12),
              _routeRow(widget.task.pickupAddress, widget.task.dropoffAddress),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: [
                    const Icon(Icons.access_time_rounded,
                        size: 13, color: Color(0xFFF59E0B)),
                    const SizedBox(width: 4),
                    Text('Finding driver... ${_timeAgo(widget.task.createdAt)}',
                        style: const TextStyle(
                            color: Color(0xFFF59E0B), fontSize: 11)),
                  ]),
                  _fareChip(widget.task.estimatedFare),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── CARD DESIGN 8: Assigned with Driver Info (Customer/Merchant) ─────────────
class TaskCard8Assigned extends StatelessWidget {
  final TaskModel task;
  final VoidCallback? onTap;
  final VoidCallback? onCallDriver;
  const TaskCard8Assigned(
      {super.key, required this.task, this.onTap, this.onCallDriver});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.4)),
        ),
        child: Column(
          children: [
            // Driver info header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(18)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor:
                        const Color(0xFF3B82F6).withValues(alpha: 0.25),
                    child: const Icon(Icons.person_rounded,
                        color: Color(0xFF60A5FA), size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(task.driverName ?? 'Driver Assigned',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13)),
                        Text(task.vehicleType ?? 'Delivery Vehicle',
                            style: const TextStyle(
                                color: Color(0xFF94A3B8), fontSize: 11)),
                      ],
                    ),
                  ),
                  _statusBadge(task.status),
                  if (onCallDriver != null) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: onCallDriver,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.call_rounded,
                            size: 16, color: Color(0xFF34D399)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _routeRow(task.pickupAddress, task.dropoffAddress),
                  if (task.pickupOtp != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: const Color(0xFFF59E0B)
                                .withValues(alpha: 0.4)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.vpn_key_rounded,
                            color: Color(0xFFFCD34D), size: 16),
                        const SizedBox(width: 8),
                        Text('OTP: ${task.pickupOtp}',
                            style: const TextStyle(
                                color: Color(0xFFFCD34D),
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                letterSpacing: 4)),
                      ]),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_timeAgo(task.createdAt),
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 11)),
                      _fareChip(task.estimatedFare),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── CARD DESIGN 9: Compact Row (Merchant Order List) ─────────────────────────
class TaskCard9Compact extends StatelessWidget {
  final TaskModel task;
  final VoidCallback? onTap;
  const TaskCard9Compact({super.key, required this.task, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: task.status.bgColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(task.taskIcon, color: task.status.color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(task.customerName ?? task.taskTypeLabel,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                  const SizedBox(height: 2),
                  Text(task.dropoffAddress,
                      style: const TextStyle(
                          color: Color(0xFF94A3B8), fontSize: 11),
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _statusBadge(task.status),
                const SizedBox(height: 4),
                if (task.estimatedFare != null)
                  Text('₹${task.estimatedFare!.toStringAsFixed(0)}',
                      style: const TextStyle(
                          color: Color(0xFF34D399),
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── CARD DESIGN 10: Morning Subscription Strip ───────────────────────────────
class TaskCard10Subscription extends StatelessWidget {
  final Map<String, dynamic> sub;
  final VoidCallback? onTap;
  final VoidCallback? onTogglePause;
  const TaskCard10Subscription(
      {super.key, required this.sub, this.onTap, this.onTogglePause});

  @override
  Widget build(BuildContext context) {
    final isPaused = sub['isCurrentlyPaused'] == true;
    final color = isPaused ? const Color(0xFFF59E0B) : const Color(0xFF10B981);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
              child: Icon(
                  isPaused
                      ? Icons.pause_circle_rounded
                      : Icons.breakfast_dining_rounded,
                  color: color,
                  size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(sub['itemName']?.toString() ?? 'Subscription',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14)),
                  Text(
                      '${sub['quantity']} ${sub['unit']} • ${sub['deliverySlot'] ?? '06:00 AM'}',
                      style: const TextStyle(
                          color: Color(0xFF94A3B8), fontSize: 12)),
                  Text('₹${sub['pricePerDelivery']}/day • ${sub['businessName'] ?? ''}',
                      style: const TextStyle(
                          color: Color(0xFF64748B), fontSize: 11)),
                ],
              ),
            ),
            Column(
              children: [
                Chip(
                  label: Text(isPaused ? 'PAUSED' : 'ACTIVE',
                      style: TextStyle(
                          color: color,
                          fontSize: 9,
                          fontWeight: FontWeight.bold)),
                  backgroundColor: color.withValues(alpha: 0.15),
                  visualDensity: VisualDensity.compact,
                ),
                if (onTogglePause != null)
                  TextButton(
                    onPressed: onTogglePause,
                    style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 24)),
                    child: Text(isPaused ? 'Resume' : 'Pause',
                        style: TextStyle(color: color, fontSize: 11)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── CARD DESIGN 11: Intercity Banner (Customer discover) ────────────────────
class TaskCard11Banner extends StatelessWidget {
  final Map<String, dynamic> banner;
  final VoidCallback? onBook;
  const TaskCard11Banner({super.key, required this.banner, this.onBook});

  @override
  Widget build(BuildContext context) {
    final from = banner['fromCity']?.toString() ?? 'City';
    final to = banner['toCity']?.toString() ?? 'City';
    final price = (banner['expectedPrice'] as num?)?.toDouble() ?? 0;
    final seats = banner['seatsAvailable'] as int? ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.alt_route_rounded,
                  color: Color(0xFF818CF8), size: 22),
              const SizedBox(width: 10),
              Text('$from  ➜  $to',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
              const Spacer(),
              Text('₹${price.toStringAsFixed(0)}/seat',
                  style: const TextStyle(
                      color: Color(0xFF34D399),
                      fontWeight: FontWeight.bold,
                      fontSize: 15)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                const Icon(Icons.event_seat_rounded,
                    size: 14, color: Color(0xFF94A3B8)),
                const SizedBox(width: 4),
                Text('$seats seats left',
                    style: const TextStyle(
                        color: Color(0xFF94A3B8), fontSize: 12)),
              ]),
              ElevatedButton(
                onPressed: seats > 0 ? onBook : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: seats > 0
                      ? const Color(0xFF6366F1)
                      : Colors.grey.shade700,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  textStyle: const TextStyle(fontSize: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(seats > 0 ? 'Book Seat' : 'Sold Out'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── CARD DESIGN 12: Driver Task Accept Card (Driver Dispatch) ────────────────
class TaskCard12DriverDispatch extends StatelessWidget {
  final TaskModel task;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;
  const TaskCard12DriverDispatch(
      {super.key, required this.task, this.onAccept, this.onReject});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.7)),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
              blurRadius: 16),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  const Icon(Icons.notifications_active_rounded,
                      color: Color(0xFFFCD34D), size: 20),
                  const SizedBox(width: 8),
                  const Text('NEW DISPATCH',
                      style: TextStyle(
                          color: Color(0xFFFCD34D),
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          letterSpacing: 1)),
                ]),
                _fareChip(task.estimatedFare),
              ],
            ),
            const SizedBox(height: 12),
            _routeRow(task.pickupAddress, task.dropoffAddress),
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.straighten_rounded,
                  size: 13, color: Color(0xFF94A3B8)),
              const SizedBox(width: 4),
              Text(
                  '${task.distanceKm?.toStringAsFixed(1) ?? '--'} km • ${task.taskTypeLabel} • ${task.paymentMode ?? 'Cash'}',
                  style: const TextStyle(
                      color: Color(0xFF94A3B8), fontSize: 12)),
            ]),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onAccept,
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: const Text('Accept'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onReject,
                    icon: const Icon(Icons.close_rounded,
                        size: 16, color: Color(0xFFEF4444)),
                    label: const Text('Reject',
                        style: TextStyle(color: Color(0xFFEF4444))),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFEF4444)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── CARD DESIGN 13: Merchant RFQ Quote Card ─────────────────────────────────
class TaskCard13RfqQuote extends StatelessWidget {
  final Map<String, dynamic> rfq;
  final VoidCallback? onQuote;
  final VoidCallback? onCall;
  const TaskCard13RfqQuote(
      {super.key, required this.rfq, this.onQuote, this.onCall});

  @override
  Widget build(BuildContext context) {
    final status = rfq['status']?.toString() ?? 'Open';
    final isCompleted = status == 'OrderCreated';
    final borderColor = isCompleted
        ? const Color(0xFF10B981)
        : const Color(0xFFF59E0B);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor.withValues(alpha: 0.45)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: borderColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(status.toUpperCase(),
                      style: TextStyle(
                          color: borderColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold)),
                ),
                Text('${(rfq['quotes'] as List?)?.length ?? 0} Quotes',
                    style: const TextStyle(
                        color: Color(0xFF94A3B8), fontSize: 11)),
              ],
            ),
            const SizedBox(height: 10),
            Text(rfq['rawRequirementText']?.toString() ?? 'Grocery Request',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15)),
            const SizedBox(height: 4),
            Text('By: ${rfq['customerId']?.toString().substring(0, 8) ?? 'Customer'}…',
                style: const TextStyle(
                    color: Color(0xFF64748B), fontSize: 11)),
            const SizedBox(height: 12),
            Row(
              children: [
                if (!isCompleted)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onQuote,
                      icon: const Icon(Icons.send_rounded, size: 14),
                      label: const Text('Submit Quote',
                          style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  )
                else
                  const Row(children: [
                    Icon(Icons.check_circle_rounded,
                        color: Color(0xFF10B981), size: 16),
                    SizedBox(width: 6),
                    Text('Order Finalized',
                        style: TextStyle(
                            color: Color(0xFF10B981),
                            fontWeight: FontWeight.bold,
                            fontSize: 12)),
                  ]),
                const SizedBox(width: 10),
                if (onCall != null)
                  IconButton(
                    icon: const Icon(Icons.phone_in_talk_rounded,
                        color: Color(0xFF34D399), size: 20),
                    onPressed: onCall,
                    tooltip: 'Call Customer',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── CARD DESIGN 14: Khata / Ledger Entry Card ────────────────────────────────
class TaskCard14Khata extends StatelessWidget {
  final Map<String, dynamic> entry;
  const TaskCard14Khata({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    final isDebit = entry['entryType']?.toString() == 'DuesDebit';
    final color =
        isDebit ? const Color(0xFFEF4444) : const Color(0xFF10B981);
    final amount = (entry['amount'] as num?)?.toDouble() ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
            child: Icon(
                isDebit
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded,
                color: color,
                size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    entry['customerName']?.toString() ?? 'Customer',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
                Text(
                    '${entry['paymentMethod']?.toString() ?? 'Cash'} • ${entry['notes']?.toString() ?? ''}',
                    style: const TextStyle(
                        color: Color(0xFF94A3B8), fontSize: 11),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${isDebit ? '+' : '-'}₹${amount.toStringAsFixed(0)}',
                  style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
              Chip(
                label: Text(isDebit ? 'DUES' : 'PAID',
                    style: TextStyle(
                        color: color,
                        fontSize: 9,
                        fontWeight: FontWeight.bold)),
                backgroundColor: color.withValues(alpha: 0.1),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── CARD DESIGN 15: OTP Verify Step Card (Driver in progress) ───────────────
class TaskCard15OtpVerify extends StatelessWidget {
  final TaskModel task;
  final TextEditingController otpCtrl;
  final VoidCallback? onVerifyPickup;
  final VoidCallback? onVerifyDrop;
  const TaskCard15OtpVerify({
    super.key,
    required this.task,
    required this.otpCtrl,
    this.onVerifyPickup,
    this.onVerifyDrop,
  });

  @override
  Widget build(BuildContext context) {
    final isAtPickup = task.status == TaskStatus.assign;
    final stepColor =
        isAtPickup ? const Color(0xFF3B82F6) : const Color(0xFF8B5CF6);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: stepColor.withValues(alpha: 0.7)),
        boxShadow: [
          BoxShadow(
              color: stepColor.withValues(alpha: 0.25),
              blurRadius: 18),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(
                  isAtPickup
                      ? Icons.store_rounded
                      : Icons.home_rounded,
                  color: stepColor,
                  size: 22),
              const SizedBox(width: 10),
              Text(
                  isAtPickup
                      ? 'AT PICKUP — Enter OTP from Sender'
                      : 'AT DROP — Enter OTP from Receiver',
                  style: TextStyle(
                      color: stepColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
            ]),
            const SizedBox(height: 14),
            _routeRow(task.pickupAddress, task.dropoffAddress),
            const SizedBox(height: 16),
            TextField(
              controller: otpCtrl,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: stepColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 28,
                  letterSpacing: 12),
              maxLength: 6,
              decoration: InputDecoration(
                hintText: '------',
                hintStyle: TextStyle(
                    color: stepColor.withValues(alpha: 0.3),
                    fontSize: 28,
                    letterSpacing: 12),
                counterText: '',
                filled: true,
                fillColor: stepColor.withValues(alpha: 0.08),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        BorderSide(color: stepColor.withValues(alpha: 0.5))),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        BorderSide(color: stepColor.withValues(alpha: 0.35))),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: stepColor, width: 2)),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isAtPickup ? onVerifyPickup : onVerifyDrop,
                icon: const Icon(Icons.verified_rounded, size: 18),
                label: Text(
                    isAtPickup ? 'Verify Pickup OTP' : 'Verify Drop OTP',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: stepColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────
//  Smart Card Selector — picks correct design by context
// ──────────────────────────────────────────────
Widget buildTaskCard(
  TaskModel task, {
  String viewerRole = 'Customer',   // 'Customer' | 'Merchant' | 'Driver'
  VoidCallback? onTap,
  VoidCallback? onCallDriver,
  VoidCallback? onAccept,
  VoidCallback? onReject,
}) {
  // Driver: Pending dispatch → accept card
  if (viewerRole == 'Driver' && task.status == TaskStatus.pending) {
    return TaskCard12DriverDispatch(
        task: task, onAccept: onAccept, onReject: onReject);
  }
  // Driver: ongoing with purple neon
  if (viewerRole == 'Driver' && task.status == TaskStatus.ongoing) {
    return TaskCard4NeonGlow(task: task, onTap: onTap);
  }
  // Driver: assigned / en-route
  if (viewerRole == 'Driver' && task.status == TaskStatus.assign) {
    return TaskCard8Assigned(task: task, onTap: onTap, onCallDriver: onCallDriver);
  }
  // Completed — celebration card
  if (task.status == TaskStatus.completed) {
    return TaskCard5Completed(task: task, onTap: onTap);
  }
  // Cancelled
  if (task.status == TaskStatus.cancelled) {
    return TaskCard6Cancelled(task: task, onTap: onTap);
  }
  // Customer pending ride
  if (viewerRole == 'Customer' && task.taskType == 'MobilityRide') {
    return task.status == TaskStatus.pending
        ? TaskCard7Pending(task: task, onTap: onTap)
        : TaskCard1CabRide(task: task, onTap: onTap);
  }
  // Customer grocery
  if (viewerRole == 'Customer' && task.taskType == 'GroceryDelivery') {
    return TaskCard2Grocery(task: task, onTap: onTap);
  }
  // Merchant default
  if (viewerRole == 'Merchant') {
    return TaskCard3Timeline(task: task, onTap: onTap);
  }
  // Fallback pending
  if (task.status == TaskStatus.pending) {
    return TaskCard7Pending(task: task, onTap: onTap);
  }
  // Fallback assigned
  if (task.status == TaskStatus.assign) {
    return TaskCard8Assigned(task: task, onTap: onTap, onCallDriver: onCallDriver);
  }
  // Default compact
  return TaskCard9Compact(task: task, onTap: onTap);
}
