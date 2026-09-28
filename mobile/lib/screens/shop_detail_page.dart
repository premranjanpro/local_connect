import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';
import '../services/api_service.dart';
import 'category_products_page.dart';
import 'cart_page.dart';
import '../widgets/profile_sheets/shop_profile_sheet.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  Shop Detail Page — Hero + Category Grid
// ══════════════════════════════════════════════════════════════════════════════

class ShopDetailPage extends StatefulWidget {
  final Map<String, dynamic> shop;
  const ShopDetailPage({super.key, required this.shop});

  @override
  State<ShopDetailPage> createState() => _ShopDetailPageState();
}

class _ShopDetailPageState extends State<ShopDetailPage> {
  List<Map<String, dynamic>> _categories = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final data = await ApiService.getShopCategories(widget.shop['id']);
      setState(() {
        _categories = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _categories = _mockCategories();
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> _mockCategories() => [
        {
          'id': 'cat-01',
          'name': 'Vegetables',
          'icon': '🥦',
          'color': '0xFF059669',
          'itemCount': 24,
        },
        {
          'id': 'cat-02',
          'name': 'Fruits',
          'icon': '🍎',
          'color': '0xFFEF4444',
          'itemCount': 18,
        },
        {
          'id': 'cat-03',
          'name': 'Dairy',
          'icon': '🥛',
          'color': '0xFF3B82F6',
          'itemCount': 12,
        },
        {
          'id': 'cat-04',
          'name': 'Grocery',
          'icon': '🛒',
          'color': '0xFFF59E0B',
          'itemCount': 45,
        },
        {
          'id': 'cat-05',
          'name': 'Spices',
          'icon': '🌶️',
          'color': '0xFFEF4444',
          'itemCount': 30,
        },
        {
          'id': 'cat-06',
          'name': 'Snacks',
          'icon': '🍿',
          'color': '0xFF8B5CF6',
          'itemCount': 22,
        },
        {
          'id': 'cat-07',
          'name': 'Beverages',
          'icon': '🥤',
          'color': '0xFF06B6D4',
          'itemCount': 15,
        },
        {
          'id': 'cat-08',
          'name': 'Personal Care',
          'icon': '🧴',
          'color': '0xFFEC4899',
          'itemCount': 10,
        },
      ];

  Color _hexColor(String hex) {
    try {
      return Color(int.parse(hex.replaceAll('0x', ''), radix: 16));
    } catch (_) {
      return const Color(0xFF059669);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cart = context.watch<CartProvider>();
    final shopColor = _hexColor(widget.shop['primaryColor'] ?? '0xFF059669');

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF060B18) : const Color(0xFFF1F5F9),
      body: CustomScrollView(
        slivers: [
          // ── Hero SliverAppBar ──────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: shopColor,
            leading: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.arrow_back_rounded,
                    color: Colors.white),
              ),
            ),
            actions: [
              // Cart badge
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CartPage()),
                ),
                child: Container(
                  margin: const EdgeInsets.all(8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(children: [
                    const Icon(Icons.shopping_cart_rounded,
                        color: Colors.white, size: 18),
                    if (cart.totalCount > 0) ...[
                      const SizedBox(width: 5),
                      Text('${cart.totalCount}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                    ],
                  ]),
                ),
              ),

              // Store Info / Profile Button
              GestureDetector(
                onTap: () {
                  final bid = widget.shop['id']?.toString() ?? '7a74b169-0512-4a3b-9f7d-6020832ceaf0';
                  showShopProfileSheet(context, businessId: bid);
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(children: [
                    Icon(Icons.info_outline_rounded, color: Colors.white, size: 18),
                    SizedBox(width: 4),
                    Text('Store Info', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  ]),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      shopColor,
                      shopColor.withValues(alpha: 0.7),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 50, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.storefront_rounded,
                                color: Colors.white, size: 26),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(widget.shop['businessName'],
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 20)),
                                Text(widget.shop['category'],
                                    style: TextStyle(
                                        color: Colors.white
                                            .withValues(alpha: 0.8),
                                        fontSize: 13)),
                              ],
                            ),
                          ),
                          _OpenBadge(isOpen: widget.shop['isOpen'] == true),
                        ]),
                        const SizedBox(height: 10),
                        GestureDetector(
                          onTap: () {
                            final bid = widget.shop['id']?.toString() ?? '7a74b169-0512-4a3b-9f7d-6020832ceaf0';
                            showShopProfileSheet(context, businessId: bid);
                          },
                          child: Row(children: [
                            const Icon(Icons.star_rounded,
                                color: Color(0xFFF59E0B), size: 16),
                            const SizedBox(width: 4),
                            Text('${widget.shop['rating'] ?? 5.0}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13)),
                            const SizedBox(width: 4),
                            const Text('(View Reviews)',
                                style: TextStyle(
                                    color: Colors.white70,
                                    decoration: TextDecoration.underline,
                                    fontSize: 11)),
                            const SizedBox(width: 14),
                            const Icon(Icons.location_on_rounded,
                                color: Colors.white70, size: 14),
                            const SizedBox(width: 4),
                            Text('${widget.shop['distance'] ?? '1.2'} km away',
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 12)),
                          ]),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Quick actions bar ─────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Row(
                children: [
                  _QuickActionBtn(
                    icon: Icons.edit_note_rounded,
                    label: 'Free Text Order',
                    color: const Color(0xFF6366F1),
                    isDark: isDark,
                    onTap: () => _openFreeText(),
                  ),
                  const SizedBox(width: 10),
                  _QuickActionBtn(
                    icon: Icons.local_offer_rounded,
                    label: "Today's Offers",
                    color: const Color(0xFFF59E0B),
                    isDark: isDark,
                    onTap: () {},
                  ),
                  const SizedBox(width: 10),
                  _QuickActionBtn(
                    icon: Icons.phone_rounded,
                    label: 'Call Shop',
                    color: const Color(0xFF10B981),
                    isDark: isDark,
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ),

          // ── Section title ─────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Browse Categories',
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
              ),
            ),
          ),

          // ── Category grid ─────────────────────────────────────────────
          _loading
              ? const SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(
                          color: Color(0xFF1D4ED8)),
                    ),
                  ),
                )
              : SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.6,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => _CategoryCard(
                        category: _categories[i],
                        isDark: isDark,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CategoryProductsPage(
                              shop: widget.shop,
                              category: _categories[i],
                            ),
                          ),
                        ),
                      ),
                      childCount: _categories.length,
                    ),
                  ),
                ),
        ],
      ),

      // ── Floating cart button ─────────────────────────────────────────────
      floatingActionButton: cart.totalCount > 0
          ? Container(
              margin: const EdgeInsets.only(bottom: 8),
              child: ElevatedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CartPage()),
                ),
                icon: const Icon(Icons.shopping_cart_rounded),
                label: Text(
                    '${cart.totalCount} items • ₹${cart.totalAmount.toStringAsFixed(0)}'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: shopColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 8,
                ),
              ),
            )
          : null,
      floatingActionButtonLocation:
          FloatingActionButtonLocation.centerFloat,
    );
  }

  void _openFreeText() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: MediaQuery.of(context).viewInsets,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tell us what you need',
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              const Text('E.g. "5 kg aloo, 2 kg pyaj, 1 ltr dahi"',
                  style: TextStyle(
                      color: Color(0xFF94A3B8), fontSize: 12)),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                autofocus: true,
                maxLines: 4,
                style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF0F172A)),
                decoration: InputDecoration(
                  hintText: 'Type your requirement in Hindi or English...',
                  hintStyle:
                      const TextStyle(color: Color(0xFF64748B), fontSize: 13),
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
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      if (ctrl.text.trim().isEmpty) return;
                      context
                          .read<CartProvider>()
                          .setShop(widget.shop['id'], widget.shop['businessName']);
                      context
                          .read<CartProvider>()
                          .setFreeText(ctrl.text.trim());
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const CartPage()),
                      );
                    },
                    icon: const Icon(Icons.send_rounded, size: 16),
                    label: const Text('Send Request'),
                  ),
                ),
              ]),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _OpenBadge extends StatelessWidget {
  final bool isOpen;
  const _OpenBadge({required this.isOpen});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isOpen
            ? Colors.white.withValues(alpha: 0.2)
            : Colors.black26,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white54),
      ),
      child: Text(
        isOpen ? '● OPEN' : '● CLOSED',
        style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 10),
      ),
    );
  }
}

class _QuickActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  const _QuickActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: isDark ? 0.15 : 0.08),
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final Map<String, dynamic> category;
  final bool isDark;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.category,
    required this.isDark,
    required this.onTap,
  });

  Color get color {
    try {
      return Color(
          int.parse(category['color'].toString().replaceAll('0x', ''),
              radix: 16));
    } catch (_) {
      return const Color(0xFF059669);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withValues(alpha: isDark ? 0.3 : 0.15),
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.08),
              blurRadius: 8,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    category['icon'] ?? '🛒',
                    style: const TextStyle(fontSize: 26),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${category['itemCount']} items',
                      style: TextStyle(
                          color: color,
                          fontSize: 10,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                category['name'],
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Tap to explore',
                style: TextStyle(
                  color: isDark
                      ? const Color(0xFF64748B)
                      : const Color(0xFF94A3B8),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
