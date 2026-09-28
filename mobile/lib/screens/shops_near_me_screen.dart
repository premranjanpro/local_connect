import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'shop_detail_page.dart';
import 'calling_screen.dart';

class ShopsNearMeScreen extends StatefulWidget {
  const ShopsNearMeScreen({super.key});

  @override
  State<ShopsNearMeScreen> createState() => _ShopsNearMeScreenState();
}

class _ShopsNearMeScreenState extends State<ShopsNearMeScreen> {
  List<dynamic> _shops = [];
  bool _isLoading = false;
  String _selectedCategory = 'All';
  String _searchQuery = '';

  final List<String> _categories = [
    'All',
    'Grocery & Kirana',
    'Dairy & Milk',
    'Fruits & Vegetables',
    'Pharmacy & Meds',
    'Bakery & Sweets',
    'Food & Snacks'
  ];

  @override
  void initState() {
    super.initState();
    _loadShops();
  }

  Future<void> _loadShops() async {
    setState(() => _isLoading = true);
    try {
      final shops = await ApiService.getNearbyShops(
        lat: 26.9124,
        lng: 75.7873,
        radiusKm: 10.0,
        query: _selectedCategory == 'All' ? null : _selectedCategory,
      );
      setState(() {
        _shops = shops;
        _isLoading = false;
      });
    } catch (_) {
      // Fallback curated local shops
      setState(() {
        _shops = [
          {
            'id': '7a74b169-0512-4a3b-9f7d-6020832ceaf0',
            'name': 'Gupta Kirana & General Store',
            'category': 'Grocery & Kirana',
            'address': 'Shop 14, Main Market, Vaishali Nagar',
            'phone': '9828012345',
            'distanceKm': 0.8,
            'isOpen': true,
            'rating': 4.9,
          },
          {
            'id': 'shop-dairy-02',
            'name': 'Krishna Pure Farm Dairy',
            'category': 'Dairy & Milk',
            'address': 'Plot 8, Chitrakoot Sector 2',
            'phone': '9828033445',
            'distanceKm': 1.2,
            'isOpen': true,
            'rating': 4.8,
          },
          {
            'id': 'shop-pharm-03',
            'name': 'Sanjivani Medicos & Wellness',
            'category': 'Pharmacy & Meds',
            'address': 'Ground Floor, Queens Road Crossing',
            'phone': '9828055667',
            'distanceKm': 1.9,
            'isOpen': true,
            'rating': 4.7,
          },
          {
            'id': 'shop-veg-04',
            'name': 'Kisan Fresh Sabzi Mandi',
            'category': 'Fruits & Vegetables',
            'address': 'Khatipura Road, Near Overbridge',
            'phone': '9828077889',
            'distanceKm': 2.3,
            'isOpen': true,
            'rating': 4.6,
          },
        ];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _shops.where((s) {
      final name = (s['name'] ?? '').toString().toLowerCase();
      final cat = (s['category'] ?? '').toString().toLowerCase();
      final q = _searchQuery.toLowerCase();
      return name.contains(q) || cat.contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF060B18),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Shops Near Me',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white12),
              ),
              child: TextField(
                onChanged: (v) => setState(() => _searchQuery = v),
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: const InputDecoration(
                  hintText: 'Search stores, kirana, dairy, medicine...',
                  hintStyle: TextStyle(color: Colors.grey, fontSize: 12),
                  prefixIcon: Icon(Icons.search_rounded, color: Color(0xFF10B981), size: 20),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),

          // Category Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: _categories.map((c) {
                final isSel = _selectedCategory == c;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(c),
                    selected: isSel,
                    onSelected: (v) {
                      setState(() => _selectedCategory = c);
                      _loadShops();
                    },
                    selectedColor: const Color(0xFF10B981).withValues(alpha: 0.25),
                    checkmarkColor: const Color(0xFF34D399),
                    backgroundColor: const Color(0xFF1E293B),
                    labelStyle: TextStyle(
                      color: isSel ? const Color(0xFF34D399) : Colors.grey,
                      fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                      fontSize: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(color: isSel ? const Color(0xFF10B981) : Colors.white12),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 6),

          // Shops List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)))
                : filtered.isEmpty
                    ? const Center(child: Text('No shops found nearby', style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filtered.length,
                        itemBuilder: (ctx, i) {
                          final s = filtered[i];
                          return _buildShopCard(s);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildShopCard(dynamic s) {
    final name = s['name'] ?? 'Local Store';
    final category = s['category'] ?? 'Retail';
    final address = s['address'] ?? '';
    final phone = s['phone'] ?? '';
    final dist = (s['distanceKm'] as num?)?.toDouble() ?? 1.2;
    final isOpen = s['isOpen'] == true;
    final rating = (s['rating'] as num?)?.toDouble() ?? 4.8;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.storefront_rounded, color: Color(0xFF34D399), size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 2),
                      Text(category, style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 12)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isOpen ? const Color(0xFF10B981).withValues(alpha: 0.2) : Colors.red.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isOpen ? 'OPEN' : 'CLOSED',
                    style: TextStyle(
                      color: isOpen ? const Color(0xFF34D399) : Colors.redAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    address,
                    style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text('${dist.toStringAsFixed(1)} km', style: const TextStyle(color: Colors.grey, fontSize: 11)),
              ],
            ),
            const Divider(height: 22, color: Colors.white10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 16),
                    const SizedBox(width: 4),
                    Text(rating.toString(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
                Row(
                  children: [
                    if (phone.isNotEmpty)
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.call_rounded, color: Color(0xFF10B981), size: 20),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CallingScreen(
                                partnerUserId: phone,
                                partnerName: name,
                                partnerRole: 'Shop Owner',
                              ),
                            ),
                          );
                        },
                      ),
                    const SizedBox(width: 6),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ShopDetailPage(shop: s as Map<String, dynamic>),
                          ),
                        );
                      },
                      icon: const Icon(Icons.menu_book_rounded, size: 14),
                      label: const Text('View Catalog', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
