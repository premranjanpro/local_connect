import 'package:flutter/material.dart';
import '../../services/api_service.dart';

/// Shows an attractive, professional Shop Owner / Store profile modal.
void showShopProfileSheet(BuildContext context, {required String businessId}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _ShopProfileSheet(businessId: businessId),
  );
}

class _ShopProfileSheet extends StatefulWidget {
  final String businessId;

  const _ShopProfileSheet({required this.businessId});

  @override
  State<_ShopProfileSheet> createState() => _ShopProfileSheetState();
}

class _ShopProfileSheetState extends State<_ShopProfileSheet> {
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
      final data = await ApiService.getShopProfile(widget.businessId);
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
              : _buildProfileContent(),
    );
  }

  Widget _buildProfileContent() {
    final p = _profile!;
    final stats = p['stats'] as Map<String, dynamic>? ?? {};
    final topTags = (p['topTags'] as List<dynamic>?) ?? [];
    final recentReviews = (p['recentReviews'] as List<dynamic>?) ?? [];
    final isOpen = p['isOpen'] == true;

    return Column(
      children: [
        // Drag handle
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
                // Header Banner
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B), Color(0xFF1E293B)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B82F6).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF60A5FA).withValues(alpha: 0.4)),
                        ),
                        child: const Icon(Icons.storefront_rounded, color: Color(0xFF60A5FA), size: 36),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    p['name'] ?? 'Local Store',
                                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                    maxLines: 1, overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(Icons.verified, color: Color(0xFF10B981), size: 16),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${p['category'] ?? 'Retail'} • ${p['address'] ?? ''}',
                              style: const TextStyle(color: Colors.white60, fontSize: 12),
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isOpen ? const Color(0xFF10B981).withValues(alpha: 0.2) : Colors.red.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    isOpen ? 'OPEN NOW' : 'CLOSED',
                                    style: TextStyle(
                                      color: isOpen ? const Color(0xFF34D399) : Colors.redAccent,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '🕒 ${p['openTime'] ?? '08:00'} - ${p['closeTime'] ?? '22:00'}',
                                  style: const TextStyle(color: Colors.white38, fontSize: 11),
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

                // Metrics Strip
                Row(
                  children: [
                    _buildMetricCard(
                      title: 'Orders Fulfilled',
                      value: '${stats['totalOrdersFulfilled'] ?? 0}+',
                      icon: Icons.check_circle_outline_rounded,
                      color: const Color(0xFF3ECFCF),
                    ),
                    const SizedBox(width: 8),
                    _buildMetricCard(
                      title: 'On-Time Rate',
                      value: '${stats['onTimeRate'] ?? 96}%',
                      icon: Icons.speed_rounded,
                      color: const Color(0xFF10B981),
                    ),
                    const SizedBox(width: 8),
                    _buildMetricCard(
                      title: 'Rating Score',
                      value: '${p['rating'] ?? 5.0} ★',
                      icon: Icons.star_rounded,
                      color: const Color(0xFFF59E0B),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Positive Customer Highlights (Tags)
                const Text(
                  'Customer Praise & Highlights',
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
                          const Icon(Icons.thumb_up_alt_rounded, color: Color(0xFF60A5FA), size: 12),
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

                // Recent Customer Reviews
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Verified Customer Reviews',
                      style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${recentReviews.length} Reviews',
                      style: const TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                  ],
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
                      child: Text('No reviews yet. Be the first to rate!', style: TextStyle(color: Colors.white38, fontSize: 12)),
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

  Widget _buildMetricCard({required String title, required String value, required IconData icon, required Color color}) {
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
    final name = rev['reviewerName'] ?? 'Verified Customer';
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
