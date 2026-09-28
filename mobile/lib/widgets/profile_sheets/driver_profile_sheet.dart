import 'package:flutter/material.dart';
import '../../services/api_service.dart';

/// Shows an attractive Driver profile modal for Customers & Shop Owners to inspect.
void showDriverProfileSheet(BuildContext context, {required String driverId}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _DriverProfileSheet(driverId: driverId),
  );
}

class _DriverProfileSheet extends StatefulWidget {
  final String driverId;

  const _DriverProfileSheet({required this.driverId});

  @override
  State<_DriverProfileSheet> createState() => _DriverProfileSheetState();
}

class _DriverProfileSheetState extends State<_DriverProfileSheet> {
  Map<String, dynamic>? _profile;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final data = await ApiService.getDriverProfile(widget.driverId);
      if (mounted) setState(() { _profile = data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF3B82F6)))
          : _error != null
              ? Center(child: Text('Failed to load profile: $_error', style: const TextStyle(color: Colors.white54)))
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final p = _profile!;
    final stats = p['stats'] as Map<String, dynamic>? ?? {};
    final vehicle = p['vehicle'] as Map<String, dynamic>?;
    final topTags = (p['topTags'] as List<dynamic>?) ?? [];
    final recentReviews = (p['recentReviews'] as List<dynamic>?) ?? [];
    final isOnline = p['isOnline'] == true;

    return Column(
      children: [
        Center(
          child: Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 44, height: 4,
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Driver Header Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundImage: NetworkImage(
                          p['avatarUrl'] ?? 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=300',
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  p['fullName'] ?? 'Partner Driver',
                                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(width: 6),
                                const Icon(Icons.verified, color: Color(0xFF10B981), size: 16),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'DL: ${p['licenseNumber'] ?? 'DL-142023008976'}',
                              style: const TextStyle(color: Colors.white60, fontSize: 12),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isOnline
                                        ? const Color(0xFF10B981).withValues(alpha: 0.2)
                                        : Colors.white10,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    isOnline ? 'ONLINE & ACTIVE' : 'OFFLINE',
                                    style: TextStyle(
                                      color: isOnline ? const Color(0xFF34D399) : Colors.white38,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF3B82F6).withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'VERIFIED PARTNER',
                                    style: TextStyle(color: Color(0xFF60A5FA), fontWeight: FontWeight.bold, fontSize: 10),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Vehicle Details Card
                if (vehicle != null) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF3B82F6).withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.two_wheeler_rounded, color: Color(0xFF60A5FA), size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                vehicle['plateNumber'] ?? 'RJ14-AB-1234',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  letterSpacing: 1,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${vehicle['makeModel'] ?? 'Hero Splendor Plus'} • ${vehicle['color'] ?? 'Black'} (${vehicle['vehicleType'] ?? 'Bike'})',
                                style: const TextStyle(color: Colors.white60, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Metrics Row
                Row(
                  children: [
                    _buildMetric(
                      title: 'Trips Completed',
                      value: '${stats['totalTripsCompleted'] ?? 0}+',
                      icon: Icons.route_rounded,
                      color: const Color(0xFF3ECFCF),
                    ),
                    const SizedBox(width: 8),
                    _buildMetric(
                      title: 'On-Time Rate',
                      value: '${stats['onTimeRate'] ?? 97}%',
                      icon: Icons.schedule_rounded,
                      color: const Color(0xFF10B981),
                    ),
                    const SizedBox(width: 8),
                    _buildMetric(
                      title: 'Rating Score',
                      value: '${p['rating'] ?? 5.0} ★',
                      icon: Icons.star_rounded,
                      color: const Color(0xFFF59E0B),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Positive Badges & Tags
                const Text(
                  'Driver Excellence & Highlights',
                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: topTags.map((tagObj) {
                    final tag = tagObj['tag'] ?? '';
                    final count = tagObj['count'] ?? 1;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.stars_rounded, color: Color(0xFFF59E0B), size: 13),
                          const SizedBox(width: 6),
                          Text(tag, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text('$count', style: const TextStyle(color: Color(0xFF93C5FD), fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 22),

                // Customer Reviews
                const Text(
                  'What Customers Say',
                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),

                if (recentReviews.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Center(
                      child: Text('No reviews recorded yet.', style: TextStyle(color: Colors.white38, fontSize: 12)),
                    ),
                  )
                else
                  ...recentReviews.map((rev) => _buildReviewCard(rev)),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMetric({required String title, required String value, required IconData icon, required Color color}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(title, style: const TextStyle(color: Colors.white38, fontSize: 10), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewCard(dynamic rev) {
    final name = rev['reviewerName'] ?? 'Customer';
    final stars = (rev['stars'] as num?)?.toInt() ?? 5;
    final text = rev['reviewText']?.toString();
    final tags = rev['tags']?.toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              Row(
                children: List.generate(
                  5,
                  (i) => Icon(
                    Icons.star_rounded,
                    color: i < stars ? const Color(0xFFF59E0B) : Colors.white12,
                    size: 14,
                  ),
                ),
              ),
            ],
          ),
          if (tags != null && tags.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('🏷️ $tags', style: const TextStyle(color: Color(0xFF93C5FD), fontSize: 11)),
          ],
          if (text != null && text.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(text, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ],
      ),
    );
  }
}
