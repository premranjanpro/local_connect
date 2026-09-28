import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../services/api_service.dart';
import 'shop_detail_page.dart';
import 'broadcast_feed_page.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  Map Home Screen — Full-screen map with search + shop discovery
// ══════════════════════════════════════════════════════════════════════════════

class MapHomeScreen extends StatefulWidget {
  const MapHomeScreen({super.key});

  @override
  State<MapHomeScreen> createState() => _MapHomeScreenState();
}

class _MapHomeScreenState extends State<MapHomeScreen>
    with SingleTickerProviderStateMixin {
  final MapController _mapCtrl = MapController();
  final TextEditingController _searchCtrl = TextEditingController();
  final DraggableScrollableController _sheetCtrl =
      DraggableScrollableController();

  // Location — default: Jaipur
  LatLng _myLocation = const LatLng(26.9124, 75.7873);

  List<dynamic> _shops = [];
  List<dynamic> _filteredShops = [];
  bool _loading = false;
  bool _mapReady = false;
  String? _selectedShopId;

  @override
  void initState() {
    super.initState();
    _loadNearbyShops();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _sheetCtrl.dispose();
    super.dispose();
  }

  // ─── Data Loading ─────────────────────────────────────────────────────────

  Future<void> _loadNearbyShops({String? query}) async {
    setState(() => _loading = true);
    try {
      final data = await ApiService.getNearbyShops(
        lat: _myLocation.latitude,
        lng: _myLocation.longitude,
        radiusKm: 5,
        query: query,
      );
      setState(() {
        _shops = data;
        _filteredShops = data;
        _loading = false;
      });
    } catch (_) {
      // Fallback to mock shops
      setState(() {
        _shops = _mockShops();
        _filteredShops = _mockShops();
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> _mockShops() => [
        {
          'id': 'shop-001',
          'businessName': 'Gupta Kirana Store',
          'category': 'Grocery',
          'latitude': 26.9180,
          'longitude': 75.7920,
          'distance': 0.8,
          'rating': 4.5,
          'isOpen': true,
          'primaryColor': '0xFF059669',
          'description': 'Fresh vegetables, dairy, and grocery items',
        },
        {
          'id': 'shop-002',
          'businessName': 'Fresh Mart',
          'category': 'Vegetables & Fruits',
          'latitude': 26.9060,
          'longitude': 75.7840,
          'distance': 1.2,
          'rating': 4.2,
          'isOpen': true,
          'primaryColor': '0xFF10B981',
          'description': 'Premium vegetables sourced directly from farms',
        },
        {
          'id': 'shop-003',
          'businessName': 'Raja Medical',
          'category': 'Pharmacy',
          'latitude': 26.9200,
          'longitude': 75.7800,
          'distance': 1.5,
          'rating': 4.8,
          'isOpen': false,
          'primaryColor': '0xFF3B82F6',
          'description': 'Medicines and healthcare products',
        },
        {
          'id': 'shop-004',
          'businessName': 'Hot Bites Kitchen',
          'category': 'Food & Tiffin',
          'latitude': 26.9090,
          'longitude': 75.7960,
          'distance': 2.1,
          'rating': 4.6,
          'isOpen': true,
          'primaryColor': '0xFFF59E0B',
          'description': 'Home-cooked tiffin & hot snacks delivered',
        },
        {
          'id': 'shop-005',
          'businessName': 'Sharma Dairy',
          'category': 'Dairy',
          'latitude': 26.9150,
          'longitude': 75.7860,
          'distance': 0.5,
          'rating': 4.9,
          'isOpen': true,
          'primaryColor': '0xFF8B5CF6',
          'description': 'Pure cow milk, curd, paneer — daily delivery',
        },
      ];

  void _onSearch(String q) {
    final lower = q.toLowerCase();
    setState(() {
      _filteredShops = q.isEmpty
          ? _shops
          : _shops
              .where((s) =>
                  (s['businessName'] as String)
                      .toLowerCase()
                      .contains(lower) ||
                  (s['category'] as String).toLowerCase().contains(lower))
              .toList();
    });
    if (q.length > 2) _loadNearbyShops(query: q);
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: Stack(
        children: [
          // ── Full-screen map ──────────────────────────────────────────────
          _buildMap(isDark),

          // ── Top overlay: search + broadcast ─────────────────────────────
          _buildTopOverlay(isDark),

          // ── Bottom draggable sheet: shop list ────────────────────────────
          _buildBottomSheet(isDark),
        ],
      ),
    );
  }

  Widget _buildMap(bool isDark) {
    return FlutterMap(
      mapController: _mapCtrl,
      options: MapOptions(
        initialCenter: _myLocation,
        initialZoom: 14,
        onMapReady: () => setState(() => _mapReady = true),
        onTap: (_, __) => setState(() => _selectedShopId = null),
      ),
      children: [
        // OSM tile layer
        TileLayer(
          urlTemplate: isDark
              ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
              : 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
          subdomains: const ['a', 'b', 'c', 'd'],
          userAgentPackageName: 'com.shopconnector.app',
        ),
        // Shop markers
        MarkerLayer(markers: _buildShopMarkers()),
        // My location
        MarkerLayer(
          markers: [
            Marker(
              point: _myLocation,
              width: 50,
              height: 50,
              child: _MyLocationMarker(),
            ),
          ],
        ),
      ],
    );
  }

  List<Marker> _buildShopMarkers() {
    return _filteredShops.map<Marker>((shop) {
      final lat = (shop['latitude'] as num).toDouble();
      final lng = (shop['longitude'] as num).toDouble();
      final isOpen = shop['isOpen'] == true;
      final isSelected = _selectedShopId == shop['id'];
      final color = isOpen ? AppTheme._colorFromHex(shop['primaryColor']) : Colors.grey;

      return Marker(
        point: LatLng(lat, lng),
        width: isSelected ? 140 : 110,
        height: isSelected ? 55 : 44,
        child: GestureDetector(
          onTap: () {
            setState(() => _selectedShopId = shop['id']);
            _mapCtrl.move(LatLng(lat, lng), 15.5);
            _showShopPreview(shop);
          },
          child: _ShopMapPin(
            name: shop['businessName'],
            category: shop['category'],
            color: color,
            isOpen: isOpen,
            isSelected: isSelected,
          ),
        ),
      );
    }).toList();
  }

  Widget _buildTopOverlay(bool isDark) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
        child: Column(
          children: [
            // Search + Broadcast row
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1E293B)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: _onSearch,
                      style: TextStyle(
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                          fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Search shops, items, services...',
                        hintStyle: TextStyle(
                            color: isDark
                                ? const Color(0xFF64748B)
                                : const Color(0xFF94A3B8),
                            fontSize: 13),
                        prefixIcon: Icon(Icons.search_rounded,
                            color: isDark
                                ? const Color(0xFF64748B)
                                : const Color(0xFF94A3B8),
                            size: 20),
                        suffixIcon: _searchCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close_rounded, size: 18),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  _onSearch('');
                                })
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 14, horizontal: 16),
                        filled: false,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Broadcast button
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const BroadcastFeedPage()),
                  ),
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB), Color(0xFF6366F1)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF8B5CF6).withValues(alpha: 0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.cell_tower_rounded,
                            color: Colors.white, size: 20),
                        Text('Live',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Category filter chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  'All',
                  'Grocery',
                  'Vegetables',
                  'Dairy',
                  'Food',
                  'Pharmacy',
                  'Bakery',
                ].map((cat) {
                  final sel = cat == 'All'
                      ? _searchCtrl.text.isEmpty
                      : _searchCtrl.text == cat;
                  return GestureDetector(
                    onTap: () {
                      if (cat == 'All') {
                        _searchCtrl.clear();
                        _onSearch('');
                      } else {
                        _searchCtrl.text = cat;
                        _onSearch(cat);
                      }
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: sel
                            ? const Color(0xFF1D4ED8)
                            : (isDark
                                ? const Color(0xFF1E293B)
                                : Colors.white),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black
                                  .withValues(alpha: isDark ? 0.3 : 0.08),
                              blurRadius: 6),
                        ],
                      ),
                      child: Text(
                        cat,
                        style: TextStyle(
                          color: sel
                              ? Colors.white
                              : (isDark
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF64748B)),
                          fontSize: 12,
                          fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomSheet(bool isDark) {
    return DraggableScrollableSheet(
      controller: _sheetCtrl,
      initialChildSize: 0.28,
      minChildSize: 0.12,
      maxChildSize: 0.7,
      builder: (ctx, scrollCtrl) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _loading
                          ? 'Searching...'
                          : '${_filteredShops.length} shops nearby',
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    if (_loading)
                      const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF1D4ED8))),
                  ],
                ),
              ),
              // Shop list
              Expanded(
                child: _filteredShops.isEmpty && !_loading
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.store_outlined,
                                size: 48,
                                color: isDark
                                    ? Colors.white24
                                    : Colors.grey.shade300),
                            const SizedBox(height: 8),
                            Text('No shops found',
                                style: TextStyle(
                                    color: isDark
                                        ? const Color(0xFF64748B)
                                        : Colors.grey)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: scrollCtrl,
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        itemCount: _filteredShops.length,
                        itemBuilder: (_, i) =>
                            _ShopListCard(
                          shop: _filteredShops[i],
                          isDark: isDark,
                          isSelected:
                              _selectedShopId == _filteredShops[i]['id'],
                          onTap: () => _openShop(_filteredShops[i]),
                          onLocate: () {
                            final lat = (_filteredShops[i]['latitude'] as num)
                                .toDouble();
                            final lng = (_filteredShops[i]['longitude'] as num)
                                .toDouble();
                            _mapCtrl.move(LatLng(lat, lng), 16);
                            setState(() =>
                                _selectedShopId = _filteredShops[i]['id']);
                          },
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showShopPreview(Map<String, dynamic> shop) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 24),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 20),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme._colorFromHex(shop['primaryColor'])
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.storefront_rounded,
                      color:
                          AppTheme._colorFromHex(shop['primaryColor']),
                      size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(shop['businessName'],
                          style: TextStyle(
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF0F172A),
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                      Text(shop['category'],
                          style: const TextStyle(
                              color: Color(0xFF94A3B8), fontSize: 12)),
                    ],
                  ),
                ),
                _OpenClosedBadge(isOpen: shop['isOpen'] == true),
              ],
            ),
            const SizedBox(height: 10),
            Text(shop['description'] ?? '',
                style: TextStyle(
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF475569),
                    fontSize: 13)),
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.star_rounded,
                  color: Color(0xFFF59E0B), size: 16),
              const SizedBox(width: 4),
              Text('${shop['rating']}',
                  style: const TextStyle(
                      color: Color(0xFFF59E0B),
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
              const SizedBox(width: 12),
              const Icon(Icons.directions_walk_rounded,
                  color: Color(0xFF94A3B8), size: 14),
              const SizedBox(width: 4),
              Text('${shop['distance']} km away',
                  style: const TextStyle(
                      color: Color(0xFF94A3B8), fontSize: 12)),
            ]),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _openShop(shop);
                },
                icon: const Icon(Icons.shopping_bag_rounded, size: 18),
                label: const Text('Open Shop',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      AppTheme._colorFromHex(shop['primaryColor']),
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
    );
  }

  void _openShop(Map<String, dynamic> shop) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ShopDetailPage(shop: shop)),
    );
  }
}

// ── Color helper ─────────────────────────────────────────────────────────────
extension AppTheme on Object {
  static Color _colorFromHex(dynamic hex) {
    try {
      return Color(int.parse(hex.toString().replaceAll('0x', ''),
          radix: 16));
    } catch (_) {
      return const Color(0xFF059669);
    }
  }
}

// ── My Location Marker ────────────────────────────────────────────────────────
class _MyLocationMarker extends StatefulWidget {
  @override
  State<_MyLocationMarker> createState() => _MyLocationMarkerState();
}

class _MyLocationMarkerState extends State<_MyLocationMarker>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _ring;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat();
    _ring = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        AnimatedBuilder(
          animation: _ring,
          builder: (_, __) => Container(
            width: 50 * _ring.value,
            height: 50 * _ring.value,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF1D4ED8)
                  .withValues(alpha: (1 - _ring.value) * 0.4),
            ),
          ),
        ),
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: const Color(0xFF1D4ED8),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: const [
              BoxShadow(
                  color: Color(0xFF1D4ED8),
                  blurRadius: 8,
                  spreadRadius: 1),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Shop Map Pin ──────────────────────────────────────────────────────────────
class _ShopMapPin extends StatelessWidget {
  final String name;
  final String category;
  final Color color;
  final bool isOpen;
  final bool isSelected;

  const _ShopMapPin({
    required this.name,
    required this.category,
    required this.color,
    required this.isOpen,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutBack,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: isOpen ? color : Colors.grey.shade600,
        borderRadius: BorderRadius.circular(10),
        border: isSelected
            ? Border.all(color: Colors.white, width: 2)
            : null,
        boxShadow: [
          BoxShadow(
            color: (isOpen ? color : Colors.grey)
                .withValues(alpha: isSelected ? 0.5 : 0.3),
            blurRadius: isSelected ? 14 : 8,
            spreadRadius: isSelected ? 2 : 0,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _iconFor(category),
            color: Colors.white,
            size: isSelected ? 16 : 14,
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              name,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: isSelected ? 11 : 10,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(String cat) {
    final c = cat.toLowerCase();
    if (c.contains('grocery') || c.contains('kirana')) {
      return Icons.shopping_basket_rounded;
    }
    if (c.contains('vegetable') || c.contains('fruit')) {
      return Icons.eco_rounded;
    }
    if (c.contains('dairy') || c.contains('milk')) {
      return Icons.water_drop_rounded;
    }
    if (c.contains('food') || c.contains('tiffin')) {
      return Icons.fastfood_rounded;
    }
    if (c.contains('pharma') || c.contains('medical')) {
      return Icons.local_pharmacy_rounded;
    }
    return Icons.storefront_rounded;
  }
}

// ── Open/Closed Badge ─────────────────────────────────────────────────────────
class _OpenClosedBadge extends StatelessWidget {
  final bool isOpen;
  const _OpenClosedBadge({required this.isOpen});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isOpen
            ? const Color(0xFF10B981).withValues(alpha: 0.15)
            : Colors.grey.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: isOpen ? const Color(0xFF10B981) : Colors.grey,
            width: 0.8),
      ),
      child: Text(
        isOpen ? 'OPEN' : 'CLOSED',
        style: TextStyle(
          color: isOpen ? const Color(0xFF10B981) : Colors.grey,
          fontWeight: FontWeight.bold,
          fontSize: 10,
        ),
      ),
    );
  }
}

// ── Shop List Card ────────────────────────────────────────────────────────────
class _ShopListCard extends StatelessWidget {
  final Map<String, dynamic> shop;
  final bool isDark;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLocate;

  const _ShopListCard({
    required this.shop,
    required this.isDark,
    required this.isSelected,
    required this.onTap,
    required this.onLocate,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppTheme._colorFromHex(shop['primaryColor']);
    final isOpen = shop['isOpen'] == true;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: isDark ? 0.12 : 0.06)
              : (isDark ? const Color(0xFF1E293B) : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? color.withValues(alpha: 0.6)
                : (isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? color.withValues(alpha: 0.15)
                  : Colors.black.withValues(alpha: isDark ? 0.15 : 0.05),
              blurRadius: isSelected ? 12 : 6,
            ),
          ],
        ),
        child: Row(
          children: [
            // Category icon
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: color.withValues(alpha: isOpen ? 0.15 : 0.07),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _iconFor(shop['category']),
                color: isOpen ? color : Colors.grey,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          shop['businessName'],
                          style: TextStyle(
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF0F172A),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      _OpenClosedBadge(isOpen: isOpen),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    shop['category'],
                    style: const TextStyle(
                        color: Color(0xFF94A3B8), fontSize: 11),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded,
                          color: Color(0xFFF59E0B), size: 13),
                      const SizedBox(width: 3),
                      Text(
                        '${shop['rating']}',
                        style: const TextStyle(
                            color: Color(0xFFF59E0B),
                            fontWeight: FontWeight.bold,
                            fontSize: 11),
                      ),
                      const SizedBox(width: 10),
                      const Icon(Icons.location_on_rounded,
                          color: Color(0xFF94A3B8), size: 12),
                      const SizedBox(width: 3),
                      Text(
                        '${shop['distance']} km',
                        style: const TextStyle(
                            color: Color(0xFF94A3B8), fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              children: [
                // Locate button
                GestureDetector(
                  onTap: onLocate,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white10
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.my_location_rounded,
                        size: 16, color: Color(0xFF3B82F6)),
                  ),
                ),
                const SizedBox(height: 6),
                // Shop button
                GestureDetector(
                  onTap: onTap,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isOpen
                          ? color.withValues(alpha: 0.15)
                          : Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.arrow_forward_rounded,
                        size: 16,
                        color: isOpen ? color : Colors.grey),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(String cat) {
    final c = cat.toLowerCase();
    if (c.contains('grocery') || c.contains('kirana')) {
      return Icons.shopping_basket_rounded;
    }
    if (c.contains('vegetable') || c.contains('fruit')) {
      return Icons.eco_rounded;
    }
    if (c.contains('dairy') || c.contains('milk')) {
      return Icons.water_drop_rounded;
    }
    if (c.contains('food') || c.contains('tiffin')) {
      return Icons.fastfood_rounded;
    }
    if (c.contains('pharma') || c.contains('medical')) {
      return Icons.local_pharmacy_rounded;
    }
    return Icons.storefront_rounded;
  }
}
