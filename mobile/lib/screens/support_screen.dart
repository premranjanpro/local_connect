import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  Future<void> _launchUrl(String urlString) async {
    final uri = Uri.parse(urlString);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

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
          'Help & Support',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Emergency SOS Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF7F1D1D), Color(0xFF991B1B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFEF4444)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.sos_rounded, color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Emergency SOS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                        SizedBox(height: 2),
                        Text('Instant alert to shop owner & emergency response', style: TextStyle(color: Colors.white70, fontSize: 11)),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('🚨 Emergency SOS alert transmitted to dispatch center!'),
                          backgroundColor: Color(0xFFEF4444),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFFDC2626),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                    child: const Text('TRIGGER', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            const Text(
              'CONTACT SUPPORT CHANNELS',
              style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1),
            ),
            const SizedBox(height: 10),

            // Contact Channels
            _channelTile(
              icon: Icons.chat_rounded,
              color: const Color(0xFF10B981),
              title: 'WhatsApp Live Chat',
              subtitle: 'Connect with support representative on WhatsApp',
              actionLabel: 'Chat Now',
              onTap: () => _launchUrl('https://wa.me/919828012345?text=Hello%20LocalConnect%20Support'),
            ),
            const SizedBox(height: 10),
            _channelTile(
              icon: Icons.phone_rounded,
              color: const Color(0xFF38BDF8),
              title: 'Toll-Free Helpline',
              subtitle: '1800-LOCAL-SEWA (24x7 Available)',
              actionLabel: 'Call Now',
              onTap: () => _launchUrl('tel:1800562257'),
            ),
            const SizedBox(height: 20),

            const Text(
              'FREQUENTLY ASKED QUESTIONS (FAQ)',
              style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1),
            ),
            const SizedBox(height: 10),

            // FAQs
            _faqTile(
              'Delivery Boy kaise vehicle switch karega?',
              'Delivery Boy apne dashboard me "My Garage" tab me jakar kisi bhi register kiye hue vehicle par "Go Online" button tap karke instantly switch kar sakta hai.',
            ),
            _faqTile(
              'Kya ek hi delivery boy multiple shops se jud sakta hai?',
              'Haan! ShopConnector multi-tenant architecture support karta hai. Ek delivery boy multiple shop owners se connected hokar dono ki delivery tasks seamlessly complete kar sakta hai.',
            ),
            _faqTile(
              'Customer OTP verify kaise hota hai?',
              'Order pickup ke time Shop Owner ya Driver Pickup OTP verify karta hai, aur delivery complete hone par Customer ko greeting toast ke sath Dropoff OTP match kiya jata hai.',
            ),
            _faqTile(
              'School Service task me kya features hain?',
              'School transit schedule me student pickup, boarding notification, school arrival, aur dropoff status parents aur shop owners dono ko real-time MQTT map par live dikhta hai.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _channelTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required String actionLabel,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: color.withValues(alpha: 0.2),
              foregroundColor: color,
              elevation: 0,
              side: BorderSide(color: color.withValues(alpha: 0.5)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              visualDensity: VisualDensity.compact,
            ),
            child: Text(actionLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
          ),
        ],
      ),
    );
  }

  Widget _faqTile(String question, String answer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        collapsedIconColor: Colors.grey,
        iconColor: const Color(0xFF38BDF8),
        title: Text(question, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Text(answer, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12, height: 1.4)),
          ),
        ],
      ),
    );
  }
}
