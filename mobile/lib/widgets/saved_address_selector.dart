import 'package:flutter/material.dart';
import '../services/api_service.dart';

/// Reusable Address Selector for Customer order/task creation.
/// Displays Home, Office, Other chips with quick-add dialog and optional lat/lng.
class SavedAddressSelector extends StatefulWidget {
  final String token;
  final String? initialSelectedId;
  final ValueChanged<Map<String, dynamic>> onAddressSelected;
  final VoidCallback? onManualAddressChosen;

  const SavedAddressSelector({
    super.key,
    required this.token,
    this.initialSelectedId,
    required this.onAddressSelected,
    this.onManualAddressChosen,
  });

  @override
  State<SavedAddressSelector> createState() => _SavedAddressSelectorState();
}

class _SavedAddressSelectorState extends State<SavedAddressSelector> {
  List<dynamic> _addresses = [];
  bool _loading = true;
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.initialSelectedId;
    _loadAddresses();
  }

  Future<void> _loadAddresses() async {
    setState(() => _loading = true);
    try {
      final list = await ApiService.getSavedAddresses(widget.token);
      if (mounted) {
        setState(() {
          _addresses = list;
          _loading = false;
          // Auto select default if nothing selected yet
          if (_selectedId == null && _addresses.isNotEmpty) {
            final defaultAddr = _addresses.firstWhere(
              (a) => a['isDefault'] == true,
              orElse: () => _addresses.first,
            );
            _selectedId = defaultAddr['id']?.toString();
            widget.onAddressSelected(Map<String, dynamic>.from(defaultAddr));
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  IconData _iconForType(String type) {
    switch (type.toLowerCase()) {
      case 'home':
        return Icons.home_rounded;
      case 'office':
      case 'work':
        return Icons.business_rounded;
      default:
        return Icons.location_on_rounded;
    }
  }

  Color _colorForType(String type) {
    switch (type.toLowerCase()) {
      case 'home':
        return const Color(0xFF10B981);
      case 'office':
      case 'work':
        return const Color(0xFF3B82F6);
      default:
        return const Color(0xFFF59E0B);
    }
  }

  void _showAddAddressDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddAddressBottomSheet(
        token: widget.token,
        onAddressAdded: (newAddr) {
          setState(() {
            _addresses.insert(0, newAddr);
            _selectedId = newAddr['id']?.toString();
          });
          widget.onAddressSelected(newAddr);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 48,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6C63FF)),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(Icons.bookmark_added_rounded, color: Color(0xFF6C63FF), size: 16),
                SizedBox(width: 6),
                Text(
                  'Saved Addresses',
                  style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            GestureDetector(
              onTap: _showAddAddressDialog,
              child: const Row(
                children: [
                  Icon(Icons.add_circle_outline_rounded, color: Color(0xFF3ECFCF), size: 15),
                  SizedBox(width: 4),
                  Text(
                    '+ Add New',
                    style: TextStyle(color: Color(0xFF3ECFCF), fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ..._addresses.map((addr) {
                final id = addr['id']?.toString();
                final isSelected = _selectedId == id;
                final type = addr['addressType'] ?? 'Home';
                final title = addr['title'] ?? type;
                final fullAddr = addr['fullAddress'] ?? '';
                final chipColor = _colorForType(type);

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _selectedId = id);
                      widget.onAddressSelected(Map<String, dynamic>.from(addr));
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? chipColor.withValues(alpha: 0.18)
                            : const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected ? chipColor : Colors.white12,
                          width: isSelected ? 1.5 : 1,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: chipColor.withValues(alpha: 0.2),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                )
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_iconForType(type), color: chipColor, size: 16),
                          const SizedBox(width: 6),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                title,
                                style: TextStyle(
                                  color: isSelected ? Colors.white : Colors.white70,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              if (fullAddr.isNotEmpty)
                                Text(
                                  fullAddr.length > 22
                                      ? '${fullAddr.substring(0, 22)}...'
                                      : fullAddr,
                                  style: const TextStyle(color: Colors.white38, fontSize: 10),
                                ),
                            ],
                          ),
                          if (isSelected) ...[
                            const SizedBox(width: 6),
                            Icon(Icons.check_circle_rounded, color: chipColor, size: 14),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              }),

              // Manual Entry Option Chip
              GestureDetector(
                onTap: () {
                  setState(() => _selectedId = 'manual');
                  widget.onManualAddressChosen?.call();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: _selectedId == 'manual'
                        ? const Color(0xFF6C63FF).withValues(alpha: 0.2)
                        : const Color(0xFF1A1E2E),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _selectedId == 'manual' ? const Color(0xFF6C63FF) : Colors.white12,
                      width: _selectedId == 'manual' ? 1.5 : 1,
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.edit_location_alt_rounded, color: Colors.white70, size: 15),
                      SizedBox(width: 6),
                      Text(
                        'Type Manual',
                        style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AddAddressBottomSheet extends StatefulWidget {
  final String token;
  final ValueChanged<Map<String, dynamic>> onAddressAdded;

  const _AddAddressBottomSheet({required this.token, required this.onAddressAdded});

  @override
  State<_AddAddressBottomSheet> createState() => _AddAddressBottomSheetState();
}

class _AddAddressBottomSheetState extends State<_AddAddressBottomSheet> {
  final _titleCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _landmarkCtrl = TextEditingController();
  final _latCtrl = TextEditingController();
  final _lngCtrl = TextEditingController();

  String _addressType = 'Home';
  bool _isDefault = false;
  bool _isSaving = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).padding.bottom + bottomInset + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 14),
            const Row(
              children: [
                Icon(Icons.add_location_alt_rounded, color: Color(0xFF3ECFCF), size: 22),
                SizedBox(width: 8),
                Text(
                  'Add New Address',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Type chips (Home, Office, Other)
            Row(
              children: ['Home', 'Office', 'Other'].map((t) {
                final isSelected = _addressType == t;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(t),
                      selected: isSelected,
                      selectedColor: const Color(0xFF3B82F6),
                      backgroundColor: const Color(0xFF1E293B),
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.white70,
                        fontWeight: FontWeight.bold,
                      ),
                      onSelected: (val) {
                        if (val) setState(() => _addressType = t);
                      },
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),

            // Title
            TextField(
              controller: _titleCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                labelText: 'Address Title (e.g. My Apartment, Branch Office)',
                labelStyle: const TextStyle(color: Colors.white54, fontSize: 12),
                filled: true,
                fillColor: const Color(0xFF1E293B),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),

            // Full Address
            TextField(
              controller: _addressCtrl,
              maxLines: 2,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                labelText: 'Full Address *',
                labelStyle: const TextStyle(color: Colors.white54, fontSize: 12),
                filled: true,
                fillColor: const Color(0xFF1E293B),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),

            // Landmark
            TextField(
              controller: _landmarkCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                labelText: 'Landmark (Optional)',
                labelStyle: const TextStyle(color: Colors.white54, fontSize: 12),
                filled: true,
                fillColor: const Color(0xFF1E293B),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),

            // Optional Coordinates (Lat / Lng)
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _latCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: InputDecoration(
                      labelText: 'Latitude (Optional)',
                      labelStyle: const TextStyle(color: Colors.white38, fontSize: 11),
                      filled: true,
                      fillColor: const Color(0xFF1E293B),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _lngCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: InputDecoration(
                      labelText: 'Longitude (Optional)',
                      labelStyle: const TextStyle(color: Colors.white38, fontSize: 11),
                      filled: true,
                      fillColor: const Color(0xFF1E293B),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Default Checkbox
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _isDefault,
              activeColor: const Color(0xFF10B981),
              title: const Text('Set as default delivery address', style: TextStyle(color: Colors.white70, fontSize: 13)),
              onChanged: (v) => setState(() => _isDefault = v ?? false),
            ),

            if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
              const SizedBox(height: 8),
            ],

            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _isSaving ? null : _saveAddress,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _isSaving
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Save Address', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveAddress() async {
    final addr = _addressCtrl.text.trim();
    if (addr.isEmpty) {
      setState(() => _error = 'Please enter full address.');
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final payload = {
        'addressType': _addressType,
        'title': _titleCtrl.text.trim().isEmpty ? _addressType : _titleCtrl.text.trim(),
        'fullAddress': addr,
        'landmark': _landmarkCtrl.text.trim().isEmpty ? null : _landmarkCtrl.text.trim(),
        'latitude': double.tryParse(_latCtrl.text.trim()),
        'longitude': double.tryParse(_lngCtrl.text.trim()),
        'isDefault': _isDefault,
      };

      final result = await ApiService.addSavedAddress(widget.token, payload);
      if (mounted) {
        Navigator.pop(context);
        widget.onAddressAdded(result);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _error = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }
}
