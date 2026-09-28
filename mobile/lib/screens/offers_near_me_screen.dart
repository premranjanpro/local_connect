import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class OffersNearMeScreen extends StatelessWidget {
  const OffersNearMeScreen({super.key});

  final List<Map<String, dynamic>> _offers = const [
    {
      'code': 'KIRANA50',
      'title': 'Flat ₹50 OFF on Monthly Kirana',
      'shop': 'Gupta Kirana & General Store',
      'discount': '₹50 OFF',
      'minOrder': 'Min. Order ₹500',
      'expires': 'Valid till 30 Sep',
      'color': Color(0xFF10B981),
      'icon': Icons.shopping_basket_rounded,
    },
    {
      'code': 'MILKFREE',
      'title': 'First Day Free Milk (1 Litre)',
      'shop': 'Krishna Pure Farm Dairy',
      'discount': '100% FREE',
      'minOrder': 'With Monthly Milk Subscription',
      'expires': 'Valid this week',
      'color': Color(0xFF38BDF8),
      'icon': Icons.breakfast_dining_rounded,
    },
    {
      'code': 'MEDICINE15',
      'title': '15% OFF on Chronic Prescriptions',
      'shop': 'Sanjivani Medicos & Wellness',
      'discount': '15% OFF',
      'minOrder': 'Min. Order ₹300',
      'expires': 'Valid all month',
      'color': Color(0xFFF59E0B),
      'icon': Icons.medical_services_rounded,
    },
    {
      'code': 'CABRIDE20',
      'title': '20% Cashback on Daily Cab Rides',
      'shop': 'Local Connect Mobility',
      'discount': '20% BACK',
      'minOrder': 'First 3 Rides',
      'expires': 'Valid till Sunday',
      'color': Color(0xFF8B5CF6),
      'icon': Icons.local_taxi_rounded,
    },
  ];

  @override
  Widget build(BuildContext context) {
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
          'Offers & Deals Near Me',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _offers.length,
        itemBuilder: (ctx, i) {
          final o = _offers[i];
          final color = o['color'] as Color;
          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: color.withValues(alpha: 0.4)),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 3)),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(o['icon'] as IconData, color: color, size: 22),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(o['shop'].toString(), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                              Text(
                                o['discount'].toString(),
                                style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 16),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Text(o['expires'].toString(), style: const TextStyle(color: Colors.grey, fontSize: 10)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    o['title'].toString(),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(o['minOrder'].toString(), style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                  const Divider(height: 20, color: Colors.white10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: color.withValues(alpha: 0.5), style: BorderStyle.solid),
                        ),
                        child: Row(
                          children: [
                            Text(
                              o['code'].toString(),
                              style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: o['code'].toString()));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Coupon ${o['code']} copied to clipboard!'),
                              backgroundColor: color,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        icon: const Icon(Icons.copy_rounded, size: 14),
                        label: const Text('Copy Code', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: color,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
