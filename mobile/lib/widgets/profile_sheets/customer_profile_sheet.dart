import 'package:flutter/material.dart';
import '../../services/api_service.dart';

/// Shows an attractive Customer profile modal for Shop Owners & Drivers to inspect.
void showCustomerProfileSheet(BuildContext context, {required String customerId}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _CustomerProfileSheet(customerId: customerId),
  );
}

class _CustomerProfileSheet extends StatefulWidget {
  final String customerId;

  const _CustomerProfileSheet({required this.customerId});

  @override
  State<_CustomerProfileSheet> createState() => _CustomerProfileSheetState();
}

class _CustomerProfileSheetState extends State<_CustomerProfileSheet> {
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
      final data = await ApiService.getCustomerProfile(widget.customerId);
      if (mounted) setState(() { _profile = data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)))
          : _error != null
              ? Center(child: Text('Failed to load profile: $_error', style: const TextStyle(color: Colors.white54)))
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final p = _profile!;
    final stats = p['stats'] as Map<String, dynamic>? ?? {};
    final topTags = (p['topTags'] as List<dynamic>?) ?? [];
    final recentReviews = (p['recentReviews'] as List<dynamic>?) ?? [];

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
                // Customer Header Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF064E3B), Color(0xFF1E293B)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundImage: NetworkImage(
                          p['avatarUrl'] ?? 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=300',
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
                                  p['fullName'] ?? 'Customer',
                                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(width: 6),
                                const Icon(Icons.verified, color: Color(0xFF10B981), size: 16),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '📞 ${p['phone']} • Member since ${p['memberSince'] ?? '2026'}',
                              style: const TextStyle(color: Colors.white60, fontSize: 12),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'TRUSTED BUYER',
                                style: TextStyle(color: Color(0xFF34D399), fontWeight: FontWeight.bold, fontSize: 10),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Metrics Row
                Row(
                  children: [
                    _buildMetric(
                      title: 'Orders Placed',
                      value: '${stats['totalOrdersPlaced'] ?? 0}+',
                      icon: Icons.shopping_bag_outlined,
                      color: const Color(0xFF3ECFCF),
                    ),
                    const SizedBox(width: 8),
                    _buildMetric(
                      title: 'Completion Rate',
                      value: '${stats['completionRate'] ?? 98}%',
                      icon: Icons.task_alt_rounded,
                      color: const Color(0xFF10B981),
                    ),
                    const SizedBox(width: 8),
                    _buildMetric(
                      title: 'Trust Rating',
                      value: '${p['customerRating'] ?? 5.0} ★',
                      icon: Icons.star_rounded,
                      color: const Color(0xFFF59E0B),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Feedback Tags by Drivers & Merchants
                const Text(
                  'Driver & Merchant Feedback Tags',
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
                        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.thumb_up_alt_rounded, color: Color(0xFF34D399), size: 12),
                          const SizedBox(width: 6),
                          Text(tag, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text('$count', style: const TextStyle(color: Color(0xFF6EE7B7), fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 22),

                // Reviews from Drivers & Shops
                const Text(
                  'Driver & Store Feedback Logs',
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
    final name = rev['reviewerName'] ?? 'Partner Driver';
    final role = rev['reviewerRole'] ?? 'Driver';
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
              Text('$name ($role)', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
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
            Text('🏷️ $tags', style: const TextStyle(color: Color(0xFF6EE7B7), fontSize: 11)),
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
