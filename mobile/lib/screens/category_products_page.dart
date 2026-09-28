import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';
import '../services/api_service.dart';
import 'cart_page.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  Category Products Page — SubCategory + Product List with Add to Cart
// ══════════════════════════════════════════════════════════════════════════════

class CategoryProductsPage extends StatefulWidget {
  final Map<String, dynamic> shop;
  final Map<String, dynamic> category;

  const CategoryProductsPage({
    super.key,
    required this.shop,
    required this.category,
  });

  @override
  State<CategoryProductsPage> createState() => _CategoryProductsPageState();
}

class _CategoryProductsPageState extends State<CategoryProductsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  List<String> _subCategories = ['All'];
  List<Map<String, dynamic>> _products = [];
  String _selectedSub = 'All';
  bool _loading = true;
  String _sortBy = 'default';

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    try {
      final data = await ApiService.getCategoryProducts(
        widget.shop['id'],
        widget.category['id'],
      );
      final products = List<Map<String, dynamic>>.from(data);
      final subs = ['All', ...{...products.map((p) => p['subCategory'] as String? ?? 'Others')}];
      setState(() {
        _products = products;
        _subCategories = subs;
        _tabCtrl = TabController(length: subs.length, vsync: this);
        _loading = false;
      });
    } catch (_) {
      final mock = _mockProducts();
      final subs = ['All', ...{...mock.map((p) => p['subCategory'] as String? ?? 'Others')}];
      setState(() {
        _products = mock;
        _subCategories = subs;
        _tabCtrl = TabController(length: subs.length, vsync: this);
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> _mockProducts() {
    final cat = widget.category['name']?.toString().toLowerCase() ?? '';
    if (cat.contains('vegetable')) {
      return [
        {'id': 'p001', 'name': 'Aloo (Potato)', 'price': 25.0, 'unit': 'kg', 'subCategory': 'Root Vegetables', 'stock': 50.0, 'description': 'Fresh farm aloo'},
        {'id': 'p002', 'name': 'Pyaj (Onion)', 'price': 30.0, 'unit': 'kg', 'subCategory': 'Root Vegetables', 'stock': 40.0, 'description': 'Red onions'},
        {'id': 'p003', 'name': 'Tamatar (Tomato)', 'price': 40.0, 'unit': 'kg', 'subCategory': 'Salad', 'stock': 30.0, 'description': 'Ripe red tomatoes'},
        {'id': 'p004', 'name': 'Palak (Spinach)', 'price': 20.0, 'unit': 'bunch', 'subCategory': 'Leafy Greens', 'stock': 20.0, 'description': 'Fresh palak patta'},
        {'id': 'p005', 'name': 'Gobhi (Cauliflower)', 'price': 35.0, 'unit': 'piece', 'subCategory': 'Cruciferous', 'stock': 15.0, 'description': 'White cauliflower'},
        {'id': 'p006', 'name': 'Gajar (Carrot)', 'price': 28.0, 'unit': 'kg', 'subCategory': 'Root Vegetables', 'stock': 25.0, 'description': 'Orange carrots'},
        {'id': 'p007', 'name': 'Methi', 'price': 15.0, 'unit': 'bunch', 'subCategory': 'Leafy Greens', 'stock': 10.0, 'description': 'Fresh methi leaves'},
        {'id': 'p008', 'name': 'Lauki (Bottle Gourd)', 'price': 18.0, 'unit': 'piece', 'subCategory': 'Gourds', 'stock': 12.0, 'description': 'Fresh lauki'},
      ];
    }
    return [
      {'id': 'p101', 'name': 'Full Cream Milk', 'price': 60.0, 'unit': 'litre', 'subCategory': 'Milk', 'stock': 100.0, 'description': 'Fresh cow milk'},
      {'id': 'p102', 'name': 'Dahi (Curd)', 'price': 45.0, 'unit': '500g', 'subCategory': 'Curd & Yogurt', 'stock': 30.0, 'description': 'Homemade curd'},
      {'id': 'p103', 'name': 'Paneer', 'price': 120.0, 'unit': '200g', 'subCategory': 'Paneer', 'stock': 20.0, 'description': 'Fresh soft paneer'},
      {'id': 'p104', 'name': 'Butter', 'price': 55.0, 'unit': '100g', 'subCategory': 'Butter', 'stock': 15.0, 'description': 'Amul-style butter'},
    ];
  }

  List<Map<String, dynamic>> get _filteredProducts {
    List<Map<String, dynamic>> list = _selectedSub == 'All'
        ? _products
        : _products.where((p) => p['subCategory'] == _selectedSub).toList();
    if (_sortBy == 'price_asc') {
      list = [...list]..sort((a, b) => (a['price'] as num).compareTo(b['price'] as num));
    } else if (_sortBy == 'price_desc') {
      list = [...list]..sort((a, b) => (b['price'] as num).compareTo(a['price'] as num));
    }
    return list;
  }

  Color get _shopColor {
    try {
      return Color(int.parse(
          widget.shop['primaryColor'].toString().replaceAll('0x', ''),
          radix: 16));
    } catch (_) {
      return const Color(0xFF059669);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cart = context.watch<CartProvider>();

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF060B18) : const Color(0xFFF1F5F9),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(color: _shopColor),
            )
          : NestedScrollView(
              headerSliverBuilder: (ctx, _) => [
                SliverAppBar(
                  pinned: true,
                  backgroundColor: _shopColor,
                  title: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.category['name'],
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                      Text(widget.shop['businessName'],
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 11)),
                    ],
                  ),
                  actions: [
                    // Sort
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.sort_rounded,
                          color: Colors.white),
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      onSelected: (v) => setState(() => _sortBy = v),
                      itemBuilder: (_) => [
                        const PopupMenuItem(value: 'default', child: Text('Default')),
                        const PopupMenuItem(value: 'price_asc', child: Text('Price: Low to High')),
                        const PopupMenuItem(value: 'price_desc', child: Text('Price: High to Low')),
                      ],
                    ),
                    // Cart
                    GestureDetector(
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const CartPage())),
                      child: Container(
                        margin: const EdgeInsets.only(right: 12),
                        child: Stack(
                          children: [
                            const Icon(Icons.shopping_cart_rounded,
                                color: Colors.white, size: 24),
                            if (cart.totalCount > 0)
                              Positioned(
                                right: 0,
                                top: 0,
                                child: Container(
                                  width: 14,
                                  height: 14,
                                  decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle),
                                  child: Text('${cart.totalCount}',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold)),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  bottom: TabBar(
                    controller: _tabCtrl,
                    isScrollable: true,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white60,
                    indicatorColor: Colors.white,
                    indicatorWeight: 2.5,
                    tabAlignment: TabAlignment.start,
                    labelStyle: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 12),
                    tabs: _subCategories
                        .map((s) => Tab(text: s))
                        .toList(),
                    onTap: (i) =>
                        setState(() => _selectedSub = _subCategories[i]),
                  ),
                ),
              ],
              body: _filteredProducts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.inventory_2_outlined,
                              size: 60,
                              color: isDark
                                  ? Colors.white24
                                  : Colors.grey.shade300),
                          const SizedBox(height: 12),
                          const Text('No products in this category',
                              style: TextStyle(color: Color(0xFF94A3B8))),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding:
                          const EdgeInsets.fromLTRB(12, 12, 12, 80),
                      itemCount: _filteredProducts.length,
                      itemBuilder: (_, i) => _ProductCard(
                        product: _filteredProducts[i],
                        shopId: widget.shop['id'],
                        shopName: widget.shop['businessName'],
                        accentColor: _shopColor,
                        isDark: isDark,
                      ),
                    ),
            ),
      // Floating cart button
      floatingActionButton: cart.totalCount > 0
          ? Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 24),
              child: ElevatedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CartPage()),
                ),
                icon: const Icon(Icons.shopping_cart_rounded),
                label: Text(
                    '${cart.totalCount} items • ₹${cart.totalAmount.toStringAsFixed(0)} — View Cart'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _shopColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 10,
                ),
              ),
            )
          : null,
      floatingActionButtonLocation:
          FloatingActionButtonLocation.centerFloat,
    );
  }
}

// ── Product Card ──────────────────────────────────────────────────────────────
class _ProductCard extends StatefulWidget {
  final Map<String, dynamic> product;
  final String shopId;
  final String shopName;
  final Color accentColor;
  final bool isDark;

  const _ProductCard({
    required this.product,
    required this.shopId,
    required this.shopName,
    required this.accentColor,
    required this.isDark,
  });

  @override
  State<_ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<_ProductCard> {
  double _qty = 0;

  @override
  Widget build(BuildContext context) {
    final cart = context.read<CartProvider>();
    final inCart = context.watch<CartProvider>()
        .items
        .indexWhere((i) => i.productId == widget.product['id']) >= 0;
    final price = (widget.product['price'] as num).toDouble();
    final unit = widget.product['unit']?.toString() ?? 'piece';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: inCart
              ? widget.accentColor.withValues(alpha: 0.5)
              : (widget.isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
          width: inCart ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: inCart
                ? widget.accentColor.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: widget.isDark ? 0.1 : 0.04),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        children: [
          // Emoji / image placeholder
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: widget.accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                _emojiFor(widget.product['name']),
                style: const TextStyle(fontSize: 26),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.product['name'],
                  style: TextStyle(
                    color: widget.isDark
                        ? Colors.white
                        : const Color(0xFF0F172A),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.product['description'] ?? '',
                  style: const TextStyle(
                      color: Color(0xFF94A3B8), fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  '₹${price.toStringAsFixed(0)} / $unit',
                  style: TextStyle(
                    color: widget.accentColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Add / Qty controls
          inCart
              ? _QtyControl(
                  product: widget.product,
                  accentColor: widget.accentColor,
                  isDark: widget.isDark,
                )
              : GestureDetector(
                  onTap: () {
                    cart.setShop(widget.shopId, widget.shopName);
                    cart.addItem(CartItem(
                      productId: widget.product['id'],
                      productName: widget.product['name'],
                      price: price,
                      unit: unit,
                    ));
                    setState(() => _qty = 1);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: widget.accentColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'ADD',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12),
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  String _emojiFor(String name) {
    final n = name.toLowerCase();
    if (n.contains('aloo') || n.contains('potato')) return '🥔';
    if (n.contains('pyaj') || n.contains('onion')) return '🧅';
    if (n.contains('tamatar') || n.contains('tomato')) return '🍅';
    if (n.contains('palak') || n.contains('spinach')) return '🥬';
    if (n.contains('gobhi') || n.contains('cauliflower')) return '🥦';
    if (n.contains('gajar') || n.contains('carrot')) return '🥕';
    if (n.contains('milk') || n.contains('doodh')) return '🥛';
    if (n.contains('dahi') || n.contains('curd')) return '🥛';
    if (n.contains('paneer')) return '🧀';
    if (n.contains('butter')) return '🧈';
    if (n.contains('apple') || n.contains('seb')) return '🍎';
    if (n.contains('banana') || n.contains('kela')) return '🍌';
    return '🛒';
  }
}

class _QtyControl extends StatefulWidget {
  final Map<String, dynamic> product;
  final Color accentColor;
  final bool isDark;

  const _QtyControl({
    required this.product,
    required this.accentColor,
    required this.isDark,
  });

  @override
  State<_QtyControl> createState() => _QtyControlState();
}

class _QtyControlState extends State<_QtyControl> {
  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final item = cart.items
        .where((i) => i.productId == widget.product['id'])
        .firstOrNull;
    final qty = item?.quantity ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: widget.accentColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: widget.accentColor.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () => context.read<CartProvider>()
                .updateQty(widget.product['id'], qty - 1),
            child: Container(
              padding: const EdgeInsets.all(6),
              child: Icon(
                qty <= 1 ? Icons.delete_outline_rounded : Icons.remove_rounded,
                color: widget.accentColor,
                size: 16,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              qty.toStringAsFixed(qty == qty.truncate() ? 0 : 1),
              style: TextStyle(
                color: widget.accentColor,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => context.read<CartProvider>()
                .updateQty(widget.product['id'], qty + 1),
            child: Container(
              padding: const EdgeInsets.all(6),
              child: Icon(Icons.add_rounded,
                  color: widget.accentColor, size: 16),
            ),
          ),
        ],
      ),
    );
  }
}
