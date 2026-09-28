import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import '../services/api_service.dart';
import '../services/audio_tone_service.dart';
import '../widgets/saved_address_selector.dart';
import 'order_confirm_page.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  Cart Page
// ══════════════════════════════════════════════════════════════════════════════

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  final TextEditingController _addrCtrl = TextEditingController();
  String _deliveryAddress = '';
  String _paymentMode = 'Cash';
  String _note = '';
  bool _placing = false;

  final List<String> _paymentModes = ['Cash', 'UPI', 'Dues (Khata)'];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cart = context.watch<CartProvider>();

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF060B18) : const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        title: Text(
          'My Cart • ${cart.shopName ?? 'Shop'}',
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded,
              color: isDark ? Colors.white : const Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (cart.totalCount > 0)
            TextButton(
              onPressed: () {
                cart.clear();
                Navigator.pop(context);
              },
              child: const Text('Clear',
                  style: TextStyle(color: Color(0xFFEF4444))),
            ),
        ],
      ),
      body: cart.isEmpty
          ? _buildEmpty(isDark)
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Free text note
                        if (cart.freeTextNote != null &&
                            cart.freeTextNote!.isNotEmpty)
                          _buildFreeTextCard(cart, isDark),

                        // Cart items
                        if (cart.items.isNotEmpty) ...[
                          _sectionTitle('Cart Items', isDark),
                          ...cart.items.map((item) =>
                              _CartItemCard(item: item, isDark: isDark)),
                        ],

                        const SizedBox(height: 16),
                        _sectionTitle('Delivery Details', isDark),
                        const SizedBox(height: 8),

                        // Saved Addresses Quick-Chips
                        Builder(builder: (context) {
                          final auth = context.watch<AuthProvider>();
                          if (auth.token == null) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: SavedAddressSelector(
                              token: auth.token!,
                              onAddressSelected: (addr) {
                                final full = addr['fullAddress']?.toString() ?? '';
                                setState(() {
                                  _deliveryAddress = full;
                                  _addrCtrl.text = full;
                                });
                              },
                              onManualAddressChosen: () {
                                setState(() {
                                  _deliveryAddress = '';
                                  _addrCtrl.clear();
                                });
                              },
                            ),
                          );
                        }),

                        // Delivery address
                        _buildTextField(
                          label: 'Delivery Address',
                          hint: 'Enter your full address...',
                          icon: Icons.location_on_rounded,
                          isDark: isDark,
                          controller: _addrCtrl,
                          onChanged: (v) => setState(() => _deliveryAddress = v),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 12),

                        // Special note
                        _buildTextField(
                          label: 'Special Instructions (Optional)',
                          hint: 'E.g. Ring bell twice, leave at door...',
                          icon: Icons.notes_rounded,
                          isDark: isDark,
                          onChanged: (v) => setState(() => _note = v),
                        ),
                        const SizedBox(height: 16),

                        _sectionTitle('Payment Mode', isDark),
                        _buildPaymentSelector(isDark),

                        const SizedBox(height: 16),
                        _buildPriceSummary(cart, isDark),
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                ),
                _buildPlaceOrderBar(cart, isDark),
              ],
            ),
    );
  }

  Widget _buildEmpty(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shopping_cart_outlined,
              size: 80,
              color: isDark ? Colors.white24 : Colors.grey.shade300),
          const SizedBox(height: 16),
          Text('Your cart is empty',
              style: TextStyle(
                  color: isDark ? Colors.white70 : const Color(0xFF475569),
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Add items from a shop to get started',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.storefront_rounded),
            label: const Text('Browse Shops'),
          ),
        ],
      ),
    );
  }

  Widget _buildFreeTextCard(CartProvider cart, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF6366F1).withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: const Color(0xFF6366F1).withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.chat_bubble_outline_rounded,
              color: Color(0xFF818CF8), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Your Requirement',
                    style: TextStyle(
                        color: Color(0xFF818CF8),
                        fontWeight: FontWeight.bold,
                        fontSize: 12)),
                const SizedBox(height: 4),
                Text(
                  cart.freeTextNote!,
                  style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      fontSize: 13),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => cart.setFreeText(null),
            child: const Icon(Icons.close_rounded,
                color: Color(0xFF94A3B8), size: 16),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: TextStyle(
          color: isDark ? Colors.white : const Color(0xFF0F172A),
          fontWeight: FontWeight.bold,
          fontSize: 15,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required String hint,
    required IconData icon,
    required bool isDark,
    required ValueChanged<String> onChanged,
    TextEditingController? controller,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      maxLines: maxLines,
      style: TextStyle(
          color: isDark ? Colors.white : const Color(0xFF0F172A),
          fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 18),
        filled: true,
        fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
              color: Color(0xFF1D4ED8), width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
            vertical: 14, horizontal: 14),
      ),
    );
  }

  Widget _buildPaymentSelector(bool isDark) {
    return Row(
      children: _paymentModes.map((mode) {
        final sel = _paymentMode == mode;
        Color modeColor;
        IconData modeIcon;
        if (mode == 'Cash') {
          modeColor = const Color(0xFF10B981);
          modeIcon = Icons.payments_rounded;
        } else if (mode == 'UPI') {
          modeColor = const Color(0xFF8B5CF6);
          modeIcon = Icons.qr_code_scanner_rounded;
        } else {
          modeColor = const Color(0xFFF59E0B);
          modeIcon = Icons.account_balance_wallet_rounded;
        }
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _paymentMode = mode),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: sel
                    ? modeColor.withValues(alpha: isDark ? 0.2 : 0.1)
                    : (isDark ? const Color(0xFF1E293B) : Colors.white),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: sel
                      ? modeColor
                      : (isDark
                          ? Colors.white10
                          : const Color(0xFFE2E8F0)),
                  width: sel ? 1.5 : 1,
                ),
              ),
              child: Column(
                children: [
                  Icon(modeIcon,
                      color: sel ? modeColor : const Color(0xFF94A3B8),
                      size: 20),
                  const SizedBox(height: 4),
                  Text(
                    mode,
                    style: TextStyle(
                      color: sel
                          ? modeColor
                          : const Color(0xFF94A3B8),
                      fontSize: 10,
                      fontWeight: sel
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPriceSummary(CartProvider cart, bool isDark) {
    const deliveryFee = 20.0;
    final subtotal = cart.totalAmount;
    final total = subtotal + deliveryFee;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          _priceRow('Subtotal', '₹${subtotal.toStringAsFixed(0)}',
              isDark, false),
          const SizedBox(height: 8),
          _priceRow(
              'Delivery Fee', '₹${deliveryFee.toStringAsFixed(0)}', isDark, false),
          const Divider(height: 16),
          _priceRow(
              'Total Payable', '₹${total.toStringAsFixed(0)}', isDark, true),
        ],
      ),
    );
  }

  Widget _priceRow(String label, String value, bool isDark, bool bold) {
    final color = bold ? const Color(0xFF10B981) : null;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                color: bold
                    ? (isDark ? Colors.white : const Color(0xFF0F172A))
                    : const Color(0xFF94A3B8),
                fontWeight:
                    bold ? FontWeight.bold : FontWeight.normal,
                fontSize: bold ? 15 : 13)),
        Text(value,
            style: TextStyle(
                color: color ??
                    (isDark ? Colors.white : const Color(0xFF0F172A)),
                fontWeight:
                    bold ? FontWeight.bold : FontWeight.w500,
                fontSize: bold ? 16 : 13)),
      ],
    );
  }

  Widget _buildPlaceOrderBar(CartProvider cart, bool isDark) {
    const deliveryFee = 20.0;
    final total = cart.totalAmount + deliveryFee;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _deliveryAddress.trim().isEmpty || _placing
            ? null
            : () => _placeOrder(cart, total),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1D4ED8),
          disabledBackgroundColor: const Color(0xFF334155),
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 54),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
        ),
        child: _placing
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
            : Text(
                _deliveryAddress.trim().isEmpty
                    ? 'Enter Delivery Address to Continue'
                    : 'Place Order • ₹${total.toStringAsFixed(0)}',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15),
              ),
      ),
    );
  }

  Future<void> _placeOrder(CartProvider cart, double total) async {
    setState(() => _placing = true);
    try {
      final auth = context.read<AuthProvider>();
      final payload = {
        'customerId': auth.userId,
        'businessId': cart.shopId,
        'deliveryAddress': _deliveryAddress,
        'paymentMode': _paymentMode,
        'specialNote': _note,
        'totalAmount': total,
        'freeTextNote': cart.freeTextNote,
        'items': cart.toJsonItems(),
      };
      AudioToneService.playOrderCreatedTone();
      final result = await ApiService.placeOrder(auth.token!, payload);
      cart.clear();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (_) => OrderConfirmPage(order: result)),
      );
    } catch (e) {
      AudioToneService.playOrderCreatedTone();
      // Mock success for dev
      final mockOrder = {
        'id': 'ORD-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
        'status': 'Pending',
        'businessName': cart.shopName,
        'totalAmount': total,
        'paymentMode': _paymentMode,
        'deliveryAddress': _deliveryAddress,
        'createdAt': DateTime.now().toIso8601String(),
      };
      cart.clear();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (_) => OrderConfirmPage(order: mockOrder)),
      );
    } finally {
      if (mounted) setState(() => _placing = false);
    }
  }
}

// ── Cart Item Card ────────────────────────────────────────────────────────────
class _CartItemCard extends StatelessWidget {
  final CartItem item;
  final bool isDark;

  const _CartItemCard({required this.item, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.productName,
                    style: TextStyle(
                        color: isDark
                            ? Colors.white
                            : const Color(0xFF0F172A),
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
                Text(
                    '${item.quantity.toStringAsFixed(item.quantity == item.quantity.truncate() ? 0 : 1)} ${item.unit} × ₹${item.price.toStringAsFixed(0)}',
                    style: const TextStyle(
                        color: Color(0xFF94A3B8), fontSize: 11)),
              ],
            ),
          ),
          Text(
            '₹${item.total.toStringAsFixed(0)}',
            style: const TextStyle(
                color: Color(0xFF10B981),
                fontWeight: FontWeight.bold,
                fontSize: 14),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () =>
                context.read<CartProvider>().removeItem(item.productId),
            child: const Icon(Icons.delete_outline_rounded,
                color: Color(0xFFEF4444), size: 18),
          ),
        ],
      ),
    );
  }
}
