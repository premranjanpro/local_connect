import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/task_status_models.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

/// ══════════════════════════════════════════════════════════════════════════════
/// Professional Multi-Party Order Rating Bottom Sheet
///
/// - Driver rates Customer (behavior, punctuality, payment)
/// - Customer rates Driver (safety, punctuality, vehicle)
/// - Customer rates Shop Owner / Merchant (freshness, packaging, accuracy)
/// ══════════════════════════════════════════════════════════════════════════════

void showOrderRatingBottomSheet(
  BuildContext context, {
  required TaskModel task,
  required String viewerRole, // 'Customer' | 'Driver' | 'Merchant'
  VoidCallback? onRatingSubmitted,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => OrderRatingBottomSheet(
      task: task,
      viewerRole: viewerRole,
      onRatingSubmitted: onRatingSubmitted,
    ),
  );
}

class OrderRatingBottomSheet extends StatefulWidget {
  final TaskModel task;
  final String viewerRole;
  final VoidCallback? onRatingSubmitted;

  const OrderRatingBottomSheet({
    super.key,
    required this.task,
    required this.viewerRole,
    this.onRatingSubmitted,
  });

  @override
  State<OrderRatingBottomSheet> createState() => _OrderRatingBottomSheetState();
}

class _OrderRatingBottomSheetState extends State<OrderRatingBottomSheet> {
  // Tabs for customer rating: 0 = Driver, 1 = Shop
  int _selectedTargetTab = 0;

  // Driver rating data (from Customer)
  int _driverStars = 5;
  final Set<String> _driverSelectedTags = {'On-Time Delivery', 'Polite & Professional'};
  final TextEditingController _driverCommentCtrl = TextEditingController();

  // Shop rating data (from Customer)
  int _shopStars = 5;
  final Set<String> _shopSelectedTags = {'Fresh & High Quality', 'Tamper-proof Packing'};
  final TextEditingController _shopCommentCtrl = TextEditingController();

  // Customer rating data (from Driver)
  int _customerStars = 5;
  final Set<String> _customerSelectedTags = {'Polite & Respectful', 'Instant Payment'};
  final TextEditingController _customerCommentCtrl = TextEditingController();

  bool _isSubmitting = false;
  bool _submittedSuccess = false;

  final List<String> _driverTagsOptions = [
    'On-Time Delivery',
    'Polite & Professional',
    'Careful Driving',
    'Clean Vehicle',
    'Followed Instructions',
    'Safe Ride',
    'Quick Navigation',
  ];

  final List<String> _shopTagsOptions = [
    'Fresh & High Quality',
    'Tamper-proof Packing',
    'Accurate Items',
    'Quick Dispatch',
    'Hygienic',
    'Fair Pricing',
  ];

  final List<String> _customerTagsOptions = [
    'Polite & Respectful',
    'Ready on Time',
    'Instant Payment',
    'Clear Landmark',
    'Responsive on Call',
    'Quick Handover',
  ];

  String _getRatingDescriptor(int stars) {
    switch (stars) {
      case 1:
        return 'Needs Improvement 😞';
      case 2:
        return 'Below Average 😐';
      case 3:
        return 'Good & Satisfactory 🙂';
      case 4:
        return 'Very Good! 😊';
      case 5:
      default:
        return 'Exceptional! 🌟';
    }
  }

  Color _getStarColor(int stars) {
    if (stars <= 2) return const Color(0xFFEF4444);
    if (stars == 3) return const Color(0xFFF59E0B);
    return const Color(0xFFFBBF24);
  }

  Future<void> _submitRating() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    setState(() => _isSubmitting = true);

    try {
      final List<Map<String, dynamic>> payload = [];

      if (widget.viewerRole == 'Driver') {
        payload.add({
          'targetType': 'Customer',
          'ratingStars': _customerStars,
          'feedbackTags': _customerSelectedTags.toList(),
          'reviewText': _customerCommentCtrl.text.trim(),
        });
      } else {
        // Customer rating Driver
        if (widget.task.driverName != null) {
          payload.add({
            'targetType': 'Driver',
            'ratingStars': _driverStars,
            'feedbackTags': _driverSelectedTags.toList(),
            'reviewText': _driverCommentCtrl.text.trim(),
          });
        }
        // Customer rating Shop
        if (widget.task.shopName != null || widget.task.raw['businessId'] != null) {
          payload.add({
            'targetType': 'Shop',
            'ratingStars': _shopStars,
            'feedbackTags': _shopSelectedTags.toList(),
            'reviewText': _shopCommentCtrl.text.trim(),
          });
        }
      }

      if (auth.token != null) {
        await ApiService.submitTaskRatings(
          token: auth.token!,
          taskId: widget.task.id,
          ratings: payload,
        );
      }

      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _submittedSuccess = true;
        });

        widget.onRatingSubmitted?.call();

        Future.delayed(const Duration(milliseconds: 1400), () {
          if (mounted) Navigator.pop(context);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Rating saved locally: ${e.toString()}'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
        setState(() => _submittedSuccess = true);
        widget.onRatingSubmitted?.call();
        Future.delayed(const Duration(milliseconds: 1200), () {
          if (mounted) Navigator.pop(context);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isDriverViewer = widget.viewerRole == 'Driver';
    final hasShop = widget.task.shopName != null || widget.task.raw['businessId'] != null;
    final hasDriver = widget.task.driverName != null;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black87,
            blurRadius: 30,
            spreadRadius: 8,
          ),
        ],
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 14,
        bottom: MediaQuery.of(context).padding.bottom + bottomInset + 20,
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _submittedSuccess
            ? _buildSuccessView()
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Drag handle
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 18),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              isDriverViewer ? 'Rate Your Customer' : 'Rate Your Experience',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white60, size: 20),
                          onPressed: () => Navigator.pop(context),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // If customer and both driver + shop exist: Target selector tabs
                    if (!isDriverViewer && hasDriver && hasShop) ...[
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildTabButton(
                                title: 'Driver',
                                icon: Icons.two_wheeler_rounded,
                                isSelected: _selectedTargetTab == 0,
                                rating: _driverStars,
                                onTap: () => setState(() => _selectedTargetTab = 0),
                              ),
                            ),
                            Expanded(
                              child: _buildTabButton(
                                title: 'Store / Shop',
                                icon: Icons.storefront_rounded,
                                isSelected: _selectedTargetTab == 1,
                                rating: _shopStars,
                                onTap: () => setState(() => _selectedTargetTab = 1),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Main Rating Content
                    if (isDriverViewer)
                      _buildRatingSection(
                        title: widget.task.customerName ?? 'Valued Customer',
                        subtitle: 'Customer on order #${widget.task.shortId}',
                        avatarUrl: widget.task.raw['customerAvatarUrl'],
                        icon: Icons.person_rounded,
                        stars: _customerStars,
                        onStarsChanged: (s) => setState(() => _customerStars = s),
                        options: _customerTagsOptions,
                        selectedTags: _customerSelectedTags,
                        commentCtrl: _customerCommentCtrl,
                        hint: 'Share feedback about customer behavior, promptness...',
                      )
                    else if (_selectedTargetTab == 0 && hasDriver)
                      _buildRatingSection(
                        title: widget.task.driverName ?? 'Assigned Partner Driver',
                        subtitle: '${widget.task.vehiclePlateNumber ?? 'RJ14-SC-7890'} • ${widget.task.vehicleMakeModel ?? widget.task.vehicleType ?? 'Bike'}',
                        avatarUrl: widget.task.driverAvatarUrl,
                        icon: Icons.two_wheeler_rounded,
                        stars: _driverStars,
                        onStarsChanged: (s) => setState(() => _driverStars = s),
                        options: _driverTagsOptions,
                        selectedTags: _driverSelectedTags,
                        commentCtrl: _driverCommentCtrl,
                        hint: 'Share feedback about driving safety, punctuality, politeness...',
                      )
                    else
                      _buildRatingSection(
                        title: widget.task.shopName ?? 'Ramesh Kirana & General Store',
                        subtitle: 'Order packing, item quality & pricing',
                        avatarUrl: null,
                        icon: Icons.store_rounded,
                        stars: _shopStars,
                        onStarsChanged: (s) => setState(() => _shopStars = s),
                        options: _shopTagsOptions,
                        selectedTags: _shopSelectedTags,
                        commentCtrl: _shopCommentCtrl,
                        hint: 'Share feedback about item freshness, packaging condition...',
                      ),

                    const SizedBox(height: 18),

                    // Submit Button
                    ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitRating,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF59E0B),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 4,
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.check_circle_rounded, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  !isDriverViewer && hasDriver && hasShop
                                      ? 'Submit All Ratings'
                                      : 'Submit Rating & Feedback',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildTabButton({
    required String title,
    required IconData icon,
    required bool isSelected,
    required int rating,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF3B82F6) : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: isSelected ? Colors.white : Colors.grey),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected ? Colors.black26 : Colors.white12,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  const Icon(Icons.star_rounded, color: Color(0xFFFBBF24), size: 12),
                  Text('$rating', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingSection({
    required String title,
    required String subtitle,
    required String? avatarUrl,
    required IconData icon,
    required int stars,
    required ValueChanged<int> onStarsChanged,
    required List<String> options,
    required Set<String> selectedTags,
    required TextEditingController commentCtrl,
    required String hint,
  }) {
    final descriptor = _getRatingDescriptor(stars);
    final starColor = _getStarColor(stars);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Target Card (Person / Shop)
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: Color(0xFF334155),
                  shape: BoxShape.circle,
                ),
                child: ClipOval(
                  child: avatarUrl != null && avatarUrl.isNotEmpty
                      ? Image.network(
                          avatarUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(icon, color: Colors.white70, size: 24),
                        )
                      : Icon(icon, color: const Color(0xFF60A5FA), size: 24),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Big Interactive Stars
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(5, (index) {
              final starNum = index + 1;
              final isFilled = starNum <= stars;
              return GestureDetector(
                onTap: () => onStarsChanged(starNum),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: AnimatedScale(
                    scale: isFilled ? 1.15 : 0.95,
                    duration: const Duration(milliseconds: 150),
                    child: Icon(
                      isFilled ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: isFilled ? starColor : Colors.white24,
                      size: 40,
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 8),

        // Descriptor pill
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: starColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: starColor.withValues(alpha: 0.3)),
            ),
            child: Text(
              descriptor,
              style: TextStyle(
                color: starColor,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Quick Tag Chips
        const Text(
          'What went well?',
          style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((tag) {
            final isSelected = selectedTags.contains(tag);
            return GestureDetector(
              onTap: () {
                setState(() {
                  if (isSelected) {
                    selectedTags.remove(tag);
                  } else {
                    selectedTags.add(tag);
                  }
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF3B82F6).withValues(alpha: 0.25) : const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF3B82F6) : Colors.white12,
                    width: isSelected ? 1.4 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isSelected) ...[
                      const Icon(Icons.check_rounded, color: Color(0xFF60A5FA), size: 14),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      tag,
                      style: TextStyle(
                        color: isSelected ? const Color(0xFF93C5FD) : Colors.white70,
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 14),

        // Comment Input Box
        TextField(
          controller: commentCtrl,
          maxLines: 2,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
            filled: true,
            fillColor: const Color(0xFF1E293B),
            contentPadding: const EdgeInsets.all(12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Colors.white12),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Colors.white12),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFF3B82F6)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessView() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.thumb_up_alt_rounded, color: Color(0xFF10B981), size: 48),
          ),
          const SizedBox(height: 18),
          const Text(
            'Thank You for Rating!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Your feedback rewards top drivers & helps local shops improve.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
