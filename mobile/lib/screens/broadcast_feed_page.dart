import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import 'create_broadcast_page.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  Broadcast Feed Page — Hyperlocal Need / Offer posts
// ══════════════════════════════════════════════════════════════════════════════

class BroadcastFeedPage extends StatefulWidget {
  const BroadcastFeedPage({super.key});

  @override
  State<BroadcastFeedPage> createState() => _BroadcastFeedPageState();
}

class _BroadcastFeedPageState extends State<BroadcastFeedPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  String _filter = 'All'; // All / NEED / OFFER
  List<Map<String, dynamic>> _posts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _tabCtrl.addListener(() {
      setState(() {
        _filter = ['All', 'NEED', 'OFFER'][_tabCtrl.index];
      });
    });
    _loadPosts();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPosts() async {
    setState(() => _loading = true);
    try {
      final data = await ApiService.getBroadcastPosts(
          lat: 26.9124, lng: 75.7873, radiusKm: 5);
      setState(() {
        _posts = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _posts = _mockPosts();
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> _mockPosts() => [
        {
          'id': 'b001',
          'postType': 'NEED',
          'posterName': 'Rajesh Kumar',
          'distance': 1.2,
          'description': '5 kg aloo, 2 kg pyaj, 1 kg tamatar chahiye fresh wala',
          'price': 150.0,
          'priceMode': 'ASKING',
          'createdAt': DateTime.now().subtract(const Duration(minutes: 8)).toIso8601String(),
          'responseCount': 3,
          'status': 'Active',
          'hasVoice': true,
          'hasMedia': false,
        },
        {
          'id': 'b002',
          'postType': 'OFFER',
          'posterName': 'Gupta Store',
          'distance': 0.8,
          'description': 'Fresh vegetables 20% off today only — tomato ₹40/kg, potato ₹22/kg',
          'price': null,
          'priceMode': 'FIXED',
          'createdAt': DateTime.now().subtract(const Duration(minutes: 15)).toIso8601String(),
          'responseCount': 12,
          'status': 'Active',
          'hasVoice': false,
          'hasMedia': true,
        },
        {
          'id': 'b003',
          'postType': 'NEED',
          'posterName': 'Priya Sharma',
          'distance': 2.1,
          'description': 'Electrician chahiye ghar mein wiring problem hai, budget ₹500',
          'price': 500.0,
          'priceMode': 'FIXED',
          'createdAt': DateTime.now().subtract(const Duration(minutes: 30)).toIso8601String(),
          'responseCount': 1,
          'status': 'Active',
          'hasVoice': false,
          'hasMedia': false,
        },
        {
          'id': 'b004',
          'postType': 'OFFER',
          'posterName': 'Sharma Dairy',
          'distance': 0.5,
          'description': 'Pure cow milk subscription — ₹55/litre morning delivery 6–7 AM, minimum 3 days',
          'price': 55.0,
          'priceMode': 'FIXED',
          'createdAt': DateTime.now().subtract(const Duration(hours: 1)).toIso8601String(),
          'responseCount': 8,
          'status': 'Active',
          'hasVoice': false,
          'hasMedia': true,
        },
        {
          'id': 'b005',
          'postType': 'NEED',
          'posterName': 'Mohan Lal',
          'distance': 3.0,
          'description': 'Maid chahiye 4 hours daily morning, salary ₹3000/month',
          'price': 3000.0,
          'priceMode': 'FIXED',
          'createdAt': DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
          'responseCount': 0,
          'status': 'Active',
          'hasVoice': true,
          'hasMedia': false,
        },
      ];

  List<Map<String, dynamic>> get _filteredPosts {
    if (_filter == 'All') return _posts;
    return _posts.where((p) => p['postType'] == _filter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF060B18) : const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB), Color(0xFF6366F1)]),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.cell_tower_rounded,
                color: Colors.white, size: 16),
          ),
          const SizedBox(width: 10),
          Text(
            'Live Broadcast',
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              fontWeight: FontWeight.bold,
              fontSize: 17,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(children: [
              Icon(Icons.circle, color: Color(0xFFEF4444), size: 7),
              SizedBox(width: 4),
              Text('LIVE',
                  style: TextStyle(
                      color: Color(0xFFEF4444),
                      fontSize: 10,
                      fontWeight: FontWeight.bold)),
            ]),
          ),
        ]),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded,
                color: isDark ? Colors.white60 : const Color(0xFF64748B)),
            onPressed: _loadPosts,
          ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor:
              isDark ? Colors.white : const Color(0xFF0F172A),
          unselectedLabelColor: const Color(0xFF94A3B8),
          indicatorColor: const Color(0xFF8B5CF6),
          tabs: const [
            Tab(text: '🌐  All'),
            Tab(text: '📢  Need'),
            Tab(text: '🏷  Offer'),
          ],
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                  color: Color(0xFF8B5CF6)))
          : _filteredPosts.isEmpty
              ? _buildEmpty(isDark)
              : RefreshIndicator(
                  onRefresh: _loadPosts,
                  color: const Color(0xFF8B5CF6),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
                    itemCount: _filteredPosts.length,
                    itemBuilder: (_, i) => _BroadcastPostCard(
                      post: _filteredPosts[i],
                      isDark: isDark,
                      onRespond: () => _showRespondSheet(_filteredPosts[i]),
                    ),
                  ),
                ),

      // ── FABs: Need + Offer ───────────────────────────────────────────────
      floatingActionButton: _buildFABs(isDark),
    );
  }

  Widget _buildEmpty(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cell_tower_rounded,
              size: 64, color: Color(0xFF8B5CF6)),
          const SizedBox(height: 12),
          Text('No posts nearby',
              style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  fontWeight: FontWeight.bold,
                  fontSize: 16)),
          const SizedBox(height: 6),
          const Text('Be the first to post a Need or Offer!',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildFABs(bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Offer FAB
        FloatingActionButton.extended(
          heroTag: 'offer_fab',
          onPressed: () => _openCreate('OFFER'),
          backgroundColor: const Color(0xFF059669),
          icon: const Icon(Icons.local_offer_rounded),
          label: const Text('Post Offer',
              style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 10),
        // Need FAB
        FloatingActionButton.extended(
          heroTag: 'need_fab',
          onPressed: () => _openCreate('NEED'),
          backgroundColor: const Color(0xFF8B5CF6),
          icon: const Icon(Icons.campaign_rounded),
          label: const Text('Post Need',
              style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  void _openCreate(String type) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => CreateBroadcastPage(initialType: type)),
    ).then((_) => _loadPosts());
  }

  void _showRespondSheet(Map<String, dynamic> post) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ctrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final auth = context.read<AuthProvider>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: MediaQuery.of(context).viewInsets,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Respond to this ${post['postType']}',
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                post['description'],
                style: const TextStyle(
                    color: Color(0xFF94A3B8), fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 14),
              TextField(
                controller: ctrl,
                autofocus: true,
                maxLines: 3,
                style: TextStyle(
                    color: isDark
                        ? Colors.white
                        : const Color(0xFF0F172A),
                    fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Type your response...',
                  hintStyle: const TextStyle(
                      color: Color(0xFF64748B), fontSize: 13),
                  filled: true,
                  fillColor: isDark
                      ? const Color(0xFF0F172A)
                      : const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              if (post['priceMode'] == 'ASKING')
                TextField(
                  controller: priceCtrl,
                  keyboardType: TextInputType.number,
                  style: TextStyle(
                      color: isDark
                          ? Colors.white
                          : const Color(0xFF0F172A),
                      fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Your quoted price (₹)',
                    prefixText: '₹ ',
                    hintStyle: const TextStyle(
                        color: Color(0xFF64748B), fontSize: 13),
                    filled: true,
                    fillColor: isDark
                        ? const Color(0xFF0F172A)
                        : const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    if (ctrl.text.trim().isEmpty) return;
                    try {
                      await ApiService.respondToBroadcast(
                        token: auth.token!,
                        postId: post['id'],
                        message: ctrl.text.trim(),
                        quotedPrice: priceCtrl.text.isEmpty
                            ? null
                            : double.tryParse(priceCtrl.text),
                      );
                    } catch (_) {}
                    if (!context.mounted) return;
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('✅ Response sent!'),
                        backgroundColor: Color(0xFF10B981),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  icon: const Icon(Icons.send_rounded, size: 16),
                  label: const Text('Send Response',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Broadcast Post Card ───────────────────────────────────────────────────────
class _BroadcastPostCard extends StatelessWidget {
  final Map<String, dynamic> post;
  final bool isDark;
  final VoidCallback onRespond;

  const _BroadcastPostCard({
    required this.post,
    required this.isDark,
    required this.onRespond,
  });

  @override
  Widget build(BuildContext context) {
    final isNeed = post['postType'] == 'NEED';
    final color =
        isNeed ? const Color(0xFF8B5CF6) : const Color(0xFF059669);
    final responseCount = post['responseCount'] as int? ?? 0;
    final price = (post['price'] as num?)?.toDouble();
    final priceMode = post['priceMode']?.toString();
    final hasVoice = post['hasVoice'] == true;
    final hasMedia = post['hasMedia'] == true;
    final timeAgo = _timeAgo(post['createdAt']);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: color.withValues(alpha: isDark ? 0.35 : 0.2)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.06),
            blurRadius: 10,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: type badge + name + distance + time
            Row(children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(isNeed ? Icons.campaign_rounded : Icons.local_offer_rounded,
                      color: color, size: 13),
                  const SizedBox(width: 4),
                  Text(isNeed ? 'NEED' : 'OFFER',
                      style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.bold,
                          fontSize: 10)),
                ]),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  post['posterName'] ?? 'Anonymous',
                  style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      fontWeight: FontWeight.bold,
                      fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Row(children: [
                const Icon(Icons.location_on_rounded,
                    color: Color(0xFF94A3B8), size: 12),
                Text('${post['distance']} km',
                    style: const TextStyle(
                        color: Color(0xFF94A3B8), fontSize: 11)),
              ]),
            ]),

            const SizedBox(height: 10),

            // Description
            Text(
              post['description'] ?? '',
              style: TextStyle(
                color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
                fontSize: 14,
                height: 1.4,
              ),
            ),

            const SizedBox(height: 8),

            // Media indicators
            if (hasVoice || hasMedia)
              Row(children: [
                if (hasVoice) ...[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.mic_rounded,
                              color: Color(0xFF60A5FA), size: 12),
                          SizedBox(width: 4),
                          Text('Voice',
                              style: TextStyle(
                                  color: Color(0xFF60A5FA), fontSize: 10)),
                        ]),
                  ),
                  const SizedBox(width: 6),
                ],
                if (hasMedia)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.image_rounded,
                              color: Color(0xFFFCD34D), size: 12),
                          SizedBox(width: 4),
                          Text('Photo',
                              style: TextStyle(
                                  color: Color(0xFFFCD34D), fontSize: 10)),
                        ]),
                  ),
              ]),

            const SizedBox(height: 8),

            // Price + time + responses
            Row(children: [
              if (price != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    priceMode == 'ASKING'
                        ? 'Budget: ₹${price.toStringAsFixed(0)}'
                        : '₹${price.toStringAsFixed(0)}',
                    style: const TextStyle(
                        color: Color(0xFF34D399),
                        fontWeight: FontWeight.bold,
                        fontSize: 11),
                  ),
                )
              else if (priceMode == 'ASKING')
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('Asking price',
                      style: TextStyle(
                          color: Color(0xFFFCD34D), fontSize: 11)),
                ),
              const Spacer(),
              Text(timeAgo,
                  style: const TextStyle(
                      color: Color(0xFF64748B), fontSize: 11)),
            ]),

            const SizedBox(height: 12),

            // Bottom: responses count + respond button
            Row(children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(children: [
                  const Icon(Icons.chat_bubble_outline_rounded,
                      size: 13, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 5),
                  Text('$responseCount response${responseCount != 1 ? 's' : ''}',
                      style: const TextStyle(
                          color: Color(0xFF94A3B8), fontSize: 11)),
                ]),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: onRespond,
                icon: Icon(
                  isNeed
                      ? Icons.reply_rounded
                      : Icons.thumb_up_rounded,
                  size: 14,
                ),
                label: Text(isNeed ? 'Respond' : 'Interested',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  String _timeAgo(String? iso) {
    if (iso == null) return '';
    try {
      final d = DateTime.parse(iso);
      final diff = DateTime.now().difference(d);
      if (diff.inMinutes < 1) return 'just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) {
      return '';
    }
  }
}
