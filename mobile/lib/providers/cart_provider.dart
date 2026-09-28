import 'package:flutter/material.dart';

class CartItem {
  final String productId;
  final String productName;
  final double price;
  final String unit;
  double quantity;
  final String? imageUrl;

  CartItem({
    required this.productId,
    required this.productName,
    required this.price,
    required this.unit,
    this.quantity = 1,
    this.imageUrl,
  });

  double get total => price * quantity;

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'productName': productName,
        'unitPrice': price,
        'unit': unit,
        'quantity': quantity,
        'totalPrice': total,
      };
}

class CartProvider extends ChangeNotifier {
  final List<CartItem> _items = [];
  String? _shopId;
  String? _shopName;
  String? _freeTextNote;

  List<CartItem> get items => List.unmodifiable(_items);
  String? get shopId => _shopId;
  String? get shopName => _shopName;
  String? get freeTextNote => _freeTextNote;

  int get totalCount =>
      _items.fold(0, (sum, i) => sum + i.quantity.ceil());

  double get totalAmount => _items.fold(0, (sum, i) => sum + i.total);

  bool get isEmpty => _items.isEmpty && (_freeTextNote?.isEmpty ?? true);

  void setShop(String id, String name) {
    if (_shopId != id) {
      _items.clear();
      _freeTextNote = null;
    }
    _shopId = id;
    _shopName = name;
    notifyListeners();
  }

  void addItem(CartItem item) {
    final idx = _items.indexWhere((i) => i.productId == item.productId);
    if (idx >= 0) {
      _items[idx].quantity += item.quantity;
    } else {
      _items.add(item);
    }
    notifyListeners();
  }

  void removeItem(String productId) {
    _items.removeWhere((i) => i.productId == productId);
    notifyListeners();
  }

  void updateQty(String productId, double qty) {
    final idx = _items.indexWhere((i) => i.productId == productId);
    if (idx >= 0) {
      if (qty <= 0) {
        _items.removeAt(idx);
      } else {
        _items[idx].quantity = qty;
      }
      notifyListeners();
    }
  }

  void setFreeText(String? text) {
    _freeTextNote = text;
    notifyListeners();
  }

  void clear() {
    _items.clear();
    _freeTextNote = null;
    notifyListeners();
  }

  List<Map<String, dynamic>> toJsonItems() =>
      _items.map((i) => i.toJson()).toList();
}
